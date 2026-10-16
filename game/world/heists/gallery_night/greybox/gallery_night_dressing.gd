## Gallery Night G2 dressing data (GN-C2, ENV C): KitPlacer anchors, keep-outs, seeds, the directly placed exterior
## props and light tweaks. Read by gn_dress.gd. Coordinates as gallery_night_layout.gd (metres, plan origin = the NW
## building corner on the wall centre lines, +z south; FFL B -4.2, G 0.0, U 5.4, R 9.0).
## Floor props: pos = bottom-centre. Wall mounts: pos = the centre of the item on the wall face. Ceiling mounts: pos =
## the ceiling point. Yaw: the prop's front (-Z) faces 0 north (-z), 180 south (+z), -90 east (+x), 90 west (-x).
## Rules from the doc (Room list notes): benches, plinths and stanchions stay >= 2.0 m off hung gallery walls (KEEP_OUT
## bands), every inspection PatrolPoint keeps its 0.73 m (markers are keep-outs), NPC idle points >= 1 m off doors.
extends RefCounted

const G: float = 0.0
const U: float = 5.4
## Hall chandelier mount (the coffered laylight's plane) and the gallery ceilings.
const HALL_CEIL: float = 9.8

## [room, name, catalog asset, pos, yaw_deg, metas]. Metas: `faces_anchor`, `faces_node` (a map path), else node metas.
const ANCHORS: Array = [
	# GH gala (the bar itself is map-built, gn_content support_prop): three bronze ring chandeliers in the coffer bays
	# (2700 K, 70%), the landing spot on the centrepiece, eight linen cocktail tables clear of the patrol / patron points
	# and the stair, two gallery benches under the colonnades, the string trio's stands by the east colonnade, the
	# walk-through velvet rope at the stair foot (no collider: next_heist §7.9 "or none").
	["GH", "ChandelierW", "prop_chandelier_ring", Vector3(17.0, HALL_CEIL, 21.0), 0.0, {}],
	["GH", "ChandelierE", "prop_chandelier_ring", Vector3(27.0, HALL_CEIL, 21.0), 0.0, {}],
	["GH", "ChandelierN", "prop_chandelier_ring", Vector3(23.0, HALL_CEIL, 13.0), 0.0, {}],
	["GH", "LandingSpot", "prop_track_light", Vector3(21.0, HALL_CEIL, 9.0), 0.0, {}],
	["GH", "CocktailTable1", "prop_cocktail_table", Vector3(17.8, G, 18.5), 0.0, {}],
	["GH", "CocktailTable2", "prop_cocktail_table", Vector3(21.8, G, 23.2), 0.0, {}],
	["GH", "CocktailTable3", "prop_cocktail_table", Vector3(26.5, G, 18.0), 0.0, {}],
	["GH", "CocktailTable4", "prop_cocktail_table", Vector3(15.6, G, 24.2), 0.0, {}],
	["GH", "CocktailTable5", "prop_cocktail_table", Vector3(28.4, G, 24.2), 0.0, {}],
	["GH", "CocktailTable6", "prop_cocktail_table", Vector3(18.8, G, 12.6), 0.0, {}],
	["GH", "CocktailTable7", "prop_cocktail_table", Vector3(25.2, G, 12.6), 0.0, {}],
	["GH", "CocktailTable8", "prop_cocktail_table", Vector3(14.1, G, 21.6), 0.0, {}],
	["GH", "BenchW", "prop_bench_gallery", Vector3(13.5, G, 10.6), 90.0, {}],
	["GH", "BenchE", "prop_bench_gallery", Vector3(30.5, G, 10.6), -90.0, {}],
	["GH", "TrioStand1", "prop_music_stand", Vector3(29.6, G, 13.4), 45.0, {}],
	["GH", "TrioStand2", "prop_music_stand", Vector3(30.6, G, 14.4), 75.0, {}],
	["GH", "TrioStand3", "prop_music_stand", Vector3(30.9, G, 12.6), 20.0, {}],
	["GH", "VelvetRope", "prop_stanchion_velvet", Vector3(22.0, G, 15.05), 0.0, {}],
	# VE: the guest-list lectern beside the inner screen, a velvet rope run along the west wall
	["VE", "GuestLectern", "prop_lectern", Vector3(24.7, G, 27.2), 180.0, {}],
	["VE", "VestibuleRope", "prop_stanchion_velvet", Vector3(19.3, G, 27.5), 90.0, {}],
	# EB: the gala's silent-auction table (catalogues) mid-room
	["EB", "AuctionTable", "prop_consult_table", Vector3(36.5, G, 28.6), 0.0, {}],
	["EB", "BenchEB", "prop_bench_gallery", Vector3(41.2, G, 28.6), 180.0, {}],
	# BR: the staff table (the kit seats its chairs round it), J: the mop sink on the west wall
	["BR", "BreakTable", "prop_table_break", Vector3(4.6, G, 2.3), 0.0, {}],
	["J", "MopSink", "prop_mop_sink", Vector3(24.42, G, 3.4), -90.0, {}],
	# CS: the conservator's two studio easels by the north light, the suction table
	["CS", "EaselN", "prop_easel_studio", Vector3(39.5, U, 4.0), 180.0, {}],
	["CS", "EaselE", "prop_easel_studio", Vector3(42.0, U, 6.5), 90.0, {}],
	["CS", "SuctionTable", "prop_suction_table", Vector3(35.6, U, 2.0), 0.0, {}],
	# AS: plan chests along the south wall between the racks and the lockers
	["AS", "PlanChestS1", "prop_plan_chest", Vector3(14.5, -4.2, 19.29), 180.0, {}],
	["AS", "PlanChestS2", "prop_plan_chest", Vector3(16.0, -4.2, 19.29), 180.0, {}],
	# PL: the inert-gas suppression cylinder bank on the south wall
	["PL", "GasBankA", "prop_gas_cylinders", Vector3(5.0, -4.2, 19.6), 180.0, {}],
	["PL", "GasBankB", "prop_gas_cylinders", Vector3(8.0, -4.2, 19.6), 180.0, {}],
	# SC: the wall key cabinet over the key chest (kc_security) on the east wall
	["SC", "KeyCabinet", "prop_key_cabinet", Vector3(17.9, 1.85, 3.0), 90.0, {}],
	# TR: a bench facing the painting wall (south), north of the laser grid, clear of the door
	["TR", "TreasuryBench", "prop_bench_gallery", Vector3(42.0, U, 25.3), 180.0, {}],
	# BW: a bench against the west wall facing the hall and a bronze on its plinth (the strip is too narrow for the kit)
	["BW", "BalconyBenchW", "prop_bench_gallery", Vector3(12.65, U, 17.0), -90.0, {}],
	["BW", "BalconyBronzeW", "prop_plinth_bronze_a", Vector3(12.6, U, 22.5), -90.0, {}],
]

## Kit seed per room (layout variety between same-kit rooms).
const KIT_SEEDS: Dictionary = {
	"WG": 7101, "EG": 7202, "EB": 7303, "UG1": 7404, "UG2": 7505, "UG3": 7606, "BW": 7707, "BE": 7808, "SL": 7909,
	"PWW": 8101, "PWM": 8202, "FR": 8313, "FS": 8404, "BB": 8505, "BC": 8606, "UC": 8707, "SC": 8808,
}
## Rooms whose kit ceiling grid is off (designed fixtures / open to the hall).
const NO_CEILING_GRID: Array[String] = ["GH", "BW", "BE", "SL"]
## Rooms without fill lights (the shafts) and the warm (2700-3000 K) fill rooms.
const NO_FILL: Array[String] = ["SS", "LF", "HH"]
const WARM_ROOMS: Array[String] = ["GH", "WG", "EG", "EB", "DC", "VE", "CK", "GS", "UG1", "UG2", "UG3", "BW", "BE", "SL",
	"TR", "CO", "PWW", "PWM"]
## Clear-interior overrides [x0, z0, x1, z1] (none: the rooms are inside their walls' faces).
const CLEAR: Dictionary = {}
## Catalog assets placed without a collider / nav obstruction (the walk-through velvet rope).
const NO_COLLIDE: Array[String] = ["prop_stanchion_velvet"]

## The grand stair (GH) and its upper landings: [x0, y0, z0, x1, y1, z1] keep-outs (flights, the floor under the half
## landing, the landings' approach on the balconies).
const STAIR_KEEP_OUT: Array = [
	[20.5, 0.0, 9.9, 23.5, 3.0, 15.0], [15.0, 0.0, 8.0, 29.0, 2.6, 10.4], [14.9, 0.0, 10.1, 16.7, 5.4, 14.7],
	[27.3, 0.0, 10.1, 29.1, 5.4, 14.7], [13.4, 5.4, 13.8, 15.0, 7.5, 17.0], [29.0, 5.4, 13.8, 30.6, 7.5, 17.0],
]

## Per-room keep-outs [x0, y0, z0, x1, y1, z1]: the galleries' 1.9 m bands along every hung wall (benches and plinths
## >= 2 m off hung works), the hall's axis from the vestibule to the stair, the balconies' walkway along the rail.
const KEEP_OUT: Dictionary = {
	"WG": [[0.0, 0.0, 8.0, 12.0, 2.4, 10.0], [0.0, 0.0, 18.0, 12.0, 2.4, 20.0], [0.0, 0.0, 8.0, 2.0, 2.4, 20.0],
		[10.0, 0.0, 8.0, 12.0, 2.4, 20.0]],
	"EG": [[32.0, 0.0, 12.0, 44.0, 2.4, 14.0], [32.0, 0.0, 22.0, 44.0, 2.4, 24.0], [32.0, 0.0, 12.0, 34.0, 2.4, 24.0],
		[42.0, 0.0, 12.0, 44.0, 2.4, 24.0]],
	"EB": [[32.0, 0.0, 24.0, 34.2, 2.4, 30.0], [41.8, 0.0, 24.0, 44.0, 2.4, 30.0], [32.0, 0.0, 24.0, 44.0, 2.4, 25.4]],
	"UG1": [[0.0, 5.4, 8.0, 12.0, 7.8, 10.0], [0.0, 5.4, 18.0, 12.0, 7.8, 20.0], [0.0, 5.4, 8.0, 2.0, 7.8, 20.0],
		[10.0, 5.4, 8.0, 12.0, 7.8, 20.0], [5.0, 5.4, 11.0, 8.0, 7.8, 17.0]],
	"UG2": [[0.0, 5.4, 20.0, 12.0, 7.8, 22.0], [0.0, 5.4, 28.0, 12.0, 7.8, 30.0], [0.0, 5.4, 20.0, 2.0, 7.8, 30.0],
		[10.0, 5.4, 20.0, 12.0, 7.8, 30.0]],
	"UG3": [[32.0, 5.4, 12.0, 44.0, 7.8, 14.0], [32.0, 5.4, 22.0, 44.0, 7.8, 24.0], [32.0, 5.4, 12.0, 34.0, 7.8, 24.0],
		[42.0, 5.4, 12.0, 44.0, 7.8, 24.0], [37.0, 5.4, 13.0, 39.0, 7.8, 18.0]],
	"GH": [[20.0, 0.0, 15.0, 24.0, 3.0, 26.0]],
	"BW": [[14.0, 5.4, 8.0, 15.0, 7.5, 26.0]],
	"BE": [[29.0, 5.4, 8.0, 30.0, 7.5, 26.0]],
	"SL": [[12.0, 5.4, 26.0, 32.0, 7.5, 27.2]],
}

## Lights: room id (or a DIRECT prop's name prefix before `_`) -> fixture asset -> Light3D properties.
const WARM_3000: Color = Color(1.0, 0.82, 0.62)
const LIGHT_TWEAKS: Dictionary = {
	"GH": {"prop_chandelier_ring": {"omni_range": 11.0, "light_energy": 3.2},
		"prop_track_light": {"spot_range": 9.0, "light_energy": 4.0, "spot_angle": 30.0, "light_color": WARM_3000}},
	"WG": {"prop_track_light": {"spot_range": 6.0, "light_energy": 2.0, "light_color": WARM_3000}},
	"EG": {"prop_track_light": {"spot_range": 6.0, "light_energy": 2.0, "light_color": WARM_3000}},
	"EB": {"prop_track_light": {"spot_range": 6.0, "light_energy": 2.0, "light_color": WARM_3000}},
	"UG1": {"prop_track_light": {"spot_range": 8.5, "light_energy": 2.6, "light_color": WARM_3000}},
	"UG2": {"prop_track_light": {"spot_range": 8.5, "light_energy": 2.6, "light_color": WARM_3000}},
	"UG3": {"prop_track_light": {"spot_range": 8.5, "light_energy": 2.6, "light_color": WARM_3000}},
	"DC": {"prop_downlight": {"spot_range": 6.0, "light_energy": 1.0}},
	"VE": {"prop_downlight": {"spot_range": 6.0, "light_energy": 2.0}},
	"CK": {"prop_downlight": {"spot_range": 6.0, "light_energy": 1.8}},
	"GS": {"prop_downlight": {"spot_range": 6.0, "light_energy": 1.6}},
	"TR": {"prop_downlight": {"spot_range": 6.0, "light_energy": 1.6}},
	"PWW": {"prop_downlight": {"spot_range": 4.5, "light_energy": 1.6}},
	"PWM": {"prop_downlight": {"spot_range": 4.5, "light_energy": 1.6}},
	"CS": {"prop_fluorescent": {"spot_range": 5.5, "light_energy": 1.6, "light_color": Color(1.0, 0.97, 0.93)}},
	"LD": {"prop_fluorescent": {"spot_range": 6.0, "light_energy": 1.4}},
	"AS": {"prop_fluorescent": {"spot_range": 4.5, "light_energy": 1.3}},
	"PL": {"prop_fluorescent": {"spot_range": 4.5, "light_energy": 1.2}},
	"HalberdFlood": {"prop_uplight_lilac": {"light_color": Color(1.0, 0.78, 0.5), "light_energy": 4.0, "spot_range": 12.0,
		"spot_angle": 18.0}},
}
## Fixtures that cast shadows: [room, near this point] (<= 8 shadowed lights in any view, level_standards §5).
const SHADOW_FIXTURES: Array = [
	["GH", Vector3(17.0, 9.0, 21.0)], ["UG1", Vector3(6.0, 11.0, 14.0)], ["WG", Vector3(6.0, 4.4, 14.0)],
	["CS", Vector3(38.0, 9.0, 6.0)], ["LD", Vector3(38.0, 4.4, 6.0)], ["AS", Vector3(22.0, -0.9, 14.0)],
]

## Directly placed props (outside, and pieces no kit places): [name, catalog asset, pos, yaw_deg, metas]. A name prefix
## before `_` keys LIGHT_TWEAKS.
const DIRECT_PROPS: Array = [
	# X1 Aldous Parade: street lamps on the kerb (arms over the road) and the park side, planters at the portico, the
	# lilac gala uplights along the south facade (between the windows) and the warm floods on the gilded halberd
	["ParadeLamp_1", "prop_street_lamp", Vector3(-34.0, G, 35.7), 180.0, {}],
	["ParadeLamp_2", "prop_street_lamp", Vector3(-20.0, G, 35.7), 180.0, {}],
	["ParadeLamp_3", "prop_street_lamp", Vector3(-6.0, G, 35.7), 180.0, {}],
	["ParadeLamp_4", "prop_street_lamp", Vector3(8.0, G, 35.7), 180.0, {}],
	["ParadeLamp_5", "prop_street_lamp", Vector3(36.0, G, 35.7), 180.0, {}],
	["ParadeLamp_6", "prop_street_lamp", Vector3(50.0, G, 35.7), 180.0, {}],
	["ParkLamp_1", "prop_street_lamp", Vector3(-28.0, G, 49.3), 0.0, {}],
	["ParkLamp_2", "prop_street_lamp", Vector3(0.0, G, 49.3), 0.0, {}],
	["ParkLamp_3", "prop_street_lamp", Vector3(28.0, G, 49.3), 0.0, {}],
	["ParkLamp_4", "prop_street_lamp", Vector3(56.0, G, 49.3), 0.0, {}],
	["PorticoPlanter_W", "prop_planter_street", Vector3(16.6, G, 31.2), 180.0, {}],
	["PorticoPlanter_E", "prop_planter_street", Vector3(27.4, G, 31.2), 180.0, {}],
	["Uplight_1", "prop_uplight_lilac", Vector3(2.5, G, 30.45), 0.0, {}],
	["Uplight_2", "prop_uplight_lilac", Vector3(7.0, G, 30.45), 0.0, {}],
	["Uplight_3", "prop_uplight_lilac", Vector3(10.5, G, 30.45), 0.0, {}],
	["Uplight_4", "prop_uplight_lilac", Vector3(14.5, G, 30.45), 0.0, {}],
	["Uplight_5", "prop_uplight_lilac", Vector3(26.0, G, 30.45), 0.0, {}],
	["Uplight_6", "prop_uplight_lilac", Vector3(29.5, G, 30.45), 0.0, {}],
	["Uplight_7", "prop_uplight_lilac", Vector3(32.6, G, 30.45), 0.0, {}],
	["Uplight_8", "prop_uplight_lilac", Vector3(40.0, G, 30.45), 0.0, {}],
	["HalberdFlood_W", "prop_uplight_lilac", Vector3(19.2, G, 31.2), 0.0, {}],
	["HalberdFlood_E", "prop_uplight_lilac", Vector3(23.0, G, 31.2), 0.0, {}],
	# X2 Mews / Wexley St: wall lamps on the north facade and the Mews houses, street lamps along the hotel (the
	# closures' vehicles are part of the closure geometry: gn_art_site.CLOSURE_VEHICLES)
	["MewsLamp_1", "prop_wall_lamp", Vector3(7.0, 2.6, -0.2), 0.0, {}],
	["MewsLamp_2", "prop_wall_lamp", Vector3(12.5, 2.6, -0.2), 0.0, {}],
	["MewsLamp_3", "prop_wall_lamp", Vector3(18.0, 2.6, -0.2), 0.0, {}],
	["MewsLamp_4", "prop_wall_lamp", Vector3(24.0, 2.6, -0.2), 0.0, {}],
	["MewsLamp_5", "prop_wall_lamp", Vector3(32.4, 2.6, -0.2), 0.0, {}],
	["MewsLamp_6", "prop_wall_lamp", Vector3(39.6, 2.6, -0.2), 0.0, {}],
	["MewsHouseLamp_1", "prop_wall_lamp", Vector3(-24.0, 2.6, -8.0), 180.0, {}],
	["MewsHouseLamp_2", "prop_wall_lamp", Vector3(-4.0, 2.6, -8.0), 180.0, {}],
	["MewsHouseLamp_3", "prop_wall_lamp", Vector3(16.0, 2.6, -8.0), 180.0, {}],
	["MewsHouseLamp_4", "prop_wall_lamp", Vector3(36.0, 2.6, -8.0), 180.0, {}],
	["WexleyLamp_1", "prop_street_lamp", Vector3(57.8, G, -12.0), 90.0, {}],
	["WexleyLamp_2", "prop_street_lamp", Vector3(57.8, G, 6.0), 90.0, {}],
	["WexleyLamp_3", "prop_street_lamp", Vector3(57.8, G, 24.0), 90.0, {}],
	# X3 Sculpture Court: five bronzes, stone benches on the west wall, two standing heaters and the smokers' ashtray
	# stand, lanterns on the court walls and the WG west facade
	["CourtBronze_1", "prop_bronze_court", Vector3(-13.0, G, 4.0), 30.0, {}],
	["CourtBronze_2", "prop_bronze_court", Vector3(-4.0, G, 4.0), -20.0, {}],
	["CourtBronze_3", "prop_bronze_court", Vector3(-13.5, G, 9.5), 70.0, {}],
	["CourtBronze_4", "prop_bronze_court", Vector3(-3.5, G, 22.5), 200.0, {}],
	["CourtBronze_5", "prop_bronze_court", Vector3(-13.0, G, 27.0), 160.0, {}],
	["CourtBench_1", "prop_bench_stone", Vector3(-15.75, G, 17.0), -90.0, {}],
	["CourtBench_2", "prop_bench_stone", Vector3(-15.75, G, 21.5), -90.0, {}],
	["CourtHeater_1", "prop_patio_heater", Vector3(-5.5, G, 9.0), 0.0, {}],
	["CourtHeater_2", "prop_patio_heater", Vector3(-10.5, G, 24.0), 0.0, {}],
	["CourtAshtray", "prop_ashtray_stand", Vector3(-9.0, G, 13.2), 0.0, {}],
	["CourtLamp_1", "prop_wall_lamp", Vector3(-16.0, 2.4, 6.0), -90.0, {}],
	["CourtLamp_2", "prop_wall_lamp", Vector3(-16.0, 2.4, 15.0), -90.0, {}],
	["CourtLamp_3", "prop_wall_lamp", Vector3(-16.0, 2.4, 24.0), -90.0, {}],
	["CourtLamp_4", "prop_wall_lamp", Vector3(-0.2, 2.8, 5.0), 90.0, {}],
	["CourtLamp_5", "prop_wall_lamp", Vector3(-0.2, 2.8, 20.0), 90.0, {}],
	["CourtLamp_6", "prop_wall_lamp", Vector3(-0.2, 2.8, 26.0), 90.0, {}],
	# X4 roof deck: the AHUs and condensers (hard cover, the doc's roof plan)
	["RoofAHU_1", "prop_air_handler", Vector3(6.0, 9.0, 3.5), 180.0, {}],
	["RoofAHU_2", "prop_air_handler", Vector3(13.5, 9.0, 3.5), 180.0, {}],
	["RoofCondenser_1", "prop_hvac_condenser", Vector3(19.0, 9.0, 3.0), 180.0, {}],
	["RoofCondenser_2", "prop_hvac_condenser", Vector3(20.6, 9.0, 3.0), 180.0, {}],
	["RoofCondenser_3", "prop_hvac_condenser", Vector3(22.2, 9.0, 3.0), 180.0, {}],
]
