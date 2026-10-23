## D-076 pad-only walks through screens the earlier walks skipped: options + keybinds, (more below).
## Real InputEventJoypadButton only (d-pad, A, B, Y); no focus grabs, no direct calls on the subject.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const MAX_STEPS: int = 60


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## D-pad until `target` has focus. Keeps a direction while it reaches new controls; on a dead end or
## a revisit it turns (down, right, up, left). Fails after MAX_STEPS presses.
func _nav_to(target: Control, label: String) -> bool:
	await wait_frames(2)
	var dirs: Array[JoyButton] = [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP,
			JOY_BUTTON_DPAD_LEFT]
	var d: int = 0
	var seen: Dictionary = {}
	for _i: int in range(MAX_STEPS):
		if _focus() == target:
			return true
		seen[_focus()] = true
		await _pad(dirs[d])
		if seen.has(_focus()):
			d = (d + 1) % dirs.size()
	assert_eq(_focus(), target, "%s reachable by d-pad (focus on %s)" % [label, _focus()])
	return _focus() == target


## Options from the main menu with the pad: every tab by d-pad, the Controls pad column rebinds to a
## pressed pad button (A that opened the capture must not be captured itself), B leaves without saving.
func test_options_and_keybinds_gamepad_only() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	assert_eq(f.current, f.main_menu as Control)
	assert_true(await _nav_to(f.main_menu.settings_button, "Settings"))
	await _pad(JOY_BUTTON_A)
	var s: OptionsScreen = f.options_menu.screen
	assert_true(s != null and f.current == (s as Control), "A opens Options")
	if s == null:
		return
	for t: StringName in [OptionsScreen.TAB_AUDIO, OptionsScreen.TAB_VIDEO, OptionsScreen.TAB_ACCESSIBILITY,
			OptionsScreen.TAB_CONTROLS, OptionsScreen.TAB_KEYS]:
		assert_true(await _nav_to(s.tab_buttons[t] as Control, "tab %s" % t))
		await _pad(JOY_BUTTON_A)
		assert_eq(s.current_tab, t, "A shows tab %s" % t)
	var action: StringName = InputBindings.actions()[0]
	var pad_b: Button = s.controls_tab.rows[action][InputEventCodec.PAD] as Button
	assert_true(await _nav_to(s.controls_tab.rows[action][InputEventCodec.KBM] as Control, "kbm binding"))
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_focus(), pad_b as Control, "d-pad right reaches the pad column of %s" % action)
	await _pad(JOY_BUTTON_A)
	assert_true(s.controls_tab.is_capturing(), "A starts capture")
	await _pad(JOY_BUTTON_Y)
	if not s.controls_tab.pending_conflict.is_empty():
		await _nav_to(s.controls_tab.swap_button, "Swap")
		await _pad(JOY_BUTTON_A)
	assert_false(s.controls_tab.is_capturing())
	var col: Array[Dictionary] = InputBindings.column(s.draft, action, InputEventCodec.PAD)
	var has_y: bool = false
	for d: Dictionary in col:
		has_y = has_y or int(d.get("button", d.get("button_index", -1))) == JOY_BUTTON_Y
	assert_true(has_y, "pad Y bound to %s in the draft: %s" % [action, col])
	assert_true(s.is_dirty())
	await _pad(JOY_BUTTON_B)
	assert_eq(f.current, f.main_menu as Control, "B leaves Options (unapplied edits dropped)")
	f.queue_free()
	await wait_frames(2)


## Payday with the pad only at 720p: A on Continue opens the cards, d-pad moves to card 2, A picks
## it (after the input grace), A on Continue finishes.
func test_payday_gamepad_only() -> void:
	SaveService.delete_profile(SLOT)
	var s: PaydayScreen = (load("res://content/ui/results/payday.tscn") as PackedScene).instantiate() as PaydayScreen
	add_child(s)
	await wait_frames(1)
	s.show_result(HeistCatalog.sample_result())
	var done: Array[int] = [0]
	s.continue_pressed.connect(func() -> void: done[0] += 1)
	await wait_frames(2)
	var vis: Rect2 = s.get_viewport().get_visible_rect().grow(1.0)
	assert_true(vis.encloses(s.continue_button.get_global_rect()), "Continue on screen at 720p")
	if s.has_card_pick():
		assert_true(await _nav_to(s.continue_button, "result Continue"))
		await _pad(JOY_BUTTON_A)
		assert_true(s.cards_stage, "A opens the cards")
		s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
		for c: Control in s.card_views:
			assert_true(vis.encloses(c.get_global_rect()), "card on screen at 720p")
		assert_true(await _nav_to(s.card_views[1], "card 2"))
		await _pad(JOY_BUTTON_A)
		assert_eq(s.picked_index, 1, "A picks the focused card")
		await wait_frames(2)
	assert_true(await _nav_to(s.continue_button, "Continue"))
	await _pad(JOY_BUTTON_A)
	assert_eq(done[0], 1, "A on Continue finishes the payday")
	s.queue_free()
	await wait_frames(2)


## Quit to the main menu and back with the pad (2D hub, the shipped hub): the saved profile is what
## the main menu and the hub show after the round trip.
func test_hub_quit_and_reload_gamepad_only() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 7
	SaveService.save_profile(p, SLOT)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	assert_true(await _nav_to(f.main_menu.safehouse_button, "Safehouse"))
	await _pad(JOY_BUTTON_A)
	assert_eq(f.current, f.hub as Control, "A enters the hub")
	assert_true(f.hub.level_label.text.contains("7"), f.hub.level_label.text)
	assert_true(await _nav_to(f.hub.back_button, "hub Main menu"))
	await _pad(JOY_BUTTON_A)
	assert_eq(f.current, f.main_menu as Control, "A on Main menu quits to the main menu")
	assert_true(f.main_menu.profile_label.text.contains("7"), f.main_menu.profile_label.text)
	p.level = 8
	SaveService.save_profile(p, SLOT)
	await _pad(JOY_BUTTON_B)
	assert_eq(f.current, f.main_menu as Control, "B on the main menu does nothing")
	assert_true(await _nav_to(f.main_menu.safehouse_button, "Safehouse again"))
	await _pad(JOY_BUTTON_A)
	assert_true(f.hub.level_label.text.contains("8"), "hub reloads the saved profile: %s" % f.hub.level_label.text)
	await _pad(JOY_BUTTON_B)
	assert_eq(f.current, f.main_menu as Control, "B on the hub goes back to the main menu")
	f.queue_free()
	await wait_frames(2)
