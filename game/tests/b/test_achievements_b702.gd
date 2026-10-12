## B7-02 achievements expansion: ~40 data-driven achievements, state conditions on the career (B7-01),
## Notoriety and "every heist", their unlock rewards (presets, parts, weapon finish unlock ids, ENV D batch-3
## bases behind unlock ids), strings, and the categorised screen with live career progress.
extends TestCase

const SCREEN_SCENE: PackedScene = preload("res://content/ui/achievements/achievements_screen.tscn")
## Weapon finish unlock ids B7-04 earns through achievements (AchievementDef.unlock, one achievement each).
const FINISH_IDS: Array[StringName] = [&"unlock.finish.arctic", &"unlock.finish.cherry_polymer",
	&"unlock.finish.carbon", &"unlock.finish.urban_camo", &"unlock.finish.midnight_chrome", &"unlock.finish.copper_patina"]
## ENV D batch-3 bases (D3-03), hidden until their glb lands.
const BATCH3: Array[StringName] = [&"mask_base.ram", &"mask_base.stag", &"mask_base.cat", &"mask_base.boar",
	&"mask_base.serpent", &"mask_base.moth", &"mask_base.knight", &"mask_base.doll", &"mask_base.sunburst",
	&"mask_base.geo", &"mask_base.robot", &"mask_base.jester"]
const NEW_PRESETS: Array[StringName] = [&"mask.silent_partner", &"mask.dock_boss", &"mask.grand_tourist", &"mask.thousand_yard"]


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_ids_strings_and_categories() -> void:
	var strings: Dictionary = StringTable.parse_csv()
	var seen: Dictionary = {}
	var orders: Dictionary = {}
	for a: AchievementDef in Achievements.all():
		assert_false(seen.has(a.id), "duplicate id %s" % a.id)
		seen[a.id] = true
		assert_false(orders.has(a.order), "%s shares order %d" % [a.id, a.order])
		orders[a.order] = true
		assert_has(strings, String(a.name_key))
		assert_has(strings, String(a.desc_key))
		assert_eq(a.name_key, StringName("%s.name" % a.id))
		assert_has(Achievements.CATEGORIES, a.category, "%s category" % a.id)
		assert_has(strings, "ui.achievements.category.%s" % a.category)
	assert_true(seen.size() >= 35, "about 40: %d" % seen.size())


func test_every_condition_evaluates() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for a: AchievementDef in Achievements.all():
		assert_has(Achievements.EVENTS, a.event(), "%s event" % a.id)
		assert_true(Achievements.target_of(a) >= 1, "%s target" % a.id)
		assert_eq(Achievements.current_value(p, a), 0, "%s starts at 0" % a.id)
		assert_eq(Achievements.display_progress(p, a), 0)
		var c: Dictionary = a.condition
		if c.has("heist"):
			assert_true(HeistCatalog.ids().has(StringName(c["heist"])), "%s names an offered heist" % a.id)
		if a.event() == Achievements.CAREER_STAT:
			var stat: String = String(c.get("stat", ""))
			var known: bool = Career.CREW_COUNTERS.has(stat) or stat in [Career.PLAYED, Career.WON, Career.FAILED,
				Career.STEALTH_WINS, Career.LOUD_WINS, Career.SPENDING_EARNED, Career.STASH_EARNED, Career.XP_EARNED,
				Career.SMALL_LOOT, Career.BAGS, Career.CASH_SPENT, Career.OFFSHORE_SPENT, Career.CUSTODY, Career.TIME_PLAYED_S]
			assert_true(known, "%s reads a Career counter (%s)" % [a.id, stat])
	assert_eq(Achievements.sync(p), [] as Array[StringName], "nothing unlocks on an empty profile")


func test_rewards_exist_and_are_granted() -> void:
	for a: AchievementDef in Achievements.all():
		for id: StringName in a.rewards:
			assert_true(MaskCatalog.has_part(id), "%s reward %s is an available part" % [a.id, id])
		for id: StringName in a.unlocks:
			assert_true(String(id).begins_with("unlock."), "%s: %s is an unlock id" % [a.id, id])
		if a.unlock == &"":
			continue
		var finish: bool = String(a.unlock).begins_with(AchievementsScreen.FINISH_PREFIX)
		assert_true(finish or String(a.unlock).begins_with(MaskCatalog.UNLOCK_ACHIEVEMENT_PREFIX), String(a.unlock))
		assert_true(not finish or FINISH_IDS.has(a.unlock), "%s: agreed finish id" % a.id)
		assert_ne(AchievementsScreen.reward_name(a), "", "%s unlock owns a preset, a (pending) part or a finish" % a.id)
		var p: PlayerProfile = PlayerProfile.new_default()
		p.achievements[a.id] = {"progress": Achievements.target_of(a) - 1, "unlocked": false}
		assert_true(Achievements._advance(p, a, Achievements.target_of(a)), "%s unlocks at its target" % a.id)
		for id: StringName in Achievements.reward_ids(a):
			if String(id).begins_with("unlock."):
				assert_has(p.unlocks, id, "%s records %s" % [a.id, id])
			else:
				assert_true(MaskLocker.is_part_owned(p, id), "%s grants %s" % [a.id, id])
		for md: MaskDef in MaskCatalog.presets():
			if md.unlock == a.unlock:
				assert_true(MaskLocker.is_equippable(p, md.id), "%s owns %s" % [a.id, md.id])
	var used: Array[StringName] = []
	for a: AchievementDef in Achievements.all():
		assert_false(used.has(a.unlock) and a.unlock != &"", "%s: unlock id used once" % a.id)
		used.append(a.unlock)
		used.append_array(a.unlocks)
	for f: StringName in FINISH_IDS:
		assert_eq(used.count(f), 1, "%s granted by exactly one achievement" % f)
	for f: StringName in [&"unlock.finish.case_hardened", &"unlock.finish.brass_engraved", &"unlock.finish.gilded_ledger"]:
		assert_false(used.has(f), "%s stays a Notoriety reward" % f)


func test_career_stat_achievements_progress_and_unlock() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for i: int in range(9):
		Career.record(p, _result(&"dockside_burn", true, false, 2, 30, 0), {"success": true}, 0)
	Achievements.sync(p)
	var ten: AchievementDef = _def(&"achievement.ten_alarms")
	assert_eq(Achievements.display_progress(p, ten), 9)
	assert_false(MaskLocker.is_part_owned(p, &"mask_colors.cobalt_flare"))
	Career.record(p, _result(&"dockside_burn", true, false, 2, 30, 0), {"success": true}, 0)
	var got: Array[StringName] = Achievements.on_payday(p, _result(&"dockside_burn", true, false, 2, 30, 0), {"success": true})
	assert_has(got, &"achievement.ten_alarms")
	assert_has(got, &"achievement.steady_work", "10 wins")
	assert_true(MaskLocker.is_part_owned(p, &"mask_colors.cobalt_flare"), "reward part granted")
	assert_has(p.unlocks, &"unlock.finish.cherry_polymer", "weapon finish unlock recorded")
	assert_eq(Achievements.display_progress(p, _def(&"achievement.hundred_down")), 100, "300 kills capped at 100")
	assert_true(Achievements.is_unlocked(p, &"achievement.hundred_down"))
	assert_eq(Achievements.progress(p, &"achievement.thousand_down"), 300)
	assert_false(Achievements.is_unlocked(p, &"achievement.clean_lines"), "no headshot data -> stays locked")
	assert_eq(Achievements.progress(p, &"achievement.clean_lines"), 0)


func test_headshots_unlock_when_data_exists() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var r: Dictionary = _result(&"glasshouse", true, false, 0, 0, 0)
	(r["crew"] as Array)[0]["headshots"] = 250
	Career.record(p, r, {"success": true}, 0)
	assert_has(Achievements.sync(p), &"achievement.clean_lines")
	var key: StringName = UiText.item_key(&"finish.urban_camo")
	var want: String = "Urban Camo" if UiText.t(key) == String(key) else UiText.t(key)
	assert_eq(AchievementsScreen.finish_name(&"unlock.finish.urban_camo"), want, "B7-04's name string, else the id")


func test_heist_specific_and_every_heist() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var got: Array[StringName] = Achievements.on_payday(p, _result(&"dockside_burn", true, false, 4, 0, 0), {"success": true})
	assert_has(got, &"achievement.harbour_master")
	assert_true(MaskLocker.is_equippable(p, &"mask.dock_boss"))
	got = Achievements.on_payday(p, _result(&"shadow_ledger", true, true, 0, 0, 0), {"success": true})
	assert_has(got, &"achievement.off_the_books")
	assert_true(MaskLocker.is_equippable(p, &"mask.silent_partner"))
	var tour: AchievementDef = _def(&"achievement.grand_tour")
	assert_eq(Achievements.target_of(tour), HeistCatalog.ids().size(), "every offered heist")
	for id: StringName in HeistCatalog.ids():
		assert_false(Achievements.is_unlocked(p, tour.id), "not before %s" % id)
		Career.record(p, _result(id, true, false, 1, 0, 0), {"success": true}, 0)
		Achievements.sync(p)
	assert_true(Achievements.is_unlocked(p, tour.id), "every heist won")
	assert_true(MaskLocker.is_equippable(p, &"mask.grand_tourist"))
	assert_false(Achievements.is_unlocked(p, &"achievement.lethal_itinerary"), "not on Lethal")
	assert_eq(Achievements.display_progress(p, _def(&"achievement.lethal_itinerary")), 0, "no Lethal win on the career")
	Career.record(p, _result(&"dockside_burn", true, false, 4, 0, 0), {"success": true}, 0)
	assert_eq(Achievements.display_progress(p, _def(&"achievement.lethal_itinerary")), 1, "Dockside on Lethal")


func test_notoriety_reached_runs_on_rank_up() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	p.level = 100
	p.xp = XpCurve.xp_for_level(100)
	p.cash = Notoriety.cost_for(1)
	var r: Dictionary = Notoriety.rank_up(p)
	assert_true(bool(r["ok"]))
	assert_has(r["achievements"] as Array, &"achievement.clean_slate")
	assert_true(MaskLocker.is_part_owned(p, &"mask_colors.signal_white"))
	assert_eq(Achievements.display_progress(p, _def(&"achievement.old_hand")), 1)
	assert_eq(Career.total(p, Career.CASH_SPENT), Notoriety.cost_for(1), "rank-up cost is spending")


func test_batch3_bases_wait_for_env_d() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for id: StringName in BATCH3:
		assert_true(MaskCatalog.is_known(id), "%s slot in the data" % id)
		var b: MaskBaseDef = MaskCatalog.part(id) as MaskBaseDef
		assert_true(b.requires_model, "%s hidden until its glb lands" % id)
		var short: String = String(id).trim_prefix("mask_base.")
		assert_eq(b.model_path, "res://assets/masks/mask_base_%s/mask_base_%s.glb" % [short, short])
		assert_eq(MaskCatalog.is_available(id), ResourceLoader.exists(b.model_path))
		assert_ne(UiText.t(UiText.item_key(id)), String(UiText.item_key(id)), "%s has a name" % id)
		if b.unlock != &"":
			assert_false(PaydayCards.pool(PaydayCards.MASK_PART, p).has(id), "%s is unlock-only" % id)
	# an earned unlock owns the base as soon as it is available (apply_unlocks on load)
	MaskLocker.grant_unlock(p, &"unlock.achievement.career_criminal")
	var knight: MaskPartDef = MaskCatalog.part(&"mask_base.knight")
	assert_eq(MaskLocker.is_part_owned(p, knight.id), MaskCatalog.is_available(knight.id))
	assert_has(p.unlocks, &"unlock.achievement.career_criminal", "recorded for when the model lands")
	assert_ne(AchievementsScreen.reward_name(_def(&"achievement.career_criminal")), "")


func test_parts_behind_unlocks_are_granted_when_available() -> void:
	# A shipped part stands in for a batch-3 base: grant_unlock / apply_unlocks own available unlock parts.
	var part: MaskPartDef = MaskCatalog.part(&"mask_colors.moss_bark")
	var before: StringName = part.unlock
	part.unlock = &"unlock.achievement.test_probe"
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_false(PaydayCards.pool(PaydayCards.MASK_PART, p).has(part.id), "unlock parts never drop")
	assert_has(MaskLocker.grant_unlock(p, &"unlock.achievement.test_probe"), part.id)
	var q: PlayerProfile = PlayerProfile.new_default()
	q.unlocks = [&"unlock.achievement.test_probe"] as Array[StringName]
	assert_has(MaskLocker.apply_unlocks(q), part.id, "load-time repair owns it")
	part.unlock = before


func test_new_presets_resolve() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for id: StringName in NEW_PRESETS:
		var md: MaskDef = MaskCatalog.resolve(id, p)
		assert_true(md != null and md.model != null, "%s resolves with its base mesh" % id)
		if md == null:
			continue
		assert_true(String(md.unlock).begins_with(MaskCatalog.UNLOCK_ACHIEVEMENT_PREFIX))
		assert_false(MaskLocker.is_equippable(p, id), "%s starts locked" % id)
		var comp: Dictionary = MaskComposer.composition_of(md)
		for k: String in MaskCatalog.KINDS:
			assert_true(MaskCatalog.has_part(StringName(String(comp[k]))), "%s: %s part resolves" % [id, k])
		assert_ne(MaskCatalog.display_name(id), String(UiText.item_key(id)), "%s has a name string" % id)


func test_screen_groups_and_shows_live_progress() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for i: int in range(37):
		Career.record(p, _result(&"glasshouse", true, false, 0, 0, 0), {"success": true}, 0)
	var s: AchievementsScreen = SCREEN_SCENE.instantiate() as AchievementsScreen
	s.setup(p)
	add_child(s)
	await wait_frames(1)
	assert_eq(s.rows.size(), Achievements.all().size())
	for c: StringName in Achievements.CATEGORIES:
		assert_true(s.category_labels.has(c), "header for %s" % c)
	var row: Control = s.rows[&"achievement.career_criminal"] as Control
	var want: String = UiText.t(&"ui.achievements.progress", {"progress": "37", "target": "100"})
	var found: bool = false
	for l: Node in row.find_children("*", "Label", true, false):
		found = found or (l as Label).text == want
	assert_true(found, "career progress 37 / 100 shown")
	assert_near(row.find_child("Progress", true, false).get(&"value"), 0.37, 0.001)
	assert_eq(s.focus_chain.size(), s.rows.size() + 1, "headers are not focusable")
	s.queue_free()
	await wait_frames(1)


func _def(id: StringName) -> AchievementDef:
	return ContentDB.by_id(ContentDB.ACHIEVEMENTS, id) as AchievementDef


func _result(heist: StringName, success: bool, stealth: bool, difficulty: int, kills: int, headshots: int) -> Dictionary:
	var row: Dictionary = {"slot": 0, "is_ai": false, "kills": kills if kills > 0 else 30, "specials_killed": 0, "downs": 0,
		"civilians_killed": 0, "in_custody": false}
	if headshots > 0:
		row["headshots"] = headshots
	return {"heist_id": heist, "success": success, "stealth": stealth, "difficulty": difficulty, "time_s": 300.0,
		"loot": [], "crew": [row]}
