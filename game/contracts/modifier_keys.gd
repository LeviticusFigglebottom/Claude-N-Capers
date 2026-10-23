## Registry of every modifier key that skills / perk cards / assets / difficulty may grant.
## Owner: LEAD. Contract: docs/contracts/modifiers.md (v1).
##
## - ENV B may only GRANT keys listed here (CI test checks content/data against this table).
## - ENV A must IMPLEMENT a hook for every key whose `phase` <= current roadmap phase.
## - New keys: ask the lead (status file question); the lead adds them here.
##
## Types: MULT (product of sources, default 1.0), ADD (sum, default 0), FLAG (any source true),
##        PARAMS (Dictionary; last-granted wins; used for perk-deck signature mechanics),
##        LIST (every source's Dictionary is kept: Modifiers.list(); for triggered effects several
##        skills grant independently, D-031).
## Weapon qualifiers: a weapon class (Enums.WeaponClass lowercased), `suppressed`, `akimbo`, or `all`.
## Keys ending in `.<class>` accept a weapon-class qualifier (see Enums.WeaponClass names) or `.all`.
class_name ModifierKeys
extends RefCounted

enum Type { MULT, ADD, FLAG, PARAMS, LIST }

## key -> [Type, phase_introduced, description]
const KEYS: Dictionary = {
	# --- Stealth ---------------------------------------------------------------
	&"stealth.detection_rate_mult": [Type.MULT, 1, "Speed at which observers fill detection on you (masked)."],
	&"stealth.casing_detection_rate_mult": [Type.MULT, 2, "Same, while in casing mode (Chameleon basic analog)."],
	&"stealth.casing_can_pickup_items": [Type.FLAG, 2, "Pick up small loot/items while casing (Chameleon aced analog)."],
	&"stealth.concealment_add": [Type.ADD, 4, "Concealment points added (qualifier: melee/armor/primary/secondary/all)."],
	&"stealth.mark_duration_mult": [Type.MULT, 2, "Duration of marks on enemies/cameras."],
	&"stealth.mark_damage_bonus_mult": [Type.MULT, 3, "Marked enemies take more damage (High Value Target analog)."],
	&"stealth.body_bags_extra": [Type.ADD, 1, "Extra body bags carried."],
	&"stealth.body_bag_speed_mult": [Type.MULT, 2, "Body bagging interaction speed (lower = faster)."],
	&"stealth.body_bag_concealed_carry": [Type.FLAG, 2, "Carrying body bags does not slow you (Cleaner-like)."],
	&"stealth.cable_ties_extra": [Type.ADD, 1, "Extra cable ties."],
	&"stealth.cable_tie_speed_mult": [Type.MULT, 2, "Tie speed."],
	&"stealth.pager_answer_speed_mult": [Type.MULT, 2, "Pager answer channel time multiplier."],
	&"stealth.can_dominate_guards": [Type.FLAG, 3, "Shouting at a guard can force surrender (Hostage Taker / Dominator analog)."],
	&"stealth.civilian_intimidate_range_mult": [Type.MULT, 2, "Shout range vs civilians."],
	&"stealth.civilian_stay_down_mult": [Type.MULT, 2, "How long intimidated civilians stay down."],
	&"stealth.silent_devices": [Type.FLAG, 2, "Drills/saws make no noise; NPCs must SEE them (Hardware-Expert aced analog)."],
	&"stealth.ecm_extra": [Type.ADD, 2, "Extra ECM jammers."],
	&"stealth.ecm_duration_mult": [Type.MULT, 2, "ECM jam duration."],
	&"stealth.ecm_feedback": [Type.FLAG, 2, "ECM can trigger feedback (stuns enemies in radius)."],
	&"stealth.ecm_feedback_duration_mult": [Type.MULT, 3, "Feedback duration."],
	&"stealth.ecm_feedback_retrigger": [Type.FLAG, 3, "ECM feedback can recharge and be retriggered."],
	&"stealth.ecm_pager_delay": [Type.FLAG, 2, "Pagers of guards killed during an ECM jam pause (ECM Specialist aced)."],
	&"stealth.ecm_opens_doors": [Type.FLAG, 2, "Placing an ECM on certain electronic doors/ATMs opens them."],
	&"stealth.pocket_ecm": [Type.PARAMS, 3, "Hacker-deck pocket ECM: {charges, duration, cooldown}."],
	&"stealth.sixth_sense": [Type.FLAG, 2, "Standing still briefly auto-marks nearby enemies in stealth."],
	&"stealth.camera_loop": [Type.FLAG, 3, "Interact with a camera to loop it for 20 s (stealth only)."],

	# --- Interaction / devices -----------------------------------------------
	&"interaction.speed_mult": [Type.MULT, 2, "General interaction speed (lower = faster)."],
	&"interaction.lockpick_speed_mult": [Type.MULT, 2, "Lockpick speed."],
	&"interaction.can_lockpick_safes": [Type.FLAG, 3, "Can lockpick small safes."],
	&"interaction.device_speed_mult": [Type.MULT, 1, "Drill/saw speed (lower = faster)."],
	&"interaction.device_jam_chance_mult": [Type.MULT, 1, "Drill/saw jam chance."],
	&"interaction.device_auto_restart_chance": [Type.ADD, 2, "Chance a jammed device restarts itself."],
	&"interaction.device_melee_restart": [Type.FLAG, 2, "Melee a jammed device to try restarting it."],
	&"interaction.shaped_charge": [Type.FLAG, 3, "Trip mines can be used as shaped charges on doors/safes."],
	&"interaction.revive_speed_mult": [Type.MULT, 1, "Revive speed."],

	# --- Loot ------------------------------------------------------------------
	&"loot.carry_speed_penalty_mult": [Type.MULT, 2, "Bag move-speed penalty multiplier (lower = faster)."],
	&"loot.throw_distance_mult": [Type.MULT, 2, "Bag throw distance."],
	&"loot.can_sprint_with_heavy": [Type.FLAG, 3, "Sprint while carrying heavy bags."],

	# --- Movement --------------------------------------------------------------
	&"movement.speed_mult": [Type.MULT, 2, "Base move speed."],
	&"movement.crouch_speed_mult": [Type.MULT, 2, "Crouch move speed."],
	&"movement.stamina_mult": [Type.MULT, 2, "Stamina pool."],
	&"movement.shoot_while_sprinting": [Type.FLAG, 3, "Fire while sprinting."],
	&"movement.reload_while_sprinting": [Type.FLAG, 3, "Reload while sprinting."],

	# --- Defense ---------------------------------------------------------------
	&"defense.health_mult": [Type.MULT, 1, "Max health."],
	&"defense.armor_mult": [Type.MULT, 1, "Max armor."],
	&"defense.armor_regen_delay_mult": [Type.MULT, 1, "Delay before armor starts regenerating."],
	&"defense.armor_regen_rate_mult": [Type.MULT, 2, "Armor regeneration speed."],
	&"defense.dodge_add": [Type.ADD, 2, "Dodge chance (0..1) added."],
	&"defense.damage_taken_mult": [Type.MULT, 2, "All incoming damage."],
	&"defense.health_regen_per_sec": [Type.ADD, 3, "Fraction of max health regenerated per second."],
	&"defense.bleedout_time_add": [Type.ADD, 2, "Seconds added to bleed-out timer."],
	&"defense.downs_extra": [Type.ADD, 2, "Extra downs before custody."],
	&"defense.revived_health_mult": [Type.MULT, 2, "Health you return with after a revive."],
	&"defense.self_revive_charges": [Type.ADD, 3, "Get-up-yourself charges (Messiah analog)."],
	&"defense.swan_song": [Type.PARAMS, 3, "On downed: keep fighting for {duration} with {speed_penalty}."],
	&"defense.shockproof": [Type.PARAMS, 3, "Taser counter: {tase_shorten, can_interact_counter}."],
	&"defense.cloaker_counter": [Type.FLAG, 3, "Melee-countering a charging Phantom knocks it down."],
	&"defense.berserk": [Type.PARAMS, 3, "Low-health damage bonus: {threshold, max_damage_mult}."],
	&"defense.bullseye": [Type.PARAMS, 3, "Headshot kills regen armor: {armor, cooldown}."],

	# --- Weapons (qualified by weapon class or .all) ---------------------------
	&"weapon.damage_mult": [Type.MULT, 1, "Weapon damage."],
	&"weapon.saw_wear_mult": [Type.MULT, 4, "Saw blade wear per second (lower = blades last longer)."],
	&"weapon.saw_damage_mult": [Type.MULT, 4, "Saw damage to enemies."],
	&"weapon.saw_shield_pierce": [Type.FLAG, 4, "Saw cuts through shields."],
	&"weapon.reload_speed_mult": [Type.MULT, 2, "Reload speed (higher = faster)."],
	&"weapon.spread_mult": [Type.MULT, 2, "Spread/accuracy cone multiplier (lower = tighter)."],
	&"weapon.recoil_mult": [Type.MULT, 2, "Recoil multiplier (lower = steadier)."],
	&"weapon.mag_extra": [Type.ADD, 2, "Extra rounds per magazine."],
	&"weapon.ammo_total_mult": [Type.MULT, 2, "Total ammo pool."],
	&"weapon.ammo_pickup_mult": [Type.MULT, 2, "Ammo pickup amount."],
	&"weapon.headshot_mult": [Type.MULT, 2, "Headshot damage multiplier bonus."],
	&"weapon.armor_pierce_add": [Type.ADD, 3, "Armor-piercing chance (0..1)."],
	&"weapon.swap_speed_mult": [Type.MULT, 2, "Weapon swap speed (higher = faster)."],
	&"weapon.ads_speed_mult": [Type.MULT, 2, "Aim-down-sights speed."],
	&"weapon.crit_chance_add": [Type.ADD, 3, "Critical hit chance (ignores... doubles damage)."],
	&"weapon.shield_pierce": [Type.FLAG, 3, "Rounds penetrate Bulwark shields."],
	&"weapon.melee_charge_speed_mult": [Type.MULT, 3, "Melee charge speed."],

	# --- Crowd control / team ----------------------------------------------------
	&"ability.inspire": [Type.PARAMS, 2, "Shout-revive at range: {range, cooldown}; basic part gives team speed/reload buff."],
	&"ability.converts_max": [Type.ADD, 3, "Number of surrendered cops that can be converted to allies (Joker analog)."],
	&"ability.convert_health_mult": [Type.MULT, 3, "Converted ally health."],
	&"ability.hostage_regen": [Type.PARAMS, 3, "Per-hostage health regen {per_hostage, max_hostages}."],
	&"ability.stockholm": [Type.FLAG, 3, "Hostages may revive you; civilians stay down longer."],
	&"ability.intimidate_cops": [Type.FLAG, 3, "Shout can make low-tier police surrender."],
	&"team.health_mult": [Type.MULT, 3, "Crew-wide health (Foreman-style)."],
	&"team.armor_mult": [Type.MULT, 3, "Crew-wide armor."],
	&"team.stamina_mult": [Type.MULT, 3, "Crew-wide stamina."],
	&"team.damage_reduction_hostage": [Type.PARAMS, 3, "Crew flat damage absorption per hostage {absorb_per_hostage, max_hostages} (D-056)."],

	# --- Deployables (qualified by deployable kind) ------------------------------
	&"deploy.extra": [Type.ADD, 2, "Extra deployable units (qualifier: kind)."],
	&"deploy.capacity_mult": [Type.MULT, 3, "Uses/charges per deployable (qualifier: kind)."],
	&"deploy.second_deployable": [Type.FLAG, 3, "Carry two deployable kinds (Jack of all Trades analog)."],

	# --- Perk-deck signature mechanics (PARAMS; see pd2_fidelity.md §P) -----------
	&"perk.stoic": [Type.PARAMS, 4, "Composure: armor->0, damage becomes DoT; flask negates remaining DoT."],
	&"perk.grinder": [Type.PARAMS, 4, "Bloodletter: dealing damage grants stacking heal-over-time."],
	&"perk.anarchist": [Type.PARAMS, 4, "Overclock: armor regenerates in periodic chunks, no delay."],
	&"perk.ex_president": [Type.PARAMS, 4, "Incumbent: kills store health, released when armor regenerates."],
	&"perk.gambler": [Type.PARAMS, 4, "Long Odds: ammo pickups heal you and the team."],
	&"perk.kingpin": [Type.PARAMS, 4, "Overlord: injector throwable, heal from damage taken for 6 s."],
	&"perk.yakuza": [Type.PARAMS, 5, "Inkwork (Yakuza): lower health, faster armor regen + move speed."],
	&"perk.biker": [Type.PARAMS, 5, "Road Crew (Biker): any crew kill gives health + armor, rate-limited."],
	&"perk.maniac": [Type.PARAMS, 5, "Frenzy (Maniac): damage dealt -> Hysteria stacks -> flat absorb, crew-shared."],
	&"perk.sociopath": [Type.PARAMS, 4, "Clean Sweep: kills near enemies restore armor/health on cooldowns."],
	&"perk.rogue_dodge_stack": [Type.PARAMS, 4, "Slipper: reduced aggro near crew (dodge/swap/AP via generic keys)."],
	&"perk.crook": [Type.PARAMS, 4, "Hustler: dodge + armor bonus in Light/Patrol/Heavy vests only."],
	&"perk.burglar": [Type.PARAMS, 4, "Prowler: still/crouching lowers enemy targeting weight and armor regen delay "
		+ "{still_aggro_mult, still_regen_delay_mult}; its stealth speed/dodge cards use generic keys."],
	&"perk.infiltrator": [Type.PARAMS, 4, "Knuckles: close-range damage reduction, melee buffs."],
	&"perk.muscle": [Type.PARAMS, 4, "Bulk: health regen, threat increase."],
	&"perk.armorer": [Type.PARAMS, 4, "Ironclad: armor bonus, brief invulnerability on armor break."],
	&"perk.crew_chief": [Type.PARAMS, 4, "Foreman: team-wide stacking buffs."],
	&"perk.throwable": [Type.PARAMS, 4, "Deck-granted throwable item replacing grenades {item_id}."],

	# --- P4 skill + perk keys (ENV B requests QB-31/QB-32, approved D-031) ---------
	&"defense.reviving_damage_taken_mult": [Type.PARAMS, 4, "Incoming damage x mult while you hold a revive interaction and for..."],
	&"ability.revive_target_health_mult": [Type.MULT, 4, "Health a crew member YOU revive gets up with (the reviver's skill;..."],
	&"ability.revive_target_buff": [Type.PARAMS, 4, "A crew member you revive takes damage x damage_taken_mult for duration s."],
	&"deploy.medical_user_buff": [Type.PARAMS, 4, "Anyone using your First Aid Kit or Doctor Bag takes damage x damage_taken_mult for..."],
	&"deploy.fak_auto_revive": [Type.PARAMS, 4, "A crew member downed within radius m of your placed First Aid Kit consumes it and is..."],
	&"defense.bleedout_health_mult": [Type.MULT, 4, "Bleedout HP (100 base, L2.5)."],
	&"defense.post_revive_buff": [Type.LIST, 4, "Buffs on yourself for duration s after being revived (1.0 = none). Basic/aced..."],
	&"defense.bleedout_pause_unseen": [Type.FLAG, 4, "Bleedout timer pauses while no enemy has line of sight to you (counts again as..."],
	&"defense.self_revive_refill_on_doctor_bag": [Type.FLAG, 4, "Using a Doctor Bag restores your defense.self_revive_charges to..."],
	&"defense.healing_received_mult": [Type.MULT, 4, "All healing you receive (bags, kits, regen, perks)."],
	&"ability.convert_damage_mult": [Type.MULT, 4, "Damage dealt by your converted allies."],
	&"ability.convert_speed_mult": [Type.MULT, 4, "Convert interaction time (lower = faster)."],
	&"ability.convert_owner_buff": [Type.PARAMS, 4, "While you own at least one living convert: your move speed and max health..."],
	&"stealth.noise_intimidates_civilians": [Type.FLAG, 4, "Your unsuppressed gunfire acts as an intimidation shout on civilians..."],
	&"weapon.still_spread_mult": [Type.MULT, 4, "Spread multiplier while you stand still."],
	&"weapon.moving_spread_mult": [Type.MULT, 4, "Multiplier on the moving-spread penalty (lower = smaller penalty)."],
	&"weapon.hip_spread_mult": [Type.MULT, 4, "Spread multiplier for hip fire only."],
	&"weapon.fire_rate_mult": [Type.MULT, 4, "Rate of fire (higher = faster)."],
	&"weapon.hip_fire_rate_mult": [Type.MULT, 4, "Rate of fire while hip firing (single-shot weapons)."],
	&"weapon.falloff_range_mult": [Type.MULT, 4, "Scales falloff_start/falloff_end distances."],
	&"movement.ads_speed_penalty_mult": [Type.MULT, 4, "Move-speed penalty while aiming down sights (0 = no penalty)."],
	&"weapon.kill_damage_buff": [Type.LIST, 4, "A kill with trigger_class gives damage x damage_mult for duration s, to that class or..."],
	&"weapon.kill_reload_buff": [Type.LIST, 4, "auto_kills"],
	&"weapon.hit_stack_buff": [Type.LIST, 4, "damage), per_hit: float, max_stacks: int, duration: float}"],
	&"weapon.headshot_refund": [Type.PARAMS, 4, "headshots headshots within window s refund refund rounds to the magazine."],
	&"weapon.graze": [Type.PARAMS, 4, "Hits deal frac of the damage to enemies within radius m of the trajectory; headshot_kill_frac..."],
	&"weapon.body_expertise": [Type.PARAMS, 4, "Fraction of the headshot bonus applied to non-head hits for automatic fire."],
	&"weapon.stagger_chance_add": [Type.ADD, 4, "Chance per hit to stagger a non-immune enemy."],
	&"weapon.unseen_strike": [Type.PARAMS, 4, "After idle_s without losing armor/health, +crit_add crit chance for duration s (taking..."],
	&"weapon.crit_per_concealment": [Type.PARAMS, 4, "Crit chance from detection risk below threshold_dr (35): +per_step per..."],
	&"weapon.melee_bloodthirst": [Type.PARAMS, 4, "Each non-melee kill adds per_kill to the next melee hit's multiplier (cap..."],
	&"weapon.melee_knockdown_mult": [Type.MULT, 4, "Knockdown chance of your melee hits."],
	&"weapon.shield_knockback": [Type.FLAG, 4, "Hits can knock Bulwarks back (melee 100%, ranged by damage)."],
	&"defense.outnumbered": [Type.PARAMS, 4, "With enemies+ enemies within radius m: damage and damage-taken multipliers for duration s."],
	&"defense.flashbang_duration_mult": [Type.MULT, 4, "Flashbang blind duration."],
	&"defense.interact_damage_taken_mult": [Type.MULT, 4, "Incoming damage while holding an interaction."],
	&"defense.armor_break_speed_buff": [Type.PARAMS, 4, "On armor break: move speed for duration s, also for the crew if team."],
	&"defense.target_priority_mult": [Type.MULT, 4, "Weight of you in enemy target selection (lower = targeted less)."],
	&"defense.armor_broken_stagger": [Type.PARAMS, 4, "While armor is broken (and persist_s after it recovers) your first hit on each..."],
	&"defense.dodge_per_concealment": [Type.PARAMS, 4, "Dodge from detection risk below threshold_dr (35), same shape as..."],
	&"defense.sprint_dodge_add": [Type.ADD, 4, "Dodge added while sprinting."],
	&"defense.melee_damage_taken_mult": [Type.MULT, 4, "Incoming melee damage."],
	&"defense.melee_counter": [Type.FLAG, 4, "While charging melee, an enemy melee strike on you is countered (knockdown, no damage)."],
	&"movement.sprint_speed_mult": [Type.MULT, 4, "Sprint speed."],
	&"movement.sprint_any_direction": [Type.FLAG, 4, "Sprint sideways/backwards."],
	&"team.armor_regen_rate_mult": [Type.MULT, 4, "Crew-wide armor regeneration speed (team key, non-stacking)."],
	&"stealth.casing_can_mark": [Type.FLAG, 4, "Mark guards and cameras while casing."],
	&"loot.small_loot_value_mult": [Type.MULT, 4, "Value of small loot (cash/jewelry pickups) you pick up."],
	&"stealth.mark_far_damage_mult": [Type.PARAMS, 4, "Extra damage multiplier on your marked enemies beyond min_distance m."],
	&"stealth.mark_by_aim": [Type.FLAG, 4, "Aiming at a special for a moment marks it (any weapon)."],
	&"deploy.deploy_speed_mult": [Type.MULT, 4, "Deploy/use time of deployables (lower = faster)."],
	&"deploy.sentry_cost_mult": [Type.MULT, 4, "Fraction of your ammo a sentry costs to deploy."],
	&"deploy.sentry_shield": [Type.FLAG, 4, "Your sentries have a frontal shield."],
	&"deploy.sentry_accuracy_mult": [Type.MULT, 4, "Sentry spread (lower = more accurate)."],
	&"deploy.sentry_turn_speed_mult": [Type.MULT, 4, "Sentry rotation speed."],
	&"deploy.sentry_health_mult": [Type.MULT, 4, "Sentry health."],
	&"deploy.sentry_modes": [Type.PARAMS, 4, "Unlocks switchable sentry modes (interact to cycle)."],
	&"deploy.trip_mine_radius_mult": [Type.MULT, 4, "Trip mine blast radius."],
	&"deploy.trip_mine_fire": [Type.PARAMS, 4, "Detonations leave a fire area."],
	&"deploy.ammo_bag_bulletstorm": [Type.PARAMS, 4, "Users of your ammo bags fire without using ammo for a duration scaled by the..."],
	&"weapon.ammo_pickup_range_mult": [Type.MULT, 4, "Ammo box pickup radius."],
	&"weapon.kill_ammo_drop": [Type.PARAMS, 4, "Every n-th kill drops an extra ammo box."],
	&"weapon.ammo_pickup_throwable": [Type.PARAMS, 4, "Ammo boxes may contain a throwable; chance grows by step per box without one,..."],
	&"interaction.device_fix_speed_mult": [Type.MULT, 4, "Time to fix a jammed drill/saw (lower = faster)."],
	&"progression.xp_mult": [Type.MULT, 4, "Heist XP multiplier (payout calculator)."],
	&"movement.armor_penalty_mult": [Type.MULT, 4, "Scales the armor's move-speed penalty (1 − ArmorDef.move_speed_mult)."],
	&"deploy.armor_bag": [Type.FLAG, 4, "Unlocks the armor bag deployable (change armor mid-heist)."],
	&"interaction.doctor_bag_speed_mult": [Type.MULT, 4, "Doctor bag use time multiplier (lower = faster)."],
	&"progression.card_drop_quality_add": [Type.ADD, 4, "Chance that a PAYDAY card rolls the next quality tier."],
	&"ability.shout_range_mult": [Type.MULT, 4, "Shout distance (all shout targets). The existing..."],
	&"team.armor_regen_delay_mult": [Type.MULT, 4, "Crew-wide armor regen delay multiplier (lower = sooner; Ironclad card 9)."],
}


static func is_known(key: StringName) -> bool:
	if KEYS.has(key):
		return true
	return KEYS.has(base_key(key))


## "weapon.damage_mult.shotgun" -> "weapon.damage_mult"
static func base_key(key: StringName) -> StringName:
	var s: String = String(key)
	var parts: PackedStringArray = s.split(".")
	if parts.size() >= 3:
		return StringName(parts[0] + "." + parts[1])
	return key


static func type_of(key: StringName) -> Type:
	var entry: Array = KEYS.get(key, KEYS.get(base_key(key), [Type.MULT, 0, ""]))
	return entry[0]
