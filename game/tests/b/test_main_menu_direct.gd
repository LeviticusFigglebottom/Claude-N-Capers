## PO r305: "a button to go to the other menus (planning board, heist select) from the main menu without going to the
## safehouse". The main menu's direct entries (The Board, Planning Table, Armory & Workshop, All Stations) open the 2D
## screens with no safehouse walk, the contract path reaches pre-planning, and every Back lands on the main menu (All
## Stations: on the 2D station list, then the main menu). The Safehouse entry still opens the hub.
extends TestCase


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	OnboardingTips.persist = false


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = 150000
	SaveService.save_profile(p, 0)


func _flow() -> MenuFlow:
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	return f


func _press(b: Button) -> void:
	b.pressed.emit()
	await wait_frames(2)


func test_main_menu_lists_the_direct_entries() -> void:
	var f: MenuFlow = await _flow()
	var m: MainMenu = f.main_menu
	for id: StringName in MainMenu.DIRECT_STATIONS:
		var b: Button = m.station_buttons.get(id) as Button
		assert_true(b != null and b.visible, "%s entry" % id)
		assert_eq(b.text, UiText.t(MainMenu.STATION_KEYS[id] as StringName).to_upper())
		assert_true(f.stations.find(id) != null, "%s is a hub station" % id)
	assert_true(m.stations_button.visible and m.safehouse_button.visible)
	assert_true(m.focus_chain.has(m.stations_button), "the entries are in the focus chain")
	f.queue_free()
	await wait_frames(1)


func test_planning_table_reaches_preplan_and_backs_out_to_the_main_menu() -> void:
	var f: MenuFlow = await _flow()
	await _press(f.main_menu.station_buttons[&"planning"] as Button)
	assert_eq(f.current, f.heist_select as Control, "Planning Table -> heist select")
	assert_false(f.safehouse.is_active(), "no safehouse walk")
	await _press(f.heist_select.next_button)
	assert_eq(f.current, f.briefing_screen as Control)
	await _press(f.briefing_screen.continue_button)
	assert_eq(f.current, f.preplanning_screen as Control, "pre-planning reached from the main menu")
	await _press(f.preplanning_screen.back_button)
	await _press(f.briefing_screen.back_button)
	assert_eq(f.current, f.heist_select as Control)
	await _press(f.heist_select.back_button)
	assert_eq(f.current, f.main_menu as Control, "Back lands on the main menu, not the hub")
	f.queue_free()
	await wait_frames(1)


func test_board_and_armory_back_to_the_main_menu() -> void:
	var f: MenuFlow = await _flow()
	await _press(f.main_menu.station_buttons[&"board"] as Button)
	assert_eq(f.current, f.board_screen as Control, "The Board")
	await _press(f.board_screen.back_button)
	assert_eq(f.current, f.main_menu as Control)
	await _press(f.main_menu.station_buttons[&"armory"] as Button)
	assert_eq(f.current, f.loadout_screen as Control, "Armory & Workshop")
	assert_true(f.loadout_screen.hub_mode, "the station loadout (no Launch)")
	await _press(f.loadout_screen.back_button)
	assert_eq(f.current, f.main_menu as Control)
	f.queue_free()
	await wait_frames(1)


func test_all_stations_and_the_safehouse_entry() -> void:
	var f: MenuFlow = await _flow()
	await _press(f.main_menu.stations_button)
	assert_eq(f.current, f.hub as Control, "All Stations -> the 2D station list")
	assert_false(f.safehouse.is_active())
	f.open_station(&"profile")
	await wait_frames(2)
	assert_ne(f.current, f.hub as Control, "a station opened")
	f.show_hub()  # every station's Back
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control, "a station's Back returns to the station list")
	await _press(f.hub.back_button)
	assert_eq(f.current, f.main_menu as Control, "the list's Back returns to the main menu")
	# The Safehouse entry drops the direct path: Back from a station goes to the hub again.
	BTestUtil.pin_menu_hub(true)
	await _press(f.main_menu.safehouse_button)
	assert_eq(f.current, f.hub as Control)
	f.open_station(&"board")
	await wait_frames(2)
	await _press(f.board_screen.back_button)
	assert_eq(f.current, f.hub as Control, "safehouse path: Back to the hub")
	BTestUtil.pin_menu_hub(false)
	f.queue_free()
	await wait_frames(1)
