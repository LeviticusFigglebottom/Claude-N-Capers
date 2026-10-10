## Firing range damage math (B1-05): falloff, headshots, DPS and time-to-kill from RESOLVED
## WeaponStats (LoadoutResolver output). Owner: ENV B. UI/range tooling only.
##
## These formulas mirror pd2_fidelity.md L3.2/L3.3 so the readout matches what ENV A's weapon
## runtime (A1-08) will do. If A1-08 lands with different rules, ENV A's runtime wins and this
## file follows it.
##
## * falloff_mult(d): 1.0 up to falloff_start_m, then linear to falloff_min_mult at falloff_end_m,
##   constant after. min_mult > 1 means damage GROWS with range (snipers). ARs use start = end = 9999.
## * Headshot multiplier is per enemy per difficulty (L3.3): the dummy row's value. The weapon's own
##   WeaponStats.headshot_mult is only a fallback when the dummy row has none (QB for the lead).
## * Crits are a separate multiplicative headshot (L3.3).
## * Shotguns: damage is per pellet, every pellet is assumed to hit for DPS/TTK; any pellet on the
##   head makes the whole shot a headshot (handled by RangeDebugGun).
## * TTK: shots fired back to back at fire_rate_rpm; every emptied magazine adds an empty reload
##   (reload_empty_time_s) instead of one shot interval. The first shot lands at t = 0.
class_name RangeMath
extends RefCounted

const EPS: float = 0.0001


static func falloff_mult(s: WeaponStats, distance_m: float) -> float:
	if distance_m <= s.falloff_start_m:
		return 1.0
	if distance_m >= s.falloff_end_m or s.falloff_end_m <= s.falloff_start_m:
		return s.falloff_min_mult
	var t: float = (distance_m - s.falloff_start_m) / (s.falloff_end_m - s.falloff_start_m)
	return lerpf(1.0, s.falloff_min_mult, t)


## Headshot multiplier used against a dummy (per enemy per difficulty, weapon value as fallback).
static func headshot_mult(s: WeaponStats, dummy_headshot_mult: float) -> float:
	if dummy_headshot_mult > 0.0:
		return dummy_headshot_mult
	return s.headshot_mult


## Multiplier a hit zone receives (HEAD and WEAKPOINT take the headshot multiplier).
static func zone_mult(zone: int, hs_mult: float) -> float:
	if zone == Enums.HitZone.HEAD or zone == Enums.HitZone.WEAKPOINT:
		return hs_mult
	return 1.0


## Damage of one pellet/bullet at `distance_m`, body hit.
static func pellet_damage(s: WeaponStats, distance_m: float) -> float:
	return s.damage * falloff_mult(s, distance_m)


## Damage of a whole shot (all pellets hit) at `distance_m` with a zone multiplier.
static func shot_damage(s: WeaponStats, distance_m: float, mult: float = 1.0) -> float:
	return pellet_damage(s, distance_m) * float(maxi(s.pellets, 1)) * mult


## Seconds between two shots (INF when the weapon has no rate of fire).
static func shot_interval_s(s: WeaponStats) -> float:
	if s.fire_rate_rpm <= 0.0:
		return INF
	return 60.0 / s.fire_rate_rpm


static func shots_to_kill(health: float, damage_per_shot: float) -> int:
	if damage_per_shot <= 0.0:
		return 0
	return maxi(ceili(health / damage_per_shot - EPS), 1)


## Time from the first shot to the killing shot (see header for the reload rule).
static func time_to_kill_s(s: WeaponStats, shots: int) -> float:
	if shots <= 0:
		return INF
	var mag: int = maxi(s.mag_size, 1)
	var reloads: int = (shots - 1) / mag
	return float(shots - 1 - reloads) * shot_interval_s(s) + float(reloads) * s.reload_empty_time_s


## Burst DPS (one magazine, no reload), body hits at `distance_m`.
static func dps(s: WeaponStats, distance_m: float) -> float:
	if s.fire_rate_rpm <= 0.0:
		return 0.0
	return shot_damage(s, distance_m) * s.fire_rate_rpm / 60.0


## Sustained DPS including the empty reload, body hits at `distance_m`.
static func sustained_dps(s: WeaponStats, distance_m: float) -> float:
	var mag: int = maxi(s.mag_size, 1)
	var cycle: float = float(mag - 1) * shot_interval_s(s) + s.reload_empty_time_s
	if cycle <= 0.0 or is_inf(cycle):
		return 0.0
	return shot_damage(s, distance_m) * float(mag) / cycle


## Everything the stat panel shows for a dummy at a distance.
## { distance_m, falloff_mult, headshot_mult, health, body_damage, head_damage, dps, sustained_dps,
##   shots_body, shots_head, ttk_body_s, ttk_head_s }
static func readout(s: WeaponStats, health: float, dummy_headshot_mult: float, distance_m: float) -> Dictionary:
	var hs: float = headshot_mult(s, dummy_headshot_mult)
	var body: float = shot_damage(s, distance_m)
	var head: float = shot_damage(s, distance_m, hs)
	var shots_body: int = shots_to_kill(health, body)
	var shots_head: int = shots_to_kill(health, head)
	return {
		"distance_m": distance_m, "falloff_mult": falloff_mult(s, distance_m), "headshot_mult": hs,
		"health": health, "body_damage": body, "head_damage": head,
		"dps": dps(s, distance_m), "sustained_dps": sustained_dps(s, distance_m),
		"shots_body": shots_body, "shots_head": shots_head,
		"ttk_body_s": time_to_kill_s(s, shots_body), "ttk_head_s": time_to_kill_s(s, shots_head),
	}
