## AH-D1: Afterhours clips in the "humanoid" library (char_anim_humanoid, tools/blender/characters/_anim_ah.py): dj_mix
## (QC-74, the DJ at the 1.0 m booth). Companion of test_anims.gd (which counts this clip). The clip is present with its
## length, loop flag and event; the loop closes with the root fixed; no joint goes below the floor; the hands work the
## decks at the booth height and the right hand is on the headphone cup at `cue`. Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, loops, events]
const CLIPS: Dictionary = {
	"dj_mix": [240, true, {"cue": 90}],
}
const NOTES: Array[String] = ["ah_dj_placement"]
## _anim_ah DECK_Z: the deck top above the root plane; the wrists ride at most this far above it (the fingertips and
## the heel of the hand are on the top, the hand pitched down over the faders / the platter: the wrist ~0.13-0.15 m up)
const DECK_Z: float = 1.00
const WRIST_ABOVE: float = 0.17
## frames with both hands on the decks, and frames inside the cue hold (3.0-4.2 s)
const DECK_FRAMES: Array[int] = [0, 30, 150, 180, 210]
const CUE_FRAMES: Array[int] = [95, 110, 120]
## the right wrist at the headphone cup: this close to the head bone, on the right (Godot +x)
const CUP_TOL: float = 0.20

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


func _snapshot(clip: String, f: int) -> Array[Vector3]:
	_player.play(StringName(clip))
	_player.seek(float(f) / 30.0, true)
	var out: Array[Vector3] = []
	for b: int in range(_skel.get_bone_count()):
		out.append((_skel.global_transform * _skel.get_bone_global_pose(b)).origin)
	_player.stop()
	return out


func test_clips_present_with_events_and_notes() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	for n: String in NOTES:
		assert_true(String(lines.get(n, "")).length() > 40, "SOURCE %s" % n)
	for clip: String in CLIPS:
		var spec: Array = CLIPS[clip]
		var a: Animation = _anim(clip)
		assert_true(a != null, "AH-D1 clip %s" % clip)
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


func test_loops_close_root_fixed_above_the_floor() -> void:
	if not _ready_or_fail():
		return
	var root_bone: int = _skel.find_bone("root")
	for clip: String in CLIPS:
		if _anim(clip) == null:
			continue
		var n: int = int(CLIPS[clip][0])
		var first: Array[Vector3] = _snapshot(clip, 0)
		var last: Array[Vector3] = _snapshot(clip, n)
		var worst: float = 0.0
		for i: int in range(first.size()):
			worst = maxf(worst, first[i].distance_to(last[i]))
		assert_true(worst < 0.002, "%s: the loop closes (%f m)" % [clip, worst])
		var drift: float = 0.0
		var lowest: float = 1.0
		for f: int in range(0, n + 1, 6):
			var snap: Array[Vector3] = _snapshot(clip, f)
			if root_bone >= 0:
				drift = maxf(drift, snap[root_bone].distance_to(first[root_bone]))
			for p: Vector3 in snap:
				lowest = minf(lowest, p.y)
		assert_true(drift < 0.001, "%s: the root never moves (%f m)" % [clip, drift])
		assert_true(lowest > -0.005, "%s: no joint below the floor (%f)" % [clip, lowest])


## Both wrists ride just above the deck top ahead of the body (left on the mixer, right on the right jog wheel); in the
## cue hold the right wrist is up at the right side of the head.
func test_hands_on_the_decks_and_the_cue() -> void:
	if not _ready_or_fail() or _anim("dj_mix") == null:
		fail("dj_mix missing")
		return
	var hl: int = _skel.find_bone("hand.L")
	var hr: int = _skel.find_bone("hand.R")
	var head: int = _skel.find_bone("head")
	for f: int in DECK_FRAMES:
		var snap: Array[Vector3] = _snapshot("dj_mix", f)
		for b: int in [hl, hr]:
			var w: Vector3 = snap[b]
			assert_true(w.y > DECK_Z and w.y < DECK_Z + WRIST_ABOVE, "dj_mix f%d: wrist %s at the deck top" % [f, w])
			assert_true(w.z < -0.25, "dj_mix f%d: wrist %s ahead, over the booth" % [f, w])
		assert_true(snap[hl].x < snap[hr].x, "dj_mix f%d: left hand on the mixer, right on the right deck" % f)
	for f: int in CUE_FRAMES:
		var snap: Array[Vector3] = _snapshot("dj_mix", f)
		var d: float = snap[hr].distance_to(snap[head])
		assert_true(d < CUP_TOL and snap[hr].x > snap[head].x, "dj_mix f%d: right wrist %s at the cup (head %s, %f m)"
			% [f, snap[hr], snap[head], d])
