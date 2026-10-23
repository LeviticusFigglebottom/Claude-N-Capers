## Rolling Thunder levers (LEAD r286, from P's D-158 real-input verdicts), as tweak knobs defaulting to the shipped
## behaviour; the LEAD flips them in rt_tweak.tres. Owner: ENV A. Read by RollingThunderMission.
class_name RtTweak
extends Resource

const PATH: String = "res://world/heists/rolling_thunder/rt_tweak.tres"
const FROM_STOP: StringName = &"stop"
const FROM_ESCORT_DOWN: StringName = &"escort_down"

static var _cached: RtTweak = null

## D-158 truck window: the first assault's BUILD waits truck_window_s from the stop (FROM_STOP, today), or from the last
## convoy unit's death (FROM_ESCORT_DOWN), never past stop + escort_down_max_s.
@export var truck_window_from: StringName = FROM_STOP
@export var truck_window_s: float = 30.0
@export var escort_down_max_s: float = 60.0
## Units kept out of the first assault (AssaultDirector.wave1_exclude: unit ids or bare names, e.g. &"stinger") at
## wave1_exclude_min_difficulty and above. [] = today.
@export var wave1_exclude: Array[StringName] = []
@export var wave1_exclude_min_difficulty: Enums.Difficulty = Enums.Difficulty.HAZARDOUS


static func data() -> RtTweak:
	if _cached == null:
		_cached = load(PATH) as RtTweak if ResourceLoader.exists(PATH) else null
		if _cached == null:
			_cached = RtTweak.new()
	return _cached
