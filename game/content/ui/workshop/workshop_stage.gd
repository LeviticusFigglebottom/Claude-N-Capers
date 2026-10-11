## 3D stage of the weapon workshop (B4-17, pd2_fidelity P6). Owner: ENV B.
## A SubViewportContainer with its own world (the MaskPreview pattern): the assembled WeaponVisual on a
## turntable disc in front of a neutral GSR gradient backdrop, lit by a studio key / fill / rim rig that
## turns with the camera (the look stays the same from every side, like a turntable under fixed lights).
##
## Orbit camera around the weapon's bounding centre:
## * mouse: left drag orbits, right / middle drag pans, wheel zooms;
## * gamepad: right stick orbits, LB + right stick pans, triggers zoom, R3 resets;
## * keyboard: W/A/S/D orbit, Shift + W/A/S/D pan, Q/E (or -/+) zoom, R / Home resets.
## Idle in the overview, the turntable spins slowly (WorkshopTweak.idle_spin_*).
##
## Slot focus (attach-marker preview): focus_slot(mod_type) moves the camera to the attach marker of that
## ModType (WeaponVisual.MARKER_FOR_MOD_TYPE) and shows a small ring + axes gizmo on it. The camera eases
## toward its goal (goal_* fields); settle() jumps there (tests, screenshots).
## Tuning: WorkshopTweak (content/data/ui/workshop_tweak.tres). Visual only.
class_name WorkshopStage
extends SubViewportContainer

signal view_changed()

var tweak: WorkshopTweak
var viewport: SubViewport
var camera: Camera3D
var visual: WeaponVisual
var turntable: MeshInstance3D
var gizmo: Node3D
## Bounding box of the assembled weapon (both guns of a pair) in stage space.
var bounds: AABB = AABB(Vector3.ZERO, Vector3.ONE * 0.1)
## Overview distance that frames the whole weapon.
var overview_distance: float = 1.0
## Camera goal (what input changes) and current state (eases toward the goal).
var goal_target: Vector3 = Vector3.ZERO
var goal_yaw_deg: float = 0.0
var goal_pitch_deg: float = 0.0
var goal_distance: float = 1.0
var target: Vector3 = Vector3.ZERO
var yaw_deg: float = 0.0
var pitch_deg: float = 0.0
var distance: float = 1.0
## Focused ModType (-1 = overview) and the marker node it points at.
var focused_slot: int = -1
var focused_marker: Node3D = null

var _lights: Array[DirectionalLight3D] = []
var _light_angles: Array[Vector2] = []
var _idle_s: float = 0.0
var _orbit_drag: bool = false
var _pan_drag: bool = false


func _init() -> void:
	tweak = WorkshopTweak.load_default()
	stretch = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport.positional_shadow_atlas_size = 1024
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	viewport.add_child(_build_environment())
	_add_light(tweak.key_color, tweak.key_energy, tweak.key_angles_deg, true)
	_add_light(tweak.fill_color, tweak.fill_energy, tweak.fill_angles_deg, false)
	_add_light(tweak.rim_color, tweak.rim_energy, tweak.rim_angles_deg, false)
	turntable = MeshInstance3D.new()
	turntable.name = "Turntable"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.height = 0.02
	disc.radial_segments = 96
	disc.rings = 1
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tweak.turntable_color
	mat.roughness = tweak.turntable_roughness
	mat.metallic = 0.0
	mat.metallic_specular = 0.15
	disc.material = mat
	turntable.mesh = disc
	viewport.add_child(turntable)
	visual = WeaponVisual.new()
	visual.name = "Weapon"
	viewport.add_child(visual)
	gizmo = _build_gizmo()
	gizmo.visible = false
	viewport.add_child(gizmo)
	camera = Camera3D.new()
	camera.fov = tweak.fov_deg
	camera.near = 0.01
	camera.far = 50.0
	camera.current = true
	viewport.add_child(camera)
	reset_view()
	settle()


## Show `def` with `mods` (the applied mods: equipped + stock defaults; WeaponVisual.setup). Keeps the
## current camera angle; re-frames the overview and keeps a slot focus on the new model's marker.
func show_build(def: WeaponDef, mods: Array[WeaponModDef]) -> void:
	var same_weapon: bool = visual.weapon == def and def != null
	visual.setup(def, mods)
	_measure()
	if not same_weapon:
		reset_view()
	elif focused_slot >= 0:
		focus_slot(focused_slot)
	else:
		goal_distance = clampf(goal_distance, _zoom_min(), _zoom_max())
	_place_turntable()


## Back to the whole-weapon overview at the start angle.
func reset_view() -> void:
	focused_slot = -1
	focused_marker = null
	gizmo.visible = false
	goal_target = bounds.get_center()
	goal_yaw_deg = tweak.start_yaw_deg
	goal_pitch_deg = tweak.start_pitch_deg
	goal_distance = overview_distance
	_idle_s = 0.0
	view_changed.emit()


## The attach marker of `mod_type` on the main gun (null when the weapon has none for that type).
func slot_marker(mod_type: int) -> Node3D:
	if not WeaponVisual.MARKER_FOR_MOD_TYPE.has(mod_type):
		return null
	return visual.get_base_marker(WeaponVisual.MARKER_FOR_MOD_TYPE[mod_type])


## Move the camera to `mod_type`'s attach marker and show the gizmo there. False (and the overview)
## when the weapon has no marker for it.
func focus_slot(mod_type: int) -> bool:
	var marker: Node3D = slot_marker(mod_type)
	if marker == null:
		reset_view()
		return false
	focused_slot = mod_type
	focused_marker = marker
	var p: Vector3 = stage_position(marker)
	goal_target = p
	goal_distance = minf(maxf(overview_distance * tweak.focus_distance_mult, tweak.focus_min_distance_m),
			overview_distance * tweak.focus_max_overview_frac)
	# Look at the side the part sits on: right side for +X markers, from above for top rails.
	goal_yaw_deg = _yaw_for(p)
	var above: bool = p.y > bounds.get_center().y
	goal_pitch_deg = clampf(tweak.start_pitch_deg + (tweak.focus_pitch_above_deg if above else tweak.focus_pitch_below_deg),
			-tweak.pitch_limit_deg, tweak.pitch_limit_deg)
	_place_gizmo(marker)
	_idle_s = 0.0
	view_changed.emit()
	return true


## Jump the camera to its goal (no easing).
func settle() -> void:
	target = goal_target
	yaw_deg = goal_yaw_deg
	pitch_deg = goal_pitch_deg
	distance = goal_distance
	_apply_camera()


## Orbit by degrees (input paths and tests).
func orbit(yaw_delta: float, pitch_delta: float) -> void:
	_idle_s = 0.0
	goal_yaw_deg = wrapf(goal_yaw_deg + yaw_delta, -180.0, 180.0)
	if absf(goal_yaw_deg - yaw_deg) > 180.0:
		yaw_deg += 360.0 * signf(goal_yaw_deg - yaw_deg)
	goal_pitch_deg = clampf(goal_pitch_deg + pitch_delta, -tweak.pitch_limit_deg, tweak.pitch_limit_deg)


## Multiply the camera distance (< 1 = closer), within the zoom limits.
func zoom(mult: float) -> void:
	_idle_s = 0.0
	goal_distance = clampf(goal_distance * mult, _zoom_min(), _zoom_max())


## Pan the orbit target in the camera plane by `screen_delta` meters (x right, y up), clamped near the weapon.
func pan(screen_delta: Vector2) -> void:
	_idle_s = 0.0
	var b: Basis = camera.global_transform.basis
	var t: Vector3 = goal_target + b.x * screen_delta.x + b.y * screen_delta.y
	var c: Vector3 = bounds.get_center()
	var lim: float = _radius() * tweak.pan_limit_radii
	var off: Vector3 = t - c
	goal_target = c + (off.normalized() * lim if off.length() > lim else off)


## `node`'s position in stage space (the viewport's world origin).
func stage_position(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else _local_to_stage(node)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_poll_devices(delta)
	_idle_s += delta
	if focused_slot < 0 and _idle_s >= tweak.idle_spin_after_s and not _orbit_drag and not _pan_drag:
		goal_yaw_deg = wrapf(goal_yaw_deg + tweak.idle_spin_deg_s * delta, -180.0, 180.0)
		if absf(goal_yaw_deg - yaw_deg) > 180.0:
			yaw_deg += 360.0 * signf(goal_yaw_deg - yaw_deg)
	var k: float = 1.0 - exp(-tweak.follow_rate * delta)
	target = target.lerp(goal_target, k)
	yaw_deg = lerpf(yaw_deg, goal_yaw_deg, k)
	pitch_deg = lerpf(pitch_deg, goal_pitch_deg, k)
	distance = lerpf(distance, goal_distance, k)
	_apply_camera()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_orbit_drag = mb.pressed
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_pan_drag = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					zoom(1.0 / tweak.zoom_step_mult)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoom(tweak.zoom_step_mult)
		accept_event()
	elif event is InputEventMouseMotion and (_orbit_drag or _pan_drag):
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		if _orbit_drag:
			orbit(-rel.x * tweak.drag_deg_per_px, rel.y * tweak.drag_deg_per_px)
		else:
			var s: float = tweak.pan_m_per_px * distance
			pan(Vector2(-rel.x * s, rel.y * s))
		accept_event()


## Gamepad right stick / LB / triggers / R3 and keyboard W/A/S/D, Shift, Q/E, R. Polled while visible
## (UI navigation keeps the arrows, the left stick and the d-pad).
func _poll_devices(delta: float) -> void:
	var stick: Vector2 = Vector2.ZERO
	var zoom_axis: float = 0.0
	var pan_mode: bool = false
	for device: int in Input.get_connected_joypads():
		var v: Vector2 = Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if v.length() > tweak.stick_deadzone and v.length() > stick.length():
			stick = v
			pan_mode = Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER)
		zoom_axis += Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) - Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
		if Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_STICK):
			reset_view()
	var keys: Vector2 = Vector2(
			_key(KEY_D) - _key(KEY_A),
			_key(KEY_S) - _key(KEY_W))
	if keys != Vector2.ZERO:
		if Input.is_physical_key_pressed(KEY_SHIFT):
			pan(Vector2(keys.x, -keys.y) * tweak.pan_rate * distance * delta)
		else:
			orbit(-keys.x * tweak.key_deg_s * delta, -keys.y * tweak.key_deg_s * delta)
	zoom_axis += _key(KEY_Q) + _key(KEY_MINUS) - _key(KEY_E) - _key(KEY_EQUAL)
	if Input.is_physical_key_pressed(KEY_R) or Input.is_physical_key_pressed(KEY_HOME):
		reset_view()
	if stick != Vector2.ZERO:
		if pan_mode:
			pan(Vector2(stick.x, -stick.y) * tweak.pan_rate * distance * delta)
		else:
			orbit(-stick.x * tweak.stick_deg_s * delta, stick.y * tweak.stick_deg_s * delta)
	if absf(zoom_axis) > tweak.stick_deadzone:
		zoom(pow(tweak.zoom_trigger_rate, clampf(zoom_axis, -1.0, 1.0) * delta))


static func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


## Unit vector from the target toward the camera for (yaw, pitch) degrees: yaw 0 = the weapon's right
## side (+X), positive yaw swings toward the stock (+Z), positive pitch = above.
static func orbit_dir(yaw: float, pitch: float) -> Vector3:
	var y: float = deg_to_rad(yaw)
	var p: float = deg_to_rad(pitch)
	return Vector3(cos(p) * cos(y), sin(p), cos(p) * sin(y))


func _apply_camera() -> void:
	var eye: Vector3 = target + orbit_dir(yaw_deg, pitch_deg) * distance
	camera.transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	for i: int in range(_lights.size()):
		var a: Vector2 = _light_angles[i]
		var from: Vector3 = orbit_dir(yaw_deg + a.y, a.x)
		_lights[i].transform = Transform3D(Basis.looking_at(-from, Vector3.UP), Vector3.ZERO)


func _measure() -> void:
	var box: AABB = AABB()
	var first: bool = true
	for n: Node in visual.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = n as VisualInstance3D
		if not _visible_under(vi, visual):
			continue
		var b: AABB = _local_to_stage_xf(vi) * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	bounds = box if not first else AABB(Vector3(-0.05, -0.05, -0.05), Vector3.ONE * 0.1)
	overview_distance = _radius() / sin(deg_to_rad(tweak.fov_deg) * 0.5) * tweak.frame_margin


func _radius() -> float:
	return maxf(bounds.size.length() * 0.5, 0.05)


func _zoom_min() -> float:
	return minf(overview_distance * tweak.zoom_min_mult, tweak.focus_min_distance_m)


func _zoom_max() -> float:
	return overview_distance * tweak.zoom_max_mult


func _yaw_for(p: Vector3) -> float:
	var c: Vector3 = bounds.get_center()
	# Parts on the left (-X) side are viewed from the left; everything else from the right 3/4 view.
	if p.x < c.x - 0.01:
		return tweak.focus_left_yaw_deg
	return tweak.start_yaw_deg + (tweak.focus_rear_yaw_deg if p.z > c.z else 0.0)


func _place_turntable() -> void:
	var r: float = _radius() * tweak.turntable_radius_mult
	var disc: CylinderMesh = turntable.mesh as CylinderMesh
	disc.top_radius = r
	disc.bottom_radius = r
	var c: Vector3 = bounds.get_center()
	turntable.position = Vector3(c.x, bounds.position.y - tweak.turntable_gap_m - disc.height * 0.5, c.z)


func _place_gizmo(marker: Node3D) -> void:
	var xf: Transform3D = _local_to_stage_xf(marker)
	var s: float = goal_distance
	gizmo.transform = Transform3D(xf.basis.orthonormalized().scaled(Vector3.ONE * s), xf.origin)
	var ring: MeshInstance3D = gizmo.get_node(^"Ring") as MeshInstance3D
	ring.scale = Vector3.ONE * tweak.gizmo_ring_frac
	for axis: String in ["AxisX", "AxisY", "AxisZ"]:
		(gizmo.get_node(NodePath(axis)) as Node3D).scale = Vector3.ONE * tweak.gizmo_axis_frac
	gizmo.visible = true


func _build_gizmo() -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "MarkerGizmo"
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 8
	torus.material = _gizmo_material(tweak.gizmo_color)
	ring.mesh = torus
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)  # ring around the marker's -Z (the mount / bore axis)
	g.add_child(ring)
	var axes: Array[Array] = [
		["AxisX", Vector3.RIGHT, tweak.gizmo_color.lerp(Color(0.95, 0.45, 0.4), 0.7)],
		["AxisY", Vector3.UP, tweak.gizmo_color.lerp(Color(0.5, 0.9, 0.45), 0.7)],
		["AxisZ", Vector3.FORWARD, tweak.gizmo_color],
	]
	for a: Array in axes:
		var axis: Node3D = Node3D.new()
		axis.name = String(a[0])
		var m: MeshInstance3D = MeshInstance3D.new()
		var bar: BoxMesh = BoxMesh.new()
		bar.size = Vector3(0.06, 0.06, 1.0)
		bar.material = _gizmo_material(a[2] as Color)
		m.mesh = bar
		var dir: Vector3 = a[1]
		m.position = dir * 0.5
		if dir != Vector3.FORWARD:
			m.basis = Basis.looking_at(dir, Vector3.UP if dir != Vector3.UP else Vector3.BACK)
		axis.add_child(m)
		g.add_child(axis)
	return g


static func _gizmo_material(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 10
	m.disable_receive_shadows = true
	return m


func _build_environment() -> WorldEnvironment:
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = tweak.backdrop_top
	sky_mat.sky_horizon_color = tweak.backdrop_horizon
	sky_mat.ground_horizon_color = tweak.backdrop_horizon
	sky_mat.ground_bottom_color = tweak.backdrop_floor
	sky_mat.sky_curve = 0.2
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 0.0
	sky_mat.energy_multiplier = tweak.backdrop_energy
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = tweak.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	return we


func _add_light(c: Color, energy: float, angles: Vector2, shadows: bool) -> void:
	var l: DirectionalLight3D = DirectionalLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.shadow_enabled = shadows
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	l.directional_shadow_max_distance = 6.0
	l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	viewport.add_child(l)
	_lights.append(l)
	_light_angles.append(angles)


## Transform of `node` relative to the stage (viewport world), without needing the tree.
func _local_to_stage_xf(node: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != viewport:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _local_to_stage(node: Node3D) -> Vector3:
	return _local_to_stage_xf(node).origin


static func _visible_under(node: Node3D, root: Node) -> bool:
	var n: Node = node
	while n != null and n != root:
		if n is Node3D and not (n as Node3D).visible:
			return false
		n = n.get_parent()
	return true
