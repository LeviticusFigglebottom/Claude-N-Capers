## D-115 (ENV D loud coverage FROZEN flags) for AnimDriver: a looping clip cut by a one-shot (fire_*, reload, turn,
## a hit) resumes at its own running phase when the one-shot ends, instead of restarting on frame 0 (or on the body's
## fixed loop offset). Before, a gunner firing on a steady cadence restarted aim_* / idle_alert_<kind> on the same
## frame after every shot: the pose repeated bit for bit each second (the harness's FROZEN on aim_rifle, aim_pistol,
## idle_alert_rifle) and the breathing never got past its first second. Owner: ENV A. Presentation only.
class_name LoopResume
extends RefCounted

## Presentation clock (s), advanced by AnimDriver.tick (step()).
var clock: float = 0.0
## This tick's delta: the player has sampled up to clock - last_dt and advances by last_dt after the tick.
var last_dt: float = 0.0

var _d: AnimDriver = null
## The loop cut by the one-shot, its position (s) and speed_scale then, and the driver clock (s) at the cut.
var _clip: StringName = &""
var _pos: float = 0.0
var _speed: float = 1.0
var _at: float = 0.0


func _init(driver: AnimDriver) -> void:
	_d = driver


## Before the driver leaves clip `from` for `to`: remember `from` when it is a playing loop cut by a one-shot.
func leaving(from: StringName, to: StringName) -> void:
	if from == &"" or from == to:
		return
	if to != _d._oneshot:
		if to != _clip:
			_clip = &""  # the loop is left for good (another loop, a pose, locomotion)
		return
	var player: AnimationPlayer = _d.player
	var full: String = _d._resolve(from)
	var a: Animation = player.get_animation(full) if full != "" else null
	if a == null or a.loop_mode == Animation.LOOP_NONE:
		return  # one-shot to one-shot (fire, fire...): keep the loop the first one cut
	if _has_method_keys(a):
		_clip = &""  # a loop with method-track keys restarts as before: a resume seek would skip keys (D-132 parity)
		return
	if String(player.current_animation) != full:
		_clip = &""
		return
	_clip = from
	_pos = player.current_animation_position
	_speed = player.speed_scale
	_at = clock - last_dt


## Advance the clock by one driver tick.
func step(delta: float) -> void:
	clock += delta
	last_dt = delta


## After the driver started `want` (played as `full`): true when it is the loop a one-shot cut, now seeked to where it
## would be had it kept playing.
func resume(want: StringName, full: String) -> bool:
	if want != _clip or _clip == &"":
		return false
	_clip = &""
	var a: Animation = _d.player.get_animation(full)
	if a == null or a.length <= 0.0:
		return false
	_d.player.seek(fposmod(_pos + (clock - last_dt - _at) * _speed, a.length), true)
	return true


static func _has_method_keys(a: Animation) -> bool:
	for t: int in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_METHOD and a.track_get_key_count(t) > 0:
			return true
	return false
