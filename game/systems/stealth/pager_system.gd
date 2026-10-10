## Pager service (G.SVC_PAGERS, child of HeistRuntime). Owner: ENV A. Rows S5.2-S5.5.
##
## PUBLIC API:
##   start_pager(guard) -> int          -> schedule a pager for a guard killed/dominated in stealth
##   on_guard_dominated(guard)          -> hook for domination (also driven by npc_alert_state_changed)
##   blocks_body(guard) -> bool         -> a pager is pending/beeping on this guard (no bagging)
##   pager_entries() -> Array[Dictionary] {pager_id, guard_net_id, time_left, answering, world_pos}
##   answered_total / max_answers       -> S5.3 team-wide count and cap
##   set_answered_total(n)              -> test hook
## Flow (server): guard dies (or is dominated) while StealthDirector.is_stealth() -> after
## rand(pager_delay_min_s, pager_delay_max_s) on GameRng &"pagers" the pager beeps: pager_started
## [R] + a `PagerInteractable` on the guard (kind &"answer_pager", priority 10, allow_multiple).
## Nobody starts answering within pager_window_s -> pager_failed(&"timeout") + alarm. The set of
## current answerers becoming empty before completion -> pager_failed(&"released") + alarm (S5.4).
## The first completion counts: pager_answered(pager_id, slot, total) [R]; other holders are
## cancelled without alarm. total == max_answers -> Mercer line; total > max_answers -> the
## completed answer raises alarm_raised(&"pager_limit") (S5.3). No pagers once loud: pending and
## beeping pagers are cancelled with pager_failed(&"cancelled") (no alarm, it already sounded).
class_name PagerSystem
extends Node

enum State { PENDING, ACTIVE, DONE }

const COMP_NAME: String = "PagerInteractable"
## Variant scalar a heist may define to change the cap (S5.3).
const MAX_ANSWERS_SCALAR: StringName = &"pager_max_answers"

var max_answers: int = 4
var answered_total: int = 0

var _runtime: HeistRuntime = null
var _tw: StealthTweak = null
var _next_id: int = 1
## pager_id -> {id, guard (NpcBase), guard_net_id, state, delay, time_left, comp, holders}
var _pagers: Dictionary[int, Dictionary] = {}
## Guard instance ids that already had a pager.
var _paged: Dictionary[int, bool] = {}


func _ready() -> void:
	_tw = Tweak.stealth()
	max_answers = _tw.pager_max_answers
	_runtime = HeistRuntime.of(self)
	if _runtime != null:
		var v: Variant = _runtime.variants.get(MAX_ANSWERS_SCALAR)
		if v is int or v is float:
			max_answers = int(v)
		_runtime.phase_changed.connect(_on_phase_changed)
	EventBus.npc_killed.connect(_on_npc_killed)
	EventBus.npc_alert_state_changed.connect(_on_alert_state_changed)


func _exit_tree() -> void:
	if EventBus.npc_killed.is_connected(_on_npc_killed):
		EventBus.npc_killed.disconnect(_on_npc_killed)
	if EventBus.npc_alert_state_changed.is_connected(_on_alert_state_changed):
		EventBus.npc_alert_state_changed.disconnect(_on_alert_state_changed)


## Server: schedule a pager on `guard`. Returns the pager id (0 if none: loud, not a guard, repeat).
func start_pager(guard: NpcBase) -> int:
	if not Net.is_authority() or guard == null or guard.role != &"guard" or not _is_stealth():
		return 0
	var iid: int = guard.get_instance_id()
	if _paged.has(iid):
		return 0
	_paged[iid] = true
	var pid: int = _next_id
	_next_id += 1
	var rng: RandomNumberGenerator = GameRng.stream(&"pagers")
	_pagers[pid] = {
		"id": pid, "guard": guard, "guard_net_id": guard.net_id, "state": State.PENDING,
		"delay": rng.randf_range(_tw.pager_delay_min_s, _tw.pager_delay_max_s),
		"time_left": _tw.pager_window_s, "comp": null, "holders": {},
	}
	return pid


## Domination hook (S5.2: dominating a guard also triggers his pager).
func on_guard_dominated(guard: NpcBase) -> int:
	return start_pager(guard)


## True while a pager is pending or beeping on `guard` (body bagging is blocked).
func blocks_body(guard: Node) -> bool:
	for pid: int in _pagers:
		if _pagers[pid]["guard"] == guard and int(_pagers[pid]["state"]) != State.DONE:
			return true
	return false


## Beeping pagers for the HUD (LocalHudModel): time_left = start window, or the answer time left.
func pager_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array[int] = []
	ids.assign(_pagers.keys())
	ids.sort()
	for pid: int in ids:
		var p: Dictionary = _pagers[pid]
		if int(p["state"]) != State.ACTIVE:
			continue
		var guard: Node3D = p["guard"] as Node3D
		var holders: Dictionary = p["holders"]
		var left: float = float(p["time_left"])
		if not holders.is_empty():
			left = _answer_time_left(p)
		out.append({
			"pager_id": pid, "guard_net_id": int(p["guard_net_id"]), "time_left": left,
			"answering": not holders.is_empty(),
			"world_pos": guard.global_position if is_instance_valid(guard) and guard.is_inside_tree() else Vector3.ZERO,
		})
	return out


## Pager state (State) or -1 when unknown / resolved.
func pager_state(pager_id: int) -> int:
	return int(_pagers[pager_id]["state"]) if _pagers.has(pager_id) else -1


## Test hook: set the team-wide answered count.
func set_answered_total(n: int) -> void:
	answered_total = n


func _physics_process(delta: float) -> void:
	if not Net.is_authority() or _pagers.is_empty():
		return
	var ids: Array[int] = []
	ids.assign(_pagers.keys())
	for pid: int in ids:
		if not _pagers.has(pid):
			continue
		var p: Dictionary = _pagers[pid]
		if not is_instance_valid(p["guard"]):
			_remove(pid)
			continue
		match int(p["state"]):
			State.PENDING:
				p["delay"] = float(p["delay"]) - delta
				if float(p["delay"]) <= 0.0:
					if _is_stealth():
						_activate(pid)
					else:
						_cancel(pid)
			State.ACTIVE:
				if (p["holders"] as Dictionary).is_empty():
					p["time_left"] = float(p["time_left"]) - delta
					if float(p["time_left"]) <= 0.0:
						_fail(pid, &"timeout")


func _activate(pid: int) -> void:
	var p: Dictionary = _pagers[pid]
	var guard: NpcBase = p["guard"] as NpcBase
	var comp: InteractableComponent = InteractableComponent.new()
	comp.name = COMP_NAME
	comp.kind = &"answer_pager"
	comp.priority = 10
	comp.allow_multiple = true
	comp.interaction_time_s = _tw.pager_answer_s
	comp.speed_modifier_key = &"stealth.pager_answer_speed_mult"
	comp.casing_allowed = false
	comp.prompt_key = &"ui.prompt.answer_pager"
	comp.position = Vector3(0.0, 0.5, 0.0)
	guard.add_child(comp)
	comp.started.connect(_on_answer_started.bind(pid))
	comp.cancelled.connect(_on_answer_cancelled.bind(pid))
	comp.completed.connect(_on_answer_completed.bind(pid))
	p["comp"] = comp
	p["state"] = State.ACTIVE
	p["time_left"] = _tw.pager_window_s
	_emit(&"pager_started", [pid, int(p["guard_net_id"])])
	_emit(&"audio_cue_requested", [&"cue.pager_beep", guard.global_position, int(p["guard_net_id"])])


func _on_answer_started(crew: Node, pid: int) -> void:
	if not _pagers.has(pid) or int(_pagers[pid]["state"]) != State.ACTIVE:
		return
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	(_pagers[pid]["holders"] as Dictionary)[slot] = true
	_emit(&"pager_answer_started", [pid, slot])
	var g: Node3D = _pagers[pid]["guard"] as Node3D
	_emit(&"audio_cue_requested", [&"cue.pager_radio", g.global_position, int(_pagers[pid]["guard_net_id"])])


func _on_answer_cancelled(crew: Node, pid: int) -> void:
	if not _pagers.has(pid) or int(_pagers[pid]["state"]) != State.ACTIVE:
		return
	var holders: Dictionary = _pagers[pid]["holders"]
	holders.erase(int(crew.get(&"slot")) if crew != null else -1)
	if holders.is_empty():
		_fail(pid, &"released")  # S5.4


func _on_answer_completed(crew: Node, pid: int) -> void:
	if not _pagers.has(pid) or int(_pagers[pid]["state"]) != State.ACTIVE:
		return
	var p: Dictionary = _pagers[pid]
	p["state"] = State.DONE
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	answered_total += 1
	var total: int = answered_total
	var guard_id: int = int(p["guard_net_id"])
	_remove(pid)
	_emit(&"pager_answered", [pid, slot, total])
	if total == max_answers:
		_emit(&"voice_line_requested", [&"mercer", &"vo.mercer.pager_last", {}])
	if total > max_answers:
		_raise_alarm(&"pager_limit", guard_id)  # S5.3: the extra answer completes, then alarm


func _fail(pid: int, reason: StringName) -> void:
	var guard_id: int = int(_pagers[pid]["guard_net_id"])
	_pagers[pid]["state"] = State.DONE
	_remove(pid)
	_emit(&"pager_failed", [pid, reason])
	_raise_alarm(&"pager_failed", guard_id)


func _cancel(pid: int) -> void:
	_pagers[pid]["state"] = State.DONE
	_remove(pid)
	_emit(&"pager_failed", [pid, &"cancelled"])


## Drop the pager: cancel remaining holders (state is DONE, so no alarm) and remove the component.
func _remove(pid: int) -> void:
	var p: Dictionary = _pagers[pid]
	p["state"] = State.DONE
	var comp: InteractableComponent = p["comp"] as InteractableComponent
	if comp != null and is_instance_valid(comp):
		comp.enabled = false
		if _runtime != null and _runtime.interaction != null:
			_runtime.interaction.cancel_all_on(comp)
		comp.queue_free()
	_pagers.erase(pid)


func _answer_time_left(p: Dictionary) -> float:
	var comp: InteractableComponent = p["comp"] as InteractableComponent
	if comp == null or _runtime == null or _runtime.interaction == null:
		return float(p["time_left"])
	var best: float = INF
	for slot: int in _runtime.interaction.holders_of(comp):
		var s: Dictionary = _runtime.interaction.session(slot)
		best = minf(best, maxf(float(s.get("duration", 0.0)) - float(s.get("progress", 0.0)), 0.0))
	return best if best != INF else float(p["time_left"])


func _on_npc_killed(npc_id: int, _killer_id: int, _info: Dictionary) -> void:
	var npc: NpcBase = Ids.lookup(npc_id) as NpcBase
	if npc != null and (_runtime == null or _runtime.is_ancestor_of(npc)):
		start_pager(npc)


func _on_alert_state_changed(npc_id: int, _old_state: int, new_state: int) -> void:
	if new_state != Enums.AlertState.DOMINATED:
		return
	var npc: NpcBase = Ids.lookup(npc_id) as NpcBase
	if npc != null and (_runtime == null or _runtime.is_ancestor_of(npc)):
		on_guard_dominated(npc)


func _on_phase_changed(_old_phase: int, _new_phase: int) -> void:
	if _is_stealth():
		return
	var ids: Array[int] = []
	ids.assign(_pagers.keys())
	for pid: int in ids:
		if _pagers.has(pid):
			_cancel(pid)


func _is_stealth() -> bool:
	var st: StealthDirector = _stealth()
	if st != null:
		return st.is_stealth()
	return _runtime != null and not _runtime.went_loud \
		and (_runtime.phase == Enums.HeistPhase.CASING or _runtime.phase == Enums.HeistPhase.STEALTH)


func _stealth() -> StealthDirector:
	if _runtime != null:
		return _runtime.service(G.SVC_STEALTH) as StealthDirector
	return HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector


func _raise_alarm(reason: StringName, source_net_id: int) -> void:
	var st: StealthDirector = _stealth()
	if st != null:
		st.raise_alarm(reason, source_net_id)


func _emit(sig: StringName, args: Array) -> void:
	EventBus.emit_signal.callv([sig] + args)
	Net.replicate_event(sig, args)
