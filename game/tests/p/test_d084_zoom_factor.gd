## D-084: CrewView.zoom_factor = tan(base_fov/2) / tan(fov/2) of the local camera; 1.0 at hip fire;
## CrewView.local_zoom_factor() and zoom_factor_changed. Aim is held with real input (PInputDriver).
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


func test_formula() -> void:
	assert_near(CrewView.zoom_factor_for(70.0, 70.0), 1.0, 1e-6, "same fov")
	assert_near(CrewView.zoom_factor_for(70.0, 2.0 * rad_to_deg(atan(tan(deg_to_rad(35.0)) / 4.0))), 4.0, 1e-4, "4x")


func test_no_view_is_one() -> void:
	_rt.teardown()
	_rt = null
	await wait_frames(2)
	assert_eq(CrewView.local_zoom_factor(), 1.0, "no local view")


func test_scope_zoom_and_reset_at_hip() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	assert_true(c.masked, "masked (aim allowed)")
	var view: CrewView = CrewView.of(c)
	assert_true(view != null, "view")
	await wait_frames(3)
	assert_eq(CrewView.local_view(), view, "local view registered")
	assert_eq(view.zoom_factor, 1.0, "hip fire = 1.0")
	var st: WeaponStats = c.weapons.stats(c.weapons.equipped_slot)
	var mag0: float = st.magnification
	st.magnification = 4.0  # setup: a 4x scope (restored below; stats may be shared)
	var seen: Array[float] = []
	view.zoom_factor_changed.connect(func(f: float) -> void: seen.append(f))
	_inp.press(&"aim")
	var cam: Camera3D = view.camera()
	var gs: GameSettings = GameSettings.current()
	assert_true(await wait_until(func() -> bool: return view.zoom_factor > 3.99, 3.0), "zoomed to ~4x (%.3f)" % view.zoom_factor)
	assert_near(view.zoom_factor, CrewView.zoom_factor_for(gs.fov(), cam.fov), 1e-4, "matches the camera fov")
	assert_near(CrewView.local_zoom_factor(), view.zoom_factor, 1e-6, "static accessor")
	assert_true(seen.size() > 0 and seen.back() > 3.99, "zoom_factor_changed emitted")
	_inp.release(&"aim")
	assert_true(await wait_until(func() -> bool: return view.zoom_factor == 1.0, 3.0), "back to 1.0 at hip")
	assert_eq(seen.back(), 1.0, "changed(1.0) emitted at hip")
	assert_near(cam.fov, gs.fov(), 1e-3, "camera at base fov")
	st.magnification = mag0
