## A1-05 / S3.2 (P1) + S3.3: a guard reaching "!" radios for guard_radio_call_s then raises the
## alarm; death or domination during the call cancels it.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0)})
	await wait_physics_frames(1)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _guard() -> NpcBase:
	return _rt.npcs(&"guard")[0] as NpcBase


func _brain() -> GuardBrain:
	return _guard().get_node("Brain") as GuardBrain


func test_s3_3_spotted_radios_then_alarm() -> void:
	var npc: NpcBase = _guard()
	var reasons: Array[StringName] = []
	var cb: Callable = func(r: StringName, _s: int) -> void: reasons.append(r)
	EventBus.alarm_raised.connect(cb)
	npc.notify_crew_spotted(_rt.crew_controller(0))
	await wait_physics_frames(1)
	assert_eq(_brain().state_name(), &"alarmed", "! -> ALARMED")
	assert_true(_brain().radio_time_left > 0.0, "radio call running")
	var call_s: float = Tweak.stealth().guard_radio_call_s
	await wait_seconds(call_s - 0.5)
	assert_true(reasons.is_empty(), "no alarm before the call finishes")
	await wait_seconds(0.8)
	EventBus.alarm_raised.disconnect(cb)
	assert_eq(reasons, [&"guard_radio"] as Array[StringName], "alarm raised by the radio call")
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD, "S11.2: heist went loud")
	assert_eq(_brain().state_name(), &"combat", "guard switches to combat")


func test_s3_3_killing_guard_mid_call_cancels_alarm() -> void:
	var npc: NpcBase = _guard()
	var brain: GuardBrain = _brain()
	npc.notify_crew_spotted(_rt.crew_controller(0))
	await wait_seconds(1.0)
	assert_eq(brain.state_name(), &"alarmed")
	npc.die()
	await wait_seconds(Tweak.stealth().guard_radio_call_s + 0.5)
	assert_false(_rt.stealth.alarm_raised, "dead guard never completes the call")
	assert_ne(_rt.phase, Enums.HeistPhase.LOUD, "still stealth")
	assert_near(brain.radio_time_left, 0.0, 0.0001, "call cancelled")
	assert_eq(brain.state_name(), &"dead")


func test_s3_3_domination_mid_call_cancels_alarm() -> void:
	var npc: NpcBase = _guard()
	var brain: GuardBrain = _brain()
	npc.notify_crew_spotted(_rt.crew_controller(0))
	await wait_seconds(0.8)
	npc.set_alert_state(Enums.AlertState.DOMINATED)
	await wait_seconds(Tweak.stealth().guard_radio_call_s + 0.5)
	assert_false(_rt.stealth.alarm_raised, "dominated guard never completes the call")
	assert_eq(brain.state_name(), &"dominated", "brain leaves non-brain states alone")
