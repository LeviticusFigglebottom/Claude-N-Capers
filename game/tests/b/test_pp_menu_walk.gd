## PQ-B-7 (D-076): a player can walk main menu -> hub -> Planning (heist select) -> briefing ->
## pre-planning -> loadout -> Launch with real mouse clicks and keyboard only. The actual level load
## is intercepted at the loadout's launch_requested (covered by the launch tests).
extends TestCase

const SLOT: int = 0


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func _click(c: Control) -> void:
	assert_true(c != null and c.is_visible_in_tree(), "click target visible")
	if c == null:
		return
	var vis: Rect2 = c.get_viewport().get_visible_rect()
	assert_true(vis.encloses(c.get_global_rect()), "%s on screen (%s in %s)" % [c.get_path(), c.get_global_rect(), vis])
	var pos: Vector2 = c.get_global_rect().get_center()
	var vp: Viewport = c.get_viewport()
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	vp.push_input(m, true)
	await wait_frames(1)
	for down: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = pos
		e.global_position = pos
		vp.push_input(e, true)
		await wait_frames(1)
	await wait_frames(2)


func _accept() -> void:
	for down: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = &"ui_accept"
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func test_menu_to_launch_by_real_input() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(2)
	f.show_home()
	await wait_frames(2)
	assert_true(f.current is MainMenu, "starts on the main menu")
	f.main_menu.safehouse_button.grab_focus()
	await wait_frames(1)
	await _accept()
	assert_eq(f.current, f.hub as Control, "Enter on Safehouse opens the hub")
	await _click(f.hub.station_button(&"planning"))
	assert_eq(f.current, f.heist_select as Control, "Planning card opens heist select")
	await _click(f.heist_select.heist_buttons[0])
	await _click(f.heist_select.next_button)
	assert_true(f.current is BriefingScreen, "Next opens the briefing")
	await _click(f.briefing_screen.continue_button)
	assert_true(f.current is PreplanningScreen, "Continue opens pre-planning")
	await _click(f.preplanning_screen.confirm_button)
	assert_true(f.current is LoadoutScreen, "Confirm opens the loadout")
	var ls: LoadoutScreen = f.loadout_screen
	var launched: Array[bool] = [false]
	for c: Dictionary in ls.launch_requested.get_connections():
		ls.launch_requested.disconnect(c["callable"] as Callable)
	ls.launch_requested.connect(func(_l: Loadout) -> void: launched[0] = true)
	await _click(ls.launch_button)
	assert_true(launched[0], "Launch clicked -> launch_requested")
	f.queue_free()
	await wait_frames(2)
