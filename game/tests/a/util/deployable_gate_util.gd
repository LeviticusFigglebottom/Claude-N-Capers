## Test-only (D-111): grants a test Loadout the DeployableGate FLAG of its deployable(s) WITHOUT adding units.
## The gate keys are ADD keys that also add units (stealth.ecm_extra, deploy.extra.trip_mine, deploy.extra.fak),
## so granting the real skill (or 1) would change the counts the tests assert. GATE_ONLY is truthy for
## Modifiers.flag() but truncates/rounds to 0 in DeployableSystem.count_for(), so base counts are kept.
## Goes through Loadout.modifiers, which LoadoutModifiers/ModifierPush hand to Modifiers (source &"loadout")
## before the crew spawns, i.e. before DeployableSystem builds the inventory.
## A loadout with skills / a perk deck whose modifiers are still empty would be resolved by LoadoutModifiers;
## setting modifiers here skips that, so only use it on skill-less test loadouts (asserted).
class_name ADeployableGateUtil
extends RefCounted

const GATE_ONLY: float = 0.001


## Adds the gate flag for `l.deployable` and `l.deployable_secondary` to `l.modifiers`; returns `l`.
static func grant(l: Loadout) -> Loadout:
	assert(l.skills.is_empty() and l.perk_deck == &"", "ADeployableGateUtil.grant: skill-less loadouts only")
	var mods: Dictionary = l.modifiers.duplicate()
	for id: StringName in [l.deployable, l.deployable_secondary]:
		var flag: StringName = DeployableGate.required_flag(id)
		if flag != &"" and not mods.has(flag):
			mods[flag] = GATE_ONLY
	l.modifiers = mods
	return l
