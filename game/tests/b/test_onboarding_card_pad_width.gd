## LEAD r309 pad pass: on a pad the Stay quiet card's "D-pad Up" cap (throw a bag) widened its row and pushed the card
## past the right edge at 720p. A wide cap takes its width back from the row's text: the card keeps its width.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	OnboardingTips.persist = false


func after_all() -> void:
	InteractionPanel.pad_active = false


func _card_width(pad: bool) -> float:
	InteractionPanel.pad_active = pad
	OnboardingTips.reset()
	var model: MockHudModel = MockHudModel.new()
	model.casing = false
	add_child(model)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.auto_find_model = false
	add_child(hud)
	await wait_frames(1)
	hud.onboarding.show_delay_s = 0.0
	hud.bind(model)
	model.player_mode = &"masked"
	await wait_frames(3)
	assert_eq(hud.onboarding.shown, &"stealth")
	var w: float = hud.onboarding.panel.size.x
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)
	return w


func test_wide_pad_caps_keep_the_card_width() -> void:
	var keys: float = await _card_width(false)
	var pad: float = await _card_width(true)
	assert_true(OnboardingCard.cap_extra("D-pad Up") > 0.0, "a word cap is wider than a letter")
	assert_eq(OnboardingCard.cap_extra("X"), 0.0)
	assert_true(absf(pad - keys) <= 2.0, "same card width on a pad (%.0f) as on keys (%.0f)" % [pad, keys])
	assert_true(pad <= OnboardingCard.WIDTH + 2.0, "never past its width: %.0f" % pad)
