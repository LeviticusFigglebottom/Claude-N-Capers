## Glasshouse G2 art pass (C1-08): material library assignment, room finishes, trim, facade and
## neighbour detail, reflection probes, occluders and ambience. Owner: ENV C. Used by build_greybox.gd.
## Design: docs/design/heists/glasshouse.md §Audio/lighting; style: docs/art/style_guide.md (GSR,
## D-035); materials + UV convention: tools/texgen/README.md (1 UV unit = 2 m, world-anchored).
extends RefCounted

const M: GDScript = preload("res://world/heists/glasshouse/greybox/gh_mesh.gd")
const L: GDScript = preload("res://world/heists/glasshouse/greybox/glasshouse_layout.gd")
const MAT_DIR: String = "res://world/materials/"
const TRIM_TABLE: String = "res://assets/textures/trim_interior/trim_table.json"
const LIBRARY: Array[String] = [
	"plaster_painted", "drywall_painted", "concrete", "terrazzo", "marble_cream", "carpet_commercial",
	"ceiling_tile", "wood_veneer_walnut", "brushed_steel", "chrome", "brass", "glass_clear",
	"rubber_black", "fabric_upholstery", "leather_dark", "plastic_matte", "brick_red", "asphalt",
	"tile_ceramic_white", "vinyl_floor", "metal_painted", "paint_white",
]
## Door frame casing beyond the opening (prop door frames: 1.15 / 2.15 / 1.35 m for 0.9 / 1.8 / 1.1).
const DOOR_CASING: float = 0.18
## Window frame visuals overhang the opening by 0.04 m a side.
const WINDOW_CASING: float = 0.06
## Untextured emissive / glass surfaces (meta untextured_ok): key -> [albedo, emission, energy, alpha].
const EMISSIVE: Dictionary = {
	"emit_warm": [Color(1.0, 0.86, 0.66), Color(1.0, 0.82, 0.58), 3.0, 1.0],
	"emit_cool": [Color(0.9, 0.94, 1.0), Color(0.88, 0.93, 1.0), 2.5, 1.0],
	"emit_led": [Color(0.93, 0.95, 1.0), Color(0.93, 0.95, 1.0), 4.0, 1.0],
	"emit_neon": [Color(1.0, 0.24, 0.65), Color(1.0, 0.24, 0.65), 6.0, 1.0],
	"emit_monitor": [Color(0.55, 0.75, 1.0), Color(0.5, 0.72, 1.0), 2.0, 1.0],
	"window_lit": [Color(0.95, 0.8, 0.55), Color(0.95, 0.74, 0.48), 1.2, 1.0],
	"window_dark": [Color(0.09, 0.1, 0.12), Color(0.0, 0.0, 0.0), 0.0, 1.0],
}
## Room id -> [floor, walls, ceiling] library ids (doc §Audio/lighting palette; lead brief C1-08).
const FINISH: Dictionary = {
	"G1": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G7": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G2": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G3": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],
	"G4": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G8": ["terrazzo", "drywall_painted", "plaster_painted"],
	"G9": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G10": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G5": ["terrazzo", "plaster_painted", "plaster_painted"],
	"G6": ["carpet_commercial", "plaster_painted", "plaster_painted"],
	"U1": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"U2": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"U3": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],
	"U4": ["carpet_commercial", "drywall_painted", "ceiling_tile"],
	"U8": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"U5": ["carpet_commercial", "drywall_painted", "ceiling_tile"],
	"U6": ["carpet_commercial", "plaster_painted", "ceiling_tile"],
	"U7": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
}
## Greybox surface class -> library id for site / massing / props.
const CLASS_MAT: Dictionary = {
	"paving": "concrete", "sidewalk": "concrete", "facade_a": "plaster_painted", "facade_b": "concrete",
	"facade_c": "brick_red", "brick": "brick_red", "concrete": "concrete", "fence": "metal_painted",
	"fence_post": "paint_white",
	"vehicle": "metal_painted", "trim": "metal_painted", "counter": "wood_veneer_walnut",
	"prop": "fabric_upholstery", "stair": "terrazzo", "glass": "glass_clear", "frame": "metal_painted",
	"door": "wood_veneer_walnut",
}
## Per greybox class: [bottom (-Y), top (+Y), sides] material keys ("" = face not rendered).
## "@room" = the finish of the room the face looks into; "@parapet" = concrete above the roof only.
const CLASS_FACES: Dictionary = {
	"wall_ext": ["", "concrete", "brick_red"], "wall": ["", "@parapet", "@room"], "floor": ["", "", "drywall_painted"],
	"roof": ["plaster_painted", "concrete", ""], "slab": ["concrete", "concrete", "concrete"],
	"asphalt": ["", "asphalt", "concrete"], "stair": ["", "terrazzo", "terrazzo"],
	"none": ["", "", ""],
}
## PO-8: collision-only boxes whose finish is drawn elsewhere -> bullet surface id: glazing panes,
## ceilings (tile / plaster) and the ground slab (terrazzo sales floor, tiled restrooms).
const SURFACE_GROUPS: Array = [["Geometry/Building/Glazing", &"glass"], ["Geometry/Building/Ceilings", &"plaster"],
	["Geometry/Building/Slabs/SlabGround", &"tile"]]
const BASEBOARD_H: float = 0.125
const BASEBOARD_D: float = 0.015
const CORNICE_H: float = 0.25
const CORNICE_D: float = 0.05
const CORNICE_ROOMS: Array[String] = ["G5", "G6"]
## Visual tile edge (m) for the big horizontal surfaces (floors, ceilings, roof, grade) of these merged visual groups
## (gh_mesh.tile_groups: the Compatibility renderer's 8-lights-per-mesh limit). Visual only; colliders and navmesh unchanged.
const SLAB_TILE: float = 6.0
const TILED_GROUPS: Array[String] = ["Interior", "Shell", "Street"]
## Wall faces longer than WALL_TILE_MIN_RUN of these groups go to 6 m x 2 m tiles per wall plane (gh_mesh.wall_tile_groups);
## shorter ones (door reveals, jambs, ends) stay merged. GH stays under ~1,000 MeshInstances with every wall run tiled.
const WALL_TILED_GROUPS: Array[String] = ["Interior", "Shell"]
const WALL_TILE_MIN_RUN: float = 1.0

var acc: RefCounted = M.new()
var _mats: Dictionary = {}
## Wall lines: [axis, fixed, from, to, y0, y1, openings] (exterior walls run 0 .. parapet).
var _walls: Array[Array] = []


func setup() -> void:
	for g: String in TILED_GROUPS:
		acc.tile_groups[g] = SLAB_TILE
	for g: String in WALL_TILED_GROUPS:
		acc.wall_tile_groups[g] = WALL_TILE_MIN_RUN
	for id: String in LIBRARY:
		var m: Material = load(MAT_DIR + id + ".tres") as Material
		_mats[id] = m
		acc.register_material(id, m)
	var trim: Material = load(MAT_DIR + "trim_interior.tres") as Material
	var f: FileAccess = FileAccess.open(TRIM_TABLE, FileAccess.READ)
	var table: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	for s: Dictionary in table["strips"]:
		acc.register_material("trim_" + String(s["name"]), trim,
			Vector2(float(s["v_top_gltf"]), float(s["v_bottom_gltf"])))
	for k: String in EMISSIVE:
		var row: Array = EMISSIVE[k]
		var em: StandardMaterial3D = StandardMaterial3D.new()
		em.resource_name = "gh_" + k
		em.albedo_color = row[0]
		em.roughness = 0.35 if k.begins_with("window") else 0.6
		if float(row[2]) > 0.0:
			em.emission_enabled = true
			em.emission = row[1]
			em.emission_energy_multiplier = float(row[2])
		em.set_meta(&"untextured_ok", true)
		_mats[k] = em
		acc.register_material(k, em)
	for w: Array in L.EXT_WALLS:
		_walls.append([String(w[1]), float(w[2]), float(w[3]), float(w[4]), 0.0, L.PARAPET_TOP, w[5], true])
	for w2: Array in L.INT_WALLS:
		_walls.append([String(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), float(w2[5]), float(w2[6]), w2[7], false])


func mat(key: String) -> Material:
	return _mats.get(key)


## Tinted copy of a library material (keeps its textures, so it stays a textured library surface).
func add_tint(key: String, base: String, tint: Color) -> void:
	var m: BaseMaterial3D = (_mats[base] as BaseMaterial3D).duplicate() as BaseMaterial3D
	m.resource_name = key
	m.albedo_color = tint
	_mats[key] = m
	acc.register_material(key, m)


# --- Rooms -------------------------------------------------------------------------------------

## Interior room id containing p (by the layout's room boxes), "" outside.
static func room_at(p: Vector3) -> String:
	for r: Array in L.ROOMS:
		if String(r[1]) == "exterior":
			continue
		for b: Array in r[4]:
			if p.x > float(b[0]) and p.x < float(b[3]) and p.z > float(b[2]) and p.z < float(b[5]) \
					and p.y > float(b[1]) - 0.05 and p.y < float(b[4]) + 0.6:
				return String(r[0])
	return ""


func _room_wall(p: Vector3) -> String:
	var r: String = room_at(p)
	return String((FINISH[r] as Array)[1]) if FINISH.has(r) else "drywall_painted"


# --- Box faces by greybox class ------------------------------------------------------------------

## Material key for face f (0 -X, 1 +X, 2 -Y, 3 +Y, 4 -Z, 5 +Z) of a box of greybox class `cls`.
func face_key(cls: String, f: int, n: Vector3, c: Vector3) -> String:
	var rule: Array = CLASS_FACES.get(cls, ["", String(CLASS_MAT.get(cls, "concrete")), String(CLASS_MAT.get(cls, "concrete"))])
	var key: String = String(rule[0] if f == 2 else (rule[1] if f == 3 else rule[2]))
	if key == "@room":
		key = _room_wall(c + n * 0.3)
	elif key == "@parapet":
		key = "concrete" if c.y > 7.9 else ""
	return key


## PO-8: material key a bullet meets on face f of a class `cls` box (build_greybox._box): the drawn
## face, or the room's floor finish on a floor's top (drawn separately by room_surfaces).
func surface_face(f: int, n: Vector3, c: Vector3, cls: String) -> String:
	if cls == "" or cls == "none":
		return ""
	if f == 3 and cls == "floor":
		var r: String = room_at(c + n * 0.3)
		return String((FINISH[r] as Array)[0]) if FINISH.has(r) else "concrete"
	return face_key(cls, f, n, c)


## PO-8: tags the bullet surface ids left after the build (collision-only groups whose finish is drawn
## elsewhere, then SurfaceTags.tag_tree). Returns an error per body still untagged.
func tag_surfaces(root: Node) -> PackedStringArray:
	for g: Array in SURFACE_GROUPS:
		SurfaceTags.tag_untagged(root, NodePath(String(g[0])), g[1])
	var out: PackedStringArray = PackedStringArray()
	for p: String in SurfaceTags.tag_tree(root):
		out.append("no surface id for %s" % p)
	return out


## PO-5 stair ramp (Dockside `_ramp` style): one invisible StaticBody3D "Ramp" (layer 1) under a
## flight, convex prisms each a (z, y) polygon extruded over x0..x1, tagged `surface` like the treads.
## Walkers (players and NpcMotor's plain move_and_slide) slide up it instead of stepping each riser.
static func ramp(flight: Node3D, owner_root: Node, x0: float, x1: float, polys: Array, surface: StringName) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"surface", surface)
	flight.add_child(body)
	body.owner = owner_root
	for i: int in range(polys.size()):
		var pts: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in polys[i]:
			pts.append(Vector3(x0, p.y, p.x))
			pts.append(Vector3(x1, p.y, p.x))
		var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shp.points = pts
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Prism%d" % i
		col.shape = shp
		body.add_child(col)
		col.owner = owner_root
	return body


## Union-find over navmesh polygons (build_greybox._prune_islands).
static func uf_find(parent: PackedInt32Array, i: int) -> int:
	var r: int = i
	while parent[r] != r:
		r = parent[r]
	return r


static func uf_union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = uf_find(parent, a)
	var rb: int = uf_find(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)


func vis_box(group: String, mn: Vector3, mx: Vector3, cls: String) -> void:
	if cls == "" or cls == "none":
		return
	acc.box(group, mn, mx, func(f: int, n: Vector3, c: Vector3) -> String: return face_key(cls, f, n, c))


## Local-space box mesh (props) with metre-scaled UVs (same 2 m tile convention).
func local_box_mesh(parts: Array) -> ArrayMesh:
	var a: RefCounted = M.new()
	for k: String in _mats:
		a.register_material(k, _mats[k])
	for p: Array in parts:
		var size: Vector3 = p[0]
		var centre: Vector3 = p[1]
		var key: String = String(p[2])
		var lo: Vector3 = centre - size * 0.5
		var on_floor: bool = centre.y - size.y * 0.5 < 0.001
		a.box("p", lo, lo + size, func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 2 and on_floor else key)
	var holder: Node3D = Node3D.new()
	var out: Array = a.flush(holder, holder)
	var mesh: ArrayMesh = (out[0] as MeshInstance3D).mesh as ArrayMesh
	holder.free()
	return mesh


## Prism around the Y axis (n sides) in local space: side, top (and optional bottom) faces.
func local_prism_mesh(radius: float, y0: float, y1: float, sides: int, side_key: String, top_key: String) -> ArrayMesh:
	var a: RefCounted = M.new()
	for k: String in _mats:
		a.register_material(k, _mats[k])
	for i: int in range(sides):
		var t0: float = TAU * float(i) / float(sides)
		var t1: float = TAU * float(i + 1) / float(sides)
		var p0: Vector3 = Vector3(cos(t0) * radius, 0.0, sin(t0) * radius)
		var p1: Vector3 = Vector3(cos(t1) * radius, 0.0, sin(t1) * radius)
		var n: Vector3 = ((p0 + p1) * 0.5).normalized()
		a.quad("p", side_key, p0 + Vector3.UP * y0, p1 + Vector3.UP * y0, p1 + Vector3.UP * y1, p0 + Vector3.UP * y1, n)
		if top_key != "":
			var c: Vector3 = Vector3.UP * y1
			a.quad("p", top_key, c, p0 + Vector3.UP * y1, p1 + Vector3.UP * y1, c, Vector3.UP)
	var holder: Node3D = Node3D.new()
	var out: Array = a.flush(holder, holder)
	var mesh: ArrayMesh = (out[0] as MeshInstance3D).mesh as ArrayMesh
	holder.free()
	return mesh


# --- Room surfaces: floors, ceilings, baseboards, cornices -------------------------------------

func room_surfaces() -> void:
	for r: Array in L.ROOMS:
		var id: String = String(r[0])
		if not FINISH.has(id):
			continue
		var fin: Array = FINISH[id]
		for b: Array in r[4]:
			var x0: float = float(b[0])
			var y0: float = float(b[1])
			var z0: float = float(b[2])
			var x1: float = float(b[3])
			var y1: float = float(b[4])
			var z1: float = float(b[5])
			if String(fin[0]) != "":
				acc.quad("Interior", String(fin[0]), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1),
					Vector3(x0, y0, z1), Vector3.UP)
			for r2: Rect2 in _ceiling_rects(x0, z0, x1, z1, y1):
				acc.quad("Interior", String(fin[2]), Vector3(r2.position.x, y1, r2.position.y),
					Vector3(r2.end.x, y1, r2.position.y), Vector3(r2.end.x, y1, r2.end.y), Vector3(r2.position.x, y1, r2.end.y),
					Vector3.DOWN)
		if id == "G8":
			continue
		var box0: Array = (r[4] as Array)[0]
		var floor_y: float = float(box0[1])
		var ceil_y: float = float(box0[4])
		for b2: Array in r[4]:
			_trim_room_box(b2, floor_y, floor_y, floor_y + BASEBOARD_H, BASEBOARD_D, "trim_baseboard")
			if id in CORNICE_ROOMS:
				_trim_room_box(b2, floor_y, ceil_y - CORNICE_H, ceil_y, CORNICE_D, "trim_crown_cornice")


## A room's ceiling rectangle (x, z) minus the PO6-17 ceiling breach holes at that height (four strips around a hole).
func _ceiling_rects(x0: float, z0: float, x1: float, z1: float, y: float) -> Array[Rect2]:
	var r: Rect2 = Rect2(x0, z0, x1 - x0, z1 - z0)
	for b: Array in L.ASSAULT_BREACHES:
		var p: Vector3 = b[3]
		var sz: Vector2 = b[5]
		var hole: Rect2 = Rect2(p.x - sz.x * 0.5, p.z - sz.y * 0.5, sz.x, sz.y)
		if String(b[1]) != "ceiling" or not is_equal_approx(p.y, y) or not r.encloses(hole):
			continue
		return [Rect2(x0, z0, hole.position.x - x0, z1 - z0), Rect2(hole.end.x, z0, x1 - hole.end.x, z1 - z0),
			Rect2(hole.position.x, z0, sz.x, hole.position.y - z0), Rect2(hole.position.x, hole.end.y, sz.x, z1 - hole.end.y)]
	return [r]


## Trim strip along every wall face of a room box where the wall is solid over [ya, yb].
func _trim_room_box(b: Array, floor_y: float, ya: float, yb: float, depth: float, key: String) -> void:
	var x0: float = float(b[0])
	var z0: float = float(b[2])
	var x1: float = float(b[3])
	var z1: float = float(b[5])
	# [axis, fixed, along0, along1, inward sign]
	var edges: Array = [["x", z0, x0, x1, 1.0], ["x", z1, x0, x1, -1.0], ["z", x0, z0, z1, 1.0], ["z", x1, z0, z1, -1.0]]
	for e: Array in edges:
		var axis: String = String(e[0])
		var fixed: float = float(e[1])
		var inward: float = float(e[4])
		var t: float = _wall_thickness(axis, fixed, floor_y)
		if t <= 0.0:
			continue
		var face: float = fixed + inward * t * 0.5
		var a0: float = float(e[2]) + _end_inset(axis, float(e[2]), floor_y)
		var a1: float = float(e[3]) - _end_inset(axis, float(e[3]), floor_y)
		for run: Vector2 in wall_runs(axis, fixed, a0, a1, ya, yb):
			var lo: Vector3
			var hi: Vector3
			if axis == "x":
				lo = Vector3(run.x, ya, minf(face, face + inward * depth))
				hi = Vector3(run.y, yb, maxf(face, face + inward * depth))
			else:
				lo = Vector3(minf(face, face + inward * depth), ya, run.x)
				hi = Vector3(maxf(face, face + inward * depth), yb, run.y)
			var back: int = (4 if inward > 0.0 else 5) if axis == "x" else (0 if inward > 0.0 else 1)
			acc.box("Trim", lo, hi, func(f: int, _n: Vector3, _c: Vector3) -> String:
				return "" if f == back or (f == 2 and ya <= floor_y + 0.001) or (f == 3 and yb > floor_y + 1.0) else key)


func _wall_thickness(axis: String, fixed: float, y: float) -> float:
	for w: Array in _walls:
		if String(w[0]) == axis and is_equal_approx(float(w[1]), fixed) and y >= float(w[4]) - 0.01 and y < float(w[5]):
			return L.EXT_T if bool(w[7]) else L.INT_T
	return 0.0


## Half the thickness of the perpendicular wall at an edge end (0 when there is none).
func _end_inset(axis: String, at: float, y: float) -> float:
	var other: String = "z" if axis == "x" else "x"
	var t: float = _wall_thickness(other, at, y)
	return t * 0.5 if t > 0.0 else 0.0


## Intervals of [a0, a1] along a wall line where some wall is solid over the whole band [ya, yb].
func wall_runs(axis: String, fixed: float, a0: float, a1: float, ya: float, yb: float) -> Array[Vector2]:
	var solid: Array[Vector2] = []
	for w: Array in _walls:
		if String(w[0]) != axis or not is_equal_approx(float(w[1]), fixed):
			continue
		if float(w[4]) > ya + 0.001 or float(w[5]) < yb - 0.001:
			continue
		var segs: Array[Vector2] = [Vector2(maxf(float(w[2]), a0), minf(float(w[3]), a1))]
		for o: Array in w[6]:
			if float(o[2]) < yb - 0.001 and float(o[3]) > ya + 0.001:
				# Door openings: stop the run at the door casing (frame visuals are 0.13-0.18 m wider).
				var m: float = DOOR_CASING if float(o[2]) <= float(w[4]) + 0.01 else WINDOW_CASING
				segs = _subtract(segs, Vector2(float(o[0]) - m, float(o[1]) + m))
		for s: Vector2 in segs:
			if s.y - s.x > 0.05:
				solid.append(s)
	solid.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var merged: Array[Vector2] = []
	for s2: Vector2 in solid:
		if not merged.is_empty() and s2.x <= merged[merged.size() - 1].y + 0.001:
			merged[merged.size() - 1].y = maxf(merged[merged.size() - 1].y, s2.y)
		else:
			merged.append(s2)
	return merged


static func _subtract(segs: Array[Vector2], cut: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s: Vector2 in segs:
		if cut.y <= s.x or cut.x >= s.y:
			out.append(s)
			continue
		if cut.x > s.x:
			out.append(Vector2(s.x, cut.x))
		if cut.y < s.y:
			out.append(Vector2(cut.y, s.y))
	return out


# --- Facade -----------------------------------------------------------------------------------

## Concrete plinth (two bands so the 0.3 m shop sills keep a base), cornice band above the upper
## windows (the shopfront and entrance frames are the prop window / door visuals).
func facade() -> void:
	var lines: Array = [["x", 0.0, -1.0], ["x", 12.0, 1.0], ["z", 0.0, -1.0], ["z", 18.0, 1.0]]
	for ln: Array in lines:
		var axis: String = String(ln[0])
		var fixed: float = float(ln[1])
		var outward: float = float(ln[2])
		var face: float = fixed + outward * L.EXT_T * 0.5
		var span: Vector2 = Vector2(-0.2, 18.2) if axis == "x" else Vector2(-0.2, 12.2)
		for band: Array in [[0.0, 0.3, 0.03], [0.3, 0.6, 0.03], [7.7, 7.9, 0.06], [8.8, 8.9, 0.08]]:
			for run: Vector2 in wall_runs(axis, fixed, span.x, span.y, float(band[0]), minf(float(band[1]), L.PARAPET_TOP)):
				var d: float = float(band[2])
				var ya: float = float(band[0])
				var yb: float = float(band[1])
				var lo: Vector3
				var hi: Vector3
				var r0: float = run.x - (d if run.x <= span.x + 0.001 else 0.0)
				var r1: float = run.y + (d if run.y >= span.y - 0.001 else 0.0)
				if axis == "x":
					lo = Vector3(r0, ya, minf(face, face + outward * d))
					hi = Vector3(r1, yb, maxf(face, face + outward * d))
				else:
					lo = Vector3(minf(face, face + outward * d), ya, r0)
					hi = Vector3(maxf(face, face + outward * d), yb, r1)
				var back: int = (5 if outward < 0.0 else 4) if axis == "x" else (1 if outward < 0.0 else 0)
				acc.box("Shell", lo, hi, func(f: int, _n: Vector3, _c: Vector3) -> String:
					return "" if f == back or (f == 2 and ya < 0.001) else "concrete")
	_thresholds()


## Exterior door thresholds: the outer half of the wall under ground-floor doors (room floors stop
## at the wall line).
func _thresholds() -> void:
	for d: Array in L.DOORS:
		var p: Vector3 = d[2]
		if absf(p.y) > 0.01:
			continue
		var w: float = 1.8 if String(d[1]).contains("double") else (1.1 if String(d[1]).contains("service") else 0.9)
		var key: String = "terrazzo" if String(d[0]) == "MainEntrance" else "concrete"
		var h: float = L.EXT_T * 0.5
		if absf(p.z - 12.0) < 0.01 or absf(p.z) < 0.01:
			var z0: float = p.z if p.z > 6.0 else p.z - h
			acc.quad("Shell", key, Vector3(p.x - w * 0.5, 0.0, z0), Vector3(p.x + w * 0.5, 0.0, z0),
				Vector3(p.x + w * 0.5, 0.0, z0 + h), Vector3(p.x - w * 0.5, 0.0, z0 + h), Vector3.UP)
		elif absf(p.x - 18.0) < 0.01 and p.z > 0.0 and p.z < 12.0:
			acc.quad("Shell", key, Vector3(18.0, 0.0, p.z - w * 0.5), Vector3(18.0 + h, 0.0, p.z - w * 0.5),
				Vector3(18.0 + h, 0.0, p.z + w * 0.5), Vector3(18.0, 0.0, p.z + w * 0.5), Vector3.UP)


# --- Neighbours: windows, shopfronts, copings ----------------------------------------------------

## Window grids on every play-space-facing block face, ground-floor glazing on street faces and a
## parapet coping on each roof. Lit windows come from a fixed-seed RNG (presentation only).
func neighbours(blocks: Array) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x6C617373  # fixed: "lass"
	var centre: Vector2 = Vector2(9.0, 13.0)
	for b: Array in blocks:
		var nm: String = String(b[0])
		var bx: Array = b[1]
		var lo: Vector3 = Vector3(float(bx[0]), float(bx[1]), float(bx[2]))
		var hi: Vector3 = Vector3(float(bx[3]), float(bx[4]), float(bx[5]))
		var height: float = hi.y
		if height < 5.0:
			continue
		# Coping on the roof perimeter.
		for cp: Array in [[lo.x, hi.x, lo.z, lo.z + 0.3], [lo.x, hi.x, hi.z - 0.3, hi.z],
				[lo.x, lo.x + 0.3, lo.z + 0.3, hi.z - 0.3], [hi.x - 0.3, hi.x, lo.z + 0.3, hi.z - 0.3]]:
			acc.box("Neighbours", Vector3(float(cp[0]), hi.y, float(cp[2])), Vector3(float(cp[1]), hi.y + 0.5, float(cp[3])),
				func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 2 else "concrete")
		if nm.begins_with("Garage"):
			continue
		# Faces: [normal, fixed coordinate, along axis, a0, a1]
		var faces: Array = [[Vector3.LEFT, lo.x, "z", lo.z, hi.z], [Vector3.RIGHT, hi.x, "z", lo.z, hi.z],
			[Vector3.FORWARD, lo.z, "x", lo.x, hi.x], [Vector3.BACK, hi.z, "x", lo.x, hi.x]]
		for fc: Array in faces:
			var n: Vector3 = fc[0]
			var fx: float = float(fc[1])
			var a0: float = float(fc[3])
			var a1: float = float(fc[4])
			var mid: Vector2 = Vector2(fx, (a0 + a1) * 0.5) if String(fc[2]) == "z" else Vector2((a0 + a1) * 0.5, fx)
			var to_c: Vector2 = centre - mid
			if Vector2(n.x, n.z).dot(to_c) <= 0.0 or a1 - a0 < 4.0:
				continue
			if nm == "CastellanTailoring" and n != Vector3.BACK:
				continue
			_face_windows(rng, nm, n, fx, String(fc[2]), a0, a1, height)


func _face_windows(rng: RandomNumberGenerator, nm: String, n: Vector3, fx: float, axis: String, a0: float, a1: float,
		height: float) -> void:
	var bay: float = 3.0
	var count: int = int(floor((a1 - a0 - 1.0) / bay))
	if count < 1:
		return
	var start: float = (a0 + a1) * 0.5 - float(count) * bay * 0.5
	var ground_shop: bool = n == Vector3.BACK or n == Vector3.FORWARD and nm.begins_with("Hotel") == false and fx > 30.0
	var y: float = 3.6
	var first: bool = true
	while y + 1.8 < height - 0.6:
		for i: int in range(count):
			var c: float = start + bay * (float(i) + 0.5)
			var key: String = "window_lit" if rng.randf() < 0.32 else "window_dark"
			_window_panel(n, fx, axis, c - 0.7, c + 0.7, y, y + 1.6, key)
		y += 3.4
		first = false
	if nm == "CastellanTailoring":
		# Closed shop: steel shutters over the Harlow Ave shopfront.
		_window_panel(n, fx, axis, a0 + 1.0, a1 - 1.0, 0.3, 2.9, "metal_painted")
	elif ground_shop and not first:
		_shopfront_bays(rng, n, fx, axis, start, count, bay)


## Ground-floor shopfronts: one framed window per bay over a stall riser, a fascia band above.
func _shopfront_bays(rng: RandomNumberGenerator, n: Vector3, fx: float, axis: String, start: float, count: int,
		bay: float) -> void:
	for i: int in range(count):
		var c: float = start + bay * (float(i) + 0.5)
		var key: String = "window_lit" if rng.randf() < 0.35 else "window_dark"
		_window_panel(n, fx, axis, c - 1.2, c - 0.03, 0.7, 2.6, key)
		_window_panel(n, fx, axis, c + 0.03, c + 1.2, 0.7, 2.6, key)
	var s: float = 1.0 if n.x + n.z > 0.0 else -1.0
	var f0: float = fx
	var f1: float = fx + s * 0.08
	var lo_a: float = start + 0.2
	var hi_a: float = start + bay * float(count) - 0.2
	var lo: Vector3 = Vector3(minf(f0, f1), 2.85, lo_a) if axis == "z" else Vector3(lo_a, 2.85, minf(f0, f1))
	var hi: Vector3 = Vector3(maxf(f0, f1), 3.3, hi_a) if axis == "z" else Vector3(hi_a, 3.3, maxf(f0, f1))
	acc.box("Neighbours", lo, hi, func(_f: int, nn: Vector3, _c: Vector3) -> String:
		return "" if nn == -n else "metal_painted")


## Framed window: metal frame proud 0.04 m, glass 0.045 m (never coplanar with the facade).
func _window_panel(n: Vector3, fx: float, axis: String, a0: float, a1: float, y0: float, y1: float, key: String) -> void:
	var fr: float = 0.06
	var p0: float = fx + (0.0 if n.x + n.z > 0.0 else -0.04)
	var p1: float = p0 + 0.04
	var glass: float = fx + (0.045 if n.x + n.z > 0.0 else -0.045)
	var parts: Array = [[a0 - fr, a0, y0 - fr, y1 + fr], [a1, a1 + fr, y0 - fr, y1 + fr], [a0, a1, y1, y1 + fr],
		[a0, a1, y0 - fr, y0]]
	if key == "metal_painted":
		parts = [[a0, a1, y0, y1]]
	for p: Array in parts:
		var lo: Vector3
		var hi: Vector3
		if axis == "z":
			lo = Vector3(minf(p0, p1), float(p[2]), float(p[0]))
			hi = Vector3(maxf(p0, p1), float(p[3]), float(p[1]))
		else:
			lo = Vector3(float(p[0]), float(p[2]), minf(p0, p1))
			hi = Vector3(float(p[1]), float(p[3]), maxf(p0, p1))
		acc.box("Neighbours", lo, hi, func(f: int, nn: Vector3, _c: Vector3) -> String:
			return "" if nn == -n else ("metal_painted" if key != "metal_painted" else "metal_painted"))
	if key == "metal_painted":
		return
	var a: Vector3
	var b: Vector3
	var c: Vector3
	var d: Vector3
	if axis == "z":
		a = Vector3(glass, y0, a0)
		b = Vector3(glass, y0, a1)
		c = Vector3(glass, y1, a1)
		d = Vector3(glass, y1, a0)
	else:
		a = Vector3(a0, y0, glass)
		b = Vector3(a1, y0, glass)
		c = Vector3(a1, y1, glass)
		d = Vector3(a0, y1, glass)
	acc.quad("Neighbours", key, a, b, c, d, n)


# --- Probes, occluders, ambience -----------------------------------------------------------------

func reflection_probes(parent: Node3D, owner_root: Node) -> void:
	for r: Array in L.ROOMS:
		if String(r[1]) == "exterior":
			continue
		var b: Array = (r[4] as Array)[0]
		var lo: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
		var hi: Vector3 = Vector3(float(b[3]), float(b[4]), float(b[5]))
		var probe: ReflectionProbe = ReflectionProbe.new()
		probe.name = "Probe" + String(r[0])
		probe.position = (lo + hi) * 0.5
		probe.size = hi - lo + Vector3(0.2, 0.1, 0.2)
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		parent.add_child(probe)
		probe.owner = owner_root


## Box occluders for solid massing (neighbour blocks, the party wall). Glazed walls get none.
func occluders(parent: Node3D, owner_root: Node, blocks: Array) -> void:
	for b: Array in blocks:
		var bx: Array = b[1]
		var lo: Vector3 = Vector3(float(bx[0]), float(bx[1]), float(bx[2]))
		var hi: Vector3 = Vector3(float(bx[3]), float(bx[4]), float(bx[5]))
		var size: Vector3 = hi - lo
		if size.y < 5.0 or minf(size.x, size.z) < 1.0:
			continue
		var occ: OccluderInstance3D = OccluderInstance3D.new()
		occ.name = "Occluder" + String(b[0])
		occ.position = (lo + hi) * 0.5
		var bo: BoxOccluder3D = BoxOccluder3D.new()
		bo.size = size - Vector3(0.1, 0.1, 0.1)
		occ.occluder = bo
		parent.add_child(occ)
		occ.owner = owner_root


## Ambience beds (positional CueEmitters), the heist music director and the cue player. The audio
## scripts are loaded at build time (they use autoloads, which a --script generator cannot compile
## against as dependencies).
func audio(parent: Node3D, owner_root: Node) -> void:
	var player: Node = Node.new()
	player.set_script(load("res://world/audio/cue_player.gd"))
	player.name = "CuePlayer"
	parent.add_child(player)
	player.owner = owner_root
	var music: Node = Node.new()
	music.set_script(load("res://world/audio/music_director.gd"))
	music.name = "MusicDirector"
	music.set(&"track_id", &"glasshouse")
	parent.add_child(music)
	music.owner = owner_root
	var beds: Array = [
		["BedSalesFloor", Vector3(6.5, 2.5, 9.0), &"cue.amb_glasshouse_interior", 0.0],
		["BedBackOfHouse", Vector3(9.0, 2.2, 3.0), &"cue.amb_glasshouse_interior", -4.0],
		["BedUpstairs", Vector3(9.0, 6.4, 7.0), &"cue.amb_glasshouse_interior", -4.0],
		["BedHarlowAve", Vector3(9.0, 3.0, 22.0), &"cue.amb_street_dusk", 0.0],
		["BedPellSt", Vector3(25.0, 3.0, 4.0), &"cue.amb_street_dusk", -2.0],
		["BedAlley", Vector3(4.0, 3.0, -3.2), &"cue.amb_street_dusk", -6.0],
	]
	var emitter: Script = load("res://world/audio/cue_emitter.gd")
	for b: Array in beds:
		var em: Node3D = Node3D.new()
		em.set_script(emitter)
		em.name = String(b[0])
		em.position = b[1]
		em.set(&"cue_id", b[2])
		em.set(&"autoplay", true)
		em.set(&"volume_offset_db", float(b[3]))
		parent.add_child(em)
		em.owner = owner_root
