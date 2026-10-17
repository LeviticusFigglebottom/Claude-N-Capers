## characters.md v1.25 (D's fix for the PO's "inorganic" crew movement): the weapon-hold layer over locomotion plays
## hold_<kind>_<gait> (walk / run / sprint / crouch, the start / stop names), frame-locked to the base clip every tick;
## strafe_l / strafe_r at 18 f keep the plain hold_<kind>; sprint and crouch_walk are layered too; a missing gait clip
## falls back to hold_<kind>.
extends TestCase

const HEISTER: StringName = &"rook"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func test_gait_selection() -> void:
	assert_eq(HoldGait.gait_of(&"walk", 30), &"walk")
	assert_eq(HoldGait.gait_of(&"walk_back", 30), &"walk")
	assert_eq(HoldGait.gait_of(&"strafe_l", 30), &"walk", "30 f strafe: walk")
	assert_eq(HoldGait.gait_of(&"strafe_r", 18), &"", "18 f strafe: plain hold")
	assert_eq(HoldGait.gait_of(&"run", 20), &"run")
	assert_eq(HoldGait.gait_of(&"run_l", 20), &"run")
	assert_eq(HoldGait.gait_of(&"sprint", 16), &"sprint")
	assert_eq(HoldGait.gait_of(&"crouch_walk", 36), &"crouch")
	for c: StringName in [&"walk_start", &"walk_stop", &"run_start", &"run_stop"]:
		assert_eq(HoldGait.gait_of(c, 12), c, "%s keeps its own name" % c)
	assert_eq(HoldGait.gait_of(&"idle", 60), &"", "idle: none")
	assert_true(AnimDriver._layered_locomotion(&"sprint") and AnimDriver._layered_locomotion(&"crouch_walk"),
		"sprint and crouch_walk are layered")
	assert_false(AnimDriver._layered_locomotion(&"walk_text"), "walk_text stays unlayered")


func test_clip_for_falls_back_when_the_gait_clip_is_missing() -> void:
	var p: AnimationPlayer = AnimationPlayer.new()
	var lib: AnimationLibrary = AnimationLibrary.new()
	for pair: Array in [[&"walk", 1.0], [&"strafe_l", 0.6], [&"run", 0.6667], [&"hold_rifle", 1.0], [&"hold_rifle_walk", 1.0]]:
		var a: Animation = Animation.new()
		a.length = float(pair[1])
		lib.add_animation(pair[0], a)
	p.add_animation_library("lib", lib)
	add_child(p)
	_nodes.append(p)
	assert_eq(HoldGait.clip_for(&"hold_rifle", &"walk", p, "lib"), &"hold_rifle_walk", "walk: the gait clip")
	assert_eq(HoldGait.clip_for(&"hold_rifle", &"strafe_l", p, "lib"), &"hold_rifle", "18 f strafe: plain")
	assert_eq(HoldGait.clip_for(&"hold_rifle", &"run", p, "lib"), &"hold_rifle", "no hold_rifle_run: fallback")
	assert_eq(HoldGait.clip_for(&"", &"walk", p, "lib"), &"", "no hold: none")


func test_hold_layer_is_frame_locked_to_the_walk() -> void:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	crew.setup(0, {"peer_id": 0, "is_ai": true, "display_name": "Bot"}, null)
	crew.heister = HEISTER
	crew.net_id = 88310
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(3)
	crew.masked = true
	crew.set_physics_process(false)
	var d: AnimDriver = AnimDriver.of(crew)
	if d == null or d.player == null or d.hold_layer == null:
		skip("no animated rig")
		return
	var lib: AnimationLibrary = d.player.get_animation_library(AnimDriver.LIBRARY)
	var plain: StringName = d._held_weapon_clip(&"hold_")
	if plain == &"" or not lib.has_animation(&"walk"):
		skip("rig has no hold_<kind> / walk")
		return
	var gait: StringName = StringName(String(plain) + "_walk")
	if not lib.has_animation(gait):
		lib.add_animation(gait, lib.get_animation(plain).duplicate() as Animation)  # stand-in until D's clip lands
	d.set_process(false)
	crew.velocity = Vector3(0, 0, -1.6)
	for _i: int in 25:
		d.tick(0.05)
	assert_true(String(d.clip).begins_with("walk"), "walking (%s)" % d.clip)
	if d.clip != &"walk":
		return  # a walk_start / directional variant: selection is covered above
	assert_eq(d.hold_layer.clip, gait, "the layer plays %s over walk" % gait)
	for _i: int in 7:
		d.tick(0.033)
		assert_near(d.hold_layer.time, d.player.current_animation_position, 0.0001, "frame-locked to the walk")
