## Firing range geometry and lane list (B1-05, pd2_fidelity.md P7). Owner: ENV B.
## Data: res://content/data/range/range_layout.tres. RangeBuilder turns it into a level.
##
## Frame: the shooting line is z = 0, lanes run toward Godot -Z, x = 0 is the centre of the lanes.
## Distances are meters measured from the shooting line. Pieces come from ENV C's greybox kit
## (docs/art/pipeline.md §10): floors have a corner origin and extend +X / -Z, walls start at their
## origin and run +X (rotated 90 deg about Y they run -Z).
class_name RangeLayout
extends Resource

@export_group("Greybox kit")
@export var floor_piece: PackedScene              ## arch_floor_w400
@export var floor_piece_size_m: float = 4.0
@export var wall_piece: PackedScene               ## arch_wall_int_w400_h400
@export var wall_piece_length_m: float = 4.0

@export_group("Extents")
@export var back_z_m: float = 6.0                 ## back wall, behind the shooting line (+Z)
@export var far_z_m: float = -106.0               ## backstop wall (-Z)
@export var width_m: float = 24.0                 ## wall to wall; a multiple of floor_piece_size_m

@export_group("Lanes")
@export var lane_width_m: float = 2.5
## One lane per entry; the lane's static target stands at this distance. Lane 0 is the leftmost.
@export var lane_target_distances: PackedFloat32Array = PackedFloat32Array()
## RangeDummyDef id placed in every lane.
@export var lane_dummy: StringName = &"range_dummy.light"
## Lane used for the readout before anything was hit.
@export var default_readout_lane: int = 3

@export_group("Markers")
## Distance markers (floor line across all lanes plus a sign on each side wall).
@export var marker_distances: PackedFloat32Array = PackedFloat32Array()
@export var marker_sign_height_m: float = 0.9
@export var marker_sign_inset_m: float = 1.0       ## sign centre distance from the side wall
@export var marker_sign_yaw_deg: float = 50.0      ## turned from the wall toward the shooting line
@export var target_sign_height_m: float = 2.5      ## distance label above each target
@export var marker_line_width_m: float = 0.08
@export var lane_line_width_m: float = 0.05

@export_group("Shooting booth")
@export var bench_z_m: float = -0.45              ## bench centre (just in front of the line)
@export var bench_depth_m: float = 0.5
@export var bench_height_m: float = 1.0
@export var spawn_position: Vector3 = Vector3(0.0, 0.0, 0.0)   ## feet of the shooter / crew spawn (on the line)
@export var eye_height_m: float = 1.65


## Number of lanes (one target each).
func lane_count() -> int:
	return lane_target_distances.size()


## X of the centre of `lane`.
func lane_x(lane: int) -> float:
	var total: float = lane_width_m * float(lane_count())
	return -total * 0.5 + (float(lane) + 0.5) * lane_width_m


## Total length of the hall (back wall to backstop).
func length_m() -> float:
	return back_z_m - far_z_m
