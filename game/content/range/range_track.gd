## Lateral moving-target track (B4-13, pd2_fidelity P7: lateral tracks 2-5 m/s). Owner: ENV B.
## A rail at the lane centre and a `carriage` child that runs back and forth along local X at a
## constant `speed_mps` between -track_half_m and +track_half_m; the RangeTarget rides the carriage.
## Deterministic: the carriage offset is a pure function of the track time (`offset_at`), advanced
## by the physics tick (hitboxes move in step with physics). Starts at the centre moving +X.
class_name RangeTrack
extends Node3D

var speed_mps: float = 0.0
var track_half_m: float = 0.0
var phase_s: float = 0.0
## Seconds this track has run (offset = offset_at(time_s + phase_s)).
var time_s: float = 0.0
var carriage: Node3D = null
var paused: bool = false


func _init() -> void:
	carriage = Node3D.new()
	carriage.name = "Carriage"
	add_child(carriage)


func setup(speed: float, half_length: float, phase: float) -> void:
	speed_mps = speed
	track_half_m = half_length
	phase_s = phase
	set_time(0.0)


## Carriage X offset at track time `t` for a back-and-forth run (triangle wave, period 4*half/speed).
static func offset_at(t: float, speed: float, half: float) -> float:
	if speed <= 0.0 or half <= 0.0:
		return 0.0
	var period: float = 4.0 * half / speed
	var u: float = fposmod(t, period) / period
	if u < 0.25:
		return half * u * 4.0
	if u < 0.75:
		return half * (1.0 - (u - 0.25) * 4.0)
	return half * (-1.0 + (u - 0.75) * 4.0)


func offset() -> float:
	return offset_at(time_s + phase_s, speed_mps, track_half_m)


func set_time(t: float) -> void:
	time_s = t
	carriage.position.x = offset()


func advance(delta: float) -> void:
	set_time(time_s + delta)


func _physics_process(delta: float) -> void:
	if not paused:
		advance(delta)
