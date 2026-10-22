## Safehouse ("The Press") G1 greybox data (C4-02). Owner: ENV C. Read by build_safehouse.gd.
## Source: docs/design/heists/safehouse.md (G0 approved, D-070): the floor plan (wall centre lines x 0 / 8 / 22 /
## 22.5 / 28, z 0 / 7 / 8 / 12 / 13.5 / 18; the south strip divided at x 10.5 / 14 / 19), the vertical table, the room
## list, the stations table and the review shots. Origin: the outer NW corner; +x east, +z south (Tanner Row north).
## One floor at 0.0. Exterior walls 0.4 m, interior 0.2 m. Hand-authored from the G0 tables (C4-02 plan): the
## generator's own checks and test_safehouse_contract hold it to them.
extends RefCounted

const FLOOR_HEIGHTS: Array[float] = [0.0]
const FLOOR_NAMES: Array[String] = ["Ground"]
const EXT_T: float = 0.4
const INT_T: float = 0.2
## The building's outer footprint (centre lines) and the exterior walls' top (the hall roof, +5.8).
const LOT: Rect2 = Rect2(0.0, 0.0, 28.0, 18.0)
const PARAPET_Y: float = 5.8
const DOOR_H: float = 2.1

## Wall runs: [name, axis (x: along x at z = fixed; z: along z at x = fixed), fixed, a0, a1, thickness, y0, y1,
## class, holes [[a0, a1, y0, y1]]]. Interior walls rise to the higher roof of their two sides.
const WALLS: Array = [
	# Tanner Row: the roller door (3.5 x 3.6), the front door, the hall's clerestory windows either side of the
	# Board (sill 3.2) and the workshop window between the gun cabinets.
	["ExtN", "x", 0.0, -0.2, 28.2, EXT_T, 0.0, PARAPET_Y, "wall_ext",
		[[2.0, 5.5, 0.0, 3.6], [6.25, 7.25, 0.0, DOOR_H], [9.0, 11.0, 3.2, 4.4], [19.0, 21.0, 3.2, 4.4],
		[24.0, 26.0, 1.1, 2.2]]],
	# The yard: the range door (station 7) and the kit store's fire exit.
	["ExtS", "x", 18.0, -0.2, 28.2, EXT_T, 0.0, PARAPET_Y, "wall_ext",
		[[20.25, 21.25, 0.0, DOOR_H], [25.5, 26.5, 0.0, DOOR_H]]],
	# Party wall west: the lounge kitchen's windows.
	["ExtW", "z", 0.0, 0.2, 17.8, EXT_T, 0.0, PARAPET_Y, "wall_ext", [[13.0, 14.5, 1.1, 2.2], [15.5, 17.0, 1.1, 2.2]]],
	["ExtE", "z", 28.0, 0.2, 17.8, EXT_T, 0.0, PARAPET_Y, "wall_ext", []],
	# O1 (3.0 m cased opening LB -> hall), O2 (2.5 m hall -> lounge), D6 (lounge -> corridor).
	# (split at z 8.1, off the crew phone's z 8.0, so the phone hangs on one face)
	["LbHall", "z", 8.0, 0.2, 8.1, INT_T, 0.0, 5.8, "wall", [[4.0, 7.0, 0.0, 3.0]]],
	["HallLounge", "z", 8.0, 8.1, 12.0, INT_T, 0.0, 5.8, "wall", [[9.0, 11.5, 0.0, 2.4]]],
	["LoungeCo", "z", 8.0, 12.0, 17.8, INT_T, 0.0, 3.6, "wall", [[12.3, 13.2, 0.0, DOOR_H]]],
	["LbLounge", "x", 8.0, 0.2, 7.9, INT_T, 0.0, 5.3, "wall", []],
	# D3 (double, armory axis z 3.5), D4 (mask room axis z 9.5).
	["HallEast", "z", 22.0, 0.2, 11.9, INT_T, 0.0, 5.8, "wall", [[2.6, 4.4, 0.0, DOOR_H], [9.05, 9.95, 0.0, DOOR_H]]],
	["WsMk", "x", 7.0, 22.1, 27.8, INT_T, 0.0, 4.2, "wall", []],
	# D5 (double, the range axis x 20.75).
	["HallCo", "x", 12.0, 8.1, 22.1, INT_T, 0.0, 5.8, "wall", [[19.85, 21.65, 0.0, DOOR_H]]],
	["MkKs", "x", 12.0, 22.1, 27.8, INT_T, 0.0, 4.2, "wall", []],
	# D11 (corridor -> kit store, the corridor's end).
	["CoKs", "z", 22.5, 12.1, 17.8, INT_T, 0.0, 3.6, "wall", [[12.3, 13.2, 0.0, DOOR_H]]],
	# D7 WC, D8 store, D9 bunks, D10 range vestibule (on x 20.75).
	["CoStrip", "x", 13.5, 8.1, 22.4, INT_T, 0.0, 3.4, "wall",
		[[8.8, 9.7, 0.0, DOOR_H], [11.8, 12.7, 0.0, DOOR_H], [16.05, 16.95, 0.0, DOOR_H], [20.3, 21.2, 0.0, DOOR_H]]],
	["StripWcSt", "z", 10.5, 13.6, 17.8, INT_T, 0.0, 3.4, "wall", []],
	["StripStBk", "z", 14.0, 13.6, 17.8, INT_T, 0.0, 3.4, "wall", []],
	["StripBkRv", "z", 19.0, 13.6, 17.8, INT_T, 0.0, 3.4, "wall", []],
]

## Closed exterior leaves and frosted panes in the holes above: [name, min, max, class]. The exterior doors are
## closed, non-interactive and locked (G0 Circulation); every vertical window is frosted wired glass (not clear:
## nothing outside is modelled).
const FILLS: Array = [
	["RollerDoor", [2.0, 0.0, -0.05], [5.5, 3.6, 0.05], "door"],
	["FrontDoor", [6.25, 0.0, -0.03], [7.25, DOOR_H, 0.03], "door"],
	["FireExit", [25.5, 0.0, 17.97], [26.5, DOOR_H, 18.03], "door"],
	# The range door's red LIVE FIRE lamp over station 7 (2.3 m; on the wall face, so part of the shell).
	["LiveFireLamp", [20.6, 2.25, 17.72], [20.9, 2.4, 17.8], "prop"],
	["ClerestoryW", [9.0, 3.2, -0.01], [11.0, 4.4, 0.01], "glass_frosted"],
	["ClerestoryE", [19.0, 3.2, -0.01], [21.0, 4.4, 0.01], "glass_frosted"],
	["WorkshopWindow", [24.0, 1.1, -0.01], [26.0, 2.2, 0.01], "glass_frosted"],
	["KitchenWindowN", [-0.01, 1.1, 13.0], [0.01, 2.2, 14.5], "glass_frosted"],
	["KitchenWindowS", [-0.01, 1.1, 15.5], [0.01, 2.2, 17.0], "glass_frosted"],
]

## The ground slab under the whole lot.
const GROUND: Array = [[-0.2, -0.3, -0.2], [28.2, 0.0, 18.2]]
## The hall's three 2 x 2 m rooflights (x 12 / 15 / 18, z 6): wells from the ceiling to the roof, glass at the top.
const ROOFLIGHTS: Array = [[11.0, 5.0, 13.0, 7.0], [14.0, 5.0, 16.0, 7.0], [17.0, 5.0, 19.0, 7.0]]
const ROOFLIGHT_GLASS_Y: Vector2 = Vector2(5.68, 5.7)
const WELL_T: float = 0.05

## Roofs between the walls' inner faces: [name, [x0, z0, x1, z1], holes, y0, y1, class].
const ROOFS: Array = [
	["RoofH1", [8.1, 0.2, 21.9, 11.9], ROOFLIGHTS, 5.6, 5.8, "roof"],
	["RoofLB", [0.2, 0.2, 7.9, 7.9], [], 5.0, 5.3, "roof"],
	["RoofWS", [22.1, 0.2, 27.8, 6.9], [], 3.9, 4.2, "roof"],
	["RoofMK", [22.1, 7.1, 27.8, 11.9], [], 3.9, 4.2, "roof"],
	["RoofLG", [0.2, 8.1, 7.9, 17.8], [], 3.3, 3.6, "roof"],
	["RoofCO", [8.1, 12.1, 22.4, 13.4], [], 3.1, 3.4, "roof"],
	["RoofWC", [8.1, 13.6, 10.4, 17.8], [], 3.1, 3.4, "roof"],
	["RoofST", [10.6, 13.6, 13.9, 17.8], [], 3.1, 3.4, "roof"],
	["RoofBK", [14.1, 13.6, 18.9, 17.8], [], 3.1, 3.4, "roof"],
	["RoofRV", [19.1, 13.6, 22.4, 17.8], [], 3.1, 3.4, "roof"],
	["RoofKS", [22.6, 12.1, 27.8, 17.8], [], 3.3, 3.6, "roof"],
]
## Ceiling planes (CEIL_T) at each room's clear height (the vertical table), same rects: [name, rect, holes, y].
const CEILINGS: Array = [
	["CeilLB", [0.2, 0.2, 7.9, 7.9], [], 4.5],
	["CeilH1", [8.1, 0.2, 21.9, 11.9], ROOFLIGHTS, 5.0],
	["CeilLG", [0.2, 8.1, 7.9, 17.8], [], 3.0],
	["CeilWS", [22.1, 0.2, 27.8, 6.9], [], 3.5],
	["CeilMK", [22.1, 7.1, 27.8, 11.9], [], 3.0],
	["CeilCO", [8.1, 12.1, 22.4, 13.4], [], 2.8],
	["CeilWC", [8.1, 13.6, 10.4, 17.8], [], 2.7],
	["CeilST", [10.6, 13.6, 13.9, 17.8], [], 2.8],
	["CeilBK", [14.1, 13.6, 18.9, 17.8], [], 2.8],
	["CeilRV", [19.1, 13.6, 22.4, 17.8], [], 2.8],
	["CeilKS", [22.6, 12.1, 27.8, 17.8], [], 3.0],
]
const CEIL_T: float = 0.05

## RoomVolumes: [id, purpose, dressing kit ("" until the G2 kits exist), [x0, y0, z0, x1, y1, z1]] (centre lines,
## floor to clear ceiling). Purposes are the levelcheck table's: G0 `loading_bay` -> loading, `workshop_hall` ->
## workshop, MK `workshop` at 3.0 m -> office (the workshop band starts at 3.5), `bunk_room` -> bedroom,
## `range_vestibule` -> corridor.
const ROOMS: Array = [
	["LB", "loading", "", [0.0, 0.0, 0.0, 8.0, 4.5, 8.0]],
	["H1", "workshop", "", [8.0, 0.0, 0.0, 22.0, 5.0, 12.0]],
	["LG", "break_room", "break_room", [0.0, 0.0, 8.0, 8.0, 3.0, 18.0]],
	["WS", "workshop", "", [22.0, 0.0, 0.0, 28.0, 3.5, 7.0]],
	["MK", "office", "", [22.0, 0.0, 7.0, 28.0, 3.0, 12.0]],
	["CO", "corridor", "corridor_service", [8.0, 0.0, 12.0, 22.5, 2.8, 13.5]],
	["WC", "restroom", "restroom_single", [8.0, 0.0, 13.5, 10.5, 2.7, 18.0]],
	["ST", "electrical", "electrical_closet", [10.5, 0.0, 13.5, 14.0, 2.8, 18.0]],
	["BK", "bedroom", "", [14.0, 0.0, 13.5, 19.0, 2.8, 18.0]],
	["RV", "corridor", "", [19.0, 0.0, 13.5, 22.5, 2.8, 18.0]],
	["KS", "storage", "", [22.5, 0.0, 12.0, 28.0, 3.0, 18.0]],
]

## Stations (hub_map.md: the 9 ids; A's hub_station prefab, named by id): [id, root (floor, under the station's
## centre; wall-hung ones on the wall face at the mounting height, the visual_slots wall pivot), yaw (deg; the
## station's -Z faces the user), UsePoint distance along -Z (on the floor), Interactable (local), greybox body boxes
## [[name, local min, local max, class]]]. Positions and UsePoints are the G0 stations table's; `profile` (hub_map
## v1.1, the career screen) is the lounge bulletin board on wall x 8 (the LEAD's C4-02 ruling).
const STATIONS: Array = [
	["board", [15.0, 1.6, 0.2], 180.0, 1.2, [0.0, 0.0, -0.13],
		[["Panel", [-2.0, -1.1, -0.06], [2.0, 1.1, 0.0], "prop"]]],
	["planning", [15.0, 0.0, 6.5], 180.0, 1.25, [0.0, 0.95, 0.0],
		[["Table", [-1.5, 0.0, -0.75], [1.5, 0.9, 0.75], "counter"]]],
	["armory", [27.4, 0.0, 3.5], 90.0, 1.0, [0.0, 1.0, -0.2],
		[["Bench", [-1.2, 0.0, -0.4], [1.2, 0.9, 0.4], "counter"],
		["Pegboard", [-1.2, 1.2, 0.36], [1.2, 2.6, 0.4], "prop"]]],
	["masks", [27.4, 0.0, 9.5], 90.0, 0.8, [0.0, 0.85, -0.1],
		[["Bench", [-0.9, 0.0, -0.35], [0.9, 0.76, 0.35], "counter"],
		["MaskWall", [-0.9, 1.1, 0.36], [0.9, 2.4, 0.4], "prop"]]],
	["jukebox", [0.6, 0.0, 10.25], -90.0, 0.9, [0.0, 1.1, -0.35],
		[["Cabinet", [-0.45, 0.0, -0.325], [0.45, 1.6, 0.325], "prop"]]],
	["notoriety", [11.0, 0.0, 10.4], 0.0, 1.3, [0.0, 1.2, -0.55],
		[["Press", [-0.7, 0.0, -0.5], [0.7, 1.9, 0.5], "prop"],
		["Flywheel", [-0.85, 0.1, -0.55], [-0.7, 1.2, 0.55], "prop"],
		["Clippings", [-1.5, 0.9, 1.47], [1.5, 2.4, 1.5], "prop"]]],
	["range", [20.75, 0.0, 17.8], 0.0, 0.9, [0.0, 1.1, 0.0],
		[["Door", [-0.5, 0.0, 0.17], [0.5, DOOR_H, 0.23], "door"]]],
	["crew", [8.1, 1.4, 8.0], -90.0, 0.9, [0.0, 0.0, -0.2],
		[["Phone", [-0.15, -0.2, -0.1], [0.15, 0.15, 0.0], "prop"],
		["Polaroids", [-0.9, -0.2, -0.03], [-0.2, 0.4, 0.0], "prop"]]],
	["profile", [7.9, 1.4, 15.0], 90.0, 1.1, [0.0, 0.0, -0.1],
		[["BulletinBoard", [-0.6, -0.4, -0.03], [0.6, 0.5, 0.0], "prop"]]],
]
## The jukebox's speaker (station-local: in the cabinet's top front); MusicDirector.positional_parent plays the stems
## there (unit size 4 m, max distance 30 m: full in the lounge, present in the hall, faint in the workshop).
const JUKEBOX_SPEAKER: Vector3 = Vector3(0.0, 1.25, -0.2)
const JUKEBOX_UNIT_SIZE: float = 4.0
const JUKEBOX_MAX_DISTANCE: float = 30.0
## Wall-hung stations (levelcheck meta mount = wall: the wall carries them, not the floor).
const WALL_MOUNTED: Array[String] = ["board", "crew", "profile"]
## StationCam (hub_map: a Marker3D, -Z the view, `fov` meta): this far behind and above the UsePoint, looking at the
## Interactable.
const STATION_CAM_BACK: float = 0.5
const STATION_CAM_H: float = 1.7
const STATION_CAM_FOV: float = 55.0

## Spawns/: [name, position, yaw (-Z faces), tags]. 4 PLAYER spawns in LB facing the hall (v1 uses the first);
## `Spawn` (the loading bay fallback) and `ReturnHeist` (back in the van) on P1; `ReturnRange` in the vestibule
## facing N. All are PLAYER SpawnPoints (Marker3Ds), so the walkthrough walks from the return points too.
const SPAWNS: Array = [
	["P1", [6.0, 0.0, 4.0], -90.0, ["hub"]],
	["P2", [6.5, 0.0, 5.0], -90.0, ["hub"]],
	["P3", [6.0, 0.0, 6.0], -90.0, ["hub"]],
	["P4", [6.5, 0.0, 7.0], -90.0, ["hub"]],
	["Spawn", [6.0, 0.0, 4.0], -90.0, ["hub_entry"]],
	["ReturnHeist", [6.0, 0.0, 4.0], -90.0, ["hub_return_heist"]],
	["ReturnRange", [20.75, 0.0, 16.4], 0.0, ["hub_return_range"]],
]

## Props/ (greybox stand-ins; G2 dresses the rooms): [name, min, max, class]. The crew van backed in under the
## roller door, rear doors (north) open.
const PROPS: Array = [
	["CrewVan", [2.9, 0.0, 0.6], [4.7, 2.3, 6.2], "prop"],
]

## ReviewCameras (G0 Review shots, 16): [name, caption, position, look-at]. TopDownPlan is the plan render.
const REVIEW_CAMERAS: Array = [
	["TopDownPlan", "plan_top", [14.0, 30.0, 9.0], [14.0, 0.0, 9.0]],
	["SpawnView", "spawn_view", [6.0, 1.6, 4.0], [15.0, 1.2, 4.0]],
	["HallWideSW", "hall_wide_sw", [8.6, 2.4, 11.4], [20.0, 1.5, 2.0]],
	["BoardClose", "board_close", [15.0, 1.6, 2.7], [15.0, 1.6, 0.2]],
	["PlanningTable", "planning_table", [17.5, 2.4, 8.8], [15.0, 0.9, 6.5]],
	["OldPress", "old_press", [12.5, 1.8, 8.0], [11.0, 1.0, 10.6]],
	["LoungeFromHall", "lounge_from_hall", [9.4, 1.6, 10.25], [0.6, 1.0, 10.25]],
	["LoungeKitchen", "lounge_kitchen", [5.5, 1.6, 10.0], [3.0, 1.0, 16.0]],
	["ArmoryBench", "armory_bench", [24.0, 1.7, 3.5], [27.6, 1.3, 3.5]],
	["MaskRoom", "mask_room", [23.6, 1.7, 10.8], [27.6, 1.2, 9.5]],
	["CorridorToRange", "corridor_to_range", [20.75, 1.6, 10.5], [20.75, 1.4, 17.8]],
	["RangeVestibule", "range_vestibule", [20.0, 1.7, 14.2], [20.75, 1.2, 17.8]],
	["BunkRoom", "bunk_room", [14.6, 1.7, 14.1], [18.0, 1.0, 17.5]],
	["KitStore", "kit_store", [23.2, 1.7, 12.8], [27.0, 1.0, 17.5]],
	["RooflightUpA", "rooflight_up_a", [15.0, 1.8, 8.0], [15.0, 5.7, 6.0]],
	["RooflightUpB", "rooflight_up_b", [12.0, 1.8, 8.0], [12.0, 5.7, 6.0]],
]
const TOPDOWN_SIZE: float = 32.0
