## B1-04: payday screen totals equal PayoutCalculator output, XP lines in C6 order, the payout is
## applied to the profile (SaveService) exactly once, and D-022's banked stealth bonus is used.
extends TestCase

const TEST_ROOT: String = "user://test_profiles"
const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")

var _screen: PaydayScreen


func before_all() -> void:
	SaveService.root_dir = TEST_ROOT


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	_screen = PAYDAY_SCENE.instantiate() as PaydayScreen
	add_child(_screen)
	await wait_frames(1)


func after_each() -> void:
	_screen.queue_free()
	await wait_frames(1)


func test_routine_totals_match_calculator() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	assert_eq(int(result["difficulty"]), Enums.Difficulty.ROUTINE)
	var expected: Dictionary = PayoutCalculator.compute(result, null, null, false, Net.local_slot(), 1.0)
	_screen.show_result(result)
	assert_eq(_screen.payout, expected, "screen uses PayoutCalculator output as-is")
	for key: String in ["contract", "small_loot", "total", "stash", "spending"]:
		assert_eq((_screen.value_labels[StringName(key)] as Label).text, UiText.money(int(expected[key])), key)
	assert_eq((_screen.value_labels[&"civilian_penalty"] as Label).text, UiText.money(-int(expected["civilian_penalty"])))
	assert_eq((_screen.value_labels[&"xp_total"] as Label).text, UiText.group_digits(int(expected["xp_total"])))
	for line: Dictionary in expected["xp_lines"] as Array:
		assert_has(_screen.value_labels, StringName("xp." + String(line["key"])))


func test_payout_applied_to_profile_once() -> void:
	var result: Dictionary = HeistCatalog.sample_result()
	_screen.show_result(result)
	var p: PlayerProfile = SaveService.load_profile(0)
	assert_eq(p.stash, int(_screen.payout["stash"]))
	assert_eq(p.cash, int(_screen.payout["spending"]))
	assert_eq(p.xp, int(_screen.payout["xp_total"]))
	assert_eq(p.level, XpCurve.level_for_xp(p.xp))
	assert_eq(int(p.stats.get("heists_completed", 0)), 1)
	assert_true(p.banked_stealth_mult > 1.0, "stealth success banks the bonus (D-022)")


func test_banked_bonus_used_on_next_payday() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.banked_stealth_mult = 1.2
	_screen.apply_to_profile = false
	_screen.setup(p)
	var result: Dictionary = HeistCatalog.sample_result()
	_screen.show_result(result)
	var expected: Dictionary = PayoutCalculator.compute(result, null, null, false, Net.local_slot(), 1.2)
	assert_eq(_screen.payout, expected)
	assert_eq(_screen.xp_after, p.xp + int(expected["xp_total"]))
	assert_false(FileAccess.file_exists(SaveService.profile_path(0)), "apply_to_profile=false writes nothing")


func test_shows_on_heist_ended_when_listening() -> void:
	_screen.queue_free()
	_screen = PAYDAY_SCENE.instantiate() as PaydayScreen
	_screen.listen_heist_ended = true
	_screen.apply_to_profile = false
	_screen.visible = false
	add_child(_screen)
	await wait_frames(1)
	EventBus.heist_ended.emit(HeistCatalog.sample_result())
	assert_true(_screen.visible)
	assert_false(_screen.payout.is_empty())
