## B7-01 career stats: accumulation from HeistResults (success / fail, stealth / loud), counters the
## HeistResult does not carry stay uncounted (D-071), spending hooks, the payday path, the career screen
## and the hub's Career button. Save v7 migration / sanitizing: test_save_golden.gd.
extends TestCase

const SCREEN_SCENE: PackedScene = preload("res://content/ui/career/career_screen.tscn")
const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const SLOT: int = 0


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C\'s 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func before_each() -> void:
	SaveService.delete_profile(SLOT)


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_new_profile_has_an_empty_career() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(p.career, Career.empty())
	assert_eq(Career.total(p, Career.PLAYED), -1, "never counted")
	assert_eq(Career.accuracy(p), -1.0)
	assert_eq(Career.favourite_weapon(p), &"")
	assert_eq(p.weapon_finishes, {})


func test_success_stealth_accumulates() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var r: Dictionary = _result(&"glasshouse", true, true, 2, 600.4)
	Career.record(p, r, {"success": true, "spending": 2000, "stash": 8000, "xp_total": 5000, "small_loot": 900}, 0)
	assert_eq(Career.total(p, Career.PLAYED), 1)
	assert_eq(Career.total(p, Career.WON), 1)
	assert_eq(Career.total(p, Career.FAILED), -1, "no failure yet")
	assert_eq(Career.total(p, Career.STEALTH_WINS), 1)
	assert_eq(Career.total(p, Career.LOUD_WINS), -1)
	assert_eq(Career.total(p, Career.SPENDING_EARNED), 2000)
	assert_eq(Career.total(p, Career.STASH_EARNED), 8000)
	assert_eq(Career.total(p, Career.XP_EARNED), 5000)
	assert_eq(Career.total(p, Career.SMALL_LOOT), 900)
	assert_eq(Career.total(p, Career.BAGS), 3)
	assert_eq(Career.section(p, "bags"), {"loot.jewelry": 2, "loot.cash": 1})
	assert_eq(Career.total(p, Career.TIME_PLAYED_S), 600)
	assert_eq(Career.total(p, "kills"), 3, "the local slot's row only")
	assert_eq(Career.total(p, "civilians_killed"), 1)
	assert_eq(Career.total(p, Career.CUSTODY), -1)
	var h: Dictionary = Career.heist(p, &"glasshouse")
	assert_eq(h, {"played": 1, "won": 1, "stealth_wins": 1, "won_d2": 1, "fastest_win_ms": 600400})
	assert_eq(Career.best_difficulty(p, &"glasshouse"), 2)
	assert_near(Career.fastest_win_s(p, &"glasshouse"), 600.4, 0.001)
	assert_eq(Career.section(p, "difficulties"), {"2": {"played": 1, "won": 1}})
	assert_eq(Career.favourite_weapon(p), &"weapon.corsair_ar", "the loadout's primary (QB-1 starter)")


func test_loud_fail_and_best_and_fastest() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	Career.record(p, _result(&"glasshouse", true, false, 4, 900.0), {"success": true}, 0)
	Career.record(p, _result(&"glasshouse", true, false, 1, 500.0), {"success": true}, 0)
	var fail: Dictionary = _result(&"glasshouse", false, false, 5, 200.0)
	(fail["crew"] as Array)[0]["in_custody"] = true
	Career.record(p, fail, {"success": false}, 0)
	assert_eq(Career.total(p, Career.PLAYED), 3)
	assert_eq(Career.total(p, Career.WON), 2)
	assert_eq(Career.total(p, Career.FAILED), 1)
	assert_eq(Career.total(p, Career.LOUD_WINS), 2)
	assert_eq(Career.total(p, Career.CUSTODY), 1)
	assert_eq(Career.total(p, Career.BAGS), 6, "a failed heist secures no bags")
	assert_eq(Career.best_difficulty(p, &"glasshouse"), 4, "a Cataclysm failure is not a best")
	assert_near(Career.fastest_win_s(p, &"glasshouse"), 500.0, 0.001, "a fast failure is not a record")
	assert_eq(Career.total(p, Career.TIME_PLAYED_S), 1600, "failures count as time on the job")
	assert_eq(int((Career.section(p, "difficulties")["5"] as Dictionary)["failed"]), 1)
	var ids: Array[StringName] = [&"glasshouse", &"night_deposit"]
	assert_eq(Career.heists_won(p, ids), 1)
	assert_eq(Career.heists_won(p, ids, Enums.Difficulty.LETHAL), 1)
	assert_eq(Career.heists_won(p, ids, Enums.Difficulty.CATACLYSM), 0)
	assert_eq(Career.heists_won(p, ids, 0, true), 0, "no stealth win")
	assert_eq(Career.heists_won(p, ids, 0, false, true), 1)


func test_missing_counters_stay_uncounted() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	Career.record(p, _result(&"glasshouse", true, false, 0, 60.0), {"success": true}, 0)
	for k: String in ["shots", "hits", "headshots"]:
		assert_eq(Career.total(p, k), -1, "%s missing from the v1.0 row -> not counted" % k)
	assert_eq(Career.accuracy(p), -1.0, "no accuracy without shots")
	assert_eq(CareerScreen.value_text(p, "shots"), UiText.t(&"ui.career.not_tracked"))
	var r: Dictionary = _result(&"glasshouse", true, false, 0, 60.0)
	var row: Dictionary = (r["crew"] as Array)[0]
	row["shots"] = 40
	row["hits"] = 10
	row["headshots"] = 3
	Career.record(p, r, {"success": true}, 0)
	assert_eq(Career.total(p, "shots"), 40)
	assert_eq(Career.total(p, "headshots"), 3)
	assert_near(Career.accuracy(p), 0.25, 0.0001)
	assert_eq(CareerScreen.value_text(p, "accuracy"), UiText.t(&"ui.career.percent", {"value": "25.0"}))
	var q: PlayerProfile = PlayerProfile.new_default()
	Career.record(q, {"heist_id": &"glasshouse", "success": true}, {"success": true}, 3)
	assert_eq(Career.total(q, "kills"), -1, "no crew row for the slot -> no combat counters")
	assert_eq(Career.total(q, Career.TIME_PLAYED_S), -1, "no time_s -> no time")
	assert_eq(Career.total(q, Career.SPENDING_EARNED), -1, "no payout line -> not counted")
	assert_eq(Career.total(q, Career.PLAYED), 1)


func test_spending_hooks() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	Career.add_spent(p, 5000)
	Career.add_spent(p, -2000)
	assert_eq(Career.total(p, Career.CASH_SPENT), 3000, "a refund subtracts")
	Career.add_spent(p, -9000)
	assert_eq(Career.total(p, Career.CASH_SPENT), 0, "never below 0")
	Career.add_spent(p, 700, true)
	assert_eq(Career.total(p, Career.OFFSHORE_SPENT), 700)
	p.level = 100
	var m: WorkshopModel = WorkshopModel.new(p)
	var w: WeaponDef = _for_sale_weapon(m)
	assert_true(w != null, "a weapon is for sale at level 100")
	if w != null:
		p.cash = w.price
		assert_true(m.buy_weapon(w.id))
		assert_eq(Career.total(p, Career.CASH_SPENT), w.price, "workshop buy counted")


func test_payday_records_the_career() -> void:
	var pd: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	pd.cards_enabled = false
	add_child(pd)
	await wait_frames(1)
	var r: Dictionary = HeistCatalog.sample_result()
	pd.show_result(r)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(Career.total(q, Career.PLAYED), 1, "saved by the payday")
	assert_eq(Career.total(q, Career.STEALTH_WINS), 1)
	assert_eq(Career.total(q, Career.STASH_EARNED), int(pd.payout["stash"]))
	assert_eq(Career.total(q, Career.BAGS), 3)
	pd.queue_free()
	await wait_frames(1)


func test_screen_builds() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.notoriety = 2
	Career.record(p, _result(&"glasshouse", true, true, 2, 600.0), {"success": true, "stash": 1234}, 0)
	Career.record(p, _result(&"lost_heist", false, false, 0, 30.0), {"success": false}, 0)
	var s: CareerScreen = SCREEN_SCENE.instantiate() as CareerScreen
	s.setup(p)
	add_child(s)
	await wait_frames(1)
	assert_eq((s.value_labels["played"] as Label).text, "2")
	assert_eq((s.value_labels["stash_earned"] as Label).text, UiText.money(1234))
	assert_eq((s.value_labels["win_rate"] as Label).text, UiText.t(&"ui.career.percent", {"value": "50.0"}))
	assert_eq((s.value_labels["shots"] as Label).text, UiText.t(&"ui.career.not_tracked"))
	assert_false((s.value_labels["accuracy"] as Label).get_parent().visible, "accuracy hidden without shots")
	assert_eq(s.badge_label.text, NotorietyScreen.badge_text(2))
	for id: StringName in HeistCatalog.ids():
		assert_true(s.heist_rows.has(id), "row for offered heist %s" % id)
	assert_true(s.heist_rows.has(&"lost_heist"), "a heist on the record is listed too")
	var cells: Array[String] = CareerScreen.heist_cells(p, &"glasshouse")
	assert_eq(cells.size(), CareerScreen.COLUMNS.size())
	assert_eq(cells[6], UiText.t(&"ui.difficulty.hazardous"), "best difficulty")
	assert_eq(cells[7], UiText.clock(600.0), "fastest win")
	assert_false(s.empty_label.visible)
	assert_eq(s.focus_chain.back(), s.back_button as Control, "Back closes the focus chain")
	assert_eq(s.focus_chain.size(), 3 + s.heist_rows.size() + s.recent_rows.size() + 1, "panels + heist rows + recent rows + Back")
	var strings: Dictionary = StringTable.parse_csv()
	for k: String in CareerScreen.RECORD_KEYS + CareerScreen.MONEY_KEYS + CareerScreen.COMBAT_KEYS:
		assert_has(strings, "ui.career." + k)
	for c: String in CareerScreen.COLUMNS:
		assert_has(strings, "ui.career.col." + c)
	s.queue_free()
	await wait_frames(1)


func test_hub_opens_career_and_back_returns() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.show_hub()
	await wait_frames(1)
	assert_has(f.hub.focus_chain, f.hub.station_button(&"profile") as Control)
	f.hub.station_button(&"profile").pressed.emit()
	await wait_frames(1)
	assert_true(f.current is CareerScreen)
	(f.current as CareerScreen).back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control)
	f.queue_free()
	await wait_frames(1)


func _for_sale_weapon(m: WorkshopModel) -> WeaponDef:
	for w: Variant in ContentDB.all_weapons():
		var wd: WeaponDef = w as WeaponDef
		if m.weapon_state(wd.id) == WorkshopModel.ItemState.FOR_SALE and wd.price > 0:
			return wd
	return null


## A HeistResult (contracts/events.md v1.0 crew row: no shots / hits / headshots).
func _result(heist: StringName, success: bool, stealth: bool, difficulty: int, time_s: float) -> Dictionary:
	return {
		"heist_id": heist, "success": success, "stealth": stealth, "difficulty": difficulty, "time_s": time_s,
		"loot": [{"loot_id": &"loot.jewelry", "value": 1}, {"loot_id": &"loot.jewelry", "value": 1}, {"loot_id": &"loot.cash", "value": 1}],
		"small_loot": 100,
		"crew": [
			{"slot": 0, "is_ai": false, "kills": 3, "specials_killed": 1, "downs": 0, "civilians_killed": 1, "in_custody": false},
			{"slot": 1, "is_ai": true, "kills": 9, "specials_killed": 2, "downs": 1, "civilians_killed": 0, "in_custody": false},
		],
	}


## Payday cards: a granted cash / XP card counts into card_cash / card_xp and cards_taken; the screen lists both.
func test_payday_cards_recorded() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(Career.total(p, Career.CARD_CASH), -1, "never counted")
	Career.record_card(p, {"type": PaydayCards.CASH, "amount": 12000})
	Career.record_card(p, {"type": PaydayCards.XP, "amount": 3500})
	Career.record_card(p, {"type": PaydayCards.WEAPON_MOD, "item_id": &"mod.x"})
	assert_eq(Career.total(p, Career.CARD_CASH), 12000)
	assert_eq(Career.total(p, Career.CARD_XP), 3500)
	assert_eq(Career.total(p, Career.CARDS_TAKEN), 3)
	assert_has(CareerScreen.MONEY_KEYS, "card_cash")
	assert_eq(CareerScreen.value_text(p, "card_cash"), UiText.money(12000))
	Career.record_card(null, {"type": PaydayCards.CASH, "amount": 1})


## D-139: the Recent heists panel lists the freshness memory oldest first and each heist's freshness, times in the
## memory and runs since; its rows are in the focus chain (pad / keyboard scroll).
func test_recent_heists_panel() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(CareerScreen.recent_entries(p), [] as Array[String])
	HeistFreshness.record(p, &"gallery_night", true)
	for i: int in range(12):
		HeistFreshness.record(p, &"night_deposit", true)
	HeistFreshness.record(p, &"glasshouse", true)
	HeistFreshness.record(p, &"glasshouse", false)
	var entries: Array[String] = CareerScreen.recent_entries(p)
	assert_eq(entries.size(), 10)
	assert_eq(entries[0], "1. " + UiText.t(&"heist.night_deposit.name"))
	assert_eq(entries[9], "10. " + UiText.t(&"heist.glasshouse.name"))
	assert_eq(CareerScreen.recent_cells(p, &"glasshouse"), ["Golden Hour", "-20 %", "2", "0"] as Array[String])
	assert_eq(CareerScreen.recent_cells(p, &"gallery_night")[1], "+4 %", "15 jobs since, k = 4")
	assert_eq(CareerScreen.recent_cells(p, &"gallery_night")[3], "14")
	assert_eq(CareerScreen.recent_cells(p, &"shadow_ledger")[1], "0 %")
	assert_eq(CareerScreen.recent_cells(p, &"shadow_ledger")[3], "Never")
	var s: CareerScreen = SCREEN_SCENE.instantiate() as CareerScreen
	s.setup(p)
	add_child(s)
	await wait_frames(2)
	assert_eq(s.recent_flow.get_child_count(), 10)
	assert_false(s.recent_empty_label.visible)
	assert_true(s.recent_rows.has(&"glasshouse"))
	assert_true(s.focus_chain.has(s.recent_rows[&"glasshouse"] as Control), "recent rows are focusable")
	assert_eq(s.focus_chain.back(), s.back_button)
	# Colour-blind safety (lead r242): a drawn triangle and the sign carry the direction, not the colour alone.
	for id: StringName in [&"glasshouse", &"gallery_night", &"shadow_ledger"]:
		var mark: TrendMark = (s.recent_rows[id] as Node).find_child("Trend", true, false) as TrendMark
		var text: String = CareerScreen.recent_cells(p, id)[1]
		var pct: int = HeistFreshness.percent(float(HeistFreshness.evaluate(p, id)["mult"]))
		assert_eq(mark.direction, signi(pct), "%s: the triangle follows the sign" % id)
		if pct != 0:
			assert_true(text.begins_with("+") or text.begins_with("-"), "%s: signed text %s" % [id, text])
	s.queue_free()
	await wait_frames(1)
