## B5-02 Notoriety ranks (pd2_fidelity P10): rank-up rules (level 100, cash cost, cap 25, level/XP reset,
## cash deducted, rewards granted), the held skill builds that come back with levels (always legal), perk
## points kept, reward choices and music unlock ids (D-062). Bonus, payout and lobby: test_notoriety_bonus.gd.
extends TestCase

const LIGHT_STEP: StringName = &"skill.slipstream.light_step"
const THICK_SKIN: StringName = &"skill.juggernaut.thick_skin"


func before_each() -> void:
	Notoriety.clear_cache()


func after_all() -> void:
	Log.capture = false
	Log.captured.clear()


## A level-100 profile with enough cash for the next rank and an aced two-skill build in set 0.
func _veteran(rank: int = 0) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.notoriety = rank
	p.xp = XpCurve.xp_for_level(100)
	p.level = 100
	p.cash = Notoriety.cost_for(rank + 1) + 1000
	p.loadout.skills = {LIGHT_STEP: 2, THICK_SKIN: 2}
	p.skill_sets[0] = p.loadout.skills.duplicate()
	p.skill_sets[1] = {THICK_SKIN: 1}
	return p


func test_tweak_and_table_data() -> void:
	var t: NotorietyTweak = Notoriety.tweak()
	assert_eq(t.max_rank, 25)
	assert_eq(t.required_level, 100)
	assert_eq(t.costs.size(), t.max_rank, "one cost per rank")
	for r: int in range(2, t.max_rank + 1):
		assert_true(Notoriety.cost_for(r) > Notoriety.cost_for(r - 1), "cost grows at rank %d" % r)
	assert_eq(Notoriety.cost_for(0), 0)
	assert_eq(Notoriety.cost_for(26), 0)
	var strings: Dictionary = StringTable.parse_csv()
	var seen: Dictionary = {}
	for d: NotorietyDef in Notoriety.table().ranks:
		assert_true(d.rank >= 1 and d.rank <= t.max_rank, "rank %d in range" % d.rank)
		assert_false(seen.has(d.rank), "rank %d listed once" % d.rank)
		seen[d.rank] = true
		for id: StringName in d.rewards + d.choices:
			assert_true(MaskCatalog.has_part(id) or ContentDB.has(ContentDB.MASKS, id), "%s exists" % id)
			assert_has(strings, String(UiText.item_key(id)), "%s has a name" % id)
		for id: StringName in d.unlocks:
			assert_true(String(id).begins_with("unlock."), "%s is an unlock id" % id)
			assert_has(strings, "ui.notoriety.unlock." + String(id), "%s has a preview name" % id)
	for md: MaskDef in MaskCatalog.presets():
		if String(md.unlock).begins_with(Notoriety.UNLOCK_PREFIX):
			assert_has(strings, "item.%s.desc" % md.id)
			assert_true(md.model != null, "%s has its base mesh" % md.id)


func test_roman_numerals() -> void:
	assert_eq(Notoriety.roman(1), "I")
	assert_eq(Notoriety.roman(4), "IV")
	assert_eq(Notoriety.roman(9), "IX")
	assert_eq(Notoriety.roman(14), "XIV")
	assert_eq(Notoriety.roman(19), "XIX")
	assert_eq(Notoriety.roman(25), "XXV")
	assert_eq(Notoriety.roman(0), "")


func test_cannot_rank_up_below_level_100_or_without_cash() -> void:
	var p: PlayerProfile = _veteran()
	p.level = 99
	var r: Dictionary = Notoriety.rank_up(p)
	assert_false(bool(r["ok"]))
	assert_eq(r["reason"], Notoriety.REQ_LEVEL)
	assert_eq(p.notoriety, 0, "nothing changed")
	assert_eq(p.level, 99)
	p = _veteran()
	p.cash = Notoriety.cost_for(1) - 1
	r = Notoriety.rank_up(p)
	assert_false(bool(r["ok"]))
	assert_eq(r["reason"], Notoriety.REQ_CASH)
	assert_eq(p.cash, Notoriety.cost_for(1) - 1, "no cash taken")
	assert_false(Notoriety.can_rank_up(p))
	p.stash = 999999999
	assert_false(Notoriety.can_rank_up(p), "the stash does not pay for a rank")


func test_rank_up_resets_level_and_xp_and_takes_the_cost() -> void:
	var p: PlayerProfile = _veteran()
	var xp: int = p.xp
	var stash: int = p.stash
	var owned: Array[StringName] = p.owned_weapons.duplicate()
	var r: Dictionary = Notoriety.rank_up(p)
	assert_true(bool(r["ok"]))
	assert_eq(r["rank"], 1)
	assert_eq(r["cost"], 5000000)
	assert_eq(p.notoriety, 1)
	assert_eq(p.level, 0)
	assert_eq(p.xp, 0)
	assert_eq(p.cash, 1000, "cash minus the cost")
	assert_eq(p.stash, stash, "stash kept")
	assert_eq(p.notoriety_xp, xp, "the retired XP is kept for perk points")
	assert_eq(p.owned_weapons, owned, "items kept")
	assert_eq(p.loadout.mask, &"mask.gilded_heron", "mask kept")


func test_rank_up_grants_rewards_and_unlocks() -> void:
	var p: PlayerProfile = _veteran()
	var r: Dictionary = Notoriety.rank_up(p)
	assert_has(p.unlocks, &"unlock.notoriety.rank_1")
	assert_has(p.owned_mask_parts, &"mask_colors.crown_ember")
	assert_has(r["granted"] as Array, &"mask_colors.crown_ember")
	assert_true(MaskLocker.is_part_owned(p, &"mask_colors.crown_ember"))
	# rank 10 owns its preset through the rank unlock id
	var q: PlayerProfile = _veteran(9)
	Notoriety.rank_up(q)
	assert_true(MaskLocker.is_equippable(q, &"mask.ledger_regent"), "rank X preset")
	assert_has(Notoriety.rewards_for(10), &"mask.ledger_regent")
	assert_has(Notoriety.rewards_for(25), &"mask.last_word")


func test_music_unlock_ids_are_granted() -> void:
	var ranks: Array[int] = []
	var music: Array[int] = []
	for d: NotorietyDef in Notoriety.table().ranks:
		if not d.unlocks.is_empty():
			ranks.append(d.rank)
		for id: StringName in d.unlocks:
			if String(id).begins_with("unlock.music.") and not music.has(d.rank):
				music.append(d.rank)
	assert_true(music.size() >= 2 and music.size() <= 3, "2-3 ranks carry a music unlock")
	for rank: int in ranks:
		var p: PlayerProfile = _veteran(rank - 1)
		var r: Dictionary = Notoriety.rank_up(p)
		for id: StringName in Notoriety.def_for(rank).unlocks:
			assert_true(String(id).begins_with("unlock.music.") or String(id).begins_with("unlock.finish."),
					"%s is a music or weapon finish unlock (B7-04)" % id)
			assert_has(p.unlocks, id, "rank %d grants %s" % [rank, id])
			assert_has(r["granted"] as Array, id)


func test_cap_is_25() -> void:
	var p: PlayerProfile = _veteran(25)
	p.cash = 999999999
	var r: Dictionary = Notoriety.rank_up(p)
	assert_false(bool(r["ok"]))
	assert_eq(r["reason"], Notoriety.REQ_CAP)
	assert_eq(p.notoriety, 25)
	assert_eq(p.level, 100, "nothing reset at the cap")
	var p24: PlayerProfile = _veteran(24)
	assert_true(bool(Notoriety.rank_up(p24)["ok"]))
	assert_eq(p24.notoriety, 25)
	assert_true(MaskLocker.is_equippable(p24, &"mask.last_word"), "rank XXV preset")


func test_skill_budget_stays_legal_and_builds_come_back() -> void:
	var p: PlayerProfile = _veteran()
	Notoriety.rank_up(p)
	assert_eq(p.loadout.skills, {}, "no points at level 0")
	assert_eq(p.skill_sets[0], {})
	assert_eq(p.held_skill_sets[0], {LIGHT_STEP: 2, THICK_SKIN: 2}, "the build is held")
	assert_eq(p.held_skill_sets[1], {THICK_SKIN: 1})
	assert_eq(ProfileValidator.validate(p), [] as Array[String], "the ranked-up profile is valid")
	for xp_level: int in [1, 2, 3, 5, 8, 20]:
		SaveService.apply_heist_payout(p, {"xp_total": XpCurve.xp_for_level(xp_level) - p.xp}, XpCurve.level_for_xp)
		assert_eq(p.level, xp_level)
		for i: int in range(p.skill_sets.size()):
			var budget: int = SkillPoints.points_for_level(p.level)
			assert_true(SkillPoints.is_legal(p.skill_set(i), budget), "set %d legal at level %d" % [i, p.level])
			assert_true(SkillPoints.spent_total(p.skill_set(i)) <= budget)
		assert_eq(p.loadout.skills, p.skill_sets[p.active_skill_set], "loadout mirrors the active set")
	assert_eq(p.loadout.skills, {LIGHT_STEP: 2, THICK_SKIN: 2}, "the whole build is back")
	assert_eq(p.held_skill_sets[0], {}, "hold released once complete")
	assert_eq(p.skill_sets[1], {THICK_SKIN: 1})


func test_partial_restore_is_lowest_tier_first_and_legal() -> void:
	var p: PlayerProfile = _veteran()
	Notoriety.rank_up(p)
	SaveService.apply_heist_payout(p, {"xp_total": XpCurve.xp_for_level(3)}, XpCurve.level_for_xp)
	assert_eq(p.level, 3)
	var budget: int = SkillPoints.points_for_level(3)
	assert_true(SkillPoints.spent_total(p.loadout.skills) <= budget)
	assert_true(SkillPoints.spent_total(p.loadout.skills) > 0, "some points came back")
	assert_eq(NotorietySkills.held_points(p, 0),
			SkillPoints.spent_total({LIGHT_STEP: 2, THICK_SKIN: 2}) - SkillPoints.spent_total(p.loadout.skills))


func test_release_hands_the_build_back() -> void:
	var p: PlayerProfile = _veteran()
	Notoriety.rank_up(p)
	NotorietySkills.release(p, 0)
	SaveService.apply_heist_payout(p, {"xp_total": XpCurve.xp_for_level(20)}, XpCurve.level_for_xp)
	assert_eq(p.loadout.skills, {}, "a released set is not refilled")
	assert_eq(p.skill_sets[1], {THICK_SKIN: 1}, "other sets still refill")


func test_payday_card_xp_restores_too() -> void:
	var p: PlayerProfile = _veteran()
	Notoriety.rank_up(p)
	PaydayCards.grant(p, {"type": PaydayCards.XP, "amount": XpCurve.xp_for_level(20)})
	assert_eq(p.level, 20)
	assert_eq(p.loadout.skills, {LIGHT_STEP: 2, THICK_SKIN: 2})


func test_rank_up_twice_merges_the_hold() -> void:
	var p: PlayerProfile = _veteran()
	Notoriety.rank_up(p)
	p.level = 100
	p.xp = XpCurve.xp_for_level(100)
	p.cash = Notoriety.cost_for(2)
	assert_true(bool(Notoriety.rank_up(p)["ok"]))
	assert_eq(p.held_skill_sets[0], {LIGHT_STEP: 2, THICK_SKIN: 2}, "an unrestored hold survives the next rank")
	assert_eq(p.notoriety_xp, 2 * XpCurve.xp_for_level(100))


func test_perk_points_survive_the_reset() -> void:
	var p: PlayerProfile = _veteran()
	var tw: ProgressionUiTweak = ProgressionUiTweak.load_default()
	var earned: int = PerkProgress.earned(p, tw)
	Notoriety.rank_up(p)
	assert_eq(PerkProgress.earned(p, tw), earned, "perk points count the retired XP")


func test_reward_choice_narrows_the_pool() -> void:
	var p: PlayerProfile = _veteran(4)
	Notoriety.rank_up(p)
	assert_eq(Notoriety.pending_choices(p), [5] as Array[int])
	var opts: Array[StringName] = Notoriety.choice_options(p, 5)
	assert_eq(opts.size(), 3)
	assert_false(Notoriety.choose(p, 5, &"mask_colors.bone_ink"), "not an option")
	assert_false(Notoriety.choose(p, 15, opts[0]), "rank not reached")
	assert_true(Notoriety.choose(p, 5, opts[1]))
	assert_true(MaskLocker.is_part_owned(p, opts[1]))
	assert_eq(p.notoriety_choices[5], opts[1])
	assert_eq(Notoriety.pending_choices(p), [] as Array[int])
	assert_false(Notoriety.choose(p, 5, opts[0]), "one pick per rank")
	p.notoriety = 15
	var later: Array[StringName] = Notoriety.choice_options(p, 15)
	assert_eq(later.size(), 2, "the picked option leaves the pool")
	assert_false(later.has(opts[1]))
