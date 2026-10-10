## Props review sheet (C1-07, ENV C): renders every catalog prop/prefab visual in its own lit cell
## (3/4 front view, contact floor, backdrop wall for wall items, ceiling for ceiling items) and saves
## one page per N props. Run (Vulkan via lavapipe under xvfb):
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --path game --resolution 1920x1080 \
##     res://world/props/tools/prop_lineup.tscn -- --out=docs/levels/_props/props_v1 [--only=a,b] \
##     [--group=office] [--cols=6] [--rows=3] [--frames=12]
## Output: <out>_<page>.jpg (two-digit page numbers).
class_name PropLineupTool
extends Control

const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const FLOOR_MAT: String = "res://world/materials/concrete.tres"
const WALL_MAT: String = "res://world/materials/plaster_painted.tres"

var _out: String = ""
var _only: PackedStringArray = PackedStringArray()
var _group: String = ""
var _cols: int = 6
var _rows: int = 3
var _frames: int = 12
var _quality: float = 0.85


func _ready() -> void:
	_parse_args()
	var catalog: Dictionary = PropCatalog.load_catalog()
	var ids: Array[String] = []
	for k: Variant in catalog.keys():
		var id: String = String(k)
		var e: Dictionary = catalog[k]
		if not _only.is_empty() and not (id in _only):
			continue
		if _group != "" and String(e.get("group", "")) != _group:
			continue
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ga: String = String((catalog[a] as Dictionary).get("group", ""))
		var gb: String = String((catalog[b] as Dictionary).get("group", ""))
		return a < b if ga == gb else ga < gb)
	var per_page: int = _cols * _rows
	var pages: int = int(ceil(float(ids.size()) / float(per_page)))
	for page: int in range(pages):
		var grid: GridContainer = _make_grid()
		for i: int in range(page * per_page, mini(ids.size(), (page + 1) * per_page)):
			grid.add_child(_cell(ids[i], catalog[ids[i]]))
		for f: int in range(_frames):
			await RenderingServer.frame_post_draw
		_save(page)
		grid.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",", false)
		elif arg.begins_with("--group="):
			_group = arg.substr(8)
		elif arg.begins_with("--cols="):
			_cols = maxi(1, arg.substr(7).to_int())
		elif arg.begins_with("--rows="):
			_rows = maxi(1, arg.substr(7).to_int())
		elif arg.begins_with("--frames="):
			_frames = maxi(1, arg.substr(9).to_int())


func _make_grid() -> GridContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.135, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = _cols
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	bg.add_child(grid)
	grid.tree_exiting.connect(bg.queue_free)
	return grid


func _cell(id: String, e: Dictionary) -> Control:
	var size: Vector2 = get_viewport_rect().size
	var cw: int = int(size.x / float(_cols)) - 4
	var ch: int = int(size.y / float(_rows)) - 4
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(cw, ch - 26)
	svc.stretch = true
	box.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(cw, ch - 26)
	svc.add_child(vp)
	_stage(vp, e)
	var label := Label.new()
	label.text = "%s  [%s%s]" % [id, String(e.get("kind", "")), ("/" + String(e.get("mount", ""))) if String(e.get("mount", "")) != "" else ""]
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.88))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(cw, 26)
	box.add_child(label)
	return box


func _stage(vp: SubViewport, e: Dictionary) -> void:
	var root := Node3D.new()
	vp.add_child(root)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.52, 0.56)
	sky_mat.sky_horizon_color = Color(0.85, 0.8, 0.72)
	sky_mat.ground_horizon_color = Color(0.45, 0.42, 0.38)
	sky_mat.ground_bottom_color = Color(0.16, 0.15, 0.14)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.205, 0.21)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.7
	key.light_color = Color(1.0, 0.95, 0.88)
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.light_color = Color(0.8, 0.87, 1.0)
	fill.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	root.add_child(fill)

	var scene: PackedScene = load(String(e["scene"])) as PackedScene
	var prop: Node3D = scene.instantiate() as Node3D
	root.add_child(prop)
	var a: Array = e["aabb"]
	var bb := AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]))
	var mount: String = String(e.get("mount", ""))
	var big: float = maxf(bb.size.length(), 0.25)
	if mount == "ceiling":
		_plane(root, Vector3(0.0, 0.0, 0.0), Vector3(big * 4.0, 0.02, big * 4.0), WALL_MAT, true)
	else:
		_plane(root, Vector3(0.0, minf(bb.position.y, 0.0) - 0.01, 0.0), Vector3(big * 6.0, 0.02, big * 6.0), FLOOR_MAT, false)
	if mount == "wall" or String(e.get("place", "")) in ["wall", "corner"] or String(e.get("kind", "")) == "door":
		var back: float = bb.end.z + 0.011 if mount != "wall" else 0.011
		if String(e.get("kind", "")) == "door" or String(e.get("prefab", "")) in ["door", "window"]:
			back = 0.5
		_plane(root, Vector3(0.0, bb.get_center().y, back + 0.01), Vector3(big * 6.0, big * 4.0, 0.02), WALL_MAT, false)
	var cam := Camera3D.new()
	cam.fov = 32.0
	var c: Vector3 = bb.get_center()
	var dir := Vector3(0.62, 0.42, -1.0).normalized()
	if mount == "ceiling":
		dir = Vector3(0.5, -0.55, -1.0).normalized()
	var dist: float = big * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.12
	cam.near = 0.01
	cam.far = 200.0
	cam.current = true
	cam.look_at_from_position(c + dir * dist, c, Vector3.UP)
	root.add_child(cam)


func _plane(root: Node3D, pos: Vector3, size: Vector3, mat_path: String, ceiling: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat: BaseMaterial3D = (load(mat_path) as BaseMaterial3D).duplicate() as BaseMaterial3D
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.5
	mi.material_override = mat
	mi.position = pos + (Vector3(0.0, size.y * 0.5, 0.0) if ceiling else Vector3(0.0, -size.y * 0.5, 0.0) if size.y < 0.05 else Vector3.ZERO)
	root.add_child(mi)


func _save(page: int) -> void:
	if _out.is_empty():
		return
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s_%02d.jpg" % [_out, page + 1]
	if not path.is_absolute_path() and not path.begins_with("res://"):
		path = OS.get_environment("PWD").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = img.save_jpg(path, _quality)
	print("prop_lineup: %s %s" % [path, error_string(err)])
