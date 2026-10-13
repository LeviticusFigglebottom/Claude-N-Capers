## L4 feel: D-091 mouse gain x the Options multiplier, and the PD2-like right-stick response (deadzone, curve,
## held-full-turn ramp on yaw only, ADS / zoom division). Real input (PInputDriver: mouse motion and joypad axes on
## device 0 through the project.godot look_* bindings) where a crew is involved.
extends TestCase

const TICK: float = 1.0 / 60.0

var _rt: HeistRuntime = null
var _inp: PInputDriver = null
var _gs_saved: GameSettings = null


func before_each() -> void:
	_inp = PInputDriver.new(self)
	_gs_saved = GameSettings.current()


func after_each() -> void:
	_inp.release_all()
	GameSettings.set_current(_gs_saved)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	return _rt.crew_controller(0) as CrewController


## A PlayerInput outside the tree on default settings (the exports' defaults, GameSettings defaults).
func _pin() -> PlayerInput:
	GameSettings.set_current(GameSettings.new())
	return PlayerInput.new()


## Yaw turned (radians, positive = right) on each of `ticks` physics ticks.
func _yaw_per_tick(c: CrewController, ticks: int) -> Array[float]:
	var out: Array[float] = []
	var prev: float = c.look_yaw
	for _i: int in ticks:
		await get_tree().physics_frame
		out.append(wrapf(prev - c.look_yaw, -PI, PI))
		prev = c.look_yaw
	return out


func _mean(a: Array[float], from: int, to: int) -> float:
	var s: float = 0.0
	for i: int in range(from, to):
		s += a[i]
	return s / float(to - from)


# --- (1) D-091: Options mouse sensitivity multiplies the base gain -----------------------------------------------

func test_options_mouse_sensitivity_doubles_yaw_per_count() -> void:
	var c: CrewController = await _launch()
	_inp.capture_mouse()
	await wait_physics_frames(5)
	var gs: GameSettings = GameSettings.current()
	var old: Variant = gs.get_value(GameSettings.CONTROLS, &"mouse_sensitivity_x")
	gs.set_value(GameSettings.CONTROLS, &"mouse_sensitivity_x", 1.0)
	var y0: float = c.look_yaw
	_inp.look(100.0, 0.0)
	await wait_physics_frames(3)
	var base: float = wrapf(y0 - c.look_yaw, -PI, PI)
	var gain: float = (c.get_node("PlayerInput") as PlayerInput).mouse_sensitivity
	assert_near(base, 100.0 * gain, 1e-4, "1.0x = 100 counts x %.4f rad" % gain)
	gs.set_value(GameSettings.CONTROLS, &"mouse_sensitivity_x", 2.0)
	y0 = c.look_yaw
	_inp.look(100.0, 0.0)
	await wait_physics_frames(3)
	var doubled: float = wrapf(y0 - c.look_yaw, -PI, PI)
	gs.set_value(GameSettings.CONTROLS, &"mouse_sensitivity_x", old)
	assert_near(doubled, 2.0 * base, base * 0.01, "2.0x doubles yaw per count (%.5f vs %.5f)" % [doubled, base])
	assert_eq(gs.get_value(GameSettings.CONTROLS, &"mouse_sensitivity_x"), old, "restored")


# --- (2) right stick -------------------------------------------------------------------------------------------

func test_pad_deadzone_gives_zero() -> void:
	var pin: PlayerInput = _pin()
	for m: float in [0.0, 0.05, 0.1, 0.15, 0.199]:
		assert_eq(pin.gamepad_look_delta(Vector2(m, 0.0), 1.0), Vector2.ZERO, "|stick| %.3f inside 0.2" % m)
		assert_eq(pin.gamepad_look_step(Vector2(0.0, m), 1.0), Vector2.ZERO, "step %.3f inside 0.2" % m)
	# Radial: a diagonal of 0.13 per axis (|v| 0.184) is still inside.
	assert_eq(pin.gamepad_look_delta(Vector2(0.13, 0.13), 1.0), Vector2.ZERO, "radial deadzone")
	assert_true(pin.gamepad_look_delta(Vector2(0.25, 0.0), 1.0) != Vector2.ZERO, "past the deadzone turns")
	pin.free()


func test_pad_curve_is_monotonic_with_a_precise_zone() -> void:
	var pin: PlayerInput = _pin()
	var prev: float = 0.0
	for i: int in range(0, 51):
		var m: float = float(i) / 50.0
		var v: float = absf(pin.gamepad_look_delta(Vector2(m, 0.0), 1.0).x)
		assert_true(v >= prev, "monotonic at %.2f (%.4f >= %.4f)" % [m, v, prev])
		if m > 0.21:
			assert_true(v > prev, "strictly increasing past the deadzone at %.2f" % m)
		prev = v
	assert_near(prev, pin.gamepad_look_speed, 1e-4, "full deflection = gamepad_look_speed")
	var half: float = absf(pin.gamepad_look_delta(Vector2(0.6, 0.0), 1.0).x)
	assert_true(half < 0.5 * pin.gamepad_look_speed, "exponent < linear mid-stick (finer aim): %.3f" % half)
	pin.free()


func test_pad_ramp_engages_after_delay_and_resets() -> void:
	var pin: PlayerInput = _pin()
	var full: Vector2 = Vector2(1.0, 0.0)
	var base: float = pin.gamepad_look_delta(full, TICK).x
	var t: float = 0.0
	while t + TICK <= pin.gamepad_ramp_delay_s - 1e-6:
		assert_near(pin.gamepad_look_step(full, TICK).x, base, 1e-6, "no ramp before the delay (t %.3f)" % t)
		t += TICK
	var ticks_to_max: int = int(ceil((pin.gamepad_ramp_delay_s + pin.gamepad_ramp_time_s - t) / TICK)) + 1
	var last: float = absf(base)
	for _i: int in ticks_to_max:
		var y: float = absf(pin.gamepad_look_step(full, TICK).x)
		assert_true(y >= last - 1e-6, "ramp only rises while held")
		last = y
	assert_near(pin.gamepad_ramp_multiplier(), pin.gamepad_ramp_max_mult, 1e-4, "reaches max after delay + ramp time")
	assert_near(last, absf(base) * pin.gamepad_ramp_max_mult, 1e-5, "yaw x1.8 at max")
	# Pitch is never ramped: same stick with a vertical part, ramp at max.
	var diag: Vector2 = Vector2(0.92, -0.35)
	var ramped: Vector2 = pin.gamepad_look_step(diag, TICK)
	var plain: Vector2 = pin.gamepad_look_delta(diag, TICK)
	assert_near(ramped.y, plain.y, 1e-7, "pitch unaffected by the ramp")
	assert_near(ramped.x, plain.x * pin.gamepad_ramp_max_mult, 1e-6, "yaw ramped")
	# Below the threshold the ramp resets; re-engaging needs the full delay again.
	pin.gamepad_look_step(Vector2(0.8, 0.0), TICK)
	assert_eq(pin.gamepad_ramp_multiplier(), 1.0, "reset below the threshold")
	assert_near(pin.gamepad_look_step(full, TICK).x, base, 1e-6, "back to 1x on re-entry")
	# Off switch.
	pin.gamepad_ramp_enabled = false
	for _i: int in 60:
		pin.gamepad_look_step(full, TICK)
	assert_eq(pin.gamepad_ramp_multiplier(), 1.0, "gamepad_ramp_enabled = false: no ramp")
	pin.free()


func test_pad_ramp_through_joypad_axis_events() -> void:
	var c: CrewController = await _launch()
	var pin: PlayerInput = c.get_node("PlayerInput") as PlayerInput
	assert_true(pin != null, "local PlayerInput")
	await wait_physics_frames(5)
	var tps: float = float(Engine.physics_ticks_per_second)
	var base: float = -pin.gamepad_look_delta(Vector2(1.0, 0.0), 1.0 / tps).x
	_inp.joy_axis(JOY_AXIS_RIGHT_X, 1.0)  # look_right (axis 2, device 0)
	var n: int = int(ceil((pin.gamepad_ramp_delay_s + pin.gamepad_ramp_time_s + 0.2) * tps))
	var ys: Array[float] = await _yaw_per_tick(c, n)
	var early: float = _mean(ys, 2, int(pin.gamepad_ramp_delay_s * tps) - 2)
	var late: float = _mean(ys, n - 8, n)
	assert_near(early, base, base * 0.03, "first %.2f s at 1x (%.5f vs %.5f rad/tick)" % [pin.gamepad_ramp_delay_s, early, base])
	assert_near(late, base * pin.gamepad_ramp_max_mult, base * 0.03, "held full turn ramps to x%.1f (%.5f)" % [
		pin.gamepad_ramp_max_mult, late])
	# Ease off below the threshold, then back to full: 1x again.
	_inp.joy_axis(JOY_AXIS_RIGHT_X, 0.6)
	await wait_physics_frames(3)
	_inp.joy_axis(JOY_AXIS_RIGHT_X, 1.0)
	ys = await _yaw_per_tick(c, 6)
	assert_near(_mean(ys, 2, 6), base, base * 0.03, "ramp reset after easing off")
	_inp.joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	await wait_physics_frames(2)
	var y0: float = c.look_yaw
	await wait_physics_frames(5)
	assert_near(c.look_yaw, y0, 1e-6, "released stick: no drift")


func test_pad_ads_divides_by_zoom() -> void:
	var c: CrewController = await _launch()
	var pin: PlayerInput = c.get_node("PlayerInput") as PlayerInput
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	assert_true(c.masked, "masked (ADS needs the mask)")
	await wait_physics_frames(30)
	var tps: float = float(Engine.physics_ticks_per_second)
	var expect: float = -pin.gamepad_look_delta(Vector2(0.6, 0.0), 1.0 / tps).x
	_inp.joy_axis(JOY_AXIS_RIGHT_X, 0.6)  # below the ramp threshold
	var hip: float = _mean(await _yaw_per_tick(c, 12), 2, 12)
	_inp.joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	assert_near(hip, expect, expect * 0.03, "hip stick rate %.5f" % hip)
	var st: WeaponStats = c.weapons.stats(c.weapons.equipped_slot)
	var mag0: float = st.magnification
	st.magnification = 4.0  # setup: a 4x scope (restored below; stats may be shared)
	_inp.press(&"aim")
	var zoomed: bool = await wait_until(func() -> bool: return CrewView.local_zoom_factor() > 3.99, 3.0)
	var z: float = CrewView.local_zoom_factor()
	_inp.joy_axis(JOY_AXIS_RIGHT_X, 0.6)
	var ads: float = _mean(await _yaw_per_tick(c, 12), 2, 12)
	_inp.joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	_inp.release(&"aim")
	st.magnification = mag0
	assert_true(zoomed, "zoomed to 4x")
	assert_near(ads, hip / z, hip * 0.03, "ADS stick %.5f = hip %.5f / zoom %.2f" % [ads, hip, z])
