## One extra firing-range lane (B4-13): a dummy outside the nine static distance lanes, in the
## moving-target area (speed_mps > 0: on a lateral RangeTrack) or the armory area (armored dummies).
## Owner: ENV B. Rows live in range_layout.tres (`extra_lanes`).
class_name RangeLaneDef
extends Resource

const AREA_MOVING: StringName = &"moving"
const AREA_ARMORY: StringName = &"armory"

@export var area: StringName = AREA_ARMORY
@export var dummy: StringName = &"range_dummy.light"   ## RangeDummyDef id
@export var distance_m: float = 15.0                   ## from the shooting line (-Z)
@export var x_m: float = 0.0                           ## lane / track centre X
@export_group("Track (moving area)")
@export var speed_mps: float = 0.0                     ## 0 = static; P7 brief: 2..5 m/s
@export var track_half_m: float = 0.0                  ## the carriage runs x_m +- this
@export var phase_s: float = 0.0                       ## start offset into the cycle


func is_moving() -> bool:
	return speed_mps > 0.0 and track_half_m > 0.0
