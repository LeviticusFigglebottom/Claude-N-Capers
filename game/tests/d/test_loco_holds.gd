## D-116: the frame-locked weapon holds on the move in the "humanoid" library (tools/blender/characters/
## _anim_loco_holds.py, SOURCE `locomotion_holds`). Companion of test_anims.gd (which counts these clips):
## hold_<kind>_<gait> exists for every kind and gait, with its base clip's length and loop mode; the sprint carry keeps
## the sprint's own trunk (spine / chest equal frame by frame); the walking layers move with the steps (the chest's
## counter-twist and the weapon arm change over the cycle, unlike the standing hold_<kind>); loops close. Run after
## `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
const KINDS: Array[String] = ["rifle", "pistol", "smg", "sniper", "lmg", "akimbo"]
## layer gait -> base clip
const GAITS: Dictionary = {
	"walk": "walk", "run": "run", "sprint": "sprint", "crouch": "crouch_walk", "walk_start": "walk_start",
	"walk_stop": "walk_stop", "run_start": "run_start", "run_stop": "run_stop",
}

var _root: Node3D = null
var _player: AnimationPlayer = null


func before_all() -> void:
	var packed: PackedScene = load(GLB) as PackedScene
	if packed == null:
		return
	_root = packed.instantiate() as Node3D
	add_child(_root)
	var found: Array[Node] = _root.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_player = found[0] as AnimationPlayer


func after_all() -> void:
	if _root != null:
		_root.queue_free()


func _ready_or_fail() -> bool:
	if _root == null or _player == null:
		fail("could not load %s with an AnimationPlayer (run godot --import first)" % GLB)
		return false
	return true


func _anim(clip: String) -> Animation:
	return _player.get_animation(StringName(clip)) if _player.has_animation(StringName(clip)) else null


func _rot_track(a: Animation, bone: String) -> int:
	for t: int in range(a.get_track_count()):
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D \
				and String(a.track_get_path(t).get_concatenated_subnames()) == bone:
			return t
	return -1


func _rot(a: Animation, bone: String, time: float) -> Quaternion:
	var t: int = _rot_track(a, bone)
	return a.rotation_track_interpolate(t, time) if t >= 0 else Quaternion.IDENTITY


## Largest angle (deg) between `bone`'s rotation at any two of `n` samples over the clip.
func _spread(a: Animation, bone: String, n: int = 12) -> float:
	var qs: Array[Quaternion] = []
	for i: int in range(n):
		qs.append(_rot(a, bone, a.length * float(i) / float(n)))
	var worst: float = 0.0
	for i: int in range(n):
		for j: int in range(i + 1, n):
			worst = maxf(worst, rad_to_deg(qs[i].angle_to(qs[j])))
	return worst


func test_every_layer_matches_its_base_clip() -> void:
	if not _ready_or_fail():
		return
	for kind: String in KINDS:
		for gait: String in GAITS:
			var name: String = "hold_%s_%s" % [kind, gait]
			var a: Animation = _anim(name)
			var b: Animation = _anim(String(GAITS[gait]))
			assert_true(a != null, "%s present" % name)
			if a == null or b == null:
				continue
			assert_near(a.length, b.length, 0.001, "%s: the length of %s" % [name, GAITS[gait]])
			assert_eq(a.loop_mode, b.loop_mode, "%s: the loop mode of %s" % [name, GAITS[gait]])


func test_sprint_carry_keeps_the_sprint_trunk() -> void:
	if not _ready_or_fail():
		return
	var base: Animation = _anim("sprint")
	for kind: String in KINDS:
		var a: Animation = _anim("hold_%s_sprint" % kind)
		if a == null or base == null:
			continue
		for i: int in range(6):
			var time: float = a.length * float(i) / 6.0
			for bone: String in ["spine", "chest"]:
				var d: float = rad_to_deg(_rot(a, bone, time).angle_to(_rot(base, bone, time)))
				assert_true(d < 1.0, "hold_%s_sprint %s at %.2f s: the sprint's (%.2f deg off)" % [kind, bone, time, d])


## D-153 TAC ruling: the police rifle's port-arms run (hold_rifle_port_run) has the run's length and loop and keeps the
## plain run's upright trunk (no weapon-class hunch), unlike hold_rifle_run.
func test_port_run_keeps_the_run_trunk() -> void:
	if not _ready_or_fail():
		return
	var base: Animation = _anim("run")
	var a: Animation = _anim("hold_rifle_port_run")
	assert_true(a != null, "hold_rifle_port_run exists")
	if a == null or base == null:
		return
	assert_near(a.length, base.length, 0.001, "hold_rifle_port_run length == run")
	assert_eq(a.loop_mode, base.loop_mode, "hold_rifle_port_run loops like run")
	for i: int in range(6):
		var time: float = a.length * float(i) / 6.0
		for bone: String in ["spine", "chest"]:
			var d: float = rad_to_deg(_rot(a, bone, time).angle_to(_rot(base, bone, time)))
			assert_true(d < 1.0, "hold_rifle_port_run %s at %.2f s: the run's (%.2f deg off)" % [bone, time, d])


func test_walking_layers_move_with_the_steps() -> void:
	if not _ready_or_fail():
		return
	for kind: String in KINDS:
		for gait: String in ["walk", "run"]:
			var a: Animation = _anim("hold_%s_%s" % [kind, gait])
			if a == null:
				continue
			var chest: float = _spread(a, "chest")
			assert_true(chest > 3.0, "hold_%s_%s: the chest counter-twists with the steps (%.1f deg)" % [kind, gait, chest])
			var arm: float = _spread(a, "upper_arm.R")
			assert_true(arm > 1.5, "hold_%s_%s: the weapon arm moves with the steps (%.1f deg)" % [kind, gait, arm])


func test_loops_close() -> void:
	if not _ready_or_fail():
		return
	for kind: String in KINDS:
		for gait: String in ["walk", "run", "sprint", "crouch"]:
			var a: Animation = _anim("hold_%s_%s" % [kind, gait])
			if a == null:
				continue
			for bone: String in ["chest", "upper_arm.R", "forearm.R", "hand.R", "upper_arm.L", "hand.L"]:
				var d: float = rad_to_deg(_rot(a, bone, 0.0).angle_to(_rot(a, bone, a.length)))
				assert_true(d < 0.5, "hold_%s_%s %s closes (%.2f deg)" % [kind, gait, bone, d])


func test_source_notes() -> void:
	var f: FileAccess = FileAccess.open(SOURCE, FileAccess.READ)
	assert_true(f != null, "SOURCE.txt readable")
	if f == null:
		return
	var text: String = f.get_as_text()
	assert_true(text.contains("\nlocomotion_holds: "), "SOURCE locomotion_holds note")
	assert_true(text.contains("FRAME-LOCKED"), "the note says the layer is frame-locked to its base clip")
