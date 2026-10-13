## D1-05: silhouette lineup of every indexed character scene. Owner: ENV D.
##
## Needs a real renderer: `--headless` uses the dummy renderer and cannot draw. Run under xvfb
## (tools/setup/install_render_deps.sh installs xvfb + lavapipe):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --script res://world/characters/_tools/render_lineup.gd [-- --with-tests]
##
## Writes to res://assets/characters/_review/:
## * lineup_godot.png: the characters side by side (front view, A-pose, 1.35 m apart), neutral grey
##   backdrop, key + fill + rim light.
## * lineup_silhouette_30m.png: the same lineup as flat black silhouettes at the size a 1.78 m
##   character has at 30 m through a 1080p, 60-degree vertical FOV camera (~62 px tall), then
##   enlarged 4x (nearest) so the pixels are visible.
## * mask_fit_godot.png: front and side close-ups of each scene's head with the crew mask on
##   Head/Socket (checks the mask fit).
## Test fixtures (`"test": true` in characters.json) are only included with `--with-tests` or when
## nothing else is indexed.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/"
const MASK: String = "res://assets/masks/mask_gilded_heron/mask_gilded_heron.glb"
const SPACING: float = 1.35
const COLOUR_H: int = 900
const SIL_SCALE: int = 4
## 1.78 m at 30 m through a 60-degree vertical FOV on a 1080 px tall screen, in pixels.
const SIL_PX_PER_M: float = 1080.0 / (2.0 * 30.0 * 0.57735)

var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_lineup: --headless has no renderer; run under xvfb-run without --headless")
		quit(2)
		return
	var with_tests: bool = OS.get_cmdline_user_args().has("--with-tests")
	var entries: Array[Dictionary] = []
	for e: Dictionary in Spec.read_index():
		if with_tests or not bool(e.get("test", false)):
			entries.append(e)
	if entries.is_empty():
		entries = Spec.read_index()
	if entries.is_empty():
		push_error("render_lineup: characters.json is empty; run assemble_characters.gd first")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var width: float = SPACING * entries.size()
	await _render_colour(entries, width)
	await _render_silhouette(entries, width)
	await _render_mask_fit(entries)
	print("render_lineup: %d character(s), %d error(s)" % [entries.size(), _errors])
	quit(1 if _errors > 0 else 0)


func _viewport(size: Vector2i, bg: Color) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = bg
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	root.add_child(vp)
	return vp


func _lights(vp: SubViewport) -> void:
	var rigs: Array[Array] = [
		[Vector3(-35.0, 155.0, 0.0), 1.3, true],   # key, front-left (camera is at -Z)
		[Vector3(-15.0, -150.0, 0.0), 0.45, false],  # fill, front-right
		[Vector3(-25.0, 15.0, 0.0), 0.8, false],   # rim, behind
	]
	for r: Array in rigs:
		var l: DirectionalLight3D = DirectionalLight3D.new()
		l.rotation_degrees = r[0]
		l.light_energy = r[1]
		l.shadow_enabled = r[2]
		vp.add_child(l)


## Instances each entry along +X, facing the camera (which looks along +Z from -Z).
func _place(vp: SubViewport, entries: Array[Dictionary], width: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i: int in range(entries.size()):
		var packed: PackedScene = load(String(entries[i]["scene"])) as PackedScene
		if packed == null:
			_errors += 1
			push_error("render_lineup: could not load %s" % entries[i]["scene"])
			continue
		var ch: Node3D = packed.instantiate() as Node3D
		CrowdLod.force_level(ch, false)  # D4-01: the lineup camera is far away; show the full meshes
		ch.position = Vector3(width * 0.5 - SPACING * (i + 0.5), 0.0, 0.0)
		vp.add_child(ch)
		out.append(ch)
	return out


func _camera(vp: SubViewport, centre: Vector3, ortho_h: float, dist: float, side: bool = false) -> void:
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ortho_h
	cam.near = 0.05
	cam.far = dist * 2.0 + 10.0
	vp.add_child(cam)
	if side:
		cam.look_at_from_position(centre + Vector3(dist, 0.0, 0.0), centre, Vector3.UP)
	else:
		cam.look_at_from_position(centre + Vector3(0.0, 0.0, -dist), centre, Vector3.UP)
	cam.current = true


func _grab(vp: SubViewport) -> Image:
	for i: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img


func _save(img: Image, file: String) -> void:
	if img == null or img.is_empty():
		_errors += 1
		push_error("render_lineup: empty image for %s" % file)
		return
	var err: Error = img.save_png(OUT_DIR + file)
	if err != OK:
		_errors += 1
		push_error("render_lineup: could not save %s (%s)" % [file, error_string(err)])
	else:
		print("render_lineup: wrote %s%s (%dx%d)" % [OUT_DIR, file, img.get_width(), img.get_height()])


func _render_colour(entries: Array[Dictionary], width: float) -> void:
	var h_m: float = 2.1
	var w_px: int = maxi(int(COLOUR_H * (width + 0.4) / h_m), 400)
	var vp: SubViewport = _viewport(Vector2i(w_px, COLOUR_H), Color(0.62, 0.63, 0.65))
	_lights(vp)
	_place(vp, entries, width)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(width + 4.0, 6.0)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.52)
	floor_mesh.material_override = mat
	vp.add_child(floor_mesh)
	_camera(vp, Vector3(0.0, h_m * 0.5 - 0.05, 0.0), h_m, 20.0)
	_save(await _grab(vp), "lineup_godot.png")


func _render_silhouette(entries: Array[Dictionary], width: float) -> void:
	var h_m: float = 2.1
	var h_px: int = int(ceil(h_m * SIL_PX_PER_M))
	var w_px: int = int(ceil((width + 0.4) * SIL_PX_PER_M))
	var vp: SubViewport = _viewport(Vector2i(w_px, h_px), Color.WHITE)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	var black: StandardMaterial3D = StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	for ch: Node3D in _place(vp, entries, width):
		for n: Node in ch.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).material_override = black
	_camera(vp, Vector3(0.0, h_m * 0.5 - 0.05, 0.0), h_m, 20.0)
	var img: Image = await _grab(vp)
	if img != null and not img.is_empty():
		img.resize(img.get_width() * SIL_SCALE, img.get_height() * SIL_SCALE, Image.INTERPOLATE_NEAREST)
	_save(img, "lineup_silhouette_30m.png")


func _render_mask_fit(entries: Array[Dictionary]) -> void:
	var packed: PackedScene = load(MASK) as PackedScene
	if packed == null:
		print("render_lineup: no mask glb; skipping mask_fit_godot.png")
		return
	var tile: int = 360
	var sheet: Image = Image.create(tile * 2, tile * entries.size(), false, Image.FORMAT_RGBA8)
	for i: int in range(entries.size()):
		for side: int in [0, 1]:
			var vp: SubViewport = _viewport(Vector2i(tile, tile), Color(0.62, 0.63, 0.65))
			_lights(vp)
			var chars: Array[Node3D] = _place(vp, [entries[i]], SPACING)
			if chars.is_empty():
				vp.queue_free()
				continue
			var ch: Node3D = chars[0]
			ch.position = Vector3.ZERO
			var socket: Node3D = ch.get_node_or_null("Skeleton3D/Head/" + Spec.SOCKET_NAME) as Node3D
			if socket != null:
				socket.add_child(packed.instantiate())
			var skel: Skeleton3D = ch.get_node("Skeleton3D") as Skeleton3D
			var head_y: float = skel.get_bone_global_rest(skel.find_bone("head")).origin.y
			_camera(vp, Vector3(0.0, head_y + 0.09, 0.0), 0.42, 3.0, side == 1)
			var img: Image = await _grab(vp)
			if img != null and not img.is_empty():
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, tile, tile), Vector2i(tile * side, tile * i))
	_save(sheet, "mask_fit_godot.png")
