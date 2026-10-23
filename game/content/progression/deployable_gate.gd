## Deployables that need a modifier FLAG before they can be equipped (PD2: the armor bag needs its perk
## card). Owner: ENV B. The loadout picker shows a gated deployable locked, with the perk card that
## unlocks it, until the loadout's skills + perk cards grant the flag (LoadoutResolver.resolve_modifiers).
## ENV A's DeployableSystem gives no unit for a gated pick without the flag, so a stale save is harmless.
class_name DeployableGate
extends RefCounted

## deployable id -> FLAG modifier key it needs.
## Lead ruling (PD2-faithful): ECM, trip mines and first aid kits need the skill that carries them; the gate is
## the basic tier's grant (any non-zero value counts). D-157 (LEAD r286): the sentry needs the Sapper tree's first
## sentry skill (Mount Up basic, PD2 Technician's "Sentry Gun"), whose grant is deploy.sentry_cost_mult.
const REQUIRES: Dictionary = {
	&"deployable.armor_bag": &"deploy.armor_bag",
	&"deployable.ecm": &"stealth.ecm_extra",
	&"deployable.trip_mine": &"deploy.extra.trip_mine",
	&"deployable.fak": &"deploy.extra.fak",
	&"deployable.sentry": &"deploy.sentry_cost_mult",
}


## The FLAG `deployable_id` needs, or &"" when it is free to equip.
static func required_flag(deployable_id: StringName) -> StringName:
	return REQUIRES.get(deployable_id, &"") as StringName


## True when `modifiers` (resolved per-slot grants) allow `deployable_id`.
static func allowed(deployable_id: StringName, modifiers: Dictionary) -> bool:
	var flag: StringName = required_flag(deployable_id)
	return flag == &"" or bool(modifiers.get(flag, false))


static func allowed_for(loadout: Loadout, deployable_id: StringName) -> bool:
	return allowed(deployable_id, LoadoutResolver.resolve_modifiers(loadout))


## Where the flag comes from, for the locked label: {"card": 1-based card number, "name": card name key}
## of the first perk card (decks in id order) that grants it; {} when no card does.
static func unlock_card(deployable_id: StringName) -> Dictionary:
	var flag: StringName = required_flag(deployable_id)
	if flag == &"":
		return {}
	for r: Variant in ContentDB.all_of(ContentDB.PERKS):
		var deck: PerkDeckDef = r as PerkDeckDef
		for i: int in range(deck.cards.size()):
			var grants: Dictionary = deck.cards[i].get("grants", {})
			if grants.has(flag):
				return {"card": i + 1, "name": StringName(deck.cards[i].get("name", ""))}
	return {}


## The lowest-tier skill whose basic tier grants the flag `deployable_id` needs (then by id): {"id": skill id,
## "name": name key}; {} when no skill does (a perk card may, see unlock_card()).
static func unlock_skill(deployable_id: StringName) -> Dictionary:
	var flag: StringName = required_flag(deployable_id)
	if flag == &"":
		return {}
	var best: SkillDef = null
	for r: Variant in ContentDB.all_of(ContentDB.SKILLS):
		var sk: SkillDef = r as SkillDef
		if sk != null and sk.grants_basic.has(flag) and (best == null or sk.tier < best.tier):
			best = sk
	return {"id": best.id, "name": StringName("%s.name" % best.id)} if best != null else {}
