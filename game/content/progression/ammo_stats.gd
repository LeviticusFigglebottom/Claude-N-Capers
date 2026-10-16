## D-118 shotgun ammo in the UI numbers (Owner: ENV B). A's ShotgunAmmo decides how an AMMO mod fires; the
## resolver's WeaponStats are the stock pellet build. apply() returns the stats as the shells actually fire them,
## mirroring CrewWeapons (round 222), so the stat panels and the firing range readout / falloff graph / dummy
## simulation agree with a real shot:
## * pellets = ShotgunAmmo.pellets(stock pellets, profile); damage per pellet x ShotgunAmmo.pellet_damage_mult, so
##   the per-shot total stays the stock one (LEAD ruling: a slug's one ray carries the whole shot);
## * falloff_start_m / falloff_end_m x the ammo range_mult (CrewWeapons divides the distance by it);
## * armor_pierce = max(stats, ammo); wall_pierce = ShotgunAmmo.wall_pierce.
## Buckshot (no ammo_type) and non-shotguns come back unchanged (the same object). Never feed the result back into
## the runtime: CrewWeapons applies the ammo itself.
class_name AmmoStats
extends RefCounted


## The ammo profile (ShotgunAmmo.profile) of `def` built with `mods`; {} without a def.
static func profile(def: WeaponDef, mods: Array[StringName]) -> Dictionary:
	if def == null:
		return {}
	return ShotgunAmmo.profile(SpecialWeapons.params_of(def, mods))


## `stats` as `def` + `mods` fire them (see header). Returns `stats` itself when no ammo type is loaded.
static func apply(stats: WeaponStats, def: WeaponDef, mods: Array[StringName]) -> WeaponStats:
	if stats == null or def == null:
		return stats
	var prof: Dictionary = profile(def, mods)
	if prof.is_empty() or StringName(prof.get("ammo_type", ShotgunAmmo.BUCKSHOT)) == ShotgunAmmo.BUCKSHOT:
		return stats
	var out: WeaponStats = stats.duplicate() as WeaponStats
	var base: int = maxi(stats.pellets, 1)
	out.pellets = ShotgunAmmo.pellets(base, prof)
	out.damage = stats.damage * ShotgunAmmo.pellet_damage_mult(base, prof)
	var rm: float = maxf(float(prof.get("range_mult", 1.0)), 0.01)
	out.falloff_start_m = stats.falloff_start_m * rm
	out.falloff_end_m = stats.falloff_end_m * rm
	out.armor_pierce = maxf(stats.armor_pierce, float(prof.get("armor_pierce", 0.0)))
	out.wall_pierce = ShotgunAmmo.wall_pierce(stats.wall_pierce, prof)
	return out
