## Server-side lookups for civilians (A1-06). Owner: ENV A.
## - Call points a PANICKED civilian runs to in stealth (S3.1): map `Phone` / `AlarmButton` prefabs
##   (found by script class name so this file has no hard dependency on the prefab scripts) and any
##   Node3D in group CALL_POINT_GROUP (tests, debug markers; reason in meta META_REASON).
## - Wander points (S7.5): PatrolPoints tagged civilian/staff.
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
const WANDER_TAGS: Array[StringName] = [&"civilian", &"staff"]
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


## Travel cost from `from` to `to`: navmesh path length when the map has navigation, else
## straight-line distance.
func path_cost(from: Vector3, to: Vector3) -> float:
	if not is_inside_tree():
		return from.distance_to(to)
	var nav_map: RID = get_viewport().world_3d.navigation_map
	if NavigationServer3D.map_get_regions(nav_map).is_empty():
		return from.distance_to(to)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, from, to, true)
	if path.size() < 2:
		return from.distance_to(to)
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total + path[path.size() - 1].distance_to(to)


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
