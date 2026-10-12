## Shadow Ledger G2 art pass (C2, ENV C): material library assignment per surface class and room
## finish, the graphite curtain wall, floors / landings, neighbour towers with lit window grids, the
## wet roof and terrace, reflection probes, occluders and ambience. Used by the generator
## (sl_builder_base.gd). Same approach as Night Deposit (nd_art.gd).
## Design: docs/design/heists/shadow_ledger.md §Audio/lighting (palette: graphite #2E3136 dominant,
## glass teal #5D8C8F, cold-white LED accent; walnut and leather); style: docs/art/style_guide.md;
## UV convention: tools/texgen/README.md (1 UV unit = 2 m, world-anchored). Shares the Glasshouse
## mesh accumulator.
extends RefCounted

const M: GDScript = preload("res://world/heists/glasshouse/greybox/gh_mesh.gd")
const L: GDScript = preload("res://world/heists/shadow_ledger/greybox/shadow_ledger_layout.gd")
const MAT_DIR: String = "res://world/materials/"
const TRIM_TABLE: String = "res://assets/textures/trim_interior/trim_table.json"
const LIBRARY: Array[String] = [
	"plaster_painted", "drywall_painted", "concrete", "terrazzo", "marble_cream", "carpet_commercial",
	"ceiling_tile", "wood_veneer_walnut", "brushed_steel", "chrome", "brass", "glass_clear",
	"rubber_black", "plastic_matte", "asphalt", "tile_ceramic_white", "vinyl_floor",
	"metal_painted", "paint_white", "leather_dark", "fabric_upholstery",
]
## Tinted library surfaces (keep the library textures): key -> [library id, tint, roughness or -1].
const TINTS: Dictionary = {
	"carpet_graphite": ["carpet_commercial", Color(0.5, 0.52, 0.56), -1.0],
	"stone_graphite": ["marble_cream", Color(0.42, 0.44, 0.47), 0.3],
	"paint_graphite": ["drywall_painted", Color(0.5, 0.52, 0.55), -1.0],
	"paint_warm": ["drywall_painted", Color(0.95, 0.93, 0.88), -1.0],
	"metal_graphite": ["metal_painted", Color(0.42, 0.44, 0.48), -1.0],
	"metal_dark": ["metal_painted", Color(0.3, 0.31, 0.33), -1.0],
	"membrane": ["concrete", Color(0.5, 0.51, 0.53), 0.35],
	"paving_wet": ["concrete", Color(0.62, 0.62, 0.63), 0.22],
	"helipad": ["concrete", Color(0.36, 0.38, 0.38), 0.4],
	"tower": ["metal_painted", Color(0.34, 0.37, 0.42), -1.0],
	"tower_dark": ["metal_painted", Color(0.2, 0.21, 0.24), -1.0],
	"stone_dark": ["marble_cream", Color(0.3, 0.3, 0.31), -1.0],
	"fabric_charcoal": ["fabric_upholstery", Color(0.62, 0.64, 0.68), -1.0],
	"street": ["asphalt", Color(0.6, 0.6, 0.62), 0.3],
}
## Untextured emissive / glass / water surfaces (meta untextured_ok): key -> [albedo, emission,
## energy, roughness, alpha].
const EMISSIVE: Dictionary = {
	"emit_warm": [Color(1.0, 0.86, 0.66), Color(1.0, 0.82, 0.58), 3.0, 0.6, 1.0],
	"emit_cool": [Color(0.9, 0.94, 1.0), Color(0.88, 0.93, 1.0), 2.5, 0.6, 1.0],
	"led_white": [Color(0.85, 0.92, 1.0), Color(0.85, 0.92, 1.0), 3.0, 0.6, 1.0],
	"heli_green": [Color(0.2, 1.0, 0.35), Color(0.2, 1.0, 0.35), 3.0, 0.6, 1.0],
	"beacon_red": [Color(1.0, 0.1, 0.05), Color(1.0, 0.1, 0.05), 3.0, 0.6, 1.0],
	"city_lights": [Color(1.0, 0.75, 0.45), Color(1.0, 0.75, 0.45), 0.5, 0.6, 1.0],
	"logo_teal": [Color(0.36, 0.75, 0.78), Color(0.36, 0.75, 0.78), 2.2, 0.4, 1.0],
	"window_lit": [Color(0.95, 0.85, 0.65), Color(0.95, 0.8, 0.55), 1.1, 0.3, 1.0],
	"window_cool": [Color(0.75, 0.85, 0.95), Color(0.7, 0.82, 0.95), 0.9, 0.3, 1.0],
	"window_dark": [Color(0.07, 0.08, 0.1), Color(0.0, 0.0, 0.0), 0.0, 0.15, 1.0],
	"river": [Color(0.03, 0.05, 0.07), Color(0.0, 0.0, 0.0), 0.0, 0.08, 1.0],
	"glass_teal": [Color(0.36, 0.55, 0.56), Color(0.0, 0.0, 0.0), 0.0, 0.05, 0.32],
	"cage_mesh": [Color(0.62, 0.64, 0.68), Color(0.0, 0.0, 0.0), 0.0, 0.5, 0.35],
	"laser_red": [Color(1.0, 0.12, 0.08), Color(1.0, 0.08, 0.05), 4.0, 0.6, 1.0],
}
## Room finishes: room id -> [floor, walls, ceiling].
const FINISH: Dictionary = {
	"S1": ["vinyl_floor", "drywall_painted", "ceiling_tile"], "S2": ["concrete", "drywall_painted", "ceiling_tile"],
	"S3": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"SA": ["concrete", "paint_warm", "plaster_painted"], "SB": ["concrete", "paint_warm", "plaster_painted"],
	"SL": ["brushed_steel", "brushed_steel", "brushed_steel"], "LF1": ["concrete", "concrete", "concrete"],
	"LF2": ["concrete", "concrete", "concrete"],
	"J41": ["vinyl_floor", "drywall_painted", "ceiling_tile"], "J42": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"WCW41": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],
	"WCM41": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],
	"WCW42": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],
	"WCM42": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],
	"K1": ["carpet_graphite", "wood_veneer_walnut", "plaster_painted"],
	"K2": ["carpet_graphite", "paint_graphite", "ceiling_tile"],
	"K3": ["stone_graphite", "stone_graphite", "plaster_painted"],
	"K4": ["carpet_graphite", "drywall_painted", "ceiling_tile"],
	"K5": ["carpet_graphite", "wood_veneer_walnut", "plaster_painted"],
	"K6": ["carpet_graphite", "drywall_painted", "ceiling_tile"], "K7": ["carpet_graphite", "drywall_painted", "ceiling_tile"],
	"K8": ["carpet_graphite", "drywall_painted", "ceiling_tile"], "K9": ["carpet_graphite", "drywall_painted", "ceiling_tile"],
	"K10": ["vinyl_floor", "drywall_painted", "ceiling_tile"], "K11": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"K12": ["carpet_graphite", "drywall_painted", "ceiling_tile"], "K13": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"K14": ["concrete", "drywall_painted", "ceiling_tile"], "K15": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"K16": ["carpet_graphite", "drywall_painted", "ceiling_tile"], "K17": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"K18": ["vinyl_floor", "drywall_painted", "ceiling_tile"], "K19": ["carpet_graphite", "wood_veneer_walnut", "plaster_painted"],
	"K20": ["carpet_graphite", "drywall_painted", "ceiling_tile"], "K21": ["carpet_graphite", "drywall_painted", "ceiling_tile"],
	"K22": ["carpet_graphite", "drywall_painted", "ceiling_tile"], "K23": ["carpet_graphite", "drywall_painted", "ceiling_tile"],
	"K24": ["carpet_graphite", "paint_graphite", "ceiling_tile"],
	"M1": ["stone_graphite", "paint_graphite", "plaster_painted"], "M2": ["stone_graphite", "stone_graphite", "plaster_painted"],
	"M3": ["wood_veneer_walnut", "paint_graphite", "plaster_painted"],
	"M4": ["carpet_graphite", "wood_veneer_walnut", "plaster_painted"],
	"M5": ["carpet_graphite", "paint_warm", "plaster_painted"], "M6": ["tile_ceramic_white", "marble_cream", "plaster_painted"],
	"M7": ["carpet_graphite", "wood_veneer_walnut", "plaster_painted"],
	"M8": ["wood_veneer_walnut", "paint_graphite", "plaster_painted"],
	"M9": ["stone_graphite", "drywall_painted", "plaster_painted"], "M10": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"M11": ["vinyl_floor", "drywall_painted", "ceiling_tile"], "M12": ["concrete", "drywall_painted", "ceiling_tile"],
	"M13": ["stone_graphite", "wood_veneer_walnut", "plaster_painted"],
	"M14": ["carpet_graphite", "wood_veneer_walnut", "plaster_painted"],
	"M15": ["stone_graphite", "drywall_painted", "plaster_painted"],
	"R1": ["concrete", "concrete", "concrete"], "R2": ["concrete", "paint_warm", "concrete"], "R3": ["concrete", "concrete", "concrete"],
	"X1": ["paving_wet", "metal_graphite", ""], "X2": ["membrane", "metal_graphite", ""],
}
## Greybox surface class -> material key (all faces) for the plain classes.
const CLASS_MAT: Dictionary = {
	"trim": "metal_graphite", "frame": "metal_dark", "door": "brushed_steel", "glass": "glass_teal",
	"teal_glass": "glass_teal", "cage_mesh": "cage_mesh", "fence": "metal_dark", "steel": "brushed_steel",
	"prop": "fabric_charcoal", "counter": "wood_veneer_walnut", "planter": "stone_dark", "concrete": "concrete",
	"graphite": "metal_graphite", "roof_membrane": "membrane", "tower": "tower", "tower_dark": "tower_dark",
	"street": "street", "river": "river", "helipad": "helipad", "fixture": "emit_warm", "led_white": "led_white",
	"heli_green": "heli_green", "beacon_red": "beacon_red", "city_lights": "city_lights", "logo_teal": "logo_teal",
	"monitor": "emit_cool", "rack_led": "emit_cool", "handrail": "brushed_steel",
}
## Per class: [bottom (-Y), top (+Y), sides] ("" = not rendered; "@room" = finish of the room the
## face looks into; "@ext" = curtain-wall panel outside, room finish inside).
const CLASS_FACES: Dictionary = {
	"wall_ext": ["@ext", "@ext", "@ext"], "wall": ["@room", "@room", "@room"],
	"floor": ["plaster_painted", "", "plaster_painted"], "roof": ["plaster_painted", "membrane", "metal_graphite"],
	"stair": ["plaster_painted", "terrazzo", "terrazzo"], "ceiling": ["@ceil", "", "plaster_painted"], "none": ["", "", ""],
}
const BASEBOARD_H: float = 0.1
const BASEBOARD_D: float = 0.015
## Heights where a wall's top / bottom face is buried (slab undersides, floor levels, parapet top).
const BURIED_Y: Array[float] = [-0.6, 0.0, 3.3, 3.6, 7.2, 8.0, 11.0, 11.6, 12.7, 15.1, 15.4]

var acc: RefCounted = M.new()
var _mats: Dictionary = {}
## Wall lines: [axis, fixed, from, to, y0, y1, thickness, exterior].
var _walls: Array[Array] = []
## Room boxes for finish lookup: [id, x0, y0, z0, x1, y1, z1].
var _rooms: Array[Array] = []


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
		var tm: BaseMaterial3D = (_mats[String(row[0])] as BaseMaterial3D).duplicate() as BaseMaterial3D
		tm.resource_name = "sl_" + String(k)
		tm.albedo_color = row[1]
		if float(row[2]) >= 0.0:
			tm.roughness = float(row[2])
		_mats[String(k)] = tm
		acc.register_material(String(k), tm)
	var em_keys: Array = EMISSIVE.keys()
	em_keys.sort()
	for k2: Variant in em_keys:
		var row2: Array = EMISSIVE[k2]
		var em: StandardMaterial3D = StandardMaterial3D.new()
		em.resource_name = "sl_" + String(k2)
		var c: Color = row2[0]
		c.a = float(row2[4])
		em.albedo_color = c
		em.roughness = float(row2[3])
		if float(row2[2]) > 0.0:
			em.emission_enabled = true
			em.emission = row2[1]
			em.emission_energy_multiplier = float(row2[2])
		if float(row2[4]) < 1.0:
			em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			em.cull_mode = BaseMaterial3D.CULL_DISABLED
			em.metallic = 0.5
			em.metallic_specular = 0.9
		if String(k2) == "river":
			em.metallic_specular = 0.9
		em.set_meta(&"untextured_ok", true)
		_mats[String(k2)] = em
		acc.register_material(String(k2), em)
	_collect_rooms()


func mat(key: String) -> Material:
	return _mats.get(key)


func _collect_rooms() -> void:
	var tall: Dictionary = {}
	for t: Array in L.TALL_ROOMS:
		var q: Array = t[4]
		_rooms.append([String(t[0]), float(q[0]), float(t[2]), float(q[1]), float(q[2]), float(t[3]), float(q[3])])
		tall[String(t[0])] = true
	for lv: String in ["L40", "L41", "L42", "RF"]:
		var info: Array = L.LEVELS[lv]
		var src: Array = (L.PLAN_ROOMS[lv] as Array).duplicate()
		if lv == "L41" or lv == "L42":
			src.append_array(L.CORE)
		for r: Array in src:
			var uid: String = String(r[0])
			if uid in ["J", "WCW", "WCM"]:
				uid += lv.substr(1)
			if tall.has(uid):
				continue
			_rooms.append([uid, float(r[1]), float(info[0]), float(r[2]), float(r[3]), float(info[1]), float(r[4])])
	for x: Array in L.EXTERIOR_ROOMS:
		for b: Array in x[4]:
			_rooms.append([String(x[0]), float(b[0]), float(b[1]), float(b[2]), float(b[3]), float(b[4]), float(b[5])])


## Registers a wall line (the builder's wall() / facade boxes) for face burial and trim.
func add_wall(axis: String, fixed: float, a0: float, a1: float, y0: float, y1: float, t: float, ext: bool) -> void:
	_walls.append([axis, fixed, a0, a1, y0, y1, t, ext])


## Room id containing p, "" outside every room.
func room_at(p: Vector3) -> String:
	for r: Array in _rooms:
		if p.x > float(r[1]) and p.x < float(r[4]) and p.z > float(r[3]) and p.z < float(r[6]) \
				and p.y > float(r[2]) - 0.05 and p.y < float(r[5]) + 0.6:
			return String(r[0])
	return ""


static func inside_building(p: Vector3) -> bool:
	if p.x <= 0.0 or p.x >= 36.0 or p.z <= 0.0 or p.y < -0.6:
		return false
	if p.y < L.TOP41 + 0.8:
		return p.z < 24.0
	if p.y < L.FRF:
		return p.z < 18.0
	return p.x > 12.0 and p.x < 24.0 and p.z > 7.5 and p.z < 16.5 and p.y < L.TOPRF


func _room_key(c: Vector3, n: Vector3, idx: int) -> String:
	var r: String = room_at(c + n * 0.3)
	if FINISH.has(r) and String((FINISH[r] as Array)[idx]) != "":
		return String((FINISH[r] as Array)[idx])
	if inside_building(c + n * 0.3):
		return "plaster_painted" if idx != 0 else "concrete"
	return "metal_graphite"


## Material key for face f (0 -X, 1 +X, 2 -Y, 3 +Y, 4 -Z, 5 +Z) of a box of greybox class `cls`.
func face_key(cls: String, f: int, n: Vector3, c: Vector3, mn: Vector3, mx: Vector3) -> String:
	if cls == "wall" or cls == "wall_ext":
		if f == 2 or f == 3:
			for y: float in BURIED_Y:
				if absf(c.y - y) < 0.002:
					return ""
		if f != 2 and f != 3 and _on_ext_centreline(n, c):
			return ""
	if cls == "glass" or cls == "teal_glass" or cls == "cage_mesh":
		# panes: only the two large faces (the edges sit in the wall reveal / frame)
		var s: Vector3 = mx - mn
		var thin: int = 0 if s.x <= s.y and s.x <= s.z else (1 if s.y <= s.z else 2)
		if (f >> 1) != thin:
			return ""
	var rule: Array = CLASS_FACES.get(cls, [])
	var key: String
	if rule.is_empty():
		key = String(CLASS_MAT.get(cls, ""))
		if key == "":
			push_error("sl_art: unknown surface class `%s`" % cls)
			key = "concrete"
		return key
	key = String(rule[0] if f == 2 else (rule[1] if f == 3 else rule[2]))
	if key == "@room":
		key = _room_key(c, n, 1)
	elif key == "@ceil":
		key = _room_key(c, n, 2)
	elif key == "@ext":
		key = _room_key(c, n, 1) if inside_building(c + n * 0.25) or room_at(c + n * 0.3) != "" else "metal_graphite"
		if f == 3 and key == "metal_graphite":
			key = "metal_dark"
	return key


## True when the side face of box [mn, mx] with normal n overlaps the face plane of a wall line
## (against false: slab edges lying on a wall's face; against true: a wall end butting into a wall).
func _on_wall_face(n: Vector3, mn: Vector3, mx: Vector3, against: bool = false) -> bool:
	var sg: float = -1.0 if against else 1.0
	for w: Array in _walls:
		var t: float = float(w[6])
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


func _on_ext_centreline(n: Vector3, c: Vector3) -> bool:
	for w: Array in _walls:
		if not bool(w[7]):
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
	var slab: bool = cls == "floor" or cls == "roof" or cls == "ceiling"
	var is_wall: bool = cls == "wall" or cls == "wall_ext"
	acc.box(group, mn, mx, func(f: int, n: Vector3, c: Vector3) -> String:
		if f in skip:
			return ""
		if f != 2 and f != 3 and ((slab and _on_wall_face(n, mn, mx)) or (is_wall and _on_wall_face(n, mn, mx, true))):
			return ""
		return face_key(cls, f, n, c, mn, mx))


## Local-space box mesh (props, rails) with metre-scaled UVs (same 2 m tile convention).
func local_box_mesh(parts: Array) -> ArrayMesh:
	var a: RefCounted = M.new()
	for k: String in _mats:
		a.register_material(k, _mats[k])
	for p: Array in parts:
		var size: Vector3 = p[0]
		var centre: Vector3 = p[1]
		var key: String = String(CLASS_MAT.get(String(p[2]), String(p[2])))
		var lo: Vector3 = centre - size * 0.5
		var on_floor: bool = absf(centre.y - size.y * 0.5) < 0.001
		a.box("p", lo, lo + size, func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 2 and on_floor else key)
	return _single(a)


## Sloped coping prism along a wall line (world space, accumulated): 45 deg each side, apex up.
func coping(axis: String, fixed: float, a0: float, a1: float, y: float, h: float, key: String) -> void:
	var p: Callable = func(along: float, off: float, up: float) -> Vector3:
		return Vector3(along, y + up, fixed + off) if axis == "x" else Vector3(fixed + off, y + up, along)
	var nl: Vector3 = (Vector3(0.0, 1.0, -1.0) if axis == "x" else Vector3(-1.0, 1.0, 0.0)).normalized()
	var nr: Vector3 = (Vector3(0.0, 1.0, 1.0) if axis == "x" else Vector3(1.0, 1.0, 0.0)).normalized()
	acc.quad("Shell", key, p.call(a0, -h, 0.0), p.call(a1, -h, 0.0), p.call(a1, 0.0, h), p.call(a0, 0.0, h), nl)
	acc.quad("Shell", key, p.call(a0, h, 0.0), p.call(a1, h, 0.0), p.call(a1, 0.0, h), p.call(a0, 0.0, h), nr)
	var e0: Vector3 = Vector3.LEFT if axis == "x" else Vector3.FORWARD
	acc.quad("Shell", key, p.call(a0, -h, 0.0), p.call(a0, h, 0.0), p.call(a0, 0.0, h), p.call(a0, 0.0, h), e0)
	acc.quad("Shell", key, p.call(a1, -h, 0.0), p.call(a1, h, 0.0), p.call(a1, 0.0, h), p.call(a1, 0.0, h), -e0)


func _single(a: RefCounted) -> ArrayMesh:
	var holder: Node3D = Node3D.new()
	var out: Array = a.flush(holder, holder)
	var mesh: ArrayMesh = (out[0] as MeshInstance3D).mesh as ArrayMesh
	holder.free()
	return mesh


# --- Room surfaces -----------------------------------------------------------------------------

## Floor finishes per room rectangle (2 mm above the slab, which draws no top face) and baseboards.
func room_surfaces(level_rooms: Callable) -> void:
	for lv: String in ["L40", "L41", "L42", "RF"]:
		var ffl: float = float(L.LEVELS[lv][0])
		for r: Array in level_rooms.call(lv):
			var uid: String = String(r[0])
			if not FINISH.has(uid) or uid in ["SA", "SB", "LF1", "LF2", "SL"]:
				continue
			var key: String = String((FINISH[uid] as Array)[0])
			for q: Array in L.ROOM_RECTS.get(uid, [[r[1], r[2], r[3], r[4]]]):
				_floor(key, float(q[0]), float(q[1]), float(q[2]), float(q[3]), ffl)
	# stair floor landings (every level), the lift car floor
	for cid: String in L.STAIR_CORES:
		var x0: float = float(L.STAIR_CORES[cid]["x0"])
		for y: Variant in L.STAIR_CORES[cid]["levels"]:
			_floor("concrete", x0 + L.STAIR_CLEAR.x, L.STAIR_Z_START, x0 + L.STAIR_CLEAR.y, L.STAIR_Z_S, float(y))
	_floor("brushed_steel", 21.15, 7.65, 23.85, 10.35, L.F40)
	# terrace and roof: wet paving / membrane over the slab tops (the slabs draw no top face)
	_floor("paving_wet", 0.2, 18.0, 35.8, 23.8, L.F42)
	for b: Array in [[0.2, 0.2, 35.8, 7.35], [0.2, 16.65, 35.8, 17.8], [0.2, 7.35, 11.85, 16.65], [24.15, 7.35, 35.8, 16.65]]:
		_floor("membrane", float(b[0]), float(b[1]), float(b[2]), float(b[3]), L.FRF)


func _floor(key: String, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var yy: float = y + 0.002
	acc.quad("Interior", key, Vector3(x0, yy, z0), Vector3(x1, yy, z0), Vector3(x1, yy, z1), Vector3(x0, yy, z1), Vector3.UP)


## Baseboards along every wall face of a room rectangle where the wall is solid.
func baseboards(level_rooms: Callable) -> void:
	for lv: String in ["L41", "L42"]:
		var ffl: float = float(L.LEVELS[lv][0])
		for r: Array in level_rooms.call(lv):
			var uid: String = String(r[0])
			if not FINISH.has(uid) or uid.begins_with("WC") or uid in ["SA", "SB", "LF1", "LF2", "SL", "M6"]:
				continue
			for q: Array in L.ROOM_RECTS.get(uid, [[r[1], r[2], r[3], r[4]]]):
				_trim_rect(q, ffl)


func _trim_rect(q: Array, ffl: float) -> void:
	var x0: float = float(q[0])
	var z0: float = float(q[1])
	var x1: float = float(q[2])
	var z1: float = float(q[3])
	var ya: float = ffl
	var yb: float = ffl + BASEBOARD_H
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
		for run: Vector2 in _wall_runs(axis, fixed, a0, a1, ya, yb):
			var lo: Vector3
			var hi: Vector3
			if axis == "x":
				lo = Vector3(run.x, ya, minf(face, face + inward * BASEBOARD_D))
				hi = Vector3(run.y, yb, maxf(face, face + inward * BASEBOARD_D))
			else:
				lo = Vector3(minf(face, face + inward * BASEBOARD_D), ya, run.x)
				hi = Vector3(maxf(face, face + inward * BASEBOARD_D), yb, run.y)
			var back: int = (4 if inward > 0.0 else 5) if axis == "x" else (0 if inward > 0.0 else 1)
			var end0: int = (0 if axis == "x" else 4) if run.x <= a0 + 0.001 and a0 > float(e[2]) + 0.001 else -1
			var end1: int = (1 if axis == "x" else 5) if run.y >= a1 - 0.001 and a1 < float(e[3]) - 0.001 else -1
			acc.box("Trim", lo, hi, func(f: int, _n: Vector3, _c: Vector3) -> String:
				return "" if f == back or f == end0 or f == end1 or f == 2 else "trim_baseboard")


func _wall_thickness(axis: String, fixed: float, y: float, a0: float = -1.0e9, a1: float = 1.0e9) -> float:
	for w: Array in _walls:
		if String(w[0]) == axis and absf(float(w[1]) - fixed) < 0.01 and y >= float(w[4]) - 0.01 and y < float(w[5]) \
				and minf(a1, float(w[3])) - maxf(a0, float(w[2])) > 0.05:
			return float(w[6])
	return 0.0


func _end_inset(axis: String, at: float, y: float) -> float:
	var other: String = "z" if axis == "x" else "x"
	var t: float = _wall_thickness(other, at, y)
	return t * 0.5 if t > 0.0 else 0.0


## Intervals of [a0, a1] where a registered wall segment (openings already removed) is solid over
## [ya, yb]; door casings (0.18 m) are kept clear.
func _wall_runs(axis: String, fixed: float, a0: float, a1: float, ya: float, yb: float) -> Array[Vector2]:
	var solid: Array[Vector2] = []
	for w: Array in _walls:
		if String(w[0]) != axis or absf(float(w[1]) - fixed) > 0.01:
			continue
		if float(w[4]) > ya + 0.001 or float(w[5]) < yb - 0.001:
			continue
		var s: Vector2 = Vector2(maxf(float(w[2]), a0), minf(float(w[3]), a1))
		if s.y - s.x > 0.05:
			solid.append(s)
	solid.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var merged: Array[Vector2] = []
	for s2: Vector2 in solid:
		if not merged.is_empty() and s2.x <= merged[merged.size() - 1].y + 0.001:
			merged[merged.size() - 1].y = maxf(merged[merged.size() - 1].y, s2.y)
		else:
			merged.append(s2)
	# keep clear of the door casings (prop frames reach ~0.17 m beyond the leaf)
	var out: Array[Vector2] = []
	for m: Vector2 in merged:
		var lo: float = m.x + (0.18 if m.x > a0 + 0.001 else 0.0)
		var hi: float = m.y - (0.18 if m.y < a1 - 0.001 else 0.0)
		if hi - lo > 0.05:
			out.append(Vector2(lo, hi))
	return out


# --- Neighbours: window grids --------------------------------------------------------------------

## Window grids on the play-space-facing faces of the near neighbour towers (Arden, Vantage) and the
## crown of Calder below; lit windows from a fixed-seed RNG (presentation only, never gameplay).
func neighbours() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x534C4732  # fixed: "SLG2"
	var faces: Array = [
		# [normal, fixed, axis, a0, a1, y0, y1]
		[Vector3.RIGHT, -20.2, "z", -30.0, 40.0, -40.0, 33.0],
		[Vector3.LEFT, 66.2, "z", -8.0, 32.0, -40.0, -1.0],
		[Vector3.FORWARD, -0.2, "x", -0.2, 36.2, -30.0, -1.0],
		[Vector3.BACK, 24.2, "x", -0.2, 36.2, -30.0, -1.0],
		[Vector3.LEFT, -0.2, "z", -0.2, 24.2, -30.0, -1.0],
		[Vector3.RIGHT, 36.2, "z", -0.2, 24.2, -30.0, -1.0],
	]
	for fc: Array in faces:
		var n: Vector3 = fc[0]
		var fx: float = float(fc[1])
		var axis: String = String(fc[2])
		var a0: float = float(fc[3])
		var a1: float = float(fc[4])
		var y: float = float(fc[6]) - 3.0
		while y > float(fc[5]):
			var a: float = a0 + 1.0
			while a + 1.8 < a1 - 0.5:
				var r: float = rng.randf()
				var key: String = "window_lit" if r < 0.14 else ("window_cool" if r < 0.2 else "window_dark")
				_window_panel(n, fx, axis, a, a + 1.8, y, y + 2.2, key)
				a += 2.4
			y -= 3.6


## Window glazing quad 3 cm proud of the facade (never coplanar with it).
func _window_panel(n: Vector3, fx: float, axis: String, a0: float, a1: float, y0: float, y1: float, key: String) -> void:
	var g: float = fx + (0.03 if n.x + n.z > 0.0 else -0.03)
	var pts: Array[Vector3]
	if axis == "z":
		pts = [Vector3(g, y0, a0), Vector3(g, y0, a1), Vector3(g, y1, a1), Vector3(g, y1, a0)]
	else:
		pts = [Vector3(a0, y0, g), Vector3(a1, y0, g), Vector3(a1, y1, g), Vector3(a0, y1, g)]
	acc.quad("Site", key, pts[0], pts[1], pts[2], pts[3], n)


# --- Probes, occluders, ambience -----------------------------------------------------------------

func reflection_probes(parent: Node3D, owner_root: Node) -> void:
	for id: String in ["K3", "M2", "M1", "M3", "M4", "K1", "K5", "M8", "M14", "K11", "K13", "K16", "M15"]:
		for r: Array in _rooms:
			if String(r[0]) != id:
				continue
			var lo: Vector3 = Vector3(float(r[1]), float(r[2]), float(r[3]))
			var hi: Vector3 = Vector3(float(r[4]), float(r[5]), float(r[6]))
			var probe: ReflectionProbe = ReflectionProbe.new()
			probe.name = "Probe" + id
			probe.position = (lo + hi) * 0.5
			probe.size = hi - lo + Vector3(0.2, 0.1, 0.2)
			probe.box_projection = true
			probe.interior = true
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
			probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
			parent.add_child(probe)
			probe.owner = owner_root
			break


## Box occluders for solid massing (neighbour towers, Calder below).
func occluders(parent: Node3D, owner_root: Node) -> void:
	for b: Array in L.SITE_BLOCKS:
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


## Ambience beds (positional CueEmitters) and the cue player. No tower-night / rain bed exists in
## the cue registry yet: the interior and street beds stand in (G2 report).
func audio(parent: Node3D, owner_root: Node) -> void:
	var player: Node = Node.new()
	player.set_script(load("res://world/audio/cue_player.gd"))
	player.name = "CuePlayer"
	parent.add_child(player)
	player.owner = owner_root
	var beds: Array = [
		["BedReception", Vector3(18.0, L.F41 + 2.0, 4.0), &"cue.amb_glasshouse_interior", -8.0],
		["BedOfficesWest", Vector3(5.0, L.F41 + 2.0, 14.0), &"cue.amb_glasshouse_interior", -10.0],
		["BedOfficesEast", Vector3(30.0, L.F41 + 2.0, 12.0), &"cue.amb_glasshouse_interior", -10.0],
		["BedPartners", Vector3(18.0, L.F42 + 2.0, 6.0), &"cue.amb_glasshouse_interior", -10.0],
		["BedTerraceRain", Vector3(18.0, L.F42 + 2.0, 21.0), &"cue.amb_street_dusk", -3.0],
		["BedRoofRain", Vector3(18.0, L.FRF + 2.0, 4.0), &"cue.amb_street_dusk", -2.0],
		["BedRoofRainE", Vector3(30.0, L.FRF + 2.0, 14.0), &"cue.amb_street_dusk", -4.0],
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
