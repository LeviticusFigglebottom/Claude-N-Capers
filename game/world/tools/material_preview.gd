## Material library contact sheet (tool scene, ENV C).
## Lays out every res://world/materials/*.tres (except grey_*) as a panel + sphere under neutral
## light and saves a screenshot. Run:
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --path game --resolution 1920x1080 \
##     res://world/tools/material_preview.tscn -- --out=<path.png|path.jpg>
## Options: --only=<lib_id>[,<lib_id>] (close-up), --env=<neutral|glasshouse>, --cols=<n>,
## --quality=<0..1> (JPEG), --frames=<n>.
## Materials are previewed with world-space triplanar UVs at the library convention
## (1 UV unit = 2 m), so texel density reads exactly as it will on Blender-UV'd geometry.
class_name MaterialPreviewTool
extends Node3D

const MATERIAL_DIR: String = "res://world/materials/"
const GLASSHOUSE_ENV: String = "res://world/lighting/env_glasshouse.tres"
const UV_PER_M: float = 0.5
const CELL_W: float = 2.6
const CELL_H: float = 2.05

var _out_path: String = ""
var _only: PackedStringArray = PackedStringArray()
var _env_name: String = "neutral"
var _cols: int = 6
var _quality: float = 0.82
var _frames: int = 16


func _ready() -> void:
	_parse_args()
	var ids: PackedStringArray = _material_ids()
	if ids.is_empty():
		push_error("material_preview: no materials found")
		get_tree().quit(1)
		return
	_build_lighting()
	var close_up: bool = not _only.is_empty()
	var cols: int = mini(_cols if not close_up else mini(_cols, 3), ids.size())
	var rows: int = int(ceil(float(ids.size()) / float(cols)))
	for i: int in range(ids.size()):
		var col: int = i % cols
		var row: int = i / cols
		var origin := Vector3(
			(float(col) - float(cols - 1) * 0.5) * CELL_W,
			(float(rows - 1) * 0.5 - float(row)) * CELL_H,
			0.0
		)
		_add_sample(ids[i], origin)
	_add_camera(cols, rows)
	for i: int in range(_frames):
		await RenderingServer.frame_post_draw
	_save()
	get_tree().quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",", false)
		elif arg.begins_with("--env="):
			_env_name = arg.substr(6)
		elif arg.begins_with("--cols="):
			_cols = maxi(1, arg.substr(7).to_int())
		elif arg.begins_with("--quality="):
			_quality = clampf(arg.substr(10).to_float(), 0.1, 1.0)
		elif arg.begins_with("--frames="):
			_frames = maxi(1, arg.substr(9).to_int())


func _material_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for f: String in DirAccess.get_files_at(MATERIAL_DIR):
		var name: String = f.trim_suffix(".remap")
		if not name.ends_with(".tres") or name.begins_with("grey_"):
			continue
		var id: String = name.get_basename()
		if _only.is_empty() or id in _only:
			ids.append(id)
	ids.sort()
	return ids


func _preview_material(id: String) -> Material:
	var src: Material = load(MATERIAL_DIR + id + ".tres") as Material
	if src == null:
		push_error("material_preview: cannot load %s" % id)
		return StandardMaterial3D.new()
	var mat: Material = src.duplicate() as Material
	if mat is BaseMaterial3D:
		var bm: BaseMaterial3D = mat as BaseMaterial3D
		bm.uv1_triplanar = true
		bm.uv1_world_triplanar = true
		bm.uv1_scale = Vector3.ONE * UV_PER_M
		bm.uv1_triplanar_sharpness = 4.0
	return mat


func _add_sample(id: String, origin: Vector3) -> void:
	var mat: Material = _preview_material(id)
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.15, 1.15, 0.12)
	panel.mesh = box
	panel.material_override = mat
	panel.position = origin + Vector3(-0.6, 0.12, 0.0)
	add_child(panel)

	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 64
	sphere.rings = 32
	ball.mesh = sphere
	ball.material_override = mat
	ball.position = origin + Vector3(0.68, 0.12, 0.3)
	add_child(ball)

	var label := Label3D.new()
	label.text = id
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 10
	label.modulate = Color(0.92, 0.92, 0.9)
	label.outline_modulate = Color(0.05, 0.05, 0.06)
	label.shaded = false
	label.position = origin + Vector3(0.0, -0.73, 0.4)
	add_child(label)


func _build_lighting() -> void:
	var we := WorldEnvironment.new()
	var env: Environment
	if _env_name == "glasshouse" and ResourceLoader.exists(GLASSHOUSE_ENV):
		env = (load(GLASSHOUSE_ENV) as Environment).duplicate() as Environment
		env.fog_enabled = false
	else:
		env = Environment.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.42, 0.45, 0.5)
		sky_mat.sky_horizon_color = Color(0.62, 0.62, 0.62)
		sky_mat.ground_horizon_color = Color(0.5, 0.49, 0.47)
		sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.2, 0.205, 0.21)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.55
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.ssao_enabled = true
		env.ssao_intensity = 1.0
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.light_energy = 2.2
	key.light_color = Color(1.0, 0.98, 0.95)
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-38.0, -42.0, 0.0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.rotation_degrees = Vector3(-15.0, 140.0, 0.0)
	add_child(fill)


func _add_camera(cols: int, rows: int) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect: float = 16.0 / 9.0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.y > 0.0:
		aspect = vp.x / vp.y
	var need_h: float = float(rows) * CELL_H + 0.3
	var need_w: float = float(cols) * CELL_W + 0.3
	cam.size = maxf(need_h, need_w / aspect)
	cam.position = Vector3(0.0, 0.0, 20.0)
	cam.near = 0.1
	cam.far = 100.0
	add_child(cam)
	cam.make_current()


func _save() -> void:
	if _out_path.is_empty():
		push_warning("material_preview: no --out=<path> given; not saving")
		return
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out_path
	if not path.is_absolute_path() and not path.begins_with("res://") and not path.begins_with("user://"):
		path = OS.get_environment("PWD").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error
	if path.get_extension().to_lower() in ["jpg", "jpeg"]:
		err = img.save_jpg(path, _quality)
	else:
		err = img.save_png(path)
	if err != OK:
		push_error("material_preview: failed to save %s (%s)" % [path, error_string(err)])
	else:
		print("material_preview: saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
