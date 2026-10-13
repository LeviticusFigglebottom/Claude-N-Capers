## Real-player input for tests (D-076, QP-2). Owner: ENV P. Shared: any env may use it.
## Drives the game the way a player does: InputMap actions and keys go through Input.parse_input_event, so
## PlayerInput (the only gameplay reader of Input) builds the intent itself. Never uses HeistRuntime.set_bot_intent.
##
## Usage (inside a TestCase):
##   var inp: PInputDriver = PInputDriver.new(self)
##   inp.press(&"move_forward")            # held until release()
##   await inp.hold(&"mask_up", 1.2)       # press, wait 1.2 s of game time, release
##   await inp.tap(&"jump")                # press for 2 physics ticks
##   await inp.walk_until(&"move_forward", func() -> bool: return c.global_position.z < -4.0, 3.0)
##   inp.look(dx_px, dy_px)                # mouse motion (relative pixels, like a real mouse)
##   await inp.turn_to_yaw(crew, yaw)      # mouse-look until the crew faces `yaw`
##   inp.release_all()                     # ALWAYS in after_each
## Notes:
## - Mouse look needs Input.MOUSE_MODE_CAPTURED (MouseCapture, D-087). Headless cannot capture, so
##   PlayerInput accepts mouse motion when PlayerInput.test_assume_captured is true (set only by this driver).
## - Waits are game-time (physics ticks), not wall clock.
class_name PInputDriver
extends RefCounted

var _t: Node = null
var _held: Dictionary[StringName, bool] = {}
var _keys: Dictionary[int, bool] = {}
var _joy: Dictionary[int, bool] = {}


func _init(test: Node) -> void:
	_t = test


## Press an InputMap action (held until release / release_all).
func press(action: StringName, strength: float = 1.0) -> void:
	assert(InputMap.has_action(action), "unknown action %s" % action)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = strength
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	_held[action] = true


func release(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	_held.erase(action)


## Physical key (e.g. KEY_W): exercises the InputMap bindings themselves.
func key(keycode: Key, pressed: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	if pressed:
		_keys[keycode] = true
	else:
		_keys.erase(keycode)


## Gamepad button (e.g. JOY_BUTTON_LEFT_SHOULDER), device 0: exercises the joypad InputMap bindings.
func joy_button(button: JoyButton, pressed: bool) -> void:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	if pressed:
		_joy[button] = true
	else:
		_joy.erase(button)


func is_held(action: StringName) -> bool:
	return _held.has(action)


func release_all() -> void:
	for a: StringName in _held.keys():
		release(a)
	for k: int in _keys.keys():
		key(k as Key, false)
	for b: int in _joy.keys():
		joy_button(b as JoyButton, false)
	PlayerInput.test_assume_captured = false


## Press for `seconds` of game time, then release.
func hold(action: StringName, seconds: float) -> void:
	press(action)
	await _ticks(maxi(1, int(ceil(seconds * Engine.physics_ticks_per_second))))
	release(action)
	await _ticks(1)


## Short press (2 physics ticks), then release.
func tap(action: StringName) -> void:
	press(action)
	await _ticks(2)
	release(action)
	await _ticks(1)


## Hold `action` until `cond` or timeout (s, game time); releases it. Returns whether cond became true.
## `on_tick` (optional) is called every physics tick while held (sampling).
func walk_until(action: StringName, cond: Callable, timeout_s: float, on_tick: Callable = Callable()) -> bool:
	press(action)
	var ok: bool = await _until(cond, timeout_s, on_tick)
	release(action)
	await _ticks(1)
	return ok


## Treat the mouse as captured (see header) and try the real capture too.
## D-087: MouseCapture owns the real mode (it captures for a live PlayerInput in a windowed run); this only lets
## headless runs, which cannot capture, accept the motion.
func capture_mouse() -> void:
	PlayerInput.test_assume_captured = true


## Relative mouse motion in pixels (+x = right, +y = down).
func look(dx: float, dy: float) -> void:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	ev.screen_relative = Vector2(dx, dy)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Mouse-look in small steps until `crew.look_yaw` is within `tol` rad of `yaw`. Returns success.
func turn_to_yaw(crew: Node3D, yaw: float, tol: float = 0.02, timeout_s: float = 3.0) -> bool:
	capture_mouse()
	# Input events are delivered per rendered frame, not per physics tick: send one correction, then wait for
	# the crew's yaw to settle before the next (otherwise several queued corrections overshoot).
	var t: float = 0.0
	while t < timeout_s:
		var err: float = wrapf(yaw - float(crew.get(&"look_yaw")), -PI, PI)
		if absf(err) <= tol:
			return true
		look(-err / mouse_radians_per_px(), 0.0)
		var before: float = float(crew.get(&"look_yaw"))
		for _i: int in 10:
			await _ticks(1)
			t += 1.0 / Engine.physics_ticks_per_second
			if absf(float(crew.get(&"look_yaw")) - before) > 1e-5:
				await _ticks(2)
				t += 2.0 / Engine.physics_ticks_per_second
				break
	return false


## Radians of yaw per pixel of mouse motion (PlayerInput.mouse_sensitivity x GameSettings mouse sensitivity).
static func mouse_radians_per_px() -> float:
	var gs: GameSettings = GameSettings.current()
	var ms: float = gs.mouse_sensitivity().x if gs != null else 1.0
	var pin: PlayerInput = PlayerInput.new()
	var sens: float = pin.mouse_sensitivity
	pin.free()
	return sens * ms


func _ticks(n: int) -> void:
	for _i: int in n:
		await _t.get_tree().physics_frame


func _until(cond: Callable, timeout_s: float, on_tick: Callable) -> bool:
	var t: float = 0.0
	while true:
		await _t.get_tree().physics_frame
		if on_tick.is_valid():
			on_tick.call()
		if cond.call():
			return true
		t += 1.0 / Engine.physics_ticks_per_second
		if t >= timeout_s:
			return false
	return false
