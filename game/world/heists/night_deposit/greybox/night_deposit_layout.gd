## Night Deposit (Harbor Savings & Loan) greybox layout data. Owner: ENV C (C2, G1).
## Source of truth for build_greybox.gd. Design: docs/design/heists/night_deposit.md (APPROVED, D-040).
## Coordinates: metres, world x = plan x (east), world z = plan z (south), +y up. Origin = the NW
## corner of the building on the wall centre lines (the plan's origin). Ground FFL 0.0, basement
## FFL -4.0 (floor_heights [-4.0, 0.0]: index 0 = basement, 1 = ground).
## Boxes are [x0, y0, z0, x1, y1, z1]. Wall openings are [along0, along1, sill_y, head_y] (absolute).
## Never edit the generated night_deposit.tscn by hand: change this file and rerun the generator.
extends RefCounted

const FLOOR_HEIGHTS: Array[float] = [-4.0, 0.0]
const BASE: float = -4.0
const EXT_T: float = 0.4
const INT_T: float = 0.2
const VAULT_T: float = 0.6
## Basement ceiling = ground slab underside (0.8 m heavy vault slab); vault ceiling 3.0.
const BASE_CEIL: float = -0.8
const VAULT_CEIL: float = -1.0
const WING_CEIL: float = 3.0
const HALL_CEIL: float = 5.5
const WING_ROOF: float = 3.6
const HALL_ROOF: float = 6.5
const WING_PARAPET: float = 4.4
const HALL_PARAPET: float = 7.3
const ROAD_Y: float = -0.15
## Basement door openings: FFL -4.0 to -1.8 (2.2 m).
const BD: float = -1.8
const WATER_Y: float = -1.6
## Ceiling range override for the 3.2 m basement utility rooms (doc vertical data; level_standards
## table is 2.6-3.0 for office/storage purposes). Listed in the validation report for lead review.
const BASEMENT_CEIL_RANGE: Vector2 = Vector2(2.6, 3.2)


# --- Building shell -------------------------------------------------------------------------

## Exterior walls (two half-thickness skins: `wall_ext` outside, `wall` inside):
## [name, axis ("x" = runs along x at fixed z, "z" = along z at fixed x), fixed, outer skin from/to,
##  inner skin from/to, y0, y1, out_sign (-1 = outside towards smaller fixed coordinate), openings].
const EXT_WALLS: Array = [
	["ExtNorth", "x", 0.0, -0.2, 26.2, 0.2, 25.8, -4.3, WING_PARAPET, -1.0, [
		[2.0, 5.0, 0.0, 2.8],          # sally roller door (3.0 m; closed shutter, breach point in loud)
		[5.5, 6.5, 0.0, 2.2],          # steel personnel door G1 -> lot
		[17.7, 18.7, -4.0, BD],        # basement areaway door (pit -> B3 plant)
		[21.6, 22.6, 0.0, 2.2],        # PO6-17 Breach_3: blocked-up doorway lot -> G6 (infilled; AreawayLamp above x 21.5)
	]],
	["ExtSouthHall", "x", 20.0, -0.2, 21.2, 0.2, 20.9, -4.3, HALL_PARAPET, 1.0, [
		[1.0, 4.0, 1.0, 4.5], [4.5, 7.5, 1.0, 4.5],       # banking hall tall windows (sill 1.0, 3.5 tall)
		[9.5, 11.5, 0.0, 2.2],                             # bronze entrance (double)
		[13.5, 16.5, 1.0, 4.5], [17.0, 20.0, 1.0, 4.5],
	]],
	["ExtSouthEast", "x", 20.0, 21.2, 26.2, 21.1, 25.8, -4.3, WING_PARAPET, 1.0, [
		[21.6, 23.4, 0.3, 2.7],        # ATM vestibule green glass
		[23.75, 24.75, 0.0, 2.2],        # ATM card-reader street door
		[24.9, 25.7, 0.3, 2.7],
	]],
	["ExtWestWing", "z", 0.0, 0.0, 10.0, 0.2, 10.0, -4.3, WING_PARAPET, -1.0, []],   # party wall (chandlery)
	["ExtWestHall", "z", 0.0, 10.0, 20.0, 10.0, 19.8, -4.3, HALL_PARAPET, -1.0, []],
	["ExtEast", "z", 26.0, 0.0, 20.0, 0.2, 19.8, -4.3, WING_PARAPET, 1.0, [
		[6.15, 7.35, 0.0, 2.2],        # fire exit G7 -> Wharf Lane
		[9.0, 11.0, 0.9, 2.1],         # G11 loan office window
		[13.0, 15.0, 0.9, 2.1],        # G12 manager window
	]],
	# Stepped massing: the banking hall rises above the +3.6 wing roofs (soffit at 3.0 inside).
	["HallNorthUpper", "x", 10.0, -0.2, 21.2, 0.2, 20.9, WING_CEIL, HALL_PARAPET, -1.0, []],
	["HallEastUpper", "z", 21.0, 10.2, 19.8, 10.2, 19.8, WING_CEIL, HALL_PARAPET, 1.0, []],
]

## Interior walls: [name, axis, fixed, from, to, y0, y1, openings, thickness (optional)].
## Ground walls stop at the 3.0 ceilings; stair core walls run from the basement to the wing roof.
const INT_WALLS: Array = [
	# Stair core G2 (x 7-10, z 0-6), both floors.
	["Core_X7", "z", 7.0, 0.2, 5.9, BASE, 3.35, []],
	["Core_X10", "z", 10.0, 0.2, 5.9, BASE, 3.35, []],
	# Ground floor, back wing.
	["G_X14", "z", 14.0, 0.2, 5.9, 0.0, WING_CEIL, []],
	["G_X18", "z", 18.0, 0.2, 5.9, 0.0, WING_CEIL, []],
	["G_X21_N", "z", 21.0, 0.2, 5.9, 0.0, WING_CEIL, []],
	["G_Z6_W", "x", 6.0, 0.2, 7.0, 0.0, WING_CEIL, [[5.5, 6.5, 0.0, 2.2]]],
	# G2/G7: stair entry (flight 1 head, x 7.1-8.3) and the railed shaft over flight 2 (x 8.7-9.9).
	["G_Z6_Core", "x", 6.0, 7.0, 10.0, 0.0, WING_CEIL, [[7.1, 8.3, 0.0, 2.2], [8.7, 9.9, 0.0, 2.2]]],
	["G_Z6_E", "x", 6.0, 10.0, 25.8, 0.0, WING_CEIL,
		[[11.5, 12.5, 0.0, 2.2], [15.5, 16.5, 0.0, 2.2], [19.0, 20.0, 0.0, 2.2], [23.0, 24.0, 0.0, 2.2]]],
	["G_Z7_5", "x", 7.5, 0.2, 25.8, 0.0, WING_CEIL, [[1.5, 2.5, 0.0, 2.2], [23.0, 24.0, 0.0, 2.2]]],
	# G8/G9: teller gate at x 1, counter x 2-19 (prop + bandit glass), wall x 19-21. Soffit above 3.0.
	["G_Z10_W", "x", 10.0, 0.2, 2.0, 0.0, WING_CEIL, [[0.5, 1.5, 0.0, 2.2]]],
	["G_Z10_E", "x", 10.0, 19.0, 20.9, 0.0, WING_CEIL, []],
	# x 21: G8/G11, and the glass fronts of G11/G12 + the ATM inner door (G13) on the hall side.
	["G_X21_S", "z", 21.0, 7.6, 19.8, 0.0, WING_CEIL, [
		[10.0, 11.0, 0.0, 2.2], [11.15, 11.85, 0.9, 2.4],
		[12.25, 13.35, 0.9, 2.4], [13.5, 14.5, 0.0, 2.2], [14.65, 15.8, 0.9, 2.4],
		[17.5, 18.5, 0.0, 2.2],
	]],
	["G_Z12", "x", 12.0, 21.1, 25.8, 0.0, WING_CEIL, []],
	["G_Z16", "x", 16.0, 21.1, 25.8, 0.0, WING_CEIL, []],
	# G10 entry vestibule inside the hall footprint.
	["G_X8_5", "z", 8.5, 18.0, 19.8, 0.0, WING_CEIL, []],
	["G_X12_5", "z", 12.5, 18.0, 19.8, 0.0, WING_CEIL, []],
	["G_Z18", "x", 18.0, 8.4, 12.6, 0.0, WING_CEIL, [[9.5, 11.5, 0.0, 2.2]]],
	# Basement (FFL -4.0, ceiling -0.8).
	["B_X16", "z", 16.0, 0.2, 5.9, BASE, BASE_CEIL, []],
	["B_X21_N", "z", 21.0, 0.2, 5.9, BASE, BASE_CEIL, []],
	["B_X13_5", "z", 13.5, 0.2, 2.5, BASE, BASE_CEIL, []],
	["B_Z2_5", "x", 2.5, 13.5, 15.9, BASE, BASE_CEIL, [[14.25, 15.25, BASE, BD]]],
	["B_Z3_5", "x", 3.5, 7.1, 8.4, BASE, BASE_CEIL, []],
	["B_X8_5", "z", 8.5, 3.6, 5.9, BASE, BASE_CEIL, []],
	["B_Z6", "x", 6.0, 0.2, 25.8, BASE, BASE_CEIL, [
		[3.0, 4.0, BASE, BD], [7.25, 8.25, BASE, BD], [8.7, 9.9, BASE, BD],
		[11.5, 12.5, BASE, BD], [18.0, 19.0, BASE, BD], [23.0, 24.0, BASE, BD],
	]],
	["B_Z7_5", "x", 7.5, 0.2, 25.8, BASE, BASE_CEIL, [
		[3.0, 4.0, BASE, BD], [7.5, 8.5, BASE, BD], [13.0, 15.0, BASE, BD],
		[19.5, 20.5, BASE, BD], [23.0, 24.0, BASE, BD],
	]],
	["B_X7_S", "z", 7.0, 7.6, 19.8, BASE, BASE_CEIL, []],
	["B_X9_N", "z", 9.0, 7.6, 9.7, BASE, BASE_CEIL, []],
	["B_X19_N", "z", 19.0, 7.6, 9.7, BASE, BASE_CEIL, []],
	["B_X21_S", "z", 21.0, 7.6, 19.8, BASE, BASE_CEIL, []],
	["B_Z14", "x", 14.0, 21.1, 25.8, BASE, BASE_CEIL, [[23.0, 24.0, BASE, BD]]],
	# Vault B9: reinforced walls 0.6 m (%). The south side lines the exterior wall.
	["Vault_N", "x", 10.0, 8.7, 19.3, BASE, BASE_CEIL, [[12.8, 15.2, BASE, BASE + 2.3]], VAULT_T],
	["Vault_W", "z", 9.0, 10.3, 19.7, BASE, BASE_CEIL, [], VAULT_T],
	["Vault_E", "z", 19.0, 10.3, 19.7, BASE, BASE_CEIL, [], VAULT_T],
	["Vault_S", "x", 19.75, 9.3, 18.7, BASE, BASE_CEIL, [], 0.1],
]

## Slabs: [name, box, material]. The ground slab (0.8 m) has the stair hole (flight 1, landing,
## flight 2 and the railed shaft to the corridor).
const SLABS: Array = [
	["BasementFloor", [-0.2, -4.3, -0.2, 26.2, BASE, 20.2], "floor"],
	["GroundSlabW", [-0.2, BASE_CEIL, -0.2, 7.1, 0.0, 20.2], "floor"],
	["GroundSlabE", [9.9, BASE_CEIL, -0.2, 26.2, 0.0, 20.2], "floor"],
	["GroundSlabCoreN", [7.1, BASE_CEIL, -0.2, 9.9, 0.0, 0.2], "floor"],
	["GroundSlabCoreTop", [7.1, BASE_CEIL, 4.2, 8.7, 0.0, 20.2], "floor"],
	["GroundSlabCoreS", [8.7, BASE_CEIL, 5.85, 9.9, 0.0, 20.2], "floor"],
	["VaultRoof", [9.3, VAULT_CEIL, 10.3, 18.7, BASE_CEIL, 19.7], "ceiling"],
	["WingRoof", [0.2, 3.35, 0.2, 25.8, WING_ROOF, 9.8], "roof"],
	["OfficesRoof", [21.1, 3.35, 9.8, 25.8, WING_ROOF, 19.8], "roof"],
	["HallRoof", [0.2, 6.25, 10.2, 20.8, HALL_ROOF, 19.8], "roof"],
]

## Ceilings (0.05 m thick, underside at the room's ceiling height).
const CEILINGS: Array = [
	["CeilWingW", [0.0, WING_CEIL, 0.0, 7.0, 3.05, 10.0]],
	["CeilWingMid", [7.0, WING_CEIL, 6.0, 10.0, 3.05, 10.0]],
	["CeilWingE", [10.0, WING_CEIL, 0.0, 26.0, 3.05, 10.0]],
	["CeilOffices", [21.0, WING_CEIL, 10.0, 26.0, 3.05, 20.0]],
	["CeilVestibule", [8.5, WING_CEIL, 18.0, 12.5, 3.05, 20.0]],
	["CeilHall", [0.0, HALL_CEIL, 10.0, 21.0, 5.55, 20.0]],
	["CeilJanitor", [7.1, -0.85, 3.6, 8.4, BASE_CEIL, 4.2]],
]

## U-stair G2 (doc vertical data): 2 flights x 11 risers @ 4.0/22 m, tread 0.28, width 1.2, half
## landing at -2.0 (z 0.2-1.4, full core width). Flight 1 (x 7.1-8.3) descends north from the ground
## floor (z 4.2) to the landing; flight 2 (x 8.7-9.9) descends south from the landing to the basement
## (z 4.2). Visual steps are meshes; the collision is a smooth ramp through the nosings (validator
## convention (b)). Under flight 1 the janitor closet B14 (z >= 3.5) keeps a 3.2 m ceiling.
const STAIR: Dictionary = {
	"riser": 4.0 / 22.0, "tread": 0.28, "risers_per_flight": 11, "landing_z": [0.2, 1.4],
	"f1_x": [7.1, 8.3], "f2_x": [8.7, 9.9], "landing_x": [7.1, 9.9], "landing_y": -2.0,
	"divider_x": [8.3, 8.7], "b14_z": 3.5, "ramp_t": 0.3,
	# Wall handrails on both sides of both flights (§2 MUST, lead ruling): round bar, centre `rail_h`
	# above the nosing line (top ~0.88 m over the true nosings; the validator line runs below the bottom
	# nosing, so it reads 0.93-1.05 m), `rail_off` out from the wall face, brackets, wall returns.
	"rail_h": 0.86, "rail_off": 0.07, "rail_r": 0.02,
}

## Railings (collision panel + rails/posts): [name, box]. Height 1.05 above the floor they stand on.
const RAILINGS: Array = [
	["RailStairTop", [8.62, 0.0, 4.2, 8.68, 1.05, 5.85]],
	["RailShaft", [8.7, 0.0, 5.87, 9.9, 1.05, 5.93]],
	# Quay chain railing (1.0 m), open at the steps (x 6-11).
	["RailQuayW", [-14.0, 0.0, 33.9, 5.9, 1.0, 33.96]],
	["RailQuayE", [11.1, 0.0, 33.9, 40.0, 1.0, 33.96]],
]

## Static glazing: [name, axis, fixed, a0, a1, y0, y1]. Glass blocker (collision) + pane + frame.
## The ATM vestibule's street glazing is the green-glass jewel (doc landmark 3).
const GLAZING: Array = [
	["G11East", "z", 26.0, 9.0, 11.0, 0.9, 2.1],
	["G12East", "z", 26.0, 13.0, 15.0, 0.9, 2.1],
	["AtmSouthA", "x", 20.0, 21.6, 23.4, 0.3, 2.7],
	["AtmSouthB", "x", 20.0, 24.9, 25.7, 0.3, 2.7],
	["G11Front", "z", 21.0, 11.15, 11.85, 0.9, 2.4],
	["G12FrontA", "z", 21.0, 12.25, 13.35, 0.9, 2.4],
	["G12FrontB", "z", 21.0, 14.65, 15.8, 0.9, 2.4],
	["BanditGlass", "x", 10.0, 2.0, 19.0, 1.05, 2.25],
	["HallTransom1", "x", 20.0, 1.0, 4.0, 3.4, 4.5],
	["HallTransom2", "x", 20.0, 4.5, 7.5, 3.4, 4.5],
	["HallTransom3", "x", 20.0, 13.5, 16.5, 3.4, 4.5],
	["HallTransom4", "x", 20.0, 17.0, 20.0, 3.4, 4.5],
]

## Gameplay windows (breakable; police ENTRY bays): [name, kit piece, sill origin, yaw_deg].
## Yaw: 0 = front faces north (-z), 180 = south (+z), -90 = east (+x), 90 = west (-x).
const WINDOWS: Array = [
	["HallBay1", "prop_window_shop_w300_h240", Vector3(2.5, 1.0, 20.0), 180.0],
	["HallBay2", "prop_window_shop_w300_h240", Vector3(6.0, 1.0, 20.0), 180.0],
	["HallBay3", "prop_window_shop_w300_h240", Vector3(15.0, 1.0, 20.0), 180.0],
	["HallBay4", "prop_window_shop_w300_h240", Vector3(18.5, 1.0, 20.0), 180.0],
]

## Doors: [name, visual asset (world/props/door), origin (bottom-centre of the opening on the wall line), yaw_deg, lock,
## swing, objective_tag, extra]. Front (-Z, UsePoint side) is the corridor / outside side; INWARD
## leaves swing to the back (+Z) side, into the room (level_standards §3.3).
## Staff "keycard" doors other than the vault gate are LOCKPICK with guard/staff authorisation:
## the run has one keycard and the vault gate consumes it (deviation noted in the G1 report).
const STAFF_TAGS: Array = ["guard_hall", "guard_basement", "guard_rover", "civ_manager", "civ_cleaner"]
const DOORS: Array = [
	["SallyPersonnelDoor", "prop_door_single_steel_t40", Vector3(6.0, 0.0, 0.0), 0.0, "LOCKPICK", "INWARD", "sally_door",
		{"npc_auth": true}],
	["LoadingDoor", "prop_door_single_steel_t20", Vector3(6.0, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["SecurityRoomDoor", "prop_door_single_steel_t20", Vector3(12.0, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["BreakRoomDoor", "prop_door_single_ivory_t20", Vector3(16.0, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["ElectricalDoor", "prop_door_single_steel_t20", Vector3(19.5, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["StorageDoor", "prop_door_single_ivory_t20", Vector3(23.5, 0.0, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["TellerDoor", "prop_door_single_walnut_t20", Vector3(2.0, 0.0, 7.5), 0.0, "LOCKPICK", "INWARD", "teller_door",
		{"npc_auth": true}],
	["LoanCorridorDoor", "prop_door_single_ivory_t20", Vector3(23.5, 0.0, 7.5), 0.0, "NONE", "INWARD", "", {}],
	["FireExit", "prop_door_service_steel_t40", Vector3(26.0, 0.0, 6.75), 90.0, "NONE", "INWARD", "fire_exit",
		{"service": true, "fire_exit": true, "suspicious_when_open": true}],
	["TellerGate", "prop_door_single_walnut_t20", Vector3(1.0, 0.0, 10.0), 180.0, "LOCKPICK", "INWARD", "teller_gate",
		{"npc_auth": true}],
	["LoanHallDoor", "prop_door_single_walnut_t20", Vector3(21.0, 0.0, 10.5), 90.0, "NONE", "INWARD", "", {}],
	["ManagerHallDoor", "prop_door_single_walnut_t20", Vector3(21.0, 0.0, 14.0), 90.0, "NONE", "INWARD", "", {}],
	["AtmInnerDoor", "prop_door_single_glass_t20", Vector3(21.0, 0.0, 18.0), -90.0, "LOCKPICK", "INWARD", "atm_door", {}],
	["VestibuleInnerDoors", "prop_door_double_glass_t20", Vector3(10.5, 0.0, 18.0), 180.0, "LOCKPICK", "DOUBLE", "", {}],
	["MainEntrance", "prop_door_double_bronze_t40", Vector3(10.5, 0.0, 20.0), 180.0, "LOCKPICK", "DOUBLE", "main_entrance", {}],
	["AtmStreetDoor", "prop_door_single_steel_t40", Vector3(24.25, 0.0, 20.0), 180.0, "NONE", "INWARD", "atm_street_door", {"public": true}],
	# Basement.
	["XferDoor", "prop_door_single_steel_t20", Vector3(3.5, BASE, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["JanitorDoor", "prop_door_single_ivory_t20", Vector3(7.75, BASE, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["LockerRoomDoor", "prop_door_single_ivory_t20", Vector3(12.0, BASE, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["WCDoor", "prop_door_single_ivory_t20", Vector3(14.75, BASE, 2.5), 180.0, "NONE", "INWARD", "", {}],
	["PlantDoor", "prop_door_single_steel_t20", Vector3(18.5, BASE, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["ServerDoor", "prop_door_single_steel_t20", Vector3(23.5, BASE, 6.0), 180.0, "LOCKPICK", "INWARD", "server_door",
		{"npc_auth": true}],
	["RecordsDoor", "prop_door_single_ivory_t20", Vector3(3.5, BASE, 7.5), 0.0, "NONE", "INWARD", "", {}],
	# B5 -> B7/B10: corridor to dead-end inspection passage, a fire-rated steel door (both sides are
	# corridors, so it carries fire_exit like Glasshouse's LobbyDoor; it swings into the passage).
	["InspectionWestDoor", "prop_door_single_steel_t20", Vector3(8.0, BASE, 7.5), 0.0, "NONE", "INWARD", "", {"fire_exit": true}],
	["VaultGate", "prop_door_double_grille_t20", Vector3(14.0, BASE, 7.5), 0.0, "KEYCARD", "DOUBLE", "vault_gate",
		{"npc_auth": true}],
	["InspectionEastDoor", "prop_door_single_steel_t20", Vector3(20.0, BASE, 7.5), 0.0, "NONE", "INWARD", "", {"fire_exit": true}],
	["CountRoomDoor", "prop_door_single_steel_t20", Vector3(23.5, BASE, 7.5), 0.0, "LOCKPICK", "INWARD", "count_door",
		{"npc_auth": true}],
	["DepositoryDoor", "prop_door_single_steel_t20", Vector3(23.5, BASE, 14.0), 0.0, "LOCKPICK", "INWARD", "depository_door",
		{"npc_auth": true}],
	# Round vault door, 2.2 m (validator vault-door rule 1.8-2.4 m): prop_vault_door_round (tools/blender/props/bank.py).
	["VaultDoor", "prop_vault_door_round", Vector3(14.0, BASE, 10.0), 0.0, "VAULT", "INWARD", "vault_door",
		{"width_m": 2.2}],
	["AreawayDoor", "prop_door_single_steel_t40", Vector3(18.2, BASE, 0.0), 0.0, "NONE", "INWARD", "areaway_door", {}],
	# Play-space closures: chained/barred gates the police open in loud (mission unlocks them).
	["AlleyGate", "prop_door_double_steel_t10", Vector3(-14.0, 0.0, -12.5), -90.0, "BARRED", "DOUBLE", "police_gate", {}],
	["HarborWestGate", "prop_door_double_steel_t10", Vector3(-14.0, ROAD_Y, 26.2), -90.0, "BARRED", "DOUBLE", "police_gate", {}],
	["HarborEastGate", "prop_door_double_steel_t10", Vector3(40.0, ROAD_Y, 26.2), 90.0, "BARRED", "DOUBLE", "police_gate", {}],
	["WharfNorthGate", "prop_door_double_steel_t10", Vector3(27.6, 0.0, -14.0), 180.0, "BARRED", "DOUBLE", "police_gate", {}],
]

## Areaway (vent route): pit outside the north wall (floor -4.0), ladder on the ledge face, caged
## top with the grate gate (variant `vent_open`: unlocked 3 s / padlocked lockpick 8 s).
const AREAWAY: Dictionary = {
	"pit": [17.6, BASE, -2.4, 18.8, 0.0, -0.2], "ledge": [16.9, -4.3, -2.6, 17.6, 0.0, -0.2],
	"gate_pos": Vector3(16.95, 0.0, -1.4), "gate_yaw": 90.0, "ladder_pos": Vector3(17.6, BASE, -0.55),
	"ladder_yaw": -90.0, "cage_h": 2.2,
}

## Cash lift (bags only) G1 <-> B1 in the NE corner of the sally port: shaft footprint, the bag_lift
## car floor centre at G1 = landing 0 (0.05 m sill so the car floor rests on the slab; B1 is BASE below),
## and the bag hatch in the west shaft wall on each floor (z range, sill/head above the floor: 0.8 m
## high, too low for a crouched crew capsule) with the call panel above it, `panel_y` above the car
## floor (`art/nd_cash_lift.tscn` Panel at G1, a dressed panel at B1 for the runtime LandingPanel1).
const LIFT: Dictionary = {"box": [5.6, 1.1, 6.9, 2.5], "car": Vector3(6.25, 0.05, 1.8), "hatch_z": [1.2, 2.4],
	"hatch_y": [0.45, 1.25], "panel_y": 1.45}


# --- Site -----------------------------------------------------------------------------------

## Ground surfaces: [name, box, material]. Lot/alley/sidewalks/quay top 0.0, carriageways -0.15.
const GROUND: Array = [
	["LotW", [-14.0, -0.3, -15.0, 16.9, 0.0, -0.2], "paving"],
	["LotMid", [16.9, -0.3, -15.0, 19.0, 0.0, -2.6], "paving"],
	["LotE", [19.0, -0.3, -15.0, 26.2, 0.0, -0.2], "paving"],
	["AlleyWestVista", [-30.0, -0.3, -15.0, -14.0, 0.0, -10.0], "paving"],
	["WarehouseYard", [-30.0, -0.3, -19.0, 26.2, 0.0, -15.0], "paving"],
	["AreawayPitFloor", [16.9, -4.3, -2.6, 19.0, BASE, -0.2], "concrete"],
	["WharfSidewalkW", [26.2, -0.3, -30.0, 29.0, 0.0, 20.2], "sidewalk"],
	["WharfLane", [29.0, -0.3, -30.0, 36.0, ROAD_Y, 22.2], "asphalt"],
	["WharfSidewalkE", [36.0, -0.3, -30.0, 37.2, 0.0, 20.2], "sidewalk"],
	# Harbor St sidewalk, cut for the Wharf Lane junction (the lane runs through to the carriageway)
	["HarborSidewalkW", [-45.0, -0.3, 20.2, 29.0, 0.0, 22.2], "sidewalk"],
	["HarborSidewalkE", [36.0, -0.3, 20.2, 60.0, 0.0, 22.2], "sidewalk"],
	["HarborStreet", [-45.0, -0.3, 22.2, 60.0, ROAD_Y, 30.2], "asphalt"],
	["QuayW", [-45.0, -2.4, 30.2, 6.0, 0.0, 34.0], "quay"],
	["QuayE", [11.0, -2.4, 30.2, 60.0, 0.0, 34.0], "quay"],
	["QuayStepsHead", [6.0, -2.4, 30.2, 11.0, 0.0, 32.2], "quay"],
	["QuayLanding", [5.5, -2.4, 34.0, 11.5, -1.2, 35.4], "quay"],
	["Seabed", [-60.0, -7.0, 34.0, 80.0, -6.0, 160.0], "none"],
	# crane / container yard behind the palisade (the containers stand on it)
	["CraneYard", [37.2, -0.3, -30.0, 52.0, 0.0, 20.2], "paving"],
]

## Quay steps (dressing + walkable ramp): x 6-11, from the quay (0.0, z 32.2) down to the landing
## (-1.2, z 34.0): 7 risers x 0.171, 6 treads x 0.3. Not a building stair (no floor_heights chain).
const QUAY_STEPS: Dictionary = {"x": [6.0, 11.0], "z_top": 32.2, "z_bot": 34.0, "y_top": 0.0, "y_bot": -1.2, "risers": 7}

## Water (visual only; the OUT_OF_BOUNDS zone sits under its surface).
const WATER: Array = [-450.0, WATER_Y - 0.05, 34.0, 450.0, WATER_Y, 320.0]

## Neighbour / dressing blocks (solid massing): [name, box, material].
const BLOCKS: Array = [
	["PellChandlery", [-14.0, -0.3, -0.2, -0.2, 8.0, 20.2], "facade_a"],
	["ChandleryYardBlock", [-45.0, -0.3, -10.0, -14.0, 8.5, -0.2], "brick"],
	["HarborNorthWest", [-45.0, -0.3, -0.2, -14.0, 11.0, 20.2], "facade_b"],
	["AlleyEndBlock", [-45.0, -0.3, -15.0, -30.0, 9.0, -10.0], "brick"],
	["YardEndBlock", [-45.0, -0.3, -19.0, -30.0, 9.0, -15.0], "brick"],
	["WarehouseBacks", [-45.0, -0.3, -30.0, 26.2, 8.0, -19.0], "brick"],
	["WarehouseDock1", [-6.0, -0.3, -19.0, 2.0, 1.2, -17.6], "concrete"],
	["WarehouseDock2", [12.0, -0.3, -19.0, 20.0, 1.2, -17.6], "concrete"],
	["TJunctionFacade", [15.0, -0.3, -40.0, 60.0, 12.0, -30.0], "facade_c"],
	["BendFacade", [-52.0, -0.3, 20.2, -45.0, 12.0, 34.0], "facade_c"],
	["HarborEastFacade", [52.0, -0.3, -30.0, 60.0, 10.0, 20.2], "facade_b"],
	["DrawbridgeDeck", [60.1, ROAD_Y - 0.3, 22.2, 64.0, 9.0, 30.2], "trim"],
	["DrawbridgeTowerN", [60.0, -0.3, 20.2, 63.0, 12.0, 22.3], "concrete"],
	["DrawbridgeTowerS", [60.0, -0.3, 30.1, 63.0, 12.0, 32.2], "concrete"],
	["DrawbridgeAbutment", [60.0, -2.4, 32.2, 64.0, 3.0, 34.0], "concrete"],
	["FarShore", [-450.0, WATER_Y, 300.0, 450.0, 6.0, 310.0], "facade_c"],
	# pier sheds closing the harbour's flanks (vista: the water views end on buildings, not the void)
	["EastPierSheds", [64.0, WATER_Y, 32.2, 72.0, 8.0, 120.0], "facade_b"],
	["WestPierSheds", [-60.0, WATER_Y, 34.0, -52.0, 8.0, 120.0], "facade_a"],
	# Crane / container yard (behind the palisade, x 37.2+).
	["CraneOffice", [40.0, -0.3, 2.0, 44.0, 6.5, 6.0], "concrete"],
	# container stacks: collision; the visuals are the ISO containers (dressing SITE_DRESSING)
	["ContainerStackA", [39.0, -0.3, -12.0, 51.0, 5.2, -9.5], "container_hidden"],
	["ContainerStackB", [39.0, -0.3, -6.0, 51.0, 2.6, -3.5], "container_hidden"],
	["ContainerStackC", [39.0, -0.3, 9.0, 51.0, 5.2, 11.5], "container_hidden"],
	["ContainerStackD", [45.0, -0.3, 14.0, 51.0, 7.8, 16.5], "container_hidden"],
	["GantryCraneA", [38.5, -0.3, -20.0, 39.5, 22.0, -19.0], "crane"],
	["GantryCraneABeam", [38.5, 20.0, -20.0, 58.0, 22.0, -19.0], "crane"],
	["GantryCraneB", [38.5, -0.3, 17.0, 39.5, 22.0, 18.0], "crane"],
	["GantryCraneBBeam", [38.5, 20.0, 17.0, 58.0, 22.0, 18.0], "crane"],
	# Moored trawler west of the steps (P3 sniper perch on the wheelhouse).
	["TrawlerHull", [-9.0, -2.4, 34.6, 1.0, -0.6, 38.6], "boat_hidden"],
	["TrawlerWheelhouse", [-6.0, -0.6, 35.4, -2.0, 2.8, 37.8], "boat_hidden"],
	# Escape boat E2 (Co-op launch) moored at the landing: walkable deck at -1.0.
	["LaunchHull", [4.0, -2.4, 35.4, 13.0, -1.0, 38.4], "boat_hidden"],
	["LaunchCabin", [10.0, -1.0, 36.2, 12.6, 1.0, 38.0], "boat_hidden"],
	# Roof plant (wing roof, condensers) + hall skylight laylight (P3 rappel).
	["RoofCondenser1", [2.0, WING_ROOF, 2.0, 4.0, 4.8, 3.5], "trim"],
	["RoofCondenser2", [5.0, WING_ROOF, 2.0, 7.0, 4.8, 3.5], "trim"],
	["RoofAHU", [14.0, WING_ROOF, 1.5, 18.0, 5.2, 4.0], "trim"],
	["HallSkylight", [7.0, HALL_ROOF, 13.0, 14.0, 6.9, 17.0], "glass"],
	# Vista dressing beyond the closures.
	["UtilityVanWest", [-20.0, ROAD_Y, 23.4, -15.2, 2.3, 25.4], "van_hidden"],
	["PoliceBarrierWest", [-14.6, ROAD_Y, 22.4, -14.4, 1.1, 25.0], "barrier"],
	# PO-7: the chassis stands 5 mm off the WharfNorthGate frame (x 28.6): 28.65 left a 5 cm slit beside the
	# gate; flush (28.6) or tucked in, its end face z-fights the architrave / plinth faces.
	["ContainerTrailerChassis", [28.605, ROAD_Y, -15.2, 37.15, 1.31, -12.8], "trim"],
	["ContainerTrailer", [29.85, 1.31, -15.2, 35.95, 3.9, -12.8], "container_hidden"],
	["RoadBarrierEast", [44.0, ROAD_Y, 22.4, 44.2, 1.1, 25.0], "barrier"],
]

## Fences / closures with gates (the gates are door prefabs in DOORS):
## [name, axis, fixed, from, to, y0, y1, openings, material].
const FENCES: Array = [
	["WestClosure", "z", -14.0, -14.99, -0.21, 0.0, 2.4, [[-13.5, -11.5, 0.0, 2.2]], "fence"],
	["WarehouseFence", "x", -15.0, -13.99, 26.19, 0.0, 2.4, [], "fence"],
	["WharfFenceCorner", "z", 26.2, -14.99, -14.01, 0.0, 2.4, [], "fence"],
	["WharfNorthHoarding", "x", -14.0, 26.21, 28.59, 0.0, 2.4, [[26.6, 28.6, 0.0, 2.2]], "fence"],
	["CraneYardPalisade", "z", 37.2, -29.99, 20.19, 0.0, 2.4, [], "fence"],
	["CraneYardSouth", "x", 20.2, 37.21, 51.99, 0.0, 2.4, [], "fence"],
	["HarborWestRoadworks", "z", -14.0, 20.21, 33.99, ROAD_Y, 2.4, [[25.2, 27.2, ROAD_Y, ROAD_Y + 2.2]], "fence"],
	["HarborEastRoadworks", "z", 40.0, 20.21, 33.99, ROAD_Y, 2.4, [[25.2, 27.2, ROAD_Y, ROAD_Y + 2.2]], "fence"],
]


# --- Props ------------------------------------------------------------------------------------

## Map-built props (G2: everything else is catalog dressing, night_deposit_dressing.gd):
## [name, bottom-centre (x, y, z), size (x, y, z) before yaw, yaw_deg, kind, support, material class].
const PROPS: Array = [
	# B13 WC cubicle partition (laminate panel between the two toilets)
	["CubiclePartition", Vector3(14.75, BASE, 0.85), Vector3(0.05, 2.0, 1.3), 0.0, "partition", false, "partition"],
]

## Landmark 2: mosaic compass rose in the hall floor (inlay, nd_art.gd compass()).
const COMPASS: Dictionary = {"pos": Vector3(10.5, 0.0, 14.5), "radius": 1.8}


# --- Lighting ------------------------------------------------------------------------------

## Map-built ceiling fixtures (rooms without a dressing kit; dressed rooms get their fixtures from
## the kit): [name, (x, ceiling_y, z), colour, energy, range].
const CEILING_LIGHTS: Array = [
	["LightStair", Vector3(8.5, 3.35, 3.0), Color(0.95, 0.95, 1.0), 0.9, 8.0],
	["LightG10", Vector3(10.5, WING_CEIL, 19.0), Color(1.0, 0.82, 0.6), 0.5, 3.5],
]

## Wall-mounted lights / signs: [name, pivot on the wall face, yaw_deg (front -Z out of the wall),
## colour, energy, range, size]. The ATM vestibule's lit fascia band (no lettering) and the stair's
## half-landing bulkhead.
const WALL_LIGHTS: Array = [
	["AtmFascia", Vector3(23.5, 3.05, 20.2), 180.0, Color(0.7, 1.0, 0.85), 1.2, 6.0, Vector3(2.6, 0.4, 0.1)],
	["StairLandingLight", Vector3(8.5, -0.5, 0.2), 180.0, Color(0.95, 0.95, 1.0), 0.8, 6.0, Vector3(0.3, 0.18, 0.12)],
]


# --- Spawns, patrols, tactical -------------------------------------------------------------

## [name, pos, yaw_deg (-Z = facing), tags]. Casing spawns first (default crew spawns): on Harbor St's
## kerb lane, 4.3 m off the bank front and turned 25° east onto the facade (not the chandlery wall; P spawn probe).
const PLAYER_SPAWNS: Array = [
	["CasingSidewalk1", Vector3(-2.0, ROAD_Y, 24.5), -25.0, ["casing_sidewalk"]],
	["CasingSidewalk2", Vector3(0.0, ROAD_Y, 24.5), -25.0, ["casing_sidewalk"]],
	["CasingSidewalk3", Vector3(2.0, ROAD_Y, 24.5), -25.0, ["casing_sidewalk"]],
	["CasingSidewalk4", Vector3(4.0, ROAD_Y, 24.5), -25.0, ["casing_sidewalk"]],
	["PreplanLot1", Vector3(1.5, 0.0, -9.0), 180.0, ["preplan_spawn_lot"]],
	["PreplanLot2", Vector3(3.0, 0.0, -9.0), 180.0, ["preplan_spawn_lot"]],
	["PreplanLot3", Vector3(1.5, 0.0, -10.5), 180.0, ["preplan_spawn_lot"]],
	["PreplanLot4", Vector3(3.0, 0.0, -10.5), 180.0, ["preplan_spawn_lot"]],
	["PreplanQuay1", Vector3(24.0, 0.0, 31.4), 0.0, ["preplan_spawn_quay"]],
	["PreplanQuay2", Vector3(25.5, 0.0, 31.4), 0.0, ["preplan_spawn_quay"]],
	["PreplanQuay3", Vector3(27.0, 0.0, 31.4), 0.0, ["preplan_spawn_quay"]],
	["PreplanQuay4", Vector3(28.5, 0.0, 31.4), 0.0, ["preplan_spawn_quay"]],
	# D-040: OUT_OF_BOUNDS (harbor water) respawns at the quay steps.
	["OobQuaySteps1", Vector3(7.0, 0.0, 31.4), 180.0, ["oob_respawn"]],
	["OobQuaySteps2", Vector3(8.5, 0.0, 31.4), 180.0, ["oob_respawn"]],
	["OobQuaySteps3", Vector3(10.0, 0.0, 31.4), 180.0, ["oob_respawn"]],
]

## Fixed NPC spawns: [name, kind, pos, yaw, tags, idle_activity, patrol_graph ("" = none)].
const NPC_SPAWNS: Array = [
	["GuardHall", "GUARD", Vector3(8.0, 0.0, 13.0), -90.0, ["guard_hall"], "", "Bank"],
	["GuardBasement", "GUARD", Vector3(14.0, BASE, 6.9), 180.0, ["guard_basement"], "", "Bank"],
	# D-063: the operator sits in the station's NPC seat (prop_chair_task, 0.47 m; desk 0.74 m)
	["CameraOperatorSeat", "CAMERA_OPERATOR", Vector3(11.3, 0.0, 2.5), 90.0, ["security_operator"], "desk_work", ""],
	["PoliceHarborWest", "POLICE", Vector3(-24.0, ROAD_Y, 26.2), -90.0, ["police_harbor_west"], "", ""],
	["PoliceHarborEast", "POLICE", Vector3(48.0, ROAD_Y, 26.2), 90.0, ["police_harbor_east"], "", ""],
	["PoliceWharfNorth", "POLICE", Vector3(32.5, ROAD_Y, -22.0), 180.0, ["police_wharf_north"], "", ""],
	["PoliceAlleyWest", "POLICE", Vector3(-20.0, 0.0, -12.5), -90.0, ["police_alley_west"], "", ""],
]

## Patrol graph `Bank` (one graph across both floors, linked through the stair points, doc
## §Circulation): {point: [pos, pause Vector2, anim, tags, face_yaw or null]}.
const PATROL_POINTS_BANK: Dictionary = {
	# Ground: G7 spine + rooms.
	"G7West": [Vector3(1.2, 0.0, 6.75), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"G7Loading": [Vector3(6.0, 0.0, 6.75), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"G7Stair": [Vector3(7.7, 0.0, 6.75), Vector2.ZERO, "idle", ["guard", "staff", "staff_cleaner"], null],
	"G7Mid": [Vector3(12.5, 0.0, 6.75), Vector2(2.0, 4.0), "idle", ["guard", "staff", "staff_cleaner", "staff_manager"], null],
	"G7Break": [Vector3(16.0, 0.0, 6.75), Vector2.ZERO, "idle", ["guard", "staff", "staff_cleaner", "staff_manager"], null],
	"G7Elec": [Vector3(19.5, 0.0, 6.75), Vector2.ZERO, "idle", ["guard"], null],
	"G7East": [Vector3(24.5, 0.0, 6.75), Vector2(2.0, 4.0), "check_door", ["guard"], -90.0],
	"G1Sally": [Vector3(4.4, 0.0, 2.6), Vector2(3.0, 6.0), "check_door", ["guard"], 0.0],
	"G3Security": [Vector3(12.4, 0.0, 4.2), Vector2(4.0, 8.0), "lean", ["guard"], null],
	"G4Break": [Vector3(15.0, 0.0, 5.0), Vector2(5.0, 10.0), "idle", ["guard", "staff", "staff_cleaner", "staff_manager"], null],
	"G6Storage": [Vector3(23.6, 0.0, 4.0), Vector2(2.0, 4.0), "idle", ["guard"], null],
	"G8West": [Vector3(2.0, 0.0, 8.6), Vector2.ZERO, "idle", ["guard", "staff", "staff_manager"], null],
	"G8Mid": [Vector3(10.5, 0.0, 9.0), Vector2(3.0, 6.0), "idle", ["guard", "staff", "staff_manager"], null],
	"G8East": [Vector3(18.0, 0.0, 9.0), Vector2.ZERO, "idle", ["guard"], null],
	"G9Gate": [Vector3(1.0, 0.0, 11.0), Vector2.ZERO, "idle", ["guard", "staff", "staff_cleaner", "staff_manager"], null],
	"G9Compass": [Vector3(8.0, 0.0, 13.0), Vector2(4.0, 8.0), "idle", ["guard", "staff", "staff_cleaner"], -90.0],
	"G9Windows": [Vector3(6.0, 0.0, 18.6), Vector2(2.0, 4.0), "idle", ["guard", "staff", "staff_cleaner"], 180.0],
	"G9Vestibule": [Vector3(13.6, 0.0, 17.2), Vector2.ZERO, "idle", ["guard", "staff", "staff_cleaner"], null],
	"G9Atm": [Vector3(19.8, 0.0, 18.5), Vector2(2.0, 4.0), "check_door", ["guard"], -90.0],
	"G9Offices": [Vector3(19.8, 0.0, 14.0), Vector2.ZERO, "idle", ["guard", "staff", "staff_manager"], null],
	"G9LoanDoor": [Vector3(19.8, 0.0, 11.0), Vector2.ZERO, "idle", ["guard", "staff", "staff_manager"], null],
	"G11Loan": [Vector3(23.5, 0.0, 8.6), Vector2.ZERO, "idle", ["guard", "staff", "staff_manager"], null],
	"G12Manager": [Vector3(23.0, 0.0, 13.0), Vector2(20.0, 40.0), "idle", ["staff", "staff_manager"], null],
	# Stair (links the floors).
	"G2Top": [Vector3(7.7, 0.0, 5.0), Vector2.ZERO, "idle", ["guard", "staff", "staff_cleaner", "staff_manager"], null],
	"StairLanding": [Vector3(8.5, -2.0, 0.8), Vector2.ZERO, "idle", ["guard", "staff", "staff_cleaner", "staff_manager"], null],
	"StairFoot": [Vector3(9.3, BASE, 5.1), Vector2.ZERO, "idle", ["guard", "staff", "staff_cleaner", "staff_manager"], null],
	# Basement: B5 spine + rooms.
	"B5West": [Vector3(3.5, BASE, 6.75), Vector2.ZERO, "idle", ["guard", "staff"], null],
	"B5Stair": [Vector3(9.3, BASE, 6.75), Vector2.ZERO, "idle", ["guard", "staff", "staff_cleaner", "staff_manager"], null],
	"B5Mid": [Vector3(14.0, BASE, 6.75), Vector2(3.0, 6.0), "idle", ["guard", "staff", "staff_cleaner"], 180.0],
	"B5Plant": [Vector3(18.5, BASE, 6.75), Vector2.ZERO, "idle", ["guard", "staff", "staff_manager"], null],
	"B5East": [Vector3(23.5, BASE, 6.75), Vector2.ZERO, "idle", ["guard", "staff", "staff_manager"], null],
	"B1Xfer": [Vector3(3.5, BASE, 3.0), Vector2(2.0, 4.0), "idle", ["guard"], null],
	"B2Lockers": [Vector3(12.0, BASE, 3.6), Vector2(10.0, 20.0), "idle", ["staff", "staff_cleaner"], null],
	"B3Plant": [Vector3(17.9, BASE, 2.6), Vector2(2.0, 4.0), "check_door", ["guard"], 0.0],
	"B4Server": [Vector3(23.9, BASE, 3.6), Vector2(2.0, 4.0), "idle", ["guard"], null],
	"B6Records": [Vector3(4.6, BASE, 13.6), Vector2(2.0, 4.0), "idle", ["guard"], null],
	"B7Inspection": [Vector3(8.0, BASE, 14.0), Vector2(4.0, 8.0), "idle", ["guard"], 180.0],
	"B8Ante": [Vector3(14.0, BASE, 8.0), Vector2(4.0, 8.0), "idle", ["guard"], 180.0],
	"B10Inspection": [Vector3(20.0, BASE, 14.0), Vector2(4.0, 8.0), "idle", ["guard"], 180.0],
	"B11Count": [Vector3(22.4, BASE, 9.0), Vector2(3.0, 6.0), "idle", ["guard", "staff", "staff_manager"], null],
	"B12Depository": [Vector3(23.5, BASE, 15.6), Vector2(2.0, 4.0), "idle", ["guard"], null],
}

const PATROL_EDGES_BANK: Array = [
	# G7 spine.
	["G7West", "G7Loading"], ["G7Loading", "G7Stair"], ["G7Stair", "G7Mid"], ["G7Mid", "G7Break"],
	["G7Break", "G7Elec"], ["G7Elec", "G7East"],
	# (b) G7 -> G1 -> G7 -> G6 and the BOH rooms (each room links two spine points).
	["G1Sally", "G7Loading"], ["G1Sally", "G7West"], ["G3Security", "G7Mid"], ["G3Security", "G7Stair"],
	["G4Break", "G7Break"], ["G4Break", "G7Mid"], ["G6Storage", "G7East"], ["G6Storage", "G7Elec"],
	# (a) G7 -> G8 -> G9 hall circuit -> G8 -> G7 (and back through G11).
	["G7West", "G8West"], ["G8West", "G8Mid"], ["G8Mid", "G8East"], ["G8West", "G9Gate"],
	["G9Gate", "G9Compass"], ["G9Compass", "G9Windows"], ["G9Windows", "G9Vestibule"],
	["G9Vestibule", "G9Atm"], ["G9Atm", "G9Offices"], ["G9Offices", "G9LoanDoor"], ["G9LoanDoor", "G9Compass"],
	["G9Vestibule", "G9Compass"], ["G9LoanDoor", "G11Loan"], ["G11Loan", "G7East"], ["G12Manager", "G9Offices"],
	["G8East", "G9LoanDoor"],
	# (c) G7 -> stair -> B5 -> B6 -> B5 -> stair -> G7.
	["G7Stair", "G2Top"], ["G7Loading", "G2Top"], ["G2Top", "StairLanding"], ["StairLanding", "StairFoot"],
	["StairFoot", "B5Stair"], ["StairFoot", "B5West"],
	# Basement spine + loops through B5 mid: (a) B8 outside the lasers, (b) B7/B10, (c) B11/B12/B1.
	["B5West", "B5Stair"], ["B5Stair", "B5Mid"], ["B5Mid", "B5Plant"], ["B5Plant", "B5East"],
	["B8Ante", "B5Mid"], ["B8Ante", "B5Stair"], ["B8Ante", "B5Plant"],
	["B7Inspection", "B5Stair"], ["B7Inspection", "B5West"], ["B10Inspection", "B5Plant"], ["B10Inspection", "B5East"],
	["B11Count", "B5East"], ["B11Count", "B12Depository"], ["B12Depository", "B5East"],
	["B1Xfer", "B5West"], ["B1Xfer", "B5Stair"], ["B6Records", "B5West"], ["B6Records", "B5Stair"],
	["B3Plant", "B5Plant"], ["B3Plant", "B5Mid"], ["B4Server", "B5East"], ["B4Server", "B5Plant"],
	["B2Lockers", "B5Mid"], ["B2Lockers", "B5Stair"],
]

## Exterior lot loop (rover_exterior post, pause_anim smoke).
const PATROL_POINTS_EXTERIOR: Dictionary = {
	"LotSallyDoor": [Vector3(7.0, 0.0, -1.6), Vector2(15.0, 30.0), "smoke", ["guard"], 0.0],
	"LotCars": [Vector3(17.5, 0.0, -7.5), Vector2.ZERO, "idle", ["guard"], null],
	"LotGrate": [Vector3(15.6, 0.0, -1.6), Vector2(3.0, 6.0), "idle", ["guard"], 90.0],
	"LotAlleyMouth": [Vector3(24.0, 0.0, -12.5), Vector2(3.0, 6.0), "idle", ["guard"], -90.0],
	"LotWest": [Vector3(-6.0, 0.0, -6.0), Vector2.ZERO, "idle", ["guard"], null],
	"LotDumpster": [Vector3(11.0, 0.0, -3.0), Vector2(10.0, 20.0), "smoke", ["guard"], null],
}
const PATROL_EDGES_EXTERIOR: Array = [
	["LotSallyDoor", "LotDumpster"], ["LotDumpster", "LotGrate"], ["LotGrate", "LotCars"], ["LotCars", "LotAlleyMouth"],
	["LotAlleyMouth", "LotWest"], ["LotWest", "LotSallyDoor"], ["LotCars", "LotDumpster"],
]

## Rare `armored_car_early` (Brutal+, doc §Rare events): the armoured car parks in the lot west of the
## E1 van bay, rear doors to the building (behind the building: out of the casing sidewalk's view).
## Its 2 extra guards spawn at the rear (GUARD SpawnPoints tagged `scripted` + `guard_armored_car`,
## HeistMission.spawn_guards) and walk graph `ArmoredCar`. The rear-doors start links to the personnel
## door, the G1 sally point and (directly, the nav path runs through G1 and the stair) the B1 transfer
## room, so the start has the 3 loop options the patrols rule wants; the B1 point's weight (6, vs 0.3 for
## the personnel door) makes the usual route the cash run lot -> B1 -> B5 -> stair -> G1 -> lot.
## Optional 6th row element of a patrol point: PatrolPoint.weight.
const ARMORED_CAR: Dictionary = {
	"body": [Vector3(-1.2, 0.0, -5.0), Vector3(2.2, 2.4, 5.0)],
	"spawns": [["ArmoredCarGuardA", Vector3(-1.8, 0.0, -1.6), 180.0], ["ArmoredCarGuardB", Vector3(-0.6, 0.0, -1.6), 180.0]],
}
const PATROL_POINTS_ARMORED: Dictionary = {
	"AcRearDoors": [Vector3(-1.2, 0.0, -1.5), Vector2(4.0, 8.0), "idle", ["guard"], 0.0],
	"AcPersonnelDoor": [Vector3(6.0, 0.0, -1.0), Vector2.ZERO, "idle", ["guard"], null, 0.3],
	"AcSallyPort": [Vector3(4.6, 0.0, 3.2), Vector2(2.0, 4.0), "idle", ["guard"], null],
	"AcStairTop": [Vector3(7.7, 0.0, 5.0), Vector2.ZERO, "idle", ["guard"], null],
	"AcStairLanding": [Vector3(8.5, -2.0, 0.8), Vector2.ZERO, "idle", ["guard"], null],
	"AcStairFoot": [Vector3(9.3, BASE, 5.1), Vector2.ZERO, "idle", ["guard"], null],
	"AcB5West": [Vector3(3.5, BASE, 6.75), Vector2.ZERO, "idle", ["guard"], null],
	"AcB1Xfer": [Vector3(3.2, BASE, 2.6), Vector2(6.0, 12.0), "idle", ["guard"], null, 6.0],
}
const PATROL_EDGES_ARMORED: Array = [
	["AcRearDoors", "AcPersonnelDoor"], ["AcRearDoors", "AcSallyPort"], ["AcRearDoors", "AcB1Xfer"],
	["AcPersonnelDoor", "AcSallyPort"], ["AcSallyPort", "AcStairTop"], ["AcStairTop", "AcStairLanding"],
	["AcStairLanding", "AcStairFoot"], ["AcStairFoot", "AcB5West"], ["AcB5West", "AcB1Xfer"],
]

## Tactical points: [name, kind, pos, yaw, tags, breachable].
const TACTICAL: Array = [
	["EntryMainDoor", "ENTRY", Vector3(10.5, 0.0, 21.4), 0.0, ["main_door"], false],
	["EntryHallBay1", "ENTRY", Vector3(2.5, 0.0, 21.4), 0.0, ["hall_window"], true],
	["EntryHallBay2", "ENTRY", Vector3(6.0, 0.0, 21.4), 0.0, ["hall_window"], true],
	["EntryHallBay4", "ENTRY", Vector3(18.5, 0.0, 21.4), 0.0, ["hall_window"], true],
	["EntryAtmDoor", "ENTRY", Vector3(24.25, 0.0, 21.4), 0.0, ["atm_door"], false],
	["EntrySallyRoller", "ENTRY", Vector3(3.5, 0.0, -1.4), 180.0, ["sally_roller"], true],
	["EntrySallyDoor", "ENTRY", Vector3(6.0, 0.0, -1.4), 180.0, ["sally_door"], false],
	["EntryFireExit", "ENTRY", Vector3(27.4, 0.0, 6.75), 90.0, ["fire_exit"], false],
	["RappelSkylight", "RAPPEL", Vector3(10.5, HALL_ROOF + 0.4, 15.0), 0.0, ["skylight", "p3"], true],
	["FlankAreaway", "FLANK", Vector3(16.2, 0.0, -1.4), 90.0, ["areaway"], false],
	["CoverTellerCounter", "COVER", Vector3(8.0, 0.0, 10.75), 180.0, ["counter"], false],
	["CoverCheckTableNW", "COVER", Vector3(4.5, 0.0, 13.65), 180.0, ["table"], false],
	["CoverCheckTableSE", "COVER", Vector3(16.5, 0.0, 15.85), 0.0, ["table"], false],
	["CoverG7StairEntry", "COVER", Vector3(7.7, 0.0, 5.4), 0.0, ["stair"], false],
	["CoverG7LoadingDoor", "COVER", Vector3(5.0, 0.0, 6.6), 90.0, ["door_recess"], false],
	["CoverB5Gate", "COVER", Vector3(12.4, BASE, 7.0), 90.0, ["vault_gate"], false],
	["CoverB5Stair", "COVER", Vector3(9.3, BASE, 5.6), 0.0, ["stair"], false],
	["CoverVaultCage", "COVER", Vector3(14.0, BASE, 12.9), 0.0, ["cage"], false],
	["CoverLotCars", "COVER", Vector3(22.3, 0.0, -3.9), 0.0, ["vehicle"], false],
	["CoverLotDumpster", "COVER", Vector3(9.0, 0.0, -2.2), 180.0, ["dumpster"], false],
	["CoverQuayBench", "COVER", Vector3(20.0, 0.0, 30.6), 0.0, ["bench"], false],
	["SniperCraneOffice", "SNIPER_PERCH", Vector3(42.0, 6.5, 4.0), 90.0, ["crane_office", "p3"], false],
	["SniperTrawler", "SNIPER_PERCH", Vector3(-4.0, 2.8, 36.6), 180.0, ["trawler_wheelhouse", "p3"], false],
]

## Pre-planning points (contracts/preplanning.md, heist_map.md v1.2): [id, category, pos, floor, params].
## Labels are strings keys `ui.preplan.point.<id>`. Crew-spawn points use `spawn` (D-046 final, contract wording).
const PREPLAN_POINTS: Array = [
	["pp_drop_lot", "drop_zone", Vector3(10.6, 0.0, -2.4), 1, {}],
	["pp_drop_quay", "drop_zone", Vector3(14.0, 0.0, 32.0), 1, {}],
	["pp_spawn_lot", "spawn", Vector3(2.25, 0.0, -9.75), 1, {"spawn_tag": &"preplan_spawn_lot"}],
	["pp_spawn_quay", "spawn", Vector3(26.25, 0.0, 31.4), 1, {"spawn_tag": &"preplan_spawn_quay"}],
	["pp_escape_van", "escape", Vector3(2.5, 0.0, -5.4), 1, {"variant_group": &"escape", "variant_slot": &"esc_van_lot"}],
	["pp_escape_boat", "escape", Vector3(7.5, -1.0, 36.9), 1, {"variant_group": &"escape", "variant_slot": &"esc_boat_quay"}],
	["pp_insider_code", "insider", Vector3(23.0, 0.0, 13.0), 1, {"variant_group": &"code_note"}],
	["pp_insider_keycard", "insider", Vector3(2.0, 0.0, 8.6), 1, {"variant_group": &"keycard"}],
	["pp_vent", "insider", Vector3(16.2, 0.0, -1.4), 1, {"variant_group": &"vent_open", "variant_slot": &"vent_open"}],
	["pp_blueprint_cams", "insider", Vector3(12.4, 0.0, 4.2), 1, {"variant_group": &"camera"}],
]


# --- PO6-17 RNG assault events (D-114 §5 / D-115 #5) -------------------------------------------

## Marker nodes only, under `AssaultEvents` (group `assault_events`; world/heists/shared/assault_markers.gd); ENV A's
## event code consumes them. Contract: docs/levels/_art/po6_17/README.md. Turret vans: [name, pos (road,
## bottom-centre), yaw_deg (+Z = the van's forward)]: Harbor Street opposite the hall bays and the entrance, and Wharf
## Lane opposite the G11 / G12 windows; clear of the parked cars, the escapes (lot van, quay boat) and the police gates.
const ASSAULT_TURRET_VANS: Array = [
	["TurretVan_1", Vector3(4.0, ROAD_Y, 26.0), 90.0],     # Harbor St eastbound lane: x 1-7, z 24.8-27.2
	["TurretVan_2", Vector3(32.6, ROAD_Y, 10.0), 180.0],   # Wharf Lane, nose north: x 31.4-33.8, z 7.1-13.1
]
## Helicopter orbit: [name, centre (y = flight height of the heli pivot), radius]: over the bank and Harbor Street,
## clear of the crane-yard gantries (x 38.5+, 22 m) and the 11-12 m neighbour blocks.
const ASSAULT_HELI_ORBITS: Array = [["HeliOrbit_1", Vector3(12.0, 30.0, 8.0), 22.0]]
## Rappel landing points: [name, pos]. The hall roof east of the skylight beside the Breach_1 hatch (off the
## navmesh: ENV A pairs it with that ceiling breach) and Harbor Street in front of the bank.
const ASSAULT_HELI_DROPS: Array = [
	["HeliDrop_1", Vector3(16.6, HALL_ROOF, 15.75)],
	["HeliDrop_2", Vector3(12.0, ROAD_Y, 28.5)],
]
## Breach points: [name, kind, breach scene (world/props/assault_event/<id>.tscn), pos on the room-side face
## (wall: bottom-centre of the opening; ceiling: centre of the ceiling underside), yaw_deg (-Z into the room;
## ceilings: the turn of +Y = the side of the roof EntryPoint about the vertical, 0 = north), size (w, h) m, room,
## ceiling depth (ceiling underside to roof top; 0 for walls)]. The wall opening is in EXT_WALLS; the ceiling holes
## are cut from the slabs / ceilings (and the art ceilings) by the generator. Sizes match the breach scenes.
const ASSAULT_BREACHES: Array = [
	# G9 banking hall: a sealed roof hatch east of the skylight laylight (RappelSkylight), between the coffer beams.
	["Breach_1", "ceiling", "prop_breach_ceiling_p100_d550", Vector3(14.9, HALL_CEIL, 15.75), 0.0, Vector2(1.2, 1.2), "G9",
		HALL_ROOF - HALL_CEIL],
	# G8 teller workroom: a wing-roof hatch over the staff walkway behind the counter (between the stools and the
	# teller stations 2 / 3; the room's fixtures stay at its ends), the roof EntryPoint north of it.
	["Breach_2", "ceiling", "prop_breach_ceiling", Vector3(7.75, WING_CEIL, 8.6), 0.0, Vector2(1.2, 1.2), "G8",
		WING_ROOF - WING_CEIL],
	# G6 storage (the srv_ground rack room): a blocked-up doorway from the staff lot, west of the rack.
	["Breach_3", "wall", "prop_breach_wall_t40", Vector3(22.1, 0.0, 0.2), 180.0, Vector2(1.0, 2.2), "G6", 0.0],
]


# --- Rooms and zones ------------------------------------------------------------------------

## [id, purpose, dressing_kit, floor_index, boxes, ceiling_range override or null].
const ROOMS: Array = [
	["G1", "storage", "sally_port", 1, [[0.0, 0.0, 0.0, 7.0, WING_CEIL, 6.0]], null],
	["G2", "stair", "", 1, [[7.0, BASE, 0.0, 10.0, 3.35, 6.0]], null],
	["G3", "security_room", "security_office_bank", 1, [[10.0, 0.0, 0.0, 14.0, WING_CEIL, 6.0]], null],
	["G4", "break_room", "break_room", 1, [[14.0, 0.0, 0.0, 18.0, WING_CEIL, 6.0]], null],
	["G5", "electrical", "electrical_closet", 1, [[18.0, 0.0, 0.0, 21.0, WING_CEIL, 6.0]], null],
	["G6", "storage", "storage_supplies", 1, [[21.0, 0.0, 0.0, 26.0, WING_CEIL, 6.0]], null],
	["G7", "corridor", "corridor_service", 1, [[0.0, 0.0, 6.0, 26.0, WING_CEIL, 7.5]], null],
	["G8", "office", "teller_line", 1, [[0.0, 0.0, 7.5, 21.0, WING_CEIL, 10.0]], null],
	["G9", "banking_hall", "banking_hall", 1, [[0.0, 0.0, 10.0, 21.0, HALL_CEIL, 18.0],
		[0.0, 0.0, 18.0, 8.5, HALL_CEIL, 20.0], [12.5, 0.0, 18.0, 21.0, HALL_CEIL, 20.0]], null],
	["G10", "corridor", "", 1, [[8.5, 0.0, 18.0, 12.5, WING_CEIL, 20.0]], null],
	["G11", "office", "office_loan", 1, [[21.0, 0.0, 7.5, 26.0, WING_CEIL, 12.0]], null],
	["G12", "office", "office_manager_bank", 1, [[21.0, 0.0, 12.0, 26.0, WING_CEIL, 16.0]], null],
	["G13", "lobby", "atm_vestibule", 1, [[21.0, 0.0, 16.0, 26.0, WING_CEIL, 20.0]], null],
	["B1", "storage", "cash_transfer", 0, [[0.0, BASE, 0.0, 7.0, BASE_CEIL, 6.0]], BASEMENT_CEIL_RANGE],
	["B2", "locker_room", "locker_room", 0, [[10.0, BASE, 2.5, 16.0, BASE_CEIL, 6.0],
		[10.0, BASE, 0.0, 13.5, BASE_CEIL, 2.5]], BASEMENT_CEIL_RANGE],
	["B13", "restroom", "restroom_wc", 0, [[13.5, BASE, 0.0, 16.0, BASE_CEIL, 2.5]], BASEMENT_CEIL_RANGE],
	["B3", "plant", "plant_room", 0, [[16.0, BASE, 0.0, 21.0, BASE_CEIL, 6.0]], BASEMENT_CEIL_RANGE],
	["B4", "server_room", "server_room", 0, [[21.0, BASE, 0.0, 26.0, BASE_CEIL, 6.0]], BASEMENT_CEIL_RANGE],
	["B5", "corridor", "corridor_service", 0, [[0.0, BASE, 6.0, 26.0, BASE_CEIL, 7.5]], BASEMENT_CEIL_RANGE],
	["B6", "storage", "storage_archive", 0, [[0.0, BASE, 7.5, 7.0, BASE_CEIL, 20.0]], BASEMENT_CEIL_RANGE],
	["B7", "corridor", "corridor_inspection", 0, [[7.0, BASE, 7.5, 9.0, BASE_CEIL, 20.0]], BASEMENT_CEIL_RANGE],
	["B8", "vault", "vault_antechamber", 0, [[9.0, BASE, 7.5, 19.0, BASE_CEIL, 10.0]], null],
	["B9", "vault", "vault_main", 0, [[9.0, BASE, 10.0, 19.0, VAULT_CEIL, 20.0]], null],
	["B10", "corridor", "corridor_inspection", 0, [[19.0, BASE, 7.5, 21.0, BASE_CEIL, 20.0]], BASEMENT_CEIL_RANGE],
	["B11", "office", "count_room", 0, [[21.0, BASE, 7.5, 26.0, BASE_CEIL, 14.0]], BASEMENT_CEIL_RANGE],
	["B12", "vault", "depository", 0, [[21.0, BASE, 14.0, 26.0, BASE_CEIL, 20.0]], null],
	["B14", "storage", "janitor_closet", 0, [[7.0, BASE, 3.5, 8.5, BASE_CEIL, 6.0]], BASEMENT_CEIL_RANGE],
	["X1", "exterior", "exterior_lot", 1, [[-14.0, 0.0, -15.0, 26.2, 4.0, -0.2]], null],
	["X2", "exterior", "exterior_harbor", 1, [[-14.0, ROAD_Y, 20.2, 40.0, 4.0, 34.0],
		[26.2, ROAD_Y, -14.0, 37.2, 4.0, 20.2]], null],
]

## Fixed MapZones: [name, kind, zone_id, boxes]. SECURE_LOOT/ESCAPE live in the `escape` slots;
## the dumpster BODY_HIDE comes with its body_container prefab.
const ZONES: Array = [
	["PublicStreetQuay", "PUBLIC", "street", [[-14.0, -0.5, 20.2, 40.0, 4.0, 34.0], [26.2, -0.5, -14.0, 37.2, 4.0, 20.2]]],
	["PublicLot", "PUBLIC", "lot", [[-14.0, -0.5, -15.0, 26.2, 4.0, -0.2]]],
	["PublicAtmVestibule", "PUBLIC", "atm_vestibule", [[21.1, -0.2, 16.1, 25.9, WING_CEIL, 19.9]]],
	["RestrictedWing", "RESTRICTED", "back_of_house", [[0.2, -0.2, 0.2, 25.8, 3.4, 10.0], [21.1, -0.2, 10.0, 25.8, 3.4, 15.9]]],
	["RestrictedHall", "RESTRICTED", "banking_hall", [[0.2, -0.2, 10.0, 20.9, 6.2, 19.8]]],
	["RestrictedBasement", "RESTRICTED", "basement", [[0.2, -4.2, 0.2, 25.8, -0.8, 19.8]]],
	["RestrictedAreaway", "RESTRICTED", "areaway", [[17.6, -4.2, -2.4, 18.8, -0.5, -0.2]]],
	["BodyHideJanitor", "BODY_HIDE", "janitor_closet", [[7.15, -4.2, 3.65, 8.35, -1.0, 5.85]]],
	# D-040: the harbor water is a hard boundary (respawn at `oob_respawn`, never an alarm).
	["OutOfBoundsWater", "OUT_OF_BOUNDS", "harbor_water", [[-60.0, -12.0, 34.05, 80.0, -1.3, 160.0]]],
]


# --- Review cameras ---------------------------------------------------------------------------

## [name, position, look-at target, fov (TopDown*: ortho size), caption].
## Interior cameras sit >= 0.5 m inside their room (levelcheck `cameras`: >= 0.3 m from any collision).
const REVIEW_CAMERAS: Array = [
	["TopDownSite", Vector3(13.0, 80.0, 10.0), Vector3(13.0, 0.0, 10.0), 70.0,
		"Top-down site: bank, lot + alley, Wharf Lane, Harbor St, quay, closures"],
	["TopDownBuilding", Vector3(13.0, 40.0, 10.0), Vector3(13.0, 0.0, 10.0), 30.0,
		"Top-down building: stepped massing (hall +6.5, wing +3.6), roof plant, skylight"],
	["ExtHarborFacade", Vector3(10.5, 1.7, 33.0), Vector3(10.5, 3.5, 19.0), 70.0,
		"Exterior: Harbor St facade from the quay: harbor clock, bronze doors, tall hall windows (landmark)"],
	["ExtAtmCorner", Vector3(33.0, 1.7, 29.0), Vector3(23.0, 2.0, 18.0), 70.0,
		"Exterior: Harbor St / Wharf Ln corner: green-glass ATM vestibule (landmark), fire exit side"],
	["ExtLotSallyPort", Vector3(14.0, 3.0, -13.0), Vector3(4.0, 1.0, -1.5), 70.0,
		"Exterior: staff lot from the alley mouth: sally roller + personnel door, van E1 slot, dumpster, areaway cage"],
	["ExtQuaySteps", Vector3(13.6, 2.0, 30.7), Vector3(7.5, -1.0, 36.5), 70.0,
		"Exterior: quay steps, landing and the moored launch (E2), chain railing"],
	["ExtWharfLane", Vector3(32.5, 1.7, -12.0), Vector3(30.0, 1.5, 15.0), 70.0,
		"Exterior: Wharf Lane from the trailer closure: crane yard palisade, bank east side"],
	["HallFromVestibule", Vector3(10.5, 1.65, 17.4), Vector3(10.5, 1.4, 10.5), 80.0,
		"G9 banking hall from the vestibule: teller counter + bandit glass, compass rose"],
	["CompassLandmark", Vector3(2.0, 2.4, 18.6), Vector3(10.5, 0.0, 14.5), 70.0,
		"G9 mosaic compass rose (landmark), check tables, the hall guard post"],
	["HallGuardPost", Vector3(8.0, 1.65, 13.0), Vector3(21.0, 1.4, 15.0), 80.0,
		"G9 hall guard post view east: ATM glass door, G11/G12 glass fronts"],
	["TellerWorkroom", Vector3(0.8, 1.65, 9.3), Vector3(19.0, 1.0, 8.4), 70.0,
		"G8 teller workroom behind the counter (hidden from the seated hall guard)"],
	["StaffCorridor", Vector3(25.4, 1.65, 6.75), Vector3(0.0, 1.4, 6.75), 60.0, "G7 staff corridor: the 26 m sightline"],
	["SecurityRoom", Vector3(13.5, 1.8, 5.5), Vector3(10.2, 1.0, 2.0), 75.0, "G3 security room: camera station against the west wall"],
	["SallyPort", Vector3(0.9, 2.0, 5.25), Vector3(5.0, 0.9, 0.6), 75.0, "G1 sally port: roller + personnel door, cash lift"],
	["StairCore", Vector3(7.7, 1.65, 6.9), Vector3(8.6, -2.0, 1.0), 75.0, "G2 U-stair from the corridor (railing over flight 2)"],
	["BasementCorridor", Vector3(0.6, -2.35, 6.75), Vector3(26.0, -2.6, 6.75), 60.0, "B5 basement spine and the vault gate"],
	["Antechamber", Vector3(9.75, -2.35, 8.1), Vector3(18.5, -3.2, 9.6), 75.0, "B8 antechamber: laser plane, time-lock panel, vault door"],
	["VaultInterior", Vector3(14.0, -2.2, 10.6), Vector3(14.0, -3.4, 18.0), 80.0, "B9 vault: cash cage, Co-op pallet, deposit box walls"],
	["CountDepository", Vector3(25.2, -2.35, 8.2), Vector3(22.5, -3.4, 18.0), 75.0, "B11 count room and B12 depository safe"],
	["RecordsRoom", Vector3(6.5, -2.35, 8.0), Vector3(1.0, -3.4, 18.0), 75.0, "B6 records: compact shelving, microfiche desk"],
	["PlantAreaway", Vector3(17.9, -2.2, 5.35), Vector3(18.2, -3.0, 0.2), 80.0, "B3 plant room and the areaway door"],
	["ManagerOffice", Vector3(21.7, 1.8, 15.3), Vector3(25.5, 0.6, 12.5), 75.0, "G12 manager office: desk, manager safe slot"],
	["AtmVestibule", Vector3(25.2, 1.8, 19.2), Vector3(21.0, 1.0, 16.5), 75.0,
		"G13 ATM vestibule (24 h, PUBLIC): ATMs, night drop, hall door"],
	["CranePerch", Vector3(42.0, 8.2, 4.0), Vector3(10.0, 0.0, -3.0), 70.0, "Crane office roof (P3 sniper perch) over the lot and sally door"],
	# G2 additions: one shot per remaining major room (level_standards §8)
	["BreakRoom", Vector3(17.35, 1.7, 5.35), Vector3(14.6, 0.9, 1.0), 75.0, "G4 break room: kitchen run, lockers (kc_break_locker), table"],
	["SuppliesStore", Vector3(21.65, 1.7, 5.35), Vector3(25.0, 0.8, 1.2), 75.0, "G6 supplies storage (srv_ground rack slot)"],
	["LoanOffice", Vector3(21.65, 1.7, 8.15), Vector3(25.5, 0.6, 11.0), 75.0,
		"G11 loan office: desk, officer seat, visitors, Wharf Lane window"],
	["CashTransfer", Vector3(6.35, -2.35, 5.35), Vector3(1.0, -3.4, 1.5), 75.0, "B1 cash transfer: lift landing, cash cages, sorting bench"],
	["LockerRoom", Vector3(14.9, -2.35, 5.4), Vector3(10.6, -3.4, 0.8), 75.0, "B2 locker room: lockers, bench, sink row (WC door)"],
	["ServerRoom", Vector3(24.3, -2.35, 4.8), Vector3(21.5, -3.2, 0.8), 75.0, "B4 server room: rack rows, UPS, console (srv_basement slot)"],
	["InspectionPassage", Vector3(7.9, -2.35, 8.35), Vector3(7.9, -3.0, 19.5), 70.0, "B7 vault inspection passage (dead end with a reason)"],
]
