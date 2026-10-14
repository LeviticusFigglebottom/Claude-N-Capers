## Server-side lookups for civilians (A1-06). Owner: ENV A.
## - Call points a PANICKED civilian runs to in stealth (S3.1): map `Phone` / `AlarmButton` prefabs
##   (found by script class name so this file has no hard dependency on the prefab scripts) and any
##   Node3D in group CALL_POINT_GROUP (tests, debug markers; reason in meta META_REASON).
## - Wander points (S7.5): PatrolPoints tagged civilian/staff. PO-5 (PD2: customers stay in public
##   areas, staff at their posts): `wander_options` gives a customer only `civilian` points outside
##   RESTRICTED / NO_CIVILIAN MapZones, and a staff civilian (a spawn tag containing "staff", or a
##   `staff`-only home point) only `staff` points sharing its home point's `staff_*` area tags (home =
##   nearest staff point to its spawn on its floor); never NO_CIVILIAN. Reach is navmesh path length
##   (no navmesh: straight line on the same floor), so floors and walls do not count as "near".
##   PO-10 reservation: a point is not offered while another live NPC of this heist is heading to it (its
##   NpcMotor target; released when it arrives, re-targets or dies) or stands on it
##   (StealthTweak.civilian_wander_taken_m), so two civilians never walk to the same point at once.
## - Hostage count (S7.2): civilians in G.HOSTAGE; emits hostage_count_changed [R] on change.
## Self-installed as the runtime service SERVICE by the first CivilianBrain (`ensure`), like
## ShoutSystem; HeistRuntime may create it directly later.
class_name CivilianTargets
extends Node

const SERVICE: StringName = &"civilian_targets"
const CALL_POINT_GROUP: StringName = &"civilian_call_point"
const META_REASON: StringName = &"call_reason"
const REASON_PHONE: StringName = &"civilian_call"
const REASON_BUTTON: StringName = &"alarm_button"
const TAG_CIVILIAN: StringName = &"civilian"
const TAG_STAFF: StringName = &"staff"
const WANDER_TAGS: Array[StringName] = [TAG_CIVILIAN, TAG_STAFF]
## PatrolPoint tags naming a staff area (`staff_floor`, `staff_boh`, `staff_upper`...).
const STAFF_AREA_PREFIX: String = "staff_"
## Script class names of the prefabs civilians use, and the alarm reason each one raises.
const PREFAB_REASONS: Dictionary[StringName, StringName] = {
	&"Phone": REASON_PHONE, &"AlarmButton": REASON_BUTTON,
}

var hostage_count: int = 0

var _runtime: HeistRuntime = null
var _scanned: bool = false
var _prefabs: Array[Node3D] = []
var _wander_points: Array[PatrolPoint] = []


## The runtime's CivilianTargets service, created on first use.
static func ensure(rt: HeistRuntime) -> CivilianTargets:
	if rt == null:
		return null
	var s: CivilianTargets = rt.service(SERVICE) as CivilianTargets
	if s == null:
		s = CivilianTargets.new()
		s.name = "CivilianTargets"
		s._runtime = rt
		rt.register_service(SERVICE, s)
	return s


## Mark `node` as a place panicked civilians run to (raises `reason` when the call completes).
static func add_call_point(node: Node3D, reason: StringName = REASON_PHONE) -> void:
	node.set_meta(META_REASON, reason)
	node.add_to_group(CALL_POINT_GROUP)


## [{ "node": Node3D, "position": Vector3, "reason": StringName }]
func call_points() -> Array[Dictionary]:
	_scan()
	var out: Array[Dictionary] = []
	for p: Node3D in _prefabs:
		if not is_instance_valid(p) or not p.is_inside_tree():
			continue
		var gname: StringName = _class_of(p)
		var use: Node3D = p.get_node_or_null(^"UsePoint") as Node3D
		out.append({
			"node": p, "position": use.global_position if use != null else p.global_position,
			"reason": PREFAB_REASONS.get(gname, REASON_PHONE),
		})
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group(CALL_POINT_GROUP):
			var m: Node3D = n as Node3D
			if m == null or (_runtime != null and not _runtime.is_ancestor_of(m)):
				continue
			out.append({"node": m, "position": m.global_position, "reason": StringName(m.get_meta(META_REASON, REASON_PHONE))})
	return out


func wander_points() -> Array[PatrolPoint]:
	_scan()
	var out: Array[PatrolPoint] = []
	for p: PatrolPoint in _wander_points:
		if is_instance_valid(p) and p.is_inside_tree():
			out.append(p)
	return out


## PO-5 (S7.5): wander profile of a civilian: { "staff": bool, "areas": Array[StringName] } (areas empty =
## any staff point). Computed from its spawn tags and spawn position (SpawnPoint, else `home`).
func wander_profile(npc: NpcBase, home: Vector3) -> Dictionary:
	var staff: bool = false
	var tags: Variant = npc.spawn_info.get("tags", []) if npc != null else []
	if tags is Array:
		for t: Variant in tags as Array:
			if String(t).contains("staff"):
				staff = true
	var sp: Node3D = npc.spawn_info.get("spawn_point") as Node3D if npc != null else null
	if sp != null and is_instance_valid(sp) and sp.is_inside_tree():
		home = sp.global_position
	var dy_max: float = Tweak.stealth().civilian_wander_floor_dy_m
	var nearest: PatrolPoint = null
	var nearest_staff: PatrolPoint = null
	var best: float = INF
	var best_staff: float = INF
	for p: PatrolPoint in wander_points():
		if absf(p.global_position.y - home.y) > dy_max:
			continue
		var d: float = p.global_position.distance_to(home)
		if d < best:
			best = d
			nearest = p
		if p.tags.has(TAG_STAFF) and d < best_staff:
			best_staff = d
			nearest_staff = p
	if not staff and nearest != null and nearest.tags.has(TAG_STAFF) and not nearest.tags.has(TAG_CIVILIAN):
		staff = true  # posted next to staff-only points (no tag convention on this map)
	var areas: Array[StringName] = []
	if staff and nearest_staff != null:
		for t: StringName in nearest_staff.tags:
			if String(t).begins_with(STAFF_AREA_PREFIX):
				areas.append(t)
	return {"staff": staff, "areas": areas}


## PO-5 (S7.5): wander points a civilian with `profile` (wander_profile) standing at `from` may walk to:
## role/area tags and MapZones allow it, farther than `min_m` and within `radius` of travel.
func wander_options(from: Vector3, profile: Dictionary, radius: float, min_m: float = 1.0) -> Array[PatrolPoint]:
	var out: Array[PatrolPoint] = []
	var staff: bool = bool(profile.get("staff", false))
	var areas: Array = profile.get("areas", [])
	var dy_max: float = Tweak.stealth().civilian_wander_floor_dy_m
	var nav: bool = has_navigation()
	var taken: Array[Vector3] = taken_spots(from)
	var taken_m: float = Tweak.stealth().civilian_wander_taken_m
	for p: PatrolPoint in wander_points():
		var pos: Vector3 = p.global_position
		var flat: float = Vector2(pos.x - from.x, pos.z - from.z).length()
		if flat <= min_m or from.distance_to(pos) > radius:
			continue
		if _is_taken(pos, taken, taken_m):
			continue
		if not _role_allows(p, staff, areas) or not _zones_allow(pos, staff):
			continue
		if nav:
			if nav_path_length(from, pos) > radius:
				continue
		elif absf(pos.y - from.y) > dy_max:
			continue
		out.append(p)
	return out


## PO-10: where live NPCs of this heist stand or are walking to (their NpcMotor target while not arrived),
## except one standing at `exclude_at` (the asking civilian itself).
func taken_spots(exclude_at: Vector3 = Vector3.INF) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not is_inside_tree():
		return out
	for n: Node in get_tree().get_nodes_in_group(G.NPC):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.alive or (_runtime != null and not _runtime.is_ancestor_of(npc)):
			continue
		if exclude_at != Vector3.INF and npc.global_position.distance_to(exclude_at) < 0.05:
			continue
		out.append(npc.global_position)
		var m: NpcMotor = npc.get_node_or_null(^"Motor") as NpcMotor
		if m != null and not m.arrived and m.target != Vector3.INF:
			out.append(m.target)
	return out


static func _is_taken(pos: Vector3, taken: Array[Vector3], taken_m: float) -> bool:
	for t: Vector3 in taken:
		if absf(t.y - pos.y) < 1.0 and Vector2(t.x - pos.x, t.z - pos.z).length() <= taken_m:
			return true
	return false


static func _role_allows(p: PatrolPoint, staff: bool, areas: Array) -> bool:
	if not staff:
		return p.tags.has(TAG_CIVILIAN)
	if not p.tags.has(TAG_STAFF):
		return false
	if areas.is_empty():
		return true
	for a: Variant in areas:
		if p.tags.has(StringName(a)):
			return true
	return false


## Customers stay out of RESTRICTED (back of house, upstairs, behind the counter) and NO_CIVILIAN zones;
## staff only out of NO_CIVILIAN.
func _zones_allow(pos: Vector3, staff: bool) -> bool:
	var st: StealthDirector = _runtime.stealth if _runtime != null else null
	if st == null or not st.is_inside_tree():
		return true
	var kinds: Array[int] = st.zone_kinds_at(pos + Vector3.UP * Tweak.stealth().zone_probe_height_m)
	if kinds.has(MapZone.Kind.NO_CIVILIAN):
		return false
	return staff or not kinds.has(MapZone.Kind.RESTRICTED)


## True when this heist's world has a baked navmesh.
func has_navigation() -> bool:
	if not is_inside_tree():
		return false
	var nav_map: RID = get_viewport().world_3d.navigation_map
	# Regions register before the map's first sync; until it has synced every path query is empty, so
	# callers use their same-floor straight-line fallback instead of finding no reachable point at all.
	return not NavigationServer3D.map_get_regions(nav_map).is_empty() \
		and NavigationServer3D.map_get_iteration_id(nav_map) > 0


## Navmesh path length from `from` to `to` (INF without a navmesh or a path).
func nav_path_length(from: Vector3, to: Vector3) -> float:
	if not has_navigation():
		return INF
	var nav_map: RID = get_viewport().world_3d.navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, from, to, true)
	if path.size() < 2:
		return INF
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total + path[path.size() - 1].distance_to(to)


## Travel cost from `from` to `to`: navmesh path length when the map has navigation, else
## straight-line distance.
func path_cost(from: Vector3, to: Vector3) -> float:
	var n: float = nav_path_length(from, to)
	return n if n < INF else from.distance_to(to)


## Server: recount G.HOSTAGE in this heist; emits hostage_count_changed [R] when it changed.
func recount_hostages() -> int:
	var count: int = 0
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group(G.HOSTAGE):
			var npc: NpcBase = n as NpcBase
			if npc != null and npc.alive and (_runtime == null or _runtime.is_ancestor_of(npc)):
				count += 1
	if count != hostage_count:
		hostage_count = count
		if Net.is_authority():
			EventBus.hostage_count_changed.emit(count)
			Net.replicate_event(&"hostage_count_changed", [count])
	return count


func _scan() -> void:
	if _scanned or _runtime == null:
		return
	_scanned = true
	var root: Node = _runtime.map if _runtime.map != null else _runtime
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var pp: PatrolPoint = n as PatrolPoint
		if pp != null:
			for t: StringName in pp.tags:
				if WANDER_TAGS.has(t):
					_wander_points.append(pp)
					break
		elif PREFAB_REASONS.has(_class_of(n)) and n is Node3D:
			_prefabs.append(n as Node3D)
		for c: Node in n.get_children():
			stack.append(c)


static func _class_of(n: Node) -> StringName:
	var s: Script = n.get_script() as Script
	return s.get_global_name() if s != null else &""
