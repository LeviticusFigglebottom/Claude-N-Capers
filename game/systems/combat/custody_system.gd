## Custody, auto-release, hostage trades and the all-custody fail (A3-04). Owner: ENV A. Server only.
## Runtime service SERVICE (HeistRuntime._create_services). Rows:
## - L2.9 custody: on crew_custody the slot gets an entry. Routine/Tense: auto-release after
##   CustodyTweak.auto_release_s[difficulty] (119 s); Hazardous+: trade only. A released crew member
##   is back at full health (downs reset, CrewHealth.release_from_custody), with release_ammo_frac of
##   every weapon's full ammo and no deployables refilled, behind the nearest free crew member (humans
##   first) or at the first PLAYER SpawnPoint.
## - L2.10 / S7.3 trade: negotiation trade_base_s + trade_per_civilian_kill_s x civilians that slot
##   killed this heist. L1.6: the countdown pauses during trade_locked_phases (ANTICIPATION..SUSTAIN).
##   When a slot's negotiation is over, one hostage (G.HOSTAGE: tied civilians / tied cops, or a
##   SURRENDERED cop; lowest net_id first) is highlighted (`highlighted_hostage()`, HUD) and gets an
##   enabled `TradeInteractable` (kind &"trade_hostage"). Completing it trades the oldest trade-ready
##   slot: the hostage leaves play, crew_traded(slot, hostage_net_id) [R], the slot is released.
##   L2.9 solo with AI / L6.3: when no human is free and a free (NORMAL) AI teammate exists, the
##   trade happens automatically. AI teammates in custody are traded like humans.
## - L2.9 fail (conservative, lead ruling): every crew member (humans and AI) in custody, or on a
##   trade-only difficulty (Hazardous+) every human in custody with no free AI teammate, held for
##   all_custody_fail_delay_s -> HeistRuntime.end_heist(false, [], &"all_custody") (events.md D-038).
##   Routine/Tense custody alone never fails while anyone is free (119 s auto-release).
class_name CustodySystem
extends Node

signal trade_ready(slot: int)
## A crew member left custody (hostage_net_id 0 = auto-release).
signal released(slot: int, hostage_net_id: int)

const SERVICE: StringName = &"custody"
const TRADE_NAME: String = "TradeInteractable"

var _runtime: HeistRuntime = null
## slot -> { "auto_left": float (< 0 = trade only), "negotiation_left": float, "order": int,
##           "announced": bool }
var _entries: Dictionary[int, Dictionary] = {}
## slot -> civilians killed this heist (S7.3).
var _civ_kills: Dictionary[int, int] = {}
var _order: int = 0
var _fail_hold: float = 0.0
var _highlight: NpcBase = null


## The runtime's CustodySystem (null when the runtime has none).
static func of(rt: HeistRuntime) -> CustodySystem:
	return rt.service(SERVICE) as CustodySystem if rt != null else null


func _ready() -> void:
	_runtime = HeistRuntime.of(self)
	EventBus.crew_custody.connect(_on_crew_custody)
	EventBus.civilian_killed.connect(_on_civilian_killed)


func _exit_tree() -> void:
	for pair: Array in [[EventBus.crew_custody, _on_crew_custody], [EventBus.civilian_killed, _on_civilian_killed]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


# --- Queries (HUD, tests) ------------------------------------------------------------------------

func in_custody(slot: int) -> bool:
	return _entries.has(slot)


## Seconds of negotiation left for `slot` (0 = trade ready, -1 = not in custody).
func negotiation_left(slot: int) -> float:
	return maxf(float(_entries[slot]["negotiation_left"]), 0.0) if _entries.has(slot) else -1.0


## Seconds until `slot` is auto-released (-1 = trade only or not in custody).
func auto_release_left(slot: int) -> float:
	return maxf(float(_entries[slot]["auto_left"]), 0.0) if _entries.has(slot) and float(_entries[slot]["auto_left"]) >= 0.0 else -1.0


func is_trade_ready(slot: int) -> bool:
	return _entries.has(slot) and float(_entries[slot]["negotiation_left"]) <= 0.0


## The oldest trade-ready slot in custody, or -1.
func ready_slot() -> int:
	var best: int = -1
	var best_order: int = 1 << 30
	for slot: int in _entries:
		if is_trade_ready(slot) and int(_entries[slot]["order"]) < best_order:
			best = slot
			best_order = int(_entries[slot]["order"])
	return best


## L2.10: the hostage highlighted for the next trade (HUD outline), or null.
func highlighted_hostage() -> NpcBase:
	return _highlight if _highlight != null and is_instance_valid(_highlight) else null


## S7.3 + L2.10: negotiation length for `slot` right now.
func trade_time_for(slot: int) -> float:
	var tw: CustodyTweak = CustodyTweak.data()
	return tw.trade_base_s + tw.trade_per_civilian_kill_s * float(_civ_kills.get(slot, 0))


func civilians_killed(slot: int) -> int:
	return _civ_kills.get(slot, 0)


## L1.6: negotiation is paused in the locked assault phases.
func is_negotiation_locked() -> bool:
	var dir: AssaultDirector = _runtime.service(G.SVC_DIRECTOR) as AssaultDirector if _runtime != null else null
	return dir != null and CustodyTweak.data().trade_locked_phases.has(int(dir.assault_phase))


## Hostages a trade can use: tied civilians/cops (G.HOSTAGE) and surrendered cops, by net_id.
func hostage_candidates() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	if _runtime == null or not is_inside_tree():
		return out
	for n: Node in get_tree().get_nodes_in_group(G.HOSTAGE):
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.alive and _runtime.is_ancestor_of(npc) and not out.has(npc):
			out.append(npc)
	for n: Node in _runtime.npcs(&"police"):
		var cop: NpcBase = n as NpcBase
		var s: PoliceSurrender = PoliceSurrender.of(cop)
		if s != null and s.is_surrendered() and not out.has(cop):
			out.append(cop)
	out.sort_custom(func(a: NpcBase, b: NpcBase) -> bool: return a.net_id < b.net_id)
	return out


# --- Tick -------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Net.is_authority() and _runtime != null and _runtime.phase != Enums.HeistPhase.ENDED:
		tick(delta)


## Server: advance timers by `delta` (tests may call it with large steps).
func tick(delta: float) -> void:
	if _runtime == null or not Net.is_authority():
		return
	var locked: bool = is_negotiation_locked()
	var slots: Array[int] = []
	slots.assign(_entries.keys())
	for slot: int in slots:
		var c: CrewController = _runtime.crew_controller(slot) as CrewController
		if c == null or c.crew_state != Enums.CrewState.CUSTODY:
			_entries.erase(slot)  # released elsewhere
			continue
		var e: Dictionary = _entries[slot]
		if float(e["auto_left"]) >= 0.0:
			e["auto_left"] = float(e["auto_left"]) - delta
			if float(e["auto_left"]) <= 0.0:
				release(slot, 0)
				continue
		if not locked:
			e["negotiation_left"] = float(e["negotiation_left"]) - delta
		if float(e["negotiation_left"]) <= 0.0 and not bool(e["announced"]):
			e["announced"] = true
			trade_ready.emit(slot)
	_update_highlight()
	_auto_trade()
	_check_fail(delta)


func _update_highlight() -> void:
	var want: NpcBase = null
	if ready_slot() >= 0:
		var cands: Array[NpcBase] = hostage_candidates()
		var cur: NpcBase = highlighted_hostage()
		want = cur if cur != null and cands.has(cur) else (cands[0] if not cands.is_empty() else null)
	if want == highlighted_hostage():
		return
	_set_trade_enabled(highlighted_hostage(), false)
	_highlight = want
	_set_trade_enabled(want, true)


func _auto_trade() -> void:
	var slot: int = ready_slot()
	var h: NpcBase = highlighted_hostage()
	if slot < 0 or h == null or _free_human_exists() or not _free_ai_exists():
		return
	trade(slot, h)


func _check_fail(delta: float) -> void:
	if not _should_fail():
		_fail_hold = 0.0
		return
	_fail_hold += delta
	if _fail_hold >= CustodyTweak.data().all_custody_fail_delay_s:
		Log.info(&"combat", "all humans in custody, no release path: heist failed")
		_runtime.end_heist(false, [] as Array[int], HeistRuntime.FAIL_ALL_CUSTODY)


## L2.9 fail rule (conservative, lead ruling): every crew member (humans and AI teammates) is in
## custody, or, on a trade-only difficulty (no auto-release), every human is in custody and no AI
## teammate is free.
func _should_fail() -> bool:
	var humans: int = 0
	var humans_free: int = 0
	var ai_free: int = 0
	var total: int = 0
	var in_custody: int = 0
	for c: CrewController in _runtime.crew_members():
		total += 1
		var held: bool = c.crew_state == Enums.CrewState.CUSTODY
		if held:
			in_custody += 1
		if c.is_ai:
			if not held:
				ai_free += 1
		else:
			humans += 1
			if not held:
				humans_free += 1
	if humans == 0:
		return false
	if in_custody == total:
		return true
	var trade_only: bool = CustodyTweak.data().auto_release_for(_runtime.difficulty) < 0.0
	return trade_only and humans_free == 0 and ai_free == 0


func _free_human_exists() -> bool:
	for c: CrewController in _runtime.crew_members():
		if not c.is_ai and c.crew_state != Enums.CrewState.CUSTODY:
			return true
	return false


func _free_ai_exists() -> bool:
	for c: CrewController in _runtime.crew_members():
		if c.is_ai and c.crew_state == Enums.CrewState.NORMAL:
			return true
	return false


# --- Trade / release ---------------------------------------------------------------------------------

## Server: trade `hostage` for crew `slot` (must be trade-ready). Returns true on success.
func trade(slot: int, hostage: NpcBase) -> bool:
	if not Net.is_authority() or not is_trade_ready(slot) or hostage == null or not is_instance_valid(hostage):
		return false
	if not hostage_candidates().has(hostage):
		return false
	var hid: int = hostage.net_id
	_set_trade_enabled(hostage, false)
	if _highlight == hostage:
		_highlight = null
	_remove_hostage(hostage)
	EventBus.crew_traded.emit(slot, hid)
	Net.replicate_event(&"crew_traded", [slot, hid])
	Log.info(&"combat", "slot %d traded for hostage %d" % [slot, hid])
	release(slot, hid)
	return true


## Server: bring `slot` back from custody (L2.9 release rules). `hostage_net_id` 0 = auto-release.
func release(slot: int, hostage_net_id: int = 0) -> void:
	var c: CrewController = _runtime.crew_controller(slot) as CrewController if _runtime != null else null
	_entries.erase(slot)
	if c == null or c.health == null or c.crew_state != Enums.CrewState.CUSTODY:
		return
	c.health.release_from_custody()
	_set_release_ammo(c)
	c.teleport(_release_transform(c))
	released.emit(slot, hostage_net_id)
	Log.info(&"combat", "slot %d released from custody (hostage %d)" % [slot, hostage_net_id])


func _set_release_ammo(c: CrewController) -> void:
	var w: CrewWeapons = c.weapons
	if w == null:
		return
	w.set_loadout(c.loadout)  # full magazines + reserves; deployables untouched (L2.9)
	var frac: float = CustodyTweak.data().release_ammo_frac
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if not w.has_weapon(ws):
			continue
		var total: int = int(round(float(w.mag(ws) + w.reserve(ws)) * frac))
		var m: int = mini(w.mag_size(ws), total)
		w.set_ammo(ws, m, total - m)


func _release_transform(c: CrewController) -> Transform3D:
	var best: CrewController = null
	for other: CrewController in _runtime.crew_members():
		if other == c or other.crew_state == Enums.CrewState.CUSTODY:
			continue
		if best == null or (best.is_ai and not other.is_ai):
			best = other
	if best != null:
		var back: Vector3 = -best.aim_direction()
		back.y = 0.0
		back = back.normalized() if back.length() > 0.01 else Vector3.BACK
		var pos: Vector3 = best.global_position + back * CustodyTweak.data().release_near_crew_offset_m
		return Transform3D(best.global_transform.basis, pos)
	if _runtime.map != null:
		var spawns: Array[Node] = _runtime.map.get_slots(G.PLAYER_SPAWN)
		if not spawns.is_empty():
			return (spawns[c.slot % spawns.size()] as Node3D).global_transform
	return c.global_transform


func _remove_hostage(h: NpcBase) -> void:
	var ps: PoliceSurrender = PoliceSurrender.of(h)
	if ps != null:
		ps.release_as_hostage()
	var brain: Node = h.get_node_or_null(^"Brain")
	if brain != null and brain.has_method(&"release_as_hostage"):
		brain.call(&"release_as_hostage")
	h.remove_from_group(G.HOSTAGE)
	if h.get_parent() != null:
		h.get_parent().remove_child(h)
	h.queue_free()
	var targets: CivilianTargets = CivilianTargets.ensure(_runtime)
	if targets != null:
		targets.recount_hostages()


func _set_trade_enabled(h: NpcBase, on: bool) -> void:
	if h == null or not is_instance_valid(h):
		return
	var comp: InteractableComponent = h.get_node_or_null(TRADE_NAME) as InteractableComponent
	if comp == null:
		if not on:
			return
		comp = InteractableComponent.new()
		comp.name = TRADE_NAME
		comp.kind = &"trade_hostage"
		comp.prompt_key = &"ui.prompt.trade_hostage"
		comp.interaction_time_s = CustodyTweak.data().trade_interaction_s
		comp.priority = 150
		comp.position = Vector3(0.0, 0.6, 0.0)
		comp.extra_check = _trade_check.bind(h)
		comp.completed.connect(_on_trade_completed.bind(h))
		h.add_child(comp)
	comp.enabled = on
	if not on and _runtime != null and _runtime.interaction != null:
		_runtime.interaction.cancel_all_on(comp)


func _trade_check(_crew: Node, h: NpcBase) -> StringName:
	if h != highlighted_hostage() or ready_slot() < 0:
		return InteractableComponent.BLOCK_STATE
	return InteractableComponent.BLOCK_NONE


func _on_trade_completed(_crew: Node, h: NpcBase) -> void:
	var slot: int = ready_slot()
	if slot >= 0:
		trade(slot, h)


# --- Events -------------------------------------------------------------------------------------------

func _on_crew_custody(slot: int) -> void:
	if not Net.is_authority() or _runtime == null or _entries.has(slot):
		return
	var c: CrewController = _runtime.crew_controller(slot) as CrewController
	if c == null or not _runtime.is_ancestor_of(c):
		return
	_entries[slot] = {
		"auto_left": CustodyTweak.data().auto_release_for(_runtime.difficulty),
		"negotiation_left": trade_time_for(slot), "order": _order, "announced": false,
	}
	_order += 1


func _on_civilian_killed(_npc_net_id: int, slot: int) -> void:
	if slot >= 0:
		_civ_kills[slot] = _civ_kills.get(slot, 0) + 1
