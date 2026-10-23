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
