## PP-A-1 (D-082 playability pass): real-player input for tests. Owner: ENV A (test support).
## Everything goes through Input.parse_input_event (InputMap actions, physical keys, mouse motion), so
## PlayerInput, the only gameplay reader of Input, builds the crew intent itself. Never calls
## set_bot_intent / teleport_crew and never writes game state.
##
## Usage (inside a TestCase):
##   var inp: PlayerInputDriver = PlayerInputDriver.new(self)
##   await inp.hold(&"mask_up", 1.2)          # press, wait 1.2 s of game time, release
##   await inp.tap(&"shout")                  # 2 physics ticks
##   await inp.walk_until(&"move_forward", cond, 4.0)
##   await inp.aim_at(crew, world_point)      # mouse-look (yaw + pitch)
##   inp.release_all()                        # ALWAYS in after_each
## Mouse look: headless DisplayServer ignores MOUSE_MODE_CAPTURED, and PlayerInput reads mouse motion only
## while captured. capture_mouse() also sets PlayerInput.test_assume_captured when that hook exists (ENV P,
## env/p-play, not yet on trunk). can_mouse_look() reports whether mouse motion will reach PlayerInput.
## Waits are game time (physics ticks).
class_name PlayerInputDriver
extends RefCounted

const ASSUME_CAPTURED: StringName = &"test_assume_captured"

var _t: Node = null
var _held: Dictionary[StringName, bool] = {}
var _keys: Dictionary[int, bool] = {}


func _init(test: Node) -> void:
	_t = test


## Press an InputMap action (held until release / release_all).
func press(action: StringName, strength: float = 1.0) -> void:
	assert(InputMap.has_action(action), "unknown action %s" % action)
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = strength
	_send(ev)
	_held[action] = true


func release(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	_send(ev)
	_held.erase(action)


## Physical key (e.g. KEY_W): exercises the InputMap bindings themselves.
func key(keycode: Key, pressed: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	_send(ev)
	if pressed:
		_keys[keycode] = true
	else:
		_keys.erase(keycode)


func is_held(action: StringName) -> bool:
	return _held.has(action)


## Release every held action / key and drop the capture assumption. Call in after_each.
func release_all() -> void:
	for a: StringName in _held.keys():
		release(a)
	for k: int in _keys.keys():
		key(k as Key, false)
	_set_assume_captured(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Press for `seconds` of game time, then release.
func hold(action: StringName, seconds: float) -> void:
	press(action)
	await ticks(maxi(1, ceili(seconds * Engine.physics_ticks_per_second)))
	release(action)
	await ticks(1)


## Short press (2 physics ticks), then release.
func tap(action: StringName) -> void:
	press(action)
	await ticks(2)
	release(action)
	await ticks(1)


## Hold `action` until `cond` or `timeout_s` (game time), then release. Returns whether cond became true.
func walk_until(action: StringName, cond: Callable, timeout_s: float) -> bool:
	press(action)
	var ok: bool = await until(cond, timeout_s)
	release(action)
	await ticks(1)
	return ok


## Capture the mouse (and assume it captured where the PlayerInput hook exists).
func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_assume_captured(true)


## True when mouse motion will reach PlayerInput (really captured, or the test hook is set).
func can_mouse_look() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or bool(_script_get(ASSUME_CAPTURED, false))


## Relative mouse motion in pixels (+x = right, +y = down).
func look(dx: float, dy: float) -> void:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	ev.screen_relative = Vector2(dx, dy)
	_send(ev)


## Mouse-look until `crew` faces `yaw` / `pitch` (rad) within `tol`. Returns success.
func turn_to(crew: Node3D, yaw: float, pitch: float, tol: float = 0.02, timeout_s: float = 3.0) -> bool:
	capture_mouse()
	if not can_mouse_look():
		return false
	var rad_px: Vector2 = mouse_radians_per_px()
	var t: float = 0.0
	while t < timeout_s:
		var ey: float = wrapf(yaw - float(crew.get(&"look_yaw")), -PI, PI)
		var ep: float = pitch - float(crew.get(&"look_pitch"))
		if absf(ey) <= tol and absf(ep) <= tol:
			return true
		look(-ey / rad_px.x, -ep / rad_px.y)
		# Input events land per rendered frame: wait for the crew to apply one correction before the next.
		var before: Vector2 = Vector2(float(crew.get(&"look_yaw")), float(crew.get(&"look_pitch")))
		for _i: int in 10:
			await ticks(1)
			t += 1.0 / Engine.physics_ticks_per_second
			if Vector2(float(crew.get(&"look_yaw")), float(crew.get(&"look_pitch"))).distance_to(before) > 1e-5:
				await ticks(2)
				t += 2.0 / Engine.physics_ticks_per_second
				break
	return false


## Mouse-look so the crew's eye looks at `point`.
func aim_at(crew: CrewController, point: Vector3, tol: float = 0.02, timeout_s: float = 3.0) -> bool:
	var d: Vector3 = point - crew.eye_position()
	return await turn_to(crew, atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()), tol, timeout_s)


## Radians of (yaw, pitch) per pixel of mouse motion (PlayerInput.mouse_sensitivity x the GameSettings
## sensitivity; pitch sign includes invert_y).
static func mouse_radians_per_px() -> Vector2:
	var gs: GameSettings = GameSettings.current()
	var ms: Vector2 = gs.mouse_sensitivity() if gs != null else Vector2.ONE
	var inv: float = -1.0 if gs != null and gs.invert_y() else 1.0
	var pin: PlayerInput = PlayerInput.new()
	var sens: float = pin.mouse_sensitivity
	pin.free()
	return Vector2(sens * ms.x, sens * ms.y * inv)


func ticks(n: int) -> void:
	for _i: int in n:
		await _t.get_tree().physics_frame


## Wait until `cond` (checked every physics tick) or `timeout_s`. Returns whether it became true.
func until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while t < timeout_s:
		await _t.get_tree().physics_frame
		if cond.call():
			return true
		t += 1.0 / Engine.physics_ticks_per_second
	return false


func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _set_assume_captured(on: bool) -> void:
	if _script_has(ASSUME_CAPTURED):
		(PlayerInput as GDScript).set(ASSUME_CAPTURED, on)


## A static var of PlayerInput by name (null when the script has none). get_script_property_list() does
## not list static vars, so probe with get().
static func _script_has(prop: StringName) -> bool:
	return (PlayerInput as GDScript).get(prop) != null


static func _script_get(prop: StringName, fallback: Variant) -> Variant:
	var v: Variant = (PlayerInput as GDScript).get(prop)
	return fallback if v == null else v
