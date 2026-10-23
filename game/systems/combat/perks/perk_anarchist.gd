## perk.anarchist (Overclock, PD2 Anarchist). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## - health_to_armor_fraction of max health is removed; armor gains removed x health_to_armor_ratio.
## - Armor no longer waits for the regen delay: it ticks tick_by_armor[armor] = [armor, interval s]
##   continuously, even right after a hit (replaces CrewHealth's delayed full regen).
## - break_immunity_s of health immunity when armor breaks (break_immunity_cooldown_s).
## - damage_dealt_armor when damaging an enemy (damage_dealt_armor_cooldown_s).
class_name PerkAnarchist
extends PerkComponent

const KEY: StringName = &"perk.anarchist"

var _tick_acc: float = 0.0
var _dealt_cd: float = 0.0


func _health_fraction() -> float:
	return clampf(num("health_to_armor_fraction"), 0.0, 0.95)


func adjust_max_health(value: float, _raw_armor: float) -> float:
	return value * (1.0 - _health_fraction())


func adjust_max_armor(value: float, raw_health: float) -> float:
	return value + raw_health * _health_fraction() * maxf(num("health_to_armor_ratio"), 0.0)


## D-164 (Copycat mimic): an empty tick_by_armor keeps CrewHealth's normal delayed regen.
func handles_armor_regen() -> bool:
	return _ticks()


func _ticks() -> bool:
	var table: Variant = param("tick_by_armor", {})
	return not (table is Dictionary and (table as Dictionary).is_empty())


## [armor per tick, tick interval] for the worn armor.
func armor_tick() -> Vector2:
	var table: Variant = param("tick_by_armor", {})
	var id: StringName = PerkUtil.armor_id(crew)
	if table is Dictionary:
		var row: Variant = (table as Dictionary).get(id, (table as Dictionary).get(String(id)))
		if row is Array and (row as Array).size() >= 2:
			return Vector2(float(row[0]), float(row[1]))
	return PerkTweak.data().anarchist_fallback_tick


func tick(delta: float) -> void:
	_tick_immunity(delta)
	_dealt_cd = maxf(_dealt_cd - delta, 0.0)
	var h: CrewHealth = _health()
	if h == null or h.armor >= h.max_armor or not _ticks():
		_tick_acc = 0.0
		return
	var t: Vector2 = armor_tick()
	_tick_acc += delta
	var interval: float = maxf(t.y, 0.05)
	while _tick_acc >= interval:
		_tick_acc -= interval
		_add_armor(t.x)


func after_hit(out: Dictionary) -> void:
	_try_break_immunity(out, num("break_immunity_s"), num("break_immunity_cooldown_s"))


func on_damage_dealt(_victim: Node, info: Dictionary) -> void:
	var a: float = num("damage_dealt_armor")
	if a <= 0.0 or _dealt_cd > 0.0 or float(info.get("amount", 0.0)) <= 0.0:
		return
	_add_armor(a)
	_dealt_cd = num("damage_dealt_armor_cooldown_s")
