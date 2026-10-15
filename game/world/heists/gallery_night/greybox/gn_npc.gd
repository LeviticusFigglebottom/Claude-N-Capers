## Gallery Night NPC data, tactical points and greybox lights (GN-C1 G1 step 2). Owner: ENV C.
## Chain: gn_builder_base <- gn_gameplay <- gn_content <- gn_npc <- build_greybox.
## Design: gallery_night.md Circulation + roster (spawn tags B1), Loud (police entries, perches, anchors), B1 lights.
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
const MEWS: Dictionary = {
	"MewsDoor": [Vector3(42.5, 0.0, -1.5), Vector2(20, 40), "smoke", ["guard_mews"], 180.0],
	"MewsBins": [Vector3(29.7, 0.0, -2.4), Vector2.ZERO, "idle", ["guard_mews"], null],
	"MewsLadder": [Vector3(11.5, 0.0, -2.0), Vector2(4, 8), "look", ["guard_mews"], 180.0],
	"MewsVan": [Vector3(36.5, 0.0, -6.8), Vector2.ZERO, "idle", ["guard_mews"], null],
	"MewsMouth": [Vector3(47.0, 0.0, -4.0), Vector2(20, 40), "smoke", ["guard_mews"], 90.0],
	"MewsLD": [Vector3(41.0, 0.0, 3.0), Vector2(6, 10), "look", ["guard_mews"], 0.0],
}
const MEWS_EDGES: Array = [
	["MewsDoor", "MewsBins"], ["MewsBins", "MewsLadder"], ["MewsLadder", "MewsVan"], ["MewsVan", "MewsMouth"],
	["MewsMouth", "MewsDoor"], ["MewsDoor", "MewsLD"], ["MewsLD", "MewsBins"], ["MewsVan", "MewsDoor"],
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
	# Rare-event timed spawns (QC-25 hook, HeistRuntime.SCRIPTED_SPAWN_TAG): not spawned at load; at LD.
	["InspectorA", "GUARD", Vector3(40.5, 0.0, 6.0), 180.0, ["scripted", "guard_inspection"], "", "Halberd"],
	["InspectorB", "GUARD", Vector3(42.0, 0.0, 6.0), 180.0, ["scripted", "guard_inspection"], "", "Halberd"],
	["VaultlineA", "GUARD", Vector3(40.5, 0.0, 9.5), 180.0, ["scripted", "guard_vaultline"], "", "Halberd"],
	["VaultlineB", "GUARD", Vector3(42.0, 0.0, 9.5), 180.0, ["scripted", "guard_vaultline"], "", "Halberd"],
]
## Slot NPCs: slot id -> [name, kind, position, yaw, tags, idle, graph, seat asset (optional)]. PO6-06: a seated
## (desk_work) NPC spawns on the `Seat` of its own catalog NPC seat (prop_chair_task: no collider / nav obstruction,
## D-063) placed in the slot at the spawn transform, pulled up to its desk (the greybox desks are 0.75 m, front -Z).
const SLOT_NPCS: Dictionary = {
	"rover_ground": ["GuardRoverGround", "GUARD", Vector3(10.0, 0.0, 7.0), -90.0, ["guard_rover_ground"], "", "Halberd"],
	"rover_upper": ["GuardRoverUpper", "GUARD", Vector3(10.0, 5.4, 7.0), -90.0, ["guard_rover_upper"], "", "Halberd"],
	"rover_basement": ["GuardRoverBasement", "GUARD", Vector3(10.0, -4.2, 7.0), -90.0, ["guard_rover_basement"], "",
		"Halberd"],
	"dock_smoker": ["GuardDockSmoker", "GUARD", Vector3(43.5, 0.0, -2.5), 90.0, ["guard_mews"], "smoke", "Mews"],
	# standing (teller) at BenchCS (0.9 m), 0.28 m off its north edge (z 9.65), clear of the kc_conservator UsePoint
	"cons_late": ["Conservator", "CIVILIAN", Vector3(39.55, 5.4, 9.37), 180.0, ["civ_conservator"], "teller", ""],
	"curator_hall": ["Curator", "CIVILIAN", Vector3(17.5, 0.0, 15.5), -90.0, ["civ_curator"], "curator_inspect", ""],
	"curator_office": ["Curator", "CIVILIAN", Vector3(6.0, 5.4, 1.3), 180.0, ["civ_curator"], "desk_work", "",
		"prop_chair_task"],  # at DeskCO
	"pa_late": ["AdminPA", "CIVILIAN", Vector3(14.0, 5.4, 3.3), 180.0, ["civ_admin"], "desk_work", "",
		"prop_chair_task"],  # at DeskAO
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
]
## Rooms without a greybox key light (shafts; exterior / roof are not key-light rooms).
const UNLIT_ROOMS: Array[String] = ["SS", "LF", "HH", "LM"]
## Exterior key lights at grade (street / wall lamps, 4.5 m up; fixtures are the G2 art pass): [name, x, z]. The Mews
## (spawn + E1 escape) every ~20 m from the gate to the LD roller and up Wexley St, the reflecting pool and the court
## gate, the portico pair either side of the bronze doors, the Parade at the police islands. pd2_fidelity §7.11: the
## viewmodel reads in ADS fights outside, so they carry viewmodel_lit like the interior keys.
const EXT_LAMPS: Array = [
	["LampMewsW", -30.0, -4.0], ["LampMewsGate", -10.0, -4.0], ["LampMewsMid", 10.0, -4.0],
	["LampMewsDock", 30.0, -4.0], ["LampMewsCorner", 47.0, -3.0], ["LampWexleyN", 51.0, -16.0],
	["LampWexleyS", 51.0, 14.0], ["LampPool", -3.0, 18.0], ["LampCourtN", -8.0, 5.0], ["LampCourtS", -8.0, 27.0],
	["LampPorticoW", 18.0, 34.5], ["LampPorticoE", 26.0, 34.5], ["LampParadeW", -30.0, 46.0],
	["LampParadeMid", 4.0, 46.0], ["LampParadeE", 52.0, 46.0],
]
const EXT_LAMP_Y: float = 4.5
const EXT_LAMP_COLOR: Color = Color(1.0, 0.86, 0.66)


# --- NPC spawns ----------------------------------------------------------------------------------

func build_npcs() -> void:
	_graph("Halberd", &"halberd", 1, HALBERD, HALBERD_EDGES)
	_graph("Mews", &"mews", 1, MEWS, MEWS_EDGES)
	_graph("Gala", &"gala", 1, GALA, GALA_EDGES)
	_graph("Staff", &"staff", 1, STAFF, STAFF_EDGES)
	for s: Array in FIXED_SPAWNS:
		_npc(n("Spawns"), s)


func npc_slot(vs: VariantSlot, _group: String, slot_id: String, _at: Vector3, _yaw: float) -> bool:
	if SLOT_NPCS.has(slot_id):
		_npc(vs, SLOT_NPCS[slot_id])
		return true
	return slot_id in ["rover_none", "sec_empty", "cons_gone", "pa_none", "xl_none"]


func _npc(parent: Node3D, s: Array) -> void:
	spawn_at(parent, String(s[0]), String(s[1]), s[2] as Vector3, float(s[3]), s[4], String(s[5]), String(s[6]))
	if s.size() > 7:  # PO6-06: the NPC's seat, its `Seat` marker right under the spawn
		catalog_prop(parent, String(s[7]), String(s[0]) + "Chair", s[2] as Vector3, float(s[3]))


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
		var tp: TacticalPoint = TacticalPoint.new()
		tp.name = String(t[0])
		tp.kind = TacticalPoint.Kind[String(t[1])]
		tp.position = t[2] as Vector3
		tp.basis = yaw_basis(float(t[3]))
		tp.tags = _names(t[4])
		tp.breachable = bool(t[5])
		add(tac, tp)


# --- Greybox lights (B1: key lights carry viewmodel_lit; the art pass is G2) -----------------------

## One key OmniLight3D per interior room (layers 1 | viewmodel_lit), centred in its first plan rect, 0.4 m under
## its ceiling (the Great Hall: the chandelier height 6 m; open-top rooms 4 m); its range reaches the room's far
## floor corners (the floor read black past ~0.8 x the long side). Then the exterior lamps (EXT_LAMPS).
func build_lights(lit: Node3D) -> void:
	var done: Dictionary = {}
	for r: Array in L.ROOMS:
		var rid: String = String(r[1])
		var f: String = String(r[0])
		if done.has(f + rid) or rid in UNLIT_ROOMS or String(r[2]) == "exterior":
			continue
		done[f + rid] = true
		var ceil: float = float(r[7]) if float(r[7]) > 0.0 else 4.4
		var h: float = 6.0 if rid == "GH" else minf(ceil, 5.0) - 0.4
		var w: float = float(r[5]) - float(r[3])
		var d: float = float(r[6]) - float(r[4])
		var corner: float = Vector3(w * 0.5, h, d * 0.5).length() * 1.1
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Key%s%s" % [f, rid]
		light.position = Vector3((float(r[3]) + float(r[5])) * 0.5, float(L.FFL[f]) + h, (float(r[4]) + float(r[6])) * 0.5)
		light.omni_range = clampf(maxf(maxf(w, d) * 0.8, corner), 4.0, 16.0)
		light.light_energy = 1.0
		light.shadow_enabled = false
		light.layers = 1 | VIEWMODEL_LIT_LAYER
		light.set_meta(&"key_light", true)
		add(lit, light)
	var ext: Node3D = add(lit, node3d("Exterior")) as Node3D
	for e: Array in EXT_LAMPS:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = String(e[0])
		lamp.position = Vector3(float(e[1]), EXT_LAMP_Y, float(e[2]))
		lamp.light_color = EXT_LAMP_COLOR
		lamp.light_energy = 1.5
		lamp.omni_range = 16.0
		lamp.omni_attenuation = 0.7
		lamp.shadow_enabled = false
		lamp.layers = 1 | VIEWMODEL_LIT_LAYER
		lamp.set_meta(&"key_light", true)
		add(ext, lamp)
