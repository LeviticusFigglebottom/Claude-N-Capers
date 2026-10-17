## Gallery Night NPC data and tactical points (GN-C1 G1 step 2; the G1 key lights gave way to the G2 fixtures, gn_dress.gd).
## Owner: ENV C.
## Chain: gn_builder_base <- gn_gameplay <- gn_content <- gn_npc <- build_greybox.
## Design: gallery_night.md Circulation + roster (spawn tags B1), Loud (police entries, perches, anchors).
## Patrol graphs (heist_map.md §4): `halberd` (guards, every floor, linked through Stair SS and the staff door; >= 3
## loops through each guard post's start point), `mews` (the dock smoker), `gala` (patrons: tag civilian; cower
## points tag cower) and `staff` (curator, attendants, waitstaff, conservator, PA: tag staff + the role tag).
## Calm exits (QC-51, HeistMission.civilians_leave(exit_tag); G1 step 2d): `ExitPortico` (tags exit, exit_guests) on
## the portico kerb west of the limo, the guests' way out at last call; `ExitDock` (exit_staff) in the Mews outside the
## LD personnel door, the waitstaff's at last call + 120 s (Circulation). Neither carries civilian / staff, so nobody
## wanders to them.
## NPC visuals resolve by spawn tag (NpcVisualTweak.tag_characters, ENV A; B1 map) and fall back to the role's.
extends "res://world/heists/gallery_night/greybox/gn_content.gd"

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
## Patrol points per graph: name -> [position, pause (s, Vector2), pause anim, tags, facing yaw or null].
const HALBERD: Dictionary = {
	"HallFoot": [Vector3(22.0, 0.0, 17.0), Vector2(30, 60), "look", ["guard", "guard_ground"], 180.0],
	"HallSW": [Vector3(17.0, 0.0, 22.5), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"HallSE": [Vector3(27.0, 0.0, 22.5), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"HallNW": [Vector3(20.2, 0.0, 11.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"Vestibule": [Vector3(22.0, 0.0, 28.0), Vector2(4, 8), "look", ["guard", "guard_ground"], 0.0],
	"Cloakroom": [Vector3(13.0, 0.0, 27.3), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"WG1": [Vector3(8.0, 0.0, 13.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"WG2": [Vector3(5.0, 0.0, 17.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"DC1": [Vector3(3.5, 0.0, 25.0), Vector2(4, 8), "look", ["guard", "guard_ground"], 180.0],
	"EG1": [Vector3(38.0, 0.0, 17.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"EB1": [Vector3(38.0, 0.0, 27.0), Vector2(4, 8), "look", ["guard", "guard_ground"], 0.0],
	"SSG": [Vector3(1.5, 0.0, 7.1), Vector2.ZERO, "idle", ["guard"], null],
	"BC1": [Vector3(7.5, 0.0, 7.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"BC2": [Vector3(13.0, 0.0, 7.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"BC3": [Vector3(22.5, 0.0, 7.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"BC4": [Vector3(31.0, 0.0, 7.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"BreakRoom": [Vector3(6.5, 0.0, 3.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"SecurityCoffee": [Vector3(15.0, 0.0, 4.8), Vector2(15, 25), "idle", ["guard", "guard_ground"], 0.0],
	"Registrar": [Vector3(21.5, 0.0, 4.8), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"LD1": [Vector3(37.0, 0.0, 4.0), Vector2.ZERO, "idle", ["guard", "guard_ground"], null],
	"LD2": [Vector3(35.5, 0.0, 8.5), Vector2(4, 8), "look", ["guard", "guard_ground"], 180.0],
	"SSU": [Vector3(1.5, 5.4, 7.1), Vector2.ZERO, "idle", ["guard"], null],
	"UC1": [Vector3(7.5, 5.4, 7.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"UC2": [Vector3(11.0, 5.4, 7.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"UC3": [Vector3(22.5, 5.4, 7.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"UC4": [Vector3(27.5, 5.4, 7.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"BW1": [Vector3(13.5, 5.4, 10.5), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"BW2": [Vector3(13.5, 5.4, 22.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"BE1": [Vector3(30.5, 5.4, 11.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"BE2": [Vector3(30.5, 5.4, 22.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"UG1a": [Vector3(9.0, 5.4, 11.0), Vector2(6, 10), "look", ["guard", "guard_upper"], 90.0],
	"UG1b": [Vector3(3.0, 5.4, 18.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"UG2a": [Vector3(6.0, 5.4, 25.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"SL1": [Vector3(22.0, 5.4, 28.0), Vector2(4, 8), "look", ["guard", "guard_upper"], 0.0],
	"AT1": [Vector3(34.5, 5.4, 26.0), Vector2(8, 15), "idle", ["guard", "guard_upper"], null],
	"UG3a": [Vector3(35.0, 5.4, 18.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"UG3b": [Vector3(40.5, 5.4, 22.0), Vector2(6, 6), "look", ["guard", "guard_upper"], 180.0],
	"CS1": [Vector3(37.5, 5.4, 4.0), Vector2.ZERO, "idle", ["guard", "guard_upper"], null],
	"SSB": [Vector3(1.5, -4.2, 7.1), Vector2.ZERO, "idle", ["guard"], null],
	"BB1": [Vector3(7.5, -4.2, 7.0), Vector2.ZERO, "idle", ["guard", "guard_basement"], null],
	"BB2": [Vector3(13.0, -4.2, 7.0), Vector2.ZERO, "idle", ["guard", "guard_basement"], null],
	"BBVault": [Vector3(19.5, -4.2, 7.0), Vector2(8, 8), "look", ["guard", "guard_basement"], 180.0],
	"BB3": [Vector3(25.5, -4.2, 7.0), Vector2.ZERO, "idle", ["guard", "guard_basement"], null],
	"BB4": [Vector3(31.0, -4.2, 7.0), Vector2.ZERO, "idle", ["guard", "guard_basement"], null],
	"PL1": [Vector3(6.5, -4.2, 11.0), Vector2.ZERO, "idle", ["guard", "guard_basement"], null],
	"PL2": [Vector3(2.0, -4.2, 16.0), Vector2(6, 10), "look", ["guard", "guard_basement"], -90.0],
	"LK1": [Vector3(8.0, -4.2, 3.0), Vector2.ZERO, "idle", ["guard", "guard_basement"], null],
	"FR1": [Vector3(13.0, -4.2, 3.5), Vector2.ZERO, "idle", ["guard", "guard_basement"], null],
	"QR1": [Vector3(26.0, -4.2, 3.0), Vector2.ZERO, "idle", ["guard", "guard_basement"], null],
}
const HALBERD_EDGES: Array = [
	["HallFoot", "HallSW"], ["HallFoot", "HallSE"], ["HallSW", "HallSE"], ["HallSW", "Vestibule"], ["HallSE", "Vestibule"],
	["Vestibule", "Cloakroom"], ["Cloakroom", "HallSW"], ["HallFoot", "HallNW"], ["HallNW", "HallSW"], ["HallFoot", "WG1"],
	["WG1", "WG2"], ["WG2", "DC1"], ["DC1", "WG1"], ["WG1", "HallNW"], ["HallFoot", "EG1"], ["EG1", "EB1"], ["EB1", "HallSE"],
	["EG1", "HallSE"],
	["SSG", "BC1"], ["BC1", "BC2"], ["BC2", "BC3"], ["BC3", "BC4"], ["BC1", "BreakRoom"], ["BreakRoom", "BC2"],
	["BC2", "SecurityCoffee"], ["SecurityCoffee", "BC3"], ["BC3", "Registrar"], ["Registrar", "BC4"], ["BC1", "WG1"],
	["BC3", "HallNW"], ["BC4", "LD1"], ["LD1", "LD2"], ["LD2", "BC4"], ["LD1", "BC3"], ["LD2", "BC3"],
	["SSG", "SSU"], ["SSG", "SSB"],
	["SSU", "UC1"], ["UC1", "UC2"], ["UC2", "UC3"], ["UC3", "UC4"], ["UC1", "BW1"], ["UC2", "BW1"], ["BW1", "BW2"],
	["BW1", "UG1a"], ["UG1a", "UG1b"], ["UG1b", "UG2a"], ["UG2a", "SL1"], ["SL1", "AT1"], ["AT1", "UG3b"], ["UG3b", "UG3a"],
	["UG3a", "BE2"], ["BE2", "BE1"], ["BE1", "UC4"], ["BE1", "UC3"], ["UC4", "CS1"], ["CS1", "UC3"], ["BW2", "BE2"],
	["SSB", "BB1"], ["BB1", "BB2"], ["BB2", "BBVault"], ["BBVault", "BB3"], ["BB3", "BB4"], ["BB1", "PL1"], ["BB2", "PL1"],
	["PL1", "PL2"], ["BB1", "LK1"], ["BB2", "LK1"], ["BB1", "FR1"], ["BB2", "FR1"], ["QR1", "BB3"], ["QR1", "BBVault"],
	["QR1", "BB4"],
]
## The Mews points carry `guard` (the route tag a guard walks, as Court / Rounds) and the beat tag `guard_mews`.
const MEWS: Dictionary = {
	"MewsDoor": [Vector3(42.5, 0.0, -1.5), Vector2(20, 40), "smoke", ["guard", "guard_mews"], 180.0],
	"MewsBins": [Vector3(29.7, 0.0, -2.4), Vector2.ZERO, "idle", ["guard", "guard_mews"], null],
	"MewsLadder": [Vector3(11.5, 0.0, -2.0), Vector2(4, 8), "look", ["guard", "guard_mews"], 180.0],
	"MewsVan": [Vector3(36.5, 0.0, -6.8), Vector2.ZERO, "idle", ["guard", "guard_mews"], null],
	"MewsMouth": [Vector3(47.0, 0.0, -4.0), Vector2(20, 40), "smoke", ["guard", "guard_mews"], 90.0],
	"MewsLD": [Vector3(41.0, 0.0, 3.0), Vector2(6, 10), "look", ["guard", "guard_mews"], 0.0],
}
const MEWS_EDGES: Array = [
	["MewsDoor", "MewsBins"], ["MewsBins", "MewsLadder"], ["MewsLadder", "MewsVan"], ["MewsVan", "MewsMouth"],
	["MewsMouth", "MewsDoor"], ["MewsDoor", "MewsLD"], ["MewsLD", "MewsBins"], ["MewsVan", "MewsDoor"],
]
## D-140 (GUARDS lever): `court` = the `rover_court` beat, the Sculpture Court (X3) behind the West Gallery: the north
## bronzes, the areaway grate (watched from the south, 2 m off the light well, facing the grate and the French doors),
## the court gate and the west benches; >= 1.2 m off the bronzes, heaters, pool rim, the patrons' smoking spots and
## every UsePoint / door. `rounds` = the `sec_empty` roundsman: with the security room unstaffed the console officer
## walks the closed upper west wing (UG1 Calloway partition, the BW balcony, UG2 Sallow, the SL loggia), off the
## Halberd upper points (>= 2 m) and the partition screens. One guard on each graph (no shared-post loop rule).
const COURT: Dictionary = {
	"CourtNE": [Vector3(-3.0, 0.0, 8.0), Vector2.ZERO, "idle", ["guard"], null],
	"CourtGrate": [Vector3(-5.0, 0.0, 17.0), Vector2(6, 10), "look", ["guard"], 0.0],
	"CourtGate": [Vector3(-8.0, 0.0, 26.5), Vector2(4, 8), "look", ["guard"], 180.0],
	"CourtWest": [Vector3(-14.0, 0.0, 13.0), Vector2.ZERO, "idle", ["guard"], null],
}
const COURT_EDGES: Array = [
	["CourtNE", "CourtGrate"], ["CourtGrate", "CourtGate"], ["CourtGate", "CourtWest"], ["CourtWest", "CourtNE"],
]
const ROUNDS: Dictionary = {
	"RndUG1": [Vector3(9.0, 5.4, 17.5), Vector2(6, 10), "look", ["guard"], 90.0],
	"RndBW": [Vector3(13.5, 5.4, 16.5), Vector2(4, 8), "look", ["guard"], -90.0],
	"RndUG2": [Vector3(9.0, 5.4, 23.0), Vector2(6, 10), "look", ["guard"], 90.0],
	"RndSL": [Vector3(17.0, 5.4, 28.5), Vector2(4, 8), "look", ["guard"], 0.0],
}
const ROUNDS_EDGES: Array = [
	["RndUG1", "RndBW"], ["RndBW", "RndUG2"], ["RndUG2", "RndSL"], ["RndSL", "RndUG1"], ["RndUG1", "RndUG2"],
]
const GALA: Dictionary = {
	"GalaHallW": [Vector3(19.5, 0.0, 20.0), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaHallE": [Vector3(25.0, 0.0, 19.5), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaHallSE": [Vector3(24.0, 0.0, 24.5), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaHallSW": [Vector3(18.0, 0.0, 24.5), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaWG": [Vector3(8.0, 0.0, 16.5), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaWG2": [Vector3(6.5, 0.0, 11.5), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaEG": [Vector3(36.0, 0.0, 19.0), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaEB": [Vector3(35.0, 0.0, 27.5), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaEB2": [Vector3(41.0, 0.0, 27.0), Vector2(10, 30), "browse", ["civilian"], null],
	"GalaVE": [Vector3(24.5, 0.0, 28.0), Vector2(5, 10), "browse", ["civilian"], null],
	"GalaCourt1": [Vector3(-8.0, 0.0, 10.0), Vector2(20, 40), "smoke", ["civilian", "civilian_court"], null],
	"GalaCourt2": [Vector3(-13.5, 0.0, 22.0), Vector2(20, 40), "smoke", ["civilian", "civilian_court"], null],
	"CowerGH1": [Vector3(17.0, 0.0, 8.31), Vector2.ZERO, "idle", ["cower"], 180.0],
	"CowerGH2": [Vector3(22.0, 0.0, 8.31), Vector2.ZERO, "idle", ["cower"], 180.0],
	"CowerWG": [Vector3(11.69, 0.0, 18.5), Vector2.ZERO, "idle", ["cower"], 90.0],
	"CowerEG": [Vector3(32.31, 0.0, 22.0), Vector2.ZERO, "idle", ["cower"], -90.0],
	"ExitPortico": [Vector3(18.0, 0.0, 34.5), Vector2.ZERO, "idle", ["exit", "exit_guests"], 180.0],
}
const GALA_EDGES: Array = [
	["GalaHallW", "GalaHallE"], ["GalaHallE", "GalaHallSE"], ["GalaHallSE", "GalaHallSW"], ["GalaHallSW", "GalaHallW"],
	["GalaHallW", "GalaWG"], ["GalaWG", "GalaWG2"], ["GalaWG2", "GalaHallW"], ["GalaHallE", "GalaEG"], ["GalaEG", "GalaEB"],
	["GalaEB", "GalaEB2"], ["GalaEB2", "GalaEG"], ["GalaHallSE", "GalaVE"], ["GalaVE", "GalaHallSW"], ["GalaWG2", "GalaCourt1"],
	["GalaCourt1", "GalaCourt2"], ["GalaCourt2", "GalaVE"], ["CowerGH1", "GalaHallW"], ["CowerGH1", "CowerGH2"],
	["CowerGH2", "GalaHallE"], ["CowerWG", "GalaWG"], ["CowerWG", "GalaHallW"], ["CowerEG", "GalaEG"], ["CowerEG", "GalaHallE"],
	["GalaVE", "ExitPortico"],
]
const STAFF: Dictionary = {
	"StaffBar": [Vector3(13.7, 0.0, 18.6), Vector2(10, 30), "browse", ["staff", "staff_bar"], -90.0],
	"StaffTable": [Vector3(20.0, 0.0, 21.0), Vector2(5, 10), "browse", ["staff", "staff_bar"], null],
	"StaffWG": [Vector3(2.0, 0.0, 12.0), Vector2(10, 20), "curator_inspect", ["staff", "staff_attendant", "staff_curator"], -90.0],
	"StaffEG": [Vector3(42.0, 0.0, 16.0), Vector2(10, 20), "curator_inspect", ["staff", "staff_attendant", "staff_curator"], 90.0],
	"StaffBC": [Vector3(9.0, 0.0, 7.0), Vector2.ZERO, "idle", ["staff"], null],
	"StaffBR": [Vector3(5.0, 0.0, 4.5), Vector2(10, 20), "browse", ["staff", "staff_bar"], null],
	"CowerBR": [Vector3(8.69, 0.0, 4.0), Vector2.ZERO, "idle", ["cower"], 90.0],
	"StaffSSG": [Vector3(1.5, 0.0, 7.1), Vector2.ZERO, "idle", ["staff"], null],
	"StaffSSU": [Vector3(1.5, 5.4, 7.1), Vector2.ZERO, "idle", ["staff"], null],
	"StaffUC": [Vector3(9.0, 5.4, 7.0), Vector2.ZERO, "idle", ["staff"], null],
	"StaffCO": [Vector3(7.5, 5.4, 3.8), Vector2(15, 30), "desk_work", ["staff", "staff_curator"], null],
	"StaffUG1": [Vector3(2.0, 5.4, 10.5), Vector2(10, 20), "curator_inspect", ["staff", "staff_curator"], -90.0],
	"StaffCS": [Vector3(35.0, 5.4, 9.5), Vector2(15, 30), "desk_work", ["staff", "staff_cs", "staff_curator"], null],
	"StaffAT": [Vector3(34.8, 5.4, 29.2), Vector2(15, 30), "browse", ["staff", "staff_attendant"], null],
	"CowerAT": [Vector3(35.69, 5.4, 29.0), Vector2.ZERO, "idle", ["cower"], 90.0],
	"StaffAO": [Vector3(12.0, 5.4, 3.5), Vector2(15, 30), "desk_work", ["staff", "staff_admin"], null],
	"ExitDock": [Vector3(41.5, 0.0, -3.0), Vector2.ZERO, "idle", ["exit_staff"], 0.0],
}
const STAFF_EDGES: Array = [
	["StaffBar", "StaffTable"], ["StaffTable", "StaffWG"], ["StaffWG", "StaffBar"], ["StaffTable", "StaffEG"],
	["StaffWG", "StaffBC"], ["StaffBC", "StaffBR"], ["StaffBR", "CowerBR"], ["CowerBR", "StaffBC"], ["StaffBC", "StaffSSG"],
	["StaffSSG", "StaffSSU"], ["StaffSSU", "StaffUC"], ["StaffUC", "StaffCO"], ["StaffUC", "StaffUG1"], ["StaffUC", "StaffCS"],
	["StaffUC", "StaffAT"], ["StaffAT", "CowerAT"], ["StaffUC", "StaffAO"], ["StaffCO", "StaffUG1"],
	["StaffBC", "ExitDock"],
]
## Fixed spawns (roster): [name, kind, position, yaw, tags, idle, graph].
const FIXED_SPAWNS: Array = [
	["GuardHall", "GUARD", Vector3(22.0, 0.0, 17.0), 180.0, ["guard_hall"], "look", "Halberd"],
	["AttendantStair", "CIVILIAN", Vector3(19.5, 0.0, 16.0), 180.0, ["civ_attendant"], "browse", ""],
	["AttendantEG", "CIVILIAN", Vector3(39.0, 0.0, 15.0), 90.0, ["civ_attendant"], "browse", ""],
	["WaitstaffBar", "CIVILIAN", Vector3(13.7, 0.0, 18.6), -90.0, ["civ_waitstaff"], "browse", ""],
	["WaitstaffHall", "CIVILIAN", Vector3(24.0, 0.0, 21.0), 0.0, ["civ_waitstaff"], "walk_text", ""],
	["PatronHallW", "CIVILIAN", Vector3(19.5, 0.0, 20.5), 90.0, ["civ_patron"], "browse", ""],
	["PatronHallE", "CIVILIAN", Vector3(25.5, 0.0, 20.0), -90.0, ["civ_patron"], "browse", ""],
	["PatronWG", "CIVILIAN", Vector3(7.0, 0.0, 14.0), 90.0, ["civ_patron"], "browse", ""],
	["PatronEG", "CIVILIAN", Vector3(37.0, 0.0, 20.5), -90.0, ["civ_patron"], "browse", ""],
	["PatronCourt", "CIVILIAN", Vector3(-8.0, 0.0, 12.0), 90.0, ["civ_patron", "civilian_court"], "smoke", ""],
	# GN-C2 (doc roster: GH x4, WG x2, EG x2, EB x2, court x2 = 12). The mission keeps the first `patrons` (3/5/7/9)
	# civ_patron spawns in this order (thin_civilians), so the 6th-9th spread over EB, the bar, WG and EG; the last
	# three (EB donor wall, GH east, the court) only stand in with stragglers' logic or a larger roll. Each browses an
	# artwork or the bar from >= 1 m, off every UsePoint, door clear zone and patrol point.
	["PatronEB1", "CIVILIAN", Vector3(42.5, 0.0, 26.1), 0.0, ["civ_patron"], "browse", ""],  # StudyEB1
	["PatronHallBar", "CIVILIAN", Vector3(16.6, 0.0, 20.1), 90.0, ["civ_patron"], "browse", ""],  # the gala bar
	["PatronWG2", "CIVILIAN", Vector3(7.75, 0.0, 18.0), 180.0, ["civ_patron"], "browse", ""],  # StudyWG1 / WG2
	["PatronEG2", "CIVILIAN", Vector3(42.0, 0.0, 14.1), 0.0, ["civ_patron"], "browse", ""],  # StudyEG2
	["PatronEB2", "CIVILIAN", Vector3(34.4, 0.0, 26.8), 90.0, ["civ_patron"], "browse", ""],  # the donor wall
	["PatronHallE2", "CIVILIAN", Vector3(27.5, 0.0, 15.0), 45.0, ["civ_patron"], "browse", ""],  # up at the landing
	["PatronCourt2", "CIVILIAN", Vector3(-10.0, 0.0, 12.0), -90.0, ["civ_patron", "civilian_court"], "smoke", ""],
	# Rare-event timed spawns (QC-25 hook, HeistRuntime.SCRIPTED_SPAWN_TAG): not spawned at load; at LD.
	["InspectorA", "GUARD", Vector3(40.5, 0.0, 6.0), 180.0, ["scripted", "guard_inspection"], "", "Halberd"],
	["InspectorB", "GUARD", Vector3(42.0, 0.0, 6.0), 180.0, ["scripted", "guard_inspection"], "", "Halberd"],
	# Doc §Rare events (insurance_inspection): the two inspectors come with 2 Halberd escorts (extra guards, pagers).
	["InspectorEscortA", "GUARD", Vector3(39.0, 0.0, 6.0), 180.0, ["scripted", "guard_inspection_escort"], "", "Halberd"],
	["InspectorEscortB", "GUARD", Vector3(43.0, 0.0, 7.5), 180.0, ["scripted", "guard_inspection_escort"], "", "Halberd"],
	["VaultlineA", "GUARD", Vector3(40.5, 0.0, 9.5), 180.0, ["scripted", "guard_vaultline"], "", "Halberd"],
	["VaultlineB", "GUARD", Vector3(42.0, 0.0, 9.5), 180.0, ["scripted", "guard_vaultline"], "", "Halberd"],
]
## Slot NPCs: slot id -> [name, kind, position, yaw, tags, idle, graph, seat asset (optional), desk it faces
## (optional, Props/MapBuilt)]. PO6-06: a seated
## (desk_work) NPC spawns on the `Seat` of its own catalog NPC seat (prop_chair_task: no collider / nav obstruction,
## D-063) placed in the slot at the spawn transform, pulled up to its desk (the greybox desks are 0.75 m, front -Z).
const SLOT_NPCS: Dictionary = {
	"rover_ground": ["GuardRoverGround", "GUARD", Vector3(10.0, 0.0, 7.0), -90.0, ["guard_rover_ground"], "", "Halberd"],
	"rover_upper": ["GuardRoverUpper", "GUARD", Vector3(10.0, 5.4, 7.0), -90.0, ["guard_rover_upper"], "", "Halberd"],
	"rover_basement": ["GuardRoverBasement", "GUARD", Vector3(10.0, -4.2, 7.0), -90.0, ["guard_rover_basement"], "",
		"Halberd"],
	"dock_smoker": ["GuardDockSmoker", "GUARD", Vector3(43.5, 0.0, -2.5), 90.0, ["guard_mews"], "smoke", "Mews"],
	# D-140: the court rover (exterior beat, the mews pool's look) and the sec_empty roundsman (the operator's look:
	# the same officer, at the console or on his rounds), each on its own graph.
	"rover_court": ["GuardRoverCourt", "GUARD", Vector3(-3.5, 0.0, 6.0), 180.0, ["guard_mews", "guard_court"], "",
		"Court"],
	"sec_empty": ["GuardRounds", "GUARD", Vector3(9.0, 5.4, 19.0), 180.0, ["guard_operator", "guard_rounds"], "",
		"Rounds"],
	# standing (teller) at BenchCS (0.9 m), 0.28 m off its north edge (z 9.65), clear of the kc_conservator UsePoint
	"cons_late": ["Conservator", "CIVILIAN", Vector3(39.55, 5.4, 9.37), 180.0, ["civ_conservator"], "teller", ""],
	"curator_hall": ["Curator", "CIVILIAN", Vector3(17.5, 0.0, 15.5), -90.0, ["civ_curator"], "curator_inspect", ""],
	"curator_office": ["Curator", "CIVILIAN", Vector3(6.0, 5.4, 1.3), 180.0, ["civ_curator"], "desk_work", "",
		"prop_chair_task", "DeskCO"],
	"pa_late": ["AdminPA", "CIVILIAN", Vector3(14.0, 5.4, 3.3), 180.0, ["civ_admin"], "desk_work", "",
		"prop_chair_task", "DeskAO"],
	# D-130 gala_extra (Tense+): a cloakroom attendant (event staff, leaves with the waitstaff) standing behind the CK
	# counter's west half, 1.05 m off the till's UsePoint, facing the room; a room attendant posted in the Drawings
	# Cabinet at the south vitrine (curator_inspect, as the attendants' gallery checks), off DC1 and the studies.
	"gx_cloakroom": ["CloakroomAttendant", "CIVILIAN", Vector3(14.45, 0.0, 29.4), 0.0, ["civ_waitstaff"], "teller", ""],
	"gx_drawings": ["AttendantDC", "CIVILIAN", Vector3(3.2, 0.0, 28.45), 180.0, ["civ_attendant"], "curator_inspect", ""],
}
## TacticalPoints (doc Loud: police entries, perches, anchors, flanks): [name, kind, position, yaw, tags, breachable].
const TACTICAL: Array = [
	["EntryBronzeDoors", "ENTRY", Vector3(20.5, 0.0, 31.2), 0.0, ["door", "south", "breach_only"], true],
	["EntryGiftShop", "ENTRY", Vector3(28.0, 0.0, 25.0), 180.0, ["door", "south", "breach_only"], true],
	["EntryEBWindow1", "ENTRY", Vector3(34.0, 0.0, 31.0), 0.0, ["window", "south", "breach_only"], true],
	["EntryEBWindow2", "ENTRY", Vector3(38.0, 0.0, 31.0), 0.0, ["window", "south", "breach_only"], true],
	["EntryEBWindow3", "ENTRY", Vector3(42.0, 0.0, 31.0), 0.0, ["window", "south", "breach_only"], true],
	["EntryCourtDoors", "ENTRY", Vector3(-1.0, 0.0, 12.5), -90.0, ["door", "west", "breach_only"], true],
	["EntryCourtGate", "ENTRY", Vector3(-8.0, 0.0, 31.0), 0.0, ["gate", "west", "breach_only"], true],
	["EntryDockRoller", "ENTRY", Vector3(36.5, 0.0, -1.2), 180.0, ["roller", "north", "breach_only"], true],
	["EntryDockPersonnel", "ENTRY", Vector3(41.0, 0.0, -1.0), 180.0, ["door", "north", "breach_only"], true],
	["EntryHeadHouse", "ENTRY", Vector3(4.0, 9.0, 7.0), 90.0, ["door", "roof", "breach_only"], true],
	["RappelOculus", "RAPPEL", Vector3(22.0, 11.0, 17.0), 0.0, ["oculus", "roof", "breach_only"], true],
	["EntryOculus", "ENTRY", Vector3(22.0, 11.0, 17.0), 0.0, ["skylight", "roof", "breach_only"], true],
	["FlankAreaway", "FLANK", Vector3(-4.5, 0.0, 14.0), 90.0, ["areaway", "vent", "phantom"], false],
	["FlankMewsLadder", "FLANK", Vector3(10.0, 0.0, -1.2), 180.0, ["ladder", "north"], false],
	["AnchorPortico", "SHIELD_ANCHOR", Vector3(22.0, 0.0, 32.0), 0.0, ["portico"], false],
	["AnchorVestibule", "SHIELD_ANCHOR", Vector3(22.0, 0.0, 25.0), 0.0, ["vestibule"], false],
	["AnchorMewsRoller", "SHIELD_ANCHOR", Vector3(32.0, 0.0, -2.0), 180.0, ["mews"], false],
	["AnchorBackCorridor", "SHIELD_ANCHOR", Vector3(30.0, 0.0, 7.0), -90.0, ["back_corridor"], false],
	["SniperHotel", "SNIPER_PERCH", Vector3(62.0, 22.0, 12.0), 90.0, ["hotel_terrace", "s1"], false],
	["SniperConservatory", "SNIPER_PERCH", Vector3(-24.0, 14.0, 4.0), -90.0, ["ostrander_roof", "s2"], false],
	["CoverBar", "COVER", Vector3(15.6, 0.0, 18.6), -90.0, ["bar", "h1"], false],
	["CoverHalfLandingW", "COVER", Vector3(17.5, 2.7, 9.5), 180.0, ["balustrade", "h1"], false],
	["CoverHalfLandingE", "COVER", Vector3(26.5, 2.7, 9.5), 180.0, ["balustrade", "h1"], false],
	["CoverUC", "COVER", Vector3(20.0, 5.4, 7.0), 90.0, ["door_recess", "h2"], false],
	["CoverBB", "COVER", Vector3(16.0, -4.2, 7.0), 90.0, ["door_recess", "h3"], false],
	["CoverLD", "COVER", Vector3(40.0, 0.0, 7.0), 0.0, ["crates", "h4"], false],
	# GN-C2 (doc Loud COVER ~50): beside real cover geometry, on the navmesh, -Z facing away from the cover (as
	# CoverBar). Vehicle cover (the E1 van, the E2 limo) lives in the escape slots (gn_content ESCAPE_COVER).
	# Great Hall: the bar ends, the stair foot (central balustrades), the arch / opening jambs (both sides).
	["CoverBarN", "COVER", Vector3(14.8, 0.0, 17.1), 0.0, ["bar", "h1"], false],
	["CoverBarS", "COVER", Vector3(14.8, 0.0, 20.1), 180.0, ["bar", "h1"], false],
	["CoverStairFootW", "COVER", Vector3(20.3, 0.0, 14.0), 90.0, ["balustrade", "h1"], false],
	["CoverStairFootE", "COVER", Vector3(23.7, 0.0, 14.0), -90.0, ["balustrade", "h1"], false],
	["CoverVEArchW", "COVER", Vector3(19.6, 0.0, 25.45), 0.0, ["jamb", "h1"], false],
	["CoverVEArchE", "COVER", Vector3(24.4, 0.0, 25.45), 0.0, ["jamb", "h1"], false],
	["CoverWGArchHallN", "COVER", Vector3(12.55, 0.0, 11.4), -90.0, ["jamb", "h1"], false],
	["CoverWGArchHallS", "COVER", Vector3(12.55, 0.0, 16.6), -90.0, ["jamb", "h1"], false],
	["CoverWGArchWGN", "COVER", Vector3(11.45, 0.0, 11.4), 90.0, ["jamb", "h1"], false],
	["CoverWGArchWGS", "COVER", Vector3(11.45, 0.0, 16.6), 90.0, ["jamb", "h1"], false],
	["CoverEGArchHallN", "COVER", Vector3(31.45, 0.0, 15.4), 90.0, ["jamb", "h1"], false],
	["CoverEGArchHallS", "COVER", Vector3(31.45, 0.0, 20.6), 90.0, ["jamb", "h1"], false],
	["CoverEGArchEGN", "COVER", Vector3(32.55, 0.0, 15.4), -90.0, ["jamb", "h4"], false],
	["CoverEGArchEGS", "COVER", Vector3(32.55, 0.0, 20.6), -90.0, ["jamb", "h4"], false],
	["CoverEBOpeningEGW", "COVER", Vector3(35.4, 0.0, 23.45), 0.0, ["jamb", "h4"], false],
	["CoverEBOpeningEGE", "COVER", Vector3(40.6, 0.0, 23.45), 0.0, ["jamb", "h4"], false],
	["CoverEBOpeningEBW", "COVER", Vector3(35.4, 0.0, 24.55), 180.0, ["jamb", "h4"], false],
	["CoverEBOpeningEBE", "COVER", Vector3(40.6, 0.0, 24.55), 180.0, ["jamb", "h4"], false],
	# The cloakroom and gift-shop counters (staff side).
	["CoverCloakroomCounter", "COVER", Vector3(14.0, 0.0, 29.4), 180.0, ["counter", "h1"], false],
	["CoverGiftShopCounter", "COVER", Vector3(30.8, 0.0, 28.0), -90.0, ["counter", "h1"], false],
	# The Mews bins (north face and ends).
	["CoverMewsBinsWN", "COVER", Vector3(28.6, 0.0, -1.85), 0.0, ["bins", "h4"], false],
	["CoverMewsBinsEN", "COVER", Vector3(30.8, 0.0, -1.85), 0.0, ["bins", "h4"], false],
	["CoverMewsBinsW", "COVER", Vector3(27.1, 0.0, -0.8), 90.0, ["bins", "h4"], false],
	["CoverMewsBinsE", "COVER", Vector3(32.3, 0.0, -0.8), -90.0, ["bins", "h4"], false],
	# Basement: the AS painting screens (aisles, off the rack studies' UsePoints), the FR crates, the PL AHU + crates.
	["CoverRacksW", "COVER", Vector3(16.0, -4.2, 16.0), 0.0, ["rack", "h3"], false],
	["CoverRacksE", "COVER", Vector3(28.0, -4.2, 16.0), 0.0, ["rack", "h3"], false],
	["CoverRacksMid", "COVER", Vector3(21.5, -4.2, 14.0), 180.0, ["rack", "h3"], false],
	["CoverRacksEMid", "COVER", Vector3(27.5, -4.2, 14.0), 180.0, ["rack", "h3"], false],
	["CoverFRCrates", "COVER", Vector3(17.75, -4.2, 1.6), 180.0, ["crates", "h3"], false],
	["CoverPLAHU", "COVER", Vector3(10.2, -4.2, 14.0), 90.0, ["ahu", "h3"], false],
	["CoverPLCrates", "COVER", Vector3(10.4, -4.2, 16.75), 90.0, ["crates", "h3"], false],
	# Upper: the balcony balustrades (BW / BE / SL), the UG1 / UG3 partition screens, the CS bench.
	["CoverBWN", "COVER", Vector3(14.5, 5.4, 11.0), 90.0, ["balustrade", "h2"], false],
	["CoverBWMid", "COVER", Vector3(14.5, 5.4, 20.0), 90.0, ["balustrade", "h2"], false],
	["CoverBWS", "COVER", Vector3(14.5, 5.4, 24.0), 90.0, ["balustrade", "h2"], false],
	["CoverBEN", "COVER", Vector3(29.5, 5.4, 11.0), -90.0, ["balustrade", "h2"], false],
	["CoverBEMid", "COVER", Vector3(29.5, 5.4, 20.0), -90.0, ["balustrade", "h2"], false],
	["CoverBES", "COVER", Vector3(29.5, 5.4, 24.0), -90.0, ["balustrade", "h2"], false],
	["CoverSLW", "COVER", Vector3(18.0, 5.4, 26.5), 180.0, ["balustrade", "h2"], false],
	["CoverSLMid", "COVER", Vector3(22.0, 5.4, 26.5), 180.0, ["balustrade", "h2"], false],
	["CoverSLE", "COVER", Vector3(26.0, 5.4, 26.5), 180.0, ["balustrade", "h2"], false],
	["CoverScreenUG1E", "COVER", Vector3(6.55, 5.4, 14.0), -90.0, ["screen", "h2"], false],
	["CoverScreenUG1W", "COVER", Vector3(5.45, 5.4, 14.0), 90.0, ["screen", "h2"], false],
	["CoverScreenUG3W", "COVER", Vector3(37.45, 5.4, 15.5), 90.0, ["screen", "h2"], false],
	["CoverScreenUG3E", "COVER", Vector3(38.55, 5.4, 15.5), -90.0, ["screen", "h2"], false],
	["CoverBenchCS", "COVER", Vector3(40.0, 5.4, 10.85), 180.0, ["bench", "h2"], false],
]
# --- NPC spawns ----------------------------------------------------------------------------------

## [chair, desk name] pending `faces` links (link_seats).
var _seat_links: Array = []


func build_npcs() -> void:
	_graph("Halberd", &"halberd", 1, HALBERD, HALBERD_EDGES)
	_graph("Mews", &"mews", 1, MEWS, MEWS_EDGES)
	_graph("Court", &"court", 1, COURT, COURT_EDGES)
	_graph("Rounds", &"rounds", 2, ROUNDS, ROUNDS_EDGES)
	_graph("Gala", &"gala", 1, GALA, GALA_EDGES)
	_graph("Staff", &"staff", 1, STAFF, STAFF_EDGES)
	for s: Array in FIXED_SPAWNS:
		_npc(n("Spawns"), s)


func npc_slot(vs: VariantSlot, _group: String, slot_id: String, _at: Vector3, _yaw: float) -> bool:
	if SLOT_NPCS.has(slot_id):
		_npc(vs, SLOT_NPCS[slot_id])
		return true
	return slot_id in ["cons_gone", "pa_none", "xl_none"]


func _npc(parent: Node3D, s: Array) -> void:
	spawn_at(parent, String(s[0]), String(s[1]), s[2] as Vector3, float(s[3]), s[4], String(s[5]), String(s[6]))
	if s.size() > 7:  # PO6-06: the NPC's seat, its `Seat` marker right under the spawn
		var chair: Node3D = catalog_prop(parent, String(s[7]), String(s[0]) + "Chair", s[2] as Vector3, float(s[3]), true)
		if s.size() > 8 and chair != null:  # the desk it faces (Props/MapBuilt, linked once built: link_seats)
			_seat_links.append([chair, String(s[8])])


## The slot seats' `faces` links to their map-built desks (levelcheck orientation).
func link_seats() -> void:
	for l: Array in _seat_links:
		var desk: Node = n("Props/MapBuilt").get_node_or_null(String(l[1]))
		if desk == null:
			errors.append("seat %s: no desk Props/MapBuilt/%s" % [(l[0] as Node).name, String(l[1])])
			continue
		(l[0] as Node).set_meta(&"faces", (l[0] as Node).get_path_to(desk))


func _graph(nm: String, gid: StringName, floor_idx: int, points: Dictionary, edges: Array) -> void:
	var g: PatrolGraph = PatrolGraph.new()
	g.name = nm
	g.graph_id = gid
	g.floor_index = floor_idx
	add(n("Patrols"), g)
	for pn: Variant in points:
		var row: Array = points[pn]
		var p: PatrolPoint = PatrolPoint.new()
		p.name = String(pn)
		p.position = row[0] as Vector3
		p.pause_range = row[1] as Vector2
		p.pause_anim = StringName(String(row[2]))
		p.tags = _names(row[3])
		if row[4] != null:
			p.basis = yaw_basis(float(row[4]))
			p.face_marker_forward = true
		add(g, p)
	var links: Dictionary = {}
	for e: Array in edges:
		for pair: Array in [[e[0], e[1]], [e[1], e[0]]]:
			if not points.has(pair[0]) or not points.has(pair[1]):
				errors.append("patrol edge %s-%s: unknown point" % [pair[0], pair[1]])
				continue
			if not links.has(pair[0]):
				links[pair[0]] = []
			if not (links[pair[0]] as Array).has(pair[1]):
				(links[pair[0]] as Array).append(pair[1])
	for pn2: Variant in points:
		var pp: PatrolPoint = g.get_node(String(pn2)) as PatrolPoint
		var paths: Array[NodePath] = []
		for other: Variant in links.get(pn2, []):
			paths.append(pp.get_path_to(g.get_node(String(other))))
		pp.links = paths


func build_tactical(tac: Node3D) -> void:
	for t: Array in TACTICAL:
		tactical_point(tac, t)
