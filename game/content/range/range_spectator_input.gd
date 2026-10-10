## TEMPORARY range-only tool (B1-05 STOPGAP), NOT the player controller: a free-flying range camera
## that fires RangeDebugGun. Used only while ENV A's CrewController (A1-0x) and weapon runtime
## (A1-08) do not exist; DELETE this file and RangeDebugGun when they land (FiringRange then spawns
## the crew through RangeCrewBridge). Raw Input is read here, hence the `_input` file name
## (check_banned.py rule). Owner: ENV B.
##
## Aim mode (mouse captured): WASD move, Q/E down/up, Shift faster, mouse look, LMB fire, RMB aim
## down sights, R reload, Tab/Esc back to the panels. Gamepad: left stick move, right stick look,
## RT fire, LT aim, X reload, LB/RB down/up, Start/Back back to the panels.
## Panel mode: the camera ignores input except a left click on the range (emits aim_requested).
class_name RangeSpectator
extends Node3D

## A shot was fired; `hits` are RangeTarget.take_hit results.
signal shot_fired(hits: Array[Dictionary])
## The user wants aim mode (true) or the panels (false).
signal aim_requested(on: bool)

const PITCH_LIMIT_DEG: float = 85.0

var tweak: RangeTweak = null
var gun: RangeDebugGun = RangeDebugGun.new()
var camera: Camera3D
var aim_active: bool = false
var attacker_net_id: int = 0

var _mouse_ads: bool = false
var _pad_ads: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _trigger: bool = false
var _pad_trigger: bool = false
var _fired_this_pull: bool = false
var _shot_requested: bool = false


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "RangeCamera"
	camera.fov = tweak.fov_deg
	camera.current = true
	add_child(camera)
	gun.max_range_m = tweak.max_hit_range_m
	_apply_look()


## Camera height above the feet position.
func set_eye(feet: Vector3, eye_height_m: float) -> void:
	position = feet + Vector3.UP * eye_height_m


## Point the camera at a world position (tests and initial framing).
func look_at_point(p: Vector3) -> void:
	var d: Vector3 = (p - global_position).normalized()
	_yaw = atan2(-d.x, -d.z)
	_pitch = asin(clampf(d.y, -1.0, 1.0))
	_apply_look()


## Enter/leave aim mode (FiringRange calls this; it also owns the panels).
func set_aim_active(on: bool) -> void:
	aim_active = on
	_trigger = false
	_pad_trigger = false
	_mouse_ads = false
	_pad_ads = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


## Fire one shot on the next physics tick regardless of input (tests, tooling).
func request_shot() -> void:
	_shot_requested = true


func is_ads() -> bool:
	return _mouse_ads or _pad_ads


func aim_basis() -> Basis:
	return camera.global_transform.basis if camera != null else global_transform.basis


func _unhandled_input(event: InputEvent) -> void:
	if not aim_active:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			aim_requested.emit(true)
		return
	if _handle_aim_event(event):
		get_viewport().set_input_as_handled()


func _handle_aim_event(event: InputEvent) -> bool:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_look(-motion.relative.x * tweak.mouse_look_deg_per_px, -motion.relative.y * tweak.mouse_look_deg_per_px)
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_trigger = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_ads = mb.pressed
		return true
	var reload_pressed: bool = false
	var menu_pressed: bool = false
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		reload_pressed = key.physical_keycode == KEY_R
		menu_pressed = key.physical_keycode == KEY_TAB or key.physical_keycode == KEY_ESCAPE
	var jb: InputEventJoypadButton = event as InputEventJoypadButton
	if jb != null and jb.pressed:
		reload_pressed = jb.button_index == JOY_BUTTON_X
		menu_pressed = jb.button_index in [JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_B]
	if reload_pressed:
		gun.reload()
	if menu_pressed:
		aim_requested.emit(false)
	return reload_pressed or menu_pressed


func _physics_process(delta: float) -> void:
	gun.tick(delta)
	if aim_active:
		_move_and_look(delta)
	var held: bool = aim_active and (_trigger or _pad_trigger)
	if not held:
		_fired_this_pull = false
	var want: bool = _shot_requested or (held and (gun.automatic or not _fired_this_pull))
	if want and gun.can_fire():
		_shot_requested = false
		_fired_this_pull = true
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var hits: Array[Dictionary] = gun.fire(space, camera.global_position, aim_basis(), is_ads(), attacker_net_id)
		shot_fired.emit(hits)
	if camera != null and gun.stats != null:
		var zoom: float = maxf(gun.stats.magnification, 1.0) if is_ads() else 1.0
		camera.fov = tweak.fov_deg / zoom


func _move_and_look(delta: float) -> void:
	var dir: Vector3 = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		dir.y += 1.0
	var stick: Vector2 = _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	dir.x += stick.x
	dir.z += stick.y
	var speed: float = tweak.move_speed_mps
	if Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK):
		speed *= tweak.sprint_mult
	var flat: Basis = Basis(Vector3.UP, _yaw)
	position += flat * Vector3(dir.x, 0.0, dir.z).limit_length(1.0) * speed * delta
	position.y = maxf(position.y + dir.y * speed * delta, 0.3)
	var look: Vector2 = _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if look != Vector2.ZERO:
		_look(-look.x * tweak.stick_look_deg_s * delta, -look.y * tweak.stick_look_deg_s * delta)
	_pad_trigger = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	_pad_ads = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5


func _stick(ax: JoyAxis, ay: JoyAxis) -> Vector2:
	var v: Vector2 = Vector2(Input.get_joy_axis(0, ax), Input.get_joy_axis(0, ay))
	if v.length() < tweak.stick_deadzone:
		return Vector2.ZERO
	return v


func _look(yaw_deg: float, pitch_deg: float) -> void:
	_yaw += deg_to_rad(yaw_deg)
	_pitch = clampf(_pitch + deg_to_rad(pitch_deg), -deg_to_rad(PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
	_apply_look()


func _apply_look() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	if camera != null:
		camera.rotation = Vector3(_pitch, 0.0, 0.0)
