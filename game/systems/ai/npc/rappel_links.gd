## QC-41: one-way rappel NavigationLink3Ds (Dockside Burn skylights, Night Deposit hall skylight). Owner: ENV A.
## At heist start every TacticalPoint of kind RAPPEL (heist_map.md `Tactical`) gets a child `RappelLink`:
## start at the point (roof side), end on the floor below it (first world hit of a ray straight down from
## RAY_START_BELOW_M under the point, so the skylight itself is skipped), bidirectional = false (police come
## down, nobody climbs up). NpcMotor performs the descent (`rappelling`). Police-only islands such as the
## Dockside high-bay roof reach the interior only through these links.
class_name RappelLinks
extends RefCounted

const META: StringName = &"rappel"
const LINK_NAME: String = "RappelLink"
const RAY_START_BELOW_M: float = 0.6
const RAY_LENGTH_M: float = 40.0
## World layers the floor below is found on (static world | world_dynamic).
const WORLD_MASK: int = (1 << 0) | (1 << 1)


## Build the links for `map` (in the tree). Returns how many were made.
static func build(map: Node3D) -> int:
	if map == null or not map.is_inside_tree():
		return 0
	var made: int = 0
	for n: Node in map.get_tree().get_nodes_in_group(&"rappel_point"):
		var tp: TacticalPoint = n as TacticalPoint
		if tp == null or not map.is_ancestor_of(tp) or tp.get_node_or_null(LINK_NAME) != null:
			continue
		var floor_pos: Vector3 = floor_below(tp)
		if floor_pos == Vector3.INF:
			Log.warn(&"heist", "RAPPEL point %s: no floor below it" % tp.get_path())
			continue
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = LINK_NAME
		link.bidirectional = false
		link.set_meta(META, true)
		tp.add_child(link)
		link.global_transform = Transform3D(Basis.IDENTITY, tp.global_position)
		link.start_position = Vector3.ZERO
		link.end_position = floor_pos - tp.global_position
		made += 1
	return made


## First floor hit straight below `p` (skipping RAY_START_BELOW_M), or Vector3.INF.
static func floor_below(p: Node3D) -> Vector3:
	var from: Vector3 = p.global_position - Vector3(0.0, RAY_START_BELOW_M, 0.0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - Vector3(0.0, RAY_LENGTH_M, 0.0), WORLD_MASK)
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.get("position", Vector3.INF) as Vector3 if not hit.is_empty() else Vector3.INF
