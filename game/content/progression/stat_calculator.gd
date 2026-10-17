## Maps physical WeaponStats to PD2-style UI numbers (pd2_fidelity.md L3.1, P6). Owner: ENV B.
## UI only; parameters in content/data/tweak/display_stats.tres (DisplayStatTweak).
##
## display(stats) -> {
##   "damage": float, "accuracy": int 0..100, "stability": int 0..100, "concealment": int,
##   "threat": int 0..43, "mag": int, "total_ammo": int, "rof": float (rpm),
##   "reload": float (s, tactical), "reload_empty": float (s) }
##   (reload values via LoadoutResolver.reload_times: shell-fed weapons are derived per D-045)
## delta(base, modded) -> { key: {"base", "modded", "diff", "changed": bool, "better": bool} }
##   for each DisplayStatTweak.delta_keys entry; "better" drives green (true) / red (false).
class_name StatCalculator
extends RefCounted

const TWEAK: StringName = &"display_stats"
const EPS: float = 0.0001


static func display(stats: WeaponStats) -> Dictionary:
	var t: DisplayStatTweak = ContentDB.tweak(TWEAK) as DisplayStatTweak
	var dmg: float = stats.damage * pow(float(maxi(stats.pellets, 1)), t.damage_pellet_exponent) * t.damage_scale
	var acc: float = _linear_score(stats.spread_deg_ads * ads_spread_mult(), t.accuracy_spread_best_deg,
			t.accuracy_spread_worst_deg, t.accuracy_max)
	var recoil: float = stats.recoil_kick_deg + stats.recoil_horizontal_deg * t.stability_horizontal_weight
	var stab: float = _linear_score(recoil, t.stability_recoil_best_deg, t.stability_recoil_worst_deg, t.stability_max)
	var threat: float = clampf(stats.suppression * t.threat_scale, 0.0, t.threat_max)
	var reload: Vector2 = LoadoutResolver.reload_times(stats)  # D-045 shell-fed totals
	return {
		"damage": snappedf(dmg, 0.1),
		"accuracy": roundi(acc),
		"stability": roundi(stab),
		"concealment": stats.concealment,
		"threat": roundi(threat),
		"mag": stats.mag_size,
		"total_ammo": stats.total_ammo,
		"rof": stats.fire_rate_rpm,
		"reload": reload.x,
		"reload_empty": reload.y,
	}


## D-131 (ENV A): the runtime multiplier on spread_deg_ads (CombatTweak.ads_spread_mult), so Accuracy shows the cone
## the crew actually fires; 1.0 while the tweak has no such field.
static func ads_spread_mult() -> float:
	var v: Variant = CombatTweak.data().get(&"ads_spread_mult")
	return float(v) if v != null else 1.0


static func delta(base: WeaponStats, modded: WeaponStats) -> Dictionary:
	var t: DisplayStatTweak = ContentDB.tweak(TWEAK) as DisplayStatTweak
	var a: Dictionary = display(base)
	var b: Dictionary = display(modded)
	var out: Dictionary = {}
	for key: StringName in t.delta_keys:
		var k: String = String(key)
		var va: float = float(a[k])
		var vb: float = float(b[k])
		var diff: float = vb - va
		var changed: bool = absf(diff) > EPS
		var better: bool = diff < 0.0 if t.lower_is_better.has(key) else diff > 0.0
		out[k] = {"base": a[k], "modded": b[k], "diff": diff, "changed": changed, "better": changed and better}
	return out


## 0 at `worst`, `max_score` at `best`, clamped.
static func _linear_score(value: float, best: float, worst: float, max_score: float) -> float:
	if is_equal_approx(worst, best):
		return max_score
	return clampf((worst - value) / (worst - best), 0.0, 1.0) * max_score
