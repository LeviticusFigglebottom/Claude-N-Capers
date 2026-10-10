## D-022 QB-6 / QB-11: LoadoutResolver concealment bonus (`stealth.concealment_add.<qualifier>`) from
## injected test-only skill and perk grants, and the P1-only empty-slot rule.
extends TestCase


func before_all() -> void:
	ContentDB.clear_cache()


func after_each() -> void:
	ContentDB.clear_cache()
	Log.capture = false
	Log.captured.clear()


func _stock_loadout() -> Loadout:
	var l: Loadout = Loadout.new()
	l.secondary = &"weapon.kestrel_p9"
	l.melee = &"melee.folding_knife"
	l.armor = &"armor.tailored_suit"
	return l


## D-022 QB-6: a test-only skill (basic + aced) and perk deck injected into ContentDB.
func _inject_concealment_sources() -> void:
	var skill: SkillDef = SkillDef.new()
	skill.id = &"skill.test.pockets"
	skill.grants_basic = {&"stealth.concealment_add.melee": 2}
	skill.grants_aced = {&"stealth.concealment_add.armor": 1}
	ContentDB.inject(ContentDB.SKILLS, skill.id, skill)
	var deck: PerkDeckDef = PerkDeckDef.new()
	deck.id = &"perk.test_deck"
	deck.cards = [
		{"name": "a", "desc": "", "cost": 0, "grants": {&"stealth.concealment_add.all": 1}},
		{"name": "b", "desc": "", "cost": 0, "grants": {&"stealth.concealment_add.secondary": 3}},
	] as Array[Dictionary]
	ContentDB.inject(ContentDB.PERKS, deck.id, deck)


func test_concealment_bonus_sums_injected_skill_and_perk_grants() -> void:
	_inject_concealment_sources()
	var l: Loadout = _stock_loadout()
	l.armor = &"armor.patrol_vest"
	l.skills = {&"skill.test.pockets": 2}
	l.perk_deck = &"perk.test_deck"
	l.perk_deck_cards = 1
	var bd: Dictionary = LoadoutResolver.concealment_breakdown(l)
	ContentDB.clear_cache()
	assert_eq(bd["armor"], 23, "item concealment unchanged; the bonus is its own line")
	assert_eq(bd["bonus"], 4, "melee 2 + armor 1 (aced) + all 1")
	assert_eq(bd["total"], 117)
	assert_eq(bd["detection_risk"], 6)


func test_concealment_bonus_basic_only_and_resolve() -> void:
	_inject_concealment_sources()
	var l: Loadout = _stock_loadout()
	l.armor = &"armor.patrol_vest"
	l.skills = {&"skill.test.pockets": 1}
	var r: Loadout = LoadoutResolver.resolve(l)
	var bonus: int = LoadoutResolver.concealment_bonus(l)
	ContentDB.clear_cache()
	assert_eq(bonus, 2)
	assert_eq(r.modifiers, {&"stealth.concealment_add.melee": 2})
	assert_eq(r.concealment_total, 115)
	assert_eq(r.detection_risk, 9)


## PD2: each weapon caps at 30, but bonuses still raise the total. The .secondary bonus is added after
## the clamp, so the 30-concealment pistol stays 30 and the total goes past 120.
func test_concealment_bonus_applies_after_weapon_cap() -> void:
	_inject_concealment_sources()
	var l: Loadout = _stock_loadout()
	l.perk_deck = &"perk.test_deck"
	l.perk_deck_cards = 2
	var bd: Dictionary = LoadoutResolver.concealment_breakdown(l)
	var r: Loadout = LoadoutResolver.resolve(l)
	ContentDB.clear_cache()
	assert_eq(bd["secondary"], 30, "per-weapon cap still 30")
	assert_eq(r.resolved_secondary.concealment, 30)
	assert_eq(bd["bonus"], 4, "all 1 + secondary 3")
	assert_eq(bd["total"], 124)
	assert_eq(bd["detection_risk"], 3)


func test_concealment_bonus_slot_qualifier_needs_filled_slot() -> void:
	var l: Loadout = _stock_loadout()
	var mods: Dictionary = {&"stealth.concealment_add.primary": 5, &"stealth.concealment_add.secondary": 1,
		&"stealth.concealment_add": 1}
	assert_eq(LoadoutResolver.concealment_bonus_from(l, mods), 2, "no primary in P1; bare key = all")
	l.melee = &""
	assert_eq(LoadoutResolver.concealment_bonus_from(l, {&"stealth.concealment_add.melee": 2}), 0)
	assert_eq(LoadoutResolver.concealment_bonus(_stock_loadout()), 0, "no grants -> 0")


func test_concealment_bonus_unknown_qualifier_logged() -> void:
	Log.capture = true
	var mods: Dictionary = {&"stealth.concealment_add.mask": 3, &"stealth.detection_rate_mult": 0.5}
	assert_eq(LoadoutResolver.concealment_bonus_from(_stock_loadout(), mods), 0)
	assert_true(_logged("stealth.concealment_add.mask"))


## D-022 QB-11: the empty slot = 30 rule is P1 only.
func test_p4_rejects_loadout_without_primary_and_secondary() -> void:
	skip("TODO(P4): D-022 QB-11 - from P4 the resolver must reject a loadout with an empty primary or "
		+ "secondary (PD2 rule) instead of counting the slot as empty_slot_concealment 30")


func _logged(fragment: String) -> bool:
	for line: String in Log.captured:
		if line.contains(fragment):
			return true
	return false
