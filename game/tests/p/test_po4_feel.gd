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


## PO-4 / D-097 (PD2): a semi shot's kick punches the camera up over PlayerInput.recoil_apply_s (not a one-tick snap)
## and, a semi-default gun having no recoil_wait, the whole kick then eases back. Real fire input.
func test_recoil_punch_eases_in_and_recovers() -> void:
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
	var peak: float = trace.max()
	if peak <= 0.0001:
		skip("equipped weapon has no vertical kick")
		return
	var rising: int = 0
	for k: int in range(1, trace.size()):
		if trace[k] > trace[k - 1] + 1e-6 and trace[k] < peak - 1e-6:
			rising += 1
	assert_true(rising >= 1, "kick spread over several ticks, trace %s" % [trace])
	await wait_physics_frames(60)
	assert_near(c.look_pitch - p0, 0.0, peak * 0.05 + 1e-4, "PD2 recovery: the kick is put back")
	assert_true(pin.recoil_apply_s > 0.0, "tunable on")


## D-097 (PD2): an auto-default gun accumulates kick through a burst (no recovery while shots keep coming within one
## fire interval), then puts the whole burst's kick back after the trigger is released.
func test_auto_burst_accumulates_then_recovers() -> void:
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
	var def: WeaponDef = ContentDB.weapon(&"weapon.corsair_ar")
	if def.fire_modes.is_empty() or def.fire_modes[0] != &"auto":
		skip("corsair_ar is not auto-default")
		return
	var p0: float = c.look_pitch
	_inp.press(&"fire")
	var mid: float = 0.0
	for k: int in 30:
		await wait_physics_frames(1)
		if k == 14:
			mid = c.look_pitch - p0
	var end: float = c.look_pitch - p0
	_inp.release(&"fire")
	assert_true(mid > 0.0005 and end > mid + 0.0005, "kick builds through the burst (%.4f -> %.4f)" % [mid, end])
	await wait_physics_frames(90)
	assert_near(c.look_pitch - p0, 0.0, end * 0.05 + 1e-4, "whole burst kick put back after release")


## PO-4 (PD2): a real jump's landing dips the camera (camera only) and it recovers; a flat walk never dips.
func test_landing_dip_and_recovery() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_physics_frames(20)
	var walk_min: float = 0.0
	_inp.press(&"move_forward")
	for _i: int in 30:
		await wait_physics_frames(1)
		walk_min = minf(walk_min, c.land_dip)
	_inp.release(&"move_forward")
	assert_near(walk_min, 0.0, 1e-6, "walking does not dip")
	await _inp.tap(&"jump")
	var lowest: float = 0.0
	var landed_tick: int = -1
	for t: int in 120:
		await wait_physics_frames(1)
		lowest = minf(lowest, c.land_dip)
		if landed_tick < 0 and c.land_dip < 0.0:
			landed_tick = t
	assert_true(lowest < -0.005, "landing dipped the camera (%.3f m)" % lowest)
	assert_true(lowest >= -Tweak.crew().land_dip_max_m - 0.005, "dip capped")
	assert_near(c.land_dip, 0.0, 0.002, "recovered")



## PO-4 (PD2 _end_action_running): fire pressed while sprinting ends the sprint at once (and it stays off while the
## sprint key is still held), the shot waits CrewTweak.sprint_exit_fire_s for the gun to come up, then fires.
func test_sprint_to_fire_exit_delay() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_seconds(1.0)
	var w: CrewWeapons = c.weapons
	var ws: int = w.equipped_slot
	var m0: int = w.mag(ws)
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	assert_true(await wait_until(func() -> bool: return c.sprinting, 1.0), "sprinting")
	_inp.press(&"fire")
	var exit_s: float = Tweak.crew().sprint_exit_fire_s
	var early_shot: bool = false
	var t: float = 0.0
	while t < exit_s - 0.08:
		await wait_physics_frames(1)
		t += 1.0 / Engine.physics_ticks_per_second
		early_shot = early_shot or w.mag(ws) < m0
	assert_false(c.sprinting, "sprint ended by the fire press (sprint still held)")
	assert_false(early_shot, "no shot while the gun comes up")
	assert_true(await wait_until(func() -> bool: return w.mag(ws) < m0, exit_s + 0.5), "then it fires")
	_inp.release(&"fire")
	assert_false(c.sprinting, "sprint stays off until re-pressed")
	_inp.release(&"sprint")
	await wait_physics_frames(2)
	_inp.press(&"sprint")
	assert_true(await wait_until(func() -> bool: return c.sprinting, 1.0), "re-pressed sprint runs again")


## PO-4 (PD2 0.23 s stance transition): crouch / stand ease the camera instead of snapping it; gameplay eye height
## switches at once. Real crouch input.
func test_crouch_camera_eases() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_physics_frames(20)
	var tw: CrewTweak = Tweak.crew()
	var head: Node3D = c.get_node(^"Head") as Node3D
	var full: float = tw.eye_standing - tw.eye_crouched
	_inp.press(&"crouch")
	assert_true(await wait_until(func() -> bool: return c.crouched, 0.5), "crouched")
	await wait_physics_frames(1)
	assert_near(c.eye_height(), tw.eye_crouched, 1e-4, "gameplay eye switches at once")
	assert_true(head.position.y > tw.eye_crouched + full * 0.4, "camera still easing down (%.3f)" % head.position.y)
	await wait_seconds(0.4)
	assert_near(head.position.y, tw.eye_crouched, 0.01, "camera arrived")
	_inp.release(&"crouch")
	assert_true(await wait_until(func() -> bool: return not c.crouched, 0.5), "stood up")
	await wait_physics_frames(1)
	assert_true(head.position.y < tw.eye_standing - full * 0.4, "camera easing up (%.3f)" % head.position.y)
	await wait_seconds(0.4)
	assert_near(head.position.y, tw.eye_standing, 0.01, "camera back at standing height")


## PO-4 (PD2 use_headbob): walking bobs the camera subtly (within the CrewTweak amplitudes), standing still does not,
## and gameplay eye height is untouched. Real input.
func test_head_bob_subtle_while_walking() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_physics_frames(20)
	var tw: CrewTweak = Tweak.crew()
	var head: Node3D = c.get_node(^"Head") as Node3D
	var gs: GameSettings = GameSettings.current()
	if gs != null and gs.has_method(&"head_bob") and not bool(gs.call(&"head_bob")):
		skip("head bob switched off in Options")
		return
	_inp.press(&"move_forward")
	var max_x: float = 0.0
	var dy_min: float = 0.0
	var dy_max: float = 0.0
	for _i: int in 90:
		await wait_physics_frames(1)
		max_x = maxf(max_x, absf(head.position.x))
		var dy: float = head.position.y - c.eye_height()
		dy_min = minf(dy_min, dy)
		dy_max = maxf(dy_max, dy)
		assert_near(c.eye_position().y - c.global_position.y, c.eye_height(), 1e-5, "gameplay eye untouched")
	_inp.release(&"move_forward")
	assert_true(max_x > tw.head_bob_lateral_m * 0.3, "lateral bob while walking (%.4f)" % max_x)
	assert_true(max_x <= tw.head_bob_lateral_m * tw.head_bob_sprint_mult + 1e-4, "subtle lateral")
	assert_true(dy_max - dy_min > tw.head_bob_vertical_m * 0.5, "vertical bob (%.4f)" % (dy_max - dy_min))
	assert_true(dy_max <= tw.head_bob_vertical_m * tw.head_bob_sprint_mult + 0.002, "subtle vertical")
	await wait_seconds(1.0)
	assert_near(head.position.x, 0.0, 1e-5, "no bob standing still")
	assert_near(head.rotation.z, 0.0, 1e-5, "no roll standing still")


## PO-4 (PD2 melee hit shaker): a landed melee hit punches the local camera (pitch down + roll) and it settles; the
## gameplay look (look_pitch / yaw) is untouched. hit_landed is CrewMelee's own signal (emitted on a strike).
func test_melee_hit_camera_punch() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await wait_physics_frames(20)
	assert_true(c.melee != null, "crew has CrewMelee")
	if c.melee == null:
		return
	var head: Node3D = c.get_node(^"Head") as Node3D
	var p0: float = c.look_pitch
	c.melee.hit_landed.emit(null)
	var lowest: float = 0.0
	var max_roll: float = 0.0
	for _i: int in 12:
		await wait_physics_frames(1)
		lowest = minf(lowest, head.rotation.x - c.look_pitch)
		max_roll = maxf(max_roll, absf(head.rotation.z))
	assert_true(lowest < -deg_to_rad(Tweak.crew().melee_punch_pitch_deg) * 0.5, "pitch punch (%.2f deg)" % rad_to_deg(lowest))
	assert_true(max_roll > deg_to_rad(Tweak.crew().melee_punch_roll_deg) * 0.4, "roll punch")
	assert_near(c.look_pitch, p0, 1e-6, "gameplay look untouched")
	await wait_seconds(1.0)
	assert_near(c.melee_punch.length(), 0.0, 1e-4, "settled")
