## Safehouse G2 surface pass (C4-03; safehouse.md §Lighting and mood palette). Owner: ENV C. Copy-adapted from Rolling
## Thunder's rt_finish.gd (D-147; the chains are not shared code): every Geometry box is re-faced with library finishes
## per room (floor / walls / ceiling), the exterior rule for faces outside the rooms, the class rules for the closed
## exterior doors (green enamel), the frosted windows and the rooflight glass; the stations' and props' greybox stand-ins
## get a world-triplanar library override until their art lands. Data below. Deterministic: tree order, sorted keys.
## Called by build_safehouse.gd after the stations / props and before the lighting lane and the navmesh bake.
extends RefCounted

const L: GDScript = preload("res://world/hub/safehouse/greybox/safehouse_layout.gd")
const M: GDScript = preload("res://world/heists/glasshouse/greybox/gh_mesh.gd")
const MAT_DIR: String = "res://world/materials/"
const PROBE: float = 0.3
const EPS: float = 0.004
const HASH: float = 2.0
const NORMALS: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK]
const FOLDER: String = "Finish"
## The ground slab is cut by the rooms only: a cut at every wall piece's end ran the whole slab and an eye ray along
## such a seam slipped between the two faces (bounds, C4-03). Its pieces under the walls are hidden inside them.
const GROUND_PATH: String = "Building/Ground/"
## Compatibility path (the low-end players): a merged room mesh gets every light in range per pixel (C4-03: the hall's
## one mesh cost ~5 s a frame on llvmpipe), so every room's floors / ceilings go to SLAB_TILE tiles and its walls to
## wall tiles (gh_mesh tile_groups / wall_tile_groups, as Glasshouse): each tile gets the lights around it. Visual only.
const SLAB_TILE: float = 4.0
const WALL_TILE_MIN_RUN: float = 1.0

## Finish key -> [library material id, albedo tint (null: the library's own)]. The G0 palette: aged brick (bare in the
## loading bay, the workshop and the kit store), the hall and the rooms limewashed (warm-white plaster), print-works
## green enamel (#2F4A3E: doors, the press), sealed concrete, oak boards, terrazzo.
const KEYS: Dictionary = {
	"brick": ["brick_red", null],
	"concrete": ["concrete", null],
	"enamel_green": ["metal_painted", Color(0.18, 0.29, 0.24)],
	"cast_iron": ["metal_painted", Color(0.1, 0.1, 0.1)],
	"frosted": ["glass_frosted", null],
	"limewash": ["plaster_painted", Color(0.93, 0.9, 0.83)],
	"metal": ["metal_painted", null],
	"oak": ["wood_panel_oak", null],
	"paper": ["plaster_painted", Color(0.9, 0.88, 0.8)],
	"plywood": ["plywood_painted", null],
	"polymer": ["polymer_black", null],
	"red": ["metal_painted", Color(0.7, 0.08, 0.06)],
	"gunmetal": ["metal_painted", Color(0.42, 0.43, 0.44)],
	"tabletop": ["metal_painted", Color(0.7, 0.69, 0.66)],
	"terrazzo": ["terrazzo", null],
	"tile": ["tile_ceramic_white", null],
	"van": ["metal_painted", Color(0.32, 0.34, 0.35)],
	"walnut": ["wood_veneer_walnut", null],
}
## Room id -> [floor, walls, ceiling].
const ROOM_FINISH: Dictionary = {
	"LB": ["concrete", "brick", "concrete"], "H1": ["concrete", "limewash", "concrete"],
	"LG": ["oak", "limewash", "limewash"], "WS": ["concrete", "brick", "concrete"],
	"MK": ["concrete", "limewash", "limewash"], "CO": ["concrete", "limewash", "limewash"],
	"WC": ["terrazzo", "tile", "limewash"], "ST": ["concrete", "limewash", "limewash"],
	"BK": ["oak", "limewash", "limewash"], "RV": ["concrete", "limewash", "limewash"],
	"KS": ["concrete", "brick", "concrete"],
}
## Greybox classes whose faces keep their own finish inside the rooms too (the closed doors, the frosted panes).
const CLASS_FINISH: Dictionary = {"door": "enamel_green", "glass_frosted": "frosted", "prop": "red"}
## Faces outside the rooms: the first matching [path prefix (under Geometry/), greybox class ("" = any), finish key];
## "" drops the face. The rooflight wells are seen from the hall; the outer faces only from the rooflights.
const EXTERIOR: Array = [
	["Building/Rooflights/", "ceiling", "limewash"],
	["Building/Ceilings/", "", ""],
	["Building/Walls/", "", "brick"],
	["Building/", "", "concrete"],
]
## The stations' and props' greybox stand-ins (and any other non-box greybox mesh): [path prefix, finish key].
const OVERRIDES: Array = [
	["Stations/board/", "plywood"],
	["Stations/planning/Visual/Greybox/Top", "tabletop"],   # G3: a light top, so the pendant pool reads on it
	["Stations/planning/", "gunmetal"],   # not steel_bare: a bare metal reads black until its probe renders
	["Stations/armory/", "oak"],
	["Stations/masks/", "oak"],
	["Stations/jukebox/", "walnut"],
	["Stations/notoriety/Visual/Greybox/Clippings", "paper"],
	["Stations/notoriety/", "cast_iron"],
	["Stations/range/", "enamel_green"],
	["Stations/crew/Visual/Greybox/Phone", "polymer"],
	["Stations/crew/", "plywood"],
	["Stations/profile/", "plywood"],
	["Props/CrewVan", "van"],
	["Props/LiveFireLamp", "red"],
	["", "concrete"],
]

var b: Object
var root: Node3D
var report: PackedStringArray = PackedStringArray()
var acc: RefCounted = M.new()
## [rid, purpose, AABB]
var _rooms: Array[Array] = []
var _mats: Dictionary = {}
var _tri: Dictionary = {}
var _glass: Material = null
## Solids: [aabb, index]; a HASH grid of their indices.
var _solids: Array[AABB] = []
var _grid: Dictionary = {}
## BoxMesh instance id -> greybox class (the builder's mesh cache keys).
var _cls: Dictionary = {}
var _counts: Dictionary = {"boxes": 0, "pieces": 0, "buried": 0, "coplanar": 0, "overrides": 0, "glass": 0}


func _init(builder: Object) -> void:
	b = builder


func build() -> void:
	root = b.get(&"map_root")
	_setup_materials()
	for rid: String in ROOM_FINISH:
		acc.tile_groups["R_" + rid] = SLAB_TILE
		acc.wall_tile_groups["R_" + rid] = WALL_TILE_MIN_RUN
	for r: Array in L.ROOMS:
		if not ROOM_FINISH.has(String(r[0])):
			continue
		var a: Array = r[3]
		var lo: Vector3 = Vector3(float(a[0]), float(a[1]), float(a[2]))
		_rooms.append([String(r[0]), String(r[1]), AABB(lo, Vector3(float(a[3]), float(a[4]), float(a[5])) - lo)])
	var cache: Dictionary = b.get(&"_mesh_cache")
	for k: Variant in cache:
		var mesh: Mesh = cache[k]
		_cls[mesh.get_instance_id()] = String(k).get_slice("|", 0)
	var geo: Node3D = root.get_node("Geometry") as Node3D
	var boxes: Array[Array] = []   # [mi, aabb, cls, path]
	var others: Array[MeshInstance3D] = []
	_collect(geo, boxes, others)
	for i: int in range(boxes.size()):
		_add_solid(boxes[i][1], i)
	for i2: int in range(boxes.size()):
		_box(boxes[i2][0], boxes[i2][1], String(boxes[i2][2]), String(boxes[i2][3]), i2)
	for mi: MeshInstance3D in others:
		_override(mi)
	for top: String in ["Stations", "Props"]:
		var t: Node = root.get_node_or_null(top)
		if t == null:
			continue
		for n: Node in t.find_children("*", "MeshInstance3D", true, false):
			if _grey(n as MeshInstance3D):
				_override(n as MeshInstance3D)
	var parent: Node3D = b.call(&"add", geo, b.call(&"node3d", FOLDER)) as Node3D
	acc.flush(parent, root)
	report.append("finishes: %d boxes re-faced in %d pieces (%d buried, %d coplanar dropped), %d overrides, %d glass"
		% [_counts["boxes"], _counts["pieces"], _counts["buried"], _counts["coplanar"], _counts["overrides"],
			_counts["glass"]])
	var errs: PackedStringArray = b.get(&"errors")
	for line: String in report:
		printerr("finish: " + line)
		if line.begins_with("ERROR"):
			errs.append(line)
	b.set(&"errors", errs)


func _setup_materials() -> void:
	var keys: Array = KEYS.keys()
	keys.sort()
	for k: Variant in keys:
		var row: Array = KEYS[k]
		var lib: BaseMaterial3D = load(MAT_DIR + String(row[0]) + ".tres") as BaseMaterial3D
		if lib == null:
			report.append("ERROR finish: no library material %s" % row[0])
			continue
		var m: Material = lib
		if row[1] != null:
			var t: BaseMaterial3D = lib.duplicate() as BaseMaterial3D
			t.resource_name = "sh_" + String(k)
			t.albedo_color = row[1]
			m = t
		_mats[String(k)] = m
	for k2: Variant in keys:
		if _mats.has(String(k2)):
			acc.register_material(String(k2), _triplanar(String(k2)))  # one instance per finish: the hull overrides
			# and the re-faced boxes share it, so their coplanar seams never z-fight
	var src: BaseMaterial3D = load(MAT_DIR + "glass_clear.tres") as BaseMaterial3D
	var g: BaseMaterial3D = src.duplicate() as BaseMaterial3D
	g.resource_name = "sh_glass"
	g.uv1_triplanar = true
	g.uv1_world_triplanar = true
	g.uv1_scale = Vector3.ONE   # 512 px over 1 m: 512 px/m (as OF's glass)
	g.cull_mode = BaseMaterial3D.CULL_DISABLED
	g.albedo_color = Color(0.86, 0.9, 0.9, 0.5)
	_glass = g


## World-triplanar copy of a finish (512 px/m for the 1024 px library).
func _triplanar(key: String) -> Material:
	if key == "glass":
		return _glass
	if _tri.has(key):
		return _tri[key]
	var m: BaseMaterial3D = (_mats[key] as BaseMaterial3D).duplicate() as BaseMaterial3D
	m.resource_name = "sh_tri_" + key
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * (1.0 / M.TILE_M)
	_tri[key] = m
	return m


static func _lib_of(key: String) -> String:
	if key == "glass":
		return "glass_clear"
	return String((KEYS[key] as Array)[0]) if KEYS.has(key) else key


# --- Collection ----------------------------------------------------------------------------------

static func _grey(mi: MeshInstance3D) -> bool:
	if mi == null or mi.material_override != null or mi.mesh == null or mi.mesh.get_surface_count() == 0 or not mi.visible:
		return false
	var m: Material = mi.mesh.surface_get_material(0)
	return m != null and m.resource_path.get_file().begins_with("grey_")


func _collect(n: Node, boxes: Array[Array], others: Array[MeshInstance3D]) -> void:
	for c: Node in n.get_children():
		if String(c.name) == FOLDER:
			continue
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null and _grey(mi):
			var xf: Transform3D = b.call(&"global_xform", mi)
			var boxy: bool = mi.mesh is BoxMesh and xf.basis.is_equal_approx(Basis.IDENTITY) \
				and mi.get_parent() is StaticBody3D and _cls.has(mi.mesh.get_instance_id())
			if boxy:
				var sz: Vector3 = (mi.mesh as BoxMesh).size
				var path: String = String(root.get_node("Geometry").get_path_to(mi.get_parent()))
				boxes.append([mi, AABB(xf.origin - sz * 0.5, sz), String(_cls[mi.mesh.get_instance_id()]), path])
			else:
				others.append(mi)
		_collect(c, boxes, others)


func _add_solid(a: AABB, idx: int) -> void:
	_solids.append(a)
	for k: Vector3i in _cells(a):
		if not _grid.has(k):
			_grid[k] = []
		(_grid[k] as Array).append(idx)


static func _cells(a: AABB) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var lo: Vector3i = Vector3i(floori(a.position.x / HASH), floori(a.position.y / HASH), floori(a.position.z / HASH))
	var hi: Vector3i = Vector3i(floori(a.end.x / HASH), floori(a.end.y / HASH), floori(a.end.z / HASH))
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				out.append(Vector3i(x, y, z))
	return out


## Solid indices whose box meets `a` (sorted, unique).
func _near(a: AABB) -> Array[int]:
	var seen: Dictionary = {}
	for k: Vector3i in _cells(a):
		for i: Variant in _grid.get(k, []):
			if not seen.has(i) and _solids[int(i)].intersects(a):
				seen[i] = true
	var out: Array[int] = []
	for i2: Variant in seen:
		out.append(int(i2))
	out.sort()
	return out


static func _strict_has(a: AABB, p: Vector3) -> bool:
	return p.x > a.position.x and p.x < a.end.x and p.y > a.position.y and p.y < a.end.y and p.z > a.position.z \
		and p.z < a.end.z


func room_at(p: Vector3) -> Array:
	for r: Array in _rooms:
		if (r[2] as AABB).grow(0.001).has_point(p):
			return r
	return []


# --- Boxes ---------------------------------------------------------------------------------------

func _box(mi: MeshInstance3D, a: AABB, cls: String, path: String, self_id: int) -> void:
	var votes: Dictionary = {}
	var near: Array[int] = _near(a.grow(PROBE + 0.01))
	for f: int in range(6):
		var n: Vector3 = NORMALS[f]
		var ax: int = f >> 1
		var sgn: float = 1.0 if f % 2 == 1 else -1.0
		var plane: float = a.end[ax] if sgn > 0.0 else a.position[ax]
		var ua: int = (ax + 1) % 3
		var va: int = (ax + 2) % 3
		var cu: Array[float] = [a.position[ua], a.end[ua]]
		var cv: Array[float] = [a.position[va], a.end[va]]
		var pp: float = plane + sgn * PROBE
		for r: Array in _rooms:
			var rb: AABB = r[2]
			if rb.position[ax] <= pp and rb.end[ax] >= pp and _overlaps(rb, a, ua, va):
				_cut_into(cu, rb.position[ua], rb.end[ua])
				_cut_into(cv, rb.position[va], rb.end[va])
		for j: int in near:
			if j == self_id or path.begins_with(GROUND_PATH):   # the slab: rooms cut it, its solids do not
				continue
			var s: AABB = _solids[j]
			if s.position[ax] <= plane + EPS and s.end[ax] >= plane - EPS and _overlaps(s, a, ua, va):
				_cut_into(cu, s.position[ua], s.end[ua])
				_cut_into(cv, s.position[va], s.end[va])
		cu.sort()
		cv.sort()
		for iu: int in range(cu.size() - 1):
			for iv: int in range(cv.size() - 1):
				var u0: float = cu[iu]
				var u1: float = cu[iu + 1]
				var v0: float = cv[iv]
				var v1: float = cv[iv + 1]
				if u1 - u0 < 0.001 or v1 - v0 < 0.001:
					continue
				var c: Vector3 = Vector3.ZERO
				c[ax] = plane
				c[ua] = (u0 + u1) * 0.5
				c[va] = (v0 + v1) * 0.5
				if _buried(c + n * EPS, near, self_id):
					_counts["buried"] += 1   # kept: levelcheck seam_gaps rays start inside the walls at the corners
				if _coplanar_lower(c - n * EPS, near, self_id, ax, sgn, plane):
					_counts["coplanar"] += 1
					continue
				var key: String = _key(c + n * PROBE, n, cls, path)
				if key == "":
					continue
				var room: Array = room_at(c + n * PROBE)
				var group: String = ("R_" + String(room[0]).replace("-", "")) if not room.is_empty() \
					else "X_" + path.get_slice("/", 1)
				var q: Array[Vector3] = []
				var drawn: float = plane
				for uv: Vector2 in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
					var p: Vector3 = Vector3.ZERO
					p[ax] = drawn
					p[ua] = uv.x
					p[va] = uv.y
					q.append(p)
				if key == "glass":
					_glass_quad(q, n)
				elif key == "frosted":   # transparent: its own mesh, never in a room's merged opaque mesh (C4-03:
					# sharing the hall's mesh cost ~5 s a frame on the Compatibility path)
					acc.quad("Frosted", key, q[0], q[1], q[2], q[3], n)
				else:
					acc.quad(group, key, q[0], q[1], q[2], q[3], n)
				var lib: String = _lib_of(key)
				votes[lib] = float(votes.get(lib, 0.0)) + (u1 - u0) * (v1 - v0)
				_counts["pieces"] += 1
	_counts["boxes"] += 1
	var body: Node = mi.get_parent()
	if not votes.is_empty():
		var best: String = ""
		var best_a: float = -1.0
		var libs: Array = votes.keys()
		libs.sort()
		for l: Variant in libs:
			if float(votes[l]) > best_a:
				best_a = float(votes[l])
				best = String(l)
		SurfaceTags.tag(body, SurfaceTags.for_id(best))
	body.remove_child(mi)
	mi.free()


## True when boxes `p` and `q` overlap (with area) on the axes `ua` and `va`.
static func _overlaps(p: AABB, q: AABB, ua: int, va: int) -> bool:
	return p.position[ua] < q.end[ua] - 0.001 and p.end[ua] > q.position[ua] + 0.001 \
		and p.position[va] < q.end[va] - 0.001 and p.end[va] > q.position[va] + 0.001


static func _cut_into(cuts: Array[float], lo: float, hi: float) -> void:
	for v: float in [lo, hi]:
		if v > cuts[0] + 0.001 and v < cuts[1] - 0.001 and not _has_near(cuts, v):
			cuts.append(v)


static func _has_near(cuts: Array[float], v: float) -> bool:
	for c: float in cuts:
		if absf(c - v) < 0.001:
			return true
	return false


func _buried(p: Vector3, near: Array[int], self_id: int) -> bool:
	for j: int in near:
		if j != self_id and _strict_has(_solids[j], p):
			return true
	return false


## True when a lower box has a same-facing face on this plane over the point (it draws the piece).
func _coplanar_lower(p: Vector3, near: Array[int], self_id: int, ax: int, sgn: float, plane: float) -> bool:
	for j: int in near:
		if j >= self_id:
			break
		var s: AABB = _solids[j]
		var fp: float = s.end[ax] if sgn > 0.0 else s.position[ax]
		if absf(fp - plane) < 0.002 and _strict_has(s, p):
			return true
	return false


## The finish of a piece whose probe (0.3 m off it) is `p`: the class's own (doors, frosted panes, the lamp), else the
## room's, else the exterior rule.
func _key(p: Vector3, n: Vector3, cls: String, path: String) -> String:
	if cls == "glass":
		return "glass"
	if CLASS_FINISH.has(cls):
		return String(CLASS_FINISH[cls])
	var room: Array = room_at(p)
	if not room.is_empty():
		var fin: Array = ROOM_FINISH[String(room[0])]
		return String(fin[0] if n.y > 0.7 else (fin[2] if n.y < -0.7 else fin[1]))
	for rule: Array in EXTERIOR:
		if path.begins_with(String(rule[0])) and (String(rule[1]) == "" or String(rule[1]) == cls):
			return String(rule[2])
	return "concrete"


func _glass_quad(q: Array[Vector3], n: Vector3) -> void:
	if not acc.has_material("glass"):
		acc.register_material("glass", _glass)
	acc.quad("Glass", "glass", q[0], q[1], q[2], q[3], n)
	_counts["glass"] += 1


# --- Overrides -----------------------------------------------------------------------------------

func _override(mi: MeshInstance3D) -> void:
	var path: String = String(root.get_path_to(mi))
	var key: String = "concrete"
	var mat: Material = mi.mesh.surface_get_material(0)
	var body: Node = mi.get_parent()
	if mat != null and mat.resource_path.get_file() == "grey_glass.tres":
		key = "glass"
	else:
		for rule: Array in OVERRIDES:
			if path.begins_with(String(rule[0])):
				key = String(rule[1])
				break
	mi.material_override = _triplanar(key)
	_counts["glass" if key == "glass" else "overrides"] += 1
	var tagged: Node = body if body is CollisionObject3D else null
	if tagged != null and not tagged.has_meta(&"art_asset"):
		SurfaceTags.tag(tagged, SurfaceTags.for_id(_lib_of(key)))
