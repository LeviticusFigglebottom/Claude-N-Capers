## B4-02: the 21 perk decks as data (14 + Hacker D-161 + Inkwork / Road Crew / Frenzy D-162 + Veil / Buddy System
## D-163 + Lifeline D-164)
## (pd2_fidelity.md P4 + P-decks table, research §3.2/Appendix B).
## 9 cards each, PD2 costs, shared cards 2/4/6/8 identical in every deck, only registry keys,
## strings present, each deck grants its signature key, PARAMS re-grants carry the full dict.
extends TestCase

const COSTS: Array[int] = [200, 300, 400, 600, 1000, 1600, 2400, 3200, 4000]
const DECK_TOTAL: int = 13700
## pd2_fidelity.md "P-decks" table: deck id -> signature modifier key.
const SIGNATURE: Dictionary = {
	&"perk.foreman": &"team.damage_reduction_hostage",
	&"perk.bulk": &"perk.muscle",
	&"perk.ironclad": &"perk.armorer",
	&"perk.slipper": &"perk.rogue_dodge_stack",
	&"perk.hustler": &"perk.crook",
	&"perk.clean_sweep": &"perk.sociopath",
	&"perk.prowler": &"perk.burglar",
	&"perk.knuckles": &"perk.infiltrator",
	&"perk.bloodletter": &"perk.grinder",
	&"perk.composure": &"perk.stoic",
	&"perk.overclock": &"perk.anarchist",
	&"perk.incumbent": &"perk.ex_president",
	&"perk.long_odds": &"perk.gambler",
	&"perk.overlord": &"perk.kingpin",
	&"perk.hacker": &"stealth.pocket_ecm",  # D-161: the 15th deck
	&"perk.inkwork": &"perk.yakuza",  # D-162 (PD2 Yakuza)
	&"perk.road_crew": &"perk.biker",  # D-162 (PD2 Biker)
	&"perk.frenzy": &"perk.maniac",  # D-162 (PD2 Maniac)
	&"perk.veil": &"perk.sicario",  # D-163 (PD2 Sicario)
	&"perk.buddy_system": &"perk.tag_team",  # D-163 (PD2 Tag Team)
	&"perk.lifeline": &"perk.leech",  # D-164 (PD2 Leech)
}
## Shared cards (index = card number - 1): PD2 Helmet Popping, Blending In, Walk-in Closet,
## Fast and Furious (the parts that have registry keys).
const SHARED: Dictionary = {
	1: {&"weapon.headshot_mult.all": 1.25},
	3: {&"stealth.concealment_add.all": 1, &"progression.xp_mult": 1.45, &"movement.armor_penalty_mult": 0.85},
	5: {&"weapon.ammo_pickup_mult.all": 1.35, &"deploy.armor_bag": true},
	7: {&"weapon.damage_mult.all": 1.05, &"interaction.doctor_bag_speed_mult": 0.8333},
}
## Deck completion bonus (PD2): every deck's card 9 grants this too (D-031).
const COMPLETION: Dictionary = {&"progression.card_drop_quality_add": 0.1}
## D-031 QB-37: Hustler's vest bonus applies to Light Vest, Patrol Vest and Heavy Vest only.
const HUSTLER_VESTS: Array[StringName] = [&"armor.light_vest", &"armor.patrol_vest", &"armor.heavy_vest"]

var _strings: Dictionary = {}


func before_all() -> void:
	ContentDB.clear_cache()
	_strings = StringTable.parse_csv()


func after_all() -> void:
	ContentDB.clear_cache()


func _decks() -> Array:
	return ContentDB.all_of(ContentDB.PERKS)


func test_fourteen_decks_with_expected_ids() -> void:
	var ids: Array = []
	for d: Variant in _decks():
		ids.append((d as PerkDeckDef).id)
	assert_eq(ids.size(), 21, "decks: %s" % [ids])
	var expected: Array = SIGNATURE.keys()
	ContentDB.sort_ids(expected)
	assert_eq(ids, expected)


func test_nine_cards_with_pd2_costs() -> void:
	var sum: int = 0
	for c: int in COSTS:
		sum += c
	assert_eq(sum, DECK_TOTAL, "research §3.2: a full deck costs 13,700")
	for d: Variant in _decks():
		var deck: PerkDeckDef = d as PerkDeckDef
		assert_eq(deck.cards.size(), 9, "%s card count" % deck.id)
		var total: int = 0
		for i: int in range(deck.cards.size()):
			var card: Dictionary = deck.cards[i]
			for field: String in ["name", "desc", "cost", "grants"]:
				assert_has(card, field, "%s card %d" % [deck.id, i + 1])
			assert_true(card["name"] is String and card["desc"] is String)
			assert_true(card["cost"] is int)
			assert_true(card["grants"] is Dictionary)
			assert_eq(int(card["cost"]), COSTS[i], "%s card %d cost" % [deck.id, i + 1])
			total += int(card["cost"])
		assert_eq(total, DECK_TOTAL, "%s total cost" % deck.id)


func test_shared_cards_identical_across_decks() -> void:
	var first: PerkDeckDef = null
	for d: Variant in _decks():
		var deck: PerkDeckDef = d as PerkDeckDef
		for idx: Variant in SHARED:
			var card: Dictionary = deck.cards[int(idx)]
			assert_eq(card["grants"], SHARED[idx], "%s shared card %d" % [deck.id, int(idx) + 1])
			assert_eq(card["name"], "perk.shared.card%d.name" % (int(idx) + 1))
			if first != null:
				assert_eq(card, first.cards[int(idx)], "%s card %d equals %s" % [deck.id, int(idx) + 1, first.id])
		if first == null:
			first = deck


func test_unique_cards_use_deck_strings() -> void:
	for d: Variant in _decks():
		var deck: PerkDeckDef = d as PerkDeckDef
		var snake: String = String(deck.id).trim_prefix("perk.")
		for n: int in [1, 3, 5, 7, 9]:
			var card: Dictionary = deck.cards[n - 1]
			assert_eq(card["name"], "perk.%s.card%d.name" % [snake, n])
			assert_eq(card["desc"], "perk.%s.card%d.desc" % [snake, n])
			assert_false((card["grants"] as Dictionary).is_empty(), "%s card %d grants nothing" % [deck.id, n])


func test_all_grants_are_registry_keys_with_matching_types() -> void:
	for d: Variant in _decks():
		var deck: PerkDeckDef = d as PerkDeckDef
		for i: int in range(deck.cards.size()):
			var grants: Dictionary = deck.cards[i]["grants"]
			for key: Variant in grants:
				var k: StringName = StringName(key)
				var where: String = "%s card %d %s" % [deck.id, i + 1, k]
				assert_true(ModifierKeys.is_known(k), "unknown key " + where)
				var v: Variant = grants[key]
				match ModifierKeys.type_of(k):
					ModifierKeys.Type.PARAMS:
						assert_true(v is Dictionary and not (v as Dictionary).is_empty(), where)
					ModifierKeys.Type.FLAG:
						assert_true(v is bool, where)
					_:
						assert_true(v is float or v is int, where)
				if String(k).begins_with("weapon."):
					assert_ne(k, ModifierKeys.base_key(k), "weapon keys need a qualifier: " + where)


func test_strings_exist_for_decks_and_cards() -> void:
	assert_has(_strings, "perk.shared.completion.desc")
	for d: Variant in _decks():
		var deck: PerkDeckDef = d as PerkDeckDef
		assert_has(_strings, "%s.name" % deck.id)
		assert_has(_strings, "%s.desc" % deck.id)
		assert_eq(deck.description, "%s.desc" % deck.id)
		for card: Dictionary in deck.cards:
			assert_has(_strings, String(card["name"]))
			assert_has(_strings, String(card["desc"]))


func test_each_deck_grants_its_signature_key() -> void:
	for d: Variant in _decks():
		var deck: PerkDeckDef = d as PerkDeckDef
		var sig: StringName = SIGNATURE[deck.id]
		var found: bool = false
		for card: Dictionary in deck.cards:
			if (card["grants"] as Dictionary).has(sig):
				found = true
		assert_true(found, "%s never grants %s" % [deck.id, sig])
	var foreman: Dictionary = _team(&"perk.foreman", 9)
	for k: StringName in [&"team.health_mult", &"team.armor_mult", &"team.stamina_mult"]:
		assert_has(foreman, k, "Foreman team aura")


func test_card_nine_grants_completion_bonus() -> void:
	for d: Variant in _decks():
		var deck: PerkDeckDef = d as PerkDeckDef
		var grants: Dictionary = deck.cards[8]["grants"]
		for k: Variant in COMPLETION:
			assert_eq(grants.get(k), COMPLETION[k], "%s card 9 completion bonus" % deck.id)


## D-031 QB-37: perk.crook vest set = Light, Patrol and Heavy Vest (PD2 LBV/BV/HBV), on every card.
func test_hustler_vests_are_light_patrol_heavy_only() -> void:
	var deck: PerkDeckDef = ContentDB.by_id(ContentDB.PERKS, &"perk.hustler") as PerkDeckDef
	var seen: int = 0
	for card: Dictionary in deck.cards:
		var crook: Variant = (card["grants"] as Dictionary).get(&"perk.crook")
		if crook == null:
			continue
		seen += 1
		var ids: Array = (crook as Dictionary)["vest_armor_ids"]
		assert_eq(ids, HUSTLER_VESTS as Array, "Hustler vest set")
		for id: Variant in ids:
			assert_true(ContentDB.armor(StringName(id)) != null, "%s exists" % id)
	assert_eq(seen, 3, "cards 3, 5 and 7 grant perk.crook")
	var crook9: Dictionary = _resolve(&"perk.hustler", 9)[&"perk.crook"]
	for excluded: StringName in [&"armor.tailored_suit", &"armor.flak_rig", &"armor.tactical_plate", &"armor.breacher_plate"]:
		assert_false((crook9["vest_armor_ids"] as Array).has(excluded), "%s gets no Hustler bonus" % excluded)


## PARAMS is last-granted-wins, so a card that upgrades a deck mechanic re-grants the whole dict:
## every later grant of the same PARAMS key must keep every field of the earlier one.
func test_params_regrants_carry_full_dict() -> void:
	for d: Variant in _decks():
		var deck: PerkDeckDef = d as PerkDeckDef
		var last: Dictionary = {}  # key -> previous dict
		for i: int in range(deck.cards.size()):
			var grants: Dictionary = deck.cards[i]["grants"]
			for key: Variant in grants:
				if ModifierKeys.type_of(StringName(key)) != ModifierKeys.Type.PARAMS:
					continue
				var cur: Dictionary = grants[key]
				if last.has(key):
					for field: Variant in (last[key] as Dictionary):
						assert_has(cur, field, "%s card %d %s drops %s" % [deck.id, i + 1, key, field])
				last[key] = cur


## PD2 deck totals (Appendix B) hold after all 9 cards (MULT cards are per-card ratios).
func test_pd2_cumulative_values() -> void:
	assert_near(float(_resolve(&"perk.bulk", 9)[&"defense.health_mult"]), 2.0, 0.0001)
	assert_near(float(_resolve(&"perk.bulk", 5)[&"defense.health_mult"]), 1.4, 0.0001)
	assert_near(float(_resolve(&"perk.ironclad", 9)[&"defense.armor_mult"]), 1.35, 0.0001)
	assert_near(float(_resolve(&"perk.slipper", 9)[&"defense.dodge_add"]), 0.45, 0.0001)
	assert_near(float(_resolve(&"perk.prowler", 9)[&"defense.dodge_add"]), 0.3, 0.0001)
	assert_near(float(_resolve(&"perk.overlord", 9)[&"defense.health_mult"]), 1.8, 0.0001)
	assert_near(float(_resolve(&"perk.long_odds", 9)[&"defense.health_mult"]), 1.4, 0.0001)
	assert_near(float(_resolve(&"perk.incumbent", 9)[&"defense.health_mult"]), 1.4, 0.0001)
	assert_near(float(_resolve(&"perk.bloodletter", 9)[&"weapon.armor_pierce_add.all"]), 0.2, 0.0001)
	var foreman: Dictionary = _resolve(&"perk.foreman", 9)
	var foreman_team: Dictionary = _team(&"perk.foreman", 9)
	assert_near(float(foreman_team[&"team.health_mult"]) * float(foreman[&"defense.health_mult"]), 1.2, 0.0001)
	var crook: Dictionary = _resolve(&"perk.hustler", 9)[&"perk.crook"]
	assert_near(float(crook["vest_armor_mult"]), 1.65, 0.0001)
	assert_near(float(crook["vest_dodge_add"]), 0.25, 0.0001)
	var stoic: Dictionary = _resolve(&"perk.composure", 9)[&"perk.stoic"]
	assert_near(float(stoic["delayed_fraction"]), 0.75)
	assert_near(float(stoic["negate_heal_fraction"]), 0.5)


func _resolve(deck_id: StringName, cards: int) -> Dictionary:
	var l: Loadout = Loadout.new()
	l.perk_deck = deck_id
	l.perk_deck_cards = cards
	return LoadoutResolver.resolve_modifiers(l)


## The deck's crew-wide grants (TEAM source team_perk.<deck>), D-031 QB-35.
func _team(deck_id: StringName, cards: int) -> Dictionary:
	var l: Loadout = Loadout.new()
	l.perk_deck = deck_id
	l.perk_deck_cards = cards
	return LoadoutResolver.team_modifier_sources(l).get(LoadoutResolver.team_perk_source(deck_id), {})
