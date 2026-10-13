## P1-03 ADS audit with real input: one eased ADS weight for camera and arms; reload and sprint drop ADS.
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


func _masked() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	assert_true(c.masked, "masked")
	return c


## PI-16/17: arms and camera use the same target, rate and ease: stepped with the same deltas they are equal.
func test_arms_and_camera_share_eased_weight() -> void:
	var c: CrewController = await _masked()
	var view: CrewView = CrewView.of(c)
	view.set_process(false)
	var fp: FpViewmodel = FpViewmodel.new()
	fp._crew = c
	_inp.press(&"aim")
	await wait_physics_frames(2)
	var dt: float = 1.0 / 60.0
	var diffs: Array[float] = []
	var mid: bool = false
	for _k: int in 60:
		view._process(dt)
		fp._update_ads(dt, FpViewmodelTweak.data())
		diffs.append(absf(fp.ads_weight - view.ads_blend))
		mid = mid or (view.ads_blend > 0.2 and view.ads_blend < 0.8)
	assert_true(mid, "saw the transition")
	assert_true(diffs.max() < 1e-6, "arms == camera weight every step")
	assert_near(view.ads_blend, 1.0, 1e-6, "full ADS")
	view.set_process(true)
	fp.free()


## PI-16: reloading drops ADS for the camera too (no zoomed view with the gun at the hip).
func test_reload_drops_ads() -> void:
	var c: CrewController = await _masked()
	var view: CrewView = CrewView.of(c)
	await _inp.tap(&"fire")
	await wait_physics_frames(10)
	_inp.press(&"aim")
	assert_true(await wait_until(func() -> bool: return view.ads_blend >= 1.0, 2.0), "aimed")
	await _inp.tap(&"reload")
	assert_true(await wait_until(func() -> bool: return c.weapons.reloading, 0.5), "reloading (mag not full)")
	assert_true(await wait_until(func() -> bool: return view.ads_blend <= 0.0, 1.0), "camera leaves ADS while reloading")
	assert_true(await wait_until(func() -> bool: return not c.weapons.reloading, 6.0), "reload done")
	assert_true(await wait_until(func() -> bool: return view.ads_blend >= 1.0, 2.0), "back to ADS with aim still held")


## PI-18: sprint wins over aim: no ADS while sprinting, ADS returns when sprint ends.
func test_sprint_cancels_ads() -> void:
	var c: CrewController = await _masked()
	var view: CrewView = CrewView.of(c)
	_inp.press(&"aim")
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	assert_true(await wait_until(func() -> bool: return c.sprinting, 1.0), "sprinting")
	await wait_physics_frames(30)
	assert_false(CrewView.is_aiming(c), "not aiming while sprinting")
	assert_true(view.ads_blend <= 0.0, "camera not zoomed while sprinting (%.2f)" % view.ads_blend)
	_inp.release(&"sprint")
	assert_true(await wait_until(func() -> bool: return view.ads_blend >= 1.0, 2.0), "ADS back after sprint")
