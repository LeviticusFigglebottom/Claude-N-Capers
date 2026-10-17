## Shadow Ledger G2 dressing and art data (SL-1, ENV C): catalog visuals for the map-built props, KitPlacer seeds,
## keep-outs, the directly placed props (roof plant, terrace bollards, picture lights), light tweaks per zone and the
## shadow-casting fixtures. Read by sl_dress.gd / sl_art.gd / sl_builder_base.gd. Coordinates as
## shadow_ledger_layout.gd (metres, +z south; L40 FFL 0.0, L41 3.6, L42 8.0, roof 11.6). Floor props: pos =
## bottom-centre. Wall mounts: pos = the item's centre on the wall face. Yaw: the prop's front (-Z) faces 0 north
## (-z), 180 south (+z), -90 east (+x), 90 west (-x).
extends RefCounted

const F41: float = 3.6
const F42: float = 8.0
const FRF: float = 11.6

## Map-built props (layout PROPS names, the gameplay ContractorCart) -> [catalog asset, visual yaw relative to the body
## (deg), kind override or ""]. The body keeps its layout collider, nav obstruction and position; the visual replaces
## the greybox box. Assets are modelled to the layout boxes (tools/blender/props/calder.py).
const PROP_ART: Dictionary = {
	# L40
	"FreightDolly": ["prop_freight_dolly", 0.0, ""],
	"SignInLectern": ["prop_lectern_signin", 180.0, ""],
	"RecyclingCage": ["prop_recycling_cage", 90.0, ""],
	# K1 / K2 / K3 / K4 / K5
	"KesslerDesk": ["prop_desk_exec", 0.0, ""],
	"KesslerCredenza": ["prop_credenza_w200", 180.0, "credenza"],
	"KesslerSofa": ["prop_sofa_w200", 90.0, ""],
	"KesslerShelves": ["prop_bookcase_w160", 90.0, "bookshelf"],
	"ConferenceTable": ["prop_table_conference_l360", 90.0, ""],
	"ConferenceCredenza": ["prop_credenza_w200_d40", -90.0, "credenza"],
	"ReceptionDesk": ["prop_reception_desk_exec", 0.0, ""],
	"LoungeChairW": ["prop_armchair_club", 0.0, ""],
	"LoungeChairE": ["prop_armchair_club", 0.0, ""],
	"AssistantDeskA": ["prop_desk_office", 0.0, ""],
	"AssistantDeskB": ["prop_desk_office", 0.0, ""],
	"AssistantPrinter": ["prop_printer_mfp", 90.0, ""],
	"MoorDesk": ["prop_desk_exec", 0.0, ""],
	"MoorMeetingTable": ["prop_table_round_d120", 0.0, ""],
	# K8 / J41 / K11 / K12 / K13 / K14 / K15
	"WorkstationsA": ["prop_workstation_pod", 0.0, ""],
	"WorkstationsB": ["prop_workstation_pod", 0.0, ""],
	"WorkstationsC": ["prop_workstation_pod", 0.0, ""],
	"OpenOfficePrinter": ["prop_printer_mfp", 90.0, ""],
	"MopSink": ["prop_mop_sink_w90", 0.0, "mop_sink"],
	"LedgerRackW": ["prop_server_rack_pair", 180.0, "server_rack"],
	"LedgerRackE": ["prop_server_rack_pair", 180.0, "server_rack"],
	"CracUnit": ["prop_crac_unit", 0.0, ""],
	"UpsUnit": ["prop_ups_tower", 180.0, ""],
	"ITDeskA": ["prop_desk_office", 0.0, ""],
	"ITDeskB": ["prop_desk_office", 0.0, ""],
	"ITSpares": ["prop_shelving_it_w160", 90.0, "shelving"],
	"KeyCabinet": ["prop_key_cabinet_floor", 180.0, "key_cabinet"],
	"SecurityCounter": ["prop_counter_security_w140", 0.0, ""],
	"SecurityLockers": ["prop_lockers_w120", 180.0, "lockers"],
	"SwitchboardL41": ["prop_switchboard_w200", 180.0, ""],
	"Copier": ["prop_copier", 180.0, ""],
	# K17 - K24, the washrooms
	"CompactShelvingA": ["prop_compact_shelving_w400", 0.0, "shelving"],
	"CompactShelvingB": ["prop_compact_shelving_w400", 0.0, "shelving"],
	"BreakCounter": ["prop_counter_kitchen_w300", 0.0, "kitchen_counter"],
	"BreakFridge": ["prop_fridge_w70", 0.0, ""],
	"BreakTable": ["prop_table_break_l160", 0.0, ""],
	"LibraryStacksA": ["prop_library_stack_w400", 0.0, "bookshelf"],
	"LibraryStacksB": ["prop_library_stack_w400", 0.0, "bookshelf"],
	"K20Desk": ["prop_desk_office", 0.0, ""],
	"K21Desk": ["prop_desk_office", 0.0, ""],
	"K22Desk": ["prop_desk_office", 0.0, ""],
	"K23Desk": ["prop_desk_office", 0.0, ""],
	"InterviewTable": ["prop_table_round_d120", 0.0, ""],
	"SinkCounterWL41": ["prop_vanity_w240", 0.0, ""],
	"SinkCounterML41": ["prop_vanity_w240", 0.0, ""],
	"SinkCounterWL42": ["prop_vanity_w240", 0.0, ""],
	"SinkCounterML42": ["prop_vanity_w240", 0.0, ""],
	# L42
	"LoungeBar": ["prop_bar_lounge_w300", 0.0, ""],  # the backlit teal front faces the room (south)
	"SofaGroupW": ["prop_sofa_w220", 0.0, ""],
	"SofaGroupE": ["prop_sofa_w220", 0.0, ""],
	"LoungeCoffeeTable": ["prop_coffee_table_w100", 0.0, "coffee_table"],
	"Piano": ["prop_piano_grand", 180.0, ""],
	"PlinthGalleryA": ["prop_plinth_sculpture_a", 0.0, "sculpture"],
	"PlinthGalleryB": ["prop_plinth_sculpture_b", 0.0, "sculpture"],
	"PlinthArtHall": ["prop_plinth_sculpture_b", 90.0, "sculpture"],
	"StudyDesk": ["prop_desk_exec", 0.0, ""],
	"StudyShelves": ["prop_bookcase_w240", 90.0, "bookshelf"],
	"StudyArmchair": ["prop_armchair_club", 90.0, ""],
	"GuestBed": ["prop_bed_queen", -90.0, ""],
	"NightstandN": ["prop_nightstand", -90.0, ""],
	"NightstandS": ["prop_nightstand", -90.0, ""],
	"GuestWardrobe": ["prop_wardrobe_w160", 180.0, ""],
	"BathVanity": ["prop_vanity_w200", 0.0, ""],
	"DressingWardrobes": ["prop_wardrobe_w160_d50", 0.0, ""],
	"DiningTable": ["prop_table_dining_l360", 0.0, ""],
	"DiningSideboard": ["prop_sideboard_w240", 180.0, "credenza"],
	"WineFridge": ["prop_wine_fridge", 180.0, ""],
	"LinenShelves": ["prop_shelving_linen", -90.0, "shelving"],
	"CleanerCartL42": ["prop_cleaner_cart", 0.0, "cleaning_cart"],
	"PantryCounter": ["prop_counter_pantry_w350", 180.0, "kitchen_counter"],
	"PantryFridge": ["prop_fridge_w70", 180.0, ""],
	"PantryTable": ["prop_table_round_d120", 0.0, ""],
	"SubBoardL42": ["prop_switchboard_w200", 0.0, ""],
	"WineRacks": ["prop_wine_rack_w260", 180.0, "shelving"],
	"Humidor": ["prop_humidor_cabinet", 90.0, ""],
	"BoardroomTable": ["prop_table_boardroom_l480", 90.0, ""],
	"BoardroomCredenza": ["prop_credenza_w200", 180.0, "credenza"],
	# terrace, roof
	"PlanterA": ["prop_planter_terrace", 0.0, ""],
	"PlanterB": ["prop_planter_terrace", 0.0, ""],
	"PlanterC": ["prop_planter_terrace", 0.0, ""],
	"PlanterD": ["prop_planter_terrace", 0.0, ""],
	"LoungerA": ["prop_lounger", 180.0, ""],
	"LoungerB": ["prop_lounger", 180.0, ""],
	"OutdoorKitchen": ["prop_outdoor_kitchen", 180.0, ""],
	"PatioHeaterA": ["prop_patio_heater_slim", 0.0, ""],
	"PatioHeaterB": ["prop_patio_heater_slim", 0.0, ""],
	"AirHandlerRoof": ["prop_ahu_roof", 0.0, ""],
	"Chiller": ["prop_chiller_roof", 0.0, ""],
	"WaterTank": ["prop_water_tank_roof", 0.0, ""],
	"LiftMotors": ["prop_lift_motors", 0.0, ""],
	"BMUMachine": ["prop_bmu_machine", 0.0, ""],
	"CradleGarage": ["prop_cradle_garage", 180.0, ""],
	"InsertionAnchor": ["prop_anchor_frame_h140", 0.0, ""],
	"E2AnchorFrame": ["prop_anchor_frame_h220", 0.0, ""],
	# gameplay-built (sl_gameplay.gd, code_contractor slot)
	"ContractorCart": ["prop_it_trolley", 0.0, ""],
}
## Map-built chairs -> catalog chair (the body keeps its 0.45 box collider and `Seat` marker; layout CHAIRS carry their
## `faces` desk).
const CHAIR_ART: Dictionary = {
	# the reception seat is 0.48 m wide: the reception alarm's UsePoint stays clear (furniture_logic)
	"ReceptionChair": "prop_chair_consult", "KesslerChair": "prop_chair_office", "MoorChair": "prop_chair_office",
	"StudyChair": "prop_chair_office",
	"ConfChairW1": "prop_chair_office", "ConfChairW2": "prop_chair_office", "ConfChairW3": "prop_chair_office",
	"ConfChairE1": "prop_chair_office", "ConfChairE2": "prop_chair_office", "ConfChairE3": "prop_chair_office",
	"BreakChairS1": "prop_chair_break", "BreakChairS2": "prop_chair_break", "BreakChairW": "prop_chair_break",
	"BreakChairE": "prop_chair_break",
	"DiningChairN1": "prop_chair_consult", "DiningChairN2": "prop_chair_consult", "DiningChairS1": "prop_chair_consult",
	"DiningChairS2": "prop_chair_consult", "DiningChairW": "prop_chair_consult", "DiningChairE": "prop_chair_consult",
	"BoardChairW1": "prop_chair_office", "BoardChairW2": "prop_chair_office", "BoardChairW3": "prop_chair_office",
	"BoardChairW4": "prop_chair_office", "BoardChairE1": "prop_chair_office", "BoardChairE2": "prop_chair_office",
	"BoardChairE3": "prop_chair_office", "BoardChairE4": "prop_chair_office", "BoardChairHead": "prop_chair_office",
	"MoorMeetChairN": "prop_chair_visitor", "MoorMeetChairW": "prop_chair_visitor", "MoorMeetChairE": "prop_chair_visitor",
	"InterviewChairN": "prop_chair_visitor", "InterviewChairS1": "prop_chair_visitor",
	"InterviewChairS2": "prop_chair_visitor",
	"PantryChairW": "prop_chair_break", "PantryChairE": "prop_chair_break", "PantryChairS": "prop_chair_break",
	"AssistantChairA": "prop_chair_office", "AssistantChairB": "prop_chair_office",
	"PodAChairN1": "prop_chair_office", "PodAChairN2": "prop_chair_office", "PodAChairS1": "prop_chair_office",
	"PodAChairS2": "prop_chair_office", "PodBChairN1": "prop_chair_office", "PodBChairN2": "prop_chair_office",
	"PodBChairS1": "prop_chair_office", "PodBChairS2": "prop_chair_office", "PodCChairN1": "prop_chair_office",
	"PodCChairN2": "prop_chair_office", "PodCChairS1": "prop_chair_office", "PodCChairS2": "prop_chair_office",
	"ITChairA": "prop_chair_office", "ITChairB": "prop_chair_office",
	"K20Chair": "prop_chair_office", "K21Chair": "prop_chair_office", "K22Chair": "prop_chair_office",
	"K23Chair": "prop_chair_office",
}

## Kit seed per room (layout variety between same-kit rooms: K20-K23, the four washrooms, the corridors, K18 / M11).
const KIT_SEEDS: Dictionary = {
	"S1": 9301, "S2": 9302, "S3": 9303, "J41": 9304, "J42": 9305, "WCW41": 9306, "WCM41": 9407, "WCW42": 9508,
	"WCM42": 9609, "K1": 9310, "K2": 9311, "K3": 9312, "K4": 9313, "K5": 9414, "K6": 9315, "K7": 9416, "K8": 9317,
	"K9": 9318, "K10": 9319, "K11": 9320, "K12": 9321, "K13": 9322, "K14": 9323, "K15": 9324, "K16": 9325, "K17": 9326,
	"K18": 9327, "K19": 9328, "K20": 9329, "K21": 9430, "K22": 9531, "K23": 9632, "K24": 9333, "M1": 9334,
	"M2": 9335, "M3": 9336, "M4": 9337, "M5": 9338, "M6": 9339, "M7": 9340, "M8": 9341, "M9": 9442, "M10": 9543,
	"M11": 9444, "M12": 9545, "M13": 9346, "M14": 9347, "M15": 9348, "R1": 9349, "R3": 9350,
}
## Room keep-outs [x0, y0, z0, x1, y1, z1]: the reception's lift fronts, stair foot and logo wall; the gallery walkway
## along the void and the stair arrival; the art hall east of the laser plane (paintings, study door) and the plane
## itself; the cage and its gate; the camera operator's place at the monitor wall; the body-hide corners; the
## cleaner / rover routes through the long rooms.
const KEEP_OUT: Dictionary = {
	"K3": [[15.4, F41, 6.0, 20.6, F41 + 2.6, 7.4], [12.1, F41, 2.2, 14.2, F41 + 2.6, 3.6],
		[12.1, F41, 2.2, 20.6, F41 + 3.8, 4.1],
		[23.3, F41, 2.4, 23.9, F41 + 3.6, 4.8], [16.4, F41, 4.0, 19.6, F41 + 2.6, 6.0]],
	"M2": [[12.1, F42, 4.06, 20.45, F42 + 2.8, 6.25], [20.5, F42, 0.2, 23.0, F42 + 2.8, 2.8],
		[20.5, F42, 2.8, 23.9, F42 + 2.8, 5.8]],
	"M3": [[26.1, F42, 0.2, 28.9, F42 + 3.0, 7.4], [24.05, F42, 0.9, 25.1, F42 + 3.0, 5.1]],
	"K11": [[26.85, F41, 8.25, 30.65, F41 + 2.6, 10.65], [27.9, F41, 10.5, 29.3, F41 + 2.6, 11.9]],
	"K13": [[27.9, F41, 12.9, 30.0, F41 + 2.6, 16.1]],
	"J41": [[12.2, F41, 9.1, 14.8, F41 + 2.0, 10.3]],
	"J42": [[12.2, F42, 9.1, 14.8, F42 + 2.0, 9.8]],
	"R3": [[15.2, FRF, 14.4, 18.7, FRF + 2.0, 16.3]],
	"K8": [[0.2, F41, 11.7, 10.4, F41 + 2.6, 12.4]],
	# K17: the route door -> north strip -> east aisle -> south strip -> safe stays clear (kit only west of the door)
	"K17": [[0.2, F41, 20.0, 5.9, F41 + 2.4, 20.8], [0.2, F41, 19.15, 1.1, F41 + 2.4, 23.8],
		[2.3, F41, 18.1, 5.9, F41 + 2.4, 19.25], [4.9, F41, 18.6, 5.9, F41 + 2.4, 23.8], [0.2, F41, 21.55, 5.9, F41 + 2.4, 23.8]],
	"K19": [[12.1, F41, 21.0, 17.9, F41 + 2.4, 22.1]],
	"M8": [[0.2, F42, 13.1, 10.4, F42 + 2.6, 13.6]],
	# K16 (SL-1 polish): the bench by K8 and the mail trolley by K13 (DIRECT_PROPS) keep the kit's wall items off them
	"K16": [[6.2, F41, 16.5, 7.8, F41 + 2.4, 17.15], [26.35, F41, 16.5, 27.45, F41 + 2.4, 17.15]],
	# S1 (SL-1 polish): the post room's mail trolley by the S3 opening (DIRECT_PROPS)
	"S1": [[25.5, 0.0, 11.9, 26.5, 2.4, 12.5]],
}
## Rooms whose doors get a room sign beside them (sl_dress._door_signs, SL-1 polish): the asset, its centre height
## and its offset from the door's centre line past the leaf's half width (clear of the frame, on the handle side).
const DOOR_SIGN_ROOMS: Array[String] = ["K16"]
const DOOR_SIGN_ASSET: String = "prop_door_sign"
const DOOR_SIGN_Z: float = 1.5
const DOOR_SIGN_OFFSET: float = 0.32
## Desk-mounted screens on the map-built desks (sl_dress._desk_screens): host catalog asset -> screen asset.
const DESK_SCREENS: Dictionary = {"prop_workstation_pod": "prop_pod_screen"}
## Rooms whose kit ceiling grid is off (none).
const NO_CEILING_GRID: Array[String] = []
## Map-built ceiling lights (layout / build_greybox) kept: rooms without a kit (the stairs, the head house) and the
## reception void.
const KEEP_MAP_LIGHTS: Array[String] = ["LightReceptionVoid", "LightSA0", "LightSA1", "LightSA2", "LightSA3", "LightSB0",
	"LightSB1", "LightSB2", "LightR2"]
## Map-built light fixtures -> catalog model (glb only; the map light stays).
const MAP_FIXTURE_ART: Dictionary = {"ceiling": "prop_ceiling_panel_cool", "void": "prop_led_linear"}

## Directly placed props: [name, asset, pos, yaw, metas]. Picture lights over the art hall's paintings; the roof's
## packaged plant on the open roof (exterior_roof_tower kit: ahu, hvac) and its floods; terrace LED bollards.
const DIRECT_PROPS: Array = [
	# M3 paintings (Gameplay/Misc/Painting1/2 on the south wall face z 7.4, centre 1.6 m)
	["PictureLightP1", "prop_picture_light", Vector3(27.3, F42 + 2.25, 7.4), 0.0, {}],
	["PictureLightP2", "prop_picture_light", Vector3(28.3, F42 + 2.25, 7.4), 0.0, {}],
	# Roof (X2): condensers on the plant block's east face and a packaged AHU by the BMU rail end
	["RoofCondenser1", "prop_hvac_condenser", Vector3(24.405, FRF, 10.2), -90.0, {}],
	["RoofCondenser2", "prop_hvac_condenser", Vector3(24.405, FRF, 11.4), -90.0, {}],
	["RoofCondenser3", "prop_hvac_condenser", Vector3(24.405, FRF, 12.6), -90.0, {}],
	["RoofAhuPackaged", "prop_air_handler", Vector3(13.3, FRF, 6.82), 0.0, {}],
	# roof floods on the plant block (wall lamps by the head-house door, over the plant door, the pad side, south)
	["RoofLampHeadHouse", "prop_wall_lamp", Vector3(11.85, FRF + 2.6, 14.4), 90.0, {}],
	["RoofLampPlantN", "prop_wall_lamp", Vector3(21.0, FRF + 2.6, 7.35), 0.0, {}],
	["RoofLampPlantE", "prop_wall_lamp", Vector3(24.15, FRF + 2.6, 14.6), -90.0, {}],
	["RoofLampPlantS", "prop_wall_lamp", Vector3(18.0, FRF + 2.6, 16.65), 180.0, {}],
	# terrace (X1): LED bollards along the planters and by the loungers
	["TerraceBollard1", "prop_bollard_led", Vector3(1.0, F42, 22.9), 0.0, {}],
	["TerraceBollard2", "prop_bollard_led", Vector3(8.0, F42, 23.4), 0.0, {}],
	["TerraceBollard3", "prop_bollard_led", Vector3(16.0, F42, 23.4), 0.0, {}],
	["TerraceBollard4", "prop_bollard_led", Vector3(24.0, F42, 23.4), 0.0, {}],
	["TerraceBollard5", "prop_bollard_led", Vector3(31.6, F42, 23.4), 0.0, {}],
	# SL-1 polish. K16 spine: a bench against the K8 wall and the internal-mail trolley parked by K13, against the north
	# wall (face z 16.6), between the patrol points and clear of the door zones (the 1.3 m spine keeps >= 0.85 m)
	["SpineBench", "prop_bench_corridor", Vector3(7.0, F41, 16.85), 180.0, {}],
	["SpineMailTrolley", "prop_mail_trolley", Vector3(26.9, F41, 16.83), 180.0, {}],
	# S1 service lobby: the post room's mail trolley against the south wall beside the S3 opening (outside the E3 escape
	# zone, z <= 11.4, and the spawns), a notice and the service lift's sign on the lift wall (x 24.15, wall mounts)
	["LobbyMailTrolley", "prop_mail_trolley", Vector3(26.0, 0.0, 12.19), 0.0, {}],
	["LobbyNoticeLift", "prop_notice_frame", Vector3(24.15, 1.5, 11.0), -90.0, {}],
	["LobbySignLift", "prop_door_sign", Vector3(24.15, 1.5, 10.25), -90.0, {}],
	# roof: the helipad windsock, clamped to the plant block's north face (z 7.35) by its NE corner, the sock streaming
	# north at 4 m, seen from the pad and its approach (clear of the C10 pole round the corner and the plant lamp)
	["HelipadWindsock", "prop_windsock", Vector3(23.4, FRF + 2.206, 7.35), 0.0, {}],
]

## Kit fixture light tweaks per room id: asset -> Light3D properties. Offices and corridors run their 4000 K panels at
## the night level (doc: 30 %; here ~45 % with the fills), BOH 5000 K, the security room dim and blue, the server room
## 6500 K, the executive downlights 3000 K pools.
const _NIGHT_PANEL: Dictionary = {"prop_ceiling_panel_neutral": {"light_energy": 0.75, "light_color": Color(1.0, 0.91, 0.8)}}
const _BOH_PANEL: Dictionary = {"prop_ceiling_panel_cool": {"light_energy": 1.1, "light_color": Color(0.95, 0.97, 1.0)}}
const _EXEC: Dictionary = {"prop_downlight": {"light_energy": 1.6, "light_color": Color(1.0, 0.78, 0.55)}}
const LIGHT_TWEAKS: Dictionary = {
	"K4": _NIGHT_PANEL, "K8": _NIGHT_PANEL, "K12": _NIGHT_PANEL, "K15": _NIGHT_PANEL, "K20": _NIGHT_PANEL,
	"K21": _NIGHT_PANEL, "K22": _NIGHT_PANEL, "K23": _NIGHT_PANEL, "K24": _NIGHT_PANEL, "K6": _NIGHT_PANEL,
	"K7": _NIGHT_PANEL, "K9": _NIGHT_PANEL, "K16": _NIGHT_PANEL, "M9": _NIGHT_PANEL, "K10": _NIGHT_PANEL,
	"M10": _NIGHT_PANEL, "S3": _NIGHT_PANEL,
	"S1": _BOH_PANEL, "K11": {"prop_ceiling_panel_cool": {"light_energy": 1.2, "light_color": Color(0.85, 0.92, 1.0)}},
	"K13": {"prop_ceiling_panel_neutral": {"light_energy": 0.45, "light_color": Color(0.7, 0.8, 1.0)}},
	"K18": {"prop_ceiling_panel_neutral": {"light_energy": 1.1, "light_color": Color(1.0, 0.86, 0.7)}},
	"M11": {"prop_ceiling_panel_neutral": {"light_energy": 1.1, "light_color": Color(1.0, 0.9, 0.78)}},
	"K1": _EXEC, "K2": _EXEC, "K3": _EXEC, "K5": _EXEC, "K19": _EXEC, "M1": _EXEC, "M2": _EXEC, "M3": _EXEC,
	"M4": _EXEC, "M5": _EXEC, "M8": _EXEC, "M14": _EXEC, "M15": _EXEC,
}
## Shadow-casting fixtures (doc: readable shadows for stealth in the executive spaces): the kit fixture nearest the
## target casts shadows. <= 8 shadowed lights in any review view.
const SHADOW_FIXTURES: Array = [
	["K3", Vector3(17.0, F41 + 3.6, 5.0)], ["M2", Vector3(16.0, F42 + 3.0, 6.0)], ["M1", Vector3(6.0, F42 + 3.0, 4.0)],
	["M4", Vector3(32.0, F42 + 3.0, 3.0)], ["K8", Vector3(5.0, F41 + 3.0, 12.0)],
]
## Rooms without fill lights and the warm (3000-3500 K) fill rooms; the dim rooms' fills run lower.
const NO_FILL: Array[String] = ["LF1", "LF2", "SL", "SA", "SB"]
const WARM_ROOMS: Array[String] = ["K1", "K2", "K3", "K5", "K18", "K19", "M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8",
	"M11", "M13", "M14", "M15", "WCW41", "WCM41", "WCW42", "WCM42"]
const DIM_FILL_ROOMS: Array[String] = ["K13", "K11"]
