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


func bags_secured() -> int:
	return _bags_secured


func secured_value() -> int:
	return _loot_value


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


## Mercer (or another speaker) line: voice_line_requested [R] (C8).
func say(line_id: StringName, context: Dictionary = {}, speaker: StringName = SPEAKER_MERCER) -> void:
	EventBus.voice_line_requested.emit(speaker, line_id, context)
	Net.replicate_event(&"voice_line_requested", [speaker, line_id, context])


# --- Map access --------------------------------------------------------------------

## Gameplay prefabs in this heist with `objective_tag` == tag.
func find_tagged(tag: StringName) -> Array[Node]:
	return _runtime.find_by_tag(tag) if _runtime != null else []


func phase() -> int:
	return _runtime.phase if _runtime != null else Enums.HeistPhase.LOADING


func went_loud() -> bool:
	return _runtime != null and _runtime.went_loud


func variant(group_or_scalar: StringName) -> Variant:
	return _runtime.variants.get(group_or_scalar) if _runtime != null else null


func difficulty() -> int:
	return _runtime.difficulty if _runtime != null else Enums.Difficulty.ROUTINE


## C10: make escape zones tagged `tag` (all escape zones if empty) available.
func activate_escape(tag: StringName = &"") -> void:
	if _runtime == null:
		return
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


func end_heist(success: bool) -> void:
	if _runtime != null:
		_runtime.end_heist(success)


# --- Internal (HeistRuntime) --------------------------------------------------------

func _bind(rt: HeistRuntime) -> void:
	_runtime = rt
	rt.phase_changed.connect(_on_phase_changed)
	_internal(&"pager_answered", func(_p: int, _s: int, total: int) -> void: _on_pager_answered(total))
	_internal(&"alarm_raised", func(reason: StringName, _src: int) -> void: _on_alarm(reason))
	_internal(&"item_picked_up", _on_item_picked)
	_internal(&"loot_secured", _on_loot_secured)


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
