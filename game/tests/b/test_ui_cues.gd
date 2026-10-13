## D-090 UI sound cues (contracts/audio_cues.md v1.5): every UI cue is in ENV C's registry on the UI
## bus with a loadable procedural stream, UiBuild buttons carry the cue wiring (focus on navigation,
## press cue by kind), and the menus / HUD / payday screen request their cues. Headless: requests are
## recorded in UiSfx.played and no player node is created.
extends TestCase

const REGISTRY_PATH: String = "res://world/audio/cues.tres"
const HUD_PATH: String = "res://content/ui/hud/hud.tscn"
const PAYDAY_SCENE: String = "res://content/ui/results/payday.tscn"
const MAIN_MENU_SCENE: String = "res://content/ui/menus/main_menu.tscn"
const SLOT: int = 0
## Cues synthesised by tools/audiogen/ui/build_ui.py (cue.payday_tick is ENV C's).
const NEW_CUES: Array[StringName] = [&"cue.ui_focus", &"cue.ui_confirm", &"cue.ui_back", &"cue.ui_primary",
		&"cue.ui_error", &"cue.ui_tab", &"cue.hud_objective_done", &"cue.hud_hint", &"cue.payday_total",
		&"cue.card_flip", &"cue.hud_hit", &"cue.hud_headshot", &"cue.hud_kill", &"cue.hud_heartbeat"]


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR
	UiSfx.reset()


func before_each() -> void:
	UiSfx.reset()


func _registry() -> AudioCueRegistry:
	return load(REGISTRY_PATH) as AudioCueRegistry


func test_every_ui_cue_is_registered_on_the_ui_bus() -> void:
	var reg: AudioCueRegistry = _registry()
	assert_true(reg != null, "cues.tres loads")
	for id: StringName in UiSfx.ALL:
		var c: AudioCueDef = reg.get_cue(id)
		assert_true(c != null, "%s is in cues.tres" % id)
		if c == null:
			continue
		assert_eq(c.bus, &"UI", "%s on the UI bus" % id)
		assert_false(c.positional, "%s is 2D" % id)
		assert_false(c.loop, "%s is a one-shot" % id)
		assert_false(c.streams.is_empty(), "%s has a stream" % id)
	for id: StringName in NEW_CUES:
		assert_has(UiSfx.ALL, id)


func test_new_cue_streams_load_and_are_short() -> void:
	var reg: AudioCueRegistry = _registry()
	for id: StringName in NEW_CUES:
		var c: AudioCueDef = reg.get_cue(id)
		if c == null:
			assert_true(false, "%s missing" % id)
			continue
		var s: AudioStream = c.streams[0]
		assert_true(s != null, "%s stream loads" % id)
		if s == null:
			continue
		assert_true(s.resource_path.begins_with("res://assets/audio/sfx/ui/"), "%s lives under sfx/ui: %s" % [id, s.resource_path])
		var len_s: float = s.get_length()
		assert_true(len_s > 0.01 and len_s < 0.8, "%s is short and dry (%.3f s)" % [id, len_s])
		var src: String = s.resource_path.get_base_dir().path_join("SOURCE.txt")
		assert_true(FileAccess.file_exists(src), "%s has a SOURCE.txt" % id)
	assert_eq(UiSfx.cue_def(&"cue.ui_focus").get(&"id"), &"cue.ui_focus", "UiSfx resolves through the registry")


func test_ui_build_buttons_carry_the_cue_wiring() -> void:
	var b: Button = UiBuild.button(&"ui.menu.options")
	var p: Button = UiBuild.primary(UiBuild.button(&"ui.results.continue"))
	var g: Button = UiBuild.ghost(UiBuild.button(&"ui.menu.cancel"))
	var t: Button = UiBuild.tab(UiBuild.button(&"ui.menu.options"))
	assert_eq(UiSfx.kind_of(b), UiSfx.KIND_CONFIRM)
	assert_eq(UiSfx.press_cue(b), UiSfx.CONFIRM)
	assert_eq(UiSfx.press_cue(p), UiSfx.PRIMARY)
	assert_eq(UiSfx.press_cue(g), UiSfx.BACK)
	assert_eq(UiSfx.press_cue(t), UiSfx.TAB)
	for x: Button in [b, p, g, t]:
		assert_eq(x.pressed.get_connections().size(), 1, "one press connection (re-wiring only changes the kind)")
		x.free()


func test_press_and_navigation_focus_play_cues() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	add_child(box)
	var a: Button = UiBuild.button(&"ui.menu.options")
	var p: Button = UiBuild.primary(UiBuild.button(&"ui.results.continue"))
	box.add_child(a)
	box.add_child(p)
	await wait_frames(1)
	a.grab_focus()
	assert_false(UiSfx.played.has(UiSfx.FOCUS), "programmatic focus (screen open, mouse) stays quiet")
	UiSfx.note_navigation()
	p.grab_focus()
	assert_eq(UiSfx.played.count(UiSfx.FOCUS), 1, "focus after a navigation input ticks")
	a.grab_focus()
	assert_eq(UiSfx.played.count(UiSfx.FOCUS), 1, "the repeat guard throttles a focus burst")
	a.pressed.emit()
	assert_eq(UiSfx.played.back(), UiSfx.CONFIRM)
	p.pressed.emit()
	assert_eq(UiSfx.played.back(), UiSfx.PRIMARY)
	p.pressed.emit()
	assert_eq(UiSfx.played.count(UiSfx.PRIMARY), 1, "a double press inside the cooldown plays once")
	assert_false(UiSfx.play(&"cue.no_such_ui_cue"), "an unknown cue is silent")
	assert_true(get_tree().root.get_node_or_null(^"UiSfx") == null, "headless: no player node")
	box.queue_free()
	await wait_frames(1)


func test_menus_wire_their_entries() -> void:
	var m: MainMenu = (load(MAIN_MENU_SCENE) as PackedScene).instantiate() as MainMenu
	add_child(m)
	await wait_frames(2)
	for b: Button in [m.safehouse_button, m.range_button, m.settings_button, m.quit_button]:
		assert_eq(UiSfx.press_cue(b), UiSfx.CONFIRM, "main menu %s" % b.text)
	m.queue_free()
	var pm: PauseMenu = PauseMenu.new()
	add_child(pm)
	await wait_frames(1)
	for b: Button in [pm.resume_button, pm.options_button, pm.leave_button]:
		assert_eq(UiSfx.press_cue(b), UiSfx.CONFIRM, "pause menu %s" % b.text)
	assert_eq(UiSfx.press_cue(pm.confirm_button), UiSfx.PRIMARY)
	assert_eq(UiSfx.press_cue(pm.cancel_button), UiSfx.BACK)
	pm.queue_free()
	await wait_frames(1)


func test_hud_objective_done_and_hint_cues() -> void:
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = (load(HUD_PATH) as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
	await wait_frames(1)
	hud.bind(model)
	hud.hint.capture_probe = func() -> bool: return true
	model.objectives = [{"id": &"a", "text_key": &"objective.glasshouse.keycard", "args": {}, "state": Enums.ObjectiveState.ACTIVE}]
	await wait_frames(1)
	assert_false(UiSfx.played.has(UiSfx.OBJECTIVE_DONE))
	model.objectives = [
		{"id": &"a", "text_key": &"objective.glasshouse.keycard", "args": {}, "state": Enums.ObjectiveState.COMPLETED},
		{"id": &"b", "text_key": &"objective.glasshouse.secure", "args": {"bags": 2}, "state": Enums.ObjectiveState.ACTIVE}]
	await wait_frames(1)
	assert_true(hud.objectives.flashing)
	assert_eq(UiSfx.played.count(UiSfx.OBJECTIVE_DONE), 1, "objective done chime")
	model.player_mode = &"casing"
	hud.hint.refresh()
	assert_eq(hud.hint.hint, &"mask_up")
	assert_eq(UiSfx.played.count(UiSfx.HINT), 1, "a new hint blips")
	UiSfx.reset()
	hud.hint.refresh()
	assert_false(UiSfx.played.has(UiSfx.HINT), "the same hint again is quiet")
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)


func test_payday_total_and_card_flip_cues() -> void:
	SaveService.delete_profile(SLOT)
	var s: PaydayScreen = (load(PAYDAY_SCENE) as PackedScene).instantiate() as PaydayScreen
	add_child(s)
	await wait_frames(1)
	s.show_result(HeistCatalog.sample_result())
	assert_eq(s.total_landed_count, 1, "headless: no count-up, the total lands at once")
	assert_eq(UiSfx.played.count(UiSfx.PAYDAY_TOTAL), 1, "register cha-chunk")
	s.show_cards()
	await wait_frames(2)
	assert_false(UiSfx.played.has(UiSfx.CARD_FLIP), "face-down cards are quiet")
	s.pick(0)
	assert_eq(UiSfx.played.count(UiSfx.CARD_FLIP), 1, "the three cards flip as one sound")
	assert_eq(UiSfx.kind_of(s.card_views[0]), UiSfx.KIND_NONE, "cards tick on navigation only")
	s.queue_free()
	await wait_frames(1)


## Lane 6: a refused action buzzes: a click on a disabled button, or an action reporting failure.
func test_refusals_play_the_error_cue() -> void:
	var b: Button = UiBuild.primary(UiBuild.button(&"ui.menu.confirm"))
	add_child(b)
	b.disabled = true
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	b.gui_input.emit(click)
	assert_eq(UiSfx.played.back(), UiSfx.ERROR, "disabled click buzzes")
	UiSfx.played.clear()
	b.disabled = false
	b.gui_input.emit(click)
	assert_false(UiSfx.played.has(UiSfx.ERROR), "an enabled button does not buzz")
	await wait_seconds(0.2)
	assert_false(UiSfx.check(false))
	assert_eq(UiSfx.played.back(), UiSfx.ERROR, "a failed action buzzes")
	assert_true(UiSfx.check(true))
	b.queue_free()
