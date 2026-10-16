## D-116: surrender variety in the "humanoid" library (char_anim_humanoid, tools/blender/characters/_anim_surrender.py).
## Companion of test_anims.gd (which counts these clips): every variant is present with its length and loop mode,
## SOURCE.txt lists the variant groups and the pick rule, chained poses equal the originals' (surrender_b/_c start on
## surrender frame 0 and end on its last frame, kneel_cuffed_b/_c start on kneel_cuffed frame 0, surrender_idle* start
## on surrender's last frame; 1 cm per bone), the loops close and have periods of their own, and each variant differs
## visibly from its original (some bone > 10 deg apart at some shared time). Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, looped, the group's original ("" = none), [clip, time] frame 0 equals, [clip, time] the last
## frame equals]
const VARIANTS: Dictionary = {
	"hands_up_b": [82, true, "hands_up", [], []], "hands_up_c": [98, true, "hands_up", [], []],
	"surrender_b": [54, false, "surrender", ["surrender", 0.0], ["surrender", 1.6]],
	"surrender_c": [42, false, "surrender", ["surrender", 0.0], ["surrender", 1.6]],
	"kneel_cuffed_b": [104, true, "kneel_cuffed", ["kneel_cuffed", 0.0], []],
	"kneel_cuffed_c": [118, true, "kneel_cuffed", ["kneel_cuffed", 0.0], []],
	"surrender_idle": [96, true, "", ["surrender", 1.6], []],
	"surrender_idle_b": [110, true, "surrender_idle", ["surrender", 1.6], []],
	"surrender_idle_c": [84, true, "surrender_idle", ["surrender", 1.6], []],
}
const GROUPS: Dictionary = {
	"hands_up": "hands_up, hands_up_b, hands_up_c", "surrender": "surrender, surrender_b, surrender_c",
	"kneel_cuffed": "kneel_cuffed, kneel_cuffed_b, kneel_cuffed_c",
	"surrender_idle": "surrender_idle, surrender_idle_b, surrender_idle_c",
}
## the originals' loop periods (frames): a variant loop must not share one
const ORIGINAL_PERIODS: Array[int] = [60, 90]

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


func test_variants_present_with_source_groups() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	for g: String in GROUPS:
		assert_eq(String(lines.get("variants." + g, "")).strip_edges(), GROUPS[g], "SOURCE variants.%s" % g)
	var rule: String = String(lines.get("surrender_variants", ""))
	assert_true(rule.contains("hash") and rule.contains("random offset"), "SOURCE surrender_variants: the pick rule")
	var periods: Array[int] = ORIGINAL_PERIODS.duplicate()
	for clip: String in VARIANTS:
		var spec: Array = VARIANTS[clip]
		var a: Animation = _anim(clip)
		assert_true(a != null, "D-116 clip %s" % clip)
		if a == null:
			continue
		var n: int = int(spec[0])
		assert_near(a.length, float(n) / 30.0, 0.002, "%s length" % clip)
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR if bool(spec[1]) else Animation.LOOP_NONE, "%s loop mode" % clip)
		assert_true(String(lines.get("clip." + clip, "")).begins_with(" %df " % n), "SOURCE clip.%s" % clip)
		if bool(spec[1]):
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


func test_chain_poses_match_the_originals() -> void:
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
		for f: int in range(0, n + 1, 3):
			for p: Vector3 in _snapshot(clip, float(f) / 30.0):
				lowest = minf(lowest, p.y)
		assert_true(lowest > -0.01, "%s: no joint below the floor (%f)" % [clip, lowest])
