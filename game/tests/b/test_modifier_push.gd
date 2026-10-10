## ModifierPush: resolved crew loadouts reach the Modifiers service at heist start (QB-L2).
extends TestCase


func after_each() -> void:
	Modifiers.clear_all()


func _loadout(deck: StringName, cards: int) -> Loadout:
	var l: Loadout = Loadout.new()
	l.secondary = &"weapon.kestrel_p9"
	l.melee = &"melee.folding_knife"
	l.armor = &"armor.tailored_suit"
	l.perk_deck = deck
	l.perk_deck_cards = cards
	return LoadoutResolver.resolve(l)


func test_personal_and_team_sources_are_pushed() -> void:
	var bulk: Loadout = _loadout(&"perk.bulk", 9)
	var foreman: Loadout = _loadout(&"perk.foreman", 9)
	ModifierPush.push({0: bulk, 1: foreman})
	assert_near(Modifiers.mult(0, &"defense.health_mult"),
			float(bulk.modifiers.get(&"defense.health_mult", 1.0)), 0.0001, "slot 0 personal grants")
	assert_near(Modifiers.mult(0, &"weapon.headshot_mult", &"pistol"), 1.25, 0.0001, "Headhunter card")
	var team: Dictionary = LoadoutResolver.crew_team_modifier_sources([bulk, foreman])
	assert_false(team.is_empty(), "Foreman grants team sources")
	for source: Variant in team:
		for key: Variant in team[source]:
			var t: int = ModifierKeys.type_of(StringName(key))
			if t == ModifierKeys.Type.MULT:
				assert_near(Modifiers.mult(0, StringName(key)), float(team[source][key]) *
						(float(bulk.modifiers.get(key, 1.0))), 0.0001, "team %s reaches slot 0" % key)


func test_nothing_pushed_for_null_loadouts() -> void:
	ModifierPush.push({0: null})
	assert_near(Modifiers.mult(0, &"defense.health_mult"), 1.0, 0.0001)
