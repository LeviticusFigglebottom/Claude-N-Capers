## A1-06 / S3.1, S7.4, D-016: a fully alerted civilian runs to a phone, calls, raises the alarm;
## shouting during the call interrupts it.
extends TestCase

var _rt: HeistRuntime = null
var _alarms: Array[Array] = []
var _saved_chance: float = 0.5


func before_each() -> void:
	_saved_chance = Tweak.stealth().fleeing_shout_chance
	_alarms.clear()
	EventBus.alarm_raised.connect(_on_alarm)
	_rt = await HeistLauncher.launch(&"unit_map", 4242, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 1)})


func after_each() -> void:
	Tweak.stealth().fleeing_shout_chance = _saved_chance
	if EventBus.alarm_raised.is_connected(_on_alarm):
		EventBus.alarm_raised.disconnect(_on_alarm)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_alarm(reason: StringName, source: int) -> void:
	_alarms.append([reason, source])


func _civ() -> NpcBase:
	return _rt.npcs(&"civilian")[0] as NpcBase


func _brain(npc: NpcBase) -> CivilianBrain:
	return npc.get_node(^"Brain") as CivilianBrain


## Civilian at (0,0,0), phone marker 6 m north (-Z).
func _setup() -> NpcBase:
	var civ: NpcBase = _civ()
	civ.global_position = Vector3(0, 0.05, 0)
	var phone: Node3D = Node3D.new()
	phone.name = "TestPhone"
	_rt.dynamic_root.add_child(phone)
	phone.global_position = Vector3(0, 0.05, -6)
	CivilianTargets.add_call_point(phone, CivilianTargets.REASON_PHONE)
	(_rt.crew_controller(0) as CrewController).set_masked(true)  # S1.2: being spotted force-masks (PO-11: only masked shouts intimidate)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 15)))
	await wait_physics_frames(2)
	return civ


func _shout() -> void:
	var i: CrewIntent = CrewIntent.new()
	i.shout = true
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)


func test_s3_1_spotted_civilian_runs_to_phone_and_calls() -> void:
	var civ: NpcBase = await _setup()
	var b: CivilianBrain = _brain(civ)
	civ.notify_crew_spotted(_rt.crew_controller(0))
	assert_eq(civ.alert_state, Enums.AlertState.PANICKED, "panicked on crew_spotted")
	assert_eq(b.mode, CivilianBrain.Mode.RUN_TO_CALL, "running to the phone")
	assert_true(await wait_until(func() -> bool: return b.is_calling(), 5.0), "reached the phone and calls")
	assert_true(civ.global_position.distance_to(Vector3(0, 0.05, -6)) < 1.0, "at the phone (%s)" % civ.global_position)
	assert_true(_alarms.is_empty(), "no alarm while the call is in progress")
	assert_true(await wait_until(func() -> bool: return not _alarms.is_empty(), Tweak.stealth().civilian_call_s + 1.0),
		"alarm after the call")
	assert_eq(_alarms[0][0], &"civilian_call", "reason civilian_call")
	assert_eq(_alarms[0][1], civ.net_id, "source is the civilian")
	await wait_physics_frames(2)
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD, "heist went loud")


func test_s3_1_shout_interrupts_call() -> void:
	Tweak.stealth().fleeing_shout_chance = 1.0
	var civ: NpcBase = await _setup()
	var b: CivilianBrain = _brain(civ)
	civ.notify_crew_spotted(_rt.crew_controller(0))
	assert_true(await wait_until(func() -> bool: return b.is_calling(), 5.0), "calling")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -2)))
	await wait_physics_frames(2)
	await _shout()
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED, "shout puts the caller down")
	assert_false(b.is_calling(), "call interrupted")
	await wait_seconds(Tweak.stealth().civilian_call_s + 0.5)
	assert_true(_alarms.is_empty(), "no alarm")


func test_d_016_failed_roll_keeps_fleeing() -> void:
	Tweak.stealth().fleeing_shout_chance = 0.0
	var civ: NpcBase = await _setup()
	civ.notify_crew_spotted(_rt.crew_controller(0))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 2)))
	await wait_physics_frames(2)
	await _shout()
	assert_eq(civ.alert_state, Enums.AlertState.PANICKED, "roll failed: still panicked")


func test_s3_1_noise_and_corpse_stimulus_panic() -> void:
	var civ: NpcBase = await _setup()
	civ.notify_noise(Vector3(5, 0, 0), &"drill", 0)
	assert_eq(civ.alert_state, Enums.AlertState.CALM, "drill noise ignored")
	civ.notify_stimulus(99, &"corpse", Vector3(5, 0, 0))
	assert_eq(civ.alert_state, Enums.AlertState.PANICKED, "corpse -> panic")
