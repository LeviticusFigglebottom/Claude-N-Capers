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


func test_dot_labels_do_not_stack() -> void:
	# Real-input GH Tab shot: far markers close together stacked their distance labels; a dot whose label would sit
	# on another's draws only the dot.
	var taken: Array[Rect2] = [Rect2(Vector2(1200, 420), Vector2(55, 22))]
	assert_true(ObjectiveMarkers.label_overlaps(Rect2(Vector2(1205, 430), Vector2(55, 22)), taken), "stacked")
	assert_false(ObjectiveMarkers.label_overlaps(Rect2(Vector2(1200, 460), Vector2(55, 22)), taken), "clear below")


## LEAD r308 (AH gear prompt): a marker label under the interaction prompt is not drawn (the badge stays); the HUD hands
## the prompt's rect to the markers only while a prompt shows.
func test_marker_label_yields_to_the_prompt() -> void:
	var prompt: Rect2 = Rect2(Vector2(500, 420), Vector2(300, 40))
	assert_true(ObjectiveMarkers.label_hidden_by(Rect2(Vector2(520, 440), Vector2(260, 20)), [Rect2(), prompt]), "under")
	assert_false(ObjectiveMarkers.label_hidden_by(Rect2(Vector2(520, 500), Vector2(260, 20)), [Rect2(), prompt]), "below")
	assert_false(ObjectiveMarkers.label_hidden_by(Rect2(Vector2(520, 440), Vector2(260, 20)), [Rect2(), Rect2()]), "none")
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = (load("res://content/ui/hud/hud.tscn") as PackedScene).instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
	await wait_frames(1)
	hud.bind(model)
	model.interaction = {}
	await wait_frames(2)
	assert_false(hud.objective_markers.prompt_band.has_area(), "no prompt: no band")
	model.interaction = {"text_key": &"ui.prompt.interact", "args": {}, "progress": 0.0}
	await wait_frames(3)
	assert_true(hud.objective_markers.prompt_band.has_area(), "a prompt shows: its band reaches the markers")
	# LEAD r309: the open onboarding card is a band too (a label ran under the Stay quiet card).
	assert_false(hud.objective_markers.card_band.has_area(), "no card: no band")
	hud.onboarding.show_delay_s = 0.0
	OnboardingTips.persist = false
	OnboardingTips.reset()
	model.player_mode = &"masked"
	await wait_frames(3)
	assert_true(hud.onboarding.visible)
	assert_eq(hud.objective_markers.card_band.size, hud.onboarding.panel.get_global_rect().size,
			"the card's rect reaches the markers (it slides in: the size, not the spot)")
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)
