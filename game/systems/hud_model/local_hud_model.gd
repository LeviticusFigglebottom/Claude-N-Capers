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
##   HeistRuntime service &"custody" (CustodySystem, server; ui_hud v1.2):
##       in_custody(slot) -> bool, negotiation_left(slot) -> float, auto_release_left(slot) -> float,
##       highlighted_hostage() -> Node with net_id
##   HeistRuntime.get_service(G.SVC_STEALTH):
##       detection_entries(crew_slot) -> Array of {observer_net_id, world_pos, value, kind, state} (server)
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
## ui_hud v1.7 (D-071): crew_stats
signal crew_stats_changed()
## masked, casing
signal masked_changed()
## ui_hud v1.2 (D-043): `custody` changed.
signal custody_changed()
## ui_hud v1.3 (D-049): captain_resistance, captain_present
signal captain_changed()
## ui_hud v1.4 (QB-60): stamina, exhausted
signal stamina_changed()
## ui_hud v1.5 (D-057, B4-18): weapon_charge / weapon_spin
signal weapon_charge_changed()
signal weapon_spin_changed()
## ui_hud v1.6 (S1.3, B5-05): player_mode
signal player_mode_changed()
## PP-A-1 (S5.8): dominate_target / dominate_window_s changed.
signal dominate_prompt_changed()
## ui_hud v1.8 (D-089): objective_markers changed.
signal objective_markers_changed(markers: Array[Dictionary])
## PO6-03 (ui_hud v1.9): placed timed devices (drills, thermal drills, saws, hack terminals).
signal devices_changed()
## ui_hud v1.20 (D-161): pocket_ecm
signal pocket_ecm_changed()
## ui_hud v1.21 (D-163): perk_item
signal perk_item_changed()

## S1.1 "Suspicious actions not allowed" prompt (strings.csv key, ENV B).
const SUSPICIOUS_PROMPT_KEY: StringName = &"ui.prompt.suspicious_not_allowed"
const WARNING_PHANTOM: StringName = &"phantom"
const WARNING_STINGER: StringName = &"stinger"
## A3-02 (L4.9): Commander Brandt on the map (captain_arrived .. captain_retreated).
const WARNING_CAPTAIN: StringName = &"captain"
## An objective whose marker_tags resolve to nothing is retried (backing off) at most this many times.
const MARKER_MAX_TRIES: int = 6
## Contract property -> its change signal (ui_hud.md v1.1 + v1.2 custody + v1.3 captain).
const GROUP_SIGNAL: Dictionary[StringName, StringName] = {
	&"health": &"vitals_changed", &"max_health": &"vitals_changed", &"armor": &"vitals_changed",
	&"max_armor": &"vitals_changed", &"downs_left": &"vitals_changed", &"crew_state": &"vitals_changed",
	&"bleedout_s": &"vitals_changed", &"flashed_s": &"vitals_changed",
	&"revive_progress": &"vitals_changed", &"reviver_slot": &"vitals_changed",
	&"ammo": &"ammo_changed", &"equipped_slot": &"ammo_changed",
	&"reloading": &"ammo_changed", &"reload_progress": &"ammo_changed",
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
	&"crew_stats": &"crew_stats_changed",
	&"masked": &"masked_changed", &"casing": &"masked_changed",
	&"custody": &"custody_changed",
	&"captain_resistance": &"captain_changed", &"captain_present": &"captain_changed",
	&"stamina": &"stamina_changed", &"exhausted": &"stamina_changed",
	&"weapon_charge": &"weapon_charge_changed", &"weapon_spin": &"weapon_spin_changed",
	&"player_mode": &"player_mode_changed",
	&"dominate_target": &"dominate_prompt_changed", &"dominate_window_s": &"dominate_prompt_changed",
	&"objective_markers": &"objective_markers_changed",
	&"devices": &"devices_changed",
	&"pocket_ecm": &"pocket_ecm_changed",
	&"perk_item": &"perk_item_changed",
}
## Extra (non-contract) properties included in snapshot().
const EXTRA_PROPERTIES: Array[StringName] = [&"tracked_slot_resolved", &"mask_progress", &"heist_phase", &"local_net_id"]

## PO6-20: height of a pager row's world_pos above the guard's body origin (m).
@export var pager_marker_up_m: float = 1.2
## PO6-03: height of a device row's world_pos above the device (m).
@export var device_panel_up_m: float = 0.45
## PO6-03: how far a device row's world_pos sits out of the lock face (m), so panels clear the safe door.
@export var device_panel_out_m: float = 0.25
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
## PO6-17b: seconds of breach / flash blindness left on the tracked member (0 = none); B / P white the screen out.
var flashed_s: float = 0.0
## ui_hud v1.10: 0..1 while the HUD's crew member is downed/helpless and someone holds revive on them, else 0.
var revive_progress: float = 0.0
## ui_hud v1.10: crew slot holding that revive (-1 = none).
var reviver_slot: int = -1
# --- stamina_changed (ui_hud v1.4, QB-60)
## Stamina current / max, 0..1 (CrewStamina).
var stamina: float = 1.0
## True while sprint is blocked after running dry (until back above the threshold).
var exhausted: bool = false
# --- weapon_charge_changed / weapon_spin_changed (ui_hud v1.5, D-057)
## Bow draw 0..1 while charging (0 otherwise); minigun spin-up 0..1 (CrewWeapons.charge / spin).
var weapon_charge: float = 0.0
var weapon_spin: float = 0.0
# --- player_mode_changed (ui_hud v1.6, S1.3)
## &"civilian" (no gear yet) | &"casing" | &"masked" (CrewController.player_mode).
var player_mode: StringName = &"casing"
## PP-A-1 (S5.8 / D-079): net id of the guard a shout would dominate right now (tracked crew has
## stealth.can_dominate_guards, guard inside his window, in range + aim cone), 0 = none. HUD (ENV B) shows
## the shout prompt / "!" telegraph while non-zero.
var dominate_target: int = 0
## Seconds left in that guard's window (0 when dominate_target is 0); client value is approximate.
var dominate_window_s: float = 0.0
# --- ammo_changed
## Enums.WeaponSlot (int) -> {"mag": int, "reserve": int} for PRIMARY and SECONDARY.
var ammo: Dictionary = {}
## Enums.WeaponSlot
var equipped_slot: int = Enums.WeaponSlot.PRIMARY
## ui_hud v1.12 (D-106): the equipped weapon is reloading, and how far (0..1; -1 when not reloading).
var reloading: bool = false
var reload_progress: float = -1.0
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
## {} = no prompt, else {"text_key": StringName, "kind": StringName, "args": Dictionary, "progress": float 0..1,
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
# --- pocket_ecm_changed (ui_hud v1.20, D-161)
## EcmSystem.pocket_state(tracked slot): {"charges", "max", "recharge_left", "active_left", "mode"}; {} = none.
var pocket_ecm: Dictionary = {}
# --- perk_item_changed (ui_hud v1.21, D-163)
## The deck throwable's state, any deck: {"kind": StringName (ThrowableDef.kind), "charges": int, "max": int,
## "cooldown_left": s, "active_left": s, "partner_slot": int (-1 = none), "mode": StringName (&"" | &"jam" |
## &"feedback"), v1.22 "segments": {"count", "size"} while a Leech ampule runs}; {} = no deck item. pocket_ecm stays one
## round as an alias (the pocket ECM shows here too).
var perk_item: Dictionary = {}
## Unstoppable camera alarm countdown (S3.5); < 0 = inactive.
var camera_alarm_s: float = -1.0
# --- objectives_changed
## [{"id": StringName, "text_key": StringName, "args": Dictionary, "state": int (Enums.ObjectiveState)}]
var objectives: Array[Dictionary] = []
# --- objective_markers_changed (ui_hud v1.8, D-089)
## [{"id": StringName, "text_key": StringName, "position": Vector3, "state": int}] for ACTIVE objectives
## whose data carries `marker_tags` (map objective_tags); one entry per tagged node in the map.
var objective_markers: Array[Dictionary] = []
# --- devices_changed (PO6-03, ui_hud v1.9)
## One row per placed device while running / jammed / paused (removed when done):
## {"net_id": int, "kind": StringName (&"drill"/&"thermal"/&"saw"/&"hack"), "world_pos": Vector3 (panel anchor),
##  "progress": float 0..1, "time_left_s": float (run time left, jams excluded), "duration_s": float,
##  "state": StringName (&"running"/&"jammed"/&"paused"), "fix_prompt_key": StringName (&"" unless jammed),
##  "auto_restart_in_s": float (>= 0 while a jammed device's auto-restart is pending, else -1)}.
## kinds also &"c4" (armed fuse) and &"time_lock" (Safe timers).
## Objective rows carry "device_net_id" (-1 = none): the device serving that ACTIVE objective.
var devices: Array[Dictionary] = []
# --- assault_changed
## Enums.AssaultPhase
var assault_phase: int = Enums.AssaultPhase.NONE
var assault_wave: int = 0
# --- hostages_changed
var hostages: int = 0
# --- warnings_changed
## Active special warnings: &"phantom", &"stinger", &"captain" (Brandt on the map; the % comes from
## AssaultDirector.aegis_resistance() on the server).
var warnings: Array[StringName] = []
# --- crew_changed
## Teammates only, by slot: [{"slot": int, "name": String, "is_ai": bool, "health_frac": float,
## "armor_frac": float, "state": int (Enums.CrewState), "downs_left": int, "carried_loot_id": StringName,
## "mode": StringName (ui_hud v1.6: &"civilian" / &"casing" / &"masked")}]
var crew: Array[Dictionary] = []
# --- crew_stats_changed (ui_hud v1.7, D-071)
## Every crew member (humans and Crew AI, local included), by slot: {"slot", "name", "is_ai", "is_local",
## "kills", "specials_killed", "civilians_killed", "downs", "shots", "hits", "headshots"} (server counts,
## CrewStatsService, replicated).
var crew_stats: Array[Dictionary] = []
# --- masked_changed
var masked: bool = false
## Casing mode (S1.1) = tracked crew member unmasked.
var casing: bool = true
## ui_hud v1.2: {} (not in custody) or {in_custody: bool, negotiation_left_s: float,
## auto_release_left_s: float (< 0 = none), highlighted_hostage_net_id: int (0 = none)}.
var custody: Dictionary = {}
# --- captain_changed (ui_hud v1.3)
## Commander Brandt's damage resistance for every enemy, 0..1 (server value, replicated by
## HeistNetSync to clients); 0 when he is absent or not in position yet.
var captain_resistance: float = 0.0
## Brandt is on the map (captain_arrived .. captain_retreated). ENV B shows the widget while true.
var captain_present: bool = false
# --- extras (no contract signal; `changed` only)
## Slot actually tracked this poll (-1 = none).
var tracked_slot_resolved: int = -1
## ui_hud v1.9 (D-100): net id of the crew member this HUD belongs to (0 = unknown); matches the attacker /
## victim ids of damage_applied / npc_killed for hit markers and damage arcs. Announced via `changed`.
var local_net_id: int = 0
## Mask-up hold progress 0..1.
var mask_progress: float = 0.0
## Enums.HeistPhase
var heist_phase: int = Enums.HeistPhase.LOADING

## Lookups walked by find_by_tag since the runtime was bound (tests / profiling).
var marker_lookups: int = 0
## ui_hud v1.16: scoped ADS overlay state, WRITTEN by ENV P's scope overlay every frame and read by ENV B with get()
## (fields only, no signal; the model never sets them). `scope_ring`: the scope's clear circle in viewport pixels
## (Rect2() when not scoped).
var scoped_ads: bool = false
var scope_ring: Rect2 = Rect2()
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
var _captain_present: bool = false
## Client objective cache from objective_updated [R]: id -> {id, text_key, args, state, order}
var _event_objectives: Dictionary[StringName, Dictionary] = {}
## ui_hud v1.8 marker cache: objective id -> tagged map nodes; key = active marked objectives + tags.
var _marker_nodes: Dictionary[StringName, Array] = {}
var _reload_total: float = 0.0
## Per objective id: the args signature its markers were resolved for, and the retry state of an unresolved one
## ({"next": poll index, "tries": int}). Resolved ids are never re-queried until their data changes.
var _marker_sig: Dictionary[StringName, String] = {}
var _marker_retry: Dictionary[StringName, Dictionary] = {}
## PO6-03: net ids of known timed devices; client extrapolation [progress, seen_at_s, state] per id;
## the runtime last scanned for devices; objective id -> serving device net id.
var _device_ids: Dictionary[int, bool] = {}
var _device_seen: Dictionary[int, Array] = {}
var _devices_scanned_rt: HeistRuntime = null
var _objective_device: Dictionary[StringName, int] = {}
var _marker_poll: int = 0
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
	_listen(EventBus.device_started, _on_device_started)
	_listen(EventBus.objective_updated, _on_objective_updated)
	_listen(EventBus.special_spawned, _on_special_spawned)
	_listen(EventBus.npc_killed, _on_npc_killed)
	_listen(EventBus.captain_arrived, _on_captain_arrived)
	_listen(EventBus.captain_retreated, _on_captain_retreated)
	_assign(&"pagers_max", PagerSystem.cap_for(HeistRuntime.of(self)))  # D-130: the heist's cap by difficulty
	_flush()


func _exit_tree() -> void:
	for c: Array in _connections:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_connections.clear()
	_bind_mission(null)


func _process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_process_step(delta)
	FrameProf.end(&"hud_model", fp)


func _process_step(delta: float) -> void:
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
func track(crew_member: Node) -> void:
	tracked_crew = crew_member as CrewController
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
	# LEAD (OF loud hitches: one hud_model frame of 458 ms at OF start): FrameProf sub-keys name the slow poll.
	var fp: int = FrameProf.begin()
	_poll_vitals(c, slot)
	_poll_weapons(c)
	_poll_inventory(c)
	_poll_interaction(c, slot)
	fp = FrameProf.lap(&"hud_model.player", fp)
	_poll_detection(slot)
	_poll_marks_and_timers(slot)
	_publish_pagers()
	fp = FrameProf.lap(&"hud_model.stealth", fp)
	_poll_devices()
	_poll_objectives()
	fp = FrameProf.lap(&"hud_model.objectives", fp)
	_poll_warnings(c)
	_poll_dominate(c)
	_poll_crew(slot)
	_poll_crew_stats()
	_poll_custody(c, slot)
	_poll_captain()
	fp = FrameProf.lap(&"hud_model.crew", fp)
	_flush()  # emits the changed groups: the HUD's own handlers run inside
	FrameProf.end(&"hud_model.flush", fp)


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
	_assign(&"flashed_s", snappedf(float(_read(hp, &"flashed_left", 0.0)), 0.05))
	var bleed: float = float(_read(hp, &"bleedout_left", -1.0))
	_assign(&"bleedout_s", bleed if bleed > 0.0 else -1.0)
	_assign(&"local_net_id", c.net_id if c != null else 0)
	var rv: Vector2 = _revive_of(c)
	_assign(&"revive_progress", maxf(rv.x, 0.0))
	_assign(&"reviver_slot", int(rv.y))
	if c != null:
		_assign(&"crew_state", c.crew_state)
		_assign(&"masked", c.masked)
		_assign(&"casing", not c.masked)
		_assign(&"mask_progress", c.mask_progress)
		_assign(&"stamina", snappedf(c.stamina.fraction(), 0.01))
		_assign(&"player_mode", c.player_mode)
		_assign(&"exhausted", c.stamina.exhausted)


## v1.12: progress from reload_left against the longest reload_left seen since this reload began (covers
## whole-magazine and shell-by-shell reloads alike).
func _poll_reload(w: Object) -> void:
	var on: bool = bool(_read(w, &"reloading", false))
	var left: float = float(_read(w, &"reload_left", 0.0))
	if not on:
		_reload_total = 0.0
		_assign(&"reloading", false)
		_assign(&"reload_progress", -1.0)
		return
	_reload_total = maxf(_reload_total, left)
	_assign(&"reloading", true)
	_assign(&"reload_progress", snappedf(clampf(1.0 - left / _reload_total, 0.0, 1.0) if _reload_total > 0.0 else 0.0, 0.01))


func _poll_weapons(c: CrewController) -> void:
	var w: Object = _member_obj(c, &"weapons")
	var out: Dictionary = {}
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		out[ws] = {"mag": int(_read_slot(w, &"mag", ws)), "reserve": int(_read_slot(w, &"reserve", ws))}
	_assign(&"ammo", out)
	_assign(&"equipped_slot", int(_read(w, &"equipped_slot", Enums.WeaponSlot.PRIMARY)))
	_poll_reload(w)
	var lo: Loadout = c.loadout if c != null else null
	_assign(&"deployable_id", StringName(_read(w, &"deployable_id", lo.deployable if lo != null else &"")))
	# ui_hud v1.20: a deck throwable (flask, injector, pocket ECM) replaces the loadout's (PerkHooks.throwable_id).
	var deck_item: StringName = PerkHooks.throwable_id(c) if c != null else &""
	_assign(&"throwable_id", deck_item if deck_item != &"" else StringName(_read(w, &"throwable_id",
		lo.throwable if lo != null else &"")))
	var ecm: EcmSystem = _rt_service(c, EcmSystem.SERVICE) as EcmSystem
	var pocket: Dictionary = ecm.pocket_state(c.slot).duplicate() if ecm != null and c != null else {}
	_assign(&"pocket_ecm", pocket)
	var items: PerkItems = _rt_service(c, PerkItems.SERVICE) as PerkItems
	var item: Dictionary = items.state(c.slot).duplicate() if items != null and c != null else {}
	if item.is_empty() and not pocket.is_empty():
		item = PerkItems.entry(PerkPocketEcm.KIND, int(pocket["charges"]), int(pocket["max"]),
			float(pocket["recharge_left"]), float(pocket["active_left"]), -1, StringName(pocket["mode"]))
	_assign(&"perk_item", item)
	_assign(&"deployable_count", int(_read(w, &"deployable_count", 0)))
	_assign(&"throwable_count", int(_read(w, &"throwable_count", 0)))
	_assign(&"weapon_charge", snappedf(float(_read(w, &"charge", 0.0)), 0.01))
	_assign(&"weapon_spin", snappedf(float(_read(w, &"spin", 0.0)), 0.01))


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
	var kind: StringName = &""
	var blocked: StringName = &""
	var isys: InteractionSystem = _runtime.interaction if _runtime != null else null
	if isys == null and c != null:
		isys = c.hub_interaction  # QC-43: the safehouse crew's own system
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
			kind = comp.kind  # P PO-pass #13: the panel names the verb for a generic prompt
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
		out = {"text_key": prompt, "kind": kind, "args": args, "progress": prog, "blocked_reason": blocked}
	_assign(&"interaction", out)


func _poll_detection(slot: int) -> void:
	var st: Object = _service(G.SVC_STEALTH)
	if st != null and st.has_method(&"detection_entries") and Net.is_authority():
		var rows: Array[Dictionary] = []
		for v: Variant in st.call(&"detection_entries", slot):
			# ui_hud v1.17: value-0 rows of CURIOUS / INVESTIGATING observers carry their "?" state.
			if v is Dictionary and (float((v as Dictionary).get("value", 0.0)) > 0.0
					or StringName((v as Dictionary).get("state", &"")) != &""):
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


## GN-8 (B's GN audit): the HUD's current step is the first ACTIVE row, so an ACTIVE optional / as-needed step
## (`args.optional`: GN keycard, code, hack) listed before a required one (the centrepiece) took the slot. Every
## ACTIVE optional row moves to just after the last ACTIVE required row; everything else keeps the mission order.
## With no required step active the order is unchanged (the optional steps are then the current ones).
static func required_first(rows: Array[Dictionary]) -> Array[Dictionary]:
	var last_req: int = -1
	for i: int in range(rows.size()):
		if _row_active(rows[i]) and not _row_optional(rows[i]):
			last_req = i
	if last_req < 0:
		return rows
	var out: Array[Dictionary] = []
	var moved: Array[Dictionary] = []
	for i: int in range(rows.size()):
		if i < last_req and _row_active(rows[i]) and _row_optional(rows[i]):
			moved.append(rows[i])
			continue
		out.append(rows[i])
		if i == last_req:
			out.append_array(moved)
	return out


static func _row_active(row: Dictionary) -> bool:
	return int(row.get("state", -1)) == Enums.ObjectiveState.ACTIVE


static func _row_optional(row: Dictionary) -> bool:
	return bool((row.get("args", {}) as Dictionary).get("optional", false))


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
			"device_net_id": int(_objective_device.get(StringName(o["id"]), -1)),
		})
	_assign(&"objectives", required_first(list))
	_poll_markers(src)


## ui_hud v1.8: markers for ACTIVE objectives with `marker_tags`. Tag lookups walk the map, so they are
## cached per objective and redone only for an objective that appears or has its data updated
## (update_objective_data: new marker_tags, or a node given a matching objective_tag at runtime, QC-60);
## an unresolved one retries with back-off up to MARKER_MAX_TRIES. Positions are read every poll.
func _poll_markers(src: Array[Dictionary]) -> void:
	if _runtime == null:
		return  # objectives published before the runtime is bound: resolve on a later poll
	var want: Dictionary[StringName, Array] = {}
	var sigs: Dictionary[StringName, String] = {}
	var skips: Dictionary[StringName, Variant] = {}
	for o: Dictionary in src:
		var tags: Variant = (o.get("args", {}) as Dictionary).get("marker_tags", [])
		if int(o["state"]) != Enums.ObjectiveState.ACTIVE or not (tags is Array) or (tags as Array).is_empty():
			continue
		if bool((o.get("args", {}) as Dictionary).get("disabled", false)):
			continue  # e.g. Night Deposit's code / server steps in a lockdown (the panel hides them too)
		want[StringName(o["id"])] = tags as Array
		skips[StringName(o["id"])] = (o.get("args", {}) as Dictionary).get("marker_skip_prefixes", [])
		sigs[StringName(o["id"])] = str(o.get("args", {}))  # any data update re-resolves (QC-60: runtime tags)
	_marker_poll += 1
	for gone: StringName in _marker_nodes.keys():
		if not want.has(gone):
			_marker_nodes.erase(gone)
			_marker_sig.erase(gone)
			_marker_retry.erase(gone)
	# P / lead (ND 1 Hz stutter): each find_by_tag walks the whole map, so only new / changed objectives are
	# resolved, and an unresolved one retries with exponential back-off and gives up after MARKER_MAX_TRIES.
	var todo: Array[StringName] = []
	var tags: Array = []
	for id: StringName in want:
		var changed: bool = _marker_sig.get(id, "") != sigs[id] or not _marker_nodes.has(id)
		if not changed:
			if not (_marker_nodes[id] as Array).is_empty():
				continue
			var r: Dictionary = _marker_retry.get(id, {})
			if int(r.get("tries", 0)) >= MARKER_MAX_TRIES or _marker_poll < int(r.get("next", 0)):
				continue
		else:
			_marker_retry.erase(id)
		todo.append(id)
		for t: Variant in want[id]:
			if not tags.has(StringName(t)):
				tags.append(StringName(t))
	# LEAD (OF start: 477 ms here): every tag of every objective to resolve in ONE map walk.
	var found: Dictionary = _runtime.find_by_tags(tags) if not tags.is_empty() else {}
	for id: StringName in todo:
		_marker_sig[id] = sigs[id]
		var nodes: Array[Node3D] = []
		for t: Variant in want[id]:
			marker_lookups += 1
			for n: Node in found.get(StringName(t), []):
				if n is Node3D and not _marker_skipped(n, skips[id]):
					nodes.append(n as Node3D)
		_marker_nodes[id] = nodes
		if nodes.is_empty():
			var tries: int = int((_marker_retry.get(id, {}) as Dictionary).get("tries", 0)) + 1
			var wait: int = int(maxf(poll_hz, 1.0)) * (1 << mini(tries - 1, 5))  # ~1 s, 2 s, 4 s ... (map not ready)
			_marker_retry[id] = {"tries": tries, "next": _marker_poll + wait}
		else:
			_marker_retry.erase(id)
	var out: Array[Dictionary] = []
	for o2: Dictionary in src:
		var oid: StringName = StringName(o2["id"])
		if not _marker_nodes.has(oid):
			continue
		for v: Variant in _marker_nodes[oid]:
			if not is_instance_valid(v):
				continue  # freed (picked-up keycard, ...)
			var n3: Node3D = v as Node3D
			if n3.is_inside_tree() and n3.is_visible_in_tree():
				out.append({"id": oid, "text_key": StringName(o2["text_key"]), "position": n3.global_position,
					"state": int(o2["state"])})
	_assign(&"objective_markers", out)


## Objective data `marker_skip_prefixes` (Array of node-name prefixes): tagged nodes the mission does not mark yet
## (OF: the vault-wall deposit boxes while the vault is sealed; the SD hall's boxes are marked).
static func _marker_skipped(n: Node, prefixes: Variant) -> bool:
	if not (prefixes is Array):
		return false
	for p: Variant in prefixes:
		if String(n.name).begins_with(String(p)):
			return true
	return false


## PO6-03: device rows from the known device net ids (EventBus device_started on every peer, plus one scan of
## the interactables when the runtime binds, for late joiners). Clients extrapolate a running device's
## progress between replicated snapshots (HeistNetSync mirrors runner / hack state at its own rate).
func _poll_devices() -> void:
	if _runtime == null:
		_assign(&"devices", [] as Array[Dictionary])
		return
	if _devices_scanned_rt != _runtime:
		_devices_scanned_rt = _runtime
		_device_seen.clear()
		for comp: Node in get_tree().get_nodes_in_group(G.INTERACTABLE):
			var owner_node: Node = comp.get_parent()
			if owner_node != null and _runtime.is_ancestor_of(owner_node) and _device_info(owner_node).size() > 0:
				_device_ids[NetIds.of(owner_node)] = true
	var now: float = Time.get_ticks_msec() / 1000.0
	var out: Array[Dictionary] = []
	var obj_dev: Dictionary[StringName, int] = {}
	for id: int in _device_ids.keys():
		var n: Node3D = Ids.lookup(id) as Node3D
		if n == null or not is_instance_valid(n) or not n.is_inside_tree():
			_device_ids.erase(id)
			_device_seen.erase(id)
			continue
		var info: Dictionary = _device_info(n)
		if info.is_empty():
			continue
		var st: StringName = info["state"]
		if st == &"done" or st == &"idle":
			_device_seen.erase(id)
			continue
		var dur: float = maxf(float(info["duration"]), 0.01)
		var p: float = float(info["progress"])
		if not Net.is_authority():
			var seen: Array = _device_seen.get(id, [])
			if seen.is_empty() or not is_equal_approx(float(seen[0]), p) or StringName(seen[2]) != st:
				_device_seen[id] = [p, now, st]
			elif st == &"running":
				p = minf(p + (now - float(seen[1])) / dur, 0.999)
		var anchor: Node3D = info["anchor"]
		var outward: Vector3 = anchor.global_basis.z.normalized() * float(info["out"]) * device_panel_out_m
		out.append({
			"net_id": id, "kind": StringName(info["kind"]),
			"world_pos": anchor.global_position + Vector3.UP * device_panel_up_m + outward,
			"auto_restart_in_s": snappedf(float(info["restart_in"]), 0.1),
			"progress": snappedf(p, 0.001), "time_left_s": snappedf(maxf(1.0 - p, 0.0) * dur, 0.1), "duration_s": dur,
			"state": st, "fix_prompt_key": StringName(info["fix_key"]) if st == &"jammed" else &"",
		})
		for oid: StringName in _marker_nodes:
			if _serves(_marker_nodes[oid], n, info["target"]):
				obj_dev[oid] = id
	_objective_device = obj_dev
	_assign(&"devices", out)


## {kind, state, progress, duration, anchor, target, fix_key, restart_in, out} of a timed device node ({} = none).
## kinds: drill / thermal / saw (DeviceRunner), hack (HackTerminal), c4 / time_lock (Safe timers), c4 (Padlock).
static func _device_info(n: Node) -> Dictionary:
	var ht: HackTerminal = n as HackTerminal
	if ht != null:
		var hs: StringName = [&"idle", &"running", &"jammed", &"done"][int(ht.state)]
		if hs == &"running" and ht.is_paused():
			hs = &"paused"
		var hd: float = ht.duration if ht.duration > 0.0 else ht.effective_duration()
		return {"kind": &"hack", "state": hs, "progress": ht.progress, "duration": hd, "anchor": ht, "target": null,
			"fix_key": &"ui.prompt.restart_hack", "restart_in": -1.0, "out": 0.0}
	var safe: Safe = n as Safe
	if safe != null and safe.timer_left >= 0.0 and safe.stage in [Safe.Stage.C4_ARMED, Safe.Stage.TIME_LOCK_RUNNING]:
		var c4: bool = safe.stage == Safe.Stage.C4_ARMED
		var total: float = maxf(Tweak.interaction().c4_fuse_s if c4 else safe.time_lock_s, 0.01)
		return {"kind": &"c4" if c4 else &"time_lock", "state": &"running", "progress": 1.0 - safe.timer_left / total,
			"duration": total, "anchor": safe, "target": safe, "fix_key": &"", "restart_in": -1.0, "out": -1.0}
	var pl: Padlock = n as Padlock
	if pl != null and pl.c4_armed():  # D-138.2: a C4 charge on a padlock
		var fuse: float = maxf(Tweak.interaction().c4_fuse_s, 0.01)
		return {"kind": &"c4", "state": &"running", "progress": 1.0 - pl.timer_left / fuse, "duration": fuse,
			"anchor": pl, "target": null, "fix_key": &"", "restart_in": -1.0, "out": 1.0}
	var r: Variant = n.get(&"runner")
	if not (r is DeviceRunner):
		return {}
	var dr: DeviceRunner = r as DeviceRunner
	if safe != null and safe._device_point != null:
		return {}  # PO6-01: the shared runner is listed once, under its drill point
	var kind: StringName = dr.kind
	var dp: DrillPoint = n as DrillPoint
	var anchor: Node3D = n as Node3D
	var target: Node = n if safe != null else null
	if dp != null:
		kind = dp.device_kind()
		if dp.device_node != null and is_instance_valid(dp.device_node):
			anchor = dp.device_node
		target = dp.get_node_or_null(dp.target) if not dp.target.is_empty() else null
	var ds: StringName = [&"idle", &"running", &"jammed", &"done"][int(dr.state)]
	# Out of the lock face: a DrillPoint's -Z points into the lock, a Safe's door faces -Z.
	return {"kind": kind, "state": ds, "progress": dr.progress, "duration": dr.duration, "anchor": anchor,
		"target": target, "fix_key": &"ui.prompt.fix_drill", "out": 1.0 if dp != null else -1.0,
		"restart_in": dr.restart_left if dr.state == DeviceRunner.State.JAMMED and dr.restart_left >= 0.0 else -1.0}


## True when an objective's marker nodes are the device, its target, or within 2 m of the device.
static func _serves(markers: Array, device: Node3D, target: Variant) -> bool:
	for v: Variant in markers:
		if not is_instance_valid(v):
			continue
		var m: Node3D = v as Node3D
		if m == device or (target != null and is_instance_valid(target) and m == target):
			return true
		if m.is_inside_tree() and m.global_position.distance_to(device.global_position) <= 2.0:
			return true
	return false


func _on_device_started(device_net_id: int, _kind: StringName, _duration: float) -> void:
	_device_ids[device_net_id] = true


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
	if _captain_present:
		out.append(WARNING_CAPTAIN)
	_assign(&"warnings", out)


## PP-A-1: the guard nearest the aim line inside his S5.8 window, in D-079 range and cone (no LOS test:
## presentation only, the server decides).
func _poll_dominate(c: CrewController) -> void:
	var best: NpcBase = null
	var best_left: float = 0.0
	if c != null and c.is_inside_tree() and _runtime != null and Modifiers.flag(c.slot, &"stealth.can_dominate_guards"):
		var eye: Vector3 = c.eye_position()
		var aim: Vector3 = c.aim_direction()
		var range_m: float = ShoutSystem.guard_dominate_range_for(c)
		var best_ang: float = INF
		for n: Node in _runtime.npcs(&"guard"):
			var npc: NpcBase = n as NpcBase
			var gb: GuardBrain = npc.get_node_or_null(^"Brain") as GuardBrain if npc != null else null
			if gb == null or not npc.alive or gb.dominate_window_left <= 0.0:
				continue
			var to: Vector3 = npc.global_position + Vector3(0.0, 1.2, 0.0) - eye
			var ang: float = aim.angle_to(to)
			if to.length() > range_m or ang > deg_to_rad(ShoutSystem.guard_dominate_cone_half_deg(to.length())) \
					or ang >= best_ang:
				continue
			best = npc
			best_ang = ang
			best_left = gb.dominate_window_left
	_assign(&"dominate_target", best.net_id if best != null else 0)
	_assign(&"dominate_window_s", snappedf(best_left, 0.1))


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
				"carried_loot_id": bag, "mode": c.player_mode,
				# B (teammate badges): seconds of bleedout left (-1 = not bleeding out); revive 0..1 (-1 = none)
				"bleedout_s": _bleed_of(hp), "revive_progress": _revive_of(c).x,
			})
	_assign(&"crew", list)


static func _bleed_of(hp: Object) -> float:
	var b: float = float(_read(hp, &"bleedout_left", -1.0))
	return b if b > 0.0 else -1.0


## (progress 0..1, reviver slot) of the revive someone holds on `c` (its ReviveInteractable), else (-1, -1).
## Uses InteractionSystem.session(), which is replicated to clients (A3-07).
func _revive_of(c: CrewController) -> Vector2:
	if c == null or _runtime == null or _runtime.interaction == null:
		return Vector2(-1.0, -1.0)
	var rev: Node = c.get_node_or_null(^"ReviveInteractable")
	if rev == null:
		return Vector2(-1.0, -1.0)
	for m: CrewController in _runtime.crew_members():
		if m == c:
			continue
		var sess: Dictionary = _runtime.interaction.session(m.slot)
		if not sess.is_empty() and sess.get("comp") == rev:
			return Vector2(_runtime.interaction.progress(m.slot), float(m.slot))
	return Vector2(-1.0, -1.0)


func _poll_crew_stats() -> void:
	var list: Array[Dictionary] = []
	var st: CrewStatsService = _runtime.stats if _runtime != null else null
	if st != null:
		for c: CrewController in _runtime.crew_members():
			var row: Dictionary = {"slot": c.slot, "name": c.display_name, "is_ai": c.is_ai, "is_local": c.is_local()}
			for k: StringName in CrewStatsService.COUNTERS:
				row[String(k)] = st.value(c.slot, k)
			list.append(row)
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["slot"]) < int(b["slot"]))
	_assign(&"crew_stats", list)


## ui_hud v1.3: Commander Brandt from HeistNetSync.captain_state() (server: the director's
## AegisCaptain; client: the replicated value). captain_arrived/retreated [R] also set presence, so a
## client is never behind the warning. No runtime: absent.
func _poll_captain() -> void:
	var st: Dictionary = {}
	if _runtime != null and _runtime.net_sync != null:
		st = _runtime.net_sync.captain_state()
	var present: bool = _captain_present or bool(st.get("present", false))
	_assign(&"captain_present", present)
	_assign(&"captain_resistance", clampf(float(st.get("resistance", 0.0)), 0.0, 1.0) if present else 0.0)


## ui_hud v1.2: custody of the tracked slot from the CustodySystem service (server). Without the
## service (clients, no runtime) a crew member in CUSTODY state reports in_custody with unknown (-1)
## timers until custody timers are replicated.
func _poll_custody(c: CrewController, slot: int) -> void:
	var out: Dictionary = {}
	var svc: Object = _service(CustodySystem.SERVICE)
	if svc != null and slot >= 0 and svc.has_method(&"in_custody") and bool(svc.call(&"in_custody", slot)):
		var hostage_id: int = 0
		var h: Object = svc.call(&"highlighted_hostage") as Object if svc.has_method(&"highlighted_hostage") else null
		if h != null and is_instance_valid(h):
			hostage_id = int(_read(h, &"net_id", 0))
		out = {
			"in_custody": true,
			"negotiation_left_s": float(_read_slot(svc, &"negotiation_left", slot, -1.0)),
			"auto_release_left_s": float(_read_slot(svc, &"auto_release_left", slot, -1.0)),
			"highlighted_hostage_net_id": hostage_id,
		}
	elif c != null and c.crew_state == Enums.CrewState.CUSTODY:
		out = {
			"in_custody": true, "negotiation_left_s": -1.0, "auto_release_left_s": -1.0,
			"highlighted_hostage_net_id": 0,
		}
	_assign(&"custody", out)


# --- Pagers / ECM / client detection -----------------------------------------------

func _tick_timers(delta: float) -> void:
	for pid: int in _pagers:
		var e: Dictionary = _pagers[pid]
		if bool(e.get("answering", false)):
			e["progress"] = minf(float(e.get("progress", 0.0)) + delta / maxf(float(e.get("answer_s", 1.0)), 0.001), 1.0)
		else:  # PO6-08 (D-114 §4): the window is frozen while answering
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
	# PO6-20: where the body lies (PagerSystem: its hips; dragged bodies move) for B's waypoint, pager_marker_up_m
	# above it; without a server row (event fallback) the body's root.
	var gid: int = int(e.get("guard_net_id", 0))
	var pos: Vector3 = Vector3(e.get("world_pos", Vector3.ZERO))
	var body: Node3D = Ids.lookup(gid) as Node3D if gid != 0 and pos == Vector3.ZERO else null
	if body != null and body.is_inside_tree():
		pos = body.global_position
	return {"pager_id": int(e.get("pager_id", 0)), "time_left_s": left, "answering": answering, "progress": prog,
		"guard_net_id": gid, "world_pos": pos + Vector3.UP * pager_marker_up_m}


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
	var row: Dictionary = {
		"observer_net_id": oid, "world_pos": pos as Vector3,
		"value": clampf(float(e.get("value", 0.0)), 0.0, 1.0), "kind": int(e.get("kind", 0)),
	}
	var state: StringName = StringName(e.get("state", &""))
	if state != &"":
		row["state"] = state  # ui_hud v1.17 (D-128): &"curious" / &"investigating"; absent = meter only
	return row


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
	e["answering"] = true  # PO6-08: time_left (the window) stays frozen; the answer fills `progress`
	e["time_left"] = float(e.get("time_left", Tweak.stealth().pager_window_s))
	e["answer_s"] = Tweak.stealth().pager_answer_s * Modifiers.mult(crew_slot, &"stealth.pager_answer_speed_mult")
	e["progress"] = 0.0
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


## Client (PO-B-C7): seed the replicated objectives from the bring-up (HeistNetSync.objectives_state),
## then later objective_updated facts update them.
func seed_objectives(list: Array) -> void:
	for e: Variant in list:
		var a: Array = e as Array
		if a != null and a.size() == 3:
			_on_objective_updated(StringName(a[0]), int(a[1]), a[2] as Dictionary)


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


func _on_captain_arrived(_npc_net_id: int) -> void:
	_captain_present = true


func _on_captain_retreated(_npc_net_id: int) -> void:
	_captain_present = false


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
func _rt_service(c: Node, service_name: StringName) -> Node:
	var rt: HeistRuntime = HeistRuntime.of(c) if c != null else null
	return rt.service(service_name) if rt != null else null


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
		if s == &"objective_markers_changed":
			objective_markers_changed.emit(objective_markers)
		else:
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
