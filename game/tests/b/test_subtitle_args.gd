## HUD readability pass (GH loud capture): "Van's 240.0 seconds out": a float argument (the escape ETA)
## reads as whole seconds in subtitles.
extends TestCase

var _saved: GameSettings


func before_all() -> void:
	_saved = GameSettings.current()
	GameSettings.set_current(GameSettings.new())


func after_all() -> void:
	GameSettings.set_current(_saved)


func test_float_args_read_as_whole_numbers() -> void:
	var o: SubtitleOverlay = SubtitleOverlay.new()
	o.auto_process = false
	add_child(o)
	assert_true(o.show_line(&"mercer", &"vo.mercer.glasshouse_van_eta", {"seconds": 240.0}))
	var text: String = (o.rows[0]["text"] as Label).text
	assert_true(text.contains("240 seconds") and not text.contains("240.0"), text)
	o.queue_free()
	await wait_frames(1)
