## PQ-B-13 (D-076): heist select -> briefing -> pre-planning -> loadout -> Launch with a gamepad only
## (InputEventJoypadButton d-pad + A, B for back). No mouse, no keyboard, no direct focus grabs: every
## screen's default focus and d-pad neighbours must make the next button reachable.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const MAX_STEPS: int = 40


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C\'s 3D safehouse at the contract path: these drive the 2D hub
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


func test_select_to_launch_gamepad_only() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	f.show_hub()
	await wait_frames(2)
	assert_true(_focus() != null, "hub has default focus for the pad")
	assert_true(await _nav_to(f.hub.station_button(&"planning"), "Planning card"))
	await _pad(JOY_BUTTON_A)
	assert_eq(f.current, f.heist_select as Control, "A on Planning")
	assert_true(await _nav_to(f.heist_select.next_button, "heist select Next"))
	await _pad(JOY_BUTTON_A)
	assert_true(f.current is BriefingScreen, "A on Next opens the briefing")
	await _pad(JOY_BUTTON_B)
	assert_eq(f.current, f.heist_select as Control, "B backs out of the briefing")
	assert_true(await _nav_to(f.heist_select.next_button, "Next again"))
	await _pad(JOY_BUTTON_A)
	assert_true(f.current is BriefingScreen, "briefing again")
	if not f.current is BriefingScreen:
		return
	assert_true(await _nav_to(f.briefing_screen.continue_button, "briefing Continue"))
	await _pad(JOY_BUTTON_A)
	assert_true(f.current is PreplanningScreen, "A on Continue opens pre-planning")
	assert_true(await _nav_to(f.preplanning_screen.confirm_button, "pre-planning Confirm"))
	await _pad(JOY_BUTTON_A)
	assert_true(f.current is LoadoutScreen, "A on Confirm opens the loadout")
	var ls: LoadoutScreen = f.loadout_screen
	var launched: Array[bool] = [false]
	for c: Dictionary in ls.launch_requested.get_connections():
		ls.launch_requested.disconnect(c["callable"] as Callable)
	ls.launch_requested.connect(func(_l: Loadout) -> void: launched[0] = true)
	assert_true(await _nav_to(ls.launch_button, "loadout Launch"))
	await _pad(JOY_BUTTON_A)
	assert_true(launched[0], "A on Launch")
	f.queue_free()
	await wait_frames(2)


## PQ-B-15: from the armory loadout, every sub-screen (skills, perk deck, masks, workshop) opens with
## d-pad + A and B returns to the loadout.
func test_loadout_subscreens_gamepad_only() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	f.show_hub()
	await wait_frames(1)
	f.open_station(&"armory")  # setup only; the subject is the pad navigation below
	await wait_frames(2)
	var ls: LoadoutScreen = f.loadout_screen
	assert_true(f.current == (ls as Control))
	var subs: Array[Array] = [
		[ls.skills_button, "skills", func() -> bool: return f.current is SkillTreeScreen],
		[ls.perks_button, "perk deck", func() -> bool: return f.current is PerkDeckScreen],
		[ls.mask_option, "masks", func() -> bool: return f.current is MaskScreen],
		[ls.workshop_button, "workshop", func() -> bool:
			return ls.workshop != null and is_instance_valid(ls.workshop) and ls.workshop.is_visible_in_tree()],
	]
	for sub: Array in subs:
		var b: Button = sub[0] as Button
		var label: String = sub[1] as String
		var opened: Callable = sub[2] as Callable
		if not await _nav_to(b, label + " button"):
			continue
		await _pad(JOY_BUTTON_A)
		await wait_frames(2)
		assert_true(opened.call(), "A opens " + label)
		assert_true(_focus() != null, label + " gives the pad a focused control")
		await _pad(JOY_BUTTON_B)
		await wait_frames(3)
		assert_true(f.current == (ls as Control) and not opened.call(), "B returns from %s to the loadout" % label)
		assert_true(_focus() != null, "focus restored after leaving " + label)
	f.queue_free()
	await wait_frames(2)


## PQ-B-26: the Board with the pad only: a pin has default focus, d-pad moves to Take, A takes the
## contract (briefing opens), B on the briefing returns to the Board.
func test_board_take_contract_gamepad_only() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	f.show_hub()
	await wait_frames(1)
	assert_true(await _nav_to(f.hub.station_button(&"board"), "Board card"))
	await _pad(JOY_BUTTON_A)
	assert_eq(f.current, f.board_screen as Control, "A opens the Board")
	await wait_frames(2)
	assert_true(_focus() != null, "Board gives the pad a focused control")
	# KR-6: pins sit where the time-rotating contracts put them, so a blind d-pad walk could miss Take.
	# The designed pad path: A on the focused pin selects that contract and moves focus to Take.
	assert_true(_focus() is BoardPin, "default focus on a pin")
	await _pad(JOY_BUTTON_A)
	assert_eq(_focus(), f.board_screen.take_button as Control, "A on a pin jumps to Take")
	assert_true(await _nav_to(f.board_screen.take_button, "Take"))
	assert_false(f.board_screen.take_button.disabled, "a contract is selected")
	await _pad(JOY_BUTTON_A)
	assert_true(f.current is BriefingScreen, "A on Take opens the briefing")
	await _pad(JOY_BUTTON_B)
	assert_eq(f.current, f.board_screen as Control, "B returns to the Board")
	f.queue_free()
	await wait_frames(2)


## PQ-B-26: Notoriety with the pad only: A on Rank up, A on Confirm, then d-pad to the 2nd reward
## choice and A picks it (saved).
func test_notoriety_rank_up_and_reward_pick_gamepad_only() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.notoriety = 4
	p.xp = XpCurve.xp_for_level(100)
	p.level = 100
	p.cash = Notoriety.cost_for(5)
	Notoriety.clear_cache()
	var s: NotorietyScreen = (load("res://content/ui/notoriety/notoriety_screen.tscn") as PackedScene).instantiate()
	s.profile_slot = SLOT
	s.setup(p)
	add_child(s)
	await wait_frames(2)
	assert_true(await _nav_to(s.rank_up_button, "Rank up"))
	await _pad(JOY_BUTTON_A)
	assert_true(s.is_confirming(), "A opens the confirm")
	await wait_frames(1)
	assert_true(await _nav_to(s.confirm_button, "Confirm"))
	await _pad(JOY_BUTTON_A)
	assert_eq(p.notoriety, 5, "A confirms")
	await wait_frames(2)
	assert_eq(s.choice_buttons.size(), 3)
	var second: StringName = s.choice_buttons.keys()[1] as StringName
	assert_true(await _nav_to(s.choice_buttons[second] as Control, "2nd reward"))
	await _pad(JOY_BUTTON_A)
	assert_eq(p.notoriety_choices.get(5), second, "A picks the focused reward")
	assert_eq(SaveService.load_profile(SLOT).notoriety_choices.get(5), second, "saved")
	s.queue_free()
	await wait_frames(2)
