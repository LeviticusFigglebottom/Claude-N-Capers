## Afterhours G2 dressing data (AH-C2, reuse-first, D-147): read by ah_dress.gd. Owner: ENV C. ENV D's club set pieces
## (prop_ah_*, tools/blender/props/club_hero.py: built to the G1 boxes' footprints) and the library. Site coordinates
## (origin = the club's NW corner, +x east, +z south), metres, yaw in degrees (yaw 0: the prop's front (-Z) faces north,
## 90 west, 180 south, -90 east).
extends RefCounted

## Catalog art over the G1 map-built boxes (Props/MapBuilt): body name -> [asset, yaw (deg, in the body's frame), nx, nz,
## alternate (every second row turned 180 deg), keep the asset's height]. The greybox Mesh goes, the collider stays.
## The bars: D's counters are 2 m units, customer side front (main bar east, east bar west, VIP bar north); the 7.0 m
## main bar takes three (1.17 scale), the 6.0 / 8.0 m bars tile exactly. The back bars are D's 7 m bottle wall (the
## main and VIP bars) and a 2 m counter unit (the east bar's two short backs).
const PROP_ART: Dictionary = {
	"MainBarBack": ["prop_ah_back_bar", -90.0, 1, 1, false, true],
	"MainBarCounter": ["prop_ah_bar_counter_2m", -90.0, 1, 3, false, true],
	"EastBarBackN": ["prop_ah_bar_counter_2m", 90.0, 1, 1, false, true],
	"EastBarBackS": ["prop_ah_bar_counter_2m", 90.0, 1, 1, false, true],
	"EastBarCounter": ["prop_ah_bar_counter_2m", 90.0, 1, 3, false, true],
	"VIPBarBack": ["prop_ah_back_bar", 0.0, 1, 1, false, true],
	"VIPBarCounter": ["prop_ah_bar_counter_2m", 0.0, 4, 1, false, true],
	# the box office's cash window faces the foyer (west; its -X end, the cash window, to the south)
	"BoxOfficeCounter": ["prop_ah_box_office_counter", 90.0, 1, 1, false, true],
	# the stage: the DJ booth and the stacks face the floor (south)
	"DJBooth": ["prop_ah_dj_booth", 180.0, 1, 1, false, true],
	"SpeakerStackW": ["prop_ah_speaker_stack", 180.0, 1, 1, false, true],
	"SpeakerStackE": ["prop_ah_speaker_stack", 180.0, 1, 1, false, true],
	# G7 booths on the south wall face the hall (north); the reserved corner booth; the high tables
	"BoothW1": ["prop_ah_booth", 0.0, 1, 1, false, true],
	"BoothW2": ["prop_ah_booth", 0.0, 1, 1, false, true],
	"BoothE1": ["prop_ah_booth", 0.0, 1, 1, false, true],
	"BoothReserved": ["prop_ah_booth_corner", 0.0, 1, 1, false, true],
	"HighTable1": ["prop_ah_high_table", 0.0, 1, 1, false, true],
	"HighTable2": ["prop_ah_high_table", 0.0, 1, 1, false, true],
	# U1 VIP booths along the rail, VIPTable2's bottle service; U2 the sofa faces its coffee table (south)
	"VIPBooth1": ["prop_ah_booth_vip", 0.0, 1, 1, false, true],
	"VIPBooth2": ["prop_ah_booth_vip", 0.0, 1, 1, false, true],
	"VIPBooth3": ["prop_ah_booth_vip", 0.0, 1, 1, false, true],
	"VIPTable2": ["prop_ah_bottle_table", 0.0, 1, 1, false, true],
	"VIPSofa": ["prop_ah_vip_sofa", 180.0, 1, 1, false, true],
	"VIPCoffeeTable": ["prop_ah_vip_coffee_table", 0.0, 1, 1, false, true],
	# BOH: the G13 crate stacks and keg trolley, the G21 keg rack (east wall, faces west) and bottle bank, G11's flight
	# cases; U12's shelving (east wall, its face at x 35.10)
	"CratesG13W": ["prop_ah_crates", 0.0, 1, 1, false, true],
	"CratesG13E": ["prop_ah_crates", 0.0, 1, 1, false, true],
	"KegTrolley": ["prop_ah_keg_trolley", 0.0, 1, 1, false, true],
	"KegRack": ["prop_ah_keg_rack", 90.0, 1, 1, false, true],
	"BottleBank": ["prop_ah_bottle_bank", 0.0, 1, 1, false, true],
	"FlightCases": ["prop_ah_flight_cases", 0.0, 1, 1, false, true],
	"PrivateShelving": ["prop_ah_private_shelving", 90.0, 1, 1, false, true],
	# the library: the count room, Crale's office, the staff room, the green-room sofa
	"CountTable": ["prop_counter_count_w240", 0.0, 1, 1, false, true],
	"CountDesk": ["prop_desk_office", 0.0, 1, 1, false, true],
	"OfficeDesk": ["prop_desk_exec", 0.0, 1, 1, false, true],
	"StaffTable": ["prop_table_break", 0.0, 1, 1, false, true],
	"GreenRoomSofa": ["prop_sofa_w220", 0.0, 1, 1, false, true],
	# the street: parked sedans (Tolley St along z, Marlin Ave along x), the queue's velvet rope and the passage's
	"CarTolley1": ["veh_car_sedan_navy", 0.0, 1, 1, false, true],
	"CarTolley2": ["veh_car_sedan_silver", 180.0, 1, 1, false, true],
	"CarMarlin1": ["veh_car_sedan_wine", 90.0, 1, 1, false, true],
	"CarMarlin2": ["veh_car_sedan_navy", -90.0, 1, 1, false, true],
	"QueueRail": ["prop_stanchion_velvet", 0.0, 3, 1, false, true],
	"PassageRope": ["prop_stanchion_velvet", 0.0, 1, 1, false, true],
}
## Geometry groups whose boxes may carry PROP_ART too.
const ART_GROUPS: Array[String] = ["Props/MapBuilt", "Geometry/Site/Closures"]

## Landmark visuals (no collider, no bake obstruction: they replace G1 boxes, whose colliders stay): [name, asset,
## parent, position, yaw, G1 boxes whose greybox Mesh they replace]. The marquee hangs off the Marlin Ave facade (z 28.2)
## from its wall-side soffit centre (D's `Mount`), reaching 2.8 m out over the sidewalk (+z: yaw 180).
const LANDMARKS: Array = [
	["MarqueeArt", "prop_ah_marquee", "Geometry/Site/Landmarks", Vector3(17.0, 3.6, 28.2), 180.0,
		["Geometry/Site/Landmarks/Marquee"]],
]

## Rooms the KitPlacer dresses although their purpose is exterior.
const PLACER_EXTERIOR: Array[String] = []
## Per-room placer seeds (default 7100).
const KIT_SEEDS: Dictionary = {}
## Extra keep-outs per room: [x0, y0, z0, x1, y1, z1] (world).
const KEEP_OUT: Dictionary = {
	# U9: the turn inside the office door (x 28, z 17.45-18.55; P's G2 runs stuck at (28.7, 17.9) with the kit's
	# credenza 0.3 m off the jamb): 1.6 m deep, the door's width plus 0.75 m each side, kept clear
	"U9": [[28.0, 4.2, 16.7, 29.6, 6.4, 19.3]],
}
## Rooms without the kit's ceiling grid: the hall and the bars under the lacquer (their light is the club rig).
const NO_CEILING_GRID: Array[String] = ["G6"]

## Street furniture rows: [room, name, from, to, yaw, [[asset, first, step, count, side offset], ...]]. A slot meeting a
## keep-out (the queue, the parked cars, spawns, doors) is skipped. Lamps stand at the kerb with the arm over the road
## (yaw: the road's side): Marlin Ave south of the club's front (z 32.2), Tolley St east of the club (x 38.0; the doc's
## 4000 K LED street).
const ROWS: Array = [
	["X2", "MarlinN", [-14.0, 0.0, 32.2], [36.0, 0.0, 32.2], 180.0, [
		["prop_street_lamp", 4.0, 16.0, 3, 0.0], ["prop_bin_street", 4.7, 32.0, 2, 0.0]]],
	["X2", "TolleyW", [38.0, 0.0, -10.0], [38.0, 0.0, 26.0], -90.0, [
		["prop_street_lamp", 2.0, 12.0, 3, 0.0]]],
]

## Directly placed props: [name, asset, position, yaw, metas]. Wall mounts sit on the face at `position` (centred);
## ceiling mounts hang from it.
const DIRECT_PROPS: Array = [
	# the bars' stools on the customer side facing the counter, 0.8 m apart (a slot on a patron / bartender spawn is
	# skipped): the main bar (counter x 2.2, customers east), the east bar (x 23.9, customers west), the VIP bar (z 25.9,
	# customers north)
	["StoolMain0", "prop_stool_teller", Vector3(3.0, 0.0, 10.5), 90.0, {}],
	["StoolMain1", "prop_stool_teller", Vector3(3.0, 0.0, 11.3), 90.0, {}],
	["StoolMain2", "prop_stool_teller", Vector3(3.0, 0.0, 12.1), 90.0, {}],
	["StoolMain3", "prop_stool_teller", Vector3(3.0, 0.0, 12.9), 90.0, {}],
	["StoolMain4", "prop_stool_teller", Vector3(3.0, 0.0, 13.7), 90.0, {}],
	["StoolMain5", "prop_stool_teller", Vector3(3.0, 0.0, 14.5), 90.0, {}],
	["StoolMain6", "prop_stool_teller", Vector3(3.0, 0.0, 15.3), 90.0, {}],
	["StoolMain7", "prop_stool_teller", Vector3(3.0, 0.0, 16.1), 90.0, {}],
	["StoolEast0", "prop_stool_teller", Vector3(23.0, 0.0, 8.6), -90.0, {}],
	["StoolEast1", "prop_stool_teller", Vector3(23.0, 0.0, 9.4), -90.0, {}],
	["StoolEast2", "prop_stool_teller", Vector3(23.0, 0.0, 10.2), -90.0, {}],
	["StoolEast3", "prop_stool_teller", Vector3(23.0, 0.0, 11.0), -90.0, {}],
	["StoolEast4", "prop_stool_teller", Vector3(23.0, 0.0, 11.8), -90.0, {}],
	["StoolEast5", "prop_stool_teller", Vector3(23.0, 0.0, 12.6), -90.0, {}],
	["StoolEast6", "prop_stool_teller", Vector3(23.0, 0.0, 13.4), -90.0, {}],
	["StoolVIP0", "prop_stool_teller", Vector3(12.5, 4.2, 25.0), 180.0, {}],
	["StoolVIP1", "prop_stool_teller", Vector3(13.3, 4.2, 25.0), 180.0, {}],
	["StoolVIP2", "prop_stool_teller", Vector3(14.1, 4.2, 25.0), 180.0, {}],
	["StoolVIP3", "prop_stool_teller", Vector3(14.9, 4.2, 25.0), 180.0, {}],
	["StoolVIP4", "prop_stool_teller", Vector3(15.7, 4.2, 25.0), 180.0, {}],
	["StoolVIP5", "prop_stool_teller", Vector3(16.5, 4.2, 25.0), 180.0, {}],
	["StoolVIP6", "prop_stool_teller", Vector3(17.3, 4.2, 25.0), 180.0, {}],
	["StoolVIP7", "prop_stool_teller", Vector3(18.1, 4.2, 25.0), 180.0, {}],
	["StoolVIP8", "prop_stool_teller", Vector3(18.9, 4.2, 25.0), 180.0, {}],
	["StoolVIP9", "prop_stool_teller", Vector3(19.7, 4.2, 25.0), 180.0, {}],
	# the alley: a sodium lamp over the loading door (the north facade's outer face, z -0.2; the roller x 29.5-32.5)
	["AlleyLamp", "prop_wall_lamp_sodium", Vector3(33.4, 3.4, -0.2), 0.0, {}],
	# G6: the mirror ball over the dance floor and the truss along the stage front, from the hall roof (8.0); the 2.01 m
	# units on a 2.12 m pitch (placed footprints keep 5 cm apart, _place_ext)
	["MirrorBall", "prop_ah_mirror_ball", Vector3(14.0, 8.0, 12.5), 0.0, {}],
	["TrussStage0", "prop_ah_truss_2m", Vector3(10.82, 8.0, 10.6), 0.0, {}],
	["TrussStage1", "prop_ah_truss_2m", Vector3(12.94, 8.0, 10.6), 0.0, {}],
	["TrussStage2", "prop_ah_truss_2m", Vector3(15.06, 8.0, 10.6), 0.0, {}],
	["TrussStage3", "prop_ah_truss_2m", Vector3(17.18, 8.0, 10.6), 0.0, {}],
]
