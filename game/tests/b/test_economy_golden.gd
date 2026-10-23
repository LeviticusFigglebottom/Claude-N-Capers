## S10.6 / D-120 economy golden test (D-161 (1), LEAD r287). Pins pd2_fidelity.md's S10.6 table against the real data and
## code: the unscaled bag values (LootDefs, PD2's order), each heist's contract (HeistDef.base_payout through
## HeistCatalog.contract_preview at every difficulty), the broker price (BoardBroker.cost with the shipped BoardTweak), and
## the bag share of a full clear (bags / (contract + bags + small loot), the table's full-clear bag and small-loot totals).
## A change to any of these is an economy change: update the S10.6 table and this file together, through the LEAD.
extends TestCase

## D-120 bag values (unscaled), highest first.
const BAGS: Dictionary = {
	&"loot.gold": 14000, &"loot.weapon_crate": 8500, &"loot.cash_bricks": 8000, &"loot.ledger_books": 8000,
	&"loot.painting_lantern_bearer": 8000, &"loot.ledger_drives": 7500, &"loot.parcels": 7500,
	&"loot.server_drives": 7500, &"loot.contraband": 7000, &"loot.bearer_bonds": 7000,
	&"loot.painting_salt_orchard": 6800, &"loot.cash": 6500, &"loot.jewelry": 6000, &"loot.painting_widow_in_blue": 6000,
	&"loot.painting_tidewater_saint": 5200, &"loot.ledger_laptop": 5000, &"loot.painting": 4500,
	&"loot.painting_study": 2800,
}
## heist -> [base_payout, Routine full-clear bags, Routine small loot, bag share %] (S10.6 table, D-120).
const HEISTS: Dictionary = {
	&"glasshouse": [12000, 27000, 9850, 55],
	&"night_deposit": [26000, 75350, 11000, 67],
	&"shadow_ledger": [70000, 51000, 8500, 39],
	&"dockside_burn": [24000, 122400, 5250, 81],
	&"gallery_night": [57000, 79200, 14100, 53],
}
## heist -> contract per difficulty (Routine .. Cataclysm), the S10.6 table's Contract column.
const CONTRACTS: Dictionary = {
	&"glasshouse": [12000, 24000, 31200, 50400, 86400, 110400],
	&"night_deposit": [26000, 52000, 67600, 109200, 187200, 239200],
	&"shadow_ledger": [70000, 140000, 182000, 294000, 504000, 644000],
	&"dockside_burn": [24000, 48000, 62400, 100800, 172800, 220800],
	&"gallery_night": [57000, 114000, 148200, 239400, 410400, 524400],
}
## heist -> broker price per difficulty, the S10.6 table's Broker column.
const BROKER: Dictionary = {
	&"glasshouse": [5200, 10400, 17120, 35040, 68640, 101040],
	&"night_deposit": [6600, 13200, 20760, 40920, 78720, 113920],
	&"shadow_ledger": [11000, 22000, 32200, 59400, 110400, 154400],
	&"dockside_burn": [6400, 12800, 20240, 40080, 77280, 112080],
	&"gallery_night": [9700, 19400, 28820, 53940, 101040, 142440],
}


func before_all() -> void:
	ContentDB.clear_cache()


func test_bag_values_and_pd2_order() -> void:
	var last: int = 1 << 30
	for id: StringName in BAGS:
		var def: LootDef = ContentDB.by_id(ContentDB.LOOT, id) as LootDef
		assert_true(def != null, "%s exists" % id)
		if def == null:
			continue
		assert_eq(def.value, int(BAGS[id]), "%s = $%d (D-120)" % [id, int(BAGS[id])])
		assert_true(int(BAGS[id]) <= last, "%s keeps PD2's order" % id)
		last = int(BAGS[id])


func test_contracts_scale_per_difficulty() -> void:
	for h: StringName in HEISTS:
		var def: HeistDef = HeistRegistry.get_def(h)
		assert_true(def != null, "%s def" % h)
		if def == null:
			continue
		assert_eq(def.base_payout, int((HEISTS[h] as Array)[0]), "%s base_payout (D-120)" % h)
		for d: int in range(Enums.Difficulty.size()):
			assert_eq(HeistCatalog.contract_preview(def.base_payout, d), int((CONTRACTS[h] as Array)[d]),
					"%s contract @%d" % [h, d])


func test_broker_prices() -> void:
	var t: BoardTweak = BoardTweak.load_default()
	for h: StringName in HEISTS:
		var base: int = int((HEISTS[h] as Array)[0])
		for d: int in range(Enums.Difficulty.size()):
			var cost: int = BoardBroker.cost(base, d, t)
			assert_eq(cost, int((BROKER[h] as Array)[d]), "%s broker @%d" % [h, d])
			var c: int = int((CONTRACTS[h] as Array)[d])
			var r: Array = HEISTS[h] as Array
			var mult: float = float(c) / float(r[0])
			var full: float = (c + (int(r[1]) + int(r[2])) * mult) * 1.1
			var share: float = cost / full
			assert_true(share > 0.02 and share < 0.25, "%s @%d: the broker is %.1f%% of a full clear (a small cut)"
					% [h, d, share * 100.0])


func test_bags_are_most_of_a_full_clear() -> void:
	for h: StringName in HEISTS:
		var r: Array = HEISTS[h] as Array
		var share: float = float(r[1]) / float(int(r[0]) + int(r[1]) + int(r[2]))
		assert_eq(roundi(share * 100.0), int(r[3]), "%s: bags are %d%% of a full clear (S10.6)" % [h, int(r[3])])
		if h != &"shadow_ledger":  # SL is an objective heist: its contract is the floor
			assert_true(share > 0.5, "%s: greed pays (bags > half a full clear)" % h)
