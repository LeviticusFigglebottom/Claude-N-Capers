## Navigation path queries for every ENV A system. Owner: ENV A.
## LEAD / C (OF loud: 1,498 "It's not expect to not find the most reachable polygons"): Godot 4.7 stops a path search
## after `path_search_max_polygons` (default 4096) polygons, and OF's navmesh has 4,165, so long queries failed or came
## back partial. NavigationServer3D.map_get_path has no such parameter: query through NavigationPathQueryParameters3D with
## the cap lifted (MAX_POLYGONS), and give NavigationAgent3Ds the same cap (configure_agent).
class_name NavPath
extends RefCounted

## 0 = no cap on the searched polygons (Godot: "a value of 0 or below counts as unlimited").
const MAX_POLYGONS: int = 0


## The path from `from` to `to` on navigation map `map` over `layers` (as map_get_path(map, from, to, optimize, layers)).
static func query(map: RID, from: Vector3, to: Vector3, optimize: bool = true, layers: int = 1) -> PackedVector3Array:
	var q: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
	q.map = map
	q.start_position = from
	q.target_position = to
	q.navigation_layers = layers
	q.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL if optimize \
		else NavigationPathQueryParameters3D.PATH_POSTPROCESSING_EDGECENTERED
	q.path_search_max_polygons = MAX_POLYGONS
	var r: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(q, r)
	return r.path


## An NPC / crew NavigationAgent3D without the 4096-polygon search cap.
static func configure_agent(agent: NavigationAgent3D) -> void:
	if agent != null:
		agent.path_search_max_polygons = MAX_POLYGONS
