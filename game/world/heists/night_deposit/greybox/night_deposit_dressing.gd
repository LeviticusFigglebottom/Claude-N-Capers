## Night Deposit G2 dressing data (C2, ENV C): KitPlacer anchors, kit rooms, keep-outs, seeds, the
## directly placed exterior props, site dressing and light tweaks. Read by nd_dress.gd.
## Coordinates as night_deposit_layout.gd (metres, plan origin = NW building corner, +z south).
## Floor props: pos = bottom-centre, back 12 mm off the wall face (interior walls 0.1 m and
## exterior walls 0.2 m from the wall line, vault walls 0.3 m). Wall mounts: pos = the centre of the
## item on the wall face. Ceiling mounts: pos = the ceiling point. Yaw: the prop's front (-Z) faces
## 0 north (-z), 180 south (+z), -90 east (+x), 90 west (-x).
extends RefCounted

const BASE: float = -4.0
const BASE_CEIL: float = -0.8
const ROAD_Y: float = -0.15
## Teller counter: 6 stations of 17/6 m between the wall stubs (x 2.0-19.0), centre z 9.7 (the bandit
## glass on the wall line z 10.0 stands on its marble top, 1.05 m).
const COUNTER_Z: float = 9.7
const COUNTER_W: float = 17.0 / 6.0
## Deposit-box wall units (1.8 m, 0.45 m deep) on both vault side walls: unit centres along z; the
## saw points sit on the doors at `SAW_Y` (D-057). West face x 9.3, east face x 18.7.
const BOX_UNITS_Z: Array[float] = [12.0, 13.83, 15.66, 17.49]
const BOX_FRONT_W: float = 9.3 + 0.012 + 0.45
const BOX_FRONT_E: float = 18.7 - 0.012 - 0.45
const SAW_Y: float = 1.25

## [room, name, catalog asset, pos, yaw_deg, metas]. Metas: `faces_anchor` (another anchor of the
## room), `faces_node` (a map path, e.g. the camera station), any other key is set as a node meta.
const ANCHORS: Array = [
	# G1 sally port: two cash trolleys on the west wall (the roller bay and lift landing stay clear)
	["G1", "CashTrolleyA", "prop_cash_trolley", Vector3(0.562, 0.0, 3.2), -90.0, {}],
	["G1", "CashTrolleyB", "prop_cash_trolley", Vector3(0.562, 0.0, 4.35), -90.0, {}],
	# G3 security: the operator's NPC seat at the camera station (D-063: seat 0.47 / desk 0.74), the key
	# credenza (kc_security) with the key cabinet over it on the east wall
	["G3", "OperatorChair", "prop_chair_task", Vector3(11.3, 0.0, 2.5), 90.0, {"faces_node": "Gameplay/Misc/CameraStation"}],
	["G3", "KeyCredenza", "prop_credenza", Vector3(13.653, 0.0, 3.6), 90.0, {}],
	["G3", "KeyCabinet", "prop_key_cabinet", Vector3(13.9, 1.55, 3.6), 90.0, {}],
	# G4 break room: kitchen run on the north wall (code_break_board note on the counter), lockers on the
	# east wall carry kc_break_locker
	["G4", "KitchenCounter", "prop_kitchen_counter", Vector3(15.32, 0.0, 0.537), 180.0, {}],
	["G4", "Fridge", "prop_fridge", Vector3(16.882, 0.0, 0.582), 180.0, {}],
	["G4", "BreakLockers", "prop_lockers", Vector3(17.628, 0.0, 3.0), 90.0, {"support": true}],
	["G4", "Microwave", "prop_microwave", Vector3(16.25, 0.9, 0.43), 180.0, {}],
	# G5 electrical: main switchboard + alarm panel (north wall), telecom / UPS cabinet
	["G5", "BreakerMain", "prop_breaker_panel", Vector3(19.1, 1.45, 0.2), 180.0, {}],
	["G5", "BreakerAlarm", "prop_breaker_panel", Vector3(20.1, 1.45, 0.2), 180.0, {}],
	["G5", "Telecom", "prop_ups_cabinet", Vector3(20.488, 0.0, 2.7), 90.0, {}],
	# G8 teller workroom: the 6-station transaction counter (front = the staff side, north)
	["G8", "TellerCounter1", "prop_counter_teller", Vector3(2.0 + COUNTER_W * 0.5, 0.0, COUNTER_Z), 0.0, {}],
	["G8", "TellerCounter2", "prop_counter_teller", Vector3(2.0 + COUNTER_W * 1.5, 0.0, COUNTER_Z), 0.0, {}],
	["G8", "TellerCounter3", "prop_counter_teller", Vector3(2.0 + COUNTER_W * 2.5, 0.0, COUNTER_Z), 0.0, {}],
	["G8", "TellerCounter4", "prop_counter_teller", Vector3(2.0 + COUNTER_W * 3.5, 0.0, COUNTER_Z), 0.0, {}],
	["G8", "TellerCounter5", "prop_counter_teller", Vector3(2.0 + COUNTER_W * 4.5, 0.0, COUNTER_Z), 0.0, {}],
	["G8", "TellerCounter6", "prop_counter_teller", Vector3(2.0 + COUNTER_W * 5.5, 0.0, COUNTER_Z), 0.0, {}],
	# G9 banking hall: check-writing tables (cover), queue stanchions before the counter, waiting
	# benches, the night-mode pendants (2 of 8 lit), the hall clock over the vestibule
	["G9", "CheckTableNW", "prop_check_table", Vector3(4.5, 0.0, 13.0), 0.0, {}],
	["G9", "CheckTableNE", "prop_check_table", Vector3(16.5, 0.0, 13.0), 0.0, {}],
	["G9", "CheckTableSW", "prop_check_table", Vector3(4.5, 0.0, 16.5), 0.0, {}],
	["G9", "CheckTableSE", "prop_check_table", Vector3(16.5, 0.0, 16.5), 0.0, {}],
	["G9", "QueueRailW", "prop_queue_post", Vector3(5.6, 0.0, 11.7), 0.0, {}],
	["G9", "QueueRailE", "prop_queue_post", Vector3(13.6, 0.0, 11.7), 0.0, {}],
	["G9", "BenchWest", "prop_bench_upholstered", Vector3(0.437, 0.0, 14.5), -90.0, {}],
	["G9", "BenchEast", "prop_bench_upholstered", Vector3(20.663, 0.0, 12.6), 90.0, {}],
	["G9", "PendantA1", "prop_pendant_brass_off", Vector3(2.6, 5.5, 12.6), 0.0, {}],
	["G9", "PendantA2", "prop_pendant_brass", Vector3(7.9, 5.5, 12.6), 0.0, {}],
	["G9", "PendantA3", "prop_pendant_brass_off", Vector3(13.1, 5.5, 12.6), 0.0, {}],
	["G9", "PendantA4", "prop_pendant_brass_off", Vector3(18.4, 5.5, 12.6), 0.0, {}],
	["G9", "PendantB1", "prop_pendant_brass_off", Vector3(2.6, 5.5, 16.6), 0.0, {}],
	["G9", "PendantB2", "prop_pendant_brass_off", Vector3(7.9, 5.5, 16.6), 0.0, {}],
	["G9", "PendantB3", "prop_pendant_brass", Vector3(13.1, 5.5, 16.6), 0.0, {}],
	["G9", "PendantB4", "prop_pendant_brass_off", Vector3(18.4, 5.5, 16.6), 0.0, {}],
	["G9", "HallClock", "prop_clock_harbor", Vector3(10.5, 3.95, 19.8), 0.0, {}],
	# G11 loan office: free-standing desk (0.74 m), the officer's seat east of it, two visitors west
	["G11", "LoanDesk", "prop_desk_bank", Vector3(24.0, 0.0, 10.0), -90.0, {}],
	["G11", "LoanOfficerChair", "prop_chair_task", Vector3(24.95, 0.0, 10.0), 90.0, {"faces_anchor": "LoanDesk"}],
	["G11", "LoanVisitorA", "prop_chair_visitor", Vector3(23.0, 0.0, 9.6), -111.8, {"faces_anchor": "LoanDesk"}],
	["G11", "LoanVisitorB", "prop_chair_visitor", Vector3(23.0, 0.0, 10.4), -68.2, {"faces_anchor": "LoanDesk"}],
	# G12 manager: desk (kc_manager_desk, code_manager_planner on top), the night manager's NPC seat
	# (spawn `NightManager`), two visitor chairs
	["G12", "ManagerDesk", "prop_desk_bank", Vector3(23.6, 0.0, 13.95), -90.0, {}],
	["G12", "ManagerChair", "prop_chair_task", Vector3(24.55, 0.0, 13.95), 90.0, {"faces_anchor": "ManagerDesk"}],
	["G12", "ManagerVisitorA", "prop_chair_visitor", Vector3(22.6, 0.0, 13.55), -111.8, {"faces_anchor": "ManagerDesk"}],
	["G12", "ManagerVisitorB", "prop_chair_visitor", Vector3(22.6, 0.0, 14.35), -68.2, {"faces_anchor": "ManagerDesk"}],
	["G12", "ManagerBookshelf", "prop_bookshelf", Vector3(25.0, 0.0, 12.287), 180.0, {}],
	["G12", "ManagerPlant", "prop_plant_tall", Vector3(21.47, 0.0, 15.47), 0.0, {}],
	["G12", "ManagerCredenza", "prop_credenza", Vector3(22.65, 0.0, 15.653), 0.0, {}],
	# G13 ATM vestibule: two ATMs (saw targets) and the night depository head on the north wall
	["G13", "ATM1", "prop_atm", Vector3(22.3, 0.0, 16.472), 180.0, {}],
	["G13", "ATM2", "prop_atm", Vector3(23.4, 0.0, 16.472), 180.0, {}],
	["G13", "NightDrop", "prop_night_drop", Vector3(25.2, 0.0, 16.337), 180.0, {}],
	# B1 cash transfer
	["B1", "XferTrolleyA", "prop_cash_trolley", Vector3(0.562, BASE, 2.3), -90.0, {}],
	["B1", "XferTrolleyB", "prop_cash_trolley", Vector3(0.562, BASE, 3.45), -90.0, {}],
	["B1", "SortingBench", "prop_packing_bench", Vector3(3.6, BASE, 0.592), 180.0, {}],
	# B2 locker room: the sink row on the east wall (plumbing beside the WCs)
	["B2", "SinkA", "prop_sink_vanity", Vector3(15.638, BASE, 3.9), 90.0, {}],
	["B2", "SinkB", "prop_sink_vanity", Vector3(15.638, BASE, 4.8), 90.0, {}],
	# B13 WCs: two toilets on the north wall either side of the cubicle partition
	["B13", "ToiletA", "prop_toilet", Vector3(14.1, BASE, 0.532), 180.0, {}],
	["B13", "ToiletB", "prop_toilet", Vector3(15.4, BASE, 0.532), 180.0, {}],
	# B3 plant
	["B3", "Boiler", "prop_boiler", Vector3(20.463, BASE, 1.4), 90.0, {}],
	["B3", "AirHandler", "prop_air_handler", Vector3(20.388, BASE, 3.95), 90.0, {}],
	["B3", "WaterTank", "prop_water_tank", Vector3(16.6, BASE, 4.4), 0.0, {}],
	# B4 server room: rack rows on both walls
	["B4", "RackW1", "prop_server_rack", Vector3(21.612, BASE, 2.4), -90.0, {}],
	["B4", "RackW2", "prop_server_rack", Vector3(21.612, BASE, 3.01), -90.0, {}],
	["B4", "RackW3", "prop_server_rack", Vector3(21.612, BASE, 3.62), -90.0, {}],
	["B4", "RackE1", "prop_server_rack", Vector3(25.288, BASE, 2.8), 90.0, {}],
	["B4", "RackE2", "prop_server_rack", Vector3(25.288, BASE, 3.41), 90.0, {}],
	["B4", "ConsoleDesk", "prop_desk_office", Vector3(21.9, BASE, 5.538), 0.0, {}],
	["B4", "ConsoleChair", "prop_chair_office", Vector3(21.9, BASE, 4.86), 180.0, {"faces_anchor": "ConsoleDesk"}],
	# B6 records: two free-standing double-sided shelf rows, the microfiche desk (kc_records,
	# code_records_ledger) on the west wall
	["B6", "ShelfRow1N1", "prop_shelving_archive", Vector3(1.0, BASE, 10.4), 0.0, {}],
	["B6", "ShelfRow1N2", "prop_shelving_archive", Vector3(2.21, BASE, 10.4), 0.0, {}],
	["B6", "ShelfRow1N3", "prop_shelving_archive", Vector3(3.42, BASE, 10.4), 0.0, {}],
	["B6", "ShelfRow1S1", "prop_shelving_archive", Vector3(1.0, BASE, 10.86), 180.0, {}],
	["B6", "ShelfRow1S2", "prop_shelving_archive", Vector3(2.21, BASE, 10.86), 180.0, {}],
	["B6", "ShelfRow1S3", "prop_shelving_archive", Vector3(3.42, BASE, 10.86), 180.0, {}],
	["B6", "ShelfRow2N1", "prop_shelving_boxes", Vector3(1.0, BASE, 12.9), 0.0, {}],
	["B6", "ShelfRow2N2", "prop_shelving_archive", Vector3(2.21, BASE, 12.9), 0.0, {}],
	["B6", "ShelfRow2N3", "prop_shelving_archive", Vector3(3.42, BASE, 12.9), 0.0, {}],
	["B6", "ShelfRow2S1", "prop_shelving_archive", Vector3(1.0, BASE, 13.36), 180.0, {}],
	["B6", "ShelfRow2S2", "prop_shelving_boxes", Vector3(2.21, BASE, 13.36), 180.0, {}],
	["B6", "ShelfRow2S3", "prop_shelving_archive", Vector3(3.42, BASE, 13.36), 180.0, {}],
	["B6", "ShelfRow3N1", "prop_shelving_archive", Vector3(2.21, BASE, 17.4), 0.0, {}],
	["B6", "ShelfRow3S1", "prop_shelving_archive", Vector3(2.21, BASE, 17.86), 180.0, {}],
	["B6", "ShelfRow3N2", "prop_shelving_boxes", Vector3(3.42, BASE, 17.4), 0.0, {}],
	["B6", "ShelfRow3S2", "prop_shelving_archive", Vector3(3.42, BASE, 17.86), 180.0, {}],
	["B6", "ShelfRow3N3", "prop_shelving_archive", Vector3(4.63, BASE, 17.4), 0.0, {}],
	["B6", "ShelfRow3S3", "prop_shelving_archive", Vector3(4.63, BASE, 17.86), 180.0, {}],
	["B6", "MicroficheDesk", "prop_desk_office", Vector3(0.562, BASE, 15.6), -90.0, {}],
	["B6", "MicroficheChair", "prop_chair_office", Vector3(1.29, BASE, 15.6), 90.0, {"faces_anchor": "MicroficheDesk"}],
	["B6", "Microfiche", "prop_microfiche", Vector3(0.52, BASE + 0.74, 15.5), -90.0, {}],
	# B8 antechamber: viewing bench against the vault wall, behind the laser plane
	["B8", "ViewingBench", "prop_vault_bench", Vector3(11.0, BASE, 9.478), 0.0, {}],
	# B9 vault: deposit-box walls (4 units each side), the inspection table
	["B9", "BoxesW1", "prop_deposit_boxes", Vector3(9.537, BASE, BOX_UNITS_Z[0]), -90.0, {}],
	["B9", "BoxesW2", "prop_deposit_boxes", Vector3(9.537, BASE, BOX_UNITS_Z[1]), -90.0, {}],
	["B9", "BoxesW3", "prop_deposit_boxes", Vector3(9.537, BASE, BOX_UNITS_Z[2]), -90.0, {}],
	["B9", "BoxesW4", "prop_deposit_boxes", Vector3(9.537, BASE, BOX_UNITS_Z[3]), -90.0, {}],
	["B9", "BoxesE1", "prop_deposit_boxes", Vector3(18.463, BASE, BOX_UNITS_Z[0]), 90.0, {}],
	["B9", "BoxesE2", "prop_deposit_boxes", Vector3(18.463, BASE, BOX_UNITS_Z[1]), 90.0, {}],
	["B9", "BoxesE3", "prop_deposit_boxes", Vector3(18.463, BASE, BOX_UNITS_Z[2]), 90.0, {}],
	["B9", "BoxesE4", "prop_deposit_boxes", Vector3(18.463, BASE, BOX_UNITS_Z[3]), 90.0, {}],
	["G8", "TellerStool1", "prop_stool_teller", Vector3(4.6, 0.0, 8.15), 10.0, {}],
	["G8", "TellerStool2", "prop_stool_teller", Vector3(9.2, 0.0, 8.15), -8.0, {}],
	["G8", "TellerStool3", "prop_stool_teller", Vector3(12.4, 0.0, 8.15), 15.0, {}],
	["G8", "TellerStool4", "prop_stool_teller", Vector3(17.6, 0.0, 8.15), -12.0, {}],
	["B14", "JanitorLight", "prop_fluorescent", Vector3(7.7, BASE_CEIL, 5.1), 90.0, {}],
	["B9", "InspectionTable", "prop_vault_table", Vector3(11.4, BASE, 18.9), 0.0, {}],
	# B11 count room: two back-to-back counting desks, the sealing bench on the east wall
	["B11", "CountDeskA", "prop_desk_office", Vector3(23.3, BASE, 10.65), 0.0, {}],
	["B11", "CountDeskB", "prop_desk_office", Vector3(23.3, BASE, 11.362), 180.0, {}],
	["B11", "SealingBench", "prop_packing_bench", Vector3(25.408, BASE, 11.0), 90.0, {}],
	# X1 staff lot: sodium poles, staff cars in the marked stalls, facade lamps over the doors
	["X1", "LotLampWest", "prop_street_lamp_sodium", Vector3(-7.0, 0.0, -9.6), 180.0, {}],
	["X1", "LotLampMid", "prop_street_lamp_sodium", Vector3(5.5, 0.0, -9.9), 180.0, {}],
	["X1", "LotLampEast", "prop_street_lamp_sodium", Vector3(17.0, 0.0, -9.9), 180.0, {}],
	["X1", "CarLotA", "veh_car_sedan_navy", Vector3(20.3, 0.0, -6.7), 180.0, {}],
	["X1", "CarLotB", "veh_car_sedan_silver", Vector3(22.9, 0.0, -6.7), 180.0, {}],
	["X1", "CarLotC", "veh_car_sedan_wine", Vector3(12.5, 0.0, -6.7), 180.0, {}],
	["X1", "SallyDoorLamp", "prop_wall_lamp_sodium", Vector3(6.0, 2.75, -0.2), 0.0, {}],
	["X1", "LotWallLamp", "prop_wall_lamp_sodium", Vector3(13.5, 3.0, -0.2), 0.0, {}],
	["X1", "AreawayLamp", "prop_wall_lamp_sodium", Vector3(21.5, 3.0, -0.2), 0.0, {}],
	# X2H Harbor Street sidewalk + quay
	["X2H", "LampHarbor1", "prop_street_lamp_sodium", Vector3(-8.0, 0.0, 21.2), 180.0, {}],
	["X2H", "LampHarbor2", "prop_street_lamp_sodium", Vector3(5.5, 0.0, 21.2), 180.0, {}],
	["X2H", "LampHarbor3", "prop_street_lamp_sodium", Vector3(18.0, 0.0, 21.2), 180.0, {}],
	["X2H", "LampHarbor4", "prop_street_lamp_sodium", Vector3(28.3, 0.0, 21.2), 180.0, {}],
	["X2H", "LampQuayW", "prop_street_lamp_sodium", Vector3(-4.0, 0.0, 31.3), 0.0, {}],
	["X2H", "LampQuayE", "prop_street_lamp_sodium", Vector3(15.0, 0.0, 31.3), 0.0, {}],
	["X2H", "LampQuayFar", "prop_street_lamp_sodium", Vector3(30.0, 0.0, 31.3), 0.0, {}],
	["X2H", "CarHarborA", "veh_car_sedan_navy", Vector3(-6.0, ROAD_Y, 23.3), 90.0, {}],
	["X2H", "CarHarborB", "veh_car_sedan_wine", Vector3(16.6, ROAD_Y, 23.3), 90.0, {}],
	["X2H", "CarHarborC", "veh_car_sedan_silver", Vector3(-10.5, ROAD_Y, 29.1), -90.0, {}],
	["X2H", "MooringA", "prop_mooring_bollard", Vector3(-8.0, 0.0, 33.3), 0.0, {}],
	["X2H", "MooringB", "prop_mooring_bollard", Vector3(2.0, 0.0, 33.3), 0.0, {}],
	["X2H", "MooringC", "prop_mooring_bollard", Vector3(14.0, 0.0, 33.3), 0.0, {}],
	["X2H", "MooringD", "prop_mooring_bollard", Vector3(24.0, 0.0, 33.3), 0.0, {}],
	["X2H", "MooringE", "prop_mooring_bollard", Vector3(34.0, 0.0, 33.3), 0.0, {}],
	["X2H", "QuayBenchA", "prop_vault_bench", Vector3(-2.0, 0.0, 31.2), 180.0, {}],
	["X2H", "QuayBenchB", "prop_vault_bench", Vector3(20.0, 0.0, 31.2), 180.0, {}],
	["X2H", "QuayBinA", "prop_bin_street", Vector3(-0.6, 0.0, 31.2), 180.0, {}],
	["X2H", "QuayBinB", "prop_bin_street", Vector3(21.4, 0.0, 31.2), 180.0, {}],
	["X2H", "SidewalkBin", "prop_bin_street", Vector3(13.0, 0.0, 21.75), 180.0, {}],
	["X2H", "HarborClock", "prop_clock_harbor", Vector3(10.5, 3.65, 20.2), 180.0, {}],
	# X2W Wharf Lane (east facade)
	["X2W", "LampWharfW", "prop_street_lamp_sodium", Vector3(27.8, 0.0, -4.0), -90.0, {}],
	["X2W", "LampWharfW2", "prop_street_lamp_sodium", Vector3(27.8, 0.0, 12.0), -90.0, {}],
	["X2W", "LampWharfE", "prop_street_lamp_sodium", Vector3(36.75, 0.0, 8.0), 90.0, {}],
	["X2W", "CarWharf", "veh_car_sedan_silver", Vector3(30.1, ROAD_Y, 2.0), 0.0, {}],
	["X2W", "FireExitLamp", "prop_wall_lamp_sodium", Vector3(26.2, 3.0, 6.75), -90.0, {}],
	["X2W", "WharfBin", "prop_bin_street", Vector3(28.3, 0.0, 15.5), -90.0, {}],
	["X2W", "WharfBollard1", "prop_bollard_steel", Vector3(28.75, 0.0, -1.0), 0.0, {}],
	["X2W", "WharfBollard2", "prop_bollard_steel", Vector3(28.75, 0.0, 9.5), 0.0, {}],
	["X2W", "WharfBollard3", "prop_bollard_steel", Vector3(28.75, 0.0, 17.5), 0.0, {}],
]

## Exterior kit rooms (KitPlacer frames whose wall 0 is the facade; only wall 0 exists):
## [kit room id, RoomVolume id, box [x0, y0, z0, x1, y1, z1], yaw_deg of the local frame, floor y].
const KIT_ROOMS_EXT: Array = [
	["X1", "X1", [-14.0, 0.0, -6.2, 26.2, 4.0, -0.2], 180.0, 0.0],
	["X2H", "X2", [-14.0, 0.0, 20.2, 26.2, 4.0, 22.2], 0.0, 0.0],
	["X2W", "X2", [26.2, 0.0, -14.0, 29.0, 4.0, 20.2], 90.0, 0.0],
]

## Clear interiors where the wall-line insets do not apply (0.6 m vault walls, the 0.1 m vault lining).
const CLEAR: Dictionary = {
	"B7": [7.1, 7.6, 8.7, 19.8], "B8": [9.1, 7.6, 18.9, 9.7], "B9": [9.3, 10.3, 18.7, 19.7], "B10": [19.3, 7.6, 20.9, 19.8],
	# B14 under flight 1: the stair divider (x 8.3-8.7) bounds the closet on the east
	"B14": [7.1, 3.6, 8.3, 5.9],
}

## Extra keep-outs per kit room (world boxes [x0, y0, z0, x1, y1, z1]).
const KEEP_OUT: Dictionary = {
	# the roller-door bay, the cash lift shaft and its loading front
	"G1": [[1.8, 0.0, 0.2, 5.2, 3.0, 2.4], [4.5, 0.0, 1.0, 6.9, 3.0, 2.6]],
	# srv_ground: the G6 rack + hack terminal (variant)
	"G6": [[23.2, 0.0, 0.2, 25.8, 3.0, 2.3]],
	# the transaction counter's customer ledge (beyond the room line) and the teller gate's swing
	# the staff walkway along the counter (patrol G8West-Mid-East, the drawer UsePoints) and the
	# tellers' alarm button on the back wall
	"G8": [[0.2, 0.0, 9.2, 2.0, 3.0, 9.9], [2.0, 0.0, 8.45, 19.0, 3.0, 9.3], [14.3, 0.0, 7.6, 15.7, 3.0, 8.45]],
	# compass rose (landmark, stays clear), the vestibule doors' swing and the ATM door's
	"G9": [[8.3, 0.0, 12.3, 12.7, 3.0, 16.7], [8.4, 0.0, 18.0, 12.6, 3.1, 20.0], [9.0, 0.0, 16.6, 12.0, 3.0, 18.0],
		[19.8, 0.0, 17.2, 20.9, 3.0, 18.8]],
	# the B13 WCs inside the B2 bounding box, the WC door's approach
	"B2": [[13.4, BASE, 0.0, 16.0, -0.8, 2.6], [13.9, BASE, 2.6, 15.6, -0.8, 3.5]],
	# the cubicle partition
	"B13": [[14.69, BASE, 0.2, 14.81, -0.8, 1.55]],
	# lift shaft + loading front
	"B1": [[4.5, BASE, 1.0, 6.9, -0.8, 2.6]],
	# srv_basement hack terminal (north wall)
	"B4": [[23.2, BASE, 0.2, 24.8, -0.8, 1.9]],
	# the cage and its gate, the Co-op pallet, the vault door's swing
	"B9": [[11.6, BASE, 13.1, 16.4, -1.0, 16.9], [12.6, BASE, 10.3, 15.4, -1.0, 13.1], [12.9, BASE, 17.9, 15.1, -1.0, 19.7]],
	# janitor: the BODY_HIDE floor
	"B14": [[7.4, BASE, 4.6, 8.4, BASE + 2.0, 5.9]],
	# the lot: the roller-door apron, the areaway cage, the armoured-car bay (rare event), the dumpster
	"X1": [[1.0, -0.5, -6.2, 6.0, 4.0, -0.2], [16.8, -0.5, -2.8, 19.2, 4.0, -0.2], [-2.6, -0.5, -6.2, 0.2, 4.0, -2.4],
		[8.2, -0.5, -2.0, 10.8, 4.0, -0.2]],
	# the ATM street door's front, the main entrance steps
	"X2H": [[8.6, -0.5, 20.2, 12.4, 4.0, 22.2], [23.4, -0.5, 20.2, 25.1, 4.0, 22.2]],
	# the fire exit apron
	"X2W": [[26.2, -0.5, 5.6, 29.0, 4.0, 7.9]],
}

## Kit seeds (variety: every room differs).
const KIT_SEEDS: Dictionary = {
	"G1": 5101, "G3": 5103, "G4": 5104, "G5": 5105, "G6": 5106, "G7": 5107, "G8": 5108, "G9": 5109, "G11": 5111,
	"G12": 5112, "G13": 5113, "B1": 5201, "B2": 5202, "B3": 5203, "B4": 5204, "B5": 5205, "B6": 5206, "B7": 5207,
	"B8": 5208, "B9": 5209, "B10": 5210, "B11": 5211, "B12": 5212, "B13": 5213, "B14": 5214,
	"X1": 5301, "X2H": 5302, "X2W": 5303,
}

## Props outside every kit room: [name, asset, pos, yaw_deg, metas]. Prefab-visual scenes used as
## dressing get their metas here (kind, mount).
const DIRECT_PROPS: Array = [
	# the ATM street door's card-swipe reader (always open at night: dressing, doc G13)
	["AtmDoorCardReader", "prop_keycard_reader", Vector3(23.57, 1.2, 20.2), 180.0, {"kind": "card_reader", "mount": "wall"}],
]

## Site dressing instanced under Geometry over its collision blocks (not props): [name, asset, pos, yaw].
const SITE_DRESSING: Array = [
	# boats: pivot = keel bottom (deck -1.0 / -0.6 minus the 1.0 / 1.8 m draught)
	["LaunchE2", "veh_boat_launch", Vector3(8.5, -2.0, 36.9), 0.0],
	["Trawler", "veh_trawler", Vector3(-4.0, -2.4, 36.6), 0.0],
	["ContainerA1", "prop_container_40_rust", Vector3(45.0, 0.0, -10.75), 0.0],
	["ContainerA2", "prop_container_40_blue", Vector3(45.0, 2.59, -10.75), 180.0],
	["ContainerB1", "prop_container_40_green", Vector3(45.0, 0.0, -4.75), 0.0],
	["ContainerC1", "prop_container_40_blue", Vector3(45.0, 0.0, 10.25), 180.0],
	["ContainerC2", "prop_container_40_rust", Vector3(45.0, 2.59, 10.25), 0.0],
	["ContainerD1", "prop_container_20_green", Vector3(48.0, 0.0, 15.25), 0.0],
	["ContainerD2", "prop_container_20_rust", Vector3(48.0, 2.59, 15.25), 180.0],
	["ContainerD3", "prop_container_20_blue", Vector3(48.0, 5.18, 15.25), 0.0],
	["TrailerBox", "prop_container_20_rust", Vector3(32.9, 1.31, -14.0), 0.0],
	["VistaVanWest", "veh_van_secure", Vector3(-17.6, ROAD_Y, 24.4), 90.0],
]

## Kit fixture light overrides per kit room: {room: {kind: {light property: value}}}.
const LIGHT_TWEAKS: Dictionary = {
	"G3": {"light_fixture": {"light_energy": 0.8}},
	"G9": {"light_fixture": {"light_energy": 2.4, "omni_range": 8.0}},
	"B9": {"light_fixture": {"light_energy": 2.0}},
	"X1": {"wall_lamp": {"spot_range": 10.0, "light_energy": 3.0}},
	"X2W": {"wall_lamp": {"spot_range": 8.0, "light_energy": 2.4}},
}

## Kit-placed fixtures that cast shadows: the fixture nearest each point (<= 8 per room / per view).
## Not the hall pendants: their lamp sits inside the opal globe, which would shadow the whole hall.
const SHADOW_FIXTURES: Array = [
	["B9", Vector3(14.0, -1.0, 15.0)],
	["B5", Vector3(14.0, -0.8, 6.75)], ["G7", Vector3(12.0, 3.0, 6.75)], ["X2H", Vector3(5.5, 6.0, 21.2)],
	["X2H", Vector3(15.0, 6.0, 31.3)], ["X1", Vector3(5.5, 6.0, -9.9)],
]

## Night-mode hall pendants that are lit (2 of 8: doc §Audio/lighting, 25 %).
const LIT_PENDANTS: Array[String] = ["PendantA2", "PendantB3"]
