## Shadow Ledger (Kessler & Moor penthouse, Calder Tower) greybox layout data. Owner: ENV C (C2, G1).
## Source of truth for build_greybox.gd. Design: docs/design/heists/shadow_ledger.md (APPROVED, D-042).
## Coordinates: metres, world x = plan x (east), world z = plan z (south), +y up. Origin = the NW
## corner of the floor plate on the wall centre lines (the plan's origin). Levels (floor_heights):
## L40 service 0.0, L41 offices 3.6, L42 partners 8.0, roof 11.6. Room rectangles are the plan
## generator's (tools/levelcheck/plans/shadow_ledger_floors_ascii.py); the builder derives the
## interior walls from their edges (0.2 m, 0.3 m for the core and the roof plant block), the curtain
## wall from the facade edges and the slabs/ceilings from the vertical data.
## Boxes are [x0, y0, z0, x1, y1, z1]. Never edit the generated shadow_ledger.tscn by hand.
extends RefCounted

const FLOOR_HEIGHTS: Array[float] = [0.0, 3.6, 8.0, 11.6]
## HeistMap.floor_names (D-054), parallel to FLOOR_HEIGHTS.
const FLOOR_NAMES: Array[String] = ["L40", "L41", "L42", "Roof"]
const F40: float = 0.0
const F41: float = 3.6
const F42: float = 8.0
const FRF: float = 11.6
## Slab undersides (wall tops): L40 plenum + slab 3.3-3.6, L41 0.8 m slab 7.2-8.0, roof 11.0-11.6.
const TOP40: float = 3.3
const TOP41: float = 7.2
const TOP42: float = 11.0
const TOPRF: float = 15.1
const PLANT_ROOF: float = 15.4
const PARAPET_TOP: float = 12.7
const DOOR_H: float = 2.2
const EXT_T: float = 0.4
const INT_T: float = 0.2
const CORE_T: float = 0.3
## Level key -> [FFL, wall top, floor index].
const LEVELS: Dictionary = {"L40": [F40, TOP40, 0], "L41": [F41, TOP41, 1], "L42": [F42, TOP42, 2], "RF": [FRF, TOPRF, 3]}
const CORE_IDS: Array[String] = ["J", "LF1", "LF2", "SL", "SA", "WCW", "WCM", "SB"]

# --- Plan rectangles (from the plan generator) -------------------------------------------------

const CORE: Array = [
	["J", 12.0, 7.5, 15.0, 10.5], ["LF1", 15.0, 7.5, 18.0, 10.0], ["LF2", 18.0, 7.5, 21.0, 10.0],
	["SL", 21.0, 7.5, 24.0, 10.5], ["SA", 12.0, 10.5, 15.0, 16.5], ["WCW", 15.0, 10.0, 18.0, 16.5],
	["WCM", 18.0, 10.0, 21.0, 16.5], ["SB", 21.0, 10.5, 24.0, 16.5],
]
## Rooms per level: [plan id, x0, z0, x1, z1]. L40: only the in-play rooms (the rest is the sealed
## vacant floor). The core rooms are appended by the builder on L41/L42.
const PLAN_ROOMS: Dictionary = {
	"L40": [["S1", 24.0, 7.5, 30.0, 12.5], ["S3", 24.0, 12.5, 25.5, 16.5], ["S2", 25.5, 12.5, 30.0, 16.5],
		["SA", 12.0, 10.5, 15.0, 16.5], ["SB", 21.0, 10.5, 24.0, 16.5], ["SL", 21.0, 7.5, 24.0, 10.5]],
	"L41": [["K1", 0.0, 0.0, 7.0, 6.0], ["K2", 7.0, 0.0, 12.0, 6.0], ["K3", 12.0, 0.0, 24.0, 7.5],
		["K4", 24.0, 0.0, 29.0, 6.0], ["K5", 29.0, 0.0, 36.0, 6.0], ["K6", 0.0, 6.0, 12.0, 7.5],
		["K7", 24.0, 6.0, 36.0, 7.5], ["K8", 0.0, 7.5, 10.5, 16.5], ["K9", 10.5, 7.5, 12.0, 16.5],
		["K10", 24.0, 7.5, 25.5, 16.5], ["K11", 25.5, 7.5, 31.0, 12.5], ["K12", 31.0, 7.5, 36.0, 12.5],
		["K13", 25.5, 12.5, 30.0, 16.5], ["K14", 30.0, 12.5, 32.5, 16.5], ["K15", 32.5, 12.5, 36.0, 16.5],
		["K16", 0.0, 16.5, 36.0, 18.0], ["K17", 0.0, 18.0, 6.0, 24.0], ["K18", 6.0, 18.0, 12.0, 24.0],
		["K19", 12.0, 18.0, 18.0, 24.0], ["K20", 18.0, 18.0, 21.0, 24.0], ["K21", 21.0, 18.0, 24.0, 24.0],
		["K22", 24.0, 18.0, 27.0, 24.0], ["K23", 27.0, 18.0, 30.0, 24.0], ["K24", 30.0, 18.0, 36.0, 24.0]],
	"L42": [["M1", 0.0, 0.0, 12.0, 7.5], ["M2", 12.0, 0.0, 24.0, 7.5], ["M3", 24.0, 0.0, 29.0, 7.5],
		["M4", 29.0, 0.0, 36.0, 7.5], ["M5", 0.0, 7.5, 6.5, 13.0], ["M6", 6.5, 7.5, 10.5, 11.0],
		["M7", 6.5, 11.0, 10.5, 13.0], ["M8", 0.0, 13.0, 10.5, 18.0], ["M9", 10.5, 7.5, 12.0, 16.5],
		["M10", 24.0, 7.5, 25.5, 16.5], ["M11", 25.5, 7.5, 31.0, 12.0], ["M12", 25.5, 12.0, 28.0, 16.5],
		["M13", 28.0, 12.0, 31.0, 16.5], ["M14", 31.0, 7.5, 36.0, 16.5], ["M15", 10.5, 16.5, 36.0, 18.0]],
	"RF": [["R1", 12.0, 7.5, 15.0, 10.5], ["R2", 12.0, 10.5, 15.0, 16.5], ["R3", 15.0, 7.5, 24.0, 16.5]],
}
## Curtain-wall lines per level: [axis ("x" = along x at fixed z), fixed, from, to].
const FACADE_LINES: Dictionary = {
	"L41": [["x", 0.0, 0.0, 36.0], ["x", 24.0, 0.0, 36.0], ["z", 0.0, 0.0, 24.0], ["z", 36.0, 0.0, 24.0]],
	"L42": [["x", 0.0, 0.0, 36.0], ["x", 18.0, 0.0, 36.0], ["z", 0.0, 0.0, 18.0], ["z", 36.0, 0.0, 18.0]],
}
## Solid facade bays (no glazing): [level, axis, fixed, from, to] (terrace ladder bay, C12 camera bay).
const SOLID_BAYS: Array = [["L42", "x", 18.0, 34.0, 35.0], ["L42", "x", 18.0, 5.5, 6.5]]
## Plan openings without a wall: [level, axis, fixed, from, to].
const WALL_OPEN: Array = [
	["L40", "x", 12.5, 24.0, 25.5],
	["L41", "x", 7.5, 10.5, 12.0], ["L41", "x", 7.5, 24.0, 25.5], ["L41", "x", 16.5, 10.5, 12.0], ["L41", "x", 16.5, 24.0, 25.5],
	["L42", "z", 12.0, 4.0, 7.5], ["L42", "x", 7.5, 10.5, 12.0], ["L42", "x", 16.5, 10.5, 12.0], ["L42", "x", 16.5, 24.0, 25.5],
]
## Interior glazing: [level, axis, fixed, from, to, sill (rel), head (rel), frosted]: the K11/K12 vision panel
## and the lounge's glass wall over the reception void. D-142: a frosted pane is opaque for stealth vision (not
## `see_through`, the shared texgen `glass_frosted` finish); the K11/K12 panel is frosted so K12 never sees the 45 s
## ledger hack in K11 (ghost line step 5). The lounge wall is clear.
const WALL_GLASS: Array = [["L41", "z", 31.0, 9.0, 11.0, 0.9, 2.1, true], ["L42", "z", 12.0, 0.0, 4.0, 0.0, 3.0, false]]
## Door leaves on solid walls (visual only, no gap): locked fire doors to the sealed vacant floor
## (no prefab, no interaction) and the closed, locked-out lift landing doors. [name, box].
const DOOR_PANELS: Array = [
	["SealedS1East", [29.86, F40, 9.5, 29.9, F40 + 2.1, 10.5]],
	["SealedStairA", [12.15, F40, 15.3, 12.19, F40 + 2.1, 16.2]],
	["Lift1L41", [16.0, F41, 7.31, 17.0, F41 + 2.1, 7.35]], ["Lift2L41", [19.0, F41, 7.31, 20.0, F41 + 2.1, 7.35]],
	["Lift1L42", [16.0, F42, 7.31, 17.0, F42 + 2.1, 7.35]], ["Lift2L42", [19.0, F42, 7.31, 20.0, F42 + 2.1, 7.35]],
	["ServiceLiftL41", [24.15, F41, 8.65, 24.19, F41 + 2.1, 9.85]], ["ServiceLiftL42", [24.15, F42, 8.65, 24.19, F42 + 2.1, 9.85]],
]
## Service lift car opening at L40 (S1 -> car, open; 1.2 m): [axis, fixed, from, to, head].
const LIFT_CAR_OPENING: Array = ["z", 24.0, 8.65, 9.85, 2.4]

# --- Rooms -------------------------------------------------------------------------------------

## Room metadata by unique id: [purpose, dressing kit, ceiling (rel; 0 = none), facade sill (rel),
## ceiling_range override or null]. Core rooms on L41/L42 get a level suffix (J41, WCW42 ...).
## lounge / dining_room / dressing have no row in the ceiling table: 2.6-3.0 (residential)
## overrides, justified in the design doc's room list (D-048). M7 is `dressing` (QC-30).
const ROOM_META: Dictionary = {
	"S1": ["lobby", "service_lobby", 3.0, 0.9, null], "S2": ["storage", "refuse_room", 3.0, 0.9, null],
	"S3": ["corridor", "corridor_service", 3.0, 0.9, null],
	"SA": ["stair", "", 0.0, 0.0, null], "SB": ["stair", "", 0.0, 0.0, null],
	"SL": ["elevator", "", 2.6, 0.0, null], "LF1": ["shaft", "", 0.0, 0.0, null], "LF2": ["shaft", "", 0.0, 0.0, null],
	"J41": ["storage", "janitor_sl", 2.7, 0.9, null], "J42": ["storage", "linen_janitor", 2.7, 0.9, null],
	"WCW41": ["restroom", "restroom_exec", 2.7, 0.9, null], "WCM41": ["restroom", "restroom_exec", 2.7, 0.9, null],
	"WCW42": ["restroom", "restroom_exec", 2.7, 0.9, null], "WCM42": ["restroom", "restroom_exec", 2.7, 0.9, null],
	"K1": ["office", "office_partner", 3.0, 0.9, null], "K2": ["office", "conference_room", 3.0, 0.9, null],
	"K3": ["lobby", "reception_exec", 3.6, 0.3, null], "K4": ["office", "office_small", 3.0, 0.9, null],
	"K5": ["office", "office_partner", 3.0, 0.9, null], "K6": ["corridor", "corridor_office", 2.7, 0.9, null],
	"K7": ["corridor", "corridor_office", 2.7, 0.9, null], "K8": ["office", "office_open_law", 3.0, 0.9, null],
	"K9": ["corridor", "corridor_office", 2.7, 0.9, null], "K10": ["corridor", "corridor_service", 2.7, 0.9, null],
	"K11": ["server_room", "server_room_sl", 2.7, 0.9, null], "K12": ["office", "office_it", 3.0, 0.9, null],
	"K13": ["security_room", "security_office_sl", 2.7, 0.9, null], "K14": ["electrical", "electrical_sl", 2.7, 0.9, null],
	"K15": ["storage", "copy_room", 3.0, 0.9, null], "K16": ["corridor", "corridor_spine_sl", 2.7, 0.9, null],
	"K17": ["storage", "archive_records", 3.0, 0.9, null], "K18": ["break_room", "break_room_office", 3.0, 0.9, null],
	"K19": ["office", "library_law", 3.0, 0.9, null], "K20": ["office", "office_small", 3.0, 0.9, null],
	"K21": ["office", "office_small", 3.0, 0.9, null], "K22": ["office", "office_small", 3.0, 0.9, null],
	"K23": ["office", "office_small", 3.0, 0.9, null], "K24": ["office", "meeting_small", 3.0, 0.9, null],
	"M1": ["lounge", "lounge_exec", 3.0, 0.3, Vector2(2.6, 3.0)], "M2": ["lobby", "gallery_mezzanine", 3.0, 0.3, null],
	"M3": ["gallery", "art_hall", 3.0, 0.9, Vector2(3.0, 4.5)], "M4": ["office", "study_exec", 3.0, 0.3, null],
	"M5": ["bedroom", "bedroom_exec", 3.0, 0.9, null], "M6": ["restroom", "bathroom_ensuite", 2.7, 0.9, null],
	"M7": ["dressing", "dressing_room", 2.7, 0.9, Vector2(2.6, 3.0)], "M8": ["dining_room", "dining_exec", 3.0, 0.3, Vector2(2.6, 3.0)],
	"M9": ["corridor", "corridor_office", 2.7, 0.9, null], "M10": ["corridor", "corridor_service", 2.7, 0.9, null],
	"M11": ["break_room", "break_room_office", 2.7, 0.9, null], "M12": ["electrical", "electrical_sl", 2.7, 0.9, null],
	"M13": ["storage", "wine_room", 2.7, 0.9, null], "M14": ["office", "boardroom", 3.0, 0.9, null],
	"M15": ["corridor", "corridor_glazed", 2.7, 0.3, null],
	"R1": ["plant", "plant_riser", 3.5, 0.0, null], "R2": ["stair", "", 3.5, 0.0, null], "R3": ["plant", "plant_room_roof", 3.5, 0.0, null],
}
## RoomVolume / ceiling rectangles where they differ from the plan rectangle: K3 and M2 leave out
## the feature stair / void; J and R1 leave out the services riser.
const ROOM_RECTS: Dictionary = {
	"K3": [[12.0, 2.2, 24.0, 7.5], [20.6, 0.0, 24.0, 2.2]],
	"M2": [[12.0, 4.0, 20.5, 7.5], [20.5, 0.0, 24.0, 7.5]],
	"J41": [[12.0, 7.5, 13.5, 9.0], [12.0, 9.0, 15.0, 10.5]],
	"J42": [[12.0, 7.5, 13.5, 9.0], [12.0, 9.0, 15.0, 10.5]],
	"R1": [[12.0, 7.5, 13.5, 9.0], [12.0, 9.0, 15.0, 10.5]],
}
## Rooms that span levels (one volume each): [id, floor index, y0, y1, rect].
const TALL_ROOMS: Array = [
	["SA", 0, F40, FRF, [12.0, 10.5, 15.0, 16.5]], ["SB", 0, F40, TOP42, [21.0, 10.5, 24.0, 16.5]],
	["SL", 0, F40, FRF, [21.0, 7.5, 24.0, 10.5]], ["LF1", 1, F41, FRF, [15.0, 7.5, 18.0, 10.0]],
	["LF2", 1, F41, FRF, [18.0, 7.5, 21.0, 10.0]],
]
## Exterior rooms: [id, purpose, kit, floor index, boxes].
const EXTERIOR_ROOMS: Array = [
	["X1", "exterior", "exterior_terrace", 2, [[0.0, F42, 18.0, 36.0, FRF, 24.0]]],
	["X2", "exterior", "exterior_roof_tower", 3, [[0.0, FRF, 0.0, 36.0, 15.5, 7.5], [0.0, FRF, 16.5, 36.0, 15.5, 18.0],
		[0.0, FRF, 7.5, 12.0, 15.5, 16.5], [24.0, FRF, 7.5, 36.0, 15.5, 16.5]]],
]

# --- Doors -------------------------------------------------------------------------------------

## Guards and staff that may open locked doors (A2-01 npc_authorized_tags).
const STAFF_TAGS: Array = ["guard_reception", "guard_rover_l41", "guard_rover_l42", "guard_stair", "guard_roof",
	"civ_cleaner_l41", "civ_cleaner_l42", "civ_it", "civ_partner", "civ_kessler", "civ_assistant", "civ_associate"]
## Doors: [name, kit piece, origin (bottom-centre on the wall line), yaw, lock, swing, objective_tag, extra].
## Yaw 0 = front (-Z, UsePoint) faces north, 180 south, 90 west, -90 east. INWARD swings to the back.
## The wall hole is cut from this list (1.0 m single, 2.0 m double; head 2.2) unless extra.no_wall.
## Stair doors: doc "push bar on the floor side, lockpick 8 s from the stair side" - a push_bar door
## blocks its outside completely (A2-08), so they are LOCKPICK 8 s from both sides (G1 report).
const DOORS: Array = [
	# L40 service level.
	["RefuseDoor", "arch_door_single_t20", Vector3(25.5, F40, 14.5), 90.0, "NONE", "INWARD", "", {}],
	["StairBL40", "arch_door_single_t40", Vector3(24.0, F40, 15.75), -90.0, "NONE", "INWARD", "", {"starts_open": true, "fire_exit": true}],
	["StairAGate", "arch_door_single_t20", Vector3(14.15, F40, 15.1), 0.0, "BARRED", "OUTWARD", "police_gate", {"no_wall": true}],
	["StairBGate", "arch_door_single_t20", Vector3(23.15, F40, 15.1), 0.0, "BARRED", "OUTWARD", "police_gate", {"no_wall": true}],
	# L41 north band.
	["K1Door", "arch_door_single_t20", Vector3(5.5, F41, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["K2Door", "arch_door_single_t20", Vector3(9.5, F41, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["ReceptionGlassW", "arch_door_single_t20", Vector3(12.0, F41, 6.75), 90.0, "NONE", "INWARD", "", {"leaf_surface": "glass"}],
	["ReceptionGlassE", "arch_door_single_t20", Vector3(24.0, F41, 6.75), -90.0, "NONE", "INWARD", "", {"leaf_surface": "glass"}],
	["K4Door", "arch_door_single_t20", Vector3(26.5, F41, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["K5Door", "arch_door_single_t20", Vector3(30.5, F41, 6.0), 180.0, "NONE", "INWARD", "", {}],
	["K1FacadeDoor", "arch_door_single_t40", Vector3(0.0, F41, 3.0), -90.0, "LOCKPICK", "OUTWARD", "gondola_west",
		{"interaction_time_s": 8.0, "access_sides": "front"}],
	# L41 west.
	["K8DoorN", "arch_door_single_t20", Vector3(2.0, F41, 7.5), 0.0, "NONE", "INWARD", "", {}],
	["K8DoorE", "arch_door_single_t20", Vector3(10.5, F41, 12.0), -90.0, "NONE", "INWARD", "", {}],
	["K8DoorS", "arch_door_single_t20", Vector3(5.0, F41, 16.5), 180.0, "NONE", "INWARD", "", {}],
	["JanitorL41", "arch_door_single_t40", Vector3(12.0, F41, 9.0), 90.0, "NONE", "INWARD", "", {}],
	["StairAL41", "arch_door_single_t40", Vector3(12.0, F41, 15.75), 90.0, "LOCKPICK", "INWARD", "stair_door",
		{"npc_auth": true, "interaction_time_s": 8.0}],
	["WCWestL41", "arch_door_single_t40", Vector3(16.5, F41, 16.5), 180.0, "NONE", "INWARD", "", {}],
	["WCMenL41", "arch_door_single_t40", Vector3(19.5, F41, 16.5), 180.0, "NONE", "INWARD", "", {}],
	# L41 east wing.
	["StairBL41", "arch_door_single_t40", Vector3(24.0, F41, 15.75), -90.0, "LOCKPICK", "INWARD", "stair_door",
		{"npc_auth": true, "interaction_time_s": 8.0}],
	["ServerDoor", "arch_door_single_t20", Vector3(25.5, F41, 10.0), 90.0, "ELECTRONIC", "INWARD", "server_door",
		{"npc_auth": true}],
	["ITDoor", "arch_door_single_t20", Vector3(33.5, F41, 7.5), 0.0, "NONE", "INWARD", "", {}],
	["SecurityDoor", "arch_door_single_t20", Vector3(25.5, F41, 14.5), 90.0, "NONE", "INWARD", "", {}],
	["ElectricalL41", "arch_door_single_t20", Vector3(31.5, F41, 16.5), 180.0, "NONE", "INWARD", "", {}],
	["CopyRoomDoor", "arch_door_single_t20", Vector3(34.0, F41, 16.5), 180.0, "NONE", "INWARD", "", {}],
	["CageGate", "arch_door_single_t20", Vector3(28.6, F41, 10.5), 180.0, "ELECTRONIC", "OUTWARD", "cage_gate",
		{"no_wall": true, "leaf_surface": "metal"}],
	# L41 south band (K16 -> rooms).
	["ArchiveDoor", "arch_door_single_t20", Vector3(3.0, F41, 18.0), 0.0, "NONE", "INWARD", "", {}],
	["BreakRoomDoor", "arch_door_single_t20", Vector3(9.0, F41, 18.0), 0.0, "NONE", "INWARD", "", {}],
	["LibraryDoor", "arch_door_single_t20", Vector3(15.0, F41, 18.0), 0.0, "NONE", "INWARD", "", {}],
	["K20Door", "arch_door_single_t20", Vector3(19.5, F41, 18.0), 0.0, "NONE", "INWARD", "", {}],
	["K21Door", "arch_door_single_t20", Vector3(22.5, F41, 18.0), 0.0, "NONE", "INWARD", "", {}],
	["K22Door", "arch_door_single_t20", Vector3(25.5, F41, 18.0), 0.0, "NONE", "INWARD", "", {}],
	["K23Door", "arch_door_single_t20", Vector3(28.5, F41, 18.0), 0.0, "NONE", "INWARD", "", {}],
	["InterviewDoor", "arch_door_single_t20", Vector3(33.0, F41, 18.0), 0.0, "NONE", "INWARD", "", {}],
	# L42.
	["ArtHallDoors", "arch_door_double_t20", Vector3(24.0, F42, 3.0), 90.0, "NONE", "DOUBLE", "", {"starts_open": true}],
	# PO-7: centred in the M10 corridor mouth (x 24.15-25.4); at x 25.0 its frame ran 0.1 m into the x 25.5 wall.
	["ArtHallStaffDoor", "arch_door_single_t20", Vector3(24.8, F42, 7.5), 180.0, "NONE", "INWARD", "", {}],
	["StudyDoor", "arch_door_single_t20", Vector3(29.0, F42, 3.5), 90.0, "LOCKPICK", "INWARD", "study_door",
		{"npc_auth": true, "interaction_time_s": 8.0}],
	["StudyFacadeDoor", "arch_door_single_t40", Vector3(33.0, F42, 0.0), 180.0, "LOCKPICK", "OUTWARD", "gondola_north",
		{"interaction_time_s": 8.0, "access_sides": "front"}],
	["LinenL42", "arch_door_single_t40", Vector3(12.0, F42, 9.0), 90.0, "NONE", "INWARD", "", {}],
	["StairAL42", "arch_door_single_t40", Vector3(12.0, F42, 15.75), 90.0, "LOCKPICK", "INWARD", "stair_door",
		{"npc_auth": true, "interaction_time_s": 8.0}],
	["StairBL42", "arch_door_single_t40", Vector3(24.0, F42, 15.75), -90.0, "LOCKPICK", "INWARD", "stair_door",
		{"npc_auth": true, "interaction_time_s": 8.0}],
	["WCWestL42", "arch_door_single_t40", Vector3(16.5, F42, 16.5), 180.0, "NONE", "INWARD", "", {}],
	["WCMenL42", "arch_door_single_t40", Vector3(19.5, F42, 16.5), 180.0, "NONE", "INWARD", "", {}],
	["SuiteDoor", "arch_door_single_t20", Vector3(6.5, F42, 12.0), -90.0, "NONE", "INWARD", "", {}],
	["BathDoor", "arch_door_single_t20", Vector3(8.5, F42, 11.0), 180.0, "NONE", "INWARD", "", {}],
	["DressingDoor", "arch_door_single_t20", Vector3(10.5, F42, 12.0), -90.0, "NONE", "INWARD", "", {}],
	["DiningDoor", "arch_door_single_t20", Vector3(10.5, F42, 15.0), -90.0, "NONE", "INWARD", "", {}],
	["PantryDoor", "arch_door_single_t20", Vector3(25.5, F42, 10.0), 90.0, "NONE", "INWARD", "", {}],
	["ElectricalL42", "arch_door_single_t20", Vector3(25.5, F42, 14.0), 90.0, "NONE", "INWARD", "", {}],
	["WineRoomDoor", "arch_door_single_t20", Vector3(29.5, F42, 16.5), 180.0, "NONE", "INWARD", "", {}],
	["BoardroomDoor", "arch_door_single_t20", Vector3(33.5, F42, 16.5), 180.0, "NONE", "INWARD", "", {}],
	# Terrace sliders (lockpick 8 s from outside; the leaf opens onto the terrace).
	["SliderDining", "arch_door_single_t40", Vector3(4.5, F42, 18.0), 180.0, "LOCKPICK", "OUTWARD", "terrace_slider",
		{"npc_auth": true, "interaction_time_s": 8.0, "leaf_surface": "glass"}],
	["SliderWest", "arch_door_single_t40", Vector3(14.5, F42, 18.0), 180.0, "LOCKPICK", "OUTWARD", "terrace_slider",
		{"npc_auth": true, "interaction_time_s": 8.0, "leaf_surface": "glass"}],
	["SliderEast", "arch_door_single_t40", Vector3(30.5, F42, 18.0), 180.0, "LOCKPICK", "OUTWARD", "terrace_slider",
		{"npc_auth": true, "interaction_time_s": 8.0, "leaf_surface": "glass"}],
	# Roof: head house (Stair A), riser bay, plant. The head house -> plant door sits on the floor
	# landing (z 15.75) instead of the plan's z 12, which is over the stair void (G1 report).
	["RoofDoor", "arch_door_single_t40", Vector3(12.0, FRF, 15.75), 90.0, "LOCKPICK", "INWARD", "roof_door",
		{"npc_auth": true, "interaction_time_s": 8.0}],
	["RiserBayDoor", "arch_door_single_t40", Vector3(12.0, FRF, 9.0), 90.0, "LOCKPICK", "INWARD", "riser_door",
		{"npc_auth": true, "interaction_time_s": 8.0}],
	["HeadHousePlantDoor", "arch_door_single_t40", Vector3(15.0, FRF, 15.75), 90.0, "NONE", "INWARD", "", {}],
	["PlantDoor", "arch_door_single_t40", Vector3(19.5, FRF, 7.5), 0.0, "NONE", "INWARD", "", {}],
]

# --- Vertical circulation ----------------------------------------------------------------------

## Stair cores (doc vertical data): 3 x 6 m on centre lines, 0.3 m walls (clear x0+0.15..x0+2.85,
## z 10.65..16.35). Every up-flight starts at z 15.03 (west half, rising north); the half landing at
## the north end absorbs the shorter 3.6 m storeys; the return flight (east half) rises south to the
## floor landing (z 15.03-16.35). Risers 0.18 (3.6 m storeys) / 0.1833 (4.4 m), tread 0.28.
const STAIR_CORES: Dictionary = {"SA": {"x0": 12.0, "levels": [F40, F41, F42, FRF]}, "SB": {"x0": 21.0, "levels": [F40, F41, F42]}}
const STAIR_Z_START: float = 15.03
const STAIR_Z_N: float = 10.65
const STAIR_Z_S: float = 16.35
const STAIR_TREAD: float = 0.28
## Flight / well offsets from the core's x0: west flight, divider (well), east flight.
const STAIR_WEST: Vector2 = Vector2(0.2, 1.4)
const STAIR_WELL: Vector2 = Vector2(1.4, 1.6)
const STAIR_EAST: Vector2 = Vector2(1.6, 2.8)
const STAIR_CLEAR: Vector2 = Vector2(0.15, 2.85)
## SL-P1 (ENV P real-input pass): clear headroom over every stair / landing walk line (a bag carrier's head).
const STAIR_HEADROOM: float = 2.1
## Handrails (level_standards §2 MUST 1.0-1.1 m): bar centre above the riser-to-riser nosing line
## (top 1.05 m), offset from the wall / divider / balustrade face.
const HANDRAIL_H: float = 1.025
const HANDRAIL_OFF: float = 0.07
## Feature stair L41 -> L42 (doc): x 12.84-20.50, z 0.6-2.0, 2 x 12 risers, landing 1.5 m, solid base.
const FEATURE_STAIR: Dictionary = {"x0": 12.84, "z": [0.6, 2.0], "risers": 12, "landing": 1.5, "y0": F41, "y1": F42}

## Services riser (1.5 x 1.5 m on centre lines, NE corner of J): walls 0.15, L41 floor -> roof.
## Panels (0.9 x 2.0) on its south wall into J at L41 and L42; grating at L42; hatch in R1.
const RISER: Dictionary = {
	"box": [13.5, 7.5, 15.0, 9.0], "t": 0.15, "panel": [13.8, 14.7], "inner": [13.65, 7.65, 14.85, 8.85],
	"lower_hole": [13.65, 7.65, 14.25, 8.05], "hatch": [14.25, 7.65, 14.85, 8.05],
	"lower_ladder": Vector3(13.95, F41, 7.8), "upper_ladder": Vector3(14.55, F42, 7.8),
}

## Gondola (BMU cradle) stops: cradle deck box, boarding ladder base + height (ladder yaw: Top is
## 0.4 m along the ladder's +Z), parapet gate gap [axis, fixed, from, to], nav link roof <-> room.
const GONDOLAS: Dictionary = {
	"gon_west_l41": {"deck": [-1.05, F41 - 0.15, 1.3, -0.25, F41, 4.0], "ladder": Vector3(-0.6, F41, 1.8), "ladder_yaw": 90.0,
		"ladder_h": 8.0, "gate": ["z", 0.0, 1.3, 2.3], "link": [Vector3(0.9, FRF, 1.8), Vector3(1.0, F41, 3.0)]},
	"gon_north_l42": {"deck": [31.6, F42 - 0.15, -1.05, 34.4, F42, -0.25], "ladder": Vector3(31.95, F42, -0.6), "ladder_yaw": 0.0,
		"ladder_h": 3.6, "gate": ["x", 0.0, 31.45, 32.45], "link": [Vector3(31.95, FRF, 0.9), Vector3(33.0, F42, 1.0)]},
}
## Terrace caged ladder (SE bay, x 34-35): terrace -> roof; parapet gap x 34-35 at z 18.
const TERRACE_LADDER: Dictionary = {"pos": Vector3(34.5, F42, 18.45), "yaw": 180.0, "h": 3.6,
	"gap": ["x", 18.0, 34.0, 35.0], "link": [Vector3(34.5, F42, 19.1), Vector3(34.5, FRF, 17.3)]}

## Roof parapet runs (1.1 m + 55 deg coping, RT.ANGLE_DEG): [name, axis, fixed, from, to].
const PARAPETS: Array = [
	["ParapetN", "x", 0.0, -0.2, 36.2], ["ParapetS", "x", 18.0, -0.2, 36.2],
	["ParapetW", "z", 0.0, 0.2, 17.8], ["ParapetE", "z", 36.0, 0.2, 17.8],
]
## Terrace glass balustrade (1.1 m, L42 level): [name, box(, solid upstand height)]. D-142: the M2 void edge stands
## on a 0.45 m stone-clad upstand (opaque for stealth vision); the glass above it stays clear (`see_through`).
const VOID_UPSTAND: float = 0.45
const BALUSTRADES: Array = [
	["BalustradeS", [-0.2, F42, 23.97, 36.2, F42 + 1.1, 24.03]],
	["BalustradeW", [-0.03, F42, 18.2, 0.03, F42 + 1.1, 23.97]],
	["BalustradeE", [35.97, F42, 18.2, 36.03, F42 + 1.1, 23.97]],
	# Gallery void edge (L42) and the feature-stair arrival.
	["VoidRailS", [12.1, F42, 4.0, 20.56, F42 + 1.1, 4.06], VOID_UPSTAND],
	["VoidRailE", [20.5, F42, 2.0, 20.56, F42 + 1.1, 4.0], VOID_UPSTAND],
	["VoidRailNE", [20.5, F42, 0.2, 20.56, F42 + 1.1, 0.6], VOID_UPSTAND],
]

# --- Gameplay placements (used by sl_gameplay.gd) ----------------------------------------------

## Server cage K11 (mesh enclosure 2.4 m, gate on its south side at x 28.15-29.05). PO-9: the north panel at
## z 8.4 leaves the hack terminal room to stand clear of the gate's 1 m door zone.
const CAGE: Dictionary = {"box": [27.0, 8.4, 30.5, 10.5], "h": 2.4, "gate": [28.1, 29.1]}
## Art hall laser plane (M3, x 26.5, full width between the curtain wall and the M3/M10 wall).
const LASER_X: float = 26.5
const LASER_Z: Vector2 = Vector2(0.2, 7.4)
## Security camera mounts: id -> [pivot, yaw, bracket box or null]. Wall mounts face the room; where
## the doc's view direction runs along a wall, a small soffit bracket (Geometry) carries the camera.
const CAMERAS: Dictionary = {
	"C1": [Vector3(23.9, F41 + 3.1, 1.0), 90.0, null],
	"C2": [Vector3(0.02, F41 + 2.5, 6.75), -90.0, null],
	"C3": [Vector3(25.25, F41 + 2.55, 10.6), 0.0, [25.1, F41 + 2.35, 10.6, 25.4, TOP41 - 0.9, 10.9]],
	"C4": [Vector3(35.98, F41 + 2.5, 17.25), 90.0, null],
	"C5": [Vector3(35.98, F41 + 2.5, 6.75), 90.0, null],
	"C6": [Vector3(12.4, F42 + 2.8, 7.35), 0.0, null],
	"C7": [Vector3(28.9, F42 + 2.6, 0.6), 90.0, null],
	"C8": [Vector3(10.6, F42 + 2.5, 17.25), -90.0, null],
	"C9": [Vector3(11.85, FRF + 3.0, 11.0), 90.0, null],
	"C10": [Vector3(24.15, FRF + 3.0, 7.9), -90.0, null],
	"C11": [Vector3(0.02, F41 + 2.9, 8.2), -90.0, null],
	"C12": [Vector3(6.0, F42 + 2.75, 18.35), -90.0, [5.7, F42 + 2.55, 18.2, 6.0, F42 + 2.95, 18.5]],
}
const CAMERA_SETS: Array = [
	["cam_a", ["C1", "C3", "C6", "C9", "C11", "C12"]],
	["cam_b", ["C2", "C5", "C7", "C8", "C10", "C11"]],
	["cam_c", ["C3", "C4", "C6", "C7", "C9", "C10"]],
]

# --- Site (visual dressing beyond the play space; no collision) --------------------------------

## [name, box, material]. Calder below the play space, the neighbours, the streets and the skyline.
const SITE_BLOCKS: Array = [
	["CalderBelow", [-0.2, -160.0, -0.2, 36.2, -0.6, 24.2], "tower_dark"],
	["ArdenTower", [-80.0, -160.0, -30.0, -20.2, 33.6, 40.0], "tower"],
	["ArdenCrown", [-70.0, 33.6, -20.0, -30.0, 36.0, 30.0], "tower_dark"],
	["VantageHouse", [66.2, -160.0, -8.0, 100.0, -0.4, 32.0], "tower"],
	["VantagePlantA", [72.0, -0.4, 2.0, 80.0, 2.6, 8.0], "concrete"],
	["VantagePlantB", [86.0, -0.4, 18.0, 94.0, 3.0, 26.0], "concrete"],
	# (SL-1 polish: the south / south-west / east skyline towers are generated by sl_skyline.gd from a fixed seed)
	["StreetGrid", [-300.0, -161.0, -20.0, 300.0, -160.0, 300.0], "street"],
	["Riverside", [-300.0, -161.0, -60.0, 300.0, -160.0, -20.0], "street"],
	["KestrelRiver", [-300.0, -162.0, -300.0, 300.0, -161.0, -60.0], "river"],
	# Horizon ring (300 m): the far-bank skyline (N) and distant towers all round, above eye height.
	["FarBank", [-330.0, -162.0, -330.0, 330.0, 22.0, -300.0], "tower_dark"],
	["HorizonS", [-330.0, -162.0, 300.0, 330.0, 26.0, 330.0], "tower_dark"],
	["HorizonW", [-330.0, -162.0, -300.0, -300.0, 24.0, 300.0], "tower_dark"],
	["HorizonE", [300.0, -162.0, -300.0, 330.0, 23.0, 300.0], "tower_dark"],
]
## Lit floor bands on the near neighbours (dim emissive, flush on their facades): [name, box]. The
## 300 m horizon ring carries none: in the fog its faces vanish and a lit band would float.
const CITY_LIGHTS: Array = [
	["ArdenLit1", [-20.25, 2.0, -24.0, -20.15, 3.0, -4.0]], ["ArdenLit2", [-20.25, 9.2, 6.0, -20.15, 10.2, 30.0]],
	["ArdenLit3", [-20.25, 16.4, -20.0, -20.15, 17.4, 12.0]], ["ArdenLit4", [-20.25, -12.4, 0.0, -20.15, -11.4, 36.0]],
	["ArdenLit5", [-20.25, 23.6, 14.0, -20.15, 24.6, 34.0]], ["ArdenLit6", [-20.25, -26.8, -26.0, -20.15, -25.8, 10.0]],
]
## Cables (dressing): [name, from, to]. Insertion line from Arden. (SL-2: the E2 line down to Vantage is the bag
## line's own cable, drawn by the zipline from its anchor only when `esc_line` is rolled.)
const CABLES: Array = [
	["InsertionLine", Vector3(0.9, FRF + 1.4, 17.2), Vector3(-20.2, 24.0, 16.0)],
]
## Zipline far end (Vantage House roof, beyond the OOB curtain).
const E2_LINE_END: Vector3 = Vector3(68.0, 0.0, 15.0)

# --- Props (gameplay-relevant blockers; placeholder boxes) -------------------------------------

## [name, bottom-centre, size (x, y, z) before yaw, yaw, kind, support, material].
const PROPS: Array = [
	# L40
	["FreightDolly", Vector3(28.4, F40, 11.7), Vector3(1.0, 1.0, 0.7), 0.0, "cart", false, "prop"],
	["SignInLectern", Vector3(29.55, F40, 8.2), Vector3(0.5, 1.1, 0.4), 0.0, "lectern", true, "prop"],
	["RecyclingCage", Vector3(29.4, F40, 13.4), Vector3(0.9, 1.6, 1.2), 0.0, "cage", false, "fence"],
	# K1 Kessler
	["KesslerDesk", Vector3(3.0, F41, 2.2), Vector3(1.8, 0.75, 0.9), 0.0, "desk", true, "prop"],
	["KesslerCredenza", Vector3(3.0, F41, 0.46), Vector3(2.0, 0.8, 0.5), 0.0, "cabinet", true, "counter"],
	["KesslerSofa", Vector3(5.8, F41, 3.6), Vector3(0.9, 0.8, 2.0), 0.0, "sofa", false, "prop"],
	["KesslerShelves", Vector3(6.69, F41, 1.4), Vector3(0.4, 2.0, 1.6), 0.0, "shelf", true, "prop"],
	# K2 conference
	["ConferenceTable", Vector3(9.5, F41, 3.0), Vector3(1.4, 0.75, 3.6), 0.0, "table", true, "prop"],
	["ConferenceCredenza", Vector3(7.31, F41, 3.0), Vector3(0.4, 0.8, 2.0), 0.0, "cabinet", true, "counter"],
	# K3 reception (1.05 transaction ledge; the guard sits north of it facing south)
	["ReceptionDesk", Vector3(18.0, F41, 5.1), Vector3(3.0, 1.05, 0.6), 0.0, "counter_transaction", true, "counter"],
	["LoungeChairW", Vector3(13.6, F41, 5.6), Vector3(0.8, 0.8, 0.8), 0.0, "armchair", false, "prop"],
	["LoungeChairE", Vector3(14.8, F41, 5.6), Vector3(0.8, 0.8, 0.8), 0.0, "armchair", false, "prop"],
	# K4 assistant
	["AssistantDeskA", Vector3(25.6, F41, 2.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["AssistantDeskB", Vector3(27.6, F41, 2.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["AssistantPrinter", Vector3(28.64, F41, 4.8), Vector3(0.5, 1.0, 0.6), 0.0, "printer", false, "trim"],
	# K5 Moor
	["MoorDesk", Vector3(32.5, F41, 2.2), Vector3(1.8, 0.75, 0.9), 0.0, "desk", true, "prop"],
	["MoorMeetingTable", Vector3(33.8, F41, 4.6), Vector3(1.2, 0.75, 1.2), 0.0, "table", true, "prop"],
	# K8 open office (3 clusters)
	["WorkstationsA", Vector3(3.0, F41, 10.0), Vector3(2.4, 0.75, 1.6), 0.0, "desk", true, "prop"],
	["WorkstationsB", Vector3(7.0, F41, 10.0), Vector3(2.4, 0.75, 1.6), 0.0, "desk", true, "prop"],
	["WorkstationsC", Vector3(5.0, F41, 13.8), Vector3(2.4, 0.75, 1.6), 0.0, "desk", true, "prop"],
	["OpenOfficePrinter", Vector3(10.14, F41, 8.4), Vector3(0.5, 1.0, 0.6), 0.0, "printer", false, "trim"],
	# J (L41) janitor
	["MopSink", Vector3(12.65, F41, 10.09), Vector3(0.9, 0.9, 0.5), 0.0, "sink", false, "trim"],
	# K11 server room
	["LedgerRackW", Vector3(27.75, F41, 8.9), Vector3(1.3, 2.0, 0.6), 0.0, "rack", false, "trim"],
	["LedgerRackE", Vector3(29.75, F41, 8.9), Vector3(1.3, 2.0, 0.6), 0.0, "rack", false, "trim"],
	["CracUnit", Vector3(30.2, F41, 11.9), Vector3(1.0, 1.9, 0.8), 0.0, "crac", false, "trim"],
	["UpsUnit", Vector3(26.0, F41, 8.0), Vector3(0.8, 1.6, 0.6), 0.0, "ups", false, "trim"],
	# K12 IT
	# P round 243: desk A west of the ITDoor (x 33.05-33.95) so the door-to-desk lane is >= 2 m; the west slot stays
	# under an agent's width (no nav strip).
	["ITDeskA", Vector3(32.2, F41, 9.0), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["ITDeskB", Vector3(33.0, F41, 11.2), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["ITSpares", Vector3(35.54, F41, 9.6), Vector3(0.5, 2.0, 1.6), 0.0, "shelf", true, "prop"],
	# K13 security room (station against the east wall, the door behind the operator)
	["KeyCabinet", Vector3(26.2, F41, 12.76), Vector3(0.8, 1.0, 0.3), 0.0, "cabinet", true, "trim"],
	["SecurityCounter", Vector3(26.8, F41, 16.14), Vector3(1.4, 0.9, 0.5), 0.0, "counter_service", true, "counter"],
	["SecurityLockers", Vector3(28.1, F41, 12.86), Vector3(1.2, 1.8, 0.5), 0.0, "locker", false, "trim"],
	# K14 / K15
	["SwitchboardL41", Vector3(31.25, F41, 12.86), Vector3(2.0, 2.0, 0.5), 0.0, "switchboard", false, "trim"],
	["Copier", Vector3(34.25, F41, 13.0), Vector3(1.0, 1.1, 0.7), 0.0, "copier", false, "trim"],
	# K17 archive, K18 break, K19 library, K20-K23 associates, K24 interview
	["CompactShelvingA", Vector3(3.0, F41, 19.6), Vector3(4.0, 2.2, 0.8), 0.0, "shelf", true, "prop"],
	["CompactShelvingB", Vector3(3.0, F41, 21.2), Vector3(4.0, 2.2, 0.8), 0.0, "shelf", true, "prop"],
	["BreakCounter", Vector3(9.0, F41, 23.49), Vector3(3.0, 0.9, 0.6), 0.0, "counter_service", true, "counter"],
	["BreakFridge", Vector3(11.54, F41, 23.44), Vector3(0.7, 1.8, 0.7), 0.0, "fridge", false, "trim"],
	["BreakTable", Vector3(9.0, F41, 21.0), Vector3(1.6, 0.75, 1.0), 0.0, "table", true, "prop"],
	["LibraryStacksA", Vector3(15.0, F41, 20.5), Vector3(4.0, 2.2, 0.6), 0.0, "shelf", true, "prop"],
	["LibraryStacksB", Vector3(15.0, F41, 22.6), Vector3(4.0, 2.2, 0.6), 0.0, "shelf", true, "prop"],
	["K20Desk", Vector3(19.5, F41, 22.8), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["K21Desk", Vector3(22.5, F41, 22.8), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["K22Desk", Vector3(25.5, F41, 22.8), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["K23Desk", Vector3(28.5, F41, 22.8), Vector3(1.4, 0.75, 0.7), 0.0, "desk", true, "prop"],
	["InterviewTable", Vector3(33.0, F41, 21.5), Vector3(1.2, 0.75, 1.2), 0.0, "table", true, "prop"],
	["SinkCounterWL41", Vector3(16.5, F41, 10.435), Vector3(2.4, 0.85, 0.55), 180.0, "sink", false, "counter"],
	["SinkCounterML41", Vector3(19.5, F41, 10.435), Vector3(2.4, 0.85, 0.55), 180.0, "sink", false, "counter"],
	# L42: M1 lounge
	["LoungeBar", Vector3(2.5, F42, 1.6), Vector3(3.0, 1.1, 0.6), 0.0, "counter_bar", true, "counter"],
	["SofaGroupW", Vector3(4.0, F42, 5.0), Vector3(2.2, 0.8, 0.9), 0.0, "sofa", false, "prop"],
	["SofaGroupE", Vector3(8.0, F42, 5.0), Vector3(2.2, 0.8, 0.9), 0.0, "sofa", false, "prop"],
	["LoungeCoffeeTable", Vector3(6.0, F42, 3.9), Vector3(1.0, 0.45, 0.6), 0.0, "table", true, "prop"],
	["Piano", Vector3(9.5, F42, 1.6), Vector3(1.5, 1.0, 1.6), 0.0, "piano", false, "prop"],
	# M2 gallery, M3 art hall (west part)
	["PlinthGalleryA", Vector3(16.0, F42, 6.6), Vector3(0.6, 1.1, 0.6), 0.0, "plinth", false, "prop"],
	["PlinthGalleryB", Vector3(19.0, F42, 6.6), Vector3(0.6, 1.1, 0.6), 0.0, "plinth", false, "prop"],
	["PlinthArtHall", Vector3(25.3, F42, 6.0), Vector3(0.6, 1.1, 0.6), 0.0, "plinth", false, "prop"],
	# M4 study
	["StudyDesk", Vector3(32.0, F42, 2.6), Vector3(1.8, 0.75, 0.9), 0.0, "desk", true, "prop"],
	["StudyShelves", Vector3(35.54, F42, 3.6), Vector3(0.5, 2.2, 2.4), 0.0, "shelf", true, "prop"],
	["StudyArmchair", Vector3(34.6, F42, 4.2), Vector3(0.8, 0.8, 0.8), 0.0, "armchair", false, "prop"],
	# M5 guest suite, M6 bath, M7 dressing, M8 dining
	["GuestBed", Vector3(1.26, F42, 10.2), Vector3(2.1, 0.6, 1.8), 0.0, "bed", true, "prop"],
	["NightstandN", Vector3(0.46, F42, 8.85), Vector3(0.5, 0.6, 0.45), 0.0, "nightstand", true, "prop"],
	["NightstandS", Vector3(0.46, F42, 11.55), Vector3(0.5, 0.6, 0.45), 0.0, "nightstand", true, "prop"],
	["GuestWardrobe", Vector3(5.5, F42, 7.91), Vector3(1.6, 2.0, 0.6), 0.0, "wardrobe", false, "prop"],
	["BathVanity", Vector3(8.5, F42, 7.885), Vector3(2.0, 0.85, 0.55), 180.0, "sink", false, "counter"],
	["DressingWardrobes", Vector3(8.0, F42, 12.65), Vector3(1.6, 2.0, 0.5), 0.0, "wardrobe", false, "prop"],
	["DiningTable", Vector3(5.0, F42, 15.3), Vector3(3.6, 0.75, 1.2), 0.0, "table", true, "prop"],
	["DiningSideboard", Vector3(5.0, F42, 13.34), Vector3(2.4, 0.9, 0.45), 0.0, "cabinet", true, "counter"],
	["WineFridge", Vector3(10.09, F42, 13.41), Vector3(0.6, 0.9, 0.6), 0.0, "fridge", false, "trim"],
	# J (L42) linen + the cleaner's cart
	["LinenShelves", Vector3(12.45, F42, 8.0), Vector3(0.5, 2.0, 0.6), 0.0, "shelf", true, "prop"],
	["CleanerCartL42", Vector3(12.65, F42, 10.09), Vector3(0.9, 1.0, 0.5), 0.0, "cart", true, "prop"],
	# M11 pantry, M12 electrical, M13 wine room, M14 boardroom
	["PantryCounter", Vector3(28.25, F42, 7.885), Vector3(3.5, 0.9, 0.55), 0.0, "counter_service", true, "counter"],
	["PantryFridge", Vector3(30.54, F42, 7.96), Vector3(0.7, 1.8, 0.7), 0.0, "fridge", false, "trim"],
	["PantryTable", Vector3(28.0, F42, 10.3), Vector3(1.2, 0.75, 1.2), 0.0, "table", true, "prop"],
	["SubBoardL42", Vector3(26.75, F42, 16.14), Vector3(2.0, 2.0, 0.5), 0.0, "switchboard", false, "trim"],
	["WineRacks", Vector3(29.5, F42, 12.36), Vector3(2.6, 2.0, 0.5), 0.0, "shelf", false, "prop"],
	["Humidor", Vector3(30.64, F42, 14.5), Vector3(0.5, 1.0, 0.6), 0.0, "cabinet", true, "trim"],
	["BoardroomTable", Vector3(33.5, F42, 12.0), Vector3(1.4, 0.75, 4.8), 0.0, "table", true, "prop"],
	["BoardroomCredenza", Vector3(33.5, F42, 7.86), Vector3(2.0, 0.8, 0.5), 0.0, "cabinet", true, "counter"],
	["SinkCounterWL42", Vector3(16.5, F42, 10.435), Vector3(2.4, 0.85, 0.55), 180.0, "sink", false, "counter"],
	["SinkCounterML42", Vector3(19.5, F42, 10.435), Vector3(2.4, 0.85, 0.55), 180.0, "sink", false, "counter"],
	# Terrace X1
	["PlanterA", Vector3(4.0, F42, 23.4), Vector3(3.0, 0.9, 0.8), 0.0, "planter", false, "planter"],
	["PlanterB", Vector3(12.0, F42, 23.4), Vector3(3.0, 0.9, 0.8), 0.0, "planter", false, "planter"],
	["PlanterC", Vector3(20.0, F42, 23.4), Vector3(3.0, 0.9, 0.8), 0.0, "planter", false, "planter"],
	["PlanterD", Vector3(28.0, F42, 23.4), Vector3(3.0, 0.9, 0.8), 0.0, "planter", false, "planter"],
	["LoungerA", Vector3(8.0, F42, 20.6), Vector3(0.7, 0.4, 1.9), 0.0, "lounger", false, "prop"],
	["LoungerB", Vector3(9.4, F42, 20.6), Vector3(0.7, 0.4, 1.9), 0.0, "lounger", false, "prop"],
	["OutdoorKitchen", Vector3(17.5, F42, 18.51), Vector3(3.0, 0.9, 0.6), 0.0, "counter_service", true, "counter"],
	["PatioHeaterA", Vector3(22.0, F42, 20.4), Vector3(0.5, 2.2, 0.5), 0.0, "heater", false, "trim"],
	["PatioHeaterB", Vector3(25.0, F42, 21.6), Vector3(0.5, 2.2, 0.5), 0.0, "heater", false, "trim"],
	# Roof: plant room R3 (body hide behind the AHU), BMU and its cradle garage, anchors
	["AirHandlerRoof", Vector3(17.5, FRF, 13.5), Vector3(2.4, 2.2, 1.6), 0.0, "ahu", false, "trim"],
	["Chiller", Vector3(21.5, FRF, 13.5), Vector3(2.2, 2.0, 1.4), 0.0, "chiller", false, "trim"],
	["WaterTank", Vector3(21.8, FRF, 9.6), Vector3(1.6, 2.2, 1.6), 0.0, "tank", false, "trim"],
	["LiftMotors", Vector3(16.5, FRF, 9.0), Vector3(2.0, 1.2, 1.2), 0.0, "lift_motor", false, "trim"],
	["BMUMachine", Vector3(4.5, FRF, 1.8), Vector3(3.0, 2.5, 1.6), 0.0, "bmu", false, "steel"],
	["CradleGarage", Vector3(8.5, FRF, 2.0), Vector3(3.0, 2.2, 2.4), 0.0, "garage", false, "steel"],
	["InsertionAnchor", Vector3(0.9, FRF, 17.2), Vector3(0.6, 1.4, 0.6), 0.0, "anchor_frame", false, "steel"],
	["E2AnchorFrame", Vector3(35.4, FRF, 15.6), Vector3(0.6, 2.2, 0.6), 0.0, "anchor_frame", false, "steel"],
]
## Chairs: [name, bottom-centre, yaw (front -Z faces the desk), the desk prop it faces].
const CHAIRS: Array = [
	["ReceptionChair", Vector3(18.0, F41, 4.3), 180.0, "ReceptionDesk"],
	["KesslerChair", Vector3(3.0, F41, 1.3), 180.0, "KesslerDesk"],
	["MoorChair", Vector3(32.5, F41, 1.3), 180.0, "MoorDesk"],
	["StudyChair", Vector3(32.0, F42, 1.7), 180.0, "StudyDesk"],
	# PO-9: seats round the tables, 0.225 m off the table edge, each facing its table. Door zones, patrol
	# spots and the credenzas / sideboard behind them stay clear.
	# K2 conference: three a side (the south end is the door's clear zone).
	["ConfChairW1", Vector3(8.35, F41, 1.8), -90.0, "ConferenceTable"],
	["ConfChairW2", Vector3(8.35, F41, 3.0), -90.0, "ConferenceTable"],
	["ConfChairW3", Vector3(8.35, F41, 4.2), -90.0, "ConferenceTable"],
	["ConfChairE1", Vector3(10.65, F41, 1.8), 90.0, "ConferenceTable"],
	["ConfChairE2", Vector3(10.65, F41, 3.0), 90.0, "ConferenceTable"],
	["ConfChairE3", Vector3(10.65, F41, 4.2), 90.0, "ConferenceTable"],
	# K18 break room: two on the counter side and one at each end (the K18Break patrol spot is north).
	["BreakChairS1", Vector3(8.6, F41, 21.95), 0.0, "BreakTable"],
	["BreakChairS2", Vector3(9.4, F41, 21.95), 0.0, "BreakTable"],
	["BreakChairW", Vector3(7.75, F41, 21.0), -90.0, "BreakTable"],
	["BreakChairE", Vector3(10.25, F41, 21.0), 90.0, "BreakTable"],
	# M8 dining: two a side and one at each end (the M8Dining patrol spot is south of the middle).
	["DiningChairN1", Vector3(3.9, F42, 14.25), 180.0, "DiningTable"],
	["DiningChairN2", Vector3(6.1, F42, 14.25), 180.0, "DiningTable"],
	["DiningChairS1", Vector3(3.9, F42, 16.35), 0.0, "DiningTable"],
	["DiningChairS2", Vector3(6.1, F42, 16.35), 0.0, "DiningTable"],
	["DiningChairW", Vector3(2.75, F42, 15.3), -90.0, "DiningTable"],
	["DiningChairE", Vector3(7.25, F42, 15.3), 90.0, "DiningTable"],
	# M14 boardroom: four a side and the head at the north end (the south end is the door and patrol spot).
	["BoardChairW1", Vector3(32.35, F42, 10.35), -90.0, "BoardroomTable"],
	["BoardChairW2", Vector3(32.35, F42, 11.45), -90.0, "BoardroomTable"],
	["BoardChairW3", Vector3(32.35, F42, 12.55), -90.0, "BoardroomTable"],
	["BoardChairW4", Vector3(32.35, F42, 13.65), -90.0, "BoardroomTable"],
	["BoardChairE1", Vector3(34.65, F42, 10.35), 90.0, "BoardroomTable"],
	["BoardChairE2", Vector3(34.65, F42, 11.45), 90.0, "BoardroomTable"],
	["BoardChairE3", Vector3(34.65, F42, 12.55), 90.0, "BoardroomTable"],
	["BoardChairE4", Vector3(34.65, F42, 13.65), 90.0, "BoardroomTable"],
	["BoardChairHead", Vector3(33.5, F42, 9.15), 180.0, "BoardroomTable"],
	# PO-9 (remaining tables). K5 Moor's meeting table: north, west and east (the south side is 0.2 m off the
	# wall); the phone / bracelet / code-note UsePoints stay clear at z 3.05.
	["MoorMeetChairN", Vector3(33.8, F41, 3.55), 180.0, "MoorMeetingTable"],
	["MoorMeetChairW", Vector3(32.75, F41, 4.6), -90.0, "MoorMeetingTable"],
	["MoorMeetChairE", Vector3(34.85, F41, 4.6), 90.0, "MoorMeetingTable"],
	# K24 interview room: the interviewee on the door side, two interviewers across the table (the K24Interview
	# patrol spot inside the door stays clear).
	["InterviewChairN", Vector3(33.0, F41, 20.45), 180.0, "InterviewTable"],
	["InterviewChairS1", Vector3(32.7, F41, 22.55), 0.0, "InterviewTable"],
	["InterviewChairS2", Vector3(33.3, F41, 22.55), 0.0, "InterviewTable"],
	# M11 pantry: west, east and south (the M11Pantry patrol spot and the phone are north; the west seat is
	# outside the PantryDoor clear zone).
	["PantryChairW", Vector3(26.95, F42, 10.3), -90.0, "PantryTable"],
	["PantryChairE", Vector3(29.05, F42, 10.3), 90.0, "PantryTable"],
	["PantryChairS", Vector3(28.0, F42, 11.35), 0.0, "PantryTable"],
	# K4 assistants: behind each desk, back to the window (the phone UsePoint is on the room side).
	["AssistantChairA", Vector3(25.6, F41, 1.2), 180.0, "AssistantDeskA"],
	["AssistantChairB", Vector3(27.6, F41, 1.2), 180.0, "AssistantDeskB"],
	# K8 open office: four seats per 2.4 x 1.6 pod (two desks a side). Pod A's north pair sits 0.3 / 0.1 m east,
	# clear of the K8North patrol spot by the north door.
	["PodAChairN1", Vector3(2.7, F41, 8.75), 180.0, "WorkstationsA"],
	["PodAChairN2", Vector3(3.7, F41, 8.75), 180.0, "WorkstationsA"],
	["PodAChairS1", Vector3(2.4, F41, 11.25), 0.0, "WorkstationsA"],
	["PodAChairS2", Vector3(3.6, F41, 11.25), 0.0, "WorkstationsA"],
	["PodBChairN1", Vector3(6.4, F41, 8.75), 180.0, "WorkstationsB"],
	["PodBChairN2", Vector3(7.6, F41, 8.75), 180.0, "WorkstationsB"],
	["PodBChairS1", Vector3(6.4, F41, 11.25), 0.0, "WorkstationsB"],
	["PodBChairS2", Vector3(7.6, F41, 11.25), 0.0, "WorkstationsB"],
	["PodCChairN1", Vector3(4.4, F41, 12.55), 180.0, "WorkstationsC"],
	["PodCChairN2", Vector3(5.6, F41, 12.55), 180.0, "WorkstationsC"],
	["PodCChairS1", Vector3(4.4, F41, 15.05), 0.0, "WorkstationsC"],
	["PodCChairS2", Vector3(5.6, F41, 15.05), 0.0, "WorkstationsC"],
	# K12 IT: both desks are worked from the north side, facing south. Desk A's seat is rolled
	# to the west end, out of the ITDoor swing; desk B's sits between the desks, east of the K12IT patrol spot,
	# leaving the kc_it / PhoneIT / code-note UsePoints on the south sides clear.
	["ITChairA", Vector3(31.8, F41, 8.2), 180.0, "ITDeskA"],
	["ITChairB", Vector3(33.4, F41, 10.4), 180.0, "ITDeskB"],
	# K20-K23 associates: the desk is 0.65 m off the window, so the seat is on the room side, facing it.
	["K20Chair", Vector3(19.5, F41, 22.0), 180.0, "K20Desk"],
	["K21Chair", Vector3(22.5, F41, 22.0), 180.0, "K21Desk"],
	["K22Chair", Vector3(25.5, F41, 22.0), 180.0, "K22Desk"],
	["K23Chair", Vector3(28.5, F41, 22.0), 180.0, "K23Desk"],
]
## D-130 late-staff work spots (sl_gameplay LATE_STAFF): these layout chairs are D-063 NPC seats (no collider, no
## navmesh obstruction; same art, `Seat` and place), so the seated worker's spawn on them stays on the navmesh.
const NPC_SEAT_CHAIRS: Array[String] = ["AssistantChairA", "PodAChairS1"]
## Logo wall ("K&M", glass teal, landmark 2) on K3's east wall: visual box.
const LOGO_WALL: Array = [23.87, F41 + 1.2, 2.6, 23.9, F41 + 2.6, 4.6]

# --- Spawns, patrols, tactical -----------------------------------------------------------------

## [name, pos, yaw, tags]. Roof spawns first (default crew spawns), then the service level, OOB.
const PLAYER_SPAWNS: Array = [
	["RoofSpawn1", Vector3(2.2, FRF, 15.2), 0.0, ["roof_spawn"]],
	["RoofSpawn2", Vector3(3.4, FRF, 15.2), 0.0, ["roof_spawn"]],
	["RoofSpawn3", Vector3(4.6, FRF, 15.2), 0.0, ["roof_spawn"]],
	["RoofSpawn4", Vector3(5.8, FRF, 15.2), 0.0, ["roof_spawn"]],
	["ServiceSpawn1", Vector3(26.2, F40, 9.0), 90.0, ["preplan_spawn_service"]],
	["ServiceSpawn2", Vector3(27.4, F40, 9.0), 90.0, ["preplan_spawn_service"]],
	["ServiceSpawn3", Vector3(26.2, F40, 10.4), 90.0, ["preplan_spawn_service"]],
	["ServiceSpawn4", Vector3(27.4, F40, 10.4), 90.0, ["preplan_spawn_service"]],
	# D-040: OUT_OF_BOUNDS respawn on the roof (SW, under the insertion line).
	["OobRoof1", Vector3(2.2, FRF, 13.0), 0.0, ["oob_respawn"]],
	["OobRoof2", Vector3(3.4, FRF, 13.0), 0.0, ["oob_respawn"]],
	["OobRoof3", Vector3(4.6, FRF, 13.0), 0.0, ["oob_respawn"]],
]

## Fixed NPC spawns: [name, kind, pos, yaw, tags, idle_activity, patrol graph].
const NPC_SPAWNS: Array = [
	["GuardReception", "GUARD", Vector3(18.0, F41, 3.6), 180.0, ["guard_reception"], "", "Tower"],
	["CameraOperatorSeat", "CAMERA_OPERATOR", Vector3(28.65, F41, 14.5), -90.0, ["security_operator"], "desk_work", ""],
	["CleanerL41A", "CIVILIAN", Vector3(8.8, F41, 15.6), 0.0, ["civ_cleaner_l41", "civ_staff"], "browse", ""],
	# Police (contract only; the heist is stealth-only): P1/P2 below the L40 gates, P3 roof NW
	# (heli rappel), P4 passenger lifts at K3.
	["PoliceStairA", "POLICE", Vector3(13.5, F40 - 1.8, 11.4), 0.0, ["police_stair_a"], "", ""],
	["PoliceStairB", "POLICE", Vector3(22.5, F40 - 1.8, 11.4), 0.0, ["police_stair_b"], "", ""],
	["PoliceRoofRappel", "POLICE", Vector3(3.0, FRF, 6.0), 180.0, ["police_roof"], "", ""],
	["PoliceLifts", "POLICE", Vector3(17.5, F41, 6.9), 0.0, ["police_lifts"], "", ""],
]

## Patrol graph `Tower` (one graph across L40-L42 through the stair landings, doc §Circulation):
## {point: [pos, pause, anim, tags, face yaw or null]}.
const PATROL_POINTS_TOWER: Dictionary = {
	# L41: reception, ring corridors
	"K3Desk": [Vector3(18.0, F41, 3.75), Vector2(30.0, 60.0), "desk", ["guard", "guard_l41"], 180.0],
	"K3West": [Vector3(13.0, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_clean_l41", "staff_partner"], null],
	"K3East": [Vector3(23.0, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_clean_l41", "staff_partner"], null],
	"K3Lifts": [Vector3(18.0, F41, 6.6), Vector2(2.0, 4.0), "idle", ["guard", "guard_l41", "staff", "staff_clean_l41"], null],
	"K3Window": [Vector3(22.2, F41, 1.2), Vector2(5.0, 10.0), "idle", ["staff", "staff_partner"], 0.0],
	"K6West": [Vector3(1.0, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff_clean_l41"], null],
	"K6K1": [Vector3(5.5, F41, 6.75), Vector2(2.0, 4.0), "check_door", ["guard", "guard_l41"], 0.0],
	"K6K2": [Vector3(9.5, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41"], null],
	"K6East": [Vector3(11.25, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_clean_l41"], null],
	"K7West": [Vector3(24.75, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_it", "staff_partner"], null],
	"K7K4": [Vector3(26.5, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_partner"], null],
	"K7K5": [Vector3(30.5, F41, 6.75), Vector2(2.0, 4.0), "check_door", ["guard", "guard_l41", "staff", "staff_partner"], 0.0],
	"K7IT": [Vector3(33.5, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_it"], null],
	"K7East": [Vector3(35.0, F41, 6.75), Vector2.ZERO, "idle", ["guard", "guard_l41"], null],
	"K9North": [Vector3(11.25, F41, 8.4), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff_clean_l41"], null],
	"K9Mid": [Vector3(11.25, F41, 12.0), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff_clean_l41"], null],
	"K9South": [Vector3(11.25, F41, 15.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "guard_stair"], null],
	"K10North": [Vector3(24.75, F41, 8.4), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_it"], null],
	"K10Mid": [Vector3(24.65, F41, 12.0), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_it"], null],
	"K10South": [Vector3(24.75, F41, 15.75), Vector2.ZERO, "idle", ["guard", "guard_l41", "guard_stair"], null],
	"K16West": [Vector3(1.0, F41, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff_clean_l41"], null],
	"K16Archive": [Vector3(3.0, F41, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l41"], null],
	"K16OpenOffice": [Vector3(5.0, F41, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_clean_l41"], null],
	"K16Break": [Vector3(9.0, F41, 17.25), Vector2.ZERO, "idle",
		["guard", "guard_l41", "staff", "staff_clean_l41", "staff_it", "staff_partner"], null],
	"K16StairA": [Vector3(11.25, F41, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l41", "guard_stair", "staff"], null],
	"K16Library": [Vector3(15.0, F41, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff", "staff_clean_l41"], null],
	"K16WC": [Vector3(19.5, F41, 17.25), Vector2.ZERO, "idle",
		["guard", "guard_l41", "staff", "staff_clean_l41", "staff_it", "staff_partner"], null],
	"K16StairB": [Vector3(24.75, F41, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l41", "guard_stair", "staff"], null],
	"K16K23": [Vector3(28.5, F41, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l41"], null],
	"K16Interview": [Vector3(33.0, F41, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l41"], null],
	"K16East": [Vector3(35.0, F41, 17.25), Vector2(2.0, 4.0), "idle", ["guard", "guard_l41"], 90.0],
	# L41 rooms
	"K8North": [Vector3(2.0, F41, 8.6), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff_clean_l41"], null],
	"K8Centre": [Vector3(5.0, F41, 12.0), Vector2(3.0, 6.0), "idle", ["guard", "guard_l41", "staff", "staff_clean_l41"], null],
	"K8East": [Vector3(9.6, F41, 12.0), Vector2.ZERO, "idle", ["guard", "guard_l41", "staff_clean_l41"], null],
	"K17Archive": [Vector3(4.5, F41, 18.7), Vector2(3.0, 6.0), "idle", ["guard", "guard_l41"], null],
	"K18Break": [Vector3(9.0, F41, 20.0), Vector2(10.0, 20.0), "idle",
		["guard", "guard_l41", "staff", "staff_clean_l41", "staff_it", "staff_partner"], null],
	"K19Library": [Vector3(15.0, F41, 19.2), Vector2(3.0, 6.0), "idle", ["guard", "guard_l41"], null],
	"K24Interview": [Vector3(33.0, F41, 19.6), Vector2(3.0, 6.0), "idle", ["guard", "guard_l41"], null],
	"K13Security": [Vector3(27.0, F41, 14.5), Vector2(15.0, 30.0), "idle", ["guard", "guard_l41"], null],
	"K12IT": [Vector3(32.5, F41, 10.1), Vector2(20.0, 40.0), "idle", ["guard", "guard_l41", "staff", "staff_it"], null],
	"K11Rack": [Vector3(26.4, F41, 11.4), Vector2(50.0, 80.0), "idle", ["staff", "staff_it"], null],
	"K5Desk": [Vector3(31.5, F41, 3.6), Vector2(40.0, 70.0), "phone", ["staff", "staff_partner"], null],
	"K4Desk": [Vector3(26.6, F41, 3.3), Vector2(5.0, 10.0), "idle", ["staff", "staff_partner"], null],
	"WCWestL41": [Vector3(16.5, F41, 15.2), Vector2(10.0, 20.0), "idle", ["staff", "staff_clean_l41", "staff_it", "staff_partner"], null],
	"WCMenL41": [Vector3(19.5, F41, 15.2), Vector2(10.0, 20.0), "idle", ["staff", "staff_clean_l41", "staff_it"], null],
	# Stair landings (link the floors)
	"SAL40": [Vector3(13.2, F40, 15.8), Vector2(4.0, 6.0), "check_door", ["guard_stair"], 0.0],
	"SAL41": [Vector3(13.2, F41, 15.8), Vector2.ZERO, "idle", ["guard", "guard_stair"], null],
	"SAL42": [Vector3(13.2, F42, 15.8), Vector2.ZERO, "idle", ["guard", "guard_stair"], null],
	"SARoof": [Vector3(13.2, FRF, 15.8), Vector2(6.0, 6.0), "check_door", ["guard_stair"], 90.0],
	"SBL40": [Vector3(22.0, F40, 15.8), Vector2(4.0, 6.0), "check_door", ["guard_stair"], 0.0],
	"SBL41": [Vector3(22.0, F41, 15.8), Vector2.ZERO, "idle", ["guard", "guard_stair"], null],
	"SBL42": [Vector3(22.0, F42, 15.8), Vector2.ZERO, "idle", ["guard", "guard_stair"], null],
	# L42
	"M2Landing": [Vector3(22.0, F42, 5.5), Vector2(2.0, 4.0), "idle", ["guard", "guard_l42", "staff", "staff_clean_l42"], null],
	"M2Walk": [Vector3(16.0, F42, 5.0), Vector2.ZERO, "idle", ["guard", "guard_l42", "staff_clean_l42"], null],
	"M1Lounge": [Vector3(6.0, F42, 6.4), Vector2(3.0, 6.0), "idle", ["guard", "guard_l42", "staff_clean_l42"], null],
	"M1Bar": [Vector3(2.5, F42, 2.6), Vector2(5.0, 10.0), "idle", ["staff_clean_l42"], null],
	"M9North": [Vector3(11.25, F42, 8.4), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair", "staff_clean_l42"], null],
	"M9Mid": [Vector3(11.25, F42, 12.0), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair"], null],
	"M9South": [Vector3(11.25, F42, 15.75), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair", "staff_clean_l42"], null],
	"M7Door": [Vector3(9.6, F42, 12.0), Vector2(2.0, 4.0), "check_door", ["guard", "guard_l42"], 90.0],
	"M8Dining": [Vector3(5.0, F42, 16.9), Vector2(3.0, 6.0), "idle", ["guard", "guard_l42", "staff_clean_l42"], null],
	"M15West": [Vector3(11.25, F42, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair", "staff_clean_l42"], null],
	"M15SliderW": [Vector3(14.5, F42, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair", "staff_clean_l42"], null],
	"M15WC": [Vector3(19.5, F42, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair", "staff_clean_l42"], null],
	"M15StairB": [Vector3(24.75, F42, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair", "staff_clean_l42"], null],
	"M15SliderE": [Vector3(30.5, F42, 17.25), Vector2(2.0, 4.0), "idle", ["guard", "guard_l42"], 180.0],
	"M15East": [Vector3(35.0, F42, 17.25), Vector2.ZERO, "idle", ["guard", "guard_l42"], null],
	"M10North": [Vector3(24.75, F42, 8.4), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair", "staff_clean_l42"], null],
	"M10Mid": [Vector3(24.75, F42, 12.0), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair", "staff_clean_l42"], null],
	"M10South": [Vector3(24.75, F42, 15.75), Vector2.ZERO, "idle", ["guard", "guard_l42", "guard_stair"], null],
	"M3West": [Vector3(25.4, F42, 4.5), Vector2(8.0, 8.0), "look", ["guard", "guard_l42"], -90.0],
	"M11Pantry": [Vector3(28.0, F42, 8.9), Vector2(10.0, 20.0), "idle", ["guard", "guard_l42", "staff", "staff_clean_l42"], null],
	"M14Boardroom": [Vector3(33.5, F42, 15.2), Vector2(3.0, 6.0), "idle", ["guard", "guard_l42"], null],
	"WCWestL42": [Vector3(16.5, F42, 15.2), Vector2(10.0, 20.0), "idle", ["staff_clean_l42"], null],
	"WCMenL42": [Vector3(19.5, F42, 15.2), Vector2(10.0, 20.0), "idle", ["staff_clean_l42"], null],
}
const PATROL_EDGES_TOWER: Array = [
	# L41 reception and the ring (loop a), the open office (b), IT / partner doors (c)
	["K3Desk", "K3West"], ["K3Desk", "K3East"], ["K3Desk", "K3Lifts"], ["K3West", "K3Lifts"], ["K3Lifts", "K3East"],
	["K3Desk", "K3Window"], ["K3Window", "K3East"],
	["K3West", "K6East"], ["K6East", "K6K2"], ["K6K2", "K6K1"], ["K6K1", "K6West"], ["K6East", "K9North"],
	["K9North", "K9Mid"], ["K9Mid", "K9South"], ["K9South", "K16StairA"], ["K9South", "SAL41"],
	["K3East", "K7West"], ["K7West", "K7K4"], ["K7K4", "K7K5"], ["K7K5", "K7IT"], ["K7IT", "K7East"],
	["K7West", "K10North"], ["K10North", "K10Mid"], ["K10Mid", "K10South"], ["K10South", "K16StairB"], ["K10South", "SBL41"],
	["K16West", "K16Archive"], ["K16Archive", "K16OpenOffice"], ["K16OpenOffice", "K16Break"], ["K16Break", "K16StairA"],
	["K16StairA", "K16Library"], ["K16Library", "K16WC"], ["K16WC", "K16StairB"], ["K16StairB", "K16K23"],
	["K16K23", "K16Interview"], ["K16Interview", "K16East"],
	["K6West", "K8North"], ["K8North", "K8Centre"], ["K8Centre", "K16OpenOffice"], ["K8Centre", "K8East"], ["K8East", "K9Mid"],
	# South spurs (d, e, f)
	["K17Archive", "K16Archive"], ["K18Break", "K16Break"], ["K19Library", "K16Library"], ["K24Interview", "K16Interview"],
	["K13Security", "K10Mid"], ["K12IT", "K7IT"], ["K11Rack", "K10Mid"], ["K5Desk", "K7K5"], ["K4Desk", "K7K4"],
	["WCWestL41", "K16Library"], ["WCWestL41", "K16WC"], ["WCMenL41", "K16WC"],
	# Stairs
	["SAL40", "SAL41"], ["SAL41", "SAL42"], ["SAL42", "SARoof"], ["SBL40", "SBL41"], ["SBL41", "SBL42"],
	# L42 (rover loops a-c, fire watch b)
	["SAL42", "M9South"], ["SBL42", "M10South"], ["M9South", "M9Mid"], ["M9Mid", "M9North"], ["M9North", "M1Lounge"],
	["M1Lounge", "M2Walk"], ["M1Lounge", "M1Bar"], ["M2Walk", "M2Landing"], ["M2Landing", "M3West"], ["M3West", "M10North"],
	["M10North", "M10Mid"], ["M10Mid", "M10South"], ["M10Mid", "M11Pantry"], ["M10North", "M11Pantry"],
	["M9South", "M15West"], ["M15West", "M15SliderW"], ["M15SliderW", "M15WC"], ["M15WC", "M15StairB"],
	["M15StairB", "M15SliderE"], ["M15SliderE", "M15East"], ["M15StairB", "M10South"],
	["M14Boardroom", "M15SliderE"], ["M14Boardroom", "M15East"], ["M8Dining", "M9South"], ["M7Door", "M9Mid"],
	["WCWestL42", "M15SliderW"], ["WCWestL42", "M15WC"], ["WCMenL42", "M15WC"],
]

## Patrol graph `Roof` (roof watch; pause `smoke` under the R3 canopy).
const PATROL_POINTS_ROOF: Dictionary = {
	"RoofHeadHouse": [Vector3(10.8, FRF, 15.75), Vector2(3.0, 6.0), "check_door", ["guard", "guard_roof"], -90.0],
	"RoofWest": [Vector3(10.5, FRF, 10.5), Vector2.ZERO, "idle", ["guard", "guard_roof"], null],
	"RoofNW": [Vector3(6.0, FRF, 5.5), Vector2.ZERO, "idle", ["guard", "guard_roof"], null],
	"RoofNorth": [Vector3(15.0, FRF, 5.5), Vector2.ZERO, "idle", ["guard", "guard_roof"], null],
	"RoofCanopy": [Vector3(19.5, FRF, 6.5), Vector2(20.0, 40.0), "smoke", ["guard", "guard_roof"], null],
	"PadWest": [Vector3(24.6, FRF, 8.0), Vector2(3.0, 6.0), "idle", ["guard", "guard_roof"], -90.0],
	"PadNorth": [Vector3(30.0, FRF, 1.6), Vector2.ZERO, "idle", ["guard", "guard_roof"], null],
	"PadSouth": [Vector3(30.0, FRF, 15.0), Vector2.ZERO, "idle", ["guard", "guard_roof"], null],
	"E2Anchor": [Vector3(33.8, FRF, 16.0), Vector2(3.0, 6.0), "idle", ["guard", "guard_roof"], -90.0],
	"SouthStrip": [Vector3(19.5, FRF, 17.2), Vector2.ZERO, "idle", ["guard", "guard_roof"], null],
	"RoofSW": [Vector3(8.0, FRF, 17.0), Vector2.ZERO, "idle", ["guard", "guard_roof"], null],
	"BMUGarage": [Vector3(8.5, FRF, 4.2), Vector2(3.0, 6.0), "idle", ["guard", "guard_roof"], null],
	"WestLadder": [Vector3(1.2, FRF, 3.6), Vector2(3.0, 6.0), "idle", ["guard", "guard_roof"], 90.0],
}
const PATROL_EDGES_ROOF: Array = [
	["RoofHeadHouse", "RoofWest"], ["RoofWest", "RoofNW"], ["RoofNW", "RoofNorth"], ["RoofNorth", "RoofCanopy"],
	["RoofCanopy", "PadWest"], ["PadWest", "PadNorth"], ["PadWest", "PadSouth"], ["PadNorth", "PadSouth"],
	["PadSouth", "E2Anchor"], ["E2Anchor", "SouthStrip"], ["SouthStrip", "RoofSW"], ["RoofSW", "RoofHeadHouse"],
	["RoofNW", "BMUGarage"], ["BMUGarage", "WestLadder"], ["WestLadder", "RoofNW"], ["RoofWest", "RoofSW"],
]

## Tactical points: [name, kind, pos, yaw, tags, breachable]. ENTRY / RAPPEL for a future loud
## variant (doc §Loud); COVER for the stealth AI.
const TACTICAL: Array = [
	["EntryStairAL41", "ENTRY", Vector3(11.25, F41, 15.75), -90.0, ["stair_door"], false],
	["EntryStairBL41", "ENTRY", Vector3(24.75, F41, 15.75), 90.0, ["stair_door"], false],
	["EntryStairAL42", "ENTRY", Vector3(11.25, F42, 15.75), -90.0, ["stair_door"], false],
	["EntryStairBL42", "ENTRY", Vector3(24.75, F42, 15.75), 90.0, ["stair_door"], false],
	["EntryRoofDoor", "ENTRY", Vector3(10.8, FRF, 15.75), -90.0, ["roof_door"], false],
	["EntryRiserBay", "ENTRY", Vector3(10.8, FRF, 9.0), -90.0, ["riser_door"], false],
	["EntryLiftsK3", "ENTRY", Vector3(17.5, F41, 6.9), 180.0, ["lifts"], false],
	["EntryLiftsM2", "ENTRY", Vector3(17.5, F42, 6.9), 180.0, ["lifts"], false],
	["EntrySliderDining", "ENTRY", Vector3(4.5, F42, 19.0), 0.0, ["terrace_slider"], false],
	["EntrySliderWest", "ENTRY", Vector3(14.5, F42, 19.0), 0.0, ["terrace_slider"], false],
	["EntrySliderEast", "ENTRY", Vector3(30.5, F42, 19.0), 0.0, ["terrace_slider"], false],
	["RappelRoofNW", "RAPPEL", Vector3(3.0, FRF, 6.0), 0.0, ["roof", "p3"], false],
	["CoverReceptionDesk", "COVER", Vector3(18.0, F41, 5.9), 0.0, ["counter"], false],
	["CoverK16StairA", "COVER", Vector3(11.25, F41, 16.9), 0.0, ["door_recess"], false],
	["CoverK16StairB", "COVER", Vector3(24.75, F41, 16.9), 0.0, ["door_recess"], false],
	["CoverK10ServiceLift", "COVER", Vector3(24.5, F41, 9.25), 90.0, ["lift_recess"], false],
	["CoverPlantBlockS", "COVER", Vector3(19.0, FRF, 17.0), 0.0, ["plant_block"], false],
	["CoverBMU", "COVER", Vector3(4.5, FRF, 3.2), 180.0, ["bmu"], false],
]

## Pre-planning points (contracts/preplanning.md, heist_map.md v1.2): [id, category, pos, floor, params].
## Crew-spawn points use the category `spawn` (lead's final ruling).
const PREPLAN_POINTS: Array = [
	["pp_spawn_roof", "spawn", Vector3(4.0, FRF, 15.2), 3, {}],
	["pp_spawn_service", "spawn", Vector3(26.8, F40, 9.7), 0, {"spawn_tag": &"preplan_spawn_service"}],
	["pp_drop_plant", "drop_zone", Vector3(17.0, FRF, 15.4), 3, {}],
	["pp_drop_refuse", "drop_zone", Vector3(27.5, F40, 13.6), 0, {}],
	["pp_escape_heli", "escape", Vector3(28.5, FRF, 9.5), 3, {"variant_group": &"escape", "variant_slot": &"esc_heli"}],
	["pp_escape_line", "escape", Vector3(34.0, FRF, 16.5), 3, {"variant_group": &"escape", "variant_slot": &"esc_line"}],
	["pp_escape_service", "escape", Vector3(22.5, F40, 9.0), 0, {"variant_group": &"escape", "variant_slot": &"esc_service"}],
	["pp_gondola_west", "insider", Vector3(1.0, FRF, 1.8), 3, {"variant_group": &"gondola", "variant_slot": &"gon_west_l41"}],
	["pp_gondola_north", "insider", Vector3(31.95, FRF, 1.0), 3, {"variant_group": &"gondola", "variant_slot": &"gon_north_l42"}],
	["pp_riser_l41", "insider", Vector3(14.2, F41, 9.7), 1, {"variant_group": &"vent_open", "variant_slot": &"vent_l41"}],
	["pp_riser_l42", "insider", Vector3(14.2, F42, 9.7), 2, {"variant_group": &"vent_open", "variant_slot": &"vent_l42"}],
]

## Fixed MapZones: [name, kind, zone_id, boxes]. SECURE_LOOT/ESCAPE live in the `escape` slots.
const ZONES: Array = [
	["PublicServiceLobby", "PUBLIC", "service_lobby", [[24.15, -0.2, 7.65, 29.9, 3.0, 12.4]]],
	["RestrictedService", "RESTRICTED", "service_level", [[24.1, -0.2, 12.55, 29.9, 3.0, 16.4], [21.1, -0.2, 7.6, 23.9, 2.6, 10.4]]],
	["RestrictedL41", "RESTRICTED", "offices", [[0.2, 3.4, 0.2, 35.8, 7.2, 23.8]]],
	["RestrictedVoid", "RESTRICTED", "reception_void", [[12.1, 7.2, 0.2, 20.5, 11.0, 4.0]]],
	["RestrictedL42", "RESTRICTED", "partners_floor", [[0.2, 7.8, 0.2, 35.8, 11.0, 17.8]]],
	["RestrictedTerrace", "RESTRICTED", "terrace", [[0.0, 7.8, 18.2, 36.0, 11.6, 24.0]]],
	["RestrictedRoof", "RESTRICTED", "roof", [[-0.2, 11.4, -0.2, 36.2, 15.5, 18.2]]],
	["RestrictedStairs", "RESTRICTED", "stairs", [[12.15, -2.0, 10.65, 14.85, 3.4, 16.35], [21.15, -2.0, 10.65, 23.85, 3.4, 16.35]]],
	["BodyHideJanitorL41", "BODY_HIDE", "janitor_l41", [[12.2, F41 - 0.2, 9.1, 14.8, F41 + 2.0, 10.3]]],
	["BodyHideLinenL42", "BODY_HIDE", "linen_l42", [[12.2, F42 - 0.2, 9.1, 14.8, F42 + 2.0, 9.8]]],
	["BodyHidePlantAHU", "BODY_HIDE", "plant_ahu", [[15.2, FRF - 0.2, 14.4, 18.7, FRF + 2.0, 16.3]]],
	# D-040: beyond the parapets / balustrade (and under the gondola cradles) is a hard boundary:
	# respawn at `oob_respawn`, never an alarm.
	["OutOfBoundsWest", "OUT_OF_BOUNDS", "oob_west", [[-60.0, -24.0, -60.0, -1.25, 13.0, 84.0]]],
	["OutOfBoundsEast", "OUT_OF_BOUNDS", "oob_east", [[37.25, -24.0, -60.0, 96.0, 13.0, 84.0]]],
	["OutOfBoundsNorth", "OUT_OF_BOUNDS", "oob_north", [[-1.25, -24.0, -60.0, 37.25, 13.0, -1.25]]],
	["OutOfBoundsSouth", "OUT_OF_BOUNDS", "oob_south", [[-1.25, -24.0, 24.75, 37.25, 13.0, 84.0]]],
]

# --- Review cameras ----------------------------------------------------------------------------

## [name, position, look-at target, fov (TopDown*: ortho size), caption].
const REVIEW_CAMERAS: Array = [
	["TopDownSite", Vector3(18.0, 66.0, 12.0), Vector3(18.0, 0.0, 12.0), 110.0,
		"Top-down site: Calder Tower top, Arden Tower (W), Vantage House (E), the skyline"],
	["TopDownTower", Vector3(18.0, 60.0, 12.0), Vector3(18.0, 0.0, 12.0), 44.0,
		"Top-down tower: roof, helipad, plant block, BMU, terrace below the south edge"],
	["ExtNorthCrown", Vector3(18.0, 13.0, -42.0), Vector3(18.0, 7.0, 6.0), 60.0,
		"Exterior: north facade (river side): the double-height reception and feature stair, the crown"],
	["ExtWestArden", Vector3(-16.0, 15.0, -6.0), Vector3(8.0, 9.0, 10.0), 70.0,
		"Exterior: from Arden Tower: west facade, BMU and the west gondola stop, insertion line"],
	["ExtTerraceSE", Vector3(42.0, 13.0, 30.0), Vector3(20.0, 9.0, 18.0), 70.0,
		"Exterior: south-east: terrace, glass balustrade, caged ladder, E2 line to Vantage House"],
	["ReceptionFromLifts", Vector3(18.0, F41 + 1.65, 7.0), Vector3(16.0, F41 + 2.6, 0.5), 80.0,
		"K3 reception (landmark): guard desk, feature stair, the void up to the gallery"],
	["GalleryWalkway", Vector3(12.6, F42 + 1.65, 6.6), Vector3(24.0, F42 + 0.8, 2.5), 80.0,
		"M2 gallery walkway over the void, feature-stair arrival, art-hall doors"],
	["ArtHallLasers", Vector3(24.6, F42 + 1.8, 6.9), Vector3(29.0, F42 + 1.0, 2.0), 80.0,
		"M3 art hall: laser plane at x 26.5, paintings, study door"],
	["StudySafe", Vector3(30.0, F42 + 1.8, 1.0), Vector3(33.0, F42 + 0.6, 7.0), 80.0,
		"M4 study: desk, time-lock safe and its reader, gondola facade door"],
	["ServerCage", Vector3(26.2, F41 + 1.9, 11.8), Vector3(29.0, F41 + 0.8, 9.0), 80.0,
		"K11 server room: the cage, ledger rack, hack terminal, drive sleds"],
	["SecurityRoom", Vector3(26.2, F41 + 1.8, 15.8), Vector3(29.5, F41 + 0.8, 14.0), 80.0,
		"K13 security room: the operator faces the monitor wall, the door behind him"],
	["SouthSpine", Vector3(0.5, F41 + 1.6, 17.25), Vector3(36.0, F41 + 1.2, 17.25), 60.0, "K16 south spine: the 36 m sightline"],
	["TerraceWest", Vector3(1.5, F42 + 1.7, 21.0), Vector3(34.0, F42 + 1.0, 20.0), 70.0,
		"X1 terrace: sliders, C12 bay, outdoor kitchen, the SE caged ladder"],
	["RoofPlantBlock", Vector3(4.0, FRF + 1.8, 16.8), Vector3(22.0, FRF + 1.0, 10.0), 75.0,
		"Roof spawn (SW): the plant block, head-house and riser-bay doors"],
	["Helipad", Vector3(18.0, FRF + 3.4, 2.0), Vector3(30.0, FRF, 9.0), 75.0, "Roof: helipad (E1) and the E2 anchor"],
	["StairACore", Vector3(13.8, F41 + 1.7, 15.8), Vector3(13.0, F41 + 1.4, 11.0), 80.0, "Stair A at L41 (U-stair, 0.3 m core walls)"],
	["ServiceLobby", Vector3(29.3, F40 + 1.7, 11.8), Vector3(22.5, F40 + 1.0, 9.0), 75.0,
		"L40 service lobby (PUBLIC): service lift car (E3), service spawn"],
	# G2 (SL-1): the remaining main rooms
	["KesslerOffice", Vector3(6.3, F41 + 1.65, 5.4), Vector3(1.5, F41 + 1.0, 1.0), 80.0,
		"K1 Victor Kessler's office: walnut desk, credenza, bookcase, the west facade access door"],
	["OpenOffice", Vector3(9.8, F41 + 1.7, 16.0), Vector3(1.0, F41 + 0.8, 8.5), 80.0,
		"K8 associates' open plan: three bench pods, C11"],
	["BreakRoom", Vector3(6.6, F41 + 1.65, 18.6), Vector3(11.0, F41 + 0.9, 23.3), 80.0, "K18 break room"],
	["LawLibrary", Vector3(17.4, F41 + 1.65, 18.6), Vector3(12.5, F41 + 1.0, 23.0), 80.0, "K19 law library: the stacks"],
	["Lounge", Vector3(11.3, F42 + 1.65, 7.0), Vector3(1.0, F42 + 1.0, 1.0), 80.0,
		"M1 partners' lounge: the backlit teal bar (kc_lounge), sofas, the baby grand"],
	["GuestSuite", Vector3(6.0, F42 + 1.65, 12.5), Vector3(0.5, F42 + 0.6, 8.5), 80.0, "M5 guest suite (kc_guest nightstand)"],
	["Dining", Vector3(10.0, F42 + 1.65, 17.5), Vector3(1.0, F42 + 0.8, 13.5), 80.0, "M8 private dining, the terrace slider"],
	["Boardroom", Vector3(31.5, F42 + 1.65, 16.0), Vector3(35.0, F42 + 0.8, 8.0), 80.0,
		"M14 boardroom: the table for twelve, the credenza (lap_boardroom)"],
]
