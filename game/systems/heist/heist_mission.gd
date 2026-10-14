# gdlint:disable=max-public-methods
## Base class for heist mission scripts (`world/heists/<id>/<id>_mission.gd`). Owner: ENV A.
## Contract: docs/contracts/heist_map.md §6. Mission scripts may use ONLY this API, EventBus,
## Services, and node paths inside their own map. Runs on the server; objective changes are
## relayed with objective_updated [R].
##
## Override the virtual hooks (`_on_mission_start`, `_on_phase_changed`, `_on_pager_answered`,
## `_on_alarm`) and drive objectives with `add_objective` / `complete` / `fail`.
class_name HeistMission
extends Node

signal objectives_changed()

## Mercer is the default speaker for mission lines (C8).
const SPEAKER_MERCER: StringName = &"mercer"

## Read-only runtime facts for mission scripts.
var phase: int:
	get:
		return _runtime.phase if _runtime != null else Enums.HeistPhase.LOADING
var went_loud: bool:
	get:
		return _runtime != null and _runtime.went_loud
var difficulty: int:
	get:
		return _runtime.difficulty if _runtime != null else Enums.Difficulty.ROUTINE
var bags_secured: int:
	get:
		return _bags_secured
var secured_value: int:
	get:
		return _loot_value
## A3-09: heist time (s) since the heist started (HeistRuntime.heist_time_s: the sum of physics
## deltas, so it follows Engine.time_scale; it stops when the heist ends).
var elapsed_s: float:
	get:
		return _runtime.heist_time_s if _runtime != null else 0.0

## QC-35 (D-064): hold the police (AssaultDirector) this long after the heist goes loud, e.g. a cartel
## phase on a LOUD_ONLY heist: set it in `_on_mission_start()` (60 / 90 / 120 s rolled by the mission).
## Setting 0 later (police tipped off) starts the police at once. Reads back the time left.
var police_delay_s: float:
	get:
		var d: AssaultDirector = _director()
		return d.start_delay_s if d != null else 0.0
	set(v):
		var d: AssaultDirector = _director()
		if d != null:
			d.start_delay_s = v

var _runtime: HeistRuntime = null
## objective id -> { "id", "text_key", "state", "data", "order" }
var _objectives: Dictionary[StringName, Dictionary] = {}
var _connections: Array[Array] = []
var _timers: Dictionary[StringName, SceneTreeTimer] = {}
var _item_reqs: Dictionary[StringName, Dictionary] = {}
var _loot_reqs: Dictionary[StringName, int] = {}
var _items_seen: Dictionary[StringName, int] = {}
var _bags_secured: int = 0
var _loot_value: int = 0


# --- Virtual hooks -----------------------------------------------------------------

## Called once the heist is loaded (variants resolved, NPCs and crew spawned).
func _on_mission_start() -> void:
	pass


func _on_phase_changed(_old_phase: int, _new_phase: int) -> void:
	pass


## S5.7: some heists react to N answered pagers (e.g. spawn a replacement guard).
func _on_pager_answered(_total: int) -> void:
	pass


func _on_alarm(_reason: StringName) -> void:
	pass


## A civilian was intimidated (dominated) by `crew_slot`; `civilian` is the NPC node (QC Night Deposit).
func _on_civilian_dominated(_civilian: Node, _crew_slot: int) -> void:
	pass


## A guard or cop was dominated / surrendered to `crew_slot`.
func _on_guard_dominated(_npc: Node, _crew_slot: int) -> void:
	pass


# --- Objectives ------------------------------------------------------------------------

func add_objective(objective_id: StringName, text_key: StringName,
		state: Enums.ObjectiveState = Enums.ObjectiveState.ACTIVE, data: Dictionary = {}) -> void:
	_objectives[objective_id] = {
		"id": objective_id, "text_key": text_key, "state": state, "data": data, "order": _objectives.size(),
	}
	_publish(objective_id)


func activate(objective_id: StringName) -> void:
	_set_state(objective_id, Enums.ObjectiveState.ACTIVE)


func complete(objective_id: StringName) -> void:
	_set_state(objective_id, Enums.ObjectiveState.COMPLETED)


func fail(objective_id: StringName) -> void:
	_set_state(objective_id, Enums.ObjectiveState.FAILED)


func objective_state(objective_id: StringName) -> int:
	if not _objectives.has(objective_id):
		return Enums.ObjectiveState.HIDDEN
	return int(_objectives[objective_id]["state"])


## Objectives in creation order (LocalHudModel reads this).
func objectives() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: StringName in _objectives:
		out.append(_objectives[k].duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	return out


func update_objective_data(objective_id: StringName, data: Dictionary) -> void:
	if _objectives.has(objective_id):
		(_objectives[objective_id]["data"] as Dictionary).merge(data, true)
		_publish(objective_id)


## Auto-complete `objective_id` once the crew picked up `count` of `item_id` (item_picked_up).
func require_items(objective_id: StringName, item_id: StringName, count: int = 1) -> void:
	_item_reqs[objective_id] = {"item": item_id, "count": count}
	_check_reqs()


## Auto-complete `objective_id` once `count` bags have been secured (loot_secured).
func require_loot(objective_id: StringName, count: int = 1) -> void:
	_loot_reqs[objective_id] = count
	_check_reqs()


# --- Events, timers, voice -----------------------------------------------------------

## Connect to an EventBus signal; disconnected automatically at teardown.
func on_event(signal_name: StringName, callable: Callable) -> void:
	if not EventBus.has_signal(signal_name):
		Log.error(&"mission", "unknown EventBus signal %s" % signal_name)
		return
	EventBus.connect(signal_name, callable)
	_connections.append([signal_name, callable])


## One-shot timer (respects Engine.time_scale). Replaces a running timer with the same id.
func start_timer(timer_id: StringName, seconds: float, callback: Callable) -> void:
	cancel_timer(timer_id)
	var t: SceneTreeTimer = get_tree().create_timer(seconds, false, true)
	_timers[timer_id] = t
	t.timeout.connect(func() -> void:
		if _timers.get(timer_id) == t:
			_timers.erase(timer_id)
			callback.call())


func cancel_timer(timer_id: StringName) -> void:
	_timers.erase(timer_id)


func timer_left(timer_id: StringName) -> float:
	var t: SceneTreeTimer = _timers.get(timer_id)
	return t.time_left if t != null else 0.0


## A3-09: timed mission event at heist time `time_mark_s` (e.g. the armoured car at 12:00 = 720.0),
## or, with `after_event` (an EventBus signal name), `time_mark_s` after the FIRST emission of that
## signal. A mark already passed fires on the next physics frame. Same id rules as start_timer
## (replaces a pending one; cancel_timer / timer_left work on it). Returns false for an unknown
## `after_event` (logged). Event hooks are disconnected automatically at teardown.
func schedule_at(time_mark_s: float, timer_id: StringName, callback: Callable, after_event: StringName = &"") -> bool:
	if after_event == &"":
		start_timer(timer_id, maxf(time_mark_s - elapsed_s, 0.0), callback)
		return true
	if not EventBus.has_signal(after_event):
		Log.error(&"mission", "unknown EventBus signal %s" % after_event)
		return false
	var argc: int = 0
	for sig: Dictionary in EventBus.get_signal_list():
		if StringName(sig["name"]) == after_event:
			argc = (sig["args"] as Array).size()
	var c: Callable = (func() -> void: start_timer(timer_id, maxf(time_mark_s, 0.0), callback)).unbind(argc)
	EventBus.connect(after_event, c, CONNECT_ONE_SHOT)
	_connections.append([after_event, c])
	return true


## A3-09: spawn `count` guards at the GUARD SpawnPoints tagged `spawn_tag` (tree order, cycling,
## 0.8 m apart when a point is reused). Points tagged HeistRuntime.SCRIPTED_SPAWN_TAG are skipped
## at load, so they are only used here. Spawned guards are ordinary guards (pagers, patrol graph
## and tags of their point). Returns the NPCs ([] with no matching point, logged).
func spawn_guards(count: int, spawn_tag: StringName) -> Array[Node]:
	var out: Array[Node] = []
	if _runtime == null or _runtime.map == null or count <= 0:
		return out
	var points: Array[SpawnPoint] = []
	for n: Node in _runtime.map.get_slots(G.GUARD_SPAWN):
		var sp: SpawnPoint = n as SpawnPoint
		if sp != null and sp.tags.has(spawn_tag):
			points.append(sp)
	if points.is_empty():
		Log.error(&"mission", "spawn_guards: no GUARD SpawnPoint tagged '%s'" % spawn_tag)
		return out
	for i: int in range(count):
		var sp2: SpawnPoint = points[i % points.size()]
		var offset: Vector3 = sp2.global_transform.basis.x * (0.8 * float(i / points.size()))
		var xf: Transform3D = sp2.global_transform
		xf.origin += offset
		var npc: NpcBase = _runtime.spawn_npc(&"guard", xf, HeistRuntime.spawn_info(sp2))
		if npc != null:
			out.append(npc)
	return out


## Mercer (or another speaker) line: voice_line_requested [R] (C8).
func say(line_id: StringName, context: Dictionary = {}, speaker: StringName = SPEAKER_MERCER) -> void:
	EventBus.voice_line_requested.emit(speaker, line_id, context)
	Net.replicate_event(&"voice_line_requested", [speaker, line_id, context])


# --- Map access --------------------------------------------------------------------

## Gameplay prefabs in this heist with `objective_tag` == tag.
func find_tagged(tag: StringName) -> Array[Node]:
	return _runtime.find_by_tag(tag) if _runtime != null else []


func variant(group_or_scalar: StringName) -> Variant:
	return _runtime.variants.get(group_or_scalar) if _runtime != null else null


## D-103 §6 / QC-51: give the MapZone at `zone_path` (relative to the map root) the kind `kind` (MapZone.Kind)
## for the rest of the run (Gallery Night last call: galleries -> RESTRICTED). Server, replicated.
func set_zone_kind(zone_path: NodePath, kind: int) -> void:
	if _runtime == null or _runtime.map == null:
		return
	var zone: MapZone = _runtime.map.get_node_or_null(zone_path) as MapZone
	if zone == null:
		Log.error(&"mission", "set_zone_kind: no MapZone at '%s'" % zone_path)
		return
	ZoneKinds.set_kind(_runtime, zone, kind)


## D-103 §6 / QC-51 (gala clock): every calm civilian walks to the nearest PatrolPoint tagged `exit_tag` and
## despawns there (no alarm). Refused while loud; alarmed / tied / fleeing civilians stay. Returns how many left.
func civilians_leave(exit_tag: StringName = &"exit") -> int:
	if _runtime == null or _runtime.map == null or _runtime.went_loud:
		return 0
	var exits: Array[Vector3] = []
	var stack: Array[Node] = [_runtime.map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var pp: PatrolPoint = n as PatrolPoint
		if pp != null and pp.tags.has(exit_tag):
			exits.append(pp.global_position)
		stack.append_array(n.get_children())
	if exits.is_empty():
		Log.error(&"mission", "civilians_leave: no PatrolPoint tagged '%s'" % exit_tag)
		return 0
	var count: int = 0
	for n: Node in _runtime.npcs(&"civilian"):
		var brain: CivilianBrain = n.get_node_or_null(^"Brain") as CivilianBrain
		if brain == null:
			continue
		var pos: Vector3 = (n as Node3D).global_position
		var best: Vector3 = exits[0]
		for e: Vector3 in exits:
			if pos.distance_squared_to(e) < pos.distance_squared_to(best):
				best = e
		if brain.leave_map(best):
			count += 1
	return count


## C10: make escape zones tagged `tag` (all escape zones if empty) available.
## C3: with an empty `tag`, a chosen escape asset's `escape_tag` (PreplanAssets) is used.
func activate_escape(tag: StringName = &"") -> void:
	if _runtime == null:
		return
	if tag == &"":
		tag = _runtime.preplan.escape_tag()
	for n: Node in get_tree().get_nodes_in_group(G.ESCAPE_ZONE):
		if not _runtime.is_ancestor_of(n):
			continue
		var host: Node = n
		while host != null and not host.has_method(&"activate"):
			host = host.get_parent()
			if host == _runtime:
				host = null
		if host == null:
			continue
		var t: Variant = host.get(&"objective_tag")
		if tag == &"" or (t != null and StringName(t) == tag):
			host.call(&"activate")
	_runtime.enter_escape_phase()


## `fail_reason`: HeistResult.fail_reason on failure (&"" = HeistRuntime.FAIL_ABORT).
func end_heist(success: bool, fail_reason: StringName = &"") -> void:
	if _runtime != null:
		_runtime.end_heist(success, [], fail_reason)


# --- Internal (HeistRuntime) --------------------------------------------------------

func _bind(rt: HeistRuntime) -> void:
	_runtime = rt
	rt.phase_changed.connect(_on_phase_changed)
	_internal(&"pager_answered", func(_p: int, _s: int, total: int) -> void: _on_pager_answered(total))
	_internal(&"alarm_raised", func(reason: StringName, _src: int) -> void: _on_alarm(reason))
	_internal(&"item_picked_up", _on_item_picked)
	_internal(&"loot_secured", _on_loot_secured)
	_internal(&"civilian_intimidated", func(id: int, slot: int) -> void: _on_civilian_dominated(Ids.lookup(id), slot))
	_internal(&"guard_dominated", func(id: int, slot: int) -> void: _on_guard_dominated(Ids.lookup(id), slot))


func _unbind() -> void:
	for c: Array in _connections:
		if EventBus.is_connected(c[0], c[1]):
			EventBus.disconnect(c[0], c[1])
	_connections.clear()
	_timers.clear()
	_runtime = null


func _internal(sig: StringName, c: Callable) -> void:
	EventBus.connect(sig, c)
	_connections.append([sig, c])


func _on_item_picked(item_id: StringName, _slot: int) -> void:
	_items_seen[item_id] = int(_items_seen.get(item_id, 0)) + 1
	_check_reqs()


func _on_loot_secured(_bag: int, _loot_id: StringName, value: int) -> void:
	_bags_secured += 1
	_loot_value += value
	_check_reqs()


func _check_reqs() -> void:
	for oid: StringName in _item_reqs:
		var r: Dictionary = _item_reqs[oid]
		if int(_items_seen.get(r["item"], 0)) >= int(r["count"]) and objective_state(oid) == Enums.ObjectiveState.ACTIVE:
			complete(oid)
	for oid: StringName in _loot_reqs:
		if _bags_secured >= _loot_reqs[oid] and objective_state(oid) == Enums.ObjectiveState.ACTIVE:
			complete(oid)


func _set_state(objective_id: StringName, s: Enums.ObjectiveState) -> void:
	if not _objectives.has(objective_id):
		add_objective(objective_id, StringName("obj.%s" % objective_id), s)
		return
	if int(_objectives[objective_id]["state"]) == s:
		return
	_objectives[objective_id]["state"] = s
	_publish(objective_id)


func _publish(objective_id: StringName) -> void:
	var o: Dictionary = _objectives[objective_id]
	var data: Dictionary = (o["data"] as Dictionary).duplicate(true)
	data["text_key"] = o["text_key"]
	EventBus.objective_updated.emit(objective_id, int(o["state"]), data)
	Net.replicate_event(&"objective_updated", [objective_id, int(o["state"]), data])
	objectives_changed.emit()


func _director() -> AssaultDirector:
	return _runtime.service(G.SVC_DIRECTOR) as AssaultDirector if _runtime != null else null
