## P-FP-STATES (PD2 L2.5 / L4.3 / L4.4, lead go 2026-10-14): first-person presentation of the crew states and of
## taking a hit, for the LOCAL human only (never a remote crew: third person is AnimDriver's). Presentation only:
## nothing here feeds gameplay. The downed eye height itself is CrewController.eye_height() (the shot origin
## follows the camera); this adds what rides on top of it:
## - DOWNED: a small camera roll; the viewmodel holds the forced secondary lower and canted in;
## - TASED: high-frequency convulsion jitter on camera and viewmodel, knees buckle (camera lower);
## - CLOAKER_DOWNED (Phantom kick, long tase): a kick punch, then the camera falls to the floor rolled onto its
##   side and the viewmodel drops out of view;
## - a hit (EventBus.damage_applied, victim = this crew, amount > 0): a critically damped camera punch, health
##   hits larger than armor hits, rolled away from the side the hit came from.
## Reduce Motion: no hit punch or roll, the tase jitter at CrewTweak.fp_reduce_motion_mult; heights stay.
## Owner: ENV P.
class_name CrewFpStates
extends RefCounted

## Camera offsets this tick: y (m, added to the head height), rot (radians: pitch, yaw, roll).
var cam_dy: float = 0.0
var cam_rot: Vector3 = Vector3.ZERO
## Viewmodel offsets this tick (camera space, m) and rotation (degrees: pitch, yaw, roll).
var vm_offset: Vector3 = Vector3.ZERO
var vm_rot_deg: Vector3 = Vector3.ZERO
## Eased 0..1 weights per state (tests read them).
var w_down: float = 0.0
var w_tase: float = 0.0
var w_kick: float = 0.0

var _crew: CrewController = null
var _t: float = 0.0
var _phase: Vector3 = Vector3.ZERO
var _hit_t: float = -1.0
var _hit_amp: Vector2 = Vector2.ZERO  # (pitch, roll) radians
var _kick_t: float = -1.0


func _init(crew: CrewController) -> void:
	_crew = crew
	var rng: RandomNumberGenerator = GameRng.stream(&"fp_states")
	_phase = Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))
	if not EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.connect(_on_damage)
	crew.crew_state_changed.connect(_on_state_changed)


func disconnect_all() -> void:
	if EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.disconnect(_on_damage)


func _on_state_changed(_old: int, new_state: int) -> void:
	if new_state == Enums.CrewState.CLOAKER_DOWNED:
		_kick_t = 0.0


func _on_damage(victim_net_id: int, _attacker_net_id: int, info: Dictionary) -> void:
	if _crew == null or not is_instance_valid(_crew) or victim_net_id != _crew.net_id or not _crew.is_local():
		return
	var amount: float = float(info.get("amount", 0.0))
	if amount <= 0.0:
		return
	var tw: CrewTweak = Tweak.crew()
	var health: bool = float(info.get("health_damage", 0.0)) > 0.0
	var deg: float = tw.fp_hit_punch_health_deg if health else tw.fp_hit_punch_armor_deg
	var side: float = 0.0
	var travel: Vector3 = info.get("direction", Vector3.ZERO) as Vector3
	if travel.length_squared() > 0.0001:
		var right: Vector3 = _crew.global_transform.basis.x
		side = signf(travel.normalized().dot(right))  # pushed the way the round travels
	_hit_amp = Vector2(deg_to_rad(deg), -side * deg_to_rad(deg * tw.fp_hit_roll_ratio))
	_hit_t = 0.0


func tick(delta: float, tw: CrewTweak, reduce_motion: bool) -> void:
	_t += delta
	var st: int = _crew.crew_state
	w_down = move_toward(w_down, 1.0 if st == Enums.CrewState.DOWNED else 0.0, delta / maxf(tw.fp_down_ease_s, 0.01))
	w_tase = move_toward(w_tase, 1.0 if st == Enums.CrewState.TASED else 0.0, delta / maxf(tw.fp_tase_ease_s, 0.01))
	var kicked: bool = st == Enums.CrewState.CLOAKER_DOWNED
	var fall: float = delta / maxf(tw.fp_kick_fall_s if kicked else tw.fp_down_ease_s * 1.5, 0.01)
	w_kick = move_toward(w_kick, 1.0 if kicked else 0.0, fall)
	var motion: float = 0.0 if reduce_motion else 1.0
	var kick_e: float = _ease(w_kick)
	var down_e: float = _ease(w_down)
	# camera height: the knee buckle under a tase, the floor after a kick (DOWNED is in eye_height())
	cam_dy = -tw.fp_tase_buckle_m * _ease(w_tase) - maxf(tw.eye_standing - tw.fp_kick_eye_m, 0.0) * kick_e
	var jit: Vector3 = _jitter(tw) * w_tase * (tw.fp_reduce_motion_mult if reduce_motion else 1.0)
	cam_rot = Vector3(
		jit.x + deg_to_rad(tw.fp_kick_pitch_deg) * kick_e,
		jit.y,
		jit.z + (deg_to_rad(tw.fp_down_roll_deg) * down_e + deg_to_rad(tw.fp_kick_roll_deg) * kick_e) * motion)
	cam_rot += _tick_hit(delta, tw) * motion
	cam_rot.x += _tick_kick_punch(delta, tw) * motion
	vm_offset = tw.fp_down_vm_offset * down_e + Vector3(0.0, -tw.fp_kick_vm_drop_m, 0.0) * kick_e
	vm_rot_deg = tw.fp_down_vm_rot_deg * down_e + Vector3(rad_to_deg(jit.x), rad_to_deg(jit.y), rad_to_deg(jit.z)) \
		* tw.fp_tase_vm_mult


## Sum of three incommensurate sines per axis (convulsion, not a wobble), radians at full weight.
func _jitter(tw: CrewTweak) -> Vector3:
	var a: float = deg_to_rad(tw.fp_tase_shake_deg)
	var f: float = tw.fp_tase_shake_hz
	var t: float = _t * TAU * f
	return Vector3(
		a * (0.6 * sin(t + _phase.x) + 0.4 * sin(t * 1.73 + _phase.y)),
		a * 0.7 * (0.6 * sin(t * 1.31 + _phase.y) + 0.4 * sin(t * 2.07 + _phase.z)),
		a * 0.8 * (0.6 * sin(t * 0.89 + _phase.z) + 0.4 * sin(t * 1.57 + _phase.x)))


## Critically damped hit punch x(t) = A * wt * e^(1 - wt) (peak A after 1/w s), as the melee punch.
func _tick_hit(delta: float, tw: CrewTweak) -> Vector3:
	if _hit_t < 0.0:
		return Vector3.ZERO
	_hit_t += delta
	var wt: float = TAU * maxf(tw.fp_hit_punch_hz, 0.01) * _hit_t
	if wt > 12.0:
		_hit_t = -1.0
		return Vector3.ZERO
	var k: float = wt * exp(1.0 - wt)
	return Vector3(_hit_amp.x * k, 0.0, _hit_amp.y * k)


## The kick lands as a sharp upward snap before the fall (pitch, radians).
func _tick_kick_punch(delta: float, tw: CrewTweak) -> float:
	if _kick_t < 0.0:
		return 0.0
	_kick_t += delta
	var wt: float = TAU * maxf(tw.fp_hit_punch_hz, 0.01) * _kick_t
	if wt > 12.0:
		_kick_t = -1.0
		return 0.0
	return deg_to_rad(tw.fp_kick_punch_deg) * wt * exp(1.0 - wt)


static func _ease(w: float) -> float:
	return w * w * (3.0 - 2.0 * w)
