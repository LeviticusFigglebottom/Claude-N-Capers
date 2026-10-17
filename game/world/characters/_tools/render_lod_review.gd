## D4-01 review: LOD0 (glb meshes) vs LOD2 (Skeleton3D/CrowdLod) for a sample of characters. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game \
##     --script res://world/characters/_tools/render_lod_review.gd
## Writes res://assets/characters/_review/lod_review.png: top row LOD0, bottom row LOD2 (close, ortho), and
## lod_review_30m.png: the same two rows at the pixel size of a 1.78 m character 30 m away (1080p, 60-degree
## vertical FOV, ~62 px tall), enlarged 4x nearest, which is where LOD2 is actually seen.
## `-- --ids=a,b,c --tag=name`: those characters, written as lod_review_<tag>.png / lod_review_<tag>_30m.png.
## `-- --dists=2,10`: also one perspective strip per distance (lod_review_<tag>_<d>m.png): each character alone, seen
## from d metres at eye height 1.65 m with the pixel density of a 1080p 60-degree view, natural LOD selection.
## `-- --out=res://dir/`: write there instead of assets/characters/_review/.
extends SceneTree

const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const OUT_DIR: String = "res://assets/characters/_review/"
const DEFAULT_IDS: Array[String] = ["security_officer", "club_patron", "cartel_gunman", "gallery_patron", "corpsman", "tac_heavy"]
const SPACING: float = 1.2
const SIL_PX_PER_M: float = 1080.0 / (2.0 * 30.0 * 0.57735)

var _ids: Array[String] = DEFAULT_IDS.duplicate()
var _name: String = "lod_review"
var _dists: Array[float] = []
var _out: String = OUT_DIR


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			_ids.assign(arg.trim_prefix("--ids=").split(","))
		elif arg.begins_with("--tag="):
			_name = "lod_review_" + arg.trim_prefix("--tag=")
		elif arg.begins_with("--dists="):
			for d: String in arg.trim_prefix("--dists=").split(","):
				_dists.append(float(d))
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_run.call_deferred()


func _run() -> void:
	var width: float = SPACING * _ids.size()
	var close: Image = await _render(Vector2i(int(width / 4.4 * 1600.0), 1600))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	close.save_png(_out + _name + ".png")
	var h_px: int = int(ceil(4.4 * SIL_PX_PER_M))
	var far: Image = await _render(Vector2i(int(ceil(width * SIL_PX_PER_M)), h_px), false)
	far.resize(far.get_width() * 4, far.get_height() * 4, Image.INTERPOLATE_NEAREST)
	far.save_png(_out + _name + "_30m.png")
	for d: float in _dists:
		var strip: Image = await _render_perspective(d)
		strip.save_png(_out + "%s_%dm.png" % [_name, int(d)])
	print("render_lod_review: wrote %s.png, %s_30m.png" % [_name, _name])
	quit(0)


## Every character alone at `d` m (camera at eye height, looking at its middle), tiles side by side; the far tiles
## are enlarged (nearest) so a strip is ~800 px tall.
func _render_perspective(d: float) -> Image:
	var tile_h: int = int(ceil(2.1 / (2.0 * d * tan(deg_to_rad(30.0))) * 1080.0))
	var tile_w: int = int(ceil(float(tile_h) * 0.95))
	var scale: int = maxi(1, 800 / tile_h)
	var strip: Image = Image.create(tile_w * scale * _ids.size(), tile_h * scale, false, Image.FORMAT_RGBA8)
	for i: int in range(_ids.size()):
		var vp: SubViewport = _lit_viewport(Vector2i(tile_w, tile_h), true)
		var packed: PackedScene = load("res://world/characters/%s/%s.tscn" % [_ids[i], _ids[i]]) as PackedScene
		var ch: Node3D = packed.instantiate() as Node3D
		vp.add_child(ch)
		var cam: Camera3D = Camera3D.new()
		cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(30.0)) * float(tile_h) / 1080.0))
		cam.near = 0.05
		cam.far = 80.0
		vp.add_child(cam)
		cam.look_at_from_position(Vector3(0.0, 1.65, -d), Vector3(0.0, 0.95, 0.0), Vector3.UP)
		cam.current = true
		for _f: int in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		vp.queue_free()
		img.convert(Image.FORMAT_RGBA8)
		if scale > 1:
			img.resize(tile_w * scale, tile_h * scale, Image.INTERPOLATE_NEAREST)
		strip.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * tile_w * scale, 0))
	return strip


func _lit_viewport(size: Vector2i, msaa: bool) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X if msaa else Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	root.add_child(vp)
	for r: Array in [[Vector3(-35.0, 155.0, 0.0), 1.3], [Vector3(-15.0, -150.0, 0.0), 0.45], [Vector3(-25.0, 15.0, 0.0), 0.8]]:
		var l: DirectionalLight3D = DirectionalLight3D.new()
		l.rotation_degrees = r[0]
		l.light_energy = r[1]
		vp.add_child(l)
	return vp


func _render(size: Vector2i, msaa: bool = true) -> Image:
	var vp: SubViewport = _lit_viewport(size, msaa)
	var width: float = SPACING * _ids.size()
	for row: int in range(2):
		for i: int in range(_ids.size()):
			var packed: PackedScene = load("res://world/characters/%s/%s.tscn" % [_ids[i], _ids[i]]) as PackedScene
			var ch: Node3D = packed.instantiate() as Node3D
			CrowdLod.force_level(ch, row == 1)
			ch.position = Vector3(width * 0.5 - SPACING * (i + 0.5), 2.2 - 2.2 * row, 0.0)
			vp.add_child(ch)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.4
	cam.near = 0.05
	cam.far = 50.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 2.15, -20.0), Vector3(0.0, 2.15, 0.0), Vector3.UP)
	cam.current = true
	for i: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img
