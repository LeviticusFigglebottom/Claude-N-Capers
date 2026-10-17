## LEAD r230 (gh_camera_02 nit): an on-screen objective marker that would sit under the subtitle box is lifted above it;
## markers clear of the box, or with no box showing, stay where they are. The HUD finds the box through
## SubtitleOverlay.GROUP.
extends TestCase


func test_marker_lifts_above_the_subtitle_box() -> void:
	var band: Rect2 = Rect2(Vector2(560, 850), Vector2(800, 140))
	var under: Vector2 = Vector2(960, 900)
	var lifted: Vector2 = ObjectiveMarkers.clear_of_band(under, band)
	assert_eq(lifted.x, under.x, "same column")
	var reach: float = ObjectiveMarkers.SIZE * 1.6 + UiTokens.FONT_SMALL + 6.0
	assert_true(lifted.y + reach <= band.position.y + 0.01, "badge and distance line end above the box (%s)" % lifted)
	assert_eq(ObjectiveMarkers.clear_of_band(Vector2(300, 900), band), Vector2(300, 900), "beside the box: unchanged")
	assert_eq(ObjectiveMarkers.clear_of_band(Vector2(960, 500), band), Vector2(960, 500), "well above: unchanged")
	assert_eq(ObjectiveMarkers.clear_of_band(under, Rect2()), under, "no box showing: unchanged")


func test_hud_reads_the_subtitle_box() -> void:
	var sub: SubtitleOverlay = SubtitleOverlay.new()
	sub.auto_process = false
	add_child(sub)
	await wait_frames(1)
	assert_true(sub.is_in_group(SubtitleOverlay.GROUP), "the overlay joins its group")
	sub.queue_free()
	await wait_frames(1)
