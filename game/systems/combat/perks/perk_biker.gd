## D-162 perk.biker (Road Crew; PD2 Biker). Owner: ENV A. Schema: B's perk_decks.md. Every crew kill (CrewKillFeed: the
## holder's or any teammate's) is a proc: +heal health and +armor armor, at most max_procs within a sliding window_s.
## Per whole 10 % step of health missing: +armor_per_missing_health armor and -window_cut_per_missing_health s of window;
## per step of armor missing: +heal_per_missing_armor health and -window_cut_per_missing_armor s. Server only.
class_name PerkBiker
extends PerkComponent

const KEY: StringName = &"perk.biker"

## Recent trigger times (component clock).
var triggers: Array[float] = []
var _clock: float = 0.0
var _feed: CrewKillFeed = null


func tick(delta: float) -> void:
	_clock += delta
	if _feed == null:
		_feed = CrewKillFeed.of(HeistRuntime.of(crew))
		if _feed != null:
			_feed.crew_kill.connect(_on_crew_kill)


## Seconds of the rate-limit window now (the missing-health / missing-armor cuts applied).
func window_s() -> float:
	return maxf(num("window_s") - num("window_cut_per_missing_health") * _steps_health()
		- num("window_cut_per_missing_armor") * _steps_armor(), 0.1)


func _on_crew_kill(_slot_k: int, _victim: int, _info: Dictionary) -> void:
	var h: CrewHealth = _health()
	if h == null or not is_instance_valid(crew) or crew.crew_state != Enums.CrewState.NORMAL:
		return
	var w: float = window_s()
	triggers = triggers.filter(func(t: float) -> bool: return _clock - t < w)
	if triggers.size() >= int(num("max_procs")):
		return
	triggers.append(_clock)
	var heal: float = num("heal") + num("heal_per_missing_armor") * _steps_armor()
	var arm: float = num("armor") + num("armor_per_missing_health") * _steps_health()
	h.heal(heal)
	_add_armor(arm)


func _steps_health() -> float:
	return floorf((1.0 - _health_frac()) * 10.0 + 0.0001)


func _steps_armor() -> float:
	var h: CrewHealth = _health()
	if h == null or h.max_armor <= 0.0:
		return 0.0
	return floorf((1.0 - h.armor / h.max_armor) * 10.0 + 0.0001)
