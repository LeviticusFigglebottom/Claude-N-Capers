## D-117 §2: Lethal / Cataclysm are shown locked and open by progression: Lethal after any heist won on the top
## build-pickable difficulty (Brutal), Cataclysm after a Lethal win (Career wins per heist and difficulty).
extends TestCase

const LETHAL: int = 4
const CATACLYSM: int = 5


func after_each() -> void:
	HeistCatalog.progress_profile = null


func _win(p: PlayerProfile, d: int) -> void:
	Career.record(p, {"heist_id": "glasshouse", "success": true, "stealth": false, "difficulty": d}, {"success": true}, -1)


func test_progression_unlocks_in_order() -> void:
	assert_true(HeistCatalog.is_progression_difficulty(LETHAL) and HeistCatalog.is_progression_difficulty(CATACLYSM))
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_false(HeistCatalog.is_difficulty_unlocked(LETHAL, p), "fresh profile: Lethal locked")
	assert_false(HeistCatalog.is_difficulty_unlocked(CATACLYSM, p))
	assert_true(HeistCatalog.is_difficulty_unlocked(3, p), "Brutal is in the build list")
	_win(p, 2)
	assert_false(HeistCatalog.is_difficulty_unlocked(LETHAL, p), "a Hazardous win is not enough")
	_win(p, 3)
	assert_true(HeistCatalog.is_difficulty_unlocked(LETHAL, p), "a Brutal win opens Lethal")
	assert_false(HeistCatalog.is_difficulty_unlocked(CATACLYSM, p), "Cataclysm still needs a Lethal win")
	_win(p, LETHAL)
	assert_true(HeistCatalog.is_difficulty_unlocked(CATACLYSM, p), "a Lethal win opens Cataclysm")
	assert_eq(Career.best_difficulty_any(p), LETHAL)


func test_menus_read_the_progress_profile() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	HeistCatalog.progress_profile = p
	assert_false(HeistCatalog.is_difficulty_unlocked(LETHAL))
	_win(p, 3)
	assert_true(HeistCatalog.is_difficulty_unlocked(LETHAL), "default profile = MenuFlow's")
	assert_true(BoardContracts.build_gate().call(LETHAL), "the Board gate follows")
	var tip: String = UiText.t(&"ui.heist_select.difficulty_locked_progress", {"name": "Cataclysm", "prev": "Lethal"})
	assert_true(tip.contains("Lethal") and not tip.contains("{"), tip)


func test_board_locked_text_names_every_condition() -> void:
	var tw: BoardTweak = BoardTweak.new()
	tw.difficulty_min_level = [0, 0, 0, 0, 80, 80]
	var p: PlayerProfile = PlayerProfile.new_default()
	var gate: Callable = func(d: int) -> bool: return HeistCatalog.is_difficulty_unlocked(d, p)
	var both: String = BoardContracts.locked_text(LETHAL, 10, tw, gate)
	assert_true(both.contains("80") and both.contains("Brutal"), "level and win both named: %s" % both)
	_win(p, 3)
	var level_only: String = BoardContracts.locked_text(LETHAL, 10, tw, gate)
	assert_true(level_only.contains("80") and not level_only.contains("Brutal"), level_only)
	var win_only: String = BoardContracts.locked_text(CATACLYSM, 90, tw, gate)
	assert_true(win_only.contains("Lethal") and not win_only.contains("80"), win_only)
