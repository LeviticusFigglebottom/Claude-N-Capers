## OF-A4 (D-136 §3b.4): one stop of a CivilianRoute (a child of the route node, in walk order). Owner: ENV A.
## A PatrolPoint, so the PatrolPoint fields keep their meaning for the routed civilian:
##   pause_range          dwell seconds at the stop, random in [x, y] (GameRng &"civilian_routes"); (0, 0) = walk through
##   pause_anim           the ambient clip / hint while dwelling (&"teller", &"desk", &"smoke", &"look", &"phone"...;
##                        &"idle" = the civilian's own idle activity); seated clips fall back to standing off a seat (PO6-06)
##   face_marker_forward  face this node's -Z while dwelling (the counter, the desk, the window)
## `tags` default to [&"civilian_route"], so wander (civilian/staff), cower and guard patrols never use the stop.
@tool
class_name CivilianRouteStop
extends PatrolPoint

## Non-empty: an "away" window named for HUD / intel (&"manager_away", &"teller_away"...). The window opens when the
## civilian sets off toward this stop and closes when it arrives at a stop whose away_window differs (back at its post).
## CivilianRoute.is_away(window) / away_changed report it.
@export var away_window: StringName = &""


func _init() -> void:
	tags = [&"civilian_route"] as Array[StringName]
