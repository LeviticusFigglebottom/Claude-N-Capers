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
## Nobody starts answering within pager_window_s -> pager_failed(&"timeout") + alarm.
## PO6-08 (D-114 §4 as amended, S5.2/S5.4): the window FREEZES the moment a player starts the answer hold
## and stays frozen while anyone holds it. When the set of answerers becomes empty before completion
## (release, look-away, going down, leaving) the pager waits StealthTweak.pager_juggle_window_s (frozen):
## if one of the released answerers starts answering ANOTHER live pager in that time (a juggle), or anyone
## picks this one up again, it resumes its remaining window; otherwise pager_failed(&"released") + alarm.
## StealthTweak.pager_release_resumes = true (opt-in, not the default) skips the alarm: the window resumes at once.
## Either resume (opt-in, or a juggled pager leaving its grace) emits pager_answer_released(pager_id, slot) [R]
## (events.md v1.4), on which CuePlayer swaps the radio loop back to the beep.
## Audio (D-114 §3): the looping cue.pager_beep / cue.pager_radio are owned by CuePlayer, keyed per
## pager on the pager_* facts (started -> beep, answer_started -> radio, answered/failed -> stop both).
## This service never requests a looping pager cue through audio_cue_requested (nobody could stop it).
## Clients: pager_entries() reads the server's rows mirrored through HeistNetSync (net_state()).
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
## Client mirror (PO6-08): rows from the server's net_state(), see _apply_remote().
var _remote_rows: Array[Dictionary] = []


func _ready() -> void:
	_tw = Tweak.stealth()
	_runtime = HeistRuntime.of(self)
	max_answers = cap_for(_runtime)
	if _runtime != null:
		_runtime.phase_changed.connect(_on_phase_changed)
	EventBus.npc_killed.connect(_on_npc_killed)
	EventBus.npc_alert_state_changed.connect(_on_alert_state_changed)


func _exit_tree() -> void:
	# PO6-08 / D-114 §3: teardown ends every live pager with a fact so CuePlayer stops its loops.
	var ids: Array[int] = []
	ids.assign(_pagers.keys())
	for pid: int in ids:
		if _pagers.has(pid):
			_cancel(pid)
	if EventBus.npc_killed.is_connected(_on_npc_killed):
		EventBus.npc_killed.disconnect(_on_npc_killed)
	if EventBus.npc_alert_state_changed.is_connected(_on_alert_state_changed):
		EventBus.npc_alert_state_changed.disconnect(_on_alert_state_changed)


## Server: schedule a pager on `guard`. Returns the pager id (0 if none: loud, not a guard, repeat).
func start_pager(guard: NpcBase) -> int:
	if not Net.is_authority() or guard == null or guard.role != &"guard" or not _is_stealth():
		return 0
	if guard.has_meta(StealthDirector.META_ALARM_REASON):
		_raise_alarm(&"npc_down", guard.net_id)  # QC-83 (d): a convoy unit down is the ambush, no pager to answer
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
		"ecm_hold": _ecm_pager_delay(),  # A2-03 (S5.6)
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


## Beeping pagers for the HUD (LocalHudModel): time_left = the response window left (frozen while
## answering, PO6-08), answer_left / progress (0..1) = the current answer hold (answering only).
func pager_entries() -> Array[Dictionary]:
	if not Net.is_authority():
		return _remote_entries()
	var out: Array[Dictionary] = []
	var ids: Array[int] = []
	ids.assign(_pagers.keys())
	ids.sort()
	for pid: int in ids:
		var p: Dictionary = _pagers[pid]
		if int(p["state"]) != State.ACTIVE:
			continue
		var guard: Node3D = p["guard"] as Node3D if is_instance_valid(p["guard"]) else null
		var holders: Dictionary = p["holders"]
		var answering: bool = not holders.is_empty()
		var answer: Vector2 = _answer_state(p) if answering else Vector2(0.0, 0.0)
		var where: Vector3 = guard.global_position if guard != null and guard.is_inside_tree() else Vector3.ZERO
		if is_instance_valid(p["comp"]) and (p["comp"] as Node3D).is_inside_tree():
			where = (p["comp"] as Node3D).global_position - Vector3.UP * _tw.pager_prompt_up_m  # PO6-20: the body
		out.append({
			"pager_id": pid, "guard_net_id": int(p["guard_net_id"]), "time_left": float(p["time_left"]),
			"answering": answering, "answer_left": answer.x, "progress": answer.y,
			"world_pos": where,
		})
	return out


## Pager state (State) or -1 when unknown / resolved.
func pager_state(pager_id: int) -> int:
	return int(_pagers[pager_id]["state"]) if _pagers.has(pager_id) else -1


## Test hook: set the team-wide answered count.
## S5.3 / D-130 / D-140 team pager cap of a run: the heist's HeistDef.pager_max_by_difficulty[difficulty] (Golden Hour
## 4/4/3/3/2/1), else StealthTweak.pager_max_answers; a rolled `pager_max_answers` variant scalar only lowers it.
static func cap_for(rt: HeistRuntime) -> int:
	var tw: StealthTweak = Tweak.stealth()
	if rt == null:
		return tw.pager_max_answers
	var cap: int = tw.pager_max_answers
	var def: HeistDef = rt.map.heist_def if rt.map != null else null
	if def != null and not def.pager_max_by_difficulty.is_empty():
		cap = def.pager_max_by_difficulty[clampi(rt.difficulty, 0, def.pager_max_by_difficulty.size() - 1)]
	# D-140: a rolled scalar may lower the per-difficulty cap, never raise it.
	var v: Variant = rt.variants.get(MAX_ANSWERS_SCALAR)
	if v is int or v is float:
		cap = mini(cap, int(v))
	return cap


## LocalHudModel reads these names (pagers_max / pagers_answered).
func pagers_max() -> int:
	return max_answers


func pagers_answered() -> int:
	return answered_total


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
		if not is_instance_valid(p["guard"]) or not (p["guard"] as Node).is_inside_tree():
			_cancel(pid)  # guard freed / despawned mid-pager: pager_failed(&"cancelled"), no alarm
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
				_reconcile_holders(pid, [] as Array[int])
				if not _pagers.has(pid):
					continue
				if is_instance_valid(p["comp"]):
					_follow_body(p, p["comp"] as InteractableComponent)
				if float(p.get("grace_left", -1.0)) >= 0.0:  # released early: juggle grace (frozen)
					p["grace_left"] = float(p["grace_left"]) - delta
					if float(p["grace_left"]) < 0.0:
						_fail(pid, &"released")  # S5.4: no juggle in time
					continue
				# PO6-08: frozen while anyone answers (S5.2 window), and while an ECM pauses it (S5.6).
				if (p["holders"] as Dictionary).is_empty() and not _ecm_paused(p):
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
	comp.aim_radius_m = _tw.pager_aim_radius_m  # PO6-20: answerable from anywhere around the body
	guard.add_child(comp)
	_follow_body(p, comp)
	comp.started.connect(_on_answer_started.bind(pid))
	comp.cancelled.connect(_on_answer_cancelled.bind(pid))
	comp.completed.connect(_on_answer_completed.bind(pid))
	p["comp"] = comp
	p["state"] = State.ACTIVE
	p["time_left"] = _tw.pager_window_s
	# D-114 §3: cue.pager_beep is a loop; CuePlayer starts it on pager_started and stops it on
	# answer_started / answered / failed. A loose audio_cue_requested here had no owner to stop it.
	_emit(&"pager_started", [pid, int(p["guard_net_id"])])


func _on_answer_started(crew: Node, pid: int) -> void:
	if not _pagers.has(pid) or int(_pagers[pid]["state"]) != State.ACTIVE:
		return
	# PO6-08 (D-114 §4): a holder freezes the window from this tick on (_physics_process skips it).
	var slot: int = int(crew.get(&"slot")) if is_instance_valid(crew) else -1
	(_pagers[pid]["holders"] as Dictionary)[slot] = true
	_pagers[pid]["grace_left"] = -1.0  # picked up again inside its grace
	# PO6-08 juggle: a pager this player just released resumes its window instead of alarming.
	for qid: int in _pagers:
		var q: Dictionary = _pagers[qid]
		if qid != pid and float(q.get("grace_left", -1.0)) >= 0.0 and (q.get("grace_slots", []) as Array).has(slot):
			q["grace_left"] = -1.0
			_emit(&"pager_answer_released", [qid, slot])  # juggled: q beeps again (CuePlayer radio -> beep)
	# CuePlayer swaps the beep loop for the cue.pager_radio loop on this fact (D-114 §3).
	_emit(&"pager_answer_started", [pid, slot])


func _on_answer_cancelled(crew: Node, pid: int) -> void:
	if not _pagers.has(pid) or int(_pagers[pid]["state"]) != State.ACTIVE:
		return
	var holders: Dictionary = _pagers[pid]["holders"]
	var slot: int = int(crew.get(&"slot")) if is_instance_valid(crew) else -1
	var released: Array[int] = []
	if holders.erase(slot):
		released.append(slot)
	_reconcile_holders(pid, released)


## PO6-08: drop holders whose interaction session is gone or whose crew left / went down. When the
## last one goes the pager enters its juggle grace (D-114 §4 amended), or resumes with
## pager_release_resumes. `released`: slots that already let go this call.
func _reconcile_holders(pid: int, released: Array[int]) -> void:
	var p: Dictionary = _pagers[pid]
	var holders: Dictionary = p["holders"]
	var was_held: bool = not released.is_empty() or not holders.is_empty()
	var isys: InteractionSystem = _runtime.interaction if _runtime != null else null
	var comp: InteractableComponent = p["comp"] as InteractableComponent if is_instance_valid(p["comp"]) else null
	if isys != null and comp != null:
		var live: Array[int] = isys.holders_of(comp)
		for slot: int in live:
			var cv: Variant = isys.session(slot).get("crew")
			var crew: Node = cv as Node if is_instance_valid(cv) else null
			if crew == null or not crew.is_inside_tree() or int(crew.get(&"crew_state")) != Enums.CrewState.NORMAL:
				if holders.erase(slot):
					released.append(slot)
				isys.cancel(slot)  # a stale session (answerer left / downed) must not keep it frozen
		for slot: Variant in holders.keys():
			if not live.has(int(slot)):
				holders.erase(slot)
				released.append(int(slot))
	if not was_held or not holders.is_empty() or not _pagers.has(pid) or int(p["state"]) != State.ACTIVE:
		return
	if _tw.pager_release_resumes:  # opt-in: the window resumes now (events.md v1.4)
		_emit(&"pager_answer_released", [pid, released.back() if not released.is_empty() else -1])
	elif float(p.get("grace_left", -1.0)) < 0.0:
		p["grace_left"] = _tw.pager_juggle_window_s  # S5.4 alarm unless juggled (D-114 §4 amended)
		p["grace_slots"] = released.duplicate()


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
	var own_line: bool = _runtime != null and _runtime.mission != null and _runtime.mission.own_last_pager_line
	if total == max_answers and not own_line:  # D-117: a heist with its own last-pager line says that one
		# D-117 §6: the bark director picks among Mercer's pager_last_answer lines (vo.mercer.pager_last included,
		# BarkTweak.patterns); without one (bare tests) the generic line.
		var barks: BarkDirector = _runtime.service(BarkDirector.SERVICE) as BarkDirector if _runtime != null else null
		if barks == null or barks.say_now(&"pager_last_answer") == &"":
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
	var comp: InteractableComponent = p["comp"] as InteractableComponent if is_instance_valid(p["comp"]) else null
	if comp != null:
		comp.enabled = false
		if is_instance_valid(_runtime) and is_instance_valid(_runtime.interaction):
			_runtime.interaction.cancel_all_on(comp)
		comp.queue_free()
	_pagers.erase(pid)


## PO6-20: keep the answer prompt on the body where it lies (a death clip can end 1-2 m from the root;
## a dragged body moves): the visual's `hips` bone, else the root, pager_prompt_up_m above the floor point.
func _follow_body(p: Dictionary, comp: InteractableComponent) -> void:
	var guard: Node3D = p["guard"] as Node3D
	var at: Vector3 = guard.global_position
	var skel: Skeleton3D = guard.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null:
		var hips: int = skel.find_bone("hips")
		if hips >= 0:
			at = skel.global_transform * skel.get_bone_global_pose(hips).origin
			at.y = guard.global_position.y
	var up: Vector3 = Vector3.UP * _tw.pager_prompt_up_m
	# GH sweep (r299): a body that folds over a desk (the camera operator at his station) put its hips inside the
	# desk's collision, so no eye anywhere had line of sight and the pager could not be answered. Keep the prompt on
	# this side of any static geometry between the body's root and its hips.
	var space: PhysicsDirectSpaceState3D = guard.get_world_3d().direct_space_state if guard.is_inside_tree() else null
	if space != null and at.distance_to(guard.global_position) > 0.05:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(guard.global_position + up, at + up, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and not (hit["collider"] as Node == guard or guard.is_ancestor_of(hit["collider"] as Node)):
			var back: Vector3 = (guard.global_position - at)
			back.y = 0.0
			at = Vector3(hit["position"]) - up + back.normalized() * 0.15
	comp.global_position = at + up


## Best current answer hold: Vector2(seconds left, progress 0..1) (the holder closest to done).
func _answer_state(p: Dictionary) -> Vector2:
	var comp: InteractableComponent = p["comp"] as InteractableComponent if is_instance_valid(p["comp"]) else null
	if comp == null or _runtime == null or _runtime.interaction == null:
		return Vector2(0.0, 0.0)
	var best: Vector2 = Vector2(INF, 0.0)
	for slot: int in _runtime.interaction.holders_of(comp):
		var s: Dictionary = _runtime.interaction.session(slot)
		var dur: float = float(s.get("duration", 0.0))
		var left: float = maxf(dur - float(s.get("progress", 0.0)), 0.0)
		if left < best.x:
			best = Vector2(left, 1.0 if dur <= 0.0 else clampf(1.0 - left / dur, 0.0, 1.0))
	return best if best.x != INF else Vector2(0.0, 0.0)


# --- Replication (PO6-08) --------------------------------------------------------------------------

## Server: the HUD rows for clients (HeistNetSync services diff):
## {"rows": [[pager_id, guard_net_id, window_left, answering, answer_left, progress]], "answered": int}.
func net_state() -> Dictionary:
	var rows: Array = []
	for e: Dictionary in pager_entries():
		rows.append([int(e["pager_id"]), int(e["guard_net_id"]), snappedf(float(e["time_left"]), 0.1),
			bool(e["answering"]), snappedf(float(e["answer_left"]), 0.1), snappedf(float(e["progress"]), 0.01)])
	return {"rows": rows, "answered": answered_total}


## Client: mirror the server's pager rows (frozen window included) so pager_entries() works on every peer.
func apply_net_state(d: Dictionary) -> void:
	if Net.is_authority():
		return
	_apply_remote(d)


func _apply_remote(d: Dictionary) -> void:
	_remote_rows.clear()
	for v: Variant in d.get("rows", []) as Array:
		var a: Array = v as Array
		if a == null or a.size() < 6:
			continue
		_remote_rows.append({
			"pager_id": int(a[0]), "guard_net_id": int(a[1]), "time_left": float(a[2]),
			"answering": bool(a[3]), "answer_left": float(a[4]), "progress": float(a[5]),
		})
	answered_total = int(d.get("answered", answered_total))


func _remote_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in _remote_rows:
		var e: Dictionary = r.duplicate()
		var guard: Node3D = Ids.lookup(int(r["guard_net_id"])) as Node3D
		e["world_pos"] = guard.global_position if guard != null and guard.is_inside_tree() else Vector3.ZERO
		out.append(e)
	return out


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


# --- A2-03 ECM hook (S5.6) ---------------------------------------------------------------------
## stealth.ecm_pager_delay: a pager whose guard died during an active jam of an ECM owned by a crew
## member with the skill pauses its window while any ECM jams. Base ECM never touches pagers.
func _ecm_pager_delay() -> bool:
	var ecm: Node = HeistRuntime.get_service(&"ecm")
	return ecm != null and ecm.has_method(&"pager_delay_active") and bool(ecm.call(&"pager_delay_active"))


func _ecm_paused(p: Dictionary) -> bool:
	if not bool(p.get("ecm_hold", false)):
		return false
	var ecm: Node = HeistRuntime.get_service(&"ecm")
	return ecm != null and ecm.has_method(&"is_jamming") and bool(ecm.call(&"is_jamming"))
# --- end A2-03


func _emit(sig: StringName, args: Array) -> void:
	EventBus.emit_signal.callv([sig] + args)
	Net.replicate_event(sig, args)
