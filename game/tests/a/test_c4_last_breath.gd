## C4 Last Breath (PD2 One Down; B's launch option "last_breath"): one down before custody instead of
## downs_before_custody, two with Nine Lives aced (defense.downs_extra), at any difficulty; the counter resets through
## a doctor bag or a custody release only.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(last_breath: bool, difficulty: Enums.Difficulty = Enums.Difficulty.ROUTINE) -> CrewHealth:
	var o: Dictionary = {"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1}
	if last_breath:
		o[CrewHealth.LAST_BREATH_OPTION] = true
	_rt = await HeistLauncher.launch(&"unit_map", 1404, difficulty, self, o)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	return (_rt.crew_controller(0) as CrewController).health


func test_off_keeps_the_tweak_limit() -> void:
	var h: CrewHealth = await _launch(false)
	assert_eq(h.max_downs(), Tweak.crew().downs_before_custody, "no option: downs_before_custody")


func test_one_down_then_custody_at_any_difficulty() -> void:
	for d: Enums.Difficulty in [Enums.Difficulty.ROUTINE, Enums.Difficulty.CATACLYSM]:
		var h: CrewHealth = await _launch(true, d)
		var c: CrewController = _rt.crew_controller(0) as CrewController
		assert_eq(h.max_downs(), CrewHealth.LAST_BREATH_DOWNS, "Last Breath: one down (difficulty %d)" % d)
		assert_eq(h.downs_left, 1)
		h.go_down()
		assert_eq(c.crew_state, Enums.CrewState.DOWNED, "the first zero-health is a down")
		h.revive(1)
		assert_eq(c.crew_state, Enums.CrewState.NORMAL, "revived")
		assert_eq(h.downs_left, 0, "no downs left")
		h.go_down()
		assert_eq(c.crew_state, Enums.CrewState.CUSTODY, "the next zero-health goes straight to custody")
		_rt.teardown()
		_rt = null
		await wait_frames(2)


func test_nine_lives_aced_gives_two_and_the_doctor_bag_resets() -> void:
	var h: CrewHealth = await _launch(true)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	Modifiers.set_source(0, &"test.nine_lives", {&"defense.downs_extra": 1})
	assert_eq(h.max_downs(), 2, "Nine Lives aced under Last Breath: 2")
	h.go_down()
	h.revive(1)
	assert_eq(h.downs_left, 1)
	h.heal(1.0, true)  # doctor bag
	assert_eq(h.downs_left, 2, "a doctor bag resets the counter")
	h.go_down()
	h.revive(1)
	h.go_down()
	h.revive(1)
	h.go_down()
	assert_eq(c.crew_state, Enums.CrewState.CUSTODY, "the third zero-health is custody")
	(_rt.service(CustodySystem.SERVICE) as CustodySystem).release(0)
	assert_eq(c.crew_state, Enums.CrewState.NORMAL, "released")
	assert_eq(h.downs_left, 2, "a custody release resets the counter")
