## Lead D-082 queue item 1: the full loop with real input only. Hub -> Planning -> heist select (Night
## Deposit) -> briefing -> pre-planning -> loadout -> Launch -> live heist -> payday (cards) -> hub, once
## pad-only (d-pad / A) and once mouse + keyboard (arrows / Enter, clicks on the forward buttons).
## Only the heist's end is setup (HeistRuntime.end_heist); finishing a heist by input is out of scope.
## Co-op lobby legs are covered by test_pp_lobby_720p (ENet loopback).
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const HEIST: StringName = &"night_deposit"
const MAX_STEPS: int = 60

var _flow: MenuFlow = null
var _pad_mode: bool = true


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C\'s 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	if _flow != null and is_instance_valid(_flow):
		_flow.call(&"_leave_heist")
		await wait_frames(3)
		_flow.queue_free()
	_flow = null
	await wait_frames(3)


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func _click(c: Control) -> void:
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
	await wait_frames(1)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _ok() -> void:
	if _pad_mode:
		await _pad(JOY_BUTTON_A)
	else:
		await _key(KEY_ENTER)


## Moves focus with the d-pad (pad mode) or arrow keys, turning on dead ends / revisits.
func _nav_to(target: Control, label: String) -> bool:
	await wait_frames(2)
	var pads: Array[JoyButton] = [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT]
	var keys: Array[Key] = [KEY_DOWN, KEY_RIGHT, KEY_UP, KEY_LEFT]
	var d: int = 0
	var seen: Dictionary = {}
	for _i: int in range(MAX_STEPS):
		if _focus() == target:
			return true
		seen[_focus()] = true
		if _pad_mode:
			await _pad(pads[d])
		else:
			await _key(keys[d])
		if seen.has(_focus()):
			d = (d + 1) % pads.size()
	assert_eq(_focus(), target, "%s reachable (%s; focus on %s)" % [label, "pad" if _pad_mode else "keys", _focus()])
	return _focus() == target


## Forward button: pad/keys focus + accept, or (mouse mode) a click.
func _press(target: Control, label: String) -> bool:
	if not _pad_mode:
		var vis: Rect2 = target.get_viewport().get_visible_rect()
		assert_true(vis.encloses(target.get_global_rect()), "%s on screen for the mouse" % label)
		await _click(target)
		return true
	if not await _nav_to(target, label):
		return false
	await _ok()
	return true


func _loop() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	_flow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(_flow)
	await wait_frames(2)
	assert_true(await _nav_to(_flow.main_menu.safehouse_button, "Safehouse"))
	await _ok()
	assert_eq(_flow.current, _flow.hub as Control, "hub")
	assert_true(await _nav_to(_flow.hub.station_button(&"planning"), "Planning"))
	await _ok()
	var hs: HeistSelect = _flow.heist_select
	assert_eq(_flow.current, hs as Control, "heist select")
	var idx: int = HeistCatalog.ids().find(HEIST)
	assert_true(idx >= 0, "night_deposit in the catalog")
	if idx < 0:
		return
	assert_true(await _nav_to(hs.heist_buttons[idx], "Night Deposit"))
	await _ok()
	assert_eq(hs.selected_heist_id(), HEIST, "Night Deposit selected")
	assert_true(await _press(hs.next_button, "Next"))
	assert_true(_flow.current is BriefingScreen, "briefing")
	if not _flow.current is BriefingScreen:
		return
	assert_true(await _press(_flow.briefing_screen.continue_button, "briefing Continue"))
	assert_true(_flow.current is PreplanningScreen, "pre-planning")
	if not _flow.current is PreplanningScreen:
		return
	assert_true(await _press(_flow.preplanning_screen.confirm_button, "pre-planning Confirm"))
	assert_true(_flow.current is LoadoutScreen, "loadout")
	if not _flow.current is LoadoutScreen:
		return
	assert_true(await _press(_flow.loadout_screen.launch_button, "Launch"))
	assert_true(await wait_until(func() -> bool: return _flow.runtime != null, 60.0), "Night Deposit launched")
	if _flow.runtime == null:
		return
	await wait_frames(10)
	_flow.runtime.call(&"end_heist", true, [Net.local_slot()] as Array[int])  # setup: the heist ends
	var pd: Array[PaydayScreen] = [null]
	assert_true(await wait_until(func() -> bool:
		for n: Node in get_tree().root.find_children("*", "PaydayScreen", true, false):
			if (n as PaydayScreen).is_visible_in_tree():
				pd[0] = n as PaydayScreen
				return true
		return false, 10.0), "payday")
	var s: PaydayScreen = pd[0]
	if s == null:
		return
	await wait_frames(3)
	assert_true(_focus() != null, "payday gives focus to the pad / keys")
	assert_true(await _press(s.continue_button, "payday Continue"))
	if s.cards_stage:
		s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
		assert_true(await _press(s.card_views[0], "card 1"))
		assert_eq(s.picked_index, 0, "card picked")
		await wait_frames(2)
		assert_true(await _press(s.continue_button, "cards Continue"))
	assert_true(await wait_until(func() -> bool: return _flow.current == (_flow.hub as Control) and _flow.visible, 10.0),
			"back in the hub")
	await wait_frames(3)
	assert_true(_focus() != null and _flow.hub.is_ancestor_of(_focus()), "hub has focus again: %s" % _focus())


func test_full_loop_pad_only() -> void:
	if UiNav.global_class(&"HeistLauncher") == null:
		skip("no HeistLauncher")
		return
	_pad_mode = true
	await _loop()


func test_full_loop_mouse_keyboard() -> void:
	if UiNav.global_class(&"HeistLauncher") == null:
		skip("no HeistLauncher")
		return
	_pad_mode = false
	await _loop()
