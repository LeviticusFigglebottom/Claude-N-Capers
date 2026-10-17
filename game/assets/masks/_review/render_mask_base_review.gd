## Review sheet for customisable mask bases (ENV D). One PNG per base, written next to this script:
## res://assets/masks/_review/mask_base_<name>_review.png.
## * top row: the mask alone, tinted with the game's mask shader (front, 3/4 both sides, side, from
##   above, back);
## * bottom row: the mask on the crew Head/Socket of three crew heads (front and 3/4 each).
##
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --path game --script res://assets/masks/_review/render_mask_base_review.gd -- vault_dial keystone bust
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const SHADER_PATH: String = "res://content/masks/mask_surface.gdshader"
const OUT_DIR: String = "res://assets/masks/_review/"
const TILE: int = 400
const CREW: Array[String] = ["crew_rook", "crew_sable", "crew_dutch"]
## Review tints (colour, roughness, metallic) per base; anything else is a neutral light grey.
const TINTS: Dictionary = {
	"vault_dial": [Color(0.46, 0.48, 0.50), 0.38, 0.85],
	"keystone": [Color(0.60, 0.53, 0.42), 0.85, 0.0],
	"bust": [Color(0.40, 0.39, 0.37), 0.55, 0.0],
}

var _errors: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("render_mask_base_review: --headless has no renderer; run under xvfb-run")
		quit(2)
		return
	var names: PackedStringArray = OS.get_cmdline_user_args()
	if names.is_empty():
		push_error("render_mask_base_review: pass base names after --, e.g. -- vault_dial bust")
		quit(2)
		return
	for n: String in names:
		await _render_base(n)
	quit(1 if _errors > 0 else 0)


func _material(base_name: String) -> ShaderMaterial:
	var t: Array = TINTS.get(base_name, [Color(0.8, 0.8, 0.8), 0.5, 0.0])
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load(SHADER_PATH) as Shader
	sm.set_shader_parameter(&"color_a", t[0])
	sm.set_shader_parameter(&"color_b", t[0])
	sm.set_shader_parameter(&"roughness_value", t[1])
	sm.set_shader_parameter(&"metallic_value", t[2])
	sm.set_shader_parameter(&"detail_strength", 0.0)
	return sm


func _mask(base_name: String) -> Node3D:
	var path: String = "res://assets/masks/mask_base_%s/mask_base_%s.glb" % [base_name, base_name]
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_errors += 1
		push_error("render_mask_base_review: could not load %s" % path)
		return null
	var inst: Node3D = packed.instantiate() as Node3D
	var mat: ShaderMaterial = _material(base_name)
	for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = mat
	return inst


func _viewport() -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(TILE, TILE)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.40, 0.41, 0.44)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	vp.add_child(env)
	for r: Array in [[Vector3(-35.0, 155.0, 0.0), 1.4, true], [Vector3(-15.0, -150.0, 0.0), 0.45, false],
			[Vector3(-25.0, 15.0, 0.0), 0.8, false]]:
		var l: DirectionalLight3D = DirectionalLight3D.new()
		l.rotation_degrees = r[0]
		l.light_energy = r[1]
		l.shadow_enabled = r[2]
		vp.add_child(l)
	root.add_child(vp)
	return vp


## Perspective camera orbiting ``centre``: yaw 0 = in front (-Z), + = toward the wearer's left (+X).
func _camera(vp: SubViewport, centre: Vector3, yaw_deg: float, pitch_deg: float, dist: float, fov: float) -> void:
	var cam: Camera3D = Camera3D.new()
	cam.fov = fov
	cam.near = 0.02
	cam.far = 20.0
	vp.add_child(cam)
	var yaw: float = deg_to_rad(yaw_deg)
	var pitch: float = deg_to_rad(pitch_deg)
	var dir: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	cam.look_at_from_position(centre + dir * dist, centre, Vector3.UP)
	cam.current = true


func _grab(vp: SubViewport) -> Image:
	for i: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _crew_entry(id: String) -> Dictionary:
	for e: Dictionary in Spec.read_index():
		if String(e.get("id", "")) == id:
			return e
	return {}


func _render_base(base_name: String) -> void:
	var views: Array[Array] = [[0.0, 0.0], [40.0, 8.0], [-40.0, 8.0], [90.0, 0.0], [0.0, 55.0], [160.0, 10.0]]
	var crew_views: Array[float] = [0.0, 35.0]
	var sheet: Image = Image.create(TILE * views.size(), TILE * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.3, 0.32))
	for i: int in range(views.size()):
		var vp: SubViewport = _viewport()
		var m: Node3D = _mask(base_name)
		if m == null:
			vp.queue_free()
			return
		vp.add_child(m)
		_camera(vp, Vector3(0.0, -0.01, -0.02), views[i][0], views[i][1], 0.95, 17.0)
		var img: Image = await _grab(vp)
		if img != null and not img.is_empty():
			sheet.blit_rect(img, Rect2i(0, 0, TILE, TILE), Vector2i(TILE * i, 0))
	var col: int = 0
	for cid: String in CREW:
		var e: Dictionary = _crew_entry(cid)
		if e.is_empty():
			_errors += 1
			push_error("render_mask_base_review: no %s in characters.json" % cid)
			continue
		for yaw: float in crew_views:
			var vp: SubViewport = _viewport()
			var packed: PackedScene = load(String(e["scene"])) as PackedScene
			var ch: Node3D = packed.instantiate() as Node3D
			CrowdLod.force_level(ch, false)
			vp.add_child(ch)
			var socket: Node3D = ch.get_node_or_null("Skeleton3D/Head/" + Spec.SOCKET_NAME) as Node3D
			if socket == null:
				_errors += 1
				push_error("render_mask_base_review: %s has no Head/Socket" % cid)
			else:
				socket.add_child(_mask(base_name))
			var skel: Skeleton3D = ch.get_node("Skeleton3D") as Skeleton3D
			var head_y: float = skel.get_bone_global_rest(skel.find_bone("head")).origin.y
			_camera(vp, Vector3(0.0, head_y + 0.06, 0.0), yaw, 4.0, 1.5, 17.0)
			var img: Image = await _grab(vp)
			if img != null and not img.is_empty():
				sheet.blit_rect(img, Rect2i(0, 0, TILE, TILE), Vector2i(TILE * col, TILE))
			col += 1
	var file: String = OUT_DIR + "mask_base_%s_review.png" % base_name
	var err: Error = sheet.save_png(file)
	if err != OK:
		_errors += 1
		push_error("render_mask_base_review: could not save %s (%s)" % [file, error_string(err)])
	else:
		print("render_mask_base_review: wrote %s" % file)
