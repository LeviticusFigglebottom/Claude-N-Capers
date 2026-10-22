## P4 gate coverage ratchet (test_p4_progression.gd). Owner: LEAD.
## Modifier keys <= P4 that were NOT covered when the gate landed, each with the env that owns the
## missing work (tools/ci/owners.json; modifiers.md: ENV A implements hooks and behaviour tests).
## The gate fails if a key outside these lists loses coverage, and if a listed key gains it (remove it
## here: the lists only shrink). A key that gains a hook but no test moves from UNHOOKED to UNTESTED.
extends RefCounted

## No runtime code reads the key (and so no behaviour test can exist).
const UNHOOKED: Dictionary = {
	&"stealth.pocket_ecm": "A",
}

## Read by runtime code (hook file in the comment) but no behaviour test.
const UNTESTED: Dictionary = {
	&"deploy.trip_mine_radius_mult": "A",  # LEAD round 35: hooked, behaviour test pending
	&"ability.convert_damage_mult": "A",  # systems/ai/police/converted_ally_brain.gd
	&"ability.convert_speed_mult": "A",  # systems/ai/police/police_surrender.gd
	&"defense.armor_regen_rate_mult": "A",  # systems/combat/team_modifiers.gd
	&"defense.bleedout_time_add": "A",  # systems/combat/crew_health.gd
	&"defense.revived_health_mult": "A",  # systems/combat/crew_health.gd
	&"deploy.deploy_speed_mult": "A",  # systems/deployables/deployable_system.gd, ...
	&"deploy.second_deployable": "A",  # systems/deployables/deployable_system.gd
	&"loot.can_sprint_with_heavy": "A",  # systems/player/crew_controller.gd
	&"loot.carry_speed_penalty_mult": "A",  # systems/player/crew_controller.gd
	&"movement.crouch_speed_mult": "A",  # systems/player/crew_controller.gd
	&"stealth.body_bag_concealed_carry": "A",  # systems/player/crew_controller.gd
	&"stealth.cable_tie_speed_mult": "A",  # systems/ai/civilian/civilian_brain.gd, ...
	&"stealth.civilian_intimidate_range_mult": "A",  # systems/stealth/shout_system.gd
	&"stealth.civilian_stay_down_mult": "A",  # systems/ai/civilian/civilian_brain.gd
	&"stealth.ecm_feedback_duration_mult": "A",  # systems/deployables/ecm_system.gd
	&"weapon.ammo_total_mult": "A",  # systems/combat/crew_weapons.gd, ...
	&"weapon.melee_bloodthirst": "A",  # systems/combat/crew_melee.gd
	&"weapon.melee_charge_speed_mult": "A",  # systems/anim/fp_viewmodel.gd, ...
	&"weapon.recoil_mult": "A",  # systems/combat/crew_weapons.gd
	&"weapon.saw_damage_mult": "A",  # systems/combat/special_weapons.gd
	&"weapon.saw_shield_pierce": "A",  # systems/combat/special_weapons.gd
	&"weapon.saw_wear_mult": "A",  # systems/combat/special_weapons.gd
	&"weapon.shield_knockback": "A",  # systems/combat/crew_melee.gd
	&"weapon.swap_speed_mult": "A",  # systems/combat/crew_weapons.gd, ...
}
