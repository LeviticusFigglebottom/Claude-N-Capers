## B4-20 achievements stub: data (data/achievements/*.tres), event conditions on the payday path,
## the cataclysm_clear unlock (oxblood_herald), persistence (save v5) and the achievements screen.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const SCREEN_SCENE: PackedScene = preload("res://content/ui/achievements/achievements_screen.tscn")
const SLOT: int = 0


func before_all() -> void:
	BTestUtil.pin_menu_hub(true)  # C's 3D safehouse at the contract path: these drive the 2D hub
	SaveService.root_dir = BTestUtil.profile_root()


func before_each() -> void:
	SaveService.delete_profile(SLOT)


func after_all() -> void:
	BTestUtil.pin_menu_hub(false)
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_data_is_complete() -> void:
	var defs: Array[AchievementDef] = Achievements.all()
	# B7-02 set of about 40, plus D-111's unlock achievements (Deep Water, Main Event, Private Viewing, The Planner,
	# Wheelman), plus the per-heist sets (D-115's 28, OF-B1's 6 for Ostrander Federal, LEAD r244's 6 parity additions,
	# RT-B1's 6, AH-B1's 6).
	assert_true(defs.size() >= 80 and defs.size() <= 105, "about 40 (B7-02) + D-111 + 40 per-heist: %d" % defs.size())
	var strings: Dictionary = StringTable.parse_csv()
	for a: AchievementDef in defs:
		assert_true(String(a.id).begins_with("achievement."), String(a.id))
		assert_has(Achievements.EVENTS, a.event(), "%s event" % a.id)
		assert_true(a.target() >= 1)
		assert_has(strings, String(a.name_key))
		assert_has(strings, String(a.desc_key))
	var cat: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, &"achievement.cataclysm_clear") as AchievementDef
	assert_eq(cat.unlock, &"unlock.achievement.cataclysm_clear")
	assert_eq(AchievementsScreen.reward_name(cat), MaskCatalog.display_name(&"mask.oxblood_herald"))


func test_first_heist_and_failures() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(Achievements.on_payday(p, _result(false, 0, false), {"success": false}), [&"achievement.hard_lessons"] as Array[StringName],
			"only the first-failure achievement")
	assert_false(Achievements.is_unlocked(p, &"achievement.first_score"), "a failure is not a completion")
	var got: Array[StringName] = Achievements.on_payday(p, _result(true, 0, false), {"success": true})
	assert_has(got, &"achievement.first_score")
	assert_eq(Achievements.progress(p, &"achievement.first_score"), 1)
	got = Achievements.on_payday(p, _result(true, 0, false), {"success": true})
	assert_false(got.has(&"achievement.first_score"), "never unlocks twice")
	assert_eq(Achievements.progress(p, &"achievement.first_score"), 1, "progress capped at the target")


func test_filters() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for i: int in range(2):
		Achievements.on_payday(p, _result(true, 0, true, &"night_deposit"), {"success": true})
	assert_eq(Achievements.progress(p, &"achievement.glasshouse_regular"), 0, "other heist")
	assert_eq(Achievements.progress(p, &"achievement.ghost_crew"), 2, "stealth runs count")
	assert_eq(Achievements.progress(p, &"achievement.make_some_noise"), 0, "stealth is not loud")
	Achievements.on_payday(p, _result(true, 1, false), {"success": true})
	assert_eq(Achievements.progress(p, &"achievement.make_some_noise"), 0, "Tense < Hazardous")
	assert_eq(Achievements.progress(p, &"achievement.ghost_crew"), 2, "loud run is not stealth")
	var got: Array[StringName] = Achievements.on_payday(p, _result(true, 2, false), {"success": true})
	assert_has(got, &"achievement.make_some_noise")
	for i: int in range(2):
		Achievements.on_payday(p, _result(true, 0, false), {"success": true})
	assert_eq(Achievements.progress(p, &"achievement.glasshouse_regular"), 3)
	assert_true(Achievements.is_unlocked(p, &"achievement.glasshouse_regular"))
	assert_false(Achievements.is_unlocked(p, &"achievement.pro_closer"))
	got = Achievements.on_payday(p, _result(true, 0, false), {"success": true}, true)
	assert_has(got, &"achievement.pro_closer")


func test_stash_and_level_events() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	Achievements.on_payday(p, _result(true, 0, false), {"success": true, "stash": 600000})
	assert_eq(Achievements.progress(p, &"achievement.offshore_million"), 600000)
	var got: Array[StringName] = Achievements.on_payday(p, _result(true, 0, false), {"success": true, "stash": 500000})
	assert_has(got, &"achievement.offshore_million")
	assert_eq(Achievements.progress(p, &"achievement.offshore_million"), 1000000)
	p.level = 24
	Achievements.record(p, Achievements.LEVEL_REACHED, {"level": p.level})
	assert_false(Achievements.is_unlocked(p, &"achievement.seasoned"))
	p.level = 30
	assert_has(Achievements.record(p, Achievements.LEVEL_REACHED, {"level": p.level}), &"achievement.seasoned")


func test_cataclysm_clear_grants_the_herald() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_false(MaskLocker.is_equippable(p, &"mask.oxblood_herald"))
	Achievements.on_payday(p, _result(true, Enums.Difficulty.LETHAL, false), {"success": true})
	assert_false(Achievements.is_unlocked(p, &"achievement.cataclysm_clear"), "Lethal is not Cataclysm")
	var got: Array[StringName] = Achievements.on_payday(p, _result(true, Enums.Difficulty.CATACLYSM, true), {"success": true})
	assert_has(got, &"achievement.cataclysm_clear")
	assert_has(p.unlocks, &"unlock.achievement.cataclysm_clear")
	assert_true(MaskLocker.is_equippable(p, &"mask.oxblood_herald"), "mask unlocked")
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_true(Achievements.is_unlocked(q, &"achievement.cataclysm_clear"), "unlocked state saved")
	assert_eq(Achievements.progress(q, &"achievement.first_score"), 1, "progress saved")
	assert_has(q.owned_masks, &"mask.oxblood_herald")


func test_payday_screen_records_achievements() -> void:
	var pd: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	pd.cards_enabled = false
	add_child(pd)
	await wait_frames(1)
	var r: Dictionary = HeistCatalog.sample_result()
	r["success"] = true
	pd.show_result(r)
	assert_has(pd.achievements_unlocked, &"achievement.first_score")
	assert_true(Achievements.is_unlocked(SaveService.load_profile(SLOT), &"achievement.first_score"), "saved by the payday")
	assert_has(pd.achievement_rows, &"achievement.first_score", "listed on the results (D-115 section)")
	assert_true(pd.achievements_panel.visible)
	pd.queue_free()
	await wait_frames(1)


func test_screen_instantiates_with_progress() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	Achievements.on_payday(p, _result(true, 0, true), {"success": true})
	var s: AchievementsScreen = SCREEN_SCENE.instantiate() as AchievementsScreen
	s.setup(p)
	add_child(s)
	await wait_frames(1)
	assert_eq(s.rows.size(), Achievements.shown().size())  # a staged (hidden) heist's set is not on the screen
	assert_eq(s.count_label.text, UiText.t(&"ui.achievements.count", {"unlocked": 1, "total": Achievements.shown().size()}))
	var first: PanelContainer = s.rows[&"achievement.first_score"] as PanelContainer
	assert_eq((first.find_child("Status", true, false) as Label).text, UiText.t(&"ui.achievements.unlocked"))
	assert_near((s.rows[&"achievement.ghost_crew"] as Control).find_child("Progress", true, false).get(&"value"), 0.2)
	assert_eq(s.focus_chain.size(), s.rows.size() + 1, "rows + Back are focusable")
	s.queue_free()
	await wait_frames(1)


## Lane 2 audit: two cards per line; the d-pad moves along a line and down a column, Back below the last.
func test_two_column_grid_pad_neighbours() -> void:
	var s: AchievementsScreen = SCREEN_SCENE.instantiate() as AchievementsScreen
	s.setup(PlayerProfile.new_default())
	add_child(s)
	await wait_frames(2)
	var g: Array[Control] = s.grids[0]
	assert_true(g.size() >= 3, "the first category has a second line")
	assert_eq(g[0].get_node(g[0].focus_neighbor_right), g[1])
	assert_eq(g[1].get_node(g[1].focus_neighbor_left), g[0])
	assert_eq(g[0].get_node(g[0].focus_neighbor_bottom), g[2], "down stays in the column")
	assert_eq(g[2].get_node(g[2].focus_neighbor_top), g[0])
	assert_eq(g[0].get_global_rect().position.y, g[1].get_global_rect().position.y, "one line")
	var last: Array[Control] = s.grids[s.grids.size() - 1]
	var tail: Control = last[last.size() - 1]
	assert_eq(tail.get_node(tail.focus_neighbor_bottom), s.back_button)
	s.queue_free()
	await wait_frames(1)


func test_hub_opens_achievements_and_back_returns() -> void:
	SaveService.save_profile(PlayerProfile.new_default(), SLOT)
	var f: MenuFlow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	add_child(f)
	await wait_frames(1)
	f.show_hub()
	await wait_frames(1)
	f.hub.achievements_button.pressed.emit()
	await wait_frames(1)
	assert_true(f.current is AchievementsScreen)
	(f.current as AchievementsScreen).back_button.pressed.emit()
	await wait_frames(1)
	assert_eq(f.current, f.hub as Control)
	f.queue_free()
	await wait_frames(1)


func _result(success: bool, difficulty: int, stealth: bool, heist: StringName = &"glasshouse") -> Dictionary:
	return {"heist_id": heist, "success": success, "difficulty": difficulty, "stealth": stealth}
