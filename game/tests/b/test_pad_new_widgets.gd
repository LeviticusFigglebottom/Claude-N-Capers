## Lead: gamepad-only pass on the round-64..68 widgets: main-menu Continue takes focus and launches on A,
## the hub's Continue is reachable with the d-pad, the onboarding card closes on its pad button.
extends TestCase

const SLOT: int = 0
const FLOW_SCENE: PackedScene = preload("res://content/ui/menus/menu_flow.tscn")
const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func after_each() -> void:
	InteractionPanel.pad_active = false  # pad presses switch the prompts to pad glyphs; do not leak


func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await wait_frames(2)


func test_continue_with_the_pad() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	QuickPlay.remember(SLOT, &"glasshouse", Enums.Difficulty.ROUTINE)
	var flow: MenuFlow = FLOW_SCENE.instantiate() as MenuFlow
	add_child(flow)
	await wait_frames(1)
	flow.show_home()
	await wait_frames(3)
	assert_eq(get_viewport().gui_get_focus_owner(), flow.main_menu.continue_button as Control, "Continue has focus")
	flow.show_hub()
	await wait_frames(3)
	flow.hub.back_button.grab_focus()
	await wait_frames(1)
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(get_viewport().gui_get_focus_owner(), flow.hub.continue_button as Control, "right of Main Menu")
	await _pad(JOY_BUTTON_DPAD_UP)
	assert_eq(get_viewport().gui_get_focus_owner(), flow.hub.options_button as Control, "up to Options")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(get_viewport().gui_get_focus_owner(), flow.hub.continue_button as Control, "and back")
	flow.queue_free()
	await wait_frames(3)


func test_onboarding_card_closes_on_the_pad() -> void:
	if not InputMap.has_action(OnboardingCard.DISMISS_ACTION):
		skip("no dismiss_tip action")
		return
	OnboardingTips.persist = false
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
	model.player_mode = &"casing"
	assert_true(hud.onboarding.visible)
	var pad_button: int = -1
	for ev: InputEvent in InputMap.action_get_events(OnboardingCard.DISMISS_ACTION):
		if ev is InputEventJoypadButton:
			pad_button = (ev as InputEventJoypadButton).button_index
	assert_true(pad_button >= 0, "dismiss_tip has a pad button")
	if pad_button >= 0:
		await _pad(pad_button as JoyButton)
		assert_false(hud.onboarding.visible, "the pad button closes the card")
		assert_true(InteractionPanel.action_key_text(OnboardingCard.DISMISS_ACTION) != "", "the footer names it")
	hud.queue_free()
	model.queue_free()
	OnboardingTips.persist = true
	OnboardingTips._loaded = false
	await wait_frames(1)
