## PQ-B-12 (D-076): real-input playthrough of the in-heist B UI on the mock model: interaction
## prompt shows the key that is really bound (and that key really fires `interact`), carried bag +
## secured-loot toast are on screen at 720p, the Tab scoreboard follows the real key, and the mission
## end (payday summary -> cards -> Continue) is finished with keyboard only.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")
const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const SLOT: int = 0

var _hud: Hud
var _model: MockHudModel


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	_model = MockHudModel.new()
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	await wait_frames(1)


static func _first_key(action: StringName) -> Key:
	for ev: InputEvent in InputMap.action_get_events(action):
		var k: InputEventKey = ev as InputEventKey
		if k != null:
			return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	return KEY_NONE


func _key(code: Key, down: bool) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	await wait_frames(2)


func _on_screen(c: Control, what: String) -> void:
	var vis: Rect2 = c.get_viewport().get_visible_rect().grow(1.0)
	assert_true(c.is_visible_in_tree(), what + " visible")
	assert_true(vis.encloses(c.get_global_rect()), "%s on screen at 720p: %s" % [what, c.get_global_rect()])


func test_interaction_prompt_matches_real_binding() -> void:
	_model.interaction = {"text_key": &"ui.prompt.interact", "args": {}, "progress": 0.0, "blocked_reason": &""}
	await wait_frames(1)
	var code: Key = _first_key(&"interact")
	assert_ne(code, KEY_NONE, "interact has a keyboard binding")
	assert_true(_hud.interaction.prompt_label.text.contains(OS.get_keycode_string(code)), "prompt names the bound key")
	_on_screen(_hud.interaction, "interaction prompt")
	await _key(code, true)
	assert_true(Input.is_action_pressed(&"interact"), "pressing the shown key fires interact")
	await _key(code, false)
	assert_false(Input.is_action_pressed(&"interact"))
	_model.interaction = {"text_key": &"ui.prompt.pick_lock", "args": {}, "progress": 0.5, "blocked_reason": &""}
	await wait_frames(1)
	assert_true(_hud.interaction.progress_bar.visible, "hold progress shown")
	_model.interaction = {}
	await wait_frames(1)
	assert_false(_hud.interaction.visible, "prompt hides when nothing to interact with")


func test_bag_and_loot_hud_on_screen() -> void:
	_model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
	await wait_frames(1)
	_on_screen(_hud.status.bag_label, "carried bag")
	EventBus.loot_secured.emit(1, &"loot.jewelry", 1000)
	await wait_frames(1)
	assert_eq(_hud.secured_bags, 1)
	_on_screen(_hud.toast_label, "secured toast")
	_model.carried_bag = {}
	await wait_frames(1)
	assert_false(_hud.status.bag_label.visible, "bag line hides after securing")


func test_scoreboard_follows_real_key() -> void:
	var code: Key = _first_key(&"scoreboard")
	if code == KEY_NONE:
		skip("scoreboard has no keyboard binding")
		return
	await _key(code, true)
	await wait_frames(1)
	assert_true(_hud.scoreboard.visible or _hud.scoreboard.is_toggle_mode(), "held key shows the scoreboard")
	if _hud.scoreboard.visible:
		_on_screen(_hud.scoreboard, "scoreboard")
	await _key(code, false)
	await wait_frames(1)
	if not _hud.scoreboard.is_toggle_mode():
		assert_false(_hud.scoreboard.visible, "released key hides it")


func test_mission_end_keyboard_only() -> void:
	SaveService.delete_profile(SLOT)
	var s: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	add_child(s)
	await wait_frames(1)
	s.show_result(HeistCatalog.sample_result())
	await wait_frames(2)
	_on_screen(s.continue_button, "payday Continue")
	var done: Array[bool] = [false]
	s.continue_pressed.connect(func() -> void: done[0] = true)
	s.continue_button.grab_focus()
	await wait_frames(1)
	await _key(KEY_ENTER, true)
	await _key(KEY_ENTER, false)
	assert_true(s.cards_stage, "Enter on the summary opens the cards")
	for v: PaydayCardView in s.card_views:
		_on_screen(v, "payday card")
	s.tick(PaydayScreen.INPUT_GRACE_S + 0.01)
	await _key(KEY_3, true)
	await _key(KEY_3, false)
	assert_eq(s.picked_index, 2, "key 3 picks the third card")
	await wait_frames(2)
	assert_eq(s.get_viewport().gui_get_focus_owner(), s.continue_button as Control, "focus moves to Continue")
	await _key(KEY_ENTER, true)
	await _key(KEY_ENTER, false)
	assert_true(done[0], "Enter on Continue leaves the payday")
	s.queue_free()
	await wait_frames(1)
