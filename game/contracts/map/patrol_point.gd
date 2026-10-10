## A node of a PatrolGraph. Owner: LEAD. Contract: docs/contracts/heist_map.md §Patrols.
@tool
class_name PatrolPoint
extends Marker3D

## Neighbours (other PatrolPoints in the same graph). Links are bidirectional.
@export var links: Array[NodePath] = []
## Seconds the NPC pauses here: random in [x, y]. (0,0) = walk through.
@export var pause_range: Vector2 = Vector2(0.0, 0.0)
## If true, NPC turns to face this node's -Z while pausing (look at a door, a window...).
@export var face_marker_forward: bool = false
## Optional animation hint while pausing: &"idle", &"phone", &"smoke", &"check_door", &"lean".
@export var pause_anim: StringName = &"idle"
## Tags filter which NPC roles may use this point: e.g. [&"guard"], [&"civilian"], [&"staff"].
@export var tags: Array[StringName] = [&"guard"]
## Relative chance this point is picked as a route branch (route randomisation).
@export var weight: float = 1.0
