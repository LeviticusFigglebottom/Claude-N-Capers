## Dressing-kit demo renders (C1-07, ENV C): builds a sample room per kit (Glasshouse sizes, a door,
## a window, stand-ins for the gameplay prefabs as keep-outs), dresses it with KitPlacer and saves
## an inside view + a top-down cutaway. Run (Vulkan via lavapipe under xvfb):
##   xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --path game --resolution 1920x1080 \
##     res://world/props/tools/kit_demo.tscn -- --out=docs/levels/_props/kit_ [--kit=break_room] [--seed=1]
## Output: <out><kit_id>.jpg
class_name KitDemoTool
extends Control

const KIT_DIR: String = "res://world/kits/"
const LAYER_CEILING: int = 2
## kit -> [width x, ceiling y, depth z, floor material, wall material, exterior?]
const ROOMS: Dictionary = {
	"storage_receiving": [4.8, 3.0, 4.3, "vinyl_floor", "drywall_painted", false],
	"electrical_closet": [1.8, 3.0, 1.8, "vinyl_floor", "drywall_painted", false],
	"workshop_jeweler": [5.3, 3.0, 4.3, "vinyl_floor", "drywall_painted", false],
	"restroom_single": [2.3, 3.0, 4.3, "tile_ceramic_white", "tile_ceramic_white", false],
	"corridor_service": [9.0, 3.0, 1.3, "vinyl_floor", "drywall_painted", false],
	"janitor_closet": [1.3, 2.8, 1.3, "vinyl_floor", "drywall_painted", false],
	"sales_floor_jewelry": [12.8, 3.6, 5.8, "terrazzo", "plaster_painted", false],
	"salon_private": [4.8, 3.2, 5.8, "terrazzo", "plaster_painted", false],
	"break_room": [5.3, 3.0, 4.3, "vinyl_floor", "plaster_painted", false],
	"security_office": [4.8, 3.0, 4.3, "carpet_commercial", "drywall_painted", false],
	"corridor_office": [9.0, 3.0, 1.3, "carpet_commercial", "plaster_painted", false],
	"office_open": [6.8, 3.0, 5.8, "carpet_commercial", "plaster_painted", false],
	"office_manager": [4.8, 3.0, 5.8, "carpet_commercial", "plaster_painted", false],
	"storage_archive": [5.8, 3.0, 5.8, "vinyl_floor", "drywall_painted", false],
	"exterior_alley": [20.0, 6.0, 6.0, "asphalt", "brick_red", true],
	"exterior_street": [20.0, 6.0, 7.0, "concrete", "brick_red", true],
}
## Gameplay prefab stand-ins (keep-outs): kit -> [[asset id, x, z, yaw_deg, ceiling?], ...] in room-local metres.
const PREFABS: Dictionary = {
	"workshop_jeweler": [["prop_safe_large", 0.0, -1.78, 180.0, false]],
	"security_office": [["prop_camera_station", -1.6, 0.4, 90.0, false]],
	"sales_floor_jewelry": [["prop_display_case_round", 1.0, 0.3, 0.0, false], ["prop_chandelier_ring", 1.0, 0.3, 0.0, true],
		["prop_display_case_wall", -5.9, -1.2, 90.0, false], ["prop_display_case_wall", -5.9, 0.4, 90.0, false],
		["prop_display_case_island", -3.0, 0.4, 0.0, false], ["prop_display_case_island", 4.4, -1.0, 0.0, false]],
	"salon_private": [["prop_display_case_island", -1.2, 1.9, 0.0, false], ["prop_display_case_island", 1.2, 1.9, 0.0, false]],
	"exterior_alley": [["prop_dumpster", -4.0, -2.2, 180.0, false], ["prop_dumpster", 2.0, -2.2, 180.0, false]],
	"exterior_street": [["veh_car_sedan_wine", -5.0, -2.2, 90.0, false], ["prop_bus_shelter", 5.0, -2.3, 0.0, false]],
}

var _out: String = ""
var _only: String = ""
var _seed: int = 1
var _frames: int = 14


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--kit="):
			_only = arg.substr(6)
		elif arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
	var ids: Array = ROOMS.keys()
	ids.sort()
	for id: Variant in ids:
		if _only != "" and String(id) != _only:
			continue
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(holder)
		var info: String = _demo(holder, String(id))
		for f: int in range(_frames):
			await RenderingServer.frame_post_draw
		_save(String(id))
		print("kit_demo: %s %s" % [id, info])
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


func _demo(holder: Control, kit_id: String) -> String:
	var spec: Array = ROOMS[kit_id]
	var size := Vector3(spec[0], spec[1], spec[2])
	var exterior: bool = spec[5]
	var world := Node3D.new()
	var room := KitRoom.from_aabb(AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size), StringName(kit_id))
	# a door on the south wall, a window on the north wall (not for corridors/closets)
	var door_u: float = minf(1.2, size.x * 0.5)
	var swing: float = 0.0 if size.x * size.z < 5.0 else -1.0     # closet doors swing out
	if size.x >= 1.6:
		room.add_door(room.wall_point(2, size.x - door_u), 0.9, swing)
	else:
		room.add_door(room.wall_point(1, size.z * 0.5), 0.9, swing)
	if size.z > 2.0 and size.x > 3.0 and not exterior:
		room.add_window(room.wall_point(0, size.x * 0.5) + Vector3(0, 0.9, 0), 1.0, 0.9, 2.1)
	if exterior:
		room.walls = [true, false, false, false]
	_build_shell(world, room, spec, exterior)
	for pf: Variant in PREFABS.get(kit_id, []):
		_prefab(world, room, pf as Array)
	var kit: DressingKit = load(KIT_DIR + kit_id + ".tres") as DressingKit
	var res: Dictionary = KitPlacer.place(room, kit, _seed)
	var props := Node3D.new()
	props.name = "Props"
	world.add_child(props)
	var nodes: Array[Node3D] = KitPlacer.instantiate(res, props)
	for i: int in range(nodes.size()):
		if String((res["placements"][i] as Dictionary)["mode"]) == "ceiling":
			_set_layer(nodes[i], LAYER_CEILING)
	var n: int = (res["placements"] as Array).size()
	var info: String = "%s  |  %d props, %.2f/m² (kit %.2f-%.2f)  |  hash %s" % [kit_id, n, float(n) / room.area(),
		kit.min_density, kit.max_density, String(res["hash"]).substr(0, 8)]
	if not (res["missing"] as PackedStringArray).is_empty():
		info += "  |  MISSING %s" % ", ".join(res["missing"])
	var ov: PackedStringArray = KitPlacer.overlaps(res)
	if not ov.is_empty():
		info += "  |  OVERLAPS %d" % ov.size()
	_views(holder, world, room, exterior, info)
	return info


func _mat(id: String) -> Material:
	var m: BaseMaterial3D = (load("res://world/materials/%s.tres" % id) as BaseMaterial3D).duplicate() as BaseMaterial3D
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.5
	return m


func _box(parent: Node3D, lo: Vector3, hi: Vector3, mat: Material, layer: int = 1) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = hi - lo
	mi.mesh = bm
	mi.material_override = mat
	mi.position = (lo + hi) * 0.5
	mi.layers = layer
	parent.add_child(mi)


func _build_shell(world: Node3D, room: KitRoom, spec: Array, exterior: bool) -> void:
	var s: Vector3 = room.size
	var t: float = 0.2
	var hx: float = s.x * 0.5
	var hz: float = s.z * 0.5
	_box(world, Vector3(-hx - t, -0.2, -hz - t), Vector3(hx + t, 0.0, hz + t), _mat(spec[3]))
	if not exterior:
		_box(world, Vector3(-hx - t, s.y, -hz - t), Vector3(hx + t, s.y + 0.05, hz + t), _mat("ceiling_tile"), LAYER_CEILING)
	var wall_mat: Material = _mat(spec[4])
	var wall_h: float = s.y if not exterior else 4.0
	for w: int in range(4):
		if not room.walls[w]:
			continue
		var holes: Array[Dictionary] = []
		for o: Dictionary in room.openings:
			if int(o["wall"]) == w:
				holes.append(o)
		holes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["u"]) < float(b["u"]))
		var ln: float = room.wall_length(w)
		var cuts: Array[float] = [0.0]
		for o: Dictionary in holes:
			cuts.append(float(o["u"]) - float(o["width"]) * 0.5)
			cuts.append(float(o["u"]) + float(o["width"]) * 0.5)
		cuts.append(ln)
		for i: int in range(0, cuts.size(), 2):
			_wall_piece(world, room, w, cuts[i] - (t if i == 0 else 0.0), cuts[i + 1] + (t if i + 2 >= cuts.size() else 0.0), 0.0, wall_h, wall_mat)
		for o: Dictionary in holes:
			var u0: float = float(o["u"]) - float(o["width"]) * 0.5
			var u1: float = float(o["u"]) + float(o["width"]) * 0.5
			_wall_piece(world, room, w, u0, u1, float(o["top"]), wall_h, wall_mat)
			if float(o["bottom"]) > 0.0:
				_wall_piece(world, room, w, u0, u1, 0.0, float(o["bottom"]), wall_mat)


func _wall_piece(world: Node3D, room: KitRoom, w: int, u0: float, u1: float, z0: float, z1: float, mat: Material) -> void:
	var a: Vector3 = room.wall_point(w, u0)
	var b: Vector3 = room.wall_point(w, u1) - KitRoom.wall_normal(w) * 0.2
	var lo := Vector3(minf(a.x, b.x), z0, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), z1, maxf(a.z, b.z))
	if hi.x - lo.x < 0.001 or hi.z - lo.z < 0.001 or z1 - z0 < 0.001:
		return
	_box(world, lo, hi, mat)


func _prefab(world: Node3D, room: KitRoom, pf: Array) -> void:
	var asset: StringName = StringName(String(pf[0]))
	var e: Dictionary = PropCatalog.entry(asset)
	var n: Node3D = (load(String(e["scene"])) as PackedScene).instantiate() as Node3D
	var bb: AABB = PropCatalog.aabb(asset)
	var y: float = room.size.y - bb.end.y if bool(pf[4]) else 0.0
	n.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(pf[3]))), Vector3(float(pf[1]), y, float(pf[2])))
	world.add_child(n)
	if bool(pf[4]):
		_set_layer(n, LAYER_CEILING)
	room.add_keep_out((n.transform * bb).grow(0.15))


func _set_layer(n: Node, layer: int) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = layer
	for c: Node in n.get_children():
		_set_layer(c, layer)


func _views(holder: Control, world: Node3D, room: KitRoom, exterior: bool, info: String) -> void:
	var size: Vector2 = get_viewport_rect().size
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override(&"separation", 4)
	holder.add_child(box)
	var w_persp: int = int(size.x * 0.58)
	var vp1: SubViewport = _viewport(box, Vector2i(w_persp, int(size.y)))
	vp1.add_child(world)
	_env(world, exterior)
	var s: Vector3 = room.size
	var cam := Camera3D.new()
	cam.fov = 72.0 if s.x * s.z > 6.0 else 85.0
	cam.cull_mask = 0xFFFFF
	# from the doorway (kept clear by the placer), looking across the room
	var o: Dictionary = room.openings[0]
	var eye: Vector3 = room.wall_point(int(o["wall"]), float(o["u"])) + KitRoom.wall_normal(int(o["wall"])) * 0.25
	eye.y = minf(1.9, s.y - 0.3)
	var target := Vector3(-eye.x * 0.6, 0.8, -eye.z * 0.6)
	if s.z < 2.0:
		eye = Vector3(s.x * 0.5 - 0.3, 1.8, 0.2)
		target = Vector3(-s.x * 0.5, 1.0, 0.0)
	if exterior:
		eye = Vector3(s.x * 0.45, 3.2, s.z * 0.5 + 4.0)
		target = Vector3(-s.x * 0.25, 0.7, -s.z * 0.25)
	cam.look_at_from_position(eye, target, Vector3.UP)
	cam.current = true
	world.add_child(cam)
	var vp2: SubViewport = _viewport(box, Vector2i(int(size.x) - w_persp - 4, int(size.y)), false)
	vp2.world_3d = vp1.find_world_3d()
	var top := Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect: float = float(vp2.size.x) / float(vp2.size.y)
	top.size = maxf(s.z + 0.8, (s.x + 0.8) / aspect)
	top.cull_mask = 1
	top.near = 0.05
	top.far = 50.0
	top.current = true
	top.look_at_from_position(Vector3(0.0, s.y + 8.0, 0.001), Vector3.ZERO, Vector3.FORWARD)
	vp2.add_child(top)
	var label := Label.new()
	label.text = info
	label.add_theme_font_size_override(&"font_size", 20)
	label.add_theme_color_override(&"font_color", Color(0.95, 0.95, 0.92))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override(&"outline_size", 6)
	label.position = Vector2(16, 12)
	holder.add_child(label)


func _viewport(parent: Control, px: Vector2i, own_world: bool = true) -> SubViewport:
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(px)
	svc.stretch = true
	parent.add_child(svc)
	var vp := SubViewport.new()
	vp.size = px
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = own_world
	svc.add_child(vp)
	return vp


func _env(world: Node3D, exterior: bool) -> void:
	var we := WorldEnvironment.new()
	var env: Environment
	if exterior and ResourceLoader.exists("res://world/lighting/env_glasshouse.tres"):
		env = (load("res://world/lighting/env_glasshouse.tres") as Environment).duplicate() as Environment
		env.fog_enabled = false
		var sun := DirectionalLight3D.new()
		sun.light_color = Color(0.75, 0.8, 1.0)
		sun.light_energy = 0.4
		sun.rotation_degrees = Vector3(-35.0, -60.0, 0.0)
		world.add_child(sun)
	else:
		env = Environment.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.5, 0.5, 0.52)
		sky_mat.sky_horizon_color = Color(0.7, 0.66, 0.6)
		sky_mat.ground_horizon_color = Color(0.4, 0.37, 0.33)
		sky_mat.ground_bottom_color = Color(0.2, 0.18, 0.16)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.08, 0.08, 0.09)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.45
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.ssao_enabled = true
		env.glow_enabled = true
		env.glow_intensity = 0.35
		var fill := DirectionalLight3D.new()
		fill.light_energy = 0.35
		fill.light_color = Color(1.0, 0.95, 0.9)
		fill.rotation_degrees = Vector3(-60.0, 35.0, 0.0)
		fill.layers = 1
		world.add_child(fill)
	we.environment = env
	world.add_child(we)


func _save(kit_id: String) -> void:
	if _out.is_empty():
		return
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s%s.jpg" % [_out, kit_id]
	if not path.is_absolute_path() and not path.begins_with("res://"):
		path = OS.get_environment("PWD").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_jpg(path, 0.85)
