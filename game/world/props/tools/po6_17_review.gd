## PO6-17 review sheet (ENV C): the assault-event props (turret van + sentry turret, police helicopter, the
## three breach points Intact vs Blown) and their Golden Hour placements (AssaultEvents markers). Run:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://world/props/tools/po6_17_review.gd -- --out=docs/levels/_art/po6_17 \
##     [--part=props|gh]
## Writes <out>/<shot>.jpg and, for a full run, <out>/contact_sheet.jpg (from every shot jpg in <out>).
## The Golden Hour part renders the whole map in software GL: ~3 min per shot. Review only; never saves a scene.
extends SceneTree

const DIR: String = "res://world/props/assault_event/"
const GH: String = "res://world/heists/glasshouse/glasshouse.tscn"
const FLOOR_MAT: String = "res://world/materials/concrete.tres"
const WALL_MAT: String = "res://world/materials/plaster_painted.tres"
const THUMB: Vector2i = Vector2i(640, 360)
const ORDER: Array[String] = ["van_front", "van_rear", "sentry_turret", "helicopter", "breach_wall", "breach_wall_out",
	"breach_window", "breach_window_out", "breach_ceiling", "breach_ceiling_roof", "gh_overview", "gh_harlow",
	"gh_breach_sales", "gh_breach_manager", "gh_breach_stock", "gh_roof", "gh_facade"]

var _out: String = "res://../docs/levels/_art/po6_17"
var _stage: Node3D = null
var _cam: Camera3D = null
var _label: Label = null
var _shots: Array[Array] = []
var _part: String = ""


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--part="):
			_part = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	get_root().add_child(canvas)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override(&"font_size", 24)
	_label.add_theme_color_override(&"font_color", Color(1, 1, 1))
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override(&"outline_size", 6)
	canvas.add_child(_label)
	if _part != "gh":
		await _props()
	if _part != "props":
		await _glasshouse()
	_sheet()
	quit(0)


# --- props on a neutral stage ---------------------------------------------------------------------

func _new_stage(ground: bool = true) -> void:
	if _stage != null:
		_stage.free()
	_stage = Node3D.new()
	get_root().add_child(_stage)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.35, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.72)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_stage.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	_stage.add_child(sun)
	if ground:
		_box(Vector3(-12, -0.2, -12), Vector3(12, 0.0, 12), FLOOR_MAT)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_stage.add_child(_cam)
	_cam.make_current()


func _box(lo: Vector3, hi: Vector3, mat: String, parent: Node3D = null) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = hi - lo
	bm.material = load(mat) as Material
	mi.mesh = bm
	mi.position = (lo + hi) * 0.5
	(parent if parent != null else _stage).add_child(mi)


func _inst(id: String, xf: Transform3D, blown: bool = false) -> Node3D:
	var n: Node3D = (load(DIR + id + ".tscn") as PackedScene).instantiate() as Node3D
	n.transform = xf
	_stage.add_child(n)
	_set_blown(n, blown)
	return n


static func _set_blown(n: Node, blown: bool) -> void:
	var intact: Node3D = n.get_node_or_null(^"Model/Intact") as Node3D
	var b: Node3D = n.get_node_or_null(^"Model/Blown") as Node3D
	if intact != null and b != null:
		intact.visible = not blown
		b.visible = blown


func _shoot(name: String, caption: String, from: Vector3, at: Vector3, fov: float = 55.0) -> void:
	_cam.fov = fov
	_cam.look_at_from_position(from, at, Vector3.UP)
	_label.text = caption
	for i: int in range(10):
		await process_frame
	var img: Image = get_root().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path: String = _out.path_join(name + ".jpg")
	img.save_jpg(path, 0.85)
	_shots.append([name, caption])
	print("po6_17_review: ", path)


func _props() -> void:
	_new_stage()
	var van: Node3D = _inst("prop_turret_van", Transform3D.IDENTITY)
	var mount: Node3D = van.get_node(^"Model/TurretMount") as Node3D
	var tur: Node3D = (load(DIR + "prop_sentry_turret.tscn") as PackedScene).instantiate() as Node3D
	tur.transform = mount.transform
	van.get_node(^"Model").add_child(tur)
	(tur.get_node(^"Model/Yaw") as Node3D).rotation.y = deg_to_rad(160.0)
	await _shoot("van_front", "prop_turret_van: nose +Z, light bar, TurretMount ring (sentry turret mounted)",
		Vector3(5.8, 2.6, 7.2), Vector3(0, 1.3, 0.3))
	(van.get_node(^"Model/DoorL") as Node3D).rotation.y = deg_to_rad(-100.0)
	(van.get_node(^"Model/DoorR") as Node3D).rotation.y = deg_to_rad(100.0)
	await _shoot("van_rear", "prop_turret_van rear: DoorL (+X) / DoorR (-X) opened (rot.y -100 / +100 deg)",
		Vector3(-5.0, 2.4, -8.2), Vector3(0, 1.1, -1.5))
	_new_stage()
	var t2: Node3D = _inst("prop_sentry_turret", Transform3D.IDENTITY)
	(t2.get_node(^"Model/Yaw") as Node3D).rotation.y = deg_to_rad(25.0)
	(t2.get_node(^"Model/Yaw/Pitch") as Node3D).rotation.x = deg_to_rad(8.0)
	await _shoot("sentry_turret", "prop_sentry_turret: Yaw (Y) > Pitch (X) > Muzzle (-Z)", Vector3(1.6, 1.3, -1.9),
		Vector3(0, 0.75, 0), 50.0)
	_new_stage()
	_inst("prop_police_helicopter", Transform3D.IDENTITY)
	await _shoot("helicopter", "prop_police_helicopter: Rotor (Y), TailRotor (X), open doors, RopeL/RopeR davits, nose Spotlight",
		Vector3(-8.5, 4.2, -6.5), Vector3(0, 1.4, -0.5))
	await _breach_stage("breach_wall", 0.2, 2.2, "prop_breach_wall: Intact (old doorway infill) | Blown (cops' side +Z behind)")
	await _breach_stage("breach_window", 0.4, 2.1, "prop_breach_window: Intact (window over sill infill) | Blown")
	await _ceiling_stage()


func _breach_stage(id: String, t: float, h: float, caption: String) -> void:
	_new_stage()
	var top: float = 3.2
	for seg: Vector2 in [Vector2(-4.5, -2.1), Vector2(-1.1, 1.1), Vector2(2.1, 4.5)]:
		_box(Vector3(seg.x, 0, 0), Vector3(seg.y, top, t), WALL_MAT)
	for cx: float in [-1.6, 1.6]:
		_box(Vector3(cx - 0.5, h, 0), Vector3(cx + 0.5, top, t), WALL_MAT)
	# the props' -Z faces the room (camera side)
	_inst("prop_" + id.trim_prefix("prop_"), Transform3D(Basis.IDENTITY, Vector3(-1.6, 0, 0)))
	_inst("prop_" + id.trim_prefix("prop_"), Transform3D(Basis.IDENTITY, Vector3(1.6, 0, 0)), true)
	await _shoot(id, caption, Vector3(0, 1.7, -4.6), Vector3(0, 1.0, 0))
	await _shoot(id + "_out", id + " from the cops' side (+Z): Charge on the outside face", Vector3(0.6, 1.7, 4.4),
		Vector3(0, 1.0, 0))


func _ceiling_stage() -> void:
	_new_stage(false)
	_box(Vector3(-6, -3.2, -6), Vector3(6, -3.0, 6), FLOOR_MAT)
	# ceiling (0 .. 0.05) and roof slab (0.4 .. 0.6) with two 1.2 m holes at x -1.6 / +1.6
	for y: Vector2 in [Vector2(0.0, 0.05), Vector2(0.4, 0.6)]:
		_box(Vector3(-6, y.x, -6), Vector3(6, y.y, -0.6), WALL_MAT)
		_box(Vector3(-6, y.x, 0.6), Vector3(6, y.y, 6), WALL_MAT)
		for seg: Vector2 in [Vector2(-6, -2.2), Vector2(-1.0, 1.0), Vector2(2.2, 6)]:
			_box(Vector3(seg.x, y.x, -0.6), Vector3(seg.y, y.y, 0.6), WALL_MAT)
	var down: Basis = Basis(Vector3.RIGHT, -PI * 0.5)
	_inst("prop_breach_ceiling", Transform3D(down, Vector3(-1.6, 0, 0)))
	_inst("prop_breach_ceiling", Transform3D(down, Vector3(1.6, 0, 0)), true)
	await _shoot("breach_ceiling", "prop_breach_ceiling from the room: Intact (access panel) | Blown (rubble 3 m below)",
		Vector3(0, -1.3, -4.2), Vector3(0, -0.6, 0), 65.0)
	await _shoot("breach_ceiling_roof", "prop_breach_ceiling on the roof: sealed skylight | blown (cover thrown aside)",
		Vector3(0.5, 2.4, -4.0), Vector3(0, 0.6, 0))


# --- Golden Hour placements ----------------------------------------------------------------------

func _glasshouse() -> void:
	if _stage != null:
		_stage.free()
		_stage = null
	var map: Node3D = (load(GH) as PackedScene).instantiate() as Node3D
	map.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(map)
	_stage = map
	_cam = Camera3D.new()
	map.add_child(_cam)
	_cam.make_current()
	var ae: Node3D = map.get_node(^"AssaultEvents") as Node3D
	# visualise the markers: vans (+ turret) on the van spots, the heli on its orbit, drop posts, orbit ring
	for c: Node in ae.get_children():
		var m: Marker3D = c as Marker3D
		var n: String = String(m.name)
		if n.begins_with("TurretVan"):
			var van: Node3D = (load(DIR + "prop_turret_van.tscn") as PackedScene).instantiate() as Node3D
			m.add_child(van)
			var tur: Node3D = (load(DIR + "prop_sentry_turret.tscn") as PackedScene).instantiate() as Node3D
			tur.transform = (van.get_node(^"Model/TurretMount") as Node3D).transform
			van.get_node(^"Model").add_child(tur)
		elif n.begins_with("HeliOrbit"):
			var r: float = float(m.get_meta(&"radius"))
			var heli: Node3D = (load(DIR + "prop_police_helicopter.tscn") as PackedScene).instantiate() as Node3D
			heli.position = Vector3(r * 0.6, 0, r * 0.8)
			heli.rotation.y = atan2(0.8, -0.6)
			m.add_child(heli)
			var ring: MeshInstance3D = MeshInstance3D.new()
			var tm: TorusMesh = TorusMesh.new()
			tm.inner_radius = r - 0.15
			tm.outer_radius = r + 0.15
			tm.rings = 96
			ring.mesh = tm
			ring.material_override = _flat(Color(1.0, 0.85, 0.2))
			m.add_child(ring)
		elif n.begins_with("HeliDrop"):
			var post: MeshInstance3D = MeshInstance3D.new()
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.3
			cyl.bottom_radius = 0.3
			cyl.height = 0.1
			post.mesh = cyl
			post.material_override = _flat(Color(1.0, 0.85, 0.2))
			post.position.y = 0.05
			m.add_child(post)
	_set_blown(ae.get_node(^"Breach_1/Visual"), true)
	_set_blown(ae.get_node(^"Breach_2/Visual"), true)
	_set_blown(ae.get_node(^"Breach_4/Visual"), true)
	await _shoot("gh_overview", "GH AssaultEvents: TurretVan_1/2 (Harlow Ave), HeliOrbit_1 r 24 m (ring), HeliDrop_1 roof / _2 alley",
		Vector3(40.0, 62.0, 58.0), Vector3(9.0, 4.0, 8.0), 60.0)
	await _shoot("gh_harlow", "GH Harlow Ave: turret vans parked in both lanes, shopfront + entrance covered",
		Vector3(-9.0, 3.0, 29.0), Vector3(9.0, 1.5, 20.0), 70.0)
	await _shoot("gh_breach_sales", "GH Breach_1 (wall, G4 corridor -> G5 sales floor), Blown",
		Vector3(9.0, 1.65, 10.0), Vector3(10.6, 1.0, 6.1), 70.0)
	await _shoot("gh_breach_manager", "GH U6 manager office: Breach_2 (wall from U7, Blown) + Breach_3 (window, Intact)",
		Vector3(8.0, 5.85, 7.0), Vector3(11.5, 5.2, 9.5), 80.0)
	await _shoot("gh_breach_stock", "GH Breach_4 (ceiling, roof -> U7 stock aisle), Blown",
		Vector3(16.9, 5.6, 9.1), Vector3(14.9, 6.2, 9.1), 75.0)
	await _shoot("gh_roof", "GH roof: Breach_4 skylight curb (Blown) + HeliDrop_1",
		Vector3(9.5, 11.5, 13.5), Vector3(14.0, 7.8, 8.5), 60.0)
	await _shoot("gh_facade", "GH south facade: Breach_3 (U6 window, Intact) next to ManagerSouthA",
		Vector3(9.0, 3.0, 19.0), Vector3(9.8, 5.2, 12.0), 50.0)


static func _flat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _sheet() -> void:
	var imgs: Array[Image] = []
	for n: String in ORDER:
		var path: String = _out.path_join(n + ".jpg")
		if FileAccess.file_exists(path):
			imgs.append(Image.load_from_file(path))
	var cols: int = 3
	var rows: int = int(ceil(float(imgs.size()) / float(cols)))
	var sheet: Image = Image.create(THUMB.x * cols, THUMB.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i: int in range(imgs.size()):
		var img: Image = imgs[i]
		img.convert(Image.FORMAT_RGB8)
		img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % cols) * THUMB.x, (i / cols) * THUMB.y))
	sheet.save_jpg(_out.path_join("contact_sheet.jpg"), 0.8)
	print("po6_17_review: contact sheet ", imgs.size(), " shots")
