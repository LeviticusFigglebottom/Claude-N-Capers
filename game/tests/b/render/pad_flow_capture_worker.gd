## Worker for pad_flow_capture.gd (LEAD r309): the un-hidden flow with a gamepad only. Every menu step is a real
## InputEventJoypadButton / JoypadMotion (d-pad to move, A to accept, B to back, the right stick to scroll the briefing);
## no focus grabs. In the heist the crew is placed facing the first props (stated shortcut, as ah_hud_capture) and
## uses the pad's interact / mask buttons. "PAD ISSUE" lines are findings; "PAD" lines report.
extends "res://tests/b/render/ah_hud_capture_worker.gd"

var _issues: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_heist = StringName(args[1]) if args.size() > 1 else &"rolling_thunder"
	_out = (args[0] if args.size() > 0 else OS.get_user_data_dir() + "/pad_flow").path_join(String(_heist))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	SaveService.root_dir = "user://pad_flow_%d" % OS.get_process_id()
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _frames(30)
	await _pad(JOY_BUTTON_DPAD_DOWN)  # the first pad input: glyphs switch to the pad
	await _pad(JOY_BUTTON_DPAD_UP)
	await _check_focus("main menu")
	await _shot("main_menu", 10)
	await _board()
	await _planning()
	if not await _wait_runtime():
		return
	await get_tree().create_timer(4.0).timeout
	_crew = _rt.crew_controller(Net.local_slot()) as Node3D
	_crew.set(&"stealth_hidden", true)  # stated shortcut, as ah_hud_capture
	await _heist_prompts()
	await _payday()
	print("PAD DONE issues=%d" % _issues)
	get_tree().quit(0)


# --- Menus --------------------------------------------------------------------------------------------------------

func _board() -> void:
	if not await _pad_press(_flow.main_menu.station_buttons[&"board"] as Control, "main menu: The Board"):
		return
	await _frames(10)
	_expect(_flow.board_screen, "the Board")
	var b: BoardScreen = _flow.board_screen
	var pin: Control = null
	for i: int in range(b.contracts.size()):
		if StringName(b.contracts[i].get("heist_id", &"")) == _heist and i < b.map_view.pins.size():
			pin = b.map_view.pins[i]
	if pin == null:
		_issue("board", "no %s contract on the Board this bucket" % _heist)
	elif await _pad_nav_to(pin, "board: the %s pin" % _heist):
		await _pad(JOY_BUTTON_A)
		await _frames(6)
		print("PAD board selected=%s take focusable=%s" % [b.contracts[b.selected_slot].get("heist_id"),
				b.take_button.focus_mode != Control.FOCUS_NONE])
	await _shot("board", 10)
	await _pad(JOY_BUTTON_B)
	await _frames(10)
	_expect(_flow.main_menu, "B from the Board: the main menu")


func _planning() -> void:
	if not await _pad_press(_flow.main_menu.station_buttons[&"planning"] as Control, "main menu: Planning Table"):
		return
	await _frames(10)
	_expect(_flow.heist_select, "heist select")
	var hs: HeistSelect = _flow.heist_select
	var entries: Array = hs.get(&"_entries") as Array
	var row: Control = null
	for i: int in range(entries.size()):
		if StringName((entries[i] as Dictionary)["id"]) == _heist:
			row = hs.heist_buttons[i]
	if row == null:
		_issue("select", "%s not offered (apply the un-hide)" % _heist)
		get_tree().quit(1)
		return
	if await _pad_nav_to(row, "select: the %s row" % _heist):
		await _pad(JOY_BUTTON_A)
	if hs.selected_heist_id() != _heist:
		_issue("select", "A on the row did not select it (%s)" % hs.selected_heist_id())
	await _shot("heist_select", 10)
	await _pad_press(hs.next_button, "select: Next")
	await _frames(20)
	_expect(_flow.briefing_screen, "briefing")
	var br: BriefingScreen = _flow.briefing_screen
	await _check_focus("briefing")
	await _shot("briefing_top", 10)
	if br.intel_overflows():
		print("PAD briefing more_below=%s" % br.more_below.text)
		await _stick(JOY_AXIS_RIGHT_Y, 1.0)
		await get_tree().create_timer(0.6).timeout
		await _stick(JOY_AXIS_RIGHT_Y, 0.0)
		if br.intel_scroll.scroll_vertical <= 0:
			_issue("briefing", "the right stick did not scroll the intel column")
		await _shot("briefing_scrolled", 10)
	else:
		print("PAD briefing: the intel column fits at this size")
	await _pad_press(br.continue_button, "briefing: Continue")
	await _frames(20)
	_expect(_flow.preplanning_screen, "pre-planning")
	await _check_focus("pre-planning")
	await _shot("preplanning", 10)
	await _pad_press(_flow.preplanning_screen.confirm_button, "pre-planning: Confirm")
	await _frames(20)
	_expect(_flow.loadout_screen, "loadout")
	await _check_focus("loadout")
	await _shot("loadout", 10)
	await _pad_press(_flow.loadout_screen.launch_button, "loadout: Launch")


# --- The heist -----------------------------------------------------------------------------------------------------

func _heist_prompts() -> void:
	await _pad(JOY_BUTTON_DPAD_DOWN)  # pad stays the last device after the load
	_report("start")
	_glyph_check("start")
	await _shot("heist_start", 10)
	if _rt.start_mode == HeistRuntime.START_CIVILIAN:
		for n: Node in _rt.find_children("*", "GearPickup", true, false):
			var g: GearPickup = n as GearPickup
			if g == null or not g.is_enabled():
				continue
			var target: Vector3 = g.global_position + Vector3(0, 0.3, 0)
			for i: int in 8:
				_crew.global_position = Vector3(target.x, _crew.global_position.y, target.z) \
						+ Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0) * 1.3
				await _place_facing(target)
				if _prompt_text() != "":
					break
			_report("gear")
			_glyph_check("gear")
			await _shot("gear_prompt", 10)
			await _pad_hold(_pad_of(&"interact"), Tweak.interaction().item_pickup_s + 0.6)
			await get_tree().create_timer(1.0).timeout
			break
	_report("before mask")
	_glyph_check("mask hint")
	await _shot("mask_hint", 10)
	await _pad_hold(_pad_of(&"mask_up"), 2.6)
	await get_tree().create_timer(1.0).timeout
	print("PAD masked=%s" % _crew.get(&"player_mode"))
	var seen: Dictionary = {}
	for c: InteractableComponent in _nearest_interactables(6):
		if seen.has(c.prompt_key) or seen.size() >= 3:
			continue
		await _place_facing(c.global_position)
		if _prompt_text() == "":
			continue
		seen[c.prompt_key] = true
		_report("prompt %s" % c.prompt_key)
		_glyph_check(String(c.prompt_key))
		await _shot("prompt_%d" % seen.size(), 10)


func _nearest_interactables(n: int) -> Array[InteractableComponent]:
	var out: Array[InteractableComponent] = []
	for node: Node in _rt.find_children("*", "InteractableComponent", true, false):
		var c: InteractableComponent = node as InteractableComponent
		if c != null and c.enabled and c.is_inside_tree():
			out.append(c)
	var at: Vector3 = _crew.global_position
	out.sort_custom(func(a: InteractableComponent, b: InteractableComponent) -> bool:
		return a.global_position.distance_to(at) < b.global_position.distance_to(at))
	return out.slice(0, n)


func _payday() -> void:
	_rt.end_heist(true, [Net.local_slot()] as Array[int])
	await get_tree().create_timer(4.0).timeout
	var pd: Node = null
	for n: Node in get_tree().root.find_children("*", "", true, false):
		if n is Control and (n as Control).is_visible_in_tree() and n.get(&"continue_button") is Button \
				and n.has_signal(&"continue_pressed"):
			pd = n
	if pd == null:
		_issue("payday", "no payday screen")
		return
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _check_focus("payday")
	_glyph_check("payday")
	await _shot("payday", 20)
	await _pad_press(pd.get(&"continue_button") as Control, "payday: Continue")
	await get_tree().create_timer(2.0).timeout
	await _check_focus("card pick")
	await _shot("card_pick", 10)
	await _pad(JOY_BUTTON_A)  # PD2's card drop: A on the focused card
	await get_tree().create_timer(3.0).timeout
	await _shot("card_revealed", 10)
	if (pd.get(&"continue_button") as Control).is_visible_in_tree():
		await _pad_press(pd.get(&"continue_button") as Control, "card pick: Continue")
	await get_tree().create_timer(3.0).timeout
	print("PAD after payday: current=%s" % (_flow.current.name if _flow.current != null else "null"))
	await _check_focus("after payday")
	await _shot("after_payday", 20)
	await _pad(JOY_BUTTON_B)
	await _frames(10)
	print("PAD after B: current=%s" % (_flow.current.name if _flow.current != null else "null"))
	await _shot("after_back", 10)


# --- Pad input -----------------------------------------------------------------------------------------------------

func _pad(button: JoyButton) -> void:
	await _pad_hold(button, 0.0)


func _pad_hold(button: JoyButton, hold_s: float) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	if hold_s > 0.0:
		await get_tree().create_timer(hold_s).timeout
	else:
		await _frames(2)
	var u: InputEventJoypadButton = e.duplicate() as InputEventJoypadButton
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


func _stick(axis: JoyAxis, value: float) -> void:
	var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = value
	Input.parse_input_event(m)
	await _frames(2)


func _pad_of(action: StringName) -> JoyButton:
	for ev: InputEvent in InputMap.action_get_events(action):
		var j: InputEventJoypadButton = ev as InputEventJoypadButton
		if j != null:
			return j.button_index
	_issue("bindings", "no pad button for %s" % action)
	return JOY_BUTTON_INVALID


## D-pad until `target` has focus (turns on a dead end or a revisit, as test_pp_pad_walks).
func _pad_nav_to(target: Control, label: String) -> bool:
	await _frames(2)
	var dirs: Array[JoyButton] = [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT]
	var d: int = 0
	var seen: Dictionary = {}
	for _i: int in range(MAX_STEPS):
		if _focus() == target:
			return true
		seen[_focus()] = true
		await _pad(dirs[d])
		if seen.has(_focus()):
			d = (d + 1) % dirs.size()
	_issue("nav", "%s not reachable by the d-pad (focus on %s)" % [label, _focus()])
	return false


func _pad_press(target: Control, label: String) -> bool:
	if target == null or not await _pad_nav_to(target, label):
		return false
	await _pad(JOY_BUTTON_A)
	return true


# --- Checks --------------------------------------------------------------------------------------------------------

func _expect(screen: Control, label: String) -> void:
	if _flow.current != screen:
		_issue("flow", "expected %s, on %s" % [label, _flow.current.name if _flow.current != null else "null"])


func _check_focus(label: String) -> void:
	await _frames(4)
	if _focus() == null or not _focus().is_visible_in_tree():
		_issue(label, "no visible focus for the pad")
	if not InteractionPanel.pad_active:
		_issue(label, "glyphs are not on the pad")


## Keyboard caps (a lone letter other than the pad's A/B/X/Y, or Enter / Escape) in visible keycaps.
func _glyph_check(label: String) -> void:
	var pad_caps: Array[String] = []
	for k: String in ["a", "b", "x", "y", "lb", "rb", "ls", "rs", "lt", "rt", "back", "start"]:
		pad_caps.append(UiText.t(StringName("ui.key.pad." + k)))
	for n: Node in get_tree().root.find_children("*", "Label", true, false):
		var l: Label = n as Label
		var cap: PanelContainer = l.get_parent() as PanelContainer if l != null else null
		if cap == null or not l.is_visible_in_tree() \
				or not [UiBuild.KEYCAP, UiBuild.KEYCAP_ROUND].has(cap.theme_type_variation):
			continue
		if not pad_caps.has(l.text) and not l.text.begins_with("D-pad"):
			_issue(label, "keyboard cap '%s' at %s" % [l.text, l.get_path()])


func _issue(tag: String, what: String) -> void:
	_issues += 1
	print("PAD ISSUE [%s] %s" % [tag, what])
