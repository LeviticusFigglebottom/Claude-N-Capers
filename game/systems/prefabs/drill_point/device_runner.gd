## Timed device (drill / thermal drill / saw) state machine shared by DrillPoint and Safe (S9.3,
## S9.4). Owner: ENV A. The owning prefab calls `tick(delta)` from `_physics_process` (server).
## Jams are rolled at placement on GameRng &"devices" (roll_jam_points: 1-2 per device, D-114 §2),
## each kept with probability clamp(interaction.device_jam_chance_mult, 0, 1), placed uniformly in
## device_jam_progress_range at least device_jam_min_gap apart. Auto-restart (chance
## interaction.device_auto_restart_chance) is rolled at placement and on each fix; a successful
## roll restarts the next jam after rand(device_restart_delay_s). While running in stealth it makes
## a NoiseEvent every device_noise_interval_s (drill_radius_m) unless stealth.silent_devices, and
## it is a `drill` stimulus. Events: device_started / jammed / restarted / finished [R].
## Saws (S9.4, kind &"saw") share every rule; their noise is kind &"saw" (StealthTweak.saw_radius_m)
## and they are an extra `saw` stimulus (S4.1: a saw cutting within 10 m).
class_name DeviceRunner
extends RefCounted

signal state_changed(state: int)
signal finished()

enum State { IDLE, RUNNING, JAMMED, DONE }

var state: State = State.IDLE
## &"drill", &"thermal", &"saw".
var kind: StringName = &"drill"
## Effective run time (s) after modifiers.
var duration: float = 0.0
## 0..1.
var progress: float = 0.0
## Remaining jam points (progress fractions, ascending).
var jams: Array[float] = []
var auto_restart: bool = false
## Seconds until an auto-restart, -1 = none pending.
var restart_left: float = -1.0
## Crew slot that placed the device (modifier source).
var slot: int = -1
## B1 Kickstarter: this jam has had its melee try.
var kicked: bool = false

var _owner: GameplayPrefab = null
var _noise_left: float = 0.0
var _stim_id: int = 0
var _saw_stim_id: int = 0


func _init(owner_prefab: GameplayPrefab, device_kind: StringName) -> void:
	_owner = owner_prefab
	kind = device_kind


## Server: the device is placed by `crew_slot`; runs `base_duration` × interaction.device_speed_mult.
func place(crew_slot: int, base_duration: float) -> void:
	if state != State.IDLE:
		return
	slot = crew_slot
	duration = maxf(base_duration * Modifiers.mult(slot, &"interaction.device_speed_mult"), 0.01)
	progress = 0.0
	_roll_jams()
	_roll_restart()
	_owner._emit_fact(&"device_started", [_owner.net_id, kind, duration])
	_set_state(State.RUNNING)


## Server: a crew member fixed the jam.
func fix(crew_slot: int) -> void:
	if state != State.JAMMED:
		return
	_roll_restart()
	_restart(crew_slot)


## Server, B1 `interaction.device_melee_restart` (PD2 Kickstarter): `crew_slot` hit the JAMMED device with melee; one
## try per jam restarts it with InteractionTweak.device_melee_restart_chance (GameRng "devices"). True: restarted.
func kick(crew_slot: int) -> bool:
	if state != State.JAMMED or kicked or not Modifiers.flag(crew_slot, &"interaction.device_melee_restart"):
		return false
	kicked = true
	if GameRng.stream(&"devices").randf() >= Tweak.interaction().device_melee_restart_chance:
		return false
	fix(crew_slot)
	return true


## Server: the target was opened another way while the device runs or is jammed (PO6-04: code / keycard on a
## safe being drilled): stop it. device_finished [R] stops its loop cue (D-114 §3); no done cue, and no `finished`
## signal (nothing more to open).
func abort() -> void:
	if not Net.is_authority() or (state != State.RUNNING and state != State.JAMMED):
		return
	restart_left = -1.0
	jams.clear()
	_owner._emit_fact(&"device_finished", [_owner.net_id])
	_set_state(State.DONE)


## Seconds of running left (excluding jams).
func time_left() -> float:
	return maxf(1.0 - progress, 0.0) * duration


func tick(delta: float) -> void:
	if not Net.is_authority():
		return
	match state:
		State.RUNNING:
			progress = minf(progress + delta / duration, 1.0)
			_tick_noise(delta)
			if not jams.is_empty() and progress >= jams[0] and progress < 1.0:
				jams.pop_front()
				_jam()
			elif progress >= 1.0:
				_finish()
		State.JAMMED:
			if restart_left >= 0.0:
				restart_left -= delta
				if restart_left <= 0.0:
					restart_left = -1.0
					_roll_restart()
					_restart(-1)


## Remove the stimulus (owner leaving the tree). PO6-07 (D-114 §3): a device removed while RUNNING emits
## device_jammed [R], the stop fact of its cue.drill_loop (no device_finished: nothing was opened).
func shutdown() -> void:
	_set_stimulus(false)
	if state == State.RUNNING and Net.is_authority() and is_instance_valid(_owner):
		_owner._emit_fact(&"device_jammed", [_owner.net_id])


func _roll_jams() -> void:
	var chance: float = clampf(Modifiers.mult(slot, &"interaction.device_jam_chance_mult"), 0.0, 1.0)
	jams = roll_jam_points(GameRng.stream(&"devices"), Tweak.interaction(), chance)


## S9.3 / D-114 §2 jam schedule (pure; PO6-02 test runs it over 1000 seeds). Ascending progress
## fractions inside tw.device_jam_progress_range, at least tw.device_jam_min_gap apart.
static func roll_jam_points(rng: RandomNumberGenerator, tw: InteractionTweak, chance: float) -> Array[float]:
	var n: int = tw.device_jams_min
	for i: int in range(tw.device_jams_max - tw.device_jams_min):
		if rng.randf() < tw.device_jam_extra_chance:
			n += 1
	var out: Array[float] = []
	var lo: float = tw.device_jam_progress_range.x
	var hi: float = tw.device_jam_progress_range.y
	for i: int in range(n):
		var keep: bool = rng.randf() < chance
		var at: float = rng.randf_range(lo, hi)
		if not keep:
			continue
		for other: float in out:
			if absf(at - other) < tw.device_jam_min_gap:
				# Push away from the nearer neighbour, inside the range; drop if there is no room.
				at = other + tw.device_jam_min_gap if at >= other else other - tw.device_jam_min_gap
		if at < lo or at > hi or _too_close(out, at, tw.device_jam_min_gap):
			continue
		out.append(at)
	out.sort()
	return out


static func _too_close(points: Array[float], at: float, gap: float) -> bool:
	for p: float in points:
		if absf(at - p) < gap - 0.0001:
			return true
	return false


func _roll_restart() -> void:
	var chance: float = clampf(Modifiers.add(slot, &"interaction.device_auto_restart_chance"), 0.0, 1.0)
	auto_restart = GameRng.stream(&"devices").randf() < chance


func _jam() -> void:
	restart_left = -1.0
	kicked = false
	if auto_restart:
		var r: Vector2 = Tweak.interaction().device_restart_delay_s
		restart_left = GameRng.stream(&"devices").randf_range(r.x, r.y)
	_owner._emit_fact(&"device_jammed", [_owner.net_id])
	_owner._cue(&"cue.drill_jam", _owner.global_position)
	_set_state(State.JAMMED)


func _restart(crew_slot: int) -> void:
	restart_left = -1.0
	_owner._emit_fact(&"device_restarted", [_owner.net_id, crew_slot])
	_set_state(State.RUNNING)


func _finish() -> void:
	_owner._emit_fact(&"device_finished", [_owner.net_id])
	_owner._cue(&"cue.drill_done", _owner.global_position)
	_set_state(State.DONE)
	finished.emit()


func _tick_noise(delta: float) -> void:
	_noise_left -= delta
	if _noise_left > 0.0:
		return
	_noise_left = Tweak.interaction().device_noise_interval_s
	if Modifiers.flag(slot, &"stealth.silent_devices"):
		return
	var rt: HeistRuntime = HeistRuntime.of(_owner)
	var st: StealthDirector = _owner._stealth()
	if rt != null and st != null and st.is_stealth():
		if kind == &"saw":
			rt.make_noise(_owner.global_position, Tweak.stealth().saw_radius_m, &"saw", _owner.net_id)
		else:
			rt.make_noise(_owner.global_position, Tweak.stealth().drill_radius_m, &"drill", _owner.net_id)


func _set_state(s: State) -> void:
	state = s
	if s == State.RUNNING:
		_noise_left = 0.0
		_owner._cue(&"cue.drill_loop", _owner.global_position)
	_set_stimulus(s == State.RUNNING)
	state_changed.emit(s)


func _set_stimulus(on: bool) -> void:
	var st: StealthDirector = _owner._stealth() if is_instance_valid(_owner) else null
	if on and _stim_id == 0 and st != null:
		_stim_id = st.register_stimulus(null, &"drill", {"position": _owner.global_position})
		if kind == &"saw":
			_saw_stim_id = st.register_stimulus(null, &"saw", {"position": _owner.global_position})
	elif not on and _stim_id != 0:
		if st != null:
			st.unregister_stimulus(_stim_id)
			if _saw_stim_id != 0:
				st.unregister_stimulus(_saw_stim_id)
		_stim_id = 0
		_saw_stim_id = 0
