## RT-D1: Rolling Thunder clips in the "humanoid" library (char_anim_humanoid, tools/blender/characters/_anim_rt.py):
## sit_vehicle (a bucket seat), vehicle_exit_l / vehicle_exit_r (the dismount through the left / right door), sit_eat
## (a diner booth) and cook_stove (a griddle). Companion of test_anims.gd (which counts these clips). Every clip is
## present with its length, loop flag and events; the loops close with the root fixed; no joint goes below the floor;
## the exits start exactly on sit_vehicle frame 0 and end exactly on idle_alert frame 0 with their root motion curve in
## SOURCE.txt; the seats are at the documented heights. Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, loops, events]
const CLIPS: Dictionary = {
	"sit_vehicle": [180, true, {}],
	"vehicle_exit_l": [45, false, {"foot_out": 14, "step_r": 26, "step_l": 37}],
	"vehicle_exit_r": [45, false, {"foot_out": 14, "step_l": 26, "step_r": 37}],
}
## exit clip -> Godot x sign of its root travel
const EXITS: Dictionary = {"vehicle_exit_l": -1.0, "vehicle_exit_r": 1.0}
## the exits' total sideways root travel (m)
const EXIT_X: float = 0.85
## a one-shot's first / last frame must match its source pose within this (m, worst bone)
const POSE_TOL: float = 0.01
const NOTES: Array[String] = ["rt_vehicle_placement"]

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


## Every bone's position at frame `f` of `clip` (skeleton space, the root bone's origin = the clip's root).
func _snapshot(clip: String, f: int) -> Array[Vector3]:
	_player.play(StringName(clip))
	_player.seek(float(f) / 30.0, true)
	var out: Array[Vector3] = []
	for b: int in range(_skel.get_bone_count()):
		out.append((_skel.global_transform * _skel.get_bone_global_pose(b)).origin)
	_player.stop()
	return out


static func _worst(a: Array[Vector3], b: Array[Vector3]) -> float:
	var d: float = 0.0
	for i: int in range(mini(a.size(), b.size())):
		d = maxf(d, a[i].distance_to(b[i]))
	return d


func test_clips_present_with_events_and_notes() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	for n: String in NOTES:
		assert_true(String(lines.get(n, "")).length() > 40, "SOURCE %s" % n)
	for clip: String in CLIPS:
		var spec: Array = CLIPS[clip]
		var a: Animation = _anim(clip)
		assert_true(a != null, "RT-D1 clip %s" % clip)
		if a == null:
			continue
		var n: int = int(spec[0])
		var loops: bool = bool(spec[1])
		assert_near(a.length, float(n) / 30.0, 0.002, "%s length" % clip)
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE, "%s loop mode" % clip)
		var row: String = String(lines.get("clip." + clip, ""))
		assert_true(row.begins_with(" %df loop=%s speed_mps=0.0" % [n, "True" if loops else "False"]),
			"SOURCE clip.%s: %s" % [clip, row])
		var ev: Dictionary = spec[2]
		for e: String in ev:
			assert_true(row.contains("%s@%d" % [e, int(ev[e])]), "%s: event %s@%d" % [clip, e, int(ev[e])])
		if EXITS.has(clip):
			assert_true(row.contains("root_motion=curve." + clip), "SOURCE clip.%s: root_motion" % clip)


func test_no_joint_below_the_floor() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		if _anim(clip) == null:
			continue
		var lowest: float = 1.0
		for f: int in range(0, int(CLIPS[clip][0]) + 1, 3):
			for p: Vector3 in _snapshot(clip, f):
				lowest = minf(lowest, p.y)
		assert_true(lowest > -0.005, "%s: no joint below the floor (%f)" % [clip, lowest])


func test_loops_close_and_root_fixed() -> void:
	if not _ready_or_fail():
		return
	var root_bone: int = _skel.find_bone("root")
	for clip: String in CLIPS:
		if _anim(clip) == null or not bool(CLIPS[clip][1]):
			continue
		var n: int = int(CLIPS[clip][0])
		var first: Array[Vector3] = _snapshot(clip, 0)
		assert_true(_worst(first, _snapshot(clip, n)) < 0.002, "%s: the loop closes" % clip)
		var drift: float = 0.0
		for f: int in range(0, n + 1, 10):
			var snap: Array[Vector3] = _snapshot(clip, f)
			if root_bone >= 0:
				drift = maxf(drift, snap[root_bone].distance_to(first[root_bone]))
		assert_true(drift < 0.001, "%s: the root never moves (%f m)" % [clip, drift])


func test_vehicle_seat_height() -> void:
	if not _ready_or_fail() or _anim("sit_vehicle") == null:
		return
	var hips: int = _skel.find_bone("hips")
	for f: int in [0, 60, 120]:
		var hp: Vector3 = _snapshot("sit_vehicle", f)[hips]
		assert_true(hp.y > 0.40 and hp.y < 0.46, "sit_vehicle f%d: the hips joint 0.40-0.45 m up (%f)" % [f, hp.y])
		assert_true(absf(hp.x) < 0.05 and hp.z > 0.0 and hp.z < 0.15, "sit_vehicle f%d: over the seat (%s)" % [f, hp])
	# lower than sit_chair's seat
	if _anim("sit_chair") != null:
		assert_true(_snapshot("sit_chair", 0)[hips].y - _snapshot("sit_vehicle", 0)[hips].y > 0.08,
			"sit_vehicle sits lower than sit_chair")


## The exits start exactly on sit_vehicle frame 0 and end exactly on idle_alert frame 0 (the clip is in place: A moves
## the root by curve.<clip>, SOURCE.txt); the curve runs from 0 to EXIT_X sideways, out of the door's side.
func test_exits_start_seated_end_on_idle_alert() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var seated: Array[Vector3] = _snapshot("sit_vehicle", 0)
	var alert: Array[Vector3] = _snapshot("idle_alert", 0)
	var hips: int = _skel.find_bone("hips")
	var foot_l: int = _skel.find_bone("foot.L")
	var foot_r: int = _skel.find_bone("foot.R")
	for clip: String in EXITS:
		if _anim(clip) == null:
			continue
		var n: int = int(CLIPS[clip][0])
		var d0: float = _worst(_snapshot(clip, 0), seated)
		var d1: float = _worst(_snapshot(clip, n), alert)
		assert_true(d0 < POSE_TOL, "%s: frame 0 == sit_vehicle frame 0 (worst bone %f m)" % [clip, d0])
		assert_true(d1 < POSE_TOL, "%s: last frame == idle_alert frame 0 (worst bone %f m)" % [clip, d1])
		var curve: String = String(lines.get("curve." + clip, ""))
		var m: RegExMatch = RegEx.create_from_string("root_m=([-0-9.,]+) total_m=([0-9.]+) dir_godot=\\(([-0-9]+),0,0\\)").search(curve)
		assert_true(m != null, "SOURCE curve.%s: %s" % [clip, curve])
		if m == null:
			continue
		var vals: PackedStringArray = m.get_string(1).split(",")
		assert_eq(vals.size(), n + 1, "curve.%s: one value per frame" % clip)
		assert_near(vals[0].to_float(), 0.0, 0.0005, "curve.%s starts at 0" % clip)
		assert_near(m.get_string(2).to_float(), EXIT_X, 0.01, "curve.%s total" % clip)
		assert_eq(m.get_string(3).to_float(), float(EXITS[clip]), "curve.%s: out of the door's side" % clip)
		var prev: float = -1.0
		for v: String in vals:
			assert_true(v.to_float() >= prev - 0.0001, "curve.%s never runs back" % clip)
			prev = v.to_float()
		# with the root moved along the curve, the body leaves the seat toward the door: the hips end out of the door's
		# side, and the feet that land are world-still between their plant and the end (no skating on the road)
		var sx: float = float(EXITS[clip])
		var land: Dictionary = {"vehicle_exit_l": [foot_r, 26, foot_l, 37], "vehicle_exit_r": [foot_l, 26, foot_r, 37]}[clip]
		for pair: int in [0, 2]:
			var bone: int = int(land[pair])
			var f0: int = int(land[pair + 1]) + 1
			var a: Vector3 = _snapshot(clip, f0)[bone] + Vector3(sx * vals[f0].to_float(), 0.0, 0.0)
			var b: Vector3 = _snapshot(clip, n)[bone] + Vector3(sx * vals[n].to_float(), 0.0, 0.0)
			assert_true(a.distance_to(b) < 0.03, "%s: the landed foot stays planted (%f m)" % [clip, a.distance_to(b)])
		var h_end: Vector3 = _snapshot(clip, n)[hips] + Vector3(sx * vals[n].to_float(), 0.0, 0.0)
		assert_true(h_end.x * sx > 0.7, "%s: the body ends outside the door (%s)" % [clip, h_end])
