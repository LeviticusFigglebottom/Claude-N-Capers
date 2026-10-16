## Stealth service (G.SVC_STEALTH): detection meters, stimuli, noise propagation, alarm.
## Owner: ENV A. Rows: S1.1, S1.5, S2.1-S2.8, S3.x, S4.1-S4.4, S11.2.
##
## PUBLIC API (other systems call only these; internals may change):
##   raise_alarm(reason, source_net_id)        -> emits alarm_raised [R] once (S3, S5, S11.2)
##   is_stealth() -> bool                      -> CASING/STEALTH and no alarm yet
##   detection_value(observer, slot) -> float  -> meter 0..1 (test_hooks.md)
##   detection_entries(slot) -> Array[Dictionary] -> {observer_net_id, world_pos, value, kind} (HUD, server)
##   fill_rate(observer, crew) -> float        -> instantaneous S2.2 fill rate per second (0 = no fill);
##                                                max of the body rate and the D-118 laser/flashlight rate
##   fill_time(preset, dr, d, angle_deg, crouched) -> float -> D-128 PD2 formula alone: s to fill (0 instant, INF never)
##   detection_risk_mult(dr) -> float          -> S2.3 DR time multiplier (interpolated table)
##   camera_countdown() -> float               -> S3.5 seconds until the camera alarm, -1 if none
##   start_camera_alarm(camera_net_id)         -> S3.5/S4.4 camera alerted by a stimulus (A2-02)
##   mark(target, by_slot) -> bool / is_marked(target) / marked_targets(slot) -> Array[Dictionary]
##                                             -> S2.9 crew-wide marks {net_id, world_pos, kind} (A2-05)
##   register_stimulus(source, kind, data) -> int / unregister_stimulus(id) / stimulus(id)
##   zone_kinds_at(pos) -> Array[int] (MapZone.Kind) / in_zone(pos, kind) -> bool
##   has_los(from, to, exclude) -> bool        -> vision ray on world/vision-blocker layers
##   make_noise(...) is HeistRuntime.make_noise; this director listens to runtime.noise_made.
## Observer protocol (NpcBase, SecurityCamera): see game/systems/stealth/README.md.
##
## Server only: meters tick at StealthTweak.tick_hz with observers staggered across physics frames
## (architecture.md §10); each observer integrates its own elapsed time. detection_progress goes to
## EventBus for the local crew member and by targeted RPC to the owning peer of a remote human
## (events.md); never for AI crew.
class_name StealthDirector
extends Node

signal crew_detected(observer: Node, crew: Node)
signal stimulus_noticed(observer: Node, stimulus_id: int)
## Server: a camera saw the crew and its S3.5 countdown started (BarkDirector: Mercer's camera_spotted line).
signal camera_countdown_started(camera_net_id: int, seconds: float)

## Physics layers that block vision: world_static(1), world_dynamic(2), vision_blockers(8).
const VISION_MASK: int = (1 << 0) | (1 << 1) | (1 << 7)
## MapZone layer "triggers" (10).
const TRIGGER_MASK: int = 1 << 9
## D-128 fill rate (progress per second) reported for PD2's instant uncover.
const INSTANT_RATE: float = 1000.0
const _PRESET_BY_KIND: Dictionary = {
	Enums.ObserverKind.GUARD: &"guard", Enums.ObserverKind.CIVILIAN: &"civilian",
	Enums.ObserverKind.CAMERA: &"camera", Enums.ObserverKind.POLICE: &"police",
}

var alarm_reason: StringName = &""
var alarm_raised: bool = false

var _runtime: HeistRuntime = null
var _tw: StealthTweak = null
var _next_stimulus_id: int = 1
## id -> { "id", "kind", "source" (Node3D), "data" }
var _stimuli: Dictionary[int, Dictionary] = {}
## observer instance id -> state.
var _states: Dictionary[int, StealthObserverState] = {}
var _observer_list: Array[StealthObserverState] = []
var _crew_list: Array[CrewController] = []
## Physics time accumulated by this director (s) and physics frame counter.
var _time: float = 0.0
var _frame: int = 0
var _refresh_stamp: int = 0
## Per-frame cache of crew zone masks (bit = MapZone.Kind).
var _zone_cache: Dictionary[int, int] = {}
var _zone_cache_frame: Dictionary[int, int] = {}
## S3.5 camera countdown (s left, -1 = none) and the camera that started it.
var _camera_left: float = -1.0
var _camera_source_id: int = 0
var _ray_q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _point_q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
var _exclude: Array[RID] = []
var _notice_buf: Array[int] = []
## S2.9 marks (A2-05): target net_id -> {"node", "kind", "left", "by_slot"}; per-slot Sixth Sense
## stand-still seconds.
var _marks: Dictionary[int, Dictionary] = {}
var _still_s: Dictionary[int, float] = {}
## D-118 per-physics-frame gadget emission of each crew member (slot -> _gadget_emission() result).
var _gadget_cache: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	_tw = Tweak.stealth()
	_ray_q.collision_mask = VISION_MASK
	_point_q.collide_with_areas = true
	_point_q.collide_with_bodies = false
	_point_q.collision_mask = TRIGGER_MASK
	_runtime = HeistRuntime.of(self)
	if _runtime != null:
		_runtime.noise_made.connect(_on_noise)
		ShoutSystem.ensure.call_deferred(_runtime)  # A2-05 S2.9: marking works without civilians
	EventBus.alarm_raised.connect(_on_alarm_event)


func _exit_tree() -> void:
	if EventBus.alarm_raised.is_connected(_on_alarm_event):
		EventBus.alarm_raised.disconnect(_on_alarm_event)


func is_stealth() -> bool:
	if alarm_raised or _runtime == null:
		return false
	return _runtime.phase == Enums.HeistPhase.CASING or _runtime.phase == Enums.HeistPhase.STEALTH


## Server: the alarm. Idempotent; HeistRuntime switches to LOUD on alarm_raised.
func raise_alarm(reason: StringName, source_net_id: int = 0) -> void:
	if not Net.is_authority() or alarm_raised:
		return
	alarm_raised = true
	alarm_reason = reason
	Log.info(&"stealth", "ALARM: %s (source %d)" % [reason, source_net_id])
	EventBus.alarm_raised.emit(reason, source_net_id)
	Net.replicate_event(&"alarm_raised", [reason, source_net_id])


## Meter of `observer` on crew `slot` (0..1, 0 if none). Server.
func detection_value(observer: Node, slot: int) -> float:
	if observer == null or not is_instance_valid(observer):
		return 0.0
	var st: StealthObserverState = _states.get(observer.get_instance_id())
	if st == null:
		return 0.0
	return st.meters.get(slot, 0.0)


## HUD model rows for crew `slot` (server; clients get detection_progress instead). ui_hud v1.17 (D-128):
## each row carries `state` (&"" / &"curious" / &"investigating", the observer's S3.4 AlertState), and an
## observer that is CURIOUS or INVESTIGATING with no meter on `slot` still gets a row at value 0 while the
## crew member is in its view or within its stealth detection range, so the HUD can show its "?".
func detection_entries(slot: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var crew: CrewController = _runtime.crew_controller(slot) as CrewController if _runtime != null else null
	for iid: int in _states:
		var st: StealthObserverState = _states[iid]
		if not is_instance_valid(st.node):
			continue
		var state: StringName = _hud_state(st.node)
		var value: float = st.meters.get(slot, -1.0)
		if value < 0.0:
			if state == &"" or crew == null or not is_instance_valid(crew) or not _hud_in_range(st, crew):
				continue
			value = 0.0
		out.append({
			"observer_net_id": NetIds.of(st.node), "world_pos": st.node.global_position,
			"value": value, "kind": st.kind, "state": state,
		})
	return out


## ui_hud v1.17: &"curious" / &"investigating" for an observer in that AlertState, else &"".
static func _hud_state(n: Node) -> StringName:
	var s: Variant = n.get(&"alert_state")
	if s == null:
		return &""
	match int(s):
		Enums.AlertState.CURIOUS:
			return &"curious"
		Enums.AlertState.INVESTIGATING:
			return &"investigating"
	return &""


## ui_hud v1.17: `crew` is within `st`'s PD2 stealth range (S2.2, its stance and DR) or in its view with sight.
func _hud_in_range(st: StealthObserverState, crew: CrewController) -> bool:
	var eye: Vector3 = _eye(st.node)
	var target: Vector3 = crew.global_position + Vector3.UP * minf(1.0, crew.eye_height())
	var c: float = maxf(detection_risk_mult(float(_detection_risk(crew))), 0.001)
	if eye.distance_to(target) <= _pd2_range(st, _attention(st, crew.crouched), c):
		return true
	return _view_angle(st, eye, _forward(st.node), target) < st.half_fov_rad and _crew_visible(st, crew, eye)


## D-128 PD2 formula alone (no sight ray, no S1.1 rules, no modifiers): seconds for an observer with preset
## `preset_key` to take its meter from empty to full on a masked crew member at DR `dr`, `d` m from its eye and
## `angle_deg` off its view axis. 0 = instant (PD2 uncover), INF = it cannot notice from there.
func fill_time(preset_key: StringName, dr: float, d: float, angle_deg: float, crouched: bool = false) -> float:
	var st: StealthObserverState = StealthObserverState.new()
	var kind: int = Enums.ObserverKind.CAMERA if preset_key == &"camera" else Enums.ObserverKind.GUARD
	st.setup(null, kind, _tw.observer_presets.get(preset_key, {}))
	var c: float = maxf(detection_risk_mult(dr), 0.001)
	var delay: float = _pd2_delay(st, c, d, deg_to_rad(angle_deg), crouched, true)
	return INF if delay < 0.0 else delay


## Instantaneous S2.2 fill rate of `observer` on `crew`: meter progress per second (D-128: 1 / PD2 delay,
## so the fill time is 1 / rate; INSTANT_RATE for PD2's uncover); 0 when it cannot fill.
func fill_rate(observer: Node, crew: CrewController) -> float:
	var n3: Node3D = observer as Node3D
	if n3 == null or crew == null or not _observer_active(n3):
		return 0.0
	var st: StealthObserverState = _states.get(n3.get_instance_id())
	if st == null:
		st = _make_state(n3)
	return _fill_rate(st, crew, _eye(n3), _forward(n3))


## S2.3: PD2 DR -> time multiplier, linearly interpolated between table points, clamped at the ends.
func detection_risk_mult(dr: float) -> float:
	var t: PackedVector2Array = _tw.dr_table
	if t.is_empty():
		return 1.0
	if dr <= t[0].x:
		return t[0].y
	for i: int in range(1, t.size()):
		if dr <= t[i].x:
			var a: Vector2 = t[i - 1]
			var b: Vector2 = t[i]
			return lerpf(a.y, b.y, (dr - a.x) / maxf(b.x - a.x, 0.001))
	return t[t.size() - 1].y


## S3.5: seconds left before the camera alarm (cannot be stopped), -1 if none is running.
func camera_countdown() -> float:
	return _camera_left


## A2-02 S4.4: a camera confirmed a stimulus (corpse, bag, broken camera...): start the S3.5
## countdown (no-op if one runs, loud, or not the server).
func start_camera_alarm(camera_net_id: int) -> void:
	if Net.is_authority() and is_stealth():
		_start_camera_countdown(camera_net_id)


# --- Stimuli ------------------------------------------------------------------------

## Register something suspicious (S4.1). `data` may carry "position" for sources without a node
## and "hidden": true while it must not be noticed (e.g. bag in a BODY_HIDE zone).
func register_stimulus(source: Node3D, kind: StringName, data: Dictionary = {}) -> int:
	var id: int = _next_stimulus_id
	_next_stimulus_id += 1
	_stimuli[id] = {"id": id, "kind": kind, "source": source, "data": data}
	return id


func unregister_stimulus(id: int) -> void:
	_stimuli.erase(id)
	for iid: int in _states:
		_states[iid].stimulus_meters.erase(id)
		_states[iid].noticed.erase(id)


func stimulus(id: int) -> Dictionary:
	return _stimuli.get(id, {})


func stimuli() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: int in _stimuli:
		out.append(_stimuli[id])
	return out


## World position of a stimulus (source node or data.position).
func stimulus_position(id: int) -> Vector3:
	return _stim_pos(_stimuli.get(id, {}))


# --- Spatial queries --------------------------------------------------------------------

func zone_kinds_at(pos: Vector3) -> Array[int]:
	var out: Array[int] = []
	var mask: int = _zone_mask_at(pos)
	for k: int in MapZone.Kind.values():
		if mask & (1 << k) != 0:
			out.append(k)
	return out


func in_zone(pos: Vector3, kind: int) -> bool:
	return _zone_mask_at(pos) & (1 << kind) != 0


func has_los(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, VISION_MASK)
	q.exclude = exclude
	return space.intersect_ray(q).is_empty()


# --- Tick -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"stealth_director", fp)


func _physics_step(delta: float) -> void:
	_time += delta
	_frame += 1
	_tick_camera_countdown(delta)
	_tick_marks(delta)  # A2-05 S2.9 (runs loud too: specials stay markable)
	if not Net.is_authority():
		return
	if not is_stealth():
		if not _states.is_empty():
			_clear_all()  # S11.2: no stealth processing once loud
		return
	var buckets: int = maxi(1, roundi(float(Engine.physics_ticks_per_second) / maxf(_tw.tick_hz, 0.1)))
	var bucket: int = _frame % buckets
	if bucket == 0 or _observer_list.is_empty():
		_refresh_lists()
	for i: int in range(bucket, _observer_list.size(), buckets):
		_tick_observer(_observer_list[i])


func _refresh_lists() -> void:
	_refresh_stamp += 1
	_observer_list.clear()
	for n: Node in get_tree().get_nodes_in_group(G.OBSERVER):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.has_method(&"eye_position"):
			continue
		if _runtime != null and not _runtime.is_ancestor_of(n3):
			continue
		var iid: int = n3.get_instance_id()
		var st: StealthObserverState = _states.get(iid)
		if st == null:
			st = _make_state(n3)
			st.last_time = _time - 1.0 / maxf(_tw.tick_hz, 0.1)
			_states[iid] = st
		st.seen_stamp = _refresh_stamp
		_observer_list.append(st)
	for iid: int in _states.keys():
		if _states[iid].seen_stamp != _refresh_stamp:
			_clear_state(_states[iid])
			_states.erase(iid)
	_crew_list = _runtime.crew_members() if _runtime != null else ([] as Array[CrewController])


func _make_state(n3: Node3D) -> StealthObserverState:
	var kind: int = int(n3.call(&"observer_kind")) if n3.has_method(&"observer_kind") else Enums.ObserverKind.GUARD
	var key: StringName = _PRESET_BY_KIND.get(kind, &"guard")
	var p: Variant = n3.get(&"detection_preset")
	if (p is StringName or p is String) and _tw.observer_presets.has(StringName(p)):
		key = StringName(p)
	var preset: Dictionary = _tw.observer_presets.get(key, {})
	if n3.has_method(&"detection_overrides"):  # A2-02 S8.1: per-camera fov_deg / range (far)
		preset = preset.duplicate()
		preset.merge(n3.call(&"detection_overrides"), true)
	var st: StealthObserverState = StealthObserverState.new()
	st.setup(n3, kind, preset)
	return st


func _tick_observer(st: StealthObserverState) -> void:
	if not is_instance_valid(st.node):
		return
	var dt: float = clampf(_time - st.last_time, 0.0, _tw.max_tick_dt_s)
	st.last_time = _time
	if dt <= 0.0:
		return
	if not _observer_active(st.node):
		_clear_state(st)
		return
	var eye: Vector3 = _eye(st.node)
	var fwd: Vector3 = _forward(st.node)
	for crew: CrewController in _crew_list:
		if is_instance_valid(crew):
			_tick_meter(st, crew, eye, fwd, dt)
	if is_instance_valid(st.node) and is_stealth():
		_tick_stimuli(st, eye, fwd, dt)


# --- Detection meters (S2.1, S2.2) -------------------------------------------------------

func _tick_meter(st: StealthObserverState, crew: CrewController, eye: Vector3, fwd: Vector3, dt: float) -> void:
	var slot: int = crew.slot
	if st.spotted.has(slot):
		return  # S2.1: stays at 1.0
	var cur: float = st.meters.get(slot, 0.0)
	var rate: float = _fill_rate(st, crew, eye, fwd)
	# S2.1 / D-128: the meter shows PD2's notice progress p (0..1) through the suspicion HUD offset
	# (playermovement _feed_suspicion_to_hud: shown = p x (1 - offset) + offset, offset = DR / 100), so it
	# appears at DR/100 and p, not the shown value, sets the fill time (1 / rate) and the drain.
	var offset: float = clampf(float(_detection_risk(crew)) / 100.0, 0.0, 0.99)
	var v: float = 0.0
	if rate > 0.0:
		v = minf(1.0, maxf(cur, offset) + rate * (1.0 - offset) * dt)
	elif cur > 0.0:
		var drain: float = 1.0 / maxf(st.delay_max, 0.001) if st.is_camera() else _tw.npc_decay_per_s
		v = cur - drain * (1.0 - offset) * dt
		if v <= offset:
			v = 0.0  # PD2: progress below 0 drops the attention object
	if v <= 0.0:
		st.meters.erase(slot)
	else:
		st.meters[slot] = v
	_send_progress(st, crew, v)
	if v >= 1.0:
		_on_full(st, crew)


func _on_full(st: StealthObserverState, crew: CrewController) -> void:
	st.spotted[crew.slot] = true
	crew.set_masked(true)  # S1.2: being detected force-masks
	if st.node.has_method(&"notify_crew_spotted"):
		st.node.call(&"notify_crew_spotted", crew)
	crew_detected.emit(st.node, crew)
	if st.is_camera():
		_start_camera_countdown(NetIds.of(st.node))


## S2.2 rate; 0 when the crew member is not visible / not eligible (S1.1, S2.8, S3.8).
func _fill_rate(st: StealthObserverState, crew: CrewController, eye: Vector3, fwd: Vector3) -> float:
	if not _crew_observable(crew):
		return 0.0
	var rule_mult: float = _rule_mult(st, crew)
	if rule_mult <= 0.0:
		return 0.0
	return maxf(_body_rate(st, crew, eye, fwd, rule_mult), _gadget_rate(st, crew, eye, fwd, rule_mult))


## S2.2 body rate: the crew member's body in view (rule_mult from _rule_mult, > 0). D-128: 1 / PD2 delay.
func _body_rate(st: StealthObserverState, crew: CrewController, eye: Vector3, fwd: Vector3, rule_mult: float) -> float:
	var c: float = maxf(detection_risk_mult(float(_detection_risk(crew))), 0.001)
	var target: Vector3 = crew.global_position + Vector3.UP * minf(1.0, crew.eye_height())
	var d: float = eye.distance_to(target)
	var ang: float = _view_angle(st, eye, fwd, target)
	# S1.1 casing keeps its own rule: PD2's instant uncover applies to masked crew only.
	var delay: float = _pd2_delay(st, c, d, ang, crew.crouched, crew.masked)
	if delay < 0.0 or not _crew_visible(st, crew, eye):
		return 0.0
	var rate: float = INSTANT_RATE if delay <= 0.0 else 1.0 / delay
	return rate * _difficulty_mult() * rule_mult


## D-128 PD2 player attention settings `st` reads for this stance (StealthTweak.attention_settings).
func _attention(st: StealthObserverState, crouched: bool) -> Dictionary:
	return _tw.attention_settings.get(StringName("%s_%s" % [st.attention, "crouch" if crouched else "stand"]), {})


## D-128 PD2 detection range (m): min(far, attention max_range) x sqrt(1 / concealment mult).
func _pd2_range(st: StealthObserverState, att: Dictionary, c: float) -> float:
	var max_range: float = float(att.get("max_range", -1.0))
	return (st.far if max_range < 0.0 else minf(st.far, max_range)) * sqrt(1.0 / c)


## D-128 PD2 notice delay (s) of `st` on a crew member `d` m away, `ang` rad off its view axis, concealment
## multiplier `c` (S2.3); 0 = instant (uncover), -1 = cannot notice (out of range or view). NPCs:
## coplogicbase _angle_and_dis_chk + _upd_attention_obj_detection; cameras: securitycamera.lua.
func _pd2_delay(st: StealthObserverState, c: float, d: float, ang: float, crouched: bool, allow_uncover: bool) -> float:
	var att: Dictionary = _attention(st, crouched)
	var dm: float = d / maxf(_pd2_range(st, att, c), 0.001)
	if dm >= 1.0:
		return -1.0
	var cam: bool = st.is_camera()
	if not cam and allow_uncover and d < float(att.get("uncover_range", 0.0)) \
			and ang < deg_to_rad(_tw.uncover_angle_deg):
		return 0.0
	var half: float = st.half_fov_rad
	if not cam:
		half = lerpf(PI, st.half_fov_rad, clampf((d - _tw.npc_all_round_m) / maxf(_tw.npc_angle_narrow_m, 0.001), 0.0, 1.0))
	if ang >= half:
		return -1.0
	var ang_ref: float = st.half_fov_rad * 2.0 if cam else st.half_fov_rad
	var t: float = (_tw.camera_dis_weight if cam else _tw.npc_dis_weight) * dm \
			+ (_tw.camera_angle_weight if cam else _tw.npc_angle_weight) * minf(ang / maxf(ang_ref, 0.001), 1.0)
	var ndm: float = float(att.get("notice_delay_mul", 1.0))
	return maxf(lerpf(st.delay_min * ndm * c, st.delay_max, t), 0.0)


func _difficulty_mult() -> float:
	if _runtime != null and _runtime.difficulty_def != null:
		return _runtime.difficulty_def.detection_speed_mult
	return 1.0


## Masked: everyone fills at stealth.detection_rate_mult (S1.4, S2.8). Unmasked (casing, S1.1/S3.8):
## civilians never; others only in RESTRICTED or within casing_too_close_m of a guard observer
## (not inside PUBLIC unless casing_too_close_applies_in_public), at casing_rate_mult.
func _rule_mult(st: StealthObserverState, crew: CrewController) -> float:
	if crew.civilian:
		return 0.0  # S1.3: civilians are undetectable (laser grids still trip)
	if crew.masked:
		return Modifiers.mult(crew.slot, &"stealth.detection_rate_mult")
	if st.kind == Enums.ObserverKind.CIVILIAN:
		return 0.0
	var zones: int = _crew_zone_mask(crew)
	var allowed: bool = zones & (1 << MapZone.Kind.RESTRICTED) != 0
	if not allowed and st.kind == Enums.ObserverKind.GUARD \
			and (zones & (1 << MapZone.Kind.PUBLIC) == 0 or _tw.casing_too_close_applies_in_public):
		var a: Vector3 = st.node.global_position
		var b: Vector3 = crew.global_position
		allowed = Vector2(a.x - b.x, a.z - b.z).length() <= _tw.casing_too_close_m
	if not allowed:
		return 0.0
	return _tw.casing_rate_mult * Modifiers.mult(crew.slot, &"stealth.casing_detection_rate_mult")


func _crew_observable(crew: CrewController) -> bool:
	if crew.crew_state != Enums.CrewState.NORMAL:
		return false
	var hidden: Variant = crew.get(&"stealth_hidden")
	return not (hidden is bool and hidden)


func _crew_visible(st: StealthObserverState, crew: CrewController, eye: Vector3) -> bool:
	var top: float = crew.eye_height()
	for h: float in _tw.los_heights:
		if _ray_clear(eye, crew.global_position + Vector3.UP * minf(h, top), st.node, crew):
			return true
	return false


func _detection_risk(crew: CrewController) -> int:
	return crew.loadout.detection_risk if crew.loadout != null else _tw.default_detection_risk


## Angle between the view centre and `target`: horizontal sector for NPCs, 3D cone for cameras (S2.6).
func _view_angle(st: StealthObserverState, eye: Vector3, fwd: Vector3, target: Vector3) -> float:
	var to: Vector3 = target - eye
	if st.is_camera():
		return fwd.angle_to(to) if to.length_squared() > 0.000001 else 0.0
	var f2: Vector2 = Vector2(fwd.x, fwd.z)
	var t2: Vector2 = Vector2(to.x, to.z)
	if t2.length_squared() < 0.000001 or f2.length_squared() < 0.000001:
		return 0.0
	return absf(f2.angle_to(t2))


func _crew_zone_mask(crew: CrewController) -> int:
	if _zone_cache_frame.get(crew.slot, -1) == _frame:
		return _zone_cache[crew.slot]
	var m: int = _zone_mask_at(crew.global_position + Vector3.UP * _tw.zone_probe_height_m)
	_zone_cache[crew.slot] = m
	_zone_cache_frame[crew.slot] = _frame
	return m


func _zone_mask_at(pos: Vector3) -> int:
	if not is_inside_tree():
		return 0
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	_point_q.position = pos
	var mask: int = 0
	for hit: Dictionary in space.intersect_point(_point_q, 16):
		var z: MapZone = hit.get("collider") as MapZone
		if z != null:
			mask |= 1 << z.kind
	return mask


# --- Weapon gadgets (D-118) ----------------------------------------------------------------
# PD2: a visible flashlight cone or laser beam/dot gives a crew member away even when the observer cannot
# see the body. It feeds the same S2.1 crew meter (max with the body rate). Only a masked crew member
# (weapon out; casing keeps it holstered) with the equipped weapon's gadget switched on (CrewWeapons
# gadget_on, server state) emits. Ranges come from the resolved weapon params (visual_slots.md v1.3),
# rates and fallbacks from StealthTweak.gadget_*. The emitter is the crew eye along aim_direction().
#   flashlight: observer eye inside the cone (half angle x gadget_light_cone_mult) within
#     gadget_light_range_m with a clear ray from the emitter; guards notice being lit from any side,
#     cameras only with the emitter inside their view cone (D-114 §1).
#   laser: the beam (ray to the first world hit, gadget_laser_range_m) passes within gadget_laser_near_m
#     of the observer's eye at a point inside its view, or its dot lands in view within the preset far
#     range; both need a clear ray from the eye.

func _gadget_rate(st: StealthObserverState, crew: CrewController, eye: Vector3, fwd: Vector3, rule_mult: float) -> float:
	if not crew.masked:
		return 0.0
	var e: Dictionary = _gadget_emission(crew)
	if e.is_empty():
		return 0.0
	var r: float = 0.0
	if bool(e["light"]):
		r = _light_rate(st, crew, e, eye, fwd)
	if bool(e["laser"]):
		r = maxf(r, _laser_rate(st, crew, e, eye, fwd))
	return r * _difficulty_mult() * rule_mult


## Cached per physics frame; {} when the crew member emits nothing.
func _gadget_emission(crew: CrewController) -> Dictionary:
	var w: CrewWeapons = crew.weapons
	if w == null or crew.civilian or not w.gadget_on(w.equipped_slot):
		return {}
	var cached: Dictionary = _gadget_cache.get(crew.slot, {})
	if int(cached.get("frame", -1)) == _frame:
		return cached
	var ws: int = w.equipped_slot
	var kinds: Array[StringName] = w.toggle_gadgets(ws)
	var p: Dictionary = SpecialWeapons.params_for(crew, ws)
	var origin: Vector3 = crew.eye_position()
	var dir: Vector3 = crew.aim_direction().normalized()
	var light_half: float = deg_to_rad(float(p.get("gadget_light_angle_deg", _tw.gadget_light_angle_deg)) * 0.5)
	var e: Dictionary = {
		"frame": _frame, "origin": origin, "dir": dir,
		"light": kinds.has(&"flashlight"), "laser": kinds.has(&"laser"),
		"light_range": float(p.get("gadget_light_range_m", _tw.gadget_light_range_m)),
		"light_cos": cos(clampf(light_half * _tw.gadget_light_cone_mult, 0.0, PI)),
		"laser_end": origin, "laser_dot": false,
	}
	if bool(e["laser"]):
		var range_m: float = float(p.get("gadget_laser_range_m", _tw.gadget_laser_range_m))
		_exclude.clear()
		_exclude.append(crew.get_rid())
		_ray_q.from = origin
		_ray_q.to = origin + dir * range_m
		_ray_q.exclude = _exclude
		var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(_ray_q)
		e["laser_end"] = hit["position"] if not hit.is_empty() else _ray_q.to
		e["laser_dot"] = not hit.is_empty()
	_gadget_cache[crew.slot] = e
	return e


func _light_rate(st: StealthObserverState, crew: CrewController, e: Dictionary, eye: Vector3, fwd: Vector3) -> float:
	var origin: Vector3 = e["origin"]
	var range_m: float = e["light_range"]
	var to: Vector3 = eye - origin
	var d: float = to.length()
	if d > range_m or d < 0.001 or (e["dir"] as Vector3).dot(to / d) < float(e["light_cos"]):
		return 0.0
	if st.is_camera() and _view_angle(st, eye, fwd, origin) > st.half_fov_rad:
		return 0.0
	if not _ray_clear(origin, eye, st.node, crew):
		return 0.0
	var dist_f: float = clampf(1.0 - d / maxf(range_m, 0.001), _tw.dist_factor_min, 1.0)
	return st.base_rate * _tw.gadget_light_detect_mult * dist_f


func _laser_rate(st: StealthObserverState, crew: CrewController, e: Dictionary, eye: Vector3, fwd: Vector3) -> float:
	var origin: Vector3 = e["origin"]
	var end: Vector3 = e["laser_end"]
	var seg: Vector3 = end - origin
	var seg_len: float = seg.length()
	if seg_len < 0.001:
		return 0.0
	var dir: Vector3 = seg / seg_len
	var near_m: float = _tw.gadget_laser_near_m
	# The beam near the eye: the closest point and the far end of the chord inside near_m.
	var tc: float = clampf((eye - origin).dot(dir), 0.0, seg_len)
	var miss: float = eye.distance_to(origin + dir * tc)
	if miss <= near_m:
		var t_exit: float = minf(seg_len, tc + sqrt(maxf(near_m * near_m - miss * miss, 0.0)))
		for t: float in [tc, t_exit]:
			if _gadget_point_seen(st, crew, eye, fwd, origin + dir * t, near_m * 0.1):
				return st.base_rate * _tw.gadget_laser_detect_mult
	if bool(e["laser_dot"]):
		var d: float = eye.distance_to(end)
		if d <= st.far and _gadget_point_seen(st, crew, eye, fwd, end, 0.0):
			var near: float = _tw.gadget_near_m
			var dist_f: float = clampf(1.0 - (d - near) / maxf(st.far - near, 0.001), _tw.dist_factor_min, 1.0)
			return st.base_rate * _tw.gadget_laser_detect_mult * dist_f
	return 0.0


## `pt` is inside the observer's view (or within `any_dir_m` of its eye) with a clear ray (stopping
## gadget_los_pullback_m short of `pt`, so the surface a dot sits on does not block it).
func _gadget_point_seen(st: StealthObserverState, crew: CrewController, eye: Vector3, fwd: Vector3, pt: Vector3,
		any_dir_m: float) -> bool:
	var to: Vector3 = pt - eye
	var d: float = to.length()
	if d > any_dir_m and _view_angle(st, eye, fwd, pt) > st.half_fov_rad:
		return false
	if d <= _tw.gadget_los_pullback_m:
		return true
	return _ray_clear(eye, pt - to / d * _tw.gadget_los_pullback_m, st.node, crew)


# --- Replication (events.md detection_progress) -------------------------------------------

func _send_progress(st: StealthObserverState, crew: CrewController, v: float) -> void:
	if crew.is_ai:
		return
	var prev: float = st.sent.get(crew.slot, 0.0)
	if absf(prev - v) < _tw.progress_send_epsilon and not (v <= 0.0 and prev > 0.0) and not (v >= 1.0 and prev < 1.0):
		return
	if v <= 0.0:
		st.sent.erase(crew.slot)
	else:
		st.sent[crew.slot] = v
	var oid: int = NetIds.of(st.node) if is_instance_valid(st.node) else 0
	if crew.peer_id == Net.local_peer_id():
		EventBus.detection_progress.emit(oid, crew.slot, v, st.kind)
	elif crew.peer_id != 0:
		_rpc_detection_progress.rpc_id(crew.peer_id, oid, crew.slot, v, st.kind)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_detection_progress(observer_net_id: int, crew_slot: int, value: float, kind: int) -> void:
	EventBus.detection_progress.emit(observer_net_id, crew_slot, value, kind)


func _clear_state(st: StealthObserverState) -> void:
	for slot: int in st.sent.keys():
		var crew: CrewController = _runtime.crew_controller(slot) as CrewController if _runtime != null else null
		if crew != null:
			_send_progress(st, crew, 0.0)
	st.sent.clear()
	st.meters.clear()
	st.spotted.clear()
	st.stimulus_meters.clear()


func _clear_all() -> void:
	for iid: int in _states:
		_clear_state(_states[iid])
	_states.clear()
	_observer_list.clear()
	_crew_list.clear()


# --- Stimuli (S4.1, S4.4, S6.3) --------------------------------------------------------------

func _tick_stimuli(st: StealthObserverState, eye: Vector3, fwd: Vector3, dt: float) -> void:
	_notice_buf.clear()
	for id: int in _stimuli:
		if st.noticed.has(id):
			continue
		var s: Dictionary = _stimuli[id]
		var preset: Dictionary = _tw.stimuli.get(s["kind"], {})
		var cur: float = st.stimulus_meters.get(id, 0.0)
		if not preset.is_empty() and _stimulus_in_view(st, s, preset, eye, fwd):
			cur += dt / maxf(float(preset.get("fill_time", 1.0)), 0.001)
		else:
			cur -= _tw.decay_per_s * dt
		if cur <= 0.0:
			st.stimulus_meters.erase(id)
		elif cur >= 1.0:
			st.stimulus_meters.erase(id)
			_notice_buf.append(id)
		else:
			st.stimulus_meters[id] = cur
	for id: int in _notice_buf:
		if not _stimuli.has(id) or not is_instance_valid(st.node):
			continue
		st.noticed[id] = true
		if st.node.has_method(&"notify_stimulus"):
			st.node.call(&"notify_stimulus", id, StringName(_stimuli[id]["kind"]), stimulus_position(id))
		stimulus_noticed.emit(st.node, id)


func _stimulus_in_view(st: StealthObserverState, s: Dictionary, preset: Dictionary, eye: Vector3, fwd: Vector3) -> bool:
	if st.is_camera() and not bool(preset.get("camera", false)):
		return false  # S4.4
	var src: Node3D = _stim_source(s)
	if not _stimulus_eligible(st, s, src):
		return false
	var pos: Vector3 = _stim_pos(s)
	if pos == Vector3.INF or eye.distance_to(pos) > float(preset.get("range", 0.0)):
		return false
	if not bool(preset.get("los", true)) and not st.is_camera():
		return true  # drills: NPCs notice them in range, even out of sight (S4.1 / S4.3)
	# PO6-04 (D-114 §1, overrides the S4.4 "drills even outside their view" clause): cameras react only to
	# what they SEE, so a camera needs the stimulus inside its cone with a clear ray, drills included.
	var target: Vector3 = pos + Vector3.UP * _tw.stimulus_los_height_m
	return _view_angle(st, eye, fwd, target) <= st.half_fov_rad and _ray_clear(eye, target, st.node, src)


func _stimulus_eligible(st: StealthObserverState, s: Dictionary, src: Node3D) -> bool:
	var data: Dictionary = s.get("data", {})
	if bool(data.get("hidden", false)):
		return false
	if src == null:
		return data.has("position")
	if src == st.node:
		return false
	var hid: Variant = src.get(&"hidden_from_stealth")
	if hid is bool and hid:
		return false  # S6.3 body bag in a BODY_HIDE zone
	var moved: Variant = src.get(&"moved")
	return not (moved is bool and not moved)  # S4.1 pre-placed bags are ignored until moved


func _stim_source(s: Dictionary) -> Node3D:
	var raw: Variant = s.get("source")
	if raw == null or not is_instance_valid(raw):
		return null
	return raw as Node3D


func _stim_pos(s: Dictionary) -> Vector3:
	var src: Node3D = _stim_source(s)
	if src != null and src.is_inside_tree():
		return src.global_position
	return (s.get("data", {}) as Dictionary).get("position", Vector3.INF)


# --- Cameras (S3.5) ---------------------------------------------------------------------------

func _start_camera_countdown(camera_net_id: int) -> void:
	if _camera_left >= 0.0 or alarm_raised:
		return
	_camera_left = _tw.camera_alarm_delay_s
	_camera_source_id = camera_net_id
	Log.info(&"stealth", "camera alert: alarm in %.1f s" % _camera_left)
	_rpc_camera_countdown.rpc(_camera_left)
	camera_countdown_started.emit(camera_net_id, _camera_left)


@rpc("authority", "call_remote", "reliable")
func _rpc_camera_countdown(seconds_left: float) -> void:
	_camera_left = seconds_left


func _tick_camera_countdown(delta: float) -> void:
	if _camera_left < 0.0:
		return
	_camera_left = maxf(0.0, _camera_left - delta)
	if _camera_left <= 0.0 and Net.is_authority():
		_camera_left = -1.0
		raise_alarm(&"camera", _camera_source_id)  # cannot be stopped (S3.5)


func _on_alarm_event(reason: StringName, _source_net_id: int) -> void:
	_camera_left = -1.0
	if not Net.is_authority():  # A3-07: clients mirror the relayed alarm (is_stealth() turns false)
		alarm_raised = true
		alarm_reason = reason


# --- Helpers ----------------------------------------------------------------------------------

func _observer_active(n3: Node3D) -> bool:
	if not is_instance_valid(n3) or not n3.is_inside_tree():
		return false
	return not n3.has_method(&"can_observe") or bool(n3.call(&"can_observe"))


func _eye(n3: Node3D) -> Vector3:
	return n3.call(&"eye_position") if n3.has_method(&"eye_position") else n3.global_position


func _forward(n3: Node3D) -> Vector3:
	if n3.has_method(&"look_forward"):
		return n3.call(&"look_forward")
	return -n3.global_transform.basis.z


func _ray_clear(from: Vector3, to: Vector3, a: Node, b: Node) -> bool:
	_exclude.clear()
	var ca: CollisionObject3D = a as CollisionObject3D
	if ca != null:
		_exclude.append(ca.get_rid())
	var cb: CollisionObject3D = b as CollisionObject3D
	if cb != null:
		_exclude.append(cb.get_rid())
	_ray_q.from = from
	_ray_q.to = to
	_ray_q.exclude = _exclude
	return get_viewport().world_3d.direct_space_state.intersect_ray(_ray_q).is_empty()


# --- Noise (S4.3) -------------------------------------------------------------------------

## Server: deliver a NoiseEvent to every listening NPC within `radius` (× noise_no_los_mult without
## LOS from the noise to the listener's eye). Cameras do not hear (S4.4). Stealth only.
func _on_noise(position: Vector3, radius: float, kind: StringName, source_net_id: int) -> void:
	if not Net.is_authority() or not is_stealth() or radius <= 0.0:
		return
	var src: Node = Ids.lookup(source_net_id) if source_net_id != 0 else null
	for n: Node in get_tree().get_nodes_in_group(G.OBSERVER):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.has_method(&"notify_noise") or not _observer_active(n3):
			continue
		if n3.has_method(&"observer_kind") and int(n3.call(&"observer_kind")) == Enums.ObserverKind.CAMERA:
			continue
		if _runtime != null and not _runtime.is_ancestor_of(n3):
			continue
		var eye: Vector3 = _eye(n3)
		var d: float = position.distance_to(eye)
		if d > radius:
			continue
		if d > radius * _tw.noise_no_los_mult and not _ray_clear(position, eye, n3, src):
			continue
		n3.call(&"notify_noise", position, kind, source_net_id)


# --- Marking (S2.9, A2-05) --------------------------------------------------------------------
# A guard, special or camera marked by a crew member (ShoutSystem: shout while aiming at it; or
# Sixth Sense) is shown to the whole crew for StealthTweak.mark_duration_<kind>_s ×
# Modifiers stealth.mark_duration_mult of the marker. Server-authoritative; clients get
# _rpc_mark and tick their own copy for LocalHudModel.

## Mark kind of `target` (&"guard", &"special", &"camera"), or &"" when it cannot be marked.
static func mark_kind_of(target: Node) -> StringName:
	var npc: NpcBase = target as NpcBase
	if npc != null:
		if not npc.alive:
			return &""
		if npc.role == &"guard" or npc.role == &"special":
			return npc.role
		return &""
	if target != null and target.has_method(&"observer_kind") \
			and int(target.call(&"observer_kind")) == Enums.ObserverKind.CAMERA:
		var destroyed: Variant = target.get(&"destroyed")
		return &"" if destroyed is bool and destroyed else &"camera"
	return &""


## Server: mark `target` for the crew (refreshes a running mark). Returns false if not markable.
func mark(target: Node3D, by_slot: int) -> bool:
	if not Net.is_authority() or target == null or not is_instance_valid(target):
		return false
	var kind: StringName = mark_kind_of(target)
	var nid: int = NetIds.of(target)
	if kind == &"" or nid == 0:
		return false
	var dur: float = _mark_base_s(kind) * Modifiers.mult(by_slot, &"stealth.mark_duration_mult")
	_marks[nid] = {"node": target, "kind": kind, "left": dur, "by_slot": by_slot}
	_rpc_mark.rpc(nid, kind, dur)
	return true


func is_marked(target: Node) -> bool:
	return target != null and _marks.has(NetIds.of(target))


## LocalHudModel (ui_hud.md v1.1): crew-wide marks [{net_id, world_pos, kind}] sorted by net_id.
## Every crew slot sees every mark (`slot` is accepted for the duck-typed HUD interface).
func marked_targets(_slot: int = -1) -> Array[Dictionary]:
	var ids: Array[int] = []
	ids.assign(_marks.keys())
	ids.sort()
	var out: Array[Dictionary] = []
	for nid: int in ids:
		var m: Dictionary = _marks[nid]
		var n: Node3D = m.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			n = Ids.lookup(nid) as Node3D
		var pos: Vector3 = n.global_position if n != null and n.is_inside_tree() else Vector3.ZERO
		out.append({"net_id": nid, "world_pos": pos, "kind": StringName(m["kind"])})
	return out


func _mark_base_s(kind: StringName) -> float:
	match kind:
		&"camera":
			return _tw.mark_duration_camera_s
		&"special":
			return _tw.mark_duration_special_s
	return _tw.mark_duration_guard_s


@rpc("authority", "call_remote", "reliable")
func _rpc_mark(net_id: int, kind: StringName, duration: float) -> void:
	_marks[net_id] = {"node": Ids.lookup(net_id), "kind": kind, "left": duration, "by_slot": -1}


func _tick_marks(delta: float) -> void:
	for nid: int in _marks.keys():
		var m: Dictionary = _marks[nid]
		var left: float = float(m["left"]) - delta
		var n: Node = m.get("node") as Node if is_instance_valid(m.get("node")) else null
		var gone: bool = Net.is_authority() and (n == null or mark_kind_of(n) == &"")
		if left <= 0.0 or gone:
			_marks.erase(nid)
		else:
			m["left"] = left
	if Net.is_authority() and is_stealth():
		_tick_sixth_sense(delta)


## S2.9 Sixth Sense (`stealth.sixth_sense`): standing still sixth_sense_still_s in stealth marks
## every guard/special within sixth_sense_radius_m (no LOS needed), again every sixth_sense_still_s.
func _tick_sixth_sense(delta: float) -> void:
	if _runtime == null:
		return
	for crew: CrewController in _runtime.crew_members():
		var slot: int = crew.slot
		if not Modifiers.flag(slot, &"stealth.sixth_sense") or crew.crew_state != Enums.CrewState.NORMAL:
			_still_s.erase(slot)
			continue
		if Vector2(crew.velocity.x, crew.velocity.z).length() > _tw.sixth_sense_still_speed:
			_still_s[slot] = 0.0
			continue
		var t: float = _still_s.get(slot, 0.0) + delta
		if t >= _tw.sixth_sense_still_s:
			t = 0.0
			for n: Node in _runtime.npcs():
				var n3: Node3D = n as Node3D
				if n3 != null and n3.global_position.distance_to(crew.global_position) <= _tw.sixth_sense_radius_m:
					mark(n3, slot)
		_still_s[slot] = t
