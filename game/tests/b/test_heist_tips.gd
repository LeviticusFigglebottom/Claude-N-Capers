## D-115: every built heist has one first-time card for its own mechanics (OnboardingCard, OnboardingTips.HEISTS).
## It queues behind the situation cards, shows once per profile, and never shows in another heist.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")

var _hud: Hud
var _model: MockHudModel
var _card: OnboardingCard
var _table: Dictionary = {}


func before_all() -> void:
	_table = StringTable.parse_csv(StringTable.CSV_PATH)


func before_each() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	OnboardingTips.persist = false
	OnboardingTips.reset()


func after_each() -> void:
	await _teardown()
	OnboardingTips.persist = true
	OnboardingTips.reset()
	OnboardingTips._loaded = false
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


## A fresh HUD + model for one run of `heist_id` (the profile's seen tips carry over between runs).
func _start_run(heist_id: StringName) -> void:
	await _teardown()
	_model = MockHudModel.new()
	_model.casing = false  # no situation until the test sets one
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	_hud.heist_id = heist_id
	add_child(_hud)
	await wait_frames(1)
	_card = _hud.onboarding
	_card.show_delay_s = 0.0
	_hud.bind(_model)


func _teardown() -> void:
	if _hud != null:
		_hud.queue_free()
		_hud = null
	if _model != null:
		_model.queue_free()
		_model = null
	await wait_frames(1)


func test_each_heist_shows_its_card_once_per_profile() -> void:
	for h: StringName in OnboardingTips.HEISTS:
		OnboardingTips.reset()
		var tip: StringName = OnboardingTips.heist_tip(h)
		await _start_run(h)
		assert_eq(_card.heist_id, h, "the HUD hands its heist to the card")
		_model.player_mode = &"casing"
		assert_eq(_card.shown, &"casing", "%s: the generic casing card comes first" % h)
		_card.dismiss()
		assert_eq(_card.shown, tip, "%s: its heist card queues right behind" % h)
		assert_true(_card.visible)
		assert_eq(_card.title.text, UiText.t(StringName("ui.tip.%s.title" % tip)))
		assert_eq(_card.step_label.text, UiText.t(StringName("heist.%s.name" % h)), "the counter slot names the heist")
		var rows: int = _card.rows_box.get_child_count()
		assert_true(rows >= 2 and rows <= 4, "%s: 2-4 short rows (%d)" % [h, rows])
		_card.dismiss()
		assert_false(_card.visible)
		assert_true(OnboardingTips.seen_ids().has(String(tip)), "stored with the other seen tips")
		# Second run on the same profile: nothing shows.
		await _start_run(h)
		_model.player_mode = &"casing"
		_card._process(OnboardingCard.SHOW_DELAY_S + 0.1)
		assert_eq(_card.shown, &"", "%s: second run, no card" % h)
		assert_false(_card.visible)


func test_card_text_keys_exist_and_resolve() -> void:
	for h: StringName in OnboardingTips.HEISTS:
		var tip: StringName = OnboardingTips.heist_tip(h)
		assert_true(OnboardingCard.ROWS.has(tip), "%s has rows" % tip)
		var keys: Array[String] = ["ui.tip.%s.title" % tip, "heist.%s.name" % h]
		for r: Array in OnboardingCard.ROWS.get(tip, []) as Array:
			keys.append(String(r[1]))
			var action: StringName = StringName(r[0])
			assert_true(action == &"" or InputMap.has_action(action), "%s: key glyph action %s exists" % [tip, action])
		for k: String in keys:
			assert_true(_table.has(k), "strings.csv has %s" % k)
			assert_true(UiText.t(StringName(k)) != k and UiText.t(StringName(k)).strip_edges() != "", "%s resolves" % k)


func test_card_never_shows_for_another_heist() -> void:
	await _start_run(&"glasshouse")
	var other: Array[StringName] = []
	for h: StringName in OnboardingTips.HEISTS:
		if h != &"glasshouse":
			other.append(OnboardingTips.heist_tip(h))
	_model.player_mode = &"casing"
	var seen: Array[StringName] = []
	for i: int in 8:
		if _card.shown != &"":
			seen.append(_card.shown)
		_card.dismiss()
	_model.player_mode = &"masked"
	if _card.shown != &"":
		seen.append(_card.shown)
	assert_eq(seen, [&"casing", &"heist_glasshouse", &"stealth"] as Array[StringName])
	for t: StringName in other:
		assert_false(OnboardingTips.is_seen(t), "%s untouched by a Glasshouse run" % t)
	# A heist without a card (and the HUD demo, no heist) only ever shows the situation cards.
	OnboardingTips.reset()
	await _start_run(&"no_card_heist")  # every listed heist has a card since Afterhours (r299)
	_model.player_mode = &"casing"
	_card.dismiss()
	assert_eq(_card.shown, &"", "no heist card for a heist without one")
	OnboardingTips.reset()
	await _start_run(&"")
	_model.player_mode = &"casing"
	_card.dismiss()
	assert_eq(_card.shown, &"")


func test_heist_card_waits_for_the_heist_and_is_not_replaced() -> void:
	OnboardingTips.mark_seen(&"casing")
	await _start_run(&"gallery_night")
	assert_eq(_card.shown, &"", "no situation yet: nothing")
	_model.player_mode = &"casing"
	assert_eq(_card.shown, &"heist_gallery_night", "a returning player gets the heist card at heist start")
	_model.player_mode = &"masked"
	assert_eq(_card.shown, &"heist_gallery_night", "a new situation does not cut the heist card short")
	_card._process(OnboardingCard.DWELL_S + 0.1)
	assert_eq(_card.shown, &"stealth", "the stealth card follows once it times out")


func test_loud_only_heist_queues_behind_the_loud_card() -> void:
	await _start_run(&"dockside_burn")
	_model.player_mode = &"masked"
	_model.heist_phase = Enums.HeistPhase.LOUD
	assert_eq(_card.shown, &"loud")
	_card.dismiss()
	assert_eq(_card.shown, &"heist_dockside_burn")


func test_civilian_start_shows_the_heist_card_first() -> void:
	# LEAD r308: on a civilian-start heist the heist card ("Guest list") shows at the civilian start, ahead of the
	# casing / stealth cards, which queue behind it.
	await _start_run(&"afterhours")
	_model.player_mode = &"civilian"
	assert_eq(_card.shown, &"heist_afterhours", "the heist card first, at the civilian start")
	_model.player_mode = &"casing"  # gear picked up
	assert_eq(_card.shown, &"heist_afterhours", "the casing situation does not cut it short")
	_card._process(OnboardingCard.DWELL_S + 0.1)
	assert_eq(_card.shown, &"casing", "the casing card follows")
	_card.dismiss()
	_model.player_mode = &"masked"
	assert_eq(_card.shown, &"stealth", "then the stealth card")
	# A returning player (heist card seen) gets nothing in civilian mode: no situation yet.
	await _start_run(&"afterhours")
	_model.player_mode = &"civilian"
	assert_eq(_card.shown, &"")
