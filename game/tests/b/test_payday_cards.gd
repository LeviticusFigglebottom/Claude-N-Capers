## B4-05: PAYDAY card drop (P9): deterministic rolls per (run seed, slot), data weights respected,
## card_drop_quality_add shifts quality, rewards granted per type and saved, owned items never drop.
extends TestCase

const SEEDS: int = 2000


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(7)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _profile() -> PlayerProfile:
	return PlayerProfile.new_default()


func test_table_data_is_consistent() -> void:
	var t: PaydayCardsTable = PaydayCards.table()
	assert_eq(t.card_count, 3, "pick 1 of 3 (P9)")
	assert_near(t.pick_time_s, 30.0, 0.001, "30 s auto-pick (P9)")
	assert_eq(t.type_weights.size(), Enums.Difficulty.size(), "one type row per difficulty")
	assert_eq(t.tier_weights.size(), Enums.Difficulty.size(), "one tier row per difficulty")
	for row: PackedFloat32Array in t.type_weights:
		assert_eq(row.size(), t.types.size())
	for row: PackedFloat32Array in t.tier_weights:
		assert_eq(row.size(), t.tier_count())
	for type: StringName in t.types:
		assert_has(PaydayCards.TYPES, type)
	assert_eq(t.cash_by_tier.size(), t.tier_count())
	assert_eq(t.xp_by_tier.size(), t.tier_count())
	assert_eq(t.cash_difficulty_mult.size(), Enums.Difficulty.size())
	assert_eq(t.xp_difficulty_mult.size(), Enums.Difficulty.size())
	for d: int in range(Enums.Difficulty.size()):
		for tier: int in range(t.tier_count()):
			var cash: int = PaydayCards.amount_for(t, PaydayCards.CASH, tier, d)
			assert_true(cash >= 20000 and cash <= 100000, "cash $20k-$100k (research §4): %d" % cash)
	for id: Variant in t.item_tiers:
		var sid: StringName = StringName(id)
		var known: bool = false
		if String(sid).begins_with("mod."):
			known = ContentDB.mod(sid) != null
		elif MaskCatalog.is_preset_id(sid):
			known = ContentDB.mask(sid) is MaskDef
		else:
			known = MaskCatalog.is_known(sid)  # hidden ENV D base slots count
		assert_true(known, "item_tiers id exists: %s" % sid)
		assert_true(int(t.item_tiers[id]) < t.tier_count())


func test_strings_for_every_type_tier_and_mask_kind() -> void:
	var table: Dictionary = StringTable.parse_csv()
	var t: PaydayCardsTable = PaydayCards.table()
	for type: StringName in t.types:
		assert_has(table, "ui.payday_cards.type.%s" % type)
	for tier: int in range(t.tier_count()):
		assert_has(table, "ui.payday_cards.tier.%d" % tier)
	for kind: String in MaskCatalog.KINDS:
		assert_has(table, "ui.payday_cards.mask_kind.%s" % kind)
	for id: StringName in PaydayCards.pool(PaydayCards.WEAPON_MOD, null) + PaydayCards.pool(PaydayCards.MASK_PART, null):
		assert_has(table, String(UiText.item_key(id)), "droppable item has a name")


func test_roll_is_deterministic_per_seed_and_slot() -> void:
	var p: PlayerProfile = _profile()
	var a: Dictionary = PaydayCards.roll(1234, 0, Enums.Difficulty.BRUTAL, p, 0.1)
	var b: Dictionary = PaydayCards.roll(1234, 0, Enums.Difficulty.BRUTAL, p, 0.1)
	assert_eq(a, b, "same seed/slot/profile -> same cards and auto pick")
	assert_eq((a["cards"] as Array).size(), 3)
	assert_true(int(a["auto_pick"]) >= 0 and int(a["auto_pick"]) < 3)
	var differs_seed: bool = false
	var differs_slot: bool = false
	for s: int in range(20):
		var base: Dictionary = PaydayCards.roll(s, 0, 0, p)
		differs_seed = differs_seed or base["cards"] != PaydayCards.roll(s + 1000, 0, 0, p)["cards"]
		differs_slot = differs_slot or base["cards"] != PaydayCards.roll(s, 1, 0, p)["cards"]
	assert_true(differs_seed, "other seeds roll other cards")
	assert_true(differs_slot, "each crew slot rolls its own cards")
	assert_eq(PaydayCards.seed_for(55, 2), hash([55, "payday_cards.2"]), "GameRng stream formula")


func test_type_and_tier_weights_respected() -> void:
	var t: PaydayCardsTable = PaydayCards.table()
	var p: PlayerProfile = _profile()
	for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.CATACLYSM]:
		var type_counts: Dictionary = {}
		var tier_counts: Array[int] = [0, 0, 0]
		var amount_cards: int = 0
		for s: int in range(SEEDS):
			var card: Dictionary = (PaydayCards.roll(s, 0, d, p)["cards"] as Array)[0]
			type_counts[card["type"]] = int(type_counts.get(card["type"], 0)) + 1
			if card["item_id"] == &"":
				tier_counts[int(card["tier"])] += 1
				amount_cards += 1
		var row: PackedFloat32Array = t.type_row(d)
		var total: float = 0.0
		for w: float in row:
			total += w
		for i: int in range(t.types.size()):
			var expected: float = row[i] / total
			var got: float = float(type_counts.get(t.types[i], 0)) / float(SEEDS)
			assert_near(got, expected, 0.05, "difficulty %d type %s" % [d, t.types[i]])
		var trow: PackedFloat32Array = t.tier_row(d)
		var ttotal: float = trow[0] + trow[1] + trow[2]
		for tier: int in range(3):
			assert_near(float(tier_counts[tier]) / float(amount_cards), trow[tier] / ttotal, 0.06,
					"difficulty %d tier %d" % [d, tier])


func test_quality_add_shifts_tiers_up() -> void:
	var p: PlayerProfile = _profile()
	var sum0: int = 0
	var sum1: int = 0
	for s: int in range(SEEDS):
		var c0: Dictionary = (PaydayCards.roll(s, 0, 0, p, 0.0)["cards"] as Array)[0]
		var c1: Dictionary = (PaydayCards.roll(s, 0, 0, p, 0.25)["cards"] as Array)[0]
		var cf: Dictionary = (PaydayCards.roll(s, 0, 0, p, 1.0)["cards"] as Array)[0]
		assert_eq(c0["type"], c1["type"], "quality never changes the type roll")
		if c0["item_id"] == &"":
			assert_true(int(c1["tier"]) >= int(c0["tier"]), "seed %d: quality only moves up" % s)
			assert_true(int(cf["tier"]) >= 1, "quality 1.0 always bumps one tier")
			sum0 += int(c0["tier"])
			sum1 += int(c1["tier"])
	assert_true(sum1 > sum0, "card_drop_quality_add raises the mean tier (%d > %d)" % [sum1, sum0])


func test_quality_add_comes_from_perk_deck_completion() -> void:
	var p: PlayerProfile = _profile()
	assert_near(PaydayCards.quality_add_for(p), 0.0, 0.0001)
	p.loadout.perk_deck = &"perk.foreman"
	p.loadout.perk_deck_cards = 9
	assert_near(PaydayCards.quality_add_for(p), 0.1, 0.0001, "deck completion card 9 (D-031)")


func test_no_owned_or_duplicate_items() -> void:
	var p: PlayerProfile = _profile()
	var stock: Array = []
	for w: Variant in ContentDB.all_weapons():
		stock.append_array(((w as WeaponDef).default_mods as Dictionary).values())
	var mods: Array[StringName] = PaydayCards.pool(PaydayCards.WEAPON_MOD, p)
	assert_true(mods.size() > 0)
	for id: StringName in mods:
		assert_false(p.owned_mods.has(id), "owned mod not offered: %s" % id)
		assert_false(stock.has(id) or stock.has(String(id)), "stock part not offered: %s" % id)
	for id: StringName in PaydayCards.pool(PaydayCards.MASK_PART, p):
		assert_false(MaskLocker.is_drop_owned(p, id))
	for s: int in range(300):
		var seen: Dictionary = {}
		for card: Dictionary in PaydayCards.roll(s, 0, Enums.Difficulty.CATACLYSM, p, 0.0)["cards"] as Array:
			var id: StringName = card["item_id"]
			if id == &"":
				continue
			assert_false(seen.has(id), "seed %d: %s twice in one roll" % [s, id])
			seen[id] = true
			assert_false(p.owned_mods.has(id) or MaskLocker.is_drop_owned(p, id), "owned item dropped: %s" % id)


func test_everything_owned_falls_back_to_cash() -> void:
	var p: PlayerProfile = _profile()
	p.owned_mods.append_array(PaydayCards.pool(PaydayCards.WEAPON_MOD, p))
	for id: StringName in PaydayCards.pool(PaydayCards.MASK_PART, p):
		assert_true(PaydayCards.grant(p, {"type": PaydayCards.MASK_PART, "item_id": id}), "grant %s" % id)
	assert_eq(PaydayCards.pool(PaydayCards.WEAPON_MOD, p).size(), 0)
	assert_eq(PaydayCards.pool(PaydayCards.MASK_PART, p).size(), 0)
	for s: int in range(100):
		for card: Dictionary in PaydayCards.roll(s, 0, 3, p)["cards"] as Array:
			assert_has([PaydayCards.CASH, PaydayCards.XP], card["type"])
			assert_true(int(card["amount"]) > 0)


func test_grant_each_type_and_save() -> void:
	var p: PlayerProfile = _profile()
	var cash0: int = p.cash
	assert_true(PaydayCards.grant(p, {"type": PaydayCards.CASH, "tier": 0, "item_id": &"", "amount": 21000}))
	assert_eq(p.cash, cash0 + 21000, "cash card pays spending cash")
	assert_true(PaydayCards.grant(p, {"type": PaydayCards.XP, "tier": 0, "item_id": &"", "amount": 5000}))
	assert_eq(p.xp, 5000)
	assert_eq(p.level, XpCurve.level_for_xp(5000), "XP card updates the level")
	var mod_id: StringName = PaydayCards.pool(PaydayCards.WEAPON_MOD, p)[0]
	var mod_card: Dictionary = {"type": PaydayCards.WEAPON_MOD, "tier": 0, "item_id": mod_id, "amount": 0}
	assert_true(PaydayCards.grant(p, mod_card))
	assert_has(p.owned_mods, mod_id)
	assert_false(PaydayCards.grant(p, mod_card), "an owned mod is never granted twice")
	var part_id: StringName = &""
	for id: StringName in PaydayCards.pool(PaydayCards.MASK_PART, p):
		if not MaskCatalog.is_preset_id(id):
			part_id = id
			break
	var part_card: Dictionary = {"type": PaydayCards.MASK_PART, "tier": 0, "item_id": part_id, "amount": 0}
	assert_true(PaydayCards.grant(p, part_card))
	assert_true(MaskLocker.is_part_owned(p, part_id))
	assert_false(PaydayCards.grant(p, part_card))
	assert_false(PaydayCards.grant(p, {"type": &"boost", "item_id": &"", "amount": 1}), "unknown type")
	assert_eq(SaveService.save_profile(p, 7), OK)
	var loaded: PlayerProfile = SaveService.load_profile(7)
	assert_eq(loaded.cash, p.cash)
	assert_eq(loaded.xp, 5000)
	assert_has(loaded.owned_mods, mod_id)
	assert_has(loaded.owned_mask_parts, part_id)
