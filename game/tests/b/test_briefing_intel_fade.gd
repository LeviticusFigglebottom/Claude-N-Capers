## LEAD r307 (720p: KNOWN SECURITY cut mid-line in the briefing's intel column): the column scrolls, and a fade over
## its foot says so while more lies below; it hides at the end of the column and when everything fits.
extends TestCase

const SCENE: String = "res://content/ui/briefing/briefing_screen.tscn"


func _screen(box_size: Vector2) -> BriefingScreen:
	var host: Control = Control.new()
	host.size = box_size
	add_child(host)
	var s: BriefingScreen = (load(SCENE) as PackedScene).instantiate() as BriefingScreen
	s.setup(&"gallery_night", Enums.Difficulty.HAZARDOUS)  # GN: the longest security list (14 items)
	host.add_child(s)
	return s


func test_fade_marks_more_below_and_clears_at_the_end() -> void:
	var s: BriefingScreen = _screen(Vector2(1280, 560))
	await wait_frames(6)
	assert_true(s.intel_overflows(), "a short page: the intel column scrolls")
	assert_true(s.intel_fade.visible, "more below: the fade shows")
	assert_true(s.intel_scroll.get_v_scroll_bar().visible, "and the scroll bar")
	s.intel_scroll.scroll_vertical = 100000
	await wait_frames(3)
	assert_false(s.intel_fade.visible, "scrolled to the end: no fade")
	s.get_parent().queue_free()
	await wait_frames(1)


func test_no_fade_when_it_fits() -> void:
	var s: BriefingScreen = _screen(Vector2(1920, 3000))
	await wait_frames(6)
	assert_false(s.intel_overflows(), "a tall page holds the whole column")
	assert_false(s.intel_fade.visible)
	s.get_parent().queue_free()
	await wait_frames(1)


func _stick(value: float) -> void:
	var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_RIGHT_Y
	m.axis_value = value
	Input.parse_input_event(m)
	await wait_frames(2)


func test_right_stick_scrolls_the_column_and_the_cue_names_it() -> void:
	# LEAD r309 pad pass: the intel labels take no focus, so the right stick scrolls the column.
	var s: BriefingScreen = _screen(Vector2(1280, 560))
	await wait_frames(6)
	assert_eq(s.intel_scroll.scroll_vertical, 0)
	await _stick(1.0)
	await wait_frames(10)
	await _stick(0.0)
	var down: int = s.intel_scroll.scroll_vertical
	assert_true(down > 0, "stick down scrolls down")
	assert_true(InteractionPanel.pad_active, "the stick counts as pad input")
	assert_true(s.more_below.text.contains(UiText.t(&"ui.key.pad.rs")), "the cue names the stick: %s" % s.more_below.text)
	await wait_frames(5)
	assert_eq(s.intel_scroll.scroll_vertical, down, "the stick at rest: no drift")
	await _stick(-0.1)
	await wait_frames(5)
	assert_eq(s.intel_scroll.scroll_vertical, down, "inside the dead zone: no scroll")
	await _stick(-1.0)
	await wait_frames(30)
	await _stick(0.0)
	assert_eq(s.intel_scroll.scroll_vertical, 0, "stick up scrolls back to the top")
	s.get_parent().queue_free()
	await wait_frames(1)
