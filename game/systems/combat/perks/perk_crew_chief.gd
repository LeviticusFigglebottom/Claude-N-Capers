## perk.crew_chief (Foreman, PD2 Crew Chief). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## Team-wide (every crew member, the holder included; several holders do not stack, the best wins):
## - team_dr damage reduction; the holder's own share x self_low_health_dr_mult below
##   self_low_health_threshold.
## - Max health x (1 + hostage_health_per x min(hostages, hostage_max_count)); stamina likewise with
##   hostage_stamina_per (PerkHooks.stamina_mult, read by the stamina system).
## Holder only: close_range_dr while an enemy is within close_range_m. The flat team.* keys
## (team.health_mult, team.stamina_mult...) and team.damage_reduction_hostage are separate keys.
class_name PerkCrewChief
extends PerkComponent

const KEY: StringName = &"perk.crew_chief"


func damage_reduction(_info: Dictionary) -> float:
	var dr: float = num("close_range_dr")
	if dr <= 0.0 or PerkUtil.enemies_near_crew(crew, num("close_range_m")).is_empty():
		return 0.0
	return dr


## Best team_dr granted to `crew` by any holder in the heist.
static func team_dr_for(crew: CrewController) -> float:
	var best: float = 0.0
	for c: CrewController in PerkUtil.crew_of(crew):
		var p: Dictionary = Modifiers.params(c.slot, KEY)
		if p.is_empty():
			continue
		var dr: float = float(PerkTweak.value(p, KEY, "team_dr", 0.0))
		var h: CrewHealth = c.health
		if c == crew and h != null and h.health / maxf(h.max_health, 0.001) < float(PerkTweak.value(p, KEY, "self_low_health_threshold", 0.0)):
			dr *= float(PerkTweak.value(p, KEY, "self_low_health_dr_mult", 1.0))
		best = maxf(best, dr)
	return best


## 1 + the best hostage bonus `field` (hostage_health_per / hostage_stamina_per) for `crew`.
static func hostage_mult(crew: CrewController, field: String) -> float:
	var best: float = 0.0
	var count: int = -1
	for c: CrewController in PerkUtil.crew_of(crew):
		var p: Dictionary = Modifiers.params(c.slot, KEY)
		var per: float = float(PerkTweak.value(p, KEY, field, 0.0)) if not p.is_empty() else 0.0
		if per <= 0.0:
			continue
		if count < 0:
			count = PerkUtil.hostage_count(crew)
		best = maxf(best, per * float(mini(count, int(PerkTweak.value(p, KEY, "hostage_max_count", 0)))))
	return 1.0 + best
