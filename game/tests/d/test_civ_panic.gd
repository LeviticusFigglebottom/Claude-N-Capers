## D-116: civilian panic variety in the "humanoid" library (char_anim_humanoid, tools/blender/characters/_anim_civ_panic.py).
## Companion of test_anims.gd (which counts these clips) and test_surrender_variants.gd (the same pick rule): every clip is
## present with its length, loop mode and frame budget, SOURCE.txt lists the variant groups and the pick / chain rule,
## the loops close, cower_b/_c have periods of their own, flee_b/_c are the flee gait (same frames, speed, no foot slide
## in the source, the legs equal flee's frame for frame), panic_start starts on idle frame 0 and ends on cower frame 0
## (1 cm per bone), and each variant differs visibly from its original. Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, looped, the group's original ("" = none), [clip, time] frame 0 equals, [clip, time] the last
## frame equals, frame budget]
const VARIANTS: Dictionary = {
	"cower_b": [52, true, "cower", [], [], 60], "cower_c": [46, true, "cower", [], [], 60],
	"flee_b": [20, true, "flee", [], [], 20], "flee_c": [20, true, "flee", [], [], 20],
	"panic_start": [24, false, "", ["idle", 0.0], ["cower", 0.0], 30],
}
const GROUPS: Dictionary = {"cower": "cower, cower_b, cower_c", "flee": "flee, flee_b, flee_c"}
const FLEE_SPEED: String = "speed_mps=4.0"
const FLEE_VARIANTS: Array[String] = ["flee_b", "flee_c"]
const LEG_BONES: Array[String] = ["hips", "thigh.L", "shin.L", "foot.L", "toe.L", "thigh.R", "shin.R", "foot.R", "toe.R"]
## the original cower's loop period (frames): a variant loop must not share it
const ORIGINAL_PERIODS: Array[int] = [60]

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


func _ready_or_fail() -> bool:
	if _root == null or _player == null or _skel == null:
		fail("could not load %s with rig_humanoid/Skeleton3D and an AnimationPlayer (run godot --import first)" % GLB)
		return false
	return true


func _anim(clip: String) -> Animation:
	return _player.get_animation(StringName(clip)) if _player.has_animation(StringName(clip)) else null


func _source_lines() -> Dictionary:
	var lines: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var i: int = line.find(":")
		if i > 0:
			lines[line.substr(0, i)] = line.substr(i + 1)
	return lines


func _check_rows() -> Dictionary:
	var out: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var m: RegExMatch = RegEx.create_from_string("^check\\.\\d+: (\\w+): (.*)$").search(line)
		if m != null:
			out[m.get_string(1)] = m.get_string(2)
	return out


static func _num(row: String, key: String) -> float:
	var m: RegExMatch = RegEx.create_from_string(key + "=(-?[0-9.]+)").search(row)
	return m.get_string(1).to_float() if m != null else INF


func _seek(clip: String, t: float) -> void:
	_player.play(StringName(clip))
	_player.seek(t, true)


## Every bone's position at time `t` of `clip`.
func _snapshot(clip: String, t: float) -> Array[Vector3]:
	_seek(clip, t)
	var out: Array[Vector3] = []
	for b: int in range(_skel.get_bone_count()):
		out.append((_skel.global_transform * _skel.get_bone_global_pose(b)).origin)
	_player.stop()
	return out


## Every bone's global rotation at time `t` of `clip`.
func _rot_snapshot(clip: String, t: float) -> Array[Quaternion]:
	_seek(clip, t)
	var out: Array[Quaternion] = []
	for b: int in range(_skel.get_bone_count()):
		out.append(_skel.get_bone_global_pose(b).basis.get_rotation_quaternion())
	_player.stop()
	return out


static func _snap_dist(a: Array[Vector3], b: Array[Vector3]) -> float:
	var worst: float = 0.0
	for i: int in range(a.size()):
		worst = maxf(worst, a[i].distance_to(b[i]))
	return worst


static func _rot_dist_deg(a: Array[Quaternion], b: Array[Quaternion]) -> float:
	var worst: float = 0.0
	for i: int in range(a.size()):
		worst = maxf(worst, rad_to_deg(2.0 * acos(minf(1.0, absf(a[i].dot(b[i]))))))
	return worst


func test_clips_present_with_source_groups() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	for g: String in GROUPS:
		assert_eq(String(lines.get("variants." + g, "")).strip_edges(), GROUPS[g], "SOURCE variants.%s" % g)
	var rule: String = String(lines.get("civ_panic_variants", ""))
	assert_true(rule.contains("hash") and rule.contains("random offset"), "SOURCE civ_panic_variants: the pick rule")
	assert_true(rule.contains("ENDS EXACTLY ON cower FRAME 0"), "SOURCE civ_panic_variants: the panic_start end pose")
	assert_true(String(lines.get("clip.panic_start", "")).contains("events=flinch@2"), "panic_start: flinch event")
	var periods: Array[int] = ORIGINAL_PERIODS.duplicate()
	for clip: String in VARIANTS:
		var spec: Array = VARIANTS[clip]
		var a: Animation = _anim(clip)
		assert_true(a != null, "D-116 clip %s" % clip)
		if a == null:
			continue
		var n: int = int(spec[0])
		assert_true(n <= int(spec[5]), "%s: %d f within its %d f budget" % [clip, n, spec[5]])
		assert_near(a.length, float(n) / 30.0, 0.002, "%s length" % clip)
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR if bool(spec[1]) else Animation.LOOP_NONE, "%s loop mode" % clip)
		assert_true(String(lines.get("clip." + clip, "")).begins_with(" %df " % n), "SOURCE clip.%s" % clip)
		if bool(spec[1]) and String(spec[2]) == "cower":
			assert_false(periods.has(n), "%s: a loop period of its own (%d f)" % [clip, n])
			periods.append(n)


func test_loops_close() -> void:
	if not _ready_or_fail():
		return
	for clip: String in VARIANTS:
		var spec: Array = VARIANTS[clip]
		if not bool(spec[1]) or _anim(clip) == null:
			continue
		var d: float = _snap_dist(_snapshot(clip, 0.0), _snapshot(clip, float(spec[0]) / 30.0))
		assert_true(d < 0.002, "%s: the loop closes (%f m)" % [clip, d])
		var a: Animation = _anim(clip)
		for t: int in range(a.get_track_count()):
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or a.track_get_key_count(t) < 2:
				continue
			var q0: Quaternion = a.track_get_key_value(t, 0)
			var q1: Quaternion = a.track_get_key_value(t, a.track_get_key_count(t) - 1)
			assert_true(absf(q0.dot(q1)) > 0.9999, "%s: %s first == last" % [clip, a.track_get_path(t)])


## flee_b / flee_c are the flee gait: the same length and speed, planted feet in the source, the legs and hips equal
## flee's at every sampled time (so A's speed_scale and foot sync work unchanged).
func test_flee_variants_share_the_gait() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var checks: Dictionary = _check_rows()
	var flee: Animation = _anim("flee")
	assert_true(flee != null and String(lines.get("clip.flee", "")).contains(FLEE_SPEED), "flee at 4.0 m/s")
	if flee == null:
		return
	for clip: String in FLEE_VARIANTS:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		assert_near(a.length, flee.length, 0.0005, "%s: the same length as flee" % clip)
		assert_true(String(lines.get("clip." + clip, "")).contains(FLEE_SPEED), "%s: %s" % [clip, FLEE_SPEED])
		var row: String = String(checks.get(clip, ""))
		assert_true(_num(row, "slide") < 0.1, "%s: no foot slide in the source (%s)" % [clip, row])
		assert_true(_num(row, "legs_err_vs_flee") < 0.1, "%s: the legs equal flee's in the source (%s)" % [clip, row])
		var worst: float = 0.0
		for i: int in range(0, 20, 2):
			var t: float = float(i) / 30.0
			var va: Array[Vector3] = _snapshot(clip, t)
			var vb: Array[Vector3] = _snapshot("flee", t)
			for bn: String in LEG_BONES:
				var bi: int = _skel.find_bone(bn)
				if bi >= 0:
					worst = maxf(worst, va[bi].distance_to(vb[bi]))
		assert_true(worst < 0.01, "%s: legs and hips follow flee frame for frame (%f m)" % [clip, worst])


func test_chain_poses() -> void:
	if not _ready_or_fail():
		return
	for clip: String in VARIANTS:
		var spec: Array = VARIANTS[clip]
		if _anim(clip) == null:
			continue
		if not (spec[3] as Array).is_empty():
			var d0: float = _snap_dist(_snapshot(clip, 0.0), _snapshot(String(spec[3][0]), float(spec[3][1])))
			assert_true(d0 < 0.01, "%s: starts on %s @%.2fs (%f m)" % [clip, spec[3][0], spec[3][1], d0])
		if not (spec[4] as Array).is_empty():
			var end_t: float = float(spec[0]) / 30.0
			var d1: float = _snap_dist(_snapshot(clip, end_t), _snapshot(String(spec[4][0]), float(spec[4][1])))
			assert_true(d1 < 0.01, "%s: ends on %s @%.2fs (%f m)" % [clip, spec[4][0], spec[4][1], d1])


func test_variants_differ_from_the_originals() -> void:
	if not _ready_or_fail():
		return
	for clip: String in VARIANTS:
		var spec: Array = VARIANTS[clip]
		var orig: String = String(spec[2])
		if orig.is_empty() or _anim(clip) == null or _anim(orig) == null:
			continue
		var span: float = minf(float(spec[0]) / 30.0, _anim(orig).length)
		var diff: float = 0.0
		for i: int in range(1, 8):
			var t: float = span * float(i) / 8.0
			diff = maxf(diff, _rot_dist_deg(_rot_snapshot(clip, t), _rot_snapshot(orig, t)))
		assert_true(diff > 10.0, "%s differs visibly from %s (max bone %f deg)" % [clip, orig, diff])


func test_no_joint_below_the_floor() -> void:
	if not _ready_or_fail():
		return
	for clip: String in VARIANTS:
		if _anim(clip) == null:
			continue
		var n: int = int(VARIANTS[clip][0])
		var lowest: float = 1.0
		for f: int in range(0, n + 1, 2):
			for p: Vector3 in _snapshot(clip, float(f) / 30.0):
				lowest = minf(lowest, p.y)
		assert_true(lowest > -0.01, "%s: no joint below the floor (%f)" % [clip, lowest])
