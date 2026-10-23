## B-PP-1..3 (D-076 playability): hub and payday driven by real InputEvents through the viewport
## (Input.parse_input_event / push_input), never set_bot_intent or direct signal emits.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const SLOT: int = 0


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


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


func _accept() -> void:
	for down: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = &"ui_accept"
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func _hub_flow() -> MenuFlow:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.show_hub()
	await wait_frames(2)
	return f


func test_hub_has_no_duplicate_buttons() -> void:
	var f: MenuFlow = await _hub_flow()
	var texts: Dictionary = {}
	for c: Control in f.hub.focus_chain:
		var b: Button = c as Button
		if b == null or b.text == "":
			continue
		assert_false(texts.has(b.text), "duplicate hub button: " + b.text)
		texts[b.text] = true
	var career: int = 0
	var noto: int = 0
	for c: Control in f.hub.focus_chain:
		var b: Button = c as Button
		if b != null and b.text == UiText.t(&"ui.career.open"):
			career += 1
		if b != null and b.text == UiText.t(&"ui.notoriety.open"):
			noto += 1
	assert_eq(career, 0, "Career side button removed; the Record station opens it")
	assert_eq(noto, 0, "Notoriety side button removed; the Old Press station opens it")
	f.queue_free()
	await wait_frames(1)


func test_hub_cards_fit_720p() -> void:
	var f: MenuFlow = await _hub_flow()
	await wait_frames(2)
	var vis: Rect2 = f.hub.get_viewport().get_visible_rect()
	assert_true(f.hub.focus_chain.size() >= 9)
	for id: Variant in f.hub.station_buttons:
		var b: Button = f.hub.station_button(id as StringName)
		var r: Rect2 = b.get_global_rect()
		assert_true(vis.encloses(r), "station card %s on screen (%s in %s)" % [id, r, vis])
	assert_true(vis.encloses(f.hub.back_button.get_global_rect()), "Main Menu button on screen")
	f.queue_free()
	await wait_frames(1)


func test_click_record_station_opens_career() -> void:
	var f: MenuFlow = await _hub_flow()
	await _click(f.hub.station_button(&"profile"))
	await wait_frames(1)
	assert_true(f.current is CareerScreen, "mouse click on The Record opens Career")
	f.queue_free()
	await wait_frames(1)


func test_keyboard_accept_old_press_opens_notoriety() -> void:
	var f: MenuFlow = await _hub_flow()
	f.hub.station_button(&"notoriety").grab_focus()
	await wait_frames(1)
	await _accept()
	assert_true(f.current is NotorietyScreen, "ui_accept on The Old Press opens Notoriety")
	f.queue_free()
	await wait_frames(1)


func test_payday_card_click_and_urgent_timer() -> void:
	SaveService.delete_profile(SLOT)
	var s: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	add_child(s)
	await wait_frames(1)
	s.show_result(HeistCatalog.sample_result())
	s.show_cards()
	await wait_frames(2)
	assert_false(s.timer_is_urgent(), "not urgent at the start")
	s.tick(s.time_left - 4.0)
	assert_true(s.timer_is_urgent(), "urgent in the last seconds")
	assert_true(s.timer_label.has_theme_color_override(&"font_color"))
	assert_eq(s.picked_index, -1, "still waiting for the player")
	await _click(s.card_views[2])
	assert_eq(s.picked_index, 2, "mouse click picks the clicked card")
	assert_false(s.auto_picked)
	assert_false(s.timer_is_urgent())
	s.queue_free()
	await wait_frames(1)


func _press(action: StringName) -> void:
	for down: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func _focused(c: Control) -> Control:
	return c.get_viewport().gui_get_focus_owner()


## PQ-B-3: d-pad / arrows follow the 2-column grid.
func test_hub_grid_navigation() -> void:
	var f: MenuFlow = await _hub_flow()
	var hub: HubMenu = f.hub
	var ids: Array[StringName] = []
	for s: HubStation in hub.stations.stations:
		ids.append(s.id)
	hub.station_button(ids[0]).grab_focus()
	await wait_frames(1)
	await _press(&"ui_right")
	assert_eq(_focused(hub), hub.station_button(ids[1]) as Control, "right -> card on the right")
	var cols: int = HubMenu.CARD_COLUMNS
	await _press(&"ui_down")
	assert_eq(_focused(hub), hub.station_button(ids[1 + cols]) as Control, "down -> card below")
	await _press(&"ui_left")
	assert_eq(_focused(hub), hub.station_button(ids[cols]) as Control, "left -> card on the left")
	await _press(&"ui_up")
	assert_eq(_focused(hub), hub.station_button(ids[0]) as Control, "up -> card above")
	hub.station_button(ids[cols - 1]).grab_focus()
	await wait_frames(1)
	await _press(&"ui_right")
	assert_eq(_focused(hub), hub.achievements_button as Control, "right of the grid -> profile panel")
	hub.station_button(ids[ids.size() - 1]).grab_focus()
	await wait_frames(1)
	await _press(&"ui_down")
	assert_eq(_focused(hub), hub.back_button as Control, "below the grid -> Main Menu")
	f.queue_free()
	await wait_frames(1)


func _payday_cards() -> PaydayScreen:
	SaveService.delete_profile(SLOT)
	var s: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	add_child(s)
	await wait_frames(1)
	s.show_result(HeistCatalog.sample_result())
	s.show_cards()
	await wait_frames(2)
	return s


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


## PQ-B-5: an accept that arrives right as the cards appear does not pick blind.
func test_payday_input_grace_blocks_blind_pick() -> void:
	var s: PaydayScreen = await _payday_cards()
	assert_true(s.in_input_grace())
	s.card_views[0].grab_focus()
	await _accept()
	assert_eq(s.picked_index, -1, "accept during grace ignored")
	s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
	assert_false(s.in_input_grace())
	s.card_views[0].grab_focus()
	await wait_frames(1)
	await _accept()
	assert_eq(s.picked_index, 0, "accept after grace picks the focused card")
	assert_false(s.auto_picked)
	s.queue_free()
	await wait_frames(1)


## PQ-B-4: number keys pick directly.
func test_payday_number_key_picks() -> void:
	var s: PaydayScreen = await _payday_cards()
	s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
	await _key(KEY_2)
	assert_eq(s.picked_index, 1, "key 2 picks the middle card")
	s.queue_free()
	await wait_frames(1)


## PQ-B-8: focusing a card by d-pad shows its full description (not only a mouse tooltip).
func test_hub_focus_shows_station_detail() -> void:
	var f: MenuFlow = await _hub_flow()
	var hub: HubMenu = f.hub
	hub.station_button(&"board").grab_focus()
	await wait_frames(1)
	await _press(&"ui_right")
	var id: StringName = hub.stations.stations[1].id
	assert_eq(hub.station_detail.text, UiText.t(hub.stations.stations[1].desc_key), "detail follows focus to " + String(id))
	assert_true(hub.station_detail.is_visible_in_tree())
	f.queue_free()
	await wait_frames(1)


## PQ-B-9: the urgent window requests one tick cue per whole second (when a cue id is configured).
func test_payday_urgent_ticks_request_cue() -> void:
	var s: PaydayScreen = await _payday_cards()
	var t: PaydayCardsTable = PaydayCards.table()
	var old_cue: StringName = t.urgent_tick_cue
	t.urgent_tick_cue = &"cue.detect_tick"  # any registered cue
	var got: Array[StringName] = []
	var cb: Callable = func(id: StringName, _p: Vector3, _n: int) -> void: got.append(id)
	EventBus.audio_cue_requested.connect(cb)
	s.tick(s.time_left - t.urgent_time_s - 0.5)
	assert_eq(s.urgent_ticks, 0, "no ticks before the window")
	for i: int in range(3):
		s.tick(1.0)
	assert_eq(s.urgent_ticks, 3)
	assert_eq(got.count(&"cue.detect_tick"), 3)
	await _key(KEY_1)
	s.tick(1.0)
	assert_eq(s.urgent_ticks, 3, "no ticks after a pick")
	EventBus.audio_cue_requested.disconnect(cb)
	t.urgent_tick_cue = old_cue
	s.queue_free()
	await wait_frames(1)


## PQ-B-9: an unregistered cue id (e.g. cue.payday_tick before ENV C ships it) requests nothing.
func test_payday_missing_cue_is_silent() -> void:
	assert_false(PaydayScreen.cue_registered(&"cue.no_such_cue"))
	var s: PaydayScreen = await _payday_cards()
	var t: PaydayCardsTable = PaydayCards.table()
	var old_cue: StringName = t.urgent_tick_cue
	t.urgent_tick_cue = &"cue.no_such_cue"
	var got: Array[StringName] = []
	var cb: Callable = func(id: StringName, _p: Vector3, _n: int) -> void: got.append(id)
	EventBus.audio_cue_requested.connect(cb)
	s.tick(s.time_left - 2.5)
	s.tick(1.0)
	assert_true(s.urgent_ticks > 0)
	assert_eq(got.size(), 0, "no request for a missing cue")
	EventBus.audio_cue_requested.disconnect(cb)
	t.urgent_tick_cue = old_cue
	s.queue_free()
	await wait_frames(1)


## PQ-B-10: LB / RB move along the cards (actions added here when project.godot lacks them yet).
func test_payday_shoulder_buttons_move_focus() -> void:
	var added: Array[StringName] = []
	for a: StringName in [&"ui_payday_prev", &"ui_payday_next"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			added.append(a)
	var s: PaydayScreen = await _payday_cards()
	s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
	s.card_views[0].grab_focus()
	await wait_frames(1)
	await _press(&"ui_payday_next")
	assert_eq(_focused(s), s.card_views[1] as Control, "RB -> next card")
	await _press(&"ui_payday_prev")
	await _press(&"ui_payday_prev")
	assert_eq(_focused(s), s.card_views[s.card_views.size() - 1] as Control, "LB wraps to the last card")
	assert_eq(s.picked_index, -1, "moving does not pick")
	for a: StringName in added:
		InputMap.erase_action(a)
	s.queue_free()
	await wait_frames(1)


## PQ-B-10: the real RB joypad button (when project.godot maps ui_payday_next) moves focus and is consumed.
func test_payday_rb_joypad_button() -> void:
	if not InputMap.has_action(&"ui_payday_next") or InputMap.action_get_events(&"ui_payday_next").is_empty():
		skip("ui_payday_next not mapped in project.godot yet")
		return
	var jb: InputEventJoypadButton = InputMap.action_get_events(&"ui_payday_next")[0] as InputEventJoypadButton
	var s: PaydayScreen = await _payday_cards()
	s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
	s.card_views[0].grab_focus()
	await wait_frames(1)
	var leaked: Array[bool] = [false]
	var probe: PpUnhandledProbe = PpUnhandledProbe.new()
	probe.hit = func() -> void: leaked[0] = true
	add_child(probe)
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = jb.button_index
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)
	assert_eq(_focused(s), s.card_views[1] as Control, "RB button -> next card")
	assert_false(leaked[0], "RB consumed: gameplay (throw/melee) never sees it")
	probe.queue_free()
	s.queue_free()
	await wait_frames(1)


## Records any pressed joypad button that reaches _unhandled_input (stand-in for gameplay input).
class PpUnhandledProbe:
	extends Node
	var hit: Callable

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventJoypadButton and event.is_pressed():
			hit.call()
