## QB-60: crew-wide (`team.*`) modifier keys combined with their per-player equivalents. Owner: ENV A.
## TEAM sources (`team_skill.<id>`, `team_perk.<deck>`, D-031 QB-35) apply to every slot, granter
## included, so each helper is simply the personal key x the team key:
## * max health  = defense.health_mult x team.health_mult            (CrewHealth.compute_max_health)
## * max armor   = defense.armor_mult x team.armor_mult              (CrewHealth.compute_max_armor)
## * regen delay = defense.armor_regen_delay_mult x team.armor_regen_delay_mult
## * regen rate  = defense.armor_regen_rate_mult x team.armor_regen_rate_mult
## * stamina     = movement.stamina_mult x team.stamina_mult         (CrewStamina)
## * `team.damage_reduction_hostage` {per, max} while the crew holds hostages (CivilianTargets count).
##   ENV B grants it in two shapes, each read by its value (every granting source counts, through
##   Modifiers.list):
##   - `per` < 1 (Foreman card 9, perk_decks.md): fractional reduction per hostage, capped at `max`
##     (a fraction): incoming damage x (1 - min(per x hostages, max));
##   - `per` >= 1 (Zip & Tie aced, skills.md): flat display-unit absorption per hostage from every hit,
##     `max` = hostages counted: damage - per x min(hostages, max), at least 0.
class_name TeamModifiers
extends RefCounted

const HOSTAGE_DR_KEY: StringName = &"team.damage_reduction_hostage"


## `personal` key x `team` key for `slot` (MULT keys). Call sites name both keys literally, so the
## B4-14 hook-coverage audit (test_perk_wiring.gd) finds the personal key in the file that applies it.
static func combined(slot: int, personal: StringName, team: StringName) -> float:
	return Modifiers.mult(slot, personal) * Modifiers.mult(slot, team)


static func health_mult(slot: int) -> float:
	return combined(slot, &"defense.health_mult", &"team.health_mult")


static func armor_mult(slot: int) -> float:
	return Modifiers.mult(slot, &"defense.armor_mult") * Modifiers.mult(slot, &"team.armor_mult")


static func armor_regen_delay_mult(slot: int) -> float:
	return Modifiers.mult(slot, &"defense.armor_regen_delay_mult") * Modifiers.mult(slot, &"team.armor_regen_delay_mult")


static func armor_regen_rate_mult(slot: int) -> float:
	return Modifiers.mult(slot, &"defense.armor_regen_rate_mult") * Modifiers.mult(slot, &"team.armor_regen_rate_mult")


static func stamina_mult(slot: int) -> float:
	return Modifiers.mult(slot, &"movement.stamina_mult") * Modifiers.mult(slot, &"team.stamina_mult")


## Hostages the crew of `node`'s heist holds now (0 without a CivilianTargets service).
static func hostage_count(node: Node) -> int:
	var rt: HeistRuntime = HeistRuntime.of(node) if node != null else null
	if rt == null:
		return 0
	var ct: CivilianTargets = rt.service(CivilianTargets.SERVICE) as CivilianTargets
	return ct.hostage_count if ct != null else 0


## `dmg` after team.damage_reduction_hostage for `hostages` held hostages (see the header).
static func hostage_reduced(slot: int, dmg: float, hostages: int) -> float:
	# D-056: PD2 Crew Chief shape: flat absorption per hostage, capped by hostage count.
	# PARAMS {absorb_per_hostage: float, max_hostages: int}; every granting source counts.
	if hostages <= 0 or dmg <= 0.0:
		return dmg
	var flat: float = 0.0
	for d: Dictionary in Modifiers.list(slot, HOSTAGE_DR_KEY):
		var per: float = float(d.get("absorb_per_hostage", 0.0))
		var mx: int = int(d.get("max_hostages", 0))
		if per <= 0.0:
			continue
		flat += per * float(mini(hostages, mx) if mx > 0 else hostages)
	return maxf(dmg - flat, 0.0)
