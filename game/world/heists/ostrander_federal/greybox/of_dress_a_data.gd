## Ostrander Federal G2 dressing data, lane A (OF-C2, ENV C): the banking hall BH, the vestibule VE and the plaza X1.
## Read by of_dress_a.gd. Design: docs/design/heists/ostrander_federal.md (Site; Ground notes; Room list BH / VE / X1;
## Audio/lighting: palette limestone #CBC3B0, deep ultramarine #2F3F6B, meridian bronze #B8873A, the hall's 3000 K
## bronze pendants; Budgets: hall density 0.03-0.06 props/m², the meridian line kept clear).
extends RefCounted

const FG: float = 0.0
## The plaza and the avenue (grade boxes' top).
const FP: float = -0.75
## The hall's coffered ceiling (the SlabE underside) and the gallery slab's underside.
const CEIL: float = 8.0

## Finish zones [id, min, max]: a shell face belongs to the first zone holding the point 5 cm in front of it (big faces
## are cut at the zone bounds). BH is the hall void and the strip under the gallery; BHC the coffered ceiling over the
## gallery (GA is lane C's room; its ceiling is the hall's); X1 the plaza, the avenue and the facade's outer face.
const ZONES: Array = [
	["VE", Vector3(20.0, -0.1, 32.0), Vector3(28.0, 4.3, 36.0)],
	["BH", Vector3(8.0, -0.1, 17.0), Vector3(40.0, 4.25, 20.0)],
	["BH", Vector3(8.0, -0.1, 20.0), Vector3(40.0, 8.62, 36.0)],
	["BHC", Vector3(8.0, 7.9, 17.0), Vector3(40.0, 8.05, 20.0)],
	["X1", Vector3(-16.0, -2.0, 36.03), Vector3(66.0, 30.0, 64.0)],
]
## Shell groups (Geometry/Building/<group>) other lanes draw: lane B's counter and lantern, the lid (OF-A6 burn), the
## vault cages, the stairs and the fire escape (lane C), the visual-only boxes (lane B's meridian line replaces its box).
const SKIP_GROUPS: Array[String] = ["Counter", "Lantern", "Lid", "Cages", "Stairs", "StairFlights", "FireEscape",
	"Visual"]
## The vestibule enclosure (walls and roof slab inside the hall): its hall faces are dark bronze (the bronze-and-glass
## vestibule, landmark 3) and its transom over the inner doors is glazed.
const VE_BOX_LO: Vector3 = Vector3(19.85, -0.1, 31.85)
const VE_BOX_HI: Vector3 = Vector3(28.15, 4.45, 36.0)
## Transom pieces over the inner doors (wall boxes inside this range from 2.2 m up): bronze-framed glass.
const TRANSOM_LO: Vector3 = Vector3(21.85, 2.15, 31.85)
const TRANSOM_HI: Vector3 = Vector3(26.15, 4.45, 32.15)
## Whole-box finishes by group or node name (every face).
const NAME_FINISH: Dictionary = {
	"Pillars": "marble", "GuardBase": "of_limestone", "GuardCap": "of_bronze", "Sills": "of_granite",
}

## Faces of a lane-A box outside the zones (another lane's room): greybox material -> a plain textured stand-in.
const OTHER_FINISH: Dictionary = {
	"grey_wall": "plaster", "grey_wall_ext": "of_limestone", "grey_floor": "concrete", "grey_ceiling": "plaster",
	"grey_stair": "concrete", "grey_glass": "glass", "grey_trim": "of_bronze_dark", "grey_frame": "of_bronze_dark",
	"grey_counter": "walnut", "grey_prop": "walnut", "grey_door": "walnut",
}
## Wall bands in BH / VE (world y): skirting, the marble dado to 1.1 m, limestone above (VE: marble to the ceiling).
const SKIRT_H: float = 0.15
const DADO_H: float = 1.1
## Ashlar coursing over limestone (BH upper walls, the facade): course height, block length, joint width (m).
const ASHLAR_COURSE: float = 0.6
const ASHLAR_BLOCK: float = 1.2
const ASHLAR_JOINT: float = 0.012
## The hall's south wall (inner face z 35.8): pilasters on the window piers [centre x], a cornice in the bays between
## them [x0, x1] under the perimeter beam (y 7.55).
const HALL_S_FACE: float = 35.8
const PILASTERS: Array = [[9.1], [14.0], [18.9], [29.1], [34.0], [38.9]]
const PILASTER_W: float = 0.7
const PILASTER_D: float = 0.12
const CORNICE_Y0: float = 7.2
const CORNICES: Array = [[8.1, 20.0], [28.0, 39.9]]
## Bronze panel strips on the vestibule's inner marble walls: [axis (0 x / 2 z), plane, outward sign, u].
const VE_STRIPS: Array = [
	[0, 20.1, 1.0, 33.2], [0, 20.1, 1.0, 34.6], [0, 27.9, -1.0, 33.2], [0, 27.9, -1.0, 34.6],
	[2, 32.1, 1.0, 20.95], [2, 32.1, 1.0, 27.05], [2, 35.8, -1.0, 20.95], [2, 35.8, -1.0, 27.05],
]
## Facade bands in X1: the granite plinth to 0.9 m, limestone above.
const PLINTH_H: float = 0.9

## Floor paint per zone: [x0, z0, x1, z1, key] in order; the first rect holding a piece wins ("" = no face: the meridian
## line's inlay band covers it); the rest is the zone's field. BH: a 0.4 m ultramarine border, 0.12 m ultramarine joints
## every 4 m (the panels read at hall scale), the meridian band. VE: a 0.3 m border round a marble field.
const MERIDIAN_RECT: Array = [23.75, 17.5, 24.25, 31.9]
const FLOOR_PAINT: Dictionary = {
	"BH": [
		[23.75, 17.5, 24.25, 31.9, ""],
		[8.0, 17.0, 8.5, 36.0, "of_marble_blue"], [39.5, 17.0, 40.0, 36.0, "of_marble_blue"],
		[8.0, 35.4, 40.0, 36.0, "of_marble_blue"], [8.0, 17.45, 40.0, 17.85, "of_marble_blue"],
		[19.5, 31.5, 28.5, 32.0, "of_marble_blue"], [19.5, 31.5, 20.0, 36.0, "of_marble_blue"],
		[28.0, 31.5, 28.5, 36.0, "of_marble_blue"],
		[8.0, 20.94, 40.0, 21.06, "of_marble_blue"], [8.0, 24.94, 40.0, 25.06, "of_marble_blue"],
		[8.0, 28.94, 40.0, 29.06, "of_marble_blue"],
		[11.94, 17.0, 12.06, 36.0, "of_marble_blue"], [15.94, 17.0, 16.06, 36.0, "of_marble_blue"],
		[19.94, 17.0, 20.06, 36.0, "of_marble_blue"], [27.94, 17.0, 28.06, 36.0, "of_marble_blue"],
		[31.94, 17.0, 32.06, 36.0, "of_marble_blue"], [35.94, 17.0, 36.06, 36.0, "of_marble_blue"],
	],
	"VE": [
		[20.0, 32.0, 20.4, 36.0, "of_marble_blue"], [27.6, 32.0, 28.0, 36.0, "of_marble_blue"],
		[20.0, 32.0, 28.0, 32.4, "of_marble_blue"], [20.0, 35.4, 28.0, 36.0, "of_marble_blue"],
	],
}
## Zone face finishes: floor field, ceiling, upper walls.
const ZONE_FINISH: Dictionary = {
	"BH": {"floor": "marble", "ceiling": "of_plaster_ultramarine", "soffit": "of_limestone", "wall": "of_limestone",
		"top": "of_limestone"},
	"BHC": {"floor": "marble", "ceiling": "of_plaster_ultramarine", "soffit": "of_plaster_ultramarine",
		"wall": "of_limestone", "top": "of_limestone"},
	"VE": {"floor": "marble", "ceiling": "plaster", "soffit": "plaster", "wall": "marble", "top": "marble"},
	"X1": {"floor": "of_granite", "ceiling": "of_limestone", "soffit": "of_limestone", "wall": "of_limestone",
		"top": "of_granite"},
}

## Site meshes (Geometry/Site/**) seen from the plaza: node name -> finish (world-triplanar material over the box /
## hull; the greybox mesh stays, its material is overridden). Plaza paving pale, the apron and steps granite, the
## avenue asphalt, the Assay Office limestone, the Corvino Building brick, the Belmont rendered.
const SITE_FINISH: Dictionary = {
	"GradeApron": "of_granite", "GradeApronSteps": "of_granite", "GradePlazaW": "concrete_light", "GradePlazaWS": "concrete_light",
	"GradePlazaSteps": "concrete_light", "GradePlazaE": "concrete_light", "GradeAvenueEastKerb": "concrete_light",
	"GradeAvenue": "asphalt", "GradeTanneryMouth": "asphalt", "GradeTannery": "asphalt",
	"PoliceIslandP1": "asphalt", "PoliceIslandP2": "asphalt",
	"AvenueWBarriers": "plastic_white", "AvenueEBarriers": "plastic_white", "RoadWorksTruck": "metal_yellow",
	"StalledBus": "metal_red", "AssayBalustrade": "of_limestone", "AssayOffice": "of_limestone",
	"CorvinoLower": "brick", "CorvinoTower": "brick", "CorvinoParapetN": "of_limestone",
	"CorvinoParapetE": "of_limestone", "CorvinoBalconyS3": "metal_dark", "BelmontArms": "plaster",
	"Step01": "of_granite", "Step02": "of_granite", "Step03": "of_granite", "Step04": "of_granite",
	"Step05": "of_granite",
}
## Finish key -> material resource.
const MATERIALS: Dictionary = {
	"marble": "res://world/materials/marble_cream.tres",
	"concrete": "res://world/materials/concrete.tres",
	"walnut": "res://world/materials/wood_veneer_walnut.tres",
	"plaster": "res://world/materials/plaster_painted.tres",
	"asphalt": "res://world/materials/asphalt.tres",
	"brick": "res://world/materials/brick_red.tres",
	"brass": "res://world/materials/brass.tres",
	"paint_white": "res://world/materials/paint_white.tres",
	"of_limestone": "res://world/props/materials/pr_of_limestone.tres",
	"of_bronze": "res://world/props/materials/pr_of_bronze.tres",
	"of_bronze_dark": "res://world/props/materials/pr_of_bronze_dark.tres",
	"of_gilt": "res://world/props/materials/pr_of_gilt.tres",
	"of_marble_blue": "res://world/props/materials/pr_of_marble_blue.tres",
	"of_plaster_ultramarine": "res://world/props/materials/pr_of_plaster_ultramarine.tres",
	"of_granite": "res://world/props/materials/pr_of_granite.tres",
	"concrete_light": "res://world/props/materials/pr_concrete_light.tres",
	"plastic_white": "res://world/props/materials/pr_plastic_white.tres",
	"metal_yellow": "res://world/props/materials/pr_metal_yellow.tres",
	"metal_red": "res://world/props/materials/pr_metal_red.tres",
	"metal_dark": "res://world/props/materials/pr_metal_dark.tres",
}

## The coffered ceiling (hall + gallery, under the SlabE underside at 8.0): beam lines [coordinate, half width, depth].
## Major beams: the walls' perimeter, the gallery front (z 20) and the lantern oculus (x 14.3 / 29.7, z 22.3 / 29.7:
## they sit outside the opening, their inner faces gilt); minor beams split the bays into ~2-2.6 m coffers. A beam
## along x crossing the oculus (z strictly inside 22.3-29.7) stops at its edges, and so does one along z.
const OCULUS: Array = [14.3, 22.3, 29.7, 29.7]
const COFFER_X: Array = [[8.35, 0.25, 0.45], [10.2, 0.14, 0.3], [12.25, 0.14, 0.3], [14.05, 0.25, 0.45],
	[16.867, 0.14, 0.3], [19.433, 0.14, 0.3], [22.0, 0.14, 0.3], [24.567, 0.14, 0.3], [27.133, 0.14, 0.3],
	[29.95, 0.25, 0.45], [31.76, 0.14, 0.3], [33.82, 0.14, 0.3], [35.88, 0.14, 0.3], [37.94, 0.14, 0.3],
	[39.65, 0.25, 0.45]]
const COFFER_Z: Array = [[17.3, 0.2, 0.45], [18.55, 0.14, 0.3], [20.0, 0.25, 0.45], [22.05, 0.25, 0.45],
	[24.767, 0.14, 0.3], [27.233, 0.14, 0.3], [29.95, 0.25, 0.45], [31.733, 0.14, 0.3], [33.767, 0.14, 0.3],
	[35.55, 0.25, 0.45]]
const COFFER_X0: float = 8.1
const COFFER_X1: float = 39.9
const COFFER_Z0: float = 17.1
const COFFER_Z1: float = 35.8
## Gilt rosette (half size, depth) at each whole coffer's centre.
const ROSETTE: Vector2 = Vector2(0.17, 0.04)

## The hall's pendants: ten 3000 K bronze drum lanterns at coffer centres (y 8.0), clear of the oculus, the gallery
## guard and the vestibule roof. The doc's budget is the sun + 4 hall pendants, but the hall views' conservative frustum
## count (levelcheck perf, no occlusion) already holds the sun and lane C's six room fixtures (SR, VT, PR, OF, LD, BB):
## one pendant fits (8); the other three wait for those to leave the hall views (lead ruling, see the lane A report).
const PENDANTS: Array = [
	["PendantN1", Vector3(11.225, CEIL, 21.025)], ["PendantN2", Vector3(18.15, CEIL, 21.025)],
	["PendantN3", Vector3(30.855, CEIL, 21.025)], ["PendantN4", Vector3(36.91, CEIL, 21.025)],
	["PendantW", Vector3(11.225, CEIL, 26.0)], ["PendantE", Vector3(34.85, CEIL, 26.0)],
	["PendantS1", Vector3(11.225, CEIL, 30.84)], ["PendantS2", Vector3(18.15, CEIL, 30.84)],
	["PendantS3", Vector3(30.855, CEIL, 30.84)], ["PendantS4", Vector3(36.91, CEIL, 30.84)],
]
const SHADOW_PENDANTS: Array[String] = ["PendantS2"]

## G1 furniture boxes (Props/MapBuilt) -> exact-fit art: [box, asset, yaw]. The greybox mesh is hidden, the collider,
## metas and nav obstruction stay; the art (bottom-centre pivot) stands at the box's floor centre.
const MAPBUILT_ART: Array = [
	["CheckDesk1", "prop_of_check_desk", 0.0], ["CheckDesk2", "prop_of_check_desk", 0.0],
	["CheckDesk3", "prop_of_check_desk", 0.0], ["CheckDesk4", "prop_of_check_desk", 0.0],
	["HallBenchW1", "prop_of_hall_bench", 90.0], ["HallBenchW2", "prop_of_hall_bench", 90.0],
	["HallBenchE1", "prop_of_hall_bench", 90.0], ["HallBenchE2", "prop_of_hall_bench", 90.0],
	["HallBenchSW", "prop_of_hall_bench", 0.0], ["HallBenchSE", "prop_of_hall_bench", 0.0],
	["QueueRail1", "prop_of_queue_rail_w900", 0.0], ["QueueRail2", "prop_of_queue_rail_w900", 0.0],
	["Kiosk", "prop_of_news_kiosk", 180.0],
	["PlazaPlanter1", "prop_of_planter_sq120", 0.0], ["PlazaPlanter2", "prop_of_planter_sq120", 0.0],
	["PlazaPlanter3", "prop_of_planter_sq120", 0.0], ["PlazaPlanter4", "prop_of_planter_sq120", 0.0],
	["PlazaPlanter5", "prop_of_planter_sq120", 0.0],
	["PlazaBench1", "prop_bench_stone", 180.0], ["PlazaBench2", "prop_bench_stone", 180.0],
	["ParkedCar2", "veh_car_sedan_navy", 90.0], ["ParkedCar3", "veh_car_sedan_wine", -90.0],
]

## Placed props: [name, asset, position (floor items at the floor, wall items at their centre on the wall face, ceiling
## items at the ceiling, "on" items on the host top), yaw (deg; the front -Z: 0 north, 180 south, 90 west, -90 east)].
## BH (x 8-40, z 17-36; patrol points, spawns, covers and the meridian strip stay clear): slip trays on the four check
## desks (off the centre rail), palms in the window piers and by the vestibule, the lobby guard's podium west of his
## post (24, 30), bins at the outer check desks.
const BH_PROPS: Array = [
	["SlipsDesk1", "prop_deposit_slips", [13.6, 1.0, 25.66], 180.0],
	["SlipsDesk2", "prop_deposit_slips", [19.9, 1.0, 25.34], 0.0],
	["SlipsDesk3", "prop_deposit_slips", [28.1, 1.0, 25.66], 180.0],
	["SlipsDesk4", "prop_deposit_slips", [34.4, 1.0, 25.34], 0.0],
	["PalmCornerW", "prop_plant_tall", [9.35, 0.0, 34.9], 180.0],
	["PalmCornerE", "prop_plant_tall", [38.65, 0.0, 34.9], 180.0],
	["PalmVestibuleW", "prop_plant_tall", [19.3, 0.0, 32.4], 180.0],
	["PalmVestibuleE", "prop_plant_tall", [28.7, 0.0, 32.4], 180.0],
	["GuardPodium", "prop_lectern", [22.7, 0.0, 30.35], 180.0],
	["BinDeskW", "prop_bin_office", [12.45, 0.0, 25.5], 0.0],
	["BinDeskE", "prop_bin_office", [35.55, 0.0, 25.5], 0.0],
]
## VE (x 20.1-27.9, z 32.1-35.8, ceiling 4.2): the greeter's lectern by the west wall, a velvet rope along the east wall,
## two palms by the inner doors, three downlights, a clock over the inner doors.
const VE_PROPS: Array = [
	["GreeterLectern", "prop_lectern", [20.75, 0.0, 34.0], -90.0],
	["VelvetRope", "prop_stanchion_velvet", [27.45, 0.0, 33.9], 90.0],
	["PalmVEW", "prop_plant_tall", [20.55, 0.0, 32.55], 0.0],
	["PalmVEE", "prop_plant_tall", [27.45, 0.0, 32.55], 0.0],
	["DownlightVE1", "prop_downlight", [22.0, 4.2, 34.0], 0.0],
	["DownlightVE2", "prop_downlight", [24.0, 4.2, 34.0], 0.0],
	["DownlightVE3", "prop_downlight", [26.0, 4.2, 34.0], 0.0],
]
## X1 (plaza z 36-48 at -0.75, the apron at 0, the avenue z 48-62, the far sidewalk z 59-62): street lamps on both kerbs,
## bollards in short groups by the benches (the central approach x 14-34 stays open: the Wrecker's vehicle route, the
## spawn and the steps), street bins, a bus shelter on the far sidewalk, two more parked cars at the plaza kerb.
const X1_PROPS: Array = [
	["PlazaLamp1", "prop_street_lamp", [-10.0, FP, 47.4], 180.0],
	["PlazaLamp2", "prop_street_lamp", [3.6, FP, 47.4], 180.0],
	["PlazaLamp3", "prop_street_lamp", [14.0, FP, 47.4], 180.0],
	["PlazaLamp4", "prop_street_lamp", [34.0, FP, 47.4], 180.0],
	["PlazaLamp5", "prop_street_lamp", [46.0, FP, 47.4], 180.0],
	["PlazaLamp6", "prop_street_lamp", [58.0, FP, 47.4], 180.0],
	["AvenueLamp1", "prop_street_lamp", [-6.0, FP, 61.3], 0.0],
	["AvenueLamp2", "prop_street_lamp", [12.0, FP, 61.3], 0.0],
	["AvenueLamp3", "prop_street_lamp", [34.0, FP, 61.3], 0.0],
	["AvenueLamp4", "prop_street_lamp", [56.0, FP, 61.3], 0.0],
	["PlazaBollardW1", "prop_bollard_steel", [8.6, FP, 47.4], 0.0],
	["PlazaBollardW2", "prop_bollard_steel", [9.9, FP, 47.4], 0.0],
	["PlazaBollardW3", "prop_bollard_steel", [11.2, FP, 47.4], 0.0],
	["PlazaBollardE1", "prop_bollard_steel", [36.8, FP, 47.4], 0.0],
	["PlazaBollardE2", "prop_bollard_steel", [38.1, FP, 47.4], 0.0],
	["PlazaBollardE3", "prop_bollard_steel", [39.4, FP, 47.4], 0.0],
	["PlazaBinW", "prop_bin_street", [5.0, FP, 47.3], 0.0],
	["PlazaBinE", "prop_bin_street", [43.0, FP, 47.3], 0.0],
	["AvenueBin", "prop_bin_street", [29.0, FP, 61.4], 180.0],
	["BusShelter", "prop_bus_shelter", [44.0, FP, 60.95], 0.0],
	["ParkedCarPlazaW", "veh_car_sedan_silver", [0.0, FP, 49.45], 90.0],
	["ParkedCarPlazaE", "veh_car_sedan_navy", [52.0, FP, 49.45], -90.0],
]
## Daytime exterior lamps barely on (lane C's DIRECT_LIGHT); the hall pendants' 3000 K.
const EXT_LIGHT_ENERGY: float = 0.25

## Arched window bays (prop_of_window_bay, 3.2 x 5.5 from the 1.0 m sill): [name, centre x]; one on each face of the
## glass (z 35.98 / 36.02).
const WINDOW_BAYS: Array = [["W1", 11.8], ["W2", 16.2], ["W3", 31.8], ["W4", 36.2]]
const WINDOW_SILL: float = 1.0
## The small gallery-level facade windows (Pane85_M / Pane86_M): [x0, x1, y0, y1] at z 36 (bronze frame boxes).
const SMALL_WINDOWS: Array = [[2.5, 3.5, 5.9, 7.4], [44.5, 45.5, 5.9, 7.4]]

## Facade trims on the plaza face (z 36.2): [x0, x1, y0, y1, proud, key]; the plinth cap skips the AV street door and the
## bronze portal (lane B), the string course skips the sunburst and frieze. OF-C2: the plinth cap also stops at the two
## window breaches (Breach_1 / _2 at x 11.8 / 36.2: 3 mm short of their infill sill, 1.054 m; blown, no cap bridges
## the hole) and 4 mm clear of the AV street door's frame.
const FACADE_TRIMS: Array = [
	[0.0, 3.0, 0.86, 0.94, 0.05, "of_granite"], [5.004, 11.27, 0.86, 0.94, 0.05, "of_granite"],
	[12.33, 21.3, 0.86, 0.94, 0.05, "of_granite"], [26.7, 35.67, 0.86, 0.94, 0.05, "of_granite"],
	[36.73, 48.0, 0.86, 0.94, 0.05, "of_granite"],
	[0.0, 18.1, 4.92, 5.08, 0.08, "of_limestone"], [29.9, 48.0, 4.92, 5.08, 0.08, "of_limestone"],
	[0.0, 48.0, 8.36, 8.6, 0.16, "of_limestone"],
]

## Fill lights (level_standards §3.7: meta fill, energy <= 0.3, no shadows, <= 2 per room): [name, position, range].
## BH's two fills are the lighting lane's warm pools (of_gi.gd HallPools); lane A lights only the vestibule.
const FILLS: Array = [
	["FillVE_0", Vector3(24.0, 3.6, 34.0), 5.0],
]
## The street lane markings on the avenue (paint_white quads 5 mm over the asphalt): the centre line (dashed) and
## the lane lines, [z, half width, dash, gap]; the far sidewalk and the plaza kerb as paving strips [z0, z1].
const LANE_LINES: Array = [[55.0, 0.06, 3.0, 0.0], [52.0, 0.05, 3.0, 6.0], [58.0, 0.05, 3.0, 6.0]]
const SIDEWALK_STRIPS: Array = [[59.0, 62.0, "concrete_light"], [47.75, 48.0, "of_granite"]]
const STREET_X0: float = -16.0
const STREET_X1: float = 66.0
