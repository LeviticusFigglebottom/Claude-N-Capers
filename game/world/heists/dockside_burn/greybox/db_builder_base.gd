## Dockside Burn generator base: shared constants, state and generic helpers. Owner: ENV C (C3).
## Chain: db_builder_base.gd <- db_gameplay.gd <- build_greybox.gd (the --script entry point).
## Same helper set as Shadow Ledger's / Night Deposit's generators (kept per heist so a heist's
## outputs never change when another heist's generator does).
extends SceneTree

const L: GDScript = preload("res://world/heists/dockside_burn/greybox/dockside_burn_layout.gd")
const R: GDScript = preload("res://world/heists/dockside_burn/greybox/dockside_burn_resources.gd")
const RT: GDScript = preload("res://world/kits/ridge_top.gd")  # not-standable guard tops (slopes, D-104)
const OUT_DIR: String = "res://world/heists/dockside_burn/"
const SCENE_PATH: String = OUT_DIR + "dockside_burn.tscn"
const DEF_PATH: String = OUT_DIR + "dockside_burn_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "dockside_burn_variants.tres"
const MISSION_PATH: String = OUT_DIR + "dockside_burn_mission.gd"
const MAT_DIR: String = "res://world/materials/"
## PO-13: harbour and slip use the library night water (texgen water_harbour_night), duplicated per body.
const WATER_MAT: String = "water_harbour_night"
const KIT_DIR: String = "res://assets/arch/"
## Visual step boxes overlap their higher neighbour by this much (no ray-through seams).
const SEAM: float = 0.02
## Prefab id -> contract class_name (gameplay_prefabs.md). Scene = the class script's .tscn sibling.
const PREFAB_CLASSES: Dictionary = {
	"door": "Door", "window": "WindowPrefab", "safe": "Safe", "drill_point": "DrillPoint",
	"keycard_pickup": "KeycardPickup", "loot_spawn": "LootSpawn", "small_loot": "SmallLoot",
	"alarm_button": "AlarmButton", "phone": "Phone", "secure_zone": "SecureZone", "escape_zone": "EscapeZone",
	"body_container": "BodyContainer", "ladder": "Ladder", "camera_station": "CameraStation",
	"security_camera": "SecurityCamera", "code_note": "CodeNote", "keypad": "Keypad", "laser_grid": "LaserGrid",
	"bag_lift": "BagLift", "hack_terminal": "HackTerminal", "zipline": "Zipline", "keycard_reader": "KeycardReader",
	"padlock": "Padlock", "burn_point": "BurnPoint", "deposit_box": "DepositBox",
}
## PO-13 surface pass: greybox class / room purpose -> library finish (db_finishes.gd).
const F: GDScript = preload("res://world/heists/dockside_burn/greybox/db_finishes.gd")
## Untextured see-through surfaces (meta untextured_ok): PVC strip curtains, the fire-volume marker.
const SEE_THROUGH_MATS: Dictionary = {
	"strip_curtain": Color(0.75, 0.88, 0.95, 0.35), "fire_volume": Color(1.0, 0.42, 0.1, 0.25),
}
## Emissive (fixtures, lamps, beacons): untextured_ok.
const EMISSIVE_MATS: Dictionary = {
	"fixture": Color(1.0, 0.95, 0.88), "sodium": Color(1.0, 0.62, 0.3), "cold_led": Color(0.8, 0.9, 1.0),
	"far_lights": Color(1.0, 0.85, 0.6), "beacon": Color(1.0, 0.42, 0.1),
}

var map_root: HeistMap = null
var errors: PackedStringArray = PackedStringArray()
## Projected nav obstructions for props and prefabs: [corners (PackedVector3Array), elevation, height].
var obstructions: Array[Array] = []
var _mat_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _scene_cache: Dictionary = {}


# --- Generic helpers (also used by db_gameplay.gd) ----------------------------------

func add(parent: Node, c: Node) -> Node:
	parent.add_child(c)
	c.owner = map_root
	return c


func node3d(nm: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var c: Node3D = Node3D.new()
	c.name = nm
	c.position = pos
	return c


static func yaw_basis(yaw_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg))


static func v3(a: Array, i: int) -> Vector3:
	return Vector3(float(a[i]), float(a[i + 1]), float(a[i + 2]))


## Material for a finish key (db_finishes FINISHES) or a greybox class (its position-free default),
## the water bodies, emissives and see-through markers. Cached: one material per key.
func lib_mat(id: String) -> Material:
	if _mat_cache.has(id):
		return _mat_cache[id]
	var m: Material
	if id in ["water", "water_slip"]:
		m = _water_mat(id)
	elif EMISSIVE_MATS.has(id) or SEE_THROUGH_MATS.has(id):
		m = _flat_mat(id)
	else:
		var key: String = id if F.FINISHES.has(id) else F.resolve(id, "", AABB())
		if not F.FINISHES.has(key):
			errors.append("unknown material class `%s`" % id)
			key = "concrete"
		if not _mat_cache.has(key):
			_mat_cache[key] = _finish_mat(key)
		m = _mat_cache[key]
	_mat_cache[id] = m
	return m


## A library finish: the texgen material duplicated (textures shared) as world triplanar at the style
## guide density, optionally tinted. resource_name db_<key> (surface_map.json gives its bullet surface).
func _finish_mat(key: String) -> Material:
	var row: Array = F.FINISHES[key]
	var lib: String = String(row[0])
	var base: BaseMaterial3D = load(MAT_DIR + lib + ".tres") as BaseMaterial3D
	var m: BaseMaterial3D = base.duplicate() as BaseMaterial3D
	m.resource_name = "db_" + key
	if row[1] != null:
		m.albedo_color = base.albedo_color * (row[1] as Color)
	var uv: float = F.uv_per_m(lib, float(base.albedo_texture.get_width()), float(base.get_meta(&"uv_tile_m", 2.0)))
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(uv, uv, uv)
	return m


func _flat_mat(id: String) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.resource_name = "db_" + id
	m.set_meta(&"untextured_ok", true)
	if EMISSIVE_MATS.has(id):
		m.albedo_color = EMISSIVE_MATS[id]
		m.emission_enabled = true
		m.emission = EMISSIVE_MATS[id]
		m.emission_energy_multiplier = 0.6 if id == "far_lights" else 3.0
	else:
		# PVC strip curtains / the fire-volume marker: see-through, both faces drawn.
		m.albedo_color = SEE_THROUGH_MATS[id]
		m.roughness = 0.9
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Finish key for a box of class `cls` named `nm` with local corners mn / mx under `parent`.
func finish(parent: Node, cls: String, nm: String, mn: Vector3, mx: Vector3, kind: String = "") -> String:
	if cls in ["water", "water_slip"] or EMISSIVE_MATS.has(cls) or SEE_THROUGH_MATS.has(cls):
		return cls
	return F.resolve(cls, nm, _world_xf(parent) * AABB(mn, mx - mn), kind)


## Transform of `nd` relative to the map root (nodes are built before the map enters a tree).
func _world_xf(nd: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = nd
	while cur != null and cur != map_root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## PO-13: `water` (harbour; the quay wall line, its min z = 44, darkens the first metres, water to +z) and
## `water_slip` (no shore darkening: walls on both sides). Glints are set later (_water_glints).
func _water_mat(id: String) -> ShaderMaterial:
	var w: ShaderMaterial = (load(MAT_DIR + WATER_MAT + ".tres") as ShaderMaterial).duplicate() as ShaderMaterial
	w.resource_name = "db_" + id
	if id == "water":
		w.set_shader_parameter(&"shore_plane", Vector4(0.0, 0.0, 1.0, -float((L.WATER[0][1] as Array)[2])))
		w.set_shader_parameter(&"shore_fade_m", 2.5)
		w.set_shader_parameter(&"shore_darken", 0.45)
	return w


func box_mesh(size: Vector3, mat_id: String) -> BoxMesh:
	var key: String = "%s|%.3f|%.3f|%.3f" % [mat_id, size.x, size.y, size.z]
	if not _box_mesh_cache.has(key):
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		bm.material = lib_mat(mat_id)
		_box_mesh_cache[key] = bm
	return _box_mesh_cache[key]


func box_shape(size: Vector3) -> BoxShape3D:
	var key: String = "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if not _box_shape_cache.has(key):
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		_box_shape_cache[key] = bs
	return _box_shape_cache[key]


## Static box (world_static) from min/max corners: StaticBody3D + CollisionShape3D + MeshInstance3D.
## mat_id "" or "none" = collision only.
func box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat_id: String, collide: bool = true) -> Node3D:
	var size: Vector3 = mx - mn
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return null
	var body: Node3D
	if collide:
		var sb: StaticBody3D = StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		body = sb
	else:
		body = Node3D.new()
	body.name = nm
	body.position = (mn + mx) * 0.5
	add(parent, body)
	if collide:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Collision"
		col.shape = box_shape(size)
		add(body, col)
	if mat_id != "" and mat_id != "none":
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = box_mesh(size, finish(parent, mat_id, nm, mn, mx))
		add(body, mi)
	return body


func box_a(parent: Node3D, nm: String, b: Array, mat_id: String, collide: bool = true) -> Node3D:
	return box(parent, nm, v3(b, 0), v3(b, 3), mat_id, collide)


## Visual-only box mesh child (no collision) at local min/max corners.
func mesh_box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat_id: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = box_mesh(mx - mn, finish(parent, mat_id, nm, mn, mx))
	mi.position = (mn + mx) * 0.5
	add(parent, mi)
	return mi


## Straight wall with rectangular openings. axis "x": runs along x at z = fixed; "z": along z at x = fixed.
## openings: [[along0, along1, sill_y, head_y], ...] (absolute heights). One box per storey (split
## at every floor level) so the per-floor plan render cuts every wall.
func wall(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, thick: float,
		yr: Vector2, openings: Array, mat_id: String) -> void:
	var y0: float = yr.x
	var y1: float = yr.y
	var cuts: Array[float] = [a0, a1]
	for o: Array in openings:
		for v: float in [float(o[0]), float(o[1])]:
			if v > a0 and v < a1 and not cuts.has(v):
				cuts.append(v)
	cuts.sort()
	var part: int = 0
	for i: int in range(cuts.size() - 1):
		var p: float = cuts[i]
		var q: float = cuts[i + 1]
		if q - p < 0.001:
			continue
		var holes: Array[Vector2] = []
		for o2: Array in openings:
			if float(o2[0]) <= p + 0.0001 and float(o2[1]) >= q - 0.0001:
				holes.append(Vector2(maxf(float(o2[2]), y0), minf(float(o2[3]), y1)))
		holes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cur: float = y0
		var spans: Array[Vector2] = []
		for h: Vector2 in holes:
			if h.x > cur + 0.0001:
				spans.append(Vector2(cur, h.x))
			cur = maxf(cur, h.y)
		if y1 > cur + 0.0001:
			spans.append(Vector2(cur, y1))
		var split: Array[Vector2] = []
		for sp: Vector2 in spans:
			var lo: float = sp.x
			for fh: float in L.FLOOR_HEIGHTS:
				if fh > lo + 0.0001 and fh < sp.y - 0.0001:
					split.append(Vector2(lo, fh))
					lo = fh
			split.append(Vector2(lo, sp.y))
		for s: Vector2 in split:
			var mn: Vector3
			var mx: Vector3
			if axis == "x":
				mn = Vector3(p, s.x, fixed - thick * 0.5)
				mx = Vector3(q, s.y, fixed + thick * 0.5)
			else:
				mn = Vector3(fixed - thick * 0.5, s.x, p)
				mx = Vector3(fixed + thick * 0.5, s.y, q)
			box(parent, "%s_%02d" % [nm, part], mn, mx, mat_id)
			part += 1


func kit_scene(piece: String) -> PackedScene:
	var path: String = "%s%s/%s.glb" % [KIT_DIR, piece, piece]
	if not _scene_cache.has(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			errors.append("missing kit piece %s" % path)
		_scene_cache[path] = ps
	return _scene_cache[path]


## Gameplay prefab scene by contract id, or null (no error) when `optional` and not on trunk.
func prefab_scene(prefab: String, optional: bool = false) -> PackedScene:
	if _scene_cache.has(prefab):
		return _scene_cache[prefab]
	var cls: String = String(PREFAB_CLASSES.get(prefab, ""))
	var ps: PackedScene = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c["class"]) == cls:
			var path: String = String(c["path"]).get_basename() + ".tscn"
			if ResourceLoader.exists(path):
				ps = load(path) as PackedScene
	if ps == null and not optional:
		errors.append("gameplay prefab `%s` (class %s) not found" % [prefab, cls])
	_scene_cache[prefab] = ps
	return ps


## Records a projected navmesh obstruction for a box (local AABB under xform).
func obstruct(xform: Transform3D, aabb: AABB) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var lo: float = INF
	var hi: float = -INF
	for corner: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
		var lp: Vector3 = aabb.position + aabb.size * corner
		pts.append(xform * lp)
	for cy: float in [aabb.position.y, aabb.end.y]:
		var w: Vector3 = xform * Vector3(aabb.position.x, cy, aabb.position.z)
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
	obstructions.append([pts, lo, hi - lo])


## Box prop: StaticBody3D map_root at the bottom-centre (meta kind / support), collision + mesh.
func prop_box(parent: Node3D, nm: String, base: Vector3, size: Vector3, yaw: float, kind: String,
		support: bool, mat_id: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = yaw_basis(yaw)
	body.set_meta(&"kind", kind)
	if support:
		body.set_meta(&"support", true)
	add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	# Mooring bollards: a ridged collider top (a domed head in the art pass), not a perch (D-104 slopes).
	col.shape = RT.shape(size) if kind == "bollard" else box_shape(size)
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = box_mesh(size, finish(parent, mat_id, nm, base - Vector3(size.x, 0.0, size.z) * 0.5, base + Vector3(size.x, size.y * 2.0,
		size.z) * 0.5, kind))
	mi.position = col.position
	add(body, mi)
	obstruct(body.transform, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size))
	return body


func chair(parent: Node3D, nm: String, base: Vector3, yaw: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = yaw_basis(yaw)
	body.set_meta(&"kind", "chair")
	add(parent, body)
	var size: Vector3 = Vector3(0.45, 0.85, 0.45)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = box_shape(size)
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	add(body, col)
	mesh_box(body, "SeatMesh", Vector3(-0.225, 0.0, -0.225), Vector3(0.225, 0.45, 0.225), "chair")
	mesh_box(body, "BackMesh", Vector3(-0.225, 0.45, 0.165), Vector3(0.225, 0.85, 0.225), "chair")
	var m: Marker3D = Marker3D.new()
	m.name = "Seat"
	m.position = Vector3(0.0, 0.45, 0.0)
	add(body, m)
	obstruct(body.transform, AABB(Vector3(-0.225, 0.0, -0.225), size))


func area_boxes(area: Area3D, boxes: Array) -> void:
	for i: int in range(boxes.size()):
		var b: Array = boxes[i]
		var mn: Vector3 = v3(b, 0)
		var mx: Vector3 = v3(b, 3)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Shape" if i == 0 else "Shape%d" % i
		col.shape = box_shape(mx - mn)
		col.position = (mn + mx) * 0.5
		add(area, col)


func zone(parent: Node3D, nm: String, kind: String, zone_id: String, boxes: Array) -> MapZone:
	var z: MapZone = MapZone.new()
	z.name = nm
	z.kind = MapZone.Kind[kind]
	z.zone_id = StringName(zone_id)
	z.collision_layer = 1 << 9
	z.collision_mask = 0
	add(parent, z)
	area_boxes(z, boxes)
	return z


func spawn(parent: Node3D, nm: String, kind: String, pos: Vector3, yaw: float, tags: Array, idle: String,
		graph: String) -> SpawnPoint:
	var sp: SpawnPoint = SpawnPoint.new()
	sp.name = nm
	sp.kind = SpawnPoint.Kind[kind]
	var tg: Array[StringName] = []
	for t: Variant in tags:
		tg.append(StringName(String(t)))
	sp.tags = tg
	sp.idle_activity = StringName(idle)
	sp.position = pos
	sp.basis = yaw_basis(yaw)
	add(parent, sp)
	if graph != "":
		sp.patrol_graph = sp.get_path_to(map_root.get_node("Patrols/" + graph))
	return sp


func n(path: String) -> Node3D:
	return map_root.get_node(path) as Node3D
