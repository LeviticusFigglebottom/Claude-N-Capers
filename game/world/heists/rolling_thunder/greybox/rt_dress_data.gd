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
	# the diner counter's front (-Z) faces the dining room (west). GPU-21 (the LEAD's render review: DR read as an
	# office): three diner counter modules (exact fit, 3 x 2.5 m) and the diner's laminate tables (0.8 m, top 0.74)
	"DinerCounter": ["prop_diner_counter_w250", 90.0, 1, 3, false, true],
	"DinerTable0": ["prop_diner_table_w80", 0.0, 1, 1, false, true],
	"DinerTable1": ["prop_diner_table_w80", 0.0, 1, 1, false, true],
	"DinerTable2": ["prop_diner_table_w80", 0.0, 1, 1, false, true],
	"PrepTable": ["prop_packing_table_steel", 0.0, 1, 1, false, true],
	"OfficeDesk": ["prop_desk_office", 180.0, 1, 1, false, true],
	# GPU-21: the function room's long tables in the diner's laminate (exact fit, 1.8 x 0.8 m)
	"FunctionTable0": ["prop_diner_table_l180", 0.0, 1, 1, false, true],
	"FunctionTable1": ["prop_diner_table_l180", 0.0, 1, 1, false, true],
	"PlantPumps": ["prop_air_handler", 180.0, 2, 1, false, false],
	"BlockPallet0": ["prop_pallet_loaded", 0.0, 1, 1, false, false],
	"BlockPallet1": ["prop_pallet_loaded", 0.0, 1, 1, false, false],
	"PlanTable": ["prop_plan_chest", 90.0, 1, 2, false, true],
	# RT-C2 batch 3 new generators: the closures' lorries (Geometry/Site/Closures boxes: the collider stays, the art
	# replaces the finish); Reyes's mixer is a convoy mover since phase 2 (rt_gameplay CONVOY_MIXER_ART)
	# the cookline faces the cook (east; D: top 0.90, the front edge 0.30 m ahead of the cook at x 28.25)
	"Cookline": ["prop_cookline", -90.0, 1, 1, false, true],
	"TMTruckN": ["veh_lorry_tm", 90.0, 1, 1, false, true],
	"LorryS": ["veh_lorry", 90.0, 1, 1, false, true],
	"LorryW": ["veh_lorry", 0.0, 1, 1, false, true],
	"LorryE": ["veh_lorry_tm", 0.0, 1, 1, false, true],
	# the 4 sidewalk closures (LEAD r304: a bare grey block read as a snag): jersey barriers in 2 m units along the run,
	# stretched to the 1.2 m collider (above the jump apex) so the art and the blocker agree
	"BarrierNE": ["prop_barrier_jersey", 0.0, 2, 1, false, false],
	"BarrierSE": ["prop_barrier_jersey", 0.0, 2, 1, false, false],
	"BarrierWN": ["prop_barrier_jersey", 90.0, 1, 2, false, false],
	"BarrierES": ["prop_barrier_jersey", 90.0, 1, 2, false, false],
	# landmark 2, the formwork stacks (prop_site_clutter), the scaffold-tower cladding and the F1 edge protection
	# (prop_scaffold bays over the thin G1 boxes; nx / nz bays along the run)
	"ClockPillar": ["prop_rt_clock_pillar", 0.0, 1, 1, false, true],
	"FormworkStack0": ["prop_site_formwork_stack", 0.0, 1, 1, false, true],
	"FormworkStack1": ["prop_site_formwork_stack", 0.0, 1, 1, false, true],
	"FormworkStack2": ["prop_site_formwork_stack", 0.0, 1, 1, false, true],
	"FormworkStack3": ["prop_site_formwork_stack", 0.0, 1, 1, false, true],
	"CladW": ["prop_scaffold_bay_w200_h460", 90.0, 1, 3, false, false],
	"CladE": ["prop_scaffold_bay_w200_h460", 90.0, 1, 3, false, false],
	"CladS": ["prop_scaffold_bay_w200_h460", 0.0, 2, 1, false, false],
	"CladNW": ["prop_scaffold_bay_w100_h460", 0.0, 1, 1, false, false],
	"CladNE": ["prop_scaffold_bay_w100_h460", 0.0, 1, 1, false, false],
	"CladNMid": ["prop_scaffold_edge_w200_h110", 0.0, 1, 1, false, false],
	"EdgeProtectionN": ["prop_scaffold_edge_w200_h110", 0.0, 12, 1, false, false],
	"EdgeProtectionW": ["prop_scaffold_edge_w200_h110", 90.0, 1, 10, false, false],
	"EdgeProtectionE": ["prop_scaffold_edge_w200_h110", 90.0, 1, 10, false, false],
	"EdgeProtectionS0": ["prop_scaffold_edge_w200_h110", 0.0, 8, 1, false, false],
	"EdgeProtectionS1": ["prop_scaffold_edge_w200_h110", 0.0, 4, 1, false, false],
}
## Geometry groups whose boxes may carry PROP_ART too (the art_mapbuilt pass also walks their children).
const ART_GROUPS: Array[String] = ["Props/MapBuilt", "Geometry/Site/Closures", "Geometry/Site/Scaffold",
	"Geometry/Site/Frame"]

## Landmark visuals (no collider, no bake obstruction: they stand on or replace G1 colliders, which stay): [name,
## asset, parent, position, yaw, G1 boxes whose greybox Mesh they replace]. The crane on its base pad (the jib along
## +X to Orchard), the Skyway's junction fascia on both deck faces, the two tracks along the rail bank and bridge.
const LANDMARKS: Array = [
	["TowerCrane", "prop_rt_tower_crane", "Geometry/Site/Crane", Vector3(-26.0, 1.4, -24.0), 0.0,
		["Geometry/Site/Crane/CraneMast", "Geometry/Site/Crane/CraneCab", "Geometry/Site/Crane/CraneJib"]],
	["GirderW", "prop_rt_skyway_girder_l2600", "Geometry/Site/Skyway", Vector3(-13.0, 7.6, 0.0), 90.0, []],
	["GirderE", "prop_rt_skyway_girder_l2600", "Geometry/Site/Skyway", Vector3(13.0, 7.6, 0.0), -90.0, []],
	["TrackW0", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(69.0, 1.2, -85.0), 0.0, []],
	["TrackW1", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(69.0, 1.2, -55.0), 0.0, []],
	["TrackW2", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(69.0, 1.2, -25.0), 0.0, []],
	["TrackW3", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(69.0, 1.2, 5.0), 0.0, []],
	["TrackW4", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(69.0, 1.2, 35.0), 0.0, []],
	["TrackW5", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(69.0, 1.2, 65.0), 0.0, []],
	["TrackE0", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(75.0, 1.2, -85.0), 0.0, []],
	["TrackE1", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(75.0, 1.2, -55.0), 0.0, []],
	["TrackE2", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(75.0, 1.2, -25.0), 0.0, []],
	["TrackE3", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(75.0, 1.2, 5.0), 0.0, []],
	["TrackE4", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(75.0, 1.2, 35.0), 0.0, []],
	["TrackE5", "prop_rail_track_l3000", "Geometry/Site/Rail", Vector3(75.0, 1.2, 65.0), 0.0, []],
	# the heli-pad marking on the roof deck under E3 (4 mm over the finish)
	["HeliPadMarking", "prop_heli_pad_marking", "Props/Dress", Vector3(32.0, 7.0, -34.0), 0.0, []],
	# bay lines round the parked cars (each car in the middle bay of its set; the cars' length runs along x)
	["BayLinesG0", "prop_bay_lines_x3", "Props/Dress", Vector3(28.5, 0.0, -42.0), 90.0, []],
	["BayLinesG1", "prop_bay_lines_x3", "Props/Dress", Vector3(18.4, 0.0, -38.0), 90.0, []],
	["BayLinesG2", "prop_bay_lines_x3", "Props/Dress", Vector3(34.0, 0.0, -36.0), 90.0, []],
	["BayLinesG3", "prop_bay_lines_x3", "Props/Dress", Vector3(28.5, 0.0, -28.0), 90.0, []],
	["BayLinesG4", "prop_bay_lines_x3", "Props/Dress", Vector3(18.4, 0.0, -26.0), 90.0, []],
	["BayLinesG5", "prop_bay_lines_x3", "Props/Dress", Vector3(40.0, 0.0, -23.5), 90.0, []],
	["BayLines20", "prop_bay_lines_x3", "Props/Dress", Vector3(28.5, 3.5, -42.0), 90.0, []],
	["BayLines21", "prop_bay_lines_x3", "Props/Dress", Vector3(18.4, 3.5, -34.0), 90.0, []],
	["BayLines22", "prop_bay_lines_x3", "Props/Dress", Vector3(34.0, 3.5, -30.0), 90.0, []],
	["BayLines24", "prop_bay_lines_x3", "Props/Dress", Vector3(24.0, 3.5, -23.0), 90.0, []],
	["BayLinesR1", "prop_bay_lines_x3", "Props/Dress", Vector3(36.0, 7.0, -18.0), 90.0, []],
	["BayLinesR2", "prop_bay_lines_x3", "Props/Dress", Vector3(30.0, 7.0, -18.0), 90.0, []],
	["BayLinesR3", "prop_bay_lines_x3", "Props/Dress", Vector3(24.0, 7.0, -18.0), 90.0, []],
	# the hoarding graphic on its street faces: Orchard (east, between the vehicle gates and the man-gate) and Tannery
	["HoardingGraphicE", "prop_hoarding_graphic_w600", "Props/Dress", Vector3(-13.9, 1.2, -30.0), -90.0, []],
	["HoardingGraphicS", "prop_hoarding_graphic_w600", "Props/Dress", Vector3(-48.0, 1.2, -10.9), 180.0, []],
]

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
	# (BinStreet0 0.65 m in toward the kerb: P's §7.6 standable FAIL, 0.6 m off the hoarding's SW corner with a 1.0 m top)
	["X1", "TanneryW_N", [-70.0, 0.0, -10.55], [-14.5, 0.0, -10.55], 180.0, [
		["prop_street_lamp", 10.0, 25.0, 2, 0.0], ["prop_bin_street", 10.6, 25.0, 1, -0.65]]],
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
		["prop_bollard_steel", 0.0, 0.7, 3, 0.0], ["prop_street_lamp", 2.5, 10.0, 2, 0.0],
		["prop_bin_street", 3.05, 10.0, 1, 0.0]]],   # D-158 am. 9: the bin keeps >= 1.2 m off the barrier post (x 22.17)
	["X6", "NorthLot", [20.0, 0.0, -53.0], [50.0, 0.0, -53.0], 180.0, [
		["prop_street_lamp", 10.0, 14.0, 1, 0.0], ["prop_bin_street", 10.55, 14.0, 1, 0.0],
		["prop_bollard_steel", 24.0, 0.7, 3, 0.0]]],
]

## Directly placed props: [name, asset, position, yaw, metas]. Wall mounts sit on the face at `position` (centred);
## ceiling mounts hang from it.
const DIRECT_PROPS: Array = [
	# DR (diner_dining, GPU-21; the counter stools and booths are map-built, rolling_thunder_content.py): the menu
	# board and the EAT / COFFEE PIE neon on the kitchen wall behind the counter (inner face x 26.9), facing the room
	["DinerMenuBoard", "prop_diner_menu_board", Vector3(26.9, 2.15, 19.6), 90.0, {}],
	["DinerNeonEat", "prop_neon_eat", Vector3(26.9, 2.2, 15.4), 90.0, {}],
	# CP-R (car_park_roof): street lamps off the parapets, the arm over the deck (the placer finds no row on the roof
	# between the parked cars, the head houses and the heli pad)
	["RoofLampW0", "prop_street_lamp", Vector3(17.2, 7.0, -40.0), -90.0, {}],
	["RoofLampW1", "prop_street_lamp", Vector3(17.2, 7.0, -28.0), -90.0, {}],
	["RoofLampN", "prop_street_lamp", Vector3(30.0, 7.0, -43.3), 180.0, {}],
	["RoofLampS", "prop_street_lamp", Vector3(20.0, 7.0, -21.0), 0.0, {}],
	# FG (site_frame_ground): the forklift between the columns, pallets in pairs, cones; clear of the guards' loop
	# (FrameNW - FrameSW at x -46, FrameNE - FrameSE at x -27)
	["FrameForklift", "prop_forklift", Vector3(-41.0, 0.0, -46.5), 0.0, {}],
	["FramePallet0", "prop_pallet_loaded", Vector3(-48.0, 0.0, -38.0), 0.0, {}],
	["FramePallet1", "prop_pallet_loaded", Vector3(-48.0, 0.0, -37.05), 0.0, {}],
	["FrameCone0", "prop_traffic_cone", Vector3(-32.6, 0.0, -42.0), 0.0, {}],
	["FrameCone1", "prop_traffic_cone", Vector3(-32.6, 0.0, -41.3), 0.0, {}],
	# F1 (site_frame_slab, +3.5): a second pallet by each block pallet, cones by the west edge
	["SlabPallet0", "prop_pallet_loaded", Vector3(-29.0, 3.5, -32.6), 0.0, {}],
	["SlabPallet1", "prop_pallet_loaded", Vector3(-45.0, 3.5, -44.6), 0.0, {}],
	["SlabCone0", "prop_traffic_cone", Vector3(-48.5, 3.5, -40.0), 0.0, {}],
	["SlabCone1", "prop_traffic_cone", Vector3(-48.5, 3.5, -39.3), 0.0, {}],
	# X4 (exterior_site): sodium masts in the yard's corners, roadworks barriers with a beacon by the crane, cones,
	# gas cylinders on the tool store's east wall; off the guards' loop (GateN - GateS at x -16.5)
	["SiteMastNW", "prop_mast_sodium", Vector3(-58.5, 0.0, -54.5), 180.0, {}],
	["SiteMastNE", "prop_mast_sodium", Vector3(-15.8, 0.0, -54.0), 180.0, {}],
	["SiteMastSW", "prop_mast_sodium", Vector3(-58.5, 0.0, -28.5), -90.0, {}],
	["SiteBarrier0", "prop_barrier_roadworks", Vector3(-19.5, 0.0, -27.5), 90.0, {}],
	["SiteBarrier1", "prop_barrier_roadworks", Vector3(-19.5, 0.0, -25.4), 90.0, {}],
	["SiteBeacon", "prop_beacon_hazard", Vector3(-19.5, 0.0, -29.0), 0.0, {}],
	["SiteCone0", "prop_traffic_cone", Vector3(-52.0, 0.0, -52.5), 0.0, {}],
	["SiteCone1", "prop_traffic_cone", Vector3(-51.3, 0.0, -52.5), 0.0, {}],
	["SiteGas", "prop_gas_cylinders", Vector3(-45.65, 0.0, -20.0), -90.0, {}],
	# prop_site_clutter: a rebar bundle and the mortar mixer in the yard's west strip
	["SiteRebar", "prop_site_rebar_bundle", Vector3(-56.0, 0.0, -40.0), 0.0, {}],
	["SiteMixer", "prop_site_mortar_mixer", Vector3(-53.0, 0.0, -36.0), 0.0, {}],
	# the junction's traffic signals (the [signals] read): the pole on each corner, the mast arm over the approach on
	# its right (the pivot is the footprint centre, SIGNAL_POLE m from the pole along the arm)
	["SignalNW", "prop_traffic_signal", Vector3(-9.1, 0.0, -8.5), 0.0, {}],
	["SignalNE", "prop_traffic_signal", Vector3(10.5, 0.0, -7.1), -90.0, {}],
	["SignalSE", "prop_traffic_signal", Vector3(9.1, 0.0, 8.5), 180.0, {}],
	["SignalSW", "prop_traffic_signal", Vector3(-10.5, 0.0, 7.1), 90.0, {}],
	# the diner's HALFWAY / OPEN 24 HRS neon on the Tannery face between the floors
	["DinerNeon", "prop_neon_halfway", Vector3(28.8, 2.95, 13.8), 0.0, {}],
	# GPU-22 (the LEAD: the wall neon is edge-on from the street): the two-sided HALFWAY pole sign on Tannery's south
	# sidewalk by the diner's NE corner (west of the trench, x 34), its faces E / W along Tannery (the junction reads
	# the W face, the east arm's convoy the E face), the cabinet 4.6-6.4 m over the kerb; the pole is the only collider
	# (rt_dress.gd POLE_OFF)
	["DinerPoleSign", "prop_pole_sign_halfway", Vector3(32.5, 0.0, 10.0), 90.0, {}],
	["DinerPoleBin", "prop_bin_street", Vector3(31.4, 0.0, 10.4), 90.0, {}],   # the street furniture at its foot
	# the car-park entrance (x 22-26 in the south facade; doc: a barrier arm, the 2.4 m height bar is the G1
	# EntranceHeightBar lintel): the barrier open (arm raised, so on the open forecourt: the Deck 2 parapet is over the
	# opening) on the lane's west edge
	["CarParkBarrier", "prop_car_park_barrier", Vector3(22.35, 0.0, -12.4), 0.0, {}],
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
