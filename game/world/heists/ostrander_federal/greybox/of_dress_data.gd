## Ostrander Federal G2 dressing data, lane C (OF-C2, ENV C): the rooms this pass dresses, the map-built furniture's
## catalog art, kit seeds, keep-outs, light tweaks, shadow fixtures, the directly placed props (exteriors X2-X5, the
## stairs) and the fill-light classes. Read by of_dress.gd. Lanes A (BH, VE, X1) and B (PC, SD, VO, the landmarks: the
## sunburst, the lantern and meridian line, the teller line) dress their own rooms in their own files.
extends RefCounted

const FB: float = -4.0
const FG: float = 0.0
const FM: float = 5.0
const FE: float = 8.6
const FR: float = 12.2

## Rooms of the other G2 lanes (never dressed here; their map-built furniture keeps its greybox / their art).
const OTHER_LANES: Array[String] = ["BH", "VE", "X1", "PC", "SD", "VO"]
## Map-built furniture of the other lanes (the teller line's work tops are lane B's landmark).
const OTHER_LANE_PROPS: Array[String] = ["TellerWorktop01", "TellerWorktop02", "TellerWorktop03", "TellerWorktop04",
	"TellerWorktop05", "TellerWorktop06", "TellerWorktop07", "TellerWorktop08", "TellerWorktop09", "TellerWorktop10",
	"TellerWorktop11", "TellerWorktop12"]

## Map-built furniture (Props/MapBuilt boxes, layout FURNITURE) -> catalog art over the unchanged collider:
## [asset, yaw (deg, the asset's front -Z turned by it), nx, nz, mirror(, keep_height)]. The box footprint is split into nx x nz cells
## (box-local x / z) and one copy of the asset is scaled into each cell and to the box height (|scale - 1| <= 0.3), so
## the visual is the collider. `mirror` turns the second row 180 deg (back-to-back desks, the boiler bank); `keep_height`
## keeps the model's own height (a sofa over its 0.45 m seat box).
## Front conventions: against a north wall 180, south 0, west -90, east 90.
const PROP_ART: Dictionary = {
	# Basement
	"LockersLK": ["prop_lockers_bank_w300", -90.0, 1, 1, false],
	"SinksLK": ["prop_sink_vanity", 90.0, 1, 2, false],
	"BenchLK": ["prop_bench_gallery", 0.0, 1, 1, false],
	"CartShelfCQ": ["prop_shelving_boxes", -90.0, 1, 2, false],
	"CountTableW": ["prop_counter_count_w240", 0.0, 1, 1, false],
	"CountTableE": ["prop_counter_count_w240", 0.0, 1, 1, false],
	"BoilerPL": ["prop_boiler", 180.0, 2, 2, true],
	"AHUPL": ["prop_air_handler", 180.0, 1, 2, true],
	"TelecomFrameCM": ["prop_server_rack_pair", -90.0, 1, 2, false],
	"ShelvesSS": ["prop_shelving_boxes", 90.0, 1, 3, false],
	"RecordsShelf1": ["prop_shelving_archive", 90.0, 1, 10, false],
	"RecordsShelf2": ["prop_shelving_archive", 90.0, 1, 10, false],
	"RecordsShelf3": ["prop_shelving_archive", -90.0, 1, 10, false],
	"RecordsShelf4": ["prop_shelving_archive", 90.0, 1, 10, false],
	"RecordsShelf5": ["prop_shelving_archive", -90.0, 1, 10, false],
	"RecordsShelf6": ["prop_shelving_archive", -90.0, 1, 10, false],
	"ViewingBench": ["prop_vault_bench", 180.0, 1, 1, false],
	# Ground
	"CartsLD": ["prop_cart_hide", 0.0, 1, 2, false],
	"BenchLD": ["prop_bench_corridor", 0.0, 1, 1, false],
	"PanelsE1": ["prop_switchboard_w200", 180.0, 1, 1, false],
	"CoffeeCounterSR": ["prop_counter_security_w140", -90.0, 1, 1, false],
	"KeyChestSR": ["prop_file_cabinet", 90.0, 1, 1, false],
	"LockersGR": ["prop_lockers_w120", 180.0, 3, 1, false],
	"KitBenchGR": ["prop_bench_gallery", 0.0, 1, 1, false],
	"SortingTableMO": ["prop_counter_count_w240", 0.0, 1, 1, false],
	"CopierMO": ["prop_copier", 90.0, 1, 1, false],
	"DeskLO1": ["prop_desk_office", 90.0, 1, 1, false],
	"DeskLO2": ["prop_desk_office", 90.0, 1, 1, false],
	"FilesLO": ["prop_file_cabinet", 90.0, 1, 2, false],
	"TableCN1": ["prop_table_round_d120", 0.0, 1, 1, false],
	"TableCN2": ["prop_table_round_d120", 0.0, 1, 1, false],
	"ATM1": ["prop_atm", -90.0, 1, 1, false],
	"ATM2": ["prop_atm", -90.0, 1, 1, false],
	"ManagerDesk": ["prop_desk_exec", -90.0, 1, 1, false],
	"ManagerCredenza": ["prop_credenza", 90.0, 1, 1, false],
	"DeskNA": ["prop_desk_office", 90.0, 1, 1, false],
	# Gallery
	"BreakTable": ["prop_table_break", 0.0, 2, 1, false],
	"BreakCounter": ["prop_counter_kitchen_w300", 180.0, 1, 1, false],
	"BreakFridge": ["prop_fridge", 180.0, 1, 1, false],
	"PanelsE2": ["prop_switchboard_w200", 180.0, 1, 1, false],
	"DeskIT1": ["prop_desk_office", 90.0, 1, 1, false],
	"DeskIT2": ["prop_desk_office", -90.0, 1, 1, false],
	"RacksSV": ["prop_server_rack", 0.0, 1, 3, false],
	"ShelvesAR": ["prop_shelving_archive", 90.0, 1, 3, false],
	"DeskAO1": ["prop_desk_office", 90.0, 1, 1, false],
	"DeskAO2": ["prop_desk_office", 90.0, 1, 1, false],
	"DeskAO3": ["prop_desk_office", 90.0, 1, 1, false],
	"DeskOF": ["prop_desk_office", 90.0, 1, 1, false],
	"WorkstationsOF1": ["prop_desk_office", 0.0, 2, 2, true],
	"WorkstationsOF2": ["prop_desk_office", 0.0, 2, 2, true],
	"ConferenceTable": ["prop_table_conference_l360", 0.0, 1, 1, false],
	"DeskCO": ["prop_desk_office", 90.0, 1, 1, false],
	"WritingDeskGAW": ["prop_desk_office", 180.0, 1, 1, false],
	"WritingDeskGAE": ["prop_desk_office", 180.0, 1, 1, false],
	"DeskTR": ["prop_desk_office", 90.0, 1, 1, false],
	"TableTT": ["prop_table_break_l160", 90.0, 1, 2, false],
	# Executive
	"BoardTable": ["prop_table_boardroom_l480", 0.0, 1, 1, false],
	"DeskEA": ["prop_desk_office", 90.0, 1, 1, false],
	"PresidentDesk": ["prop_desk_exec", 180.0, 1, 1, false],
	"PresidentShelves": ["prop_bookcase_w240", 90.0, 1, 2, false],
	"PantryCounter": ["prop_counter_kitchen_w300", 180.0, 1, 1, false],
	"PantryTable": ["prop_table_round_d120", 0.0, 1, 1, false],
	"LoungeBar": ["prop_bar_lounge_w300", 90.0, 1, 1, false],
	"LoungeSofaW": ["prop_sofa_w220", 180.0, 1, 1, false, true],
	"TableLG": ["prop_desk_office", 0.0, 2, 2, true],
	"TableCT": ["prop_desk_office", 0.0, 2, 2, true],
	"ShelvesRA": ["prop_shelving_archive", 90.0, 1, 4, false],
	"TerracePlanter1": ["prop_planter_street", 0.0, 1, 1, false],
	"TerracePlanter2": ["prop_planter_street", 0.0, 1, 1, false],
	"TerracePlanter3": ["prop_planter_street", 0.0, 1, 1, false],
	"TerracePlanter4": ["prop_planter_street", 0.0, 1, 1, false],
	"TerracePlanter5": ["prop_planter_street", 0.0, 1, 1, false],
	"TerraceBench1": ["prop_bench_stone", 0.0, 1, 1, false],
	# Roof and the lane / Tannery Street
	"RoofAHU": ["prop_ahu_roof", 0.0, 1, 1, false],
	"RoofTank": ["prop_water_tank_roof", 0.0, 1, 1, false],
	"RoofCondensers": ["prop_hvac_condenser", 180.0, 3, 2, true],
	"ParkedCar1": ["veh_car_sedan_silver", 0.0, 1, 1, false],
}

## Kit seed per room (layout variety: AO1-3, CN1/2 + TT, LG/CT, the restrooms, janitors, electrical closets,
## corridors, the break rooms and archives differ in layout hash; levelcheck `variety`).
const KIT_SEEDS: Dictionary = {
	"LK": 7101, "CQ": 7102, "CP": 7103, "PL": 7104, "CM": 7105, "SS": 7106, "BB": 7107, "RC": 7608, "VC": 7109,
	"VT": 7110, "LD": 7111, "E1": 7112, "SR": 7113, "GR": 7214, "WM": 7115, "WW": 7216, "J1": 7617, "MO": 7118,
	"BC": 7119, "LO": 7120, "TW": 7121, "CN1": 7122, "CN2": 7323, "AV": 7124, "BM": 7125, "PW": 7126, "NA": 7127,
	"BR": 7128, "E2": 7729, "IT": 7130, "SV": 7131, "WM2": 7332, "WW2": 7433, "J2": 7734, "AR": 7135, "UC": 7136,
	"AO1": 7137, "AO2": 7238, "AO3": 7339, "WL": 7140, "OF": 7141, "CF": 7142, "CO": 7443, "GA": 7144, "EL": 7245,
	"TR": 7546, "TT": 7448, "BD": 7148, "E3": 7849, "EA": 7650, "PR": 7151, "PN": 7252, "XW": 7253, "XC": 7254,
	"XL": 7155, "LG": 7156, "CT": 7357, "RA": 7259, "RP": 7659,
}

## Room keep-outs [x0, y0, z0, x1, y1, z1] (nav-critical routes and gameplay space the kits leave alone):
## the corridors' walking strip (1.2 m down the middle), the teller line (lane B's landmark: the counter, the work tops
## and the staff strip behind them, the hide line), the lid with the drill assembly and the hoist / ladder hole below
## it, the vault's bag routes (door -> hoist, door -> both cage gates; >= 60 % of VT stays clear), the dock's van /
## cart lane (roller door -> lift -> BC), the gallery's crossing line, the RC end aisle (a hide spot) and the camera
## operator's chair at the monitor wall, the lounge's door-to-terrace walk.
const KEEP_OUT: Dictionary = {
	"BB": [[0.2, FB, 7.4, 47.8, FB + 2.6, 8.6]],
	"BC": [[10.2, FG, 7.4, 47.8, FG + 2.6, 8.6]],
	"UC": [[0.2, FM, 7.4, 47.8, FM + 2.6, 8.6]],
	"XC": [[0.2, FE, 7.4, 47.8, FE + 2.6, 8.6]],
	"WL": [[6.4, FM, 9.2, 7.6, FM + 2.6, 35.8]],
	"EL": [[40.4, FM, 9.2, 41.6, FM + 2.6, 35.8]],
	"TW": [[8.1, FG, 15.4, 39.9, FG + 4.0, 16.9], [22.4, FG, 13.0, 25.6, FG + 4.0, 16.2]],
	"VT": [[21.6, FB, 13.1, 31.6, FB + 3.2, 17.2], [25.6, FB, 17.2, 28.9, FB + 3.2, 21.0],
		[22.3, FB, 22.6, 25.7, FB + 3.2, 24.0]],
	"VC": [[14.2, FB, 10.6, 33.8, FB + 3.2, 12.9]],
	"LD": [[2.6, FG, 0.2, 9.8, FG + 4.2, 3.4], [7.0, FG, 3.4, 9.8, FG + 4.2, 8.2]],
	"GA": [[8.1, FM, 18.1, 39.9, FM + 3.0, 19.85]],
	"RC": [[12.0, FB, 9.2, 13.8, FB + 3.2, 24.8], [0.2, FB, 22.9, 13.8, FB + 3.2, 24.8]],
	"SR": [[18.4, FG, 0.2, 20.6, FG + 3.0, 2.6]],
	"CP": [[16.2, FB, 4.4, 25.8, FB + 3.2, 6.8]],
	# XL: the walk from the lounge door (6, 9) to the terrace doors (x 5.6 / 10.6, z 17): the E3 bag line and the heli
	"XL": [[5.6, FE, 9.2, 11.7, FE + 2.6, 16.8]],
}

## Kit fixture light tweaks per room id: asset -> Light3D properties (doc Audio/lighting: offices 4000 K panels at
## full level (business hours), BOH 5000 K, the security room dim with the monitor glow, the basement 5000 K battens,
## the vault bright 4000 K strips, the executive level warm 3000 K).
const _OFFICE: Dictionary = {"prop_ceiling_panel_neutral": {"light_energy": 1.6, "light_color": Color(1.0, 0.94, 0.86)}}
const _BOH: Dictionary = {"prop_ceiling_panel_cool": {"light_energy": 1.3, "light_color": Color(0.96, 0.98, 1.0)},
	"prop_fluorescent": {"light_energy": 1.2, "light_color": Color(0.96, 0.98, 1.0)}}
const _EXEC: Dictionary = {"prop_downlight": {"light_energy": 1.5, "light_color": Color(1.0, 0.8, 0.6)},
	"prop_ceiling_panel_neutral": {"light_energy": 1.2, "light_color": Color(1.0, 0.84, 0.66)}}
const LIGHT_TWEAKS: Dictionary = {
	"LO": _OFFICE, "CN1": _OFFICE, "CN2": _OFFICE, "BM": _OFFICE, "NA": _OFFICE, "MO": _OFFICE, "IT": _OFFICE,
	"AO1": _OFFICE, "AO2": _OFFICE, "AO3": _OFFICE, "OF": _OFFICE, "CF": _OFFICE, "CO": _OFFICE, "TR": _OFFICE,
	"TT": _OFFICE, "UC": _OFFICE, "AR": _OFFICE, "BR": _OFFICE,
	"BB": _BOH, "BC": _BOH, "LD": _BOH, "GR": _BOH, "CQ": _BOH, "CP": _BOH, "PL": _BOH, "CM": _BOH, "SS": _BOH,
	"RC": _BOH, "E1": _BOH, "E2": _BOH, "E3": _BOH, "J1": _BOH, "J2": _BOH,
	"SR": {"prop_ceiling_panel_cool": {"light_energy": 0.55, "light_color": Color(0.75, 0.85, 1.0)},
		"prop_ceiling_panel_neutral": {"light_energy": 0.55, "light_color": Color(0.75, 0.85, 1.0)}},
	"VT": {"prop_fluorescent": {"light_energy": 1.8, "light_color": Color(1.0, 0.95, 0.88)}},
	"VC": {"prop_fluorescent": {"light_energy": 1.0, "light_color": Color(1.0, 0.92, 0.9)}},
	"BD": _EXEC, "EA": _EXEC, "PR": _EXEC, "PN": _EXEC, "XC": _EXEC, "XL": _EXEC, "LG": _EXEC, "CT": _EXEC,
	"RA": _EXEC, "XW": _EXEC,
}
## Shadow-casting fixtures: [room, target]. None since D-146: each re-drew ~300-430 casters in every hall view (the
## rooms sit behind the hall walls and the renderer does not occlude lights) for a shadow that reads only in its room,
## where the dressing casts no shadow either (RenderBudgetPolicy). Were SR, VT, PR, OF, LD, BB.
const SHADOW_FIXTURES: Array = []
## Rooms whose kit ceiling grid is off (none).
const NO_CEILING_GRID: Array[String] = []
## Rooms without fill lights (shafts and the open stairs light from their wall lamps); warm and dim fill rooms.
const NO_FILL: Array[String] = ["GL", "SA", "SB", "HH"]
const WARM_ROOMS: Array[String] = ["BD", "EA", "PR", "PN", "XC", "XL", "LG", "CT", "RA", "XW", "GA", "TW"]
const DIM_FILL_ROOMS: Array[String] = ["SR", "VC", "CM", "SV"]

## Directly placed props: [name, asset, position, yaw, metas]. Wall mounts: the position is the wall face (the item's
## back), at the item's centre height. Exteriors (X2 Ledger Lane, X3 Tannery Street, X4 the terrace, X5 the roof) and
## the stair lamps (SA / SB / HH, no kit).
const DIRECT_PROPS: Array = [
	# X2 Ledger Lane: lamps over the dock roller door, the personnel door and along the bank's north wall (face z -0.2),
	# floods on the parking structure's screen (face z -10.2); condensers against the bank wall east of the dumpsters,
	# a pallet stack and a crate west of them (off the dock doors' clear zones and the spawn -> dock walk, clear of the E1
	# secure zone and the drill van), a crate by the fire-escape drop, a street bin.
	["LaneLampDock", "prop_wall_lamp", Vector3(5.0, 4.75, -0.2), 0.0, {}],
	["LaneLampPersonnel", "prop_wall_lamp", Vector3(8.0, 2.65, -0.2), 0.0, {}],
	["LaneLampMid", "prop_wall_lamp", Vector3(24.0, 3.2, -0.2), 0.0, {}],
	["LaneLampEast", "prop_wall_lamp", Vector3(40.0, 3.2, -0.2), 0.0, {}],
	["LaneFloodGarageW", "prop_wall_lamp_sodium", Vector3(4.0, 3.4, -10.2), 180.0, {}],
	["LaneFloodGarageE", "prop_wall_lamp_sodium", Vector3(34.0, 3.4, -10.2), 180.0, {}],
	["LaneCondenser1", "prop_hvac_condenser", Vector3(36.0, FG, -0.437), 0.0, {}],
	["LaneCondenser2", "prop_hvac_condenser", Vector3(37.2, FG, -0.437), 0.0, {}],
	["LanePallets", "prop_pallet_stack", Vector3(31.0, FG, -0.62), 0.0, {}],
	["LaneCrate", "prop_crate_wood", Vector3(32.2, FG, -0.512), 0.0, {}],
	["LaneCrateFireEscape", "prop_crate_wood", Vector3(1.8, FG, -0.512), 0.0, {}],
	["LaneBin", "prop_bin_street", Vector3(38.5, FG, -0.505), 0.0, {}],
	# X3 Tannery Street: the Belmont's awnings (face x 62.2), street lamps on its kerb, a lamp over the fire exit,
	# steel bollards by the E2 bay
	["TanneryAwning1", "prop_awning", Vector3(62.2, 3.6, 2.0), 90.0, {}],
	["TanneryAwning2", "prop_awning", Vector3(62.2, 3.6, 16.0), 90.0, {}],
	["TanneryAwning3", "prop_awning", Vector3(62.2, 3.6, 30.0), 90.0, {}],
	["TanneryLamp1", "prop_street_lamp", Vector3(61.4, FG, -6.0), 90.0, {}],
	["TanneryLamp2", "prop_street_lamp", Vector3(61.4, FG, 34.0), 90.0, {}],
	["TanneryLamp3", "prop_street_lamp", Vector3(61.4, FG, 24.0), 90.0, {}],
	["TanneryFireExitLamp", "prop_wall_lamp", Vector3(48.2, 2.65, 9.0), -90.0, {}],
	# steel bollards and a street bin on the bank's Tannery kerb, north of the fire exit
	["TanneryBin", "prop_bin_street", Vector3(48.7, FG, 2.5), 0.0, {}],
	["TanneryBollard1", "prop_bollard_steel", Vector3(48.7, FG, 4.0), 0.0, {}],
	["TanneryBollard2", "prop_bollard_steel", Vector3(48.7, FG, 5.5), 0.0, {}],
	["TanneryBayBollard1", "prop_bollard_steel", Vector3(48.7, FG, 12.0), 0.0, {}],
	["TanneryBayBollard2", "prop_bollard_steel", Vector3(48.7, FG, 16.5), 0.0, {}],
	# X4 terrace: long planters and LED bollards along the south parapet (face z 35.8), off the routes round the lantern
	["TerracePlanterSW", "prop_planter_terrace", Vector3(8.0, FE, 35.39), 180.0, {}],
	["TerracePlanterSE", "prop_planter_terrace", Vector3(40.0, FE, 35.39), 180.0, {}],
	["TerraceBollard1", "prop_bollard_led", Vector3(14.5, FE, 35.4), 0.0, {}],
	["TerraceBollard2", "prop_bollard_led", Vector3(18.5, FE, 35.4), 0.0, {}],
	["TerraceBollard3", "prop_bollard_led", Vector3(29.5, FE, 35.4), 0.0, {}],
	["TerraceBollard4", "prop_bollard_led", Vector3(33.5, FE, 35.4), 0.0, {}],
	["TerraceBollard5", "prop_bollard_led", Vector3(21.3, FE, 35.4), 0.0, {}],
	["TerraceBollard6", "prop_bollard_led", Vector3(26.7, FE, 35.4), 0.0, {}],
	["TerracePlanterS", "prop_planter_terrace", Vector3(24.0, FE, 35.39), 180.0, {}],
	["TerraceBenchS1", "prop_bench_stone", Vector3(36.5, FE, 35.3), 180.0, {}],
	["TerraceBenchS2", "prop_bench_stone", Vector3(28.2, FE, 35.3), 180.0, {}],
	# the executive lounge's terrace: an outdoor bar on the CT facade (face z 17.2, between the windows), heaters and
	# loungers in the west wing, clear of the terrace doors' walk east and the drop zone (6, 30)
	["TerraceBar", "prop_outdoor_kitchen", Vector3(37.5, FE, 17.505), 180.0, {}],
	["TerraceHeaterBar", "prop_patio_heater", Vector3(40.6, FE, 18.2), 0.0, {}],
	["TerraceHeaterW1", "prop_patio_heater", Vector3(0.9, FE, 21.0), 0.0, {}],
	["TerraceHeaterW2", "prop_patio_heater", Vector3(0.9, FE, 28.8), 0.0, {}],
	["TerraceLounger1", "prop_lounger", Vector3(3.8, FE, 34.4), 0.0, {}],
	["TerraceLounger2", "prop_lounger", Vector3(4.9, FE, 34.4), 0.0, {}],
	["TerraceBenchNet", "prop_bench_stone", Vector3(45.2, FE, 26.0), 90.0, {}],
	# X5 roof: condensers on the plant room south face (z 10, face 10.1) west of its door and a packaged chiller in
	# the NE corner (off the walk to the caged ladder)
	["RoofCondenser1", "prop_hvac_condenser", Vector3(21.0, FR, 10.342), 180.0, {}],
	["RoofCondenser2", "prop_hvac_condenser", Vector3(22.2, FR, 10.342), 180.0, {}],
	["RoofCondenser3", "prop_hvac_condenser", Vector3(23.4, FR, 10.342), 180.0, {}],
	["RoofChiller", "prop_chiller_roof", Vector3(42.2, FR, 3.5), 0.0, {}],
	["RoofCondenserTank", "prop_hvac_condenser", Vector3(41.0, FR, 12.5), -90.0, {}],
	["RoofTankNW", "prop_water_tank", Vector3(11.0, FR, 9.0), 0.0, {}],
	# VT box walls (doc: the cash cage, the bullion cage, the box walls): deposit-box units on the west wall (face
	# x 14.3, clear of the bond safe at z 20.5) and the east wall either side of the bullion cage (face x 33.7); the
	# north and south walls carry the deposit_box prefabs; a counting table in the open west half. >= 60 % of the
	# floor stays clear (the hole, the hoist, the door -> cage routes are room keep-outs).
	["VaultBoxesW1", "prop_deposit_boxes", Vector3(14.535, FB, 14.6), -90.0, {}],
	["VaultBoxesW2", "prop_deposit_boxes", Vector3(14.535, FB, 16.5), -90.0, {}],
	["VaultBoxesW3", "prop_deposit_boxes", Vector3(14.535, FB, 18.4), -90.0, {}],
	["VaultBoxesW5", "prop_deposit_boxes", Vector3(14.535, FB, 22.2), -90.0, {}],
	["VaultBoxesE1", "prop_deposit_boxes", Vector3(33.465, FB, 14.6), 90.0, {}],
	["VaultBoxesE2", "prop_deposit_boxes", Vector3(33.465, FB, 22.4), 90.0, {}],
	["VaultCountTable", "prop_vault_table", Vector3(18.5, FB, 19.0), 90.0, {}],
	# CQ: a cash trolley queued on the east wall (the lift -> BB walk keeps 1.6 m) and a sealed-bag skid south of it,
	# both between the lift gates' swing (z <= 3.9) and the BB door's (1.1 m leaf hinged at x 12.6: z >= 5.9)
	["CartQueueTrolley", "prop_cash_trolley", Vector3(12.49, FB, 4.5), 90.0, {}],
	["CartQueueSkid", "prop_of_cash_skid", Vector3(12.54, FB, 5.41), 90.0, {}],
	# GA: a bronze on a plinth by the east writing desk (kit sculpture; off the crossing line)
	["GallerySculpture", "prop_plinth_bronze_a", Vector3(35.6, FM, 17.45), 180.0, {}],
	# CF: six chairs round the conference table (31, 13; 3.0 x 1.2); NA: the new-accounts officer's chair
	["ConfChairN1", "prop_chair_office", Vector3(30.0, FM, 11.75), 180.0, {}],
	["ConfChairN2", "prop_chair_office", Vector3(31.0, FM, 11.75), 180.0, {}],
	["ConfChairN3", "prop_chair_office", Vector3(32.0, FM, 11.75), 180.0, {}],
	["ConfChairS1", "prop_chair_office", Vector3(30.0, FM, 14.25), 0.0, {}],
	["ConfChairS2", "prop_chair_office", Vector3(31.0, FM, 14.25), 0.0, {}],
	["ConfChairS3", "prop_chair_office", Vector3(32.0, FM, 14.25), 0.0, {}],
	["NewAccountsChair", "prop_chair_office", Vector3(44.3, FG, 33.5), -90.0, {}],
	# BD: the table for 14 (5, 3.5; 6.0 x 1.6): six a side and one at each end
	["BoardChairN1", "prop_chair_office", Vector3(2.5, FE, 2.05), 180.0, {}],
	["BoardChairS1", "prop_chair_office", Vector3(2.5, FE, 4.95), 0.0, {}],
	["BoardChairN2", "prop_chair_office", Vector3(3.5, FE, 2.05), 180.0, {}],
	["BoardChairS2", "prop_chair_office", Vector3(3.5, FE, 4.95), 0.0, {}],
	["BoardChairN3", "prop_chair_office", Vector3(4.5, FE, 2.05), 180.0, {}],
	["BoardChairS3", "prop_chair_office", Vector3(4.5, FE, 4.95), 0.0, {}],
	["BoardChairN4", "prop_chair_office", Vector3(5.5, FE, 2.05), 180.0, {}],
	["BoardChairS4", "prop_chair_office", Vector3(5.5, FE, 4.95), 0.0, {}],
	["BoardChairN5", "prop_chair_office", Vector3(6.5, FE, 2.05), 180.0, {}],
	["BoardChairS5", "prop_chair_office", Vector3(6.5, FE, 4.95), 0.0, {}],
	["BoardChairN6", "prop_chair_office", Vector3(7.5, FE, 2.05), 180.0, {}],
	["BoardChairS6", "prop_chair_office", Vector3(7.5, FE, 4.95), 0.0, {}],
	["BoardChairW", "prop_chair_office", Vector3(1.35, FE, 3.5), -90.0, {}],
	["BoardChairE", "prop_chair_office", Vector3(8.65, FE, 3.5), 90.0, {}],
	# XL: the lounge's grand piano (west end), a coffee table before the sofa, a rug on the walk to the terrace
	["LoungePiano", "prop_piano_grand", Vector3(2.0, FE, 14.5), 90.0, {}],
	["LoungeCoffeeTable", "prop_coffee_table", Vector3(4.0, FE, 12.3), 0.0, {}],
	["LoungeRug", "prop_rug_rect", Vector3(8.6, FE, 13.0), 90.0, {}],
	# small rooms to their kit density: stores in the electrical risers E2 / E3 and the janitors J1 / J2 (against the west
	# / east walls, clear of the doors on z 7), archive boxes on the RC shelving tops (2.4 m), plant spares in RP
	["RiserE2Boxes", "prop_box_stack", Vector3(10.335, FM, 3.0), -90.0, {}],
	["RiserE2Box", "prop_box_small", Vector3(10.26, FM, 4.2), -90.0, {}],
	["RiserE3Boxes", "prop_box_stack", Vector3(10.335, FE, 3.0), -90.0, {}],
	["RiserE3Box", "prop_box_small", Vector3(10.26, FE, 4.2), -90.0, {}],
	["JanitorJ1Ladder", "prop_step_ladder", Vector3(37.55, FG, 1.2), 90.0, {}],
	["JanitorJ1Boxes", "prop_box_stack", Vector3(37.665, FG, 2.4), 90.0, {}],
	["JanitorJ1Bin", "prop_bin_small", Vector3(35.25, FG, 1.0), 0.0, {}],
	["JanitorJ2Ladder", "prop_step_ladder", Vector3(37.55, FM, 1.2), 90.0, {}],
	["JanitorJ2Boxes", "prop_box_stack", Vector3(37.665, FM, 2.4), 90.0, {}],
	["JanitorJ2Bin", "prop_bin_small", Vector3(35.25, FM, 1.0), 0.0, {}],
	["RecordsBoxes01", "prop_archive_boxes", Vector3(2.0, FB + 2.4, 12.5), 90.0, {}],
	["RecordsBoxes02", "prop_archive_boxes", Vector3(2.0, FB + 2.4, 17.0), 90.0, {}],
	["RecordsBoxes03", "prop_archive_boxes", Vector3(2.0, FB + 2.4, 21.5), 90.0, {}],
	["RecordsBoxes04", "prop_archive_boxes", Vector3(3.8, FB + 2.4, 12.5), 90.0, {}],
	["RecordsBoxes05", "prop_archive_boxes", Vector3(3.8, FB + 2.4, 17.0), 90.0, {}],
	["RecordsBoxes06", "prop_archive_boxes", Vector3(3.8, FB + 2.4, 21.5), 90.0, {}],
	["RecordsBoxes07", "prop_archive_boxes", Vector3(5.6, FB + 2.4, 12.5), 90.0, {}],
	["RecordsBoxes08", "prop_archive_boxes", Vector3(5.6, FB + 2.4, 17.0), 90.0, {}],
	["RecordsBoxes09", "prop_archive_boxes", Vector3(5.6, FB + 2.4, 21.5), 90.0, {}],
	["RecordsBoxes10", "prop_archive_boxes", Vector3(7.4, FB + 2.4, 12.5), 90.0, {}],
	["RecordsBoxes11", "prop_archive_boxes", Vector3(7.4, FB + 2.4, 17.0), 90.0, {}],
	["RecordsBoxes12", "prop_archive_boxes", Vector3(7.4, FB + 2.4, 21.5), 90.0, {}],
	["RecordsBoxes13", "prop_archive_boxes", Vector3(9.2, FB + 2.4, 12.5), 90.0, {}],
	["RecordsBoxes14", "prop_archive_boxes", Vector3(9.2, FB + 2.4, 17.0), 90.0, {}],
	["RecordsBoxes15", "prop_archive_boxes", Vector3(9.2, FB + 2.4, 21.5), 90.0, {}],
	["RecordsBoxes16", "prop_archive_boxes", Vector3(11.0, FB + 2.4, 12.5), 90.0, {}],
	["RecordsBoxes17", "prop_archive_boxes", Vector3(11.0, FB + 2.4, 17.0), 90.0, {}],
	["RecordsBoxes18", "prop_archive_boxes", Vector3(11.0, FB + 2.4, 21.5), 90.0, {}],
	["PlantRoofBoxes1", "prop_box_stack", Vector3(21.0, FR, 9.66), 0.0, {}],
	["PlantRoofBoxes2", "prop_box_stack", Vector3(21.7, FR, 9.66), 0.0, {}],
	["PlantRoofBox", "prop_box_small", Vector3(22.5, FR, 9.73), 0.0, {}],
	["PlantRoofBox2", "prop_box_small", Vector3(23.3, FR, 9.73), 0.0, {}],
	["PlantRoofBoxes3", "prop_box_stack", Vector3(24.6, FR, 9.66), 0.0, {}],
	["PlantRoofTote", "prop_ibc_tote", Vector3(32.8, FR, 9.27), 0.0, {}],
	["PlantRoofCylinders", "prop_gas_cylinders", Vector3(30.5, FR, 9.71), 0.0, {}],
	# stairs: a wall lamp on each landing wall (the stair's south wall, face z 6.85)
	["StairLampSAB", "prop_wall_lamp", Vector3(15.4, FB + 2.45, 6.85), 0.0, {}],
	["StairLampSAG", "prop_wall_lamp", Vector3(15.4, FG + 2.45, 6.85), 0.0, {}],
	["StairLampSAM", "prop_wall_lamp", Vector3(15.4, FM + 2.45, 6.85), 0.0, {}],
	["StairLampSAE", "prop_wall_lamp", Vector3(15.4, FE + 2.45, 6.85), 0.0, {}],
	["StairLampSBB", "prop_wall_lamp", Vector3(47.4, FB + 2.45, 6.85), 0.0, {}],
	["StairLampSBG", "prop_wall_lamp", Vector3(47.4, FG + 2.45, 6.85), 0.0, {}],
	["StairLampSBM", "prop_wall_lamp", Vector3(47.4, FM + 2.45, 6.85), 0.0, {}],
	["StairLampSBE", "prop_wall_lamp", Vector3(47.4, FE + 2.45, 6.85), 0.0, {}],
	["StairLampHH", "prop_wall_lamp", Vector3(15.4, FR + 2.2, 6.85), 0.0, {}],
]
## Light tweaks for the directly placed props (by name prefix): daytime exterior lamps barely on, the stair lamps 5000 K.
const DIRECT_LIGHT: Dictionary = {
	"Lane": {"light_energy": 0.25}, "Tannery": {"light_energy": 0.25}, "Terrace": {"light_energy": 0.15},
	"Stair": {"light_energy": 1.1, "light_color": Color(0.96, 0.98, 1.0)},
}

## Ambience beds (map_audio_builder): [node name, position, cue id, volume offset dB]. The hall in business hours (the
## hall, TW and the gallery), back of house per floor, the vault (VC / VT / SD), the city around the block and up top.
const AUDIO_BEDS: Array = [
	["BedHall", Vector3(24.0, 3.0, 26.0), &"cue.amb_bank_hall_day", 0.0],
	["BedTellerWorkroom", Vector3(24.0, 2.0, 12.5), &"cue.amb_bank_hall_day", -5.0],
	["BedGallery", Vector3(24.0, 6.5, 18.5), &"cue.amb_bank_hall_day", -4.0],
	["BedBOHGround", Vector3(28.0, 1.5, 4.0), &"cue.amb_bank_boh", 0.0],
	["BedBOHGallery", Vector3(24.0, 6.5, 6.0), &"cue.amb_bank_boh", -3.0],
	["BedBOHExecutive", Vector3(24.0, 10.0, 8.0), &"cue.amb_bank_boh", -5.0],
	["BedBOHBasement", Vector3(24.0, -2.5, 5.0), &"cue.amb_bank_boh", -2.0],
	["BedVault", Vector3(24.0, -2.5, 19.0), &"cue.amb_vault", 0.0],
	["BedConcourse", Vector3(24.0, -2.5, 11.0), &"cue.amb_vault", -3.0],
	["BedDepositHall", Vector3(41.0, -2.5, 17.0), &"cue.amb_vault", -4.0],
	["BedPlaza", Vector3(24.0, 1.5, 50.0), &"cue.amb_city_afternoon", 0.0],
	["BedLane", Vector3(16.0, 1.5, -5.0), &"cue.amb_city_afternoon", -3.0],
	["BedTannery", Vector3(55.0, 1.5, 10.0), &"cue.amb_city_afternoon", -3.0],
	["BedTerrace", Vector3(24.0, 10.0, 30.0), &"cue.amb_city_afternoon", -4.0],
	["BedRoof", Vector3(30.0, 13.5, 12.0), &"cue.amb_city_afternoon", -5.0],
]
