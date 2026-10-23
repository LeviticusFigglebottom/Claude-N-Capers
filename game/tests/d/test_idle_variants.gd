## D polish #2: idle_alert and idle variety (tools/blender/characters/_anim_idle_var.py). idle_alert_b (a watch check, a
## weight shift) and idle_alert_c (the shoulder radio, a look round) start on idle_alert frame 0; idle_b (a watch check,
## a weight shift) and idle_c (a stretch, a look round) on idle frame 0 (calm posts). Every variant is a loop whose frame 0
## IS its base's frame 0 (so A can swap them in through VARIANT_GROUPS without touching any chain), closes exactly, keeps
## the root fixed, stays above the floor and moves smoothly; SOURCE carries the notes A follows. Run after
## `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, event, event frame, base clip]
const CLIPS: Dictionary = {
	"idle_alert_b": [150, "watch", 57, "idle_alert"], "idle_alert_c": [174, "radio", 44, "idle_alert"],
	"idle_b": [162, "watch", 70, "idle"], "idle_c": [198, "stretch", 65, "idle"],
}
## frame 0 vs the base's frame 0, worst bone (m): the variant layer is zero at the seam
const SEAM_TOL: float = 0.002
## per-frame local rotation budget for every bone (idle loops)
const MAX_STEP_DEG: float = 15.0

var _root: Node3D = null
var _player: AnimationPlayer = null
var _skel: Skeleton3D = null


func before_all() -> void:
	var packed: PackedScene = load(GLB) as PackedScene
	if packed == null:
		return
	_root = packed.instantiate() as Node3D
	add_child(_root)
	_skel = _root.get_node_or_null("rig_humanoid/Skeleton3D") as Skeleton3D
	var found: Array[Node] = _root.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_player = found[0] as AnimationPlayer


func after_all() -> void:
	if _root != null:
		_root.queue_free()


func _pose(clip: String, f: int) -> Array:
	_player.play(StringName(clip))
	_player.seek(float(f) / 30.0, true)
	var pos: Array[Vector3] = []
	var rot: Array[Quaternion] = []
	for b: int in _skel.get_bone_count():
		pos.append((_skel.global_transform * _skel.get_bone_global_pose(b)).origin)
		rot.append(_skel.get_bone_pose_rotation(b))
	_player.stop()
	return [pos, rot]


static func _worst(a: Array, b: Array) -> float:
	var d: float = 0.0
	for i: int in mini(a.size(), b.size()):
		d = maxf(d, (a[i] as Vector3).distance_to(b[i] as Vector3))
	return d


func test_variants_present_seam_and_note() -> void:
	if _root == null or _player == null or _skel == null:
		fail("could not load %s (run godot --import first)" % GLB)
		return
	var src: String = FileAccess.get_file_as_string(SOURCE)
	assert_true(src.contains("idle_alert_variants:") and src.contains("VARIANT_GROUPS"), "SOURCE idle_alert_variants")
	assert_true(src.contains("idle_variants:"), "SOURCE idle_variants")
	for clip: String in CLIPS:
		var spec: Array = CLIPS[clip]
		var base: Array = _pose(String(spec[3]), 0)
		var a: Animation = _player.get_animation(StringName(clip)) if _player.has_animation(StringName(clip)) else null
		assert_true(a != null, "clip %s" % clip)
		if a == null:
			continue
		assert_near(a.length, float(spec[0]) / 30.0, 0.002, "%s length" % clip)
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)
		assert_true(src.contains("clip.%s: %df loop=True" % [clip, int(spec[0])]), "SOURCE clip.%s" % clip)
		assert_true(src.contains("%s@%d" % [spec[1], int(spec[2])]), "%s: event %s@%d" % [clip, spec[1], int(spec[2])])
		var d0: float = _worst(_pose(clip, 0)[0], base[0])
		assert_true(d0 < SEAM_TOL, "%s frame 0 == %s frame 0 (worst bone %.4f m)" % [clip, spec[3], d0])
		var dn: float = _worst(_pose(clip, int(spec[0]))[0], base[0])
		assert_true(dn < SEAM_TOL, "%s closes on %s frame 0 (worst bone %.4f m)" % [clip, spec[3], dn])


func test_variants_smooth_rooted_above_floor() -> void:
	if _root == null or _player == null or _skel == null:
		return
	var root_bone: int = _skel.find_bone("root")
	for clip: String in CLIPS:
		if not _player.has_animation(StringName(clip)):
			continue
		var n: int = int(CLIPS[clip][0])
		var prev: Array = _pose(clip, 0)
		var first_root: Vector3 = (prev[0] as Array)[root_bone] if root_bone >= 0 else Vector3.ZERO
		var worst: float = 0.0
		var lowest: float = 1.0
		var drift: float = 0.0
		for f: int in range(1, n + 1):
			var cur: Array = _pose(clip, f)
			for i: int in (cur[1] as Array).size():
				worst = maxf(worst, rad_to_deg(((prev[1] as Array)[i] as Quaternion).angle_to((cur[1] as Array)[i])))
			for p: Variant in cur[0]:
				lowest = minf(lowest, (p as Vector3).y)
			if root_bone >= 0:
				drift = maxf(drift, ((cur[0] as Array)[root_bone] as Vector3).distance_to(first_root))
			prev = cur
		assert_true(worst <= MAX_STEP_DEG, "%s: worst bone step %.1f deg <= %.0f" % [clip, worst, MAX_STEP_DEG])
		assert_true(lowest > -0.005, "%s: no joint below the floor (%f)" % [clip, lowest])
		assert_true(drift < 0.001, "%s: the root never moves (%f m)" % [clip, drift])
