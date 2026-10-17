## OF-A4 (D-136 §3b.4): an ordered, timed, cross-floor civilian route (the bank manager's rounds, a rotating
## teller, the officers' coffee runs; reused by Afterhours). Owner: ENV A. Placed by ENV C anywhere in the map
## (e.g. under `Patrols/`); server-side behaviour lives in CivilianBrain.
##
## Stops, in walk order: `stops` (NodePaths to PatrolPoints anywhere in the map) when set, else this node's
## PatrolPoint children (CivilianRouteStop for an away window). Each stop's PatrolPoint fields drive the dwell:
## pause_range (dwell s, GameRng &"civilian_routes"), pause_anim (ambient hint), face_marker_forward.
##
## Binding (a civilian follows at most one route): the civilian's SpawnPoint `patrol_graph` points at this node, or
## its spawn tags include one of `bind_tags` (first route in tree order wins), or the mission calls bind(npc).
## A bound CALM civilian walks the stops in order with normal navmesh paths (stairs: any floor), loops / ping-pongs /
## stops at the end per `order`, and never wanders at random. Panic, intimidation, LOUD, a seen body or crew preempt
## it through the existing CivilianBrain modes (S3.1 timing unchanged); the away window closes then.
## A stop the navmesh cannot reach (no path ends within StealthTweak.civilian_route_reach_m of it) or a walk that
## stalls twice is skipped (logged once per stop per civilian); §3b.4 fallback.
class_name CivilianRoute
extends Node3D

## A bound civilian's away window opened (away = true) or closed. Server only.
signal away_changed(npc: NpcBase, window: StringName, away: bool)
## A bound civilian arrived at stop `index` (before its dwell). Server only.
signal stop_reached(npc: NpcBase, index: int)
## A bound civilian gave stop `index` up (unreachable / stalled) and went on to the next. Server only.
signal stop_skipped(npc: NpcBase, index: int)

## LOOP: 0, 1, .. n-1, 0 ..; PING_PONG: 0 .. n-1, n-2 .. 0, 1 ..; ONCE: 0 .. n-1, then stays at the last stop.
enum Order { LOOP, PING_PONG, ONCE }

const GROUP: StringName = &"civilian_route"
const RNG_STREAM: StringName = &"civilian_routes"

## Id the mission / intel names the route by (find()); empty = the node name.
@export var route_id: StringName = &""
## Spawn tags that bind a civilian to this route (any one of them), e.g. [&"civ_manager"].
@export var bind_tags: Array[StringName] = []
@export var order: Order = Order.LOOP
## Explicit stops (PatrolPoints anywhere in the map), in order. Empty = this node's PatrolPoint children.
@export var stops: Array[NodePath] = []
## The stop a newly bound civilian walks to first.
@export var start_index: int = 0
## False: bound civilians stay at their current stop (dwell paused) until it is true again (mission control).
@export var active: bool = true

## NpcBase -> StringName open away window (only civilians with a window open).
var _away: Dictionary = {}
var _bound: Array[NpcBase] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


## The route's id: route_id, else the node name.
func id() -> StringName:
	return route_id if route_id != &"" else StringName(name)


## The stops in walk order (missing / non-PatrolPoint paths dropped).
func stop_list() -> Array[PatrolPoint]:
	var out: Array[PatrolPoint] = []
	if not stops.is_empty():
		for np: NodePath in stops:
			var p: PatrolPoint = get_node_or_null(np) as PatrolPoint
			if p != null:
				out.append(p)
		return out
	for c: Node in get_children():
		if c is PatrolPoint:
			out.append(c as PatrolPoint)
	return out


func stop_count() -> int:
	return stop_list().size()


func stop_at(index: int) -> PatrolPoint:
	var l: Array[PatrolPoint] = stop_list()
	return l[index] if index >= 0 and index < l.size() else null


## The window stop `index` names (CivilianRouteStop.away_window), else &"".
func window_of(index: int) -> StringName:
	var s: CivilianRouteStop = stop_at(index) as CivilianRouteStop
	return s.away_window if s != null else &""


## The step after stop `index` walking in direction `dir` (+1 / -1): Vector2i(next index, next dir); next index -1
## when an ONCE route is done.
func next_step(index: int, dir: int) -> Vector2i:
	var n: int = stop_count()
	if n <= 0:
		return Vector2i(-1, dir)
	match order:
		Order.ONCE:
			return Vector2i(index + 1 if index + 1 < n else -1, 1)
		Order.PING_PONG:
			if n == 1:
				return Vector2i(0, 1)
			var d: int = 1 if dir >= 0 else -1
			if index + d < 0 or index + d >= n:
				d = -d
			return Vector2i(index + d, d)
	return Vector2i((index + 1) % n, 1)


## Server: dwell seconds at stop `index`, random in its pause_range (GameRng &"civilian_routes").
func roll_dwell(index: int) -> float:
	var p: PatrolPoint = stop_at(index)
	if p == null:
		return 0.0
	var r: Vector2 = p.pause_range
	if r.y <= r.x:
		return maxf(r.x, 0.0)
	return GameRng.stream(RNG_STREAM).randf_range(maxf(r.x, 0.0), r.y)


## Server (mission): bind `npc` (a civilian) to this route. False when it has no CivilianBrain or is not calm.
func bind(npc: NpcBase) -> bool:
	var b: CivilianBrain = npc.get_node_or_null(^"Brain") as CivilianBrain if npc != null else null
	return b != null and b.set_route(self)


func bound_civilians() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for n: NpcBase in _bound:
		if is_instance_valid(n):
			out.append(n)
	return out


## True while a bound civilian has an away window open (`window` empty = any window).
func is_away(window: StringName = &"") -> bool:
	for n: Variant in _away:
		if is_instance_valid(n) and (window == &"" or _away[n] == window):
			return true
	return false


## The first open away window on this route, else &"".
func away_window() -> StringName:
	for n: Variant in _away:
		if is_instance_valid(n):
			return _away[n]
	return &""


## CivilianBrain: `npc` was bound (true) / unbound (false); unbinding closes its window.
func register_civilian(npc: NpcBase, bound: bool) -> void:
	if bound:
		if not _bound.has(npc):
			_bound.append(npc)
		return
	_bound.erase(npc)
	set_away(npc, &"")


## CivilianBrain: `npc`'s open away window is now `window` (&"" = none); emits away_changed for each change.
func set_away(npc: NpcBase, window: StringName) -> void:
	var old: StringName = _away.get(npc, &"")
	if old == window:
		return
	if old != &"":
		_away.erase(npc)
		away_changed.emit(npc, old, false)
	if window != &"":
		_away[npc] = window
		away_changed.emit(npc, window, true)


## Every CivilianRoute inside `rt` (tree order).
static func all_in(rt: HeistRuntime) -> Array[CivilianRoute]:
	var out: Array[CivilianRoute] = []
	if rt == null or not rt.is_inside_tree():
		return out
	for n: Node in rt.get_tree().get_nodes_in_group(GROUP):
		var r: CivilianRoute = n as CivilianRoute
		if r != null and rt.is_ancestor_of(r):
			out.append(r)
	return out


## The route with id `route_id` inside `rt`, else null.
static func find(rt: HeistRuntime, find_id: StringName) -> CivilianRoute:
	for r: CivilianRoute in all_in(rt):
		if r.id() == find_id:
			return r
	return null


## The route `npc` binds to at spawn: its spawn_info patrol_graph when that is a CivilianRoute, else the first route
## whose bind_tags meet its spawn tags; null = none (random wander as before).
static func for_civilian(rt: HeistRuntime, npc: NpcBase) -> CivilianRoute:
	if npc == null:
		return null
	var pg: CivilianRoute = npc.spawn_info.get("patrol_graph") as CivilianRoute
	if pg != null:
		return pg
	var tags: Array = npc.spawn_info.get("tags", [])
	if tags.is_empty():
		return null
	for r: CivilianRoute in all_in(rt):
		for t: StringName in r.bind_tags:
			if tags.has(t):
				return r
	return null


## True while any route in `rt` has `window` open (HUD / intel: "manager away from the office").
static func any_away(rt: HeistRuntime, window: StringName) -> bool:
	for r: CivilianRoute in all_in(rt):
		if r.is_away(window):
			return true
	return false
