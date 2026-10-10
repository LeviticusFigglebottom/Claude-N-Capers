## Glasshouse (Vossberg Jewelers) greybox layout data. Owner: ENV C (C1-03, G1).
## Source of truth for build_greybox.gd. Design: docs/design/heists/glasshouse.md (APPROVED, D-023).
## Coordinates: metres, world x = plan x (east), world z = plan z (south), +y up. Origin = the NW
## corner of the building on the wall centre lines (the plan's origin). Boxes are [x0, y0, z0, x1, y1, z1].
## Wall openings are [along0, along1, sill_y, head_y] in absolute heights.
## Never edit the generated glasshouse.tscn by hand: change this file and rerun the generator.
extends RefCounted

const FLOOR_HEIGHTS: Array[float] = [0.0, 4.2]
const UPPER: float = 4.2
const EXT_T: float = 0.4
const INT_T: float = 0.2
const PARAPET_TOP: float = 8.8
const GROUND_WALL_TOP: float = 4.0
const UPPER_WALL_TOP: float = 7.6
const ROAD_Y: float = -0.15

# --- Building shell -------------------------------------------------------------------------

## Exterior walls: [name, axis ("x" = runs along x at fixed z, "z" = runs along z at fixed x),
## fixed coordinate, from, to, openings].
const EXT_WALLS: Array = [
	["ExtNorth", "x", 0.0, -0.2, 18.2, [
		[2.9, 4.1, 0.0, 2.2],        # back door (service 1.1 m leaf) G1 -> alley
		[7.75, 8.75, 1.8, 3.0],      # G2 workshop high barred window
		[1.75, 2.75, 5.1, 6.3],      # U1 break-room window (fire-escape landing)
		[7.25, 8.25, 5.1, 6.3],      # U2 security office window (alley + back door)
		[11.5, 12.5, 5.7, 6.9],      # U3 high frosted window
	]],
	["ExtSouth", "x", 12.0, -0.2, 18.2, [
		[0.3, 3.3, 0.3, 2.7], [3.5, 6.5, 0.3, 2.7], [6.7, 9.7, 0.3, 2.7],   # shopfront bays A-C
		[10.25, 12.25, 0.0, 2.2],    # double glass entry door (1.8 m)
		[14.0, 17.0, 0.3, 2.7],      # salon window to Harlow Ave
		[1.25, 2.25, 5.1, 6.3], [4.75, 5.75, 5.1, 6.3],    # U5 admin
		[8.4, 9.4, 5.1, 6.3], [9.6, 10.6, 5.1, 6.3],       # U6 manager
		[13.5, 16.5, 5.1, 6.3],      # U7 stock
	]],
	["ExtWest", "z", 0.0, 0.2, 11.8, []],  # party wall with Castellan Tailoring: no openings
	["ExtEast", "z", 18.0, 0.2, 11.8, [
		[1.15, 2.35, 0.0, 2.2],      # fire exit (G10 -> Pell St)
		[7.5, 10.5, 0.3, 2.7],       # salon window to Pell St (police ENTRY)
		[7.9, 8.9, 5.1, 6.3], [9.1, 10.1, 5.1, 6.3],       # U7 stock
	]],
]

## Interior walls: [name, axis, fixed, from, to, y0, y1, openings]. Ground walls stop at the slab
## underside (4.0); full-height walls (stair core, x 10.5) run through the slab.
const INT_WALLS: Array = [
	["G_Corridor_N_W", "x", 4.5, 0.2, 13.0, 0.0, GROUND_WALL_TOP,
		[[3.0, 4.0, 0.0, 2.2], [7.0, 8.0, 0.0, 2.2], [11.0, 12.0, 0.0, 2.2]]],
	["G_Corridor_N_E", "x", 4.5, 14.5, 17.8, 0.0, GROUND_WALL_TOP,
		[[14.8, 15.8, 0.0, 2.2], [16.5, 17.5, 0.0, 2.2]]],
	["G_Corridor_S", "x", 6.0, 0.2, 17.8, 0.0, GROUND_WALL_TOP,
		[[1.0, 2.0, 0.0, 2.2], [16.0, 17.0, 0.0, 2.2]]],
	["G_G1_G2", "z", 5.0, 0.2, 4.4, 0.0, GROUND_WALL_TOP, []],
	["G_G7_E", "z", 2.0, 0.2, 2.1, 0.0, GROUND_WALL_TOP, [[0.5, 1.5, 0.0, 2.2]]],
	["G_G7_S", "x", 2.0, 0.2, 2.1, 0.0, GROUND_WALL_TOP, []],
	["Core_X10_5", "z", 10.5, 0.2, 4.4, 0.0, UPPER_WALL_TOP, []],
	["Core_X13", "z", 13.0, 0.2, 4.6, 0.0, UPPER_WALL_TOP, []],
	["Core_X16", "z", 16.0, 0.2, 4.4, 0.0, UPPER_WALL_TOP, []],
	["G_G9_W", "z", 14.5, 3.0, 4.4, 0.0, 2.85, []],
	["G_G9_N", "x", 3.0, 14.5, 15.9, 0.0, 2.85, []],
	["G_Salon_W", "z", 13.0, 6.1, 11.8, 0.0, GROUND_WALL_TOP, [[9.5, 10.5, 0.0, 2.2]]],
	["U_Corridor_N_W", "x", 4.5, 0.2, 13.0, UPPER, UPPER_WALL_TOP,
		[[2.5, 3.5, UPPER, UPPER + 2.2], [7.5, 8.5, UPPER, UPPER + 2.2], [11.0, 12.0, UPPER, UPPER + 2.2]]],
	["U_Corridor_N_E", "x", 4.5, 16.0, 17.8, UPPER, UPPER_WALL_TOP, [[16.5, 17.5, UPPER, UPPER + 2.2]]],
	["U_Corridor_S", "x", 6.0, 0.2, 17.8, UPPER, UPPER_WALL_TOP,
		[[3.5, 4.5, UPPER, UPPER + 2.2], [10.0, 11.0, UPPER, UPPER + 2.2], [12.5, 13.5, UPPER, UPPER + 2.2]]],
	["U_U1_U2", "z", 5.5, 0.2, 4.4, UPPER, UPPER_WALL_TOP, []],
	["U_U5_U6", "z", 7.0, 6.1, 11.8, UPPER, UPPER_WALL_TOP, []],
	["U_U6_U7", "z", 12.0, 6.1, 11.8, UPPER, UPPER_WALL_TOP, []],
]

## Slabs: ground floor, upper floor (hole over the stair core x 13-16, z 0-4.48), roof.
const SLABS: Array = [
	["SlabGround", [-0.2, -0.3, -0.2, 18.2, 0.0, 12.2], "none"],
	["SlabUpperW", [0.2, 4.0, 0.2, 13.0, 4.2, 11.8], "floor"],
	["SlabUpperCore", [13.0, 4.0, 4.48, 16.0, 4.2, 11.8], "floor"],
	["SlabUpperE", [16.0, 4.0, 0.2, 17.8, 4.2, 11.8], "floor"],
	["SlabRoof", [0.2, 7.6, 0.2, 17.8, 7.8, 11.8], "roof"],
]

## Ceilings (0.05 m thick, underside at the room's ceiling height).
const CEILINGS: Array = [
	["CeilBOH_W", [0.0, 3.0, 0.0, 13.0, 3.05, 4.5]],     # G1, G7, G2, G3: dropped ceiling 3.0
	["CeilG10", [16.0, 3.0, 0.0, 18.0, 3.05, 4.5]],
	["CeilG4", [0.0, 3.0, 4.5, 18.0, 3.05, 6.0]],
	["CeilG9", [14.5, 2.8, 3.0, 16.0, 2.85, 4.5]],       # janitor closet under the return flight
	["CeilG5", [0.0, 3.6, 6.0, 13.0, 3.65, 12.0]],
	["CeilG6", [13.0, 3.2, 6.0, 18.0, 3.25, 12.0]],
	["CeilUpperN_W", [0.0, 7.2, 0.0, 13.0, 7.25, 4.5]],
	["CeilUpperN_E", [16.0, 7.2, 0.0, 18.0, 7.25, 4.5]],
	["CeilUpperS", [0.0, 7.2, 4.5, 18.0, 7.25, 12.0]],
]

## U-stair G8: up-flight x 13.1-14.3 climbing north from z 4.48 to the half landing (+2.1,
## z 0.2-1.4, full core width), return flight x 14.7-15.9 climbing south to the upper floor at z 4.48.
## 24 risers x 0.175 = 4.2, treads 0.28, width 1.2.
const STAIR: Dictionary = {
	"riser": 0.175, "tread": 0.28, "risers_per_flight": 12, "landing_z": [0.2, 1.4],
	"up_x": [13.105, 14.3], "ret_x": [14.7, 15.895], "landing_x": [13.105, 15.895],
	"g9_z": 3.0, "g9_ceiling_top": 2.85,
}

## Railings (collision panel + rail/post visuals): upper void (U4, x 13-14.5) and the fire-escape
## landing on the alley side of U1 (open on the ladder side).
const RAILINGS: Array = [
	["RailVoid", [13.1, 4.2, 4.43, 14.5, 5.25, 4.53]],
	["RailLandingW", [0.98, 4.2, -1.4, 1.03, 5.25, -0.2]],
	["RailLandingE", [3.47, 4.2, -1.4, 3.52, 5.25, -0.2]],
	["RailLandingN", [1.95, 4.2, -1.42, 3.52, 5.25, -1.37]],
]
const LANDING: Array = [1.0, 4.1, -1.4, 3.5, 4.2, -0.2]

## Windows: [name, kit piece, sill origin (x, y, z), yaw_deg (front = UsePoint side), prefab?].
## Prefab windows are breakable/openable gameplay windows; the rest are static greybox glazing.
## Yaw: 0 = front faces north (-z), 180 = south (+z), -90 = east (+x), 90 = west (-x).
const WINDOWS: Array = [
	["ShopBayA", "arch_window_shop_w300_h240", Vector3(1.8, 0.3, 12.0), 180.0, true],
	["ShopBayB", "arch_window_shop_w300_h240", Vector3(5.0, 0.3, 12.0), 180.0, true],
	["ShopBayC", "arch_window_shop_w300_h240", Vector3(8.2, 0.3, 12.0), 180.0, true],
	["SalonSouth", "arch_window_shop_w300_h240", Vector3(15.5, 0.3, 12.0), 180.0, true],
	["SalonEast", "arch_window_shop_w300_h240", Vector3(18.0, 0.3, 9.0), -90.0, true],
	["WorkshopHigh", "arch_window_w100_h120", Vector3(8.25, 1.8, 0.0), 0.0, false],
	["SecurityNorth", "arch_window_w100_h120", Vector3(7.75, 5.1, 0.0), 0.0, false],
	["WCUpperNorth", "arch_window_w100_h120", Vector3(12.0, 5.7, 0.0), 0.0, false],
	["AdminSouthA", "arch_window_w100_h120", Vector3(1.75, 5.1, 12.0), 180.0, false],
	["AdminSouthB", "arch_window_w100_h120", Vector3(5.25, 5.1, 12.0), 180.0, false],
	["ManagerSouthA", "arch_window_w100_h120", Vector3(8.9, 5.1, 12.0), 180.0, false],
	["ManagerSouthB", "arch_window_w100_h120", Vector3(10.1, 5.1, 12.0), 180.0, false],
	["StockSouth", "arch_window_w300_h120", Vector3(15.0, 5.1, 12.0), 180.0, false],
	["StockEastA", "arch_window_w100_h120", Vector3(18.0, 5.1, 8.4), -90.0, false],
	["StockEastB", "arch_window_w100_h120", Vector3(18.0, 5.1, 9.6), -90.0, false],
]
## Break-room window (U1, variable `open_window`): built inside the variant slots.
const BREAKROOM_WINDOW: Dictionary = {"kit": "arch_window_w100_h120", "pos": Vector3(2.25, 5.1, 0.0), "yaw": 0.0}

## Doors: [name, kit piece, origin (bottom-centre of the opening on the wall line), yaw_deg, lock,
## swing, objective_tag, metas]. Front (-Z, UsePoint side) is the corridor / outside side; INWARD
## leaves swing to the back (+Z) side, into the room (level_standards §3.3).
const DOORS: Array = [
	["BackDoor", "arch_door_service_t40", Vector3(3.5, 0.0, 0.0), 0.0, "LOCKPICK", "INWARD", "back_door",
		{"service": true}],
	["ElectricalDoor", "arch_door_single_t20", Vector3(2.0, 0.0, 1.0), -90.0, "NONE", "INWARD", "", {}],
	["ReceivingDoor", "arch_door_single_t20", Vector3(3.5, 0.0, 4.5), 180.0, "NONE", "INWARD", "", {}],
	["WorkshopDoor", "arch_door_single_t20", Vector3(7.5, 0.0, 4.5), 180.0, "LOCKPICK", "INWARD", "workshop_door", {}],
	["WCDoor", "arch_door_single_t20", Vector3(11.5, 0.0, 4.5), 180.0, "NONE", "INWARD", "", {}],
	["JanitorDoor", "arch_door_single_t20", Vector3(15.3, 0.0, 4.5), 180.0, "NONE", "INWARD", "", {}],
	["LobbyDoor", "arch_door_single_t20", Vector3(17.0, 0.0, 4.5), 180.0, "NONE", "INWARD", "", {}],
	["FireExit", "arch_door_service_t40", Vector3(18.0, 0.0, 1.75), 90.0, "NONE", "INWARD", "fire_exit",
		{"service": true, "fire_exit": true, "suspicious_when_open": true}],
	["StaffDoor", "arch_door_single_t20", Vector3(1.5, 0.0, 6.0), 0.0, "NONE", "INWARD", "staff_door", {}],
	["SalonBackDoor", "arch_door_single_t20", Vector3(16.5, 0.0, 6.0), 0.0, "LOCKPICK", "INWARD", "", {}],
	["SalonDoor", "arch_door_single_t20", Vector3(13.0, 0.0, 10.0), 90.0, "LOCKPICK", "INWARD", "salon_door", {}],
	["MainEntrance", "arch_door_double_t40", Vector3(11.25, 0.0, 12.0), 180.0, "NONE", "DOUBLE", "main_entrance", {}],
	["BreakRoomDoor", "arch_door_single_t20", Vector3(3.0, UPPER, 4.5), 180.0, "NONE", "INWARD", "", {}],
	["SecurityDoor", "arch_door_single_t20", Vector3(8.0, UPPER, 4.5), 180.0, "NONE", "INWARD", "", {}],
	["WCUpperDoor", "arch_door_single_t20", Vector3(11.5, UPPER, 4.5), 180.0, "NONE", "INWARD", "", {}],
	["UpperLobbyDoor", "arch_door_single_t20", Vector3(17.0, UPPER, 4.5), 180.0, "NONE", "INWARD", "", {}],
	["AdminDoor", "arch_door_single_t20", Vector3(4.0, UPPER, 6.0), 0.0, "NONE", "INWARD", "", {}],
	["ManagerDoor", "arch_door_single_t20", Vector3(10.5, UPPER, 6.0), 0.0, "NONE", "INWARD", "", {}],
	["StockDoor", "arch_door_single_t20", Vector3(13.0, UPPER, 6.0), 0.0, "NONE", "INWARD", "", {}],
	# Play-space closures: chained/barred gates the police open in loud (mission unlocks them).
	["AlleyGate", "arch_door_double_t20", Vector3(-14.0, 0.0, -3.2), -90.0, "BARRED", "DOUBLE", "police_gate", {}],
	["HarlowWestGate", "arch_door_double_t20", Vector3(-14.0, ROAD_Y, 23.2), -90.0, "BARRED", "DOUBLE", "police_gate", {}],
	["HarlowEastGate", "arch_door_double_t20", Vector3(32.5, ROAD_Y, 23.2), 90.0, "BARRED", "DOUBLE", "police_gate", {}],
	["PellNorthGate", "arch_door_double_t20", Vector3(23.2, ROAD_Y, -8.0), 180.0, "BARRED", "DOUBLE", "police_gate", {}],
]

# --- Site -----------------------------------------------------------------------------------

## Ground surfaces: [name, box, material]. Sidewalks/alley top 0.0, carriageways top -0.15.
const GROUND: Array = [
	["Alley", [-20.0, -0.3, -6.2, 18.2, 0.0, -0.2], "paving"],
	["KesselYards", [-20.0, -0.3, -8.2, 18.2, 0.0, -6.2], "paving"],
	["HarlowSidewalkN_W", [-45.0, -0.3, 12.2, 21.2, 0.0, 16.2], "sidewalk"],
	["HarlowSidewalkN_E", [29.2, -0.3, 12.2, 55.0, 0.0, 16.2], "sidewalk"],
	["HarlowRoad", [-45.0, -0.3, 16.2, 55.0, ROAD_Y, 30.2], "asphalt"],
	["HarlowSidewalkS_W", [-45.0, -0.3, 30.2, 21.2, 0.0, 34.2], "sidewalk"],
	["HarlowSidewalkS_E", [29.2, -0.3, 30.2, 55.0, 0.0, 34.2], "sidewalk"],
	["PellRoadN", [21.2, -0.3, -16.0, 29.2, ROAD_Y, 16.2], "asphalt"],
	["PellRoadS", [21.2, -0.3, 30.2, 29.2, ROAD_Y, 40.0], "asphalt"],
	["PellSidewalkW_N", [18.2, -0.3, -16.0, 21.2, 0.0, 12.2], "sidewalk"],
	["PellSidewalkE_N", [29.2, -0.3, -16.0, 32.2, 0.0, 12.2], "sidewalk"],
	["PellSidewalkW_S", [18.2, -0.3, 34.2, 21.2, 0.0, 40.0], "sidewalk"],
	["PellSidewalkE_S", [29.2, -0.3, 34.2, 32.2, 0.0, 40.0], "sidewalk"],
]

## Neighbour / dressing blocks (solid massing): [name, box, material].
const BLOCKS: Array = [
	["CastellanTailoring", [-14.0, -0.3, -0.2, -0.2, 8.6, 12.2], "facade_a"],
	["HarlowNorthWest", [-45.0, -0.3, -0.2, -14.0, 12.0, 12.2], "facade_b"],
	["AlleyEndBlock", [-45.0, -0.3, -8.2, -20.0, 10.0, -0.2], "brick"],
	["KesselRowBacks", [-45.0, -0.3, -20.0, 18.2, 7.5, -8.2], "brick"],
	["PellNorthEnd", [18.2, -0.3, -24.0, 32.2, 10.0, -16.0], "facade_b"],
	["GarageBack", [38.2, -0.3, -16.0, 50.0, 10.0, 12.2], "concrete"],
	["GarageGround", [32.2, -0.3, -16.0, 38.2, 2.8, 12.2], "concrete"],
	["HarlowNorthEast", [50.0, -0.3, -16.0, 55.0, 12.0, 12.2], "facade_a"],
	["TJunctionFacade", [55.0, -0.3, 12.2, 62.0, 14.0, 34.2], "facade_c"],
	["BendFacade", [-52.0, -0.3, 12.2, -45.0, 12.0, 34.2], "facade_c"],
	["SouthWestBlock", [-45.0, -0.3, 34.2, -10.0, 12.0, 50.0], "facade_b"],
	["Hotel", [-10.0, -0.3, 34.2, 10.0, 17.0, 50.0], "facade_c"],
	["Cafe", [10.0, -0.3, 34.2, 18.2, 11.0, 50.0], "facade_a"],
	["SouthEastBlock", [32.2, -0.3, 34.2, 55.0, 13.0, 50.0], "facade_b"],
	["PellSouthRamp", [18.2, -0.3, 40.0, 32.2, 6.0, 48.0], "concrete"],
	["HotelCanopy", [-4.0, 3.4, 32.4, 4.0, 3.6, 34.2], "trim"],
	# Garage decks (levels 2 and 3, open slots facing Pell St) and parapets.
	["GarageDeck2", [32.2, 2.8, -16.0, 38.2, 3.0, 12.2], "concrete"],
	["GarageDeck3", [32.2, 5.8, -16.0, 38.2, 6.0, 12.2], "concrete"],
	["GarageRoof", [32.2, 8.8, -16.0, 38.2, 9.0, 12.2], "concrete"],
	["GarageParapet2", [32.2, 3.0, -16.0, 32.5, 4.0, 12.2], "concrete"],
	["GarageParapet3", [32.2, 6.0, -16.0, 32.5, 7.0, 12.2], "concrete"],
	["GarageParapetRoof", [32.2, 9.0, -16.0, 32.5, 10.0, 12.2], "concrete"],
	["GarageCar2A", [34.0, 3.0, -6.0, 35.8, 4.45, -1.6], "vehicle"],
	["GarageCar2B", [34.0, 3.0, 4.0, 35.8, 4.45, 8.4], "vehicle"],
	["GarageCar3A", [34.0, 6.0, -12.0, 35.8, 7.45, -7.6], "vehicle"],
	# Roof equipment (not playable in P1) and the alley stub closure.
	["RoofHVAC1", [3.0, 7.8, 5.0, 5.0, 9.0, 7.0], "trim"],
	["RoofHVAC2", [9.0, 7.8, 8.0, 11.0, 9.0, 10.0], "trim"],
	["RoofHatch", [16.6, 7.8, 1.6, 17.4, 8.0, 2.4], "trim"],
	["AlleyStubDumpster", [-19.9, 0.0, -1.3, -18.1, 1.2, -0.3], "vehicle"],
	# Vista dressing beyond the closures (work vans, box truck).
	["WorkVanWest", [-21.0, ROAD_Y, 17.2, -16.0, 2.3, 19.2], "vehicle"],
	["WorkVanEast", [35.0, ROAD_Y, 26.0, 40.0, 2.3, 28.0], "vehicle"],
	["BoxTruckPellN", [22.0, ROAD_Y, -12.6, 29.0, 3.4, -10.2], "vehicle"],
]

## Fences with gates (the gates are door prefabs in DOORS): [name, axis, fixed, from, to, y0, y1, openings, material].
const FENCES: Array = [
	["AlleyGateFence", "z", -14.0, -6.19, -0.21, 0.0, 2.4, [[-4.2, -2.2, 0.0, 2.2]], "fence"],
	["KesselYardFence", "x", -6.25, -19.99, 18.19, 0.0, 2.2, [], "fence"],
	["HarlowWestRoadworks", "z", -14.0, 12.21, 34.19, ROAD_Y, 2.4, [[22.2, 24.2, ROAD_Y, ROAD_Y + 2.2]], "fence"],
	["HarlowEastRoadworks", "z", 32.5, 12.21, 34.19, ROAD_Y, 2.4, [[22.2, 24.2, ROAD_Y, ROAD_Y + 2.2]], "fence"],
	["PellNorthHoarding", "x", -8.0, 18.21, 32.19, ROAD_Y, 2.4, [[22.2, 24.2, ROAD_Y, ROAD_Y + 2.2]], "fence"],
]

# --- Props (gameplay-relevant blockers; placeholder boxes) ----------------------------------

## [name, bottom-centre (x, y, z), size (x, y, z) before yaw, yaw_deg, kind, support, material].
const PROPS: Array = [
	# G5 sales floor
	["SalesCounter", Vector3(3.5, 0.0, 7.5), Vector3(2.6, 0.9, 0.6), 0.0, "counter_service", true, "counter"],
	["ConsultTable", Vector3(11.8, 0.0, 7.6), Vector3(1.0, 0.75, 0.8), 0.0, "table", true, "prop"],
	["WindowBench", Vector3(5.0, 0.0, 11.4), Vector3(1.6, 0.45, 0.45), 0.0, "bench", false, "prop"],
	# Shopfront window display boxes (bays A and C; bay B has the bench), lit from above (WALL_LIGHTS).
	["WindowBoxA", Vector3(2.05, 0.0, 11.565), Vector3(2.3, 0.3, 0.45), 0.0, "window_box", true, "counter"],
	["WindowBoxC", Vector3(8.0, 0.0, 11.565), Vector3(2.4, 0.3, 0.45), 0.0, "window_box", true, "counter"],
	# G6 salon
	["SalonSofa", Vector3(15.5, 0.0, 11.35), Vector3(2.0, 0.8, 0.8), 180.0, "sofa", false, "prop"],
	["SalonCoffeeTable", Vector3(15.5, 0.0, 10.2), Vector3(1.0, 0.45, 0.6), 0.0, "table", true, "prop"],
	["SalonVitrine", Vector3(13.41, 0.0, 7.4), Vector3(0.5, 1.8, 1.0), 0.0, "vitrine", true, "counter"],
	# G2 workshop
	["JewelerBenchA", Vector3(8.5, 0.0, 0.56), Vector3(1.2, 0.9, 0.7), 0.0, "workbench", true, "counter"],
	["JewelerBenchB", Vector3(9.75, 0.0, 0.56), Vector3(1.1, 0.9, 0.7), 0.0, "workbench", true, "counter"],
	["PolishingStation", Vector3(5.46, 0.0, 2.8), Vector3(0.7, 0.9, 1.2), 0.0, "workbench", true, "counter"],
	# G1 receiving + G7 electrical
	["ReceivingShelving", Vector3(0.51, 0.0, 3.25), Vector3(0.6, 2.0, 2.0), 0.0, "shelf", true, "prop"],
	["PackingBench", Vector3(4.59, 0.0, 2.4), Vector3(0.6, 0.9, 1.6), 0.0, "workbench", true, "counter"],
	["DeliveryCrates", Vector3(2.3, 0.0, 3.3), Vector3(0.6, 0.6, 0.6), 0.0, "box", false, "prop"],
	["ITRack", Vector3(0.56, 0.0, 0.56), Vector3(0.6, 2.0, 0.6), 0.0, "rack", false, "trim"],
	# G3 / U3 restrooms, G9 janitor
	["ToiletG3", Vector3(11.8, 0.0, 0.51), Vector3(0.4, 0.8, 0.6), 0.0, "toilet", false, "prop"],
	["SinkG3", Vector3(12.64, 0.0, 2.2), Vector3(0.5, 0.85, 0.5), 0.0, "sink", false, "prop"],
	["JanitorShelf", Vector3(15.25, 0.0, 3.26), Vector3(1.2, 1.5, 0.3), 0.0, "shelf", true, "prop"],
	["ToiletU3", Vector3(11.8, UPPER, 0.51), Vector3(0.4, 0.8, 0.6), 0.0, "toilet", false, "prop"],
	["SinkU3", Vector3(12.64, UPPER, 2.2), Vector3(0.5, 0.85, 0.5), 0.0, "sink", false, "prop"],
	# U1 break room
	["BreakTable", Vector3(3.0, UPPER, 2.3), Vector3(1.2, 0.75, 0.8), 0.0, "table", true, "prop"],
	["BreakLockers", Vector3(0.46, UPPER, 2.6), Vector3(0.5, 1.2, 1.4), 0.0, "locker", true, "trim"],
	["KitchenCounter", Vector3(5.09, UPPER, 1.2), Vector3(0.6, 0.9, 1.8), 0.0, "counter_service", true, "counter"],
	["Fridge", Vector3(5.09, UPPER, 2.62), Vector3(0.6, 1.8, 0.7), 0.0, "fridge", false, "trim"],
	# U2 security office
	["KeyCabinet", Vector3(10.19, UPPER, 3.4), Vector3(0.4, 1.0, 0.8), 0.0, "cabinet", true, "trim"],
	["GuardLockers", Vector3(9.0, UPPER, 0.46), Vector3(1.2, 1.8, 0.5), 0.0, "locker", false, "trim"],
	# U5 admin + appraisal
	["DeskBookkeeping", Vector3(1.6, UPPER, 9.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["DeskSalesAdmin", Vector3(4.2, UPPER, 9.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["AppraisalBench", Vector3(5.8, UPPER, 11.29), Vector3(1.4, 0.9, 0.6), 0.0, "workbench", true, "counter"],
	["FileCabinets", Vector3(6.64, UPPER, 7.8), Vector3(0.5, 1.3, 1.2), 0.0, "cabinet", false, "trim"],
	# U6 manager
	["ManagerDesk", Vector3(9.5, UPPER, 9.0), Vector3(1.6, 0.75, 0.8), 0.0, "desk", true, "prop"],
	["Credenza", Vector3(7.36, UPPER, 9.5), Vector3(0.5, 0.8, 1.6), 0.0, "cabinet", true, "counter"],
	["Bookshelf", Vector3(11.64, UPPER, 9.0), Vector3(0.5, 2.0, 1.2), 0.0, "shelf", true, "prop"],
	# U7 stock / archive
	["StockShelfA", Vector3(14.9, UPPER, 8.0), Vector3(3.6, 2.0, 0.5), 0.0, "shelf", true, "prop"],
	["StockShelfB", Vector3(14.9, UPPER, 10.2), Vector3(3.6, 2.0, 0.5), 0.0, "shelf", true, "prop"],
	# U8 roof-hatch ladder (fixed, locked in P1)
	["RoofHatchLadder", Vector3(17.75, UPPER, 2.0), Vector3(0.08, 2.95, 0.5), 0.0, "ladder_fixed", false, "trim"],
	# Alley (X1)
	["HVACCondenser1", Vector3(13.0, 0.0, -0.71), Vector3(1.4, 1.0, 0.9), 0.0, "hvac", false, "trim"],
	["HVACCondenser2", Vector3(14.6, 0.0, -0.71), Vector3(1.4, 1.0, 0.9), 0.0, "hvac", false, "trim"],
	["Pallets", Vector3(16.6, 0.0, -0.8), Vector3(1.2, 0.3, 1.0), 0.0, "pallet", false, "prop"],
	# Street (X2)
	["CarHarlow1", Vector3(-11.0, ROAD_Y, 17.3), Vector3(4.4, 1.45, 1.8), 0.0, "vehicle", false, "vehicle"],
	["CarHarlow2", Vector3(-5.0, ROAD_Y, 17.3), Vector3(4.4, 1.45, 1.8), 0.0, "vehicle", false, "vehicle"],
	["CarHarlow3", Vector3(16.0, ROAD_Y, 17.3), Vector3(4.4, 1.45, 1.8), 0.0, "vehicle", false, "vehicle"],
	["CarHarlowS1", Vector3(2.0, ROAD_Y, 29.1), Vector3(4.4, 1.45, 1.8), 0.0, "vehicle", false, "vehicle"],
	["CarPell1", Vector3(28.2, ROAD_Y, -3.0), Vector3(1.8, 1.45, 4.4), 0.0, "vehicle", false, "vehicle"],
	["CarPell2", Vector3(28.2, ROAD_Y, 37.0), Vector3(1.8, 1.45, 4.4), 0.0, "vehicle", false, "vehicle"],
	["CarPell3", Vector3(28.2, ROAD_Y, 8.0), Vector3(1.8, 1.45, 4.4), 0.0, "vehicle", false, "vehicle"],
	["BusShelter", Vector3(-4.5, 0.0, 15.4), Vector3(3.5, 2.5, 1.2), 0.0, "bus_shelter", false, "trim"],
	["TrashBinHarlow", Vector3(9.4, 0.0, 15.8), Vector3(0.5, 1.0, 0.5), 0.0, "bin", false, "trim"],
	["TrashBinPell", Vector3(20.8, 0.0, 10.8), Vector3(0.5, 1.0, 0.5), 0.0, "bin", false, "trim"],
]

## Chairs: [name, bottom-centre, yaw_deg (front -Z faces the table)], 0.45 x 0.85 x 0.45, seat 0.45.
const CHAIRS: Array = [
	["ConsultChairW", Vector3(11.0, 0.0, 7.6), -90.0],
	["ConsultChairE", Vector3(12.6, 0.0, 7.6), 90.0],
	["BreakChairN", Vector3(3.0, UPPER, 1.5), 180.0],
	["BreakChairS", Vector3(3.0, UPPER, 3.1), 0.0],
]

## Chandelier display (landmark): round plinth + glass drum, ring chandelier above (Lighting).
const CHANDELIER: Dictionary = {"pos": Vector3(7.0, 0.0, 9.0), "radius": 1.2, "plinth_h": 0.9, "glass_h": 0.6, "ceiling": 3.6}

## Street lamps: [name, base (x, y, z), arm direction yaw_deg (the head overhangs the road)].
const STREET_LAMPS: Array = [
	["LampHarlowN1", Vector3(-10.0, 0.0, 15.2), 180.0],
	["LampHarlowN2", Vector3(3.0, 0.0, 15.2), 180.0],
	["LampHarlowN3", Vector3(17.5, 0.0, 15.2), 180.0],
	["LampHarlowS1", Vector3(-8.0, 0.0, 31.2), 0.0],
	["LampHarlowS2", Vector3(8.0, 0.0, 31.2), 0.0],
	["LampHarlowS3", Vector3(16.0, 0.0, 31.2), 0.0],
	["LampPellW1", Vector3(20.2, 0.0, -3.5), -90.0],
	["LampPellW2", Vector3(20.2, 0.0, 2.0), -90.0],
	["LampPellE1", Vector3(30.2, 0.0, -9.0), 90.0],
]

# --- Lighting ------------------------------------------------------------------------------

## Ceiling fixtures with an OmniLight: [name, (x, ceiling_y, z), colour, energy, range].
## Zones (doc §Audio/lighting): sales 2700 K warm, salon dimmer, BOH 4000 K, workshop 5000 K,
## receiving dimmer 5000 K, security dim + cool, break room 3500 K, offices 4000 K.
const CEILING_LIGHTS: Array = [
	["LightG5West", Vector3(3.0, 3.6, 9.5), Color(1.0, 0.78, 0.55), 1.4, 7.0],
	["LightG5East", Vector3(10.5, 3.6, 9.5), Color(1.0, 0.78, 0.55), 1.4, 7.0],
	["LightG6", Vector3(15.5, 3.2, 9.0), Color(1.0, 0.74, 0.5), 0.9, 5.5],
	["LightG4West", Vector3(4.5, 3.0, 5.25), Color(0.93, 0.95, 1.0), 0.7, 5.0],
	["LightG4East", Vector3(13.5, 3.0, 5.25), Color(0.93, 0.95, 1.0), 0.7, 5.0],
	["LightG1", Vector3(3.2, 3.0, 2.8), Color(0.9, 0.95, 1.0), 0.5, 4.5],
	["LightG2", Vector3(8.0, 3.0, 2.5), Color(0.92, 0.96, 1.0), 0.6, 4.5],
	["LightG3", Vector3(11.75, 3.0, 2.2), Color(0.93, 0.95, 1.0), 0.5, 3.5],
	["LightG10", Vector3(17.0, 3.0, 2.2), Color(0.93, 0.95, 1.0), 0.5, 3.5],
	["LightU1", Vector3(2.75, 7.2, 2.2), Color(1.0, 0.86, 0.7), 0.7, 5.0],
	["LightU2", Vector3(8.0, 7.2, 2.2), Color(0.75, 0.85, 1.0), 0.35, 4.0],
	["LightU3", Vector3(11.75, 7.2, 2.2), Color(0.93, 0.95, 1.0), 0.5, 3.5],
	["LightU4West", Vector3(4.5, 7.2, 5.25), Color(0.93, 0.95, 1.0), 0.6, 5.0],
	["LightU4East", Vector3(13.0, 7.2, 5.25), Color(0.93, 0.95, 1.0), 0.6, 5.0],
	["LightU5", Vector3(3.5, 7.2, 9.0), Color(0.95, 0.95, 1.0), 0.8, 6.0],
	["LightU6", Vector3(9.5, 7.2, 9.0), Color(0.95, 0.95, 1.0), 0.7, 5.5],
	["LightU7", Vector3(15.0, 7.2, 9.0), Color(0.95, 0.95, 1.0), 0.6, 5.5],
	["LightU8", Vector3(17.0, 7.2, 2.2), Color(0.93, 0.95, 1.0), 0.5, 3.5],
	["LightStair", Vector3(14.5, 7.6, 2.4), Color(0.93, 0.95, 1.0), 0.8, 7.0],
]

## Wall-mounted lights: [name, pivot on the wall face, yaw_deg (front -Z out of the wall), colour,
## energy, range, size].
const WALL_LIGHTS: Array = [
	["BackDoorLamp", Vector3(3.5, 2.6, -0.2), 0.0, Color(1.0, 0.85, 0.65), 0.8, 6.0, Vector3(0.3, 0.2, 0.2)],
	["AlleyLampEast", Vector3(13.5, 3.2, -0.2), 0.0, Color(0.95, 0.95, 1.0), 0.7, 8.0, Vector3(0.3, 0.2, 0.2)],
	["AlleyLampWest", Vector3(-7.0, 3.2, -0.2), 0.0, Color(0.95, 0.95, 1.0), 0.7, 8.0, Vector3(0.3, 0.2, 0.2)],
	["WindowBoxLightA", Vector3(2.05, 2.95, 11.8), 0.0, Color(1.0, 0.8, 0.56), 0.9, 3.0, Vector3(2.0, 0.08, 0.12)],
	["WindowBoxLightC", Vector3(8.0, 2.95, 11.8), 0.0, Color(1.0, 0.8, 0.56), 0.9, 3.0, Vector3(2.0, 0.08, 0.12)],
	["MonitorWall", Vector3(5.6, 5.85, 2.0), -90.0, Color(0.55, 0.75, 1.0), 0.6, 3.5, Vector3(1.4, 0.6, 0.05)],
	["TaskLampBenchA", Vector3(8.5, 1.55, 0.2), 180.0, Color(0.92, 0.96, 1.0), 0.7, 2.5, Vector3(0.3, 0.1, 0.18)],
	["TaskLampBenchB", Vector3(9.75, 1.55, 0.2), 180.0, Color(0.92, 0.96, 1.0), 0.7, 2.5, Vector3(0.3, 0.1, 0.18)],
	["NeonVossbergSouth", Vector3(15.5, 3.4, 12.2), 180.0, Color(1.0, 0.24, 0.65), 1.2, 7.0, Vector3(2.6, 0.6, 0.1)],
	["NeonVossbergEast", Vector3(18.2, 3.4, 9.0), -90.0, Color(1.0, 0.24, 0.65), 1.2, 7.0, Vector3(2.6, 0.6, 0.1)],
]

# --- Spawns, patrols, tactical -------------------------------------------------------------

## [name, pos, yaw_deg (-Z = facing), tags].
const PLAYER_SPAWNS: Array = [
	["CasingHarlow1", Vector3(3.0, 0.0, 14.4), 0.0, ["casing_harlow"]],
	["CasingHarlow2", Vector3(4.5, 0.0, 14.4), 0.0, ["casing_harlow"]],
	["CasingHarlow3", Vector3(6.0, 0.0, 14.4), 0.0, ["casing_harlow"]],
	["CasingHarlow4", Vector3(7.5, 0.0, 14.4), 0.0, ["casing_harlow"]],
	["PreplanAlleyMouth1", Vector3(19.0, 0.0, -1.8), 90.0, ["preplan_spawn_alley_mouth"]],
	["PreplanAlleyMouth2", Vector3(19.0, 0.0, -3.0), 90.0, ["preplan_spawn_alley_mouth"]],
	["PreplanAlleyMouth3", Vector3(20.2, 0.0, -1.8), 90.0, ["preplan_spawn_alley_mouth"]],
	["PreplanAlleyMouth4", Vector3(20.2, 0.0, -3.0), 90.0, ["preplan_spawn_alley_mouth"]],
	["PreplanAlleyWest1", Vector3(-12.5, 0.0, -1.2), -90.0, ["preplan_spawn_alley"]],
	["PreplanAlleyWest2", Vector3(-12.5, 0.0, -2.4), -90.0, ["preplan_spawn_alley"]],
	["PreplanAlleyWest3", Vector3(-12.5, 0.0, -4.4), -90.0, ["preplan_spawn_alley"]],
	["PreplanAlleyWest4", Vector3(-12.5, 0.0, -5.4), -90.0, ["preplan_spawn_alley"]],
]

## Fixed NPC spawns: [name, kind, pos, yaw, tags, idle_activity, patrol_graph ("" = none)].
const NPC_SPAWNS: Array = [
	["GuardFloorPost", "GUARD", Vector3(9.6, 0.0, 11.2), 0.0, ["guard_post_floor"], "", "Building"],
	["CivCounterAssociate", "CIVILIAN", Vector3(3.6, 0.0, 6.65), 180.0, ["civ_staff_counter"], "desk_work", ""],
	["CivFloorAssociate", "CIVILIAN", Vector3(8.6, 0.0, 8.0), 90.0, ["civ_staff_floor"], "browse", ""],
	["CameraOperatorSeat", "CAMERA_OPERATOR", Vector3(6.85, UPPER, 2.0), 90.0, ["security_operator"], "desk_work", ""],
	["PoliceHarlowWest", "POLICE", Vector3(-30.0, ROAD_Y, 23.2), -90.0, ["police_harlow_west"], "", ""],
	["PoliceHarlowEast", "POLICE", Vector3(40.0, ROAD_Y, 23.2), 90.0, ["police_harlow_east"], "", ""],
	["PolicePellNorth", "POLICE", Vector3(25.2, ROAD_Y, -15.0), 180.0, ["police_pell_north"], "", ""],
	["PoliceAlleyWest", "POLICE", Vector3(-16.5, 0.0, -3.2), -90.0, ["police_alley_west"], "", ""],
]

## Patrol graphs: {graph: [graph_id, floor_index, {point: [pos, pause Vector2, anim, tags, face_yaw or null]}, edges]}.
## The doc's `ground` and `upper` networks are one graph (`building`): links must stay inside one
## PatrolGraph (heist_map.md §4 / patrols check), and the floors join through the stair points.
const PATROL_POINTS_BUILDING: Dictionary = {
	"G5Entrance": [Vector3(10.6, 0.0, 10.6), Vector2(3.0, 6.0), "idle", ["guard"], 0.0],
	"G5Chandelier": [Vector3(7.0, 0.0, 10.8), Vector2.ZERO, "idle", ["guard", "civilian"], null],
	"G5WestCases": [Vector3(2.0, 0.0, 9.0), Vector2.ZERO, "idle", ["guard", "civilian"], null],
	"G5CounterEnd": [Vector3(5.4, 0.0, 7.5), Vector2(2.0, 4.0), "idle", ["guard", "staff", "staff_floor"], null],
	"G5SalonDoor": [Vector3(12.2, 0.0, 9.4), Vector2(3.0, 5.0), "check_door", ["guard", "staff", "staff_floor", "civilian"], -90.0],
	"G5BehindCounter": [Vector3(2.0, 0.0, 6.65), Vector2.ZERO, "idle", ["guard", "staff", "staff_floor"], null],
	"G5FloorCases": [Vector3(8.6, 0.0, 8.0), Vector2(4.0, 8.0), "idle", ["staff", "staff_floor"], null],
	"G6Salon": [Vector3(14.2, 0.0, 9.6), Vector2(2.0, 4.0), "idle", ["guard", "civilian"], null],
	"G6BackDoor": [Vector3(16.5, 0.0, 7.1), Vector2.ZERO, "idle", ["guard"], null],
	"G4West": [Vector3(2.0, 0.0, 5.25), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"G4Mid": [Vector3(9.0, 0.0, 5.25), Vector2(2.0, 4.0), "idle", ["guard", "staff"], null],
	"G4Stair": [Vector3(13.8, 0.0, 5.25), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"G4East": [Vector3(16.5, 0.0, 5.25), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"G10Lobby": [Vector3(17.0, 0.0, 2.6), Vector2(2.0, 4.0), "check_door", ["guard"], -90.0],
	"G1Receiving": [Vector3(3.2, 0.0, 2.2), Vector2(2.0, 4.0), "check_door", ["guard"], 0.0],
	"G2Workshop": [Vector3(7.6, 0.0, 2.6), Vector2(2.0, 4.0), "idle", ["guard"], 0.0],
	"G2Bench": [Vector3(8.5, 0.0, 1.45), Vector2(30.0, 60.0), "idle", ["staff", "staff_boh"], 0.0],
	"G3WC": [Vector3(11.6, 0.0, 2.8), Vector2(20.0, 40.0), "idle", ["staff", "staff_boh", "staff_upper"], null],
	"StairLanding": [Vector3(14.5, 2.1, 0.8), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"U4StairTop": [Vector3(15.3, UPPER, 5.25), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"U4East": [Vector3(17.0, UPPER, 5.25), Vector2.ZERO, "idle", ["guard"], null],
	"U8Lobby": [Vector3(17.0, UPPER, 2.5), Vector2(2.0, 4.0), "idle", ["guard"], null],
	"U4Center": [Vector3(11.5, UPPER, 5.25), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"U4Mid": [Vector3(7.0, UPPER, 5.25), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"U4West": [Vector3(2.0, UPPER, 5.25), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"U1Break": [Vector3(4.0, UPPER, 3.6), Vector2(3.0, 6.0), "idle", ["guard", "staff", "staff_boh", "staff_upper"], null],
	"U1Coffee": [Vector3(4.3, UPPER, 1.2), Vector2(20.0, 40.0), "idle", ["staff", "staff_boh", "staff_upper"], -90.0],
	"U2Security": [Vector3(8.0, UPPER, 2.4), Vector2(5.0, 10.0), "lean", ["guard"], 0.0],
	"U3WC": [Vector3(11.5, UPPER, 2.8), Vector2(20.0, 40.0), "idle", ["staff", "staff_upper"], null],
	"U5Admin": [Vector3(3.0, UPPER, 7.6), Vector2(2.0, 4.0), "idle", ["guard", "staff", "staff_upper"], null],
	"U6Manager": [Vector3(9.5, UPPER, 7.6), Vector2(2.0, 4.0), "idle", ["guard", "staff", "staff_upper"], null],
	"U7Stock": [Vector3(14.9, UPPER, 7.0), Vector2(2.0, 4.0), "idle", ["guard"], null],
	"CivQueue": [Vector3(3.5, 0.0, 8.4), Vector2(10.0, 25.0), "idle", ["civilian"], 0.0],
	"CivIslandA": [Vector3(3.6, 0.0, 9.35), Vector2(8.0, 20.0), "idle", ["civilian"], 180.0],
	"CivWestCaseA": [Vector3(1.7, 0.0, 8.0), Vector2(8.0, 20.0), "idle", ["civilian"], 90.0],
	"CivWestCaseB": [Vector3(1.7, 0.0, 11.0), Vector2(8.0, 20.0), "idle", ["civilian"], 90.0],
	"CivWindowBench": [Vector3(5.0, 0.0, 10.8), Vector2(15.0, 30.0), "idle", ["civilian"], 180.0],
	"CivIslandB": [Vector3(9.8, 0.0, 9.6), Vector2(8.0, 20.0), "idle", ["civilian"], 0.0],
	"CivConsult": [Vector3(11.0, 0.0, 8.6), Vector2(10.0, 25.0), "idle", ["civilian"], 0.0],
}

const PATROL_EDGES_BUILDING: Array = [
	["G5Entrance", "G5Chandelier"], ["G5Entrance", "G5SalonDoor"], ["G5Chandelier", "G5WestCases"],
	["G5Chandelier", "G5CounterEnd"], ["G5WestCases", "G5BehindCounter"], ["G5CounterEnd", "G5BehindCounter"],
	["G5CounterEnd", "G5SalonDoor"], ["G5SalonDoor", "G6Salon"], ["G6Salon", "G6BackDoor"],
	["G6BackDoor", "G4East"], ["G5BehindCounter", "G4West"], ["G4West", "G1Receiving"],
	["G1Receiving", "G4Mid"], ["G4West", "G4Mid"], ["G4West", "G2Workshop"], ["G2Workshop", "G4Mid"],
	["G4Mid", "G4Stair"], ["G4Stair", "G4East"], ["G4East", "G10Lobby"], ["G10Lobby", "G4Stair"],
	["G4Stair", "StairLanding"], ["StairLanding", "U4StairTop"],
	["U4StairTop", "U4East"], ["U4East", "U8Lobby"], ["U8Lobby", "U4StairTop"], ["U4StairTop", "U4Center"],
	["U4Center", "U7Stock"], ["U7Stock", "U4StairTop"], ["U4Center", "U6Manager"], ["U6Manager", "U4Mid"],
	["U4Center", "U2Security"], ["U2Security", "U4Mid"], ["U4Center", "U4Mid"], ["U4Mid", "U4West"],
	["U4West", "U1Break"], ["U1Break", "U4Mid"], ["U4West", "U5Admin"], ["U5Admin", "U4Mid"],
	["U4Center", "U3WC"], ["G2Bench", "G2Workshop"], ["G3WC", "G4Mid"], ["G3WC", "G4Stair"],
	["G5FloorCases", "G5CounterEnd"], ["G5FloorCases", "G5SalonDoor"], ["U1Coffee", "U1Break"],
	["CivQueue", "G5CounterEnd"], ["CivQueue", "CivIslandA"], ["CivQueue", "CivWestCaseA"],
	["CivWestCaseA", "CivWestCaseB"], ["CivWestCaseB", "CivWindowBench"], ["CivIslandA", "CivWindowBench"],
	["CivWindowBench", "G5Chandelier"], ["CivIslandB", "G5Chandelier"], ["CivIslandB", "CivConsult"],
	["CivConsult", "G5SalonDoor"], ["CivIslandB", "G5Entrance"],
]

const PATROL_POINTS_ALLEY: Dictionary = {
	"AlleyBackDoor": [Vector3(3.5, 0.0, -1.7), Vector2(20.0, 40.0), "smoke", ["guard"], 0.0],
	"AlleyDumpsters": [Vector3(8.0, 0.0, -2.1), Vector2(20.0, 40.0), "smoke", ["guard"], null],
	"AlleyLadder": [Vector3(1.6, 0.0, -2.6), Vector2.ZERO, "idle", ["guard"], null],
	"AlleyHVAC": [Vector3(13.8, 0.0, -2.1), Vector2.ZERO, "idle", ["guard"], null],
	"AlleyMouth": [Vector3(17.5, 0.0, -3.2), Vector2(3.0, 6.0), "idle", ["guard"], -90.0],
	"AlleyVanSide": [Vector3(-1.5, 0.0, -3.2), Vector2.ZERO, "idle", ["guard"], null],
}
const PATROL_EDGES_ALLEY: Array = [
	["AlleyBackDoor", "AlleyDumpsters"], ["AlleyDumpsters", "AlleyHVAC"], ["AlleyHVAC", "AlleyMouth"],
	["AlleyBackDoor", "AlleyLadder"], ["AlleyLadder", "AlleyVanSide"], ["AlleyVanSide", "AlleyBackDoor"],
	["AlleyDumpsters", "AlleyMouth"],
]

## Tactical points: [name, kind, pos, yaw, tags, breachable].
const TACTICAL: Array = [
	["EntryMainDoor", "ENTRY", Vector3(11.25, 0.0, 13.2), 0.0, ["main_door"], false],
	["EntryShopBayA", "ENTRY", Vector3(1.8, 0.0, 13.2), 0.0, ["shopfront"], true],
	["EntryShopBayC", "ENTRY", Vector3(8.2, 0.0, 13.2), 0.0, ["shopfront"], true],
	["EntryBackDoor", "ENTRY", Vector3(3.5, 0.0, -1.4), 180.0, ["back_door"], false],
	["EntryFireExit", "ENTRY", Vector3(19.2, 0.0, 1.75), 90.0, ["fire_exit"], false],
	["EntrySalonEast", "ENTRY", Vector3(19.2, 0.0, 9.0), 90.0, ["salon_window"], true],
	["RappelRoofHatch", "RAPPEL", Vector3(17.0, 7.8, 2.0), 0.0, ["roof_hatch", "p3"], false],
	["CoverCounter", "COVER", Vector3(3.5, 0.0, 8.3), 0.0, ["counter"], false],
	["CoverChandelier", "COVER", Vector3(7.0, 0.0, 10.6), 0.0, ["chandelier"], false],
	["CoverIslandB", "COVER", Vector3(9.8, 0.0, 9.5), 0.0, ["display_case"], false],
	["CoverWorkshopDoor", "COVER", Vector3(6.5, 0.0, 5.3), 90.0, ["door_recess"], false],
	["CoverReceivingDoor", "COVER", Vector3(4.4, 0.0, 5.3), 90.0, ["door_recess"], false],
	["CoverStairFoot", "COVER", Vector3(14.3, 0.0, 5.4), 90.0, ["stair"], false],
	["CoverG10Corner", "COVER", Vector3(17.2, 0.0, 3.6), 0.0, ["corner"], false],
	["CoverDumpsters", "COVER", Vector3(8.0, 0.0, -1.9), 180.0, ["dumpster"], false],
	["CoverCarPell2", "COVER", Vector3(26.9, 0.0, 2.5), -90.0, ["vehicle"], false],
	["CoverCarHarlow3", "COVER", Vector3(16.0, 0.0, 18.8), 0.0, ["vehicle"], false],
	["FlankAlleyMouth", "FLANK", Vector3(19.6, 0.0, -4.5), 90.0, ["alley_mouth"], false],
	["SniperHotelRoof", "SNIPER_PERCH", Vector3(0.0, 17.0, 36.0), 0.0, ["hotel_roof", "p3"], false],
	["SniperGarageL2", "SNIPER_PERCH", Vector3(33.2, 3.0, 0.0), 90.0, ["garage_l2", "p3"], false],
]

## Pre-planning points (contracts/preplanning.md, heist_map.md v1.2): [id, category, pos, floor,
## params]. Labels are strings keys `ui.preplan.point.<id>`. Categories follow ENV B's asset library.
const PREPLAN_POINTS: Array = [
	["pp_alley_dumpsters", "drop_zone", Vector3(8.0, 0.0, -2.2), 0, {}],
	["pp_alley_hvac", "drop_zone", Vector3(13.8, 0.0, -2.2), 0, {}],
	["pp_side_kerb", "drop_zone", Vector3(20.6, 0.0, 6.0), 0, {}],
	["pp_spawn_alley_west", "player_spawn", Vector3(-12.5, 0.0, -3.3), 0, {"spawn_tag": &"preplan_spawn_alley"}],
	["pp_spawn_alley_mouth", "player_spawn", Vector3(19.6, 0.0, -2.4), 0, {"spawn_tag": &"preplan_spawn_alley_mouth"}],
	["pp_escape_alley_west", "escape", Vector3(-8.5, 0.0, -3.2), 0, {"variant_group": &"escape", "variant_slot": &"esc_alley_west"}],
	["pp_escape_side_street", "escape", Vector3(22.4, -0.15, 7.0), 0, {"variant_group": &"escape", "variant_slot": &"esc_pell"}],
	["pp_insider_breakroom", "insider", Vector3(1.2, 4.2, 2.6), 1, {"variant_group": &"keycard", "variant_slot": &"kc_breakroom"}],
	["pp_back_door", "access", Vector3(3.5, 0.0, -1.0), 0, {"variant_group": &"back_door", "variant_slot": &"back_propped"}],
]


# --- Rooms and zones ------------------------------------------------------------------------

## [id, purpose, dressing_kit, floor_index, boxes, ceiling_range override or null].
const ROOMS: Array = [
	["G1", "storage", "storage_receiving", 0, [[2.0, 0.0, 0.0, 5.0, 3.0, 2.0], [0.0, 0.0, 2.0, 5.0, 3.0, 4.5]], null],
	["G7", "electrical", "electrical_closet", 0, [[0.0, 0.0, 0.0, 2.0, 3.0, 2.0]], null],
	["G2", "workshop", "workshop_jeweler", 0, [[5.0, 0.0, 0.0, 10.5, 3.0, 4.5]], Vector2(2.6, 3.0)],
	["G3", "restroom", "restroom_single", 0, [[10.5, 0.0, 0.0, 13.0, 3.0, 4.5]], null],
	["G4", "corridor", "corridor_service", 0, [[0.0, 0.0, 4.5, 18.0, 3.0, 6.0]], null],
	["G8", "stair", "", 0, [[13.0, 0.0, 0.0, 14.5, 7.6, 4.5], [14.5, 0.0, 0.0, 16.0, 7.6, 3.0]], null],
	["G9", "storage", "janitor_closet", 0, [[14.5, 0.0, 3.0, 16.0, 2.8, 4.5]], null],
	["G10", "corridor", "corridor_service", 0, [[16.0, 0.0, 0.0, 18.0, 3.0, 4.5]], null],
	["G5", "sales_floor", "sales_floor_jewelry", 0, [[0.0, 0.0, 6.0, 13.0, 3.6, 12.0]], null],
	["G6", "sales_floor", "salon_private", 0, [[13.0, 0.0, 6.0, 18.0, 3.2, 12.0]], null],
	["U1", "break_room", "break_room", 1, [[0.0, UPPER, 0.0, 5.5, 7.2, 4.5]], null],
	["U2", "security_room", "security_office", 1, [[5.5, UPPER, 0.0, 10.5, 7.2, 4.5]], null],
	["U3", "restroom", "restroom_single", 1, [[10.5, UPPER, 0.0, 13.0, 7.2, 4.5]], null],
	["U4", "corridor", "corridor_office", 1, [[0.0, UPPER, 4.5, 18.0, 7.2, 6.0]], null],
	["U8", "corridor", "corridor_service", 1, [[16.0, UPPER, 0.0, 18.0, 7.2, 4.5]], null],
	["U5", "office", "office_open", 1, [[0.0, UPPER, 6.0, 7.0, 7.2, 12.0]], null],
	["U6", "office", "office_manager", 1, [[7.0, UPPER, 6.0, 12.0, 7.2, 12.0]], null],
	["U7", "storage", "storage_archive", 1, [[12.0, UPPER, 6.0, 18.0, 7.2, 12.0]], null],
	["X1", "exterior", "exterior_alley", 0, [[-14.0, 0.0, -6.2, 18.2, 4.0, -0.2]], null],
	["X2", "exterior", "exterior_street", 0, [[-14.0, ROAD_Y, 12.2, 32.2, 4.0, 34.2],
		[18.2, ROAD_Y, -8.0, 32.2, 4.0, 12.2], [18.2, ROAD_Y, 34.2, 32.2, 4.0, 40.0]], null],
]

## Fixed MapZones: [name, kind, zone_id, boxes]. Salon PUBLIC/RESTRICTED lives in the `salon` slots;
## SECURE_LOOT/ESCAPE in the `escape` slots; dumpster BODY_HIDE in the body_container prefabs.
const ZONES: Array = [
	["PublicStreets", "PUBLIC", "street", [[-14.0, -0.5, 12.2, 32.2, 4.0, 34.2], [18.2, -0.5, -8.0, 32.2, 4.0, 12.2],
		[18.2, -0.5, 34.2, 32.2, 4.0, 40.0]]],
	["PublicAlley", "PUBLIC", "alley", [[-14.0, -0.5, -6.2, 18.2, 4.0, -0.2]]],
	["PublicSalesFloor", "PUBLIC", "sales_floor", [[0.2, -0.2, 7.2, 12.9, 3.6, 11.8], [5.2, -0.2, 6.1, 12.9, 3.6, 7.2]]],
	["RestrictedBehindCounter", "RESTRICTED", "behind_counter", [[0.2, -0.2, 6.1, 5.2, 3.6, 7.2]]],
	["RestrictedBackOfHouse", "RESTRICTED", "back_of_house", [[0.2, -0.2, 0.2, 17.8, 4.0, 6.0]]],
	["RestrictedUpstairs", "RESTRICTED", "upstairs", [[0.2, 4.0, 0.2, 17.8, 7.6, 11.8]]],
	["BodyHideJanitor", "BODY_HIDE", "janitor_closet", [[14.6, -0.2, 3.1, 15.9, 2.8, 4.4]]],
]

# --- Review cameras ---------------------------------------------------------------------------

## [name, position, look-at target, fov, caption]. TopDown* are orthographic (size = fov field).
const REVIEW_CAMERAS: Array = [
	["TopDownSite", Vector3(9.0, 60.0, 13.0), Vector3(9.0, 0.0, 13.0), 64.0,
		"Top-down site: building, alley, Harlow Ave, Pell St, closures"],
	["TopDownBuilding", Vector3(9.0, 40.0, 6.0), Vector3(9.0, 0.0, 6.0), 24.0, "Top-down building footprint (roof, parapet, HVAC, hatch)"],
	["ExtHarlowCorner", Vector3(27.0, 1.7, 31.0), Vector3(14.0, 3.5, 11.0), 70.0,
		"Exterior: Harlow Ave / Pell St corner, neon sign + salon glazing (landmark)"],
	["ExtShopfront", Vector3(5.0, 1.7, 24.0), Vector3(6.0, 2.0, 11.0), 70.0,
		"Exterior: shopfront from Harlow Ave; chandelier display visible through the glass"],
	["ExtAlleyWest", Vector3(-12.5, 2.6, -5.6), Vector3(6.0, 1.2, -1.0), 70.0,
		"Exterior: service alley from the west (van E1 slot, back door, dumpsters, fire escape)"],
	["ExtAlleyMouth", Vector3(24.5, 1.7, -4.5), Vector3(5.0, 2.0, -2.0), 70.0, "Exterior: alley mouth from Pell St"],
	["ExtFireEscape", Vector3(5.5, 1.7, -5.2), Vector3(2.2, 3.8, -0.6), 70.0,
		"Exterior: fire-escape ladder + landing under the break-room window"],
	["ExtPellFireExit", Vector3(26.0, 1.7, 12.0), Vector3(18.0, 1.5, 2.0), 70.0, "Exterior: Pell St side, fire exit + van E2 slot"],
	["SalesFloorEntrance", Vector3(11.8, 1.65, 11.2), Vector3(3.0, 1.2, 7.0), 75.0,
		"G5 sales floor from the entrance (floor guard post view)"],
	["ChandelierLandmark", Vector3(2.0, 2.0, 11.2), Vector3(7.0, 1.6, 9.0), 70.0, "G5 chandelier display (landmark) and island cases"],
	["CounterStaffDoor", Vector3(8.1, 2.0, 6.45), Vector3(1.5, 0.9, 7.2), 70.0, "G5 sales counter, register, staff door behind it"],
	["SalonPrivate", Vector3(17.4, 1.65, 11.4), Vector3(13.6, 1.0, 7.0), 75.0, "G6 private salon (variable lock), cases, vitrine"],
	["CorridorG4", Vector3(17.4, 1.65, 5.25), Vector3(0.0, 1.4, 5.25), 60.0, "G4 staff corridor: the 18 m sightline (stealth crux)"],
	["WorkshopSafe", Vector3(10.0, 1.65, 4.0), Vector3(6.5, 0.8, 0.5), 75.0, "G2 workshop: the safe, keycard reader, jeweler benches"],
	["ReceivingBackDoor", Vector3(4.6, 1.65, 4.1), Vector3(2.5, 1.0, 0.3), 75.0,
		"G1 receiving, back door to the alley, G7 electrical door"],
	["StairCore", Vector3(13.8, 1.65, 5.7), Vector3(14.0, 2.6, 0.8), 75.0, "G8 U-stair from the corridor foot"],
	["UpperCorridor", Vector3(0.6, 5.85, 5.25), Vector3(18.0, 5.6, 5.25), 60.0, "U4 upper corridor and void railing"],
	["SecurityOffice", Vector3(10.0, 5.85, 4.1), Vector3(6.0, 5.0, 1.5), 75.0,
		"U2 security office: camera station (P2), key cabinet, alley window"],
	["BreakRoom", Vector3(5.0, 5.85, 4.1), Vector3(1.5, 5.0, 0.5), 75.0, "U1 break room, fire-escape window, lockers"],
	["ManagerOffice", Vector3(11.5, 5.85, 6.6), Vector3(8.0, 4.8, 10.5), 75.0, "U6 manager office (keycard / cash slots)"],
	["AdminOffice", Vector3(6.5, 5.85, 6.6), Vector3(1.0, 4.8, 10.5), 75.0, "U5 admin and appraisal office"],
	["StockRoom", Vector3(17.4, 5.85, 6.6), Vector3(13.0, 4.8, 10.5), 75.0, "U7 stock and archive"],
	["GaragePerch", Vector3(33.4, 4.6, 0.0), Vector3(17.0, 2.0, 3.0), 70.0,
		"Garage level 2 (P3 sniper perch) toward the alley mouth and salon"],
]
