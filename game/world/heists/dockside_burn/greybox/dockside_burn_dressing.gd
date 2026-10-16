## Dockside Burn G2 dressing and art data (DB-C2, ENV C): catalog visuals for the map-built props, KitPlacer seeds,
## keep-outs and anchors, the directly placed exterior props, light tweaks and the shadow-casting fixtures. Read by
## db_dress.gd / db_art.gd. Coordinates as dockside_burn_layout.gd (metres, +z south; FFL 0.0, mezzanine 3.6, roof
## 7.2). Floor props: pos = bottom-centre. Wall mounts: pos = the item's centre on the wall face. Yaw: the prop's front
## (-Z) faces 0 north (-z), 180 south (+z), -90 east (+x), 90 west (-x).
extends RefCounted

const M: float = 3.6

## Map-built props (layout PROPS / CHAIRS / gameplay prop_box names) -> [catalog asset, visual yaw relative to the
## body (deg), kind override or "", optional offset]. The body keeps its layout collider, nav obstruction and position; the visual
## replaces the greybox box. Assets are modelled to the layout boxes (tools/blender/props/dockside.py).
const PROP_ART: Dictionary = {
	"ReceptionCounter": ["prop_counter_reception_w300", 180.0, ""],
	"WaitingBench": ["prop_bench_corridor", 90.0, ""],
	"DispatchDesk": ["prop_desk_dispatch", 180.0, ""],
	"GunLocker": ["prop_gun_locker", 90.0, "gun_locker"],
	"Switchboard": ["prop_switchboard", 180.0, ""],
	"BreakTable": ["prop_table_canteen", 0.0, ""],
	"BreakCounter": ["prop_counter_break_w220", 180.0, "kitchen_counter"],
	"Fridge": ["prop_fridge", 180.0, ""],
	"CountingTable": ["prop_counter_count_w240", 0.0, ""],
	"Toilet": ["prop_toilet", 0.0, ""],
	"Sink": ["prop_basin_pedestal", 0.0, ""],
	"ForemanDesk": ["prop_desk_office", 180.0, ""],
	"CompressorA": ["prop_screw_compressor", 180.0, ""],
	"CompressorB": ["prop_screw_compressor", 180.0, ""],
	"CompressorC": ["prop_screw_compressor", 180.0, ""],
	"ReceiverVessel": ["prop_receiver_vessel", 0.0, ""],
	"ControlPanel": ["prop_plant_panel", 0.0, ""],
	"ForkliftA": ["prop_forklift", 0.0, ""],
	"ForkliftB": ["prop_forklift", 0.0, ""],
	"BatteryRack": ["prop_battery_rack", 0.0, ""],
	"ToolBench": ["prop_counter_tool_w200", 0.0, ""],
	"StaffLockers": ["prop_lockers_bank_w300", -90.0, "lockers"],
	"LockerBench": ["prop_bench_locker", 90.0, ""],
	"MopSink": ["prop_mop_sink", 180.0, "mop_sink"],
	"JanitorShelf": ["prop_shelving_janitor", -90.0, "shelving"],
	"PackingConveyor": ["prop_conveyor_roller", 0.0, ""],
	"PackingTableA": ["prop_packing_table_steel", 0.0, ""],
	"PackingTableB": ["prop_packing_table_steel", 0.0, ""],
	"IceMachine": ["prop_ice_machine", 0.0, ""],
	"BoxStackA": ["prop_fish_crates", 0.0, "fish_crates"],
	"BoxStackB": ["prop_fish_crates", 90.0, "fish_crates"],
	"RackC1W": ["prop_racking_coldstore", 0.0, ""],
	"RackC1E": ["prop_racking_coldstore", 180.0, ""],
	"RackC2W": ["prop_racking_coldstore_b", 0.0, ""],  # C2 reads half-empty, fish boxes
	"RackC2E": ["prop_racking_coldstore_b", 180.0, ""],
	"StrongroomShelf": ["prop_shelving_freezer", -90.0, "shelving"],
	"ANPalletA": ["prop_pallet_wrapped", 0.0, ""],
	"ANPalletB": ["prop_pallet_wrapped", 90.0, ""],
	"WrappingMachine": ["prop_pallet_wrapper", 0.0, ""],
	"ANForklift": ["prop_forklift", 0.0, ""],
	"ANPalletC": ["prop_pallet_wrapped", 180.0, ""],
	"ANPalletD": ["prop_pallet_wrapped", -90.0, ""],
	"HallCrateW1": ["prop_shipping_crate_h120", 0.0, ""],
	"HallCrateW2": ["prop_shipping_crate_h180", 90.0, ""],
	"HallCrateW3": ["prop_shipping_crate_h180", 0.0, ""],
	"HallCrateW4": ["prop_shipping_crate_h120", 180.0, ""],
	"HallCrateE1": ["prop_shipping_crate_h120", 90.0, ""],
	"HallCrateE2": ["prop_shipping_crate_h180", 0.0, ""],
	"HallCrateE3": ["prop_shipping_crate_h180", 180.0, ""],
	"HallCrateE4": ["prop_shipping_crate_h120", -90.0, ""],
	"PalletJack": ["prop_pallet_jack", 0.0, ""],
	"GateConsole": ["prop_counter_console_w160", 90.0, ""],
	"GateHeater": ["prop_radiator_heater", 0.0, ""],
	"NetStackA": ["prop_net_pile", 0.0, ""],
	"NetStackB": ["prop_net_pile", 180.0, ""],
	"RopeReels": ["prop_rope_reels", 0.0, ""],
	"ContainerK1": ["prop_container_40_rust", 0.0, ""],
	"ContainerK2": ["prop_container_40_blue", 0.0, ""],
	"ContainerK3": ["prop_container_40_rust", 0.0, ""],
	"ContainerK4": ["prop_container_40_green", 180.0, ""],
	"ContainerK5": ["prop_container_40_rust", 180.0, ""],
	"ContainerK6": ["prop_container_40_blue", 180.0, ""],
	"ContainerD1": ["prop_container_40_green", 0.0, "", Vector3(0.0, 0.0, -0.012)],  # the ladder side flush (zfight)
	"ReachStacker": ["veh_reach_stacker", 0.0, ""],
	"ReeferTrailer": ["veh_reefer_trailer", 0.0, ""],
	"IceBinsA": ["prop_ice_bins", 0.0, ""],
	"IceBinsB": ["prop_ice_bins", 90.0, ""],
	"IceBinsC": ["prop_ice_bins", 0.0, ""],
	"Flatbed": ["veh_flatbed_trailer", 0.0, ""],
	"SkipA": ["prop_skip", 0.0, ""],
	"SkipB": ["prop_skip", 180.0, ""],
	"ApronForklift": ["prop_forklift", 180.0, ""],
	"BollardApronA": ["prop_mooring_bollard", 0.0, ""],
	"BollardApronB": ["prop_mooring_bollard", 0.0, ""],
	"BollardApronC": ["prop_mooring_bollard", 0.0, ""],
	"BollardQuayA": ["prop_mooring_bollard", 0.0, ""],
	"BollardQuayB": ["prop_mooring_bollard", 0.0, ""],
	"BollardQuayC": ["prop_mooring_bollard", 0.0, ""],
	"BollardQuayD": ["prop_mooring_bollard", 0.0, ""],
	"Pier10Bollard": ["prop_mooring_bollard", 0.0, ""],
	"QuayNetsA": ["prop_net_pile_low", 0.0, ""],
	"QuayNetsB": ["prop_net_pile_low", 180.0, ""],
	"QuayIceBins": ["prop_ice_bins", 0.0, ""],
	# gameplay-built boxes (db_gameplay.gd): the empty strongroom's fish blocks, the product pallets under the burn
	"FishBlocks": ["prop_fish_blocks", 0.0, ""],
	"ProductPallet": ["prop_product_pallet", 0.0, ""],
}
## Stacked containers: name -> extra container visuals [asset, height] above the first (D1 two high).
const STACKED: Dictionary = {"ContainerD1": [["prop_container_40_rust", 2.6]]}
## Map-built chairs -> catalog chair (the body keeps its 0.45 box collider and `Seat` marker).
const CHAIR_ART: Dictionary = {
	"DispatchChair": "prop_chair_office", "BreakChairN": "prop_chair_break", "BreakChairS": "prop_chair_break",
	"BreakChairW": "prop_chair_break", "BreakChairE": "prop_chair_break", "CountChair": "prop_chair_office",
	"ForemanChair": "prop_chair_task", "ReceptionChair": "prop_chair_office", "GateChair": "prop_chair_office",
}
## Map-built chairs and the desk / table / counter they face (orientation `faces` links).
const CHAIR_FACES: Dictionary = {
	"DispatchChair": "DispatchDesk", "BreakChairN": "BreakTable", "BreakChairS": "BreakTable", "BreakChairW": "BreakTable",
	"BreakChairE": "BreakTable", "CountChair": "CountingTable", "ForemanChair": "ForemanDesk",
	"ReceptionChair": "ReceptionCounter", "GateChair": "GateConsole",
}

## Kit seed per room (layout variety between same-kit rooms: OC / MC, C1 / C2).
const KIT_SEEDS: Dictionary = {
	"O1": 9101, "O2": 9102, "E1": 9103, "OC": 9104, "PL": 9105, "WS": 9106, "LK": 9107, "J": 9108, "PK": 9109,
	"H": 9110, "C1": 9111, "SP": 9112, "C2": 9213, "SR": 9114, "AN": 9215, "M1": 9116, "M2": 9117, "M3": 9118,
	"MC": 9219, "GH": 9120, "QS": 9121,
}
## Rooms dressed on one box only (multi-box rooms): room -> [x0, z0, x1, z1] wall centre lines.
const DRESS_BOX: Dictionary = {"PK": [0.0, 23.0, 18.0, 32.0]}
## Room keep-outs [x0, y0, z0, x1, y1, z1]: the hall's open floor (lead G2 review; test_dockside_burn_map), the
## chambers' racking aisles (doc: aisles clear), the spine aisle floor, the culvert grate and its approach, the hall
## platform's underside and stair, the strongroom's cash / fish-block floor.
const KEEP_OUT: Dictionary = {
	"H": [[28.6, 0.0, 0.4, 42.4, 2.2, 9.6], [18.15, 0.0, 0.2, 22.3, 3.4, 8.3], [21.6, 0.0, 6.4, 29.6, 3.6, 8.4]],
	"C1": [[23.4, 0.0, 10.2, 26.6, 2.5, 23.8], [18.2, 0.0, 11.9, 20.9, 2.5, 22.1], [29.1, 0.0, 11.9, 31.8, 2.5, 22.1]],
	"C2": [[39.4, 0.0, 10.2, 42.6, 2.5, 23.8], [35.2, 0.0, 11.9, 37.0, 2.5, 22.1], [44.7, 0.0, 11.9, 47.8, 2.5, 22.1]],
	"SP": [[32.4, 0.0, 10.2, 34.6, 2.4, 23.8]],
	"PL": [[0.2, 0.0, 13.4, 3.6, 2.4, 16.6]],
	"SR": [[18.2, 0.0, 26.6, 23.0, 2.4, 31.8]],
	"AN": [[26.2, 0.0, 26.8, 28.6, 2.4, 29.4]],
}
## Rooms whose kit ceiling grid is off (none: every kit room takes its fixtures from the kit).
const NO_CEILING_GRID: Array[String] = []
## Map-built ceiling lights (layout CEILING_LIGHTS) kept: rooms without a kit grid (the head house).
const KEEP_MAP_LIGHTS: Array[String] = ["LightHH"]
## Map-built light fixtures -> catalog model (glb only; the map light stays): ceiling / wall.
const MAP_FIXTURE_ART: Dictionary = {"ceiling": "prop_bulkhead_caged", "wall": "prop_wall_lamp_sodium"}

## Directly placed props (exterior closure dressing, the roof perch plant): [name, asset, pos, yaw, metas].
const DIRECT_PROPS: Array = [
	# X5 office roof (exterior_roof kit: AHU + condensers; the perch at x 10 and the head-house door stay clear)
	["RoofAhuN", "prop_air_handler", Vector3(15.6, 7.2, 0.78), 180.0, {}],
	["RoofAhuS", "prop_air_handler", Vector3(15.6, 7.2, 7.24), 0.0, {}],
	["RoofCondenser1", "prop_hvac_condenser", Vector3(17.54, 7.2, 2.6), 90.0, {}],
	["RoofCondenser2", "prop_hvac_condenser", Vector3(17.54, 7.2, 3.75), 90.0, {}],
	["RoofCondenser3", "prop_hvac_condenser", Vector3(17.54, 7.2, 4.9), 90.0, {}],
	# X1 yard: pallet stacks against the north fence (west of the lane man-gate's swing), totes by the east fence
	["YardPallets1", "prop_pallet_stack", Vector3(3.6, 0.0, -33.53), 180.0, {}],
	["YardPallets2", "prop_pallet_stack", Vector3(4.86, 0.0, -33.53), 180.0, {}],
	["YardTote1", "prop_ibc_tote", Vector3(58.6, 0.0, -33.3), 180.0, {}],
	["YardTote2", "prop_ibc_tote", Vector3(59.65, 0.0, -33.3), 180.0, {}],
	["YardCone1", "prop_traffic_cone", Vector3(-1.6, 0.0, -31.4), 0.0, {}],
	["YardCone2", "prop_traffic_cone", Vector3(-1.0, 0.0, -31.9), 0.0, {}],
	# X3 apron: life rings on the dock wall, a pallet stack and a tote
	["ApronLifeRing1", "prop_life_ring", Vector3(48.2, 1.5, 14.0), -90.0, {}],
	["ApronLifeRing2", "prop_life_ring", Vector3(48.2, 1.5, 20.0), -90.0, {}],
	["ApronPallets", "prop_pallet_stack", Vector3(48.62, 0.0, 17.0), -90.0, {}],
	["ApronTote", "prop_ibc_tote", Vector3(48.83, 0.0, 22.5), -90.0, {}],
	# X4 quay: fish crates, a tote and pallets against the south wall between its doors; the net store's life ring
	["QuayCrates", "prop_fish_crates", Vector3(2.5, 0.0, 32.83), 180.0, {}],
	["QuayTote", "prop_ibc_tote", Vector3(21.5, 0.0, 32.83), 180.0, {}],
	["QuayPallets", "prop_pallet_stack", Vector3(35.5, 0.0, 32.62), 180.0, {}],
	["QuayLifeRing", "prop_life_ring", Vector3(11.85, 1.5, 35.2), 90.0, {}],
]

## Kit fixture light tweaks per room id: asset -> Light3D properties (the catalog defaults suit 3 m ceilings).
const LIGHT_TWEAKS: Dictionary = {
	"M2": {"prop_ceiling_panel_neutral": {"light_color": Color(1.0, 0.86, 0.7)}},
	"PL": {"prop_fluorescent": {"light_energy": 2.0, "spot_range": 7.5, "light_color": Color(1.0, 0.95, 0.86)}},
	"WS": {"prop_fluorescent": {"light_energy": 2.0, "spot_range": 7.5, "light_color": Color(1.0, 0.95, 0.86)}},
	"PK": {"prop_led_batten_cold": {"light_energy": 2.2, "spot_range": 7.0}},
	"H": {"prop_highbay_led": {"light_energy": 2.4, "spot_range": 9.0}},
	"C1": {"prop_led_batten_cold": {"light_energy": 3.2, "spot_range": 11.0}},
	"C2": {"prop_led_batten_cold": {"light_energy": 3.0, "spot_range": 11.0, "light_color": Color(0.82, 0.92, 1.0)}},
	"SP": {"prop_led_batten_cold": {"light_energy": 2.8, "spot_range": 11.0}},
	"AN": {"prop_highbay_led": {"light_energy": 2.6, "spot_range": 8.5, "light_color": Color(0.97, 0.96, 0.92)}},
	"QS": {"prop_fluorescent": {"light_energy": 1.6, "light_color": Color(1.0, 0.9, 0.76)}},
	"GH": {"prop_ceiling_panel_neutral": {"light_color": Color(1.0, 0.9, 0.76)}},
}
## Shadow-casting fixtures (doc Budgets: 1 hall, 1 per chamber, 1 AN; 4 yard masts, see SHADOW_MASTS): the kit fixture
## nearest the target point casts shadows.
const SHADOW_FIXTURES: Array = [
	["H", Vector3(33.0, 5.8, 5.0)], ["C1", Vector3(25.0, 8.0, 17.0)], ["C2", Vector3(41.0, 8.0, 17.0)],
	["AN", Vector3(37.0, 5.8, 28.0)],
]
const SHADOW_MASTS: Array[String] = ["MastYardGate", "MastYardE", "MastQuayMid", "MastFerroW"]
## Rooms without fill lights and the warm (3000-3500 K) fill rooms.
const NO_FILL: Array[String] = ["LF"]
## Tall rooms whose fills hang 2 m under the ceiling near the §3.7 cap (0.29 of 0.3, 12 m) to lift the soffit.
const HIGH_FILL_ROOMS: Array[String] = ["H"]
const WARM_ROOMS: Array[String] = ["M2", "GH", "QS", "SR"]
