## D-116 organic pass, item 2: police combat movement in the "humanoid" library (tools/blender/characters/
## _anim_police.py, SOURCE `police_combat`; the aim-on-the-move layers come from _anim_loco_holds.py, SOURCE
## `locomotion_holds`). Companion of test_anims.gd (which counts these clips): each clip is present with its length,
## loop mode and SOURCE events; the per-class reloads start and end on aim_rifle frame 0 and the staggers on
## aim_<fam> frame 0 (1 cm per bone); the cover loops close; the cover peeks lean out to their own side; the
## aim_<fam>_<gait> layers match their base clip's length and loop mode. Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, looped, SOURCE events ("" = none), [clip, time] frame 0 equals, [clip, time] the last frame equals]
const CLIPS: Dictionary = {
	"reload_smg": [54, false, "done@44,mag_in@36,mag_out@10", ["aim_rifle", 0.0], ["aim_rifle", 0.0]],
	"reload_shotgun": [84, false, "done@74,shell@14", ["aim_rifle", 0.0], ["aim_rifle", 0.0]],
	"reload_lmg": [120, false, "cover_close@92,cover_open@16,done@106,mag_in@72,mag_out@34", ["aim_rifle", 0.0],
		["aim_rifle", 0.0]],
	"reload_sniper": [78, false, "bolt@56,done@66,mag_in@42,mag_out@12", ["aim_rifle", 0.0], ["aim_rifle", 0.0]],
	"cover_peek_l_rifle": [150, true, "", [], []],
	"cover_peek_l_pistol": [150, true, "", [], []],
	"cover_peek_r_rifle": [150, true, "", [], []],
	"cover_peek_r_pistol": [150, true, "", [], []],
	"cover_low_rifle": [150, true, "", [], []],
	"cover_low_pistol": [150, true, "", [], []],
	"stagger_rifle": [36, false, "impact@2", ["aim_rifle", 0.0], ["aim_rifle", 0.0]],
	"stagger_pistol": [36, false, "impact@2", ["aim_pistol", 0.0], ["aim_pistol", 0.0]],
}
## aim on the move: layer gait -> base clip
const AIM_FAMILIES: Array[String] = ["rifle", "pistol", "akimbo"]
const AIM_GAITS: Dictionary = {"walk": "walk", "run": "run", "crouch": "crouch_walk"}

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
	var note: String = String(lines.get("police_combat", ""))
	assert_true(note.contains("reload_lmg") and note.contains("cover_peek_l_<fam>") and note.contains("stagger_<fam>"),
			"SOURCE police_combat names the clips")
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


func test_cover_loops_close_and_lean_to_their_side() -> void:
	if not _ready_or_fail():
		return
	for clip: String in CLIPS:
		if not clip.begins_with("cover_") or _anim(clip) == null:
			continue
		var d: float = _snap_dist(_snapshot(clip, 0.0), _snapshot(clip, 5.0))
		assert_true(d < 0.002, "%s: the loop closes (%f m)" % [clip, d])
		if clip.begins_with("cover_low"):
			# risen at 2.7 s (aimed over the cover) vs crouched at 0 s
			var rise: float = _bone(_snapshot(clip, 2.7), "head").y - _bone(_snapshot(clip, 0.0), "head").y
			assert_true(rise > 0.12, "%s: rises to aim over the cover (%.3f m)" % [clip, rise])
			continue
		# leaned out at 2.7 s: the head moves out to the clip's side (the rig faces -Z: +X is the body's right)
		var dx: float = _bone(_snapshot(clip, 2.7), "head").x - _bone(_snapshot(clip, 0.0), "head").x
		var out: float = -1.0 if clip.begins_with("cover_peek_l") else 1.0
		assert_true(dx * out > 0.06, "%s: leans out to its own side (head dx %.3f m)" % [clip, dx])


func test_aim_layers_match_their_base_clips() -> void:
	if not _ready_or_fail():
		return
	for fam: String in AIM_FAMILIES:
		for gait: String in AIM_GAITS:
			var name: String = "aim_%s_%s" % [fam, gait]
			var a: Animation = _anim(name)
			var b: Animation = _anim(String(AIM_GAITS[gait]))
			assert_true(a != null, "%s present" % name)
			if a == null or b == null:
				continue
			assert_near(a.length, b.length, 0.001, "%s: the length of %s" % [name, AIM_GAITS[gait]])
			assert_eq(a.loop_mode, b.loop_mode, "%s: the loop mode of %s" % [name, AIM_GAITS[gait]])
