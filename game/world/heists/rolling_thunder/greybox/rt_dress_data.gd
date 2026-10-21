## Rolling Thunder G2 dressing data (RT-C2 batch 1, reuse-first, D-147): read by rt_dress.gd. Owner: ENV C.
## Source: docs/process/next_heist_rolling_thunder.md §3c (the catalog props and kits per area) and the design doc's
## room list (kits and purposes). Site coordinates (origin = the junction, +x east, +z south), metres, yaw in degrees
## (yaw 0: the prop's front (-Z) faces north, 90 west, 180 south, -90 east).
extends RefCounted

## Catalog art over the G1 map-built boxes (Props/MapBuilt): body name -> [asset, yaw (deg, in the body's frame), nx, nz,
## alternate (every second row turned 180 deg), keep the asset's height]. The greybox Mesh goes, the collider stays;
## a cell within 3 % of the asset's footprint becomes a KitPlacer anchor of its room. The bus shelters' 0.3 m back
## panels, the cookline, the clock pillar, the formwork stacks and the camera poles wait for their new generators
## (§3c: prop_cookline, prop_rt_clock_pillar, prop_site_clutter; the shelters' art is the new street batch).
const PROP_ART: Dictionary = {
	"ParkedCarG0": ["veh_car_sedan_silver", 90.0, 1, 1, false, true],
	"ParkedCarG1": ["veh_car_sedan_navy", 90.0, 1, 1, false, true],
	"ParkedCarG2": ["veh_car_sedan_wine", 90.0, 1, 1, false, true],
	"ParkedCarG3": ["veh_car_sedan_navy", -90.0, 1, 1, false, true],
	"ParkedCarG4": ["veh_car_sedan_silver", -90.0, 1, 1, false, true],
	"ParkedCarG5": ["veh_car_sedan_wine", -90.0, 1, 1, false, true],
	"ParkedCar20": ["veh_car_sedan_wine", 90.0, 1, 1, false, true],
	"ParkedCar21": ["veh_car_sedan_silver", -90.0, 1, 1, false, true],
	"ParkedCar22": ["veh_car_sedan_navy", 90.0, 1, 1, false, true],
	"ParkedCar23": ["veh_car_sedan_silver", 90.0, 1, 1, false, true],
	"ParkedCar24": ["veh_car_sedan_wine", -90.0, 1, 1, false, true],
	"ParkedCarR0": ["veh_car_sedan_navy", 90.0, 1, 1, false, true],
	"ParkedCarR1": ["veh_car_sedan_silver", -90.0, 1, 1, false, true],
	"ParkedCarR2": ["veh_car_sedan_wine", 90.0, 1, 1, false, true],
	"ParkedCarR3": ["veh_car_sedan_navy", -90.0, 1, 1, false, true],
	"StreetCarOW1": ["veh_car_sedan_silver", 180.0, 1, 1, false, true],
	"StreetCarOW2": ["veh_car_sedan_wine", 180.0, 1, 1, false, true],
	"StreetCarOE1": ["veh_car_sedan_navy", 0.0, 1, 1, false, true],
	"StreetCarOE2": ["veh_car_sedan_silver", 0.0, 1, 1, false, true],
	"StreetCarTW1": ["veh_car_sedan_wine", 0.0, 1, 1, false, true],
	"StreetCarTW2": ["veh_car_sedan_navy", 0.0, 1, 1, false, true],
	"StreetCarON1": ["veh_car_sedan_wine", 180.0, 1, 1, false, true],
	"ShelterBench0": ["prop_bench_stone", 180.0, 2, 1, false, true],
	"ShelterBench1": ["prop_bench_stone", 180.0, 2, 1, false, true],
	"ShelterBench2": ["prop_bench_stone", 180.0, 2, 1, false, true],
	"Newsstand": ["prop_of_news_kiosk", 0.0, 1, 1, false, false],
	"Planter0": ["prop_planter_street", 0.0, 1, 2, true, true],
	"Planter1": ["prop_planter_street", 0.0, 1, 2, true, true],
	"Planter2": ["prop_planter_street", 0.0, 1, 2, true, true],
	"Planter3": ["prop_planter_street", 0.0, 1, 2, true, true],
	# the diner counter's front (-Z) faces the dining room (west)
	"DinerCounter": ["prop_counter_sales", 90.0, 1, 3, false, true],
	"DinerTable0": ["prop_table_round_d120", 0.0, 1, 1, false, true],
	"DinerTable1": ["prop_table_round_d120", 0.0, 1, 1, false, true],
	"DinerTable2": ["prop_table_round_d120", 0.0, 1, 1, false, true],
	"PrepTable": ["prop_packing_table_steel", 0.0, 1, 1, false, true],
	"OfficeDesk": ["prop_desk_office", 180.0, 1, 1, false, true],
	"FunctionTable0": ["prop_table_break_l160", 0.0, 1, 1, false, true],
	"FunctionTable1": ["prop_table_break_l160", 0.0, 1, 1, false, true],
	"PlantPumps": ["prop_air_handler", 180.0, 2, 1, false, false],
	"BlockPallet0": ["prop_pallet_loaded", 0.0, 1, 1, false, false],
	"BlockPallet1": ["prop_pallet_loaded", 0.0, 1, 1, false, false],
	"PlanTable": ["prop_plan_chest", 90.0, 1, 2, false, true],
}

## Rooms the KitPlacer dresses although their purpose is exterior (walled yards).
const PLACER_EXTERIOR: Array[String] = ["YD"]
## Per-room placer seeds (default 7100).
const KIT_SEEDS: Dictionary = {"ST": 7102, "C1": 7101, "U2": 7101}
## Extra keep-outs per room: [x0, y0, z0, x1, y1, z1] (world).
const KEEP_OUT: Dictionary = {
	# the attendant's walk from the booth door to the BoothDesk chair
	"AB": [[17.6, 0.0, -17.6, 19.4, 2.2, -15.6]],
	# the walk from the cabin door (-57, -17) down the east side to the petty cash's use point (-55.6, -22.5) past the
	# plan table (the cabin is 2.8 m clear: furniture on both long walls would close it)
	"C1": [[-57.7, 0.0, -18.4, -55.1, 2.2, -17.0], [-56.0, 0.0, -23.2, -55.1, 2.2, -17.0]],
}
## Rooms without the kit's ceiling grid.
const NO_CEILING_GRID: Array[String] = ["YD"]

## Street furniture rows (the OF way: fixed tables, D-147 kits' kinds) along the sidewalks: [room, name, from, to,
## yaw, [[asset, first (m from `from`), step (m), count, side offset (m, + = left of the run)], ...]]. A slot whose
## footprint meets a gameplay keep-out (spawns, patrol and use points, doors, nav-link ends, COVER, cars, the shelters)
## is skipped and reported, so no route or marker moves. Sidewalks (doc Site): Orchard x -14..-10 / 10..14 (kerb at
## +-10), Tannery z -11..-8 / 8..11 (kerb at +-8). Lamps stand 0.5 m in from the kerb with the arm over the road. A bin
## stands beside a lamp and bollards come in groups 0.7 m apart, so each cluster is one hole in the navmesh (RT plan
## §7.15: <= 3,500 polygons; an isolated pole on an open sidewalk splits its polygon several times).
const ROWS: Array = [
	# lamps and bins against the facades / the hoarding where the sidewalk has one (a notch in the navmesh, not a hole),
	# on the kerb elsewhere; the bollard groups on the kerb at the junction corners
	["X1", "OrchardW_N", [-13.55, 0.0, -78.0], [-13.55, 0.0, -14.0], -90.0, [
		["prop_street_lamp", 2.0, 25.0, 3, 0.0], ["prop_bin_street", 2.6, 50.0, 2, 0.15]]],
	["X1", "OrchardW_NKerb", [-10.5, 0.0, -78.0], [-10.5, 0.0, -14.0], -90.0, [
		["prop_bollard_steel", 61.4, 0.7, 3, 0.0]]],
	["X1", "OrchardW_S", [-10.5, 0.0, 14.0], [-10.5, 0.0, 62.0], -90.0, [
		["prop_bollard_steel", 0.0, 0.7, 3, 0.0], ["prop_street_lamp", 14.0, 30.0, 2, 0.0],
		["prop_bin_street", 14.55, 30.0, 1, 0.0]]],
	["X1", "OrchardE_N", [13.55, 0.0, -78.0], [13.55, 0.0, -57.0], 90.0, [
		["prop_street_lamp", 4.0, 14.0, 2, 0.0], ["prop_bin_street", 4.6, 28.0, 1, -0.15]]],
	["X1", "OrchardE_NKerb", [10.5, 0.0, -78.0], [10.5, 0.0, -14.0], 90.0, [
		["prop_bollard_steel", 61.4, 0.7, 3, 0.0]]],
	["X1", "OrchardE_S", [13.55, 0.0, 14.0], [13.55, 0.0, 62.0], 90.0, [
		["prop_street_lamp", 6.0, 20.0, 3, 0.0], ["prop_bin_street", 6.6, 40.0, 2, -0.15]]],
	["X1", "OrchardE_SKerb", [10.5, 0.0, 14.0], [10.5, 0.0, 62.0], 90.0, [
		["prop_bollard_steel", 0.0, 0.7, 3, 0.0]]],
	["X1", "TanneryW_N", [-70.0, 0.0, -10.55], [-14.5, 0.0, -10.55], 180.0, [
		["prop_street_lamp", 10.0, 25.0, 2, 0.0], ["prop_bin_street", 10.6, 25.0, 1, -0.15]]],
	["X1", "TanneryW_NKerb", [-70.0, 0.0, -8.5], [-14.5, 0.0, -8.5], 180.0, [
		["prop_bollard_steel", 54.0, 0.7, 3, 0.0]]],
	["X1", "TanneryW_S", [-70.0, 0.0, 8.5], [-14.5, 0.0, 8.5], 0.0, [
		["prop_street_lamp", 20.0, 25.0, 1, 0.0], ["prop_bin_street", 20.55, 25.0, 1, 0.0],
		["prop_bollard_steel", 54.0, 0.7, 3, 0.0]]],
	["X1", "TanneryE_N", [14.5, 0.0, -8.5], [33.5, 0.0, -8.5], 180.0, [
		["prop_bollard_steel", 0.0, 0.7, 3, 0.0], ["prop_street_lamp", 11.0, 20.0, 1, 0.0]]],
	["X1", "TanneryE_S", [14.5, 0.0, 8.5], [33.5, 0.0, 8.5], 0.0, [
		["prop_bollard_steel", 0.0, 0.7, 3, 0.0]]],
	# the car-park forecourt west of the car-park entrance (x 37-49 stays clear) and the north lot (X6)
	["X6", "Forecourt", [17.0, 0.0, -13.4], [36.0, 0.0, -13.4], 180.0, [
		["prop_bollard_steel", 0.0, 0.7, 3, 0.0], ["prop_street_lamp", 4.0, 10.0, 2, 0.0],
		["prop_bin_street", 4.55, 10.0, 1, 0.0]]],
	["X6", "NorthLot", [20.0, 0.0, -53.0], [50.0, 0.0, -53.0], 180.0, [
		["prop_street_lamp", 10.0, 14.0, 1, 0.0], ["prop_bin_street", 10.55, 14.0, 1, 0.0],
		["prop_bollard_steel", 24.0, 0.7, 3, 0.0]]],
]

## Directly placed props: [name, asset, position, yaw, metas]. Wall mounts sit on the face at `position` (centred);
## ceiling mounts hang from it.
const DIRECT_PROPS: Array = [
	# ST's second rect (x 32-34, z 26-32; the placer dresses a room's largest box): shelving and a box stack on the
	# east wall, clear of the electrical closet's door (z 26)
	["STShelf", "prop_shelving_boxes", Vector3(33.56, 0.0, 29.6), 90.0, {}],
	["STBoxStack", "prop_box_stack", Vector3(33.55, 0.0, 31.0), 90.0, {}],
	# X3 plaza (exterior_plaza, the OF kit as is): lamps, benches by the planters, the kiosk, bollards at Ashby's
	# forecourt, bins, a car on the forecourt; the shelters, planters and the shelter bench are the map's
	["PlazaLamp0", "prop_street_lamp", Vector3(-56.0, 0.0, 12.4), 0.0, {}],
	["PlazaLamp1", "prop_street_lamp", Vector3(-46.0, 0.0, 12.4), 0.0, {}],
	["PlazaLamp2", "prop_street_lamp", Vector3(-15.0, 0.0, 12.4), 0.0, {}],
	["PlazaLamp3", "prop_street_lamp", Vector3(-38.0, 0.0, 29.0), 0.0, {}],
	["PlazaBench0", "prop_bench_stone", Vector3(-50.0, 0.0, 19.4), 180.0, {}],
	["PlazaBench1", "prop_bench_stone", Vector3(-44.0, 0.0, 23.6), 0.0, {}],
	["PlazaKiosk", "prop_of_news_kiosk", Vector3(-57.0, 0.0, 27.0), -90.0, {}],
	["PlazaKioskBin", "prop_bin_street", Vector3(-55.3, 0.0, 28.4), -90.0, {}],
	["PlazaBin0", "prop_bin_street", Vector3(-45.45, 0.0, 12.4), 0.0, {}],
	["PlazaClockBin", "prop_bin_street", Vector3(-24.95, 0.0, 20.0), -90.0, {}],
	["PlazaBollard0", "prop_bollard_steel", Vector3(-22.5, 0.0, 30.6), 0.0, {}],
	["PlazaBollard1", "prop_bollard_steel", Vector3(-21.8, 0.0, 30.6), 0.0, {}],
	["PlazaBollard2", "prop_bollard_steel", Vector3(-16.2, 0.0, 30.6), 0.0, {}],
	["PlazaBollard3", "prop_bollard_steel", Vector3(-15.5, 0.0, 30.6), 0.0, {}],
	["AshbyCar", "veh_car_sedan_navy", Vector3(-21.5, 0.0, 44.0), 0.0, {}],
	# X2 Tannery underpass (exterior_underpass): cold battens and caged bulkheads under the rail bridge soffit
	# (-0.4), barriers along the cut walls past the bridge
	["UnderpassBatten0", "prop_led_batten_cold", Vector3(70.0, -0.4, -5.0), 0.0, {}],
	["UnderpassBatten1", "prop_led_batten_cold", Vector3(75.0, -0.4, 0.0), 0.0, {}],
	["UnderpassBatten2", "prop_led_batten_cold", Vector3(80.0, -0.4, 5.0), 0.0, {}],
	["UnderpassBulkhead0", "prop_bulkhead_caged", Vector3(70.0, -0.4, 8.5), 0.0, {}],
	["UnderpassBulkhead1", "prop_bulkhead_caged", Vector3(80.0, -0.4, -8.5), 0.0, {}],
	["UnderpassBarrier0", "prop_barrier_jersey", Vector3(89.0, -5.0, -10.3), 0.0, {}],
	["UnderpassBarrier1", "prop_barrier_jersey", Vector3(91.2, -5.0, -10.3), 0.0, {}],
	["UnderpassBarrier2", "prop_barrier_roadworks", Vector3(89.0, -5.0, 10.3), 180.0, {}],
	# X5 rail lane, north of the rail gate (exterior_lane): a flatbed and a skip against the palisade
	["RailLaneFlatbed", "veh_flatbed_trailer", Vector3(62.4, 0.0, -84.0), 0.0, {}],
	["RailLaneSkip", "prop_skip", Vector3(53.2, 0.0, -80.0), 0.0, {}],
	["RailLaneCone", "prop_traffic_cone", Vector3(60.6, 0.0, -80.0), 0.0, {}],
	["RailLaneCone2", "prop_traffic_cone", Vector3(60.6, 0.0, -88.0), 0.0, {}],
	# X7 tyre-shop lane (exterior_lane): a skip at the east end, a flatbed along the south block
	["TyreLaneSkip", "prop_skip", Vector3(50.6, 0.0, 37.0), 0.0, {}],
	["TyreLaneFlatbed", "veh_flatbed_trailer", Vector3(40.0, 0.0, 38.6), 90.0, {}],
	["TyreLaneCone", "prop_traffic_cone", Vector3(44.2, 0.0, 38.6), 0.0, {}],
]
