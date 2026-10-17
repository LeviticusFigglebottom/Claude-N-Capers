## RT-D1 follow-up (Rolling Thunder clips announced by ENV D, not in the library yet): sit_vehicle (seated in a car /
## cab, falls back to sit_chair), sit_eat (a diner booth, falls back to sit_chair), cook_stove (the diner cook, falls
## back to idle) map from their ambient hints; vehicle_exit_l / _r are one-shots played only when the rig has them
## (no fallback). Code rig = test_anim_driver's (none of the new clips): every fallback; a rig with the clips: each.
extends TestCase

const AD: Script = preload("res://tests/a/test_anim_driver.gd")
const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"idle\"\n"
const RT_CLIPS: Array[StringName] = [&"sit_vehicle", &"sit_eat", &"cook_stove"]

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(1)


func _npc(extra_looped: Array[StringName], extra_once: Array[StringName] = []) -> NpcBase:
	var rig: Node3D = AD._test_rig()
	var lib: AnimationLibrary = (rig.get_node(^"AnimationPlayer") as AnimationPlayer).get_animation_library(
		AnimDriver.LIBRARY)
	for c: StringName in extra_looped + extra_once:
		var a: Animation = Animation.new()
		a.length = 1.5 if extra_once.has(c) else 1.0
		a.loop_mode = Animation.LOOP_NONE if extra_once.has(c) else Animation.LOOP_LINEAR
		lib.add_animation(c, a)
	var npc: NpcBase = NpcBase.new()
	npc.role = &"civilian"
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	visual.add_child(rig)
	npc.add_child(visual)
	var gs: GDScript = GDScript.new()
	gs.source_code = HINT_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	npc.add_child(brain)
	add_child(npc)
	_nodes.append(npc)
	return npc


func _play(npc: NpcBase, h: StringName) -> String:
	npc.get_node(^"Brain").set(&"anim_hint", h)
	var d: AnimDriver = AnimDriver.of(npc)
	d.tick(0.016)
	return String(d.player.current_animation)


func test_rt_hint_mapping() -> void:
	for pair: Array in [[&"sit_vehicle", &"sit_vehicle"], [&"vehicle", &"sit_vehicle"], [&"sit_eat", &"sit_eat"],
			[&"eat", &"sit_eat"], [&"cook_stove", &"cook_stove"], [&"cook", &"cook_stove"]]:
		assert_eq(AnimDriver.HINT_CLIPS[pair[0]], pair[1], "%s -> %s" % pair)
	assert_true(AnimDriver.SEATED_CLIPS.has(&"sit_eat") and AnimDriver.SEATED_CLIPS.has(&"sit_vehicle"),
		"seated deaths in a booth / a car")
	assert_true(CivilianBrain.KNOWN_ACTIVITIES.has(&"sit_eat") and CivilianBrain.KNOWN_ACTIVITIES.has(&"cook"),
		"diner activities")
	assert_true(CivilianBrain.SEATED_ACTIVITIES.has(&"sit_eat"), "a diner in the booth cowers seated")
	assert_eq(Tweak.stealth().civilian_unseated_activity.get(&"sit_eat", &""), &"idle", "no booth seat: stands")
	var n: NpcBase = _npc(RT_CLIPS)
	for c: StringName in RT_CLIPS:
		assert_eq(_play(n, c), "humanoid/%s" % c, "%s plays when the rig has it" % c)


func test_rt_fallbacks_when_absent() -> void:
	var n: NpcBase = _npc([])
	assert_eq(_play(n, &"vehicle"), "humanoid/sit_chair", "no sit_vehicle: sit_chair")
	assert_eq(_play(n, &"eat"), "humanoid/sit_chair", "no sit_eat: sit_chair")
	assert_eq(_play(n, &"cook"), "humanoid/idle", "no cook_stove: idle")


func test_rt_vehicle_exit_plays_only_when_present() -> void:
	var bare: NpcBase = _npc([])
	var bd: AnimDriver = AnimDriver.of(bare)
	bd.tick(0.016)
	assert_false(bd.play_vehicle_exit(true), "no vehicle_exit_l: nothing plays")
	bd.tick(0.016)
	assert_eq(bd.clip, &"idle", "and the body stays on its clip")
	var full: NpcBase = _npc([], [AnimDriver.VEHICLE_EXIT_L, AnimDriver.VEHICLE_EXIT_R])
	var d: AnimDriver = AnimDriver.of(full)
	d.tick(0.016)
	assert_true(d.play_vehicle_exit(false), "vehicle_exit_r present: played")
	d.tick(0.016)
	assert_eq(d.clip, AnimDriver.VEHICLE_EXIT_R, "the right-door dismount plays")
	assert_true(d.play_vehicle_exit(true), "vehicle_exit_l present: played")
	d.tick(0.016)
	assert_eq(d.clip, AnimDriver.VEHICLE_EXIT_L, "the left-door dismount plays")
