## QC-41: one-way rappel NavigationLink3Ds (Dockside Burn skylights, Night Deposit hall skylight). Owner: ENV A.
## At heist start every TacticalPoint of kind RAPPEL (heist_map.md `Tactical`) gets a child `RappelLink`:
## start at the point (roof side), end on the floor below it (first world hit of a ray straight down from
## RAY_START_BELOW_M under the point, so the skylight itself is skipped), bidirectional = false (police come
## down, nobody climbs up). NpcMotor performs the descent (`rappelling`). Police-only islands such as the
## Dockside high-bay roof reach the interior only through these links.
## OF-A2 (QC-61) runtime links: a RAPPEL point carrying TAG_START_DISABLED in `tags` gets its link built
## disabled; the mission enables it with `RappelLinks.set_enabled(runtime.map, tag, on)` (every RAPPEL point
## carrying `tag`). Enabling re-casts the floor below (a hole lid disabled before it no
## longer counts). Server only: links matter to the authority's NPC navigation; replicas build none. Heist
## navigation iterates synchronously (D-121), so the change is visible to path queries after this physics frame.
## OF-A5 (QC-68) chains: a link's exit may land on another island whose own RAPPEL point continues the descent
## (setback -> terrace -> lantern); NpcMotor rappels each link and walks between them.
class_name RappelLinks
extends RefCounted

const META: StringName = &"rappel"
## OF-A2: a RAPPEL point with this tag starts with its link disabled.
const TAG_START_DISABLED: StringName = &"rappel_disabled"
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
		# Sweep r303 (OF seed 1, C's trace): on layer 1 the crew, guards and civilians pathed down the 8.6 m lantern drop.
		# Only loud police use these (NpcMotor adds the breach layer, D-122; the director queries 1 | BREACH).
		link.navigation_layers = Door.NAV_LAYER_BREACH
		link.set_meta(META, true)
		tp.add_child(link)
		link.global_transform = Transform3D(Basis.IDENTITY, tp.global_position)
		link.start_position = Vector3.ZERO
		link.end_position = floor_pos - tp.global_position
		link.enabled = not tp.tags.has(TAG_START_DISABLED)
		made += 1
	return made


## OF-A2: the RappelLink of RAPPEL point `tp`, or null.
static func link_of(tp: Node) -> NavigationLink3D:
	return tp.get_node_or_null(LINK_NAME) as NavigationLink3D if tp != null else null


## OF-A2 (server): enable / disable the links of every RAPPEL point under `map` carrying `tag` in its `tags`.
## Enabling re-casts the floor below each point. Returns how many links changed.
static func set_enabled(map: Node3D, tag: StringName, on: bool) -> int:
	if map == null or not map.is_inside_tree() or not Net.is_authority():
		return 0
	var changed: int = 0
	for n: Node in map.get_tree().get_nodes_in_group(&"rappel_point"):
		var tp: TacticalPoint = n as TacticalPoint
		if tp == null or not map.is_ancestor_of(tp) or not tp.tags.has(tag):
			continue
		var link: NavigationLink3D = link_of(tp)
		if link == null:
			continue
		if on:
			var floor_pos: Vector3 = floor_below(tp)
			if floor_pos != Vector3.INF:
				link.end_position = floor_pos - tp.global_position
		if link.enabled != on:
			link.enabled = on
			changed += 1
	return changed


## First floor hit straight below `p` (skipping RAY_START_BELOW_M), or Vector3.INF.
static func floor_below(p: Node3D) -> Vector3:
	var from: Vector3 = p.global_position - Vector3(0.0, RAY_START_BELOW_M, 0.0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - Vector3(0.0, RAY_LENGTH_M, 0.0), WORLD_MASK)
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.get("position", Vector3.INF) as Vector3 if not hit.is_empty() else Vector3.INF
