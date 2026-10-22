## LEAD r266, from GPU-20c's OF payday (gpu/renders/a/of_a6b_b2700/24_payday.png): the AI crew killed 6 civilians
## (Rook 4, Dutch 2) and the Cash panel showed no cleaner cost. pd2_fidelity S7.3: a civilian kill costs
## DifficultyDef.civilian_kill_penalty, **deducted from the killer's payout**. AI teammates hold their own crew slots,
## so their kills charge nobody's payday (PD2 bills the killing player). These pin that, plus the payday's
## opaque backdrop covering the whole window on an ultrawide (it stopped at the 16:9 column at 3440x1440).
extends TestCase

const PAYDAY: PackedScene = preload("res://content/ui/results/payday.tscn")
const OPTIONS: PackedScene = preload("res://content/ui/menus/options_screen.tscn")
const HAZARDOUS: DifficultyDef = preload("res://content/data/difficulty/hazardous.tres")


func _result(crew_civs: Array[int], ai_from: int) -> Dictionary:
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	r["heist_id"] = &"ostrander_federal"
	r["difficulty"] = Enums.Difficulty.HAZARDOUS
	var crew: Array = []
	for slot: int in range(crew_civs.size()):
		crew.append({"slot": slot, "is_ai": slot >= ai_from, "kills": 0, "specials_killed": 0, "downs": 0,
			"civilians_killed": crew_civs[slot], "in_custody": false, "escaped": true})
	r["crew"] = crew
	return r


func test_ai_teammates_civilian_kills_cost_the_player_nothing() -> void:
	var r: Dictionary = _result([0, 4, 2, 0] as Array[int], 1)  # GPU-20c: Rook 4, Dutch 2, the player 0
	var mine: Dictionary = PayoutCalculator.compute(r, null, null, false, 0)
	assert_eq(int(mine["civilian_penalty"]), 0, "the player killed none: no cleaner cost on their payday")
	var crew_wide: Dictionary = PayoutCalculator.compute(r, null, null, false, -1)
	var per: int = HAZARDOUS.civilian_kill_penalty
	assert_eq(int(crew_wide["civilian_penalty"]), 6 * per, "the crew-wide view still counts every kill")


func test_the_players_own_civilian_kills_are_charged_and_shown() -> void:
	var r: Dictionary = _result([2, 4, 0, 0] as Array[int], 1)
	var per: int = HAZARDOUS.civilian_kill_penalty
	assert_true(per > 0, "Hazardous has a cleaner cost")
	var mine: Dictionary = PayoutCalculator.compute(r, null, null, false, 0)
	assert_eq(int(mine["civilian_penalty"]), 2 * per, "only the player's own 2 kills")
	var pd: PaydayScreen = PAYDAY.instantiate() as PaydayScreen
	pd.cards_enabled = false
	pd.apply_to_profile = false
	add_child(pd)
	await wait_frames(1)
	pd.setup(PlayerProfile.new_default())
	pd.show_result(r)
	await wait_frames(2)
	# No Net session here (local_slot -1): the screen still bills only the local player's own kills.
	assert_eq(int(pd.payout["civilian_penalty"]), 2 * per, "the payday screen charges the player's 2, not the crew's 6")
	var shown: bool = false
	for n: Node in pd.find_children("*", "Label", true, false):
		var l: Label = n as Label
		if l.is_visible_in_tree() and l.text.contains(UiText.group_digits(2 * per)):
			shown = true
	assert_true(shown, "the cleaner cost line is on the payday")
	pd.queue_free()
	await wait_frames(1)


func test_backdrop_covers_the_whole_ultrawide_window() -> void:
	var saved: Vector2i = get_window().size
	get_window().size = Vector2i(3440, 1440)
	var pd: PaydayScreen = PAYDAY.instantiate() as PaydayScreen
	pd.cards_enabled = false
	pd.apply_to_profile = false
	add_child(pd)
	await wait_frames(3)
	var view: Rect2 = get_viewport().get_visible_rect()
	assert_true(pd.size.x < view.size.x - 1.0, "the content column is narrower than the 21:9 canvas")
	assert_eq(pd.window_fill.size(), 1, "the backdrop is registered")
	var back: Rect2 = pd.window_fill[0].get_global_rect()
	assert_true(back.grow(1.0).encloses(view), "backdrop %s covers the window %s" % [back, view])
	pd.queue_free()
	get_window().size = saved
	await wait_frames(1)


## r268: the Options screen opens from the in-heist pause over the map; its background covers the 21:9 window too.
func test_options_background_covers_the_whole_ultrawide_window() -> void:
	var saved: Vector2i = get_window().size
	get_window().size = Vector2i(3440, 1440)
	var s: UiScreen = OPTIONS.instantiate() as UiScreen
	add_child(s)
	await wait_frames(3)
	var view: Rect2 = get_viewport().get_visible_rect()
	assert_true(s.size.x < view.size.x - 1.0, "the content column is narrower than the 21:9 canvas")
	assert_eq(s.window_fill.size(), 1, "the background is registered")
	var back: Rect2 = s.window_fill[0].get_global_rect()
	assert_true(back.grow(1.0).encloses(view), "background %s covers the window %s" % [back, view])
	s.queue_free()
	get_window().size = saved
	await wait_frames(1)

