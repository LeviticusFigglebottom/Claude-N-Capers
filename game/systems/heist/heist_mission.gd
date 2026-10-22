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
## QC-83: NPC meta of a seated unit (the vehicle's net id) and the vehicle kinds whose occupants are out of sight.
const META_SEATED_IN: StringName = &"seated_in"
const ARMOURED_VEHICLES: Array[StringName] = [&"truck", &"van"]
## spawn_units beside a plain vehicle body (no seats): this far from its centre line (m).
const UNIT_SIDE_M: float = 1.9
## The seated pose (RT-D1 clip, AnimDriver hint) a unit holds in its vehicle.
const SEATED_HINT: StringName = &"sit_vehicle"
## D (r280): the driver's pose (hands on the wheel) for Seat0 of a vehicle whose occupants are seen.
const DRIVER_HINT: StringName = &"sit_vehicle_drive"
## QC-60 / §3b.9: spawn_loot(respawn = true) bags are checked this often (s) for having fallen off the map.
const LOOT_WATCH_TIMER: StringName = &"_loot_respawn_watch"
const LOOT_WATCH_S: float = 1.0

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
## QC-60: spawn_loot(respawn = true) bags: bag instance id -> [LootBag, marker Node3D].
var _respawn_bags: Dictionary[int, Array] = {}
## spawn_units: units placed per seat / point (instance id), so later calls take the free ones.
var _point_uses: Dictionary[int, int] = {}


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


## QC-63: variant group `group` was revealed during the run (reveal_variant_group, a code_note's
## `reveals_variant_group`): e.g. put marker_tags on the revealed `code_pc` slot's objective.
func _on_variant_revealed(_group: StringName) -> void:
	pass


# --- Objectives ------------------------------------------------------------------------

func add_objective(objective_id: StringName, text_key: StringName,
		state: Enums.ObjectiveState = Enums.ObjectiveState.ACTIVE, data: Dictionary = {}) -> void:
	# GN-8 (B's GN audit): re-adding an id (a relabel: GN hack_loud, casing_last_call) keeps its place in the order.
	var order: int = int(_objectives[objective_id]["order"]) if _objectives.has(objective_id) else _objectives.size()
	var prev: int = int(_objectives[objective_id]["state"]) if _objectives.has(objective_id) else -1
	_objectives[objective_id] = {
		"id": objective_id, "text_key": text_key, "state": state, "data": data, "order": order,
	}
	_publish(objective_id, prev != int(state))


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
		_publish(objective_id, false)


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


## A5-02 (D-149.1): make `id` the active layout of `group` (ConvoyLayouts: its pre-baked nav, cover, bodies and
## prefabs on, the group's others off; replicated). False for an id not in the group.
func set_layout(id: String, group: String = ConvoyLayouts.DEFAULT_GROUP) -> bool:
	return _runtime != null and _runtime.set_layout(id, group)


## QC-83 (a) (Rolling Thunder: `&"ambush"`, the crash stop): STEALTH -> LOUD from the mission, through the stealth
## director like any alarm (alarm_raised [R], _on_alarm, the phase change). No-op once loud.
func raise_alarm(reason: StringName, source_net_id: int = 0) -> void:
	if _runtime == null or _runtime.stealth == null or _runtime.went_loud:
		return
	_runtime.stealth.raise_alarm(reason, source_net_id)


## QC-83 (b) (Rolling Thunder: Vaultline crews and convoy escorts): spawn `count` units of `enemy_id` (the current
## faction's EnemyDef, AssaultDirector.enemy_def_for) through the director, as mission units: outside the assault
## force pool, and sharing the police cap (AssaultDirector.META_SHARES_CAP: police-role units count as police anyway).
## Points: with `vehicle` a ConvoyVehicle its `Seat0..n` markers; any other Node3D `vehicle` (a G1 placeholder body)
## spots beside it (UNIT_SIDE_M off its sides, alternating, along it); else every SpawnPoint tagged `spawn_tag`. On a
## seat or beside a body the unit carries `spawn_tag` as its spawn tag (NpcVisuals looks: RT `convoy_t1` crews). Seated
## (`seated`, with a vehicle; spawn them once it stopped): the unit stays on its seat, paused (no brain, physics or
## hits) and hidden when the vehicle is armoured (vehicle_kind truck / van), until dismount_units. Returns the units.
func spawn_units(enemy_id: StringName, count: int, spawn_tag: StringName, seated: bool = false,
		vehicle: Node3D = null) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	var dir: AssaultDirector = _director()
	if dir == null or count <= 0:
		return out
	var def: EnemyDef = dir.enemy_def_for(enemy_id)
	if def == null:
		Log.error(&"mission", "spawn_units: no EnemyDef '%s'" % enemy_id)
		return out
	var points: Array[Node3D] = _unit_points(spawn_tag, vehicle)
	if points.is_empty():
		Log.error(&"mission", "spawn_units: no seat / SpawnPoint for '%s'" % spawn_tag)
		return out
	for i: int in count:
		# D (RT cast): the least-used seat / point first, over every call (the mission spawns a vehicle's units one
		# call each), so two units never share a seat; a point used again steps 0.8 m aside per use.
		var p: Node3D = points[0]
		for q: Node3D in points:
			if int(_point_uses.get(q.get_instance_id(), 0)) < int(_point_uses.get(p.get_instance_id(), 0)):
				p = q
		var uses: int = int(_point_uses.get(p.get_instance_id(), 0))
		_point_uses[p.get_instance_id()] = uses + 1
		var xf: Transform3D = p.global_transform
		xf.origin += xf.basis.x * (0.8 * float(uses))
		var extra: Dictionary = {AssaultDirector.MISSION_UNIT: true}
		if not p is SpawnPoint and spawn_tag != &"":
			extra["tags"] = [spawn_tag]
		var npc: NpcBase = dir.spawn_enemy(def, xf, p if p is SpawnPoint else null, extra)
		if npc == null:
			continue
		npc.set_meta(AssaultDirector.META_SHARES_CAP, true)
		if seated and vehicle is ConvoyVehicle:
			npc.global_transform = p.global_transform
			_seat(npc, vehicle, p == points[0])
		out.append(npc)
	return out


## QC-83 (b): seated units out of their vehicle onto the road beside their seat (the seat's side, `step_m` out),
## awake: COMBAT once loud. Returns how many got out.
func dismount_units(units: Array, step_m: float = 1.6) -> int:
	var n: int = 0
	for u: Variant in units:
		if not is_instance_valid(u):  # P: freed in its seat (a harness, or killed and cleaned up) before the dismount
			continue
		var npc: NpcBase = u as NpcBase
		if npc == null or not npc.has_meta(META_SEATED_IN):
			continue
		var vehicle: Node3D = Ids.lookup(int(npc.get_meta(META_SEATED_IN))) as Node3D
		npc.remove_meta(META_SEATED_IN)
		if not npc.alive:
			continue  # killed in the car (C4, an explosion): the body stays where it died
		var was_visible: bool = npc.visible
		var left: bool = true
		var seat: Vector3 = npc.global_position
		var pos: Vector3 = seat
		if vehicle != null:
			var local: Vector3 = vehicle.to_local(seat)
			left = local.x >= 0.0  # facing +Z, local +x is the character's left (D: vehicle_exit_l)
			var side: Vector3 = vehicle.global_basis.x.normalized() * (1.0 if left else -1.0)
			pos = Vector3(seat.x, vehicle.global_position.y, seat.z) + side * (absf(local.x) + step_m)
		var fwd: Vector3 = -npc.global_basis.z
		var yaw: float = atan2(-fwd.x, -fwd.z) if Vector2(fwd.x, fwd.z).length() > 0.01 else 0.0
		var anim: AnimDriver = AnimDriver.of(npc)
		var exit_s: float = anim.vehicle_exit_length(left) if anim != null and was_visible and vehicle != null else 0.0
		n += 1
		if exit_s > 0.0:
			# D: the exit clip is in place and starts seated, the root on the footwell floor at the seat. The body
			# stays paused (no collision through the door frame) while the root slides out over the clip, then the
			# brain takes over.
			npc.global_transform = Transform3D(Basis(Vector3.UP, yaw), seat)  # upright: a seat on a ramp is tilted
			anim.play_vehicle_exit(left)
			var curve: PackedFloat32Array = AnimTweak.root_curve(AnimDriver.VEHICLE_EXIT_L if left else AnimDriver.VEHICLE_EXIT_R)
			var side: Vector3 = vehicle.global_basis.x.normalized() * (1.0 if left else -1.0)
			var ground_y: float = vehicle.global_position.y
			var tw: Tween = create_tween()
			tw.tween_method(_exit_step.bind(npc, seat, side, ground_y, curve, pos), 0.0, exit_s, exit_s)
			tw.tween_callback(_dismounted.bind(npc))
			continue
		npc.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)  # an armoured cab's crew steps out beside it
		_dismounted(npc)
	return n


## The exit slide at `t` s: D's root curve (curve.vehicle_exit_<side>: the root holds while the unit turns to the door,
## then moves out on the clip's own travel, so the planted feet never skate), from the seat down to the ground; without
## a curve, linear to `fallback` (the plain step-out spot).
func _exit_step(t: float, npc: NpcBase, seat: Vector3, side: Vector3, ground_y: float, curve: PackedFloat32Array,
		fallback: Vector3) -> void:
	if not is_instance_valid(npc):
		return
	if curve.is_empty():
		npc.global_position = seat.lerp(fallback, clampf(t / maxf(AnimDriver.of(npc).vehicle_exit_length(true), 0.01),
			0.0, 1.0))
		return
	var total: float = maxf(curve[curve.size() - 1], 0.001)
	var d: float = AnimTweak.curve_at(curve, t)
	var p: Vector3 = seat + side * d
	p.y = lerpf(seat.y, ground_y, d / total)
	npc.global_position = p


## A unit is out of its vehicle: brain, motor and collision back on; into the fight if the heist is loud.
func _dismounted(npc: NpcBase) -> void:
	if not is_instance_valid(npc):
		return
	npc.visible = true
	var brain: Node = npc.get_node_or_null(^"Brain")
	if brain != null and &"anim_hint" in brain and brain.get(&"anim_hint") in [SEATED_HINT, DRIVER_HINT]:
		brain.set(&"anim_hint", &"")
	npc.process_mode = Node.PROCESS_MODE_INHERIT
	var anim: AnimDriver = AnimDriver.of(npc)
	if anim != null:
		_hold_anim(anim, false)
	if _runtime != null and _runtime.went_loud and npc.alive:
		npc.set_alert_state(Enums.AlertState.COMBAT)


## The current faction has an EnemyDef `enemy_id` (spawn_units would spawn it).
func has_enemy(enemy_id: StringName) -> bool:
	var dir: AssaultDirector = _director()
	return dir != null and dir.enemy_def_for(enemy_id) != null


## A unit on its seat (D's RT convoy fit): facing the vehicle's front (+Z; the NPC faces its -Z), in the sit_vehicle
## pose (the `driver` in sit_vehicle_drive), paused (no brain, motor or collision) with only its AnimDriver still running
## so the pose holds; hidden in an armoured cab unless `shown` (D r280: Reyes at the Mixer's wheel, a "truck").
func _seat(npc: NpcBase, vehicle: Node3D, driver: bool = false, shown: bool = false) -> void:
	npc.set_meta(META_SEATED_IN, NetIds.of(vehicle))
	npc.global_transform = Transform3D(vehicle.global_basis.orthonormalized() * Basis(Vector3.UP, PI), npc.global_position)
	var kind: StringName = StringName(vehicle.get(&"vehicle_kind")) if &"vehicle_kind" in vehicle else &"car"
	npc.visible = shown or not ARMOURED_VEHICLES.has(kind)
	var brain: Node = npc.get_node_or_null(^"Brain")
	if brain != null and &"anim_hint" in brain:
		brain.set(&"anim_hint", DRIVER_HINT if driver and npc.visible else SEATED_HINT)
	npc.process_mode = Node.PROCESS_MODE_DISABLED  # no brain, motor or collision until it gets out
	var anim: AnimDriver = AnimDriver.of(npc)
	if anim != null and npc.visible:
		_hold_anim(anim, true)  # sit_vehicle, then the exit clip, animate while the body is paused (D r283)


## D r283: keep `anim` animating while its body is paused (a seated unit is PROCESS_MODE_DISABLED). The AnimationPlayer
## sits in the body's visual subtree and inherits DISABLED, so it goes ALWAYS with the driver (the sit loop and the
## vehicle_exit clip advance); off: both inherit again.
static func _hold_anim(anim: AnimDriver, on: bool) -> void:
	var mode: Node.ProcessMode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
	anim.process_mode = mode
	if anim.player != null:
		anim.player.process_mode = mode


func _unit_points(spawn_tag: StringName, vehicle: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var cv: ConvoyVehicle = vehicle as ConvoyVehicle
	if cv != null:
		for m: Node3D in cv.seats():
			out.append(m)
		if not out.is_empty():
			return out
	if vehicle != null:
		for i: int in 4:  # beside a plain body: left / right, front / back (made once, reused by later calls)
			var m: Marker3D = vehicle.get_node_or_null(NodePath("UnitPoint%d" % i)) as Marker3D
			if m != null:
				out.append(m)
				continue
			m = Marker3D.new()
			m.name = "UnitPoint%d" % i
			vehicle.add_child(m)
			var side: float = UNIT_SIDE_M * (1.0 if i % 2 == 0 else -1.0)
			m.position = Vector3(side, 0.05, 1.0 if i < 2 else -1.0)
			out.append(m)
		return out
	for n: Node in _runtime.map.find_children("*", "SpawnPoint", true, false):
		if (n as SpawnPoint).tags.has(spawn_tag):
			out.append(n as Node3D)
	return out


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


## QC-63 (server): reveal variant group `group` to the crew now, the same effect as a pre-planning asset's `reveals`
## (PreplanAssets.reveal_group; replicated). Calls `_on_variant_revealed(group)`. True the first time.
func reveal_variant_group(group: StringName) -> bool:
	if _runtime == null or not Net.is_authority():
		return false
	return _runtime.preplan.reveal_group(group)


## QC-63: true when `group` is known to the crew (bought intel or revealed during the run).
func is_variant_revealed(group: StringName) -> bool:
	return _runtime != null and _runtime.preplan.reveals().has(group)


## QC-60 (OF drill parts, timed loot): spawn `count` bags of `loot_id` (LootManager.spawn_bag, loot_spawned [R]) at
## the map's Node3D markers tagged `tag`: nodes whose `objective_tag` (property, as find_tagged, or a Marker3D's
## metadata `objective_tag`) is `tag`, in tree order, cycling (0.4 m up per reuse) when count > markers. Server.
## `respawn` (§3b.9: no soft lock): a bag destroyed / freed without being secured or consumed by a device
## (LootManager.META_CONSUMED) comes back at its marker, and a loose bag that fell InteractionTweak
## loot_lost_below_m below its marker (off the map) is put back there. Returns the bags ([] with no marker, logged).
func spawn_loot(loot_id: StringName, tag: StringName, count: int = 1, respawn: bool = false) -> Array:
	var out: Array = []
	var loot: LootManager = _runtime.service(G.SVC_LOOT) as LootManager if _runtime != null else null
	if loot == null or count <= 0 or not Net.is_authority():
		return out
	var markers: Array[Node3D] = loot_markers(tag)
	if markers.is_empty():
		Log.error(&"mission", "spawn_loot: no marker tagged '%s'" % tag)
		return out
	for i: int in range(count):
		var m: Node3D = markers[i % markers.size()]
		var bag: LootBag = _spawn_loot_at(loot, loot_id, m, i / markers.size())
		if bag == null:
			continue
		out.append(bag)
		if respawn:
			_watch_respawn(bag, m)
	return out


## QC-60: Node3D markers tagged `tag` for spawn_loot (bags excluded), in tree order.
func loot_markers(tag: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _runtime == null or tag == &"":
		return out
	for n: Node in find_tagged(tag):
		if n is Node3D and not n is LootBag:
			out.append(n as Node3D)
	if _runtime.map != null:
		for n: Node in _runtime.map.find_children("*", "Node3D", true, false):
			if n.has_meta(&"objective_tag") and StringName(n.get_meta(&"objective_tag")) == tag and not out.has(n):
				out.append(n as Node3D)
	return out


## RT-A6: `count` bags of `loot_id` stacked at `node` (a truck's cargo spot opened at runtime). Returns them.
func spawn_loot_at(loot_id: StringName, node: Node3D, count: int = 1) -> Array:
	var out: Array = []
	var loot: LootManager = _runtime.service(G.SVC_LOOT) as LootManager if _runtime != null else null
	if loot == null or node == null:
		return out
	for i: int in count:
		var bag: LootBag = _spawn_loot_at(loot, loot_id, node, i)
		if bag != null:
			out.append(bag)
	return out


func _spawn_loot_at(loot: LootManager, loot_id: StringName, marker: Node3D, layer: int) -> LootBag:
	var xf: Transform3D = marker.global_transform
	xf.basis = xf.basis.orthonormalized()
	xf.origin += Vector3.UP * (0.4 * float(layer))
	return loot.spawn_bag(loot_id, xf)


func _watch_respawn(bag: LootBag, marker: Node3D) -> void:
	_respawn_bags[bag.get_instance_id()] = [bag, marker]
	bag.tree_exiting.connect(_on_watched_bag_exit.bind(bag.get_instance_id(), bag.loot_id, marker), CONNECT_ONE_SHOT)
	if timer_left(LOOT_WATCH_TIMER) <= 0.0:
		start_timer(LOOT_WATCH_TIMER, LOOT_WATCH_S, _loot_watch_tick)


func _on_watched_bag_exit(id: int, loot_id: StringName, marker: Node3D) -> void:
	var entry: Array = _respawn_bags.get(id, [])
	_respawn_bags.erase(id)
	if entry.is_empty():
		return
	var bag: LootBag = entry[0] as LootBag
	if bag != null and is_instance_valid(bag) and (bag.secured or bag.has_meta(LootManager.META_CONSUMED)):
		return
	_respawn_loot.call_deferred(loot_id, marker)


func _respawn_loot(loot_id: StringName, marker: Node3D) -> void:
	if _runtime == null or not is_instance_valid(_runtime) or not _runtime.is_inside_tree() \
			or _runtime.is_queued_for_deletion() or _runtime.phase == Enums.HeistPhase.ENDED:
		return
	if marker == null or not is_instance_valid(marker) or not marker.is_inside_tree():
		return
	var loot: LootManager = _runtime.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = _spawn_loot_at(loot, loot_id, marker, 0) if loot != null else null
	if bag != null:
		Log.info(&"mission", "spawn_loot: %s respawned at %s" % [loot_id, marker.name])
		_watch_respawn(bag, marker)


func _loot_watch_tick() -> void:
	var below: float = Tweak.interaction().loot_lost_below_m
	for id: int in _respawn_bags.keys():
		var bag: LootBag = _respawn_bags[id][0] as LootBag
		var marker: Node3D = _respawn_bags[id][1] as Node3D
		if bag == null or not is_instance_valid(bag) or marker == null or not is_instance_valid(marker):
			continue
		if bag.is_carried() or bag.secured or not bag.is_inside_tree():
			continue
		if bag.global_position.y < marker.global_position.y - below:
			bag.release(marker.global_position + Vector3.UP * 0.3, Vector3.ZERO, false)
			Log.info(&"mission", "spawn_loot: %s fell off the map, back at %s" % [bag.loot_id, marker.name])
	if not _respawn_bags.is_empty():
		start_timer(LOOT_WATCH_TIMER, LOOT_WATCH_S, _loot_watch_tick)


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


## D-149.7 (Rolling Thunder: the street empties at the ambush; PD2 civilians run off a loud street): every civilian
## that can still run (not tied, down or a hostage) runs to the nearest PatrolPoint tagged `exit_tag` and despawns
## there (CivilianBrain.flee_map). Calm civilians panic first. Works loud or not (the mission calls it at the alarm).
## `only_spawn_tags` as civilians_leave. Returns how many left.
func civilians_flee(exit_tag: StringName = &"civ_flee", only_spawn_tags: Array[StringName] = []) -> int:
	if _runtime == null or _runtime.map == null:
		return 0
	var exits: Array[Vector3] = _patrol_points_tagged(exit_tag)
	if exits.is_empty():
		Log.error(&"mission", "civilians_flee: no PatrolPoint tagged '%s'" % exit_tag)
		return 0
	var count: int = 0
	for n: Node in _runtime.npcs(&"civilian"):
		var brain: CivilianBrain = n.get_node_or_null(^"Brain") as CivilianBrain
		if brain == null or not _has_spawn_tag(n as NpcBase, only_spawn_tags):
			continue
		if brain.flee_map(_nearest(exits, (n as Node3D).global_position)):
			count += 1
	return count


func _patrol_points_tagged(tag: StringName) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var stack: Array[Node] = [_runtime.map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var pp: PatrolPoint = n as PatrolPoint
		if pp != null and pp.tags.has(tag):
			out.append(pp.global_position)
		stack.append_array(n.get_children())
	return out


static func _nearest(points: Array[Vector3], pos: Vector3) -> Vector3:
	var best: Vector3 = points[0]
	for e: Vector3 in points:
		if pos.distance_squared_to(e) < pos.distance_squared_to(best):
			best = e
	return best


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
	rt.preplan.group_revealed.connect(_on_variant_revealed)


func _unbind() -> void:
	if _runtime != null and _runtime.preplan.group_revealed.is_connected(_on_variant_revealed):
		_runtime.preplan.group_revealed.disconnect(_on_variant_revealed)
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
	_publish(objective_id, true)


## `state_changed` (in the published data): false for a data-only update (counts, markers), so observers that log
## state transitions skip it (P's DB pass: `cartel -> ACTIVE` on every gunmen_down update).
func _publish(objective_id: StringName, state_changed: bool = true) -> void:
	var o: Dictionary = _objectives[objective_id]
	var data: Dictionary = (o["data"] as Dictionary).duplicate(true)
	data["text_key"] = o["text_key"]
	data["state_changed"] = state_changed
	EventBus.objective_updated.emit(objective_id, int(o["state"]), data)
	Net.replicate_event(&"objective_updated", [objective_id, int(o["state"]), data])
	objectives_changed.emit()


func _director() -> AssaultDirector:
	return _runtime.service(G.SVC_DIRECTOR) as AssaultDirector if _runtime != null else null
