## PO-5 (D-086 playability): a CALM NPC that a crew member keeps walking into steps aside, then returns
## to its spot once the crew has gone (StealthTweak npc_yield_*). NPCs in any other alert state do not.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## Crew 0 at (0, 0, 1.2) walking -Z (yaw 0) straight into whatever stands at the origin.
func _press() -> void:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 1.2)))
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = 0.0
	i.move = Vector2(0, 1)
	_rt.set_bot_intent(0, i)


func _launch_with_civ() -> NpcBase:
	_rt = await HeistLauncher.launch(&"unit_map", 519, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), {"idle_activity": &"sit"})
	await wait_physics_frames(3)
	return civ


func test_po5_calm_civilian_steps_aside_then_returns() -> void:
	var civ: NpcBase = await _launch_with_civ()
	var m: NpcMotor = civ.get_node(^"Motor") as NpcMotor
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	_press()
	assert_true(await wait_until(func() -> bool: return m.yielding(), 4.0), "pressed civilian yields")
	assert_true(await wait_until(func() -> bool: return absf(civ.global_position.x) > 0.6, 3.0), "it steps aside")
	assert_eq(civ.alert_state, Enums.AlertState.CALM, "still calm")
	assert_eq(b.mode, CivilianBrain.Mode.IDLE, "brain untouched")
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return crew.global_position.z < -0.8, 3.0), "the crew gets past")
	_rt.set_bot_intent(0, CrewIntent.new())
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(-10, 0.05, 10)))
	assert_true(await wait_until(func() -> bool: return not m.yielding() and m.arrived, 6.0), "yield ends")
	assert_true(Vector2(civ.global_position.x, civ.global_position.z).length() < 0.6, "back on its spot")


func test_po5_alerted_npc_does_not_yield() -> void:
	var civ: NpcBase = await _launch_with_civ()
	var m: NpcMotor = civ.get_node(^"Motor") as NpcMotor
	civ.alert_state = Enums.AlertState.PANICKED  # brain left IDLE: only the motor's gate is under test
	_press()
	await wait_seconds(3.0)
	assert_false(m.yielding(), "only CALM NPCs yield")
	assert_true(Vector2(civ.global_position.x, civ.global_position.z).length() < 0.2, "it holds its ground")
