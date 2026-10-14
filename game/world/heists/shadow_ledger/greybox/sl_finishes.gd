## Shadow Ledger surface pass (PO-13): greybox surface class + room purpose / face -> library material.
## Owner: ENV C. Used by sl_builder_base.gd (box / mesh_box / prop_box resolve their material here).
## Materials only: no mesh changes. Every finish is a duplicate of a texgen library material
## (game/world/materials/<lib>.tres, textures shared) set to world triplanar (the greybox boxes have
## per-face 0..1 UVs), scaled to the style guide's texel density, optionally tinted (albedo multiply).
## Palette (shadow_ledger.md §Audio/lighting, style guide §3): graphite #2E3136 dominant (honed stone
## wall panels, carpet, steel trims, BOH paint), glass teal #5D8C8F secondary (tinted balustrades), walnut
## and leather inside GSR saturation. Upscale law tower: terrazzo / honed stone front of house, carpet
## and walnut in the partner suites, tiled washrooms, painted drywall corridors, blockwork BOH,
## concrete plant and risers, anodised curtain wall, light single-ply roof, rain-dark terrace paving.
## Bullet surface ids follow from the finish key through surface_map.json (`sl_<key>`).
extends RefCounted

const L: GDScript = preload("res://world/heists/shadow_ledger/greybox/shadow_ledger_layout.gd")

## Finish key -> [library id, tint (albedo multiply) or null]. A tint with alpha < 1 makes the finish
## see-through (alpha blend, both faces). Keys without a tint that equal their library id are plain
## library surfaces.
const FINISHES: Dictionary = {
	"terrazzo": ["terrazzo", Color(0.8, 0.82, 0.86)],
	"stone_graphite": ["marble_cream", Color(0.42, 0.45, 0.5)],
	"marble_cream": ["marble_cream", null],
	"carpet_graphite": ["carpet_commercial", Color(0.82, 0.85, 0.9)],
	"wood_veneer_walnut": ["wood_veneer_walnut", null],
	"tile_graphite": ["tile_ceramic_white", Color(0.45, 0.47, 0.5)],
	"tile_ceramic_white": ["tile_ceramic_white", null],
	"vinyl_floor": ["vinyl_floor", Color(0.8, 0.82, 0.85)],
	"drywall": ["drywall_painted", Color(0.9, 0.92, 0.95)],
	"gallery_white": ["paint_white", Color(0.95, 0.95, 0.96)],
	"blockwork": ["plaster_painted", Color(0.55, 0.58, 0.62)],
	"concrete": ["concrete", null],
	"ceiling_tile": ["ceiling_tile", null],
	"plaster_ceiling": ["paint_white", null],
	"roof_membrane": ["paint_white", Color(0.72, 0.74, 0.76)],
	"paving": ["concrete", Color(0.6, 0.63, 0.67)],
	"helipad": ["concrete", Color(0.42, 0.47, 0.47)],
	"planter": ["concrete", Color(0.48, 0.48, 0.5)],
	"asphalt": ["asphalt", null],
	"alu_anodized_black": ["alu_anodized_black", null],
	"glass_curtain": ["glass_clear", Color(0.78, 0.88, 0.9)],
	"teal_glass": ["glass_clear", Color(0.55, 0.85, 0.86)],
	"brushed_steel": ["brushed_steel", null],
	"metal_painted": ["metal_painted", null],
	"metal_matte": ["metal_matte", null],
	"steel_galv": ["steel_bare", Color(0.72, 0.73, 0.75)],
	"cage_mesh": ["metal_matte", Color(1.0, 1.0, 1.0, 0.35)],
	"leather_dark": ["leather_dark", null],
	"fabric_upholstery": ["fabric_upholstery", null],
	"plastic_matte": ["plastic_matte", null],
	"lacquer_black": ["plastic_matte", Color(0.42, 0.42, 0.44)],
	"laminate_white": ["paint_white", Color(0.9, 0.9, 0.9)],
	"tower": ["metal_painted", Color(0.85, 0.9, 0.95)],
	"tower_dark": ["alu_anodized_black", null],
}
## Library ids whose native density is the 256 px/m ceiling target (kept; everything else is scaled to
## 512 px/m, style guide §4).
const CEILING_ONLY: Array[String] = ["ceiling_tile"]
const TEXEL_PX_M: float = 512.0

## Room id (unique, as the builder's _level_rooms: core rooms carry the level, J41 / WCW42 ...) ->
## [walls, ceiling] finish keys, by purpose / dressing kit. Floors come from FLOOR_FINISH (the slabs
## span several rooms).
const ROOM_FINISH: Dictionary = {
	"S1": ["blockwork", "ceiling_tile"],  # L40 service lobby
	"S2": ["blockwork", "concrete"],  # refuse room
	"S3": ["blockwork", "ceiling_tile"],  # service corridor
	"SA": ["blockwork", "concrete"],  # stair cores
	"SB": ["blockwork", "concrete"],
	"SL": ["brushed_steel", "brushed_steel"],  # service lift car
	"LF1": ["concrete", "concrete"],  # lift shafts
	"LF2": ["concrete", "concrete"],
	"J41": ["blockwork", "ceiling_tile"],  # janitor
	"J42": ["blockwork", "ceiling_tile"],
	"WCW41": ["tile_ceramic_white", "ceiling_tile"],  # washrooms
	"WCM41": ["tile_ceramic_white", "ceiling_tile"],
	"WCW42": ["tile_ceramic_white", "ceiling_tile"],
	"WCM42": ["tile_ceramic_white", "ceiling_tile"],
	"K1": ["wood_veneer_walnut", "plaster_ceiling"],  # partner office (Kessler)
	"K2": ["wood_veneer_walnut", "plaster_ceiling"],  # conference
	"K3": ["stone_graphite", "plaster_ceiling"],  # reception (landmark; honed stone panels)
	"K4": ["drywall", "ceiling_tile"],  # assistants
	"K5": ["wood_veneer_walnut", "plaster_ceiling"],  # partner office (Moor)
	"K6": ["drywall", "ceiling_tile"],  # office corridors
	"K7": ["drywall", "ceiling_tile"],
	"K8": ["drywall", "ceiling_tile"],  # open office
	"K9": ["drywall", "ceiling_tile"],
	"K10": ["blockwork", "ceiling_tile"],  # service corridor
	"K11": ["blockwork", "ceiling_tile"],  # server room
	"K12": ["drywall", "ceiling_tile"],  # IT office
	"K13": ["drywall", "ceiling_tile"],  # security office
	"K14": ["blockwork", "concrete"],  # electrical
	"K15": ["drywall", "ceiling_tile"],  # copy room
	"K16": ["drywall", "ceiling_tile"],  # south spine
	"K17": ["drywall", "ceiling_tile"],  # archive
	"K18": ["drywall", "ceiling_tile"],  # break room
	"K19": ["wood_veneer_walnut", "plaster_ceiling"],  # law library
	"K20": ["drywall", "ceiling_tile"],  # associates
	"K21": ["drywall", "ceiling_tile"],
	"K22": ["drywall", "ceiling_tile"],
	"K23": ["drywall", "ceiling_tile"],
	"K24": ["drywall", "ceiling_tile"],  # interview
	"M1": ["wood_veneer_walnut", "plaster_ceiling"],  # partners' lounge
	"M2": ["stone_graphite", "plaster_ceiling"],  # gallery mezzanine
	"M3": ["gallery_white", "plaster_ceiling"],  # art hall
	"M4": ["wood_veneer_walnut", "plaster_ceiling"],  # study
	"M5": ["drywall", "plaster_ceiling"],  # guest suite
	"M6": ["marble_cream", "plaster_ceiling"],  # ensuite
	"M7": ["wood_veneer_walnut", "plaster_ceiling"],  # dressing room
	"M8": ["wood_veneer_walnut", "plaster_ceiling"],  # dining
	"M9": ["drywall", "ceiling_tile"],  # corridor
	"M10": ["blockwork", "ceiling_tile"],  # service corridor
	"M11": ["drywall", "ceiling_tile"],  # pantry
	"M12": ["blockwork", "concrete"],  # electrical
	"M13": ["stone_graphite", "plaster_ceiling"],  # wine room
	"M14": ["wood_veneer_walnut", "plaster_ceiling"],  # boardroom
	"M15": ["drywall", "ceiling_tile"],  # glazed corridor
	"R1": ["concrete", "concrete"],  # riser plant
	"R2": ["blockwork", "concrete"],  # stair A head house
	"R3": ["concrete", "concrete"],  # plant room
}
## A wall box between two rooms shows one finish on both faces (no new meshes): the first of these.
const WALL_PRIORITY: Array[String] = ["marble_cream", "tile_ceramic_white", "stone_graphite", "wood_veneer_walnut",
	"gallery_white", "drywall", "brushed_steel", "blockwork", "concrete"]
## Floor slabs by node name: one box spans several rooms (the slab plate minus the stair, void and
## riser holes), so each takes the finish of the zone it mostly carries. Comments: rooms on each slab.
const FLOOR_FINISH: Dictionary = {
	"SlabL40_0": "vinyl_floor",  # S1-S3 service lobby / refuse / corridor
	"SlabL40_1": "vinyl_floor",  # service lift car
	"SlabL40_2": "concrete",  # stair A / B pits
	"SlabL40_3": "concrete",
	"SlabL41_00": "terrazzo",  # front of house: K3 reception, lift lobby, partner suites, conference
	"SlabL41_01": "carpet_graphite",  # K8 open office, K9
	"SlabL41_02": "tile_graphite",  # washrooms
	"SlabL41_03": "vinyl_floor",  # K10-K15 IT, server, security, electrical, copy
	"SlabL41_04": "carpet_graphite",  # K16 spine, K17-K24 associates, library, break room
	"SlabL42_00": "terrazzo",  # gallery band: M1 lounge, M2 gallery, M3 art hall, M4 study
	"SlabL42_01": "terrazzo",
	"SlabL42_02": "terrazzo",
	"SlabL42_03": "terrazzo",
	"SlabL42_04": "wood_veneer_walnut",  # partner suite: M5-M9 guest suite, dining, M10-M14 boardroom
	"SlabL42_05": "wood_veneer_walnut",
	"SlabL42_06": "wood_veneer_walnut",
	"SlabL42_07": "wood_veneer_walnut",
	"SlabL42_08": "tile_graphite",  # washrooms
	"SlabL42_09": "wood_veneer_walnut",
	"SlabL42_10": "paving",  # X1 terrace and the M15 glazed corridor that opens onto it
}
## Feature stair (K3 -> M2, honed stone treads) and its landing [x0, z0, x1, z1]; other stairs concrete.
const FEATURE_STAIR_ZONE: Array = [12.0, 0.5, 24.0, 2.1]
## Greybox class -> finish key, or a rule: "@floor" (FLOOR_FINISH), "@ceiling" (room below), "@wall"
## (rooms on both faces, WALL_PRIORITY), "@ext" (curtain wall / L40 base / roof enclosures), "@stair".
const CLASS_FINISH: Dictionary = {
	"wall": "@wall", "wall_ext": "@ext", "floor": "@floor", "ceiling": "@ceiling", "roof": "roof_membrane",
	"stair": "@stair", "counter": "wood_veneer_walnut", "prop": "wood_veneer_walnut", "chair": "leather_dark",
	"trim": "brushed_steel", "glass": "glass_curtain", "frame": "alu_anodized_black", "door": "metal_painted",
	"coping": "alu_anodized_black", "concrete": "concrete", "fence": "metal_matte", "steel": "steel_galv",
	"street": "asphalt", "graphite": "stone_graphite",
}
## Prop kind (layout PROPS / gameplay prop_box) -> finish key (else the class rule).
const KIND_FINISH: Dictionary = {
	"sofa": "leather_dark", "armchair": "leather_dark", "bed": "fabric_upholstery", "plinth": "gallery_white",
	"piano": "lacquer_black", "cart": "metal_painted", "lounger": "plastic_matte", "printer": "plastic_matte",
	"copier": "plastic_matte", "rack": "alu_anodized_black", "crac": "metal_painted", "ups": "metal_painted",
	"fridge": "brushed_steel", "sink": "marble_cream", "locker": "metal_painted", "switchboard": "metal_painted",
	"ahu": "metal_painted", "chiller": "metal_painted", "tank": "metal_painted", "lift_motor": "metal_painted",
	"bmu": "metal_painted", "garage": "metal_painted", "anchor_frame": "steel_galv", "heater": "brushed_steel",
	"riser_panel": "metal_painted", "gate": "metal_matte", "cage": "metal_matte",
	"counter_transaction": "stone_graphite", "counter_service": "laminate_white",
}
## Node name -> finish key (beats prefix, kind and class).
const NAME_FINISH: Dictionary = {
	"MopSink": "tile_ceramic_white", "KeyCabinet": "metal_painted", "CompactShelvingA": "metal_painted",
	"CompactShelvingB": "metal_painted", "ITSpares": "metal_painted", "LinenShelves": "gallery_white",
	"OutdoorKitchen": "brushed_steel", "LiftShaft1": "concrete", "LiftShaft2": "concrete",
	"ServiceLiftShaft": "concrete", "SecurityCounter": "metal_painted",
}
## Node name prefix -> finish key (lift landing doors, camera brackets).
const PREFIX_FINISH: Array = [["Lift1L", "brushed_steel"], ["Lift2L", "brushed_steel"], ["ServiceLiftL", "brushed_steel"],
	["Bracket", "alu_anodized_black"]]


## Unique room id containing p (plan rooms of the level whose storey holds p), "" outside.
static func room_at(p: Vector3) -> String:
	for lv: String in ["RF", "L42", "L41", "L40"]:
		var info: Array = L.LEVELS[lv]
		if p.y < float(info[0]) - 0.05 or p.y > float(info[1]) + 0.6:
			continue
		var src: Array = (L.PLAN_ROOMS[lv] as Array).duplicate()
		if lv == "L41" or lv == "L42":
			src.append_array(L.CORE)
		for r: Array in src:
			if p.x > float(r[1]) and p.x < float(r[3]) and p.z > float(r[2]) and p.z < float(r[4]):
				var pid: String = String(r[0])
				return pid + lv.substr(1) if pid in ["J", "WCW", "WCM"] else pid
		return ""
	return ""


static func _in_rect(p: Vector3, r: Array) -> bool:
	return p.x >= float(r[0]) and p.x <= float(r[2]) and p.z >= float(r[1]) and p.z <= float(r[3])


## Finish key for a box of greybox class `cls` named `nm` (world AABB `wb`; `kind` = prop kind or "").
static func resolve(cls: String, nm: String, wb: AABB, kind: String = "") -> String:
	if NAME_FINISH.has(nm):
		return String(NAME_FINISH[nm])
	for pf: Array in PREFIX_FINISH:
		if nm.begins_with(String(pf[0])):
			return String(pf[1])
	if kind != "" and KIND_FINISH.has(kind):
		return String(KIND_FINISH[kind])
	if FINISHES.has(cls):
		return cls
	var rule: String = String(CLASS_FINISH.get(cls, cls))
	var c: Vector3 = wb.get_center()
	match rule:
		"@floor":
			return String(FLOOR_FINISH.get(nm, "concrete"))
		"@ceiling":
			return _room_finish(room_at(Vector3(c.x, wb.position.y - 0.3, c.z)), 1, "ceiling_tile")
		"@wall":
			return _wall(c, wb, "blockwork")
		"@ext":
			if c.y > L.FRF:
				return _wall(c, wb, "alu_anodized_black")  # roof: plant-block walls, else the parapet crown
			return "stone_graphite" if c.y < L.F41 - 0.05 else "alu_anodized_black"  # L40 base / curtain wall
		"@stair":
			return "stone_graphite" if _in_rect(c, FEATURE_STAIR_ZONE) else "concrete"
	return rule


static func _room_finish(room: String, i: int, fallback: String) -> String:
	return String((ROOM_FINISH[room] as Array)[i]) if ROOM_FINISH.has(room) else fallback


## Wall piece: the finishes of the rooms 0.3 m off both faces of its thin axis; WALL_PRIORITY picks one.
## No room on either face: `fallback`.
static func _wall(c: Vector3, wb: AABB, fallback: String) -> String:
	var n: Vector3 = Vector3.RIGHT if wb.size.x <= wb.size.z else Vector3.BACK
	var off: float = (wb.size.x if wb.size.x <= wb.size.z else wb.size.z) * 0.5 + 0.3
	var keys: Array[String] = []
	for s: float in [-1.0, 1.0]:
		var r: String = room_at(c + n * off * s)
		if ROOM_FINISH.has(r):
			keys.append(String((ROOM_FINISH[r] as Array)[0]))
	if keys.is_empty():
		return fallback
	for k: String in WALL_PRIORITY:
		if keys.has(k):
			return k
	return keys[0]


## Triplanar UV scale (UV per metre) for a library material: its native density when it is within
## the +-25% band of 512 px/m (or a ceiling-only material), else 512 px/m.
static func uv_per_m(lib: String, tex_w: float, tile_m: float) -> float:
	var native: float = tex_w / tile_m
	if lib in CEILING_ONLY or (native >= TEXEL_PX_M * 0.75 and native <= TEXEL_PX_M * 1.5):
		return 1.0 / tile_m
	return TEXEL_PX_M / tex_w
