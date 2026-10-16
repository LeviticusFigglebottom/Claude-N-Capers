## 3D mask preview for the mask screen (B2-03). Owner: ENV B. A SubViewportContainer with its own
## world: camera in front of the mask (the mask faces -Z), key + rim lights, slow auto spin.
## Turn it with a mouse drag, the right stick, or ui_left/ui_right/ui_up/ui_down while focused.
## Tuning: MaskTweak (content/data/masks/mask_tweak.tres).
class_name MaskPreview
extends SubViewportContainer

const STICK_DEADZONE: float = 0.2

var viewport: SubViewport
var pivot: Node3D
var camera: Camera3D
## The current MaskComposer.instantiate() node (null = nothing shown).
var mask_node: Node3D
var yaw_deg: float = 0.0
var pitch_deg: float = 0.0
var _tweak: MaskTweak
var _idle_s: float = 0.0
var _dragging: bool = false


func _init() -> void:
	_tweak = MaskCatalog.tweak()
	yaw_deg = _tweak.preview_start_yaw_deg
	stretch = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	# D-115: focus is always visible (style.md §5); the viewport texture has no "focus" StyleBox of its own.
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _tweak.preview_background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-25.0), deg_to_rad(200.0), 0.0)), Vector3.ZERO)
	key.light_energy = 1.4
	viewport.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-10.0), deg_to_rad(-30.0), 0.0)), Vector3.ZERO)
	rim.light_energy = 0.7
	rim.light_color = Color(0.75, 0.82, 1.0)
	viewport.add_child(rim)
	pivot = Node3D.new()
	pivot.name = "Pivot"
	viewport.add_child(pivot)
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.near = 0.02
	camera.far = 10.0
	var eye: Vector3 = Vector3(0.0, 0.02, -_tweak.preview_camera_distance_m)
	camera.transform = Transform3D(Basis.looking_at(-eye, Vector3.UP), eye)
	camera.current = true
	viewport.add_child(camera)


## Show a MaskDef (null clears the preview).
func show_def(def: MaskDef) -> void:
	if mask_node != null:
		mask_node.queue_free()
		mask_node = null
	if def == null:
		return
	mask_node = MaskComposer.instantiate(def)
	pivot.add_child(mask_node)


func _process(delta: float) -> void:
	var stick: Vector2 = Vector2.ZERO
	for device: int in Input.get_connected_joypads():
		var v: Vector2 = Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if v.length() > STICK_DEADZONE and v.length() > stick.length():
			stick = v
	if stick != Vector2.ZERO and is_visible_in_tree():
		turn(stick.x * _tweak.preview_stick_deg_s * delta, stick.y * _tweak.preview_stick_deg_s * delta)
	elif not _dragging:
		_idle_s += delta
		if _idle_s >= _tweak.preview_idle_s:
			yaw_deg = wrapf(yaw_deg + _tweak.preview_spin_deg_s * delta, -180.0, 180.0)
			pitch_deg = move_toward(pitch_deg, 0.0, _tweak.preview_spin_deg_s * delta)
	_apply()


## D-115: the theme's cyan focus ring over the preview while it has focus (d-pad left / right turn it).
func _draw() -> void:
	if has_focus():
		draw_style_box(UiThemeFactory.focus_ring(0), Rect2(Vector2.ZERO, size))


## Manual turn in degrees; pauses the auto spin for MaskTweak.preview_idle_s.
func turn(yaw_delta: float, pitch_delta: float) -> void:
	_idle_s = 0.0
	yaw_deg = wrapf(yaw_deg + yaw_delta, -180.0, 180.0)
	var lim: float = _tweak.preview_pitch_limit_deg
	pitch_deg = clampf(pitch_deg + pitch_delta, -lim, lim)
	_apply()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		if _dragging:
			grab_focus()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		turn(rel.x * _tweak.preview_drag_deg_per_px, rel.y * _tweak.preview_drag_deg_per_px)
		accept_event()
	elif event.is_action(&"ui_left") or event.is_action(&"ui_right"):
		if event.is_pressed():
			turn(_tweak.preview_key_step_deg * (-1.0 if event.is_action(&"ui_left") else 1.0), 0.0)
		accept_event()


func _apply() -> void:
	if pivot != null:
		pivot.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)
