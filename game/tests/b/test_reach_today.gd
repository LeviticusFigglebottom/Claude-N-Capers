## LEAD r229 reach pass: everything new today is reachable and labelled from the pad and the keyboard.
## * D-126 secondary picker: every tile (locked ones too) takes d-pad focus and previews; a locked tile can't be picked;
##   every tile has a class glyph and a name, locked ones a lock line.
## * "Show tips again": d-pad down from the Controls tab reaches it, A opens the confirm on Cancel, left/right move
##   between Cancel / Confirm, B closes it.
## * D-128 ring colours stay three distinct states in every accessibility palette.
## * The scoped prompt dock shows the pad's button when the pad is active and still fits the margin.
extends TestCase

const LOADOUT_SCENE: PackedScene = preload("res://content/ui/menus/loadout.tscn")
const OPTIONS_SCENE: PackedScene = preload("res://content/ui/menus/options_screen.tscn")
const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	GameSettings.root_dir = BTestUtil.settings_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
	GameSettings.root_dir = GameSettings.DEFAULT_ROOT_DIR
	InteractionPanel.pad_active = false


func _press(action: StringName) -> void:
	for down: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = action
		e.pressed = down
		get_viewport().push_input(e)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_secondary_picker_walks_every_tile() -> void:
	SaveService.delete_profile(0)
	var s: LoadoutScreen = LOADOUT_SCENE.instantiate() as LoadoutScreen
	s.setup(PlayerProfile.new_default())
	add_child(s)
	await wait_frames(1)
	var picker: ItemPicker = s.weapon_option.open_picker()
	await wait_frames(3)
	var tiles: Array[Button] = picker.tiles
	assert_true(tiles.size() >= 17, "the whole slot: %d tiles" % tiles.size())
	var previewed: Array[int] = []
	picker.previewed.connect(func(i: int) -> void: previewed.append(i))
	tiles[0].grab_focus()
	await wait_frames(1)
	var seen: Dictionary = {}
	for _row: int in range(tiles.size()):
		for _col: int in range(ItemPicker.COLUMNS):
			seen[_focus()] = true
			_press(&"ui_right")
			await wait_frames(1)
		_press(&"ui_down")
		await wait_frames(1)
		for _col: int in range(ItemPicker.COLUMNS):
			_press(&"ui_left")
			await wait_frames(1)
	for t: Button in tiles:
		assert_true(seen.has(t), "the d-pad reaches %s" % t.name)
		assert_eq(t.focus_mode, Control.FOCUS_ALL, "focusable")
		assert_true(t.find_children("*", "HubStationIcon", true, false).size() > 0, "a class glyph")
		var labels: Array[Node] = t.find_children("*", "Label", true, false)
		assert_true(labels.size() > 0 and (labels[0] as Label).text != "", "a name")
		if t.disabled:
			assert_true(t.find_child("Lock", true, false) != null, "a locked tile says why")
	assert_true(previewed.size() >= tiles.size() - 1, "focus previews each tile (%d)" % previewed.size())
	var marshal: int = -1
	for i: int in range(tiles.size()):
		if StringName(s.weapon_option.get_item_metadata(i)) == &"weapon.marshal_357":
			marshal = i
	tiles[marshal].grab_focus()
	await wait_frames(2)
	assert_eq(s.stats_weapon_label.text.to_lower(), UiText.t(UiText.item_key(&"weapon.marshal_357")).to_lower(),
			"the stat panel follows a focused locked tile")
	var locked: int = -1
	for i: int in range(tiles.size()):
		if tiles[i].disabled:
			locked = i
			break
	var picks: Array[int] = []
	picker.picked.connect(func(i: int) -> void: picks.append(i))
	tiles[locked].grab_focus()
	_press(&"ui_accept")
	await wait_frames(2)
	assert_eq(picks.size(), 0, "A on a locked tile picks nothing")
	picker.close()
	s.queue_free()
	await wait_frames(1)


func test_show_tips_again_by_pad() -> void:
	OnboardingTips.persist = false
	OnboardingTips.mark_seen(&"casing")
	var o: OptionsScreen = OPTIONS_SCENE.instantiate() as OptionsScreen
	o.settings = GameSettings.new()
	o.save_on_apply = false
	add_child(o)
	await wait_frames(2)
	(o.tab_buttons[OptionsScreen.TAB_CONTROLS] as Control).grab_focus()
	var steps: int = 0
	while _focus() != o.tips_button and steps < 40:
		_press(&"ui_down")
		await wait_frames(1)
		steps += 1
	assert_eq(_focus(), o.tips_button, "d-pad down reaches Show again (%d steps)" % steps)
	assert_true(o.tips_button.text != "" and o.find_child("Row_tips", true, false) != null, "labelled row")
	_press(&"ui_accept")
	await wait_frames(2)
	assert_true(o.is_tips_confirming())
	assert_eq(_focus(), o.tips_cancel_button as Control, "Cancel first")
	_press(&"ui_right")
	await wait_frames(1)
	assert_eq(_focus(), o.tips_confirm_button as Control, "right: Confirm")
	_press(&"ui_left")
	await wait_frames(1)
	assert_eq(_focus(), o.tips_cancel_button as Control, "left: Cancel")
	_press(&"ui_cancel")
	await wait_frames(2)
	assert_false(o.is_tips_confirming(), "B closes")
	assert_eq(OnboardingTips.seen_ids().size(), 1, "nothing reset")
	o.queue_free()
	await wait_frames(1)
	OnboardingTips.reset()
	OnboardingTips.persist = true


func test_ring_states_distinct_in_every_palette() -> void:
	var palettes: HudPaletteSet = HudPaletteSet.load_default()
	for p: HudPalette in palettes.palettes:
		var cols: Array[Color] = [p.detection_suspicious, p.detection_alert, p.detection_detected]
		for i: int in range(3):
			for j: int in range(i + 1, 3):
				assert_false(cols[i].is_equal_approx(cols[j]), "%s: ring states %d / %d differ" % [p.id, i, j])


func test_scoped_dock_with_pad_glyph() -> void:
	InteractionPanel.pad_active = true
	var cam: Camera3D = Camera3D.new()
	add_child(cam)
	cam.current = true
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.size = Vector2(1920, 1080)
	await wait_frames(1)
	hud.bind(model)
	model.interaction = {"text_key": &"ui.prompt.fix_drill", "args": {}, "progress": 0.0, "blocked_reason": &""}
	model.scope_ring = Rect2(465, 43, 994, 994)
	model.scoped_ads = true
	await wait_frames(3)
	var r: Rect2 = hud.interaction.get_global_rect()
	assert_true(r.position.x >= 1459.0 and r.end.x <= 1920.5, "docked in the margin: %s" % r)
	var expect: String = InteractionPanel.action_key_text(InteractionPanel.INTERACT_ACTION)
	assert_ne(expect, "F", "the pad names its own button (%s)" % expect)
	assert_eq(hud.interaction.prompt.cap_label.text, expect, "the docked prompt shows the pad button")
	assert_true(hud.interaction.plated, "on its plate")
	InteractionPanel.pad_active = false
	hud.queue_free()
	model.queue_free()
	cam.queue_free()
	await wait_frames(2)
