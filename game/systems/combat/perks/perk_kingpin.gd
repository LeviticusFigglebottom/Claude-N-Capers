## perk.kingpin (Overlord, PD2 Kingpin). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## Injector (deck throwable kind &"injector", PerkThrowable): for duration_s, heal heal_fraction of the
## damage taken (x (1 + low_health_heal_bonus) below low_health_threshold); cooldown_s, cut by
## kill_cooldown_reduction_s per kill and by 1 s per overheal_per_cooldown_s of healing at full health.
## draws_aggro: while active, enemies within PerkTweak.kingpin_aggro_radius_m prefer the holder.
class_name PerkKingpin
extends PerkComponent

const KEY: StringName = &"perk.kingpin"

## Seconds of injector effect left.
var active_left: float = 0.0
## Seconds until the injector can be used again.
var cooldown_left: float = 0.0

var _overheal: float = 0.0


func is_active() -> bool:
	return active_left > 0.0


func use_throwable(kind: StringName) -> bool:
	if kind != &"injector" or cooldown_left > 0.0 or is_active():
		return false
	active_left = num("duration_s")
	cooldown_left = num("cooldown_s")
	_overheal = 0.0
	return true


func tick(delta: float) -> void:
	active_left = maxf(active_left - delta, 0.0)
	tick_item_cooldown(delta)


## Its item cooldown: also while the holder is down (CrewPerks.tick_item_cooldowns, PD2 timers keep running).
func tick_item_cooldown(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func after_hit(out: Dictionary) -> void:
	var h: CrewHealth = _health()
	var taken: float = float(out.get("amount", 0.0))
	if not is_active() or h == null or taken <= 0.0:
		return
	var frac: float = num("heal_fraction")
	if _health_frac() < num("low_health_threshold"):
		frac *= 1.0 + num("low_health_heal_bonus")
	var amount: float = taken * frac
	var room: float = maxf(h.max_health - h.health, 0.0)
	h.heal(amount)
	var per: float = num("overheal_per_cooldown_s")
	if per <= 0.0 or amount <= room:
		return
	_overheal += amount - room
	while _overheal >= per:
		_overheal -= per
		cooldown_left = maxf(cooldown_left - 1.0, 0.0)


func on_kill(_victim: Node, _info: Dictionary) -> void:
	cooldown_left = maxf(cooldown_left - num("kill_cooldown_reduction_s"), 0.0)


func aggro_mult(from: Node3D) -> float:
	if not is_active() or not bool(param("draws_aggro", false)):
		return 1.0
	var tw: PerkTweak = PerkTweak.data()
	if from != null and from.global_position.distance_to(crew.global_position) > tw.kingpin_aggro_radius_m:
		return 1.0
	return tw.kingpin_aggro_mult
