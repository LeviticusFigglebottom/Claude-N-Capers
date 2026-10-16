## In-heist fact log for the heist achievements (D-115). Owner: ENV B.
##
## Listens to a fixed list of EventBus facts (SIGNALS, all [R] in contracts/events.md, so every peer sees
## them) from start() until stop() or heist_ended, and keeps:
##   * every objective's last state and whether the mission marked it `skipped` (objective_updated);
##   * the other facts as [signal, args] in order (capped at MAX_EVENTS).
## snapshot() is what Achievements.on_payday reads as `facts` (`"recorded": true` marks a real log; without
## it every fact condition fails closed). It never decides gameplay and never emits.
## Owner of the instance: PaydayScreen (the in-heist one MenuFlow spawns before the launch).
class_name HeistFacts
extends RefCounted

## Facts kept as events (objective_updated is folded into `objectives`). Never per-frame signals.
const SIGNALS: Array[StringName] = [
	&"objective_updated", &"alarm_raised", &"heist_phase_changed",
	&"interaction_completed", &"device_started", &"device_finished", &"device_jammed", &"item_picked_up",
	&"glass_broken", &"laser_tripped", &"loot_spawned", &"loot_secured", &"small_loot_taken",
	&"civilian_killed", &"civilian_tied", &"guard_dominated", &"pager_answered", &"pager_failed",
	&"body_bagged", &"body_discovered", &"camera_disabled", &"cameras_loop_disabled", &"ecm_started",
	&"crew_downed", &"crew_custody", &"special_spawned", &"captain_arrived", &"assault_event_started",
]
## Upper bound on stored events (a long loud heist stays far below it).
const MAX_EVENTS: int = 4000
const OBJECTIVE_UPDATED: StringName = &"objective_updated"

## objective id -> {"state": int (Enums.ObjectiveState), "skipped": bool}
var objectives: Dictionary = {}
## [[signal: StringName, args: Array], ...] in emission order.
var events: Array[Array] = []
var running: bool = false
## True once start() ran (a heist was watched); snapshot() is only meaningful then.
var started: bool = false
var _connections: Array[Array] = []


## Connects to EventBus (idempotent). Clears nothing: call reset() for a fresh log.
func start() -> void:
	if running:
		return
	running = true
	started = true
	var arity: Dictionary = {}
	for s: Dictionary in EventBus.get_signal_list():
		arity[StringName(s["name"])] = (s["args"] as Array).size()
	for sig: StringName in SIGNALS:
		if not arity.has(sig):
			continue
		var c: Callable = _handler(sig, int(arity[sig]))
		EventBus.connect(sig, c)
		_connections.append([sig, c])
	EventBus.heist_ended.connect(_on_heist_ended)
	_connections.append([&"heist_ended", _on_heist_ended])


func stop() -> void:
	for c: Array in _connections:
		if EventBus.is_connected(c[0], c[1]):
			EventBus.disconnect(c[0], c[1])
	_connections.clear()
	running = false


func reset() -> void:
	objectives.clear()
	events.clear()


## Records one fact (the EventBus handlers call this; tests script sequences with it).
func record(sig: StringName, args: Array) -> void:
	if sig == OBJECTIVE_UPDATED:
		if args.size() >= 2:
			var data: Dictionary = args[2] as Dictionary if args.size() >= 3 and args[2] is Dictionary else {}
			objectives[StringName(args[0])] = {"state": int(args[1]), "skipped": bool(data.get("skipped", false))}
		return
	if events.size() < MAX_EVENTS:
		events.append([sig, args.duplicate()])


## The log as plain data for Achievements.on_payday.
func snapshot() -> Dictionary:
	return {"recorded": true, "objectives": objectives.duplicate(true), "events": events.duplicate(true)}


func _on_heist_ended(_result: Dictionary) -> void:
	stop()


func _handler(sig: StringName, argc: int) -> Callable:
	match argc:
		0:
			return func() -> void: record(sig, [])
		1:
			return func(a: Variant) -> void: record(sig, [a])
		2:
			return func(a: Variant, b: Variant) -> void: record(sig, [a, b])
		3:
			return func(a: Variant, b: Variant, c: Variant) -> void: record(sig, [a, b, c])
	return func(a: Variant, b: Variant, c: Variant, d: Variant) -> void: record(sig, [a, b, c, d])
