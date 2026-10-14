## Gallery Night generator base: shared constants, state and generic helpers. Owner: ENV C (GN-C1).
## Chain: gn_builder_base.gd <- gn_gameplay.gd <- build_greybox.gd (the --script entry point).
## Helpers follow the Shadow Ledger / Dockside Burn generators (box walls with holes, ramp-collision stairs,
## sequential-id scene normalisation) so the four existing heists and this one regenerate the same way.
extends SceneTree

const L: GDScript = preload("res://world/heists/gallery_night/greybox/gallery_night_layout.gd")
const OUT_DIR: String = "res://world/heists/gallery_night/"
## The map's final path. Content freeze (D-082): the skeleton never writes here (validate_all and HeistRegistry
## would pick it up); it writes DEFAULT_OUT or `-- --out=<path>` until the freeze lifts.
const SCENE_PATH: String = OUT_DIR + "gallery_night.tscn"
const DEFAULT_OUT: String = "user://gn_skeleton/gallery_night.tscn"
const DEF_PATH: String = OUT_DIR + "gallery_night_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "gallery_night_variants.tres"
const MAT_DIR: String = "res://world/materials/"
const KIT_DIR: String = "res://assets/arch/"
## Tagged marker (rehearsal F5): a Marker3D with an `objective_tag` property, which find_by_tag / the HUD resolve.
const OBJECTIVE_MARKER: GDScript = preload("res://world/kits/objective_marker.gd")
## Prefab id -> contract class_name (gameplay_prefabs.md). Scene = the class script's .tscn sibling (sl_builder_base).
const PREFAB_CLASSES: Dictionary = {"door": "Door", "window": "WindowPrefab"}
## Visual step boxes overlap their higher neighbour by this much (no ray-through seams).
const SEAM: float = 0.02
## Building surface classes -> material library (greybox kit materials).
const LIB_MATS: Dictionary = {
	"wall": "grey_wall", "wall_ext": "grey_wall_ext", "floor": "grey_floor", "ceiling": "grey_ceiling",
	"roof": "grey_ceiling", "stair": "grey_stair", "counter": "grey_counter", "prop": "grey_prop",
	"trim": "grey_trim", "glass": "grey_glass", "frame": "grey_frame", "door": "grey_door",
}
## Site surface classes (greybox flat colours, one per class; meta greybox = true). Ids resolve to a bullet
## surface through surface_map.json (asphalt / paving by name, court_stone by the `stone` keyword).
const SITE_MATS: Dictionary = {
	"asphalt": Color(0.1, 0.1, 0.11), "paving": Color(0.52, 0.5, 0.47), "court_stone": Color(0.6, 0.57, 0.5),
}

var map_root: HeistMap = null
var errors: PackedStringArray = PackedStringArray()
## Projected nav obstructions for props and prefabs: [corners (PackedVector3Array), elevation, height].
var obstructions: Array[Array] = []
var _lib_cache: Dictionary = {}
var _site_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _scene_cache: Dictionary = {}


# --- Generic helpers ---------------------------------------------------------------------------

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


func lib_mat(id: String) -> Material:
	var lib: String = String(LIB_MATS.get(id, ""))
	if lib == "":
		return _site_mat(id)
	if not _lib_cache.has(lib):
		_lib_cache[lib] = load(MAT_DIR + lib + ".tres") as Material
	return _lib_cache[lib]


func _site_mat(id: String) -> Material:
	if _site_cache.has(id):
		return _site_cache[id]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.resource_name = "gn_grey_" + id
	m.set_meta(&"greybox", true)
	if SITE_MATS.has(id):
		m.albedo_color = SITE_MATS[id]
		m.roughness = 0.9
	else:
		errors.append("unknown material class `%s`" % id)
		m.albedo_color = Color(1.0, 0.0, 1.0)
	_site_cache[id] = m
	return m


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


## Static box (world_static) from min/max corners: StaticBody3D + CollisionShape3D + MeshInstance3D. Every
## body gets a mesh (so SurfaceTags.tag_tree can tag it; the generator refuses untagged bodies).
func box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat_id: String) -> StaticBody3D:
	var size: Vector3 = mx - mn
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return null
	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.name = nm
	sb.position = (mn + mx) * 0.5
	add(parent, sb)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = box_shape(size)
	add(sb, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = box_mesh(size, mat_id)
	add(sb, mi)
	return sb


## Visual-only box mesh child (no collision) at local min/max corners.
func mesh_box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat_id: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = box_mesh(mx - mn, mat_id)
	mi.position = (mn + mx) * 0.5
	add(parent, mi)
	return mi


## Straight wall with rectangular openings. axis "x": runs along x at z = fixed; "z": along z at x = fixed.
## openings: [[along0, along1, y0, y1], ...] (absolute heights). Pieces are split at every floor level so the
## per-floor plan render cuts every wall.
func wall(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, thick: float,
		yr: Vector2, openings: Array, mat_id: String) -> void:
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
				holes.append(Vector2(maxf(float(o2[2]), yr.x), minf(float(o2[3]), yr.y)))
		holes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cur: float = yr.x
		var spans: Array[Vector2] = []
		for h: Vector2 in holes:
			if h.x > cur + 0.0001:
				spans.append(Vector2(cur, h.x))
			cur = maxf(cur, h.y)
		if yr.y > cur + 0.0001:
			spans.append(Vector2(cur, yr.y))
		for sp: Vector2 in spans:
			var lo: float = sp.x
			var split: Array[Vector2] = []
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


## Ramp collision: one StaticBody3D with convex prisms, each a (z, y) polygon extruded over x0..x1 (Dockside
## Burn / Shadow Ledger `_ramp`; stairs collide as ramps, next_heist §7.8).
func ramp(flight: Node3D, x0: float, x1: float, polys: Array) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = 1
	body.collision_mask = 0
	add(flight, body)
	for i: int in range(polys.size()):
		var pts: PackedVector3Array = PackedVector3Array()
		for pt: Vector2 in polys[i]:
			pts.append(Vector3(x0, pt.y, pt.x))
			pts.append(Vector3(x1, pt.y, pt.x))
		var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shp.points = pts
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Prism%d" % i
		col.shape = shp
		add(body, col)


## One straight flight along its local +Z from `origin` (first riser line, lower floor level): nr risers of r,
## (nr - 1) treads of t, width w. Steps are visual meshes (soffit 0.15 m below, or solid down to `solid_y`); the
## collision is a smooth ramp through the nosings, extended one tread back over the lower floor (validator
## convention (b)).
func flight(parent: Node3D, nm: String, origin: Vector3, yaw: float, w: float, nr: int, r: float, t: float,
		solid_y: Variant) -> Node3D:
	var f: Node3D = node3d(nm, origin)
	f.basis = yaw_basis(yaw)
	f.set_meta(&"kind", "stairs")
	add(parent, f)
	for k: int in range(1, nr):
		var top: float = float(k) * r
		var lo: float = (float(solid_y) - origin.y) if solid_y != null else top - r - 0.15
		mesh_box(f, "Step%02d" % k, Vector3(-w * 0.5, lo, float(k - 1) * t), Vector3(w * 0.5, top, float(k) * t + SEAM), "stair")
	var ramp_t: float = 0.3
	var end_z: float = float(nr - 1) * t
	if solid_y == null:
		ramp(f, -w * 0.5, w * 0.5, [[Vector2(-t, 0.0), Vector2(end_z, float(nr) * r), Vector2(end_z, float(nr) * r - ramp_t),
			Vector2(-t, -ramp_t)]])
	else:
		var lo2: float = minf(float(solid_y) - origin.y, -ramp_t)
		ramp(f, -w * 0.5, w * 0.5, [[Vector2(-t, 0.0), Vector2(end_z, float(nr) * r), Vector2(end_z, lo2), Vector2(-t, lo2)]])
	return f


## Balustrade: a thin full-height collider (true to the visual, next_heist §7.2) with a top-rail mesh.
func railing(parent: Node3D, nm: String, mn: Vector3, mx: Vector3) -> void:
	var body: StaticBody3D = box(parent, nm, mn, mx, "trim")
	if body == null:
		return
	body.set_meta(&"kind", "railing")


func area_boxes(area: Area3D, boxes: Array) -> void:
	for i: int in range(boxes.size()):
		var b: Array = boxes[i]
		var mn: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
		var mx: Vector3 = Vector3(float(b[3]), float(b[4]), float(b[5]))
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


func spawn(parent: Node3D, nm: String, kind: String, pos: Vector3, yaw: float, tags: Array, idle: String) -> SpawnPoint:
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
	return sp


## Placeholder for content that a later G1 step builds (a prefab, NPC spawn or prop): a Marker3D with meta
## `todo` (what goes here). Never a collision body, so validators see nothing half-built. With a `tag` it is a
## tagged marker (OBJECTIVE_MARKER: the `objective_tag` property, B5), so the mission / HUD already resolve it.
func placeholder(parent: Node3D, nm: String, world_pos: Vector3, todo: String, tag: String = "", yaw: float = 0.0) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	if tag != "":
		m.set_script(OBJECTIVE_MARKER)
		m.set(&"objective_tag", StringName(tag))
	m.name = nm
	m.transform = global_xform(parent).affine_inverse() * Transform3D(yaw_basis(yaw), world_pos)
	m.set_meta(&"todo", todo)
	add(parent, m)
	return m


## A node's transform relative to map_root (parents may be turned slots / prefabs).
func global_xform(c: Node3D) -> Transform3D:
	if c == map_root:
		return Transform3D.IDENTITY
	var xf: Transform3D = c.transform
	var p: Node = c.get_parent()
	while p != null and p != map_root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Greybox kit piece (assets/arch/<piece>/<piece>.glb), cached.
func kit_scene(piece: String) -> PackedScene:
	var path: String = "%s%s/%s.glb" % [KIT_DIR, piece, piece]
	if not _scene_cache.has(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			errors.append("missing kit piece %s" % path)
		_scene_cache[path] = ps
	return _scene_cache[path]


## Gameplay prefab scene by contract id, found by class name (never a path into game/systems); null + error if absent.
func prefab_scene(prefab: String) -> PackedScene:
	if _scene_cache.has(prefab):
		return _scene_cache[prefab]
	var cls: String = String(PREFAB_CLASSES.get(prefab, ""))
	var ps: PackedScene = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c["class"]) == cls:
			var path: String = String(c["path"]).get_basename() + ".tscn"
			if ResourceLoader.exists(path):
				ps = load(path) as PackedScene
	if ps == null:
		errors.append("gameplay prefab `%s` (class %s) not found" % [prefab, cls])
	_scene_cache[prefab] = ps
	return ps


## Records a projected navmesh obstruction for a box (local AABB under xform).
func obstruct(xform: Transform3D, aabb: AABB) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var lo: float = INF
	var hi: float = -INF
	for corner: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
		pts.append(xform * (aabb.position + aabb.size * corner))
	for cy: float in [aabb.position.y, aabb.end.y]:
		var w: Vector3 = xform * Vector3(aabb.position.x, cy, aabb.position.z)
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
	obstructions.append([pts, lo, hi - lo])


func n(path: String) -> Node3D:
	return map_root.get_node(path) as Node3D


# --- Scene normalisation (byte-stable regens; as shadow_ledger_resources.gd) --------------------

static func read_uid(path: String) -> String:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return ""
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	var first: String = f.get_line()
	f.close()
	var rx: RegEx = RegEx.create_from_string("uid=\"(uid://[a-z0-9]+)\"")
	var m: RegExMatch = rx.search(first)
	return m.get_string(1) if m != null else ""


## Rewrites the random parts of a saved .tscn (ext/sub resource ids, node unique_ids) as sequential values so
## reruns are byte-identical, and keeps the scene's previous uid.
static func normalize_scene(path: String, old_uid: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var ids: Dictionary = {}
	var ext_n: int = 0
	var sub_n: int = 0
	var decl: RegEx = RegEx.create_from_string("^\\[(ext_resource|sub_resource) [^\\n]*id=\"([^\"]+)\"")
	for line: String in text.split("\n"):
		var m: RegExMatch = decl.search(line)
		if m == null:
			continue
		if m.get_string(1) == "ext_resource":
			ext_n += 1
			ids["E|" + m.get_string(2)] = "%d_gn" % ext_n
		else:
			sub_n += 1
			ids["S|" + m.get_string(2)] = "gn_%d" % sub_n
	var out: PackedStringArray = PackedStringArray()
	var ref_ext: RegEx = RegEx.create_from_string("ExtResource\\(\"([^\"]+)\"\\)")
	var ref_sub: RegEx = RegEx.create_from_string("SubResource\\(\"([^\"]+)\"\\)")
	var uid_rx: RegEx = RegEx.create_from_string(" unique_id=[0-9]+")
	var node_n: int = 0
	for line2: String in text.split("\n"):
		var l: String = line2
		var m2: RegExMatch = decl.search(l)
		if m2 != null:
			var key: String = ("E|" if m2.get_string(1) == "ext_resource" else "S|") + m2.get_string(2)
			l = l.replace("id=\"%s\"" % m2.get_string(2), "id=\"%s\"" % ids[key])
		l = _replace_refs(l, ref_ext, ids, "E|", "ExtResource")
		l = _replace_refs(l, ref_sub, ids, "S|", "SubResource")
		if l.begins_with("[node ") and uid_rx.search(l) != null:
			node_n += 1
			l = uid_rx.sub(l, " unique_id=%d" % (100000 + node_n))
		if l.begins_with("[gd_scene") and old_uid != "":
			var hdr: RegEx = RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"")
			l = hdr.sub(l, "uid=\"%s\"" % old_uid)
		out.append(l)
	var w: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	w.store_string("\n".join(out))
	w.close()


static func _replace_refs(line: String, rx: RegEx, ids: Dictionary, prefix: String, fn: String) -> String:
	var out: String = ""
	var last: int = 0
	for m: RegExMatch in rx.search_all(line):
		var key: String = prefix + m.get_string(1)
		var rep: String = "%s(\"%s\")" % [fn, ids[key]] if ids.has(key) else m.get_string(0)
		out += line.substr(last, m.get_start() - last) + rep
		last = m.get_end()
	return out + line.substr(last)
