## Loud police AI tunables (PoliceBrain: Patrol Officer, TAC Light; L4.2). Owner: ENV A.
## Data: police_tweak.tres. ◇ = design values.
class_name PoliceTweak
extends Resource

## Target re-evaluation interval range (s).
@export var retarget_s: Vector2 = Vector2(0.5, 1.0)
## Cover-lite: a COVER TacticalPoint within this distance band of the target with LOS to it.
@export var cover_min_m: float = 8.0
@export var cover_max_m: float = 20.0
## Cover search only considers points within this distance of the unit.
@export var cover_search_m: float = 35.0
## Standoff band without cover: close in beyond max (or without LOS), back off under min.
@export var standoff_min_m: float = 8.0
@export var standoff_pref_m: float = 11.0
@export var standoff_max_m: float = 15.0
@export var fire_range_m: float = 40.0
## Flank-lite: chance a fresh unit first visits a FLANK point near the target.
@export var flank_chance: float = 0.3
@export var flank_max_from_target_m: float = 30.0
@export var flank_timeout_s: float = 12.0
@export var arrive_m: float = 0.8
@export var fallback_run_speed: float = 3.5
