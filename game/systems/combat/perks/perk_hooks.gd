## Perk-deck hook points (QB-62, P4: every `perk.*` PARAMS key). Owner: ENV A.
## Static entry points that other A systems call with a single `# perk hook` line; each routes to the
## crew member's CrewPerks (one PerkComponent per granted key, game/systems/combat/perks/perk_*.gd).
## Call sites:
##   CrewHealth.compute_max_health / compute_max_armor -> max_health / max_armor
##   CrewHealth.dodge_chance -> dodge_add
##   CrewHealth.take_hit -> incoming_damage (after dodge, before armor) and after_hit
##   CrewHealth.server_tick -> tick (true = a perk replaces the armor regen this tick)
##   PoliceBrain._pick_target -> aggro_weight
##   ammo pickups -> on_ammo_picked (perk.gambler); melee -> melee_damage_mult / on_melee_miss
##   stamina -> stamina_mult (perk.crew_chief hostages); throwables -> throwable_id / use_throwable
## Gameplay events (damage dealt, kills) come from EventBus, so combat_system / npc_base need no hook.
## Schemas: game/systems/modifiers_params.md.
class_name PerkHooks
extends RefCounted


## The crew member's CrewPerks (created and refreshed on first use). Null for a null crew.
static func of(crew: CrewController) -> CrewPerks:
	if crew == null or not is_instance_valid(crew):
		return null
	if crew.has_meta(CrewPerks.META):
		return crew.get_meta(CrewPerks.META) as CrewPerks
	var perks: CrewPerks = CrewPerks.new(crew)
	crew.set_meta(CrewPerks.META, perks)
	perks.refresh()
	return perks


static func _crew_of(h: CrewHealth) -> CrewController:
	return h.get_parent() as CrewController if h != null else null


## Armor before perks: ArmorDef.armor (CrewTweak.default_armor fallback) x defense.armor_mult.
static func raw_armor(crew: CrewController) -> float:
	var base: float = Tweak.crew().default_armor
	if crew != null and crew.loadout != null and crew.loadout.armor != &"":
		var def: ArmorDef = ContentDB.armor(crew.loadout.armor)
		if def != null:
			base = def.armor
	return base * TeamModifiers.armor_mult(crew.slot if crew != null else -1)


static func raw_health(crew: CrewController) -> float:
	return Tweak.crew().base_health * TeamModifiers.health_mult(crew.slot if crew != null else -1)


## CrewHealth.compute_max_health: `value` = base health x defense.health_mult.
static func max_health(h: CrewHealth, value: float) -> float:
	var crew: CrewController = _crew_of(h)
	var perks: CrewPerks = of(crew)
	if perks == null:
		return value
	perks.refresh()
	value *= PerkCrewChief.hostage_mult(crew, "hostage_health_per")
	return perks.adjust_max_health(value, raw_armor(crew))


## CrewHealth.compute_max_armor: `value` = armor x defense.armor_mult.
static func max_armor(h: CrewHealth, value: float) -> float:
	var crew: CrewController = _crew_of(h)
	var perks: CrewPerks = of(crew)
	if perks == null:
		return value
	perks.refresh()
	return maxf(perks.adjust_max_armor(value, raw_health(crew)), 0.0)


static func dodge_add(h: CrewHealth) -> float:
	var perks: CrewPerks = of(_crew_of(h))
	return perks.dodge_add() if perks != null else 0.0


## CrewHealth.take_hit (after the dodge roll, before armor): damage reduction (all perks summed,
## capped at PerkTweak.max_damage_reduction, + perk.crew_chief team_dr) and the perk.stoic DoT split.
static func incoming_damage(h: CrewHealth, info: Dictionary, dmg: float) -> float:
	var crew: CrewController = _crew_of(h)
	if crew != null and dmg > 0.0:
		dmg = maxf(dmg - PerkManiac.absorb_for(crew), 0.0)  # D-162 Hysteria: the holder's or a sharing teammate's
	var perks: CrewPerks = of(crew)
	if perks == null or dmg <= 0.0:
		return dmg
	var dr: float = perks.damage_reduction(info) + PerkCrewChief.team_dr_for(crew)
	dmg *= 1.0 - clampf(dr, 0.0, PerkTweak.data().max_damage_reduction)
	return perks.incoming(info, dmg)


## CrewHealth.take_hit after armor / health were reduced (`out` = final DamageInfo so far).
static func after_hit(h: CrewHealth, out: Dictionary) -> void:
	var perks: CrewPerks = of(_crew_of(h))
	if perks != null:
		perks.after_hit(out)


## CrewHealth.server_tick (NORMAL crew, before the armor regen delay). True = skip the normal regen.
static func tick(h: CrewHealth, delta: float) -> bool:
	if not Net.is_authority():
		return false
	var perks: CrewPerks = of(_crew_of(h))
	return perks != null and perks.server_tick(delta)


## Enemy target-selection weight on `crew` (> 1 = preferred). Callers divide their distance score by
## it. `from` = the choosing NPC (perk.kingpin: nearby enemies only).
static func aggro_weight(crew: CrewController, from: Node3D = null) -> float:
	var perks: CrewPerks = of(crew)
	var skill: float = Modifiers.mult(crew.slot, &"defense.target_priority_mult") if crew != null else 1.0  # B2 Low Profile
	return maxf((perks.aggro_mult(from) if perks != null else 1.0) * skill, 0.01)


## Melee damage multiplier for `crew`'s next melee hit (perk.infiltrator chain).
static func melee_damage_mult(crew: CrewController) -> float:
	var perks: CrewPerks = of(crew)
	return perks.melee_damage_mult() if perks != null else 1.0


## A melee swing of `crew` hit nothing: the perk.infiltrator chain resets.
static func on_melee_miss(crew: CrewController) -> void:
	var perks: CrewPerks = of(crew)
	var inf: PerkInfiltrator = perks.component(PerkInfiltrator.KEY) as PerkInfiltrator if perks != null else null
	if inf != null:
		inf.reset_chain()


## Server: `crew` picked up `amount` rounds from an ammo pickup (perk.gambler).
static func on_ammo_picked(crew: CrewController, amount: int) -> void:
	var perks: CrewPerks = of(crew)
	if perks != null and Net.is_authority():
		perks.on_ammo_picked(amount)


## Stamina multiplier from perk.crew_chief hostages (1.0 without).
static func stamina_mult(crew: CrewController) -> float:
	return PerkCrewChief.hostage_mult(crew, "hostage_stamina_per") if crew != null else 1.0


## The deck throwable replacing the equipped one (&"" = none: use Loadout.throwable).
static func throwable_id(crew: CrewController) -> StringName:
	var perks: CrewPerks = of(crew)
	if perks != null:
		perks.refresh()  # ui_hud v1.20: also on a client, where no server tick refreshes the components
	var t: PerkThrowable = perks.component(PerkThrowable.KEY) as PerkThrowable if perks != null else null
	return t.item_id() if t != null else &""


## Server: use `crew`'s deck throwable now (also on a CrewIntent.throw_item edge). True when used.
static func use_throwable(crew: CrewController) -> bool:
	var perks: CrewPerks = of(crew)
	var t: PerkThrowable = perks.component(PerkThrowable.KEY) as PerkThrowable if perks != null else null
	return t != null and Net.is_authority() and t.throw_now()
