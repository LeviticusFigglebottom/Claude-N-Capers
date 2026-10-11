## Night Deposit G2 art pass (C2, ENV C): material library assignment, room finishes and trim, the
## 1931 stone facade, neighbour and site detail, the mosaic compass rose, the coffered hall ceiling,
## reflection probes, occluders and ambience. Used by the generator (nd_builder_base.gd).
## Design: docs/design/heists/night_deposit.md §Audio/lighting (palette: slate green #3F5A52, marble
## cream #D9D2C2, bank red #9E2B25, brass); style: docs/art/style_guide.md; UV convention:
## tools/texgen/README.md (1 UV unit = 2 m, world-anchored). Shares the Glasshouse mesh accumulator.
extends RefCounted

const M: GDScript = preload("res://world/heists/glasshouse/greybox/gh_mesh.gd")
const L: GDScript = preload("res://world/heists/night_deposit/greybox/night_deposit_layout.gd")
const MAT_DIR: String = "res://world/materials/"
const TRIM_TABLE: String = "res://assets/textures/trim_interior/trim_table.json"
const LIBRARY: Array[String] = [
	"plaster_painted", "drywall_painted", "concrete", "terrazzo", "marble_cream", "carpet_commercial",
	"ceiling_tile", "wood_veneer_walnut", "brushed_steel", "chrome", "brass", "glass_clear",
	"rubber_black", "plastic_matte", "brick_red", "asphalt", "tile_ceramic_white", "vinyl_floor",
	"metal_painted", "paint_white",
]
## Tinted library surfaces (keep the library textures): key -> [library id, tint].
const TINTS: Dictionary = {
	"stone_facade": ["concrete", Color(0.93, 0.88, 0.78)],
	"granite": ["marble_cream", Color(0.36, 0.35, 0.34)],
	"paint_slate": ["drywall_painted", Color(0.36, 0.5, 0.45)],
	"carpet_red": ["carpet_commercial", Color(0.78, 0.36, 0.33)],
	"paving": ["concrete", Color(0.78, 0.76, 0.72)],
	"sidewalk": ["concrete", Color(0.95, 0.93, 0.9)],
	"quay_stone": ["concrete", Color(0.72, 0.7, 0.66)],
	"metal_yellow": ["metal_painted", Color(1.0, 0.82, 0.32)],
	"metal_slate": ["metal_painted", Color(0.55, 0.72, 0.66)],
	"metal_dark": ["metal_painted", Color(0.42, 0.43, 0.45)],
	"container_rust": ["metal_painted", Color(0.92, 0.5, 0.36)],
	"render_grey": ["plaster_painted", Color(0.7, 0.72, 0.74)],
	"render_sand": ["plaster_painted", Color(0.86, 0.78, 0.64)],
	"glass_green": ["glass_clear", Color(0.55, 0.85, 0.68)],
	"van_white": ["metal_painted", Color(1.0, 1.0, 0.98)],
}
## Untextured emissive / glass / water surfaces (meta untextured_ok): key -> [albedo, emission,
## energy, roughness].
const EMISSIVE: Dictionary = {
	"emit_warm": [Color(1.0, 0.86, 0.66), Color(1.0, 0.82, 0.58), 3.0, 0.6],
	"emit_cool": [Color(0.9, 0.94, 1.0), Color(0.88, 0.93, 1.0), 2.5, 0.6],
	"emit_mint": [Color(0.8, 1.0, 0.88), Color(0.78, 1.0, 0.86), 3.5, 0.6],
	"emit_sodium": [Color(1.0, 0.64, 0.32), Color(1.0, 0.6, 0.26), 3.5, 0.6],
	"window_lit": [Color(0.95, 0.8, 0.55), Color(0.95, 0.74, 0.48), 1.2, 0.35],
	"window_dark": [Color(0.09, 0.1, 0.12), Color(0.0, 0.0, 0.0), 0.0, 0.35],
	"far_lights": [Color(1.0, 0.85, 0.6), Color(1.0, 0.8, 0.5), 2.0, 0.6],
	"water": [Color(0.04, 0.08, 0.09), Color(0.0, 0.0, 0.0), 0.0, 0.08],
	"laser_red": [Color(1.0, 0.12, 0.08), Color(1.0, 0.08, 0.05), 4.0, 0.6],
	"emit_screen": [Color(0.11, 0.13, 0.16), Color(0.47, 0.56, 0.65), 0.9, 0.4],
}
## Door frame casing beyond the opening (prop door frames reach 0.125-0.175 m beyond the leaf).
const DOOR_CASING: float = 0.18
const WINDOW_CASING: float = 0.06
## Room id -> [floor, walls, ceiling] material keys (doc §Audio/lighting; night bank, 1931 stone).
const FINISH: Dictionary = {
	"G1": ["concrete", "drywall_painted", "ceiling_tile"],
	"G2": ["terrazzo", "plaster_painted", "plaster_painted"],
	"G3": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G4": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G5": ["concrete", "drywall_painted", "ceiling_tile"],
	"G6": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G7": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"G8": ["carpet_red", "plaster_painted", "ceiling_tile"],
	"G9": ["marble_cream", "plaster_painted", "plaster_painted"],
	"G10": ["terrazzo", "marble_cream", "plaster_painted"],
	"G11": ["carpet_commercial", "plaster_painted", "ceiling_tile"],
	"G12": ["carpet_red", "plaster_painted", "ceiling_tile"],
	"G13": ["terrazzo", "marble_cream", "ceiling_tile"],
	"B1": ["concrete", "drywall_painted", "concrete"],
	"B2": ["vinyl_floor", "drywall_painted", "concrete"],
	"B13": ["tile_ceramic_white", "tile_ceramic_white", "concrete"],
	"B3": ["concrete", "concrete", "concrete"],
	"B4": ["vinyl_floor", "drywall_painted", "concrete"],
	"B5": ["vinyl_floor", "drywall_painted", "concrete"],
	"B6": ["vinyl_floor", "drywall_painted", "concrete"],
	"B7": ["concrete", "concrete", "concrete"],
	"B8": ["terrazzo", "marble_cream", "plaster_painted"],
	"B9": ["terrazzo", "brushed_steel", "concrete"],
	"B10": ["concrete", "concrete", "concrete"],
	"B11": ["vinyl_floor", "drywall_painted", "concrete"],
	"B12": ["concrete", "brushed_steel", "concrete"],
	"B14": ["concrete", "drywall_painted", "concrete"],
}
## Rooms with a slate wainscot (+ brass chair rail) and a plaster cornice.
const WAINSCOT_ROOMS: Array[String] = ["G9", "G10", "G12", "B8"]
const WAINSCOT_H: float = 0.85
const CORNICE_ROOMS: Array[String] = ["G9", "G10", "G11", "G12", "G13", "B8"]
## Greybox surface class -> material key for the plain classes (all faces).
const CLASS_MAT: Dictionary = {
	"paving": "paving", "sidewalk": "sidewalk", "quay": "quay_stone", "facade_a": "render_sand",
	"facade_b": "render_grey", "facade_c": "brick_red", "brick": "brick_red", "concrete": "concrete",
	"fence": "metal_dark", "fence_post": "metal_slate", "vehicle": "van_white", "container": "container_rust",
	"crane": "metal_yellow", "barrier": "metal_yellow", "ironwork": "metal_slate", "trim": "metal_painted",
	"counter": "wood_veneer_walnut", "prop": "fabric_upholstery", "frame": "metal_dark", "door": "metal_dark",
	"glass": "glass_clear", "glass_green": "glass_green", "shaft": "concrete", "handrail": "brushed_steel",
	"stone": "stone_facade", "granite": "granite", "fixture": "emit_warm", "sodium": "emit_sodium",
	"atm_led": "emit_mint", "far_lights": "far_lights", "water": "water", "steel": "brushed_steel",
	"brass": "brass", "plant": "metal_painted", "roof_plant": "metal_painted",
}
## Per class: [bottom (-Y), top (+Y), sides] keys ("" = face not rendered). "@room": the finish of the
## room the face looks into (stone / concrete outside, see face_key); "@ext": the facade (stone above
## grade, concrete below); "@top": a coping (concrete).
const CLASS_FACES: Dictionary = {
	"wall_ext": ["@ext", "@top", "@ext"], "wall": ["@room", "@top", "@room"], "floor": ["", "", "plaster_painted"],
	"roof": ["", "concrete", "concrete"], "stair": ["plaster_painted", "terrazzo", "terrazzo"],
	"asphalt": ["", "asphalt", "concrete"], "none": ["", "", ""], "ceiling": ["", "", ""],
	"boat_hidden": ["", "", ""], "container_hidden": ["", "", ""], "van_hidden": ["", "", ""],
	"paving": ["", "paving", "concrete"], "sidewalk": ["", "sidewalk", "granite"], "quay": ["", "quay_stone", "quay_stone"],
}
const BASEBOARD_H: float = 0.125
const BASEBOARD_D: float = 0.015
const CORNICE_H: float = 0.22
const CORNICE_D: float = 0.05

var acc: RefCounted = M.new()
var _mats: Dictionary = {}
## Wall lines: [axis, fixed, from, to, y0, y1, openings, thickness, exterior].
var _walls: Array[Array] = []


func setup() -> void:
	for id: String in LIBRARY:
		var m: Material = load(MAT_DIR + id + ".tres") as Material
		_mats[id] = m
		acc.register_material(id, m)
	var trim: Material = load(MAT_DIR + "trim_interior.tres") as Material
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRIM_TABLE))
	for s: Dictionary in table["strips"]:
		acc.register_material("trim_" + String(s["name"]), trim,
			Vector2(float(s["v_top_gltf"]), float(s["v_bottom_gltf"])))
	var tint_keys: Array = TINTS.keys()
	tint_keys.sort()
	for k: Variant in tint_keys:
		var row: Array = TINTS[k]
		add_tint(String(k), String(row[0]), row[1])
	var em_keys: Array = EMISSIVE.keys()
	em_keys.sort()
	for k2: Variant in em_keys:
		var row2: Array = EMISSIVE[k2]
		var em: StandardMaterial3D = StandardMaterial3D.new()
		em.resource_name = "nd_" + String(k2)
		em.albedo_color = row2[0]
		em.roughness = float(row2[3])
		if float(row2[2]) > 0.0:
			em.emission_enabled = true
			em.emission = row2[1]
			em.emission_energy_multiplier = float(row2[2])
		if String(k2) == "water":
			em.metallic_specular = 0.9
		em.set_meta(&"untextured_ok", true)
		_mats[String(k2)] = em
		acc.register_material(String(k2), em)
	for w: Array in L.EXT_WALLS:
		_walls.append([String(w[1]), float(w[2]), minf(float(w[3]), float(w[5])), maxf(float(w[4]), float(w[6])),
			float(w[7]), float(w[8]), w[10], L.EXT_T, true])
	for w2: Array in L.INT_WALLS:
		var t: float = float(w2[8]) if w2.size() > 8 else L.INT_T
		_walls.append([String(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), float(w2[5]), float(w2[6]), w2[7], t, false])


func mat(key: String) -> Material:
	return _mats.get(key)


## Tinted copy of a library material (keeps its textures, so it stays a textured library surface).
func add_tint(key: String, base: String, tint: Color) -> void:
	var m: BaseMaterial3D = (_mats[base] as BaseMaterial3D).duplicate() as BaseMaterial3D
	m.resource_name = "nd_" + key
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


static func inside_building(p: Vector3) -> bool:
	return p.x > 0.0 and p.x < 26.0 and p.z > 0.0 and p.z < 20.0 and p.y < (L.HALL_ROOF if p.z > 10.0 and p.x < 21.0 else L.WING_ROOF)


func _room_wall(c: Vector3, n: Vector3) -> String:
	var p: Vector3 = c + n * 0.3
	var r: String = room_at(p)
	if FINISH.has(r):
		return String((FINISH[r] as Array)[1])
	if inside_building(p):
		return "concrete" if p.y < 0.0 else "plaster_painted"
	return "concrete" if p.y < -0.05 else "stone_facade"


## Material key for face f (0 -X, 1 +X, 2 -Y, 3 +Y, 4 -Z, 5 +Z) of a box of greybox class `cls`.
func face_key(cls: String, f: int, n: Vector3, c: Vector3) -> String:
	# walls are split at the ground FFL: those faces are buried (and coplanar with the floor finish)
	if (cls == "wall" or cls == "wall_ext") and (f == 2 or f == 3) and absf(c.y) < 0.001:
		return ""
	# exterior walls are two half-thickness skins: the faces where they meet are buried
	if (cls == "wall" or cls == "wall_ext") and f != 2 and f != 3 and _on_ext_centreline(n, c):
		return ""
	var rule: Array = CLASS_FACES.get(cls, [String(CLASS_MAT.get(cls, "concrete")), String(CLASS_MAT.get(cls, "concrete")),
		String(CLASS_MAT.get(cls, "concrete"))])
	var key: String = String(rule[0] if f == 2 else (rule[1] if f == 3 else rule[2]))
	if key == "@room":
		key = _room_wall(c, n)
	elif key == "@ext":
		key = "concrete" if c.y < -0.05 else ("granite" if c.y < 0.6 else "stone_facade")
		if inside_building(c + n * 0.25):
			key = _room_wall(c, n)
	elif key == "@top":
		key = "concrete"
	return key


## True when the side face of box [mn, mx] with normal n overlaps the face plane of a wall line
## (>= 1 cm along the wall and in height): slab / roof edges there lie on the wall's same-facing face
## (`against` false); a wall end there butts into the wall's opposite face (`against` true).
func _on_wall_face(n: Vector3, mn: Vector3, mx: Vector3, against: bool = false) -> bool:
	var sg: float = -1.0 if against else 1.0
	for w: Array in _walls:
		var t: float = float(w[7])
		var plane: float
		var coord: float
		var lo: float
		var hi: float
		if String(w[0]) == "x":
			if absf(n.z) < 0.9:
				continue
			plane = float(w[1]) + sg * signf(n.z) * t * 0.5
			coord = mx.z if n.z > 0.0 else mn.z
			lo = mn.x
			hi = mx.x
		else:
			if absf(n.x) < 0.9:
				continue
			plane = float(w[1]) + sg * signf(n.x) * t * 0.5
			coord = mx.x if n.x > 0.0 else mn.x
			lo = mn.z
			hi = mx.z
		if absf(coord - plane) < 0.002 and minf(hi, float(w[3])) - maxf(lo, float(w[2])) > 0.01 \
				and minf(mx.y, float(w[5])) - maxf(mn.y, float(w[4])) > 0.01:
			return true
	return false


## True when a face (normal n, centre c) lies on an exterior wall's centre line (between its skins).
func _on_ext_centreline(n: Vector3, c: Vector3) -> bool:
	for w: Array in _walls:
		if not bool(w[8]):
			continue
		var x_line: bool = String(w[0]) == "x"
		if (x_line and absf(n.z) < 0.9) or (not x_line and absf(n.x) < 0.9):
			continue
		var coord: float = c.z if x_line else c.x
		var along: float = c.x if x_line else c.z
		if absf(coord - float(w[1])) < 0.002 and along > float(w[2]) - 0.001 and along < float(w[3]) + 0.001 \
				and c.y > float(w[4]) - 0.001 and c.y < float(w[5]) + 0.001:
			return true
	return false


func vis_box(group: String, mn: Vector3, mx: Vector3, cls: String, skip: Array[int] = []) -> void:
	if cls == "" or cls == "none":
		return
	var slab: bool = cls == "floor" or cls == "roof"
	var is_wall: bool = cls == "wall" or cls == "wall_ext"
	acc.box(group, mn, mx, func(f: int, n: Vector3, c: Vector3) -> String:
		if f in skip:
			return ""
		# slab / roof edges that sit on a wall face are hidden behind it (and would z-fight); wall ends
		# that butt into another wall are buried
		if f != 2 and f != 3 and ((slab and _on_wall_face(n, mn, mx)) or (is_wall and _on_wall_face(n, mn, mx, true))):
			return ""
		return face_key(cls, f, n, c))


## Local-space box mesh (props, rails) with metre-scaled UVs (same 2 m tile convention).
func local_box_mesh(parts: Array) -> ArrayMesh:
	var a: RefCounted = M.new()
	for k: String in _mats:
		a.register_material(k, _mats[k])
	for p: Array in parts:
		var size: Vector3 = p[0]
		var centre: Vector3 = p[1]
		var key: String = String(p[2])
		var lo: Vector3 = centre - size * 0.5
		# floor-standing parts (bottom exactly at the pivot) never show their underside
		var on_floor: bool = absf(centre.y - size.y * 0.5) < 0.001
		a.box("p", lo, lo + size, func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 2 and on_floor else key)
	return _single(a)


## Round bar along local +Y from 0 to `length` (8 sides), metre-scaled UVs (handrails).
func local_rod_mesh(radius: float, length: float, key: String, sides: int = 8) -> ArrayMesh:
	var a: RefCounted = M.new()
	a.register_material(key, _mats[key])
	for i: int in range(sides):
		var t0: float = TAU * float(i) / float(sides)
		var t1: float = TAU * float(i + 1) / float(sides)
		var p0: Vector3 = Vector3(cos(t0) * radius, 0.0, sin(t0) * radius)
		var p1: Vector3 = Vector3(cos(t1) * radius, 0.0, sin(t1) * radius)
		var nn: Vector3 = ((p0 + p1) * 0.5).normalized()
		a.quad("p", key, p0, p1, p1 + Vector3.UP * length, p0 + Vector3.UP * length, nn)
		a.quad("p", key, Vector3.ZERO, p1, p0, p0, Vector3.DOWN)
		a.quad("p", key, Vector3.UP * length, p0 + Vector3.UP * length, p1 + Vector3.UP * length, p1 + Vector3.UP * length, Vector3.UP)
	return _single(a)


func _single(a: RefCounted) -> ArrayMesh:
	var holder: Node3D = Node3D.new()
	var out: Array = a.flush(holder, holder)
	var mesh: ArrayMesh = (out[0] as MeshInstance3D).mesh as ArrayMesh
	holder.free()
	return mesh


# --- Room surfaces: floors, ceilings, baseboards, wainscots, cornices ---------------------------

func room_surfaces() -> void:
	for r: Array in L.ROOMS:
		var id: String = String(r[0])
		if not FINISH.has(id):
			continue
		var fin: Array = FINISH[id]
		var box0: Array = (r[4] as Array)[0]
		var floor_y: float = float(box0[1])
		for b: Array in r[4]:
			var x0: float = float(b[0])
			var y0: float = float(b[1])
			var z0: float = float(b[2])
			var x1: float = float(b[3])
			var y1: float = float(b[4])
			var z1: float = float(b[5])
			if id != "G2":
				acc.quad("Interior", String(fin[0]), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1),
					Vector3(x0, y0, z1), Vector3.UP)
				# the ceiling stops at walls that carry on above it (their soffit is drawn by the wall)
				var cx0: float = x0 + _wall_thickness("z", x0, y1 + 0.01, z0, z1) * 0.5
				var cx1: float = x1 - _wall_thickness("z", x1, y1 + 0.01, z0, z1) * 0.5
				var cz0: float = z0 + _wall_thickness("x", z0, y1 + 0.01, x0, x1) * 0.5
				var cz1: float = z1 - _wall_thickness("x", z1, y1 + 0.01, x0, x1) * 0.5
				acc.quad("Interior", String(fin[2]), Vector3(cx0, y1, cz0), Vector3(cx1, y1, cz0), Vector3(cx1, y1, cz1),
					Vector3(cx0, y1, cz1), Vector3.DOWN)
		if id in ["B3", "B7", "B10", "G2"]:
			continue
		for b2: Array in r[4]:
			_trim_room_box(b2, floor_y, floor_y, floor_y + BASEBOARD_H, BASEBOARD_D, "trim_baseboard")
			if id in WAINSCOT_ROOMS:
				_trim_room_box(b2, floor_y, floor_y + BASEBOARD_H, floor_y + WAINSCOT_H, 0.012, "paint_slate")
				_trim_room_box(b2, floor_y, floor_y + WAINSCOT_H, floor_y + WAINSCOT_H + 0.05, 0.03, "brass")
			if id in CORNICE_ROOMS:
				var ceil_y: float = float(b2[4])
				_trim_room_box(b2, floor_y, ceil_y - CORNICE_H, ceil_y, CORNICE_D, "trim_crown_cornice")


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
		var t: float = _wall_thickness(axis, fixed, ya + 0.01, float(e[2]), float(e[3]))
		if t <= 0.0:
			continue
		var face: float = fixed + inward * t * 0.5
		var a0: float = float(e[2]) + _end_inset(axis, float(e[2]), ya + 0.01)
		var a1: float = float(e[3]) - _end_inset(axis, float(e[3]), ya + 0.01)
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
			# ends that butt into a cross wall are buried
			var end0: int = (0 if axis == "x" else 4) if run.x <= a0 + 0.001 and a0 > float(e[2]) + 0.001 else -1
			var end1: int = (1 if axis == "x" else 5) if run.y >= a1 - 0.001 and a1 < float(e[3]) - 0.001 else -1
			acc.box("Trim", lo, hi, func(f: int, _n: Vector3, _c: Vector3) -> String:
				return "" if f == back or f == end0 or f == end1 or (f == 2 and ya <= floor_y + 0.001) \
					or (f == 3 and yb > floor_y + 1.0) else key)


## Thickness of the wall on this line covering height y (0 = none).
func _wall_thickness(axis: String, fixed: float, y: float, a0: float = -1.0e9, a1: float = 1.0e9) -> float:
	for w: Array in _walls:
		if String(w[0]) == axis and absf(float(w[1]) - fixed) < 0.01 and y >= float(w[4]) - 0.01 and y < float(w[5]) \
				and minf(a1, float(w[3])) - maxf(a0, float(w[2])) > 0.05:
			return float(w[7])
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
		if String(w[0]) != axis or absf(float(w[1]) - fixed) > 0.01:
			continue
		if float(w[4]) > ya + 0.001 or float(w[5]) < yb - 0.001:
			continue
		var segs: Array[Vector2] = [Vector2(maxf(float(w[2]), a0), minf(float(w[3]), a1))]
		for o: Array in w[6]:
			if float(o[2]) < yb - 0.001 and float(o[3]) > ya + 0.001:
				var m: float = DOOR_CASING if float(o[2]) <= float(w[4]) + 0.01 or absf(float(o[2])) < 0.01 \
					or absf(float(o[2]) - L.BASE) < 0.01 else WINDOW_CASING
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


## The banking hall's coffered ceiling: a beam grid 0.32 m deep under the 5.5 m ceiling, and a
## plaster frieze band; the lit pendants hang between the beams.
func hall_coffers() -> void:
	var y1: float = L.HALL_CEIL
	var y0: float = y1 - 0.32
	for x: float in [5.25, 10.5, 15.75]:
		acc.box("Interior", Vector3(x - 0.16, y0, 10.2), Vector3(x + 0.16, y1, 19.8), func(f: int, _n: Vector3, _c: Vector3) -> String:
			return "" if f == 3 else "plaster_painted")
	for z: float in [12.0, 14.5, 17.0]:
		for seg: Vector2 in [Vector2(0.2, 5.09), Vector2(5.41, 10.34), Vector2(10.66, 15.59), Vector2(15.91, 20.8)]:
			acc.box("Interior", Vector3(seg.x, y0 + 0.04, z - 0.14), Vector3(seg.y, y1, z + 0.14),
				func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 3 else "plaster_painted")


# --- Facade -------------------------------------------------------------------------------------

## Granite plinth (0-0.6 m) round the street faces, a stone string course at the wing parapet and a
## heavy cornice + coping on the hall parapet; stone architraves round the hall bays and the
## entrance portal (pilasters, entablature); slate-green ironwork fascia over the ATM glass.
func facade() -> void:
	# [axis, line, outward, span, string course]
	var lines: Array = [["x", 20.0, 1.0, Vector2(-0.2, 26.2), false], ["z", 26.0, 1.0, Vector2(-0.2, 20.2), true],
		["x", 0.0, -1.0, Vector2(-0.2, 26.2), true]]
	for ln: Array in lines:
		var axis: String = String(ln[0])
		var fixed: float = float(ln[1])
		var outward: float = float(ln[2])
		var span: Vector2 = ln[3]
		var face: float = fixed + outward * L.EXT_T * 0.5
		var bands: Array = [[0.0, 0.3, 0.05, "granite"], [0.3, 0.6, 0.05, "granite"]]
		if bool(ln[4]):
			bands.append([3.45, 3.6, 0.06, "stone_facade"])
		for band: Array in bands:
			for run: Vector2 in wall_runs(axis, fixed, span.x, span.y, float(band[0]), float(band[1])):
				_band(axis, face, outward, run, span, float(band[0]), float(band[1]), float(band[2]), String(band[3]))
	# cornice + coping at each street wall's parapet top
	for w: Array in L.EXT_WALLS:
		var axis2: String = String(w[1])
		var fixed2: float = float(w[2])
		var top: float = float(w[8])
		var out2: float = float(w[9])
		if String(w[0]).begins_with("ExtWest") or String(w[0]).ends_with("Upper") and top < 5.0:
			continue
		var span2: Vector2 = Vector2(minf(float(w[3]), float(w[5])), maxf(float(w[4]), float(w[6])))
		_band(axis2, fixed2 + out2 * L.EXT_T * 0.5, out2, span2, span2, top - 0.16, top, 0.12, "stone_facade")
	_bay_surrounds()
	_entrance_portal()
	_thresholds()


func _band(axis: String, face: float, outward: float, run: Vector2, span: Vector2, ya: float, yb: float, d: float, key: String) -> void:
	# only the x-line (north / south) bands wrap the corners, so two bands never overlap there
	var wrap: float = d if axis == "x" else 0.0
	var r0: float = run.x - (wrap if run.x <= span.x + 0.001 else 0.0)
	var r1: float = run.y + (wrap if run.y >= span.y - 0.001 else 0.0)
	var lo: Vector3
	var hi: Vector3
	if axis == "x":
		lo = Vector3(r0, ya, minf(face, face + outward * d))
		hi = Vector3(r1, yb, maxf(face, face + outward * d))
	else:
		lo = Vector3(minf(face, face + outward * d), ya, r0)
		hi = Vector3(maxf(face, face + outward * d), yb, r1)
	var back: int = (5 if outward < 0.0 else 4) if axis == "x" else (1 if outward < 0.0 else 0)
	acc.box("Shell", lo, hi, func(f: int, _n: Vector3, _c: Vector3) -> String:
		return "" if f == back or (f == 2 and ya < 0.001) else key)


## Stone architraves round the four hall bays (window + transom) and the ATM vestibule glazing.
func _bay_surrounds() -> void:
	var z: float = 20.2
	for bay: Vector2 in [Vector2(1.0, 4.0), Vector2(4.5, 7.5), Vector2(13.5, 16.5), Vector2(17.0, 20.0)]:
		_surround_x(z, bay.x, bay.y, 1.0, 4.5, 0.18, 0.06, "stone_facade")
		# sill: a projecting stone sill under the bay
		acc.box("Shell", Vector3(bay.x - 0.2, 0.9, z), Vector3(bay.y + 0.2, 1.0, z + 0.1), func(f: int, _n: Vector3, _c: Vector3) -> String:
			return "" if f == 4 else "stone_facade")
	for w: Vector2 in [Vector2(21.6, 23.4), Vector2(24.9, 25.7)]:
		_surround_x(z, w.x, w.y, 0.3, 2.7, 0.06, 0.04, "metal_slate")
	# east windows (G11, G12): stone surrounds on the Wharf Lane face
	for zz: Vector2 in [Vector2(9.0, 11.0), Vector2(13.0, 15.0)]:
		var fx: float = 26.2
		for p: Array in [[zz.x - 0.15, zz.x, 0.75, 2.25], [zz.y, zz.y + 0.15, 0.75, 2.25], [zz.x - 0.15, zz.y + 0.15, 2.1, 2.25],
				[zz.x - 0.2, zz.y + 0.2, 0.8, 0.9]]:
			acc.box("Shell", Vector3(fx, float(p[2]), float(p[0])), Vector3(fx + 0.06, float(p[3]), float(p[1])),
				func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 0 else "stone_facade")


## Architrave round an opening on the south face (z = face, outward +Z): jambs, head, depth `d`.
func _surround_x(z: float, a0: float, a1: float, y0: float, y1: float, w: float, d: float, key: String) -> void:
	# jambs stand on the sill / plinth (no underside); the head's soffit shows
	for p: Array in [[a0 - w, a0, y0, y1 + w, true], [a1, a1 + w, y0, y1 + w, true], [a0, a1, y1, y1 + w, false]]:
		var jamb: bool = bool(p[4])
		acc.box("Shell", Vector3(float(p[0]), float(p[2]), z), Vector3(float(p[1]), float(p[3]), z + d),
			func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 4 or (f == 2 and jamb) else key)


## Bronze-door portal: two stone pilasters and an entablature over the entrance (the harbour clock
## sits on it), granite steps' nosing at the threshold.
func _entrance_portal() -> void:
	var z: float = 20.2
	for x: Vector2 in [Vector2(8.95, 9.35), Vector2(11.65, 12.05)]:
		acc.box("Shell", Vector3(x.x, 0.0, z), Vector3(x.y, 2.75, z + 0.16), func(f: int, _n: Vector3, _c: Vector3) -> String:
			return "" if f == 4 or f == 2 else "stone_facade")
		acc.box("Shell", Vector3(x.x - 0.05, 0.0, z), Vector3(x.y + 0.05, 0.45, z + 0.2), func(f: int, _n: Vector3, _c: Vector3) -> String:
			return "" if f == 4 or f == 2 else "granite")
	acc.box("Shell", Vector3(8.8, 2.75, z), Vector3(12.2, 3.0, z + 0.22), func(f: int, _n: Vector3, _c: Vector3) -> String:
		return "" if f == 4 else "stone_facade")


## Exterior door thresholds: the outer half of the wall under ground-floor street / lot doors.
func _thresholds() -> void:
	for d: Array in L.DOORS:
		var p: Vector3 = d[2]
		if absf(p.y) > 0.01 or p.x < -0.5 or p.x > 26.5 or p.z < -0.5 or p.z > 20.5:
			continue
		var w: float = 1.8 if String(d[1]).contains("double") else (1.1 if String(d[1]).contains("service") else 0.9)
		var key: String = "granite"
		var h: float = L.EXT_T * 0.5
		if absf(p.z - 20.0) < 0.01:
			acc.quad("Shell", key, Vector3(p.x - w * 0.5, 0.0, 20.0), Vector3(p.x + w * 0.5, 0.0, 20.0),
				Vector3(p.x + w * 0.5, 0.0, 20.0 + h), Vector3(p.x - w * 0.5, 0.0, 20.0 + h), Vector3.UP)
		elif absf(p.z) < 0.01:
			acc.quad("Shell", "concrete", Vector3(p.x - w * 0.5, 0.0, -h), Vector3(p.x + w * 0.5, 0.0, -h),
				Vector3(p.x + w * 0.5, 0.0, 0.0), Vector3(p.x - w * 0.5, 0.0, 0.0), Vector3.UP)
		elif absf(p.x - 26.0) < 0.01:
			acc.quad("Shell", "concrete", Vector3(26.0, 0.0, p.z - w * 0.5), Vector3(26.0 + h, 0.0, p.z - w * 0.5),
				Vector3(26.0 + h, 0.0, p.z + w * 0.5), Vector3(26.0, 0.0, p.z + w * 0.5), Vector3.UP)


# --- Site: markings, kerbs, compass rose ---------------------------------------------------------

## Road centre lines, the lot's parking stalls and the armoured-car bay hatching, the quay kerb.
func site_markings() -> void:
	var y: float = L.ROAD_Y + 0.004
	var x: float = -44.0
	while x < 59.0:
		acc.quad("Street", "paint_white", Vector3(x, y, 26.15), Vector3(x + 2.5, y, 26.15), Vector3(x + 2.5, y, 26.25),
			Vector3(x, y, 26.25), Vector3.UP)
		x += 5.0
	var z: float = -29.0
	while z < 21.5:
		acc.quad("Street", "paint_white", Vector3(32.45, y, z), Vector3(32.55, y, z), Vector3(32.55, y, z + 2.5),
			Vector3(32.45, y, z + 2.5), Vector3.UP)
		z += 5.0
	# parking-lane edge on Harbor Street (north side)
	acc.quad("Street", "paint_white", Vector3(-44.0, y, 24.35), Vector3(59.0, y, 24.35), Vector3(59.0, y, 24.45),
		Vector3(-44.0, y, 24.45), Vector3.UP)
	# lot stalls (east of the sally door: staff cars) and the armoured-car bay (west, hatched yellow)
	var ly: float = 0.004
	var sx: float = 11.2
	while sx < 26.0:
		acc.quad("Street", "paint_white", Vector3(sx, ly, -9.2), Vector3(sx + 0.1, ly, -9.2), Vector3(sx + 0.1, ly, -4.2),
			Vector3(sx, ly, -4.2), Vector3.UP)
		sx += 2.6
	for e: Array in [[0.9, -9.2, 4.6, -9.1], [0.9, -2.9, 4.6, -2.8], [0.9, -9.2, 1.0, -2.8], [4.5, -9.2, 4.6, -2.8]]:
		acc.quad("Street", "metal_yellow", Vector3(float(e[0]), ly, float(e[1])), Vector3(float(e[2]), ly, float(e[1])),
			Vector3(float(e[2]), ly, float(e[3])), Vector3(float(e[0]), ly, float(e[3])), Vector3.UP)
	# quay kerb: granite coping at the water edge (except the steps)
	for seg: Vector2 in [Vector2(-45.0, 6.0), Vector2(11.0, 60.0)]:
		acc.box("Street", Vector3(seg.x, 0.0, 33.6), Vector3(seg.y, 0.12, 34.0), func(f: int, _n: Vector3, _c: Vector3) -> String:
			return "" if f == 2 else "granite")


## Landmark 2: the mosaic compass rose inlaid in the hall floor: a brass ring, a bank-red band, a
## cream field and an 8-point star of slate and cream points (layers 3 and 6 mm above the floor).
func compass(pos: Vector3, r: float) -> void:
	var segs: int = 48
	var y1: float = pos.y + 0.003
	var y2: float = pos.y + 0.006
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		for band: Array in [[r, r - 0.08, "brass"], [r - 0.08, r - 0.3, "carpet_red"], [r - 0.3, r - 0.36, "brass"]]:
			var ro: float = float(band[0])
			var ri: float = float(band[1])
			acc.quad("Interior", String(band[2]), pos + Vector3(cos(a0) * ri, 0.003, sin(a0) * ri),
				pos + Vector3(cos(a1) * ri, 0.003, sin(a1) * ri), pos + Vector3(cos(a1) * ro, 0.003, sin(a1) * ro),
				pos + Vector3(cos(a0) * ro, 0.003, sin(a0) * ro), Vector3.UP)
		var rf: float = r - 0.36
		acc.quad("Interior", "marble_cream", Vector3(pos.x, y1, pos.z), pos + Vector3(cos(a0) * rf, 0.003, sin(a0) * rf),
			pos + Vector3(cos(a1) * rf, 0.003, sin(a1) * rf), pos + Vector3(cos(a1) * rf, 0.003, sin(a1) * rf), Vector3.UP)
	# star: 8 points, long (N/E/S/W: slate / cream halves) and short (diagonals: red / granite halves),
	# tessellated edge to edge (tips and the valleys between them), one layer 6 mm above the floor
	var vr: float = 0.45
	var yy: float = y2
	for k: int in range(8):
		var ang: float = TAU * float(k) / 8.0 - PI * 0.5
		var tip: float = (r - 0.38) if k % 2 == 0 else (r - 0.75)
		var t: Vector3 = pos + Vector3(cos(ang) * tip, 0.006, sin(ang) * tip)
		var va: float = ang - PI / 8.0
		var vb: float = ang + PI / 8.0
		var v0: Vector3 = pos + Vector3(cos(va) * vr, 0.006, sin(va) * vr)
		var v1: Vector3 = pos + Vector3(cos(vb) * vr, 0.006, sin(vb) * vr)
		var c0: Vector3 = Vector3(pos.x, yy, pos.z)
		var keys: Array = ["paint_slate", "marble_cream"] if k % 2 == 0 else ["carpet_red", "granite"]
		acc.quad("Interior", String(keys[0]), c0, v0, t, t, Vector3.UP)
		acc.quad("Interior", String(keys[1]), c0, t, v1, v1, Vector3.UP)
	acc.box("Interior", pos + Vector3(-0.12, 0.0, -0.12), pos + Vector3(0.12, 0.012, 0.12), "brass")


# --- Neighbours: windows, shopfronts, copings ----------------------------------------------------

## Window grids on every play-space-facing block face, a coping on each roof. Lit windows come from a
## fixed-seed RNG (presentation only; never gameplay).
func neighbours(blocks: Array) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x4E445032  # fixed: "NDP2"
	var centre: Vector2 = Vector2(13.0, 10.0)
	for b: Array in blocks:
		var nm: String = String(b[0])
		var bx: Array = b[1]
		var lo: Vector3 = Vector3(float(bx[0]), float(bx[1]), float(bx[2]))
		var hi: Vector3 = Vector3(float(bx[3]), float(bx[4]), float(bx[5]))
		if hi.y < 5.0 or nm in ["FarShore", "CraneOffice"]:
			continue
		for cp: Array in [[lo.x, hi.x, lo.z, lo.z + 0.3], [lo.x, hi.x, hi.z - 0.3, hi.z],
				[lo.x, lo.x + 0.3, lo.z + 0.3, hi.z - 0.3], [hi.x - 0.3, hi.x, lo.z + 0.3, hi.z - 0.3]]:
			acc.box("Neighbours", Vector3(float(cp[0]), hi.y, float(cp[2])), Vector3(float(cp[1]), hi.y + 0.45, float(cp[3])),
				func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 2 else "concrete")
		var faces: Array = [[Vector3.LEFT, lo.x, "z", lo.z, hi.z], [Vector3.RIGHT, hi.x, "z", lo.z, hi.z],
			[Vector3.FORWARD, lo.z, "x", lo.x, hi.x], [Vector3.BACK, hi.z, "x", lo.x, hi.x]]
		for fc: Array in faces:
			var n: Vector3 = fc[0]
			var fx: float = float(fc[1])
			var a0: float = float(fc[3])
			var a1: float = float(fc[4])
			var mid: Vector2 = Vector2(fx, (a0 + a1) * 0.5) if String(fc[2]) == "z" else Vector2((a0 + a1) * 0.5, fx)
			if Vector2(n.x, n.z).dot(centre - mid) <= 0.0 or a1 - a0 < 4.0:
				continue
			# faces flush against another block (party walls) get none
			if _covered(blocks, nm, n, fx, a0, a1):
				continue
			_face_windows(rng, n, fx, String(fc[2]), a0, a1, hi.y, nm == "PellChandlery" and n == Vector3.BACK)


func _covered(blocks: Array, me: String, n: Vector3, fx: float, a0: float, a1: float) -> bool:
	for b: Array in blocks:
		if String(b[0]) == me:
			continue
		var bx: Array = b[1]
		var other_face: float = float(bx[0]) if n.x > 0.5 else (float(bx[3]) if n.x < -0.5 else (float(bx[2]) if n.z > 0.5 else float(bx[5])))
		if absf(other_face - fx) > 0.05:
			continue
		var b0: float = float(bx[2]) if absf(n.x) > 0.5 else float(bx[0])
		var b1: float = float(bx[5]) if absf(n.x) > 0.5 else float(bx[3])
		if b0 <= a0 + 0.5 and b1 >= a1 - 0.5:
			return true
	return false


func _face_windows(rng: RandomNumberGenerator, n: Vector3, fx: float, axis: String, a0: float, a1: float, height: float,
		shopfront: bool) -> void:
	var bay: float = 3.0
	var count: int = int(floor((a1 - a0 - 1.0) / bay))
	if count < 1:
		return
	var start: float = (a0 + a1) * 0.5 - float(count) * bay * 0.5
	var y: float = 3.4
	while y + 1.8 < height - 0.6:
		for i: int in range(count):
			var c: float = start + bay * (float(i) + 0.5)
			var key: String = "window_lit" if rng.randf() < 0.18 else "window_dark"
			_window_panel(n, fx, axis, c - 0.7, c + 0.7, y, y + 1.6, key)
		y += 3.4
	if shopfront:
		# the chandlery's shuttered shopfront on Harbor Street
		_window_panel(n, fx, axis, a0 + 1.0, a1 - 1.0, 0.3, 2.9, "metal_slate")


## Framed window: metal frame proud 0.04 m, glass 0.045 m (never coplanar with the facade).
func _window_panel(n: Vector3, fx: float, axis: String, a0: float, a1: float, y0: float, y1: float, key: String) -> void:
	var fr: float = 0.06
	var p0: float = fx + (0.0 if n.x + n.z > 0.0 else -0.04)
	var p1: float = p0 + 0.04
	var glass: float = fx + (0.045 if n.x + n.z > 0.0 else -0.045)
	var parts: Array = [[a0 - fr, a0, y0 - fr, y1 + fr], [a1, a1 + fr, y0 - fr, y1 + fr], [a0, a1, y1, y1 + fr],
		[a0, a1, y0 - fr, y0]]
	if key == "metal_slate":
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
		acc.box("Neighbours", lo, hi, func(_f: int, nn: Vector3, _c: Vector3) -> String:
			return "" if nn == -n else ("metal_dark" if key != "metal_slate" else "metal_slate"))
	if key == "metal_slate":
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


## Box occluders for solid massing (neighbour blocks, the party walls). Glazed walls get none.
func occluders(parent: Node3D, owner_root: Node, blocks: Array) -> void:
	for b: Array in blocks:
		var bx: Array = b[1]
		var lo: Vector3 = Vector3(float(bx[0]), float(bx[1]), float(bx[2]))
		var hi: Vector3 = Vector3(float(bx[3]), float(bx[4]), float(bx[5]))
		var size: Vector3 = hi - lo
		if size.y < 5.0 or minf(size.x, size.z) < 1.0 or String(b[2]) in ["glass", "crane", "container_hidden"]:
			continue
		var occ: OccluderInstance3D = OccluderInstance3D.new()
		occ.name = "Occluder" + String(b[0])
		occ.position = (lo + hi) * 0.5
		var bo: BoxOccluder3D = BoxOccluder3D.new()
		bo.size = size - Vector3(0.1, 0.1, 0.1)
		occ.occluder = bo
		parent.add_child(occ)
		occ.owner = owner_root


## Ambience beds (positional CueEmitters) and the cue player. The bank / harbour night beds
## (amb_bank_night_interior, amb_harbor_night) are not in the cue registry yet: the interior and
## street beds stand in for them (C2 G2 report). No MusicDirector until the night_deposit track exists.
func audio(parent: Node3D, owner_root: Node) -> void:
	var player: Node = Node.new()
	player.set_script(load("res://world/audio/cue_player.gd"))
	player.name = "CuePlayer"
	parent.add_child(player)
	player.owner = owner_root
	var beds: Array = [
		["BedBankingHall", Vector3(10.5, 3.0, 14.0), &"cue.amb_glasshouse_interior", -6.0],
		["BedBackOfHouse", Vector3(13.0, 1.8, 4.0), &"cue.amb_glasshouse_interior", -8.0],
		["BedBasement", Vector3(13.0, -2.2, 7.0), &"cue.amb_glasshouse_interior", -4.0],
		["BedHarborStreet", Vector3(10.0, 3.0, 27.0), &"cue.amb_street_dusk", -2.0],
		["BedQuay", Vector3(10.0, 2.0, 33.0), &"cue.amb_street_dusk", -4.0],
		["BedLot", Vector3(8.0, 3.0, -7.0), &"cue.amb_street_dusk", -6.0],
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
