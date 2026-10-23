## C4 Last Breath (PD2 One Down; LEAD r280 queue (3)): the planning table's toggle reaches the HeistLauncher options
## (options["last_breath"], ENV A: one down before custody) and the payday screen; the lobby host's contract carries
## it (toggling it clears the ready flags); a Board contract never has it; a win with it counts in the career.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)
	SaveService.root_dir = BTestUtil.profile_root()
	OnboardingTips.persist = false


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = 500000
	SaveService.save_profile(p, 0)


func _flow() -> MenuFlow:
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	f.show_hub()
	await wait_frames(2)
	return f


func _to_loadout(f: MenuFlow) -> void:
	f.briefing_screen.continue_button.pressed.emit()
	await wait_frames(2)
	f.preplanning_screen.confirm_button.pressed.emit()
	await wait_frames(2)


func test_planning_table_toggle_reaches_the_launch_options() -> void:
	var f: MenuFlow = await _flow()
	f.open_station(&"planning")
	await wait_frames(2)
	var hs: HeistSelect = f.heist_select
	assert_true(hs.last_breath_button != null and hs.last_breath_button.toggle_mode, "a Last Breath toggle")
	assert_true(hs.focus_chain.has(hs.last_breath_button), "reachable by keys / pad")
	assert_false(hs.last_breath, "off by default")
	hs.last_breath_button.button_pressed = true
	assert_true(hs.last_breath, "the toggle sets it")
	hs.next_button.pressed.emit()
	await wait_frames(2)
	assert_true(f.last_breath)
	await _to_loadout(f)
	var opts: Dictionary = f.launch_options_for(f.loadout_screen.current_loadout())
	assert_true(bool(opts.get("last_breath", false)), "options[\"last_breath\"] for ENV A")
	# Off again: the key is absent (A's default).
	f.show_hub()
	f.open_station(&"planning")
	await wait_frames(2)
	hs.set_last_breath(false)
	assert_false(hs.last_breath_button.button_pressed, "set_last_breath updates the toggle")
	hs.next_button.pressed.emit()
	await wait_frames(2)
	await _to_loadout(f)
	assert_false(f.launch_options_for(f.loadout_screen.current_loadout()).has("last_breath"))
	f.queue_free()
	await wait_frames(2)


func test_board_contracts_never_carry_it() -> void:
	var f: MenuFlow = await _flow()
	f.heist_select.set_last_breath(true)
	f.last_breath = true
	f.open_station(&"board")
	await wait_frames(2)
	f.board_screen.contract_chosen.emit(&"glasshouse", Enums.Difficulty.TENSE, false)
	await wait_frames(2)
	assert_false(f.last_breath, "a Board contract resets it")
	f.queue_free()
	await wait_frames(2)


func test_options_builders() -> void:
	var solo: Dictionary = MenuFlow.build_launch_options(0, 0, null, {}, false, &"", null, true)
	assert_true(bool(solo.get("last_breath", false)))
	assert_false(MenuFlow.build_launch_options(0, 0, null).has("last_breath"), "absent when off")
	var coop: Dictionary = MenuFlow.build_coop_launch_options({}, {}, false, &"", {}, true)
	assert_true(bool(coop.get("last_breath", false)), "co-op: the host's contract")


func test_lobby_contract_carries_it() -> void:
	var data: Dictionary = LobbyState.contract_data(&"glasshouse", Enums.Difficulty.HAZARDOUS, false, true)
	var c: Dictionary = LobbyState.parse_contract(data)
	assert_true(bool(c.get("last_breath", false)), "round trip")
	assert_false(bool(LobbyState.parse_contract(LobbyState.contract_data(&"glasshouse", 0, false)).get("last_breath", true)))
	var legacy: Dictionary = {"heist": "glasshouse", "difficulty": 0, "is_pro": false}
	assert_false(bool(LobbyState.parse_contract(legacy).get("last_breath", true)), "an older host's payload = off")
	var bad: Dictionary = data.duplicate()
	bad["last_breath"] = "yes"
	assert_true(LobbyState.parse_contract(bad).is_empty(), "a non-bool flag is rejected")
	assert_true(bool(LobbyState.start_data(c, 7).get("last_breath", false)), "MSG_START carries it")
	# Toggling it on the same job clears the ready flags (the stakes changed); the plan votes stay.
	var s: LobbyState = LobbyState.new(true)
	s.set_crew({0: {"peer_id": 1, "is_ai": false, "display_name": "Host"},
			1: {"peer_id": 7, "is_ai": false, "display_name": "P7"}}, 0, 0)
	s.receive(0, LobbyState.MSG_CONTRACT, LobbyState.contract_data(&"glasshouse", 2, false, false))
	s.receive(1, LobbyState.MSG_READY, {"ready": true})
	assert_true(s.is_ready(1))
	s.receive(0, LobbyState.MSG_CONTRACT, LobbyState.contract_data(&"glasshouse", 2, false, true))
	assert_false(s.is_ready(1), "Last Breath on: everyone readies again")
	assert_true(bool(s.contract["last_breath"]))


func test_payday_chip_and_career() -> void:
	var pd: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	pd.cards_enabled = false
	pd.last_breath = true
	add_child(pd)
	await wait_frames(1)
	pd.show_result(HeistCatalog.sample_result())
	await wait_frames(2)
	var chips: Label = pd.find_child("SummaryChips", true, false) as Label
	assert_true(chips != null and chips.text.contains(UiText.t(&"ui.heist_select.last_breath")), "the summary row says so")
	var p: PlayerProfile = SaveService.load_profile(0)
	assert_eq(Career.total(p, Career.LAST_BREATH_WINS), 1, "a Last Breath win is on the record")
	pd.queue_free()
	await wait_frames(1)
	var q: PlayerProfile = PlayerProfile.new_default()
	var lost: Dictionary = HeistCatalog.sample_result()
	lost["success"] = false
	Career.record(q, lost, {"success": false}, 0, true)
	assert_true(Career.total(q, Career.LAST_BREATH_WINS) <= 0, "a failed run is not a win (-1 = never counted)")
	Career.record(q, HeistCatalog.sample_result(), {"success": true}, 0, false)
	assert_true(Career.total(q, Career.LAST_BREATH_WINS) <= 0, "only with the toggle on")
