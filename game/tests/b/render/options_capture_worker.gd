## Worker for options_capture.gd (loaded at runtime so autoloads exist when it compiles).
extends Node

const SLOT: int = 0
const ROOT: String = "user://options_sweep"
const HEIST: StringName = &"glasshouse"
## Section, key, value the `set` phase writes and `check` expects back.
const CHANGES: Array = [
	[&"audio", &"Master", 0.6], [&"audio", &"Music", 0.3], [&"audio", &"Voice", 0.5],
	[&"video", &"fov", 90.0], [&"video", &"effects_quality", "low"], [&"video", &"brightness", 1.2],
	[&"controls", &"mouse_sensitivity_x", 2.0], [&"controls", &"ads_sensitivity", 0.5],
	[&"controls", &"aim_mode", "toggle"], [&"controls", &"invert_y", true],
	[&"accessibility", &"subtitles", false], [&"accessibility", &"palette", "deuteranopia"],
	[&"accessibility", &"screen_shake", 0.25],
]
const REBIND_ACTION: StringName = &"mask_up"
const REBIND_KEY: Key = KEY_K

var _out: String = ""
var _phase: String = "set"
var _n: int = 0
var _fails: int = 0
var _flow: MenuFlow = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/options_sweep_shots"
	_phase = args[1] if args.size() > 1 else "set"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _log(s: String) -> void:
	print("OPT ", s)


func _check(ok: bool, what: String) -> void:
	_log(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _shot(shot: String, frames: int = 10) -> void:
	for _i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_n += 1
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%02d_%s_%dx%d.png" % [_out, _phase, _n, shot, img.get_width(), img.get_height()])


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _run() -> void:
	UiScreen.motion_enabled = false
	OnboardingTips.persist = false
	DirAccess.make_dir_recursive_absolute(ROOT)
	GameSettings.root_dir = ROOT
	SaveService.root_dir = ROOT + "/profiles"
	if _phase == "set":
		DirAccess.remove_absolute(GameSettings.file_path())
		SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	GameSettings.set_current(null)  # read the file like a fresh game
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)  # MenuFlow applies GameSettings.current() on ready
	await _frames(5)
	match _phase:
		"set":
			await _apply_changes()
		"check":
			await _verify(true)
			await _in_heist()
			await _reset()
		"reset":
			await _verify(false)
	_log("RESULT %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _apply_changes() -> void:
	var opts: OptionsScreen = _flow.options_menu.open()
	await _frames(3)
	for c: Array in CHANGES:
		opts.draft.set_value(StringName(c[0]), StringName(c[1]), c[2])
	InputBindings.rebind(opts.draft, REBIND_ACTION, {"type": "key", "keycode": int(REBIND_KEY), "physical": false}, false)
	opts._build_pages()
	for t: StringName in OptionsScreen.TABS:
		opts.show_tab(t)
		await _shot("set_" + String(t))
	opts.apply_button.pressed.emit()
	await _frames(3)
	_check(FileAccess.file_exists(GameSettings.file_path()), "settings saved to %s" % GameSettings.file_path())
	_check(not opts.is_dirty(), "nothing left unapplied")


## Values back from disk and applied to the engine (`changed` = the set phase's values, else defaults).
func _verify(changed: bool) -> void:
	var s: GameSettings = GameSettings.current()
	var d: GameSettings = GameSettings.new()
	for c: Array in CHANGES:
		var want: Variant = c[2] if changed else d.get_value(StringName(c[0]), StringName(c[1]))
		var got: Variant = s.get_value(StringName(c[0]), StringName(c[1]))
		_check(str(got) == str(want), "%s/%s = %s (want %s)" % [c[0], c[1], got, want])
	for bus: String in ["Master", "Music", "Voice"]:
		var idx: int = AudioServer.get_bus_index(bus)
		var lin: float = db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx >= 0 else -1.0
		var want: float = float(s.get_value(&"audio", StringName(bus)))
		_check(idx >= 0 and absf(lin - want) < 0.02, "bus %s at %.2f (want %.2f)" % [bus, lin, want])
	var has_k: bool = false
	for e: InputEvent in InputMap.action_get_events(REBIND_ACTION):
		if e is InputEventKey and ((e as InputEventKey).keycode == REBIND_KEY or (e as InputEventKey).physical_keycode == REBIND_KEY):
			has_k = true
	_check(has_k == changed, "InputMap %s %s K" % [REBIND_ACTION, "has" if has_k else "lacks"])
	var opts: OptionsScreen = _flow.options_menu.open()
	for t: StringName in OptionsScreen.TABS:
		opts.show_tab(t)
		await _shot("verify_" + String(t))
	opts.back_requested.emit()
	await _frames(3)


func _in_heist() -> void:
	_flow.launch(HEIST, Enums.Difficulty.ROUTINE, SaveService.load_profile(SLOT).loadout, 42)
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	var hud: Hud = _hud()
	if hud == null:
		_check(false, "heist HUD up")
		return
	await _frames(60)
	var cam: Camera3D = get_viewport().get_camera_3d()
	_check(cam != null and absf(cam.fov - 90.0) < 0.5, "camera FOV %.1f (want 90)" % (cam.fov if cam != null else -1.0))
	var key_text: String = InteractionPanel.action_key_text(REBIND_ACTION)
	_check(key_text == "K", "mask_up key text '%s' (want K)" % key_text)
	var hint_text: String = hud.hint.prompt.text if hud.hint != null and hud.hint.prompt != null else ""
	_check(hud.hint.hint == &"mask_up" and hint_text.contains("K"), "HUD prompt '%s' shows K" % hint_text)
	await _shot("heist_prompt", 10)
	var rt: Node = _flow.runtime
	var clock0: float = float(rt.get(&"heist_time_s"))
	var pm: PauseMenu = _flow.options_menu.open_pause()
	await _shot("pause", 10)
	_check(not get_tree().paused, "tree not paused with the pause menu up")
	pm.options_requested.emit()
	await _shot("pause_options", 10)
	_check(not get_tree().paused, "tree not paused with Options over the heist")
	_send_cancel()
	await _frames(10)
	_check(_flow.options_menu.pause_menu != null and is_instance_valid(_flow.options_menu.pause_menu) \
			and _flow.options_menu.pause_menu.visible, "Esc in Options: back to the pause menu")
	_send_cancel()
	await _frames(10)
	_check(_flow.options_menu.pause_menu == null or not is_instance_valid(_flow.options_menu.pause_menu) \
			or not _flow.options_menu.pause_menu.visible, "Esc in the pause menu: resumed")
	var clock1: float = float(rt.get(&"heist_time_s"))
	_check(clock0 < 0.0 or clock1 > clock0, "heist clock ran while in the menus (%.1f -> %.1f)" % [clock0, clock1])
	await _shot("resumed", 10)


func _send_cancel() -> void:
	for down: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = &"ui_cancel"
		e.pressed = down
		Input.parse_input_event(e)


func _reset() -> void:
	if _flow.runtime != null:
		_flow.call(&"_leave_heist")
		await _frames(10)
	var opts: OptionsScreen = _flow.options_menu.open()
	await _frames(3)
	for t: StringName in OptionsScreen.TABS:
		opts.show_tab(t)
		opts.reset_tab()
	opts.show_tab(OptionsScreen.TAB_CONTROLS)
	opts.controls_tab.reset_all_button.pressed.emit()  # the real Reset All Bindings button (edits the draft)
	opts.apply_button.pressed.emit()
	await _frames(3)
	await _shot("after_reset")
	_check(GameSettings.current().get_value(&"video", &"fov") == 75.0, "Reset: FOV back to 75 in memory")


func _hud() -> Hud:
	for n: Node in get_tree().root.find_children("*", "Hud", true, false):
		if n is Hud and (n as Hud).model != null:
			return n as Hud
	return null
