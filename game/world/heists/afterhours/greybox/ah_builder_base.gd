## Afterhours generator base: shared constants, state and generic helpers (AH-C1 G1 greybox). Owner: ENV C.
## Copy-adapted from rolling_thunder/greybox/rt_builder_base.gd (D-147 reuse-first; the RT chain is not shared code).
## Chain: ah_builder_base.gd <- ah_shell.gd <- ah_gameplay.gd <- build_greybox.gd (the --script entry point).
## Greybox only (G1): one flat library material per surface class (res://world/materials/grey_*.tres); the G2 art pass
## replaces these. Helpers follow the Gallery Night generator (walls with holes, ramp-collision stairs, prefab
## placement by contract class name, sequential-id scene normalisation).
extends SceneTree

const L: GDScript = preload("res://world/heists/afterhours/greybox/afterhours_layout.gd")
const LC: GDScript = preload("res://world/heists/afterhours/greybox/afterhours_layout_content.gd")
const R: GDScript = preload("res://world/heists/afterhours/greybox/afterhours_resources.gd")
const OUT_DIR: String = "res://world/heists/afterhours/"
const SCENE_PATH: String = OUT_DIR + "afterhours.tscn"
const DEF_PATH: String = OUT_DIR + "afterhours_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "afterhours_variants.tres"
## Mission script on the Mission node (ENV A's, AH-A1; the generator never edits it).
const MISSION_PATH: String = OUT_DIR + "afterhours_mission.gd"
## Tagged marker: a Marker3D with an `objective_tag` property (find_tagged / the HUD resolve it).
const OBJECTIVE_MARKER: GDScript = preload("res://world/kits/objective_marker.gd")
## Prefab id -> contract class_name (gameplay_prefabs.md); the scene is the class script's .tscn sibling.
const PREFAB_CLASSES: Dictionary = {
	"door": "Door", "window": "WindowPrefab", "loot_spawn": "LootSpawn", "keycard_pickup": "KeycardPickup",
	"keycard_reader": "KeycardReader", "keypad": "Keypad", "code_note": "CodeNote", "hack_terminal": "HackTerminal",
	"security_camera": "SecurityCamera", "camera_station": "CameraStation", "laser_grid": "LaserGrid", "safe": "Safe",
	"deposit_box": "DepositBox", "small_loot": "SmallLoot", "display_case": "DisplayCase", "drill_point": "DrillPoint",
	"alarm_button": "AlarmButton", "phone": "Phone", "body_container": "BodyContainer", "ladder": "Ladder",
	"secure_zone": "SecureZone", "escape_zone": "EscapeZone", "bag_lift": "BagLift", "padlock": "Padlock",
	"burn_point": "BurnPoint", "item_pickup": "ItemPickup", "gear_pickup": "GearPickup",
}
## Greybox surface classes -> library material (the bullet surface follows the material, surface_map.json).
const CLASS_MAT: Dictionary = {
	"wall": "grey_wall", "wall_ext": "grey_wall_ext", "wall_vault": "grey_wall_ext", "floor": "grey_floor",
	"roof": "grey_floor", "ceiling": "grey_ceiling", "stair": "grey_stair", "glass": "grey_glass",
	"counter": "grey_counter", "prop": "grey_prop", "trim": "grey_trim", "frame": "grey_frame", "paving": "grey_floor",
	"asphalt": "grey_floor", "door": "grey_door", "handrail": "grey_trim", "rail": "grey_frame",
	"mesh": "grey_frame",
}
## Not-standable guard tops (D-104 `slopes`): class "rail" boxes get a ridged collider (world/kits/ridge_top.gd).
const RT: GDScript = preload("res://world/kits/ridge_top.gd")
const MAT_DIR: String = "res://world/materials/"
## Visual step boxes overlap their higher neighbour by this much (no ray-through seams).
const SEAM: float = 0.02
## Visual steps stop this far inside the flight's sides (the collision ramp keeps the full width).
const STEP_INSET: float = 0.005
## A flight's ramp collider runs this far flat onto the floor at its top (no seam with the landing; GN-8 / SL-P1).
const RAMP_TONGUE: float = 0.3
const VIEWMODEL_LIT_LAYER: int = 1 << 20
## Exports a row may set before the prefab has them (ENV A lands the export later; set_prop skips them until then):
## BagLift.phase_block_key (env/a-core 417425fd); Door.height_m (D-158, env/a-core 75400478); Door.civilian_allowed (A, the
## D-075 guest doors: P casing seed 6501).
const OPTIONAL_PROPS: Array[String] = ["phase_block_key", "height_m", "civilian_allowed"]

var map_root: HeistMap = null
var errors: PackedStringArray = PackedStringArray()
## Projected nav obstructions: [corners (PackedVector3Array), elevation, height, carve (exact, not grown by the agent
## radius)].
var obstructions: Array[Array] = []
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
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


static func v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _material(cls: String) -> Material:
	var id: String = String(CLASS_MAT.get(cls, "grey_prop"))
	if not _mat_cache.has(id):
		_mat_cache[id] = load(MAT_DIR + id + ".tres") as Material
		if _mat_cache[id] == null:
			errors.append("missing material %s" % id)
	return _mat_cache[id]


func _surface(cls: String) -> StringName:
	return SurfaceTags.for_id(String(CLASS_MAT.get(cls, "grey_prop")))


func _box_mesh(size: Vector3, cls: String) -> Mesh:
	var key: String = "%s|%.3f|%.3f|%.3f" % [cls, size.x, size.y, size.z]
	if not _mesh_cache.has(key):
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		bm.material = _material(cls)
		_mesh_cache[key] = bm
	return _mesh_cache[key]


func _box_shape(size: Vector3) -> BoxShape3D:
	var key: String = "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if not _shape_cache.has(key):
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		_shape_cache[key] = bs
	return _shape_cache[key]


## Static box (world_static) from WORLD min/max corners under `parent` (parents sit at the origin): StaticBody3D +
## CollisionShape3D + MeshInstance3D in the class's greybox material, tagged with the class's bullet surface.
func box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, cls: String) -> StaticBody3D:
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
	col.shape = RT.shape(size) if cls == "rail" else _box_shape(size)
	add(sb, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, cls)
	add(sb, mi)
	SurfaceTags.tag(sb, _surface(cls))
	_glaze(sb, cls)
	return sb


## Clear glazing (all greybox glass is clear at G1): meta `see_through` (levelcheck) + the persistent group
## `see_through` (D-142: vision passes it; it still blocks movement and bullets).
## (class "mesh": a steel mesh panel, e.g. the G10 stock cage, is see-through the same way)
static func _glaze(body: StaticBody3D, cls: String) -> void:
	if cls == "glass" or cls == "mesh":
		body.set_meta(&"see_through", true)
		body.add_to_group(&"see_through", true)


## Visual-only box (no collision) from world corners.
func mesh_box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, cls: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = _box_mesh(mx - mn, cls)
	mi.position = (mn + mx) * 0.5
	add(parent, mi)
	return mi


## Straight wall with rectangular holes. axis "x": runs along x at z = fixed; "z": along z at x = fixed.
## holes: [[a0, a1, y0, y1], ...] (absolute heights). Pieces split at every floor level (plan renders).
func wall(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, thick: float, yr: Vector2,
		holes_in: Array, cls: String) -> void:
	var cuts: Array[float] = [a0, a1]
	for o: Array in holes_in:
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
		var hs: Array[Vector2] = []
		for o2: Array in holes_in:
			if float(o2[0]) <= p + 0.0001 and float(o2[1]) >= q - 0.0001:
				hs.append(Vector2(maxf(float(o2[2]), yr.x), minf(float(o2[3]), yr.y)))
		hs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cur: float = yr.x
		var spans: Array[Vector2] = []
		for h: Vector2 in hs:
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
				var mn: Vector3 = Vector3(p, s.x, fixed - thick * 0.5) if axis == "x" else Vector3(fixed - thick * 0.5, s.x, p)
				var mx: Vector3 = Vector3(q, s.y, fixed + thick * 0.5) if axis == "x" else Vector3(fixed + thick * 0.5, s.y, q)
				box(parent, "%s_%02d" % [nm, part], mn, mx, cls)
				part += 1


## Convex body (collision + mesh) from world points; `faces` = point-index polygons, counter-clockwise from outside
## (emitted by afterhours_geometry.py; AH has none at G1). Godot's front faces wind clockwise, so the fans are reversed.
func hull(parent: Node3D, nm: String, pts: Array, faces: Array, cls: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	add(parent, body)
	var pv: PackedVector3Array = PackedVector3Array()
	for p: Variant in pts:
		pv.append(v3(p))
	var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shp.points = pv
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shp
	add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fc: Variant in faces:
		var poly: Array = fc
		var a: Vector3 = pv[int(poly[0])]
		var nrm: Vector3 = (pv[int(poly[1])] - a).cross(pv[int(poly[2])] - a).normalized()
		for k: int in range(1, poly.size() - 1):
			for idx: int in [int(poly[0]), int(poly[k + 1]), int(poly[k])]:
				st.set_normal(nrm)
				st.add_vertex(pv[idx])
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, _material(cls))
	mi.mesh = mesh
	add(body, mi)
	SurfaceTags.tag(body, _surface(cls))
	_glaze(body, cls)
	return body


## Ramp collision: convex prisms, each a (z, y) polygon extruded over x0..x1 in the flight's local frame.
func _ramp(flight_node: Node3D, x0: float, x1: float, polys: Array) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = 1
	body.collision_mask = 0
	add(flight_node, body)
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
## (nr - 1) treads of t, width w. Visual steps (soffit 0.15 m below); collision is a smooth ramp through the nosings,
## one tread back over the lower floor and RAMP_TONGUE flat onto the upper one (GN-8 / SL-P1).
func flight(parent: Node3D, nm: String, origin: Vector3, yaw: float, w: float, nr: int, r: float, t: float) -> Node3D:
	var f: Node3D = node3d(nm, origin)
	f.basis = yaw_basis(yaw)
	f.set_meta(&"kind", "stairs")
	add(parent, f)
	for k: int in range(1, nr):
		var top: float = float(k) * r
		var mn: Vector3 = Vector3(-w * 0.5 + STEP_INSET, top - r - 0.15, float(k - 1) * t)
		var mx: Vector3 = Vector3(w * 0.5 - STEP_INSET, top, float(k) * t + SEAM)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Step%02d" % k
		mi.mesh = _box_mesh(mx - mn, "stair")
		mi.position = (mn + mx) * 0.5
		add(f, mi)
	var ramp_t: float = 0.3
	var end_z: float = float(nr - 1) * t
	var h: float = float(nr) * r
	var tip: float = end_z + RAMP_TONGUE
	_ramp(f, -w * 0.5, w * 0.5, [[Vector2(-t, 0.0), Vector2(end_z, h), Vector2(tip, h), Vector2(tip, h - ramp_t),
		Vector2(-t, -ramp_t)]])
	SurfaceTags.tag(f.get_node("Ramp"), _surface("stair"))
	return f


## Handrail (5 cm bar, world a -> b) with collision and meta kind handrail (lc_stair_rails reads its box).
func handrail(parent: Node3D, nm: String, a: Vector3, b: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = (a + b) * 0.5
	body.basis = Basis.looking_at(b - a, Vector3.UP)
	body.set_meta(&"kind", "handrail")
	add(parent, body)
	var size: Vector3 = Vector3(0.05, 0.05, a.distance_to(b))
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(size)
	add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, "handrail")
	add(body, mi)
	SurfaceTags.tag(body, _surface("handrail"))


func _area_boxes(area: Area3D, boxes: Array) -> void:
	for i: int in range(boxes.size()):
		var b: Array = boxes[i]
		var mn: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
		var mx: Vector3 = Vector3(float(b[3]), float(b[4]), float(b[5]))
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Shape" if i == 0 else "Shape%d" % i
		col.shape = _box_shape(mx - mn)
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
	_area_boxes(z, boxes)
	return z


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


func spawn(parent: Node3D, nm: String, kind: String, pos: Vector3, yaw: float, tags: Array, idle: String) -> SpawnPoint:
	var sp: SpawnPoint = SpawnPoint.new()
	sp.name = nm
	sp.kind = SpawnPoint.Kind[kind]
	var tg: Array[StringName] = []
	for t: Variant in tags:
		tg.append(StringName(String(t)))
	sp.tags = tg
	sp.idle_activity = StringName(idle)
	sp.transform = global_xform(parent).affine_inverse() * Transform3D(yaw_basis(yaw), pos)
	add(parent, sp)
	return sp


## A tagged marker (OBJECTIVE_MARKER when `tag` is set) at a world position, meta `todo`.
func marker(parent: Node3D, nm: String, world_pos: Vector3, yaw: float, tag: String, todo: String) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	if tag != "":
		m.set_script(OBJECTIVE_MARKER)
		m.set(&"objective_tag", StringName(tag))
	m.name = nm
	m.transform = global_xform(parent).affine_inverse() * Transform3D(yaw_basis(yaw), world_pos)
	if todo != "":
		m.set_meta(&"todo", todo)
	add(parent, m)
	return m


func n(path: String) -> Node3D:
	return map_root.get_node(path) as Node3D


## Records a projected navmesh obstruction for a box (local AABB under xform); `carve` cuts it exactly (no agent radius).
func obstruct(xform: Transform3D, aabb: AABB, carve: bool = false) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var lo: float = INF
	var hi: float = -INF
	for corner: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
		pts.append(xform * (aabb.position + aabb.size * corner))
	for cy: float in [aabb.position.y, aabb.end.y]:
		var w: Vector3 = xform * Vector3(aabb.position.x, cy, aabb.position.z)
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
	obstructions.append([pts, lo, hi - lo, carve])


## Gameplay prefab scene by contract id, found by class name (never a path into game/systems).
func _prefab_scene(prefab: String) -> PackedScene:
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


## Catalog prop scene by asset id (PropCatalog `scene`), or a res:// path; null + error if absent.
func catalog_scene(asset_id: String) -> PackedScene:
	if asset_id.begins_with("res://"):
		if not _scene_cache.has(asset_id):
			_scene_cache[asset_id] = load(asset_id) as PackedScene
		return _scene_cache[asset_id]
	var e: Dictionary = PropCatalog.entry(StringName(asset_id))
	var path: String = String(e.get("scene", ""))
	if path == "":
		errors.append("catalog asset %s not found" % asset_id)
		return null
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) as PackedScene
	return _scene_cache[path]


## Nav obstruction for a catalog visual's AABB ([x, y, z, sx, sy, sz], root-local) at a world transform.
func _obstruct_catalog(asset_id: String, xf: Transform3D) -> void:
	if asset_id == "" or asset_id.begins_with("res://"):
		return
	var a: Array = PropCatalog.entry(StringName(asset_id)).get("aabb", [])
	if a.size() == 6:
		obstruct(xf, AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5])))


## Sets an export, coercing data values: "enum:KEY" -> the script's enum value, String -> StringName, [x, y, z] ->
## Vector3, [a, b] -> Vector2i for Vector2i exports, arrays into typed arrays (StringName elements).
func set_prop(inst: Node, prop: String, value: Variant) -> void:
	var cur: Variant = null
	var found: bool = false
	for p: Dictionary in inst.get_property_list():
		if String(p["name"]) == prop:
			found = true
			cur = inst.get(prop)
			break
	if not found:
		if prop in OPTIONAL_PROPS:   # set once the prefab has the export; silently skipped before that
			return
		errors.append("%s has no property `%s`" % [inst.name, prop])
		return
	if value is String and String(value).begins_with("enum:"):
		inst.set(prop, _enum_value(inst, String(value).substr(5)))
		return
	match typeof(cur):
		TYPE_STRING_NAME:
			inst.set(prop, StringName(String(value)))
		TYPE_VECTOR3:
			inst.set(prop, v3(value))
		TYPE_VECTOR2I:
			inst.set(prop, Vector2i(int(value[0]), int(value[1])))
		TYPE_ARRAY:
			var arr: Array = cur
			if arr.is_typed() and arr.get_typed_builtin() == TYPE_STRING_NAME:
				var typed: Array[StringName] = []
				for v: Variant in value:
					typed.append(StringName(String(v)))
				inst.set(prop, typed)
			else:
				inst.set(prop, value)
		_:
			inst.set(prop, value)


func _enum_value(inst: Node, key: String) -> int:
	var scr: Script = inst.get_script() as Script
	if scr != null:
		for c: Variant in scr.get_script_constant_map().values():
			if c is Dictionary and (c as Dictionary).has(key):
				return int((c as Dictionary)[key])
	errors.append("enum key %s not found on %s" % [key, inst.name])
	return 0


## Transform at `at` whose -Z looks (horizontally) at `target`.
static func _facing(at: Vector3, target: Vector3) -> Transform3D:
	var to_obj: Vector3 = target - at
	to_obj.y = 0.0
	if to_obj.length() < 0.01:
		to_obj = Vector3.FORWARD
	return Transform3D(Basis.looking_at(to_obj.normalized(), Vector3.UP), at)


# --- Scene normalisation (byte-stable regens; as the GN / SL generators) --------------------------

static func _read_uid(path: String) -> String:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return ""
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	var first: String = f.get_line()
	f.close()
	var rx: RegEx = RegEx.create_from_string("uid=\"(uid://[a-z0-9]+)\"")
	var m: RegExMatch = rx.search(first)
	return m.get_string(1) if m != null else ""


## Rewrites the random parts of a saved .tscn / .tres (ext/sub resource ids, node unique_ids) as sequential values so
## reruns are byte-identical, and keeps the file's previous uid.
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
			ids["E|" + m.get_string(2)] = "%d_ah" % ext_n
		else:
			sub_n += 1
			ids["S|" + m.get_string(2)] = "ah_%d" % sub_n
	var out: PackedStringArray = PackedStringArray()
	var ref_ext: RegEx = RegEx.create_from_string("ExtResource\\(\"([^\"]+)\"\\)")
	var ref_sub: RegEx = RegEx.create_from_string("SubResource\\(\"([^\"]+)\"\\)")
	var uid_rx: RegEx = RegEx.create_from_string(" unique_id=[0-9]+")
	var hdr: RegEx = RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"")
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
		if (l.begins_with("[gd_scene") or l.begins_with("[gd_resource")) and old_uid != "":
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
