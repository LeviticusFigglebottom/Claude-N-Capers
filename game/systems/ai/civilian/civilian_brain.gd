## Civilian behaviour (child `Brain` of npc_civilian). Owner: ENV A. Server only.
## Rows: S3.1, S3.8, S6.4 (restrained stimulus), S7.1, S7.2, S7.4, S7.5, S11.2, D-016.
##
## CALM (Mode IDLE/WANDER): idle activity from `spawn_info.idle_activity` -> `anim_hint`; civilians
##   whose activity allows it wander between civilian/staff PatrolPoints (stream &"civilians"):
##   customers between public `civilian` points, staff between the `staff` points of their own area
##   (PO-5, CivilianTargets.wander_options).
## PO-5 stall: WANDER / RUN_TO_CALL that makes no progress (civilian_walk_stall_*) re-paths once, then gives
##   the target up (wander: back to IDLE, that point skipped next time; call: next call point or flee).
## PANICKED: triggered by crew_spotted, a stimulus/noise whose civilian reaction is &"panic"
##   (StealthTweak.stimuli / noise_reactions), or going LOUD (S11.2).
##   Stealth: run to the cheapest of phone / alarm button / call point / alive guard
##   (CivilianTargets.path_cost); at a call point make a `civilian_call_s` call, then
##   raise_alarm(reason, net_id); at a guard, alert the guard (`alert_from_civilian(npc)` when the
##   guard brain has it, else `notify_stimulus(id, &"alerted_npc", pos)`) and flee.
##   No call point and no guard: flee. Loud: flee from the nearest crew member, then cower.
##   civilian_fled [R] is emitted once, when the civilian first starts fleeing (first panic).
## INTIMIDATED (Mode DOWN): via ShoutSystem -> on_shouted(). A PANICKED civilian only goes down
##   on a fleeing_shout_chance roll (stream &"intimidate", D-016); success interrupts the call.
##   Re-shout resets the timer. Timer expiry -> PANICKED again (resumes running/calling).
## TIED: cable tie hold (`TieInteractable`, enabled only while DOWN). Permanent; joins G.HOSTAGE,
##   registers a `restrained` stimulus, CivilianTargets recounts hostages.
## Intimidated/tied civilians do not observe (NpcBase.BLIND_STATES).
## A3-04 (L2.10): a tied civilian can be traded for a crew member in custody (CustodySystem ->
## release_as_hostage, then the node is freed).
class_name CivilianBrain
extends Node

enum Mode { IDLE, WANDER, RUN_TO_CALL, CALLING, FLEE, COWER, DOWN, TIED, DEAD }

## Idle activities that may wander (seated / queued / desk civilians stay put).
const WANDER_ACTIVITIES: Array[StringName] = [&"", &"idle", &"browse", &"phone", &"mug"]
## D-069 adds mug (walks with it: mug_walk), mop, phone_seated (characters.md v1.7 ambient clips).
const KNOWN_ACTIVITIES: Array[StringName] = [&"browse", &"phone", &"desk_work", &"queue", &"sit", &"mug", &"mop",
	&"phone_seated"]
const KIND_GUARD: StringName = &"guard"
const KIND_POINT: StringName = &"point"
const RETARGET_S: float = 0.5

var mode: Mode = Mode.IDLE
## Animation hint for the visual (&"browse", &"walk", &"run", &"call", &"down", &"tied", &"cower"...).
var anim_hint: StringName = &"idle"
## Current run target: { "kind": KIND_POINT|KIND_GUARD, "node": Node3D, "position": Vector3, "reason": StringName }
var call_target: Dictionary = {}
var call_progress: float = 0.0
var intimidate_left: float = 0.0
var intimidated_by_slot: int = -1
var threat_position: Vector3 = Vector3.INF
var fled_reported: bool = false

var _npc: NpcBase = null
var _motor: NpcMotor = null
var _tie: InteractableComponent = null
var _runtime: HeistRuntime = null
var _targets: CivilianTargets = null
var _idle_activity: StringName = &""
var _wander_timer: float = 0.0
var _retarget_timer: float = 0.0
var _alerted_stimulus_id: int = 0
var _restrained_stimulus_id: int = 0
var _flee_stall_t: float = 0.0
var _flee_stall_pos: Vector3 = Vector3.ZERO
## PO-5 walk stall (WANDER / RUN_TO_CALL).
var _walk_stall_t: float = 0.0
var _walk_stall_pos: Vector3 = Vector3.ZERO
var _walk_stalls: int = 0
## PO-5: wander profile (CivilianTargets.wander_profile), computed on the first wander.
var _wander_profile: Dictionary = {}
## PO-5: the wander point / call target given up after a stall (skipped by the next pick).
var _failed_target: Node = null


func _ready() -> void:
	_npc = get_parent() as NpcBase
	if _npc == null:
		return
	_motor = _npc.get_node_or_null(^"Motor") as NpcMotor
	_tie = _npc.get_node_or_null(^"TieInteractable") as InteractableComponent
	_npc.crew_spotted.connect(_on_crew_spotted)
	_npc.stimulus_spotted.connect(_on_stimulus_spotted)
	_npc.noise_heard.connect(_on_noise_heard)
	_npc.died.connect(_on_died)
	if _tie != null:
		_tie.kind = &"cable_tie"
		_tie.interaction_time_s = Tweak.stealth().cable_tie_s
		_tie.speed_modifier_key = &"stealth.cable_tie_speed_mult"
		_tie.casing_allowed = false
		_tie.enabled = false
		_tie.extra_check = _tie_check
		_tie.completed.connect(_on_tie_completed)
	_idle_activity = StringName(_npc.spawn_info.get("idle_activity", &""))
	_set_idle_hint()
	_runtime = HeistRuntime.of(self)
	if _runtime != null and Net.is_authority():
		ShoutSystem.ensure(_runtime)
		_targets = CivilianTargets.ensure(_runtime)
		_runtime.phase_changed.connect(_on_phase_changed)
	_wander_timer = _roll_wander_delay()
	if _is_loud():
		_panic.call_deferred(Vector3.INF)


func _exit_tree() -> void:
	if _runtime != null and is_instance_valid(_runtime) and _runtime.phase_changed.is_connected(_on_phase_changed):
		_runtime.phase_changed.disconnect(_on_phase_changed)


# --- Queries ----------------------------------------------------------------------

func is_calling() -> bool:
	return mode == Mode.CALLING


func is_down() -> bool:
	return mode == Mode.DOWN


func is_tied() -> bool:
	return mode == Mode.TIED


## Point ShoutSystem aims at (chest standing, low when on the floor).
func shout_target_point() -> Vector3:
	var h: float = 0.4 if mode == Mode.DOWN or mode == Mode.TIED or mode == Mode.COWER else 1.0
	return _npc.global_position + Vector3(0.0, h, 0.0)


# --- Shout / tie (S7.1, S7.2) -------------------------------------------------------

## ShoutSystem: a shout from `crew` reached this civilian. Returns true if it took effect.
func on_shouted(crew: Node) -> bool:
	if not Net.is_authority() or _npc == null or not _npc.alive:
		return false
	if mode == Mode.TIED or mode == Mode.DEAD:
		return false
	if _npc.alert_state == Enums.AlertState.PANICKED:
		if GameRng.stream(&"intimidate").randf() >= Tweak.stealth().fleeing_shout_chance:  # D-016
			return false
	var slot: int = int(crew.get(&"slot")) if crew != null else -1
	_intimidate(slot)
	return true


func _intimidate(slot: int) -> void:
	var tw: StealthTweak = Tweak.stealth()
	call_progress = 0.0
	call_target = {}
	if _motor != null:
		_motor.stop()
	mode = Mode.DOWN
	anim_hint = &"down"
	intimidated_by_slot = slot
	intimidate_left = tw.intimidate_duration_s * (Modifiers.mult(slot, &"stealth.civilian_stay_down_mult") if slot >= 0 else 1.0)
	_clear_alerted_stimulus()
	_npc.set_alert_state(Enums.AlertState.INTIMIDATED)
	if _tie != null:
		_tie.enabled = true
	_emit(&"civilian_intimidated", [_npc.net_id, slot])


func _tie_check(crew: Node) -> StringName:
	if mode != Mode.DOWN:
		return InteractableComponent.BLOCK_STATE
	if crew != null and int(crew.get(&"cable_ties")) <= 0:
		return InteractableComponent.BLOCK_ITEM
	return InteractableComponent.BLOCK_NONE


func _on_tie_completed(crew: Node) -> void:
	var cc: CrewController = crew as CrewController
	if mode != Mode.DOWN or cc == null or not cc.use_cable_tie():
		return
	mode = Mode.TIED
	anim_hint = &"tied"
	_tie.enabled = false
	_npc.set_alert_state(Enums.AlertState.TIED)
	_npc.add_to_group(G.HOSTAGE)
	_emit(&"civilian_tied", [_npc.net_id, cc.slot])
	var st: StealthDirector = _stealth()
	if st != null:
		_restrained_stimulus_id = st.register_stimulus(_npc, &"restrained")  # S6.4
	if _targets != null:
		_targets.recount_hostages()


## A3-04 (L2.10): this tied civilian was traded for a crew member and leaves play (CustodySystem
## frees the node): drop the restrained stimulus and the hostage group.
func release_as_hostage() -> void:
	var st: StealthDirector = _stealth()
	if st != null and _restrained_stimulus_id != 0:
		st.unregister_stimulus(_restrained_stimulus_id)
	_restrained_stimulus_id = 0
	if _npc != null:
		_npc.remove_from_group(G.HOSTAGE)
	mode = Mode.DEAD
	anim_hint = &""


# --- Panic (S3.1, S7.4, S11.2) ------------------------------------------------------

func _on_crew_spotted(crew: Node) -> void:
	var c3: Node3D = crew as Node3D
	_panic(c3.global_position if c3 != null else Vector3.INF)


func _on_stimulus_spotted(stimulus_id: int, kind: StringName, position: Vector3) -> void:
	if stimulus_id != 0 and (stimulus_id == _alerted_stimulus_id or stimulus_id == _restrained_stimulus_id):
		return
	var preset: Dictionary = Tweak.stealth().stimuli.get(kind, {})
	if StringName(preset.get("civilian", &"ignore")) == &"panic":
		_panic(position)


func _on_noise_heard(position: Vector3, kind: StringName, _source_net_id: int) -> void:
	var r: Dictionary = Tweak.stealth().noise_reactions.get(kind, {})
	if StringName(r.get("civilian", &"ignore")) == &"panic":
		_panic(position)


func _on_phase_changed(_old: int, new_phase: int) -> void:
	if new_phase != Enums.HeistPhase.LOUD:
		return
	match mode:
		Mode.IDLE, Mode.WANDER:
			_panic(Vector3.INF)
		Mode.RUN_TO_CALL, Mode.CALLING:
			call_target = {}
			call_progress = 0.0
			_clear_alerted_stimulus()
			_flee()


## Enter PANICKED (no-op when already panicked, down, tied or dead).
func _panic(threat: Vector3) -> void:
	if not Net.is_authority() or _npc == null or not _npc.alive:
		return
	if mode != Mode.IDLE and mode != Mode.WANDER:
		return
	threat_position = threat
	_npc.set_alert_state(Enums.AlertState.PANICKED)
	if not fled_reported:
		fled_reported = true
		_emit(&"civilian_fled", [_npc.net_id])
	_resume_panic()


## PANICKED behaviour from scratch (first panic or getting back up).
func _resume_panic() -> void:
	if _is_loud():
		_flee()
		return
	var st: StealthDirector = _stealth()
	if st != null and _alerted_stimulus_id == 0:
		_alerted_stimulus_id = st.register_stimulus(_npc, &"alerted_npc")
	if not _pick_call_target():
		_flee()


func _pick_call_target() -> bool:
	var from: Vector3 = _npc.global_position
	var best: Dictionary = {}
	var best_cost: float = INF
	if _targets != null:
		for p: Dictionary in _targets.call_points():
			if p["node"] == _failed_target:
				continue
			var c: float = _targets.path_cost(from, p["position"])
			if c < best_cost:
				best_cost = c
				best = {"kind": KIND_POINT, "node": p["node"], "position": p["position"], "reason": p["reason"]}
	for g: Node3D in _alertable_guards():
		if g == _failed_target:
			continue
		var c: float = _targets.path_cost(from, g.global_position) if _targets != null else from.distance_to(g.global_position)
		if c < best_cost:
			best_cost = c
			best = {"kind": KIND_GUARD, "node": g, "position": g.global_position, "reason": &""}
	if best.is_empty():
		return false
	call_target = best
	call_progress = 0.0
	mode = Mode.RUN_TO_CALL
	anim_hint = &"run"
	_retarget_timer = RETARGET_S
	_reset_walk_stall()
	if _motor != null:
		_motor.go_to(best["position"], Tweak.stealth().civilian_run_speed)
	return true


func _alertable_guards() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _runtime == null:
		return out
	for n: Node in _runtime.npcs(&"guard"):
		var g: NpcBase = n as NpcBase
		if g != null and g.can_observe():
			out.append(g)
	return out


func _tick_run(delta: float) -> void:
	var node: Node3D = call_target.get("node") as Node3D
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		if not _pick_call_target():
			_flee()
		return
	if _tick_walk_stall(delta, Tweak.stealth().civilian_run_speed):
		_failed_target = node
		call_target = {}
		if not _pick_call_target():
			_flee()
		return
	if call_target["kind"] == KIND_GUARD:
		var g: NpcBase = node as NpcBase
		if g == null or not g.can_observe():
			if not _pick_call_target():
				_flee()
			return
		if _flat_distance(g.global_position) <= Tweak.stealth().civilian_guard_reach_m:
			_alert_guard(g)
			return
		_retarget_timer -= delta
		if _retarget_timer <= 0.0 and _motor != null:
			_retarget_timer = RETARGET_S
			_motor.go_to(g.global_position, Tweak.stealth().civilian_run_speed)
		return
	var pos: Vector3 = call_target["position"]
	var reach: float = (_motor.arrive_distance if _motor != null else 0.4) + 0.2
	if (_motor != null and _motor.arrived) or _flat_distance(pos) <= reach:
		if _motor != null:
			_motor.stop()
			_motor.face_point(node.global_position)
		mode = Mode.CALLING
		anim_hint = &"call"
		call_progress = 0.0


func _tick_call(delta: float) -> void:
	call_progress += delta
	if call_progress < Tweak.stealth().civilian_call_s:
		return
	var reason: StringName = StringName(call_target.get("reason", CivilianTargets.REASON_PHONE))
	# A2-03 (S8.4): an active ECM jams phones: the call cannot complete until the jam ends (the
	# civilian keeps trying). Alarm buttons are not jammed.
	if reason == CivilianTargets.REASON_PHONE and EcmSystem.phones_jammed():
		call_progress = Tweak.stealth().civilian_call_s
		return
	var st: StealthDirector = _stealth()
	if st != null and st.is_stealth():
		st.raise_alarm(reason, _npc.net_id)
	# raise_alarm -> LOUD -> _on_phase_changed already switched to fleeing.
	if mode == Mode.CALLING:
		call_target = {}
		_flee()


func _alert_guard(g: NpcBase) -> void:
	var brain: Node = g.get_node_or_null(^"Brain")
	if g.has_method(&"alert_from_civilian"):
		g.call(&"alert_from_civilian", _npc)
	elif brain != null and brain.has_method(&"alert_from_civilian"):
		brain.call(&"alert_from_civilian", _npc)
	else:
		var st: StealthDirector = _stealth()
		if st != null and _alerted_stimulus_id == 0:
			_alerted_stimulus_id = st.register_stimulus(_npc, &"alerted_npc")
		g.notify_stimulus(_alerted_stimulus_id, &"alerted_npc", _npc.global_position)
	call_target = {}
	_flee()


## Run away from the nearest crew member (or the threat), then cower.
func _flee() -> void:
	mode = Mode.FLEE
	anim_hint = &"run"
	_flee_stall_t = 0.0
	_flee_stall_pos = _npc.global_position
	var away_from: Vector3 = _nearest_crew_position()
	if away_from == Vector3.INF:
		away_from = threat_position
	var dir: Vector3 = Vector3.ZERO
	if away_from != Vector3.INF:
		dir = _npc.global_position - away_from
		dir.y = 0.0
	if dir.length() < 0.01 or _motor == null:
		_cower()
		return
	_motor.go_to(_npc.global_position + dir.normalized() * Tweak.stealth().civilian_flee_distance_m,
			Tweak.stealth().civilian_run_speed)


## PO-5: FLEE that makes no progress (door blocked by the crew, unreachable point) ends in COWER.
func _tick_flee_stall(delta: float) -> void:
	var tw: StealthTweak = Tweak.stealth()
	_flee_stall_t += delta
	if _flee_stall_t < tw.civilian_flee_stall_s:
		return
	var moved: float = Vector2(_npc.global_position.x - _flee_stall_pos.x, _npc.global_position.z - _flee_stall_pos.z).length()
	_flee_stall_t = 0.0
	_flee_stall_pos = _npc.global_position
	if moved < tw.civilian_flee_stall_m:
		_cower()


func _reset_walk_stall() -> void:
	_walk_stall_t = 0.0
	_walk_stall_pos = _npc.global_position
	_walk_stalls = 0


## PO-5: true when the walk to the current target has stalled twice (it re-paths after the first stall:
## blocked by a body, wedged on a corner). Holding at a door that is opening is not a stall.
func _tick_walk_stall(delta: float, move_speed: float) -> bool:
	if _motor == null or _motor.waiting_door != null:
		_walk_stall_t = 0.0
		_walk_stall_pos = _npc.global_position
		return false
	var tw: StealthTweak = Tweak.stealth()
	_walk_stall_t += delta
	if _walk_stall_t < tw.civilian_walk_stall_s:
		return false
	var moved: float = _npc.global_position.distance_to(_walk_stall_pos)
	_walk_stall_t = 0.0
	_walk_stall_pos = _npc.global_position
	if moved >= tw.civilian_walk_stall_m:
		_walk_stalls = 0
		return false
	_walk_stalls += 1
	if _walk_stalls >= 2:
		_walk_stalls = 0
		return true
	_motor.go_to(_motor.target, move_speed)  # re-path from where it stands
	return false


## PO-5 (D-086 playability): only a civilian on its feet blocks the crew (crew mask includes the NPC
## layer). Cowering, intimidated (down) and tied civilians are on the floor: the crew walks past them
## instead of being pinned in a doorway. Hitboxes are separate areas, so shooting is unaffected.
func _update_body_block() -> void:
	var blocking: bool = mode != Mode.COWER and mode != Mode.DOWN and mode != Mode.TIED and mode != Mode.DEAD
	var layer: int = NpcBase.LAYER_NPCS if blocking else 0
	if _npc.collision_layer != layer:
		_npc.collision_layer = layer


func _cower() -> void:
	mode = Mode.COWER
	anim_hint = &"cower"
	if _motor != null:
		_motor.stop()


func _get_up() -> void:
	if _tie != null:
		_tie.enabled = false
		if _runtime != null and _runtime.interaction != null:
			_runtime.interaction.cancel_all_on(_tie)
	intimidated_by_slot = -1
	mode = Mode.FLEE  # transitional; _resume_panic picks the real mode
	_npc.set_alert_state(Enums.AlertState.PANICKED)
	_resume_panic()


# --- Calm (S7.5) ----------------------------------------------------------------------

func _set_idle_hint() -> void:
	anim_hint = _idle_activity if KNOWN_ACTIVITIES.has(_idle_activity) else &"idle"


func _roll_wander_delay() -> float:
	var r: Vector2 = Tweak.stealth().civilian_wander_interval_s
	return GameRng.stream(&"civilians").randf_range(r.x, maxf(r.x, r.y))


func _tick_idle(delta: float) -> void:
	if not WANDER_ACTIVITIES.has(_idle_activity) or _targets == null or _motor == null:
		return
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_wander_timer = _roll_wander_delay()
	if _wander_profile.is_empty():
		_wander_profile = _targets.wander_profile(_npc, _npc.global_position)
	var options: Array[PatrolPoint] = _targets.wander_options(_npc.global_position, _wander_profile,
		Tweak.stealth().civilian_wander_radius_m)
	options.erase(_failed_target)
	_failed_target = null
	if options.is_empty():
		return
	var weights: PackedFloat32Array = PackedFloat32Array()
	for p: PatrolPoint in options:
		weights.append(maxf(p.weight, 0.001))
	var pick: PatrolPoint = options[GameRng.weighted_index(&"civilians", weights)]
	call_target = {"kind": KIND_POINT, "node": pick, "position": pick.global_position, "reason": &""}
	mode = Mode.WANDER
	anim_hint = &"mug_walk" if _idle_activity == &"mug" else &"walk"
	_reset_walk_stall()
	_motor.go_to(pick.global_position, Tweak.stealth().civilian_walk_speed)


func _tick_wander(delta: float) -> void:
	if _motor != null and not _motor.arrived:
		if _tick_walk_stall(delta, Tweak.stealth().civilian_walk_speed):
			_failed_target = call_target.get("node") as Node
			call_target = {}
			_motor.stop()
			mode = Mode.IDLE
			_set_idle_hint()
		return
	var p: PatrolPoint = call_target.get("node") as PatrolPoint
	call_target = {}
	mode = Mode.IDLE
	if p != null and is_instance_valid(p):
		if p.face_marker_forward and _motor != null:
			_motor.face(-p.global_transform.basis.z)
		anim_hint = p.pause_anim if p.pause_anim != &"idle" else (_idle_activity if KNOWN_ACTIVITIES.has(_idle_activity) else &"idle")
	else:
		_set_idle_hint()


# --- Tick ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not Net.is_authority() or _npc == null or not _npc.alive:
		return
	_update_body_block()
	match mode:
		Mode.IDLE:
			_tick_idle(delta)
		Mode.WANDER:
			_tick_wander(delta)
		Mode.RUN_TO_CALL:
			_tick_run(delta)
		Mode.CALLING:
			_tick_call(delta)
		Mode.FLEE:
			if _motor == null or _motor.arrived:
				_cower()
			else:
				_tick_flee_stall(delta)
		Mode.DOWN:
			intimidate_left -= delta
			if intimidate_left <= 0.0:
				_get_up()


func _on_died(_info: Dictionary, _killer_net_id: int) -> void:
	var was_hostage: bool = _npc.is_in_group(G.HOSTAGE)
	mode = Mode.DEAD
	anim_hint = &"dead"
	call_target = {}
	if _motor != null:
		_motor.stop()
	if _tie != null:
		_tie.enabled = false
		if _runtime != null and _runtime.interaction != null:
			_runtime.interaction.cancel_all_on(_tie)
	_clear_alerted_stimulus()
	var st: StealthDirector = _stealth()
	if st != null and _restrained_stimulus_id != 0:
		st.unregister_stimulus(_restrained_stimulus_id)
	_restrained_stimulus_id = 0
	if was_hostage:
		_npc.remove_from_group(G.HOSTAGE)
		if _targets != null:
			_targets.recount_hostages()


# --- Helpers -------------------------------------------------------------------------------

func _stealth() -> StealthDirector:
	return _runtime.stealth if _runtime != null else null


func _is_loud() -> bool:
	if _runtime == null:
		return false
	return _runtime.went_loud or _runtime.phase == Enums.HeistPhase.LOUD


func _clear_alerted_stimulus() -> void:
	var st: StealthDirector = _stealth()
	if st != null and _alerted_stimulus_id != 0:
		st.unregister_stimulus(_alerted_stimulus_id)
	_alerted_stimulus_id = 0


func _nearest_crew_position() -> Vector3:
	if _runtime == null:
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	for c: CrewController in _runtime.crew_members():
		var d: float = _flat_distance(c.global_position)
		if d < best_d:
			best_d = d
			best = c.global_position
	return best


func _flat_distance(p: Vector3) -> float:
	return Vector2(p.x - _npc.global_position.x, p.z - _npc.global_position.z).length()


func _emit(sig: StringName, args: Array) -> void:
	if not Net.is_authority():
		return
	EventBus.emit_signal.callv([sig] + args)
	Net.replicate_event(sig, args)
