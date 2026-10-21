## LEAD r251: Ostrander Federal payday / achievement / progression end to end, per difficulty. A HeistResult shaped like
## HeistRuntime's (contract_pay = HeistDef.base_payout, loot = LootDef values per bag) goes through PayoutCalculator,
## SaveService.apply_heist_payout (XpCurve levels) and Achievements.on_payday on a fresh profile: the cash matches the
## briefing's contract preview, XP grows with difficulty, the right OF achievements unlock and grant their mask parts.
extends TestCase

const OF: StringName = &"ostrander_federal"
const DIFFICULTIES: Array[int] = [0, 1, 2, 3, 4, 5]
## D-137: the OF contract on the D-120 shape; the briefing shows base x DifficultyDef.payout_mult.
const BASE_PAYOUT: int = 80000
const PAYOUT_MULTS: Array[float] = [1.0, 2.0, 2.6, 4.2, 7.2, 9.2]
const STEALTH_SET: Array[StringName] = [&"achievement.of_quiet_weekend", &"achievement.of_no_harm_done",
	&"achievement.of_bank_holiday"]
const LOUD_SET: Array[StringName] = [&"achievement.of_burn_and_hoist", &"achievement.of_clearing_house"]


func _def() -> HeistDef:
	return HeistRegistry.get_def(OF)


func _bags(id: StringName, n: int) -> Array:
	var v: int = int(LootManager.loot_info(id).get("value", 0))
	var out: Array = []
	for i: int in range(n):
		out.append({"loot_id": id, "value": v})
	return out


func _crew(in_custody: bool = false) -> Array:
	var out: Array = []
	for slot: int in range(4):
		out.append({"slot": slot, "is_ai": slot > 0, "name": "", "kills": 0, "specials_killed": 0, "downs": 0,
			"civilians_killed": 0, "shots": 0, "hits": 0, "headshots": 0, "in_custody": in_custody and slot == 0,
			"escaped": true})
	return out


## A successful run as HeistRuntime reports it.
func _result(d: int, stealth: bool, loot: Array, over: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {
		"heist_id": OF, "success": true, "stealth": stealth, "time_s": 900.0, "difficulty": d,
		"contract_pay": _def().base_payout, "loot": loot, "small_loot": 0, "crew": _crew(), "pagers_answered": 0,
		"seed": 7, "variants": {}, "fail_reason": &"", "loot_available": loot.size(),
	}
	r.merge(over, true)
	return r


## Payout for slot 0, applied to `p` as the payday screen does; returns [payout, unlocked ids].
func _payday(p: PlayerProfile, r: Dictionary, facts: Dictionary = {}) -> Array:
	var payout: Dictionary = PayoutCalculator.compute(r, null, null, false, 0, p.banked_stealth_mult)
	SaveService.apply_heist_payout(p, payout, XpCurve.level_for_xp)
	return [payout, Achievements.on_payday(p, r, payout, false, facts)]


func _breach_facts() -> Dictionary:
	var f: HeistFacts = HeistFacts.new()
	for id: StringName in [&"vault_drill", &"vault_breach"]:
		f.record(&"objective_updated", [id, Enums.ObjectiveState.COMPLETED, {}])
	return f.snapshot()


func test_contract_matches_the_briefing_on_every_difficulty() -> void:
	assert_eq(_def().base_payout, BASE_PAYOUT, "D-137 base payout")
	for d: int in DIFFICULTIES:
		var payout: Dictionary = PayoutCalculator.compute(_result(d, true, []), null, null, false, 0)
		var want: int = roundi(BASE_PAYOUT * PAYOUT_MULTS[d])
		assert_eq(int(payout["contract"]), want, "d%d contract" % d)
		assert_eq(int(payout["contract"]), HeistCatalog.contract_preview(BASE_PAYOUT, d), "d%d = briefing preview" % d)


func test_stealth_clear_pays_levels_and_unlocks_per_difficulty() -> void:
	var last_xp: int = -1
	for d: int in DIFFICULTIES:
		var p: PlayerProfile = PlayerProfile.new_default()
		var loot: Array = _bags(&"loot.cash_bricks", 4) + _bags(&"loot.bearer_bonds", 2)
		var out: Array = _payday(p, _result(d, true, loot))
		var payout: Dictionary = out[0]
		var got: Array[StringName] = out[1]
		var mult: float = PAYOUT_MULTS[d]
		assert_eq(int(payout["loot"]), roundi(8000 * mult) * 4 + roundi(7000 * mult) * 2, "d%d loot" % d)
		assert_true(float(payout["crew_alive_mult"]) > 1.0, "d%d crew-alive bonus" % d)
		assert_eq(int(payout["stash"]) + int(payout["spending"]), int(payout["total"]), "d%d stash + spending" % d)
		assert_eq(p.stash, int(payout["stash"]), "d%d stash banked" % d)
		assert_eq(p.cash, PlayerProfile.new_default().cash + int(payout["spending"]), "d%d spending cash" % d)
		assert_eq(p.xp, PlayerProfile.new_default().xp + int(payout["xp_total"]), "d%d xp" % d)
		assert_eq(p.level, XpCurve.level_for_xp(p.xp), "d%d level from xp" % d)
		assert_true(int(payout["xp_total"]) > last_xp, "d%d xp grows with difficulty (%d > %d)" % [d,
				int(payout["xp_total"]), last_xp])
		last_xp = int(payout["xp_total"])
		assert_eq(float(payout["stealth_bonus_banked"]), PayoutCalculator.stealth_bonus_for(OF), "d%d bank" % d)
		assert_eq(p.banked_stealth_mult, PayoutCalculator.stealth_bonus_for(OF), "d%d banked on the profile" % d)
		for id: StringName in STEALTH_SET:
			assert_true(got.has(id), "d%d stealth clear unlocks %s" % [d, id])
		for id: StringName in LOUD_SET:
			assert_false(got.has(id), "d%d stealth clear does not unlock %s" % [d, id])
		assert_eq(got.has(&"achievement.of_cataclysm"), d == Enums.Difficulty.CATACLYSM, "d%d cataclysm" % d)
		_assert_rewards(p, got, d)


func test_loud_breach_with_every_bag_unlocks_the_loud_set() -> void:
	for d: int in DIFFICULTIES:
		var p: PlayerProfile = PlayerProfile.new_default()
		var loot: Array = _bags(&"loot.cash_bricks", 6) + _bags(&"loot.gold", 2) + _bags(&"loot.server_drives", 2)
		var out: Array = _payday(p, _result(d, false, loot, {"pagers_answered": 2, "time_s": 1500.0}),
				_breach_facts())
		var payout: Dictionary = out[0]
		var got: Array[StringName] = out[1]
		assert_false(bool(payout["stealth"]), "d%d loud" % d)
		assert_eq(float(payout["stealth_bonus_banked"]), 1.0, "d%d loud banks no stealth bonus" % d)
		for id: StringName in LOUD_SET:
			assert_true(got.has(id), "d%d loud breach unlocks %s" % [d, id])
		for id: StringName in STEALTH_SET:
			assert_false(got.has(id), "d%d loud does not unlock %s" % [d, id])
		_assert_rewards(p, got, d)


func test_a_failed_run_pays_and_unlocks_nothing() -> void:
	for d: int in DIFFICULTIES:
		var p: PlayerProfile = PlayerProfile.new_default()
		var r: Dictionary = _result(d, false, _bags(&"loot.gold", 2), {"success": false, "fail_reason": &"crew_custody",
				"crew": _crew(true)})
		var out: Array = _payday(p, r, _breach_facts())
		var payout: Dictionary = out[0]
		var got: Array[StringName] = out[1]
		assert_eq(int(payout["total"]), 0, "d%d D-120: a failure pays nothing" % d)
		assert_eq(p.stash + p.cash, PlayerProfile.new_default().stash + PlayerProfile.new_default().cash,
				"d%d no money" % d)
		for a: AchievementDef in Achievements.all():
			if a.category == OF:
				assert_false(got.has(a.id), "d%d failure unlocks no %s" % [d, a.id])


func test_a_second_clear_grants_nothing_twice() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var loot: Array = _bags(&"loot.cash_bricks", 4)
	_payday(p, _result(Enums.Difficulty.CATACLYSM, true, loot))
	var parts: int = p.owned_mask_parts.size()
	var again: Array[StringName] = _payday(p, _result(Enums.Difficulty.CATACLYSM, true, loot))[1]
	for a: AchievementDef in Achievements.all():
		if a.category == OF:
			assert_false(again.has(a.id), "already unlocked: %s" % a.id)
	assert_eq(p.owned_mask_parts.size(), parts, "no duplicate mask parts")


## Every unlocked OF achievement's reward parts are owned, exist in the catalog, and are named.
func _assert_rewards(p: PlayerProfile, got: Array[StringName], d: int) -> void:
	for id: StringName in got:
		var a: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, id) as AchievementDef
		if a == null or a.category != OF:
			continue
		assert_false(a.rewards.is_empty(), "d%d %s grants a mask part" % [d, id])
		for part: StringName in a.rewards:
			assert_true(MaskCatalog.has_part(part), "d%d %s: part %s exists" % [d, id, part])
			assert_true(MaskLocker.is_part_owned(p, part), "d%d %s: part %s granted" % [d, id, part])
		assert_ne(AchievementsScreen.reward_name(a), "", "d%d %s: reward has a name" % [d, id])
