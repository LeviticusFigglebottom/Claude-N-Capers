## PO-4 feel pass: PD2 zoom sensitivity (ADS / scoped look slows by CrewView.zoom_factor, D-084) and the default
## mouse gain. Real input (PInputDriver).
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _yaw_for(c: CrewController, px: float) -> float:
	var y0: float = c.look_yaw
	_inp.look(px, 0.0)
	await wait_physics_frames(3)
	return y0 - c.look_yaw


func test_default_gain_is_moderate() -> void:
	var deg_per_count: float = rad_to_deg(PlayerInput.new().mouse_sensitivity)
	assert_true(deg_per_count > 0.05 and deg_per_count < 0.12, "default %.3f deg/count" % deg_per_count)


func test_ads_look_scales_with_zoom() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	assert_true(c.masked, "masked (ADS needs the mask)")
	await wait_physics_frames(30)
	var hip: float = await _yaw_for(c, 200.0)
	assert_near(CrewView.local_zoom_factor(), 1.0, 0.01, "hip: no zoom")
	var st: WeaponStats = c.weapons.stats(c.weapons.equipped_slot)
	var mag0: float = st.magnification
	st.magnification = 4.0  # setup: a 4x scope (restored below; stats may be shared)
	_inp.press(&"aim")
	assert_true(await wait_until(func() -> bool: return CrewView.local_zoom_factor() > 3.99, 3.0), "zoomed to 4x")
	var z: float = CrewView.local_zoom_factor()
	var ads: float = await _yaw_for(c, 200.0)
	_inp.release(&"aim")
	st.magnification = mag0
	assert_near(ads, hip / z, hip * 0.03, "ADS turn %.4f = hip %.4f / zoom %.2f" % [ads, hip, z])
