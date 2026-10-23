## D-164 Copycat (Understudy) push 1: the per-card choices and the mimic card through LoadoutResolver, the mimic table
## (every deck mimicable XOR on PD2's throwable-deck list, registered keys, PARAMS fields matching the deck's own
## schema), and the two Loadout fields through the profile save, the validator and the lobby payload.
extends TestCase

const DECK: StringName = &"perk.understudy"
## Not mimicable: their card 9 needs the deck's own item (PD2's mimicry list leaves them out), plus Copycat itself.
const NOT_MIMICABLE: Array[StringName] = [&"perk.composure", &"perk.overlord", &"perk.hacker", &"perk.veil",
	&"perk.buddy_system", &"perk.lifeline", &"perk.understudy"]


func before_all() -> void:
	ContentDB.clear_cache()


func _loadout(choices: Dictionary = {}, mimic: StringName = &"", cards: int = 9) -> Loadout:
	var l: Loadout = Loadout.new()
	l.perk_deck = DECK
	l.perk_deck_cards = cards
	l.perk_choices = choices
	l.perk_mimic_deck = mimic
	return l


func test_default_choices_stack_health_additively() -> void:
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_loadout())
	assert_near(float(m[&"defense.health_mult"]), 1.8, 0.0001, "4 x +20% = +80% (PD2 adds)")
	assert_near(float(LoadoutResolver.resolve_modifiers(_loadout({}, &"", 3))[&"defense.health_mult"]), 1.4, 0.0001,
			"cards 1 + 3: +40%")
	assert_true((m[&"perk.copycat"] as Dictionary).get("dodge_ricochet", false), "the fixed perks still apply")


func test_mixed_choices() -> void:
	# card 1 armor, card 3 dodge, card 5 dodge, card 7 speed
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_loadout({0: 1, 2: 2, "4": 2, 6: 3}))
	assert_near(float(m[&"defense.armor_mult"]), 1.05, 0.0001)
	assert_near(float(m[&"defense.dodge_add"]), 0.1, 0.0001, "two dodge picks")
	assert_near(float(m[&"movement.crouch_speed_mult"]), 1.1, 0.0001)
	assert_near(float(m[&"loot.carry_speed_penalty_mult"]), 0.9, 0.0001)
	assert_false(m.has(&"defense.health_mult"), "no health pick")
	assert_eq(LoadoutResolver.chosen_option(_loadout({0: 99}), ContentDB.by_id(ContentDB.PERKS, DECK) as PerkDeckDef, 0), 3,
			"out of range clamps to the last option")


func test_mimic_merges_the_chosen_deck() -> void:
	var m: Dictionary = LoadoutResolver.resolve_modifiers(_loadout({}, &"perk.frenzy"))
	var maniac: Dictionary = m.get(&"perk.maniac", {}) as Dictionary
	assert_eq(int(maniac.get("stacks_per_absorb", 0)), 30, "PD2's Hysteria Stacks mimic")
	assert_true(bool(maniac.get("team", false)))
	assert_false(LoadoutResolver.resolve_modifiers(_loadout({}, &"perk.frenzy", 8)).has(&"perk.maniac"),
			"needs card 9")
	# A mimic with a team key reaches the TEAM source, not the personal one.
	var l: Loadout = _loadout({}, &"perk.ironclad")
	assert_false(LoadoutResolver.resolve_modifiers(l).has(&"team.armor_regen_delay_mult"))
	var team: Dictionary = LoadoutResolver.team_modifier_sources(l)
	assert_near(float((team[LoadoutResolver.team_perk_source(DECK)] as Dictionary)[&"team.armor_regen_delay_mult"]), 0.9,
			0.0001)
	# Not mimicable, unknown, or Understudy itself: nothing.
	for bad: StringName in [&"perk.hacker", &"perk.nope", DECK]:
		assert_true(LoadoutResolver.mimic_deck(_loadout({}, bad)) == null, "%s is not a mimic" % bad)


func test_mimic_table_is_complete() -> void:
	for d: Variant in ContentDB.all_of(ContentDB.PERKS):
		var deck: PerkDeckDef = d as PerkDeckDef
		assert_eq(deck.mimicable, not NOT_MIMICABLE.has(deck.id), "%s mimicable" % deck.id)
		assert_eq(deck.mimicable, not deck.mimic_grants.is_empty(), "%s: mimic_grants iff mimicable" % deck.id)
		var own: Dictionary = {}
		for c: Dictionary in deck.cards:
			own.merge(c.get("grants", {}) as Dictionary, true)
		for key: Variant in deck.mimic_grants:
			var k: StringName = StringName(key)
			assert_true(ModifierKeys.is_known(k), "%s mimic key %s registered" % [deck.id, k])
			if ModifierKeys.type_of(k) == ModifierKeys.Type.PARAMS and own.has(k):
				var want: Array = (own[k] as Dictionary).keys()
				var have: Array = (deck.mimic_grants[key] as Dictionary).keys()
				want.sort()
				have.sort()
				assert_eq(have, want, "%s mimic %s: the deck's own field set" % [deck.id, k])
		assert_true(UiText.has(StringName("%s.mimic.desc" % deck.id)) == deck.mimicable, "%s mimic string" % deck.id)
	var cards: Array[Dictionary] = (ContentDB.by_id(ContentDB.PERKS, DECK) as PerkDeckDef).cards
	for i: int in [0, 2, 4, 6]:
		assert_eq((cards[i].get("choices", []) as Array).size(), 4, "card %d offers 4 choices" % (i + 1))
	assert_true(bool(cards[8].get("mimic", false)), "card 9 is the mimic card")


func test_profile_validator_and_lobby_round_trip() -> void:
	var l: Loadout = _loadout({0: 2, 6: 3}, &"perk.knuckles")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(PlayerProfile.loadout_to_dict(l))) as Dictionary
	var back: Loadout = PlayerProfile.loadout_from_dict(saved)
	assert_eq(back.perk_choices, {0: 2, 6: 3}, "int keys survive the JSON save")
	assert_eq(back.perk_mimic_deck, &"perk.knuckles")
	var wire: Dictionary = JSON.parse_string(JSON.stringify(LobbyState.loadout_to_dict(l))) as Dictionary
	var peer: Loadout = LobbyState.loadout_from_dict(wire)
	assert_eq(peer.perk_choices, {0: 2, 6: 3})
	assert_eq(peer.perk_mimic_deck, &"perk.knuckles")
	assert_eq(LoadoutResolver.resolve_modifiers(peer), LoadoutResolver.resolve_modifiers(l), "every peer resolves the same")
	var bad: Dictionary = wire.duplicate(true)
	bad["perk_choices"] = "lots"
	assert_true(LobbyState.sanitize_summary({"name": "x", "level": 1, "loadout": bad}).is_empty(), "bad choices rejected")
	var p: PlayerProfile = PlayerProfile.new_default()
	p.loadout.perk_deck = DECK
	p.loadout.perk_mimic_deck = &"perk.hacker"
	ProfileValidator.validate(p)
	assert_eq(p.loadout.perk_mimic_deck, &"", "a non-mimicable pick is dropped")
