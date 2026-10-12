## D-076 pad-only walks through screens the earlier walks skipped: options + keybinds, (more below).
## Real InputEventJoypadButton only (d-pad, A, B, Y); no focus grabs, no direct calls on the subject.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const MAX_STEPS: int = 60


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
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
			OptionsScreen.TAB_CONTROLS]:
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
