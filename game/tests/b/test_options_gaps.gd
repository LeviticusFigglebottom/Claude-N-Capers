## Options gaps (LEAD r280 queue (5)): a resolution picker (windowed size), a quality preset over the video knobs
## (render scale, MSAA, FXAA, effects, the new shadow quality; a hand edit makes it "custom") and interact hold /
## toggle (ENV P reads is_toggle(&"interact")). The options screen's rows follow a preset.
extends TestCase

const SCREEN_SCENE: PackedScene = preload("res://content/ui/menus/options_screen.tscn")


func before_all() -> void:
	GameSettings.root_dir = BTestUtil.settings_root()


func after_all() -> void:
	DirAccess.remove_absolute(GameSettings.root_dir.path_join(GameSettings.FILE_NAME))
	GameSettings.root_dir = GameSettings.DEFAULT_ROOT_DIR


func test_defaults_are_the_high_preset() -> void:
	var s: GameSettings = GameSettings.new()
	assert_eq(String(s.get_value(GameSettings.VIDEO, &"quality_preset")), "high")
	assert_eq(s.matching_preset(), "high", "the shipped video defaults are exactly High")
	assert_eq(String(s.get_value(GameSettings.VIDEO, &"shadow_quality")), "high")
	assert_eq(s.resolution(), Vector2i.ZERO, "auto: the window keeps its size")
	assert_false(s.is_toggle(&"interact"), "interact holds by default (PD2)")


func test_preset_writes_values_and_a_hand_edit_makes_it_custom() -> void:
	var s: GameSettings = GameSettings.new()
	s.set_value(GameSettings.VIDEO, &"quality_preset", "low")
	for k: StringName in GameSettings.QUALITY_PRESETS["low"]:
		var want: Variant = GameSettings.QUALITY_PRESETS["low"][k]
		var got: Variant = s.get_value(GameSettings.VIDEO, k)
		assert_true(is_equal_approx(float(got), float(want)) if got is float else got == want, "low sets %s" % k)
	s.set_value(GameSettings.VIDEO, &"msaa", "8x")
	assert_eq(String(s.get_value(GameSettings.VIDEO, &"quality_preset")), "custom", "a hand edit -> custom")
	s.set_value(GameSettings.VIDEO, &"msaa", "off")
	assert_eq(String(s.get_value(GameSettings.VIDEO, &"quality_preset")), "low", "back on the preset's values -> low")
	s.set_value(GameSettings.VIDEO, &"quality_preset", "custom")
	assert_eq(String(s.get_value(GameSettings.VIDEO, &"msaa")), "off", "picking custom changes nothing")
	s.set_value(GameSettings.VIDEO, &"quality_preset", "ultra")
	assert_eq(String(s.get_value(GameSettings.VIDEO, &"msaa")), "8x")
	assert_eq(s.matching_preset(), "ultra")


func test_resolution_interact_and_round_trip() -> void:
	var s: GameSettings = GameSettings.new()
	s.set_value(GameSettings.VIDEO, &"resolution", "1600x900")
	assert_eq(s.resolution(), Vector2i(1600, 900))
	s.set_value(GameSettings.VIDEO, &"resolution", "999x999")
	assert_eq(s.resolution(), Vector2i.ZERO, "an unknown size falls back to auto")
	s.set_value(GameSettings.CONTROLS, &"interact_mode", "toggle")
	assert_true(s.is_toggle(&"interact"))
	s.set_value(GameSettings.VIDEO, &"resolution", "2560x1440")
	s.set_value(GameSettings.VIDEO, &"quality_preset", "medium")
	assert_eq(s.save(), OK)
	var back: GameSettings = GameSettings.load_file()
	assert_true(back.equals(s), "saved and loaded")
	assert_eq(String(back.get_value(GameSettings.VIDEO, &"quality_preset")), "medium")
	assert_true(back.is_toggle(&"interact"))


func test_applier_sets_the_shadow_atlas() -> void:
	var vp: SubViewport = SubViewport.new()
	add_child(vp)
	var s: GameSettings = GameSettings.new()
	s.set_value(GameSettings.VIDEO, &"shadow_quality", "low")
	SettingsApplier.apply_video(s, vp)
	assert_eq(vp.positional_shadow_atlas_size, 1024)
	s.set_value(GameSettings.VIDEO, &"quality_preset", "high")
	SettingsApplier.apply_video(s, vp)
	assert_eq(vp.positional_shadow_atlas_size, 4096, "high = Godot's default")
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	vp.queue_free()


func test_screen_rows_follow_the_preset() -> void:
	var o: OptionsScreen = SCREEN_SCENE.instantiate() as OptionsScreen
	o.settings = GameSettings.new()
	o.save_on_apply = false
	add_child(o)
	await wait_frames(2)
	var video: Node = o.pages[&"video"] as Node
	for key: String in ["resolution", "quality_preset", "shadow_quality"]:
		assert_true(video.find_child("Row_" + key, true, false) != null, "video row %s" % key)
	assert_true((o.pages[&"controls"] as Node).find_child("Row_interact_mode", true, false) != null, "interact row")
	var preset: OptionButton = video.find_child("Row_quality_preset", true, false).get_node("Choice") as OptionButton
	var msaa: OptionButton = video.find_child("Row_msaa", true, false).get_node("Choice") as OptionButton
	for i: int in range(preset.item_count):
		if preset.get_item_metadata(i) == "low":
			preset.select(i)
			preset.item_selected.emit(i)
	await wait_frames(1)
	assert_eq(String(msaa.get_item_metadata(msaa.selected)), "off", "the MSAA row shows the preset's value")
	for i: int in range(msaa.item_count):
		if msaa.get_item_metadata(i) == "8x":
			msaa.select(i)
			msaa.item_selected.emit(i)
	await wait_frames(1)
	assert_eq(String(preset.get_item_metadata(preset.selected)), "custom", "the preset row shows custom")
	o.queue_free()
	await wait_frames(1)
