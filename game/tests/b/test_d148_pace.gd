## LEAD r263 regression (D-148, XP option D): every shipped heist's first clear lands on progression_pace.md's
## table, and no level-locked unlock is out of reach. The typical clear is the pace tool's
## (tests/b/tools/progression_pace_worker.gd): the heist's required bags, stealth where the mode allows it (DB is
## loud only), a crew of 4 alive, a fresh profile, freshness as PaydayScreen applies it. XP does not read cash, so the
## bags carry a flat value.
extends TestCase

const BAGS: Dictionary = {&"glasshouse": 2, &"night_deposit": 4, &"shadow_ledger": 2, &"dockside_burn": 4,
	&"gallery_night": 2, &"ostrander_federal": 6}
const STEALTH: Dictionary = {&"dockside_burn": false}
## progression_pace.md "D-148 applied", first clear on a fresh profile, Routine ... Cataclysm.
const FIRST_CLEAR_LEVEL: Dictionary = {
	&"glasshouse": [2, 5, 12, 17, 18, 19],
	&"night_deposit": [4, 8, 15, 20, 21, 22],
	&"shadow_ledger": [4, 8, 15, 20, 21, 22],
	&"dockside_burn": [4, 8, 15, 20, 21, 22],
	&"gallery_night": [4, 8, 15, 20, 21, 22],
	&"ostrander_federal": [6, 11, 18, 23, 24, 25],
}


func test_every_heist_first_clear_matches_the_pace_table() -> void:
	assert_eq(BAGS.size(), HeistCatalog.ids().size(), "every offered heist is pinned: %s" % [HeistCatalog.ids()])
	for h: StringName in HeistCatalog.ids():
		assert_true(FIRST_CLEAR_LEVEL.has(h), "%s pinned" % h)
		if not FIRST_CLEAR_LEVEL.has(h):
			continue
		for d: int in range(6):
			var p: PlayerProfile = PlayerProfile.new_default()
			var fresh: Dictionary = HeistFreshness.evaluate(p, h)
			var payout: Dictionary = PayoutCalculator.compute(_result(h, d), null, null, false, 0, p.banked_stealth_mult,
					1.0, 0.0, float(fresh.get("mult", 1.0)))
			SaveService.apply_heist_payout(p, payout, XpCurve.level_for_xp)
			assert_eq(p.level, int(FIRST_CLEAR_LEVEL[h][d]), "%s d%d: %d XP -> L%d" % [h, d, int(payout["xp_total"]),
					p.level])


## Every level gate sits inside the curve (0 .. max_level) with a finite XP cost, so nothing is out of reach: weapon
## and armor unlock_level, the Board's per-difficulty gates, Notoriety's required level.
func test_no_level_gate_is_out_of_reach() -> void:
	var top: int = XpCurve.max_level()
	assert_eq(top, 100, "D-148 keeps 100 levels")
	var gates: Dictionary = {}
	for w: Resource in ContentDB.all_weapons():
		gates["weapon %s" % w.get("id")] = int(w.get("unlock_level"))
	for a: Resource in ContentDB.all_armors():
		gates["armor %s" % a.get("id")] = int(a.get("unlock_level"))
	var board: Array = BoardTweak.load_default().difficulty_min_level
	for d: int in range(board.size()):
		gates["board d%d" % d] = int(board[d])
	gates["notoriety"] = int((load("res://content/data/tweak/notoriety.tres") as Resource).get("required_level"))
	assert_true(gates.size() >= 40, "gates found: %d" % gates.size())
	var total: int = XpCurve.xp_for_level(top)
	assert_true(total > 0 and total < 30000000, "XP to L%d is finite and PD2-sized: %d" % [top, total])
	for g: String in gates:
		var lv: int = int(gates[g])
		assert_true(lv >= 0 and lv <= top, "%s: level %d inside 0..%d" % [g, lv, top])
		assert_true(XpCurve.xp_for_level(lv) <= total, "%s: L%d costs %d XP" % [g, lv, XpCurve.xp_for_level(lv)])
		assert_eq(XpCurve.level_for_xp(XpCurve.xp_for_level(lv)), lv, "%s: L%d is reached at its XP" % [g, lv])


## The item gates (<= 45) sit inside a new player's first rotations: Routine, Tense, Hazardous, then Brutal clears
## (pace doc: L45 after ~32 clears). Lethal+ opens from the Board's level 70 (D-151; ~135 clears, test below).
func test_item_gates_open_inside_the_early_rotations() -> void:
	var item_max: int = 0
	for w: Resource in ContentDB.all_weapons():
		item_max = maxi(item_max, int(w.get("unlock_level")))
	for a: Resource in ContentDB.all_armors():
		item_max = maxi(item_max, int(a.get("unlock_level")))
	var p: PlayerProfile = PlayerProfile.new_default()
	var clears: int = 0
	for d: int in [0, 1, 2]:
		for h: StringName in HeistCatalog.ids():
			_clear(p, h, d)
			clears += 1
	while p.level < item_max and clears < 200:
		for h: StringName in HeistCatalog.ids():
			_clear(p, h, Enums.Difficulty.BRUTAL)
			clears += 1
	assert_true(p.level >= item_max, "L%d reached (item gates up to L%d)" % [p.level, item_max])
	assert_true(clears <= 40, "every item unlock inside %d clears (pace doc ~32)" % clears)


func _clear(p: PlayerProfile, h: StringName, d: int) -> void:
	var fresh: Dictionary = HeistFreshness.evaluate(p, h)
	var payout: Dictionary = PayoutCalculator.compute(_result(h, d), null, null, false, 0, p.banked_stealth_mult, 1.0,
			0.0, float(fresh.get("mult", 1.0)))
	SaveService.apply_heist_payout(p, payout, XpCurve.level_for_xp)
	HeistFreshness.record(p, h, true)


func _result(h: StringName, d: int) -> Dictionary:
	var loot: Array = []
	for i: int in range(int(BAGS.get(h, 2))):
		loot.append({"loot_id": &"loot.cash_bricks", "value": 1000})
	var crew: Array = []
	for slot: int in range(4):
		crew.append({"slot": slot, "is_ai": slot > 0, "kills": 0, "downs": 0, "civilians_killed": 0, "in_custody": false})
	return {"heist_id": h, "success": true, "stealth": bool(STEALTH.get(h, true)), "time_s": 900.0, "difficulty": d,
		"contract_pay": 0, "loot": loot, "small_loot": 0, "crew": crew, "pagers_answered": 0}


## D-151: the Board's Lethal / Cataclysm gate is level 70, reached on the realistic path (one rotation each on
## Routine, Tense and Hazardous, then Brutal) in about the clears the old pace took to level 80 (pace doc: 135 vs
## 131 pre-D-148; 230 at 80 under D-148).
func test_d151_lethal_gate_is_70_and_keeps_the_old_time_to_lethal() -> void:
	var board: Array = BoardTweak.load_default().difficulty_min_level
	assert_eq(int(board[Enums.Difficulty.LETHAL]), 70, "D-151 Lethal gate")
	assert_eq(int(board[Enums.Difficulty.CATACLYSM]), 70, "D-151 Cataclysm gate")
	var p: PlayerProfile = PlayerProfile.new_default()
	var clears: int = 0
	for d: int in [0, 1, 2]:
		for h: StringName in HeistCatalog.ids():
			_clear(p, h, d)
			clears += 1
	while p.level < 70 and clears < 400:
		for h: StringName in HeistCatalog.ids():
			_clear(p, h, Enums.Difficulty.BRUTAL)
			clears += 1
	assert_true(p.level >= 70, "L70 reached")
	assert_true(clears >= 110 and clears <= 160, "L70 in %d clears (pace doc ~135; the old pace took 131 to L80)" % clears)
