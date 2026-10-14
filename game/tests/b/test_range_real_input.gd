## Lead queue: firing range real-input pass (Case File restyle). Real key / pad events through
## Input.parse_input_event, not signal emits: Tab / Start enter aim mode and Tab / Start / Back return,
## the d-pad walks the panel focus chain, Esc leaves, the hint strip's key caps follow the last device,
## and aim mode shows less (loadout panel hidden, right panel shrunk to the readout).
extends TestCase

const SCENE: String = "res://content/range/firing_range.tscn"

var _range: FiringRange = null


func after_each() -> void:
	InteractionPanel.pad_active = false  # pad presses switch the key caps to pad names; do not leak
	if _range != null and is_instance_valid(_range):
		_range.queue_free()
	_range = null
	await wait_frames(2)


func _crew_range() -> FiringRange:
	if not RangeCrewBridge.available():
		skip("CrewController.spawn_for_range not in this tree")
		return null
	_range = (load(SCENE) as PackedScene).instantiate() as FiringRange
	add_child(_range)
	await wait_frames(2)
	await wait_physics_frames(10)
	return _range


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


## Key cap texts of the hint strip, left to right.
func _caps(o: RangeOverlay) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for h: Node in o.hints.get_children():
		if h.is_queued_for_deletion() or h.get_child_count() == 0 or not h.get_child(0) is PanelContainer:
			continue
		out.append((h.get_child(0).get_child(0) as Label).text)
	return out


func test_tab_start_and_back_switch_modes() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	assert_false(r.aim_mode)
	await _key(KEY_TAB)
	assert_true(r.aim_mode, "Tab aims")
	assert_false(r.overlay.interactive)
	await _key(KEY_TAB)
	assert_false(r.aim_mode, "Tab again: back to the panels")
	await _pad(JOY_BUTTON_START)
	assert_true(r.aim_mode, "Start aims")
	await _pad(JOY_BUTTON_BACK)
	assert_false(r.aim_mode, "Back returns to the panels")
	await _pad(JOY_BUTTON_START)
	await _key(KEY_ESCAPE)
	assert_false(r.aim_mode, "Esc in aim mode returns to the panels, it does not leave")


func test_dpad_walks_the_panels_and_esc_leaves() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	var o: RangeOverlay = r.overlay
	o.weapon_option.grab_focus()
	await wait_frames(1)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(get_viewport().gui_get_focus_owner(), o.focus_chain[1], "d-pad down: next control")
	o.exit_button.grab_focus()
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(get_viewport().gui_get_focus_owner(), o.reset_button as Control, "footer: Leave -> Reset")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(get_viewport().gui_get_focus_owner(), o.exit_button as Control, "and back")
	var left: Array[int] = [0]
	r.exit_requested.connect(func() -> void: left[0] += 1)
	await _key(KEY_ESCAPE)
	assert_eq(left[0], 1, "Esc in panel mode leaves the range")


func test_hint_caps_follow_the_device() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	var o: RangeOverlay = r.overlay
	await _key(KEY_SHIFT)
	assert_eq(_caps(o)[0], UiText.t(&"ui.key.tab"), "keyboard: [Tab] Aim")
	assert_has(_caps(o), "Escape", "[Esc] Leave range")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_caps(o)[0], UiText.t(&"ui.key.start"), "pad: [Start] Aim")
	assert_has(_caps(o), "B", "[B] Leave range")
	await _key(KEY_TAB)
	assert_true(r.aim_mode)
	assert_has(_caps(o), UiText.t(&"ui.key.mouse_left"), "aim mode on keyboard: [LMB] Fire")
	assert_has(_caps(o), UiText.t(&"ui.key.mouse_right"), "[RMB] Aim down sights")
	assert_has(_caps(o), "%s/%s" % [InteractionPanel.action_key_text(&"slot_secondary"),
		InteractionPanel.action_key_text(&"slot_primary")], "the keyboard swaps with the slot keys")
	await _pad(JOY_BUTTON_START)
	assert_false(r.aim_mode)


func test_aim_mode_shows_less() -> void:
	var r: FiringRange = await _crew_range()
	if r == null:
		return
	var o: RangeOverlay = r.overlay
	var left: Control = o.get(&"_left_panel") as Control
	var right: Control = o.get(&"_right_panel") as Control
	await wait_frames(2)
	var full: float = right.size.y
	assert_true(left.visible)
	await _key(KEY_TAB)
	await wait_frames(3)
	assert_false(left.visible, "the loadout panel hides while aiming")
	assert_true(right.size.y < full * 0.8, "the right panel shrinks to the readout (%s < %s)" % [right.size.y, full])
	assert_true(o.value_text("ls_result") != "", "last shot still shown")
	await _key(KEY_TAB)
	await wait_frames(3)
	assert_true(left.visible)
	assert_near(right.size.y, full, 1.0, "full height again")
