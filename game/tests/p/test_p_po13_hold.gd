## PO-13: weapon hold feel (PD2 vel_overshot look sway + breathing). Real input (PInputDriver mouse look).
## Windowed only (D-086): the sway follows look speed over real frame time, and headless runs process frames so fast
## that a 20-frame mouse flick is a few ms of game time (the sway never builds). Skipped headless (KR-9).
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 13, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _vm(c: CrewController) -> FpViewmodel:
	return FpViewmodel.of(CrewView.of(c).camera())


## Turning right swings the gun left (+yaw) within the PD2 hip max, then it settles; looking up dips it.
func test_look_sway_lags_and_settles() -> void:
	if DisplayServer.get_name() == "headless":
		skip("windowed feel test (xvfb-run, not --headless)")
		return
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_seconds(1.5)
	var vm: FpViewmodel = _vm(c)
	assert_true(vm != null, "viewmodel")
	if vm == null:
		return
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var peak: Vector2 = Vector2.ZERO
	for _k: int in 20:
		_inp.look(200.0, 0.0)  # fast at any frame rate (the sway reads look speed per real frame time)
		await wait_frames(1)
		peak.x = maxf(peak.x, vm.sway().x)
	assert_true(peak.x > 0.5, "turning right swings the gun left (%.2f deg)" % peak.x)
	assert_true(peak.x <= tw.sway_yaw_max_deg + 0.01, "within the PD2 hip max (%.2f)" % peak.x)
	assert_true(await wait_until(func() -> bool: return absf(vm.sway().x) < 0.05, 3.0), "settles (%s)" % vm.sway())
	for _k: int in 15:
		_inp.look(0.0, -150.0)  # mouse up: look up
		await wait_frames(1)
		peak.y = minf(peak.y, vm.sway().y)
	assert_true(peak.y < -0.15, "looking up dips the gun (%.2f deg)" % peak.y)


## Aimed: the sway is limited to the PD2 steelsight max and breathing almost stops.
func test_ads_sway_is_small() -> void:
	if DisplayServer.get_name() == "headless":
		skip("windowed feel test (xvfb-run, not --headless)")
		return
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_seconds(1.5)
	var vm: FpViewmodel = _vm(c)
	if vm == null:
		assert_true(false, "viewmodel")
		return
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	_inp.press(&"aim")
	assert_true(await wait_until(func() -> bool: return vm.ads_weight > 0.99, 3.0), "aimed")
	var peak: float = 0.0
	for _k: int in 20:
		_inp.look(80.0, 0.0)
		await wait_frames(1)
		peak = maxf(peak, absf(vm.sway().x))
	assert_true(peak <= tw.sway_ads_yaw_max_deg + 0.01, "ADS sway within %.0f deg (%.2f)" % [tw.sway_ads_yaw_max_deg, peak])
	assert_true(peak > 0.2, "but present (%.2f)" % peak)
	_inp.release(&"aim")
