## B4-01: SkillPoints budget/legality (pd2_fidelity.md P1/P2) and LoadoutResolver on real skill data,
## including crew-wide (team.*) grants routed to `team_skill.<id>` sources.
extends TestCase

const FM: StringName = &"field_medic"
const TRIAGE: StringName = &"skill.field_medic.triage"            # T1
const BEDSIDE: StringName = &"skill.field_medic.bedside_manner"   # T2
const NUMB: StringName = &"skill.field_medic.numbing_agent"       # T2
const FIELD_KIT: StringName = &"skill.field_medic.field_kit"      # T3
const HOUSE_CALL: StringName = &"skill.field_medic.house_call"    # T3
const RALLY: StringName = &"skill.field_medic.rally_cry"          # T4


func before_all() -> void:
	ContentDB.clear_cache()
	SkillPoints.clear_cache()


func after_each() -> void:
	Log.capture = false
	Log.captured.clear()


## A whole subtree aced: 46 points.
func _full_field_medic() -> Dictionary:
	return {TRIAGE: 2, BEDSIDE: 2, NUMB: 2, FIELD_KIT: 2, HOUSE_CALL: 2, RALLY: 2}


func test_points_for_level() -> void:
	assert_eq(SkillPoints.points_for_level(0), 0)
	assert_eq(SkillPoints.points_for_level(1), 1)
	assert_eq(SkillPoints.points_for_level(9), 9)
	assert_eq(SkillPoints.points_for_level(10), 12)
	assert_eq(SkillPoints.points_for_level(55), 65)
	assert_eq(SkillPoints.points_for_level(100), 120)
	assert_eq(SkillPoints.points_for_level(150), 120, "clamped to max level")
	assert_eq(SkillPoints.tree_def().respec_cost, 0, "respec is free")


func test_costs_and_spent_in_subtree() -> void:
	var t: SkillDef = ContentDB.by_id(ContentDB.SKILLS, TRIAGE) as SkillDef
	var r: SkillDef = ContentDB.by_id(ContentDB.SKILLS, RALLY) as SkillDef
	assert_eq([SkillPoints.cost_of(t, 0), SkillPoints.cost_of(t, 1), SkillPoints.cost_of(t, 2)], [0, 1, 4])
	assert_eq(SkillPoints.cost_of(r, 2), 12)
	var skills: Dictionary = {TRIAGE: 2, BEDSIDE: 1, &"skill.persuader.zip_and_tie": 1}
	assert_eq(SkillPoints.spent_in_subtree(skills, FM), 6)
	assert_eq(SkillPoints.spent_in_subtree(skills, FM, 2), 4, "only tiers below 2")
	assert_eq(SkillPoints.spent_total(skills), 7)
	assert_eq(SkillPoints.spent_total(_full_field_medic()), 46)


func test_can_unlock_steps_and_reasons() -> void:
	var r: Dictionary = SkillPoints.can_unlock({}, TRIAGE, 120)
	assert_eq([r["ok"], r["cost"], r["next_level"]], [true, 1, 1])
	r = SkillPoints.can_unlock({}, BEDSIDE, 120)
	assert_eq([r["ok"], r["reason"], r["need"], r["have"]], [false, SkillPoints.REASON_TIER, 1, 0])
	r = SkillPoints.can_unlock({TRIAGE: 1}, BEDSIDE, 120)
	assert_eq([r["ok"], r["cost"]], [true, 2])
	r = SkillPoints.can_unlock({TRIAGE: 1}, TRIAGE, 120)
	assert_eq([r["ok"], r["cost"], r["next_level"]], [true, 3, 2], "ace step costs the aced price")
	r = SkillPoints.can_unlock({TRIAGE: 2}, TRIAGE, 120)
	assert_eq(r["reason"], SkillPoints.REASON_ACED)
	r = SkillPoints.can_unlock({TRIAGE: 1}, TRIAGE, 3)
	assert_eq([r["ok"], r["reason"]], [false, SkillPoints.REASON_POINTS], "1 spent + 3 > 3")
	r = SkillPoints.can_unlock({TRIAGE: 1}, FIELD_KIT, 120)
	assert_eq(r["reason"], SkillPoints.REASON_TIER, "tier 3 needs 3 points in tiers 1-2")
	r = SkillPoints.can_unlock({TRIAGE: 1, BEDSIDE: 1}, FIELD_KIT, 120)
	assert_true(r["ok"])
	r = SkillPoints.can_unlock({}, &"skill.nope.nothing", 120)
	assert_eq(r["reason"], SkillPoints.REASON_UNKNOWN)


func test_validate_accepts_legal_sets() -> void:
	assert_eq(SkillPoints.validate({}, 0), [] as Array[String])
	assert_eq(SkillPoints.validate(_full_field_medic(), 46), [] as Array[String])
	# Tier 4 needs 18 points in tiers 1-3: T1 aced 4 + T2 aced 6 + T2 aced 6 + T3 basic 3 = 19.
	var t4: Dictionary = {TRIAGE: 2, BEDSIDE: 2, NUMB: 2, FIELD_KIT: 1, RALLY: 1}
	assert_eq(SkillPoints.validate(t4, SkillPoints.points_for_level(100)), [] as Array[String])


func test_validate_rejects_illegal_sets() -> void:
	assert_eq(SkillPoints.validate(_full_field_medic(), 45).size(), 1, "over budget")
	# 16 points below tier 4 (T1 aced + both T2 aced): not enough for Rally Cry.
	var errs: Array[String] = SkillPoints.validate({TRIAGE: 2, BEDSIDE: 2, NUMB: 2, RALLY: 1}, 120)
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("rally_cry"), errs[0])
	# A skill's own points never open its tier: T1 basic + T3 basic = 4 spent, but only 1 below tier 3.
	assert_eq(SkillPoints.validate({TRIAGE: 1, FIELD_KIT: 1}, 120).size(), 1)
	assert_eq(SkillPoints.validate({TRIAGE: 3}, 120).size(), 1, "level must be 1 or 2")
	assert_eq(SkillPoints.validate({TRIAGE: 0}, 120).size(), 1, "level 0 is not a legal entry")
	assert_eq(SkillPoints.validate({&"skill.nope.nothing": 1}, 120).size(), 1, "unknown id")
	assert_false(SkillPoints.is_legal({BEDSIDE: 1}, 120), "tier 2 without tier 1")


func test_one_full_tree_does_not_fit_at_level_100() -> void:
	var tree: Dictionary = {}
	var t: SkillTreeDef = SkillPoints.tree_def()
	for sub: StringName in t.subtree_ids(&"bruiser"):
		for tier_ids: Variant in t.layout[sub]:
			for sid: Variant in tier_ids:
				tree[StringName(sid)] = 2
	assert_eq(SkillPoints.spent_total(tree), 138)
	var errs: Array[String] = SkillPoints.validate(tree, SkillPoints.points_for_level(100))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("138"), errs[0])


## Resolver on real data: MULT multiplies basic x aced, ADD sums, FLAG ors, PARAMS aced wins.
func test_resolve_modifiers_sample_build() -> void:
	var l: Loadout = Loadout.new()
	l.skills = {
		&"skill.breacher.tinker": 2, &"skill.breacher.overclocked_bits": 2,
		&"skill.breacher.percussive_maintenance": 2, RALLY: 2, FIELD_KIT: 1,
		&"skill.slipstream.deep_pockets": 2, &"skill.juggernaut.clean_shot": 1,
	}
	Log.capture = true
	var m: Dictionary = LoadoutResolver.resolve_modifiers(l)
	assert_eq(Log.captured.size(), 0, "no errors: %s" % [Log.captured])
	assert_near(float(m[&"interaction.device_speed_mult"]), 0.7, 0.001, "drill timers -30% aced")
	assert_near(float(m[&"interaction.device_auto_restart_chance"]), 0.3, 0.0001, "10% + 20%")
	assert_eq(m[&"stealth.silent_devices"], true)
	assert_eq(m[&"interaction.device_melee_restart"], true)
	assert_near(float(m[&"interaction.revive_speed_mult"]), 0.5)
	assert_eq((m[&"ability.inspire"] as Dictionary)["range"], 9.0, "aced PARAMS replace basic")
	assert_eq(m[&"deploy.extra.fak"], 7, "Field Kit basic only")
	assert_eq(m[&"defense.bullseye"], {"armor": 5.0, "cooldown": 2.0})
	l.melee = &"melee.folding_knife"
	l.armor = &"armor.patrol_vest"
	assert_eq(LoadoutResolver.concealment_bonus(l), 6, "Deep Pockets aced: melee 2 + armor 4")


func test_every_skill_aced_resolves_without_errors() -> void:
	var l: Loadout = Loadout.new()
	for sid: StringName in SkillPoints.tree_def().all_skill_ids():
		l.skills[sid] = 2
	Log.capture = true
	var m: Dictionary = LoadoutResolver.resolve_modifiers(l)
	var team: Dictionary = LoadoutResolver.team_modifier_sources(l)
	assert_eq(Log.captured.size(), 0, "no errors: %s" % [Log.captured])
	assert_true(m.size() > 50, "%d keys" % m.size())
	for key: Variant in m:
		assert_false(String(key).begins_with("team."), "team key %s kept out of personal modifiers" % key)
	assert_true(team.size() >= 1)


## modifiers.md: team keys go to TEAM as `team_skill.<skill_id>`; two players with the same skill produce
## the same source name, so it counts once.
func test_team_skill_grants_route_to_team_sources() -> void:
	var a: Loadout = Loadout.new()
	a.skills = {&"skill.persuader.zip_and_tie": 2}
	var b: Loadout = Loadout.new()
	b.skills = {&"skill.persuader.zip_and_tie": 2, TRIAGE: 1}
	var basic_only: Loadout = Loadout.new()
	basic_only.skills = {&"skill.persuader.zip_and_tie": 1}
	var personal: Dictionary = LoadoutResolver.resolve_modifiers(a)
	assert_false(personal.has(&"team.damage_reduction_hostage"))
	assert_eq(personal[&"stealth.cable_ties_extra"], 4)
	var src: StringName = &"team_skill.skill.persuader.zip_and_tie"
	var ta: Dictionary = LoadoutResolver.team_modifier_sources(a)
	assert_eq(ta, {src: {&"team.damage_reduction_hostage": {"absorb_per_hostage": 5.0, "max_hostages": 8}}})
	assert_eq(LoadoutResolver.team_modifier_sources(b).keys(), ta.keys(), "same source name for both players")
	assert_eq(LoadoutResolver.team_modifier_sources(basic_only), {}, "basic has no crew-wide grant")
