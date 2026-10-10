## Container of PatrolPoints forming one patrol network. Owner: LEAD.
## Route generation (ENV A) picks a random walk/loop over this graph per guard per run
## (GameRng stream &"patrols"). ENV C must ensure every point is on navmesh and connected.
@tool
class_name PatrolGraph
extends Node3D

@export var graph_id: StringName = &"main"
## Floor index this graph lives on (multi-floor graphs: connect via stair PatrolPoints).
@export var floor_index: int = 0


func _ready() -> void:
	add_to_group(G.PATROL_GRAPH)


func points() -> Array[PatrolPoint]:
	var out: Array[PatrolPoint] = []
	for c: Node in find_children("*", "PatrolPoint", true, false):
		out.append(c as PatrolPoint)
	return out
