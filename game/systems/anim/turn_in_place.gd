## AnimDriver's turn in place (D-116 follow-up: ENV D turn_l_45 / turn_r_45, 12 f = 0.4 s, root_turn +-45 deg at the
## same 112.5 deg/s as turn_l / turn_r's 90 deg over 0.8 s). Owner: ENV A. Presentation only (the body's yaw is
## gameplay; only the rig under it is counter-rotated). Back-reference `_d` to the driver, like CombatClips.
## A standing body whose yaw left the rig's by:
##   >= AnimTweak.turn_90_min_deg (67.5): turn_l / turn_r (AnimTweak.turn_clip_deg, 90);
##   turn_threshold_deg (20) .. 67.5: turn_l_45 / turn_r_45 (turn_45_clip_deg, 45; a rig without them: turn_l / r);
##   below 20 (the body has stopped turning): no clip, the rig snaps over AnimTweak.turn_snap_s.
## The clip plays at speed_scale = clip_deg / |diff| (clamped to turn_speed_min..max) and the rig yaws at
## |diff| / (clip length / speed_scale), so the rig and the clip finish together; the rig never yaws past the body and
## stops when the clip is done (what is left: another clip, or the snap).
class_name TurnInPlace
extends RefCounted

## Rig yaw rate (rad/s) of the running turn clip; seconds of it left (the driver mirrors it in _turning_left).
var rate: float = 0.0
var left: float = 0.0
## The clip's speed_scale and the clip played for the running turn (tests).
var speed: float = 1.0
var turn_clip: StringName = &""
var _d: AnimDriver = null
## Rig yaw rate (rad/s) of the running no-clip snap (0 = none).
var _snap_rate: float = 0.0


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
	var abs_deg: float = absf(rad_to_deg(diff))
	var pick: Array = clip_for(rad_to_deg(diff), tw)
	turn_clip = pick[0]
	var full: String = _d._resolve(turn_clip) if _d.player != null else ""
	var length: float = _d.player.get_animation(full).length if full != "" else tw.turn_time_s
	speed = clampf(float(pick[1]) / maxf(abs_deg, 0.001), tw.turn_speed_min, tw.turn_speed_max)
	left = length / speed
	rate = absf(diff) / maxf(left, 0.001)
	_snap_rate = 0.0
	_d._turning_left = left
	_d.play_oneshot(turn_clip, left, false, speed)


## Cancel a running turn / snap (moving, a pose, an action).
func stop() -> void:
	left = 0.0
	rate = 0.0
	_snap_rate = 0.0
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
	var now: StringName = _d.choose_clip() if standing and not held else &""
	if held:
		pass
	elif not standing or AnimDriver.POSE_CLIPS.has(now) or AnimDriver.ACTION_CLIPS.has(now):
		_d._visual_yaw = body_yaw
		stop()
	else:
		_step(body_yaw, delta, tw)
	_d._prev_body_yaw = body_yaw
	if _d.rig != null:
		_d.rig.rotation.y = _d._rig_base_yaw + wrapf(_d._visual_yaw - body_yaw, -PI, PI)


func _step(body_yaw: float, delta: float, tw: AnimTweak) -> void:
	var diff: float = wrapf(body_yaw - _d._visual_yaw, -PI, PI)
	if left <= 0.0 and absf(diff) > deg_to_rad(tw.turn_threshold_deg):
		start(diff, tw)
	if left > 0.0:
		var dt: float = minf(delta, left)
		left = maxf(left - delta, 0.0)
		_d._turning_left = left
		_d._visual_yaw += clampf(diff, -rate * dt, rate * dt)
		return
	var body_turned: bool = absf(wrapf(body_yaw - _d._prev_body_yaw, -PI, PI)) > 0.0005
	if absf(diff) < 0.0001 or body_turned:
		_snap_rate = 0.0
		return
	if _snap_rate <= 0.0:
		_snap_rate = absf(diff) / maxf(tw.turn_snap_s, 0.001)
	_d._visual_yaw += clampf(diff, -_snap_rate * delta, _snap_rate * delta)
