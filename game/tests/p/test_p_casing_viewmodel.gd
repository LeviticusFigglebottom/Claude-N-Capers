## PD2: no first-person weapon/arms while casing (unmasked); masking up (G held, real input) shows it again.
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


func test_viewmodel_hidden_while_casing_shown_masked() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var view: CrewView = CrewView.of(c)
	await wait_frames(3)
	assert_true(c.is_casing(), "casing")
	assert_true(view.viewmodel() != null, "a weapon viewmodel exists (muzzle marker kept)")
	assert_false(view.viewmodel_visible(), "hidden while casing")
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	assert_true(c.masked, "masked")
	assert_true(await wait_until(func() -> bool: return view.viewmodel_visible(), 1.0), "shown after masking up")
	assert_true(c.weapon_visual != null and c.weapon_visual.get_marker(&"Muzzle") != null, "muzzle marker available")
