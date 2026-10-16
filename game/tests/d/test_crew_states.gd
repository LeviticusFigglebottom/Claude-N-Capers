## D-116: third-person crew states in the "humanoid" library (char_anim_humanoid, tools/blender/characters/
## _anim_crew3p.py): the akimbo firing set, the downed actions and the cuffed crew. Companion of test_anims.gd (which
## counts these clips): each clip is present with its length, loop mode and events in SOURCE.txt; chained poses equal
## the clips they come from / go to (1 cm per bone); crew_cuffed closes; aim_akimbo holds both hands out level and
## side by side; crew_cuffed keeps the wrists together behind the back; no joint goes below the floor. Run after
## `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, looped, SOURCE events ("" = none), [clip, time] frame 0 equals, [clip, time] the last frame equals]
const CLIPS: Dictionary = {
	"aim_akimbo": [90, true, "", [], []],
	"fire_akimbo": [9, false, "shot@0", ["aim_akimbo", 0.0], ["aim_akimbo", 0.0]],
	"fire_akimbo_l": [9, false, "shot@0", ["aim_akimbo", 0.0], ["aim_akimbo", 0.0]],
	"reload_akimbo": [60, false, "done@46,mag_in@32,mag_out@8", ["aim_akimbo", 0.0], ["aim_akimbo", 0.0]],
	"downed_fire": [9, false, "shot@0", ["downed", 0.0], ["downed", 0.0]],
	"downed_reload": [45, false, "done@34,mag_in@28,mag_out@6", ["downed", 0.0], ["downed", 0.0]],
	"downed_getup": [40, false, "up@34", ["downed", 0.0], ["hold_pistol", 0.0]],
	"downed_arrested": [40, false, "disarm@6", ["downed", 0.0], ["crew_cuffed", 0.0]],
	"crew_cuffed": [120, true, "", [], []],
	"crew_cuffed_enter": [18, false, "", ["idle", 0.0], ["crew_cuffed", 0.0]],
	"crew_cuffed_free": [24, false, "free@8", ["crew_cuffed", 0.0], ["idle_alert", 0.0]],
}

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


## Every bone's position at time `t` of `clip`.
func _snapshot(clip: String, t: float) -> Array[Vector3]:
	_player.play(StringName(clip))
	_player.seek(t, true)
	var out: Array[Vector3] = []
	for b: int in range(_skel.get_bone_count()):
		out.append((_skel.global_transform * _skel.get_bone_global_pose(b)).origin)
	_player.stop()
	return out


func _bone(snap: Array[Vector3], bone: String) -> Vector3:
	return snap[_skel.find_bone(bone)]


static func _snap_dist(a: Array[Vector3], b: Array[Vector3]) -> float:
	var worst: float = 0.0
	for i: int in range(a.size()):
		worst = maxf(worst, a[i].distance_to(b[i]))
	return worst


func test_clips_present_with_source_rows() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var note: String = String(lines.get("crew_states", ""))
	assert_true(note.contains("aim_akimbo") and note.contains("downed_arrested") and note.contains("crew_cuffed"),
			"SOURCE crew_states names the clips")
	for clip: String in CLIPS:
		var spec: Array = CLIPS[clip]
		var a: Animation = _anim(clip)
		assert_true(a != null, "D-116 clip %s" % clip)
		if a == null:
			continue
		var n: int = int(spec[0])
		assert_near(a.length, float(n) / 30.0, 0.002, "%s length" % clip)
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR if bool(spec[1]) else Animation.LOOP_NONE, "%s loop mode" % clip)
		var row: String = String(lines.get("clip." + clip, ""))
		assert_true(row.begins_with(" %df " % n), "SOURCE clip.%s" % clip)
		if not String(spec[2]).is_empty():
			assert_true(row.contains("events=" + String(spec[2])), "SOURCE clip.%s events %s" % [clip, spec[2]])


func test_chain_poses() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		var spec: Array = CLIPS[clip]
		if _anim(clip) == null:
			continue
		if not (spec[3] as Array).is_empty():
			var d0: float = _snap_dist(_snapshot(clip, 0.0), _snapshot(String(spec[3][0]), float(spec[3][1])))
			assert_true(d0 < 0.01, "%s: starts on %s @%.2fs (%f m)" % [clip, spec[3][0], spec[3][1], d0])
		if not (spec[4] as Array).is_empty():
			var end_t: float = float(spec[0]) / 30.0
			var d1: float = _snap_dist(_snapshot(clip, end_t), _snapshot(String(spec[4][0]), float(spec[4][1])))
			assert_true(d1 < 0.01, "%s: ends on %s @%.2fs (%f m)" % [clip, spec[4][0], spec[4][1], d1])


func test_cuffed_loop_closes() -> void:
	if not _ready_or_fail() or _anim("crew_cuffed") == null:
		return
	var d: float = _snap_dist(_snapshot("crew_cuffed", 0.0), _snapshot("crew_cuffed", 4.0))
	assert_true(d < 0.002, "crew_cuffed: the loop closes (%f m)" % d)


## Both hands out in front at chest height, level with each other and side by side (one gun in each).
func test_aim_akimbo_hands_side_by_side() -> void:
	if not _ready_or_fail() or _anim("aim_akimbo") == null:
		return
	for t: float in [0.0, 1.0, 2.0]:
		var s: Array[Vector3] = _snapshot("aim_akimbo", t)
		var hl: Vector3 = _bone(s, "hand.L")
		var hr: Vector3 = _bone(s, "hand.R")
		var chest: Vector3 = _bone(s, "chest")
		var fwd: Vector3 = (_bone(s, "toe.L") + _bone(s, "toe.R")) * 0.5 - (_bone(s, "foot.L") + _bone(s, "foot.R")) * 0.5
		fwd.y = 0.0
		fwd = fwd.normalized()
		assert_true(absf(hl.y - hr.y) < 0.03, "aim_akimbo @%.1f: hands level (%f m)" % [t, hl.y - hr.y])
		assert_true(hl.y > chest.y, "aim_akimbo @%.1f: hands above the chest joint" % t)
		assert_true((hl - chest).dot(fwd) > 0.35 and (hr - chest).dot(fwd) > 0.35, "aim_akimbo @%.1f: arms out" % t)
		var gap: float = Vector2(hl.x - hr.x, hl.z - hr.z).length()
		assert_true(gap > 0.14 and gap < 0.40, "aim_akimbo @%.1f: hands side by side (%f m apart)" % [t, gap])


## The wrists stay together behind the hips through the loop.
func test_cuffed_wrists_behind_the_back() -> void:
	if not _ready_or_fail() or _anim("crew_cuffed") == null:
		return
	for f: int in range(0, 121, 20):
		var s: Array[Vector3] = _snapshot("crew_cuffed", float(f) / 30.0)
		var hl: Vector3 = _bone(s, "hand.L")
		var hr: Vector3 = _bone(s, "hand.R")
		var hips: Vector3 = _bone(s, "hips")
		var fwd: Vector3 = (_bone(s, "toe.L") + _bone(s, "toe.R")) * 0.5 - (_bone(s, "foot.L") + _bone(s, "foot.R")) * 0.5
		fwd.y = 0.0
		fwd = fwd.normalized()
		assert_true(hl.distance_to(hr) < 0.14, "crew_cuffed f%d: wrists together (%f m)" % [f, hl.distance_to(hr)])
		assert_true((hl - hips).dot(fwd) < -0.05 and (hr - hips).dot(fwd) < -0.05, "crew_cuffed f%d: behind" % f)


func test_no_joint_below_the_floor() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		if _anim(clip) == null:
			continue
		var n: int = int(CLIPS[clip][0])
		var lowest: float = 1.0
		for f: int in range(0, n + 1, 3):
			for p: Vector3 in _snapshot(clip, float(f) / 30.0):
				lowest = minf(lowest, p.y)
		assert_true(lowest > -0.01, "%s: no joint below the floor (%f)" % [clip, lowest])


## Back/Socket is the carried bag's pivot; SOURCE carried_bag publishes the per-size offsets of character_spec.gd.
func test_carried_bag_offsets_published() -> void:
	var Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
	var note: String = String(_source_lines().get("carried_bag", ""))
	assert_true(note.contains("Back/Socket") and note.contains("identity"), "SOURCE carried_bag")
	var offsets: Dictionary = Spec.BACK_BAG_OFFSETS
	for size: String in ["light", "medium", "heavy"]:
		var v: Vector3 = offsets[size]
		var text: String = "%s (%s, %s, %s)" % [size, str(snappedf(v.x, 0.001)), str(snappedf(v.y, 0.001)), str(snappedf(v.z, 0.001))]
		assert_true(note.contains(text), "SOURCE carried_bag lists %s" % text)
