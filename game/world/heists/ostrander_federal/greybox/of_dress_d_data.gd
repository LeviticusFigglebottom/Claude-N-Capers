## Ostrander Federal G2 dressing D (OF-C2 vault / ops lane, ENV C): the working vault VT (caged shelving, cash skids,
## gold, a bullion cart and scale, bond boxes, signs) and the lived-in ops rooms (VO, CP, OF: workstation chairs and
## monitors, a team table, files, notice boards, a whiteboard, a wall safe, strap bins). Read by of_dress_d.gd.
## Room layout (doc Basement / Gallery notes; lane C keep-outs of_dress_data ROOM_KEEPOUT, lane B of_art_rooms): the
## loot spawns (VaultCash 24, 20.5; VaultGold 32, 19), the cage gates' swings, the hoist and its hole, the door ->
## hoist / cage routes and the box walls' fronts (1.2 m) stay clear; >= 60 % of the vault floor stays open.
extends RefCounted

## Wall faces the wall rows snap to: id -> [axis of the face plane ("x": plane x = c, "z": plane z = c), c, the normal
## into the room (+1 / -1 along that axis)].
const FACES: Dictionary = {
	"VT_N": ["z", 13.3, 1.0], "VT_W": ["x", 14.3, 1.0], "VT_E": ["x", 33.7, -1.0],
	"CASH_W": ["x", 22.55, 1.0], "CASH_E": ["x", 25.45, -1.0], "CASH_WOUT": ["x", 22.45, -1.0],
	"GOLD_N": ["z", 17.05, 1.0],
	"VO_N": ["z", 9.1, 1.0], "VO_S": ["z", 17.9, -1.0], "VO_W": ["x", 42.1, 1.0], "VO_E": ["x", 47.8, -1.0],
	"CP_N": ["z", 0.2, 1.0], "CP_S": ["z", 6.9, -1.0], "CP_E": ["x", 25.9, -1.0],
	"OF_N": ["z", 9.1, 1.0], "OF_S": ["z", 16.9, -1.0], "OF_W": ["x", 8.1, 1.0],
}

const FB: float = -4.0
const FM: float = 5.0

## Wall rows: [room, name, asset, face, along (m on the face), y (floor items: the floor; wall-mount: the centre)].
const WALL: Array = [
	# VT: caged shelving inside both cages, the signs
	["VT", "CageShelfCashW", "prop_of_cage_shelving", "CASH_W", 21.4, FB],
	["VT", "CageShelfCashE", "prop_of_cage_shelving", "CASH_E", 21.4, FB],
	["VT", "CageShelfGold", "prop_of_cage_shelving", "GOLD_N", 30.9, FB],
	["VT", "SignBullion", "prop_of_vault_sign_bullion", "VT_E", 20.4, FB + 2.3],
	["VT", "SignCashCage", "prop_of_vault_sign_cash", "CASH_WOUT", 20.0, FB + 2.3],
	["VT", "SignStaff", "prop_of_vault_sign_staff", "VT_N", 32.4, FB + 2.3],
	["VT", "SignBonds", "prop_of_vault_sign_bonds", "VT_W", 20.5, FB + 2.3],
	# VO: the vault schedule office
	["VO", "WhiteboardVO", "prop_whiteboard", "VO_W", 10.8, FM + 1.62],
	["VO", "NoticeBoardVO", "prop_of_notice_board", "VO_E", 12.9, FM + 1.5],
	["VO", "KeySafeVO", "prop_safe_wall", "VO_E", 15.0, FM + 1.0],
	# CP: the count room
	["CP", "StrapBinsCP", "prop_of_strap_bins", "CP_S", 17.6, FB],
	["CP", "NoticeBoardCP", "prop_of_notice_board", "CP_E", 4.6, FB + 1.6],
	["CP", "CageShelfCP", "prop_of_cage_shelving", "CP_S", 23.7, FB],
	["CP", "ClockCP", "prop_clock_harbor", "CP_N", 20.6, FB + 2.35],
	# OF: operations
	["OF", "FileCabinetOF2", "prop_file_cabinet", "OF_S", 9.0, FM],
	["OF", "FileCabinetOF3", "prop_file_cabinet", "OF_S", 9.5, FM],
	["OF", "FileCabinetOF4", "prop_file_cabinet", "OF_S", 10.0, FM],
	["OF", "FileCabinetOF5", "prop_file_cabinet", "OF_S", 10.5, FM],
	["OF", "NoticeBoardOF", "prop_of_notice_board", "OF_S", 14.5, FM + 1.5],
	["OF", "WhiteboardOF", "prop_whiteboard", "OF_W", 15.4, FM + 1.62],
	["OF", "PrinterOF2", "prop_printer_mfp", "OF_S", 26.6, FM],
	["OF", "ClockOF", "prop_clock_harbor", "OF_N", 20.0, FM + 2.2],
]

## Free rows: [room, name, asset, [x, y, z] (floor / host top), yaw (deg; 0 faces north -Z, 180 south, 90 west, -90 east)].
const FREE: Array = [
	# VT: the cages' stock, the counting table's tools, the west half's skids and trolleys, the bullion carts
	["VT", "CashSkidCage", "prop_of_cash_skid", [24.0, FB, 22.05], 0.0],
	["VT", "GoldSkidCage", "prop_of_gold_skid", [32.6, FB, 20.4], 0.0],
	["VT", "ScaleTable", "prop_of_bullion_scale", [18.5, FB + 0.744, 18.65], 90.0],
	["VT", "GoldBarsTable", "prop_of_gold_bars", [18.48, FB + 0.744, 19.05], 0.0],
	["VT", "BondBoxesTable", "prop_of_bond_boxes", [18.5, FB + 0.744, 19.4], 90.0],
	["VT", "StrapBinsVT", "prop_of_strap_bins", [20.25, FB, 19.0], 90.0],
	["VT", "CashSkidW", "prop_of_cash_skid", [19.6, FB, 22.6], 0.0],
	["VT", "GoldSkidW", "prop_of_gold_skid", [20.6, FB, 22.6], 0.0],
	["VT", "BullionCartW", "prop_of_bullion_cart", [17.6, FB, 15.3], 90.0],
	["VT", "CashTrolleyW", "prop_cash_trolley", [17.6, FB, 16.9], 90.0],
	["VT", "BullionCartE", "prop_of_bullion_cart", [30.0, FB, 22.3], 0.0],
	# VO: a schedule table for two, bond boxes and papers on it
	["VO", "OpsTableVO", "prop_vault_table", [43.6, FM, 15.0], 0.0],
	["VO", "ChairVOTableS", "prop_chair_visitor", [43.6, FM, 15.75], 0.0],
	["VO", "ChairVOTableN", "prop_chair_visitor", [43.6, FM, 14.25], 180.0],
	["VO", "BondBoxesVO", "prop_of_bond_boxes", [43.3, FM + 0.744, 15.0], 0.0],
	# CP: bond boxes on the desk, a cash skid by the strap bins
	["CP", "BondBoxesCP", "prop_of_bond_boxes", [20.25, FB + 0.744, 0.55], 180.0],
	["CP", "CashSkidCP", "prop_of_cash_skid", [18.2, FB, 5.3], 0.0],
	# OF: a chair at every workstation, the missing monitors, a team table in the south half
	["OF", "ChairWS1NW", "prop_chair_office", [17.2, FM, 10.2], 180.0],
	["OF", "ChairWS1NE", "prop_chair_office", [18.8, FM, 10.2], 180.0],
	["OF", "ChairWS1SW", "prop_chair_office", [17.2, FM, 12.8], 0.0],
	["OF", "ChairWS1SE", "prop_chair_office", [18.8, FM, 12.8], 0.0],
	["OF", "ChairWS2NW", "prop_chair_office", [22.7, FM, 10.2], 180.0],
	["OF", "ChairWS2NE", "prop_chair_office", [24.3, FM, 10.2], 180.0],
	["OF", "ChairWS2SW", "prop_chair_office", [22.7, FM, 12.8], 0.0],
	["OF", "ChairWS2SE", "prop_chair_office", [24.3, FM, 12.8], 0.0],
	["OF", "MonitorWS1NE", "prop_monitor", [18.8, FM + 0.75, 11.4], 0.0],
	["OF", "MonitorWS1SE", "prop_monitor", [18.8, FM + 0.75, 11.7], 180.0],
	["OF", "MonitorWS2NW", "prop_monitor", [23.1, FM + 0.75, 11.4], 0.0],
	["OF", "MonitorWS2NE", "prop_monitor", [24.3, FM + 0.75, 11.42], 0.0],
	["OF", "TeamTableW", "prop_vault_table", [22.4, FM, 15.0], 0.0],
	["OF", "TeamTableE", "prop_vault_table", [23.6, FM, 15.0], 0.0],
	["OF", "ChairTeamNW", "prop_chair_visitor", [22.4, FM, 14.2], 180.0],
	["OF", "ChairTeamNE", "prop_chair_visitor", [23.6, FM, 14.2], 180.0],
	["OF", "ChairTeamSW", "prop_chair_visitor", [22.4, FM, 15.8], 0.0],
	["OF", "ChairTeamSE", "prop_chair_visitor", [23.6, FM, 15.8], 0.0],
	["OF", "BindersTeam", "prop_binders", [23.9, FM + 0.744, 14.95], 0.0],
]

## Rooms whose chairs get `faces` links here (lane B's / the variant officers' chairs in the vault and ops rooms).
const FACES_ROOMS: Array[String] = ["SD", "VO", "PC", "OF", "VT", "CP"]
## Floor stencils (visual, 3 mm proud): hatched keep-clear bands [x0, z0, x1, z1] in front of the cage gates.
const HATCH: Array = [[23.0, 16.6, 25.0, 17.3], [28.2, 18.0, 28.85, 20.0]]
const HATCH_Y: float = FB + 0.003
const HATCH_STRIPE: float = 0.12
