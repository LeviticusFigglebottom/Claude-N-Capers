## B-PP-1..3 (D-076 playability): hub and payday driven by real InputEvents through the viewport
## (Input.parse_input_event / push_input), never set_bot_intent or direct signal emits.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const SLOT: int = 0


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
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
	await _press(&"ui_down")
	assert_eq(_focused(hub), hub.station_button(ids[3]) as Control, "down -> card below")
	await _press(&"ui_left")
	assert_eq(_focused(hub), hub.station_button(ids[2]) as Control, "left -> card on the left")
	await _press(&"ui_up")
	assert_eq(_focused(hub), hub.station_button(ids[0]) as Control, "up -> card above")
	hub.station_button(ids[1]).grab_focus()
	await wait_frames(1)
	await _press(&"ui_right")
	assert_eq(_focused(hub), hub.achievements_button as Control, "right of the grid -> profile panel")
	hub.station_button(ids[ids.size() - 1]).grab_focus()
	await wait_frames(1)
	await _press(&"ui_down")
	assert_eq(_focused(hub), hub.back_button as Control, "below the grid -> Main Menu")
	f.queue_free()
	await wait_frames(1)
