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
const KEEP_OUT: Dictionary = {}
## Rooms without the kit's ceiling grid: the hall and the bars under the lacquer (their light is the club rig).
const NO_CEILING_GRID: Array[String] = ["G6"]

## Street furniture rows: [room, name, from, to, yaw, [[asset, first, step, count, side offset], ...]].
const ROWS: Array = []

## Directly placed props: [name, asset, position, yaw, metas]. Wall mounts sit on the face at `position` (centred);
## ceiling mounts hang from it.
const DIRECT_PROPS: Array = [
	# G6: the mirror ball over the dance floor and the truss along the stage front, from the hall roof (8.0); the 2.01 m
	# units on a 2.12 m pitch (placed footprints keep 5 cm apart, _place_ext)
	["MirrorBall", "prop_ah_mirror_ball", Vector3(14.0, 8.0, 12.5), 0.0, {}],
	["TrussStage0", "prop_ah_truss_2m", Vector3(10.82, 8.0, 10.6), 0.0, {}],
	["TrussStage1", "prop_ah_truss_2m", Vector3(12.94, 8.0, 10.6), 0.0, {}],
	["TrussStage2", "prop_ah_truss_2m", Vector3(15.06, 8.0, 10.6), 0.0, {}],
	["TrussStage3", "prop_ah_truss_2m", Vector3(17.18, 8.0, 10.6), 0.0, {}],
]
