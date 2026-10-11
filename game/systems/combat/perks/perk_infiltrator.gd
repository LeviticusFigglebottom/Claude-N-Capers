## perk.infiltrator (Knuckles, PD2 Infiltrator). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## - Damage reduction: surrounded_dr while >= surrounded_min_enemies enemies are within
##   surrounded_radius_m, plus close_range_dr while an enemy is within close_range_m.
## - Melee (CrewMelee, L3.9: these run off MELEE DamageInfos the holder deals; CrewMelee reads
##   PerkHooks.melee_damage_mult and calls PerkHooks.on_melee_miss): a melee hit opens a melee_chain_window_s
##   window in which further melee hits deal x melee_chain_mult (PerkHooks.on_melee_miss resets it);
##   a melee hit heals melee_hit_heal_fraction x max health (melee_hit_heal_cooldown_s).
class_name PerkInfiltrator
extends PerkComponent

const KEY: StringName = &"perk.infiltrator"

## Seconds left in the melee chain window (0 = no chain).
var chain_left: float = 0.0

var _heal_cd: float = 0.0


func damage_reduction(_info: Dictionary) -> float:
	var dr: float = 0.0
	var need: int = int(param("surrounded_min_enemies", 3))
	if need > 0 and PerkUtil.enemies_near_crew(crew, num("surrounded_radius_m")).size() >= need:
		dr += num("surrounded_dr")
	if num("close_range_dr") > 0.0 and not PerkUtil.enemies_near_crew(crew, num("close_range_m")).is_empty():
		dr += num("close_range_dr")
	return dr


func on_damage_dealt(_victim: Node, info: Dictionary) -> void:
	if int(info.get("type", Enums.DamageType.BULLET)) != Enums.DamageType.MELEE:
		return
	chain_left = num("melee_chain_window_s")
	var frac: float = num("melee_hit_heal_fraction")
	if frac > 0.0 and _heal_cd <= 0.0 and _health() != null:
		_health().heal(_health().max_health * frac)
		_heal_cd = num("melee_hit_heal_cooldown_s")


func melee_damage_mult() -> float:
	return maxf(num("melee_chain_mult"), 1.0) if chain_left > 0.0 else 1.0


func reset_chain() -> void:
	chain_left = 0.0


func tick(delta: float) -> void:
	chain_left = maxf(chain_left - delta, 0.0)
	_heal_cd = maxf(_heal_cd - delta, 0.0)
