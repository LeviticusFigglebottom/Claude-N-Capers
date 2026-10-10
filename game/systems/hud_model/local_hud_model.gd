## Read-only HUD state for the LOCAL crew member (A1-11). Owner: ENV A.
## Contract: docs/contracts/ui_hud.md. ENV B binds every HUD scene ONLY to this node + EventBus.
## Property table, sources and update rates: game/systems/hud_model/README.md.
##
## Lives under HeistRuntime on EVERY peer (child named "LocalHudModel"). It never mutates game state,
## never reads Input and works on clients: it polls the runtime at `poll_hz` and listens to EventBus.
## All public vars are READ-ONLY for consumers (assigning them bypasses change notification).
## `changed(property)` fires for every property whose value actually changed (arrays/dictionaries
## are compared deeply); the hot properties also fire a specific signal (see README).
##
## Tracked crew member: `tracked_slot` (-1 = Net.local_slot()). Set it for spectating or tests.
##
## Duck-typed interfaces read when present (combat / weapons / stealth implementers MUST match):
##   crew.health   (Object, property on CrewController):
##       health: float, max_health: float, armor: float, max_armor: float,
##       downs_left: int, bleedout_left: float (seconds, 0 when not downed)
##   crew.weapons  (Object, property on CrewController):
##       mag(slot: int) -> int, reserve(slot: int) -> int (slot = Enums.WeaponSlot),
##       equipped_slot: int, deployable_count: int, throwable_count: int
##   crew.carried_bag (Node): loot_id: StringName, weight: int (Enums.LootWeight)
##   HeistRuntime.get_service(G.SVC_PAGERS).pager_entries() -> Array of
##       {pager_id: int, guard_net_id: int, time_left: float, answering: bool[, world_pos: Vector3]}
##   HeistRuntime.get_service(G.SVC_STEALTH):
##       marked_targets(crew_slot: int) -> Array (net ids marked for/visible to that crew member)
##       camera_countdown() -> float (seconds left, < 0 = none)
## Any member may be a property or a zero/one-argument method. Missing members fall back to defaults
## from Tweak.crew() (base_health 230, default_armor 20, downs_before_custody 3).
class_name LocalHudModel
extends Node

## Any property changed (`property` is its name, e.g. &"health").
signal changed(property: StringName)
signal health_changed(health: float, max_health: float)
signal armor_changed(armor: float, max_armor: float)
## interaction_prompt_key / interaction_progress / interaction_blocked_reason / suspicious_action_blocked.
signal interaction_changed()
signal detection_changed()
signal objectives_changed()
signal pager_timers_changed()
signal assault_changed(phase: int, wave: int)
signal teammates_changed()

## S1.1 "Suspicious actions not allowed" prompt (string key in en.csv, ENV B).
const SUSPICIOUS_PROMPT_KEY: StringName = &"ui.prompt.suspicious_not_allowed"
## Every public HUD property, in snapshot() order.
const PROPERTY_NAMES: Array[StringName] = [
	&"tracked_slot_resolved",
	&"health", &"max_health", &"armor", &"max_armor", &"downs_left", &"crew_state", &"bleedout_time_left",
	&"ammo_mag", &"ammo_reserve", &"equipped_slot", &"deployable_count", &"throwable_count",
	&"cable_ties", &"body_bags", &"carried_bag_loot_id", &"carried_bag_weight",
	&"interaction_prompt_key", &"interaction_progress", &"interaction_blocked_reason",
	&"suspicious_action_blocked", &"suspicious_action_prompt_key",
	&"detection_indicators", &"marked_targets", &"pager_timers", &"ecm_time_left", &"camera_countdown",
	&"objectives", &"assault_phase", &"assault_wave", &"hostages", &"phantom_warning", &"stinger_warning",
	&"teammates", &"masked", &"casing", &"mask_progress", &"heist_phase",
]
const SPECIAL_PHANTOM: StringName = &"phantom"
const SPECIAL_STINGER: StringName = &"stinger"

## Poll rate of the runtime (presentation only).
@export var poll_hz: float = 10.0
## Pager start window shown until PagerSystem provides pager_entries() (S5.2: 12 s).
@export var pager_window_s: float = 12.0
## Pager answer channel shown until PagerSystem provides pager_entries() (S5.2: 10 s).
@export var pager_answer_s: float = 10.0
## A detection indicator with no detection_progress update for this long is dropped.
@export var detection_stale_s: float = 1.0
## Phantom/Stinger warning radius around the tracked crew member (Phantom hum range, L4.3).
@export var special_warning_range_m: float = 25.0

## Crew slot to track; -1 = Net.local_slot(). Not a HUD property.
var tracked_slot: int = -1

## Slot actually tracked this poll (-1 = none).
var tracked_slot_resolved: int = -1
var health: float = 0.0
var max_health: float = 0.0
var armor: float = 0.0
var max_armor: float = 0.0
var downs_left: int = 0
var crew_state: Enums.CrewState = Enums.CrewState.NORMAL
## Seconds of bleedout left (L2.5), 0 when not downed.
var bleedout_time_left: float = 0.0
## Rounds in the magazine per Enums.WeaponSlot (PRIMARY, SECONDARY).
var ammo_mag: Dictionary[int, int] = {}
## Reserve rounds per Enums.WeaponSlot (PRIMARY, SECONDARY).
var ammo_reserve: Dictionary[int, int] = {}
var equipped_slot: Enums.WeaponSlot = Enums.WeaponSlot.PRIMARY
var deployable_count: int = 0
var throwable_count: int = 0
var cable_ties: int = 0
var body_bags: int = 0
## &"" = not carrying a bag.
var carried_bag_loot_id: StringName = &""
## Enums.LootWeight of the carried bag, -1 = none.
var carried_bag_weight: int = -1
## en.csv key of the current/aimed interaction prompt, &"" = none.
var interaction_prompt_key: StringName = &""
## 0..1 progress of the active hold interaction (S9.1).
var interaction_progress: float = 0.0
## InteractableComponent.BLOCK_* key, &"" = not blocked.
var interaction_blocked_reason: StringName = &""
## S1.1: true while a suspicious action is refused in casing mode.
var suspicious_action_blocked: bool = false
## SUSPICIOUS_PROMPT_KEY while suspicious_action_blocked, else &"".
var suspicious_action_prompt_key: StringName = &""
## [{observer_net_id: int, world_pos: Vector3, value: float 0..1, kind: int Enums.ObserverKind}]
var detection_indicators: Array[Dictionary] = []
## Net ids of marked enemies/cameras.
var marked_targets: Array[int] = []
## [{pager_id: int, guard_net_id: int, time_left: float, answering: bool, world_pos: Vector3}]
var pager_timers: Array[Dictionary] = []
## Longest running ECM, seconds left (0 = none).
var ecm_time_left: float = 0.0
## Camera countdown seconds (< 0 = none).
var camera_countdown: float = -1.0
## HeistMission.objectives(): [{id, text_key, state (Enums.ObjectiveState), data, order}]
var objectives: Array[Dictionary] = []
var assault_phase: Enums.AssaultPhase = Enums.AssaultPhase.NONE
var assault_wave: int = 0
var hostages: int = 0
var phantom_warning: bool = false
var stinger_warning: bool = false
## Other crew members by slot: [{slot, name, health_frac, armor_frac, state, downs_left,
## carried_bag_loot_id, is_ai}]
var teammates: Array[Dictionary] = []
var masked: bool = false
## Casing mode (S1.1) = not masked.
var casing: bool = true
## Mask-up hold progress 0..1.
var mask_progress: float = 0.0
var heist_phase: Enums.HeistPhase = Enums.HeistPhase.LOADING

var _runtime: HeistRuntime = null
var _accum: float = 0.0
var _mission: HeistMission = null
## observer_net_id -> {observer_net_id, value, kind, world_pos, age}
var _detection: Dictionary[int, Dictionary] = {}
## pager_id -> {pager_id, guard_net_id, time_left, answering}
var _pagers: Dictionary[int, Dictionary] = {}
## ecm_net_id -> seconds left
var _ecms: Dictionary[int, float] = {}
## npc_net_id -> special type (phantom / stinger)
var _specials: Dictionary[int, StringName] = {}
## Client-side objective cache from objective_updated [R].
var _event_objectives: Dictionary[StringName, Dictionary] = {}
var _connections: Array[Array] = []


func _ready() -> void:
	_listen(EventBus.heist_phase_changed, _on_heist_phase_changed)
	_listen(EventBus.assault_phase_changed, _on_assault_phase_changed)
	_listen(EventBus.hostage_count_changed, _on_hostage_count_changed)
	_listen(EventBus.crew_masked, _on_crew_masked)
	_listen(EventBus.detection_progress, _on_detection_progress)
	_listen(EventBus.pager_started, _on_pager_started)
	_listen(EventBus.pager_answer_started, _on_pager_answer_started)
	_listen(EventBus.pager_answered, _on_pager_answered)
	_listen(EventBus.pager_failed, _on_pager_failed)
	_listen(EventBus.ecm_started, _on_ecm_started)
	_listen(EventBus.ecm_ended, _on_ecm_ended)
	_listen(EventBus.objective_updated, _on_objective_updated)
	_listen(EventBus.special_spawned, _on_special_spawned)
	_listen(EventBus.npc_killed, _on_npc_killed)


func _exit_tree() -> void:
	for c: Array in _connections:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_connections.clear()
	if _mission != null and is_instance_valid(_mission) and _mission.objectives_changed.is_connected(_on_mission_objectives):
		_mission.objectives_changed.disconnect(_on_mission_objectives)
	_mission = null


func _process(delta: float) -> void:
	_tick_timers(delta)
	_accum += delta
	if _accum < 1.0 / maxf(poll_hz, 0.1):
		return
	_accum = 0.0
	refresh()


## Every HUD property by name (tests, debug overlay). Values are copies.
func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for p: StringName in PROPERTY_NAMES:
		var v: Variant = get(p)
		if v is Array or v is Dictionary:
			v = v.duplicate(true)
		out[p] = v
	return out


## Poll every source now (normally done at poll_hz).
func refresh() -> void:
	_runtime = HeistRuntime.of(self)
	var slot: int = tracked_slot if tracked_slot >= 0 else Net.local_slot()
	_assign(&"tracked_slot_resolved", slot)
	var crew: CrewController = null
	if _runtime != null and slot >= 0:
		crew = _runtime.crew_controller(slot) as CrewController
	if _runtime != null:
		_assign(&"heist_phase", _runtime.phase)
	_poll_vitals(crew, slot)
	_poll_weapons(crew)
	_poll_inventory(crew)
	_poll_interaction(crew, slot)
	_poll_stealth(slot)
	_poll_objectives()
	_poll_specials(crew)
	_poll_teammates(slot)


# --- Polling ----------------------------------------------------------------------

func _poll_vitals(crew: CrewController, slot: int) -> void:
	var tw: CrewTweak = Tweak.crew()
	var extra_downs: int = int(Modifiers.add(slot, &"defense.downs_extra")) if slot >= 0 else 0
	var hp: Object = _member_obj(crew, &"health")
	_assign(&"max_health", float(_read(hp, &"max_health", tw.base_health)))
	_assign(&"health", float(_read(hp, &"health", tw.base_health)))
	_assign(&"max_armor", float(_read(hp, &"max_armor", tw.default_armor)))
	_assign(&"armor", float(_read(hp, &"armor", tw.default_armor)))
	_assign(&"downs_left", int(_read(hp, &"downs_left", tw.downs_before_custody + extra_downs)))
	_assign(&"bleedout_time_left", float(_read(hp, &"bleedout_left", 0.0)))
	if crew != null:
		_assign(&"crew_state", crew.crew_state)
		_assign(&"masked", crew.masked)
		_assign(&"casing", not crew.masked)
		_assign(&"mask_progress", crew.mask_progress)


func _poll_weapons(crew: CrewController) -> void:
	var w: Object = _member_obj(crew, &"weapons")
	var mags: Dictionary[int, int] = {}
	var res: Dictionary[int, int] = {}
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		mags[ws] = int(_read_slot(w, &"mag", ws))
		res[ws] = int(_read_slot(w, &"reserve", ws))
	_assign(&"ammo_mag", mags)
	_assign(&"ammo_reserve", res)
	_assign(&"equipped_slot", int(_read(w, &"equipped_slot", Enums.WeaponSlot.PRIMARY)) as Enums.WeaponSlot)
	_assign(&"deployable_count", int(_read(w, &"deployable_count", 0)))
	_assign(&"throwable_count", int(_read(w, &"throwable_count", 0)))


func _poll_inventory(crew: CrewController) -> void:
	if crew == null:
		return
	_assign(&"cable_ties", crew.cable_ties)
	_assign(&"body_bags", crew.body_bags)
	var loot: StringName = &""
	var weight: int = -1
	if crew.is_carrying_bag():
		loot = StringName(_read(crew.carried_bag, &"loot_id", &""))
		weight = int(_read(crew.carried_bag, &"weight", Enums.LootWeight.MEDIUM))
	_assign(&"carried_bag_loot_id", loot)
	_assign(&"carried_bag_weight", weight)


func _poll_interaction(crew: CrewController, slot: int) -> void:
	var prompt: StringName = &""
	var prog: float = 0.0
	var blocked: StringName = &""
	var isys: InteractionSystem = _runtime.interaction if _runtime != null else null
	if crew != null and isys != null and is_instance_valid(isys):
		var sess: Dictionary = isys.session(slot)
		var comp: InteractableComponent = null
		if not sess.is_empty():
			comp = sess.get("comp") as InteractableComponent
			prog = isys.progress(slot)
		elif crew.is_inside_tree():
			comp = isys.aimed_component(crew)
			if comp != null:
				blocked = comp.availability(crew)
		if comp != null and is_instance_valid(comp):
			prompt = comp.prompt_key
		var srv_blocked: StringName = isys.blocked_reason(slot)
		if srv_blocked != &"":
			blocked = srv_blocked
	var suspicious: bool = blocked == InteractableComponent.BLOCK_CASING
	if crew != null and not crew.masked and crew.intent != null:
		var i: CrewIntent = crew.intent
		suspicious = suspicious or i.crouch or i.sprint or i.jump or i.deploy or i.throw_item or i.melee
	var before: Array = [interaction_prompt_key, interaction_progress, interaction_blocked_reason, suspicious_action_blocked]
	_assign(&"interaction_prompt_key", prompt)
	_assign(&"interaction_progress", prog)
	_assign(&"interaction_blocked_reason", blocked)
	_assign(&"suspicious_action_blocked", suspicious)
	_assign(&"suspicious_action_prompt_key", SUSPICIOUS_PROMPT_KEY if suspicious else &"")
	if before != [interaction_prompt_key, interaction_progress, interaction_blocked_reason, suspicious_action_blocked]:
		interaction_changed.emit()


func _poll_stealth(slot: int) -> void:
	_publish_detection()
	_publish_pagers()
	var st: Object = HeistRuntime.get_service(G.SVC_STEALTH) if _runtime != null else null
	var marks: Array[int] = []
	var raw: Variant = _read_slot(st, &"marked_targets", slot, [])
	if raw is Array:
		for v: Variant in raw:
			marks.append(int(v))
	_assign(&"marked_targets", marks)
	_assign(&"camera_countdown", float(_read(st, &"camera_countdown", -1.0)))


func _poll_objectives() -> void:
	var m: HeistMission = _runtime.mission if _runtime != null else null
	if m != _mission:
		if _mission != null and is_instance_valid(_mission) and _mission.objectives_changed.is_connected(_on_mission_objectives):
			_mission.objectives_changed.disconnect(_on_mission_objectives)
		_mission = m
		if _mission != null:
			_mission.objectives_changed.connect(_on_mission_objectives)
	var list: Array[Dictionary] = []
	if _mission != null and is_instance_valid(_mission) and Net.is_authority():
		list = _mission.objectives()
	else:
		for k: StringName in _event_objectives:
			list.append(_event_objectives[k].duplicate(true))
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	if _assign(&"objectives", list):
		objectives_changed.emit()


func _poll_specials(crew: CrewController) -> void:
	var phantom: bool = false
	var stinger: bool = false
	if crew != null and crew.is_inside_tree():
		for id: int in _specials.keys():
			var n: Node3D = Ids.lookup(id) as Node3D
			var alive: Variant = n.get(&"alive") if n != null else null
			if n == null or not is_instance_valid(n) or (alive != null and not bool(alive)):
				_specials.erase(id)
				continue
			if n.global_position.distance_to(crew.global_position) <= special_warning_range_m:
				phantom = phantom or _specials[id] == SPECIAL_PHANTOM
				stinger = stinger or _specials[id] == SPECIAL_STINGER
		stinger = stinger or crew.crew_state == Enums.CrewState.TASED
	_assign(&"phantom_warning", phantom)
	_assign(&"stinger_warning", stinger)


func _poll_teammates(slot: int) -> void:
	var list: Array[Dictionary] = []
	if _runtime != null:
		var tw: CrewTweak = Tweak.crew()
		for c: CrewController in _runtime.crew_members():
			if c.slot == slot:
				continue
			var hp: Object = _member_obj(c, &"health")
			var mh: float = maxf(float(_read(hp, &"max_health", tw.base_health)), 0.001)
			var ma: float = maxf(float(_read(hp, &"max_armor", tw.default_armor)), 0.001)
			var bag: StringName = &""
			if c.is_carrying_bag():
				bag = StringName(_read(c.carried_bag, &"loot_id", &""))
			list.append({
				"slot": c.slot, "name": c.display_name,
				"health_frac": clampf(float(_read(hp, &"health", mh)) / mh, 0.0, 1.0),
				"armor_frac": clampf(float(_read(hp, &"armor", ma)) / ma, 0.0, 1.0),
				"state": int(c.crew_state),
				"downs_left": int(_read(hp, &"downs_left", tw.downs_before_custody + int(Modifiers.add(c.slot, &"defense.downs_extra")))),
				"carried_bag_loot_id": bag, "is_ai": c.is_ai,
			})
	if _assign(&"teammates", list):
		teammates_changed.emit()


# --- Timers (stubbed until PagerSystem / ECM sync exist) ---------------------------

func _tick_timers(delta: float) -> void:
	for pid: int in _pagers:
		var e: Dictionary = _pagers[pid]
		e["time_left"] = maxf(float(e["time_left"]) - delta, 0.0)
	for eid: int in _ecms.keys():
		_ecms[eid] = maxf(_ecms[eid] - delta, 0.0)
	for oid: int in _detection.keys():
		_detection[oid]["age"] = float(_detection[oid]["age"]) + delta
		if float(_detection[oid]["age"]) > detection_stale_s:
			_detection.erase(oid)
	var ecm: float = 0.0
	for eid: int in _ecms:
		ecm = maxf(ecm, _ecms[eid])
	_assign(&"ecm_time_left", ecm)


func _publish_pagers() -> void:
	var list: Array[Dictionary] = []
	var svc: Object = HeistRuntime.get_service(G.SVC_PAGERS) if _runtime != null else null
	if svc != null and svc.has_method(&"pager_entries"):
		for v: Variant in svc.call(&"pager_entries"):
			if v is Dictionary:
				list.append(_pager_row(v as Dictionary))
	else:
		var ids: Array[int] = []
		ids.assign(_pagers.keys())
		ids.sort()
		for pid: int in ids:
			list.append(_pager_row(_pagers[pid]))
	if _assign(&"pager_timers", list):
		pager_timers_changed.emit()


func _pager_row(e: Dictionary) -> Dictionary:
	var gid: int = int(e.get("guard_net_id", 0))
	var pos: Variant = e.get("world_pos")
	if not pos is Vector3:
		var g: Node3D = Ids.lookup(gid) as Node3D
		pos = g.global_position if g != null and g.is_inside_tree() else Vector3.ZERO
	return {
		"pager_id": int(e.get("pager_id", 0)), "guard_net_id": gid,
		"time_left": float(e.get("time_left", 0.0)), "answering": bool(e.get("answering", false)),
		"world_pos": pos,
	}


func _publish_detection() -> void:
	var list: Array[Dictionary] = []
	var ids: Array[int] = []
	ids.assign(_detection.keys())
	ids.sort()
	for oid: int in ids:
		var d: Dictionary = _detection[oid]
		var obs: Node3D = Ids.lookup(oid) as Node3D
		var pos: Vector3 = d["world_pos"]
		if obs != null and obs.is_inside_tree():
			pos = obs.global_position
		d["world_pos"] = pos
		list.append({"observer_net_id": oid, "world_pos": pos, "value": float(d["value"]), "kind": int(d["kind"])})
	if _assign(&"detection_indicators", list):
		detection_changed.emit()


# --- EventBus ----------------------------------------------------------------------

func _on_heist_phase_changed(_old: int, new_phase: int) -> void:
	_assign(&"heist_phase", new_phase as Enums.HeistPhase)


func _on_assault_phase_changed(phase: int, wave_index: int) -> void:
	var a: bool = _assign(&"assault_phase", phase as Enums.AssaultPhase)
	var b: bool = _assign(&"assault_wave", wave_index)
	if a or b:
		assault_changed.emit(assault_phase, assault_wave)


func _on_hostage_count_changed(count: int) -> void:
	_assign(&"hostages", count)


func _on_crew_masked(crew_slot: int) -> void:
	if crew_slot == _slot():
		_assign(&"masked", true)
		_assign(&"casing", false)
		_assign(&"mask_progress", 1.0)
	_poll_teammates(_slot())


func _on_detection_progress(observer_net_id: int, crew_slot: int, value: float, kind: int) -> void:
	if crew_slot != _slot():
		return
	if value <= 0.0:
		_detection.erase(observer_net_id)
	else:
		var prev: Dictionary = _detection.get(observer_net_id, {})
		_detection[observer_net_id] = {
			"value": clampf(value, 0.0, 1.0), "kind": kind, "age": 0.0,
			"world_pos": prev.get("world_pos", Vector3.ZERO),
		}
	_publish_detection()


func _on_pager_started(pager_id: int, guard_net_id: int) -> void:
	_pagers[pager_id] = {"pager_id": pager_id, "guard_net_id": guard_net_id, "time_left": pager_window_s, "answering": false}
	_publish_pagers()


func _on_pager_answer_started(pager_id: int, _crew_slot: int) -> void:
	if not _pagers.has(pager_id):
		_pagers[pager_id] = {"pager_id": pager_id, "guard_net_id": 0}
	_pagers[pager_id]["answering"] = true
	_pagers[pager_id]["time_left"] = pager_answer_s
	_publish_pagers()


func _on_pager_answered(pager_id: int, _crew_slot: int, _total: int) -> void:
	_pagers.erase(pager_id)
	_publish_pagers()


func _on_pager_failed(pager_id: int, _reason: StringName) -> void:
	_pagers.erase(pager_id)
	_publish_pagers()


func _on_ecm_started(ecm_net_id: int, duration: float) -> void:
	_ecms[ecm_net_id] = duration
	_tick_timers(0.0)


func _on_ecm_ended(ecm_net_id: int) -> void:
	_ecms.erase(ecm_net_id)
	_tick_timers(0.0)


func _on_objective_updated(objective_id: StringName, state: int, data: Dictionary) -> void:
	var d: Dictionary = data.duplicate(true)
	var text_key: StringName = StringName(d.get("text_key", StringName("obj.%s" % objective_id)))
	d.erase("text_key")
	var order: int = _event_objectives.size()
	if _event_objectives.has(objective_id):
		order = int(_event_objectives[objective_id]["order"])
	_event_objectives[objective_id] = {"id": objective_id, "text_key": text_key, "state": state, "data": d, "order": order}
	_poll_objectives()


func _on_mission_objectives() -> void:
	_poll_objectives()


func _on_special_spawned(npc_net_id: int, special_type: StringName) -> void:
	if special_type == SPECIAL_PHANTOM or special_type == SPECIAL_STINGER:
		_specials[npc_net_id] = special_type


func _on_npc_killed(npc_net_id: int, _killer: int, _info: Dictionary) -> void:
	_specials.erase(npc_net_id)


# --- Helpers -----------------------------------------------------------------------

func _slot() -> int:
	return tracked_slot if tracked_slot >= 0 else Net.local_slot()


func _listen(sig: Signal, c: Callable) -> void:
	sig.connect(c)
	_connections.append([sig, c])


## Assign a HUD property; emits `changed` (+ health/armor signals) only on a real change.
func _assign(prop: StringName, value: Variant) -> bool:
	var old: Variant = get(prop)
	if typeof(old) == typeof(value) and old == value:
		return false
	set(prop, value)
	changed.emit(prop)
	if prop == &"health" or prop == &"max_health":
		health_changed.emit(health, max_health)
	elif prop == &"armor" or prop == &"max_armor":
		armor_changed.emit(armor, max_armor)
	return true


static func _member_obj(crew: Object, member: StringName) -> Object:
	if crew == null or not is_instance_valid(crew):
		return null
	var v: Variant = crew.get(member)
	return v as Object if v is Object else null


## Property or zero-argument method `key` of `obj`, else `default`.
static func _read(obj: Object, key: StringName, default: Variant) -> Variant:
	if obj == null or not is_instance_valid(obj):
		return default
	if obj.has_method(key):
		var r: Variant = obj.call(key)
		return r if r != null else default
	var v: Variant = obj.get(key)
	return v if v != null else default


## One-argument method `key(arg)` of `obj`, else `default`.
static func _read_slot(obj: Object, key: StringName, arg: int, default: Variant = 0) -> Variant:
	if obj == null or not is_instance_valid(obj) or not obj.has_method(key):
		return default
	var r: Variant = obj.call(key, arg)
	return r if r != null else default
