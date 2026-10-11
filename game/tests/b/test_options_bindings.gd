## B5-01: InputEvent <-> dict codec, InputMap rebinding, reset, conflict detection (swap / keep both)
## and capture. Every test leaves the InputMap at the project defaults.
extends TestCase

const K_KEY: Dictionary = {"type": "key", "keycode": KEY_K, "physical": true}
const F_KEY: Dictionary = {"type": "key", "keycode": KEY_F, "physical": true}
const R_KEY: Dictionary = {"type": "key", "keycode": KEY_R, "physical": true}
const G_KEY: Dictionary = {"type": "key", "keycode": KEY_G, "physical": true}
const MMB: Dictionary = {"type": "mouse_button", "button": MOUSE_BUTTON_MIDDLE}


func after_each() -> void:
	InputBindings.apply(GameSettings.new())


func _key_event(code: Key) -> InputEventKey:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func test_codec_round_trip() -> void:
	var events: Array[InputEvent] = []
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = KEY_W
	events.append(k)
	var shift: InputEventKey = InputEventKey.new()
	shift.keycode = KEY_SHIFT
	events.append(shift)
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_WHEEL_UP
	events.append(mb)
	var jb: InputEventJoypadButton = InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	events.append(jb)
	var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_TRIGGER_RIGHT
	jm.axis_value = 1.0
	events.append(jm)
	for e: InputEvent in events:
		var d: Dictionary = InputEventCodec.to_dict(e)
		assert_false(d.is_empty(), "dict for %s" % e.as_text())
		for v: Variant in d.values():
			assert_true(v is int or v is bool or v is String, "plain values only: %s" % [d])
		var back: InputEvent = InputEventCodec.from_dict(d)
		assert_eq(back.get_class(), e.get_class())
		assert_eq(InputEventCodec.to_dict(back), d, "round trip %s" % [d])
		assert_eq(back.device, -1, "all devices")
		assert_true(back.is_match(e), "%s matches" % e.as_text())
	assert_eq(InputEventCodec.to_dict(InputEventMouseMotion.new()), {}, "motion is not a binding")
	for bad: Variant in [null, 5, {}, {"type": "key"}, {"type": "key", "keycode": -3}, {"type": "joy_motion", "axis": 1, "dir": 0},
			{"type": "mouse_button", "button": 99}, {"type": "joy_button", "button": 1.5}]:
		assert_true(InputEventCodec.from_dict(bad) == null, "invalid: %s" % [bad])
	assert_eq(InputEventCodec.column_of(K_KEY), InputEventCodec.KBM)
	assert_eq(InputEventCodec.column_of(MMB), InputEventCodec.KBM)
	assert_eq(InputEventCodec.column_of({"type": "joy_motion", "axis": 2, "dir": -1}), InputEventCodec.PAD)
	assert_true(InputEventCodec.same(K_KEY, {"type": "key", "keycode": KEY_K, "physical": false}), "physical or not, same key")
	assert_false(InputEventCodec.same(K_KEY, F_KEY))


func test_text() -> void:
	assert_eq(InputEventCodec.text(F_KEY), "F")
	assert_eq(InputEventCodec.text(MMB), UiText.t(&"ui.options.input.mouse_3"))
	assert_eq(InputEventCodec.text({"type": "joy_button", "button": 0}), UiText.t(&"ui.options.pad.button_0"))
	assert_eq(InputEventCodec.text({"type": "joy_motion", "axis": 5, "dir": 1}), UiText.t(&"ui.options.pad.axis_5_pos"))
	assert_true(InputEventCodec.text({"type": "joy_button", "button": 40}).contains("40"))


func test_every_action_is_listed_and_named() -> void:
	var listed: Array[StringName] = InputBindings.actions()
	var project: Array[StringName] = InputBindings.project_actions()
	assert_true(project.size() >= 27, "project actions: %d" % project.size())
	var table: Dictionary = StringTable.parse_csv()
	for a: StringName in project:
		assert_has(listed, a, "%s in the rebind list" % a)
		assert_has(table, String(InputBindings.name_key(a)), "display name for %s" % a)
		assert_true(InputMap.has_action(a))
	for a: StringName in SettingsDefaults.load_default().action_order:
		assert_has(project, a, "action_order names a real action: %s" % a)
	assert_eq(listed.size(), project.size(), "no ui_* actions, no duplicates")
	assert_eq(listed[0], &"move_forward", "data order")


func test_defaults_match_the_project() -> void:
	var s: GameSettings = GameSettings.new()
	assert_eq(InputBindings.column(s, &"interact", InputEventCodec.KBM), [F_KEY] as Array[Dictionary])
	assert_eq(InputBindings.column(s, &"interact", InputEventCodec.PAD), [{"type": "joy_button", "button": 2}] as Array[Dictionary])
	assert_eq(InputBindings.column(s, &"look_left", InputEventCodec.KBM).size(), 0, "pad-only action")
	assert_eq(InputBindings.column(s, &"crouch", InputEventCodec.KBM).size(), 2, "Ctrl + C")


func test_rebind_applies_to_the_input_map() -> void:
	var s: GameSettings = GameSettings.new()
	assert_eq(InputBindings.conflicts(s, &"reload", K_KEY), [] as Array[StringName], "K is free")
	assert_eq(InputBindings.rebind(s, &"reload", K_KEY, false), [&"reload"] as Array[StringName])
	s.apply()
	assert_true(InputMap.action_has_event(&"reload", InputEventCodec.from_dict(K_KEY)))
	assert_false(InputMap.action_has_event(&"reload", InputEventCodec.from_dict(R_KEY)), "R replaced")
	assert_true(InputMap.event_is_action(_key_event(KEY_K), &"reload"))
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	assert_true(InputMap.action_has_event(&"reload", pad), "pad column untouched")
	assert_near(InputMap.action_get_deadzone(&"reload"), 0.2, 0.0001, "deadzone kept")
	# Pad rebinding to a stick direction.
	InputBindings.rebind(s, &"melee", {"type": "joy_motion", "axis": JOY_AXIS_LEFT_Y, "dir": 1}, false)
	InputBindings.apply_action(s, &"melee")
	var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_Y
	jm.axis_value = 1.0
	assert_true(InputMap.event_is_action(jm, &"melee"))


func test_reset_action_and_all() -> void:
	var s: GameSettings = GameSettings.new()
	InputBindings.rebind(s, &"reload", K_KEY, false)
	InputBindings.rebind(s, &"jump", {"type": "key", "keycode": KEY_J, "physical": true}, false)
	InputBindings.reset_action(s, &"reload")
	assert_eq(s.get_value(GameSettings.BINDINGS, &"reload"), {})
	assert_eq(InputBindings.column(s, &"reload", InputEventCodec.KBM), [R_KEY] as Array[Dictionary])
	assert_ne(s.get_value(GameSettings.BINDINGS, &"jump"), {}, "other override kept")
	InputBindings.reset_all(s)
	assert_true(s.equals(GameSettings.new()))
	s.apply()
	assert_true(InputMap.event_is_action(_key_event(KEY_R), &"reload"))
	# Rebinding back to the default clears the override.
	InputBindings.rebind(s, &"interact", K_KEY, false)
	InputBindings.rebind(s, &"interact", F_KEY, false)
	assert_eq(s.get_value(GameSettings.BINDINGS, &"interact"), {}, "default again = no override")


func test_conflict_detection() -> void:
	var s: GameSettings = GameSettings.new()
	assert_true(InputBindings.compatible(&"interact", &"shout"), "F is shared by design")
	assert_true(InputBindings.compatible(&"mask_up", &"drop_bag"), "G is shared by design")
	assert_false(InputBindings.compatible(&"reload", &"interact"))
	var c: Array[StringName] = InputBindings.conflicts(s, &"reload", F_KEY)
	assert_has(c, &"interact")
	assert_has(c, &"shout")
	assert_eq(c.size(), 2)
	assert_eq(InputBindings.conflicts(s, &"shout", F_KEY), [] as Array[StringName], "designed share is no conflict")
	var g: Array[StringName] = InputBindings.conflicts(s, &"interact", G_KEY)
	for a: StringName in [&"mask_up", &"throw_item", &"drop_bag"]:
		assert_has(g, a)
	assert_eq(InputBindings.conflicts(s, &"jump", {"type": "joy_button", "button": JOY_BUTTON_B}), [&"reload"] as Array[StringName],
			"pad column checked separately")


func test_swap_and_keep_both() -> void:
	var s: GameSettings = GameSettings.new()
	var changed_actions: Array[StringName] = InputBindings.rebind(s, &"reload", F_KEY, true)
	assert_eq(changed_actions, [&"reload", &"interact", &"shout"] as Array[StringName])
	assert_eq(InputBindings.column(s, &"reload", InputEventCodec.KBM), [F_KEY] as Array[Dictionary])
	assert_eq(InputBindings.column(s, &"interact", InputEventCodec.KBM), [R_KEY] as Array[Dictionary], "took reload's R")
	assert_eq(InputBindings.column(s, &"shout", InputEventCodec.KBM), [R_KEY, MMB] as Array[Dictionary], "F swapped, MMB kept")
	assert_eq(InputBindings.conflicts(s, &"reload", F_KEY), [] as Array[StringName], "resolved")
	var t: GameSettings = GameSettings.new()
	InputBindings.rebind(t, &"reload", F_KEY, false)
	assert_eq(InputBindings.column(t, &"interact", InputEventCodec.KBM), [F_KEY] as Array[Dictionary], "keep both")
	t.apply()
	assert_true(InputMap.event_is_action(_key_event(KEY_F), &"reload"))
	assert_true(InputMap.event_is_action(_key_event(KEY_F), &"interact"))


func test_capture() -> void:
	var k: InputEventKey = _key_event(KEY_K)
	assert_eq(InputEventCodec.capture(k, InputEventCodec.KBM), K_KEY)
	assert_eq(InputEventCodec.capture(k, InputEventCodec.PAD), {}, "keys are not pad bindings")
	k.pressed = false
	assert_eq(InputEventCodec.capture(k, InputEventCodec.KBM), {}, "release ignored")
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_RIGHT
	mb.pressed = true
	assert_eq(InputEventCodec.capture(mb, InputEventCodec.KBM), {"type": "mouse_button", "button": 2})
	var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_RIGHT_X
	jm.axis_value = -0.3
	assert_eq(InputEventCodec.capture(jm, InputEventCodec.PAD), {}, "small deflection ignored")
	jm.axis_value = -0.9
	assert_eq(InputEventCodec.capture(jm, InputEventCodec.PAD), {"type": "joy_motion", "axis": JOY_AXIS_RIGHT_X, "dir": -1})


func test_bindings_survive_save_and_load() -> void:
	GameSettings.root_dir = BTestUtil.settings_root()
	var s: GameSettings = GameSettings.new()
	InputBindings.rebind(s, &"reload", F_KEY, true)
	assert_eq(s.save(), OK)
	var t: GameSettings = GameSettings.load_file()
	t.apply()
	assert_true(InputMap.event_is_action(_key_event(KEY_F), &"reload"))
	assert_true(InputMap.event_is_action(_key_event(KEY_R), &"interact"))
	DirAccess.remove_absolute(GameSettings.file_path())
	DirAccess.remove_absolute(GameSettings.root_dir)
	GameSettings.root_dir = GameSettings.DEFAULT_ROOT_DIR
