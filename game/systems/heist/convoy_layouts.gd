## A5-02 convoy layouts (Rolling Thunder D-149.1 / QC-RT1; QC-87c levelcheck). Owner: ENV A.
## A map's convoy layouts are Node3Ds with meta `convoy_layout` (an id, e.g. "north_clean"): one per route x stop
## type, holding that stop's pre-baked NavigationRegion3D / NavigationLink3D nodes, its per-layout COVER
## (TacticalPoint `enabled`), the vehicles' stop markers and any static vehicle bodies or prefabs.
## `apply(map, id)` makes `id` the active layout (\"\" = none, the start state):
## * the active layout is shown, its nav regions / links on, its TacticalPoints enabled, its GameplayPrefabs enabled
##   (server; replicated by `pe`) and its other CollisionObject3Ds collide;
## * every other layout is hidden, its nav / cover / prefabs off and its bodies out of the physics space;
## * nodes with meta `convoy_open_nav` (the open-road nav a stopped convoy replaces) are on only while no layout is.
## Navigation iterates synchronously in a heist (D-121), so path queries see the swap after the next physics frame:
## no carve, no rebake. HeistRuntime.set_convoy_layout calls it on the server and replicates the id to clients.
class_name ConvoyLayouts
extends RefCounted

const META: StringName = &"convoy_layout"
const META_OPEN_NAV: StringName = &"convoy_open_nav"


## Layout nodes under `map`, sorted by id.
static func layouts(map: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if map == null:
		return out
	for n: Node in map.find_children("*", "Node3D", true, false):
		if n.has_meta(META):
			out.append(n as Node3D)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.get_meta(META)) < String(b.get_meta(META)))
	return out


static func find(map: Node, id: String) -> Node3D:
	for l: Node3D in layouts(map):
		if String(l.get_meta(META)) == id:
			return l
	return null


## Make `id` the active layout (\"\" = none). Returns false when `id` is not a layout of `map`.
static func apply(map: Node, id: String) -> bool:
	var all: Array[Node3D] = layouts(map)
	if all.is_empty():
		return id == ""  # no convoy in this map (every other heist): nothing to switch
	if id != "" and not all.any(func(l: Node3D) -> bool: return String(l.get_meta(META)) == id):
		return false  # unknown: nothing changes
	for l: Node3D in all:
		_switch(l, String(l.get_meta(META)) == id)
	for n: Node in map.find_children("*", "", true, false):
		if n.has_meta(META_OPEN_NAV) and (n is NavigationRegion3D or n is NavigationLink3D):
			n.set(&"enabled", id == "")
	return true


static func _switch(layout: Node3D, on: bool) -> void:
	layout.visible = on
	var stack: Array[Node] = layout.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is NavigationRegion3D or n is NavigationLink3D:
			n.set(&"enabled", on)
		elif n is TacticalPoint:
			(n as TacticalPoint).set_enabled(on)
		elif n is GameplayPrefab:
			if Net.is_authority():
				(n as GameplayPrefab).set_enabled(on)
			continue  # a prefab handles its own subtree (collision, links, interaction)
		elif n is CollisionObject3D:
			n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		stack.append_array(n.get_children())
