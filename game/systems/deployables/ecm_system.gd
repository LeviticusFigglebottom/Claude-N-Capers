## ECM jammer runtime (A2-03). Owner: ENV A. Service SERVICE (&"ecm"), child of HeistRuntime.
## Rows: S8.4 (20 s jam x stealth.ecm_duration_mult, flashing for the last 8 s, jams every camera
## and phone, not pagers / lasers / panic buttons / an already-alerted camera's S3.5 countdown;
## ECMs chain: a second one queues until the first ends), S8.5 (stealth.ecm_opens_doors: placed on a
## keycard reader it is consumed and opens the reader's doors after 4 s), S8.6 (feedback: interact
## with a placed ECM -> 15 m stun of 6 s of non-Cloaker enemies + an `alarm` noise in stealth;
## built into every ECM (D-038 QA-16; the deprecated stealth.ecm_feedback key is ignored);
## retrigger after 4 min with stealth.ecm_feedback_retrigger), S5.6
## (stealth.ecm_pager_delay: pagers of guards killed during that jam pause their 12 s window).
##
## Cameras: while jamming every SecurityCamera of the heist is set_suppressed(&"ecm", true) (blind;
## re-applied each tick so cameras spawned mid-jam are covered) and released when the chain ends.
## The S3.5 countdown lives in StealthDirector (camera_countdown()) and is never touched.
## PUBLIC API (consumers query duck-typed through HeistRuntime.get_service(&"ecm")):
##   is_jamming() -> bool               cameras and phones
##   time_left() -> float               active jam seconds left (-1 = none)
##   is_flashing() -> bool              last ecm_flash_last_s of the active jam
##   active_ecm_net_id() -> int / queued_count() -> int
##   pager_delay_active() -> bool       S5.6: the active jam's owner has stealth.ecm_pager_delay
##   add_jammer(ecm) / attach_to_reader(ecm, reader) / trigger_feedback(ecm, by_slot)
##   static phones_jammed() -> bool     convenience for phones / civilians
## Events: ecm_started(ecm_net_id, duration) [R] when a jam actually starts (a queued ECM emits it
## when its turn comes), ecm_ended(ecm_net_id) [R], ecm_feedback_triggered(ecm_net_id) [R].
class_name EcmSystem
extends Node

const SERVICE: StringName = &"ecm"
## SecurityCamera.set_suppressed source id while jamming.
const SUPPRESS_SOURCE: StringName = &"ecm"

var _runtime: HeistRuntime = null
var _active: DeployablePrefab = null
var _queue: Array[DeployablePrefab] = []
## {"ecm": DeployablePrefab, "reader": Node, "left": float}
var _door_jobs: Array[Dictionary] = []
## Feedback-placed ECMs waiting for their recharge (S8.6).
var _recharging: Array[DeployablePrefab] = []
## Stunned NPCs (S8.6): their stun timers tick here.
var _stunned: Array[NpcBase] = []
## Cameras this system suppressed (S8.4).
var _jammed_cameras: Array[SecurityCamera] = []


func _ready() -> void:
	if _runtime == null:
		_runtime = HeistRuntime.of(self)


static func phones_jammed() -> bool:
	var s: Node = HeistRuntime.get_service(SERVICE)
	return s != null and s.has_method(&"is_jamming") and bool(s.call(&"is_jamming"))


func is_jamming() -> bool:
	return _active != null and is_instance_valid(_active)


func time_left() -> float:
	return _active.jam_left if is_jamming() else -1.0


func is_flashing() -> bool:
	return is_jamming() and _active.flashing


func active_ecm_net_id() -> int:
	return _active.net_id if is_jamming() else 0


func queued_count() -> int:
	return _queue.size()


## S5.6: true while the active jam belongs to a crew member with stealth.ecm_pager_delay.
func pager_delay_active() -> bool:
	return is_jamming() and Modifiers.flag(_active.owner_slot, &"stealth.ecm_pager_delay")


## S8.4 jam duration for an ECM placed by `slot` (def params.duration or ecm_jam_s, x modifier).
static func jam_duration_for(slot: int, def: DeployableDef) -> float:
	var base: float = DeployableTweak.data().ecm_jam_s
	if def != null and def.params.has("duration"):
		base = float(def.params["duration"])
	return base * Modifiers.mult(slot, &"stealth.ecm_duration_mult")


# --- Jamming (S8.4) ------------------------------------------------------------------------------

## Server: a freshly placed ECM. Starts jamming now, or queues behind the active one (chaining).
func add_jammer(ecm: DeployablePrefab) -> void:
	if not Net.is_authority() or ecm == null:
		return
	ecm.jam_duration = jam_duration_for(ecm.owner_slot, DeployableSystem.def_for(ecm.deployable_id))
	ecm.jam_left = ecm.jam_duration
	if is_jamming():
		ecm.ecm_state = DeployablePrefab.EcmState.QUEUED
		_queue.append(ecm)
		Log.info(&"ecm", "ECM %d queued (%d waiting)" % [ecm.net_id, _queue.size()])
		return
	_start(ecm)


func _start(ecm: DeployablePrefab) -> void:
	_active = ecm
	ecm.ecm_state = DeployablePrefab.EcmState.JAMMING
	ecm.jam_left = ecm.jam_duration
	ecm.flashing = ecm.jam_left <= DeployableTweak.data().ecm_flash_last_s
	Log.info(&"ecm", "ECM %d jamming for %.1f s" % [ecm.net_id, ecm.jam_duration])
	_emit(&"ecm_started", [ecm.net_id, ecm.jam_duration])
	_emit(&"audio_cue_requested", [&"cue.ecm_active", ecm.global_position, ecm.net_id])


func _end_active() -> void:
	var ecm: DeployablePrefab = _active
	_active = null
	var id: int = 0
	if ecm != null and is_instance_valid(ecm):
		id = ecm.net_id
		ecm.ecm_state = DeployablePrefab.EcmState.SPENT
		ecm.flashing = false
		ecm.jam_left = 0.0
	Log.info(&"ecm", "ECM %d ended" % id)
	_emit(&"ecm_ended", [id])
	while not _queue.is_empty():
		var nxt: DeployablePrefab = _queue.pop_front()
		if nxt != null and is_instance_valid(nxt) and not nxt.is_queued_for_deletion():
			_start(nxt)
			return


func _physics_process(delta: float) -> void:
	if not Net.is_authority():
		return
	if _active != null:
		if not is_instance_valid(_active) or _active.is_queued_for_deletion():
			_end_active()
		else:
			_active.jam_left = maxf(_active.jam_left - delta, 0.0)
			_active.flashing = _active.jam_left <= DeployableTweak.data().ecm_flash_last_s
			if _active.jam_left <= 0.0:
				_end_active()
	_apply_camera_jam(is_jamming())
	_tick_doors(delta)
	_tick_feedback(delta)


## S8.4: blind (or release) every camera of the heist.
func _apply_camera_jam(on: bool) -> void:
	if on and _runtime != null:
		for cam: SecurityCamera in SecurityCamera.cameras_in(_runtime):
			if not _jammed_cameras.has(cam):
				cam.set_suppressed(SUPPRESS_SOURCE, true)
				_jammed_cameras.append(cam)
	elif not on and not _jammed_cameras.is_empty():
		for cam: SecurityCamera in _jammed_cameras:
			if is_instance_valid(cam):
				cam.set_suppressed(SUPPRESS_SOURCE, false)
		_jammed_cameras.clear()


# --- Doors (S8.5) --------------------------------------------------------------------------------

## Server: an ECM placed on a keycard reader (stealth.ecm_opens_doors): consumed, doors open after
## ecm_door_open_s. Does not jam.
func attach_to_reader(ecm: DeployablePrefab, reader: Node) -> void:
	if not Net.is_authority() or ecm == null or reader == null:
		return
	ecm.ecm_state = DeployablePrefab.EcmState.DOOR
	if ecm.interactable != null:
		ecm.interactable.enabled = false
	_door_jobs.append({"ecm": ecm, "reader": reader, "left": DeployableTweak.data().ecm_door_open_s})
	Log.info(&"ecm", "ECM %d on keycard reader %s: opening in %.1f s" % [ecm.net_id, reader.name,
		DeployableTweak.data().ecm_door_open_s])


func _tick_doors(delta: float) -> void:
	for i: int in range(_door_jobs.size() - 1, -1, -1):
		var job: Dictionary = _door_jobs[i]
		job["left"] = float(job["left"]) - delta
		if float(job["left"]) > 0.0:
			continue
		_door_jobs.remove_at(i)
		var reader: Node = job["reader"] as Node
		if reader != null and is_instance_valid(reader) and reader.has_method(&"open_by_ecm"):
			reader.call(&"open_by_ecm")
		var ecm: DeployablePrefab = job["ecm"] as DeployablePrefab
		if ecm != null and is_instance_valid(ecm):
			ecm.queue_free()  # consumed


# --- Feedback (S8.6) -----------------------------------------------------------------------------

## Why a crew member cannot trigger feedback on `ecm` (&"" = available). Every ECM has feedback
## (D-038 QA-16); `_crew` is kept for API stability.
func feedback_block(ecm: DeployablePrefab, _crew: CrewController) -> StringName:
	if ecm.ecm_state == DeployablePrefab.EcmState.DOOR:
		return InteractableComponent.BLOCK_DISABLED
	if ecm.feedback_used:
		if ecm.feedback_recharge_left > 0.0 or not Modifiers.flag(ecm.owner_slot, &"stealth.ecm_feedback_retrigger"):
			return InteractableComponent.BLOCK_STATE
	return InteractableComponent.BLOCK_NONE


## Server: S8.6 feedback from `ecm` (triggered by `by_slot`). Returns the number of NPCs stunned.
func trigger_feedback(ecm: DeployablePrefab, by_slot: int = -1) -> int:
	if not Net.is_authority() or ecm == null or not is_instance_valid(ecm):
		return 0
	var tw: DeployableTweak = DeployableTweak.data()
	ecm.feedback_used = true
	ecm.feedback_recharge_left = tw.ecm_feedback_recharge_s
	if not _recharging.has(ecm):
		_recharging.append(ecm)
	var pos: Vector3 = ecm.global_position
	var stun_s: float = tw.ecm_feedback_stun_s * Modifiers.mult(ecm.owner_slot, &"stealth.ecm_feedback_duration_mult")
	# The stun is an ALARM stimulus in stealth: delivered before the stun (stunned NPCs are blind),
	# so alerted guards radio once they recover.
	var st: StealthDirector = HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector
	if _runtime != null and st != null and st.is_stealth():
		_runtime.make_noise(pos, tw.ecm_feedback_radius_m, &"alarm", ecm.net_id)
	var count: int = 0
	if _runtime != null:
		for n: Node in _runtime.npcs():
			var npc: NpcBase = n as NpcBase
			if npc == null or not npc.is_in_group(G.ENEMY) or _immune(npc):
				continue
			if npc.global_position.distance_to(pos) > tw.ecm_feedback_radius_m:
				continue
			npc.stun(stun_s)
			if not _stunned.has(npc):
				_stunned.append(npc)
			count += 1
	Log.info(&"ecm", "ECM %d feedback by slot %d: %d stunned for %.1f s" % [ecm.net_id, by_slot, count, stun_s])
	_emit(&"ecm_feedback_triggered", [ecm.net_id])
	_emit(&"audio_cue_requested", [&"cue.ecm_feedback", pos, ecm.net_id])
	return count


func _immune(npc: NpcBase) -> bool:
	var def: EnemyDef = npc.enemy_def
	if def == null:
		return false
	return DeployableTweak.data().ecm_feedback_immune_ids.has(def.id) or bool(def.params.get("ecm_feedback_immune", false))


func _tick_feedback(delta: float) -> void:
	for i: int in range(_stunned.size() - 1, -1, -1):
		var npc: NpcBase = _stunned[i]
		if npc == null or not is_instance_valid(npc):
			_stunned.remove_at(i)
			continue
		npc.tick_stun(delta)
		if not npc.is_stunned():
			_stunned.remove_at(i)
	for i: int in range(_recharging.size() - 1, -1, -1):
		var ecm: DeployablePrefab = _recharging[i]
		if ecm == null or not is_instance_valid(ecm):
			_recharging.remove_at(i)
			continue
		ecm.feedback_recharge_left = maxf(ecm.feedback_recharge_left - delta, 0.0)
		if ecm.feedback_recharge_left <= 0.0:
			_recharging.remove_at(i)


func _emit(sig: StringName, args: Array) -> void:
	EventBus.emit_signal.callv([sig] + args)
	Net.replicate_event(sig, args)
