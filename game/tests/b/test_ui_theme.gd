## PO-4 "Case File" theme (docs/design/ui/style.md): caper_theme.tres is generated from UiTokens by
## UiThemeFactory and must not drift; key prompts draw the key as a cap; the hint strip picks the
## right first-time hint from real state.
extends TestCase

const HUD_PATH: String = "res://content/ui/hud/hud.tscn"

var _model: MockHudModel
var _hud: Hud


func after_each() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_hud = null
	_model = null
	await wait_frames(1)


func _spawn_hud() -> void:
	_model = MockHudModel.new()
	add_child(_model)
	_hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)


func test_saved_theme_matches_the_factory() -> void:
	var saved: Theme = UiBuild.theme()
	var built: Theme = UiThemeFactory.build()
	for type: String in built.get_type_list():
		for n: String in built.get_color_list(type):
			assert_eq(saved.get_color(n, type), built.get_color(n, type), "%s/%s colour (run build_theme.gd)" % [type, n])
		for n: String in built.get_font_size_list(type):
			assert_eq(saved.get_font_size(n, type), built.get_font_size(n, type), "%s/%s size" % [type, n])
		for n: String in built.get_stylebox_list(type):
			var a: StyleBoxFlat = saved.get_stylebox(n, type) as StyleBoxFlat
			var b: StyleBoxFlat = built.get_stylebox(n, type) as StyleBoxFlat
			if b != null:
				assert_true(a != null and a.bg_color == b.bg_color and a.border_color == b.border_color,
						"%s/%s stylebox (run build_theme.gd)" % [type, n])
		assert_eq(saved.get_type_variation_base(type), built.get_type_variation_base(type), "%s base" % type)


func test_tokens_keep_text_readable() -> void:
	for fg: Color in [UiTokens.PAPER, UiTokens.PAPER_DIM, UiTokens.BRASS_HI, UiTokens.CYAN]:
		for bg: Color in [UiTokens.INK_0, UiTokens.INK_1, UiTokens.INK_2, UiTokens.INK_3]:
			assert_true(UiAccent.contrast_ratio(fg, bg) >= 4.5, "%s on %s" % [fg.to_html(false), bg.to_html(false)])
	assert_true(UiTokens.FONT_CAPTION * 720.0 / 1080.0 >= 14.0, "caption >= 14 px at 720p")


func test_key_prompt_draws_the_key_as_a_cap() -> void:
	var p: KeyPrompt = KeyPrompt.new()
	add_child(p)
	p.set_prompt(&"ui.prompt.pick_lock", {}, "F")
	assert_eq(p.text, UiText.t(&"ui.prompt.pick_lock", {"key": "F"}))
	assert_true(p.cap.visible, "key cap shown")
	assert_eq(p.cap_label.text, "F")
	assert_false(p.left.text.contains("F") and p.right.text.contains("F"), "key not repeated in the text")
	assert_eq("%s F %s" % [p.left.text, p.right.text], p.text)
	p.set_line("Click to resume", "")
	assert_false(p.cap.visible, "no key cap without a key")
	assert_eq(p.left.text, "Click to resume")
	p.queue_free()


func test_hint_strip_follows_state() -> void:
	await _spawn_hud()
	var captured: Array[bool] = [true]
	_hud.hint.capture_probe = func() -> bool: return captured[0]
	_model.player_mode = &"casing"
	_hud.hint.refresh()
	assert_eq(_hud.hint.hint, &"mask_up")
	assert_true(_hud.hint.prompt.text.contains(InteractionPanel.action_key_text(&"mask_up")), _hud.hint.prompt.text)
	captured[0] = false
	await wait_frames(2)
	assert_eq(_hud.hint.hint, &"resume", "uncaptured mouse wins")
	assert_true(_hud.hint.visible)
	captured[0] = true
	await wait_frames(2)
	_model.player_mode = &"masked"
	_model.masked = true
	_model.carried_bag = {}
	_hud.hint.refresh()
	assert_eq(_hud.hint.hint, &"", "masked, nothing carried: no hint")
	assert_false(_hud.hint.visible)
	_model.carried_bag = {"loot_id": &"loot.jewelry", "weight": Enums.LootWeight.LIGHT}
	assert_eq(_hud.hint.hint, &"throw_bag")


func test_hud_shows_only_the_current_objective() -> void:
	await _spawn_hud()
	_model.objectives = [
		{"id": &"a", "text_key": &"objective.glasshouse.keycard", "args": {}, "state": Enums.ObjectiveState.COMPLETED},
		{"id": &"b", "text_key": &"objective.glasshouse.secure", "args": {"bags": 2}, "state": Enums.ObjectiveState.ACTIVE},
		{"id": &"c", "text_key": &"objective.glasshouse.keycard", "args": {}, "state": Enums.ObjectiveState.ACTIVE}]
	await wait_frames(1)
	assert_eq(_hud.objectives.list_box.get_child_count(), 1, "one line")
	assert_true((_hud.objectives.list_box.get_child(0) as Label).text.contains("0/2"))
	_model.objectives = []
	await wait_frames(1)
	assert_true(_hud.objectives.flashing, "the last step done still flashes")
	await wait_seconds(ObjectivesPanel.FLASH_S + 0.2)
	assert_false(_hud.objectives.visible, "nothing active: hidden")


func test_objective_complete_flash() -> void:
	await _spawn_hud()
	_model.objectives = [{"id": &"a", "text_key": &"objective.glasshouse.keycard", "args": {}, "state": Enums.ObjectiveState.ACTIVE}]
	await wait_frames(1)
	assert_false(_hud.objectives.flashing)
	_model.objectives = [
		{"id": &"a", "text_key": &"objective.glasshouse.keycard", "args": {}, "state": Enums.ObjectiveState.COMPLETED},
		{"id": &"b", "text_key": &"objective.glasshouse.secure", "args": {"bags": 2}, "state": Enums.ObjectiveState.ACTIVE}]
	await wait_frames(1)
	assert_true(_hud.objectives.flashing, "next step: the complete flash runs")
	assert_eq(_hud.objectives.header_label.text, UiText.t(&"ui.hud.objective_complete"))
	assert_eq(_hud.objectives.shown_id, &"b")
	await wait_seconds(ObjectivesPanel.FLASH_S + 0.2)
	assert_false(_hud.objectives.flashing)
	assert_eq(_hud.objectives.header_label.text, UiText.t(&"ui.hud.objectives"))


func test_crew_rows_named_by_heister_before_ready() -> void:
	_model = MockHudModel.new()
	add_child(_model)
	_hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	_hud.auto_find_model = false
	var hid: StringName = Heisters.ids()[0]
	_hud.set_crew_heisters({2: hid})  # MenuFlow hands them over before the HUD enters the tree
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)
	_model.crew = [{"slot": 2, "name": "AI 1", "is_ai": true, "health_frac": 1.0, "armor_frac": 1.0,
			"state": Enums.CrewState.NORMAL, "downs_left": 3, "carried_loot_id": &""}]
	await wait_frames(1)
	assert_eq((_hud.teammates.name_labels[2] as Label).text, Heisters.display_name(hid))


## PO-1: the mask-up ring shows while mask up is held (0 < progress < 1) and hides otherwise.
func test_mask_up_ring() -> void:
	await _spawn_hud()
	_model.player_mode = &"casing"
	assert_false(_hud.mask_ring.visible, "nothing held")
	_model.mask_progress = 0.4
	assert_true(_hud.mask_ring.visible, "held: ring shows")
	assert_near(_hud.mask_ring.progress, 0.4, 0.001)
	_model.mask_progress = 1.0
	assert_false(_hud.mask_ring.visible, "done: ring hides")


## PO-5.6: real mission data (Glasshouse) fills {count}/{total}; a disabled step (lockdown) is skipped.
func test_objective_mission_data_and_disabled_step() -> void:
	await _spawn_hud()
	_model.objectives = [
		{"id": &"keycard", "text_key": &"objective.glasshouse.keycard", "args": {"disabled": true, "reason": &"lockdown"},
			"state": Enums.ObjectiveState.ACTIVE},
		{"id": &"secure", "text_key": &"objective.glasshouse.secure",
			"args": {"bags": 2, "count": 0, "total": 2, "optional_more": true}, "state": Enums.ObjectiveState.ACTIVE}]
	await wait_frames(1)
	var l: Label = _hud.objectives.list_box.get_child(0) as Label
	assert_eq(l.text, UiText.t(&"objective.glasshouse.secure", {"count": 0, "total": 2}), "disabled keycard skipped")
	assert_false(l.text.contains("{"), l.text)
