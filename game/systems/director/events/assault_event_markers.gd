## PO6-17 marker lookup (ENV C contract, docs/levels/_art/po6_17/README.md §5): Marker3Ds under the map's
## `AssaultEvents` node (group `assault_events`): TurretVan_<n> (+Z = van forward), HeliOrbit_<n> (meta radius),
## HeliDrop_<n>, Breach_<n> (meta kind wall|window|ceiling, size Vector2, -Z into the room). Owner: ENV A.
## Maps without them use fallbacks so events still fire (AssaultEventRunner): police spawns for the van and the
## heli drop, the map's mesh bounds for the orbit, ENTRY points as fx-only breaches.
class_name AssaultEventMarkers
extends RefCounted

const ROOT_NAME: String = "AssaultEvents"
const GROUP: StringName = &"assault_events"
const VAN: String = "TurretVan"
const HELI_ORBIT: String = "HeliOrbit"
const HELI_DROP: String = "HeliDrop"
const BREACH: String = "Breach"


static func root(map: Node) -> Node:
	if map == null:
		return null
	var r: Node = map.get_node_or_null(NodePath(ROOT_NAME))
	if r != null:
		return r
	if map.is_inside_tree():
		for n: Node in map.get_tree().get_nodes_in_group(GROUP):
			if map.is_ancestor_of(n):
				return n
	return null


## Markers named `<prefix>_<n>` under the root, sorted by name (deterministic order).
static func list(map: Node, prefix: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var r: Node = root(map)
	if r == null:
		return out
	for c: Node in r.get_children():
		var n3: Node3D = c as Node3D
		if n3 != null and String(c.name).begins_with(prefix + "_"):
			out.append(n3)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	return out


## Bounds of the map's meshes (fallback orbit). Cached on the map as metadata.
static func map_bounds(map: Node3D) -> AABB:
	if map.has_meta(&"_po6_17_bounds"):
		return map.get_meta(&"_po6_17_bounds") as AABB
	var out: AABB = AABB(map.global_position - Vector3(15, 0, 15), Vector3(30, 6, 30))
	var first: bool = true
	for n: Node in map.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	map.set_meta(&"_po6_17_bounds", out)
	return out


## Closest navmesh point to `p` within `max_m` (Vector3.INF when the map has no nav or it is farther).
static func nav_point(ctx: Node3D, p: Vector3, max_m: float = 1.0) -> Vector3:
	var nav: RID = ctx.get_world_3d().navigation_map
	if not nav.is_valid() or NavigationServer3D.map_get_iteration_id(nav) == 0:
		return Vector3.INF
	var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, p)
	return c if c.distance_to(p) <= max_m else Vector3.INF
