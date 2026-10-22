## Rolling Thunder G2 finish data (RT-C2 batch 1, reuse-first): read by rt_finish.gd. Owner: ENV C. Library materials
## only (game/world/materials/; §3c: asphalt, concrete, metal_painted (Skyway green), steel_plate_riveted, brick_red);
## the new materials of §3c (steel_cabin, plywood_painted + the hoarding graphic, road markings, bay lines, the heli
## pad) come with the new-asset batch and replace the stand-ins named here.
extends RefCounted

## Finish key -> [library material id, albedo tint (null: the library's own)].
const KEYS: Dictionary = {
	"asphalt": ["asphalt", null],
	"brick": ["brick_red", null],
	"cabin_ext": ["metal_painted", Color(0.78, 0.8, 0.76)],  # stand-in for steel_cabin (§3c)
	"carpet": ["carpet_commercial", null],
	"ceiling_tile": ["ceiling_tile", null],
	"concrete": ["concrete", null],
	"drywall": ["drywall_painted", null],
	"hoarding": ["plywood_painted", null],  # RT-C2 batch 3: the texgen plywood (§3c; the hoarding graphic is open)
	"limestone": ["limestone_ashlar", null],
	"metal": ["metal_painted", null],
	"orange": ["paint_safety_orange", null],
	"plaster": ["plaster_painted", null],
	"plastic": ["plastic_matte", null],
	"riveted": ["steel_plate_riveted", null],
	"skyway_green": ["metal_painted", Color(0.3, 0.5, 0.36)],
	"steel": ["steel_bare", null],
	"steel_brushed": ["brushed_steel", null],
	"terrazzo": ["terrazzo", null],
	"tile": ["tile_ceramic_white", null],
	"vinyl": ["vinyl_floor", null],
	"vinyl_checker": ["vinyl_checker", null],  # GPU-21: the diner's checkerboard (texgen, vinyl_floor's model)
	"wood": ["wood_panel_oak", null],
}

## Room id -> [floor, walls, ceiling] finish keys (the interior faces 0.3 m off a face decide its room). GPU-21: the
## diner's dining room and the function room over it take the checkerboard and a flat plaster ceiling (no drop grid).
const ROOM_FINISH: Dictionary = {
	"CP-G": ["concrete", "concrete", "concrete"], "CP-2": ["concrete", "concrete", "concrete"],
	"CP-R": ["concrete", "concrete", "concrete"], "STA": ["concrete", "concrete", "concrete"],
	"SB": ["concrete", "concrete", "concrete"], "LF": ["riveted", "steel_brushed", "steel_brushed"],
	"R1R2": ["concrete", "concrete", "concrete"],
	"AB": ["vinyl", "drywall", "ceiling_tile"], "CWC": ["tile", "tile", "ceiling_tile"],
	"CPL": ["concrete", "concrete", "concrete"],
	"DR": ["vinyl_checker", "plaster", "plaster"], "K": ["tile", "tile", "ceiling_tile"],
	"BC": ["vinyl", "plaster", "ceiling_tile"], "E": ["vinyl", "plaster", "ceiling_tile"],
	"ST": ["vinyl", "plaster", "ceiling_tile"], "W1": ["tile", "tile", "ceiling_tile"],
	"W2": ["tile", "tile", "ceiling_tile"], "R": ["vinyl", "plaster", "ceiling_tile"],
	"SC": ["vinyl", "plaster", "plaster"], "OF": ["carpet", "plaster", "ceiling_tile"],
	"U1": ["vinyl_checker", "plaster", "plaster"], "U2": ["vinyl", "plaster", "ceiling_tile"],
	"U3": ["vinyl", "plaster", "ceiling_tile"], "U4": ["tile", "tile", "ceiling_tile"],
	"J": ["vinyl", "tile", "ceiling_tile"], "UC": ["vinyl", "plaster", "ceiling_tile"],
	"U5": ["vinyl", "plaster", "ceiling_tile"],
	"C1": ["vinyl", "drywall", "ceiling_tile"], "C2": ["vinyl", "drywall", "ceiling_tile"],
	"C3": ["tile", "tile", "ceiling_tile"], "C4": ["vinyl", "drywall", "ceiling_tile"],
	"STW": ["steel", "steel", "steel"],
}

## Faces outside the rooms (and in the exterior rooms): the first matching rule of [path prefix (under Geometry/),
## greybox class ("" = any), finish key]. "" as the key drops the face (never seen: the grade's underside).
const EXTERIOR: Array = [
	["Site/Grade/", "asphalt", "asphalt"],
	["Site/Grade/", "", "concrete"],
	["Site/Trench/HeightBar", "", "orange"],
	["Site/Trench/", "rail", "metal"],
	["Site/Trench/", "", "concrete"],
	["Site/Rail/Palisade", "", "metal"],
	["Site/Rail/Gantry", "", "metal"],
	["Site/Rail/", "", "concrete"],
	["Site/RailLane/", "", "metal"],
	["Site/Skyway/Pier", "", "concrete"],
	["Site/Skyway/Deck", "", "concrete"],   # the doc: expressway concrete; the green is the girders' (props)
	["Site/Skyway/", "", "concrete"],
	["Site/Hoarding/ManGatePanel", "mesh", "glass"],
	["Site/Hoarding/", "", "hoarding"],
	["Site/Magazine/", "", "riveted"],
	["Site/Frame/", "frame", "steel"],
	["Site/Frame/", "", "concrete"],
	["Site/Scaffold/", "", "steel"],
	["Site/Crane/CraneBase", "", "concrete"],
	["Site/Crane/", "", "orange"],
	["Site/Controller/", "", "metal"],
	["Site/Neighbours/Ashby", "", "limestone"],
	["Site/Neighbours/Warehouses", "", "brick"],
	["Site/Neighbours/Laundromat", "", "brick"],
	["Site/Neighbours/TyreShop", "", "brick"],
	["Site/Neighbours/", "", "concrete"],
	["Site/Closures/", "trim", "plastic"],
	["Site/Closures/", "", "metal"],
	["Building/Walls/WallsD/", "", "brick"],
	["Building/Walls/WallsS/", "", "cabin_ext"],
	["Building/Walls/", "", "concrete"],
	["Building/Slabs/Cabin", "", "cabin_ext"],
	["Building/Ceilings/", "", ""],
	["Building/Guards/", "frame", "metal"],
	["Building/Scaffold/", "", "steel"],
	["Building/Stairs/", "trim", "metal"],
	["Building/", "", "concrete"],
]

## Non-box greybox meshes (hulls, stair steps, rails, map-built boxes without catalog art, the convoy placeholders):
## a world-triplanar override, the first matching rule of [path prefix (from the map root), finish key].
const OVERRIDES: Array = [
	["Geometry/Site/Grade/", "asphalt"],
	["Geometry/Building/StairFlights/STW", "steel"],
	["Geometry/Building/StairFlights/", "concrete"],
	["Geometry/Building/Ramps/", "concrete"],
	["Geometry/Building/Coping/", "concrete"],
	["Geometry/", "concrete"],
	["Props/MapBuilt/Cookline", "steel_brushed"],
	["Props/MapBuilt/Formwork", "wood"],
	["Props/MapBuilt/", "metal"],
	["Variants/", "metal"],
]
## Boxes drawn VISUAL_INSET inside their collider (rt_finish.gd): the stair top rails, flush with the head-house doors'
## frames.
const INSET_BOXES: Array[String] = ["Building/Stairs/STATopRail", "Building/Stairs/SBTopRail"]
## Handrails (kind handrail, any path) and class-"rail" bodies.
const RAIL_KEY: String = "metal"

## No gh_mesh tiling: RT is judged in Forward+ (D-146; clustered lights, no 8-lights-per-object limit), and every
## extra instance costs a draw per shadow cascade. One merged mesh per room / exterior group.
