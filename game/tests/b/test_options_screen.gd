## B5-01: the options screen builds every tab, navigates with keyboard / pad focus, edits a draft,
## applies / reverts it, rebinds through "press a key" capture with conflict handling, and is reachable
## from the main menu, the hub and (in a heist) the `pause` action.
extends TestCase

const SCREEN_SCENE: PackedScene = preload("res://content/ui/menus/options_screen.tscn")
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const K_KEY: Dictionary = {"type": "key", "keycode": KEY_K, "physical": true}
const PAD_X: Dictionary = {"type": "joy_button", "button": JOY_BUTTON_X}

var _prev: GameSettings


class FakeCrew:
	extends Node
	var slot: int = -1
	var paused: bool = false

	func set_input_paused(p: bool) -> void:
		paused = p


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C\'s 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()
	GameSettings.root_dir = BTestUtil.settings_root()
	_prev = GameSettings.current()


func after_each() -> void:
	InputBindings.apply(GameSettings.new())
	SettingsApplier.apply_audio(GameSettings.new())
	GameSettings.set_current(_prev)


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
	if FileAccess.file_exists(GameSettings.file_path()):
		DirAccess.remove_absolute(GameSettings.file_path())
	DirAccess.remove_absolute(GameSettings.root_dir)
	GameSettings.root_dir = GameSettings.DEFAULT_ROOT_DIR


func _screen(s: GameSettings) -> OptionsScreen:
	var o: OptionsScreen = SCREEN_SCENE.instantiate() as OptionsScreen
	o.settings = s
	o.save_on_apply = false
	add_child(o)
	return o


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


## The `child` control ("Slider", "Toggle", "Choice") of row `Row_<key>` on tab `t`.
func _row(o: OptionsScreen, t: StringName, key: String, child: String) -> Control:
	return (o.pages[t] as Node).find_child("Row_" + key, true, false).get_node(child) as Control


func _neighbor(c: Control, side: Side) -> Control:
	return c.get_node_or_null(c.get_focus_neighbor(side)) as Control


func test_builds_every_tab() -> void:
	var o: OptionsScreen = _screen(GameSettings.new())
	await wait_frames(2)
	assert_eq(o.tab_buttons.size(), 5)
	assert_eq(o.current_tab, OptionsScreen.TAB_CONTROLS)
	assert_eq(o.controls_tab.rows.size(), InputBindings.actions().size(), "one rebind row per action")
	assert_eq(o.controls_tab.rows[&"interact"][InputEventCodec.KBM].text, "F")
	for t: StringName in OptionsScreen.TABS:
		o.show_tab(t)
		assert_true((o.pages[t] as Control).visible, "%s page shown" % t)
		var expected: int = o.draft.defaults.keys(StringName(t)).size()
		if t == OptionsScreen.TAB_CONTROLS:
			expected += o.draft.defaults.keys(GameSettings.GAMEPLAY).size()  # gameplay rows sit on Controls
			expected += 1  # Lead r228: "First-time tips: Show again"
		if t == OptionsScreen.TAB_KEYS:
			expected = InputBindings.actions().size() + 1  # D-111: the rebind table is its own tab
		assert_eq((o.page_focus[t] as Array).size(), expected, "%s rows are focusable" % t)
	assert_eq(o.palette_preview.get_child_count(), HudPalette.FIELDS.size(), "palette swatches")
	assert_true(o.apply_button.disabled, "nothing to apply yet")
	o.queue_free()
	await wait_frames(1)


func test_focus_navigation() -> void:
	var o: OptionsScreen = _screen(GameSettings.new())
	await wait_frames(2)
	var tab: Control = o.tab_buttons[OptionsScreen.TAB_CONTROLS] as Control
	assert_eq(_focused(), tab, "first tab focused on open")
	assert_eq(_neighbor(tab, SIDE_RIGHT), o.tab_buttons[OptionsScreen.TAB_KEYS] as Control, "tabs: left / right")
	var first: Control = (o.page_focus[OptionsScreen.TAB_CONTROLS] as Array)[0]
	assert_eq(_neighbor(tab, SIDE_BOTTOM), first, "down from the tabs = first row")
	assert_eq(_neighbor(first, SIDE_TOP), tab)
	var rows: Array = o.page_focus[OptionsScreen.TAB_CONTROLS]
	assert_eq(_neighbor(rows[rows.size() - 1] as Control, SIDE_BOTTOM), o.apply_button as Control, "last row -> footer")
	# PO-4 footer: Back .. Revert, Reset tab .. Apply (bottom right).
	assert_eq(_neighbor(o.apply_button, SIDE_LEFT), o.reset_button as Control, "footer: left / right")
	assert_eq(_neighbor(o.back_button, SIDE_RIGHT), o.revert_button as Control)
	assert_eq(_neighbor(o.back_button, SIDE_TOP), rows[rows.size() - 1] as Control)
	o.tab_buttons[OptionsScreen.TAB_AUDIO].pressed.emit()
	await wait_frames(2)
	assert_eq(o.current_tab, OptionsScreen.TAB_AUDIO)
	var master: Control = (o.page_focus[OptionsScreen.TAB_AUDIO] as Array)[0]
	assert_true(master is HSlider, "audio rows are sliders")
	assert_eq(_focused(), master, "switching tabs focuses the first row")
	assert_eq(_neighbor(o.tab_buttons[OptionsScreen.TAB_AUDIO] as Control, SIDE_BOTTOM), master, "chain rebuilt for the tab")
	var backs: Array = []
	o.back_requested.connect(func() -> void: backs.append(true))
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	o._unhandled_input(esc)
	assert_eq(backs.size(), 1, "Esc / pad B = Back")
	o.queue_free()
	await wait_frames(1)


func test_edit_apply_and_revert() -> void:
	var s: GameSettings = GameSettings.new()
	var o: OptionsScreen = _screen(s)
	await wait_frames(2)
	var applied: Array = []
	o.applied.connect(func() -> void: applied.append(true))
	o.show_tab(OptionsScreen.TAB_AUDIO)
	var sfx: HSlider = _row(o, OptionsScreen.TAB_AUDIO, "SFX", "Slider") as HSlider
	sfx.value = 0.5
	assert_near(float(o.draft.get_value(GameSettings.AUDIO, &"SFX")), 0.5)
	assert_near(float(s.get_value(GameSettings.AUDIO, &"SFX")), 1.0, 0.0001, "not applied yet")
	assert_true(o.is_dirty())
	assert_false(o.apply_button.disabled)
	assert_true(o.dirty_label.visible)
	o.apply_button.pressed.emit()
	assert_near(float(s.get_value(GameSettings.AUDIO, &"SFX")), 0.5)
	assert_eq(applied.size(), 1)
	assert_false(o.is_dirty())
	var idx: int = AudioServer.get_bus_index(&"SFX")
	assert_near(AudioServer.get_bus_volume_db(idx), SettingsApplier.base_db(&"SFX") + linear_to_db(0.5), 0.01, "applied to AudioServer")
	o.show_tab(OptionsScreen.TAB_VIDEO)
	var fov: HSlider = _row(o, OptionsScreen.TAB_VIDEO, "fov", "Slider") as HSlider
	assert_near(fov.value, 75.0)
	fov.value = 95.0
	var wm: OptionButton = _row(o, OptionsScreen.TAB_VIDEO, "window_mode", "Choice") as OptionButton
	wm.select(1)
	wm.item_selected.emit(1)
	assert_eq(o.draft.get_value(GameSettings.VIDEO, &"window_mode"), "fullscreen")
	o.revert_button.pressed.emit()
	await wait_frames(1)
	assert_false(o.is_dirty(), "revert drops the edits")
	assert_near(o.draft.fov(), 75.0)
	var fov2: HSlider = _row(o, OptionsScreen.TAB_VIDEO, "fov", "Slider") as HSlider
	assert_near(fov2.value, 75.0, 0.0001, "rows rebuilt from the settings")
	o.show_tab(OptionsScreen.TAB_CONTROLS)
	var inv: CheckButton = _row(o, OptionsScreen.TAB_CONTROLS, "invert_y", "Toggle") as CheckButton
	inv.button_pressed = true
	assert_true(o.draft.invert_y())
	o.reset_button.pressed.emit()
	assert_false(o.draft.invert_y(), "reset tab")
	o.queue_free()
	await wait_frames(1)


func test_apply_saves_when_asked() -> void:
	var s: GameSettings = GameSettings.new()
	var o: OptionsScreen = _screen(s)
	o.save_on_apply = true
	await wait_frames(2)
	o.draft.set_value(GameSettings.VIDEO, &"fov", 88.0)
	o.apply_changes()
	assert_near(GameSettings.load_file().fov(), 88.0, 0.0001, "written to settings.cfg")
	o.queue_free()
	await wait_frames(1)


func test_rebind_capture_and_conflicts() -> void:
	var s: GameSettings = GameSettings.new()
	var o: OptionsScreen = _screen(s)
	await wait_frames(2)
	o.show_tab(OptionsScreen.TAB_KEYS)  # D-111: the rebind table's own tab
	var ct: OptionsControlsTab = o.controls_tab
	ct.rows[&"reload"][InputEventCodec.KBM].pressed.emit()
	assert_true(ct.is_capturing())
	assert_true(ct.capture_label.visible)
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = KEY_K
	k.pressed = true
	ct._input(k)
	assert_false(ct.is_capturing())
	assert_eq(InputBindings.column(o.draft, &"reload", InputEventCodec.KBM), [K_KEY] as Array[Dictionary])
	assert_eq(ct.rows[&"reload"][InputEventCodec.KBM].text, "K")
	assert_false(ct.rows[&"reload"]["reset"].disabled, "reset enabled for an override")
	assert_true(o.is_dirty())
	assert_eq(InputBindings.column(s, &"reload", InputEventCodec.KBM)[0]["keycode"], KEY_R, "settings untouched until Apply")
	# Esc cancels a capture.
	ct.begin_capture(&"jump", InputEventCodec.KBM)
	var esc: InputEventKey = InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	ct._input(esc)
	assert_false(ct.is_capturing())
	assert_eq(ct.rows[&"jump"][InputEventCodec.KBM].text, "Space")
	# Conflict: interact's F on reload -> swap.
	ct.begin_capture(&"reload", InputEventCodec.KBM)
	ct.submit_capture({"type": "key", "keycode": KEY_F, "physical": true})
	assert_false(ct.pending_conflict.is_empty())
	assert_true(ct.conflict_bar.visible)
	assert_true(ct.conflict_label.text.contains(UiText.t(&"ui.action.interact")))
	ct.swap_button.pressed.emit()
	assert_false(ct.conflict_bar.visible)
	assert_eq(ct.rows[&"reload"][InputEventCodec.KBM].text, "F")
	assert_eq(ct.rows[&"interact"][InputEventCodec.KBM].text, "K", "interact took reload's previous K")
	# Conflict: cancel keeps everything.
	ct.begin_capture(&"jump", InputEventCodec.PAD)
	ct.submit_capture({"type": "joy_button", "button": JOY_BUTTON_X})
	ct.resolve_conflict(OptionsControlsTab.CANCEL)
	assert_eq(InputBindings.column(o.draft, &"jump", InputEventCodec.PAD), InputBindings.default_column(&"jump", InputEventCodec.PAD))
	# Keep both.
	ct.begin_capture(&"jump", InputEventCodec.PAD)
	var jb: InputEventJoypadButton = InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_X
	jb.pressed = true
	ct._input(jb)
	ct.keep_button.pressed.emit()
	assert_eq(InputBindings.column(o.draft, &"jump", InputEventCodec.PAD), [PAD_X] as Array[Dictionary])
	assert_eq(InputBindings.column(o.draft, &"interact", InputEventCodec.PAD), [PAD_X] as Array[Dictionary])
	# Apply pushes the bindings into the InputMap; Reset all restores the defaults in the draft.
	o.apply_changes()
	var f: InputEventKey = InputEventKey.new()
	f.physical_keycode = KEY_F
	assert_true(InputMap.event_is_action(f, &"reload"))
	ct.reset_all_button.pressed.emit()
	assert_eq(ct.rows[&"reload"][InputEventCodec.KBM].text, "R")
	assert_true(ct.rows[&"reload"]["reset"].disabled)
	o.queue_free()
	await wait_frames(1)


func test_menu_flow_opens_options_from_menu_and_hub() -> void:
	GameSettings.set_current(GameSettings.new())
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	f.main_menu.settings_button.pressed.emit()
	await wait_frames(1)
	assert_true(f.current is OptionsScreen, "main menu Options")
	assert_eq((f.current as OptionsScreen).settings, GameSettings.current(), "edits the game-wide settings")
	(f.current as OptionsScreen).back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.main_menu as Control, "Back returns to the main menu")
	f.show_hub()
	await wait_frames(1)
	assert_has(f.hub.focus_chain, f.hub.options_button as Control)
	f.hub.options_button.pressed.emit()
	await wait_frames(1)
	assert_true(f.current is OptionsScreen, "hub Options")
	(f.current as OptionsScreen).back_requested.emit()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control, "Back returns to the hub")
	assert_true(f.options_menu.screen == null)
	f.queue_free()
	await wait_frames(1)


func test_pause_in_a_heist_opens_options_over_the_hud() -> void:
	GameSettings.set_current(GameSettings.new())
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var crew: FakeCrew = FakeCrew.new()
	crew.slot = Net.local_slot()
	crew.add_to_group(G.CREW)
	add_child(crew)
	var pause: InputEventAction = InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	f.options_menu._unhandled_input(pause)
	assert_true(f.options_menu.pause_menu == null, "no heist layer: pause does nothing")
	f.options_menu.heist_layer = layer
	f.options_menu._unhandled_input(pause)
	var pm: PauseMenu = f.options_menu.pause_menu
	assert_true(pm != null and pm.get_parent() == layer, "PO-4: pause menu over the HUD layer")
	assert_true(crew.paused, "local crew input paused")
	pm.options_button.pressed.emit()
	var o: OptionsScreen = f.options_menu.heist_screen
	assert_true(o != null and o.get_parent() == layer, "options over the HUD layer")
	assert_false(pm.visible, "pause menu hidden under Options")
	assert_true(o.leave_button == null, "Leave Heist lives in the pause menu, not the Options footer")
	f.options_menu._unhandled_input(pause)
	assert_eq(f.options_menu.heist_screen, o, "pause while Options is up does not stack screens")
	o.back_button.pressed.emit()
	assert_true(f.options_menu.heist_screen == null)
	assert_true(pm.visible, "Back returns to the pause menu")
	assert_true(crew.paused, "still paused in the pause menu")
	f.options_menu._unhandled_input(pause)
	assert_true(f.options_menu.pause_menu == null, "pause again resumes")
	assert_false(crew.paused, "input resumed")
	var payday: Control = Control.new()
	layer.add_child(payday)
	f.options_menu.heist_payday = payday
	f.options_menu._unhandled_input(pause)
	assert_true(f.options_menu.pause_menu == null, "not over the payday screen")
	f.options_menu.heist_layer = null
	f.queue_free()
	layer.queue_free()
	crew.queue_free()
	await wait_frames(1)


## Lead r228: Controls has "First-time tips: Show again". It asks first (focus on Cancel; Cancel and Esc keep
## the seen list), then forgets every seen card (situations and heists) at once, without Apply.
func test_show_first_time_tips_again() -> void:
	OnboardingTips.persist = false
	OnboardingTips.reset()
	OnboardingTips.mark_seen(&"casing")
	OnboardingTips.mark_seen(OnboardingTips.heist_tip(&"glasshouse"))
	var o: OptionsScreen = _screen(GameSettings.new())
	await wait_frames(2)
	var rows: Array = o.page_focus[OptionsScreen.TAB_CONTROLS]
	assert_eq(rows[rows.size() - 1], o.tips_button, "the tips row ends the Controls page (pad reachable)")
	assert_eq(_neighbor(o.tips_button, SIDE_BOTTOM), o.apply_button as Control)
	o.tips_button.pressed.emit()
	await wait_frames(2)
	assert_true(o.is_tips_confirming(), "it asks first")
	assert_eq(_focused(), o.tips_cancel_button as Control, "focus on Cancel")
	o.tips_cancel_button.pressed.emit()
	assert_false(o.is_tips_confirming())
	assert_eq(OnboardingTips.seen_ids().size(), 2, "Cancel keeps the seen cards")
	o.tips_button.pressed.emit()
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	var backs: Array = []
	o.back_requested.connect(func() -> void: backs.append(true))
	o._unhandled_input(esc)
	assert_false(o.is_tips_confirming(), "Esc / pad B closes the dialog")
	assert_eq(backs.size(), 0, "and does not leave Options")
	assert_eq(OnboardingTips.seen_ids().size(), 2)
	o.tips_button.pressed.emit()
	o.tips_confirm_button.pressed.emit()
	assert_false(o.is_tips_confirming())
	assert_eq(OnboardingTips.seen_ids().size(), 0, "every card shows again")
	assert_false(OnboardingTips.is_seen(&"casing"))
	assert_true(o.tips_done_label.visible, "the row says so")
	assert_false(o.is_dirty(), "takes effect at once, nothing to Apply")
	o.queue_free()
	await wait_frames(1)
	OnboardingTips.persist = true
