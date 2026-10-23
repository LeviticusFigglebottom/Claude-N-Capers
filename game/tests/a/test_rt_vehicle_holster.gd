## RT shot review (LEAD, D 38b3a924 rt_cast_final/convoy_cab_escorts.png): a seated escort held his pistol on the wheel.
## A body in sit_vehicle / sit_vehicle_drive shows no third-person weapon; the vehicle_exit_l / _r dismount draws it
## again at its `foot_out` event (the door-side foot on the road). On a real cast rig; the exit half is skipped with a
## print when the rig lacks the clip.
extends TestCase

const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"idle\"\n"

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


func _npc() -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"police"
	npc.net_id = 97001
	npc.visual_scene = load(NpcVisuals.scene_path("patrol_officer")) as PackedScene
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
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


func test_seated_in_a_vehicle_holsters_and_the_dismount_draws_at_foot_out() -> void:
	var npc: NpcBase = _npc()
	await wait_frames(1)
	var d: AnimDriver = AnimDriver.of(npc)
	assert_true(d != null and d.player != null, "real rig animated")
	assert_true(d.weapon_shown(&"idle_alert"), "standing: the weapon shows")
	assert_false(d.weapon_shown(&"sit_vehicle"), "passenger seat: holstered")
	assert_false(d.weapon_shown(&"sit_vehicle_drive"), "driver: holstered (not on the wheel)")
	if not d.play_vehicle_exit(true):
		print("[rt holster] skip the dismount half: the rig has no vehicle_exit_l")
		return
	var foot_out: float = AnimTweak.clip_event_s(AnimDriver.VEHICLE_EXIT_L, &"foot_out", AnimDriver.VEHICLE_FOOT_OUT_S)
	assert_false(d.weapon_shown(AnimDriver.VEHICLE_EXIT_L), "climbing out: still holstered before foot_out")
	d._oneshot_left = maxf(d._oneshot_dur - (foot_out + 0.05) / maxf(d._oneshot_speed, 0.01), 0.0)
	assert_true(d.weapon_shown(AnimDriver.VEHICLE_EXIT_L), "drawn from foot_out (%.2f s)" % foot_out)
