## PO-4 lane 11: first-time onboarding cards show once per situation (casing, stealth, loud, escape),
## one at a time, and are remembered in the profile's settings (OnboardingTips).
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel
var _card: OnboardingCard


func before_each() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	OnboardingTips.persist = false
	OnboardingTips.reset()
	_model = MockHudModel.new()
	_model.casing = false  # no situation until a test sets one
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	add_child(_hud)
	await wait_frames(1)
	_card = _hud.onboarding
	_card.show_delay_s = 0.0
	_hud.bind(_model)


func after_each() -> void:
	_hud.queue_free()
	_model.queue_free()
	await wait_frames(1)
	OnboardingTips.persist = true
	OnboardingTips.reset()
	OnboardingTips._loaded = false
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_each_situation_shows_its_card_once() -> void:
	assert_false(_card.visible, "no situation yet: hidden")
	_model.player_mode = &"casing"
	assert_eq(_card.shown, &"casing")
	assert_true(_card.visible)
	assert_eq(_card.title.text, UiText.t(&"ui.tip.casing.title"))
	assert_eq(_card.rows_box.get_child_count(), 4, "four short rows, not a wall of text")
	_card.dismiss()
	assert_false(_card.visible)
	_model.player_mode = &"civilian"
	_model.player_mode = &"casing"
	assert_false(_card.visible, "casing card shows only the first time")
	_model.player_mode = &"masked"
	assert_eq(_card.shown, &"stealth")
	_card.dismiss()
	_model.heist_phase = Enums.HeistPhase.LOUD
	assert_eq(_card.shown, &"loud")
	_card.dismiss()
	_model.heist_phase = Enums.HeistPhase.ESCAPE
	assert_eq(_card.shown, &"escape")
	assert_eq(OnboardingTips.seen_ids(), ["casing", "stealth", "loud", "escape"])


func test_a_new_situation_replaces_the_open_card() -> void:
	_model.player_mode = &"casing"
	assert_eq(_card.shown, &"casing")
	_model.player_mode = &"masked"
	assert_eq(_card.shown, &"stealth", "masking up ends casing: the stealth card takes over (h02)")
	_model.assault_phase = Enums.AssaultPhase.BUILD
	assert_eq(_card.shown, &"loud", "the alarm ends stealth")
	_model.player_mode = &"casing"
	assert_eq(_card.shown, &"loud", "a seen situation never takes over")


func test_card_times_out_and_dismiss_key_closes_it() -> void:
	_model.player_mode = &"casing"
	_card._process(OnboardingCard.DWELL_S + 0.1)
	assert_false(_card.visible, "auto-hides after DWELL_S")
	_model.player_mode = &"masked"
	assert_true(_card.visible)
	var k: InputEvent = _dismiss_event()
	_card._input(k)
	assert_false(_card.visible, "H closes the card")


func test_delay_before_showing() -> void:
	_card.show_delay_s = 1.0
	_model.player_mode = &"casing"
	assert_false(_card.visible, "waits for the situation to settle")
	_card._process(1.1)
	assert_eq(_card.shown, &"casing")


func test_seen_tips_persist_in_profile_settings() -> void:
	OnboardingTips.persist = true
	var saved: Array = []
	# The runner scene blocks writes; exercise the profile round trip directly.
	var p: PlayerProfile = PlayerProfile.new_default()
	p.settings[OnboardingTips.SETTINGS_KEY] = ["casing", "loud"]
	SaveService.save_profile(p, 0)
	saved = SaveService.load_profile(0).settings.get(OnboardingTips.SETTINGS_KEY, []) as Array
	assert_eq(saved, ["casing", "loud"], "stored as a plain array in the free-form settings dict")
	assert_false(OnboardingTips._writes(), "never writes the real save from inside the test runner")


## The dismiss_tip action's first event (D-096), or H before the action exists.
func _dismiss_event() -> InputEvent:
	if InputMap.has_action(OnboardingCard.DISMISS_ACTION):
		for ev: InputEvent in InputMap.action_get_events(OnboardingCard.DISMISS_ACTION):
			var e: InputEvent = ev.duplicate() as InputEvent
			if e is InputEventKey:
				(e as InputEventKey).pressed = true
				return e
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = OnboardingCard.DISMISS_KEY
	k.pressed = true
	return k


func test_card_hides_while_the_scoreboard_is_up() -> void:
	_model.player_mode = &"casing"
	_hud.scoreboard.set_process(false)
	_hud.scoreboard.set_shown(true)
	await wait_frames(1)
	assert_false(_card.visible, "the Tab sheet covers the card")
	assert_eq(_card.shown, &"casing", "still open underneath")
	_hud.scoreboard.set_shown(false)
	await wait_frames(1)
	assert_true(_card.visible)


func test_card_hides_while_paused() -> void:
	_model.player_mode = &"casing"
	await wait_frames(1)
	assert_true(_card.visible)
	MouseCapture.push_release(&"pause")
	await wait_frames(1)
	assert_false(_card.visible, "the pause menu's job card sits on the card's spot")
	MouseCapture.pop_release(&"pause")
	await wait_frames(1)
	assert_true(_card.visible, "back after resuming")
