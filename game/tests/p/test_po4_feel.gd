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


## PO-4: at hip fire the whole rifle sits in front of the lens (the authored rig had the stock 0.11 m behind the
## camera, so the receiver filled the lower right). FpViewmodelTweak.set_hip_offset.
func test_rifle_hip_in_front_of_lens() -> void:
	_rt.teardown()
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = &"weapon.corsair_ar"
	l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await _inp.tap(&"slot_primary")
	await wait_seconds(2.0)
	var cam: Camera3D = CrewView.of(c).camera()
	var vm: FpViewmodel = FpViewmodel.of(cam)
	assert_true(vm != null and vm.weapon_visual != null, "rifle in the hands")
	if vm == null or vm.weapon_visual == null:
		return
	assert_eq(vm.anim_set, &"rifle", "rifle set")
	var inv: Transform3D = cam.global_transform.affine_inverse()
	var rear: float = -INF
	for n: Node in vm.weapon_visual.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		rear = maxf(rear, b.end.z)
	assert_true(rear < -0.02, "rifle rear %.3f m (camera space z) is in front of the lens" % rear)


## PO-4 (PD2): a shot's kick punches the camera up over PlayerInput.recoil_apply_s (not a one-tick snap), the full
## kick lands, and nothing recovers on its own. Real fire input.
func test_recoil_punch_eases_in_and_holds() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_physics_frames(30)
	var pin: PlayerInput = c.get_node(^"PlayerInput") as PlayerInput
	var p0: float = c.look_pitch
	_inp.press(&"fire")
	var trace: Array[float] = []
	for _i: int in 12:
		await wait_physics_frames(1)
		trace.append(c.look_pitch - p0)
	_inp.release(&"fire")
	var kick_ticks: int = 0
	var total: float = trace.back()
	if total <= 0.0001:
		skip("equipped weapon has no vertical kick")
		return
	for d: float in trace:
		if d > 0.0001 and d < total - 0.0001:
			kick_ticks += 1
	assert_true(kick_ticks >= 2, "kick spread over several ticks (%d), trace %s" % [kick_ticks, trace])
	await wait_physics_frames(60)
	assert_near(c.look_pitch - p0, total, 0.0005, "no auto-recovery (PD2)")
	assert_true(pin.recoil_apply_s > 0.0, "tunable on")
