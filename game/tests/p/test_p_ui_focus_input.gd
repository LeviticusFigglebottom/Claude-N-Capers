## LB / RB are shared by gameplay (throw_item / melee) and UI (ui_payday_prev / next, menus). While any UI has
## the crew's input paused (CrewInput -> CrewController.set_input_paused) the shoulders must not throw or melee,
## and a shoulder still held when the UI closes must not fire until it is pressed again. Real joypad events.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _watch(c: CrewController, ticks: int) -> Dictionary:
	var seen: Dictionary = {"melee": false, "throw_item": false}
	for _i: int in ticks:
		await wait_physics_frames(1)
		seen["melee"] = seen["melee"] or c.intent.melee
		seen["throw_item"] = seen["throw_item"] or c.intent.throw_item
	return seen


func test_shoulders_ignored_while_ui_open_and_on_close() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	assert_true(c.masked, "masked (LB = throw_item while masked)")
	# Sanity: the shoulders do drive gameplay with no UI open.
	_inp.joy_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	var free: Dictionary = await _watch(c, 3)
	_inp.joy_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	assert_true(free["melee"], "RB melees with no UI open")
	await wait_physics_frames(3)
	c.set_input_paused(true)  # what CrewInput does for payday / menus / pause
	_inp.joy_button(JOY_BUTTON_LEFT_SHOULDER, true)
	_inp.joy_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	var ui: Dictionary = await _watch(c, 10)
	assert_false(ui["melee"], "RB in UI: no melee")
	assert_false(ui["throw_item"], "LB in UI: no throw")
	_inp.joy_button(JOY_BUTTON_LEFT_SHOULDER, false)
	c.set_input_paused(false)  # UI closes while RB is still held
	var after: Dictionary = await _watch(c, 10)
	assert_false(after["melee"], "RB held through the UI close: no melee until re-pressed")
	_inp.joy_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await wait_physics_frames(2)
	_inp.joy_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	var again: Dictionary = await _watch(c, 3)
	assert_true(again["melee"], "re-pressed RB melees")
