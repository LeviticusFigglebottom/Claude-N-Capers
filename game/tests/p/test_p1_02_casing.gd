## P1-02 casing audit (real input where a player acts). Phase order is recorded from HeistRuntime.phase_changed.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null
var _phases: Array = []


func _launch(ai: bool) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": ai})
	_phases = []
	_rt.phase_changed.connect(func(o: int, n: int) -> void: _phases.append("%s->%s" % [
		Enums.HeistPhase.keys()[o], Enums.HeistPhase.keys()[n]]))


func before_each() -> void:
	_inp = PInputDriver.new(self)


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## PI-11: alarm while casing with AI teammates present: exactly CASING -> LOUD.
func test_alarm_with_ai_crew_goes_straight_loud() -> void:
	await _launch(true)
	await wait_physics_frames(10)
	assert_eq(_rt.phase, Enums.HeistPhase.CASING, "still casing (%s)" % str(_phases))
	EventBus.alarm_raised.emit(&"test", 0)
	await wait_physics_frames(5)
	assert_eq(_phases, ["CASING->LOUD"], "phase order")


## PI-12: AI teammates do not mask up (and end casing for everyone) while the humans are casing.
func test_ai_crew_keeps_casing() -> void:
	await _launch(true)
	await wait_seconds(3.0)
	assert_eq(_rt.phase, Enums.HeistPhase.CASING, "casing after 3 s with AI crew (%s)" % str(_phases))
	for s: int in range(1, 4):
		var c: CrewController = _rt.crew_controller(s) as CrewController
		if c != null and c.is_ai:
			assert_false(c.masked and not c.stealth_hidden, "AI slot %d not masked while casing" % s)


## Voluntary mask-up by holding G: CASING -> STEALTH, then alarm: STEALTH -> LOUD.
func test_mask_up_then_alarm() -> void:
	await _launch(false)
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	EventBus.alarm_raised.emit(&"test", 0)
	await wait_physics_frames(3)
	assert_eq(_phases, ["CASING->STEALTH", "STEALTH->LOUD"], "phase order")


## PI-13: pressing crouch / sprint / jump while casing reports why nothing happened (HUD hint source).
func test_casing_blocked_actions_signal() -> void:
	await _launch(false)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var got: Array[StringName] = []
	c.casing_blocked.connect(func(a: StringName) -> void: got.append(a))
	await _inp.tap(&"crouch")
	await _inp.tap(&"jump")
	_inp.press(&"move_forward")
	await _inp.tap(&"sprint")
	_inp.release(&"move_forward")
	await wait_physics_frames(2)
	assert_has(got, &"crouch", "crouch blocked")
	assert_has(got, &"jump", "jump blocked")
	assert_has(got, &"sprint", "sprint blocked")
	assert_eq(got.size(), 3, "once per press, not per tick: %s" % str(got))
	assert_false(c.crouched, "not crouched")
