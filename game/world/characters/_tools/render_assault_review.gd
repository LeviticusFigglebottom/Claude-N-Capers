## PO6-17: windowed review of the assault-event clips (rappel_hang / rappel_descend / rappel_land, heli_door_idle /
## heli_door_aim / heli_door_fire, van_exit, breach_place / breach_standback). Owner: ENV D.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy \
##     --rendering-driver opengl3 --path game --script res://world/characters/_tools/render_assault_review.gd
##
## A Tac Light officer per tile with review-only proxies at the placement documented in char_anim_humanoid/SOURCE.txt
## (`rappel_assault`, `heli_door_sill`, `van_exit_step`, `breach_charge`): the vertical rope line, the helicopter
## cabin floor / bench / roof liner, the 0.45 m van step (moved by `curve.van_exit` like A moves the root), the
## breach wall and charge; a box rifle on HandR/Socket for the heli clips. Writes
## res://assets/characters/_review/po6_17_assault_windowed.png.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
const OUT_DIR: String = "res://assets/characters/_review/"
const OUT_FILE: String = "po6_17_assault_windowed.png"
const CHAR: String = "char_tac_light"
## _anim_assault constants (Godot root space, -Z forward)
const ROPE_Z: float = -0.225
const HELI_SILL: float = 0.40
const HELI_HEADROOM: float = 1.229
const HELI_ROOT: Vector3 = Vector3(0.50, -0.344, 0.15)
const VAN_STEP_Y: float = 0.45
const VAN_EDGE: float = 0.42
const VAN_BACK: float = 0.60
const BREACH_WALL: float = 0.45
const STANDBACK_X: float = 0.80
## rows of [clip, time (s), view yaw (deg, camera around the character)]
const ROWS: Array = [
	[["rappel_hang", 0.0, 60.0], ["rappel_descend", 0.0, 60.0], ["rappel_land", 0.2, 80.0], ["rappel_land", 1.0, 60.0]],
	[["heli_door_idle", 0.0, 50.0], ["heli_door_aim", 0.0, 50.0], ["heli_door_fire", 0.033, 90.0],
		["heli_door_aim", 0.0, 150.0]],
	[["van_exit", 0.0, 90.0], ["van_exit", 0.433, 90.0], ["van_exit", 0.8, 90.0], ["van_exit", 1.2, 60.0]],
	[["breach_place", 0.0, 120.0], ["breach_place", 0.933, 90.0], ["breach_standback", 0.7, 150.0],
		["breach_standback", 1.0, 150.0]],
]
const TILE: Vector2i = Vector2i(400, 400)

var _vp: SubViewport
var _cam: Camera3D
var _label: Label3D
var _props: Node3D
var _errors: int = 0
var _curves: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_assault_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_read_curves()
	_stage()
	var cols: int = 4
	var sheet: Image = Image.create(TILE.x * cols, TILE.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	var body: Node3D = (load(Spec.scene_path(CHAR)) as PackedScene).instantiate() as Node3D
	CrowdLod.force_level(body, false)
	_vp.add_child(body)
	var player: AnimationPlayer = body.get_node("AnimationPlayer") as AnimationPlayer
	var socket: Node3D = body.get_node_or_null("Skeleton3D/HandR/Socket") as Node3D
	var gun: MeshInstance3D = _rifle()
	if socket != null:
		socket.add_child(gun)
	for r: int in range(ROWS.size()):
		var row: Array = ROWS[r]
		for c: int in range(row.size()):
			var shot: Array = row[c]
			var clip: String = String(shot[0])
			var anim: String = "humanoid/" + clip
			if not player.has_animation(anim):
				_errors += 1
				push_error("render_assault_review: %s has no %s" % [CHAR, anim])
				continue
			player.play(anim)
			player.seek(float(shot[1]), true)
			player.pause()
			gun.visible = clip.begins_with("heli_door")
			_build_props(clip, float(shot[1]))
			_label.text = "%s f%d" % [clip, roundi(float(shot[1]) * 30.0)]
			var img: Image = await _grab(_view(clip, float(shot[2])))
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(TILE.x * c, TILE.y * r))
	var err: Error = sheet.save_png(OUT_DIR + OUT_FILE)
	if err != OK:
		_errors += 1
		push_error("render_assault_review: could not save %s (%s)" % [OUT_FILE, error_string(err)])
	else:
		print("render_assault_review: wrote %s%s" % [OUT_DIR, OUT_FILE])
	quit(1 if _errors > 0 else 0)


func _read_curves() -> void:
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		for key: String in ["curve.van_exit", "curve.breach_standback"]:
			if line.begins_with(key + ":"):
				var m: RegExMatch = RegEx.create_from_string("root_m=([0-9.,]+)").search(line)
				if m != null:
					var vals: Array[float] = []
					for v: String in m.get_string(1).split(","):
						vals.append(v.to_float())
					_curves[key] = vals


## Root travel still to come at time t (the props are world-fixed; A moves the root along the curve).
func _remaining(key: String, total: float, t: float) -> float:
	var vals: Array = _curves.get(key, [])
	if vals.is_empty():
		_errors += 1
		push_error("render_assault_review: SOURCE.txt has no %s" % key)
		return 0.0
	var f: int = clampi(roundi(t * 30.0), 0, vals.size() - 1)
	return total - float(vals[f])


func _view(clip: String, yaw_deg: float) -> Transform3D:
	var target: Vector3 = Vector3(0.0, 0.9, -0.1)
	var dist: float = 3.2
	if clip.begins_with("rappel") and clip != "rappel_land":
		target = Vector3(0.0, 1.7, -0.1)
		dist = 3.6
	elif clip.begins_with("heli"):
		target = Vector3(0.0, 0.65, -0.2)
		dist = 2.8
	elif clip == "van_exit":
		target = Vector3(0.0, 0.9, 0.2)
		dist = 3.4
	_label.position = target + Vector3(0.0, 1.05, 0.0)
	var a: float = deg_to_rad(yaw_deg)
	var eye: Vector3 = target + Vector3(sin(a) * dist, 0.45, -cos(a) * dist)
	return Transform3D.IDENTITY.looking_at(target - eye, Vector3.UP).translated(eye)


func _build_props(clip: String, t: float) -> void:
	for ch: Node in _props.get_children():
		ch.free()
	if clip.begins_with("rappel"):
		var top: float = 3.0
		_add_box(Vector3(0.014, top + 0.3, 0.014), Vector3(0.0, (top - 0.3) / 2.0, ROPE_Z), Color(0.9, 0.75, 0.2))
	elif clip.begins_with("heli_door"):
		# cabin floor (root plane) up to the door edge, the rear bench, the roof liner
		_add_box(Vector3(1.6, 0.04, 1.6), Vector3(0.0, -0.02, -HELI_SILL + 0.8), Color(0.25, 0.27, 0.32))
		_add_box(Vector3(0.44, -HELI_ROOT.y, 1.44), Vector3(-HELI_ROOT.x - 0.05, -HELI_ROOT.y / 2.0, 0.53 - HELI_ROOT.z),
			Color(0.2, 0.2, 0.22))
		_add_box(Vector3(1.6, 0.03, 1.6), Vector3(0.0, HELI_HEADROOM + 0.015, -HELI_SILL + 0.8), Color(0.75, 0.75, 0.78))
	elif clip == "van_exit":
		var edge: float = -(-VAN_EDGE + _remaining("curve.van_exit", VAN_BACK, t))
		_add_box(Vector3(1.4, VAN_STEP_Y, 0.8), Vector3(0.0, VAN_STEP_Y / 2.0, edge + 0.4), Color(0.12, 0.16, 0.27))
		_add_box(Vector3(1.4, 0.05, 0.8), Vector3(0.0, VAN_STEP_Y + 1.30, edge + 0.4), Color(0.12, 0.16, 0.27))
	elif clip.begins_with("breach"):
		var dx: float = STANDBACK_X - _remaining("curve.breach_standback", STANDBACK_X, t) if clip == "breach_standback" else 0.0
		_add_box(Vector3(2.6, 2.4, 0.05), Vector3(dx, 1.2, -BREACH_WALL - 0.025), Color(0.8, 0.78, 0.72))
		if clip == "breach_standback" or t >= 28.0 / 30.0:
			_add_box(Vector3(0.16, 0.12, 0.04), Vector3(dx, 1.1, -BREACH_WALL + 0.02), Color(0.3, 0.45, 0.3))


func _add_box(size: Vector3, pos: Vector3, col: Color) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	m.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = pos
	_props.add_child(m)


## Review-only rifle: a 0.85 m box along the socket's -Z (muzzle), the grip at the origin.
func _rifle() -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.05, 0.09, 0.85)
	m.mesh = box
	m.position = Vector3(0.0, 0.06, -0.2)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.09)
	m.material_override = mat
	return m


func _stage() -> void:
	_vp = SubViewport.new()
	_vp.size = TILE
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, 150.0, 0.0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_vp.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -40.0, 0.0)
	fill.light_energy = 0.4
	_vp.add_child(fill)
	var vis: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	vis.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.48, 0.5)
	vis.material_override = mat
	vis.position = Vector3(0.0, -0.001, 0.0)
	_vp.add_child(vis)
	# root marker: a thin red cross on the floor at the character root
	for axis: Vector3 in [Vector3(0.3, 0.004, 0.02), Vector3(0.02, 0.004, 0.3)]:
		var m: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = axis
		m.mesh = box
		var mm: StandardMaterial3D = StandardMaterial3D.new()
		mm.albedo_color = Color(0.9, 0.2, 0.1)
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mm
		_vp.add_child(m)
	_props = Node3D.new()
	_vp.add_child(_props)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 2.9, 0.0)
	_label.pixel_size = 0.003
	_label.font_size = 40
	_label.outline_size = 8
	_label.modulate = Color(1.0, 1.0, 1.0)
	_label.no_depth_test = true
	_vp.add_child(_label)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_vp.add_child(_cam)
	_cam.current = true


func _grab(view: Transform3D) -> Image:
	_cam.global_transform = view
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
