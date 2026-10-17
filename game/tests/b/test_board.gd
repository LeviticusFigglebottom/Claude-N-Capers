## B4-06: the Board's contract generator (deterministic per time bucket, level gating, pro chance)
## and the contract broker (cost table, stash charge, refusals).
extends TestCase

const PERIOD: float = 600.0
## A bucket boundary for slot 0 plus one second (see _tweak: 8 staggered slots, 75 s apart).
const T0: float = 600.0 * 3000.0 + 1.0

var _city: BoardCityMap


func before_all() -> void:
	_city = BoardCityMap.load_default()


func _tweak(board_seed: int = 11) -> BoardTweak:
	var t: BoardTweak = BoardTweak.new()
	t.board_seed = board_seed
	t.slot_count = 8
	t.rotation_s = PERIOD
	t.stagger_slots = true
	t.difficulty_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	t.difficulty_min_level = [0, 0, 0, 0, 80, 80]
	t.respect_build_unlocks = false
	t.pro_chance = 0.2
	t.pro_min_difficulty = 1
	t.fallback_contacts = [&"contact.vance", &"contact.reyes", &"contact.accountant"]
	t.broker_cost_by_difficulty = [10000, 20000, 40000, 80000, 160000, 320000]
	t.broker_cost_payout_fraction = 0.1
	return t


func _pool() -> Array[Dictionary]:
	return [
		{"id": &"glasshouse", "base_payout": 40000, "mode": 0, "contact": &"contact.vance"},
		{"id": &"night_deposit", "base_payout": 60000, "mode": 0, "contact": &""},
	]


func _key(c: Dictionary) -> String:
	return "%s|%d|%s|%s|%s" % [c["heist_id"], c["difficulty"], c["is_pro"], c["contact_id"], c["map_pos"]]


func test_data_files_load() -> void:
	var t: BoardTweak = BoardTweak.load_default()
	assert_true(t.slot_count > 0 and t.rotation_s > 0.0)
	assert_eq(t.difficulty_weights.size(), Enums.Difficulty.size())
	assert_eq(t.difficulty_min_level.size(), Enums.Difficulty.size())
	assert_eq(t.broker_cost_by_difficulty.size(), Enums.Difficulty.size())
	for i: int in range(1, t.broker_cost_by_difficulty.size()):
		assert_true(t.broker_cost_by_difficulty[i] > t.broker_cost_by_difficulty[i - 1], "broker cost rises with difficulty")
	assert_true(t.min_level_of(Enums.Difficulty.LETHAL) >= 80 and t.min_level_of(Enums.Difficulty.CATACLYSM) >= 80)
	for cid: StringName in t.fallback_contacts:
		assert_true(ContactDef.find(cid) != null, "fallback contact %s exists" % cid)
	for id: StringName in _city.district_ids():
		assert_true((_city.districts[id]["polygon"] as PackedVector2Array).size() >= 3, "district %s polygon" % id)
	for hid: Variant in _city.heists:
		var d: Dictionary = _city.heists[hid] as Dictionary
		assert_true(_city.districts.has(StringName(d["district"])), "heist %s district" % hid)
		assert_true(ContactDef.find(StringName(d["contact"])) != null, "heist %s contact" % hid)
		var p: Vector2 = d["pos"] as Vector2
		assert_true(p.x > 0.0 and p.x < 1.0 and p.y > 0.0 and p.y < 1.0)
	for e: Dictionary in HeistCatalog.entries():
		assert_true(_city.heists.has(StringName(e["id"])), "every offered heist has a map spot: %s" % e["id"])


func test_rotation_is_deterministic_per_time_bucket() -> void:
	var t: BoardTweak = _tweak()
	var a: Array[Dictionary] = BoardContracts.generate(T0, 50, _pool(), t, _city)
	var again: Array[Dictionary] = BoardContracts.generate(T0, 50, _pool(), t, _city)
	var later: Array[Dictionary] = BoardContracts.generate(T0 + 70.0, 50, _pool(), t, _city)
	assert_eq(a.size(), 8)
	for i: int in range(8):
		assert_eq(a[i]["slot"], i)
		assert_eq(_key(a[i]), _key(again[i]), "same inputs, same contract")
		assert_eq(_key(a[i]), _key(later[i]), "no slot rotates within 70 s of T0")
		assert_true(float(a[i]["starts_at"]) <= T0 and T0 < float(a[i]["expires_at"]))
		assert_near(float(a[i]["expires_at"]) - float(a[i]["starts_at"]), PERIOD)
	# Staggered: slot 7 rotates at T0 + 74 s, the others later.
	var b: Array[Dictionary] = BoardContracts.generate(T0 + 80.0, 50, _pool(), t, _city)
	for i: int in range(7):
		assert_eq(b[i]["bucket"], a[i]["bucket"], "slot %d unchanged" % i)
	assert_eq(int(b[7]["bucket"]), int(a[7]["bucket"]) + 1, "slot 7 rotated")
	assert_near(BoardContracts.next_expiry(a), float(a[7]["expires_at"]))
	# A full period later every slot has a new bucket.
	var c: Array[Dictionary] = BoardContracts.generate(T0 + PERIOD, 50, _pool(), t, _city)
	var changed: int = 0
	for i: int in range(8):
		assert_eq(int(c[i]["bucket"]), int(a[i]["bucket"]) + 1)
		if _key(c[i]) != _key(a[i]):
			changed += 1
	assert_true(changed >= 6, "new contracts after a rotation: %d" % changed)
	var other: Array[Dictionary] = BoardContracts.generate(T0, 50, _pool(), _tweak(12), _city)
	var diff_seed: int = 0
	for i: int in range(8):
		if _key(other[i]) != _key(a[i]):
			diff_seed += 1
	assert_true(diff_seed >= 6, "the seed matters: %d" % diff_seed)
	assert_true(BoardContracts.generate(T0, 50, [] as Array[Dictionary], t, _city).is_empty(), "empty pool, empty board")


func test_contract_fields() -> void:
	var t: BoardTweak = _tweak()
	for c: Dictionary in BoardContracts.generate(T0, 0, _pool(), t, _city):
		var id: StringName = StringName(c["heist_id"])
		assert_true(id == &"glasshouse" or id == &"night_deposit")
		if id == &"glasshouse":
			assert_eq(c["contact_id"], &"contact.vance", "pool contact wins")
			assert_eq(c["district"], &"harlow")
			assert_eq(c["payout"], HeistCatalog.contract_preview(40000, int(c["difficulty"])))
		else:
			assert_true(t.fallback_contacts.has(StringName(c["contact_id"])), "fallback contact")
		var p: Vector2 = c["map_pos"] as Vector2
		assert_true(p.distance_to(_city.heist_anchor(id)) <= t.pin_jitter * 1.5, "pin near its heist")


func test_level_gating() -> void:
	var t: BoardTweak = _tweak()
	assert_eq(BoardContracts.allowed_difficulties(79, t), [0, 1, 2, 3] as Array[int])
	assert_eq(BoardContracts.allowed_difficulties(80, t), [0, 1, 2, 3, 4, 5] as Array[int])
	t.respect_build_unlocks = true
	var gate: Callable = func(d: int) -> bool: return d == 0 or d == 3
	assert_eq(BoardContracts.allowed_difficulties(100, t, gate), [0, 3] as Array[int])
	t.respect_build_unlocks = false
	var high_low: int = 0
	var high_vet: int = 0
	for k: int in range(60):
		for c: Dictionary in BoardContracts.generate(T0 + PERIOD * k, 79, _pool(), t, _city):
			if int(c["difficulty"]) >= Enums.Difficulty.LETHAL:
				high_low += 1
		for c: Dictionary in BoardContracts.generate(T0 + PERIOD * k, 80, _pool(), t, _city):
			if int(c["difficulty"]) >= Enums.Difficulty.LETHAL:
				high_vet += 1
	assert_eq(high_low, 0, "level 79 never sees Lethal/Cataclysm")
	assert_true(high_vet > 60, "level 80 does: %d" % high_vet)


func test_pro_chance_bounds() -> void:
	var t: BoardTweak = _tweak()
	var eligible: int = 0
	var pro: int = 0
	for k: int in range(300):
		for c: Dictionary in BoardContracts.generate(T0 + PERIOD * k, 100, _pool(), t, _city):
			if int(c["difficulty"]) < t.pro_min_difficulty:
				assert_false(bool(c["is_pro"]), "no pro below pro_min_difficulty")
				continue
			eligible += 1
			if bool(c["is_pro"]):
				pro += 1
	var frac: float = float(pro) / float(eligible)
	assert_true(frac > 0.16 and frac < 0.24, "pro fraction %.3f near 0.2 over %d" % [frac, eligible])
	for chance: float in [0.0, 1.0]:
		t.pro_chance = chance
		for k: int in range(40):
			for c: Dictionary in BoardContracts.generate(T0 + PERIOD * k, 100, _pool(), t, _city):
				var expect: bool = chance > 0.5 and int(c["difficulty"]) >= t.pro_min_difficulty
				assert_eq(bool(c["is_pro"]), expect)


func test_broker_cost_and_purchase() -> void:
	var t: BoardTweak = _tweak()
	var p: PlayerProfile = PlayerProfile.new()
	p.level = 10
	var cost: int = BoardBroker.cost(40000, Enums.Difficulty.BRUTAL, t)
	assert_eq(cost, 80000 + roundi(HeistCatalog.contract_preview(40000, Enums.Difficulty.BRUTAL) * 0.1))
	p.stash = cost + 5
	assert_eq(BoardBroker.check(p, &"glasshouse", Enums.Difficulty.BRUTAL, _pool(), t), BoardBroker.OK)
	assert_eq(BoardBroker.buy(p, &"glasshouse", Enums.Difficulty.BRUTAL, _pool(), t), BoardBroker.OK)
	assert_eq(p.stash, 5, "cost deducted from the stash")
	assert_eq(BoardBroker.buy(p, &"glasshouse", Enums.Difficulty.BRUTAL, _pool(), t), BoardBroker.R_STASH)
	assert_eq(p.stash, 5, "refused purchase changes nothing")
	p.stash = 10000000
	assert_eq(BoardBroker.buy(p, &"glasshouse", Enums.Difficulty.LETHAL, _pool(), t), BoardBroker.R_LOCKED, "level 10")
	assert_eq(BoardBroker.buy(p, &"nope", Enums.Difficulty.ROUTINE, _pool(), t), BoardBroker.R_UNKNOWN_HEIST)
	assert_eq(p.stash, 10000000)
	assert_eq(BoardBroker.buy(null, &"glasshouse", Enums.Difficulty.ROUTINE, _pool(), t), BoardBroker.R_STASH)
	assert_true(BoardBroker.cost(40000, Enums.Difficulty.CATACLYSM, t) > BoardBroker.cost(40000, Enums.Difficulty.ROUTINE, t))


func test_pool_contacts() -> void:
	var def: HeistDef = HeistDef.new()
	def.id = &"glasshouse"
	def.contact = &"contact.reyes"
	var entries: Array[Dictionary] = [
		{"id": &"glasshouse", "base_payout": 40000, "mode": 0, "def": def},
		{"id": &"night_deposit", "base_payout": 60000, "mode": 0, "def": null},
	]
	var pool: Array[Dictionary] = BoardContracts.pool_from(entries, _city)
	assert_eq(pool[0]["contact"], &"contact.reyes", "HeistDef.contact first")
	assert_eq(pool[1]["contact"], &"contact.accountant", "then the city map")
	assert_true(not BoardContracts.pool().is_empty(), "the live catalog offers heists")


## OF-B1 Board entry: per-heist weight / pro / difficulty floor from the city map. Equal weights keep the shipped
## uniform draw (same contracts as before); OF's staged entry is 0.75 / pro / Routine.
func test_per_heist_board_fields() -> void:
	var city: BoardCityMap = BoardCityMap.load_default()
	assert_near(city.heist_weight(&"ostrander_federal"), 0.75, 0.0001)
	assert_true(city.heist_pro(&"ostrander_federal"))
	assert_eq(city.heist_difficulty_min(&"ostrander_federal"), 0)
	assert_eq(city.heist_contact(&"ostrander_federal"), &"contact.accountant")
	assert_near(city.heist_weight(&"glasshouse"), 1.0, 0.0001, "unset = 1.0")
	var tw: BoardTweak = BoardTweak.new()
	tw.board_seed = 7
	var even: Array[Dictionary] = [{"id": &"a", "weight": 1.0}, {"id": &"b", "weight": 1.0}, {"id": &"c", "weight": 1.0}]
	var bare: Array[Dictionary] = [{"id": &"a"}, {"id": &"b"}, {"id": &"c"}]
	var allowed: Array[int] = [0, 1, 2, 3]
	for b: int in range(40):
		assert_eq(BoardContracts.contract_for(0, b, allowed, even, tw, null)["heist_id"],
				BoardContracts.contract_for(0, b, allowed, bare, tw, null)["heist_id"], "equal weights = the uniform draw")
	var skewed: Array[Dictionary] = [{"id": &"a", "weight": 9.0}, {"id": &"b", "weight": 1.0}]
	var a_count: int = 0
	for b: int in range(400):
		a_count += int(BoardContracts.contract_for(0, b, allowed, skewed, tw, null)["heist_id"] == &"a")
	assert_true(a_count > 320 and a_count < 400, "weight 9:1 (%d of 400)" % a_count)
	var floored: Array[Dictionary] = [{"id": &"a", "difficulty_min": 2, "pro": false}]
	tw.pro_chance = 1.0
	for b: int in range(40):
		var c: Dictionary = BoardContracts.contract_for(0, b, allowed, floored, tw, null)
		assert_true(int(c["difficulty"]) >= 2, "difficulty floor")
		assert_false(bool(c["is_pro"]), "pro: false never rolls pro")
