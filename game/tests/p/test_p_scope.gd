## Scoped ADS (LEAD 2026-10-16, PD2): a high-power scope (Osprey 762 + 4x) shows the FpScopeOverlay sight picture
## at full ADS, the gun image (with its ocular lens) is hidden and the world FOV is divided by the magnification;
## releasing aim brings the gun back. A 3x prism (Corsair) stays a 3D sight. Real input (PInputDriver).
## Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(wid: StringName, mod: StringName) -> CrewController:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = wid
	l.primary_mods = [mod] as Array[StringName]
	l.resolved_primary = LoadoutResolver.resolve_weapon(wid, l.primary_mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await _inp.tap(&"slot_primary")
	await wait_physics_frames(60)
	return c


func _image_visible(cv: CrewView) -> bool:
	var img: Node = cv.find_child("ViewmodelImage", true, false)
	return img != null and (img as CanvasItem).visible


func test_scope_shows_sight_picture_at_full_ads() -> void:
	if FpViewmodelTweak.data().viewmodel_fov_deg <= 0.0:
		skip("no viewmodel camera")
		return
	var c: CrewController = await _launch(&"weapon.osprey_762", &"mod.osprey_scope_4x")
	var cv: CrewView = CrewView.of(c)
	var st: WeaponStats = c.weapons.stats(c.weapons.equipped_slot)
	assert_true(CrewView.scope_overlay_for(st, st.magnification), "Osprey 4x is an overlay scope (mag %.1f)" %
		st.magnification)
	var ov: FpScopeOverlay = cv.scope_overlay()
	assert_true(ov != null, "overlay built")
	assert_false(ov.visible, "no overlay at the hip")
	assert_true(_image_visible(cv), "gun visible at the hip")
	_inp.press(&"aim")
	assert_true(await wait_until(func() -> bool: return cv.ads_blend > 0.999, 3.0), "aimed")
	await wait_frames(3)
	assert_near(ov.amount, 1.0, 1e-3, "full sight picture")
	assert_false(_image_visible(cv), "gun + ocular hidden at full ADS")
	var base: float = GameSettings.current().fov()
	assert_near(cv.camera().fov, base / st.magnification, 0.05, "FOV / magnification")
	_inp.release(&"aim")
	assert_true(await wait_until(func() -> bool: return cv.ads_blend < 0.001, 3.0), "back at the hip")
	await wait_frames(3)
	assert_false(ov.visible, "overlay gone")
	assert_true(_image_visible(cv), "gun back")


func test_low_power_prism_stays_3d() -> void:
	if FpViewmodelTweak.data().viewmodel_fov_deg <= 0.0:
		skip("no viewmodel camera")
		return
	var c: CrewController = await _launch(&"weapon.corsair_ar", &"mod.rail_prism_scope")
	var cv: CrewView = CrewView.of(c)
	_inp.press(&"aim")
	assert_true(await wait_until(func() -> bool: return cv.ads_blend > 0.999, 3.0), "aimed")
	await wait_frames(3)
	assert_false(cv.scope_overlay().visible, "3x prism: no overlay")
	assert_true(_image_visible(cv), "3x prism: the 3D sight stays")


func test_sight_picture_sways_and_settles() -> void:
	if FpViewmodelTweak.data().viewmodel_fov_deg <= 0.0:
		skip("no viewmodel camera")
		return
	var c: CrewController = await _launch(&"weapon.osprey_762", &"mod.osprey_scope_4x")
	var cv: CrewView = CrewView.of(c)
	_inp.press(&"aim")
	assert_true(await wait_until(func() -> bool: return cv.ads_blend > 0.999, 3.0), "aimed")
	await wait_frames(5)
	var ov: FpScopeOverlay = cv.scope_overlay()
	var peak: float = 0.0
	for _k: int in 8:  # a quick turn right
		_inp.look(40.0, 0.0)
		await wait_frames(1)
		peak = maxf(peak, ov.offset.length())
	for _k: int in 20:
		await wait_frames(1)
		peak = maxf(peak, ov.offset.length())
	assert_true(peak > 5.0, "the turn sways the sight picture (peak %.1f px)" % peak)
	await wait_physics_frames(150)
	# Still: the look-lag part springs back to ~0 (the slow breathing drift, a few px, never stops).
	var vm: FpViewmodel = FpViewmodel.of(cv.camera())
	var lag: Vector2 = vm.sight_sway_deg(1.0, 0.0)
	assert_true(lag.length() < 0.02, "look-lag sway settles when still (%s deg)" % lag)
	assert_true(ov.offset.length() < peak, "the sight picture is back near the centre (%.1f px, peak %.1f)" % [
		ov.offset.length(), peak])


## ui_hud.md v1.16: scoped ADS publishes `scoped_ads` + the ocular ring's screen bounds into the local HUD model.
func test_hud_model_gets_scoped_ads_and_ring() -> void:
	if FpViewmodelTweak.data().viewmodel_fov_deg <= 0.0:
		skip("no viewmodel camera")
		return
	var c: CrewController = await _launch(&"weapon.osprey_762", &"mod.osprey_scope_4x")
	var hm: Object = _rt.hud_model
	if hm == null or not (&"scoped_ads" in hm) or not (&"scope_ring" in hm):
		skip("LocalHudModel has no scoped_ads / scope_ring yet (ENV A, ui_hud.md v1.16)")
		return
	var cv: CrewView = CrewView.of(c)
	assert_false(bool(hm.get(&"scoped_ads")), "not scoped at the hip")
	_inp.press(&"aim")
	assert_true(await wait_until(func() -> bool: return cv.ads_blend > 0.999, 3.0), "aimed")
	await wait_frames(3)
	assert_true(bool(hm.get(&"scoped_ads")), "scoped_ads at full ADS")
	var ring: Rect2 = hm.get(&"scope_ring") as Rect2
	var size: Vector2 = cv.scope_overlay().size
	var r: float = FpScopeOverlay.ocular_radius(size)
	assert_near(ring.size.x, 2.0 * r, 1.0, "ring = the ocular's diameter")
	assert_true(ring.get_center().distance_to(size * 0.5) < r * 0.2, "ring centred (sway aside)")
	_inp.release(&"aim")
	assert_true(await wait_until(func() -> bool: return not bool(hm.get(&"scoped_ads")), 3.0), "cleared on release")
