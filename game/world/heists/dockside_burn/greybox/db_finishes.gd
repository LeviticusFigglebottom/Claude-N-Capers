## Dockside Burn surface pass (PO-13): greybox surface class + room purpose / face -> library material.
## Owner: ENV C. Used by db_builder_base.gd (box / mesh_box / prop_box resolve their material here).
## Materials only: no mesh changes. Every finish is a duplicate of a texgen library material
## (game/world/materials/<lib>.tres, textures shared) set to world triplanar (the greybox boxes have
## per-face 0..1 UVs), scaled to the style guide's texel density, optionally tinted (albedo multiply).
## Palette (dockside_burn.md §Audio/lighting, style guide §3): rust #7A4A2E dominant (cladding,
## containers, crane), concrete #7D7F7C secondary (quay, yard, cold-store floor, block walls), flare
## orange #FF6B1A accent (forklifts, barriers); cold-store interiors frosted off-white panels.
## Bullet surface ids follow from the finish key through surface_map.json (`db_<key>`).
extends RefCounted

const L: GDScript = preload("res://world/heists/dockside_burn/greybox/dockside_burn_layout.gd")

## Finish key -> [library id, tint (albedo multiply) or null]. Keys without a tint that equal their
## library id are plain library surfaces.
const FINISHES: Dictionary = {
	"concrete": ["concrete", null],
	"quay": ["concrete", Color(0.84, 0.85, 0.86)],
	"paving": ["concrete", Color(0.95, 0.93, 0.89)],
	"epoxy_floor": ["concrete", Color(0.78, 0.86, 0.84)],
	"blockwork": ["plaster_painted", Color(0.7, 0.74, 0.78)],
	"asphalt": ["asphalt", null],
	"roof_felt": ["asphalt", Color(0.82, 0.82, 0.84)],
	"brick_red": ["brick_red", Color(0.86, 0.84, 0.84)],
	"brick_dark": ["brick_red", Color(0.62, 0.6, 0.62)],
	"render_grey": ["plaster_painted", Color(0.58, 0.6, 0.62)],
	"drywall_painted": ["drywall_painted", null],
	"tile_ceramic_white": ["tile_ceramic_white", Color(0.94, 0.95, 0.95)],
	"vinyl_floor": ["vinyl_floor", Color(0.86, 0.87, 0.88)],
	"ceiling_tile": ["ceiling_tile", null],
	"frost_panel": ["paint_white", Color(0.9, 0.94, 0.97)],
	"rust_cladding": ["paint_safety_orange", Color(0.6, 0.72, 0.9)],
	"steel_cladding": ["metal_painted", Color(1.0, 1.0, 1.0)],
	"roof_metal": ["metal_matte", Color(0.85, 0.85, 0.85)],
	"container_rust": ["paint_safety_orange", Color(0.55, 0.62, 0.8)],
	"container_blue": ["metal_painted", Color(0.75, 0.92, 1.0)],
	"container_green": ["metal_painted", Color(0.8, 1.0, 0.86)],
	"crane": ["paint_safety_orange", Color(0.8, 0.76, 0.8)],
	"paint_safety_orange": ["paint_safety_orange", null],
	"metal_painted": ["metal_painted", null],
	"metal_matte": ["metal_matte", null],
	"brushed_steel": ["brushed_steel", null],
	"trailer_white": ["paint_white", Color(0.8, 0.81, 0.82)],
	"hull_dark": ["metal_painted", Color(0.62, 0.6, 0.58)],
	"deck": ["wood_veneer_walnut", Color(0.86, 0.9, 0.94)],
	"wood_veneer_walnut": ["wood_veneer_walnut", null],
	"plastic_matte": ["plastic_matte", null],
	"ice_bin": ["plastic_matte", Color(0.62, 0.8, 1.0)],
	"nets": ["fabric_upholstery", Color(0.7, 0.85, 0.75)],
	"glass_clear": ["glass_clear", null],
	"mural": ["plaster_painted", Color(0.3, 0.52, 0.64)],
}
## Library ids whose native density is the 256 px/m ceiling target (kept; everything else is scaled to
## 512 px/m, style guide §4).
const CEILING_ONLY: Array[String] = ["ceiling_tile"]
const TEXEL_PX_M: float = 512.0

## Room id (layout ROOMS) -> [floor, walls, ceiling] finish keys, by purpose / dressing kit.
const ROOM_FINISH: Dictionary = {
	"O1": ["vinyl_floor", "drywall_painted", "ceiling_tile"],  # reception
	"O2": ["vinyl_floor", "drywall_painted", "ceiling_tile"],  # security / dispatch
	"E1": ["concrete", "blockwork", "ceiling_tile"],  # electrical closet
	"OC": ["vinyl_floor", "drywall_painted", "ceiling_tile"],  # service corridor
	"ST": ["concrete", "blockwork", "concrete"],  # stair core
	"HH": ["concrete", "blockwork", "concrete"],
	"LF": ["concrete", "blockwork", "concrete"],  # goods-lift shaft
	"PL": ["epoxy_floor", "blockwork", "concrete"],  # refrigeration plant
	"WS": ["epoxy_floor", "blockwork", "concrete"],  # forklift workshop
	"LK": ["tile_ceramic_white", "drywall_painted", "ceiling_tile"],  # locker room
	"J": ["tile_ceramic_white", "blockwork", "ceiling_tile"],  # janitor
	"PK": ["epoxy_floor", "frost_panel", "frost_panel"],  # chilled packing hall
	"H": ["concrete", "blockwork", "roof_metal"],  # marshalling hall
	"C1": ["concrete", "frost_panel", "frost_panel"],  # cold store chambers + spine
	"SP": ["concrete", "frost_panel", "frost_panel"],
	"C2": ["concrete", "frost_panel", "frost_panel"],
	"SR": ["concrete", "concrete", "concrete"],  # strongroom (reinforced)
	"AN": ["concrete", "frost_panel", "frost_panel"],  # chilled quay dock
	"M1": ["vinyl_floor", "drywall_painted", "ceiling_tile"],  # count room
	"M2": ["vinyl_floor", "drywall_painted", "ceiling_tile"],  # break room
	"M3": ["tile_ceramic_white", "tile_ceramic_white", "ceiling_tile"],  # restroom
	"MC": ["vinyl_floor", "drywall_painted", "ceiling_tile"],
	"GH": ["vinyl_floor", "drywall_painted", "ceiling_tile"],  # gatehouse
	"QS": ["concrete", "blockwork", "concrete"],  # net store
}
## A wall box between two rooms shows one finish on both faces (no new meshes): the first of these.
const WALL_PRIORITY: Array[String] = ["tile_ceramic_white", "frost_panel", "blockwork", "drywall_painted", "concrete"]
## Building blocks by plan rectangle [x0, z0, x1, z1] (first match on a box's centre): exterior
## skin (`wall_ext`, and interior wall pieces open to the outside on both faces) and roof finish.
## Shed roofs take their wall finish: the roof slab's edges are flush with the wall faces (coplanar).
const FACADE_ZONES: Array = [
	["office", [-0.6, -0.6, 18.2, 8.2], "brick_red", "roof_felt"],
	["hall", [18.2, -0.6, 48.6, 10.0], "rust_cladding", "roof_metal"],
	["bay", [18.0, 10.0, 48.6, 32.6], "rust_cladding", "roof_metal"],
	["wing", [-0.6, 8.0, 18.0, 32.6], "concrete", "roof_metal"],
	["gatehouse", [23.5, -32.5, 30.5, -27.5], "render_grey", "render_grey"],
	["net_store", [11.5, 33.5, 20.5, 40.5], "rust_cladding", "rust_cladding"],
	["harbour_shed", [59.0, 44.4, 62.2, 48.0], "steel_cladding", "steel_cladding"],
]
## Steel stairs (the hall platform stair, the external fire stair and its landing) [x0, z0, x1, z1].
const STEEL_STAIR_ZONES: Array = [[-1.6, -0.6, -0.1, 8.1], [21.9, 6.7, 28.4, 8.1]]
## Greybox class -> finish key, or a rule: "@floor" / "@ceiling" (room above / below), "@wall" (rooms on
## both faces, WALL_PRIORITY), "@ext" / "@roof" (FACADE_ZONES), "@stair" (STEEL_STAIR_ZONES).
const CLASS_FINISH: Dictionary = {
	"wall": "@wall", "wall_ext": "@ext", "floor": "@floor", "ceiling": "@ceiling", "roof": "@roof",
	"stair": "@stair", "panel": "frost_panel", "counter": "wood_veneer_walnut", "prop": "wood_veneer_walnut",
	"trim": "metal_painted", "glass": "glass_clear", "frame": "metal_painted", "door": "metal_painted",
	"handrail": "brushed_steel", "concrete": "quay", "asphalt": "asphalt", "paving": "paving", "deck": "deck",
	"facade_a": "steel_cladding", "facade_b": "render_grey", "facade_c": "brick_dark", "brick": "brick_red",
	"fence": "metal_matte", "barrier": "paint_safety_orange", "container": "@container", "crane": "crane",
	"vehicle": "metal_painted", "mural": "mural", "grate": "metal_matte", "chair": "plastic_matte",
}
## Containers, trailers and stacks: one of these by a stable hash of the node name (rust dominant).
const CONTAINER_TINTS: Array[String] = ["container_rust", "container_rust", "container_blue", "container_green"]
## Prop kind (layout PROPS / gameplay prop_box) -> finish key (else the class rule).
const KIND_FINISH: Dictionary = {
	"conveyor": "brushed_steel", "locker": "metal_painted", "switchboard": "metal_painted",
	"fridge": "trailer_white", "ice_machine": "brushed_steel", "compressor": "metal_painted",
	"tank": "metal_painted", "control_panel": "metal_painted", "forklift": "paint_safety_orange",
	"rack": "metal_matte", "sink": "tile_ceramic_white", "toilet": "tile_ceramic_white", "shelf": "metal_painted",
	"pallet_wrapped": "plastic_matte", "pallet_product": "plastic_matte", "pallet_jack": "metal_painted",
	"heater": "metal_painted", "nets": "nets", "rope_reel": "nets", "ice_bins": "ice_bin", "kerb": "concrete",
	"bollard": "metal_matte", "skip": "container_rust", "fish_blocks": "frost_panel", "gangway": "metal_matte",
	"railing": "metal_painted",
}
## Node name -> finish key (beats kind and class).
const NAME_FINISH: Dictionary = {
	"ToolBench": "metal_painted", "PackingTableA": "brushed_steel", "PackingTableB": "brushed_steel",
	"GateConsole": "metal_painted", "ReachStacker": "paint_safety_orange", "ReeferTrailer": "trailer_white",
	"ReeferTruck": "trailer_white", "TrawlerHull": "hull_dark", "TrawlerWheelhouse": "trailer_white",
	"Deck": "metal_matte", "WeighbridgePlate": "metal_matte", "FarShore": "brick_dark",
	"BellweatherRoofPlant": "metal_painted", "StrongroomRoof": "concrete", "HeadHouseRoof": "blockwork",
}


## Room id containing p (layout ROOMS, exterior rooms skipped), "" outside.
static func room_at(p: Vector3) -> String:
	for r: Array in L.ROOMS:
		if String(r[1]) == "exterior":
			continue
		for b: Array in r[4]:
			if p.x > float(b[0]) and p.x < float(b[3]) and p.z > float(b[2]) and p.z < float(b[5]) \
					and p.y > float(b[1]) - 0.05 and p.y < float(b[4]) + 0.6:
				return String(r[0])
	return ""


static func _in_rect(p: Vector3, r: Array) -> bool:
	return p.x >= float(r[0]) and p.x <= float(r[2]) and p.z >= float(r[1]) and p.z <= float(r[3])


static func _zone(p: Vector3, col: int) -> String:
	for z: Array in FACADE_ZONES:
		if _in_rect(p, z[1]):
			return String(z[col])
	return "concrete"


## Finish key for a box of greybox class `cls` named `nm` (world AABB `wb`; `kind` = prop kind or "").
static func resolve(cls: String, nm: String, wb: AABB, kind: String = "") -> String:
	if NAME_FINISH.has(nm):
		return String(NAME_FINISH[nm])
	if kind != "" and KIND_FINISH.has(kind):
		return String(KIND_FINISH[kind])
	var rule: String = String(CLASS_FINISH.get(cls, cls))
	var c: Vector3 = wb.get_center()
	match rule:
		"@floor":
			return _room_finish(room_at(Vector3(c.x, wb.end.y + 0.3, c.z)), 0, "concrete")
		"@ceiling":
			return _room_finish(room_at(Vector3(c.x, wb.position.y - 0.3, c.z)), 2, "concrete")
		"@wall":
			return _wall(c, wb)
		"@ext":
			return _zone(c, 2)
		"@roof":
			return _zone(c, 3)
		"@stair":
			for z: Array in STEEL_STAIR_ZONES:
				if _in_rect(c, z):
					return "metal_matte"  # the guard panels are `fence` (metal_matte) too
			return "concrete"
		"@container":
			return CONTAINER_TINTS[absi(nm.hash()) % CONTAINER_TINTS.size()]
	return rule


static func _room_finish(room: String, i: int, fallback: String) -> String:
	return String((ROOM_FINISH[room] as Array)[i]) if ROOM_FINISH.has(room) else fallback


## Wall piece: the finishes of the rooms 0.3 m off both faces of its thin axis; WALL_PRIORITY picks one.
## No room on either face (parapets above a lower roof): the building block's exterior skin.
static func _wall(c: Vector3, wb: AABB) -> String:
	var n: Vector3 = Vector3.RIGHT if wb.size.x <= wb.size.z else Vector3.BACK
	var off: float = (wb.size.x if wb.size.x <= wb.size.z else wb.size.z) * 0.5 + 0.3
	var keys: Array[String] = []
	for s: float in [-1.0, 1.0]:
		var r: String = room_at(c + n * off * s)
		if ROOM_FINISH.has(r):
			keys.append(String((ROOM_FINISH[r] as Array)[1]))
	if keys.is_empty():
		return _zone(c, 2)
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
