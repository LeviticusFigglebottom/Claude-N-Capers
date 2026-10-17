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
## D-115 (DB-3): CartelBrain.woken_by of a cartel gunman spawned by spawn_guards.
const REINFORCEMENT_WAKE: StringName = &"reinforcement"

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

## D-117 §6: true when this mission says its own last-pager line (in `_on_pager_answered` at `pager_cap()`);
## PagerSystem then skips the generic vo.mercer.pager_last so the cap is not called twice.
var own_last_pager_line: bool = false
## SL-6 (S11.3): true when this STEALTH_ONLY mission says its own abort line (in `_on_alarm`); HeistRuntime then
## skips the generic vo.mercer.abort so the alarm is not called twice.
var own_abort_line: bool = false
## B-SL audit: true once Mercer said this heist's own intro (a `vo.mercer.*_intro` line, set by `say`); BarkDirector
## then drops the generic casing line (heist_start_casing) so the heist is not introduced twice.
var own_intro_line: bool = false

var _runtime: HeistRuntime = null
## objective id ->{ "id", "text_key", "state", "data", "order" }
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
	# GN-8 (B's GN audit): re-adding an id (a relabel: GN hack_loud, casing_last_call) keeps its place in the order.
	var order: int = int(_objectives[objective_id]["order"]) if _objectives.has(objective_id) else _objectives.size()
	_objectives[objective_id] = {
		"id": objective_id, "text_key": text_key, "state": state, "data": data, "order": order,
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
## D-115 (DB-3): a point also tagged CartelBrain.SPAWN_TAG (`cartel`) spawns a cartel gunman instead, exactly as
## HeistRuntime._spawn_npcs does at load (role CartelBrain.ROLE, enemy_def CartelBrain.ENEMY_DEF), already awake
## (COMBAT, woken_by &"reinforcement"): reinforcements arrive into a fight.
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
		var npc: NpcBase = _spawn_scripted(sp2, xf)
		if npc != null:
			out.append(npc)
	return out


func _spawn_scripted(sp: SpawnPoint, xf: Transform3D) -> NpcBase:
	var info: Dictionary = HeistRuntime.spawn_info(sp)
	if not sp.tags.has(CartelBrain.SPAWN_TAG):
		return _runtime.spawn_npc(&"guard", xf, info)
	info["enemy_def"] = load(CartelBrain.ENEMY_DEF) as EnemyDef
	var npc: NpcBase = _runtime.spawn_npc(CartelBrain.ROLE, xf, info)
	if npc != null:
		var brain: CartelBrain = npc.get_node_or_null(^"Brain") as CartelBrain
		if brain != null:
			brain.wake(REINFORCEMENT_WAKE)
		else:
			npc.set_alert_state(Enums.AlertState.COMBAT)
	return npc


## Mercer (or another speaker) line: voice_line_requested [R] (C8).
func say(line_id: StringName, context: Dictionary = {}, speaker: StringName = SPEAKER_MERCER) -> void:
	if speaker == SPEAKER_MERCER and String(line_id).ends_with("_intro"):
		own_intro_line = true
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
## despawns there (no alarm). Refused while loud; alarmed / tied / fleeing civilians stay. `only_spawn_tags` (C's
## gap 1): when set, only civilians whose SpawnPoint tags include one of them leave (waitstaff, not the curator).
## The first `keep` matching calm civilians stay on (Gallery Night's stragglers). Returns how many left.
func civilians_leave(exit_tag: StringName = &"exit", only_spawn_tags: Array[StringName] = [], keep: int = 0) -> int:
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
		if brain == null or not _has_spawn_tag(n as NpcBase, only_spawn_tags):
			continue
		if keep > 0 and brain.mode in [CivilianBrain.Mode.IDLE, CivilianBrain.Mode.WANDER]:
			keep -= 1  # a straggler: stays on
			continue
		var pos: Vector3 = (n as Node3D).global_position
		var best: Vector3 = exits[0]
		for e: Vector3 in exits:
			if pos.distance_squared_to(e) < pos.distance_squared_to(best):
				best = e
		if brain.leave_map(best):
			count += 1
	return count


## QC-51: every MapZone of kind `from_kind` in this map becomes `to_kind` (replicated; Gallery Night last call:
## PUBLIC -> RESTRICTED). Returns how many zones changed.
func set_zone_kinds(from_kind: int, to_kind: int) -> int:
	if _runtime == null or _runtime.map == null:
		return 0
	var zones: Array[MapZone] = []
	for n: Node in _runtime.map.find_children("*", "Area3D", true, false):
		var z: MapZone = n as MapZone
		if z != null and z.kind == from_kind:
			zones.append(z)
	for z: MapZone in zones:
		ZoneKinds.set_kind(_runtime, z, to_kind)
	return zones.size()


## Server: keep the first `keep` civilians spawned with SpawnPoint tag `spawn_tag` (spawn order) and remove the rest
## (variant scalars such as Gallery Night's `patrons`; call at mission start). Returns how many were removed.
func thin_civilians(spawn_tag: StringName, keep: int) -> int:
	if _runtime == null or not Net.is_authority():
		return 0
	var seen: int = 0
	var removed: int = 0
	for n: Node in _runtime.npcs(&"civilian"):
		if not _has_spawn_tag(n as NpcBase, [spawn_tag]):
			continue
		seen += 1
		if seen > keep:
			n.queue_free()  # leaves the tree at frame end: HeistNetSync replicates the despawn
			removed += 1
	return removed


## QC-54 (C's stub review): take an AlarmGroups zone offline for the rest of the run (sensor_net slot, a hack).
func disable_alarm_group(group: StringName) -> void:
	if _runtime != null:
		AlarmGroups.disable(_runtime, group)


## True when the crew bought pre-planning asset `asset_id` for this run (e.g. &"asset.intel_list").
func has_asset(asset_id: StringName) -> bool:
	return _runtime != null and _runtime.preplan != null and _runtime.preplan.has_asset(asset_id)


## D-115: the crew's pre-planned spawn tag (PreplanAssets.spawn_tag; &"" = the default spawn), e.g. Dockside Burn's
## &"preplan_spawn_lane" (the thermite bag starts with the crew).
func crew_spawn_tag() -> StringName:
	return _runtime.preplan.spawn_tag() if _runtime != null and _runtime.preplan != null else &""


## D-115 (DB-13 / DB-17): the NPC of this heist with `npc_net_id` (alive or a corpse), or null.
func npc_by_net_id(npc_net_id: int) -> NpcBase:
	if _runtime == null or npc_net_id == 0:
		return null
	var npc: NpcBase = Ids.lookup(npc_net_id) as NpcBase
	return npc if npc != null and is_instance_valid(npc) and _runtime.is_ancestor_of(npc) else null


## D-115 (DB-13): the SNIPER_PERCH TacticalPoint a Longshot `npc_net_id` holds (its brain's claimed perch, else the
## nearest perch of the map), or null.
func sniper_perch_of(npc_net_id: int) -> TacticalPoint:
	var npc: NpcBase = npc_by_net_id(npc_net_id)
	if npc == null:
		return null
	var brain: Node = npc.get_node_or_null(^"Brain")
	var claimed: Variant = brain.get(&"perch") if brain != null else null
	if claimed is TacticalPoint and is_instance_valid(claimed):
		return claimed as TacticalPoint
	var best: TacticalPoint = null
	for n: Node in _runtime.map.get_slots(G.SNIPER_PERCH) if _runtime.map != null else []:
		var tp: TacticalPoint = n as TacticalPoint
		if tp == null or tp.kind != TacticalPoint.Kind.SNIPER_PERCH:
			continue
		if best == null or tp.global_position.distance_squared_to(npc.global_position) \
				< best.global_position.distance_squared_to(npc.global_position):
			best = tp
	return best


## S5.3: the answered-pager cap of this run (PagerSystem.max_answers: StealthTweak, or the heist's scalar).
func pager_cap() -> int:
	var ps: PagerSystem = _runtime.service(G.SVC_PAGERS) as PagerSystem if _runtime != null else null
	return ps.max_answers if ps != null else Tweak.stealth().pager_max_answers


## DB-6 (QC-25 director hook): open / close the map's SNIPER_PERCH TacticalPoints tagged `tag` for the director's
## Longshots (SpecialSpawner.set_perches_open). Returns how many perches matched.
func set_sniper_perches_open(tag: StringName, open: bool) -> int:
	return SpecialSpawner.set_perches_open(_runtime, tag, open) if Net.is_authority() else 0


## The effects of this run's rolled rare events: {event id: effects Dictionary} (HeistVariantTable.rare_events).
func rare_effects() -> Dictionary:
	var out: Dictionary = {}
	if _runtime == null or _runtime.map == null or _runtime.map.variant_table == null:
		return out
	var rolled: Variant = _runtime.variants.get(VariantResolver.RARE_KEY, [])
	for ev: Dictionary in _runtime.map.variant_table.rare_events:
		var id: StringName = StringName(ev.get("id", &""))
		if rolled is Array and (rolled as Array).has(id):
			out[id] = ev.get("effects", {})
	return out


static func _has_spawn_tag(npc: NpcBase, tags: Array[StringName]) -> bool:
	if tags.is_empty():
		return true
	if npc == null:
		return false
	var have: Variant = npc.spawn_info.get("tags", [])
	if have is Array:
		for t: StringName in tags:
			if (have as Array).has(t):
				return true
	return false


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
