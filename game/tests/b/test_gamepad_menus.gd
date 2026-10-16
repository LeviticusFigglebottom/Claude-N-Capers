## D-115 gamepad-only menu pass: every menu screen, opened through MenuFlow (or standalone where the flow
## needs a live session), is usable with a pad only. For each screen:
##   (a) something inside the screen has focus once it is open;
##   (b) a walk with ui_up / ui_down / ui_left / ui_right / ui_focus_next / ui_focus_prev (InputEventAction
##       pushed into the viewport, the path a d-pad takes after the InputMap) reaches every interactive control
##       of the screen (visible, enabled buttons, option buttons, check boxes, sliders, line edits, item lists,
##       focusable panels) from the initial focus, and never leaves the screen;
##   (c) ui_cancel goes back (the screen's back signal, or its equivalent);
##   (d) every control the walk lands on is visible, has a size and shows a focus indicator (a visible "focus"
##       StyleBox, the focus_panel cyan edge, or a custom-drawn focus state).
## test_menu_reach checks the focus_chain graph; this walks the whole control tree with real input actions.
extends "res://tests/b/gamepad_walk.gd"


# --- main menu, hub, contract path --------------------------------------------------------------------------


func test_main_menu() -> void:
	var f: MenuFlow = await _new_flow()
	await _assert_walk(f.main_menu, "main menu")
	# The main menu is the root: B does nothing there (test_pp_pad_walks), so no cancel check.


func test_hub() -> void:
	var f: MenuFlow = await _new_flow()
	f.show_hub()
	if f.current != (f.hub as Control):
		skip("hub shows the 3D safehouse here (2D hub only)")
		return
	await _assert_walk(f.hub, "hub")
	await _assert_cancel("hub", _current_is(f.main_menu))


func test_board() -> void:
	var s: Control = await _station(&"board")
	await _assert_walk(s, "board")
	var b: BoardScreen = s as BoardScreen
	b.broker_toggle.grab_focus()
	_press(&"ui_accept")
	await wait_frames(2)
	await _assert_walk(s, "board (broker open)")
	await _assert_cancel("board", _hub_shown())


func test_planning_table() -> void:
	var s: Control = await _station(&"planning")
	assert_true(s is HeistSelect, "planning opens heist select")
	await _assert_walk(s, "heist select")
	await _assert_cancel("heist select", _hub_shown())


func _to_briefing() -> BriefingScreen:
	await _station(&"planning")
	_flow.call(&"_on_heist_chosen", HEIST, Enums.Difficulty.ROUTINE)
	await wait_frames(3)
	return _flow.briefing_screen


func test_briefing() -> void:
	var b: BriefingScreen = await _to_briefing()
	await _assert_walk(b, "briefing")
	await _assert_cancel("briefing", _current_is(_flow.heist_select))


func _to_preplanning() -> PreplanningScreen:
	var b: BriefingScreen = await _to_briefing()
	b.continue_requested.emit(HEIST, Enums.Difficulty.ROUTINE)
	await wait_frames(3)
	return _flow.preplanning_screen


func test_preplanning() -> void:
	var p: PreplanningScreen = await _to_preplanning()
	await _assert_walk(p, "pre-planning")
	await _assert_cancel("pre-planning", _current_is(_flow.briefing_screen))


func test_loadout_heist_path() -> void:
	var p: PreplanningScreen = await _to_preplanning()
	_flow.call(&"_on_preplan_confirmed", {})
	await wait_frames(3)
	var ls: LoadoutScreen = _flow.loadout_screen
	await _assert_walk(ls, "loadout (heist)")
	await _assert_cancel("loadout (heist)", _current_is(p))


# --- armory, pickers, workshop, progression -----------------------------------------------------------------


func test_armory() -> void:
	var s: Control = await _station(&"armory")
	assert_true(s is LoadoutScreen, "armory opens the loadout")
	await _assert_walk(s, "armory")
	await _assert_cancel("armory", _hub_shown())


static func _slots(root: Node, out: Array[ItemSlot]) -> void:
	for ch: Node in root.get_children():
		if ch is ItemSlot and (ch as ItemSlot).is_visible_in_tree() and not (ch as ItemSlot).disabled:
			out.append(ch as ItemSlot)
		_slots(ch, out)


func test_item_pickers_and_heister_picker() -> void:
	var opened: Control = await _station(&"armory")
	var ls: LoadoutScreen = opened as LoadoutScreen
	var slots: Array[ItemSlot] = []
	_slots(ls, slots)
	assert_true(slots.has(ls.heister_option), "the heister picker is one of the slots")
	# The primary card opens the workshop and the mask card the mask bench (test_workshop / test_masks).
	slots.erase(ls.primary_slot)
	slots.erase(ls.mask_option)
	assert_true(slots.size() >= 6, "loadout has its picker slots (%d)" % slots.size())
	for slot: ItemSlot in slots:
		var label: String = "picker %s" % slot.caption_key
		slot.grab_focus()
		await wait_frames(1)
		_press(&"ui_accept")
		await wait_frames(3)
		var picker: ItemPicker = slot.picker
		assert_true(picker != null and is_instance_valid(picker), "%s: A on the slot opens its picker" % label)
		if picker == null or not is_instance_valid(picker):
			continue
		await _assert_walk(picker, label)
		await _assert_cancel(label, func() -> bool: return slot.picker == null or not is_instance_valid(slot.picker) \
				or slot.picker.is_queued_for_deletion())
		await wait_frames(2)
		assert_eq(_focus(), slot as Control, "%s: closing returns focus to the slot" % label)


func test_workshop() -> void:
	var opened: Control = await _station(&"armory")
	var ls: LoadoutScreen = opened as LoadoutScreen
	ls.open_workshop()
	await wait_frames(3)
	assert_true(ls.workshop != null, "workshop opens")
	if ls.workshop == null:
		return
	await _assert_walk(ls.workshop, "workshop")
	await _assert_cancel("workshop", func() -> bool: return ls.workshop == null or not ls.workshop.is_visible_in_tree())


func _progression(scene: PackedScene, label: String) -> void:
	var opened: Control = await _station(&"armory")
	var ls: LoadoutScreen = opened as LoadoutScreen
	_flow.open_progression(scene)
	await wait_frames(3)
	await _assert_walk(_flow.progression_screen, label)
	await _assert_cancel(label, _current_is(ls))


func test_skills() -> void:
	await _progression(MenuFlow.SKILLS_SCENE, "skill tree")


## Every skill tree, opened with A on its tab.
func test_skills_every_tree() -> void:
	await _station(&"armory")
	_flow.open_progression(MenuFlow.SKILLS_SCENE)
	await wait_frames(3)
	var st: SkillTreeScreen = _flow.progression_screen as SkillTreeScreen
	for tree: StringName in st.tree_tabs:
		(st.tree_tabs[tree] as Control).grab_focus()
		_press(&"ui_accept")
		await wait_frames(2)
		await _assert_walk(st, "skill tree/%s" % tree)


func test_perks() -> void:
	await _progression(MenuFlow.PERKS_SCENE, "perk deck")


# --- options ------------------------------------------------------------------------------------------------


func test_options_every_tab() -> void:
	var f: MenuFlow = await _new_flow()
	var opts: OptionsScreen = f.options_menu.open()
	await wait_frames(3)
	for t: StringName in OptionsScreen.TABS:
		# Reach the tab button and open it with A (no direct show_tab).
		var tb: Control = opts.tab_buttons[t] as Control
		tb.grab_focus()
		_press(&"ui_accept")
		await wait_frames(3)
		assert_eq(opts.current_tab, t, "A opens tab %s" % t)
		await _assert_walk(opts, "options/%s" % t)
	await _assert_cancel("options", _current_is(f.main_menu))
