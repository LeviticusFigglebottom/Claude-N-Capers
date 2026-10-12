## PQ-B-13 (D-076): heist select -> briefing -> pre-planning -> loadout -> Launch with a gamepad only
## (InputEventJoypadButton d-pad + A, B for back). No mouse, no keyboard, no direct focus grabs: every
## screen's default focus and d-pad neighbours must make the next button reachable.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const MAX_STEPS: int = 40


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
