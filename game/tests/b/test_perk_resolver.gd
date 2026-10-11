## B4-02: LoadoutResolver.resolve_modifiers merges only cards 1..perk_deck_cards of the active deck,
## in order (MULT multiply, ADD sum, FLAG or, PARAMS last wins), on real and injected decks.
extends TestCase


func before_all() -> void:
	ContentDB.clear_cache()


func after_each() -> void:
	ContentDB.clear_cache()
	Log.capture = false
	Log.captured.clear()


func _loadout(deck: StringName, cards: int) -> Loadout:
	var l: Loadout = Loadout.new()
	l.perk_deck = deck
	l.perk_deck_cards = cards
	return l


func _inject_test_deck() -> void:
	var deck: PerkDeckDef = PerkDeckDef.new()
	deck.id = &"perk.test_merge"
	var cards: Array[Dictionary] = []
	cards.append(_card({&"defense.health_mult": 1.1, &"perk.stoic": {"a": 1, "b": 1}}))
	cards.append(_card({&"defense.dodge_add": 0.1, &"stealth.casing_can_pickup_items": false}))
	cards.append(_card({&"defense.health_mult": 1.5, &"perk.stoic": {"a": 2}}))
	cards.append(_card({&"defense.dodge_add": 0.05, &"stealth.casing_can_pickup_items": true}))
	cards.append(_card({&"stealth.casing_can_pickup_items": false}))
	deck.cards = cards
	ContentDB.inject(ContentDB.PERKS, deck.id, deck)


func _card(grants: Dictionary) -> Dictionary:
	return {"name": "n", "desc": "d", "cost": 0, "grants": grants}


func test_zero_cards_or_no_deck_grants_nothing() -> void:
	assert_eq(LoadoutResolver.resolve_modifiers(_loadout(&"perk.composure", 0)), {})
	assert_eq(LoadoutResolver.resolve_modifiers(_loadout(&"", 9)), {})


func test_four_cards_merge_only_unlocked_cards() -> void:
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_loadout(&"perk.bulk", 4))
	var expected: Array = [&"defense.health_mult", &"perk.muscle", &"weapon.headshot_mult.all",
		&"stealth.concealment_add.all", &"progression.xp_mult", &"movement.armor_penalty_mult"]
	assert_eq(m.size(), expected.size(), "keys: %s" % [m.keys()])
	for k: Variant in expected:
		assert_has(m, k)
	assert_near(float(m[&"defense.health_mult"]), 1.2, 0.0001, "Bulk cards 1+3")
	assert_near(float(m[&"weapon.headshot_mult.all"]), 1.25)
	assert_eq(m[&"stealth.concealment_add.all"], 1)
	assert_false(m.has(&"weapon.ammo_pickup_mult.all"), "card 6 is still locked")


func test_nine_cards_include_every_shared_card() -> void:
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_loadout(&"perk.knuckles", 9))
	assert_near(float(m[&"weapon.headshot_mult.all"]), 1.25)
	assert_eq(m[&"stealth.concealment_add.all"], 1)
	assert_near(float(m[&"weapon.ammo_pickup_mult.all"]), 1.35)
	assert_near(float(m[&"weapon.damage_mult.all"]), 1.05)
	assert_near(float(m[&"progression.xp_mult"]), 1.45)
	assert_near(float(m[&"movement.armor_penalty_mult"]), 0.85)
	assert_eq(m[&"deploy.armor_bag"], true)
	assert_near(float(m[&"interaction.doctor_bag_speed_mult"]), 0.8333)
	assert_near(float(m[&"progression.card_drop_quality_add"]), 0.1)
	var p: Dictionary = m[&"perk.infiltrator"]
	assert_near(float(p["close_range_dr"]), 0.24, 0.0001, "card 7 value, re-granted by card 9")
	assert_near(float(p["melee_hit_heal_fraction"]), 0.2)


func test_card_count_above_deck_size_is_clamped() -> void:
	var nine: Dictionary = LoadoutResolver.resolve_modifiers(_loadout(&"perk.overlord", 9))
	assert_eq(LoadoutResolver.resolve_modifiers(_loadout(&"perk.overlord", 12)), nine)


func test_low_profile_card_feeds_concealment_bonus() -> void:
	var l: Loadout = _loadout(&"perk.prowler", 3)
	assert_eq(LoadoutResolver.concealment_bonus(l), 0)
	l.perk_deck_cards = 4
	assert_eq(LoadoutResolver.concealment_bonus(l), 1, "Low Profile: +1 concealment")


func test_merge_rules_in_card_order() -> void:
	_inject_test_deck()
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_loadout(&"perk.test_merge", 5))
	assert_near(float(m[&"defense.health_mult"]), 1.65, 0.0001, "MULT multiplies")
	assert_near(float(m[&"defense.dodge_add"]), 0.15, 0.0001, "ADD sums")
	assert_eq(m[&"stealth.casing_can_pickup_items"], true, "FLAG ors (a later false does not clear it)")
	assert_eq(m[&"perk.stoic"], {"a": 2}, "PARAMS: the last card wins whole; fields are not merged")
	var two: Dictionary = LoadoutResolver.resolve_modifiers(_loadout(&"perk.test_merge", 2))
	assert_eq(two[&"perk.stoic"], {"a": 1, "b": 1})
	assert_eq(two[&"stealth.casing_can_pickup_items"], false)


func test_real_deck_params_last_wins() -> void:
	var three: Dictionary = LoadoutResolver.resolve_modifiers(_loadout(&"perk.composure", 3))
	var nine: Dictionary = LoadoutResolver.resolve_modifiers(_loadout(&"perk.composure", 9))
	assert_false((three[&"perk.stoic"] as Dictionary).has("negate_heal_fraction"))
	assert_has(nine[&"perk.stoic"], "negate_heal_fraction")
	assert_eq(nine[&"perk.throwable"], {"item_id": &"throwable.steady_flask"})


## D-031 QB-35: perk-deck `team.*` grants go to the TEAM source team_perk.<deck>, never to the personal
## modifiers; only unlocked cards count.
func test_team_perk_grants_route_to_team_perk_source() -> void:
	var nine: Loadout = _loadout(&"perk.foreman", 9)
	var personal: Dictionary = LoadoutResolver.resolve_modifiers(nine)
	for key: Variant in personal:
		assert_false(String(key).begins_with("team."), "team key %s kept out of personal modifiers" % key)
	assert_has(personal, &"ability.shout_range_mult", "Foreman card 3 shout range is personal")
	var team: Dictionary = LoadoutResolver.team_modifier_sources(nine)
	assert_eq(team.keys(), [&"team_perk.foreman"])
	var g: Dictionary = team[&"team_perk.foreman"]
	assert_eq(g.size(), 4, "keys: %s" % [g.keys()])
	assert_near(float(g[&"team.stamina_mult"]), 1.5)
	assert_near(float(g[&"team.health_mult"]), 1.1)
	assert_near(float(g[&"team.armor_mult"]), 1.05)
	assert_eq(g[&"team.damage_reduction_hostage"], {"absorb_per_hostage": 5.0, "max_hostages": 4})
	assert_eq(LoadoutResolver.team_modifier_sources(_loadout(&"perk.foreman", 2)), {}, "card 3 still locked")
	var five: Dictionary = LoadoutResolver.team_modifier_sources(_loadout(&"perk.foreman", 5))
	assert_eq((five[&"team_perk.foreman"] as Dictionary).keys().size(), 2, "cards 3 and 5")
	assert_eq(LoadoutResolver.team_perk_source(&"perk.foreman"), &"team_perk.foreman")


## Ironclad card 9 (Liquid Armor analog) is the crew-wide team.armor_regen_delay_mult (it replaces the old
## perk.armorer.team_regen_delay_mult field).
func test_ironclad_team_regen_delay_is_a_team_key() -> void:
	var l: Loadout = _loadout(&"perk.ironclad", 9)
	var team: Dictionary = LoadoutResolver.team_modifier_sources(l)
	assert_eq(team, {&"team_perk.ironclad": {&"team.armor_regen_delay_mult": 0.9}})
	var armorer: Dictionary = LoadoutResolver.resolve_modifiers(l)[&"perk.armorer"]
	assert_false(armorer.has("team_regen_delay_mult"))


## Skills and the deck together: both TEAM sources, and two players with the same deck write the same
## source, so Modifiers counts the aura once; it applies to the granter's slot too.
func test_team_perk_does_not_stack_across_players_and_applies_to_granter() -> void:
	var a: Loadout = _loadout(&"perk.foreman", 9)
	a.skills = {&"skill.persuader.zip_and_tie": 2}
	var b: Loadout = _loadout(&"perk.foreman", 9)
	var ta: Dictionary = LoadoutResolver.team_modifier_sources(a)
	var keys: Array = ta.keys()
	ContentDB.sort_ids(keys)
	assert_eq(keys, [&"team_perk.foreman", &"team_skill.skill.persuader.zip_and_tie"])
	Modifiers.clear_all()
	for l: Loadout in [a, b]:
		var src: Dictionary = LoadoutResolver.team_modifier_sources(l)
		for s: Variant in src:
			Modifiers.set_source(Modifiers.TEAM, StringName(s), src[s])
	assert_near(Modifiers.mult(0, &"team.health_mult"), 1.1, 0.0001, "same deck twice counts once")
	assert_near(Modifiers.mult(1, &"team.health_mult"), 1.1, 0.0001, "granter's slot gets it too")
	Modifiers.clear_all()


func test_every_deck_nine_cards_resolves_without_errors() -> void:
	Log.capture = true
	for d: Variant in ContentDB.all_of(ContentDB.PERKS):
		var l: Loadout = _loadout((d as PerkDeckDef).id, 9)
		var m: Dictionary = LoadoutResolver.resolve_modifiers(l)
		LoadoutResolver.team_modifier_sources(l)
		LoadoutResolver.resolve(l)
		assert_true(m.size() >= 9, "%s resolves %d keys" % [l.perk_deck, m.size()])
	var errors: Array = Log.captured.filter(func(line: String) -> bool: return line.begins_with("[ERROR]"))
	assert_eq(errors.size(), 0, "no errors: %s" % [errors])
