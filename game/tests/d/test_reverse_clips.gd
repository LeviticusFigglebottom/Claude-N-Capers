## characters v1.27 locomotion reversals (tools/blender/characters/_anim_reverse.py, SOURCE `loco_reverse`): an aiming
## unit that kites flips run <-> run_b / walk <-> walk_back through a plant and push instead of a crossfade between
## opposite strides (which folds the knees, D-153 motion strips). Every clip is a one-shot whose frame 0 IS the source loop
## at u_in and last frame IS the target loop at u_out; the brake foot stays put while planted with the root moved along
## curve.<clip>; the root speed crosses 0 once; the hips stay within the stated drop of the loops' lowest; no joint jumps.
## Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, source loop, its hand-off frame, target loop, its hand-off frame, brake foot, push frame]
const CLIPS: Dictionary = {
	"run_reverse_l": [18, "run", 11, "run_b", 5, "L", 6],
	"run_reverse_r": [18, "run", 0, "run_b", 16, "R", 6],
	"run_reverse_back_l": [18, "run_b", 11, "run", 5, "L", 6],
	"run_reverse_back_r": [18, "run_b", 0, "run", 16, "R", 6],
	"walk_reverse_l": [24, "walk", 15, "walk_back", 7, "L", 11],
	"walk_reverse_r": [24, "walk", 0, "walk_back", 22, "R", 11],
	"walk_reverse_back_l": [24, "walk_back", 15, "walk", 7, "L", 11],
	"walk_reverse_back_r": [24, "walk_back", 0, "walk", 22, "R", 11],
}
## loop speeds (m/s, SOURCE clip rows)
const SPEED: Dictionary = {"run": 3.5, "run_b": 3.5, "walk": 1.6, "walk_back": 1.3}
const POSE_TOL: float = 0.01
## the planted brake foot's ball (toe bone head) may roll, never slide: mm per frame, horizontal (at 3.5 m/s a slide
## would be ~117 mm per frame)
const PLANT_TOL: float = 0.010
## per-frame local rotation budget (run_b's own loop steps 27.7 deg, stagger_rifle 37.4)
const MAX_STEP_DEG: float = 36.0
## slack on the stated hip drop (m)
const DROP_SLACK: float = 0.003

var _root: Node3D = null
var _player: AnimationPlayer = null
var _skel: Skeleton3D = null
var _lines: Dictionary = {}


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
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var i: int = line.find(":")
		if i > 0:
			_lines[line.substr(0, i)] = line.substr(i + 1)


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


func _pose(clip: String, f: int) -> Array[Vector3]:
	_player.play(StringName(clip))
	_player.seek(float(f) / 30.0, true)
	var out: Array[Vector3] = []
	for b: int in range(_skel.get_bone_count()):
		out.append(_skel.get_bone_global_pose(b).origin)
	_player.stop()
	return out


func _locals(clip: String, f: int) -> Array[Quaternion]:
	_player.play(StringName(clip))
	_player.seek(float(f) / 30.0, true)
	var out: Array[Quaternion] = []
	for b: int in range(_skel.get_bone_count()):
		out.append(_skel.get_bone_pose_rotation(b))
	_player.stop()
	return out


static func _worst(a: Array[Vector3], b: Array[Vector3]) -> float:
	var d: float = 0.0
	for i: int in range(mini(a.size(), b.size())):
		d = maxf(d, a[i].distance_to(b[i]))
	return d


## curve.<clip> root_m values (m along the character's forward, + = forward), or [] if missing.
func _curve(clip: String) -> PackedFloat32Array:
	var m: RegExMatch = RegEx.create_from_string("root_m=([-0-9.,]+) total_m=([-0-9.]+) dir_godot=\\(0,0,-1\\)").search(
		String(_lines.get("curve." + clip, "")))
	var out: PackedFloat32Array = PackedFloat32Array()
	if m != null:
		for v: String in m.get_string(1).split(","):
			out.append(v.to_float())
	return out


## A value from the loco_reverse note's row for `clip` (e.g. "brake_lifts" -> "10.1").
func _note(clip: String, key: String) -> String:
	var m: RegExMatch = RegEx.create_from_string(clip + ": [^|]*" + key + "[@=]([-+0-9.]+)").search(
		String(_lines.get("loco_reverse", "")))
	return m.get_string(1) if m != null else ""


func test_clips_are_one_shots_with_events() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		var row: Array = CLIPS[clip]
		var a: Animation = _anim(clip)
		assert_true(a != null, "%s exists" % clip)
		if a == null:
			continue
		assert_eq(a.loop_mode, Animation.LOOP_NONE, "%s is a one-shot" % clip)
		assert_near(a.length, float(row[0]) / 30.0, 0.002, "%s length" % clip)
		var src: String = String(_lines.get("clip." + clip, ""))
		assert_true(src.contains("events=done@%d,foot_plant@0,push@%d" % [row[0], row[6]]), "%s events: %s" % [clip, src])
		assert_true(src.contains("root_motion=curve.%s" % clip) or _lines.has("curve." + clip), "%s root curve" % clip)
		assert_true(_note(clip, "max_hip_drop_mm") != "", "%s row in SOURCE loco_reverse" % clip)


func test_frame_0_is_the_source_loop_and_the_last_the_target() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		var row: Array = CLIPS[clip]
		if _anim(clip) == null:
			continue
		var n: int = int(row[0])
		var d0: float = _worst(_pose(clip, 0), _pose(String(row[1]), int(row[2])))
		var d1: float = _worst(_pose(clip, n), _pose(String(row[3]), int(row[4])))
		assert_true(d0 < POSE_TOL, "%s frame 0 == %s frame %d (worst bone %.4f m)" % [clip, row[1], row[2], d0])
		assert_true(d1 < POSE_TOL, "%s last frame == %s frame %d (worst bone %.4f m)" % [clip, row[3], row[4], d1])
		assert_true(_note(clip, "u_in").to_float() > -0.5, "SOURCE u_in for %s" % clip)


## The root moves along the curve: from the source loop's speed, through 0 once (at `push`), to the target loop's
## speed the other way.
func test_root_curve_reverses_once() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		var row: Array = CLIPS[clip]
		var c: PackedFloat32Array = _curve(clip)
		assert_eq(c.size(), int(row[0]) + 1, "curve.%s: one value per frame" % clip)
		if c.size() < 4:
			continue
		assert_near(c[0], 0.0, 0.0005, "curve.%s starts at 0" % clip)
		var fwd: float = 1.0 if String(row[1]) in ["run", "walk"] else -1.0
		var v0: float = (c[1] - c[0]) * 30.0
		var v1: float = (c[c.size() - 1] - c[c.size() - 2]) * 30.0
		assert_true(v0 * fwd > 0.5 * SPEED[row[1]], "curve.%s leaves at the source speed (%.2f m/s)" % [clip, v0])
		assert_near(-v1 * fwd, SPEED[row[3]], 0.05 * SPEED[row[3]], "curve.%s ends at the target speed" % clip)
		var flips: int = 0
		var at: int = -1
		for i: int in range(2, c.size()):
			if signf(c[i] - c[i - 1]) != signf(c[i - 1] - c[i - 2]) and absf(c[i] - c[i - 1]) > 1e-5:
				flips += 1
				at = i - 1
		assert_eq(flips, 1, "curve.%s: the speed crosses 0 once" % clip)
		assert_true(absi(at - int(row[6])) <= 1, "curve.%s: it crosses at push (frame %d, event %d)" % [clip, at, row[6]])


## While the brake foot is planted (frame 0 to its lift), its ball stays put on the ground with the root moved along
## the curve (it rolls from the heel / onto the toes, it never slides).
func test_brake_foot_stays_planted() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		var row: Array = CLIPS[clip]
		var c: PackedFloat32Array = _curve(clip)
		var lift: float = _note(clip, "brake_lifts").to_float()
		if _anim(clip) == null or c.size() == 0 or lift <= 0.0:
			fail("%s: no curve / brake_lifts in SOURCE" % clip)
			continue
		var toe: int = _skel.find_bone("toe.%s" % row[5])
		var prev: Vector3 = Vector3.INF
		var worst: float = 0.0
		for f: int in range(0, int(floor(lift)) + 1):
			var p: Vector3 = _pose(clip, f)[toe] + Vector3(0.0, 0.0, -c[f])
			p.y = 0.0
			if prev != Vector3.INF:
				worst = maxf(worst, p.distance_to(prev))
			prev = p
		assert_true(worst < PLANT_TOL, "%s: the planted brake foot moves %.4f m per frame at most" % [clip, worst])


func test_hips_stay_up() -> void:
	if not _ready_or_fail():
		return
	var hips: int = _skel.find_bone("hips")
	var low: Dictionary = {}
	for loop: String in SPEED:
		var a: Animation = _anim(loop)
		if a == null:
			continue
		var m: float = INF
		for f: int in range(roundi(a.length * 30.0)):
			m = minf(m, _pose(loop, f)[hips].y)
		low[loop] = m
	for clip: String in CLIPS:
		var row: Array = CLIPS[clip]
		if _anim(clip) == null or not low.has(row[1]) or not low.has(row[3]):
			continue
		var floor_y: float = minf(low[row[1]], low[row[3]])
		var stated: float = _note(clip, "max_hip_drop_mm").to_float() / 1000.0
		var m: float = INF
		for f: int in range(int(row[0]) + 1):
			m = minf(m, _pose(clip, f)[hips].y)
		assert_true(floor_y - m <= stated + DROP_SLACK, "%s: hips %.3f m below the loops' lowest (stated %.3f)" % [clip,
			floor_y - m, stated])
		assert_true(stated <= 0.02, "%s: stated hip drop %.3f m (no squat)" % [clip, stated])


func test_no_joint_jumps() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		var row: Array = CLIPS[clip]
		if _anim(clip) == null:
			continue
		var prev: Array[Quaternion] = _locals(clip, 0)
		var worst: float = 0.0
		var at: String = ""
		for f: int in range(1, int(row[0]) + 1):
			var cur: Array[Quaternion] = _locals(clip, f)
			for b: int in range(cur.size()):
				var d: float = rad_to_deg(prev[b].angle_to(cur[b]))
				if d > worst:
					worst = d
					at = "%s f%d" % [_skel.get_bone_name(b), f]
			prev = cur
		assert_true(worst <= MAX_STEP_DEG, "%s: worst per-frame step %.1f deg (%s)" % [clip, worst, at])
