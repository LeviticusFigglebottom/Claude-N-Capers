## A5-02 convoy layouts (Rolling Thunder D-149.1 / QC-RT1; QC-87c levelcheck). Owner: ENV A.
## A map's layouts are Node3Ds with meta `convoy_layout` (an id, e.g. "north_clean"), each holding that state's
## pre-baked NavigationRegion3D / NavigationLink3D nodes, its per-layout COVER (TacticalPoint `enabled`), stop markers
## and any static bodies or prefabs. Layouts belong to a group (meta `layout_group`, default "convoy"): one layout per
## group is active at a time, groups switch independently (the convoy stop, the mixer gone, the Tannery gate open).
## `apply(map, id, group)` makes `id` the group's active layout ("" = none, the start state):
## * the active layout is shown, its nav regions / links on, its TacticalPoints enabled, its GameplayPrefabs enabled
##   (server; replicated by `pe`) and its other CollisionObject3Ds collide;
## * the group's other layouts are hidden, their nav / cover / prefabs off and their bodies out of the physics space;
## * NavigationRegion3D / Link3D nodes with meta `convoy_open_nav` = the group name (the nav a layout replaces, e.g.
##   the open road before the convoy stops) are on only while the group has no active layout.
## Navigation iterates synchronously in a heist (D-121), so path queries see the swap after the next physics frame:
## no carve, no rebake. HeistRuntime.set_layout calls it on the server and replicates the ids to clients.
class_name ConvoyLayouts
extends RefCounted

const META: StringName = &"convoy_layout"
const META_GROUP: StringName = &"layout_group"
const META_OPEN_NAV: StringName = &"convoy_open_nav"
const DEFAULT_GROUP: String = "convoy"


## Layout nodes under `map` ("" group = every group), sorted by id.
static func layouts(map: Node, group: String = "") -> Array[Node3D]:
	var out: Array[Node3D] = []
	if map == null:
		return out
	for n: Node in map.find_children("*", "Node3D", true, false):
		if n.has_meta(META) and (group == "" or group_of(n) == group):
			out.append(n as Node3D)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.get_meta(META)) < String(b.get_meta(META)))
	return out


static func group_of(layout: Node) -> String:
	return String(layout.get_meta(META_GROUP, DEFAULT_GROUP))


static func find(map: Node, id: String) -> Node3D:
	for l: Node3D in layouts(map):
		if String(l.get_meta(META)) == id:
			return l
	return null


## Make `id` the active layout of `group` ("" = none). False (and nothing changes) when `id` is not in the group.
static func apply(map: Node, id: String, group: String = DEFAULT_GROUP) -> bool:
	var all: Array[Node3D] = layouts(map, group)
	if id != "" and not all.any(func(l: Node3D) -> bool: return String(l.get_meta(META)) == id):
		return false
	for l: Node3D in all:
		_switch(l, String(l.get_meta(META)) == id)
	if map != null:
		for n: Node in map.find_children("*", "", true, false):
			if n.has_meta(META_OPEN_NAV) and (n is NavigationRegion3D or n is NavigationLink3D) \
					and _open_nav_group(n) == group:
				set_nav(n, id == "")
	return true


## Every group of `map` with no active layout (the heist start).
static func reset(map: Node) -> void:
	var groups: Dictionary = {}
	for l: Node3D in layouts(map):
		groups[group_of(l)] = true
	for g: String in groups:
		apply(map, "", g)


## A NavigationRegion3D / Link3D on or off. Off also takes it off the navigation map: Godot 4.7 still merges a disabled
## region's edges with its neighbours (C, RT convoy nav: the junction-box splits never connected), so a switched-off
## layout must not be in the map at all. On puts it back on its node's map.
static func set_nav(n: Node, on: bool) -> void:
	n.set(&"enabled", on)
	if not n.is_inside_tree():
		return
	var region: NavigationRegion3D = n as NavigationRegion3D
	if region != null:
		NavigationServer3D.region_set_map(region.get_rid(), region.get_navigation_map() if on else RID())
		return
	var link: NavigationLink3D = n as NavigationLink3D
	if link != null:
		NavigationServer3D.link_set_map(link.get_rid(), link.get_navigation_map() if on else RID())


static func _open_nav_group(n: Node) -> String:
	var v: Variant = n.get_meta(META_OPEN_NAV)
	return DEFAULT_GROUP if v is bool else String(v)


static func _switch(layout: Node3D, on: bool) -> void:
	layout.visible = on
	var stack: Array[Node] = layout.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is NavigationRegion3D or n is NavigationLink3D:
			set_nav(n, on)
		elif n is TacticalPoint:
			(n as TacticalPoint).set_enabled(on)
		elif n is GameplayPrefab:
			if Net.is_authority():
				(n as GameplayPrefab).set_enabled(on)
			continue  # a prefab handles its own subtree (collision, links, interaction)
		elif n is CollisionObject3D:
			n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		stack.append_array(n.get_children())
