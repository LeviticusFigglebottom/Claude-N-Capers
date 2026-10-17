## Gallery Night G2 art pass (GN-C2, ENV C): material library assignment per surface class and room finish, merged
## world-UV visuals (the Glasshouse / Night Deposit mesh accumulator, gh_mesh.gd), room trims (baseboards, picture
## rails, cornices, the top-lit galleries' laylights), local meshes for map-built props, reflection probes and occluders.
## The facade, the site and the skyline are in gn_art_site.gd. Used by the generator (gn_builder_base.box()).
## Design: docs/design/heists/gallery_night.md §Audio/lighting (palette: gallery bone #DCD5C6, halberd green #24463A,
## gilt #B8913E, gala lilac #B79CF2 emissive only; wear pristine); style: docs/art/style_guide.md; UV convention:
## tools/texgen/README.md (1 UV unit = 2 m, world-anchored).
extends RefCounted

const M: GDScript = preload("res://world/heists/glasshouse/greybox/gh_mesh.gd")
const L: GDScript = preload("res://world/heists/gallery_night/greybox/gallery_night_layout.gd")
const AE: GDScript = preload("res://world/heists/gallery_night/greybox/gn_assault.gd")
const MAT_DIR: String = "res://world/materials/"
const TRIM_TABLE: String = "res://assets/textures/trim_interior/trim_table.json"
const LIBRARY: Array[String] = [
	"plaster_painted", "drywall_painted", "concrete", "terrazzo", "marble_cream", "carpet_commercial",
	"ceiling_tile", "wood_veneer_walnut", "brushed_steel", "chrome", "brass", "glass_clear",
	"rubber_black", "plastic_matte", "asphalt", "tile_ceramic_white", "vinyl_floor",
	"metal_painted", "paint_white", "fabric_upholstery", "brick_red", "glass_frosted",
]
## Tinted library surfaces (keep the library textures): key -> [library id, tint (sRGB multiply)]. The key ends in the
## library id so the bullet surface lookup (SurfaceTags.for_id strips leading `<prefix>_` segments) resolves it.
const TINTS: Dictionary = {
	"bone_plaster_painted": ["plaster_painted", Color(0.97, 0.985, 1.0)],
	"limestone_plaster_painted": ["plaster_painted", Color(0.9, 0.88, 0.84)],
	"ashlar_marble_cream": ["marble_cream", Color(0.94, 0.93, 0.91)],
	"granite_marble_cream": ["marble_cream", Color(0.42, 0.41, 0.4)],
	"silk_fabric_upholstery": ["fabric_upholstery", Color(0.5, 0.86, 0.62)],
	"silkdark_fabric_upholstery": ["fabric_upholstery", Color(0.42, 0.72, 0.53)],
	"carpetgreen_carpet_commercial": ["carpet_commercial", Color(0.5, 0.82, 0.66)],
	"carpetwine_carpet_commercial": ["carpet_commercial", Color(0.95, 0.55, 0.55)],
	"gilt_brass": ["brass", Color(0.84, 0.75, 0.52)],
	"bronze_brass": ["brass", Color(0.55, 0.46, 0.34)],
	"oak_wood_veneer_walnut": ["wood_veneer_walnut", Color(1.0, 1.0, 1.0)],
	"paving_concrete": ["concrete", Color(0.95, 0.93, 0.9)],
	"court_concrete": ["concrete", Color(1.0, 0.97, 0.9)],
	"lino_vinyl_floor": ["vinyl_floor", Color(0.86, 0.9, 0.88)],
	"epoxy_vinyl_floor": ["vinyl_floor", Color(0.7, 0.72, 0.72)],
	"dark_metal_painted": ["metal_painted", Color(0.55, 0.56, 0.58)],
	"green_metal_painted": ["metal_painted", Color(0.45, 0.72, 0.6)],
	"membrane_asphalt": ["asphalt", Color(0.85, 0.85, 0.86)],
	"render_plaster_painted": ["plaster_painted", Color(0.66, 0.66, 0.68)],
	"stucco_plaster_painted": ["plaster_painted", Color(0.86, 0.8, 0.72)],
}
## Untextured emissive / glass surfaces (meta untextured_ok): key -> [albedo, emission, energy, roughness].
const EMISSIVE: Dictionary = {
	"emit_warm": [Color(1.0, 0.86, 0.66), Color(1.0, 0.82, 0.58), 3.0, 0.6],
	"emit_cool": [Color(0.9, 0.94, 1.0), Color(0.88, 0.93, 1.0), 2.5, 0.6],
	"emit_lilac": [Color(0.78, 0.68, 0.98), Color(0.72, 0.61, 0.95), 3.0, 0.6],
	"laylight": [Color(0.62, 0.7, 0.82), Color(0.48, 0.58, 0.78), 0.55, 0.3],
	"window_lit": [Color(0.95, 0.8, 0.55), Color(0.95, 0.74, 0.48), 1.2, 0.35],
	"window_dark": [Color(0.09, 0.1, 0.12), Color(0.0, 0.0, 0.0), 0.0, 0.35],
	"emit_screen": [Color(0.11, 0.13, 0.16), Color(0.47, 0.56, 0.65), 0.9, 0.4],
	"laser_red": [Color(1.0, 0.12, 0.08), Color(1.0, 0.08, 0.05), 4.0, 0.6],
}
## Room id -> [floor, walls, ceiling] material keys (doc §Audio/lighting: the public gallery rooms in bone and halberd
## green, the hall in marble and bone, back of house plain and pristine).
const FINISH: Dictionary = {
	"SS": ["terrazzo", "plaster_painted", "plaster_painted"],
	"HH": ["concrete", "plaster_painted", "concrete"],
	"LF": ["epoxy_vinyl_floor", "concrete", "concrete"],
	"LM": ["concrete", "concrete", "concrete"],
	"LK": ["lino_vinyl_floor", "drywall_painted", "ceiling_tile"],
	"FR": ["concrete", "drywall_painted", "concrete"],
	"QR": ["epoxy_vinyl_floor", "drywall_painted", "concrete"],
	"BB": ["lino_vinyl_floor", "drywall_painted", "ceiling_tile"],
	"PL": ["concrete", "concrete", "concrete"],
	"AS": ["epoxy_vinyl_floor", "paint_white", "concrete"],
	"BR": ["lino_vinyl_floor", "drywall_painted", "ceiling_tile"],
	"WC": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],
	"SC": ["carpet_commercial", "drywall_painted", "ceiling_tile"],
	"RG": ["carpet_commercial", "drywall_painted", "ceiling_tile"],
	"J": ["concrete", "drywall_painted", "ceiling_tile"],
	"E1": ["concrete", "drywall_painted", "ceiling_tile"],
	"LD": ["concrete", "concrete", "concrete"],
	"BC": ["lino_vinyl_floor", "drywall_painted", "ceiling_tile"],
	"WG": ["oak_wood_veneer_walnut", "bone_plaster_painted", "bone_plaster_painted"],
	"GH": ["marble_cream", "bone_plaster_painted", "bone_plaster_painted"],
	"EG": ["oak_wood_veneer_walnut", "bone_plaster_painted", "bone_plaster_painted"],
	"DC": ["carpetgreen_carpet_commercial", "silkdark_fabric_upholstery", "bone_plaster_painted"],
	"PWW": ["terrazzo", "marble_cream", "plaster_painted"],
	"PWM": ["terrazzo", "marble_cream", "plaster_painted"],
	"CK": ["terrazzo", "bone_plaster_painted", "bone_plaster_painted"],
	"VE": ["marble_cream", "ashlar_marble_cream", "bone_plaster_painted"],
	"GS": ["terrazzo", "bone_plaster_painted", "bone_plaster_painted"],
	"EB": ["carpetgreen_carpet_commercial", "bone_plaster_painted", "bone_plaster_painted"],
	"CO": ["carpetgreen_carpet_commercial", "bone_plaster_painted", "ceiling_tile"],
	"AO": ["carpet_commercial", "drywall_painted", "ceiling_tile"],
	"UW": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],
	"FS": ["concrete", "drywall_painted", "ceiling_tile"],
	"SV": ["lino_vinyl_floor", "drywall_painted", "ceiling_tile"],
	"CS": ["lino_vinyl_floor", "paint_white", "plaster_painted"],
	"UC": ["carpet_commercial", "drywall_painted", "ceiling_tile"],
	"UG1": ["oak_wood_veneer_walnut", "silk_fabric_upholstery", "laylight"],
	"UG2": ["oak_wood_veneer_walnut", "silk_fabric_upholstery", "laylight"],
	"UG3": ["oak_wood_veneer_walnut", "silk_fabric_upholstery", "laylight"],
	"BW": ["marble_cream", "bone_plaster_painted", "bone_plaster_painted"],
	"BE": ["marble_cream", "bone_plaster_painted", "bone_plaster_painted"],
	"SL": ["marble_cream", "bone_plaster_painted", "bone_plaster_painted"],
	"AT": ["lino_vinyl_floor", "drywall_painted", "ceiling_tile"],
	"TR": ["carpetgreen_carpet_commercial", "silk_fabric_upholstery", "bone_plaster_painted"],
}
## Rooms with a picture rail (gilt) and a cornice; the galleries also get a dado (chair rail) band.
const PICTURE_RAIL_ROOMS: Array[String] = ["WG", "EG", "EB", "DC", "UG1", "UG2", "UG3", "TR", "GH"]
const PICTURE_RAIL_Y: float = 3.3
const CORNICE_ROOMS: Array[String] = ["WG", "EG", "EB", "DC", "VE", "CK", "GS", "CO", "UG1", "UG2", "UG3", "TR"]
## Rooms without baseboards (bare service spaces).
const NO_BASEBOARD: Array[String] = ["PL", "LD", "LF", "LM", "HH", "SS"]
const BASEBOARD_H: float = 0.15
const BASEBOARD_D: float = 0.015
const CORNICE_H: float = 0.22
const CORNICE_D: float = 0.06
const DOOR_CASING: float = 0.18
const WINDOW_CASING: float = 0.06
## Greybox surface class -> material key for the plain classes (all faces).
const CLASS_MAT: Dictionary = {
	"asphalt": "asphalt", "paving": "paving_concrete", "court_stone": "court_concrete", "glass": "glass_clear",
	"glass_frosted": "glass_frosted", "trim": "dark_metal_painted", "prop": "dark_metal_painted",
	"door": "green_metal_painted", "frame": "dark_metal_painted",
	"counter": "wood_veneer_walnut", "handrail": "bronze_brass", "steel": "brushed_steel", "gilt": "gilt_brass",
	"stone": "ashlar_marble_cream", "limestone": "limestone_plaster_painted", "granite": "granite_marble_cream",
	"partition": "silk_fabric_upholstery", "concrete": "concrete", "brick": "brick_red", "render": "render_plaster_painted",
	"stucco": "stucco_plaster_painted", "pole": "dark_metal_painted", "membrane": "membrane_asphalt",
}
## Per class: [bottom (-Y), top (+Y), sides] keys ("" = face not rendered). "@room": the finish of the room the face
## looks into; "@ext": the facade (limestone, granite plinth, concrete below grade); "@ceil": the ceiling finish of the
## room below; "@floor": the floor finish of the room above (or threshold stone outside).
const CLASS_FACES: Dictionary = {
	"wall_ext": ["@ext", "@ext", "@ext"], "wall": ["@room", "@room", "@room"],
	"floor": ["@ceil", "", "plaster_painted"], "sill": ["@ceil", "@floor", "plaster_painted"],
	"ceiling": ["@ceil", "plaster_painted", "plaster_painted"],
	"roof": ["@ceil", "membrane_asphalt", "limestone_plaster_painted"],
	"stair": ["plaster_painted", "@stair", "@stair"],
	"rail": ["ashlar_marble_cream", "gilt_brass", "ashlar_marble_cream"],
	"none": ["", "", ""], "hidden": ["", "", ""],
}
## Merged visual groups (one MeshInstance3D each; the Compatibility renderer lights an instance with at most 8 lights):
## one per room ("Room<floor><id>"), per facade side and 11 m segment ("Shell<N|S|E|W|U><segment>"), the grade in
## 16 m tiles ("Site"). Rooms of at least TILE_ROOM_AREA m² also cut their floor / ceiling into SLAB_TILE cells (gh_mesh
## tile_groups), the Great Hall its long walls too. Every face of the perf `draw calls` budget counts once per surface.
const SLAB_TILE: float = 6.0
const SITE_TILE: float = 16.0
const SHELL_SEGMENT: float = 11.0
const TILE_ROOM_AREA: float = 140.0
const WALL_TILED_ROOMS: Array[String] = ["GH"]
const WALL_TILE_MIN_RUN: float = 8.0
## The hall coffers' own group (10 m tiles: the three chandeliers, the landing spot and the fills light it).
const COFFERS: String = "HallCoffers"
const COFFER_TILE: float = 10.0
## Floors-above the ground: the walls of these rooms are split at FLOOR_HEIGHTS, whose buried faces are skipped.
const FLOOR_EPS: float = 0.001
const CEILING_LIFT: float = 0.004
## Thresholds reach this far past the plan opening (the door kit's double / service openings are wider).
const THRESHOLD_EXTRA: float = 0.12

## [floor, id, y0, y1, x0, z0, x1, z1] per interior room rect (_room_boxes).
static var _room_cache: Array = _room_boxes()
## Every room rect's x / z edge lines (faces are cut there: one finish per room).
static var _room_lines_x: Array[float] = _room_lines(4)
static var _room_lines_z: Array[float] = _room_lines(5)

var acc: RefCounted = M.new()
var _mats: Dictionary = {}
## Queued class boxes [mn, mx, cls] (drawn by draw_queued once every solid is known) and the solids (AABBs) in a 2 m
## grid hash: a face whose samples all lie inside other solids is buried and never drawn (junctions, floor splits).
var _queue: Array[Array] = []
var _solids: Array[AABB] = []
var _grid: Dictionary = {}
var _room_groups: Dictionary = {}
## Wall lines: [floor, axis, fixed, from, to, y0, y1, openings [[a0, a1, y0, y1]], thickness].
var _walls: Array[Array] = []


func setup() -> void:
	acc.tile_groups["Site"] = SITE_TILE
	for id: String in LIBRARY:
		var m: Material = load(MAT_DIR + id + ".tres") as Material
		_mats[id] = m
		acc.register_material(id, m)
	var trim: Material = load(MAT_DIR + "trim_interior.tres") as Material
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRIM_TABLE))
	for s: Dictionary in table["strips"]:
		var tk: String = "trim_" + String(s["name"])
		_mats[tk] = trim
		acc.register_material(tk, trim, Vector2(float(s["v_top_gltf"]), float(s["v_bottom_gltf"])))
	var tint_keys: Array = TINTS.keys()
	tint_keys.sort()
	for k: Variant in tint_keys:
		var row: Array = TINTS[k]
		var tm: BaseMaterial3D = (_mats[String(row[0])] as BaseMaterial3D).duplicate() as BaseMaterial3D
		tm.resource_name = "gn_" + String(k)
		tm.albedo_color = row[1]
		_mats[String(k)] = tm
		acc.register_material(String(k), tm)
	var em_keys: Array = EMISSIVE.keys()
	em_keys.sort()
	for k2: Variant in em_keys:
		var row2: Array = EMISSIVE[k2]
		var em: StandardMaterial3D = StandardMaterial3D.new()
		em.resource_name = "gn_" + String(k2)
		em.albedo_color = row2[0]
		em.roughness = float(row2[3])
		if float(row2[2]) > 0.0:
			em.emission_enabled = true
			em.emission = row2[1]
			em.emission_energy_multiplier = float(row2[2])
		em.set_meta(&"untextured_ok", true)
		_mats[String(k2)] = em
		acc.register_material(String(k2), em)
	for w: Array in L.WALLS:
		var holes: Array = []
		for o: Array in L.OPENINGS:
			if String(o[0]) == String(w[0]) and String(o[2]) == String(w[1]) and absf(float(o[3]) - float(w[2])) < 0.001:
				holes.append([float(o[4]), float(o[5]), float(o[6]), float(o[7])])
		holes.append_array(AE.holes(String(w[0]), String(w[1]), float(w[2]), float(w[3]), float(w[4])))
		_walls.append([String(w[0]), String(w[1]), float(w[2]), float(w[3]), float(w[4]), float(w[6]), float(w[7]), holes,
			float(w[5])])


func mat(key: String) -> Material:
	return _mats.get(key)


func has_key(key: String) -> bool:
	return _mats.has(key)


## Bullet surface id for a material key (its library id).
static func surface_of(key: String) -> StringName:
	if key == "" or key.begins_with("emit") or key.begins_with("window") or key == "laylight":
		return &"glass" if key == "laylight" or key.begins_with("window") else &""
	return SurfaceTags.for_id(key)


# --- Rooms -------------------------------------------------------------------------------------

## [floor, id, y0, y1, x0, z0, x1, z1] per interior room rect (the halls and galleries up to their top; the shafts
## floor to floor).
static func _room_boxes() -> Array:
	var out: Array = []
	for r: Array in L.ROOMS:
		if String(r[2]) == "exterior":
			continue
		var f: String = String(r[0])
		var y0: float = float(L.FFL[f])
		var rid: String = String(r[1])
		var ceil: float = float(r[7])
		var y1: float = y0 + (ceil if ceil > 0.0 else 3.6)
		if rid in ["SS", "LF"]:
			var i: int = L.FLOORS.find(f)
			y1 = float(L.FLOOR_HEIGHTS[i + 1]) if i + 1 < L.FLOOR_HEIGHTS.size() else y0 + 3.0
		if f == "U" and L.U_TOP.has(rid):
			y1 = maxf(y1, float(L.U_TOP[rid]) - L.SLAB_T)
		if f == "G" and ceil > 0.0 and ceil < 5.0:
			y1 = float(L.FFL["U"]) - L.SLAB_T
		if f == "B":
			y1 = -L.SLAB_T
		out.append([f, rid, y0, y1, float(r[3]), float(r[4]), float(r[5]), float(r[6])])
	return out


static func _room_lines(i0: int) -> Array[float]:
	var out: Array[float] = []
	for b: Array in _room_boxes():
		for v: float in [float(b[i0]), float(b[i0 + 2])]:
			if not out.has(v):
				out.append(v)
	out.sort()
	return out


## Interior room id containing p, "" outside (and in slabs / voids between floors).
static func room_at(p: Vector3) -> String:
	for b: Array in _room_cache:
		if p.x > float(b[4]) and p.x < float(b[6]) and p.z > float(b[5]) and p.z < float(b[7]) \
				and p.y > float(b[2]) - 0.05 and p.y < float(b[3]) + 0.05:
			return String(b[1])
	return ""


## The building footprint at height y (the facade's outer line), for faces that look into the building but no room.
static func inside_building(p: Vector3) -> bool:
	for i: int in range(L.FLOORS.size()):
		var f: String = L.FLOORS[i]
		var y0: float = float(L.FFL[f]) - L.SLAB_T
		var y1: float = float(L.FLOOR_HEIGHTS[i + 1]) - L.SLAB_T if i + 1 < L.FLOOR_HEIGHTS.size() else 12.0
		var ft: Array = L.FOOT[f]
		if p.y >= y0 and p.y < y1 and p.x > float(ft[0]) and p.x < float(ft[2]) and p.z > float(ft[1]) and p.z < float(ft[3]):
			return f != "R" or p.x < 3.0 or (p.x > 28.0 and p.z < 6.0)
	return false


func _room_wall(c: Vector3, n: Vector3) -> String:
	var p: Vector3 = c + n * 0.3
	var r: String = room_at(p)
	if FINISH.has(r):
		return String((FINISH[r] as Array)[1])
	if inside_building(p):
		return "plaster_painted"
	return _ext_key(c)


static func _ext_key(c: Vector3) -> String:
	if c.y < -0.05:
		return "concrete"
	if c.y < 0.6:
		return "granite_marble_cream"
	return "limestone_plaster_painted"


func _floor_finish(c: Vector3) -> String:
	var r: String = room_at(c + Vector3.UP * 0.3)
	if FINISH.has(r):
		return String((FINISH[r] as Array)[0])
	return "granite_marble_cream" if absf(c.y) < 0.01 else "concrete"


func _ceil_finish(c: Vector3) -> String:
	var r: String = room_at(c + Vector3.DOWN * 0.3)
	if FINISH.has(r):
		return String((FINISH[r] as Array)[2])
	return "plaster_painted" if inside_building(c + Vector3.DOWN * 0.3) else "limestone_plaster_painted"


## Material key for face f (0 -X, 1 +X, 2 -Y, 3 +Y, 4 -Z, 5 +Z) of a box of greybox class `cls`.
func face_key(cls: String, f: int, n: Vector3, c: Vector3) -> String:
	var rule: Array = CLASS_FACES.get(cls, [])
	if rule.is_empty():
		return String(CLASS_MAT.get(cls, cls if _mats.has(cls) else "concrete"))
	var key: String = String(rule[0] if f == 2 else (rule[1] if f == 3 else rule[2]))
	if (cls == "wall" or cls == "wall_ext") and f == 3 and FINISH.has(room_at(c + Vector3.UP * 0.3)) \
			and _at_floor_level(c.y):
		return ""   # a lower wall's top under a room floor: the room's floor quad (or a threshold) covers it
	match key:
		"@room":
			key = _room_wall(c, n)
		"@ext":
			key = _room_wall(c, n) if f != 2 and f != 3 else "limestone_plaster_painted"
		"@floor":
			key = _floor_finish(c)
		"@ceil":
			key = _ceil_finish(c)
		"@stair":
			key = "marble_cream" if c.x > 12.0 and c.z > 8.0 and c.y >= -0.01 else "terrazzo"
	return key


static func _at_floor_level(y: float) -> bool:
	for fh: float in L.FLOOR_HEIGHTS:
		if absf(y - fh) < FLOOR_EPS or absf(y - (fh - L.SLAB_T)) < FLOOR_EPS:
			return true
	return false


## Queues a class box (drawn by draw_queued) and records it as a solid (not glass).
func vis_box(mn: Vector3, mx: Vector3, cls: String) -> void:
	var idx: int = -1
	if not cls.begins_with("glass"):  # clear or frosted (D-142) panes
		idx = _solids.size()
		_add_solid(AABB(mn, mx - mn))
	if cls == "" or cls == "none" or cls == "hidden":
		return
	if cls == "ceiling":   # underside 4 mm up: an opening head at the ceiling height keeps its soffit (zfight)
		mn.y += CEILING_LIFT
	_queue.append([mn, mx, cls, idx])


func _add_solid(b: AABB) -> void:
	var i: int = _solids.size()
	_solids.append(b)
	for cx: int in range(floori(b.position.x / 2.0), floori(b.end.x / 2.0) + 1):
		for cz: int in range(floori(b.position.z / 2.0), floori(b.end.z / 2.0) + 1):
			var k: Vector2i = Vector2i(cx, cz)
			if not _grid.has(k):
				_grid[k] = PackedInt32Array()
			var l: PackedInt32Array = _grid[k]
			l.append(i)
			_grid[k] = l


func _in_solid(q: Vector3) -> bool:
	var k: Vector2i = Vector2i(floori(q.x / 2.0), floori(q.z / 2.0))
	if not _grid.has(k):
		return false
	for i: int in _grid[k]:
		var b: AABB = _solids[i]
		if q.x > b.position.x + 1e-4 and q.x < b.end.x - 1e-4 and q.y > b.position.y + 1e-4 and q.y < b.end.y - 1e-4 \
				and q.z > b.position.z + 1e-4 and q.z < b.end.z - 1e-4:
			return true
	return false


## The exposed parts of face f (normal n) of box [mn, mx] as world rects [lo, hi] (flat along n): the face minus what
## other solids cover: a solid just in front of it (buried, 5 mm out) or the same-facing coplanar face of a larger solid
## (equal size: the earlier one), which draws that area itself (no z-fighting).
func _exposed(mn: Vector3, mx: Vector3, f: int, _n: Vector3, self_idx: int) -> Array:
	var ax: int = f / 2   # 0 x, 1 y, 2 z
	var u: int = 1 if ax == 0 else 0
	var v: int = 1 if ax == 2 else 2
	var d: float = mx[ax] if f % 2 == 1 else mn[ax]
	var sgn: float = 1.0 if f % 2 == 1 else -1.0
	var outer: Rect2 = Rect2(mn[u], mn[v], mx[u] - mn[u], mx[v] - mn[v])
	var self_area: float = outer.get_area()
	var holes: Array[Rect2] = []
	var seen: Dictionary = {}
	for cx: int in range(floori(minf(mn.x, mx.x) / 2.0), floori(maxf(mn.x, mx.x) / 2.0) + 1):
		for cz: int in range(floori(minf(mn.z, mx.z) / 2.0), floori(maxf(mn.z, mx.z) / 2.0) + 1):
			var k: Vector2i = Vector2i(cx, cz)
			if not _grid.has(k):
				continue
			for i: int in _grid[k]:
				if i == self_idx or seen.has(i):
					continue
				seen[i] = true
				var bb: AABB = _solids[i]
				var lo_a: float = bb.position[ax]
				var hi_a: float = bb.end[ax]
				var front: float = d + sgn * 0.005
				# buried: only floors / ceilings / tops (a wall end buried in a crossing wall stays: levelcheck seam_gaps
				# rays start inside the walls' corner squares and need those faces)
				var covers: bool = ax == 1 and front > lo_a + 1e-4 and front < hi_a - 1e-4
				if not covers:
					var on_plane: bool = absf((hi_a if sgn > 0.0 else lo_a) - d) < 0.0015
					if on_plane:
						var r_area: float = (bb.size[u]) * (bb.size[v])
						covers = r_area > self_area + 1e-6 or (absf(r_area - self_area) <= 1e-6 and (self_idx < 0 or i < self_idx))
				if not covers:
					continue
				var r: Rect2 = Rect2(bb.position[u], bb.position[v], bb.size[u], bb.size[v]).intersection(outer)
				if r.size.x > 1e-4 and r.size.y > 1e-4:
					holes.append(r)
	var out: Array = []
	for piece: Rect2 in rects_minus(outer, holes):
		if piece.size.x < 0.002 or piece.size.y < 0.002:
			continue
		var lo: Vector3 = mn
		var hi: Vector3 = mx
		lo[ax] = d
		hi[ax] = d
		lo[u] = piece.position.x
		hi[u] = piece.end.x
		lo[v] = piece.position.y
		hi[v] = piece.end.y
		out.append([lo, hi])
	return out


## Rect minus holes -> merged rects (deterministic grid sweep, as the builder's rects_minus).
static func rects_minus(outer: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	if holes.is_empty():
		return [outer]
	var xs: Array[float] = [outer.position.x, outer.end.x]
	var ys: Array[float] = [outer.position.y, outer.end.y]
	for h: Rect2 in holes:
		for vx: float in [h.position.x, h.end.x]:
			if vx > xs[0] + 1e-5 and vx < xs[1] - 1e-5 and not _has_near(xs, vx):
				xs.append(vx)
		for vy: float in [h.position.y, h.end.y]:
			if vy > ys[0] + 1e-5 and vy < ys[1] - 1e-5 and not _has_near(ys, vy):
				ys.append(vy)
	xs.sort()
	ys.sort()
	var out: Array[Rect2] = []
	var open: Dictionary = {}
	for j: int in range(ys.size() - 1):
		var runs: Array = []
		var start: float = NAN
		for i: int in range(xs.size() - 1):
			var cx: float = (xs[i] + xs[i + 1]) * 0.5
			var cy: float = (ys[j] + ys[j + 1]) * 0.5
			var inside: bool = false
			for h2: Rect2 in holes:
				if cx > h2.position.x and cx < h2.end.x and cy > h2.position.y and cy < h2.end.y:
					inside = true
					break
			if not inside and is_nan(start):
				start = xs[i]
			if inside and not is_nan(start):
				runs.append([start, xs[i]])
				start = NAN
		if not is_nan(start):
			runs.append([start, xs[xs.size() - 1]])
		var nxt: Dictionary = {}
		for run: Array in runs:
			var key: String = "%.5f|%.5f" % [float(run[0]), float(run[1])]
			var y0: float = float((open[key] as Array)[1]) if open.has(key) else ys[j]
			nxt[key] = [float(run[0]), y0, float(run[1])]
		var keys: Array = open.keys()
		keys.sort()
		for k: Variant in keys:
			if not nxt.has(k):
				var o: Array = open[k]
				out.append(Rect2(float(o[0]), float(o[1]), float(o[2]) - float(o[0]), ys[j] - float(o[1])))
		open = nxt
	var keys2: Array = open.keys()
	keys2.sort()
	for k2: Variant in keys2:
		var o2: Array = open[k2]
		out.append(Rect2(float(o2[0]), float(o2[1]), float(o2[2]) - float(o2[0]), ys[ys.size() - 1] - float(o2[1])))
	return out


static func _has_near(arr: Array[float], v: float) -> bool:
	for x: float in arr:
		if absf(x - v) < 1e-5:
			return true
	return false


static func _face_area(size: Vector3, n: Vector3) -> float:
	if absf(n.x) > 0.5:
		return size.y * size.z
	if absf(n.y) > 0.5:
		return size.x * size.z
	return size.x * size.y


static func _inside(b: AABB, q: Vector3) -> bool:
	return q.x > b.position.x + 1e-4 and q.x < b.end.x - 1e-4 and q.y > b.position.y + 1e-4 and q.y < b.end.y - 1e-4 \
		and q.z > b.position.z + 1e-4 and q.z < b.end.z - 1e-4


## Draws every queued class box: each drawn, unburied face to the merged visual of the room it looks into, the facade
## to its side's segment, the grade to "Site".
func draw_queued() -> void:
	var normals: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK]
	for q: Array in _queue:
		var mn: Vector3 = q[0]
		var mx: Vector3 = q[1]
		var cls: String = String(q[2])
		for f: int in range(6):
			var n: Vector3 = normals[f]
			var corners: Array[Vector3] = M._face(mn, mx, f)
			var c: Vector3 = (corners[0] + corners[2]) * 0.5
			if face_key(cls, f, n, c) == "":
				continue
			for piece: Array in _exposed(mn, mx, f, n, int(q[3])):
				for sub: Array in _split_at_rooms(piece[0], piece[1]):
					var pc: Array[Vector3] = M._face(sub[0], sub[1], f)
					var c2: Vector3 = (pc[0] + pc[2]) * 0.5
					var key: String = face_key(cls, f, n, c2)
					if key != "":
						acc.quad(_group_for(cls, c2, n), key, pc[0], pc[1], pc[2], pc[3], n)
	_queue.clear()


## A flat face rect [lo, hi] cut at every room-rect edge line crossing it (x and z), so each piece takes the finish and
## the visual group of the one room it looks into.
static func _split_at_rooms(lo: Vector3, hi: Vector3) -> Array:
	var xs: Array[float] = [lo.x, hi.x]
	var zs: Array[float] = [lo.z, hi.z]
	for v: float in _room_lines_x:
		if v > lo.x + 0.01 and v < hi.x - 0.01:
			xs.append(v)
	for w: float in _room_lines_z:
		if w > lo.z + 0.01 and w < hi.z - 0.01:
			zs.append(w)
	if xs.size() == 2 and zs.size() == 2:
		return [[lo, hi]]
	xs.sort()
	zs.sort()
	var out: Array = []
	for i: int in range(xs.size() - 1):
		for j: int in range(zs.size() - 1):
			out.append([Vector3(xs[i], lo.y, zs[j]), Vector3(xs[i + 1], hi.y, zs[j + 1])])
	return out


## Merged visual group of a face (centre c, normal n) of a class box.
func _group_for(cls: String, c: Vector3, n: Vector3) -> String:
	if cls in ["asphalt", "paving", "court_stone"]:
		return "Site"
	var probe: Vector3 = c + n * 0.3
	var r: String = room_at(probe)
	if r != "":
		return room_group(_floor_of(probe.y), r)
	return shell_group(c, n)


## A room's visual group (registers its tiling on first use).
func room_group(f: String, rid: String) -> String:
	var g: String = "Room" + f + rid
	if not _room_groups.has(g):
		_room_groups[g] = true
		for r: Array in L.ROOMS:
			if String(r[1]) == rid and (float(r[5]) - float(r[3])) * (float(r[6]) - float(r[4])) >= TILE_ROOM_AREA:
				acc.tile_groups[g] = SLAB_TILE
				if rid in WALL_TILED_ROOMS:
					acc.wall_tile_groups[g] = WALL_TILE_MIN_RUN
				break
	return g


## Facade / roof group: by the face's side (N S E W, U for up / down) and SHELL_SEGMENT segment along it.
func shell_group(c: Vector3, n: Vector3) -> String:
	if absf(n.y) > 0.5:
		return "ShellU%d_%d" % [floori(c.x / 22.0), floori(c.z / 16.0)]
	if absf(n.z) > 0.5:
		return "Shell%s%d" % ["S" if n.z > 0.0 else "N", floori(c.x / SHELL_SEGMENT)]
	return "Shell%s%d" % ["E" if n.x > 0.0 else "W", floori(c.z / SHELL_SEGMENT)]


static func _floor_of(y: float) -> String:
	var f: String = "B"
	for i: int in range(L.FLOORS.size()):
		if y >= float(L.FLOOR_HEIGHTS[i]) - 0.35:
			f = L.FLOORS[i]
	return f


func wall_list() -> Array[Array]:
	return _walls


## Dominant bullet surface of a class box (area weighted over its drawn faces).
func box_surface(mn: Vector3, mx: Vector3, cls: String) -> StringName:
	var size: Vector3 = mx - mn
	var mid: Vector3 = (mn + mx) * 0.5
	var normals: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK]
	var areas: Array[float] = [size.y * size.z, size.y * size.z, size.x * size.z, size.x * size.z, size.x * size.y, size.x * size.y]
	var votes: Dictionary = {}
	for f: int in range(6):
		var s: StringName = surface_of(face_key(cls, f, normals[f], mid + normals[f] * size * 0.5))
		if s != &"":
			votes[s] = int(votes.get(s, 0)) + maxi(1, int(areas[f] * 10000.0))
	var best: StringName = &"concrete"
	var bw: int = 0
	var keys: Array = votes.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for k: Variant in keys:
		if int(votes[k]) > bw:
			bw = int(votes[k])
			best = StringName(k)
	return best


# --- Local meshes (map-built props, rails, steps) ------------------------------------------------

## Local-space box mesh with metre-scaled UVs: parts [[size, centre, key], ...].
func local_box_mesh(parts: Array) -> ArrayMesh:
	var a: RefCounted = M.new()
	for k: String in _mats:
		a.register_material(k, _mats[k])
	for p: Array in parts:
		var size: Vector3 = p[0]
		var centre: Vector3 = p[1]
		var key: String = String(p[2])
		var lo: Vector3 = centre - size * 0.5
		a.box("p", lo, lo + size, key)
	return _single(a)


## Local mesh from 8 hexahedron corners (0-3 one face, 4-7 the opposite face, same order), world-planar UVs.
func local_hex_mesh(c: Array[Vector3], key: String) -> ArrayMesh:
	var a: RefCounted = M.new()
	a.register_material(key, _mats[key])
	var centre: Vector3 = Vector3.ZERO
	for p: Vector3 in c:
		centre += p / 8.0
	for q: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [1, 2, 6, 5], [0, 3, 7, 4]]:
		var p0: Vector3 = c[int(q[0])]
		var p1: Vector3 = c[int(q[1])]
		var p2: Vector3 = c[int(q[2])]
		var p3: Vector3 = c[int(q[3])]
		var nrm: Vector3 = (p1 - p0).cross(p2 - p0)
		if nrm.length() < 1e-8:
			nrm = (p2 - p0).cross(p3 - p0)
		nrm = nrm.normalized()
		var fc: Vector3 = (p0 + p1 + p2 + p3) * 0.25
		if nrm.dot(fc - centre) < 0.0:
			nrm = -nrm
		a.quad("p", key, p0, p1, p2, p3, nrm)
	return _single(a)


## Round bar along local +Y from 0 to `length` (8 sides).
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


# --- Room trims ----------------------------------------------------------------------------------

## Baseboards in every finished room, a gilt picture rail and a plaster cornice in the public rooms, the galleries'
## laylight mullion grid.
func room_trims() -> void:
	_room_floors()
	for b: Array in _room_cache:
		var rid: String = String(b[1])
		if not FINISH.has(rid) or rid in NO_BASEBOARD:
			continue
		var fy: float = float(b[2])
		var rect: Array = [float(b[4]), float(b[5]), float(b[6]), float(b[7])]
		if rid == "GH" and fy > 1.0:
			continue
		_trim_rect(String(b[0]), rid, rect, fy, fy, fy + BASEBOARD_H, BASEBOARD_D, "trim_baseboard")
		if rid in PICTURE_RAIL_ROOMS and not (rid in ["BW", "BE", "SL"]):
			_trim_rect(String(b[0]), rid, rect, fy, fy + PICTURE_RAIL_Y, fy + PICTURE_RAIL_Y + 0.05, 0.03, "gilt_brass")
		if rid in CORNICE_ROOMS:
			var cy: float = _cornice_top(String(b[0]), rid, fy)
			_trim_rect(String(b[0]), rid, rect, fy, cy - CORNICE_H, cy, CORNICE_D, "trim_crown_cornice")
	_laylights()


## Floor finish quads per room rect at its FFL, inside its walls' faces (the slab tops are not drawn: one slab spans
## many rooms), and a threshold under every floor-level opening in an interior wall (the facade ones have sills). The
## stair core above the basement only has its floor landing (the flights rise through the slab hole); the rooms on the
## roof slab (head house, lift motor room) stand on the roof finish.
func _room_floors() -> void:
	for r: Array in L.ROOMS:
		var rid: String = String(r[1])
		var f: String = String(r[0])
		if not FINISH.has(rid) or f == "R":
			continue
		var y: float = float(L.FFL[f])
		var outer: Rect2 = Rect2(float(r[3]), float(r[4]), float(r[5]) - float(r[3]), float(r[6]) - float(r[4]))
		if rid == "SS" and f != "B":
			outer = Rect2(outer.position.x, 6.35, outer.size.x, outer.end.y - 6.35)
		var holes: Array[Rect2] = []
		for w: Array in _walls:
			if String(w[0]) != f or float(w[5]) > y + 0.5 or float(w[6]) < y + 0.5:
				continue
			var t: float = float(w[8]) * 0.5
			var wr: Rect2 = Rect2(float(w[3]), float(w[2]) - t, float(w[4]) - float(w[3]), t * 2.0) if String(w[1]) == "x" \
				else Rect2(float(w[2]) - t, float(w[3]), t * 2.0, float(w[4]) - float(w[3]))
			var cut: Rect2 = wr.intersection(outer)
			if cut.size.x > 1e-4 and cut.size.y > 1e-4:
				holes.append(cut)
		for pr: Rect2 in rects_minus(outer, holes):
			acc.quad(room_group(f, rid), String((FINISH[rid] as Array)[0]), Vector3(pr.position.x, y, pr.position.y),
				Vector3(pr.end.x, y, pr.position.y), Vector3(pr.end.x, y, pr.end.y), Vector3(pr.position.x, y, pr.end.y), Vector3.UP)
	for o: Array in L.OPENINGS:
		var f2: String = String(o[0])
		if not (String(o[1]) in ["D", "A", "S", "V"]) or absf(float(o[6]) - float(L.FFL[f2])) > 0.001 or f2 == "R":
			continue
		var axis: String = String(o[2])
		var fixed: float = float(o[3])
		var ft: Array = L.FOOT[f2]
		if (axis == "x" and (absf(fixed - float(ft[1])) < 0.001 or absf(fixed - float(ft[3])) < 0.001)) \
				or (axis == "z" and (absf(fixed - float(ft[0])) < 0.001 or absf(fixed - float(ft[2])) < 0.001)):
			continue
		var y2: float = float(o[6])
		var t: float = wall_thickness(f2, axis, fixed, float(o[7]) + 0.2, float(o[4]) - 0.5, float(o[5]) + 0.5) * 0.5
		if t <= 0.0:
			t = wall_thickness(f2, axis, fixed, y2 + 0.05, float(o[4]) - 1.0, float(o[5]) + 1.0) * 0.5
		if t <= 0.0:
			continue
		var a0: float = float(o[4]) - THRESHOLD_EXTRA
		var a1: float = float(o[5]) + THRESHOLD_EXTRA
		var side: Vector3 = Vector3(0.0, 0.0, 1.0) if axis == "x" else Vector3(1.0, 0.0, 0.0)
		var mid: Vector3 = Vector3((a0 + a1) * 0.5, y2, fixed) if axis == "x" else Vector3(fixed, y2, (a0 + a1) * 0.5)
		var rid2: String = room_at(mid + side * 0.6 + Vector3.UP * 0.3)
		if not FINISH.has(rid2):
			rid2 = room_at(mid - side * 0.6 + Vector3.UP * 0.3)
		if not FINISH.has(rid2):
			continue
		var key: String = String((FINISH[rid2] as Array)[0])
		var lo: Vector3 = Vector3(a0, y2, fixed - t) if axis == "x" else Vector3(fixed - t, y2, a0)
		var hi: Vector3 = Vector3(a1, y2, fixed + t) if axis == "x" else Vector3(fixed + t, y2, a1)
		acc.quad(room_group(f2, rid2), key, Vector3(lo.x, y2, lo.z), Vector3(hi.x, y2, lo.z), Vector3(hi.x, y2, hi.z),
			Vector3(lo.x, y2, hi.z), Vector3.UP)


## The top of a room's walls under its ceiling (for the cornice).
static func _cornice_top(f: String, rid: String, fy: float) -> float:
	for r: Array in L.ROOMS:
		if String(r[0]) == f and String(r[1]) == rid:
			return fy + float(r[7])
	return fy + 3.0


## Trim strip along every wall face of a room rect where the wall is solid over [ya, yb].
func _trim_rect(f: String, rid: String, r: Array, floor_y: float, ya: float, yb: float, depth: float, key: String) -> void:
	var x0: float = float(r[0])
	var z0: float = float(r[1])
	var x1: float = float(r[2])
	var z1: float = float(r[3])
	var edges: Array = [["x", z0, x0, x1, 1.0], ["x", z1, x0, x1, -1.0], ["z", x0, z0, z1, 1.0], ["z", x1, z0, z1, -1.0]]
	for e: Array in edges:
		var axis: String = String(e[0])
		var fixed: float = float(e[1])
		var inward: float = float(e[4])
		var t: float = wall_thickness(f, axis, fixed, ya + 0.01, float(e[2]), float(e[3]))
		if t <= 0.0:
			continue
		var face: float = fixed + inward * t * 0.5
		var a0: float = float(e[2]) + _end_inset(f, axis, float(e[2]), ya + 0.01)
		var a1: float = float(e[3]) - _end_inset(f, axis, float(e[3]), ya + 0.01)
		for run: Vector2 in wall_runs(f, axis, fixed, a0, a1, ya, yb):
			var lo: Vector3
			var hi: Vector3
			if axis == "x":
				lo = Vector3(run.x, ya, minf(face, face + inward * depth))
				hi = Vector3(run.y, yb, maxf(face, face + inward * depth))
			else:
				lo = Vector3(minf(face, face + inward * depth), ya, run.x)
				hi = Vector3(maxf(face, face + inward * depth), yb, run.y)
			var back: int = (4 if inward > 0.0 else 5) if axis == "x" else (0 if inward > 0.0 else 1)
			var end0: int = (0 if axis == "x" else 4) if run.x <= a0 + 0.001 and a0 > float(e[2]) + 0.001 else -1
			var end1: int = (1 if axis == "x" else 5) if run.y >= a1 - 0.001 and a1 < float(e[3]) - 0.001 else -1
			var low: bool = ya <= floor_y + 0.001
			acc.box(room_group(f, rid) + ("Trim" if rid in WALL_TILED_ROOMS else ""), lo, hi, func(fc: int, _n: Vector3, _c: Vector3) -> String:
				if fc == back or fc == end0 or fc == end1 or (fc == 2 and low):
					return ""
				# trim-sheet strips map V over a face's height: their flat top / underside take plain paint
				return "plaster_painted" if (fc == 2 or fc == 3) and key.begins_with("trim_") else key)


## Thickness of the wall on this line (floor f) covering height y (0 = none).
func wall_thickness(f: String, axis: String, fixed: float, y: float, a0: float = -1.0e9, a1: float = 1.0e9) -> float:
	for w: Array in _walls:
		if String(w[1]) == axis and absf(float(w[2]) - fixed) < 0.01 and y >= float(w[5]) - 0.01 and y < float(w[6]) \
				and minf(a1, float(w[4])) - maxf(a0, float(w[3])) > 0.05 and (String(w[0]) == f or f == ""):
			return float(w[8])
	return 0.0


## The walls on this line (floor f) over [a0, a1] covering height y: [[from, to, thickness]] (clipped to [a0, a1]).
func wall_segments(f: String, axis: String, fixed: float, y: float, a0: float, a1: float) -> Array:
	var out: Array = []
	for w: Array in _walls:
		if String(w[1]) == axis and absf(float(w[2]) - fixed) < 0.01 and y >= float(w[5]) - 0.01 and y < float(w[6]) \
				and minf(a1, float(w[4])) - maxf(a0, float(w[3])) > 0.05 and String(w[0]) == f:
			out.append([maxf(a0, float(w[3])), minf(a1, float(w[4])), float(w[8])])
	return out


func _end_inset(f: String, axis: String, at: float, y: float) -> float:
	var other: String = "z" if axis == "x" else "x"
	var t: float = wall_thickness(f, other, at, y)
	return t * 0.5 if t > 0.0 else 0.0


## Intervals of [a0, a1] along a wall line where some wall is solid over the whole band [ya, yb].
func wall_runs(_f: String, axis: String, fixed: float, a0: float, a1: float, ya: float, yb: float) -> Array[Vector2]:
	var solid: Array[Vector2] = []
	for w: Array in _walls:
		if String(w[1]) != axis or absf(float(w[2]) - fixed) > 0.01:
			continue
		if float(w[5]) > ya + 0.001 or float(w[6]) < yb - 0.001:
			continue
		var segs: Array[Vector2] = [Vector2(maxf(float(w[3]), a0), minf(float(w[4]), a1))]
		for o: Array in w[7]:
			if float(o[2]) < yb - 0.001 and float(o[3]) > ya + 0.001:
				var m: float = DOOR_CASING if _at_floor_level(float(o[2])) else WINDOW_CASING
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


## The top-lit galleries' laylights: a gilt mullion grid 0.12 m under the glowing laylight (the roof underside at
## FFL + 6.0), 3 m bays, and a deep plaster cove band round the room under it.
func _laylights() -> void:
	for r: Array in L.ROOMS:
		var rid: String = String(r[1])
		if not (rid in ["UG1", "UG2", "UG3"]):
			continue
		var y1: float = float(L.U_TOP[rid]) - L.SLAB_T
		var x0: float = float(r[3]) + L.INT_T
		var z0: float = float(r[4]) + L.INT_T
		var x1: float = float(r[5]) - L.INT_T
		var z1: float = float(r[6]) - L.INT_T
		var nx: int = maxi(2, roundi((x1 - x0) / 3.0))
		var nz: int = maxi(2, roundi((z1 - z0) / 3.0))
		for i: int in range(1, nx):
			var x: float = lerpf(x0, x1, float(i) / float(nx))
			acc.box(room_group("U", rid), Vector3(x - 0.045, y1 - 0.12, z0), Vector3(x + 0.045, y1 - 0.006, z1),
				func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 3 or f == 4 or f == 5 else "gilt_brass")
		for j: int in range(1, nz):
			var z: float = lerpf(z0, z1, float(j) / float(nz))
			for i2: int in range(nx):
				var xa: float = lerpf(x0, x1, float(i2) / float(nx)) + (0.045 if i2 > 0 else 0.0)
				var xb: float = lerpf(x0, x1, float(i2 + 1) / float(nx)) - (0.045 if i2 < nx - 1 else 0.0)
				acc.box(room_group("U", rid), Vector3(xa, y1 - 0.1, z - 0.04), Vector3(xb, y1 - 0.006, z + 0.04),
					func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 3 or f == 0 or f == 1 else "gilt_brass")


## The Great Hall's coffered laylight: a beam grid 0.4 m deep under the 9.8 m ceiling (2 m bays), open at the oculus.
func hall_coffers(oculus: Array) -> void:
	acc.tile_groups[COFFERS] = COFFER_TILE
	var y1: float = 9.8
	var y0: float = y1 - 0.4
	var x0: float = 12.1
	var x1: float = 31.9
	var z0: float = 8.1
	var z1: float = 25.9
	var x: float = 14.0
	var ox0: float = float(oculus[0])
	var oz0: float = float(oculus[1])
	var ox1: float = float(oculus[2])
	var oz1: float = float(oculus[3])
	while x < x1 - 0.5:
		var spans: Array = [[z0, z1]]
		if x + 0.15 > ox0 and x - 0.15 < ox1:
			spans = [[z0, oz0 - 0.05], [oz1 + 0.05, z1]]   # ends inside the oculus lining (no coplanar end faces)
		for sp: Array in spans:
			acc.box(COFFERS, Vector3(x - 0.15, y0, float(sp[0])), Vector3(x + 0.15, y1 - 0.002, float(sp[1])),
				_coffer_face.bind(oculus))
		x += 2.0
	var z: float = 10.0
	while z < z1 - 0.5:
		var xs: Array = [x0]
		var xx: float = 14.0
		while xx < x1 - 0.5:
			xs.append(xx)
			xx += 2.0
		xs.append(x1)
		for i: int in range(xs.size() - 1):
			var a: float = float(xs[i]) + (0.15 if i > 0 else 0.0)
			var b: float = float(xs[i + 1]) - (0.15 if i < xs.size() - 2 else 0.0)
			if z + 0.12 > oz0 and z - 0.12 < oz1 and b > ox0 and a < ox1:
				continue
			acc.box(COFFERS, Vector3(a, y0 + 0.05, z - 0.12), Vector3(b, y1 - 0.002, z + 0.12), _coffer_face.bind(oculus))
		z += 2.0


func _coffer_face(f: int, _n: Vector3, c: Vector3, oculus: Array) -> String:
	if f == 3:
		return ""
	if c.x > float(oculus[0]) - 0.2 and c.x < float(oculus[2]) + 0.2 and c.z > float(oculus[1]) - 0.2 and c.z < float(oculus[3]) + 0.2:
		return "gilt_brass"
	return "bone_plaster_painted" if f != 2 else "gilt_brass"


# --- Probes and occluders -------------------------------------------------------------------------

## One box-projected ReflectionProbe per interior room (UPDATE_ONCE, no ambient).
func reflection_probes(parent: Node3D, owner_root: Node) -> void:
	var done: Dictionary = {}
	for b: Array in _room_cache:
		var key: String = String(b[0]) + String(b[1])
		if done.has(key) or String(b[1]) in ["LM"]:
			continue
		done[key] = true
		var lo: Vector3 = Vector3(float(b[4]), float(b[2]), float(b[5]))
		var hi: Vector3 = Vector3(float(b[6]), float(b[3]), float(b[7]))
		var probe: ReflectionProbe = ReflectionProbe.new()
		probe.name = "Probe%s%s" % [String(b[0]), String(b[1])]
		probe.position = (lo + hi) * 0.5
		probe.size = hi - lo + Vector3(0.2, 0.1, 0.2)
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.max_distance = maxf(probe.size.x, probe.size.z) * 1.5
		parent.add_child(probe)
		probe.owner = owner_root
