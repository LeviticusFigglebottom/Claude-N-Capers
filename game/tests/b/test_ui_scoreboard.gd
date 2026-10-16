## B6-02: the Tab scoreboard overlay builds from MockHudModel.crew_stats (one row per crew member, AI
## included), shows "—" for counters a row lacks, marks the local player, follows the `scoreboard`
## action (hold, and toggle via controls/scoreboard_mode) and the HUD palette; the payday screen
## renders the awards section.
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")
const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")

var _hud: Hud
var _model: MockHudModel
var _settings: GameSettings


func before_each() -> void:
	_settings = GameSettings.new()
	_model = MockHudModel.new()
	add_child(_model)
	_hud = HUD_SCENE.instantiate() as Hud
	_hud.auto_find_model = false
	_hud.settings = _settings
	add_child(_hud)
	await wait_frames(1)
	_hud.bind(_model)


func after_each() -> void:
	Input.action_release(ScoreboardOverlay.ACTION)
	_hud.queue_free()
	_model.queue_free()
	await wait_frames(1)


func _board() -> ScoreboardOverlay:
	return _hud.scoreboard


func test_rows_from_mock_mark_local_and_dash_missing_counters() -> void:
	_model.crew_stats = MockHudDriver.stats_rows(2)
	_board().set_shown(true)
	var b: ScoreboardOverlay = _board()
	assert_eq(b.rows.size(), 4, "one row per crew member, Crew AI included")
	assert_eq(b.cells.size(), 4)
	assert_eq(b.local_slot, 0, "local row marked")
	var mine: Dictionary = b.cells[0]
	assert_eq((mine[ScoreboardOverlay.NAME] as Label).text, UiText.t(&"ui.scoreboard.you",
			{"name": UiText.t(&"ui.results.crew_slot", {"slot": 1})}))
	assert_eq((mine[CrewStats.KILLS] as Label).text, "6")
	assert_eq((mine[CrewStats.ACCURACY] as Label).text, UiText.t(&"ui.scoreboard.pct", {"value": 64}), "18/28 hits")
	assert_eq((mine[CrewStats.HEADSHOTS] as Label).text, "4")
	var dash: String = UiText.t(&"ui.scoreboard.missing")
	assert_eq(dash, "—")
	for slot: int in [1, 2, 3]:
		var row: Dictionary = b.cells[slot]
		assert_eq((row[CrewStats.ACCURACY] as Label).text, dash, "AI row %d has no shots/hits" % slot)
		assert_eq((row[CrewStats.HEADSHOTS] as Label).text, dash)
		assert_ne((row[CrewStats.KILLS] as Label).text, dash, "kills exist on every row")
		assert_true((row[ScoreboardOverlay.NAME] as Label).text.ends_with("[AI]"), "AI tag")
	assert_eq((b.cells[2][CrewStats.CIVILIANS] as Label).text, "1")


func test_missing_field_detected_per_row() -> void:
	_model.crew_stats = [
		{"slot": 1, "name": "Mate", "is_ai": false, "is_local": false, "kills": 2, "shots": 10, "hits": 5},
		{"slot": 0, "name": "Me", "is_ai": false, "is_local": true, "kills": 1, "downs": 0},
	]
	_board().set_shown(true)
	var b: ScoreboardOverlay = _board()
	assert_eq(CrewStats.slot_of(b.rows[0]), 0, "rows ordered by slot")
	var dash: String = UiText.t(&"ui.scoreboard.missing")
	assert_eq((b.cells[0][CrewStats.DOWNS] as Label).text, "0", "a zero is not missing")
	assert_eq((b.cells[1][CrewStats.DOWNS] as Label).text, dash)
	assert_eq((b.cells[0][CrewStats.ACCURACY] as Label).text, dash)
	assert_eq((b.cells[1][CrewStats.ACCURACY] as Label).text, UiText.t(&"ui.scoreboard.pct", {"value": 50}))
	assert_eq((b.cells[1][CrewStats.SPECIALS] as Label).text, dash)
	assert_eq(b.local_slot, 0)


func test_model_without_crew_stats_lists_crew_with_dashes() -> void:
	_model.crew = [{"slot": 1, "name": "Sable", "is_ai": true}, {"slot": 2, "name": "Dutch", "is_ai": true}]
	_model.crew_stats = []
	_board().set_shown(true)
	assert_eq(_board().rows.size(), 0, "an empty crew_stats is shown as is")
	_board().set_shown(false)
	var rows: Array[Dictionary] = _fallback_rows()
	assert_eq(rows.size(), 3, "local player + 2 teammates")
	assert_eq(ScoreboardOverlay.cell_text(rows[1], CrewStats.KILLS), UiText.t(&"ui.scoreboard.missing"))
	var locals: Array = rows.filter(func(r: Dictionary) -> bool: return ScoreboardOverlay.is_local_row(r))
	assert_eq(locals.size(), 1, "exactly one local row")


## build_rows() on a model that has `crew` but no `crew_stats` property.
func _fallback_rows() -> Array[Dictionary]:
	var legacy: LegacyModel = LegacyModel.new()
	legacy.crew = _model.crew
	add_child(legacy)
	var b: ScoreboardOverlay = ScoreboardOverlay.new()
	add_child(b)
	b.bind(legacy)
	var rows: Array[Dictionary] = b.build_rows()
	b.queue_free()
	legacy.queue_free()
	return rows


func test_hold_action_shows_while_held() -> void:
	var b: ScoreboardOverlay = _board()
	assert_false(b.visible, "hidden by default")
	assert_false(b.is_toggle_mode(), "hold by default")
	_model.crew_stats = MockHudDriver.stats_rows(1)
	Input.action_press(ScoreboardOverlay.ACTION)
	await wait_frames(2)
	assert_true(b.visible, "shown while the scoreboard action is held")
	assert_eq(b.cells.size(), 4, "refreshed when shown")
	Input.action_release(ScoreboardOverlay.ACTION)
	await wait_frames(2)
	assert_false(b.visible, "hidden on release")


func test_toggle_mode_flips_on_press() -> void:
	_settings.set_value(GameSettings.CONTROLS, &"scoreboard_mode", "toggle")
	var b: ScoreboardOverlay = _board()
	assert_true(b.is_toggle_mode())
	b.update_input(true)
	assert_true(b.visible)
	b.update_input(false)
	assert_true(b.visible, "release keeps it open in toggle mode")
	b.update_input(true)
	assert_false(b.visible, "second press closes it")
	b.update_input(false)
	assert_false(b.visible)


func test_follows_palette() -> void:
	_model.crew_stats = MockHudDriver.stats_rows(1)
	_settings.set_value(GameSettings.ACCESSIBILITY, &"palette", "high_contrast")
	_board().set_shown(true)
	var hc: HudTweak = HudPaletteSet.active_tweak(_settings)
	var name_mate: Label = _board().cells[1][ScoreboardOverlay.NAME]
	var name_me: Label = _board().cells[0][ScoreboardOverlay.NAME]
	assert_eq(name_mate.get_theme_color(&"font_color"), hc.ally_color, "teammates use the palette ally colour")
	assert_eq(name_me.get_theme_color(&"font_color"), hc.interaction_color, "local row uses the highlight colour")


func test_demo_driver_feeds_the_scoreboard() -> void:
	var driver: MockHudDriver = MockHudDriver.new()
	driver.model = _model
	driver.setup_initial()
	assert_eq(_model.crew_stats.size(), 4)
	driver._enter_stage(8)
	_board().set_shown(true)
	assert_eq((_board().cells[0][CrewStats.KILLS] as Label).text, "9")
	driver.free()


func test_payday_renders_awards_section() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	var screen: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	screen.apply_to_profile = false
	screen.setup(PlayerProfile.new_default())
	add_child(screen)
	await wait_frames(1)
	var result: Dictionary = HeistCatalog.sample_result()
	screen.show_result(result)
	# Sample: slot 0 human 2 kills / 1 civilian, slot 1 AI 1 kill / 1 down, slots 2-3 AI clean.
	assert_eq(screen.awards, HeistAwards.compute(result["crew"] as Array), "screen uses HeistAwards as-is")
	assert_has(screen.award_labels, &"most_kills")
	assert_has(screen.award_labels, &"iron")
	assert_false(screen.award_labels.has(&"civilian_friendly"), "the only human killed a civilian; AI never wins (D-071)")
	assert_false(screen.award_labels.has(&"most_accurate"), "no shots/hits in HeistResult yet: skipped")
	assert_false(screen.award_labels.has(&"most_headshots"))
	assert_eq((screen.award_labels[&"iron"] as Label).text, screen._crew_name(0, false), "0 downs: the human (AI never wins)")
	assert_eq((screen.award_labels[&"most_kills"] as Label).text, screen._crew_name(0, false))
	screen.free()
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_payday_without_awards_says_so() -> void:
	var screen: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	screen.apply_to_profile = false
	screen.setup(PlayerProfile.new_default())
	add_child(screen)
	await wait_frames(1)
	var result: Dictionary = HeistCatalog.sample_result()
	result["crew"] = [{"slot": 0, "is_ai": false}]
	screen.show_result(result)
	assert_eq(screen.awards.size(), 0)
	assert_eq(screen.award_labels.size(), 0)
	screen.free()


## A model with `crew` but no `crew_stats` (the shape of ENV A's LocalHudModel before the QB lands).
class LegacyModel:
	extends Node
	signal crew_changed()
	var crew: Array[Dictionary] = []


## r224 GN 1080p capture: 16 objectives ran the Tab sheet off the screen. Past HudTweak.scoreboard_objectives_max
## lines the done ones fold into one line, the live ones fill the rest and "+N more" closes; the sheet fits.
func test_long_objective_list_folds_and_the_sheet_fits() -> void:
	var obs: Array[Dictionary] = []
	for i: int in range(16):
		var st: int = Enums.ObjectiveState.COMPLETED if i < 3 else Enums.ObjectiveState.ACTIVE
		obs.append({"id": StringName("o%d" % i), "text_key": &"objective.test.drill_vault", "state": st, "args": {}})
	_model.objectives = obs
	var sb: ScoreboardOverlay = _board()
	sb.set_shown(true)
	sb.refresh()
	await wait_frames(3)
	var lines: Array[Node] = sb.objectives_box.get_children()
	var cap: int = sb.tweak.scoreboard_objectives_max
	assert_eq(lines.size(), cap, "capped at %d lines" % cap)
	assert_eq((lines[0] as Label).text, UiText.t(&"ui.scoreboard.objectives_done", {"count": 3}), "done ones folded")
	assert_eq((lines[lines.size() - 1] as Label).text, UiText.t(&"ui.scoreboard.objectives_more", {"count": 13 - (cap - 2)}))
	var view: Rect2 = sb.get_viewport_rect()
	assert_true(sb.sheet.get_global_rect().end.y <= view.end.y, "sheet ends on screen (%s)" % sb.sheet.get_global_rect())
	var few: Array[Dictionary] = []
	few.assign(obs.slice(0, 5))
	_model.objectives = few
	sb.set_shown(true)  # hold mode hides it again without the key
	sb.refresh()
	await wait_frames(2)
	assert_eq(sb.objectives_box.get_child_count(), 5, "a short list shows whole, done ones included")
