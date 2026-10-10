## Owner: LEAD. Regenerates InputMap actions + navigation defaults in project.godot (D-025).
## Run: godot --headless --path game -s ../tools/ci/set_project_settings.gd
extends SceneTree

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e

func _mouse(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = b
	return e

func _joy(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = b
	return e

func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = a
	e.axis_value = v
	return e

func _initialize() -> void:
	var m := {
		"move_forward": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_back": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"sprint": [_key(KEY_SHIFT), _joy(JOY_BUTTON_LEFT_STICK)],
		"crouch": [_key(KEY_CTRL), _key(KEY_C), _joy(JOY_BUTTON_RIGHT_STICK)],
		"jump": [_key(KEY_SPACE), _joy(JOY_BUTTON_A)],
		"interact": [_key(KEY_F), _joy(JOY_BUTTON_X)],
		"shout": [_key(KEY_F), _mouse(MOUSE_BUTTON_MIDDLE), _joy(JOY_BUTTON_X)],
		"fire": [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"aim": [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"reload": [_key(KEY_R), _joy(JOY_BUTTON_B)],
		"melee": [_key(KEY_V), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		"throw_item": [_key(KEY_G), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		"deploy": [_key(KEY_5), _joy(JOY_BUTTON_DPAD_DOWN)],
		"mask_up": [_key(KEY_G), _joy(JOY_BUTTON_Y)],
		"slot_primary": [_key(KEY_2)],
		"slot_secondary": [_key(KEY_1)],
		"swap_weapon": [_mouse(MOUSE_BUTTON_WHEEL_UP), _joy(JOY_BUTTON_Y)],
		"drop_bag": [_key(KEY_G), _joy(JOY_BUTTON_DPAD_UP)],
		"order_menu": [_key(KEY_T), _joy(JOY_BUTTON_DPAD_LEFT)],
		"scoreboard": [_key(KEY_TAB), _joy(JOY_BUTTON_BACK)],
		"pause": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
	}
	for action: String in m:
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": m[action]})
	ProjectSettings.set_setting("navigation/3d/default_cell_size", 0.1)
	ProjectSettings.set_setting("navigation/3d/default_cell_height", 0.1)
	print(ProjectSettings.save())
	quit()
