## AnimDriver's turn in place (D-116 follow-up: ENV D turn_l_45 / turn_r_45, 12 f = 0.4 s, root_turn +-45 deg at the
## same 112.5 deg/s as turn_l / turn_r's 90 deg over 0.8 s). Owner: ENV A. Presentation only (the body's yaw is
## gameplay; only the rig under it is counter-rotated). Back-reference `_d` to the driver, like CombatClips.
## A standing body whose yaw left the rig's by:
##   >= AnimTweak.turn_90_min_deg (67.5): turn_l / turn_r (AnimTweak.turn_clip_deg, 90);
##   turn_threshold_deg (20) .. 67.5: turn_l_45 / turn_r_45 (turn_45_clip_deg, 45; a rig without them: turn_l / r);
##   below 20 (the body has stopped turning): no clip, the rig snaps over AnimTweak.turn_snap_s.
## Lead ruling (planted feet over an exact yaw): the clip plays at speed_scale 1 and the rig yaws at the clip's own
## root rate (clip deg / clip length) for the whole clip, so the rig turns exactly the clip's degrees and the feet stay
## planted. The residual (body yaw - rig yaw when the clip ends: |diff| - clip deg, signed, so a 30 deg turn on the
## 45 clip eases back 15 deg) is eased in over the clip's blend-out (AnimTweak.blend_s, smoothstep). A residual
## above AnimTweak.turn_residual_max_deg (22.5, the most the 45 clip leaves) the same way (the body turned on, or
## > 112.5 deg on the 90 clip) starts the next clip instead; the clip's own overshoot (clip deg - |diff| at its start)
## is always eased back, never answered with a reverse clip (a rig without the 45 clips overshoots a 30 deg turn by
## 60). A reverse residual beyond that overshoot (the body turned back during the clip) uses the threshold as usual.
class_name TurnInPlace
extends RefCounted

## Rig yaw rate (rad/s, signed: positive = left) of the running turn clip; seconds of it left (the driver mirrors it
## in _turning_left).
var rate: float = 0.0
var left: float = 0.0
## The clip played for the running turn and its speed_scale (always 1; tests).
var speed: float = 1.0
var turn_clip: StringName = &""
var _d: AnimDriver = null
## Rig yaw rate (rad/s) of the running no-clip snap (0 = none).
var _snap_rate: float = 0.0
## The residual ease after a clip: seconds elapsed and its duration (0 = none).
var _ease_t: float = 0.0
var _ease_dur: float = 0.0
## The finished clip's overshoot (rad, >= 0) and its direction: a reverse residual up to it eases instead of turning.
var _overshoot: float = 0.0
var _dir: float = 0.0


func _init(driver: AnimDriver) -> void:
	_d = driver


## The turn clip for a yaw difference of `diff_deg` (positive = left) and its own turn in degrees: [clip, deg].
func clip_for(diff_deg: float, tw: AnimTweak) -> Array:
	var l: bool = diff_deg > 0.0
	if absf(diff_deg) < tw.turn_90_min_deg:
		var c45: StringName = &"turn_l_45" if l else &"turn_r_45"
		if _d._has_clip(c45):
			return [c45, tw.turn_45_clip_deg]
	return [&"turn_l" if l else &"turn_r", tw.turn_clip_deg]


## Start the turn clip for `diff` (radians, positive = left).
func start(diff: float, tw: AnimTweak) -> void:
	var pick: Array = clip_for(rad_to_deg(diff), tw)
	turn_clip = pick[0]
	var full: String = _d._resolve(turn_clip) if _d.player != null else ""
	var length: float = _d.player.get_animation(full).length if full != "" else tw.turn_time_s
	speed = 1.0
	left = maxf(length, 0.001)
	rate = signf(diff) * deg_to_rad(float(pick[1])) / left
	_dir = signf(diff)
	_overshoot = maxf(deg_to_rad(float(pick[1])) - absf(diff), 0.0)
	_snap_rate = 0.0
	_ease_dur = 0.0
	_d._turning_left = left
	_d.play_oneshot(turn_clip, left, false, speed)


## Whether a turn clip or its residual ease is running (tests).
func busy() -> bool:
	return left > 0.0 or _ease_dur > 0.0


## Cancel a running turn / ease / snap (moving, a pose, an action).
func stop() -> void:
	left = 0.0
	rate = 0.0
	_snap_rate = 0.0
	_ease_dur = 0.0
	_overshoot = 0.0
	_d._turning_left = 0.0


## One driver tick: pick / run the turn and set the rig's counter-yaw (the old AnimDriver._update_turn).
func update(delta: float, tw: AnimTweak) -> void:
	var body: Node3D = _d._body
	var body_yaw: float = body.global_rotation.y if body.is_inside_tree() else body.rotation.y
	if _d.clip == &"":
		# First frame: the spawner places the body after add_child (bind() saw yaw 0): no spawn spin.
		_d._visual_yaw = body_yaw
		_d._prev_body_yaw = body_yaw
	var standing: bool = _d.horizontal_speed() <= tw.move_threshold_mps
	var held: bool = (_d._npc != null and not _d._npc.alive) or _d._interact_kind != &""
	var now: StringName = _d._choose_clip_tick() if standing and not held else &""
	if held:
		pass
	elif not standing or AnimDriver.POSE_CLIPS.has(now) or AnimDriver.ACTION_CLIPS.has(now):
		_d._visual_yaw = body_yaw
		stop()
	else:
		_step(body_yaw, delta, tw)
	_d._prev_body_yaw = body_yaw
	if _d.rig != null:
		var y: float = _d._rig_base_yaw + wrapf(_d._visual_yaw - body_yaw, -PI, PI)
		if y != _d.rig.rotation.y:  # P6 #3: an unchanged write still dirties the whole rig's transforms
			_d.rig.rotation.y = y


func _step(body_yaw: float, delta: float, tw: AnimTweak) -> void:
	var diff: float = wrapf(body_yaw - _d._visual_yaw, -PI, PI)
	var limit: float = deg_to_rad(tw.turn_threshold_deg)
	if _ease_dur > 0.0:
		# Right after a clip: its overshoot eases back; a same-way residual up to turn_residual_max_deg eases in.
		limit = _overshoot + 0.001 if diff * _dir < 0.0 else maxf(limit, deg_to_rad(tw.turn_residual_max_deg))
		limit = maxf(limit, deg_to_rad(tw.turn_threshold_deg))
	if left <= 0.0 and _d.net_oneshot_left > 0.0:
		return  # a client's npc_oneshot (NetOneshot) is not cut by a turn: the rig holds until it ends
	if left <= 0.0 and absf(diff) > limit:
		start(diff, tw)
	if left > 0.0:
		# The clip's own root rate for the clip's whole length (speed_scale 1): planted feet.
		var dt: float = minf(delta, left)
		left = maxf(left - delta, 0.0)
		_d._turning_left = left
		_d._visual_yaw += rate * dt
		if left <= 0.0:
			_ease_t = 0.0
			_ease_dur = maxf(tw.blend_s, 0.001)  # the residual eases in over the blend-out into the next clip
		return
	if _ease_dur > 0.0:
		_step_ease(diff, delta)
		return
	var body_turned: bool = absf(wrapf(body_yaw - _d._prev_body_yaw, -PI, PI)) > 0.0005
	if absf(diff) < 0.0001 or body_turned:
		_snap_rate = 0.0
		return
	if _snap_rate <= 0.0:
		_snap_rate = absf(diff) / maxf(tw.turn_snap_s, 0.001)
	_d._visual_yaw += clampf(diff, -_snap_rate * delta, _snap_rate * delta)


## Ease the residual `diff` in: smoothstep over _ease_dur, each tick closing the share of what is left that the curve
## gives, so the rig lands on the (possibly still turning) body exactly when the ease ends.
func _step_ease(diff: float, delta: float) -> void:
	var s0: float = smoothstep(0.0, 1.0, _ease_t / _ease_dur)
	_ease_t = minf(_ease_t + delta, _ease_dur)
	var s1: float = smoothstep(0.0, 1.0, _ease_t / _ease_dur)
	var share: float = 1.0 if s0 >= 1.0 else (s1 - s0) / (1.0 - s0)
	_d._visual_yaw += diff * share
	if _ease_t >= _ease_dur:
		_ease_dur = 0.0
		_overshoot = 0.0
