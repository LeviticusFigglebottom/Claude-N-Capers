## Ostrander Federal G2 surface data (OF-C2 surfaces lane, ENV C): finish keys, the per-room finish table and the trim
## styles read by of_finish.gd. Palette (ostrander_federal.md Audio/lighting): limestone #CBC3B0 dominant (the public
## stone rooms), deep ultramarine #2F3F6B secondary (coffer grounds, carpets, the vault paint), meridian bronze accent;
## BOH painted block and vinyl in a cool grey-blue; wear pristine. Rooms BH, VE and X1 belong to the hall lane (THEIRS).
extends RefCounted

## Rooms another lane dresses: a Geometry box within TOUCH of these keeps its greybox mesh (that lane re-materials it);
## its faces into our rooms get SKIN-proud skins.
const THEIRS: Array[String] = ["BH", "VE", "X1"]
const TOUCH: float = 0.35
## The finish of a sliver of one of our boxes that shows in their rooms (a wall end at the gallery corner): by class.
const THEIRS_KEY: Dictionary = {"wall": "ashlar", "wall_ext": "facade", "floor": "terrazzo", "roof": "roof_membrane",
	"ceiling": "plaster_ivory", "stair": "terrazzo", "trim": "metal_dark"}
## Skins on another lane's boxes stand this far proud (zfight PLANE_EPS is 2 mm).
const SKIN: float = 0.004
## A box is the hall lane's when at least this share of its exposed area looks into their rooms.
const THEIRS_SHARE: float = 0.25
## Trim strips stop this short of their wall run's ends (door frames sit flush with the jambs: no coplanar ends).
const TRIM_END_INSET: float = 0.01
## Door casings (the prefabs' frames, built at runtime) reach this far either side of the opening (trims stop there).
const DOOR_CASING: float = 0.12
## Wall faces left out: [axis of the plane ("z": plane z = c), c, normal sign, a0, a1, y0, y1] (the VT box banks of
## of_art_rooms.gd BANKS: lane B's frames and door tiles sit flush on the wall face).
const WALL_CUTS: Array = [
	["z", 13.3, 1.0, 14.3, 22.6, -4.0, -1.9], ["z", 13.3, 1.0, 25.2, 28.6, -4.0, -1.9],
	["z", 24.8, -1.0, 14.3, 33.7, -4.0, -1.9],
]
## Trim strips are tested against the props / fixtures in pieces of this length.
const STRIP_STEP: float = 0.25
## Floor areas our floor faces leave out: [x0, z0, x1, z1, floor y] (the TW lid's marble panel, 2-6 mm over the slab).
const FLOOR_CUTS: Array = [[22.8, 13.4, 25.2, 15.8, 0.0]]

## Finish key -> [library id, tint (albedo multiply) or null, strip V range [top, bottom] or null]. A strip range maps a
## face's whole height onto that part of the texture (the wainscot: 1 m of panels over floor -> dado; trims: the strip).
## Keys end in their library id where the bullet surface lookup needs it (SurfaceTags.for_id).
const KEYS: Dictionary = {
	"ashlar": ["limestone_ashlar", null, null],
	"ashlar_warm": ["limestone_ashlar", Color(1.0, 0.975, 0.93), null],
	"ashlar_grey": ["limestone_ashlar", Color(0.86, 0.87, 0.88), null],
	"ashlar_plinth": ["limestone_ashlar", Color(0.74, 0.72, 0.68), null],
	"facade": ["limestone_ashlar", Color(0.98, 0.96, 0.92), null],
	"panel_oak": ["wood_panel_oak", null, null],
	"wainscot_oak": ["wood_panel_oak", null, [0.0, 0.5]],
	"wainscot_walnut": ["wood_panel_oak", Color(0.7, 0.62, 0.58), [0.0, 0.5]],
	"panelfull_walnut": ["wood_panel_oak", Color(0.7, 0.62, 0.58), [0.0, 1.0]],
	"panelfull_oak": ["wood_panel_oak", null, [0.0, 1.0]],
	"vault_steel": ["steel_plate_riveted", null, null],
	"plaster": ["plaster_painted", null, null],
	"plaster_ivory": ["plaster_painted", Color(1.0, 0.985, 0.96), null],
	"plaster_ultra": ["plaster_painted", Color(0.42, 0.5, 0.74), null],
	"plaster_boh": ["plaster_painted", Color(0.8, 0.86, 0.93), null],
	"plaster_bohgrey": ["plaster_painted", Color(0.68, 0.72, 0.78), null],
	"drywall": ["drywall_painted", null, null],
	"drywall_warm": ["drywall_painted", Color(1.0, 0.97, 0.92), null],
	"terrazzo": ["terrazzo", null, null],
	"marble": ["marble_cream", null, null],
	"carpet_ultra": ["carpet_commercial", Color(0.62, 0.72, 1.0), null],
	"carpet": ["carpet_commercial", null, null],
	"vinyl": ["vinyl_floor", null, null],
	"vinyl_cool": ["vinyl_floor", Color(0.84, 0.9, 0.96), null],
	"concrete": ["concrete", null, null],
	"concrete_sealed": ["concrete", Color(0.86, 0.88, 0.92), null],
	"ceiling_tile": ["ceiling_tile", null, null],
	"tile_white": ["tile_ceramic_white", null, null],
	"paving": ["concrete", Color(0.95, 0.93, 0.9), null],
	"roof_membrane": ["asphalt", Color(0.86, 0.86, 0.87), null],
	"asphalt": ["asphalt", null, null],
	"brick": ["brick_red", null, null],
	"steel": ["brushed_steel", null, null],
	"metal": ["metal_painted", null, null],
	"metal_dark": ["metal_painted", Color(0.6, 0.62, 0.66), null],
	"metal_ultra": ["metal_painted", Color(0.62, 0.68, 0.9), null],
	"bronze": ["brass", Color(0.8, 0.66, 0.46), null],
	"wood": ["wood_veneer_walnut", null, null],
	"cable_fabric": ["fabric_upholstery", Color(0.42, 0.42, 0.44), null],
}
## Trim-sheet strips (trim_interior, trim_table.json) used as keys "trim_<strip>".
const TRIM_STRIPS: Array[String] = ["baseboard", "crown_cornice", "chair_rail", "wood_trim", "wood_trim_wide",
	"metal_edge", "rubber_bumper", "metal_kickplate", "picture_rail"]

## Room id -> [floor, walls, ceiling, style]. Styles (STYLES): stone (ashlar, stone plinth, cornice, pilasters), panel
## (oak wainscot to the dado, wood dado rail and skirting, cornice), panel_full (2 m walnut panelling, picture rail,
## plaster frieze, cornice), office (painted drywall, skirting), boh (cool painted block, skirting, chair rail),
## corridor (boh + a rubber bumper rail), wet (tiled walls), plain (bare service rooms), vault (riveted steel lining,
## kickplate), stair, exterior. Ceiling styles are in CEILING_FEATURES.
const ROOMS: Dictionary = {
	# Basement
	"LK": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"GL": ["steel", "steel", "steel", "plain"],
	"CQ": ["concrete_sealed", "plaster_bohgrey", "concrete", "corridor"],
	"SA": ["terrazzo", "plaster_boh", "plaster", "stair"],
	"CP": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"PL": ["concrete", "plaster_bohgrey", "concrete", "plain"],
	"CM": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"SS": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"SB": ["terrazzo", "plaster_boh", "plaster", "stair"],
	"BB": ["vinyl_cool", "plaster_boh", "ceiling_tile", "corridor"],
	"RC": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"VC": ["terrazzo", "ashlar", "plaster_ultra", "stone"],
	"VT": ["concrete_sealed", "vault_steel", "concrete", "vault"],
	"SD": ["terrazzo", "ashlar", "plaster_ivory", "stone"],
	# Ground
	"LD": ["concrete", "plaster_bohgrey", "concrete", "corridor"],
	"E1": ["concrete", "plaster_bohgrey", "concrete", "plain"],
	"SR": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"GR": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"WM": ["tile_white", "tile_white", "ceiling_tile", "wet"],
	"WW": ["tile_white", "tile_white", "ceiling_tile", "wet"],
	"J1": ["concrete_sealed", "plaster_bohgrey", "ceiling_tile", "plain"],
	"MO": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"BC": ["vinyl_cool", "plaster_boh", "ceiling_tile", "corridor"],
	"LO": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	"TW": ["carpet_ultra", "drywall_warm", "plaster_ivory", "panel"],
	"PC": ["carpet_ultra", "plaster_ivory", "plaster_ultra", "panel_full"],
	"CN1": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	"CN2": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	"AV": ["marble", "ashlar", "plaster_ivory", "stone"],
	"BM": ["carpet_ultra", "plaster_ivory", "plaster_ivory", "panel_full"],
	"PW": ["marble", "tile_white", "plaster_ivory", "wet"],
	"NA": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	# Gallery
	"BR": ["vinyl_cool", "drywall", "ceiling_tile", "office"],
	"E2": ["concrete", "plaster_bohgrey", "concrete", "plain"],
	"IT": ["vinyl_cool", "drywall", "ceiling_tile", "office"],
	"SV": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"WM2": ["tile_white", "tile_white", "ceiling_tile", "wet"],
	"WW2": ["tile_white", "tile_white", "ceiling_tile", "wet"],
	"J2": ["concrete_sealed", "plaster_bohgrey", "ceiling_tile", "plain"],
	"AR": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	"UC": ["carpet", "drywall_warm", "ceiling_tile", "panel"],
	"AO1": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	"AO2": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	"AO3": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	"WL": ["terrazzo", "ashlar", "plaster_ivory", "stone"],
	"OF": ["carpet", "drywall_warm", "ceiling_tile", "panel"],
	"CF": ["carpet_ultra", "plaster_ivory", "plaster_ivory", "panel_full"],
	"CO": ["carpet", "drywall_warm", "ceiling_tile", "panel"],
	"GA": ["terrazzo", "ashlar", "", "stone"],
	"EL": ["terrazzo", "ashlar", "plaster_ivory", "stone"],
	"VO": ["carpet", "drywall_warm", "ceiling_tile", "panel"],
	"TR": ["carpet", "drywall_warm", "ceiling_tile", "panel"],
	"TT": ["carpet", "drywall_warm", "ceiling_tile", "panel"],
	# Executive
	"BD": ["carpet_ultra", "plaster_ivory", "plaster_ivory", "panel_full"],
	"E3": ["concrete", "plaster_bohgrey", "concrete", "plain"],
	"EA": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	"PR": ["carpet_ultra", "plaster_ivory", "plaster_ivory", "panel_full"],
	"PN": ["vinyl_cool", "drywall", "ceiling_tile", "office"],
	"XW": ["marble", "tile_white", "plaster_ivory", "wet"],
	"XC": ["carpet_ultra", "drywall_warm", "ceiling_tile", "panel"],
	"XL": ["carpet_ultra", "plaster_ivory", "plaster_ivory", "panel_full"],
	"LG": ["carpet", "drywall_warm", "ceiling_tile", "panel"],
	"CT": ["carpet", "drywall_warm", "ceiling_tile", "panel"],
	"RA": ["vinyl_cool", "plaster_boh", "ceiling_tile", "boh"],
	# Roof
	"HH": ["concrete", "plaster_bohgrey", "concrete", "stair"],
	"RP": ["concrete", "plaster_bohgrey", "concrete", "plain"],
	# Exteriors (the walls they look at are the facade)
	"X2": ["paving", "facade", "", "exterior"],
	"X3": ["asphalt", "facade", "", "exterior"],
	"X4": ["paving", "facade", "", "exterior"],
	"X5": ["roof_membrane", "facade", "", "exterior"],
}
## Style -> {skirt: [key, height, depth], dado: [key, y, height, depth, wainscot key or ""], cornice: [key, height,
## depth], picture: [key, y, height, depth], pilasters: [key, width, proud, spacing]} (absent = none).
const STYLES: Dictionary = {
	"stone": {"skirt": ["ashlar_plinth", 0.22, 0.032], "cornice": ["trim_crown_cornice", 0.25, 0.07],
		"pilasters": ["ashlar_warm", 0.5, 0.07, 3.2]},
	"panel": {"skirt": ["trim_wood_trim_wide", 0.1875, 0.028], "dado": ["trim_wood_trim", 0.95, 0.09375, 0.028, "wainscot_oak"],
		"cornice": ["trim_crown_cornice", 0.25, 0.06]},
	"panel_full": {"skirt": ["trim_wood_trim_wide", 0.1875, 0.03],
		"dado": ["trim_wood_trim", 0.95, 0.09375, 0.03, "wainscot_walnut"],
		"picture": ["trim_wood_trim", 2.05, 0.09375, 0.03, "panelfull_walnut"],
		"cornice": ["trim_crown_cornice", 0.25, 0.08]},
	"office": {"skirt": ["trim_baseboard", 0.127, 0.013], "dado": ["trim_chair_rail", 0.9, 0.0625, 0.016, ""]},
	"boh": {"skirt": ["trim_baseboard", 0.127, 0.013], "dado": ["trim_chair_rail", 0.9, 0.0625, 0.016, ""]},
	"corridor": {"skirt": ["trim_baseboard", 0.127, 0.013], "dado": ["trim_rubber_bumper", 0.85, 0.125, 0.032, ""]},
	"vault": {"skirt": ["trim_metal_kickplate", 0.125, 0.012], "dado": ["trim_metal_edge", 1.2, 0.0625, 0.015, ""],
		"cornice": ["trim_metal_edge", 0.0625, 0.02]},
	"stair": {"skirt": ["trim_baseboard", 0.127, 0.013]},
	"wet": {},
	"plain": {},
	"exterior": {},
}
## Ceiling features: room -> [kind, key, spacing (m), beam width, beam depth]. coffer: a beam grid both ways; beams_x /
## beams_z: beams running along x / z at the listed positions (or every spacing); a segment that would hit a
## ceiling-mounted fixture is left out.
const CEILING_FEATURES: Dictionary = {
	"VC": ["coffer", "plaster_ivory", 2.5, 0.22, 0.16],
	"PC": ["coffer", "plaster_ivory", 2.4, 0.2, 0.16],
	"BM": ["coffer", "plaster_ivory", 2.6, 0.18, 0.12],
	"CF": ["coffer", "plaster_ivory", 2.6, 0.18, 0.12],
	"BD": ["coffer", "plaster_ivory", 2.4, 0.18, 0.12],
	"PR": ["coffer", "plaster_ivory", 2.4, 0.18, 0.12],
	"XL": ["coffer", "plaster_ivory", 2.6, 0.18, 0.12],
	"AV": ["coffer", "plaster_ivory", 2.6, 0.2, 0.15],
	"TW": ["coffer", "plaster_ivory", 4.0, 0.25, 0.2],
	"WL": ["beams_z", "plaster_ivory", 3.0, 0.2, 0.14],
	"EL": ["beams_z", "plaster_ivory", 3.0, 0.2, 0.14],
	"SD": ["beams_x", "plaster_ivory", 0.0, 0.3, 0.22, [12.05, 17.05, 22.05]],
	"VT": ["beams_z", "metal_dark", 4.0, 0.22, 0.3],
	"LD": ["beams_x", "metal_dark", 3.0, 0.2, 0.3],
	"PL": ["beams_x", "metal_dark", 3.5, 0.2, 0.25],
}
## Rooms whose wall runs get no trims / pilasters beyond these walls' faces (none yet).
## Pieces: Geometry groups / node prefixes handled by name.
## Map-built furniture boxes (Props/MapBuilt) in our rooms that still show greybox: material by class.
const CLASS_KEY: Dictionary = {
	"wall": "plaster_boh", "wall_ext": "facade", "floor": "concrete", "roof": "roof_membrane", "ceiling": "plaster",
	"stair": "terrazzo", "counter": "wood", "prop": "metal", "trim": "metal_dark", "frame": "metal_dark",
	"door": "metal", "handrail": "steel", "paving": "paving", "asphalt": "asphalt",
}
## Greybox material -> class (the generator's CLASS_MAT, reversed; several classes share a greybox material).
const GREY_CLASS: Dictionary = {
	"grey_wall": "wall", "grey_wall_ext": "wall_ext", "grey_floor": "floor", "grey_ceiling": "ceiling",
	"grey_stair": "stair", "grey_glass": "glass", "grey_counter": "counter", "grey_prop": "prop", "grey_trim": "trim",
	"grey_frame": "frame", "grey_door": "door",
}
## Site pieces by node name prefix -> key for every face (the neighbours, closures, grade).
const SITE_KEYS: Array = [
	["GradeTannery", "asphalt"], ["GradeAvenue", "asphalt"], ["GradeTanneryMouth", "asphalt"], ["Grade", "paving"],
	["PoliceIsland", "asphalt"], ["ParkingStructure", "concrete"], ["BelmontArms", "brick"], ["Corvino", "brick"],
	["AssayOffice", "ashlar_grey"], ["Barrier", "metal_dark"], ["Balustrade", "ashlar_grey"],
	["Truck", "metal"], ["Bus", "metal"],
]
## Vault cage panels (Geometry/Building/Cages): drawn as a steel frame with vertical bars over the unchanged collider.
const CAGE_POST: float = 0.06
const CAGE_POST_STEP: float = 1.0
const CAGE_BAR: float = 0.014
const CAGE_BAR_PITCH: float = 0.1
const CAGE_KEY: String = "metal_ultra"
## Merged visuals: big rooms and the exteriors tile their floors / ceilings (gh_mesh tile_groups; the Compatibility
## renderer lights an instance with 8 lights at most); walls stay one mesh per room (the perf budget).
const TILE: float = 8.0
const TILE_AREA: float = 200.0
## The detail meshes (D_<room>: trims, pilasters, coffers and beams, cage bars, trays) draw to this distance.
const DETAIL_VIS: float = 24.0
