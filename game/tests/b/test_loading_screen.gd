## Lead queue (b): the heist loading screen names the heist and rotates tips (never the same twice).
extends TestCase


func test_names_the_heist_and_rotates_tips() -> void:
	var l: LoadingScreen = LoadingScreen.new()
	l.setup(&"glasshouse", Enums.Difficulty.ROUTINE)
	add_child(l)
	await wait_frames(1)
	assert_eq(l.title.text, UiText.t(&"heist.glasshouse.name"))
	assert_true(l.caption.text.contains(UiText.t(UiText.difficulty_key(Enums.Difficulty.ROUTINE)).to_upper()))
	var first: int = l.tip_index
	assert_true(first >= 0 and first < LoadingScreen.TIP_COUNT)
	assert_false(l.tip_label.text.begins_with("ui."), "tip string exists")
	l._process(LoadingScreen.TIP_S + 0.01)
	assert_ne(l.tip_index, first, "a new tip after TIP_S")
	l.queue_free()


func test_every_tip_string_exists() -> void:
	for i: int in range(LoadingScreen.TIP_COUNT):
		var k: StringName = StringName("ui.loading.tip.%d" % (i + 1))
		assert_ne(UiText.t(k), String(k), "%s is in strings.csv" % k)
