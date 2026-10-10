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
		&"stealth.concealment_add.all"]
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
