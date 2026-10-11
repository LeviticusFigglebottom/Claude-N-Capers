## B5-02 Notoriety outside the rank-up itself: the XP bonus in PayoutCalculator (its own payday line), the
## payday's use of the profile rank, the payday card pool exclusion and the lobby summary's rank (co-op).
extends TestCase


func before_each() -> void:
	Notoriety.clear_cache()


func test_xp_bonus_math() -> void:
	assert_near(Notoriety.xp_bonus(0), 0.0)
	assert_near(Notoriety.xp_bonus(1), 0.02)
	assert_near(Notoriety.xp_bonus(10), 0.2)
	assert_near(Notoriety.xp_bonus(15), 0.3)
	assert_near(Notoriety.xp_bonus(25), 0.3, 0.0001, "capped at +30 %")


func test_payout_calculator_notoriety_line() -> void:
	var r: Dictionary = {"success": true, "stealth": false, "difficulty": 0, "contract_pay": 1000, "loot": [],
		"small_loot": 0, "crew": [{"slot": 0, "is_ai": false, "in_custody": false}]}
	var d: DifficultyDef = DifficultyDef.new()
	var tw: PayoutTweak = PayoutTweak.new()
	var plain: Dictionary = PayoutCalculator.compute(r, d, tw, false, 0)
	var ranked: Dictionary = PayoutCalculator.compute(r, d, tw, false, 0, 1.0, 1.45, 0.1)
	var base: int = tw.base_xp_success
	assert_eq(_line(plain, PayoutCalculator.XP_NOTORIETY), 0)
	assert_eq(_line(ranked, PayoutCalculator.XP_NOTORIETY), roundi(base * 0.1))
	assert_eq(_line(ranked, PayoutCalculator.XP_ADDITIVE), roundi(base * 0.45), "own line, not merged")
	assert_eq(ranked["xp_total"], base + roundi(base * 0.45) + roundi(base * 0.1), "additive: both on the same total")
	var banked: Dictionary = PayoutCalculator.compute(r, d, tw, false, 0, 1.2, 1.0, 0.1)
	var before_stealth: int = base + roundi(base * 0.1)
	assert_eq(_line(banked, PayoutCalculator.XP_STEALTH), roundi(before_stealth * 0.2), "stealth bonus applies after it")
	r["success"] = false
	var failed: Dictionary = PayoutCalculator.compute(r, d, tw, false, 0, 1.0, 1.0, 0.1)
	var fail_base: int = roundi(base * tw.base_xp_failure_fraction)
	assert_eq(_line(failed, PayoutCalculator.XP_NOTORIETY), roundi(fail_base * 0.1), "a permanent bonus, failures too")


func test_payday_compute_uses_the_profile_rank() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.notoriety = 5
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	var out: Dictionary = PaydayScreen.compute_payout(r, p, 0)
	assert_true(_line(out, PayoutCalculator.XP_NOTORIETY) > 0, "rank V adds the line")
	p.notoriety = 0
	assert_eq(_line(PaydayScreen.compute_payout(r, p, 0), PayoutCalculator.XP_NOTORIETY), 0)


func test_exclusive_parts_never_drop_from_payday_cards() -> void:
	var pool: Array[StringName] = PaydayCards.pool(PaydayCards.MASK_PART, PlayerProfile.new_default())
	var ex: Array[StringName] = Notoriety.exclusive_ids()
	assert_true(ex.size() >= 10)
	for id: StringName in ex:
		assert_false(pool.has(id), "%s is a Notoriety reward only" % id)
	assert_false(pool.has(&"mask.ledger_regent"))


func test_lobby_summary_carries_the_rank() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.profile_name = "Wren"
	p.notoriety = 12
	var sum: Dictionary = LobbyState.summary_from(p.loadout, p)
	assert_eq(sum["notoriety"], 12)
	assert_true(LobbyState.is_json_safe(sum))
	var wire: Dictionary = JSON.parse_string(JSON.stringify(sum)) as Dictionary
	var clean: Dictionary = LobbyState.sanitize_summary(wire)
	assert_eq(clean["notoriety"], 12, "survives JSON (float -> int)")
	assert_eq(LobbyState.validate_summary(clean), [] as Array[String])
	var s: LobbyState = LobbyState.new(true)
	s.set_crew({0: {"peer_id": 1, "is_ai": false, "display_name": "Host"},
		1: {"peer_id": 7, "is_ai": false, "display_name": "P7"}}, 0, 0)
	assert_eq(s.receive(1, LobbyState.MSG_PROFILE, wire), LobbyState.OK)
	assert_eq(s.slot_view(1)["notoriety"], 12, "every peer sees the rank")
	assert_true(s.is_legal(1))
	var old: Dictionary = wire.duplicate(true)
	old.erase("notoriety")
	assert_eq(LobbyState.sanitize_summary(old)["notoriety"], 0, "an older peer's summary reads as rank 0")
	var forged: Dictionary = clean.duplicate(true)
	forged["notoriety"] = 99
	assert_false(LobbyState.validate_summary(forged).is_empty(), "rank above the cap flagged")
	wire["notoriety"] = "XII"
	assert_eq(LobbyState.sanitize_summary(wire), {}, "a non-int rank is malformed")


func _line(out: Dictionary, key: StringName) -> int:
	for l: Dictionary in out["xp_lines"] as Array:
		if l["key"] == key:
			return int(l["amount"])
	return -999999
