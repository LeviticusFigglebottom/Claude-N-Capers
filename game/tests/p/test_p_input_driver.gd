## Self-test of PInputDriver: real InputMap actions / keys / mouse motion reach PlayerInput and move the crew.
## No set_bot_intent, no teleports after setup.
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


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func test_local_crew_has_player_input_and_no_bot_intent() -> void:
	var c: CrewController = _crew()
	assert_true(c.get_node_or_null(^"PlayerInput") is PlayerInput, "PlayerInput on the local crew")
	assert_false(_rt.has_bot_intent(0), "no bot intent held")


func test_action_press_walks_forward() -> void:
	var c: CrewController = _crew()
	await wait_until(func() -> bool: return c.grounded, 2.0)
	var z0: float = c.global_position.z
	var ok: bool = await _inp.walk_until(&"move_forward", func() -> bool: return c.global_position.z < z0 - 1.0, 2.0)
	assert_true(ok, "moved 1 m forward (dz %.2f)" % (c.global_position.z - z0))
	assert_false(Input.is_action_pressed(&"move_forward"), "released")
	await wait_physics_frames(30)
	assert_true(Vector2(c.velocity.x, c.velocity.z).length() < 0.05, "stops after release")


func test_physical_key_uses_input_map() -> void:
	var c: CrewController = _crew()
	await wait_until(func() -> bool: return c.grounded, 2.0)
	var ev: InputEventKey = null
	for e: InputEvent in InputMap.action_get_events(&"move_forward"):
		if e is InputEventKey:
			ev = e
			break
	assert_true(ev != null, "move_forward has a key binding")
	var k: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
	var z0: float = c.global_position.z
	_inp.key(k, true)
	await wait_physics_frames(20)
	_inp.key(k, false)
	assert_true(c.global_position.z < z0 - 0.3, "key %s walked forward (dz %.2f)" % [OS.get_keycode_string(k), c.global_position.z - z0])


func test_mouse_look_turns() -> void:
	var c: CrewController = _crew()
	_inp.capture_mouse()
	var y0: float = c.look_yaw
	_inp.look(200.0, 0.0)  # right
	await wait_physics_frames(2)
	assert_true(c.look_yaw < y0 - 0.1, "mouse right turns right (yaw %.3f -> %.3f)" % [y0, c.look_yaw])
	_inp.look(0.0, -100.0)  # up
	await wait_physics_frames(2)
	assert_true(c.look_pitch > 0.1, "mouse up pitches up (%.3f)" % c.look_pitch)
	assert_true(await _inp.turn_to_yaw(c, PI * 0.5), "turn_to_yaw converged (%.3f)" % c.look_yaw)


func test_hold_mask_up() -> void:
	var c: CrewController = _crew()
	assert_false(c.masked, "starts unmasked (casing)")
	await _inp.hold(&"mask_up", 0.4)
	assert_false(c.masked, "short hold does not mask")
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	assert_true(c.masked, "full hold masks up")


## Mouse gain is resolution independent: N mouse counts turn exactly N x sensitivity, whatever the window size.
## Headless runs have a 1/30 stretch transform (InputEventMouseMotion.relative = 30 x counts), so this also fails
## if PlayerInput ever goes back to `relative`.
func test_degrees_per_mouse_count() -> void:
	var c: CrewController = _crew()
	_inp.capture_mouse()
	await wait_physics_frames(2)
	var per: float = PInputDriver.mouse_radians_per_px()
	assert_true(per > 0.0, "sensitivity")
	var y0: float = c.look_yaw
	_inp.look(-400.0, 0.0)  # 400 counts left
	await wait_physics_frames(3)
	assert_near(c.look_yaw - y0, 400.0 * per, 1e-4, "400 counts left = %.2f deg (got %.2f deg)"
		% [rad_to_deg(400.0 * per), rad_to_deg(c.look_yaw - y0)])
	var p0: float = c.look_pitch
	_inp.look(0.0, -100.0)  # 100 counts up
	await wait_physics_frames(3)
	var inv: float = -1.0 if GameSettings.current() != null and GameSettings.current().invert_y() else 1.0
	var ms: Vector2 = GameSettings.current().mouse_sensitivity() if GameSettings.current() != null else Vector2.ONE
	assert_near(c.look_pitch - p0, 100.0 * PInputDriver.mouse_radians_per_px() / maxf(ms.x, 1e-6) * ms.y * inv, 1e-4, "100 counts up")
