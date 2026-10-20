## A heist sun with a slow cloud-shadow light-energy curve (OF-C2, ostrander_federal.md §Audio/lighting: "direct and
## intermittent; the cloud-shadow animation is a slow light-energy curve on the sun, presentation only"). Owner: ENV C.
## Deterministic, no RNG: the cloud cover is a fixed sum of slow cosines of the elapsed time (the PERIODS / WEIGHTS
## table), shaped so the sun is out ~65% of the time and a cloud passes every ~80 s (45 per hour):
##   cover(t) = smoothstep(COVER_LO, COVER_HI, sum_i w_i * (0.5 - 0.5 * cos(2 pi t / P_i)) / sum_i w_i)
##   light_energy = base_energy * (1 - depth * cover(t))
## t starts at 0 on _ready with cover(0) = 0 (full sun), so a review shot or a fresh peer sees the base energy; peers
## drift apart only by their load times (presentation only, never gameplay: detection does not read light energy).
## The curve is off in the editor and when `animate` is false.
extends DirectionalLight3D

## Cosine periods (s) of the cloud field and their weights (mutually prime-ish periods: no short repeat).
const PERIODS: Array[float] = [97.0, 61.0, 37.0]
const WEIGHTS: Array[float] = [0.5, 0.3, 0.2]
## The cover mix maps through smoothstep(COVER_LO, COVER_HI, mix): below COVER_LO the sun is clear.
const COVER_LO: float = 0.6
const COVER_HI: float = 0.88

## Energy with the sun clear.
@export var base_energy: float = 1.0
## Fraction of the energy a full cloud takes away (0 = no clouds).
@export_range(0.0, 1.0) var depth: float = 0.5
@export var animate: bool = true

var _t: float = 0.0


func _ready() -> void:
	light_energy = base_energy
	set_process(animate and not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_t += delta
	light_energy = energy_at(_t)


## The sun's energy `t` seconds after _ready.
func energy_at(t: float) -> float:
	return base_energy * (1.0 - depth * cover(t))


## Cloud cover in [0, 1] at `t` (0 = clear sun).
static func cover(t: float) -> float:
	var mix: float = 0.0
	var wsum: float = 0.0
	for i: int in range(PERIODS.size()):
		mix += WEIGHTS[i] * (0.5 - 0.5 * cos(TAU * t / PERIODS[i]))
		wsum += WEIGHTS[i]
	return smoothstep(COVER_LO, COVER_HI, mix / wsum)
