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
	assert_true(_hud.interaction.prompt.text.contains(OS.get_keycode_string(code)), "prompt names the bound key")
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


## Lead bug: "Secure the bags ({count}/{total})" showed raw. Missions pass {"bags": N}; the panel fills
## total from bags and count from secured bags, and never shows raw braces.
func test_objective_placeholders_filled() -> void:
	_model.objectives = [{"id": &"secure", "text_key": &"objective.glasshouse.secure",
			"args": {"bags": 2, "optional_more": true}, "state": Enums.ObjectiveState.ACTIVE}]
	await wait_frames(1)
	var l: Label = _hud.objectives.list_box.get_child(0) as Label
	assert_false(l.text.contains("{"), "no raw placeholder: " + l.text)
	assert_true(l.text.contains("0/2"), "count/total filled: " + l.text)
	EventBus.loot_secured.emit(7, &"loot.jewelry", 1000)
	await wait_frames(1)
	l = _hud.objectives.list_box.get_child(0) as Label
	assert_true(l.text.contains("1/2"), "count follows secured bags: " + l.text)
	var raw: String = ObjectivesPanel.objective_text({"text_key": &"objective.glasshouse.secure", "args": {}})
	assert_false(raw.contains("{"), "unknown total drops the ( ) group: " + raw)
	assert_eq(ObjectivesPanel.objective_text({"text_key": &"objective.glasshouse.secure",
			"args": {"count": 3, "total": 4}}), UiText.t(&"objective.glasshouse.secure", {"count": 3, "total": 4}))


## PP-A-1: domination prompt visible while dominate_target != 0, hidden at 0, names the shout key.
func test_dominate_prompt_follows_guard_id() -> void:
	assert_false(_hud.dominate.visible, "hidden with no guard")
	_model.dominate_window_s = 2.4
	_model.dominate_target = 4711
	await wait_frames(1)
	assert_true(_hud.dominate.visible, "shown for a guard id")
	_on_screen(_hud.dominate, "domination prompt")
	var key: String = InteractionPanel.action_key_text(&"shout")
	assert_ne(key, "")
	assert_true(_hud.dominate.prompt.text.contains(key), _hud.dominate.prompt.text)
	assert_true(_hud.dominate.prompt.text.contains("2.4"), _hud.dominate.prompt.text)
	_model.dominate_target = 0
	await wait_frames(1)
	assert_false(_hud.dominate.visible, "hidden again at 0")


## Stand-in for ENV P's CrewController (PI-13 casing_blocked); no P files used.
class FakeCrew:
	extends Node
	signal casing_blocked(action: StringName)
	var slot: int = 0


## PI-13: a blocked sprint while casing shows "Mask up to sprint" for ~1.5 s; no-op without the signal.
func test_casing_blocked_hint() -> void:
	assert_false(_hud.watch_crew(Node.new()), "no signal -> no-op")
	var crew: FakeCrew = FakeCrew.new()
	add_child(crew)
	assert_true(_hud.watch_crew(crew))
	crew.casing_blocked.emit(&"sprint")
	await wait_frames(1)
	assert_true(_hud.toast_label.visible)
	assert_true(_hud.toast_label.text.begins_with("Mask up to sprint"), _hud.toast_label.text)
	assert_false(_hud.toast_label.text.contains("{"), _hud.toast_label.text)
	await wait_seconds(Hud.CASING_HINT_S + 0.3)
	assert_false(_hud.toast_label.visible, "hint gone after ~1.5 s")
	crew.casing_blocked.emit(&"ladder")
	await wait_frames(1)
	assert_eq(_hud.toast_label.text, UiText.t(&"ui.hud.casing_blocked.generic",
			{"key": InteractionPanel.action_key_text(&"mask_up")}), "unknown action -> generic hint")
	crew.queue_free()
	await wait_frames(1)


## PQ-B-23 (lead ruling): floating HUD text uses outline 8 + a soft dark drop shadow, no backing panel.
func test_floating_text_outline_and_shadow() -> void:
	var labels: Array[Label] = [_hud.toast_label, _hud.dominate.prompt.left, _hud.interaction.prompt.left,
			_hud.interaction.blocked_label, _hud.status.mask_label, _hud.status.bag_label,
			_hud.status.hostages_label, _hud.status.warnings_label]
	for l: Label in labels:
		assert_eq(l.get_theme_constant(&"outline_size"), 8, l.name)
		assert_eq(l.get_theme_color(&"font_outline_color"), Color(0, 0, 0, 1), l.name)
		var sh: Color = l.get_theme_color(&"font_shadow_color")
		assert_true(sh.a > 0.3 and sh.a < 1.0 and sh.get_luminance() < 0.1, "soft dark shadow %s" % l.name)
		assert_true(l.get_theme_constant(&"shadow_offset_y") > 0, l.name)
		assert_true(l.get_theme_constant(&"shadow_outline_size") > 0, "blurred shadow %s" % l.name)
		assert_false(l.get_parent() is PanelContainer, "no backing panel %s" % l.name)


## D-082 fix (full-loop walk): pad players saw keyboard keys in prompts. A pad press switches the
## interaction / domination prompts to pad names; a key press switches back.
func test_prompts_follow_last_device() -> void:
	_model.interaction = {"text_key": &"ui.prompt.interact", "args": {}, "progress": 0.0, "blocked_reason": &""}
	_model.dominate_window_s = 1.0
	_model.dominate_target = 3
	await wait_frames(1)
	var key: String = InteractionPanel.action_key_text(&"interact")
	assert_true(_hud.interaction.prompt.text.contains(key), _hud.interaction.prompt.text)
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_Y
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)
	var pad: String = InteractionPanel.pad_text(&"interact")
	assert_ne(pad, "", "interact has a pad binding")
	assert_true(_hud.interaction.prompt.text.contains(pad), "pad name: " + _hud.interaction.prompt.text)
	assert_false(_hud.interaction.prompt.text.contains(" %s " % key), _hud.interaction.prompt.text)
	assert_true(_hud.dominate.prompt.text.contains(InteractionPanel.pad_text(&"shout")), _hud.dominate.prompt.text)
	await _key(KEY_ESCAPE, true)
	await _key(KEY_ESCAPE, false)
	assert_true(_hud.interaction.prompt.text.contains(key), "back to keys: " + _hud.interaction.prompt.text)
	_model.dominate_target = 0
