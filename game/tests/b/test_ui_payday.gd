## B1-04: payday screen totals equal PayoutCalculator output, XP lines in C6 order, the payout is
## applied to the profile (SaveService) exactly once, and D-022's banked stealth bonus is used.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")

var _screen: PaydayScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	_screen = PAYDAY_SCENE.instantiate() as PaydayScreen
	add_child(_screen)
	await wait_frames(1)


func after_each() -> void:
	_screen.queue_free()
	await wait_frames(1)


func test_routine_totals_match_calculator() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	assert_eq(int(result["difficulty"]), Enums.Difficulty.ROUTINE)
	var expected: Dictionary = PayoutCalculator.compute(result, null, null, false, Net.local_slot(), 1.0)
	_screen.show_result(result)
	assert_eq(_screen.payout, expected, "screen uses PayoutCalculator output as-is")
	for key: String in ["contract", "small_loot", "total", "stash", "spending"]:
		assert_eq((_screen.value_labels[StringName(key)] as Label).text, UiText.money(int(expected[key])), key)
	assert_eq((_screen.value_labels[&"civilian_penalty"] as Label).text, UiText.money(-int(expected["civilian_penalty"])))
	assert_eq((_screen.value_labels[&"xp_total"] as Label).text, UiText.group_digits(int(expected["xp_total"])))
	for line: Dictionary in expected["xp_lines"] as Array:
		assert_has(_screen.value_labels, StringName("xp." + String(line["key"])))


func test_payout_applied_to_profile_once() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	_screen.show_result(result)
	var p: PlayerProfile = SaveService.load_profile(0)
	assert_eq(p.stash, int(_screen.payout["stash"]))
	assert_eq(p.cash, int(_screen.payout["spending"]))
	assert_eq(p.xp, int(_screen.payout["xp_total"]))
	assert_eq(p.level, XpCurve.level_for_xp(p.xp))
	assert_eq(int(p.stats.get("heists_completed", 0)), 1)
	assert_true(p.banked_stealth_mult > 1.0, "stealth success banks the bonus (D-022)")


func test_banked_bonus_used_on_next_payday() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.banked_stealth_mult = 1.2
	_screen.apply_to_profile = false
	_screen.setup(p)
	var result: Dictionary = HeistCatalog.sample_result()
	_screen.show_result(result)
	var expected: Dictionary = PayoutCalculator.compute(result, null, null, false, Net.local_slot(), 1.2)
	assert_eq(_screen.payout, expected)
	assert_eq(_screen.xp_after, p.xp + int(expected["xp_total"]))
	assert_false(FileAccess.file_exists(SaveService.profile_path(0)), "apply_to_profile=false writes nothing")


func test_shows_on_heist_ended_when_listening() -> void:
	_screen.queue_free()
	_screen = PAYDAY_SCENE.instantiate() as PaydayScreen
	_screen.listen_heist_ended = true
	_screen.apply_to_profile = false
	_screen.visible = false
	add_child(_screen)
	await wait_frames(1)
	EventBus.heist_ended.emit(HeistCatalog.sample_result())
	assert_true(_screen.visible)
	assert_false(_screen.payout.is_empty())


# --- B4-05: payday card pick (P9) ---


func test_card_pick_flow_pick_reveal_continue() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	_screen.show_result(result)
	assert_true(_screen.has_card_pick(), "successful heist offers a card pick")
	var expected: Dictionary = PaydayCards.roll(int(result["seed"]), Net.local_slot(), int(result["difficulty"]),
			_screen.profile, PaydayCards.quality_add_for(_screen.profile))
	assert_eq(_screen.card_roll, expected, "cards rolled from the run seed + local slot")
	var emitted: Array[bool] = [false]
	_screen.continue_pressed.connect(func() -> void: emitted[0] = true)
	_screen.continue_button.pressed.emit()
	assert_false(emitted[0], "Continue on the summary opens the cards")
	assert_true(_screen.cards_stage)
	assert_eq(_screen.card_views.size(), 3)
	assert_true(_screen.continue_button.disabled, "no Continue before a pick")
	for v: PaydayCardView in _screen.card_views:
		assert_false(v.face_up, "cards start face down")
	_screen.continue_button.pressed.emit()
	assert_false(emitted[0])
	var before: PlayerProfile = SaveService.load_profile(0)
	_screen.tick(PaydayScreen.INPUT_GRACE_S + 0.01)  # PQ-B-5 input grace
	_screen.card_views[1].pressed.emit()  # mouse click / ui_accept on the second card
	assert_eq(_screen.picked_index, 1)
	assert_false(_screen.auto_picked)
	for v: PaydayCardView in _screen.card_views:
		assert_true(v.face_up, "all three revealed")
	assert_true(_screen.card_views[1].picked)
	assert_false(_screen.continue_button.disabled)
	_assert_granted(before, SaveService.load_profile(0), expected["cards"][1] as Dictionary)
	_screen.card_views[0].pressed.emit()
	assert_eq(_screen.picked_index, 1, "only one pick")
	_screen.continue_button.pressed.emit()
	assert_true(emitted[0], "Continue after the reveal leaves the payday")


func test_card_auto_pick_after_timeout() -> void:
	_screen.show_result(HeistCatalog.sample_result())
	_screen.show_cards()
	var t: float = PaydayCards.table().pick_time_s
	_screen.tick(t - 0.5)
	assert_eq(_screen.picked_index, -1, "still waiting before the timer runs out")
	assert_false(_screen.timer_label.text.is_empty())
	var before: PlayerProfile = SaveService.load_profile(0)
	_screen.tick(1.0)
	var auto: int = int(_screen.card_roll["auto_pick"])
	assert_eq(_screen.picked_index, auto, "timer picks the rolled auto_pick card")
	assert_true(_screen.auto_picked)
	_assert_granted(before, SaveService.load_profile(0), (_screen.card_roll["cards"] as Array)[auto] as Dictionary)
	assert_false(_screen.continue_button.disabled)


## QB-PC1 (D-049): leaving with an unpicked card auto-picks the timeout's card (same deterministic roll).
func test_leaving_auto_picks_like_the_timeout() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	_screen.show_result(result)
	var auto: int = int(_screen.card_roll["auto_pick"])
	var card: Dictionary = (_screen.card_roll["cards"] as Array)[auto] as Dictionary
	var before: PlayerProfile = SaveService.load_profile(0)
	remove_child(_screen)  # leaving the screen (summary stage, cards never opened)
	assert_eq(_screen.picked_index, auto, "tree exit picks auto_pick")
	assert_true(_screen.auto_picked)
	_assert_granted(before, SaveService.load_profile(0), card)
	add_child(_screen)
	await wait_frames(1)
	assert_false(_screen.finish_card_pick(), "nothing left to pick")
	# App quit (WM close request) on the card stage.
	SaveService.delete_profile(0)
	_screen.show_result(result)
	_screen.show_cards()
	auto = int(_screen.card_roll["auto_pick"])
	card = (_screen.card_roll["cards"] as Array)[auto] as Dictionary
	before = SaveService.load_profile(0)
	_screen.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_screen.picked_index, auto, "app quit picks auto_pick")
	_assert_granted(before, SaveService.load_profile(0), card)


func test_no_card_pick_on_failure_or_preview() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	result["success"] = false
	_screen.show_result(result)
	assert_false(_screen.has_card_pick(), "failed heists get no card (PD2)")
	var emitted: Array[bool] = [false]
	_screen.continue_pressed.connect(func() -> void: emitted[0] = true)
	_screen.continue_button.pressed.emit()
	assert_true(emitted[0])
	_screen.apply_to_profile = false
	_screen.show_result(HeistCatalog.sample_result())
	assert_false(_screen.has_card_pick(), "previews (apply_to_profile=false) never grant cards")


func _assert_granted(before: PlayerProfile, after: PlayerProfile, card: Dictionary) -> void:
	match StringName(card["type"]):
		PaydayCards.CASH:
			assert_eq(after.cash, before.cash + int(card["amount"]), "cash card saved")
		PaydayCards.XP:
			assert_eq(after.xp, before.xp + int(card["amount"]), "xp card saved")
			assert_eq(after.level, XpCurve.level_for_xp(after.xp))
		PaydayCards.WEAPON_MOD:
			assert_false(before.owned_mods.has(card["item_id"]))
			assert_has(after.owned_mods, card["item_id"], "mod card saved")
		PaydayCards.MASK_PART:
			assert_false(before.owned_mask_parts.has(card["item_id"]))
			assert_has(after.owned_mask_parts, card["item_id"], "mask part card saved")


## Lead round 62: each column's best crew value (kills / specials, > 0, ties shared) is marked.
func test_crew_best_values_highlighted() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	result["crew"] = [
		{"slot": 0, "is_ai": false, "kills": 7, "specials_killed": 1, "downs": 0, "civilians_killed": 0},
		{"slot": 1, "is_ai": true, "kills": 7, "specials_killed": 0, "downs": 2, "civilians_killed": 0},
		{"slot": 2, "is_ai": true, "kills": 3, "specials_killed": 0, "downs": 0, "civilians_killed": 0}]
	_screen.show_result(result)
	assert_eq(_screen.crew_best.get("kills", []), [0, 1], "tie shares the top kills")
	assert_eq(_screen.crew_best.get("specials_killed", []), [0])
	assert_false(_screen.crew_best.has("downs"), "downs are not an achievement")


## The XP bar ends on the new progress, level and level-up line (the animation is skipped headless).
func test_xp_bar_final_state() -> void:
	_screen.show_result(HeistCatalog.sample_result())
	_screen.finish_xp()
	assert_near(_screen.level_bar.value, PaydayScreen._level_progress(_screen.xp_after), 0.0001)
	var leveled: bool = XpCurve.level_for_xp(_screen.xp_after) > XpCurve.level_for_xp(_screen.xp_before)
	assert_eq(_screen.level_up_label.visible, leveled)


## Lead failure pass: a failed heist says why (fail_reason) and what was lost, not a table of zeros.
func test_failure_reason_and_loss() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	result["success"] = false
	result["fail_reason"] = &"all_custody"
	_screen.show_result(result)
	assert_eq((_screen.value_labels[&"fail_reason"] as Label).text, UiText.t(&"ui.results.fail.all_custody"))
	assert_true(_screen.value_labels.has(&"lost_total"), "the loss panel replaces the cash table")
	assert_false(_screen.value_labels.has(&"contract"), "no zeroed cash lines")
	var would: Dictionary = PaydayScreen.compute_payout(HeistCatalog.sample_result(), null, Net.local_slot())
	assert_eq((_screen.value_labels[&"lost_total"] as Label).text, UiText.money(int(would["total"])))
	assert_eq(PaydayScreen.fail_reason_key(&""), &"ui.results.fail.abort", "no reason reads as walking away")


## Lane 2 audit: a full crew's stats table is on screen at 720p without scrolling (it was under the fold).
func test_full_crew_table_on_screen_at_720p() -> void:
	var saved: Vector2i = get_window().size
	get_window().size = Vector2i(1280, 720)
	var result: Dictionary = HeistCatalog.sample_result()
	var crew: Array = []
	for slot: int in range(4):
		crew.append({"slot": slot, "is_ai": slot >= 2, "kills": 30 + slot, "specials_killed": slot, "downs": slot,
			"civilians_killed": 1})
	result["crew"] = crew
	_screen.apply_to_profile = false
	_screen.show_result(result)
	await wait_frames(3)
	var vis: Rect2 = get_viewport().get_visible_rect().grow(1.0)
	var labels: Array[Node] = _screen.find_children("*", "Label", true, false)
	var crew_name: String = _screen.call(&"_crew_name", 3, true) as String
	var last: Label = null
	for n: Node in labels:
		if (n as Label).text == crew_name and (n as Label).is_visible_in_tree():
			last = n as Label
	assert_true(last != null, "the last crew row is built")
	if last != null:
		var row: Control = last.get_parent() as Control
		var view: Rect2 = vis
		var n: Node = row.get_parent()
		while n != null:
			if n is ScrollContainer:
				(n as ScrollContainer).scroll_vertical = 0
				view = view.intersection((n as Control).get_global_rect().grow(1.0))
			n = n.get_parent()
		await wait_frames(1)
		assert_true(view.encloses(row.get_global_rect()), "crew table %s inside %s" % [row.get_global_rect(), view])
	assert_true(vis.encloses(_screen.continue_button.get_global_rect()), "Continue on screen")
	get_window().size = saved


## P fresh-eyes #12: "Clean job" only for a stealth win with no civilian killed; a body makes it "Quiet job.
## Not a clean one."; an alarm is "Went loud".
func test_clean_job_line_needs_no_alarm_and_no_civilians() -> void:
	_screen.apply_to_profile = false
	var r: Dictionary = HeistCatalog.sample_result()
	var clean: Dictionary = r.duplicate(true)
	clean["stealth"] = true
	for m: Dictionary in clean.get("crew", []) as Array:
		m["civilians_killed"] = 0
	_screen.show_result(clean)
	assert_eq(_screen.call(&"_summary_key", true), &"ui.results.stealth", "no alarm, no civilians: clean")
	var messy: Dictionary = clean.duplicate(true)
	(messy["crew"] as Array)[0]["civilians_killed"] = 1
	_screen.show_result(messy)
	assert_eq(_screen.call(&"_summary_key", true), &"ui.results.stealth_messy", "a civilian killed: not clean")
	var loud: Dictionary = clean.duplicate(true)
	loud["stealth"] = false
	_screen.show_result(loud)
	assert_eq(_screen.call(&"_summary_key", true), &"ui.results.loud")
