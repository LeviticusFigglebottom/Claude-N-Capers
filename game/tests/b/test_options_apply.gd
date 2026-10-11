## B5-01: SettingsApplier pushes audio bus volumes into AudioServer (linear -> dB on top of the bus
## layout's mix level, mute at 0), video options into a viewport, and brightness into an Environment.
extends TestCase


func after_all() -> void:
	SettingsApplier.apply_audio(GameSettings.new())
	Engine.max_fps = 0


func test_bus_volume_applies_to_audio_server() -> void:
	var s: GameSettings = GameSettings.new()
	SettingsApplier.apply_audio(s)
	for bus: StringName in s.defaults.keys(GameSettings.AUDIO):
		assert_true(AudioServer.get_bus_index(bus) >= 0, "bus %s exists after apply" % bus)
	var idx: int = AudioServer.get_bus_index(&"SFX")
	var base: float = SettingsApplier.base_db(&"SFX")
	s.set_value(GameSettings.AUDIO, &"SFX", 0.5)
	SettingsApplier.apply_audio(s)
	assert_near(AudioServer.get_bus_volume_db(idx), base + linear_to_db(0.5), 0.01, "half = about -6 dB")
	assert_false(AudioServer.is_bus_mute(idx))
	s.set_value(GameSettings.AUDIO, &"SFX", 0.0)
	s.apply()
	assert_true(AudioServer.is_bus_mute(idx), "0 mutes")
	s.set_value(GameSettings.AUDIO, &"SFX", 1.0)
	SettingsApplier.apply_audio(s)
	assert_false(AudioServer.is_bus_mute(idx))
	assert_near(AudioServer.get_bus_volume_db(idx), base, 0.01, "full = the layout's own level")
	var amb: int = AudioServer.get_bus_index(&"Ambience")
	assert_near(AudioServer.get_bus_volume_db(amb), SettingsApplier.base_db(&"Ambience"), 0.01, "mix level kept, not reset to 0 dB")
	s.set_value(GameSettings.AUDIO, &"Music", 0.25)
	SettingsApplier.apply_audio(s)
	SettingsApplier.apply_audio(s)
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), SettingsApplier.base_db(&"Music") + linear_to_db(0.25),
			0.01, "re-applying does not compound")
	assert_false(SettingsApplier.set_bus_volume(&"NoSuchBus", 0.5))


func test_video_applies_to_the_viewport() -> void:
	var vp: SubViewport = SubViewport.new()
	add_child(vp)
	var s: GameSettings = GameSettings.new()
	s.set_value(GameSettings.VIDEO, &"render_scale", 0.75)
	s.set_value(GameSettings.VIDEO, &"msaa", "8x")
	s.set_value(GameSettings.VIDEO, &"fxaa", true)
	s.set_value(GameSettings.VIDEO, &"max_fps", 120)
	SettingsApplier.apply_video(s, vp)
	assert_near(vp.scaling_3d_scale, 0.75)
	assert_eq(vp.msaa_3d, Viewport.MSAA_8X)
	assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA)
	assert_eq(Engine.max_fps, 120)
	s.set_value(GameSettings.VIDEO, &"msaa", "off")
	s.set_value(GameSettings.VIDEO, &"fxaa", false)
	s.set_value(GameSettings.VIDEO, &"max_fps", 0)
	SettingsApplier.apply_video(s, vp)
	assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_eq(Engine.max_fps, 0)
	vp.queue_free()
	await wait_frames(1)


func test_brightness_helper() -> void:
	var env: Environment = Environment.new()
	var s: GameSettings = GameSettings.new()
	SettingsApplier.apply_environment(env, s)
	assert_false(env.adjustment_enabled, "default brightness leaves the environment alone")
	s.set_value(GameSettings.VIDEO, &"brightness", 1.3)
	SettingsApplier.apply_environment(env, s)
	assert_true(env.adjustment_enabled)
	assert_near(env.adjustment_brightness, 1.3)
	SettingsApplier.apply_environment(null, s)
