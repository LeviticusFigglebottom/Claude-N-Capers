## B1-07: PayoutCalculator golden numbers (pd2_fidelity S10.4, S7.3, C6).
## Difficulty defs are built in code so these goldens don't depend on the difficulty data files.
extends TestCase


func _diff(payout_mult: float, xp_mult: float, civ_penalty: int) -> DifficultyDef:
	var d: DifficultyDef = DifficultyDef.new()
	d.payout_mult = payout_mult
	d.xp_mult = xp_mult
	d.civilian_kill_penalty = civ_penalty
	return d


func _tweak() -> PayoutTweak:
	return PayoutTweak.new()  # script defaults == payout.tres values (checked below)


func _member(slot: int, is_ai: bool, custody: bool = false, civs: int = 0) -> Dictionary:
	return {"slot": slot, "is_ai": is_ai, "kills": 0, "specials_killed": 0, "downs": 0,
		"civilians_killed": civs, "in_custody": custody, "escaped": not custody}


func _result(success: bool = true, stealth: bool = false) -> Dictionary:
	return {
		"heist_id": &"glasshouse", "success": success, "stealth": stealth, "time_s": 600.0, "difficulty": 0,
		"contract_pay": 10000,
		"loot": [{"loot_id": &"loot.jewelry", "value": 1000}, {"loot_id": &"loot.jewelry", "value": 1000},
			{"loot_id": &"loot.cash", "value": 2500}],
		"small_loot": 750,
		"crew": [_member(0, false), _member(1, false), _member(2, true), _member(3, true)],
		"pagers_answered": 0, "seed": 1, "variants": {},
	}


func _xp(out: Dictionary, key: StringName) -> int:
	for l: Dictionary in out["xp_lines"] as Array:
		if l["key"] == key:
			return int(l["amount"])
	return -999999


func test_tres_matches_script_defaults() -> void:
	var tw: PayoutTweak = load(PayoutCalculator.DEFAULT_TWEAK_PATH) as PayoutTweak
	assert_true(tw != null, "payout.tres loads")
	if tw == null:
		return
	var d: PayoutTweak = PayoutTweak.new()
	for p: Dictionary in d.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(tw.get(p["name"]), d.get(p["name"]), String(p["name"]))


func test_golden_routine() -> void:
	var out: Dictionary = PayoutCalculator.compute(_result(), _diff(1.0, 1.0, 4000), _tweak(), false, 0)
	assert_eq(out["contract"], 10000)
	assert_eq(out["loot"], 4500)
	assert_eq(out["small_loot"], 750)
	assert_eq(out["subtotal"], 15250)
	assert_near(float(out["crew_alive_mult"]), 1.1)
	assert_eq(out["gross"], 16775)
	assert_eq(out["civilian_penalty"], 0)
	assert_eq(out["total"], 16775)
	assert_eq(out["stash"], 13420)
	assert_eq(out["spending"], 3355)
	# XP: base 2000 + 3 bags x 250; 3 surviving teammates -> +30% additive.
	assert_eq(_xp(out, PayoutCalculator.XP_BASE), 2750)
	assert_eq(_xp(out, PayoutCalculator.XP_PRO), 0)
	assert_eq(_xp(out, PayoutCalculator.XP_DIFFICULTY), 0)
	assert_eq(_xp(out, PayoutCalculator.XP_CUSTODY), 0)
	assert_eq(_xp(out, PayoutCalculator.XP_ADDITIVE), 825)
	assert_eq(_xp(out, PayoutCalculator.XP_STEALTH), 0)
	assert_eq(out["xp_total"], 3575)
	assert_false(out["stealth_bonus_consumed"])
	assert_near(float(out["stealth_bonus_banked"]), 1.0)


## D-022 QB-13: a successful stealth heist BANKS the bonus; with nothing banked its own stealth XP
## line is 0.
func test_golden_brutal_pro_stealth() -> void:
	var r: Dictionary = _result(true, true)
	r["difficulty"] = Enums.Difficulty.BRUTAL
	var out: Dictionary = PayoutCalculator.compute(r, _diff(4.2, 10.0, 4000), _tweak(), true, 0)
	assert_eq(out["contract"], 42000)
	var lines: Array = out["loot_lines"] as Array
	assert_eq(lines.size(), 3)
	assert_eq(lines[0], {"loot_id": &"loot.jewelry", "base": 1000, "value": 4200})
	assert_eq(lines[2], {"loot_id": &"loot.cash", "base": 2500, "value": 10500})
	assert_eq(out["loot"], 18900)
	assert_eq(out["small_loot"], 3150)
	assert_eq(out["subtotal"], 64050)
	assert_eq(out["gross"], 70455)
	assert_eq(out["stash"], 56364)
	assert_eq(out["spending"], 14091)
	# XP chain: 2750 -> pro +550 -> difficulty x10 +29700 -> additive +30% 9900 -> no bank, stealth 0.
	assert_eq(_xp(out, PayoutCalculator.XP_BASE), 2750)
	assert_eq(_xp(out, PayoutCalculator.XP_PRO), 550)
	assert_eq(_xp(out, PayoutCalculator.XP_DIFFICULTY), 29700)
	assert_eq(_xp(out, PayoutCalculator.XP_ADDITIVE), 9900)
	assert_eq(_xp(out, PayoutCalculator.XP_STEALTH), 0)
	assert_eq(out["xp_total"], 42900)
	assert_near(float(out["stealth_bonus_banked"]), 1.2, 0.0001, "banked for the next payday")
	assert_false(out["stealth_bonus_consumed"])


## Same heist, but the previous heist banked x1.2: it is spent here (+20% of 42900) and this
## stealth heist banks a fresh x1.2.
func test_golden_brutal_pro_stealth_with_bank() -> void:
	var r: Dictionary = _result(true, true)
	r["difficulty"] = Enums.Difficulty.BRUTAL
	var out: Dictionary = PayoutCalculator.compute(r, _diff(4.2, 10.0, 4000), _tweak(), true, 0, 1.2)
	assert_eq(out["gross"], 70455, "the bank never touches cash")
	assert_eq(_xp(out, PayoutCalculator.XP_STEALTH), 8580)
	assert_eq(out["xp_total"], 51480)
	assert_true(out["stealth_bonus_consumed"])
	assert_near(float(out["stealth_bonus_banked"]), 1.2)


func test_loud_success_consumes_bank_and_banks_nothing() -> void:
	var out: Dictionary = PayoutCalculator.compute(_result(true, false), _diff(1.0, 1.0, 0), _tweak(), false, 0, 1.2)
	assert_eq(_xp(out, PayoutCalculator.XP_STEALTH), 715, "3575 x 0.2")
	assert_eq(out["xp_total"], 4290)
	assert_true(out["stealth_bonus_consumed"])
	assert_near(float(out["stealth_bonus_banked"]), 1.0)


func test_failure_keeps_bank_and_banks_nothing() -> void:
	var out: Dictionary = PayoutCalculator.compute(_result(false, true), _diff(1.0, 1.0, 0), _tweak(), false, 0, 1.2)
	assert_eq(_xp(out, PayoutCalculator.XP_STEALTH), 0)
	assert_false(out["stealth_bonus_consumed"], "failure does not consume the bank")
	assert_near(float(out["stealth_bonus_banked"]), 1.0)


func test_routine_golden_unchanged_without_bank() -> void:
	var out: Dictionary = PayoutCalculator.compute(_result(), _diff(1.0, 1.0, 4000), _tweak(), false, 0, 1.0)
	assert_eq(out["xp_total"], 3575)
	assert_false(out["stealth_bonus_consumed"])
	assert_near(float(out["stealth_bonus_banked"]), 1.0)


func test_small_loot_unscaled_when_flag_off() -> void:
	var tw: PayoutTweak = _tweak()
	tw.small_loot_scaled_by_difficulty = false
	var out: Dictionary = PayoutCalculator.compute(_result(), _diff(4.2, 1.0, 0), tw, false, 0)
	assert_eq(out["small_loot"], 750)
	assert_eq(out["contract"], 42000, "contract always scales (D-020)")


func test_crew_alive_bonus_off_when_anyone_in_custody() -> void:
	var r: Dictionary = _result()
	(r["crew"] as Array)[3] = _member(3, true, true)  # an AI in custody also counts
	var out: Dictionary = PayoutCalculator.compute(r, _diff(1.0, 1.0, 0), _tweak(), false, 0)
	assert_near(float(out["crew_alive_mult"]), 1.0)
	assert_eq(out["gross"], 15250)
	assert_eq(out["stash"], 12200)
	assert_eq(out["spending"], 3050)
	assert_eq(_xp(out, PayoutCalculator.XP_ADDITIVE), 550, "2 surviving teammates -> +20%")


func test_custody_xp_penalty_for_that_player() -> void:
	var r: Dictionary = _result()
	(r["crew"] as Array)[1] = _member(1, false, true)
	var out: Dictionary = PayoutCalculator.compute(r, _diff(1.0, 1.0, 0), _tweak(), false, 1)
	assert_eq(_xp(out, PayoutCalculator.XP_CUSTODY), -825)
	var other: Dictionary = PayoutCalculator.compute(r, _diff(1.0, 1.0, 0), _tweak(), false, 0)
	assert_eq(_xp(other, PayoutCalculator.XP_CUSTODY), 0)


func test_split_sums_to_total() -> void:
	for mult: float in [1.0, 2.0, 2.6, 4.2, 7.2, 9.2]:
		for civs: int in [0, 1, 3]:
			var r: Dictionary = _result()
			(r["crew"] as Array)[0] = _member(0, false, false, civs)
			var out: Dictionary = PayoutCalculator.compute(r, _diff(mult, 1.0, 3500), _tweak(), false, 0)
			assert_eq(int(out["stash"]) + int(out["spending"]), int(out["total"]), "mult %s civs %d" % [mult, civs])
			assert_eq(int(out["contract"]) + int(out["loot"]) + int(out["small_loot"]), int(out["subtotal"]))


func test_civilian_penalty_comes_out_of_spending() -> void:
	var r: Dictionary = _result()
	(r["crew"] as Array)[0] = _member(0, false, false, 2)
	(r["crew"] as Array)[1] = _member(1, false, false, 1)
	var mine: Dictionary = PayoutCalculator.compute(r, _diff(1.0, 1.0, 4000), _tweak(), false, 0)
	assert_eq(mine["civilian_penalty"], 8000)
	assert_eq(mine["total"], 8775)
	assert_eq(mine["stash"], 13420, "stash is 80% of gross; penalty not taken from it")
	assert_eq(mine["spending"], -4645)
	var crew_wide: Dictionary = PayoutCalculator.compute(r, _diff(1.0, 1.0, 4000), _tweak(), false, -1)
	assert_eq(crew_wide["civilian_penalty"], 12000)


func test_failure_pays_no_cash_and_reduced_xp() -> void:
	var r: Dictionary = _result(false, true)
	(r["crew"] as Array)[0] = _member(0, false, false, 1)
	var out: Dictionary = PayoutCalculator.compute(r, _diff(2.0, 2.0, 1000), _tweak(), false, 0)
	assert_eq(out["contract"], 0)
	assert_eq(out["loot"], 0)
	assert_eq(out["small_loot"], 0)
	assert_eq((out["loot_lines"] as Array).size(), 0)
	assert_near(float(out["crew_alive_mult"]), 1.0)
	assert_eq(out["civilian_penalty"], 1000)
	assert_eq(out["total"], -1000)
	assert_eq(out["stash"], 0)
	assert_eq(out["spending"], -1000)
	assert_eq(_xp(out, PayoutCalculator.XP_BASE), 500)
	assert_eq(_xp(out, PayoutCalculator.XP_DIFFICULTY), 500)
	assert_eq(_xp(out, PayoutCalculator.XP_ADDITIVE), 0)
	assert_eq(_xp(out, PayoutCalculator.XP_STEALTH), 0)
	assert_eq(out["xp_total"], 1000)


func test_body_bags_earn_no_bag_xp() -> void:
	var r: Dictionary = _result()
	(r["loot"] as Array).append({"loot_id": &"loot.body_bag", "value": 0})
	var out: Dictionary = PayoutCalculator.compute(r, _diff(1.0, 1.0, 0), _tweak(), false, 0)
	assert_eq(_xp(out, PayoutCalculator.XP_BASE), 2750)


func test_xp_lines_follow_c6_order() -> void:
	var out: Dictionary = PayoutCalculator.compute(_result(), _diff(1.0, 1.0, 0), _tweak(), true, 0)
	var keys: Array[StringName] = []
	for l: Dictionary in out["xp_lines"] as Array:
		keys.append(l["key"] as StringName)
	assert_eq(keys, PayoutCalculator.XP_ORDER)
	assert_eq(keys, [&"ui.results.xp.base", &"ui.results.xp.pro", &"ui.results.xp.difficulty",
		&"ui.results.xp.custody", &"ui.results.xp.additive", &"ui.results.xp.stealth"] as Array[StringName])
	var sum: int = 0
	for l: Dictionary in out["xp_lines"] as Array:
		sum += int(l["amount"])
	assert_eq(sum, int(out["xp_total"]))


func test_defaults_load_without_args() -> void:
	var out: Dictionary = PayoutCalculator.compute(_result())
	for k: String in ["success", "stealth", "contract", "loot_lines", "loot", "small_loot", "civilian_penalty",
			"subtotal", "crew_alive_mult", "gross", "total", "stash", "spending", "xp_lines", "xp_total",
			"stealth_bonus_consumed", "stealth_bonus_banked"]:
		assert_has(out, k)


func test_xp_mult_joins_additive_line() -> void:
	var plain: Dictionary = PayoutCalculator.compute(_result(), _diff(1.0, 1.0, 4000), _tweak(), false, 0, 1.0)
	var boosted: Dictionary = PayoutCalculator.compute(_result(), _diff(1.0, 1.0, 4000), _tweak(), false, 0, 1.0, 1.45)
	var add_plain: int = _xp(plain, PayoutCalculator.XP_ADDITIVE)
	var before_additive: int = int(plain["xp_total"]) - add_plain
	assert_eq(_xp(boosted, PayoutCalculator.XP_ADDITIVE),
			roundi(float(before_additive) * (float(add_plain) / float(before_additive) + 0.45)),
			"Low Profile +45% XP is additive with the crew-alive bonus (PD2)")
	assert_eq(int(boosted["total"]), int(plain["total"]), "cash unaffected")
