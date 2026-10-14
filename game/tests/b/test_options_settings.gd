## B5-01: GameSettings model + settings.cfg persistence: defaults from the tweak, round trip,
## clamping, the changed signal and the corrupt / partly bad file fallbacks.
extends TestCase


func before_all() -> void:
	GameSettings.root_dir = BTestUtil.settings_root()
	DirAccess.make_dir_recursive_absolute(GameSettings.root_dir)


func before_each() -> void:
	_remove_file()


func after_all() -> void:
	_remove_file()
	DirAccess.remove_absolute(GameSettings.root_dir)
	GameSettings.root_dir = GameSettings.DEFAULT_ROOT_DIR


func _remove_file() -> void:
	if FileAccess.file_exists(GameSettings.file_path()):
		DirAccess.remove_absolute(GameSettings.file_path())


func _write(text: String) -> void:
	var f: FileAccess = FileAccess.open(GameSettings.file_path(), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_defaults_come_from_the_tweak() -> void:
	var d: SettingsDefaults = SettingsDefaults.load_default()
	for section: StringName in GameSettings.VALUE_SECTIONS:
		assert_true(not d.keys(section).is_empty(), "section %s has keys" % section)
	var s: GameSettings = GameSettings.new()
	assert_near(s.fov(), 75.0)
	assert_near(float(d.spec(GameSettings.VIDEO, &"fov")["min"]), 60.0)
	assert_near(float(d.spec(GameSettings.VIDEO, &"fov")["max"]), 100.0)
	assert_eq(s.mouse_sensitivity(), Vector2.ONE)
	assert_false(s.invert_y())
	assert_near(s.pad_deadzone(), 0.2)
	assert_near(s.pad_sensitivity(), 1.0)
	for a: StringName in [&"aim", &"crouch", &"sprint"]:
		assert_false(s.is_toggle(a), "%s defaults to hold" % a)
	assert_false(s.is_toggle(&"fire"), "no mode for fire")
	assert_eq(s.get_value(GameSettings.ACCESSIBILITY, &"palette"), "default")
	for bus: StringName in [&"Master", &"Music", &"SFX", &"Weapons", &"Enemies", &"World", &"UI", &"Voice", &"Ambience"]:
		assert_true(s.get_value(GameSettings.AUDIO, bus) is float, "audio bus %s" % bus)
	assert_eq(s.get_value(GameSettings.BINDINGS, &"fire"), {}, "no override")
	assert_eq(s.get_value(&"video", &"nope"), null)


func test_round_trip() -> void:
	var s: GameSettings = GameSettings.new()
	s.set_value(GameSettings.AUDIO, &"Music", 0.35)
	s.set_value(GameSettings.VIDEO, &"fov", 92.0)
	s.set_value(GameSettings.VIDEO, &"window_mode", "fullscreen")
	s.set_value(GameSettings.VIDEO, &"max_fps", 144)
	s.set_value(GameSettings.CONTROLS, &"invert_y", true)
	s.set_value(GameSettings.CONTROLS, &"crouch_mode", "toggle")
	s.set_value(GameSettings.ACCESSIBILITY, &"palette", "tritanopia")
	InputBindings.rebind(s, &"reload", {"type": "key", "keycode": KEY_K, "physical": true}, false)
	InputBindings.rebind(s, &"fire", {"type": "joy_button", "button": 10}, false)
	assert_eq(s.save(), OK)
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(GameSettings.file_path()), OK)
	assert_eq(cfg.get_value("meta", "version"), GameSettings.CURRENT_VERSION)
	var stored: Variant = cfg.get_value("bindings", "reload")
	assert_true(stored is Dictionary, "bindings are plain dicts, not objects")
	assert_eq(((stored as Dictionary)["kbm"] as Array)[0], {"type": "key", "keycode": KEY_K, "physical": true})
	var t: GameSettings = GameSettings.load_file()
	assert_true(t.equals(s), "load(save(s)) == s")
	assert_near(t.fov(), 92.0)
	assert_true(t.is_toggle(&"crouch"))
	assert_eq(t.get_value(GameSettings.VIDEO, &"max_fps"), 144)
	assert_eq(InputBindings.column(t, &"fire", InputEventCodec.PAD), [{"type": "joy_button", "button": 10}] as Array[Dictionary])
	assert_eq(InputBindings.column(t, &"fire", InputEventCodec.KBM), InputBindings.default_column(&"fire", InputEventCodec.KBM),
			"untouched column stays default")


func test_clamping_and_types() -> void:
	var s: GameSettings = GameSettings.new()
	assert_near(float(s.set_value(GameSettings.VIDEO, &"fov", 200.0)), 100.0)
	assert_near(float(s.set_value(GameSettings.VIDEO, &"fov", 10)), 60.0, 0.0001, "int accepted and clamped")
	assert_near(float(s.set_value(GameSettings.VIDEO, &"fov", "wide")), 75.0, 0.0001, "wrong type -> default")
	assert_near(float(s.set_value(GameSettings.VIDEO, &"fov", NAN)), 75.0, 0.0001, "NaN -> default")
	assert_near(float(s.set_value(GameSettings.AUDIO, &"Master", -1.0)), 0.0)
	assert_near(float(s.set_value(GameSettings.AUDIO, &"Master", 3.0)), 1.0)
	assert_eq(s.set_value(GameSettings.VIDEO, &"max_fps", -30), 0)
	assert_eq(s.set_value(GameSettings.VIDEO, &"max_fps", 59.6), 60, "int rounded")
	assert_eq(s.set_value(GameSettings.VIDEO, &"vsync", 0), true, "bool needs a bool")
	assert_eq(s.set_value(GameSettings.VIDEO, &"msaa", "16x"), "4x", "unknown choice -> default")
	assert_eq(s.set_value(GameSettings.ACCESSIBILITY, &"palette", &"protanopia"), "protanopia", "StringName ok")
	assert_eq(s.set_value(GameSettings.CONTROLS, &"aim_mode", "sometimes"), "hold")
	assert_eq(s.set_value(&"video", &"nope", 1), null, "unknown key")
	assert_near(float(s.set_value(GameSettings.CONTROLS, &"pad_deadzone", 0.9)), 0.5)


func test_changed_signal() -> void:
	var s: GameSettings = GameSettings.new()
	var got: Array = []
	s.changed.connect(func(section: StringName, key: StringName) -> void: got.append([section, key]))
	s.set_value(GameSettings.VIDEO, &"fov", 80.0)
	s.set_value(GameSettings.VIDEO, &"fov", 80.0)
	assert_eq(got, [[&"video", &"fov"]], "once per actual change")
	s.set_value(GameSettings.VIDEO, &"fov", 500.0)
	s.set_value(GameSettings.VIDEO, &"fov", 100.0)
	assert_eq(got.size(), 2, "clamped value equal to the stored one: no signal")
	InputBindings.rebind(s, &"jump", {"type": "key", "keycode": KEY_J, "physical": true}, false)
	assert_eq(got[2], [&"bindings", &"jump"])
	var other: GameSettings = GameSettings.new()
	got.clear()
	s.copy_from(other)
	assert_has(got, [&"video", &"fov"])
	assert_has(got, [&"bindings", &"jump"])
	assert_true(s.equals(other))


func test_reset_section() -> void:
	var s: GameSettings = GameSettings.new()
	s.set_value(GameSettings.CONTROLS, &"invert_y", true)
	s.set_value(GameSettings.VIDEO, &"fov", 90.0)
	s.reset_section(GameSettings.CONTROLS)
	assert_false(s.invert_y())
	assert_near(s.fov(), 90.0, 0.0001, "other sections kept")


func test_missing_file_gives_defaults() -> void:
	assert_true(GameSettings.load_file().equals(GameSettings.new()))


func test_corrupt_file_falls_back_to_defaults() -> void:
	_write("this is { not [ a config ] file = = \n\u0000\u0001")
	var s: GameSettings = GameSettings.load_file()
	assert_true(s.equals(GameSettings.new()), "garbage -> defaults")


func test_bad_values_fall_back_per_key() -> void:
	_write("""[meta]
version=1
[video]
fov=92.0
max_fps="fast"
window_mode="fullscreen"
[audio]
Music=4.0
SFX=Vector3(1, 2, 3)
[controls]
invert_y=true
not_a_key=5
[unknown]
x=1
[bindings]
reload={"kbm": [{"type": "key", "keycode": 75, "physical": true}, {"type": "warp"}, {"type": "joy_button", "button": 3}]}
not_an_action={"kbm": [{"type": "key", "keycode": 75, "physical": true}]}
jump="space"
""")
	var s: GameSettings = GameSettings.load_file()
	assert_near(s.fov(), 92.0, 0.0001, "good value kept")
	assert_eq(s.get_value(GameSettings.VIDEO, &"max_fps"), 0, "bad type -> default")
	assert_eq(s.get_value(GameSettings.VIDEO, &"window_mode"), "fullscreen")
	assert_near(float(s.get_value(GameSettings.AUDIO, &"Music")), 1.0, 0.0001, "clamped")
	assert_near(float(s.get_value(GameSettings.AUDIO, &"SFX")), 1.0, 0.0001, "wrong type -> default")
	assert_true(s.invert_y())
	assert_eq(InputBindings.column(s, &"reload", InputEventCodec.KBM),
			[{"type": "key", "keycode": KEY_K, "physical": true}] as Array[Dictionary], "invalid / wrong-column events dropped")
	assert_eq(s.get_value(GameSettings.BINDINGS, &"not_an_action"), {}, "unknown action dropped")
	assert_eq(s.get_value(GameSettings.BINDINGS, &"jump"), {}, "non-dict entry dropped")


func test_newer_version_reads_known_keys() -> void:
	_write("[meta]\nversion=99\n[video]\nfov=66.0\nray_tracing=true\n")
	var s: GameSettings = GameSettings.load_file()
	assert_eq(s.loaded_version, 99)
	assert_near(s.fov(), 66.0)


func test_every_options_string_exists() -> void:
	var table: Dictionary = StringTable.parse_csv()
	var d: SettingsDefaults = SettingsDefaults.load_default()
	for section: StringName in GameSettings.VALUE_SECTIONS:
		assert_has(table, "ui.options.tab.%s" % section)
		for key: StringName in d.keys(section):
			assert_has(table, String(OptionsRows.label_key(section, key)))
			var sp: Dictionary = d.spec(section, key)
			if String(sp["type"]) == SettingsDefaults.T_CHOICE:
				for o: Variant in sp["options"]:
					assert_has(table, String(OptionsRows.option_key(section, key, String(o))))
	for i: int in range(1, InputEventCodec.MAX_MOUSE_BUTTON + 1):
		assert_has(table, "ui.options.input.mouse_%d" % i)
	for i: int in range(16):
		assert_has(table, "ui.options.pad.button_%d" % i)
	for axis: int in range(6):
		for sign_name: String in ["pos", "neg"]:
			assert_has(table, "ui.options.pad.axis_%d_%s" % [axis, sign_name])
	for f: StringName in HudPalette.FIELDS:
		assert_has(table, "ui.options.palette.field.%s" % f)
	for a: StringName in InputBindings.project_actions():
		assert_has(table, "ui.action.%s" % a)


func test_current_is_shared_and_replaceable() -> void:
	var prev: GameSettings = GameSettings.current()
	var mine: GameSettings = GameSettings.new()
	GameSettings.set_current(mine)
	assert_eq(GameSettings.current(), mine)
	GameSettings.set_current(prev)
	assert_eq(GameSettings.current(), prev)


## ENV P head bob: on by default, off when unticked, and always off under Reduce Motion.
func test_head_bob_follows_reduce_motion() -> void:
	var s: GameSettings = GameSettings.new()
	assert_true(s.head_bob(), "default on")
	s.set_value(GameSettings.ACCESSIBILITY, &"reduce_motion", true)
	assert_false(s.head_bob(), "Reduce Motion forces it off")
	s.set_value(GameSettings.ACCESSIBILITY, &"reduce_motion", false)
	s.set_value(GameSettings.ACCESSIBILITY, &"head_bob", false)
	assert_false(s.head_bob(), "player turned it off")


## D-105 effects quality: high by default, the chosen level, one step lower under Reduce Motion.
func test_effects_quality_follows_reduce_motion() -> void:
	var s: GameSettings = GameSettings.new()
	assert_eq(s.effects_quality(), GameSettings.EFFECTS_HIGH, "default high")
	s.set_value(GameSettings.VIDEO, &"effects_quality", "medium")
	assert_eq(s.effects_quality(), GameSettings.EFFECTS_MEDIUM)
	s.set_value(GameSettings.ACCESSIBILITY, &"reduce_motion", true)
	assert_eq(s.effects_quality(), GameSettings.EFFECTS_LOW, "Reduce Motion lowers it one step")
	s.set_value(GameSettings.VIDEO, &"effects_quality", "low")
	assert_eq(s.effects_quality(), GameSettings.EFFECTS_LOW, "never below low")
	for id: StringName in GameSettings.EFFECTS_QUALITY_IDS:
		assert_true(UiText.t(StringName("ui.options.video.effects_quality.%s" % id)) != "", "option label %s" % id)
