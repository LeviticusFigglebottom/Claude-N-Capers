## D-106: weapon stats as the player will have them in play, with their skills and perk deck applied
## (PD2's inventory shows skill-boosted stats). No new rules: the loadout's merged grants come from
## LoadoutResolver.resolve_modifiers() and are read the way ENV A's CrewWeapons reads Modifiers at runtime
## (qualifier = the weapon class: "<key>.all" and "<key>.<class>" count, MULT keys multiply, ADD keys add).
## Static (always-on) weapon keys only; conditional buffs (kill / hit stacks, crits) stay out. Owner: ENV B.
class_name SkillBoost
extends RefCounted


## A copy of `stats` (weapon `def`) with the grants in `modifiers` applied. Returns `stats` itself
## when nothing applies.
static func apply(stats: WeaponStats, def: WeaponDef, modifiers: Dictionary) -> WeaponStats:
	if stats == null or def == null or modifiers.is_empty():
		return stats
	var q: StringName = Enums.weapon_class_qualifier(def.weapon_class)
	var out: WeaponStats = stats.duplicate() as WeaponStats
	out.damage *= mult(modifiers, &"weapon.damage_mult", q)
	out.headshot_mult *= mult(modifiers, &"weapon.headshot_mult", q)
	out.fire_rate_rpm *= mult(modifiers, &"weapon.fire_rate_mult", q)
	var spread: float = mult(modifiers, &"weapon.spread_mult", q)
	out.spread_deg_hip *= spread
	out.spread_deg_ads *= spread
	var recoil: float = mult(modifiers, &"weapon.recoil_mult", q)
	out.recoil_kick_deg *= recoil
	out.recoil_horizontal_deg *= recoil
	out.mag_size = maxi(stats.mag_size + int(add(modifiers, &"weapon.mag_extra", q)), 1)
	out.total_ammo = int(round(float(stats.total_ammo) * mult(modifiers, &"weapon.ammo_total_mult", q)))
	var speed: float = maxf(mult(modifiers, &"weapon.reload_speed_mult", q), 0.01)
	for field: StringName in [&"reload_time_s", &"reload_empty_time_s", &"reload_per_round_s", &"reload_start_s",
			&"reload_end_s", &"reload_end_empty_s"]:
		out.set(field, float(stats.get(field)) / speed)
	return out


## Product of the MULT grants of `key` for qualifier `q` (1.0 when none).
static func mult(modifiers: Dictionary, key: StringName, q: StringName) -> float:
	var r: float = 1.0
	for k: StringName in _keys(key, q):
		if modifiers.has(k) and (modifiers[k] is float or modifiers[k] is int):
			r *= float(modifiers[k])
	return r


## Sum of the ADD grants of `key` for qualifier `q` (0 when none).
static func add(modifiers: Dictionary, key: StringName, q: StringName) -> float:
	var r: float = 0.0
	for k: StringName in _keys(key, q):
		if modifiers.has(k) and (modifiers[k] is float or modifiers[k] is int):
			r += float(modifiers[k])
	return r


## StatCalculator.display keys whose shown value differs between `base` and `boosted` (marked in the UI).
static func boosted_keys(base: Dictionary, boosted: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in boosted:
		if not is_equal_approx(float(boosted[k]), float(base.get(k, boosted[k]))):
			out.append(String(k))
	return out


static func _keys(key: StringName, q: StringName) -> Array[StringName]:
	return [StringName("%s.all" % key), StringName("%s.%s" % [key, q])]
