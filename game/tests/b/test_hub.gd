## B4-07: the safehouse hub UI layer (pd2_fidelity C9). The hub lists the stations of
## data/ui/hub_stations.tres; MenuFlow.open_station(id) opens each one (the API ENV C's 3D hub calls)
## and Back returns to the hub; a Board contract carries is_pro into the launch options and payday.
extends TestCase

const HUB_SCENE: PackedScene = preload("res://content/ui/hub/hub_menu.tscn")
const START_CASH: int = 150000
const STATION_IDS: Array[StringName] = [&"board", &"planning", &"armory", &"masks", &"range", &"crew", &"jukebox",
		&"notoriety", &"profile"]


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C\'s 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
	Log.capture = false
	Log.captured.clear()


func before_each() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = START_CASH
	p.stash = 2000000
	p.level = 40
	p.xp = XpCurve.xp_for_level(40) + 10
	SaveService.save_profile(p, 0)


func _flow() -> MenuFlow:
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	return f


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _to_hub(f: MenuFlow) -> void:
	f.main_menu.safehouse_button.pressed.emit()
	await wait_frames(2)


func test_station_data() -> void:
	var list: HubStationList = HubStationList.load_default()
	assert_eq(list.ids(), STATION_IDS, "station order (2D hub) and ids (3D hub API)")
	var table: Dictionary = StringTable.parse_csv()
	for s: HubStation in list.stations:
		assert_has(MenuFlow.TARGETS, s.target, "known target for %s" % s.id)
		assert_has(table, String(s.title_key))
		assert_has(table, String(s.desc_key))
		assert_true(s.icon_kind != &"", "icon kind for %s" % s.id)
	assert_true(list.find(&"nope") == null)
	assert_eq(list.find(&"board").target, MenuFlow.TARGET_BOARD)


func test_hub_instantiates_with_profile_summary() -> void:
	var h: HubMenu = HUB_SCENE.instantiate() as HubMenu
	add_child(h)
	await wait_frames(2)
	assert_eq(h.station_buttons.size(), STATION_IDS.size())
	for id: StringName in STATION_IDS:
		assert_true(h.station_button(id) != null, "card for %s" % id)
	assert_eq(_focused(), h.station_button(&"board") as Control, "first station focused")
	assert_false(h.station_button(&"board").focus_neighbor_bottom.is_empty(), "focus chain set")
	var p: PlayerProfile = SaveService.load_profile(0)
	assert_eq(h.level_label.text, UiText.t(&"ui.menu.level", {"level": 40}))
	assert_true(h.spending_label.text.contains(UiText.group_digits(START_CASH)), h.spending_label.text)
	assert_true(h.stash_label.text.contains(UiText.group_digits(2000000)), h.stash_label.text)
	var free: int = SkillPoints.points_for_level(40) - SkillPoints.spent_total(p.loadout.skills)
	assert_true(h.skill_points_label.text.contains(str(free)), h.skill_points_label.text)
	assert_true(h.xp_bar.value > 0.0 and h.xp_bar.value < 1.0, "xp bar part filled: %s" % h.xp_bar.value)
	var asked: Array[StringName] = []
	h.station_requested.connect(func(id: StringName) -> void: asked.append(id))
	h.station_button(&"masks").pressed.emit()
	assert_eq(asked, [&"masks"] as Array[StringName], "a card asks for its station")
	h.queue_free()
	await wait_frames(1)


## r262 OF payday + hub still: after a first Hazardous OF clear (L18) the Armory card shows skill and perk points;
## "20 SKILL POINTS · 58 PERK POINTS" ran past the card. One count per line, inside the card.
func test_armory_points_stay_inside_the_card() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.xp = 29250
	p.level = XpCurve.level_for_xp(p.xp)
	var h: HubMenu = HUB_SCENE.instantiate() as HubMenu
	add_child(h)
	h.setup(p)
	await wait_frames(3)
	var l: Label = h.skill_points_label
	assert_eq(l.text.split("\n").size(), 2, "skill and perk points, one per line: %s" % l.text)
	var card: Rect2 = h.station_button(&"armory").get_global_rect()
	assert_true(card.encloses(l.get_global_rect()), "points %s inside the card %s" % [l.get_global_rect(), card])
	assert_true(l.get_minimum_size().x <= card.size.x, "points fit the card width")
	h.queue_free()
	await wait_frames(1)


func test_main_menu_to_hub_and_back() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(2)
	await _to_hub(f)
	assert_eq(f.current, f.hub as Control)
	f.hub.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.main_menu as Control, "hub Back -> main menu")
	assert_eq(_focused(), f.main_menu.safehouse_button as Control)
	f.queue_free()
	await wait_frames(1)


func test_every_station_opens_and_back_returns_to_hub() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	await _to_hub(f)
	# Board
	assert_true(f.open_station(&"board"))
	await wait_frames(2)
	assert_true(f.board_screen != null)
	assert_eq(f.current, f.board_screen as Control, "board station")
	assert_eq(f.board_screen.profile, f.profile, "the board edits the flow's profile")
	f.board_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.hub as Control, "board Back -> hub")
	# Planning table
	f.hub.station_button(&"planning").pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.heist_select as Control, "planning station")
	f.heist_select.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.hub as Control, "heist select Back -> hub")
	assert_eq(_focused(), f.hub.station_button(&"board") as Control, "hub focused again")
	# Armory
	assert_true(f.open_station(&"armory"))
	await wait_frames(2)
	var ls: LoadoutScreen = f.loadout_screen
	assert_eq(f.current, ls as Control, "armory station")
	assert_true(ls.hub_mode)
	assert_false(ls.launch_button.visible, "no Launch in the armory")
	assert_false(ls.focus_chain.has(ls.launch_button))
	ls.select_armor(&"armor.patrol_vest")
	ls.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.hub as Control, "armory Back -> hub")
	assert_eq(SaveService.load_profile(0).loadout.armor, &"armor.patrol_vest", "armory saved on Back")
	# Mask bench
	assert_true(f.open_station(&"masks"))
	await wait_frames(2)
	assert_true(f.mask_screen != null)
	assert_eq(f.current, f.mask_screen as Control, "mask bench")
	f.mask_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_true(f.mask_screen == null, "mask screen closed")
	assert_eq(f.current, f.hub as Control, "mask bench Back -> hub")
	# Firing range door
	assert_true(f.open_station(&"range"))
	await wait_frames(3)
	assert_true(f.firing_range != null and f.firing_range.is_inside_tree(), "range entered")
	assert_false(f.visible)
	f.firing_range.exit_requested.emit()
	await wait_frames(2)
	assert_true(f.firing_range == null)
	assert_true(f.visible)
	assert_eq(f.current, f.hub as Control, "range exit -> hub")
	f.queue_free()
	await wait_frames(1)


func test_armory_progression_round_trip() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	await _to_hub(f)
	f.open_station(&"armory")
	await wait_frames(1)
	f.loadout_screen.skills_button.pressed.emit()
	await wait_frames(1)
	assert_true(f.progression_screen is SkillTreeScreen)
	f.progression_screen.back_requested.emit()
	await wait_frames(1)
	assert_eq(f.current, f.loadout_screen as Control, "skills Back -> armory")
	f.loadout_screen.mask_option.pressed.emit()
	await wait_frames(1)
	f.mask_screen.back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.loadout_screen as Control, "masks from the armory Back -> armory")
	f.loadout_screen.back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control)
	f.queue_free()
	await wait_frames(1)


func test_open_station_rejects_unknown_ids() -> void:
	Log.capture = true
	Log.captured.clear()
	var f: MenuFlow = _flow()
	await wait_frames(1)
	await _to_hub(f)
	assert_false(f.open_station(&"jacuzzi"))
	assert_eq(f.current, f.hub as Control, "nothing opened")
	var errors: int = 0
	for line: String in Log.captured:
		if line.begins_with("[ERROR][ui]") and line.contains("open_station"):
			errors += 1
	assert_eq(errors, 1)
	Log.capture = false
	f.queue_free()
	await wait_frames(1)


func test_open_station_works_without_the_2d_hub_shown() -> void:
	# ENV C's 3D safehouse calls open_station directly from the main menu state.
	var f: MenuFlow = _flow()
	await wait_frames(1)
	assert_eq(f.current, f.main_menu as Control)
	assert_true(f.open_station(&"planning"))
	await wait_frames(1)
	assert_eq(f.current, f.heist_select as Control)
	f.heist_select.back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control, "station Back always lands in the hub")
	f.queue_free()
	await wait_frames(1)


## Board -> briefing -> pre-planning -> loadout: is_pro rides along to the launch options; Back from
## the briefing returns to the Board. The planning table path is never pro.
func test_board_contract_carries_is_pro_to_launch_options() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	await _to_hub(f)
	f.open_station(&"board")
	await wait_frames(2)
	f.board_screen.contract_chosen.emit(&"glasshouse", Enums.Difficulty.BRUTAL, true)
	await wait_frames(2)
	assert_eq(f.current, f.briefing_screen as Control, "contract -> briefing")
	assert_true(f.is_pro)
	assert_eq(f.briefing_screen.heist_id, &"glasshouse")
	assert_eq(f.briefing_screen.difficulty, Enums.Difficulty.BRUTAL)
	f.briefing_screen.back_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.board_screen as Control, "briefing Back -> the Board")
	f.board_screen.contract_chosen.emit(&"glasshouse", Enums.Difficulty.BRUTAL, true)
	await wait_frames(1)
	f.briefing_screen.continue_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.preplanning_screen as Control)
	f.preplanning_screen.confirm_button.pressed.emit()
	await wait_frames(2)
	assert_eq(f.current, f.loadout_screen as Control)
	assert_false(f.loadout_screen.hub_mode, "heist path loadout has Launch")
	assert_true(f.loadout_screen.launch_button.visible)
	var opts: Dictionary = f.launch_options_for(f.loadout_screen.current_loadout())
	assert_true(bool(opts.get("is_pro", false)), "pro job reaches HeistLauncher options")
	assert_has(opts, "preplan")
	assert_eq(int(((opts["preplan"] as Dictionary)["plan"] as Dictionary)["difficulty"]), Enums.Difficulty.BRUTAL)
	# Back out to the hub, take the planning table instead: not pro.
	f.loadout_screen.back_button.pressed.emit()
	f.preplanning_screen.back_button.pressed.emit()
	f.briefing_screen.back_button.pressed.emit()
	await wait_frames(1)
	f.board_screen.back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control)
	f.open_station(&"planning")
	f.heist_select.next_button.pressed.emit()
	await wait_frames(1)
	assert_false(f.is_pro, "planning table contracts are never pro")
	f.briefing_screen.continue_button.pressed.emit()
	await wait_frames(1)
	f.preplanning_screen.confirm_button.pressed.emit()
	await wait_frames(1)
	assert_false(f.launch_options_for(f.loadout_screen.current_loadout()).has("is_pro"))
	f.queue_free()
	await wait_frames(1)


## Taking a real pin emits the contract's own pro flag, and MenuFlow stores it.
func test_board_take_uses_the_pin_flag() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	f.open_station(&"board")
	await wait_frames(2)
	var b: BoardScreen = f.board_screen
	assert_false(b.contracts.is_empty(), "board has contracts")
	b.select_slot(0)
	var c: Dictionary = b.selected_contract()
	assert_true(b.take_selected())
	await wait_frames(1)
	assert_eq(f.current, f.briefing_screen as Control)
	assert_eq(f.is_pro, bool(c["is_pro"]))
	assert_eq(f.briefing_screen.heist_id, StringName(c["heist_id"]))
	f.queue_free()
	await wait_frames(1)


## QB-BRD1 (D-049): a failed pro job consumes its Board contract (no restart): the pin is locked for
## the rest of its rotation; a success, or a failed non-pro run, consumes nothing.
func test_failed_pro_job_consumes_the_contract() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	f.open_station(&"board")
	await wait_frames(2)
	var b: BoardScreen = f.board_screen
	var t: Dictionary = {"now": Time.get_unix_time_from_system()}
	b.clock = func() -> float: return float(t["now"])
	b.refresh_board()
	b.select_slot(0)
	b.contracts[0]["is_pro"] = true
	var key: String = BoardContracts.contract_key(b.contracts[0])
	assert_true(b.take_selected())
	assert_true(f.is_pro)
	f._on_heist_ended({"success": true})
	assert_true(f.consumed_contracts.is_empty(), "a successful pro job consumes nothing here")
	f._on_heist_ended({"success": false, "fail_reason": &"all_custody"})
	assert_true(f.consumed_contracts.has(key), "failed pro job: contract consumed")
	f.open_station(&"board")
	await wait_frames(1)
	b.select_slot(0)
	assert_true(bool(b.selected_contract()["consumed"]))
	assert_true(b.take_button.disabled, "Take locked")
	assert_true(b.consumed_label.visible)
	assert_true(b.map_view.pins[0].modulate.a < 1.0, "pin dimmed")
	assert_false(b.take_selected(), "can't relaunch it")
	assert_eq(f.current, b as Control)
	b.select_slot(1)
	assert_false(b.take_button.disabled, "other contracts stay open")
	# The slot's next rotation is a new contract.
	t["now"] = float(b.contracts[0]["expires_at"]) + 1.0
	b.refresh_board()
	b.select_slot(0)
	assert_false(bool(b.selected_contract()["consumed"]), "next rotation is a fresh contract")
	# A failed non-pro (planning table) run consumes nothing.
	f.consumed_contracts.clear()
	f._on_heist_chosen(&"glasshouse", Enums.Difficulty.ROUTINE)
	f._on_heist_ended({"success": false})
	assert_true(f.consumed_contracts.is_empty())
	f.queue_free()
	await wait_frames(1)


## B4-16: the pro-job lock is saved (profile.pro_job_locks, key -> expires_at), so a restarted flow
## still locks the pin; an expired lock is pruned.
func test_pro_job_lock_survives_restart() -> void:
	var f: MenuFlow = _flow()
	await wait_frames(1)
	f.open_station(&"board")
	await wait_frames(2)
	var b: BoardScreen = f.board_screen
	b.select_slot(0)
	b.contracts[0]["is_pro"] = true
	var c: Dictionary = b.contracts[0]
	var key: String = BoardContracts.contract_key(c)
	assert_true(b.take_selected())
	f._on_heist_ended({"success": false})
	var disk: PlayerProfile = SaveService.load_profile(0)
	assert_near(float(disk.pro_job_locks[key]), float(c["expires_at"]), 0.001, "lock saved with its expiry")
	f.queue_free()
	await wait_frames(1)
	var g: MenuFlow = _flow()
	await wait_frames(1)
	assert_false(g.consumed_contracts.has(key))
	g.open_station(&"board")
	await wait_frames(2)
	assert_true(g.consumed_contracts.has(key), "restored from the profile")
	g.board_screen.select_slot(0)
	assert_true(bool(g.board_screen.selected_contract()["consumed"]))
	g.queue_free()
	await wait_frames(1)
	assert_eq(ProJobLocks.prune(disk, float(c["expires_at"]) + 1.0), 1, "expired lock pruned")
	assert_true(disk.pro_job_locks.is_empty())
	assert_false(ProJobLocks.is_locked(disk, c, 0.0))


func test_build_launch_options_is_pro_key() -> void:
	var l: Loadout = Loadout.new()
	assert_false(MenuFlow.build_launch_options(3, 0, l).has("is_pro"))
	assert_false(MenuFlow.build_launch_options(3, 0, l, {}, false).has("is_pro"))
	assert_true(bool(MenuFlow.build_launch_options(3, 0, l, {}, true)["is_pro"]))


func test_payday_pays_the_pro_xp_line() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	var plain: Dictionary = PaydayScreen.compute_payout(result, null, 0)
	var pro: Dictionary = PaydayScreen.compute_payout(result, null, 0, true)
	assert_eq(_xp_line(plain, PayoutCalculator.XP_PRO), 0)
	assert_true(_xp_line(pro, PayoutCalculator.XP_PRO) > 0, "pro line paid")
	assert_true(int(pro["xp_total"]) > int(plain["xp_total"]))
	var pd: PaydayScreen = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	pd.apply_to_profile = false
	pd.is_pro = true
	add_child(pd)
	await wait_frames(1)
	pd.show_result(result)
	assert_eq(_xp_line(pd.payout, PayoutCalculator.XP_PRO), _xp_line(pro, PayoutCalculator.XP_PRO), "screen uses is_pro")
	pd.queue_free()
	await wait_frames(1)


static func _xp_line(payout: Dictionary, key: StringName) -> int:
	for line: Dictionary in payout.get("xp_lines", []) as Array:
		if StringName(line["key"]) == key:
			return int(line["amount"])
	return -1


## D-111 (style.md §11): cards are icon + title (+ one state word); the description shows in the side panel.
## At 720p every title fits on its card untrimmed.
func test_station_titles_fit_at_720p() -> void:
	var saved: Vector2i = get_window().size
	get_window().size = Vector2i(1280, 720)
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	var f: MenuFlow = _flow()
	await wait_frames(2)
	f.show_hub()
	await wait_frames(3)
	assert_true(f.hub.start_here != null and f.hub.start_here.is_visible_in_tree(), "START HERE shows for a new profile")
	assert_eq(HubMenu.CARD_COLUMNS, 3)
	var checked: int = 0
	for id: Variant in f.hub.station_buttons:
		var st: HubStation = f.hub.stations.find(StringName(id))
		var title_text: String = UiText.t(st.title_key)
		for n: Node in (f.hub.station_buttons[id] as Control).find_children("*", "Label", true, false):
			var l: Label = n as Label
			assert_ne(l.text, UiText.t(st.desc_key), "%s: no description on the card" % id)
			if l.text == title_text:
				checked += 1
				var w: float = l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						l.get_theme_font_size(&"font_size")).x
				assert_true(w <= l.size.x + 1.0, "%s title fits: %.0f > %.0f" % [id, w, l.size.x])
	assert_eq(checked, f.hub.station_buttons.size(), "titles checked")
	f.queue_free()
	get_window().size = saved
	await wait_frames(1)
