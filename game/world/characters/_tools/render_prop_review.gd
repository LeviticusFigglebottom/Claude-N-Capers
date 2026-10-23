## D's hero-prop review (the safehouse props, C4-03 G2): for each scene, its visual AABB (meshes only; the collision
## body is reported apart), its nodes, and a 4-view sheet (front 3/4, front, side, back 3/4) on a neutral floor with a
## 1.8 m reference post. Writes <out>/<id>_review.png and <out>/props_review_log.txt.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 960x540 --path game res://world/characters/_tools/render_prop_review.tscn -- --out=/abs/dir \
##     --scenes=res://assets/props/prop_sh_jukebox/prop_sh_jukebox.glb,...   [--wall=<id>,...]
## ``--light=night``: a dark stage so emissive signs read in their hue (writes <id>_review_night.png). Props under
## 1 m across are framed on their own AABB, without the 1.8 m post (its size is in the log).
## Wall props (``--wall``) are shown against a backdrop at y = 0 with the pivot at 1.5 m. ``--focus=x,y,z,r`` frames
## every view on that point (scene space) at r metres instead of the whole AABB (close-ups of character details).
## ``--lift=m`` raises every model by m (hand-held items whose origin is the grip, not the base).
## Owner: ENV D.
extends Node3D

const TILE: Vector2i = Vector2i(480, 360)

var _out: String = ""
var _scenes: PackedStringArray = []
var _wall: PackedStringArray = []
var _focus: Vector4 = Vector4.ZERO
var _lift: float = 0.0
## --light=night: a dark stage (dim ambient, a weak cool key): emissive signs and lamps read in their own hue
var _night: bool = false
var _log: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--scenes="):
			_scenes = a.trim_prefix("--scenes=").split(",", false)
		elif a.begins_with("--wall="):
			_wall = a.trim_prefix("--wall=").split(",", false)
		elif a == "--light=night":
			_night = true
		elif a.begins_with("--lift="):
			_lift = a.trim_prefix("--lift=").to_float()
		elif a.begins_with("--focus="):
			var f: PackedFloat64Array = a.trim_prefix("--focus=").split_floats(",")
			_focus = Vector4(f[0], f[1], f[2], f[3])
	if _out == "":
		_out = OS.get_user_data_dir() + "/prop_review"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_stage()
	for path: String in _scenes:
		await _review(path)
	var f: FileAccess = FileAccess.open(_out + "/props_review_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	get_tree().quit(0)


func _stage() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.78, 0.79, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.52)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	if _night:
		env.environment.background_color = Color(0.03, 0.03, 0.05)
		env.environment.ambient_light_color = Color(0.12, 0.12, 0.16)
		env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		sun.light_color = Color(0.6, 0.65, 0.85)
		sun.light_energy = 0.12
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor_mi.mesh = pm
	add_child(floor_mi)


func _review(path: String) -> void:
	var id: String = path.get_file().get_basename()
	var wall: bool = _wall.has(id)
	var root: Node3D = Node3D.new()
	add_child(root)
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	model.position.y += _lift
	var post: MeshInstance3D = MeshInstance3D.new()  # 1.8 m reference post, 0.1 m square
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.1, 1.8, 0.1)
	post.mesh = bm
	root.add_child(post)
	if wall:
		model.position = Vector3(0, 1.5, 0)
		var back: MeshInstance3D = MeshInstance3D.new()
		var wb: BoxMesh = BoxMesh.new()
		wb.size = Vector3(6.0, 3.2, 0.1)
		back.mesh = wb
		back.position = Vector3(0, 1.6, 0.05)
		root.add_child(back)
	var aabb: AABB = AABB()
	var first: bool = true
	var tris: int = 0
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var box: AABB = model.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
		for s: int in mi.mesh.get_surface_count():
			tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_say("%s aabb pos %s size %s (x %.2f  y %.2f  z %.2f)  tris %d" % [id, aabb.position, aabb.size, aabb.size.x,
		aabb.size.y, aabb.size.z, tris])
	for n: Node in model.find_children("*", "", true, false):
		if n is Node3D and not n is MeshInstance3D:
			_say("  node %s (%s) at %s" % [model.get_path_to(n), n.get_class(), (n as Node3D).position])
	var c: Vector3 = model.position + aabb.get_center()
	# small props (under 1 m across) are framed on their own AABB; the reference post then stands out of frame
	var diag: float = aabb.size.length()
	var r: float = maxf(diag * 1.15, 1.6) if diag >= 1.0 else maxf(diag * 1.9, 0.25)
	post.visible = diag >= 1.0  # beside a small prop, at close range the post blocks the side views
	if _focus.w > 0.0:
		c = model.position + Vector3(_focus.x, _focus.y, _focus.z)
		r = _focus.w
	post.position = Vector3(c.x + aabb.size.x / 2 + 0.4, 0.9, c.z)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 45.0
	root.add_child(cam)
	cam.current = true
	var tiles: Array[Image] = []
	var dirs: Array[float] = [35.0, 0.0, 90.0, 150.0]
	if wall:
		dirs = [30.0, 0.0, -30.0, 60.0]
	for deg: float in dirs:
		var a: float = deg_to_rad(deg)
		# the prop faces -Z: the front views come from -Z
		cam.look_at_from_position(c + Vector3(sin(a) * r, r * 0.35, -cos(a) * r), c)
		tiles.append(await _grab())
	_sheet(tiles, 2, "%s/%s_review%s.png" % [_out, id, "_night" if _night else ""])
	root.queue_free()
	await get_tree().process_frame


func _grab() -> Image:
	for _i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	return img


func _sheet(tiles: Array[Image], cols: int, path: String) -> void:
	var rows: int = ceili(float(tiles.size()) / cols)
	var sheet: Image = Image.create(TILE.x * cols, TILE.y * rows, false, Image.FORMAT_RGB8)
	for k: int in tiles.size():
		sheet.blit_rect(tiles[k], Rect2i(Vector2i.ZERO, TILE), Vector2i((k % cols) * TILE.x, (k / cols) * TILE.y))
	sheet.save_png(path)


func _say(s: String) -> void:
	_log.append(s)
	print("[PROP] " + s)
