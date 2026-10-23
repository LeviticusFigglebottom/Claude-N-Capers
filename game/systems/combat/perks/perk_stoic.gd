## perk.stoic (Composure, PD2 Stoic). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## - armor_to_health: that fraction of the armor is removed and added to max health (1.0 = no armor).
## - Each hit: delayed_fraction of it becomes damage over time (dot_duration_s); the rest applies now.
## - Flask (deck throwable kind &"flask", PerkThrowable): cancels all pending DoT; flask_cooldown_s.
##   Kills cut kill_cooldown_reduction_s (low_health_kill_cooldown_reduction_s below low_health_threshold).
## - auto_negate_after_s (> 0): pending DoT is cancelled after that long without taking damage.
## - Every cancel heals negate_heal_fraction x the remaining DoT.
class_name PerkStoic
extends PerkComponent

const KEY: StringName = &"perk.stoic"

## Seconds until the flask can be used again.
var flask_cooldown_left: float = 0.0
## Pending DoT instances: x = damage per second, y = seconds left.
var dots: Array[Vector2] = []

var _since_damage: float = 0.0
var _downs_seen: int = -1


func _fraction() -> float:
	return clampf(num("armor_to_health"), 0.0, 1.0)


func adjust_max_health(value: float, raw_armor: float) -> float:
	return value + raw_armor * _fraction()


func adjust_max_armor(value: float, _raw_health: float) -> float:
	return value * (1.0 - _fraction())


func incoming(_info: Dictionary, dmg: float) -> float:
	var f: float = clampf(num("delayed_fraction"), 0.0, 1.0)
	var dur: float = num("dot_duration_s")
	_since_damage = 0.0
	if f <= 0.0 or dur <= 0.0 or dmg <= 0.0:
		return dmg
	dots.append(Vector2(dmg * f / dur, dur))
	return dmg * (1.0 - f)


## Damage still pending in the DoT.
func pending_damage() -> float:
	var total: float = 0.0
	for d: Vector2 in dots:
		total += d.x * d.y
	return total


## Its item cooldown: also while the holder is down (CrewPerks.tick_item_cooldowns, PD2 timers keep running).
func tick_item_cooldown(delta: float) -> void:
	flask_cooldown_left = maxf(flask_cooldown_left - delta, 0.0)


func tick(delta: float) -> void:
	var h: CrewHealth = _health()
	if h == null:
		return
	if _downs_seen >= 0 and _downs_seen != h.downs_used:  # a down clears the DoT
		dots.clear()
	_downs_seen = h.downs_used
	tick_item_cooldown(delta)
	if dots.is_empty():
		return
	_since_damage += delta
	var auto: float = num("auto_negate_after_s")
	if auto > 0.0 and _since_damage >= auto:
		negate()
		return
	var dmg: float = 0.0
	for i: int in range(dots.size() - 1, -1, -1):
		var d: Vector2 = dots[i]
		var step: float = minf(delta, d.y)
		dmg += d.x * step
		d.y -= step
		if d.y <= 0.0:
			dots.remove_at(i)
		else:
			dots[i] = d
	if dmg <= 0.0 or h.invuln_left > 0.0:
		return
	h.health = maxf(h.health - dmg, 0.0)
	if h.health <= 0.0:
		dots.clear()
		h.go_down()


## Cancel all pending DoT (flask / auto negate) and heal negate_heal_fraction of it.
func negate() -> void:
	var rest: float = pending_damage()
	dots.clear()
	var h: CrewHealth = _health()
	if h != null and rest > 0.0:
		h.heal(rest * clampf(num("negate_heal_fraction"), 0.0, 1.0))


func use_throwable(kind: StringName) -> bool:
	if kind != &"flask" or flask_cooldown_left > 0.0:
		return false
	negate()
	flask_cooldown_left = num("flask_cooldown_s")
	return true


func on_kill(_victim: Node, _info: Dictionary) -> void:
	var cut: float = num("kill_cooldown_reduction_s")
	if _health_frac() < num("low_health_threshold"):
		cut = maxf(cut, num("low_health_kill_cooldown_reduction_s"))
	flask_cooldown_left = maxf(flask_cooldown_left - cut, 0.0)
