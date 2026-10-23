## B5-02 Notoriety UI: the screen builds (rank, checklist, cost, reward preview), the confirm panel
## warns and confirms (saved), cancel and Esc close it, reward choices, focus navigation, the hub's rank
## badge + Notoriety button through MenuFlow, and the payday's Notoriety XP line.
extends TestCase

const SCREEN_SCENE: PackedScene = preload("res://content/ui/notoriety/notoriety_screen.tscn")
const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const SLOT: int = 0


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func before_each() -> void:
	SaveService.delete_profile(SLOT)
	Notoriety.clear_cache()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _veteran(rank: int = 0) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.notoriety = rank
	p.xp = XpCurve.xp_for_level(100)
	p.level = 100
	p.cash = Notoriety.cost_for(rank + 1)
	return p


func _screen(p: PlayerProfile) -> NotorietyScreen:
	var s: NotorietyScreen = SCREEN_SCENE.instantiate() as NotorietyScreen
	s.profile_slot = SLOT
	s.setup(p)
	add_child(s)
	return s


func test_screen_builds_for_a_new_profile() -> void:
	var s: NotorietyScreen = _screen(PlayerProfile.new_default())
	await wait_frames(1)
	assert_eq(s.rank_label.text, UiText.t(&"ui.notoriety.badge_none"))
	assert_eq(s.next_label.text, UiText.t(&"ui.notoriety.next", {"rank": "I"}))
	assert_eq(s.check_rows.size(), 2, "level + cash rows")
	assert_eq((s.check_rows[Notoriety.REQ_LEVEL] as Label).text, UiText.t(&"ui.notoriety.check.unmet"))
	assert_eq(s.cost_label.text, UiText.t(&"ui.notoriety.cost", {"amount": UiText.money(5000000)}))
	assert_true(s.rank_up_button.disabled, "requirements unmet")
	assert_false(s.request_rank_up())
	assert_false(s.is_confirming())
	var texts: Array[String] = []
	for l: Node in s.reward_list.get_children():
		texts.append((l as Label).text)
	assert_has(texts, UiText.t(&"ui.notoriety.reward_line", {"name": MaskCatalog.part_name(&"mask_colors.crown_ember")}))
	assert_has(texts, UiText.t(&"ui.notoriety.reward_xp", {"pct": 2}))
	assert_eq(s.focus_chain, [s.rank_up_button, s.back_button] as Array[Control])
	s.queue_free()
	await wait_frames(1)


func test_confirm_warns_and_ranks_up() -> void:
	var p: PlayerProfile = _veteran()
	var s: NotorietyScreen = _screen(p)
	await wait_frames(1)
	assert_false(s.rank_up_button.disabled)
	assert_eq((s.check_rows[Notoriety.REQ_CASH] as Label).text, UiText.t(&"ui.notoriety.check.met"))
	assert_eq(s.confirm_rank_up()["ok"], false, "no rank-up without the confirm panel")
	s.rank_up_button.pressed.emit()
	assert_true(s.is_confirming())
	assert_eq(s.confirm_body.text, UiText.t(&"ui.notoriety.confirm_body", {"amount": UiText.money(5000000)}))
	assert_true(s.confirm_body.text.contains("0"), "the warning names the reset")
	assert_eq(s.focus_chain, [s.confirm_button, s.cancel_button] as Array[Control], "focus stays in the dialog")
	assert_true(s.rank_up_button.disabled)
	s.cancel_button.pressed.emit()
	assert_false(s.is_confirming())
	assert_eq(p.notoriety, 0, "cancel changes nothing")
	s.request_rank_up()
	var ranks: Array[int] = []
	s.rank_changed.connect(func(r: int) -> void: ranks.append(r))
	s.confirm_button.pressed.emit()
	assert_eq(p.notoriety, 1)
	assert_eq(p.level, 0)
	assert_eq(ranks, [1] as Array[int])
	assert_eq(s.rank_label.text, UiText.t(&"ui.notoriety.badge", {"rank": "I"}))
	assert_eq(s.result_label.text, UiText.t(&"ui.notoriety.done", {"rank": "I"}))
	var saved: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(saved.notoriety, 1, "saved")
	assert_eq(saved.cash, 0)
	assert_has(saved.owned_mask_parts, &"mask_colors.crown_ember")
	s.queue_free()
	await wait_frames(1)


func test_escape_cancels_the_confirm_first() -> void:
	var s: NotorietyScreen = _screen(_veteran())
	await wait_frames(1)
	var backs: Array[int] = [0]
	s.back_requested.connect(func() -> void: backs[0] += 1)
	s.request_rank_up()
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	s._unhandled_input(ev)
	assert_false(s.is_confirming(), "Esc closes the confirm")
	assert_eq(backs[0], 0, "and does not leave the screen")
	s._unhandled_input(ev)
	assert_eq(backs[0], 1, "a second Esc leaves")
	s.queue_free()
	await wait_frames(1)


func test_reward_choice_buttons() -> void:
	var p: PlayerProfile = _veteran(4)
	var s: NotorietyScreen = _screen(p)
	await wait_frames(1)
	s.request_rank_up()
	s.confirm_rank_up()
	await wait_frames(1)  # the deferred focus lands before the pick, as with a real player
	assert_eq(p.notoriety, 5)
	assert_eq(s.choice_buttons.size(), 3)
	var first: StringName = s.choice_buttons.keys()[0] as StringName
	assert_eq(s.focus_chain[0], s.choice_buttons[first] as Control, "choices come first in focus")
	(s.choice_buttons[first] as Button).pressed.emit()
	assert_eq(p.notoriety_choices[5], first)
	assert_eq(s.choice_buttons.size(), 0, "no pending choice left")
	assert_eq(SaveService.load_profile(SLOT).notoriety_choices[5], first, "saved")
	s.queue_free()
	await wait_frames(1)


func test_screen_at_the_cap() -> void:
	var p: PlayerProfile = _veteran(25)
	p.cash = 999999999
	var s: NotorietyScreen = _screen(p)
	await wait_frames(1)
	assert_eq(s.next_label.text, UiText.t(&"ui.notoriety.max_reached"))
	assert_eq(s.check_rows.keys(), [Notoriety.REQ_CAP])
	assert_true(s.rank_up_button.disabled)
	assert_false(s.cost_label.visible)
	assert_eq(s.bonus_label.text, UiText.t(&"ui.notoriety.xp_bonus_max", {"pct": 30}))
	s.queue_free()
	await wait_frames(1)


func test_badge_texts() -> void:
	assert_eq(NotorietyScreen.level_text(73, 0), UiText.t(&"ui.menu.level", {"level": 73}))
	assert_eq(NotorietyScreen.level_text(100, 12), UiText.t(&"ui.notoriety.level_badge", {"rank": "XII", "level": 100}))
	assert_true(NotorietyScreen.level_text(100, 12).contains("XII"))
	assert_eq(NotorietyScreen.badge_text(3), UiText.t(&"ui.notoriety.badge", {"rank": "III"}))


func test_hub_badge_and_notoriety_screen_round_trip() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.notoriety = 7
	SaveService.save_profile(p, SLOT)
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.show_hub()
	await wait_frames(1)
	assert_eq(f.hub.notoriety_label.text, UiText.t(&"ui.notoriety.badge", {"rank": "VII"}))
	assert_true(f.hub.level_label.text.contains("VII"), "rank badge next to the level")
	assert_has(f.hub.focus_chain, f.hub.station_button(&"notoriety") as Control)
	f.hub.station_button(&"notoriety").pressed.emit()
	await wait_frames(1)
	assert_true(f.current is NotorietyScreen)
	assert_eq((f.current as NotorietyScreen).profile.notoriety, 7)
	(f.current as NotorietyScreen).back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control)
	f.queue_free()
	await wait_frames(1)


func test_payday_lists_the_notoriety_line() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.notoriety = 10
	SaveService.save_profile(p, SLOT)
	var pd: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	pd.cards_enabled = false
	pd.apply_to_profile = false
	pd.setup(p)
	add_child(pd)
	await wait_frames(1)
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	pd.show_result(r)
	var key: StringName = StringName("xp." + String(PayoutCalculator.XP_NOTORIETY))
	assert_true(pd.value_labels.has(key), "own XP line on the payday")
	var amount: int = 0
	for l: Dictionary in pd.payout["xp_lines"] as Array:
		if l["key"] == PayoutCalculator.XP_NOTORIETY:
			amount = int(l["amount"])
	assert_true(amount > 0)
	assert_eq((pd.value_labels[key] as Label).text, UiText.group_digits(amount))
	pd.queue_free()
	await wait_frames(1)
