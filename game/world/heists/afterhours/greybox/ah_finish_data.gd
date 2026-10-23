## Afterhours G2 finish data (AH-C2, reuse-first): read by ah_finish.gd. Owner: ENV C. Library materials only
## (game/world/materials/). The club palette (afterhours.md Audio/lighting): velvet plum dominant (upholstery, the
## hall's wall drapes), black lacquer secondary (the stage, the hall's ceilings and floor, the bar fronts), gilded
## plaster on the circle front; front of house terrazzo and plum carpet; BOH concrete, drywall and vinyl (wear heavy).
extends RefCounted

## Finish key -> [library material id, albedo tint (null: the library's own)].
const KEYS: Dictionary = {
	"asphalt": ["asphalt", null],
	"brick": ["brick_red", null],
	"carpet": ["carpet_commercial", null],
	"carpet_plum": ["carpet_plum", null],
	"ceiling_tile": ["ceiling_tile", null],
	"concrete": ["concrete", null],
	"drywall": ["drywall_painted", null],
	"gilded": ["plaster_gilded", null],
	"lacquer": ["lacquer_black", null],
	"limestone": ["limestone_ashlar", null],
	"metal": ["metal_painted", null],
	"plaster": ["plaster_painted", null],
	"plastic": ["plastic_matte", null],
	"steel": ["steel_bare", null],
	"terrazzo": ["terrazzo", null],
	"tile": ["tile_ceramic_white", null],
	"velvet": ["velvet_plum", null],
	"vinyl": ["vinyl_floor", null],
	"wood": ["wood_panel_oak", null],
}

## Room id -> [floor, walls, ceiling] finish keys (the interior faces 0.3 m off a face decide its room).
const ROOM_FINISH: Dictionary = {
	# front of house: the foyer and box office terrazzo; the hall black (lacquer floor and ceiling, velvet drapes);
	# the bars under / on the circle and the VIP lounge plum; the grand stair carpeted
	"G1": ["terrazzo", "plaster", "plaster"], "G2": ["terrazzo", "plaster", "plaster"],
	"G6": ["lacquer", "velvet", "lacquer"], "G7": ["terrazzo", "velvet", "lacquer"],
	"G8": ["carpet_plum", "plaster", "plaster"],
	"U1": ["carpet_plum", "velvet", "lacquer"], "U2": ["carpet_plum", "velvet", "plaster"],
	"U12": ["carpet_plum", "plaster", "plaster"],
	"G3a": ["tile", "tile", "ceiling_tile"], "G3b": ["tile", "tile", "ceiling_tile"],
	"U4a": ["tile", "tile", "ceiling_tile"], "U4b": ["tile", "tile", "ceiling_tile"],
	"U13": ["tile", "tile", "ceiling_tile"],
	# the upper wing: Crale's office panelled, the count room and the corridors carpeted, the projection box
	"U9": ["carpet", "wood", "plaster"], "U10": ["carpet", "drywall", "ceiling_tile"],
	"U6": ["carpet", "plaster", "ceiling_tile"], "U6b": ["carpet", "plaster", "ceiling_tile"],
	"U5": ["vinyl", "drywall", "concrete"],
	# back of house
	"G10": ["concrete", "drywall", "concrete"], "G23": ["concrete", "drywall", "concrete"],
	"G27": ["concrete", "drywall", "concrete"], "G16": ["concrete", "drywall", "concrete"],
	"G13": ["concrete", "drywall", "concrete"], "G21": ["concrete", "concrete", "concrete"],
	"G22": ["concrete", "drywall", "concrete"], "G15": ["tile", "tile", "concrete"],
	"G11": ["vinyl", "plaster", "ceiling_tile"], "G12": ["vinyl", "drywall", "ceiling_tile"],
	"G14": ["vinyl", "drywall", "ceiling_tile"], "G20": ["vinyl", "drywall", "ceiling_tile"],
	"G24": ["vinyl", "drywall", "ceiling_tile"], "G25": ["vinyl", "drywall", "ceiling_tile"],
	"G26": ["vinyl", "drywall", "ceiling_tile"],
}

## Set pieces inside a room (ah_finish.gd checks these first): [path prefix (under Geometry/), finish key]. The circle
## front's gilt (the doc's gilded plaster), the stage and the hall's upstands black lacquer.
const PATH_FINISH: Array = [
	["Building/Guards/BalconyFront", "gilded"],
	["Building/Stage/", "lacquer"],
	["Building/Upstands/", "lacquer"],
]

## The grade box (its underside is dropped: never seen).
const GRADE_PREFIX: String = "Building/Slabs/Grade_"

## Faces outside the rooms (and in the exterior rooms): the first matching rule of [path prefix (under Geometry/),
## greybox class ("" = any), finish key]. "" as the key drops the face.
const EXTERIOR: Array = [
	["Building/Slabs/Grade_", "", "asphalt"],
	["Building/Slabs/", "", "concrete"],
	["Building/Walls/", "wall_ext", "brick"],
	["Building/Walls/", "", "plaster"],
	["Building/Ceilings/", "", ""],
	["Building/Cage/", "", "metal"],
	["Building/PassageGate/", "", "metal"],
	["Building/Guards/", "", "metal"],
	["Building/Stairs/", "trim", "metal"],
	["Building/", "", "concrete"],
	["Site/Closures/", "trim", "plastic"],
	["Site/Closures/", "", "metal"],
	["Site/Landmarks/", "", "lacquer"],
	["Site/Neighbours/Corliss", "", "limestone"],
	["Site/Neighbours/OfficesE", "", "limestone"],
	["Site/Neighbours/", "", "brick"],
]

## Non-box greybox meshes (hulls, stair steps, rails, map-built boxes without catalog art): a world-triplanar override,
## the first matching rule of [path prefix (from the map root), finish key].
const OVERRIDES: Array = [
	["Geometry/Building/StairFlights/G8", "carpet_plum"],
	["Geometry/Building/StairFlights/", "concrete"],
	["Geometry/", "concrete"],
	["Props/MapBuilt/", "lacquer"],
	["Variants/", "metal"],
]
## Boxes drawn VISUAL_INSET inside their collider (ah_finish.gd).
const INSET_BOXES: Array[String] = []
## Handrails (kind handrail, any path) and class-"rail" bodies.
const RAIL_KEY: String = "metal"
