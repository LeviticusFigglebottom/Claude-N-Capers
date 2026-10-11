## B5-01 options hooks (ENV B's GameSettings): camera FOV + ADS zoom (CrewView), mouse / pad sensitivity, pad
## deadzone, invert_y and hold/toggle for aim/crouch/sprint (PlayerInput); D-069 camera near plane 0.02 m.
extends TestCase

var _rt: HeistRuntime = null
var _gs: GameSettings = null


func before_each() -> void:
	_gs = GameSettings.new()
	GameSettings.set_current(_gs)


func after_each() -> void:
	GameSettings.set_current(null)
	for a: StringName in [&"aim", &"crouch", &"sprint"]:
		Input.action_release(a)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_pad_settings_shape_look() -> void:
	var pin: PlayerInput = PlayerInput.new()
	add_child(pin)
	_gs.set_value(GameSettings.CONTROLS, &"pad_deadzone", 0.5)
	assert_eq(pin.gamepad_look_delta(Vector2(0.4, 0.0), 1.0), Vector2.ZERO, "inside the settings deadzone")
	_gs.set_value(GameSettings.CONTROLS, &"pad_deadzone", 0.0)
	var base: Vector2 = pin.gamepad_look_delta(Vector2(0.0, 1.0), 1.0)
	_gs.set_value(GameSettings.CONTROLS, &"pad_sensitivity", 2.0)
	var fast: Vector2 = pin.gamepad_look_delta(Vector2(0.0, 1.0), 1.0)
	assert_near(fast.y, base.y * 2.0, 0.0001, "pad_sensitivity scales look speed")
	_gs.set_value(GameSettings.CONTROLS, &"invert_y", true)
	assert_near(pin.gamepad_look_delta(Vector2(0.0, 1.0), 1.0).y, -fast.y, 0.0001, "invert_y flips pitch")
	pin.queue_free()


func test_hold_and_toggle() -> void:
	var pin: PlayerInput = PlayerInput.new()
	add_child(pin)
	Input.action_press(&"aim")
	await wait_frames(1)
	assert_true(pin._held_or_toggled(&"aim"), "hold (default): pressed = on")
	Input.action_release(&"aim")
	await wait_frames(1)
	assert_false(pin._held_or_toggled(&"aim"), "hold: released = off")
	_gs.set_value(GameSettings.CONTROLS, GameSettings.MODE_KEYS[&"aim"], "toggle")
	assert_true(_gs.is_toggle(&"aim"), "aim set to toggle")
	Input.action_press(&"aim")
	await wait_frames(1)
	assert_true(pin._held_or_toggled(&"aim"), "toggle: first press = on")
	Input.action_release(&"aim")
	await wait_frames(1)
	assert_true(pin._held_or_toggled(&"aim"), "toggle: stays on after release")
	Input.action_press(&"aim")
	await wait_frames(1)
	assert_false(pin._held_or_toggled(&"aim"), "toggle: second press = off")
	pin.queue_free()


func _rook() -> Loadout:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.heister = &"rook"
	return l


func test_camera_fov_ads_zoom_and_near_plane() -> void:
	_gs.set_value(GameSettings.VIDEO, &"fov", 90.0)
	_rt = await HeistLauncher.launch(&"unit_map", 5101, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true,
		"loadouts": {0: _rook()}})
	await wait_frames(4)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_eq(c.heister, &"rook", "Loadout.heister (D-073, characters.md v1.8 sleeves)")
	var view: CrewView = CrewView.of(c)
	var cam: Camera3D = view.camera() if view != null else null
	assert_true(cam != null, "local camera")
	if cam == null:
		return
	assert_near(cam.near, 0.02, 0.0001, "D-069 near plane")
	assert_near(cam.fov, 90.0, 0.01, "FOV from GameSettings")
	_gs.set_value(GameSettings.VIDEO, &"fov", 70.0)
	await wait_frames(2)
	assert_near(cam.fov, 70.0, 0.01, "a changed setting applies at once")
	c.weapons.stats(c.weapons.equipped_slot).magnification = 2.0
	var aim: CrewIntent = CrewIntent.new()
	aim.aim = true
	_rt.set_bot_intent(0, aim)
	await wait_seconds(0.6)
	assert_near(cam.fov, 35.0, 0.5, "ADS zoom: fov / magnification")
