## Read-only HUD state for the LOCAL crew member (A1-11). Owner: ENV A.
## Contract: docs/contracts/ui_hud.md v1.1 "exact binding shape (D-024)". ENV B binds every HUD scene
## ONLY to this node + EventBus: it finds it via group G.LOCAL_HUD_MODEL, reads properties with get()
## and connects the group signals by name. Property table and sources: game/systems/hud_model/README.md.
##
## Lives under HeistRuntime on EVERY peer (child named "LocalHudModel"). It never mutates game state,
## never reads Input and works on clients: it polls the runtime at `poll_hz` and listens to EventBus.
## Every public var is READ-ONLY for consumers. Internally each change ASSIGNS a new Array/Dictionary
## (never mutated in place), then the group signal of that property fires once (see GROUP_SIGNAL).
## `changed(property)` additionally fires per changed property (debug / tests).
##
## Tracked crew member: `tracked_slot` (-1 = Net.local_slot()). Set it for spectating or tests.
## `tracked_crew` mode (QB-48): `track(crew)` (or set `tracked_crew`) binds a CrewController directly,
## with or without a HeistRuntime (e.g. ENV B's firing range: add a LocalHudModel anywhere, then
## track(crew)). It wins over `tracked_slot`; the binding shape (properties, signals, group) is the same.
## Without a runtime the runtime-backed properties keep their defaults (objectives, crew, pagers...).
##
## Duck-typed interfaces read when present (combat / weapons / stealth implementers MUST match):
##   crew.health   (Object, property on CrewController):
##       health: float, max_health: float, armor: float, max_armor: float,
##       downs_left: int, bleedout_left: float (seconds; <= 0 or missing when not downed)
##   crew.weapons  (Object, property on CrewController):
##       mag(slot: int) -> int, reserve(slot: int) -> int (slot = Enums.WeaponSlot),
##       equipped_slot: int, deployable_count: int, throwable_count: int,
##       deployable_id: StringName, throwable_id: StringName (fallback: crew.loadout)
##   crew.carried_bag (Node): loot_id: StringName, weight: int (Enums.LootWeight)
##   InteractableComponent: prompt_key (export), optional prompt_args: Dictionary
##   HeistRuntime.get_service(G.SVC_PAGERS):
##       pager_entries() -> Array of {pager_id, guard_net_id, time_left, answering, world_pos[, progress]}
##       optional pagers_answered: int, pagers_max: int
##   HeistRuntime.get_service(G.SVC_STEALTH):
##       detection_entries(crew_slot) -> Array of {observer_net_id, world_pos, value, kind} (server)
##       marked_targets(crew_slot) -> Array of net ids or {net_id, world_pos, kind}
##       camera_countdown() -> float (seconds left, < 0 = none)
## Any member may be a property or a method. Missing members fall back to defaults from
## Tweak.crew() (base_health 230, default_armor 20, downs_before_custody 3) and Tweak.stealth().
class_name LocalHudModel
extends Node

## Debug/test: one property changed (`property` is its name). The contract signals follow.
signal changed(property: StringName)
## health, max_health, armor, max_armor, downs_left, crew_state, bleedout_s
signal vitals_changed()
## ammo, equipped_slot
signal ammo_changed()
## deployable_id, throwable_id, deployable_count, throwable_count, cable_ties, body_bags
signal inventory_changed()
## carried_bag
signal carried_bag_changed()
## interaction
signal interaction_changed()
## detection
signal detection_changed()
## marked_targets
signal marked_targets_changed()
## pagers, pagers_answered, pagers_max
signal pagers_changed()
## ecm_time_left_s, camera_alarm_s
signal timers_changed()
## objectives
signal objectives_changed()
## assault_phase, assault_wave
signal assault_changed()
## hostages
signal hostages_changed()
## warnings
signal warnings_changed()
## crew
signal crew_changed()
## masked, casing
signal masked_changed()

## S1.1 "Suspicious actions not allowed" prompt (strings.csv key, ENV B).
const SUSPICIOUS_PROMPT_KEY: StringName = &"ui.prompt.suspicious_not_allowed"
const WARNING_PHANTOM: StringName = &"phantom"
const WARNING_STINGER: StringName = &"stinger"
## Contract property -> its change signal (ui_hud.md v1.1).
const GROUP_SIGNAL: Dictionary[StringName, StringName] = {
	&"health": &"vitals_changed", &"max_health": &"vitals_changed", &"armor": &"vitals_changed",
	&"max_armor": &"vitals_changed", &"downs_left": &"vitals_changed", &"crew_state": &"vitals_changed",
	&"bleedout_s": &"vitals_changed",
	&"ammo": &"ammo_changed", &"equipped_slot": &"ammo_changed",
	&"deployable_id": &"inventory_changed", &"throwable_id": &"inventory_changed",
	&"deployable_count": &"inventory_changed", &"throwable_count": &"inventory_changed",
	&"cable_ties": &"inventory_changed", &"body_bags": &"inventory_changed",
	&"carried_bag": &"carried_bag_changed",
	&"interaction": &"interaction_changed",
	&"detection": &"detection_changed",
	&"marked_targets": &"marked_targets_changed",
	&"pagers": &"pagers_changed", &"pagers_answered": &"pagers_changed", &"pagers_max": &"pagers_changed",
	&"ecm_time_left_s": &"timers_changed", &"camera_alarm_s": &"timers_changed",
	&"objectives": &"objectives_changed",
	&"assault_phase": &"assault_changed", &"assault_wave": &"assault_changed",
	&"hostages": &"hostages_changed",
	&"warnings": &"warnings_changed",
	&"crew": &"crew_changed",
	&"masked": &"masked_changed", &"casing": &"masked_changed",
}
## Extra (non-contract) properties included in snapshot().
const EXTRA_PROPERTIES: Array[StringName] = [&"tracked_slot_resolved", &"mask_progress", &"heist_phase"]

## Poll rate of the runtime (presentation only).
@export var poll_hz: float = 10.0
## A client-side detection row with no detection_progress update for this long is dropped.
@export var detection_stale_s: float = 1.0
## Phantom/Stinger warning radius around the tracked crew member (Phantom hum range, L4.3).
@export var special_warning_range_m: float = 25.0

## Crew slot to track; -1 = Net.local_slot(). Not a HUD property.
var tracked_slot: int = -1
## QB-48: crew member tracked directly (wins over tracked_slot; null = slot mode). Not a HUD property.
var tracked_crew: CrewController = null

# --- vitals_changed
var health: float = 0.0
var max_health: float = 0.0
var armor: float = 0.0
var max_armor: float = 0.0
var downs_left: int = 0
var crew_state: Enums.CrewState = Enums.CrewState.NORMAL
## Seconds until custody while bleeding out (L2.5); < 0 = not bleeding out.
var bleedout_s: float = -1.0
# --- ammo_changed
## Enums.WeaponSlot (int) -> {"mag": int, "reserve": int} for PRIMARY and SECONDARY.
var ammo: Dictionary = {}
## Enums.WeaponSlot
var equipped_slot: int = Enums.WeaponSlot.PRIMARY
# --- inventory_changed
var deployable_id: StringName = &""
var throwable_id: StringName = &""
var deployable_count: int = 0
var throwable_count: int = 0
var cable_ties: int = 0
var body_bags: int = 0
# --- carried_bag_changed
## {} = none, else {"loot_id": StringName, "weight": int (Enums.LootWeight)}
var carried_bag: Dictionary = {}
# --- interaction_changed
## {} = no prompt, else {"text_key": StringName, "args": Dictionary, "progress": float 0..1,
## "blocked_reason": StringName (strings key or &"")}
var interaction: Dictionary = {}
# --- detection_changed
## [{"observer_net_id": int, "world_pos": Vector3, "value": float 0..1, "kind": int (Enums.ObserverKind)}]
var detection: Array[Dictionary] = []
# --- marked_targets_changed
## [{"net_id": int, "world_pos": Vector3, "kind": StringName}]
var marked_targets: Array[Dictionary] = []
# --- pagers_changed
## [{"pager_id": int, "time_left_s": float, "answering": bool, "progress": float 0..1}]
var pagers: Array[Dictionary] = []
var pagers_answered: int = 0
var pagers_max: int = 4
# --- timers_changed
## Longest running ECM, seconds; < 0 = none.
var ecm_time_left_s: float = -1.0
## Unstoppable camera alarm countdown (S3.5); < 0 = inactive.
var camera_alarm_s: float = -1.0
# --- objectives_changed
## [{"id": StringName, "text_key": StringName, "args": Dictionary, "state": int (Enums.ObjectiveState)}]
var objectives: Array[Dictionary] = []
# --- assault_changed
## Enums.AssaultPhase
var assault_phase: int = Enums.AssaultPhase.NONE
var assault_wave: int = 0
# --- hostages_changed
var hostages: int = 0
# --- warnings_changed
## Active special warnings: &"phantom", &"stinger".
var warnings: Array[StringName] = []
# --- crew_changed
## Teammates only, by slot: [{"slot": int, "name": String, "is_ai": bool, "health_frac": float,
## "armor_frac": float, "state": int (Enums.CrewState), "downs_left": int, "carried_loot_id": StringName}]
var crew: Array[Dictionary] = []
# --- masked_changed
var masked: bool = false
## Casing mode (S1.1) = tracked crew member unmasked.
var casing: bool = true
# --- extras (no contract signal; `changed` only)
## Slot actually tracked this poll (-1 = none).
var tracked_slot_resolved: int = -1
## Mask-up hold progress 0..1.
var mask_progress: float = 0.0
## Enums.HeistPhase
var heist_phase: int = Enums.HeistPhase.LOADING

var _runtime: HeistRuntime = null
var _accum: float = 0.0
var _mission: HeistMission = null
var _dirty: Dictionary[StringName, bool] = {}
## Client fallback: observer_net_id -> {value, kind, world_pos, age}
var _detection: Dictionary[int, Dictionary] = {}
## Fallback until PagerSystem: pager_id -> {pager_id, guard_net_id, time_left, answering}
var _pagers: Dictionary[int, Dictionary] = {}
## ecm_net_id -> seconds left
var _ecms: Dictionary[int, float] = {}
## npc_net_id -> special type (phantom / stinger)
var _specials: Dictionary[int, StringName] = {}
## Client objective cache from objective_updated [R]: id -> {id, text_key, args, state, order}
var _event_objectives: Dictionary[StringName, Dictionary] = {}
var _connections: Array[Array] = []


func _ready() -> void:
	add_to_group(G.LOCAL_HUD_MODEL)
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
	_assign(&"pagers_max", Tweak.stealth().pager_max_answers)
	_flush()


func _exit_tree() -> void:
	for c: Array in _connections:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_connections.clear()
	_bind_mission(null)


func _process(delta: float) -> void:
	_tick_timers(delta)
	_accum += delta
	if _accum < 1.0 / maxf(poll_hz, 0.1):
		_flush()
		return
	_accum = 0.0
	refresh()


## Every HUD property by name (contract + extras; tests, debug overlay). Values are deep copies.
func snapshot() -> Dictionary:
	var out: Dictionary = {}
	var names: Array[StringName] = []
	names.assign(GROUP_SIGNAL.keys())
	names.append_array(EXTRA_PROPERTIES)
	for p: StringName in names:
		var v: Variant = get(p)
		if v is Array or v is Dictionary:
			v = v.duplicate(true)
		out[p] = v
	return out


## QB-48: track `crew` directly (null = back to tracked_slot / the local slot). Refreshes now.
func track(crew_member: CrewController) -> void:
	tracked_crew = crew_member
	if is_inside_tree():
		refresh()


## Poll every source now (normally done at poll_hz) and emit the group signals that changed.
func refresh() -> void:
	var c: CrewController = _tracked()
	_runtime = _runtime_of(c) if c != null else HeistRuntime.of(self)
	var slot: int = _slot()
	_assign(&"tracked_slot_resolved", slot)
	if c == null and _runtime != null and slot >= 0:
		c = _runtime.crew_controller(slot) as CrewController
	if _runtime != null:
		_assign(&"heist_phase", int(_runtime.phase))
	_poll_vitals(c, slot)
	_poll_weapons(c)
	_poll_inventory(c)
	_poll_interaction(c, slot)
	_poll_detection(slot)
	_poll_marks_and_timers(slot)
	_publish_pagers()
	_poll_objectives()
	_poll_warnings(c)
	_poll_crew(slot)
	_flush()


# --- Polling ----------------------------------------------------------------------

func _poll_vitals(c: CrewController, slot: int) -> void:
	var tw: CrewTweak = Tweak.crew()
	var extra_downs: int = int(Modifiers.add(slot, &"defense.downs_extra")) if slot >= 0 else 0
	var hp: Object = _member_obj(c, &"health")
	_assign(&"max_health", float(_read(hp, &"max_health", tw.base_health)))
	_assign(&"health", float(_read(hp, &"health", tw.base_health)))
	_assign(&"max_armor", float(_read(hp, &"max_armor", tw.default_armor)))
	_assign(&"armor", float(_read(hp, &"armor", tw.default_armor)))
	_assign(&"downs_left", int(_read(hp, &"downs_left", tw.downs_before_custody + extra_downs)))
	var bleed: float = float(_read(hp, &"bleedout_left", -1.0))
	_assign(&"bleedout_s", bleed if bleed > 0.0 else -1.0)
	if c != null:
		_assign(&"crew_state", c.crew_state)
		_assign(&"masked", c.masked)
		_assign(&"casing", not c.masked)
		_assign(&"mask_progress", c.mask_progress)


func _poll_weapons(c: CrewController) -> void:
	var w: Object = _member_obj(c, &"weapons")
	var out: Dictionary = {}
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		out[ws] = {"mag": int(_read_slot(w, &"mag", ws)), "reserve": int(_read_slot(w, &"reserve", ws))}
	_assign(&"ammo", out)
	_assign(&"equipped_slot", int(_read(w, &"equipped_slot", Enums.WeaponSlot.PRIMARY)))
	var lo: Loadout = c.loadout if c != null else null
	_assign(&"deployable_id", StringName(_read(w, &"deployable_id", lo.deployable if lo != null else &"")))
	_assign(&"throwable_id", StringName(_read(w, &"throwable_id", lo.throwable if lo != null else &"")))
	_assign(&"deployable_count", int(_read(w, &"deployable_count", 0)))
	_assign(&"throwable_count", int(_read(w, &"throwable_count", 0)))


func _poll_inventory(c: CrewController) -> void:
	if c == null:
		return
	_assign(&"cable_ties", c.cable_ties)
	_assign(&"body_bags", c.body_bags)
	var bag: Dictionary = {}
	if c.is_carrying_bag():
		bag = {
			"loot_id": StringName(_read(c.carried_bag, &"loot_id", &"")),
			"weight": int(_read(c.carried_bag, &"weight", Enums.LootWeight.MEDIUM)),
		}
	_assign(&"carried_bag", bag)


func _poll_interaction(c: CrewController, slot: int) -> void:
	var prompt: StringName = &""
	var args: Dictionary = {}
	var prog: float = 0.0
	var blocked: StringName = &""
	var isys: InteractionSystem = _runtime.interaction if _runtime != null else null
	if c != null and isys != null and is_instance_valid(isys):
		var sess: Dictionary = isys.session(slot)
		var comp: InteractableComponent = null
		if not sess.is_empty():
			comp = sess.get("comp") as InteractableComponent
			prog = isys.progress(slot)
		elif c.is_inside_tree():
			comp = isys.aimed_component(c)
			if comp != null:
				blocked = comp.availability(c)
		if comp != null and is_instance_valid(comp):
			prompt = comp.prompt_key
			var a: Variant = comp.get(&"prompt_args")
			if a is Dictionary:
				args = (a as Dictionary).duplicate(true)
		var srv_blocked: StringName = isys.blocked_reason(slot)
		if srv_blocked != &"":
			blocked = srv_blocked
	# S1.1: suspicious action refused while casing.
	var suspicious: bool = blocked == InteractableComponent.BLOCK_CASING
	if c != null and not c.masked and c.intent != null:
		var i: CrewIntent = c.intent
		suspicious = suspicious or i.crouch or i.sprint or i.jump or i.deploy or i.throw_item or i.melee
	if suspicious:
		blocked = SUSPICIOUS_PROMPT_KEY
	var out: Dictionary = {}
	if prompt != &"" or blocked != &"" or prog > 0.0:
		out = {"text_key": prompt, "args": args, "progress": prog, "blocked_reason": blocked}
	_assign(&"interaction", out)


func _poll_detection(slot: int) -> void:
	var st: Object = _service(G.SVC_STEALTH)
	if st != null and st.has_method(&"detection_entries") and Net.is_authority():
		var rows: Array[Dictionary] = []
		for v: Variant in st.call(&"detection_entries", slot):
			if v is Dictionary and float((v as Dictionary).get("value", 0.0)) > 0.0:
				rows.append(_detection_row(v as Dictionary))
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["observer_net_id"]) < int(b["observer_net_id"]))
		_assign(&"detection", rows)
		return
	_publish_detection()


func _poll_marks_and_timers(slot: int) -> void:
	var st: Object = _service(G.SVC_STEALTH)
	var marks: Array[Dictionary] = []
	var raw: Variant = _read_slot(st, &"marked_targets", slot, [])
	if raw is Array:
		for v: Variant in raw:
			var row: Dictionary = _mark_row(v)
			if not row.is_empty():
				marks.append(row)
	_assign(&"marked_targets", marks)
	var cam: float = float(_read(st, &"camera_countdown", -1.0))
	_assign(&"camera_alarm_s", cam if cam >= 0.0 else -1.0)


func _poll_objectives() -> void:
	var m: HeistMission = _runtime.mission if _runtime != null else null
	_bind_mission(m)
	var src: Array[Dictionary] = []
	if _mission != null and Net.is_authority():
		for o: Dictionary in _mission.objectives():
			src.append({"id": o["id"], "text_key": o["text_key"], "args": o.get("data", {}), "state": o["state"]})
	else:
		var ids: Array[StringName] = []
		ids.assign(_event_objectives.keys())
		ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return int(_event_objectives[a]["order"]) < int(_event_objectives[b]["order"]))
		for k: StringName in ids:
			src.append(_event_objectives[k])
	var list: Array[Dictionary] = []
	for o: Dictionary in src:
		if int(o["state"]) == Enums.ObjectiveState.HIDDEN:
			continue
		list.append({
			"id": StringName(o["id"]), "text_key": StringName(o["text_key"]),
			"args": (o.get("args", {}) as Dictionary).duplicate(true), "state": int(o["state"]),
		})
	_assign(&"objectives", list)


func _poll_warnings(c: CrewController) -> void:
	var phantom: bool = false
	var stinger: bool = false
	if c != null and c.is_inside_tree():
		for id: int in _specials.keys():
			var n: Node3D = Ids.lookup(id) as Node3D
			var alive: Variant = n.get(&"alive") if n != null else null
			if n == null or not is_instance_valid(n) or (alive != null and not bool(alive)):
				_specials.erase(id)
				continue
			if n.is_inside_tree() and n.global_position.distance_to(c.global_position) <= special_warning_range_m:
				phantom = phantom or _specials[id] == WARNING_PHANTOM
				stinger = stinger or _specials[id] == WARNING_STINGER
		stinger = stinger or c.crew_state == Enums.CrewState.TASED
	var out: Array[StringName] = []
	if phantom:
		out.append(WARNING_PHANTOM)
	if stinger:
		out.append(WARNING_STINGER)
	_assign(&"warnings", out)


func _poll_crew(slot: int) -> void:
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
			var downs_default: int = tw.downs_before_custody + int(Modifiers.add(c.slot, &"defense.downs_extra"))
			list.append({
				"slot": c.slot, "name": c.display_name, "is_ai": c.is_ai,
				"health_frac": clampf(float(_read(hp, &"health", mh)) / mh, 0.0, 1.0),
				"armor_frac": clampf(float(_read(hp, &"armor", ma)) / ma, 0.0, 1.0),
				"state": int(c.crew_state), "downs_left": int(_read(hp, &"downs_left", downs_default)),
				"carried_loot_id": bag,
			})
	_assign(&"crew", list)


# --- Pagers / ECM / client detection -----------------------------------------------

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
	var ecm: float = -1.0
	for eid: int in _ecms:
		ecm = maxf(ecm, _ecms[eid])
	_assign(&"ecm_time_left_s", ecm)


func _publish_pagers() -> void:
	var list: Array[Dictionary] = []
	var svc: Object = _service(G.SVC_PAGERS)
	if svc != null and svc.has_method(&"pager_entries"):
		for v: Variant in svc.call(&"pager_entries"):
			if v is Dictionary:
				list.append(_pager_row(v as Dictionary))
		_assign(&"pagers_answered", int(_read(svc, &"pagers_answered", pagers_answered)))
		_assign(&"pagers_max", int(_read(svc, &"pagers_max", pagers_max)))
	else:
		var ids: Array[int] = []
		ids.assign(_pagers.keys())
		ids.sort()
		for pid: int in ids:
			list.append(_pager_row(_pagers[pid]))
	_assign(&"pagers", list)


func _pager_row(e: Dictionary) -> Dictionary:
	var left: float = float(e.get("time_left", e.get("time_left_s", 0.0)))
	var answering: bool = bool(e.get("answering", false))
	var answer_s: float = maxf(Tweak.stealth().pager_answer_s, 0.001)
	var prog: float = float(e.get("progress", clampf(1.0 - left / answer_s, 0.0, 1.0) if answering else 0.0))
	return {"pager_id": int(e.get("pager_id", 0)), "time_left_s": left, "answering": answering, "progress": prog}


func _publish_detection() -> void:
	var list: Array[Dictionary] = []
	var ids: Array[int] = []
	ids.assign(_detection.keys())
	ids.sort()
	for oid: int in ids:
		var d: Dictionary = _detection[oid]
		list.append(_detection_row({"observer_net_id": oid, "world_pos": d["world_pos"], "value": d["value"], "kind": d["kind"]}))
	_assign(&"detection", list)


static func _detection_row(e: Dictionary) -> Dictionary:
	var oid: int = int(e.get("observer_net_id", 0))
	var pos: Variant = e.get("world_pos", Vector3.ZERO)
	var obs: Node3D = Ids.lookup(oid) as Node3D
	if obs != null and obs.is_inside_tree():
		pos = obs.global_position
	return {
		"observer_net_id": oid, "world_pos": pos as Vector3,
		"value": clampf(float(e.get("value", 0.0)), 0.0, 1.0), "kind": int(e.get("kind", 0)),
	}


static func _mark_row(v: Variant) -> Dictionary:
	var nid: int = 0
	var kind: StringName = &""
	var pos: Vector3 = Vector3.ZERO
	if v is Dictionary:
		var d: Dictionary = v
		nid = int(d.get("net_id", 0))
		kind = StringName(d.get("kind", &""))
		pos = d.get("world_pos", Vector3.ZERO)
	elif v is int:
		nid = v
	var n: Node3D = Ids.lookup(nid) as Node3D
	if n != null and n.is_inside_tree():
		pos = n.global_position
		if kind == &"":
			var role: Variant = n.get(&"role")
			kind = StringName(role) if role != null else &""
	if nid == 0:
		return {}
	return {"net_id": nid, "world_pos": pos, "kind": kind}


# --- EventBus ----------------------------------------------------------------------

func _on_heist_phase_changed(_old: int, new_phase: int) -> void:
	_assign(&"heist_phase", new_phase)
	_flush()


func _on_assault_phase_changed(phase: int, wave_index: int) -> void:
	_assign(&"assault_phase", phase)
	_assign(&"assault_wave", wave_index)
	_flush()


func _on_hostage_count_changed(count: int) -> void:
	_assign(&"hostages", count)
	_flush()


func _on_crew_masked(crew_slot: int) -> void:
	if crew_slot == _slot():
		_assign(&"masked", true)
		_assign(&"casing", false)
		_assign(&"mask_progress", 1.0)
	_flush()


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
	if not Net.is_authority() or not _has_stealth_rows():
		_publish_detection()
		_flush()


func _on_pager_started(pager_id: int, guard_net_id: int) -> void:
	_pagers[pager_id] = {
		"pager_id": pager_id, "guard_net_id": guard_net_id,
		"time_left": Tweak.stealth().pager_window_s, "answering": false,
	}
	_publish_pagers()
	_flush()


func _on_pager_answer_started(pager_id: int, crew_slot: int) -> void:
	var e: Dictionary = _pagers.get(pager_id, {"pager_id": pager_id, "guard_net_id": 0})
	e["answering"] = true
	e["time_left"] = Tweak.stealth().pager_answer_s * Modifiers.mult(crew_slot, &"stealth.pager_answer_speed_mult")
	_pagers[pager_id] = e
	_publish_pagers()
	_flush()


func _on_pager_answered(pager_id: int, _crew_slot: int, total: int) -> void:
	_pagers.erase(pager_id)
	_assign(&"pagers_answered", total)
	_publish_pagers()
	_flush()


func _on_pager_failed(pager_id: int, _reason: StringName) -> void:
	_pagers.erase(pager_id)
	_publish_pagers()
	_flush()


func _on_ecm_started(ecm_net_id: int, duration: float) -> void:
	_ecms[ecm_net_id] = duration
	_tick_timers(0.0)
	_flush()


func _on_ecm_ended(ecm_net_id: int) -> void:
	_ecms.erase(ecm_net_id)
	_tick_timers(0.0)
	_flush()


func _on_objective_updated(objective_id: StringName, state: int, data: Dictionary) -> void:
	var args: Dictionary = data.duplicate(true)
	var text_key: StringName = StringName(args.get("text_key", StringName("obj.%s" % objective_id)))
	args.erase("text_key")
	var order: int = _event_objectives.size()
	if _event_objectives.has(objective_id):
		order = int(_event_objectives[objective_id]["order"])
	_event_objectives[objective_id] = {"id": objective_id, "text_key": text_key, "args": args, "state": state, "order": order}
	_poll_objectives()
	_flush()


func _on_mission_objectives() -> void:
	_poll_objectives()
	_flush()


func _on_special_spawned(npc_net_id: int, special_type: StringName) -> void:
	if special_type == WARNING_PHANTOM or special_type == WARNING_STINGER:
		_specials[npc_net_id] = special_type


func _on_npc_killed(npc_net_id: int, _killer: int, _info: Dictionary) -> void:
	_specials.erase(npc_net_id)


# --- Helpers -----------------------------------------------------------------------

func _slot() -> int:
	var c: CrewController = _tracked()
	if c != null:
		return c.slot
	return tracked_slot if tracked_slot >= 0 else Net.local_slot()


## The directly tracked crew member when still valid (a freed one drops back to slot mode).
func _tracked() -> CrewController:
	if not is_instance_valid(tracked_crew):
		tracked_crew = null
		return null
	return tracked_crew


## The HeistRuntime `crew` belongs to (an ancestor), else null: tracked_crew mode never falls back to
## HeistRuntime.current() for a crew member outside a heist.
static func _runtime_of(crew_member: Node) -> HeistRuntime:
	var n: Node = crew_member.get_parent() if crew_member != null else null
	while n != null:
		if n is HeistRuntime:
			return n as HeistRuntime
		n = n.get_parent()
	return null


func _service(service_name: StringName) -> Object:
	if _runtime == null and _tracked() == null:
		_runtime = HeistRuntime.of(self)
	if _runtime == null:
		return null
	var n: Node = _runtime.service(service_name)
	return n if n != null else HeistRuntime.get_service(service_name)


func _has_stealth_rows() -> bool:
	var st: Object = _service(G.SVC_STEALTH)
	return st != null and st.has_method(&"detection_entries")


func _bind_mission(m: HeistMission) -> void:
	if m == _mission:
		return
	if _mission != null and is_instance_valid(_mission) and _mission.objectives_changed.is_connected(_on_mission_objectives):
		_mission.objectives_changed.disconnect(_on_mission_objectives)
	_mission = m
	if _mission != null:
		_mission.objectives_changed.connect(_on_mission_objectives)


func _listen(sig: Signal, c: Callable) -> void:
	sig.connect(c)
	_connections.append([sig, c])


## Assign a NEW value to a HUD property; marks its group signal dirty only on a real change.
func _assign(prop: StringName, value: Variant) -> bool:
	var old: Variant = get(prop)
	if typeof(old) == typeof(value) and old == value:
		return false
	set(prop, value)
	changed.emit(prop)
	if GROUP_SIGNAL.has(prop):
		_dirty[GROUP_SIGNAL[prop]] = true
	return true


## Emit each dirty group signal once (after all properties of the batch are assigned).
func _flush() -> void:
	if _dirty.is_empty():
		return
	var sigs: Array[StringName] = []
	sigs.assign(_dirty.keys())
	_dirty.clear()
	for s: StringName in sigs:
		emit_signal(s)


static func _member_obj(obj: Object, member: StringName) -> Object:
	if obj == null or not is_instance_valid(obj):
		return null
	var v: Variant = obj.get(member)
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
