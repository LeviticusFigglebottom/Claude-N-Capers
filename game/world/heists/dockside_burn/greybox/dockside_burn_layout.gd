## Dockside Burn (Ortega Cold Storage, Pier 9) greybox layout data. Owner: ENV C (C3, G1).
## Source of truth for build_greybox.gd. Design: docs/design/heists/dockside_burn.md (APPROVED, D-064).
## Coordinates: metres, world x = plan x (east), world z = plan z (south), +y up. Origin = the NW
## corner of the Ortega building on the wall centre lines (the plan's origin). Levels
## (floor_heights, D-054 floor_names): Landing -1.8 (landing stage / pontoon), Ground 0.0,
## Mezzanine 3.6 (office block + hall platform), Roof 7.2 (office block).
## Boxes are [x0, y0, z0, x1, y1, z1]. Wall openings are [along0, along1, sill_y, head_y] (absolute).
## Door openings are derived from DOORS by the builder (no duplicated numbers).
## Never edit the generated dockside_burn.tscn by hand: change this file and rerun the generator.
extends RefCounted

const FLOOR_HEIGHTS: Array[float] = [-1.8, 0.0, 3.6, 7.2]
## HeistMap.floor_names (D-054), parallel to FLOOR_HEIGHTS.
const FLOOR_NAMES: Array[String] = ["Landing", "Ground", "Mezzanine", "Roof"]
const LAND: float = -1.8
const MEZZ: float = 3.6
const ROOF: float = 7.2
const EXT_T: float = 0.4
const INT_T: float = 0.2
const CORE_T: float = 0.3
## Office block: ceilings 3.0 (ground) / 6.6 (mezzanine), slabs 3.3-3.6 and 6.9-7.2, parapet 8.3.
const OFFICE_CEIL: float = 3.0
const MEZZ_SLAB: float = 3.3
const MEZZ_CEIL: float = 6.6
const ROOF_SLAB: float = 6.9
const OFFICE_PARAPET: float = 8.3
## Head house over stair ST (2.7 clear above the roof): ceiling 9.9, roof slab 9.9-10.2.
const HH_CEIL: float = 9.9
const HH_TOP: float = 10.2
## Marshalling hall: ceiling 5.8, roof slab 6.3-6.6, parapet 7.7.
const HALL_CEIL: float = 5.8
const HALL_ROOF: float = 6.6
const HALL_PARAPET: float = 7.7
## High-bay cold store: ceiling 8.0 (D-064 override 6.0-9.0), roof slab 8.7-9.0, parapet 10.1.
const BAY_CEIL: float = 8.0
const BAY_ROOF: float = 9.0
const BAY_PARAPET: float = 10.1
## West wing (plant, workshop, packing): roof slab 5.5-5.8, parapet 6.9.
const WING_ROOF: float = 5.8
const WING_PARAPET: float = 6.9
const PLANT_CEIL: float = 5.0
const PACK_CEIL: float = 4.5
const SMALL_CEIL: float = 3.0
const AN_CEIL: float = 5.8
const SR_CEIL: float = 3.5
## Water surface (visual) and the OUT_OF_BOUNDS cap: the pontoon / stage decks are at -1.8.
const WATER_Y: float = -2.4
const OOB_TOP: float = -2.2
## High-bay ceiling override (doc Floor plans, D-048 / D-064 Q3): C1, C2, SP.
const BAY_CEIL_RANGE: Vector2 = Vector2(6.0, 9.0)
## Door opening sizes per door type: [opening width, head above the door's floor].
## Kit doors (0.9 / 1.8 / 1.1 m leaves), the cold-store sliding doors (2.4 x 3.6, two 1.2 m leaves),
## roller doors (3.6 x 4.0, two 1.8 m leaves; G1 hinged stand-ins) and the strongroom vault door
## (2.0 x 2.2, one leaf).
## Lead G2 review: the loading hall's open floor (no props; >= 12 m) [x0, z0, x1, z1].
const HALL_OPEN_FLOOR: Array = [28.6, 0.4, 42.4, 9.6]
const DOOR_OPENINGS: Dictionary = {
	"single": [1.0, 2.2], "double": [2.0, 2.2], "service": [1.2, 2.2], "slide": [2.6, 3.7],
	"roller": [3.8, 4.1], "vault": [2.2, 2.3],
}


# --- Building shell -------------------------------------------------------------------------

## Exterior walls (0.4 m, two 0.2 m skins: `wall_ext` outside, `wall` inside): [name, axis ("x" =
## runs along x at fixed z, "z" = along z at fixed x), fixed, from, to, y0, y1, out_sign (-1 = the
## outside is towards the smaller fixed coordinate), extra openings (windows; doors are added from
## DOORS)]. North / south faces run corner to corner (-0.2..48.2), east / west between them.
const EXT_WALLS: Array = [
	["NorthOffice", "x", 0.0, -0.2, 17.85, 0.0, OFFICE_PARAPET, -1.0, [
		[3.6, 4.8, 0.9, 2.1], [7.2, 8.4, 0.9, 2.1], [9.9, 11.1, 0.9, 2.1], [12.9, 14.1, 0.9, 2.1],
		[3.6, 4.8, MEZZ + 0.9, MEZZ + 2.1], [7.2, 8.4, MEZZ + 0.9, MEZZ + 2.1],
		[9.9, 11.1, MEZZ + 0.9, MEZZ + 2.1], [12.9, 14.1, MEZZ + 0.9, MEZZ + 2.1],
	]],
	["NorthHeadHouse", "x", 0.0, -0.2, 3.15, OFFICE_PARAPET, HH_TOP, -1.0, []],
	# Hall north wall: three yard roller doors and the clerestory band (4.8-5.5).
	["NorthHall", "x", 0.0, 18.15, 48.2, 0.0, HALL_PARAPET, -1.0, [[18.6, 47.4, 4.8, 5.5]]],
	["SouthWing", "x", 32.0, -0.2, 18.0, 0.0, WING_PARAPET, 1.0, []],
	["SouthBay", "x", 32.0, 18.0, 48.2, 0.0, BAY_PARAPET, 1.0, []],
	["WestOffice", "z", 0.0, 0.2, 7.85, 0.0, OFFICE_PARAPET, -1.0, []],
	["WestHeadHouse", "z", 0.0, 0.2, 6.15, OFFICE_PARAPET, HH_TOP, -1.0, []],
	["WestWing", "z", 0.0, 7.85, 31.8, 0.0, WING_PARAPET, -1.0, []],
	["EastHall", "z", 48.0, 0.2, 10.0, 0.0, HALL_PARAPET, 1.0, []],
	["EastBay", "z", 48.0, 10.0, 31.8, 0.0, BAY_PARAPET, 1.0, []],
]

## Interior / party walls: [name, axis, fixed, from, to, y0, y1, thickness, material, extra openings].
## Office ground walls stop at the 3.0 ceilings, mezzanine walls at 6.6; walls that become exterior
## above a lower roof run up to that block's parapet.
const INT_WALLS: Array = [
	# Office block / hall (x 18) and office / west wing (z 8): fire walls up to the office parapet.
	["X18Office", "z", 18.0, 0.15, 7.85, 0.0, OFFICE_PARAPET, CORE_T, "wall", [[0.9, 2.1, 0.45, 1.25]]],
	["X18Workshop", "z", 18.0, 7.85, 10.15, 0.0, HALL_PARAPET, CORE_T, "wall", []],
	["X18Bay", "z", 18.0, 10.15, 31.8, 0.0, BAY_PARAPET, EXT_T, "wall", []],
	["Z8Office", "x", 8.0, 0.2, 17.85, 0.0, OFFICE_PARAPET, CORE_T, "wall", []],
	# Hall / cold store (z 10): the high-bay north wall above the hall roof (mural band 6.6-9.0).
	["Z10Bay", "x", 10.0, 18.2, 47.8, 0.0, BAY_PARAPET, CORE_T, "wall", []],
	# Stair core ST (0.3 m) up to the head-house roof.
	["CoreX3", "z", 3.0, 0.2, 6.15, 0.0, HH_TOP, CORE_T, "wall", []],
	["CoreZ6", "x", 6.0, 0.2, 2.85, 0.0, HH_TOP, CORE_T, "wall", []],
	# Office ground floor. PO-7: G_X9 / M_X9 run to the z 6 wall's face (5.9); 5.85 left a 5 cm
	# see-through corner slit.
	["G_X9", "z", 9.0, 0.2, 5.9, 0.0, OFFICE_CEIL, INT_T, "wall", []],
	["G_Z6", "x", 6.0, 3.15, 17.85, 0.0, OFFICE_CEIL, INT_T, "wall", []],
	# Goods lift shaft LF (x 15-18, z 0-3) to the mezzanine ceiling; west hatch at the mezzanine.
	["ShaftX15", "z", 15.0, 0.2, 2.9, 0.0, MEZZ_CEIL, INT_T, "wall", [[0.9, 2.1, MEZZ + 0.45, MEZZ + 1.25]]],
	["ShaftZ3", "x", 3.0, 14.9, 17.85, 0.0, MEZZ_CEIL, INT_T, "wall", []],
	["G_X15S", "z", 15.0, 3.1, 5.9, 0.0, OFFICE_CEIL, INT_T, "wall", []],
	# Mezzanine.
	["M_X9", "z", 9.0, 0.2, 5.9, MEZZ, MEZZ_CEIL, INT_T, "wall", []],
	["M_X15S", "z", 15.0, 3.1, 5.9, MEZZ, MEZZ_CEIL, INT_T, "wall", []],
	["M_Z6", "x", 6.0, 3.15, 17.85, MEZZ, MEZZ_CEIL, INT_T, "wall", []],
	# West wing (walls up to the wing roof slab, 5.5).
	["W_X10", "z", 10.0, 8.15, 17.9, 0.0, 5.5, INT_T, "wall", []],
	["W_Z18", "x", 18.0, 0.2, 17.8, 0.0, 5.5, INT_T, "wall", []],
	["LK_X5", "z", 5.0, 18.1, 22.9, 0.0, SMALL_CEIL, INT_T, "wall", []],
	["J_X8", "z", 8.0, 18.1, 20.9, 0.0, SMALL_CEIL, INT_T, "wall", []],
	["J_Z21", "x", 21.0, 5.1, 8.1, 0.0, SMALL_CEIL, INT_T, "wall", []],
	["LK_Z23", "x", 23.0, 0.2, 5.1, 0.0, SMALL_CEIL, INT_T, "wall", []],
	# Cold store insulated panels (0.2) to the 8.0 ceiling; strongroom walls 0.4 (reinforced).
	["Panel_X32", "z", 32.0, 10.15, 23.9, 0.0, BAY_CEIL, INT_T, "panel", []],
	["Panel_X35", "z", 35.0, 10.15, 23.9, 0.0, BAY_CEIL, INT_T, "panel", []],
	["SR_Z24", "x", 24.0, 18.2, 26.2, 0.0, BAY_CEIL, EXT_T, "panel", []],
	["Panel_Z24", "x", 24.0, 26.2, 47.8, 0.0, BAY_CEIL, INT_T, "panel", [[32.1, 34.9, 0.0, 4.0]]],
	["SR_X26", "z", 26.0, 24.2, 31.8, 0.0, AN_CEIL, EXT_T, "panel", []],
]

## Openings without a door: the spine-aisle strip curtains (walkable, block LOS; visual only).
## Z10Bay's north portal is added here: [wall name, opening].
const PORTALS: Array = [["Z10Bay", [32.1, 34.9, 0.0, 4.0]]]
## Strip curtains (visual only, no collision): [name, box].
const STRIP_CURTAINS: Array = [
	["StripCurtainN", [32.1, 0.0, 9.98, 34.9, 4.0, 10.02]],
	["StripCurtainS", [32.1, 0.0, 23.98, 34.9, 4.0, 24.02]],
]

## Slabs and roofs: [name, box, material].
const SLABS: Array = [
	# Mezzanine slab (office block minus stair core ST and the lift shaft LF) + the core landings.
	["MezzSlabA", [3.15, MEZZ_SLAB, 0.2, 14.9, MEZZ, 7.85], "floor"],
	["MezzSlabB", [14.9, MEZZ_SLAB, 3.1, 17.85, MEZZ, 7.85], "floor"],
	["MezzSlabC", [0.2, MEZZ_SLAB, 6.15, 3.15, MEZZ, 7.85], "floor"],
	["RoofSlabA", [3.15, ROOF_SLAB, 0.2, 17.85, ROOF, 7.85], "roof"],
	["RoofSlabB", [0.2, ROOF_SLAB, 6.15, 3.15, ROOF, 7.85], "roof"],
	["LiftShaftCap", [15.1, MEZZ_CEIL, 0.2, 17.85, ROOF_SLAB, 2.9], "ceiling"],
	["HeadHouseRoof", [-0.2, HH_CEIL, -0.2, 3.15, HH_TOP, 6.15], "roof"],
	["HallRoof", [18.15, 6.3, 0.2, 47.8, HALL_ROOF, 9.85], "roof"],
	["WingRoof", [0.2, 5.5, 8.15, 17.8, WING_ROOF, 31.8], "roof"],
	["BayRoof", [18.2, 8.7, 10.15, 47.8, BAY_ROOF, 31.8], "roof"],
	# Strongroom roof (vault ceiling 3.5, 0.3 m reinforced).
	["StrongroomRoof", [18.2, SR_CEIL, 24.2, 25.8, SR_CEIL + 0.3, 31.8], "concrete"],
]

## Ceilings (0.05 m, underside at the room ceiling height): [name, box].
const CEILINGS: Array = [
	["CeilOfficeG", [3.15, OFFICE_CEIL, 0.2, 17.85, OFFICE_CEIL + 0.05, 7.85]],
	["CeilOCWest", [0.2, OFFICE_CEIL, 6.15, 3.15, OFFICE_CEIL + 0.05, 7.85]],
	["CeilOfficeM", [3.15, MEZZ_CEIL, 3.1, 17.85, MEZZ_CEIL + 0.05, 7.85]],
	["CeilOfficeMN", [3.15, MEZZ_CEIL, 0.2, 14.9, MEZZ_CEIL + 0.05, 3.1]],
	["CeilMCWest", [0.2, MEZZ_CEIL, 6.15, 3.15, MEZZ_CEIL + 0.05, 7.85]],
	["CeilPlantWorkshop", [0.2, PLANT_CEIL, 8.15, 17.8, PLANT_CEIL + 0.05, 17.9]],
	["CeilPacking", [0.2, PACK_CEIL, 18.1, 17.8, PACK_CEIL + 0.05, 31.8]],
	["CeilLockers", [0.2, SMALL_CEIL, 18.1, 5.1, SMALL_CEIL + 0.05, 22.9]],
	["CeilJanitor", [5.1, SMALL_CEIL, 18.1, 7.9, SMALL_CEIL + 0.05, 20.9]],
	["CeilHall", [18.15, HALL_CEIL, 0.2, 47.8, HALL_CEIL + 0.05, 9.85]],
	["CeilBay", [18.2, BAY_CEIL, 10.15, 47.8, BAY_CEIL + 0.05, 23.8]],
	["CeilAnteroom", [26.2, AN_CEIL, 24.1, 47.8, AN_CEIL + 0.05, 31.8]],
]

## Static glazing: [name, axis, fixed, a0, a1, y0, y1] (glass blocker + pane + head frame).
const GLAZING: Array = [
	["O1WindowW", "x", 0.0, 3.6, 4.8, 0.9, 2.1], ["O1WindowE", "x", 0.0, 7.2, 8.4, 0.9, 2.1],
	["O2WindowW", "x", 0.0, 9.9, 11.1, 0.9, 2.1], ["O2WindowE", "x", 0.0, 12.9, 14.1, 0.9, 2.1],
	["M2WindowW", "x", 0.0, 3.6, 4.8, MEZZ + 0.9, MEZZ + 2.1], ["M2WindowE", "x", 0.0, 7.2, 8.4, MEZZ + 0.9, MEZZ + 2.1],
	["M1WindowW", "x", 0.0, 9.9, 11.1, MEZZ + 0.9, MEZZ + 2.1], ["M1WindowE", "x", 0.0, 12.9, 14.1, MEZZ + 0.9, MEZZ + 2.1],
	["HallClerestory", "x", 0.0, 18.6, 47.4, 4.8, 5.5],
	["GatehouseWindow", "z", 30.0, -31.2, -28.8, 0.9, 2.1],
	["NetStoreWindow", "x", 40.0, 14.5, 17.5, 0.9, 2.1],
]

## Hall platform PF (x 18-22, z 0-8, deck 3.3-3.6) on three columns along x 21.85.
const PLATFORM: Dictionary = {
	"deck": [18.15, MEZZ_SLAB, 0.2, 22.0, MEZZ, 8.0],
	"columns": [Vector2(21.85, 0.45), Vector2(21.85, 3.6), Vector2(21.85, 6.6)],
}

## Railings (Geometry: collision panel + rails/posts, kind railing): [name, box]. Top 1.05 above the
## floor they stand on.
const RAILINGS: Array = [
	# Hall platform: east edge (up to the stair head) and south edge.
	["RailPFEast", [21.95, MEZZ, 0.2, 22.0, MEZZ + 1.05, 6.8]],
	["RailPFSouth", [18.15, MEZZ, 7.95, 22.0, MEZZ + 1.05, 8.0]],
	# Fire-stair landing (MC west door, +3.6): west and south edges.
	["RailFireLandingW", [-1.45, MEZZ, 6.0, -1.4, MEZZ + 1.05, 8.0]],
	["RailFireLandingS", [-1.45, MEZZ, 7.95, -0.2, MEZZ + 1.05, 8.0]],
	# Quay edge (z 44), open at the pontoon ramp (x 23-25) and the quay-steps recess (x 56-58).
	["RailQuayW", [-8.0, 0.0, 43.95, 22.9, 1.05, 44.0]],
	["RailQuayMid", [25.1, 0.0, 43.95, 55.9, 1.05, 44.0]],
	["RailQuayE", [58.1, 0.0, 43.95, 62.0, 1.05, 44.0]],
	# Guards round the quay-steps recess top.
	["RailRecessW", [55.9, 0.0, 40.3, 56.0, 1.05, 43.95]],
	["RailRecessE", [58.0, 0.0, 40.3, 58.1, 1.05, 43.95]],
	# Apron edge on the slip (x 62), open at the gangway (z -14.6..-11.4).
	["RailApronN", [62.0, 0.0, -32.0, 62.05, 1.05, -14.6]],
	["RailApronS", [62.0, 0.0, -11.4, 62.05, 1.05, 43.95]],
	["RailSlipHead", [62.05, 0.0, -32.05, 72.0, 1.05, -32.0]],
	# Pier 10 edge on the slip (x 72), open at the gangway; Pier 10 harbour edge.
	["RailPier10N", [71.95, 0.0, -32.0, 72.0, 1.05, -14.6]],
	["RailPier10S", [71.95, 0.0, -11.4, 72.0, 1.05, 43.95]],
	["RailPier10Quay", [72.0, 0.0, 43.95, 84.0, 1.05, 44.0]],
	# Pontoon (16 x 4 at -1.8): west, east and north (except the ramp); the launch closes the south.
	["RailPontoonW", [16.0, LAND, 50.0, 16.05, LAND + 1.05, 54.0]],
	["RailPontoonE", [31.95, LAND, 50.0, 32.0, LAND + 1.05, 54.0]],
	["RailPontoonNW", [16.05, LAND, 50.0, 22.9, LAND + 1.05, 50.05]],
	["RailPontoonNE", [25.1, LAND, 50.0, 31.95, LAND + 1.05, 50.05]],
	# Landing stage (x 52-62, z 44-48 at -1.8): water sides.
	["RailStageW", [52.0, LAND, 44.0, 52.05, LAND + 1.05, 48.0]],
	["RailStageS", [52.05, LAND, 47.95, 59.15, LAND + 1.05, 48.0]],
]

## Pontoon ramp (quay 0.0 -> pontoon -1.8 over 6 m, 16.7 deg): x 23-25, z 44-50; guard panels
## (Geometry, sloped tops via a full-height panel) both sides.
const RAMP: Dictionary = {"x": [23.0, 25.0], "z": [44.0, 50.0], "y": [0.0, LAND], "t": 0.3}


# --- Vertical circulation ----------------------------------------------------------------------

## Stair core ST (doc vertical data): 3 x 6 m on centre lines, 0.3 m walls (clear x 0.15..2.85,
## z 0.15..5.85). Every up-flight starts at z 4.53 (west half, rising north); the half landing at
## the north end; the return flight (east half) rises south to the floor landing (z 4.53-5.85).
## 2 x 10 risers @ 0.18 per 3.6 m storey, tread 0.28 (Shadow Ledger core, same dimensions).
const STAIR_CORE: Dictionary = {"x0": 0.0, "levels": [0.0, MEZZ, ROOF]}
const STAIR_Z_START: float = 4.53
const STAIR_Z_N: float = 0.15
const STAIR_Z_S: float = 5.85
const STAIR_TREAD: float = 0.28
const STAIR_RISER: float = 0.18
## Flight / well offsets from the core's x0: west flight, divider (well), east flight, clear width.
const STAIR_WEST: Vector2 = Vector2(0.2, 1.4)
const STAIR_WELL: Vector2 = Vector2(1.4, 1.6)
const STAIR_EAST: Vector2 = Vector2(1.6, 2.8)
const STAIR_CLEAR: Vector2 = Vector2(0.15, 2.85)
## Handrails (level_standards §2 MUST 1.0-1.1 m open / 0.85-1.1 wall): bar centre above the
## riser-to-riser nosing line (top 1.05 m), offset from the wall / guard face.
const HANDRAIL_H: float = 1.025
const HANDRAIL_OFF: float = 0.07
## Straight two-flight stairs with a mid landing: [name, bottom riser line (x, y, z), yaw (local +Z =
## the rising direction; -90 = rising west, 0 = rising south, 180 = rising north), width, risers per
## flight, tread, landing length, guard sides (["L", "R"] = open sides needing 1.05 guards, local
## -X / +X), solid base y (null = posts only)].
const STRAIGHT_STAIRS: Array = [
	# Hall platform stair: hall floor (x 28.24) -> platform (x 22.0, +3.6), z 6.8-8.0, open both sides.
	["PlatformStair", Vector3(28.24, 0.0, 7.4), -90.0, 1.2, 10, 0.28, 1.2, ["L", "R"], 0.0],
	# External fire stair (west face): ground (z -0.24) -> the MC landing (z 6.0, +3.6), x -1.4..-0.2;
	# the building wall on its east (local +X), open west (local -X).
	["FireStair", Vector3(-0.8, 0.0, -0.24), 0.0, 1.2, 10, 0.28, 1.2, ["L"], 0.0],
]
## Fire-stair top landing (MC west door): slab + two posts.
const FIRE_LANDING: Array = [-1.4, MEZZ_SLAB, 6.0, -0.2, MEZZ, 8.0]
## Quay steps (-1.8 -> 0.0): one flight, 10 risers x 0.18, 9 treads x 0.30, 2.0 m wide, in the
## recess x 56-58 (z 40.3-43.0), walls both sides, the recess floor z 43-44 at -1.8.
const QUAY_STEPS: Dictionary = {"origin": Vector3(57.0, LAND, 43.0), "yaw": 180.0, "w": 2.0, "risers": 10, "tread": 0.3}

## Goods lift LF (bags only, 2 bags / 8 s): the car stands at the east hatch on the ground floor
## (landing 0, front -Z east into the hall under the platform) and at the west hatch on the
## mezzanine (landing 1, front west into M1). Hatches 1.2 x 0.8 (sill 0.45): too low for the crew.
const LIFT: Dictionary = {
	"car0": Vector3(17.2, 0.05, 1.5), "yaw0": -90.0, "car1": Vector3(15.8, MEZZ + 0.05, 1.5), "yaw1": 90.0,
	"panel_y": 1.45, "use0": Vector3(18.9, 0.0, 1.5), "use1": Vector3(14.1, MEZZ, 1.5),
}


# --- Doors --------------------------------------------------------------------------------------

## Doors: [name, type (DOOR_OPENINGS key) + "_t20" / "_t40" for kit doors, origin (bottom-centre of
## the opening on the wall line), yaw_deg (front -Z = UsePoint side = corridor / outside), lock,
## swing, objective_tag, extra]. INWARD leaves swing to the back (+Z) side, into the room.
## Yaw: 0 = front north (-z), 180 = south (+z), 90 = west (-x), -90 = east (+x).
## extra: service / fire_exit (meta), width_m, padlock (seconds: a placed-saw drill_point on the lock,
## SAW_TARGET, D-057 / QC-37), shutter (fire shutter of a product room), entry (police ENTRY tag).
## D-111: the moored launch visual (catalog veh_boat_launch, pivot = keel bottom, deck 1.0 m above): [asset, pivot, yaw].
const LAUNCH: Array = ["veh_boat_launch", Vector3(23.5, -2.6, 55.5), 0.0]
const DOORS: Array = [
	# Office block, ground.
	["O1Front", "single_t40", Vector3(6.0, 0.0, 0.0), 0.0, "LOCKPICK", "INWARD", "door_office", {}],
	["O1Corridor", "single_t20", Vector3(4.0, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["O2Corridor", "single_t20", Vector3(12.0, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["E1Corridor", "single_t20", Vector3(16.5, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["StairGround", "service_t20", Vector3(1.5, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {"service": true}],
	["OCWest", "single_t40", Vector3(0.0, 0.0, 7.0), 90.0, "LOCKPICK", "INWARD", "oc_west_door", {"fire_exit": true}],
	["OCHall", "service_t20", Vector3(18.0, 0.0, 7.0), 90.0, "NONE", "INWARD", "", {"service": true}],
	["PLCorridor", "single_t20", Vector3(4.0, 0.0, 8.0), 0.0, "NONE", "INWARD", "", {}],
	["WSCorridor", "single_t20", Vector3(14.0, 0.0, 8.0), 0.0, "NONE", "INWARD", "", {}],
	["WSHall", "service_t20", Vector3(18.0, 0.0, 9.0), -90.0, "NONE", "INWARD", "", {"service": true}],
	["PLWorkshop", "single_t20", Vector3(10.0, 0.0, 13.0), 90.0, "NONE", "INWARD", "", {}],
	["PLWest", "single_t40", Vector3(0.0, 0.0, 14.0), 90.0, "LOCKPICK", "INWARD", "pl_west_door", {}],
	["PKPlant", "single_t20", Vector3(9.0, 0.0, 18.0), 180.0, "NONE", "INWARD", "", {"shutter": "prod_packing"}],
	["PKWorkshop", "single_t20", Vector3(14.0, 0.0, 18.0), 180.0, "NONE", "INWARD", "", {"shutter": "prod_packing"}],
	["Janitor", "single_t20", Vector3(7.0, 0.0, 21.0), 180.0, "NONE", "INWARD", "", {}],
	["Lockers", "single_t20", Vector3(5.0, 0.0, 22.0), -90.0, "NONE", "INWARD", "", {}],
	["PKRoller", "roller", Vector3(7.8, 0.0, 32.0), 180.0, "BARRED", "DOUBLE", "pk_roller",
		{"padlock": 30.0, "shutter": "prod_packing"}],
	["PKQuay", "single_t40", Vector3(12.0, 0.0, 32.0), 180.0, "LOCKPICK", "INWARD", "pk_quay_door", {"shutter": "prod_packing"}],
	# Cold store: sliding doors (fire shutters of the product rooms).
	["PKChamberA", "slide", Vector3(18.0, 0.0, 21.2), 90.0, "NONE", "DOUBLE", "", {"shutter": "prod_chamber_a|prod_packing"}],
	["ChamberANorth", "slide", Vector3(24.2, 0.0, 10.0), 0.0, "NONE", "DOUBLE", "", {"shutter": "prod_chamber_a"}],
	["ChamberASpine", "slide", Vector3(32.0, 0.0, 16.2), -90.0, "NONE", "DOUBLE", "", {"shutter": "prod_chamber_a"}],
	["SpineChamberB", "slide", Vector3(35.0, 0.0, 19.2), 90.0, "NONE", "DOUBLE", "", {"shutter": "prod_chamber_b"}],
	["ChamberBNorth", "slide", Vector3(41.2, 0.0, 10.0), 0.0, "NONE", "DOUBLE", "", {"shutter": "prod_chamber_b"}],
	["ChamberBSouth", "slide", Vector3(41.2, 0.0, 24.0), 180.0, "NONE", "DOUBLE", "", {"shutter": "prod_chamber_b"}],
	# Strongroom vault door (thermal drill, doc 2.0 x 2.2).
	["StrongroomDoor", "vault", Vector3(26.0, 0.0, 28.0), -90.0, "VAULT", "INWARD", "strongroom_door", {"width_m": 2.0}],
	# Anteroom (quay dock).
	["ANRollerW", "roller", Vector3(30.8, 0.0, 32.0), 180.0, "BARRED", "DOUBLE", "an_roller", {"padlock": 30.0}],
	["ANRollerE", "roller", Vector3(40.8, 0.0, 32.0), 180.0, "BARRED", "DOUBLE", "an_roller", {"padlock": 30.0}],
	["ANQuay", "single_t40", Vector3(46.0, 0.0, 32.0), 180.0, "LOCKPICK", "INWARD", "door_quay", {}],
	["ANEast", "single_t40", Vector3(48.0, 0.0, 28.0), -90.0, "LOCKPICK", "INWARD", "an_east_door", {}],
	# Marshalling hall roller doors (yard) and the apron dock door.
	["HallRoller1", "roller", Vector3(25.8, 0.0, 0.0), 0.0, "BARRED", "DOUBLE", "hall_roller", {"padlock": 30.0}],
	["HallRoller2", "roller", Vector3(33.8, 0.0, 0.0), 0.0, "BARRED", "DOUBLE", "hall_roller", {"padlock": 30.0}],
	["HallRoller3", "roller", Vector3(41.8, 0.0, 0.0), 0.0, "BARRED", "DOUBLE", "hall_roller", {"padlock": 30.0}],
	["DockRoller", "roller", Vector3(48.0, 0.0, 4.8), -90.0, "BARRED", "DOUBLE", "door_dock", {"padlock": 30.0}],
	# Mezzanine.
	["StairMezz", "service_t20", Vector3(1.5, MEZZ, 6.0), 180.0, "NONE", "INWARD", "", {"service": true}],
	["M2Corridor", "single_t20", Vector3(6.0, MEZZ, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["M1Corridor", "single_t20", Vector3(12.0, MEZZ, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["M3Corridor", "single_t20", Vector3(16.5, MEZZ, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["MCWest", "single_t40", Vector3(0.0, MEZZ, 7.0), 90.0, "LOCKPICK", "INWARD", "mc_west_door", {"fire_exit": true}],
	["MCPlatform", "single_t20", Vector3(18.0, MEZZ, 7.0), 90.0, "NONE", "INWARD", "", {}],
	# Roof head house (player perch: `perch_roof` unlocks it; else LOCKPICK 8 s).
	["RoofDoor", "service_t20", Vector3(1.5, ROOF, 6.0), 180.0, "LOCKPICK", "INWARD", "roof_door", {"service": true}],
	# Gatehouse and the quay net store.
	["GatehouseNorth", "single_t20", Vector3(27.0, 0.0, -32.0), 0.0, "NONE", "INWARD", "", {}],
	["GatehouseSouth", "single_t20", Vector3(27.0, 0.0, -28.0), 180.0, "NONE", "INWARD", "", {}],
	["NetStoreWest", "single_t20", Vector3(12.0, 0.0, 37.0), 90.0, "NONE", "INWARD", "", {}],
	["NetStoreEast", "single_t20", Vector3(20.0, 0.0, 37.0), -90.0, "NONE", "INWARD", "", {}],
	# Play-space closures: chained / barred gates the police breach (mission opens them on arrival).
	["LaneManGate", "single_t20", Vector3(-4.0, 0.0, -34.0), 0.0, "BARRED", "INWARD", "police_gate", {}],
	["BellweatherGate", "single_t20", Vector3(-8.0, 0.0, -14.0), 90.0, "BARRED", "INWARD", "police_gate", {}],
	["FerroWestGate", "double_t20", Vector3(-12.0, 0.0, -43.0), 90.0, "BARRED", "DOUBLE", "police_gate", {}],
	["FerroEastGate", "double_t20", Vector3(66.0, 0.0, -43.0), -90.0, "BARRED", "DOUBLE", "police_gate", {}],
	["Pier10Gate", "double_t20", Vector3(84.0, 0.0, -14.0), -90.0, "BARRED", "DOUBLE", "police_gate", {}],
]

## Fire shutters (doc Loud): product slot -> the doors the mission closes and bars after the burn.
const SHUTTERS: Dictionary = {
	"prod_chamber_a": ["ChamberANorth", "PKChamberA", "ChamberASpine"],
	"prod_chamber_b": ["ChamberBNorth", "SpineChamberB", "ChamberBSouth"],
	"prod_packing": ["PKChamberA", "PKRoller", "PKQuay", "PKPlant", "PKWorkshop"],
}


# --- Small buildings (gatehouse GH, quay net store QS, P4 harbour shed) -----------------------

## [name, x0, z0, x1, z1, floor y, wall top, roof thickness, wall thickness, open sides ("N", "S",
## "W", "E")]. Doors and windows on their walls come from DOORS / GLAZING.
const SHEDS: Array = [
	["Gatehouse", 24.0, -32.0, 30.0, -28.0, 0.0, 2.7, 0.3, 0.3, []],
	["NetStore", 12.0, 34.0, 20.0, 40.0, 0.0, 3.0, 0.3, 0.3, []],
	["HarbourShed", 59.2, 44.6, 62.0, 47.8, LAND, LAND + 2.6, 0.2, 0.2, ["W"]],
]


# --- Site -----------------------------------------------------------------------------------

## Walkable ground (top 0.0 unless stated): [name, box, material]. The Pier 9 deck is split round the
## quay-steps recess (x 56-58, z 40.3-44).
const GROUND: Array = [
	["Pier9", [-8.0, -2.6, -34.0, 56.0, 0.0, 44.0], "concrete"],
	["Pier9Recess", [56.0, -2.6, -34.0, 58.0, 0.0, 40.3], "concrete"],
	["Pier9East", [58.0, -2.6, -34.0, 62.0, 0.0, 44.0], "concrete"],
	["SlipHead", [62.0, -2.6, -34.0, 72.0, 0.0, -32.0], "concrete"],
	["RecessFloor", [56.0, -2.6, 43.0, 58.0, LAND, 44.0], "concrete"],
	["Pier10", [72.0, -2.6, -34.0, 100.0, 0.0, 44.0], "concrete"],
	["FerroStreet", [-70.0, -0.3, -58.0, 150.0, 0.0, -34.0], "asphalt"],
	["Bellweather", [-40.0, -0.3, -34.0, -8.0, 0.0, 44.0], "paving"],
	["LandingStage", [52.0, -2.1, 44.0, 62.0, LAND, 48.0], "deck"],
	["Pontoon", [16.0, -2.1, 50.0, 32.0, LAND, 54.0], "deck"],
	["Seabed", [-60.0, -9.0, 44.0, 140.0, -8.0, 200.0], "none"],
	["SlipBed", [62.0, -9.0, -32.0, 72.0, -8.0, 44.0], "none"],
]

## Water (visual only; the OUT_OF_BOUNDS zones sit under its surface): harbour and slip.
const WATER: Array = [
	["HarbourWater", [-200.0, WATER_Y - 0.05, 44.0, 250.0, WATER_Y, 420.0]],
	["SlipWater", [62.0, WATER_Y - 0.05, -32.0, 72.0, WATER_Y, 44.0]],
]

## Neighbour / dressing blocks (solid massing): [name, box, material(, "ridge": ridged collider top)].
const BLOCKS: Array = [
	# Bellweather Ice Co. (west): north shed, main building (roof +8.0, parapet 9.0), west block.
	["BellweatherShed", [-30.0, -0.3, -32.0, -10.0, 6.0, -18.0], "facade_a"],
	["BellweatherMain", [-30.0, -0.3, -10.0, -10.0, 8.0, 40.0], "facade_b"],
	["BellweatherParapetS", [-30.0, 8.0, 39.7, -10.0, 9.0, 40.0], "facade_b"],
	["BellweatherParapetE", [-10.3, 8.0, -10.0, -10.0, 9.0, 40.0], "facade_b"],
	["BellweatherRoofPlant", [-26.0, 8.0, 10.0, -16.0, 10.5, 24.0], "trim"],
	["BellweatherWest", [-60.0, -0.3, -34.0, -30.0, 9.0, 44.0], "brick"],
	# Rail viaduct over Ferro Street (deck +7.0, walkway parapet) and its piers on the north kerb.
	["ViaductDeck", [-70.0, 6.2, -58.0, 150.0, 7.0, -50.0], "concrete"],
	["ViaductParapet", [-70.0, 7.0, -50.2, 150.0, 8.1, -50.0], "concrete"],
	["NextBlockBacks", [-70.0, -0.3, -80.0, 150.0, 9.0, -58.5], "brick"],
	["FerroWestVista", [-80.0, -0.3, -58.0, -70.0, 12.0, -34.0], "facade_c"],
	["FerroEastVista", [150.0, -0.3, -58.0, 160.0, 12.0, -34.0], "facade_c"],
	# Ferro Street closures: semi-trailers under the viaduct (west) and the reefer truck (east).
	["SemiTrailerN", [-17.0, 0.0, -51.6, -12.2, 4.0, -48.6], "container"],
	["SemiTrailerS", [-17.0, 0.0, -39.6, -12.2, 4.0, -36.6], "container"],
	["ReeferTruck", [66.2, 0.0, -51.0, 71.0, 4.0, -46.5], "vehicle"],
	["EastBlockFerro", [84.0, -0.3, -34.0, 150.0, 9.0, -33.0], "brick"],
	# Pier 10 container terminal: stacks (4 high, 10.4 m) behind the hoarding, the gantry crane.
	["StacksNorth", [88.0, 0.0, -34.0, 100.0, 10.4, -18.0], "container"],
	["StacksSouth", [88.0, 0.0, -10.0, 100.0, 10.4, 44.0], "container"],
	["StacksBack", [100.0, -0.3, -34.0, 120.0, 10.4, 44.0], "container"],
	["CraneLegNW", [73.5, 0.0, -8.5, 74.5, 22.0, -7.5], "crane"],
	["CraneLegNE", [79.5, 0.0, -8.5, 80.5, 22.0, -7.5], "crane"],
	["CraneLegSW", [73.5, 0.0, 7.5, 74.5, 22.0, 8.5], "crane"],
	["CraneLegSE", [79.5, 0.0, 7.5, 80.5, 22.0, 8.5], "crane"],
	["CranePortalN", [73.5, 20.0, -8.5, 80.5, 22.0, -7.5], "crane"],
	["CranePortalS", [73.5, 20.0, 7.5, 80.5, 22.0, 8.5], "crane"],
	["CraneGirderW", [73.5, 21.0, -8.5, 74.5, 22.0, 8.5], "crane"],
	["CraneGirderE", [79.5, 21.0, -8.5, 80.5, 22.0, 8.5], "crane"],
	["CraneCab", [76.5, 22.0, -2.0, 81.0, 22.2, 2.0], "crane"],
	["CraneCabRoof", [76.5, 24.6, -2.0, 81.0, 24.8, 2.0], "crane"],
	["CraneCabBack", [80.8, 22.2, -2.0, 81.0, 24.6, 2.0], "crane"],
	["CraneBoom", [56.0, 25.6, -1.0, 110.0, 26.6, 1.0], "crane"],
	# Harbour: the moored trawler east of the landing stage (S4 wheelhouse), the far shore.
	["TrawlerHull", [63.0, -3.4, 48.6, 80.0, 0.5, 53.0], "vehicle"],
	["TrawlerWheelhouse", [68.0, 0.5, 49.6, 72.0, 4.0, 52.0], "vehicle"],
	["TrawlerMast", [74.8, 0.5, 50.6, 75.2, 9.0, 51.0], "trim"],
	["FarShore", [-200.0, WATER_Y, 400.0, 250.0, 8.0, 410.0], "facade_c"],
	# The Co-op launch (escape E3) moored along the pontoon: walkable deck at -1.6. D-111: the catalog `veh_boat_launch`
	# (LAUNCH, 9 x 3 m, deck 1.0 m over its keel, its quay side on the pontoon edge z 54) is the visual; these are its
	# hidden colliders (ND pattern): the hull block under the deck, the cabin block, and the harbour-side gunwale cap
	# (ridged, D-104 slopes).
	["LaunchHull", [19.0, -3.2, 54.0, 28.0, -1.6, 57.0], "none"],
	["LaunchGunwale", [19.1, -1.6, 56.89, 25.8, -1.48, 56.99], "none", "ridge"],
	["LaunchCabin", [25.0, -1.6, 54.8, 27.6, 0.4, 56.6], "none"],
	# High-bay roof plant: evaporator condensers (vapour plumes, landmark 3) and the skylights.
	["CondenserA", [24.0, BAY_ROOF, 27.0, 30.0, BAY_ROOF + 2.2, 30.0], "trim"],
	["CondenserB", [36.0, BAY_ROOF, 27.0, 42.0, BAY_ROOF + 2.2, 30.0], "trim"],
	["SkylightC1", [23.5, BAY_ROOF, 15.5, 26.5, BAY_ROOF + 0.4, 18.5], "glass"],
	["SkylightSP", [32.5, BAY_ROOF, 15.5, 34.5, BAY_ROOF + 0.4, 18.5], "glass"],
	["SkylightC2", [39.5, BAY_ROOF, 15.5, 42.5, BAY_ROOF + 0.4, 18.5], "glass"],
	# Office roof plant (HVAC).
	["RoofHVACA", [6.5, ROOF, 2.0, 9.0, ROOF + 1.5, 3.6], "trim"],
	["RoofHVACB", [11.5, ROOF, 2.0, 14.0, ROOF + 1.5, 3.6], "trim"],
]

## Fences and closures (2.4 m solid corrugated steel / hoarding, Geometry): [name, axis, fixed, from,
## to, y0, y1, extra openings, material]. Gate openings come from DOORS; the yard gate (x 30-38) is
## an open slide gate.
const FENCES: Array = [
	["NorthFenceW", "x", -34.0, -8.0, 30.0, 0.0, 2.4, [], "fence"],
	["NorthFenceE", "x", -34.0, 38.0, 84.0, 0.0, 2.4, [], "fence"],
	["LaneFence", "z", -8.0, -34.0, 43.95, 0.0, 2.4, [], "fence"],
	["BellweatherFrontage", "x", -34.0, -40.0, -8.0, 0.0, 2.4, [], "fence"],
	["FerroWestClosure", "z", -12.0, -58.0, -34.0, 0.0, 2.4, [], "barrier"],
	["FerroEastClosure", "z", 66.0, -58.0, -34.0, 0.0, 2.4, [], "barrier"],
	["ViaductPalisade", "x", -52.0, -12.0, 66.0, 0.0, 2.4, [], "fence"],
	["Pier10Hoarding", "z", 84.0, -34.0, 44.0, 0.0, 2.4, [], "fence"],
	["Pier10North", "x", -34.0, 84.0, 88.0, 0.0, 2.4, [], "fence"],
]

## The yard gate's open slide leaf (parked against the fence east of the opening) and the gatehouse
## weighbridge plate (visual, flush).
const GATE_LEAF: Array = [38.1, 0.0, -34.6, 46.0, 2.2, -34.45]
const WEIGHBRIDGE: Array = [30.0, 0.0, -32.0, 38.0, 0.02, -18.0]


# --- Props (gameplay-relevant blockers; placeholder boxes) ----------------------------------

## [name, bottom-centre (x, y, z), size (x, y, z) before yaw, yaw_deg, kind, support, material].
const PROPS: Array = [
	# O1 reception
	["ReceptionCounter", Vector3(6.0, 0.0, 3.2), Vector3(3.0, 0.9, 0.6), 0.0, "counter_service", true, "counter"],
	["WaitingBench", Vector3(8.45, 0.0, 1.6), Vector3(0.45, 0.45, 1.6), 0.0, "bench", false, "prop"],
	# O2 dispatch / security
	["DispatchDesk", Vector3(12.0, 0.0, 1.0), Vector3(2.4, 0.75, 0.8), 0.0, "desk", true, "prop"],
	["GunLocker", Vector3(14.6, 0.0, 3.2), Vector3(0.5, 1.9, 1.2), 0.0, "locker", false, "trim"],
	# E1 electrical
	["Switchboard", Vector3(16.0, 0.0, 3.4), Vector3(1.6, 2.0, 0.4), 0.0, "switchboard", false, "trim"],
	# M2 break room
	["BreakTable", Vector3(6.0, MEZZ, 2.8), Vector3(1.6, 0.75, 0.9), 0.0, "table", true, "prop"],
	["BreakCounter", Vector3(4.4, MEZZ, 0.5), Vector3(2.2, 0.9, 0.6), 0.0, "counter_service", true, "counter"],
	["Fridge", Vector3(8.4, MEZZ, 0.55), Vector3(0.7, 1.8, 0.7), 0.0, "fridge", false, "trim"],
	# M1 count room
	# PO-9: 0.35 m east, clear of the CageCashA UsePoint (10.4, 2.1)
	["CountingTable", Vector3(11.85, MEZZ, 2.6), Vector3(2.4, 0.9, 1.0), 0.0, "counter_service", true, "counter"],
	# M3 restroom
	["Toilet", Vector3(16.5, MEZZ, 3.45), Vector3(0.4, 0.8, 0.6), 0.0, "toilet", false, "prop"],
	["Sink", Vector3(17.6, MEZZ, 4.6), Vector3(0.5, 0.85, 0.5), 0.0, "sink", false, "prop"],
	# PF platform (foreman's desk)
	["ForemanDesk", Vector3(19.4, MEZZ, 1.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	# PL plant: screw compressors, receiver vessel, control panel
	["CompressorA", Vector3(2.0, 0.0, 11.0), Vector3(1.6, 1.8, 2.6), 0.0, "compressor", false, "trim"],
	["CompressorB", Vector3(5.0, 0.0, 11.0), Vector3(1.6, 1.8, 2.6), 0.0, "compressor", false, "trim"],
	["CompressorC", Vector3(8.0, 0.0, 11.0), Vector3(1.6, 1.8, 2.6), 0.0, "compressor", false, "trim"],
	["ReceiverVessel", Vector3(2.4, 0.0, 16.3), Vector3(3.0, 1.6, 1.2), 0.0, "tank", false, "trim"],
	["ControlPanel", Vector3(5.5, 0.0, 17.6), Vector3(2.0, 2.0, 0.4), 0.0, "control_panel", false, "trim"],
	# WS workshop: forklifts on charge, battery racks, bench
	["ForkliftA", Vector3(13.0, 0.0, 15.3), Vector3(1.2, 2.1, 2.6), 0.0, "forklift", false, "vehicle"],
	["ForkliftB", Vector3(15.6, 0.0, 15.3), Vector3(1.2, 2.1, 2.6), 0.0, "forklift", false, "vehicle"],
	["BatteryRack", Vector3(17.4, 0.0, 11.5), Vector3(0.8, 1.2, 2.4), 0.0, "rack", true, "trim"],
	["ToolBench", Vector3(11.5, 0.0, 17.45), Vector3(2.0, 0.9, 0.7), 0.0, "counter_service", true, "counter"],
	# LK lockers / J janitor
	["StaffLockers", Vector3(0.45, 0.0, 20.5), Vector3(0.5, 1.8, 3.0), 0.0, "locker", false, "trim"],
	["LockerBench", Vector3(2.4, 0.0, 20.5), Vector3(0.4, 0.45, 2.0), 0.0, "bench", false, "prop"],
	["MopSink", Vector3(7.4, 0.0, 18.45), Vector3(0.6, 0.9, 0.5), 0.0, "sink", false, "prop"],
	["JanitorShelf", Vector3(5.4, 0.0, 19.2), Vector3(0.5, 1.8, 1.2), 0.0, "shelf", true, "prop"],
	# PK packing hall
	["PackingConveyor", Vector3(9.0, 0.0, 26.0), Vector3(8.0, 0.9, 1.0), 0.0, "conveyor", true, "counter"],
	["PackingTableA", Vector3(4.0, 0.0, 28.6), Vector3(2.0, 0.9, 0.8), 0.0, "counter_service", true, "counter"],
	["PackingTableB", Vector3(14.5, 0.0, 28.6), Vector3(2.0, 0.9, 0.8), 0.0, "counter_service", true, "counter"],
	["IceMachine", Vector3(16.6, 0.0, 30.6), Vector3(1.4, 1.8, 1.2), 0.0, "ice_machine", false, "trim"],
	["BoxStackA", Vector3(2.0, 0.0, 24.6), Vector3(1.2, 1.5, 1.2), 0.0, "box", false, "prop"],
	["BoxStackB", Vector3(15.8, 0.0, 22.0), Vector3(1.2, 1.5, 1.2), 0.0, "box", false, "prop"],
	# C1 / C2 racking: two back-to-back pairs per chamber (4 racking rows, 3 levels to 6.6 m).
	["RackC1W", Vector3(22.15, 0.0, 17.0), Vector3(2.7, 6.6, 9.2), 0.0, "rack", false, "trim"],
	["RackC1E", Vector3(27.85, 0.0, 17.0), Vector3(2.7, 6.6, 9.2), 0.0, "rack", false, "trim"],
	["RackC2W", Vector3(38.15, 0.0, 17.0), Vector3(2.7, 6.6, 9.2), 0.0, "rack", false, "trim"],
	["RackC2E", Vector3(43.85, 0.0, 17.0), Vector3(2.7, 6.6, 9.2), 0.0, "rack", false, "trim"],
	# SR strongroom shelving (always), AN anteroom pallets, wrapping machine, forklift
	["StrongroomShelf", Vector3(18.6, 0.0, 26.0), Vector3(0.6, 2.0, 2.4), 0.0, "shelf", true, "prop"],
	["ANPalletA", Vector3(30.0, 0.0, 25.4), Vector3(1.2, 1.6, 1.2), 0.0, "pallet_wrapped", false, "prop"],
	["ANPalletB", Vector3(31.4, 0.0, 25.4), Vector3(1.2, 1.6, 1.2), 0.0, "pallet_wrapped", false, "prop"],
	["WrappingMachine", Vector3(38.5, 0.0, 25.6), Vector3(2.0, 2.2, 2.0), 0.0, "wrapping_machine", false, "trim"],
	["ANForklift", Vector3(43.5, 0.0, 28.5), Vector3(1.2, 2.1, 2.6), 90.0, "forklift", false, "vehicle"],
	["ANPalletC", Vector3(46.8, 0.0, 25.4), Vector3(1.2, 1.6, 1.2), 0.0, "pallet_wrapped", false, "prop"],
	["ANPalletD", Vector3(36.0, 0.0, 30.6), Vector3(1.2, 1.6, 1.2), 0.0, "pallet_wrapped", false, "prop"],
	# H loading hall (lead G2 review): an open floor x 28.6-42.4 (13.8 m, the full hall depth) between
	# two crate-cover banks (shipping crates 1.2 m, stacks 1.8 m): west by the platform stair, east by
	# the dock door. HALL_OPEN_FLOOR is asserted by test_dockside_burn_map.
	["HallCrateW1", Vector3(26.9, 0.0, 3.2), Vector3(1.2, 1.2, 1.2), 0.0, "crate", true, "prop"],
	["HallCrateW2", Vector3(26.9, 0.0, 4.5), Vector3(1.2, 1.8, 1.2), 0.0, "crate", false, "prop"],
	["HallCrateW3", Vector3(25.6, 0.0, 3.2), Vector3(1.2, 1.8, 1.2), 0.0, "crate", false, "prop"],
	["HallCrateW4", Vector3(26.9, 0.0, 5.8), Vector3(1.2, 1.2, 1.2), 0.0, "crate", true, "prop"],
	["HallCrateE1", Vector3(43.7, 0.0, 3.4), Vector3(1.2, 1.2, 1.2), 0.0, "crate", true, "prop"],
	["HallCrateE2", Vector3(43.7, 0.0, 4.7), Vector3(1.2, 1.8, 1.2), 0.0, "crate", false, "prop"],
	["HallCrateE3", Vector3(45.0, 0.0, 6.0), Vector3(1.2, 1.8, 1.2), 0.0, "crate", false, "prop"],
	["HallCrateE4", Vector3(43.7, 0.0, 8.4), Vector3(1.2, 1.2, 1.2), 0.0, "crate", true, "prop"],
	["PalletJack", Vector3(46.6, 0.0, 9.0), Vector3(0.6, 1.2, 1.6), 90.0, "pallet_jack", false, "trim"],
	# GH gatehouse / QS net store
	["GateConsole", Vector3(29.4, 0.0, -30.0), Vector3(0.7, 0.9, 1.6), 0.0, "counter_service", true, "counter"],
	["GateHeater", Vector3(24.5, 0.0, -29.2), Vector3(0.4, 0.6, 0.8), 0.0, "heater", false, "trim"],
	["NetStackA", Vector3(13.4, 0.0, 34.9), Vector3(1.8, 1.2, 1.2), 0.0, "nets", false, "prop"],
	["NetStackB", Vector3(13.4, 0.0, 39.1), Vector3(1.8, 1.2, 1.2), 0.0, "nets", false, "prop"],
	["RopeReels", Vector3(17.0, 0.0, 39.2), Vector3(1.6, 0.9, 1.0), 0.0, "rope_reel", false, "prop"],
	# Yard: containers K1-K6 (40 ft, one high; doors on the weighbridge side), D1 (two high), cover.
	["ContainerK1", Vector3(8.0, 0.0, -26.82), Vector3(12.2, 2.6, 2.44), 0.0, "container", false, "container"],
	["ContainerK2", Vector3(8.0, 0.0, -20.82), Vector3(12.2, 2.6, 2.44), 0.0, "container", false, "container"],
	["ContainerK3", Vector3(8.0, 0.0, -14.82), Vector3(12.2, 2.6, 2.44), 0.0, "container", false, "container"],
	["ContainerK4", Vector3(52.0, 0.0, -26.82), Vector3(12.2, 2.6, 2.44), 0.0, "container", false, "container"],
	["ContainerK5", Vector3(52.0, 0.0, -20.82), Vector3(12.2, 2.6, 2.44), 0.0, "container", false, "container"],
	["ContainerK6", Vector3(52.0, 0.0, -14.82), Vector3(12.2, 2.6, 2.44), 0.0, "container", false, "container"],
	["ContainerD1", Vector3(8.0, 0.0, -6.82), Vector3(12.2, 5.2, 2.44), 0.0, "container", false, "container"],
	["ReachStacker", Vector3(22.0, 0.0, -12.0), Vector3(3.0, 3.5, 7.0), 0.0, "vehicle", false, "vehicle"],
	["ReeferTrailer", Vector3(52.0, 0.0, -4.0), Vector3(2.5, 4.0, 13.0), 90.0, "vehicle", false, "vehicle"],
	["IceBinsA", Vector3(24.0, 0.0, -20.0), Vector3(1.2, 1.2, 1.2), 0.0, "ice_bins", false, "prop"],
	["IceBinsB", Vector3(25.3, 0.0, -20.0), Vector3(1.2, 1.2, 1.2), 0.0, "ice_bins", false, "prop"],
	["IceBinsC", Vector3(42.0, 0.0, -24.0), Vector3(1.2, 1.2, 1.2), 0.0, "ice_bins", false, "prop"],
	["WeighbridgeKerbW", Vector3(29.85, 0.0, -23.0), Vector3(0.3, 0.3, 9.2), 0.0, "kerb", false, "concrete"],
	["WeighbridgeKerbE", Vector3(38.15, 0.0, -25.0), Vector3(0.3, 0.3, 13.6), 0.0, "kerb", false, "concrete"],
	# Lane: flatbed, skips
	["Flatbed", Vector3(-6.0, 0.0, 18.0), Vector3(2.4, 1.4, 7.0), 0.0, "vehicle", false, "vehicle"],
	["SkipA", Vector3(-6.8, 0.0, 26.5), Vector3(1.6, 1.4, 3.2), 0.0, "skip", false, "container"],
	["SkipB", Vector3(-6.8, 0.0, -20.0), Vector3(1.6, 1.4, 3.2), 0.0, "skip", false, "container"],
	# Apron / quay: forklift, bollards, net stacks, ice-bin pallets
	["ApronForklift", Vector3(55.0, 0.0, 20.0), Vector3(1.2, 2.1, 2.6), 0.0, "forklift", false, "vehicle"],
	["BollardApronA", Vector3(61.4, 0.0, -24.0), Vector3(0.4, 0.8, 0.4), 0.0, "bollard", false, "trim"],
	["BollardApronB", Vector3(61.4, 0.0, 6.0), Vector3(0.4, 0.8, 0.4), 0.0, "bollard", false, "trim"],
	["BollardApronC", Vector3(61.4, 0.0, 30.0), Vector3(0.4, 0.8, 0.4), 0.0, "bollard", false, "trim"],
	["BollardQuayA", Vector3(2.0, 0.0, 43.4), Vector3(0.4, 0.8, 0.4), 0.0, "bollard", false, "trim"],
	["BollardQuayB", Vector3(14.0, 0.0, 43.4), Vector3(0.4, 0.8, 0.4), 0.0, "bollard", false, "trim"],
	["BollardQuayC", Vector3(34.0, 0.0, 43.4), Vector3(0.4, 0.8, 0.4), 0.0, "bollard", false, "trim"],
	["BollardQuayD", Vector3(48.0, 0.0, 43.4), Vector3(0.4, 0.8, 0.4), 0.0, "bollard", false, "trim"],
	["QuayNetsA", Vector3(5.0, 0.0, 37.0), Vector3(2.0, 1.0, 1.5), 0.0, "nets", false, "prop"],
	["QuayNetsB", Vector3(38.0, 0.0, 37.6), Vector3(2.0, 1.0, 1.5), 0.0, "nets", false, "prop"],
	["QuayIceBins", Vector3(28.0, 0.0, 38.0), Vector3(1.2, 1.2, 1.2), 0.0, "ice_bins", false, "prop"],
	["Pier10Bollard", Vector3(72.6, 0.0, 20.0), Vector3(0.4, 0.8, 0.4), 0.0, "bollard", false, "trim"],
]

## Chairs: [name, bottom-centre, yaw_deg (front -Z faces the table)], 0.45 x 0.85 x 0.45, seat 0.45.
const CHAIRS: Array = [
	["DispatchChair", Vector3(12.0, 0.0, 1.85), 0.0],
	["BreakChairN", Vector3(6.0, MEZZ, 1.9), 180.0],
	["BreakChairS", Vector3(6.0, MEZZ, 3.7), 0.0],
	["BreakChairW", Vector3(4.75, MEZZ, 2.8), -90.0],
	["BreakChairE", Vector3(7.25, MEZZ, 2.8), 90.0],
	["CountChair", Vector3(11.85, MEZZ, 3.55), 0.0],
	["ForemanChair", Vector3(19.4, MEZZ, 1.75), 0.0],
	# PO-9: the receptionist's seat on the staff side of the O1 counter (the DeskCashO1 UsePoint is on the
	# front-door side) and the gate man's seat at the gatehouse console, clear of both door zones.
	["ReceptionChair", Vector3(6.0, 0.0, 3.95), 0.0],
	["GateChair", Vector3(28.6, 0.0, -30.0), -90.0],
]

## Sodium yard masts / quay lamps: [name, base, arm yaw_deg].
const MASTS: Array = [
	["MastYardW", Vector3(-2.5, 0.0, -32.5), 180.0], ["MastYardGate", Vector3(23.0, 0.0, -33.0), 180.0],
	["MastYardE", Vector3(44.0, 0.0, -33.0), 180.0], ["MastApron", Vector3(60.5, 0.0, -1.0), 90.0],
	["MastLaneS", Vector3(-7.4, 0.0, 30.0), -90.0], ["MastQuayW", Vector3(4.0, 0.0, 43.4), 0.0],
	["MastQuayMid", Vector3(30.0, 0.0, 43.4), 0.0], ["MastQuayE", Vector3(52.0, 0.0, 43.4), 0.0],
	["MastFerroW", Vector3(4.0, 0.0, -38.0), 0.0], ["MastFerroE", Vector3(52.0, 0.0, -38.0), 0.0],
]


# --- Lighting ------------------------------------------------------------------------------

## Ceiling fixtures with an OmniLight: [name, (x, ceiling_y, z), colour, energy, range].
## Zones (doc Audio/lighting): hall 5000 K LED half on, chambers / spine 6000 K cold strips, AN 5000 K,
## plant 4000 K, offices 4000 K / break room 3500 K, the strongroom's caged bulkhead.
const CEILING_LIGHTS: Array = [
	["LightO1", Vector3(6.0, OFFICE_CEIL, 3.0), Color(0.95, 0.95, 1.0), 0.6, 6.0],
	["LightO2", Vector3(12.0, OFFICE_CEIL, 3.0), Color(0.75, 0.85, 1.0), 0.4, 5.0],
	["LightE1", Vector3(16.5, OFFICE_CEIL, 4.5), Color(0.95, 0.95, 1.0), 0.4, 3.5],
	["LightOC", Vector3(9.0, OFFICE_CEIL, 7.0), Color(0.95, 0.95, 1.0), 0.5, 9.0],
	["LightM1", Vector3(12.0, MEZZ_CEIL, 3.0), Color(0.95, 0.95, 1.0), 0.6, 6.0],
	["LightM2", Vector3(6.0, MEZZ_CEIL, 3.0), Color(1.0, 0.88, 0.72), 0.6, 6.0],
	["LightM3", Vector3(16.5, MEZZ_CEIL, 4.5), Color(0.95, 0.95, 1.0), 0.4, 3.5],
	["LightMC", Vector3(9.0, MEZZ_CEIL, 7.0), Color(0.95, 0.95, 1.0), 0.5, 9.0],
	["LightPL", Vector3(5.0, PLANT_CEIL, 14.0), Color(1.0, 0.95, 0.85), 0.9, 9.0],
	["LightWS", Vector3(14.0, PLANT_CEIL, 12.5), Color(1.0, 0.95, 0.85), 0.9, 9.0],
	["LightPKW", Vector3(5.0, PACK_CEIL, 27.0), Color(0.92, 0.96, 1.0), 0.9, 10.0],
	["LightPKE", Vector3(13.0, PACK_CEIL, 25.0), Color(0.92, 0.96, 1.0), 0.9, 10.0],
	["LightLK", Vector3(2.5, SMALL_CEIL, 20.5), Color(0.95, 0.95, 1.0), 0.5, 5.0],
	["LightJ", Vector3(6.5, SMALL_CEIL, 19.5), Color(0.95, 0.95, 1.0), 0.3, 3.0],
	["LightHallW", Vector3(26.0, HALL_CEIL, 5.0), Color(0.95, 0.97, 1.0), 1.2, 14.0],
	["LightHallE", Vector3(40.0, HALL_CEIL, 5.0), Color(0.95, 0.97, 1.0), 1.2, 14.0],
	["LightC1", Vector3(25.0, BAY_CEIL, 15.0), Color(0.8, 0.9, 1.0), 1.4, 14.0],
	["LightSP", Vector3(33.5, BAY_CEIL, 17.0), Color(0.8, 0.9, 1.0), 1.2, 12.0],
	["LightC2", Vector3(41.0, BAY_CEIL, 15.0), Color(0.8, 0.9, 1.0), 1.4, 14.0],
	["LightSR", Vector3(22.0, SR_CEIL, 28.0), Color(1.0, 0.92, 0.8), 0.7, 7.0],
	["LightANW", Vector3(32.0, AN_CEIL, 28.0), Color(0.95, 0.97, 1.0), 1.0, 12.0],
	["LightANE", Vector3(42.0, AN_CEIL, 28.0), Color(0.95, 0.97, 1.0), 1.0, 12.0],
	["LightGH", Vector3(27.0, 2.7, -30.0), Color(1.0, 0.9, 0.75), 0.5, 5.0],
	["LightQS", Vector3(16.0, 3.0, 37.0), Color(1.0, 0.9, 0.75), 0.6, 7.0],
	["LightHH", Vector3(1.5, HH_CEIL, 3.0), Color(0.95, 0.95, 1.0), 0.5, 6.0],
]

## Wall-mounted sodium floods (the mural, the dock door): [name, pivot on the wall face, yaw_deg
## (front -Z out of the wall), colour, energy, range, size].
const WALL_LIGHTS: Array = [
	["MuralFloodW", Vector3(28.0, 6.9, 9.85), 0.0, Color(1.0, 0.62, 0.3), 1.6, 12.0, Vector3(0.5, 0.3, 0.3)],
	["MuralFloodE", Vector3(38.0, 6.9, 9.85), 0.0, Color(1.0, 0.62, 0.3), 1.6, 12.0, Vector3(0.5, 0.3, 0.3)],
	["DockDoorLamp", Vector3(48.2, 5.0, 8.0), -90.0, Color(1.0, 0.62, 0.3), 0.9, 10.0, Vector3(0.4, 0.25, 0.25)],
	["QuayDoorLamp", Vector3(36.0, 5.0, 32.2), 180.0, Color(1.0, 0.62, 0.3), 0.9, 10.0, Vector3(0.4, 0.25, 0.25)],
	["LaneDoorLamp", Vector3(-0.2, 2.6, 13.0), 90.0, Color(1.0, 0.62, 0.3), 0.6, 8.0, Vector3(0.3, 0.2, 0.2)],
]

## Landmark 1: the "ORTEGA COLD STORAGE" leaping-fish mural (12 x 2.2 m) on the high-bay north wall
## above the hall roof (outer face z 9.85), x 27-39, y 6.75-8.95.
const MURAL: Array = [27.0, 6.75, 9.83, 39.0, 8.95, 9.85]


# --- Spawns, patrols, tactical -------------------------------------------------------------

## [name, pos, yaw_deg (-Z = facing), tags]. Gate spawns are the default (no `preplan` tag).
const PLAYER_SPAWNS: Array = [
	["Gate1", Vector3(31.5, 0.0, -38.5), 180.0, ["spawn_gate"]],
	["Gate2", Vector3(33.0, 0.0, -38.5), 180.0, ["spawn_gate"]],
	["Gate3", Vector3(34.5, 0.0, -38.5), 180.0, ["spawn_gate"]],
	["Gate4", Vector3(36.0, 0.0, -38.5), 180.0, ["spawn_gate"]],
	["Lane1", Vector3(-6.5, 0.0, -31.5), 180.0, ["preplan_spawn_lane"]],
	["Lane2", Vector3(-5.0, 0.0, -31.5), 180.0, ["preplan_spawn_lane"]],
	["Lane3", Vector3(-3.5, 0.0, -31.5), 180.0, ["preplan_spawn_lane"]],
	["Lane4", Vector3(-2.0, 0.0, -31.5), 180.0, ["preplan_spawn_lane"]],
	["Pontoon1", Vector3(20.5, LAND, 52.0), 0.0, ["preplan_spawn_pontoon"]],
	["Pontoon2", Vector3(22.0, LAND, 52.0), 0.0, ["preplan_spawn_pontoon"]],
	["Pontoon3", Vector3(26.0, LAND, 52.0), 0.0, ["preplan_spawn_pontoon"]],
	["Pontoon4", Vector3(27.5, LAND, 52.0), 0.0, ["preplan_spawn_pontoon"]],
	# D-040: OUT_OF_BOUNDS (harbour, slip) respawns on the quay by the pontoon ramp.
	["OobQuay1", Vector3(27.0, 0.0, 42.4), 180.0, ["oob_respawn"]],
	["OobQuay2", Vector3(28.5, 0.0, 42.4), 180.0, ["oob_respawn"]],
	["OobQuay3", Vector3(30.0, 0.0, 42.4), 180.0, ["oob_respawn"]],
]

## Police spawns (doc Loud; director-chosen; none inside the building, QC-42 / D-064):
## [name, pos, yaw, tags]. P3 (Pier 10) lives in the `gangway_down` slot.
const POLICE_SPAWNS: Array = [
	["PoliceFerroEast", Vector3(70.0, 0.0, -44.0), -90.0, ["police_n", "p1e"]],
	["PoliceFerroWest", Vector3(-20.0, 0.0, -44.0), 90.0, ["police_n", "p1w"]],
	["PoliceBellweather", Vector3(-24.0, 0.0, -14.0), 90.0, ["police_w", "p2"]],
	["PoliceHarbourShed", Vector3(60.6, LAND, 46.2), 90.0, ["police_s", "p4"]],
	# P5: high-bay roof, police-only island reached only through the one-way rappel links (QC-41).
	["PoliceRoof", Vector3(46.0, BAY_ROOF, 12.0), 0.0, ["police_roof", "p5"]],
]
const POLICE_PIER10: Array = ["PolicePier10", Vector3(90.0, 0.0, -14.0), 90.0, ["police_e", "p3"]]

## Cartel posts (doc roster; `guard_post` slots, 2 gunmen each): post -> [[name, pos, yaw], ...],
## spawn tag, idle activity.
const CARTEL_POSTS: Dictionary = {
	"post_gate": [[["GunmanGateA", Vector3(27.5, 0.0, -26.0), 0.0], ["GunmanGateB", Vector3(26.0, 0.0, -25.8), 0.0]],
		"cartel_gate", "smoke"],
	"post_yard_w": [[["GunmanYardWA", Vector3(7.0, 0.0, -23.6), 90.0], ["GunmanYardWB", Vector3(16.5, 0.0, -23.0), -90.0]],
		"cartel_yard_w", ""],
	"post_yard_e": [[["GunmanYardEA", Vector3(44.0, 0.0, -22.8), -90.0], ["GunmanYardEB", Vector3(60.0, 0.0, -23.0), -90.0]],
		"cartel_yard_e", ""],
	"post_hall": [[["GunmanHallA", Vector3(34.6, 0.0, 5.0), 0.0], ["GunmanHallB", Vector3(46.4, 0.0, 3.4), -90.0]],
		"cartel_hall", ""],
	"post_platform": [[["GunmanPlatformA", Vector3(20.0, MEZZ, 4.8), 90.0], ["GunmanPlatformB", Vector3(6.6, MEZZ, 4.7), 0.0]],
		"cartel_platform", "sit"],
	"post_dock": [[["GunmanDockA", Vector3(28.6, 0.0, 26.6), 90.0], ["GunmanDockB", Vector3(37.0, 0.0, 27.8), 90.0]],
		"cartel_dock", ""],
	"post_quay": [[["GunmanQuayA", Vector3(21.2, 0.0, 36.0), 0.0], ["GunmanQuayB", Vector3(40.0, 0.0, 41.6), -90.0]],
		"cartel_quay", "smoke"],
}
## Cartel reinforcements (rare `cartel_reinforcements`, QC-25 spawn_guards at the gate): scripted.
const REINFORCEMENT_SPAWNS: Array = [
	["ReinforcementA", Vector3(32.0, 0.0, -36.5), 180.0], ["ReinforcementB", Vector3(36.0, 0.0, -36.5), 180.0],
]
## Night shift (slot group `night_shift`: 1 / 2 / 3 workers): candidate positions.
const WORKERS: Dictionary = {
	"AN1": [Vector3(43.0, 0.0, 26.2), 180.0], "AN2": [Vector3(45.6, 0.0, 26.2), 180.0],
	"PK": [Vector3(4.0, 0.0, 30.0), 0.0], "H": [Vector3(36.0, 0.0, 3.0), 180.0],
}
const NIGHT_SHIFT: Dictionary = {"shift_1": ["PK"], "shift_2": ["AN1", "H"], "shift_3": ["AN1", "AN2", "PK"]}

## Patrol graph `Cartel` (one graph across yard, hall, mezzanine, anteroom and quay; doc
## Circulation): {point: [pos, pause Vector2, anim, tags, face_yaw or null]}.
## Each cartel post has a HUB and three loop points that are linked all-to-all (the post's local
## loops: >= 3 per start point, heist_map.md §4); only the hub links out, to the AREA points listed
## after all posts (door / stair / aisle crossings). The validator's loop search walks neighbours in
## point order, so the posts' loops are found before it leaves the post (deterministic, cheap).
const PATROL_POINTS: Dictionary = {
	# post_gate: gatehouse <-> weighbridge, the gate (looking out at Ferro St).
	"PostGate": [Vector3(27.0, 0.0, -26.6), Vector2(10.0, 20.0), "smoke", ["cartel", "cartel_yard"], null],
	"GateGHWest": [Vector3(22.5, 0.0, -30.0), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"GateWeighN": [Vector3(34.0, 0.0, -29.5), Vector2(3.0, 6.0), "smoke", ["cartel", "cartel_yard"], null],
	"GateIn": [Vector3(34.0, 0.0, -33.0), Vector2(4.0, 8.0), "look", ["cartel", "cartel_yard"], 0.0],
	# post_yard_w: the K1-K3 alleys and both ends of the west container block.
	"PostYardW": [Vector3(8.0, 0.0, -23.8), Vector2(2.0, 4.0), "look", ["cartel", "cartel_yard"], null],
	"YWWest": [Vector3(0.6, 0.0, -23.8), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"YWEast": [Vector3(16.5, 0.0, -23.8), Vector2(2.0, 4.0), "idle", ["cartel", "cartel_yard"], null],
	"YWNorth": [Vector3(8.0, 0.0, -30.5), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	# post_yard_e: the K4-K6 alleys and both ends of the east container block.
	"PostYardE": [Vector3(52.0, 0.0, -23.8), Vector2(2.0, 4.0), "look", ["cartel", "cartel_yard"], null],
	"YEWest": [Vector3(44.0, 0.0, -23.8), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"YEEast": [Vector3(60.0, 0.0, -23.8), Vector2(2.0, 4.0), "idle", ["cartel", "cartel_yard"], null],
	"YENorth": [Vector3(52.0, 0.0, -30.5), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	# post_hall: hall floor, the dock-door side, the spine-aisle mouth (pause at the strip curtain).
	"PostHall": [Vector3(34.6, 0.0, 6.0), Vector2(2.0, 4.0), "idle", ["cartel", "cartel_hall", "staff", "staff_dock"], null],
	"HallW": [Vector3(24.6, 0.0, 4.0), Vector2(2.0, 4.0), "idle", ["cartel", "cartel_hall", "staff"], null],
	"HallE": [Vector3(42.0, 0.0, 3.0), Vector2(3.0, 6.0), "look", ["cartel", "cartel_hall", "staff"], -90.0],
	"HallSP": [Vector3(33.5, 0.0, 8.9), Vector2(3.0, 6.0), "look", ["cartel", "cartel_hall", "staff", "staff_dock"], 180.0],
	# post_platform: PF <-> M1 <-> M2 (coffee pause).
	"PostPlatform": [Vector3(20.0, MEZZ, 4.0), Vector2(4.0, 8.0), "look", ["cartel", "cartel_mezz"], -90.0],
	"PFStairTop": [Vector3(20.8, MEZZ, 7.25), Vector2.ZERO, "idle", ["cartel", "cartel_mezz"], null],
	"M1": [Vector3(13.4, MEZZ, 4.4), Vector2(4.0, 8.0), "idle", ["cartel", "cartel_mezz"], null],
	"M2": [Vector3(6.0, MEZZ, 4.7), Vector2(10.0, 20.0), "sit", ["cartel", "cartel_mezz"], null],
	# post_dock: the anteroom floor, the strongroom door (pause look), the quay roller doors.
	"PostDock": [Vector3(36.6, 0.0, 28.0), Vector2.ZERO, "idle", ["cartel", "cartel_dock", "staff", "staff_dock"], null],
	"ANVault": [Vector3(28.4, 0.0, 28.0), Vector2(3.0, 6.0), "look", ["cartel", "cartel_dock"], 90.0],
	"ANRollW": [Vector3(30.8, 0.0, 29.2), Vector2(2.0, 4.0), "idle", ["cartel", "cartel_dock", "staff", "staff_dock"], null],
	"ANRollE": [Vector3(40.8, 0.0, 29.2), Vector2(2.0, 4.0), "idle", ["cartel", "cartel_dock", "staff", "staff_dock"], null],
	# post_quay: net store <-> pontoon ramp <-> the quay.
	"PostQuay": [Vector3(21.2, 0.0, 37.0), Vector2(10.0, 20.0), "smoke", ["cartel", "cartel_quay"], null],
	"QRamp": [Vector3(24.0, 0.0, 42.6), Vector2(3.0, 6.0), "look", ["cartel", "cartel_quay"], 180.0],
	"QSWest": [Vector3(10.8, 0.0, 37.0), Vector2.ZERO, "idle", ["cartel", "cartel_quay"], null],
	"QMid": [Vector3(40.0, 0.0, 40.6), Vector2.ZERO, "idle", ["cartel", "cartel_quay"], null],
	# AREA points (after all posts): yard, apron, hall doors, the platform stair, spine, anteroom, quay, lane.
	"WeighW": [Vector3(28.6, 0.0, -20.0), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"WeighE": [Vector3(39.4, 0.0, -20.0), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"YardWSouth": [Vector3(8.0, 0.0, -10.8), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"Gangway": [Vector3(60.4, 0.0, -13.0), Vector2(4.0, 8.0), "look", ["cartel", "cartel_yard"], -90.0],
	"ApronN": [Vector3(60.0, 0.0, -6.5), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"DockDoorOut": [Vector3(49.8, 0.0, 6.8), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"ApronS": [Vector3(56.0, 0.0, 14.0), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"Roller2Out": [Vector3(33.8, 0.0, -2.0), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"StairLanding": [Vector3(25.1, 1.8, 7.4), Vector2.ZERO, "idle", ["cartel", "cartel_hall"], null],
	"SPMid": [Vector3(33.5, 0.0, 17.0), Vector2.ZERO, "idle", ["cartel", "cartel_dock", "staff", "staff_dock"], null],
	"ANSP": [Vector3(33.5, 0.0, 25.3), Vector2.ZERO, "idle", ["cartel", "cartel_dock", "staff", "staff_dock"], null],
	"ANEast": [Vector3(46.4, 0.0, 28.0), Vector2.ZERO, "idle", ["cartel", "cartel_dock", "staff"], null],
	"QAN": [Vector3(46.0, 0.0, 33.4), Vector2.ZERO, "idle", ["cartel", "cartel_quay"], null],
	"QSteps": [Vector3(57.0, 0.0, 39.4), Vector2(3.0, 6.0), "look", ["cartel", "cartel_quay"], 180.0],
	"QPK": [Vector3(12.0, 0.0, 33.4), Vector2.ZERO, "idle", ["cartel", "cartel_quay"], null],
	"QW": [Vector3(1.0, 0.0, 40.0), Vector2.ZERO, "idle", ["cartel", "cartel_quay"], null],
	"LaneS": [Vector3(-4.0, 0.0, 34.0), Vector2.ZERO, "idle", ["cartel", "cartel_quay"], null],
	"LaneMid": [Vector3(-4.0, 0.0, 10.0), Vector2.ZERO, "idle", ["cartel", "cartel_yard"], null],
	"LaneN": [Vector3(-4.0, 0.0, -24.0), Vector2(3.0, 6.0), "look", ["cartel", "cartel_yard"], 0.0],
}

## Posts: hub + three loop points, all-to-all (6 links each).
const PATROL_POSTS: Array = [
	["PostGate", "GateGHWest", "GateWeighN", "GateIn"], ["PostYardW", "YWWest", "YWEast", "YWNorth"],
	["PostYardE", "YEWest", "YEEast", "YENorth"], ["PostHall", "HallW", "HallE", "HallSP"],
	["PostPlatform", "PFStairTop", "M1", "M2"], ["PostDock", "ANVault", "ANRollW", "ANRollE"],
	["PostQuay", "QRamp", "QSWest", "QMid"],
]

## Hub <-> area and area <-> area links.
const PATROL_EDGES: Array = [
	["PostGate", "WeighW"], ["PostGate", "WeighE"], ["PostYardW", "WeighW"], ["PostYardW", "YardWSouth"],
	["PostYardW", "LaneN"], ["PostYardE", "WeighE"], ["PostYardE", "Gangway"], ["Gangway", "ApronN"],
	["ApronN", "DockDoorOut"], ["DockDoorOut", "ApronS"], ["DockDoorOut", "PostHall"], ["ApronS", "ANEast"],
	["Roller2Out", "WeighW"], ["Roller2Out", "WeighE"], ["Roller2Out", "YardWSouth"], ["Roller2Out", "PostHall"],
	["StairLanding", "PostHall"], ["StairLanding", "PostPlatform"], ["SPMid", "PostHall"], ["SPMid", "ANSP"],
	["ANSP", "PostDock"], ["ANEast", "PostDock"], ["ANEast", "QAN"], ["QAN", "PostQuay"], ["QAN", "QSteps"],
	["QSteps", "PostQuay"], ["PostQuay", "QPK"], ["QPK", "LaneS"], ["QPK", "QW"], ["QW", "LaneS"],
	["LaneS", "LaneMid"], ["LaneMid", "YardWSouth"], ["LaneMid", "LaneN"],
]

## Tactical points: [name, kind, pos, yaw, tags, breachable]. Building ENTRY points carry
## `breach_only` (QC-42, D-064: police never spawn inside, they breach in).
const TACTICAL: Array = [
	# ENTRY: play-space gates and approaches.
	["EntryGate", "ENTRY", Vector3(34.0, 0.0, -35.4), 180.0, ["gate", "north"], false],
	["EntryLaneManGate", "ENTRY", Vector3(-4.0, 0.0, -35.2), 180.0, ["man_gate", "north"], true],
	["EntryFerroWest", "ENTRY", Vector3(-13.2, 0.0, -43.0), -90.0, ["closure", "north"], true],
	["EntryFerroEast", "ENTRY", Vector3(67.2, 0.0, -43.0), 90.0, ["closure", "north"], true],
	["EntryBellweatherGate", "ENTRY", Vector3(-9.2, 0.0, -14.0), -90.0, ["man_gate", "west"], true],
	["EntryPier10Gate", "ENTRY", Vector3(85.2, 0.0, -14.0), 90.0, ["hoarding_gate", "east"], true],
	["EntryQuaySteps", "ENTRY", Vector3(57.0, 0.0, 39.6), 180.0, ["quay_steps", "south"], false],
	# ENTRY: building shell (breach targets only).
	["EntryHallRoller1", "ENTRY", Vector3(25.8, 0.0, -1.4), 180.0, ["roller", "north", "breach_only"], true],
	["EntryHallRoller2", "ENTRY", Vector3(33.8, 0.0, -1.4), 180.0, ["roller", "north", "breach_only"], true],
	["EntryHallRoller3", "ENTRY", Vector3(41.8, 0.0, -1.4), 180.0, ["roller", "north", "breach_only"], true],
	["EntryDockRoller", "ENTRY", Vector3(49.4, 0.0, 4.8), 90.0, ["roller", "east", "breach_only"], true],
	["EntryOfficeFront", "ENTRY", Vector3(6.0, 0.0, -1.2), 180.0, ["door", "north", "breach_only"], true],
	["EntryOCWest", "ENTRY", Vector3(-1.2, 0.0, 7.0), -90.0, ["door", "west", "breach_only"], true],
	["EntryPLWest", "ENTRY", Vector3(-1.2, 0.0, 14.0), -90.0, ["door", "west", "breach_only"], true],
	["EntryMCWest", "ENTRY", Vector3(-0.8, MEZZ, 7.0), -90.0, ["door", "west", "fire_stair", "breach_only"], true],
	["EntryANRollerW", "ENTRY", Vector3(30.8, 0.0, 33.4), 0.0, ["roller", "south", "breach_only"], true],
	["EntryANRollerE", "ENTRY", Vector3(40.8, 0.0, 33.4), 0.0, ["roller", "south", "breach_only"], true],
	["EntryANQuay", "ENTRY", Vector3(46.0, 0.0, 33.4), 0.0, ["door", "south", "breach_only"], true],
	["EntryANEast", "ENTRY", Vector3(49.4, 0.0, 28.0), 90.0, ["door", "east", "breach_only"], true],
	["EntryPKRoller", "ENTRY", Vector3(7.8, 0.0, 33.4), 0.0, ["roller", "south", "breach_only"], true],
	["EntryPKQuay", "ENTRY", Vector3(12.0, 0.0, 33.4), 0.0, ["door", "south", "breach_only"], true],
	# RAPPEL + ENTRY: the high-bay skylights (8.0 m drop to the chamber floors; QC-41 links).
	["RappelC1", "RAPPEL", Vector3(25.0, BAY_ROOF + 0.4, 17.0), 0.0, ["skylight", "roof", "breach_only"], true],
	["RappelSP", "RAPPEL", Vector3(33.5, BAY_ROOF + 0.4, 17.0), 0.0, ["skylight", "roof", "breach_only"], true],
	["RappelC2", "RAPPEL", Vector3(41.0, BAY_ROOF + 0.4, 17.0), 0.0, ["skylight", "roof", "breach_only"], true],
	["EntrySkylightC1", "ENTRY", Vector3(25.0, BAY_ROOF + 0.4, 17.0), 0.0, ["skylight", "roof", "breach_only"], true],
	["EntrySkylightSP", "ENTRY", Vector3(33.5, BAY_ROOF + 0.4, 17.0), 0.0, ["skylight", "roof", "breach_only"], true],
	["EntrySkylightC2", "ENTRY", Vector3(41.0, BAY_ROOF + 0.4, 17.0), 0.0, ["skylight", "roof", "breach_only"], true],
	# FLANK: the culvert (Phantom; nav layer `vent`), container alleys, the lane behind the fire stair.
	["FlankCulvertOutfall", "FLANK", Vector3(-5.5, 0.0, 42.6), 0.0, ["culvert", "vent", "phantom"], false],
	["FlankCulvertGrate", "FLANK", Vector3(2.0, 0.0, 15.0), 0.0, ["culvert", "vent", "phantom"], false],
	["FlankAlleyWest", "FLANK", Vector3(8.0, 0.0, -23.8), 90.0, ["container_alley"], false],
	["FlankAlleyEast", "FLANK", Vector3(52.0, 0.0, -23.8), -90.0, ["container_alley"], false],
	["FlankLane", "FLANK", Vector3(-3.0, 0.0, 9.0), 0.0, ["lane"], false],
	# SHIELD_ANCHOR (Bulwark / Aegis formations).
	["AnchorWeighbridge", "SHIELD_ANCHOR", Vector3(34.0, 0.0, -26.0), 180.0, ["weighbridge"], false],
	["AnchorHallRoller2", "SHIELD_ANCHOR", Vector3(33.8, 0.0, -3.0), 180.0, ["hall_roller"], false],
	["AnchorQuayAN", "SHIELD_ANCHOR", Vector3(36.0, 0.0, 36.0), 0.0, ["quay"], false],
	["AnchorLane", "SHIELD_ANCHOR", Vector3(-2.6, 0.0, -3.0), 0.0, ["lane"], false],
	["AnchorSpineMouth", "SHIELD_ANCHOR", Vector3(33.5, 0.0, 9.0), 180.0, ["spine"], false],
	# COVER.
	["CoverK1East", "COVER", Vector3(15.0, 0.0, -28.6), 90.0, ["container"], false],
	["CoverK3East", "COVER", Vector3(15.0, 0.0, -13.0), 90.0, ["container"], false],
	["CoverK4West", "COVER", Vector3(45.0, 0.0, -28.6), -90.0, ["container"], false],
	["CoverK6West", "COVER", Vector3(45.0, 0.0, -13.0), -90.0, ["container"], false],
	["CoverD1", "COVER", Vector3(8.0, 0.0, -4.8), 180.0, ["container"], false],
	["CoverReachStacker", "COVER", Vector3(24.0, 0.0, -12.0), 90.0, ["vehicle"], false],
	["CoverReefer", "COVER", Vector3(52.0, 0.0, -6.0), 180.0, ["vehicle"], false],
	["CoverWeighKerb", "COVER", Vector3(29.4, 0.0, -25.0), -90.0, ["kerb"], false],
	["CoverIceBins", "COVER", Vector3(24.6, 0.0, -19.0), 180.0, ["ice_bins"], false],
	["CoverHallCratesW", "COVER", Vector3(28.1, 0.0, 3.8), 90.0, ["crates"], false],
	["CoverHallCratesE", "COVER", Vector3(42.5, 0.0, 4.0), -90.0, ["crates"], false],
	["CoverPlatformStair", "COVER", Vector3(26.0, 0.0, 9.0), 0.0, ["stair"], false],
	["CoverRackC1", "COVER", Vector3(25.0, 0.0, 22.2), 0.0, ["rack"], false],
	["CoverRackC2", "COVER", Vector3(41.0, 0.0, 22.2), 0.0, ["rack"], false],
	["CoverANPallets", "COVER", Vector3(30.7, 0.0, 26.6), 180.0, ["pallets"], false],
	["CoverWrapper", "COVER", Vector3(38.5, 0.0, 27.2), 180.0, ["machine"], false],
	["CoverForkliftAN", "COVER", Vector3(43.5, 0.0, 26.8), 180.0, ["vehicle"], false],
	["CoverNetStoreW", "COVER", Vector3(11.4, 0.0, 34.4), 0.0, ["building"], false],
	["CoverNetStoreE", "COVER", Vector3(20.6, 0.0, 39.6), 180.0, ["building"], false],
	["CoverQuayNets", "COVER", Vector3(38.0, 0.0, 36.4), 0.0, ["nets"], false],
	["CoverFlatbed", "COVER", Vector3(-3.4, 0.0, 18.0), -90.0, ["vehicle"], false],
	["CoverFireStair", "COVER", Vector3(-3.0, 0.0, 3.0), -90.0, ["stair"], false],
	["CoverApronForklift", "COVER", Vector3(55.0, 0.0, 17.8), 0.0, ["vehicle"], false],
	["CoverGatehouse", "COVER", Vector3(23.4, 0.0, -27.6), 0.0, ["building"], false],
	# SNIPER_PERCH: always on (D-064 Q8); S3 / S4 live in their rare-event slots.
	["SniperCrane", "SNIPER_PERCH", Vector3(79.0, 22.2, 0.0), 90.0, ["crane", "s1"], false],
	["SniperBellweather", "SNIPER_PERCH", Vector3(-14.0, 8.0, 38.0), -135.0, ["bellweather_roof", "s2"], false],
]
const SNIPER_VIADUCT: Array = ["SniperViaduct", "SNIPER_PERCH", Vector3(10.0, 7.0, -51.0), 180.0, ["viaduct", "s3"], false]
const SNIPER_TRAWLER: Array = ["SniperTrawler", "SNIPER_PERCH", Vector3(70.0, 4.0, 50.8), 0.0, ["trawler", "s4"], false]

## Nav links (always present): one-way rappel links roof -> chamber floors (QC-41) and the culvert
## (Phantom, nav layer `vent` = layer 3). [name, from, to, bidirectional, navigation_layers].
const NAV_LINKS: Array = [
	["RappelLinkC1", Vector3(25.0, BAY_ROOF, 19.2), Vector3(25.0, 0.0, 19.2), false, 1],
	["RappelLinkSP", Vector3(33.5, BAY_ROOF, 19.2), Vector3(33.5, 0.0, 19.2), false, 1],
	["RappelLinkC2", Vector3(41.0, BAY_ROOF, 19.2), Vector3(41.0, 0.0, 19.2), false, 1],
	["CulvertLink", Vector3(-5.5, 0.0, 42.6), Vector3(2.0, 0.0, 15.0), true, 4],
]

## Pre-planning points (contracts/preplanning.md, D-046): [id, category, pos, floor (index into
## floor_heights: 0 Landing, 1 Ground, 2 Mezzanine, 3 Roof), params].
const PREPLAN_POINTS: Array = [
	["pp_spawn_gate", "spawn", Vector3(33.75, 0.0, -38.5), 1, {}],
	["pp_spawn_lane", "spawn", Vector3(-4.25, 0.0, -31.5), 1, {"spawn_tag": &"preplan_spawn_lane"}],
	["pp_spawn_pontoon", "spawn", Vector3(24.0, LAND, 52.0), 0, {"spawn_tag": &"preplan_spawn_pontoon"}],
	["pp_drop_gatehouse", "drop_zone", Vector3(25.5, 0.0, -26.6), 1, {}],
	["pp_drop_lane", "drop_zone", Vector3(-2.6, 0.0, -2.6), 1, {}],
	["pp_drop_quay", "drop_zone", Vector3(16.0, 0.0, 37.0), 1, {}],
	["pp_drop_platform", "drop_zone", Vector3(20.0, MEZZ, 2.6), 2, {}],
	["pp_escape_gate", "escape", Vector3(34.0, 0.0, -22.0), 1, {"variant_group": &"escape", "variant_slot": &"esc_van_gate"}],
	["pp_escape_lane", "escape", Vector3(-5.0, 0.0, 1.5), 1, {"variant_group": &"escape", "variant_slot": &"esc_van_lane"}],
	["pp_escape_boat", "escape", Vector3(23.0, -1.6, 55.6), 0, {"variant_group": &"escape", "variant_slot": &"esc_boat"}],
	["pp_perch_roof", "drop_zone", Vector3(10.0, ROOF, 5.0), 3, {"variant_group": &"player_perch", "variant_slot": &"perch_roof"}],
	["pp_perch_stack", "drop_zone", Vector3(8.0, 0.0, -4.6), 1,
		{"variant_group": &"player_perch", "variant_slot": &"perch_stack"}],
	["pp_gangway", "insider", Vector3(60.4, 0.0, -13.0), 1, {"variant_group": &"east_gangway", "variant_slot": &"gangway_up"}],
]


# --- Rooms and zones ------------------------------------------------------------------------

## [id, purpose, dressing_kit, floor_index, boxes, ceiling_range override or null].
const ROOMS: Array = [
	["O1", "reception", "office_front_desk", 1, [[3.0, 0.0, 0.0, 9.0, OFFICE_CEIL, 6.0]], null],
	["O2", "security_room", "security_office", 1, [[9.0, 0.0, 0.0, 15.0, OFFICE_CEIL, 6.0]], null],
	["ST", "stair", "", 1, [[0.0, 0.0, 0.0, 3.0, ROOF, 6.0]], null],
	["LF", "elevator", "", 1, [[15.0, 0.0, 0.0, 18.0, MEZZ_CEIL, 3.0]], null],
	["E1", "electrical", "electrical_closet", 1, [[15.0, 0.0, 3.0, 18.0, OFFICE_CEIL, 6.0]], null],
	["OC", "corridor", "corridor_service", 1, [[0.0, 0.0, 6.0, 18.0, OFFICE_CEIL, 8.0]], null],
	["PL", "plant", "plant_refrigeration", 1, [[0.0, 0.0, 8.0, 10.0, PLANT_CEIL, 18.0]], null],
	["WS", "workshop", "workshop_forklift", 1, [[10.0, 0.0, 8.0, 18.0, PLANT_CEIL, 18.0]], null],
	["LK", "locker_room", "locker_room", 1, [[0.0, 0.0, 18.0, 5.0, SMALL_CEIL, 23.0]], null],
	["J", "janitor", "janitor_closet", 1, [[5.0, 0.0, 18.0, 8.0, SMALL_CEIL, 21.0]], null],
	["PK", "warehouse", "packing_hall", 1, [[8.0, 0.0, 18.0, 18.0, PACK_CEIL, 21.0], [5.0, 0.0, 21.0, 18.0, PACK_CEIL, 23.0],
		[0.0, 0.0, 23.0, 18.0, PACK_CEIL, 32.0]], null],
	["H", "warehouse", "marshalling_hall", 1, [[18.0, 0.0, 0.0, 48.0, HALL_CEIL, 10.0]], null],
	["C1", "warehouse", "cold_store_racked", 1, [[18.0, 0.0, 10.0, 32.0, BAY_CEIL, 24.0]], BAY_CEIL_RANGE],
	["SP", "warehouse", "cold_store_aisle", 1, [[32.0, 0.0, 10.0, 35.0, BAY_CEIL, 24.0]], BAY_CEIL_RANGE],
	["C2", "warehouse", "cold_store_racked", 1, [[35.0, 0.0, 10.0, 48.0, BAY_CEIL, 24.0]], BAY_CEIL_RANGE],
	["SR", "vault", "strongroom_freezer", 1, [[18.0, 0.0, 24.0, 26.0, SR_CEIL, 32.0]], null],
	["AN", "warehouse", "quay_dock", 1, [[26.0, 0.0, 24.0, 48.0, AN_CEIL, 32.0]], null],
	["M1", "cash_office", "count_room", 2, [[9.0, MEZZ, 0.0, 15.0, MEZZ_CEIL, 6.0]], null],
	["M2", "break_room", "break_room", 2, [[3.0, MEZZ, 0.0, 9.0, MEZZ_CEIL, 6.0]], null],
	["M3", "restroom", "restroom_single", 2, [[15.0, MEZZ, 3.0, 18.0, MEZZ_CEIL, 6.0]], null],
	["MC", "corridor", "corridor_service", 2, [[0.0, MEZZ, 6.0, 18.0, MEZZ_CEIL, 8.0]], null],
	["HH", "stair", "", 3, [[0.0, ROOF, 0.0, 3.0, HH_CEIL, 6.0]], null],
	["GH", "office", "gatehouse", 1, [[24.0, 0.0, -32.0, 30.0, 2.7, -28.0]], null],
	["QS", "storage", "net_store", 1, [[12.0, 0.0, 34.0, 20.0, 3.0, 40.0]], null],
	["X1", "exterior", "exterior_yard", 1, [[-8.0, -0.5, -34.0, 24.0, 4.0, 0.0], [24.0, -0.5, -34.0, 30.0, 4.0, -32.0],
		[24.0, -0.5, -28.0, 30.0, 4.0, 0.0], [30.0, -0.5, -34.0, 62.0, 4.0, 0.0]], null],
	["X2", "exterior", "exterior_lane", 1, [[-8.0, -0.5, 0.0, 0.0, 4.0, 32.0]], null],
	["X3", "exterior", "exterior_apron", 1, [[48.0, -0.5, 0.0, 62.0, 4.0, 32.0]], null],
	["X4", "exterior", "exterior_quay", 1, [[-8.0, -0.5, 32.0, 12.0, 4.0, 44.0], [12.0, -0.5, 32.0, 20.0, 4.0, 34.0],
		[12.0, -0.5, 40.0, 20.0, 4.0, 44.0], [20.0, -0.5, 32.0, 62.0, 4.0, 44.0], [16.0, -2.3, 50.0, 32.0, 2.0, 54.0],
		[52.0, -2.3, 44.0, 59.2, 2.0, 48.0]], null],
	["X5", "exterior", "exterior_roof", 3, [[3.0, ROOF, 0.0, 18.0, ROOF + 2.0, 8.0], [0.0, ROOF, 6.0, 3.0, ROOF + 2.0, 8.0]], null],
]

## Fixed MapZones: [name, kind, zone_id, boxes]. SECURE_LOOT / ESCAPE live in the `escape` slots.
const ZONES: Array = [
	["RestrictedCoOp", "RESTRICTED", "ortega_cold_storage", [[0.2, -0.2, 0.2, 47.8, 9.0, 31.8]]],
	["RestrictedYard", "RESTRICTED", "ortega_yard", [[-8.0, -0.5, -34.0, 62.0, 4.0, 0.0]]],
	# D-040: the harbour and the slip are hard boundaries (respawn at `oob_respawn`, never an alarm).
	["OutOfBoundsHarbour", "OUT_OF_BOUNDS", "harbour_water", [[-60.0, -12.0, 44.05, 140.0, OOB_TOP, 200.0]]],
	["OutOfBoundsSlip", "OUT_OF_BOUNDS", "slip_water", [[62.05, -12.0, -31.95, 71.95, OOB_TOP, 44.05]]],
]


# --- Review cameras ---------------------------------------------------------------------------

## [name, position, look-at target, fov (TopDown*: ortho size), caption].
## Interior cameras sit >= 0.5 m inside their room (levelcheck `cameras`).
const REVIEW_CAMERAS: Array = [
	["TopDownSite", Vector3(38.0, 140.0, 2.0), Vector3(38.0, 0.0, 2.0), 150.0,
		"Top-down site: Pier 9 (building, yard, lane, apron, quay), Ferro St, Bellweather, the slip, Pier 10"],
	["TopDownBuilding", Vector3(24.0, 70.0, 16.0), Vector3(24.0, 0.0, 16.0), 56.0,
		"Top-down building: office block (+7.2), hall (+6.6), high bay (+9.0), west wing (+5.8)"],
	["ExtGate", Vector3(34.0, 1.7, -45.0), Vector3(34.0, 5.0, 0.0), 70.0,
		"Exterior: from Ferro St through the gate: weighbridge, gatehouse, hall roller doors, the mural (landmark 1)"],
	["ExtYardEast", Vector3(44.0, 1.7, -10.8), Vector3(78.0, 12.0, -2.0), 70.0,
		"Exterior: from K6 east: apron, gangway, the Pier 10 crane over the slip (landmark 2)"],
	["ExtQuay", Vector3(24.0, -0.1, 53.0), Vector3(24.0, 4.0, 30.0), 75.0,
		"Exterior: from the pontoon: quay, net store, AN / PK doors, condenser plumes (landmark 3)"],
	["ExtLane", Vector3(-4.0, 1.7, -31.0), Vector3(-4.0, 2.0, 20.0), 70.0,
		"Exterior: west lane from the north end: the fire stair, Bellweather fence, E2"],
	["YardWest", Vector3(17.5, 2.2, -32.5), Vector3(6.0, 1.5, -12.0), 70.0,
		"Yard west: K1-K3 alleys and D1 (player perch with the ladder)"],
	["Gatehouse", Vector3(25.0, 1.7, -29.0), Vector3(34.0, 1.0, -24.0), 75.0,
		"GH gatehouse (H4): console, window to the weighbridge"],
	["HallPlatform", Vector3(20.0, 5.25, 3.0), Vector3(40.0, 1.0, 8.0), 75.0,
		"H from the platform PF (H1): roller doors, the spine-aisle mouth"],
	["HallFloor", Vector3(46.4, 1.7, 7.6), Vector3(20.0, 2.6, 4.0), 75.0,
		"H from the dock door: the platform, its stair, the goods-lift hatch"],
	["ChamberA", Vector3(25.0, 1.7, 23.2), Vector3(25.0, 3.0, 11.0), 75.0, "C1 chamber A down the centre aisle (racking)"],
	["ChamberB", Vector3(41.0, 1.7, 23.2), Vector3(41.0, 3.0, 11.0), 75.0, "C2 chamber B down the centre aisle"],
	["Spine", Vector3(33.5, 1.7, 10.8), Vector3(33.5, 1.5, 24.0), 70.0, "SP spine aisle from the hall end (strip curtains)"],
	["Anteroom", Vector3(47.2, 1.7, 30.6), Vector3(27.0, 1.2, 27.0), 75.0,
		"AN anteroom (H2) from the east door: the vault door, quay roller doors, pallets"],
	["Strongroom", Vector3(19.0, 1.7, 31.2), Vector3(25.5, 1.0, 27.0), 80.0, "SR strongroom (vault): cash pallets, the vault door"],
	["Packing", Vector3(0.8, 2.2, 23.8), Vector3(12.0, 1.0, 31.0), 75.0, "PK packing hall: the packing line, quay doors"],
	["Plant", Vector3(9.3, 2.2, 17.3), Vector3(1.0, 1.0, 9.0), 75.0, "PL plant: compressors, the culvert grate"],
	["Workshop", Vector3(10.8, 2.2, 8.8), Vector3(17.0, 0.8, 16.0), 75.0, "WS workshop: forklifts on charge"],
	["Reception", Vector3(8.3, 1.8, 5.3), Vector3(4.0, 1.0, 0.5), 75.0, "O1 reception: counter, front door"],
	["Dispatch", Vector3(14.3, 1.8, 5.3), Vector3(10.0, 1.0, 0.5), 75.0, "O2 dispatch / security room: desk, dispatch safe"],
	["CountRoom", Vector3(9.8, 5.4, 5.3), Vector3(14.5, 4.2, 1.0), 75.0, "M1 count room (H1): counting table, cash cage slot, lift hatch"],
	["BreakRoom", Vector3(8.3, 5.4, 5.3), Vector3(4.0, 4.2, 0.5), 75.0, "M2 break room"],
	["LockerRoom", Vector3(4.3, 1.8, 22.3), Vector3(0.5, 1.0, 18.5), 75.0, "LK locker room"],
	["QuayShed", Vector3(19.0, 1.8, 35.2), Vector3(14.0, 1.2, 40.0), 75.0, "QS quay net store (H3): the pontoon window"],
	["LandingStage", Vector3(57.0, 1.7, 39.0), Vector3(60.0, -1.8, 47.0), 75.0, "X4 quay steps down to the landing stage, P4 shed"],
	["RoofPerch", Vector3(10.0, 8.85, 6.2), Vector3(10.0, 7.0, -50.0), 70.0, "X5 office roof (player perch) toward the viaduct"],
	["SniperCrane", Vector3(79.0, 23.8, -2.6), Vector3(40.0, 0.0, -12.0), 70.0, "S1 crane cab: the Longshot's view over the yard and apron"],
]
