## D-115: per-heist achievements (5-6 each for Golden Hour, Nightfall Depository, Shadow Ledger, Dockside Burn,
## Gallery Night; OF-B1: Ostrander Federal). Every one unlocks from a scripted HeistResult + in-heist fact log (HeistFacts) that satisfies
## it, and a near miss (one condition broken) does not; rewards are granted; strings, categories and condition
## keys are valid; fact conditions fail closed without a log; the PaydayScreen hands its log to on_payday.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const SLOT: int = 0
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn", &"gallery_night",
	&"ostrander_federal", &"rolling_thunder", &"afterhours"]
const DONE: int = Enums.ObjectiveState.COMPLETED
const ACTIVE: int = Enums.ObjectiveState.ACTIVE
const LANTERN: StringName = &"loot.painting_lantern_bearer"
const CANVASES: Array[StringName] = [&"loot.painting_lantern_bearer", &"loot.painting_salt_orchard",
	&"loot.painting_widow_in_blue", &"loot.painting_tidewater_saint"]


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func before_each() -> void:
	SaveService.delete_profile(SLOT)


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


# --- Data ---------------------------------------------------------------------------------------

func test_every_heist_has_its_set() -> void:
	var strings: Dictionary = StringTable.parse_csv()
	var known: Array[String] = HeistConditions.known_keys()
	var per: Dictionary = {}
	for a: AchievementDef in _heist_defs():
		var c: Dictionary = a.condition
		var heist: StringName = StringName(c.get("heist", &""))
		assert_eq(a.category, heist, "%s: category is its heist" % a.id)
		assert_true(HeistCatalog.ids().has(heist) or HeistCatalog.heist_list().heists.has(heist),
				"%s names a known heist (offered, or staged in heist_list)" % a.id)
		assert_eq(a.event(), Achievements.HEIST_COMPLETED, "%s is a clear" % a.id)
		assert_has(strings, String(a.name_key))
		assert_has(strings, String(a.desc_key))
		assert_has(strings, "ui.achievements.category.%s" % a.category)
		for k: Variant in c:
			assert_has(known, String(k), "%s: condition key %s is understood" % [a.id, k])
		for id: StringName in a.rewards:
			assert_true(MaskCatalog.has_part(id), "%s reward %s is an available part" % [a.id, id])
			assert_false(MaskCatalog.part(id).default_owned, "%s reward %s is not a default part" % [a.id, id])
		var row: Dictionary = per.get(heist, {"n": 0, "speed": false, "top": false}) as Dictionary
		row["n"] = int(row["n"]) + 1
		row["speed"] = bool(row["speed"]) or c.has("max_time_s")
		if int(c.get("difficulty_min", 0)) == Enums.Difficulty.CATACLYSM:
			row["top"] = true
			assert_false(c.has("stealth") or c.has("loud"), "%s: Cataclysm clears accept any mode (LEAD r244)" % a.id)
		per[heist] = row
	for h: StringName in HEISTS:
		assert_true(per.has(h), "%s has achievements" % h)
		var row: Dictionary = per.get(h, {"n": 0, "speed": false, "top": false}) as Dictionary
		# LEAD r244 parity: 6-8 per heist (dead air on every stealth heist, a loud route where both modes exist).
		assert_true(int(row["n"]) >= 6 and int(row["n"]) <= 8, "%s: 6-8 achievements (%d)" % [h, int(row["n"])])
		assert_true(bool(row["speed"]), "%s has a speed run" % h)
		assert_true(bool(row["top"]), "%s has a Cataclysm clear" % h)
	var parts: Array[StringName] = []
	for a: AchievementDef in _heist_defs():
		for id: StringName in a.rewards:
			assert_false(parts.has(id), "%s: reward %s used once" % [a.id, id])
			parts.append(id)


## LEAD r245 (OF real-run payday: Burn and Hoist named marker tags, so it never fired): every objective an achievement
## names is one of its heist's HeistDef.objectives.
func test_named_objectives_exist_in_the_heist() -> void:
	for a: AchievementDef in _heist_defs():
		var def: HeistDef = HeistRegistry.get_def(StringName(a.condition.get("heist", &"")))
		if def == null:
			continue
		for id: Variant in a.condition.get("objectives_completed", []) as Array:
			assert_has(def.objectives, StringName(id), "%s: objective %s is one of %s's" % [a.id, id, def.id])


func test_every_heist_achievement_has_a_case() -> void:
	var cases: Dictionary = _cases()
	for a: AchievementDef in _heist_defs():
		assert_true(cases.has(a.id), "%s has a scripted case" % a.id)
	assert_eq(cases.size(), _heist_defs().size(), "no case for a missing achievement")


# --- Unlock / near miss ---------------------------------------------------------------------------

func test_scripted_runs_unlock_and_near_misses_do_not() -> void:
	var cases: Dictionary = _cases()
	for id: StringName in cases:
		var a: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, id) as AchievementDef
		assert_true(a != null, "%s exists" % id)
		if a == null:
			continue
		var cs: Dictionary = cases[id]
		var p: PlayerProfile = PlayerProfile.new_default()
		var got: Array[StringName] = _pay(p, cs["pass"] as Array)
		assert_has(got, id, "%s unlocks from its run" % id)
		assert_true(Achievements.is_unlocked(p, id))
		for part: StringName in a.rewards:
			assert_true(MaskLocker.is_part_owned(p, part), "%s grants %s" % [id, part])
		for miss: Variant in cs["miss"] as Array:
			var q: PlayerProfile = PlayerProfile.new_default()
			assert_false(_pay(q, miss as Array).has(id), "%s: near miss %s must not unlock" % [id, (miss as Array)[2]])
			assert_false(Achievements.is_unlocked(q, id))
			for part: StringName in a.rewards:
				assert_false(MaskLocker.is_part_owned(q, part), "%s: no reward on a near miss" % id)


func test_a_failed_heist_never_counts() -> void:
	var cases: Dictionary = _cases()
	for id: StringName in cases:
		var run: Array = (cases[id] as Dictionary)["pass"] as Array
		var r: Dictionary = (run[0] as Dictionary).duplicate(true)
		r["success"] = false
		var p: PlayerProfile = PlayerProfile.new_default()
		assert_false(Achievements.on_payday(p, r, {"success": false}, false, run[1] as Dictionary).has(id), "%s failed run" % id)


func test_fact_conditions_fail_closed_without_a_log() -> void:
	var cases: Dictionary = _cases()
	var n: int = 0
	for id: StringName in cases:
		var a: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, id) as AchievementDef
		if a == null or not HeistConditions.needs_facts(a.condition):
			continue
		n += 1
		var run: Array = (cases[id] as Dictionary)["pass"] as Array
		var p: PlayerProfile = PlayerProfile.new_default()
		assert_false(Achievements.on_payday(p, run[0] as Dictionary, {"success": true}).has(id), "%s needs the fact log" % id)
		var stale: Dictionary = (run[1] as Dictionary).duplicate(true)
		stale.erase("recorded")
		assert_false(Achievements.on_payday(p, run[0] as Dictionary, {"success": true}, false, stale).has(id),
				"%s: a snapshot that is not a recorded log" % id)
	assert_true(n >= 8, "fact-log achievements exist (%d)" % n)


func test_result_conditions_fail_closed_on_missing_fields() -> void:
	var c: Dictionary = {"max_kills": 0, "max_time_s": 600.0}
	assert_false(HeistConditions.passes(c, {"time_s": 10.0}, {}), "no crew rows: kills unproven")
	assert_false(HeistConditions.passes(c, {"crew": [_row(0, 0, 0)]}, {}), "no time_s")
	assert_true(HeistConditions.passes(c, {"time_s": 10.0, "crew": [_row(0, 0, 0)]}, {}))
	assert_false(HeistConditions.passes({"max_pagers": 0}, {}, {}), "no pagers_answered")
	assert_false(HeistConditions.passes({"max_time_variant": "last_call_s"}, {"time_s": 1.0, "variants": {}}, {}),
			"variant missing")
	assert_false(HeistConditions.passes({"min_bags": 0}, {}, {}), "no loot list")
	assert_true(HeistConditions.passes({}, {}, {}), "no run conditions: always passes")


func test_tool_and_body_bags_never_count_as_loot() -> void:
	assert_false(HeistConditions.counts_as_loot(&"loot.thermite"), "tool bag (D-068)")
	assert_false(HeistConditions.counts_as_loot(&"loot.body_bag"), "body bag")
	assert_true(HeistConditions.counts_as_loot(&"loot.jewelry"))
	var r: Dictionary = {"loot": [_bag(&"loot.thermite"), _bag(&"loot.body_bag"), _bag(&"loot.jewelry")]}
	assert_eq(HeistConditions.secured_counts(r), {&"loot.jewelry": 1})
	# loot_available (A, events.md v1.7) excludes tool and body bags too, so they never pad the count
	assert_true(HeistConditions.passes({"all_loot_secured": true}, r.merged({"loot_available": 1}), {}))
	assert_false(HeistConditions.passes({"all_loot_secured": true}, r.merged({"loot_available": 2}), {}),
			"a thermite or body bag does not stand in for a valued bag")


func test_fact_matching() -> void:
	var f: HeistFacts = HeistFacts.new()
	f.record(&"device_started", [7, &"drill", 120.0])
	f.record(&"objective_updated", [&"code", ACTIVE, {}])
	f.record(&"objective_updated", [&"code", DONE, {"skipped": true}])
	var s: Dictionary = f.snapshot()
	assert_true(HeistConditions.passes({"facts_seen": [{"signal": &"device_started", "args": {1: "drill"}}]}, {}, s),
			"String matches StringName")
	assert_false(HeistConditions.passes({"facts_seen": [{"signal": &"device_started", "args": {1: &"saw"}}]}, {}, s))
	assert_true(HeistConditions.passes({"facts_seen": [{"signal": &"device_started", "args": {}}]}, {}, s), "any args")
	assert_false(HeistConditions.passes({"facts_seen": [{"signal": &"device_started", "args": {5: &"drill"}}]}, {}, s),
			"index past the args")
	assert_false(HeistConditions.passes({"objectives_completed": [&"code"]}, {}, s), "skipped is not done")
	assert_true(HeistConditions.passes({"objectives_not_completed": [&"code"]}, {}, s))
	assert_eq(int((s["objectives"] as Dictionary)[&"code"]["state"]), DONE, "last state kept")


# --- Live log -----------------------------------------------------------------------------------

func test_fact_log_listens_to_the_event_bus() -> void:
	var f: HeistFacts = HeistFacts.new()
	f.start()
	f.start()  # idempotent
	EventBus.objective_updated.emit(&"server", DONE, {"text_key": &"x"})
	EventBus.device_started.emit(3, &"saw", 90.0)
	EventBus.item_picked_up.emit(&"item.code_note", 0)
	EventBus.npc_alert_state_changed.emit(1, 0, 1)  # not a kept fact
	assert_true(f.running and f.started)
	assert_eq(f.events.size(), 2, "device + item (objective folded, alert state not kept)")
	assert_eq(int((f.objectives[&"server"] as Dictionary)["state"]), DONE)
	EventBus.heist_ended.emit({"heist_id": &"night_deposit", "success": false})
	assert_false(f.running, "stops on heist_ended")
	EventBus.device_started.emit(4, &"drill", 120.0)
	assert_eq(f.events.size(), 2, "nothing after the heist")
	assert_true(bool(f.snapshot()["recorded"]))
	f.stop()


func test_payday_screen_hands_its_log_to_on_payday() -> void:
	var pd: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	pd.cards_enabled = false
	pd.start_fact_log()
	add_child(pd)
	await wait_frames(1)
	EventBus.objective_updated.emit(&"server", DONE, {})
	EventBus.objective_updated.emit(&"time_lock_wait", DONE, {"method": &"server"})
	var r: Dictionary = _res(&"night_deposit", true)
	pd.show_result(r)
	assert_has(pd.achievements_unlocked, &"achievement.nd_clockwork", "the live log reached the payday")
	assert_true(MaskLocker.is_part_owned(SaveService.load_profile(SLOT), &"mask_pattern.circuit"), "reward saved")
	pd.queue_free()
	await wait_frames(1)
	var cold: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	cold.cards_enabled = false
	add_child(cold)
	await wait_frames(1)
	SaveService.delete_profile(SLOT)
	cold.profile = null
	cold.show_result(r)
	assert_false(cold.achievements_unlocked.has(&"achievement.nd_clockwork"), "no log on a menu payday: locked")
	cold.queue_free()
	await wait_frames(1)


# --- Cases ----------------------------------------------------------------------------------------

## id -> {"pass": run, "miss": [run, ...]}; run = [result, facts snapshot, label].
func _cases() -> Dictionary:
	var out: Dictionary = {}
	var gh: StringName = &"glasshouse"
	var nd: StringName = &"night_deposit"
	var sl: StringName = &"shadow_ledger"
	var db: StringName = &"dockside_burn"
	var gn: StringName = &"gallery_night"
	# --- Golden Hour
	out[&"achievement.gh_velvet_gloves"] = _quiet_case(gh)
	out[&"achievement.gh_before_closing"] = _speed_case(gh, 330.0, 400.0)
	var jew: Array = _bags(&"loot.jewelry", 4)
	out[&"achievement.gh_whole_consignment"] = {
		"pass": _run(_res(gh, true, {"loot": jew, "loot_available": 4}), _facts([], {&"safe_loot": DONE}), "consignment"),
		"miss": [
			_run(_res(gh, true, {"loot": jew, "loot_available": 6}), _facts([], {&"safe_loot": DONE}), "delivery bags left"),
			_run(_res(gh, true, {"loot": _bags(&"loot.jewelry", 3), "loot_available": 3}), _facts([], {&"safe_loot": DONE}),
					"3 bags"),
			_run(_res(gh, true, {"loot": jew, "loot_available": 4}), _facts([], {&"safe_loot": ACTIVE}), "safe not emptied"),
		],
	}
	out[&"achievement.gh_managers_combination"] = {
		"pass": _run(_res(gh, true), _facts([], {&"safe": [DONE, false, &"code"]}), "code"),
		"miss": [
			_run(_res(gh, true), _facts([], {&"safe": [DONE, false, &"drill"]}), "drill"),
			_run(_res(gh, true), _facts([], {&"safe": [DONE, false, &"keycard"]}), "keycard"),
			_run(_res(gh, true), _facts([], {&"safe": [DONE, false, &"lockpick"]}), "lockpick"),
			_run(_res(gh, true), _facts([], {&"safe": [DONE, true, &"code"]}), "safe skipped"),
			_run(_res(gh, true), _facts([], {&"safe": DONE}), "no open_method"),
		],
	}
	out[&"achievement.gh_window_shopping"] = {
		"pass": _run(_res(gh, true), _facts([[&"small_loot_taken", [500, 0]]], {}), "no glass"),
		"miss": [
			_run(_res(gh, true), _facts([[&"glass_broken", [4, Vector3.ZERO]]], {}), "glass"),
			_run(_res(gh, false), _facts([], {}), "loud"),
		],
	}
	out[&"achievement.gh_cataclysm"] = _top_case(gh, false)  # any mode (LEAD r244)
	out[&"achievement.gh_nobody_called"] = _dead_air_case(gh)
	out[&"achievement.gh_smash_and_grab"] = {
		"pass": _run(_res(gh, false), _facts([], {&"safe": [DONE, false, &"drill"], &"safe_loot": DONE}), "drilled"),
		"miss": [
			_run(_res(gh, true), _facts([], {&"safe": DONE, &"safe_loot": DONE}), "stealth"),
			_run(_res(gh, false), _facts([], {&"safe": DONE, &"safe_loot": ACTIVE}), "safe not emptied"),
		],
	}
	out[&"achievement.nd_off_the_hook"] = _dead_air_case(&"night_deposit")
	out[&"achievement.nd_hard_withdrawal"] = {
		"pass": _run(_res(&"night_deposit", false), _facts([], {&"vault_drill": DONE}), "drilled"),
		"miss": [
			_run(_res(&"night_deposit", false), _facts([], {&"vault_drill": ACTIVE}), "not drilled"),
			_run(_res(&"night_deposit", true), _facts([], {&"vault_drill": DONE}), "stealth"),
		],
	}
	out[&"achievement.gn_do_not_disturb"] = _dead_air_case(&"gallery_night")
	var custody: Dictionary = _row(10, 0, 1)
	custody["in_custody"] = true
	out[&"achievement.db_all_hands"] = {
		"pass": _run(_res(&"dockside_burn", false, {"difficulty": Enums.Difficulty.BRUTAL}), {}, "brutal, all out"),
		"miss": [
			_run(_res(&"dockside_burn", false, {"difficulty": Enums.Difficulty.BRUTAL, "crew": [_row(5, 0, 0), custody]}), {},
					"one in custody"),
			_run(_res(&"dockside_burn", false, {"difficulty": Enums.Difficulty.HAZARDOUS}), {}, "hazardous"),
		],
	}
	# --- Nightfall Depository
	out[&"achievement.nd_quiet_deposit"] = _quiet_case(nd)
	out[&"achievement.nd_bankers_hours"] = _speed_case(nd, 700.0, 760.0)
	var nd_objs: Dictionary = {&"vault_loot": DONE, &"depository": DONE}
	out[&"achievement.nd_cleaned_out"] = {
		"pass": _run(_res(nd, true, {"loot": _bags(&"loot.cash", 9), "loot_available": 9}), _facts([], nd_objs), "all"),
		"miss": [
			_run(_res(nd, true, {"loot": _bags(&"loot.cash", 9), "loot_available": 9}),
					_facts([], {&"vault_loot": DONE, &"depository": ACTIVE}), "depository shut"),
			_run(_res(nd, true, {"loot": _bags(&"loot.cash", 8), "loot_available": 8}), _facts([], nd_objs), "8 bags"),
			_run(_res(nd, true, {"loot": _bags(&"loot.cash", 9), "loot_available": 11}), _facts([], nd_objs), "courier bags left"),
		],
	}
	out[&"achievement.nd_clockwork"] = {
		"pass": _run(_res(nd, true), _facts([], {&"server": DONE, &"time_lock_wait": DONE, &"code": [DONE, true]}), "hack"),
		"miss": [
			_run(_res(nd, true), _facts([], {&"server": ACTIVE, &"time_lock_wait": DONE, &"code": DONE}), "code"),
			_run(_res(nd, false), _facts([], {&"server": DONE, &"time_lock_wait": Enums.ObjectiveState.FAILED}), "relocked"),
		],
	}
	out[&"achievement.nd_cataclysm"] = _top_case(nd, false)
	# --- Shadow Ledger
	out[&"achievement.sl_silent_audit"] = _quiet_case(sl)
	out[&"achievement.sl_express_elevator"] = _speed_case(sl, 590.0, 610.0)
	var sl_loot: Array = _bags(&"loot.ledger_laptop", 1) + _bags(&"loot.ledger_books", 1) + _bags(&"loot.cash", 1) \
			+ _bags(&"loot.ledger_drives", 3) + _bags(&"loot.painting", 2)
	var sl_objs: Dictionary = {&"study_safe": DONE, &"paintings": DONE, &"archive_safe": DONE}
	out[&"achievement.sl_every_page"] = {
		"pass": _run(_res(sl, true, {"loot": sl_loot, "loot_available": 8}), _facts([], sl_objs), "all"),
		"miss": [
			_run(_res(sl, true, {"loot": sl_loot.slice(0, 5) + _bags(&"loot.painting", 2), "loot_available": 7}),
					_facts([], sl_objs), "2 drives"),
			_run(_res(sl, true, {"loot": sl_loot, "loot_available": 8}), _facts([], {&"study_safe": DONE, &"paintings": DONE}),
					"archive safe shut"),
			_run(_res(sl, true, {"loot": sl_loot, "loot_available": 9}), _facts([], sl_objs), "printout left"),
		],
	}
	out[&"achievement.sl_measure_twice"] = {
		"pass": _run(_res(sl, true), _facts([], {&"cage": [DONE, false, &"code"]}), "code"),
		"miss": [
			_run(_res(sl, true), _facts([], {&"cage": [DONE, false, &"saw"]}), "saw"),
			_run(_res(sl, true), _facts([], {&"cage": [DONE, false, &"left_open"]}), "left open"),
			_run(_res(sl, true), _facts([], {&"cage": DONE}), "no open_method"),
		],
	}
	out[&"achievement.sl_dead_air"] = {
		"pass": _run(_res(sl, true, {"pagers_answered": 0}), {}, "no pagers"),
		"miss": [_run(_res(sl, true, {"pagers_answered": 1}), {}, "one pager")],
	}
	out[&"achievement.sl_cataclysm"] = _top_case(sl, true)
	# --- Dockside Burn (loud-only)
	out[&"achievement.db_not_a_scratch"] = {
		"pass": _run(_res(db, false, {"crew": [_row(40, 0, 0), _row(25, 0, 0)]}), {}, "unhurt"),
		"miss": [
			_run(_res(db, false, {"crew": [_row(40, 0, 0), _row(25, 0, 1)]}), {}, "a down"),
			_run(_res(db, false, {"crew": [_row(40, 1, 0)]}), {}, "a civilian"),
		],
	}
	out[&"achievement.db_before_sunrise"] = _speed_case(db, 830.0, 860.0, false)
	var pier: Array = _bags(&"loot.cash_bricks", 4) + _bags(&"loot.weapon_crate", 4) + _bags(&"loot.contraband", 4)
	out[&"achievement.db_strip_the_pier"] = {
		"pass": _run(_res(db, false, {"loot": pier + [_bag(&"loot.thermite")], "loot_available": 12}), {}, "all"),
		"miss": [
			_run(_res(db, false, {"loot": pier.slice(0, 11) + _bags(&"loot.cash_bricks", 1), "loot_available": 12}), {},
					"3 product"),
			_run(_res(db, false, {"loot": pier, "loot_available": 13}), {}, "burned bag"),
			_run(_res(db, false, {"loot": pier}), {}, "no loot_available"),
		],
	}
	out[&"achievement.db_buyers_discount"] = {
		"pass": _run(_res(db, false, {"loot": _bags(&"loot.contraband", 4)}), _facts([], {&"burn": DONE}), "product"),
		"miss": [
			_run(_res(db, false, {"loot": _bags(&"loot.contraband", 3) + _bags(&"loot.cash_bricks", 4)}),
					_facts([], {&"burn": DONE}), "3 product"),
			_run(_res(db, false, {"loot": _bags(&"loot.contraband", 4)}), _facts([], {&"burn": ACTIVE}), "no burn"),
		],
	}
	out[&"achievement.db_cataclysm"] = _top_case(db, false)
	# --- Gallery Night
	out[&"achievement.gn_gala_manners"] = _quiet_case(gn)
	out[&"achievement.gn_quick_viewing"] = _speed_case(gn, 500.0, 560.0)
	var art: Array = []
	for id: StringName in CANVASES:
		art.append(_bag(id))
	out[&"achievement.gn_full_collection"] = {
		"pass": _run(_res(gn, true, {"loot": art + [_bag(&"loot.painting_study")], "loot_available": 5}), {}, "all"),
		"miss": [
			_run(_res(gn, true, {"loot": art, "loot_available": 4}), {}, "no study"),
			_run(_res(gn, true, {"loot": art.slice(1) + _bags(&"loot.painting_study", 2), "loot_available": 5}), {},
					"no Lantern Bearer"),
			_run(_res(gn, true, {"loot": art + [_bag(&"loot.painting_study")], "loot_available": 18}), {}, "studies left"),
		],
	}
	out[&"achievement.gn_pulled_the_plug"] = {
		"pass": _run(_res(gn, false), _facts([], {&"hack": DONE, &"lockdown": DONE, &"vault_drill": ACTIVE}), "hack"),
		"miss": [
			_run(_res(gn, false), _facts([], {&"hack": DONE, &"vault_drill": DONE}), "drilled"),
			_run(_res(gn, true), _facts([], {&"hack": DONE}), "stealth"),
		],
	}
	out[&"achievement.gn_last_call"] = {
		"pass": _run(_res(gn, true, {"time_s": 470.0, "variants": {"last_call_s": 480}}), {}, "before"),
		"miss": [
			_run(_res(gn, true, {"time_s": 500.0, "variants": {"last_call_s": 480}}), {}, "after"),
			_run(_res(gn, false, {"time_s": 300.0, "variants": {"last_call_s": 720}}), {}, "loud"),
		],
	}
	out[&"achievement.gn_cataclysm"] = _top_case(gn, false)
	# --- Ostrander Federal (OF-B1; hidden until OF-A6)
	var of: StringName = &"ostrander_federal"
	out[&"achievement.of_quiet_weekend"] = {
		"pass": _run(_res(of, true, {"pagers_answered": 0}), {}, "no pagers"),
		"miss": [_run(_res(of, true, {"pagers_answered": 1}), {}, "one pager"),
			_run(_res(of, false, {"pagers_answered": 0}), {}, "loud")],
	}
	out[&"achievement.of_no_harm_done"] = _quiet_case(of)
	out[&"achievement.of_bank_holiday"] = _speed_case(of, 1150.0, 1260.0)
	var vault: Array = _bags(&"loot.cash_bricks", 6) + _bags(&"loot.gold", 2) + _bags(&"loot.server_drives", 2)
	out[&"achievement.of_clearing_house"] = {
		"pass": _run(_res(of, true, {"loot": vault, "loot_available": 10}), {}, "every bag"),
		"miss": [
			_run(_res(of, true, {"loot": vault, "loot_available": 12}), {}, "bags left"),
			_run(_res(of, true, {"loot": _bags(&"loot.cash_bricks", 8) + _bags(&"loot.server_drives", 2),
					"loot_available": 10}), {}, "no gold"),
		],
	}
	# LEAD r245 real-run check: the loud line's burn-through objective is vault_breach (lid / hoist are marker tags,
	# not objectives); every loud bag comes up the hoist (no bypass), so the burn is the condition.
	out[&"achievement.of_burn_and_hoist"] = {
		"pass": _run(_res(of, false), _facts([], {&"vault_drill": DONE, &"vault_breach": DONE}), "burned and hoisted"),
		"miss": [
			_run(_res(of, false), _facts([], {&"vault_drill": DONE, &"vault_breach": ACTIVE}), "not burned through"),
			_run(_res(of, true), _facts([], {&"vault_breach": DONE}), "stealth"),
		],
	}
	out[&"achievement.of_cataclysm"] = _top_case(of, false)  # any mode (LEAD r244)
	# --- Rolling Thunder (RT-B1, D-151; staged in heist_list until A's G1 plays end to end). The job always ends loud.
	var rt: StringName = &"rolling_thunder"
	out[&"achievement.rt_clean_stop"] = {
		"pass": _run(_res(rt, false), _facts([], {&"signals": DONE}), "signals rigged"),
		"miss": [
			_run(_res(rt, false), _facts([], {&"signals": ACTIVE}), "crash stop"),
			_run(_res(rt, false), _facts([], {&"signals": [DONE, true]}), "signals skipped"),
		],
	}
	out[&"achievement.rt_heavy_haul"] = {
		"pass": _run(_res(rt, false, {"loot": _bags(&"loot.gold", 4) + _bags(&"loot.cash_bricks", 2)}), {}, "4 gold"),
		"miss": [_run(_res(rt, false, {"loot": _bags(&"loot.gold", 3) + _bags(&"loot.cash_bricks", 4)}), {}, "3 gold")],
	}
	var haul: Array = _bags(&"loot.cash_bricks", 6) + _bags(&"loot.gold", 4)
	out[&"achievement.rt_full_convoy"] = {
		"pass": _run(_res(rt, false, {"loot": haul, "loot_available": 10}), {}, "every bag"),
		"miss": [_run(_res(rt, false, {"loot": haul, "loot_available": 12}), {}, "bags left on the road")],
	}
	out[&"achievement.rt_iron_crew"] = {
		"pass": _run(_res(rt, false, {"difficulty": Enums.Difficulty.HAZARDOUS, "crew": [_row(9, 0, 0)]}), {}, "no downs"),
		"miss": [
			_run(_res(rt, false, {"difficulty": Enums.Difficulty.HAZARDOUS, "crew": [_row(9, 0, 1)]}), {}, "a down"),
			_run(_res(rt, false, {"difficulty": Enums.Difficulty.TENSE, "crew": [_row(9, 0, 0)]}), {}, "Tense"),
		],
	}
	out[&"achievement.rt_quick"] = _speed_case(rt, 840.0, 960.0, false)
	out[&"achievement.rt_cataclysm"] = _top_case(rt, false)
	# --- Afterhours (AH-B1, LEAD r299 pick + the r244 dead-air parity row; staged in heist_list until the un-hide)
	var ah: StringName = &"afterhours"
	out[&"achievement.ah_no_witnesses"] = _quiet_case(ah)
	out[&"achievement.ah_dead_air"] = _dead_air_case(ah)
	out[&"achievement.ah_just_looking"] = {
		"pass": _run(_res(ah, true), _facts([], {&"casing": DONE, &"safe_code": DONE}), "cased, opened by code"),
		"miss": [
			_run(_res(ah, true), _facts([], {&"casing": DONE, &"safe_code": [DONE, true]}), "drilled (code skipped)"),
			_run(_res(ah, true), _facts([], {&"casing": ACTIVE, &"safe_code": DONE}), "never cased"),
			_run(_res(ah, false), _facts([], {&"casing": DONE, &"safe_code": DONE}), "loud"),
		],
	}
	out[&"achievement.ah_bottle_service"] = {
		"pass": _run(_res(ah, true, {"loot": _bags(&"loot.parcels", 3) + _bags(&"loot.cash_bricks", 3)}),
				_facts([], {&"count_room": DONE}), "product and the count"),
		"miss": [
			_run(_res(ah, true, {"loot": _bags(&"loot.parcels", 2) + _bags(&"loot.cash_bricks", 3)}),
					_facts([], {&"count_room": DONE}), "2 parcels"),
			_run(_res(ah, true, {"loot": _bags(&"loot.parcels", 3) + _bags(&"loot.cash_bricks", 3)}),
					_facts([], {&"count_room": ACTIVE}), "count room left"),
		],
	}
	out[&"achievement.ah_closing_time"] = _speed_case(ah, 700.0, 780.0, false)
	out[&"achievement.ah_cataclysm"] = _top_case(ah, false)  # any mode (LEAD r244)
	return out


func _quiet_case(heist: StringName) -> Dictionary:
	return {
		"pass": _run(_res(heist, true, {"crew": [_row(0, 0, 1), _row(0, 0, 0)]}), {}, "no kills"),
		"miss": [
			_run(_res(heist, true, {"crew": [_row(0, 0, 0), _row(1, 0, 0)]}), {}, "a guard killed"),
			_run(_res(heist, true, {"crew": [_row(0, 1, 0)]}), {}, "a civilian killed"),
			_run(_res(heist, false, {"crew": [_row(0, 0, 0)]}), {}, "loud"),
		],
	}


func _speed_case(heist: StringName, fast: float, slow: float, stealth: bool = true) -> Dictionary:
	return {
		"pass": _run(_res(heist, stealth, {"time_s": fast}), {}, "fast"),
		"miss": [_run(_res(heist, stealth, {"time_s": slow}), {}, "slow")],
	}


## Dead air (LEAD r244 parity): a stealth clear with no pager answered.
func _dead_air_case(heist: StringName) -> Dictionary:
	return {
		"pass": _run(_res(heist, true, {"pagers_answered": 0}), {}, "no pagers"),
		"miss": [_run(_res(heist, true, {"pagers_answered": 1}), {}, "one pager"),
			_run(_res(heist, false, {"pagers_answered": 0}), {}, "loud")],
	}


func _top_case(heist: StringName, stealth: bool) -> Dictionary:
	return {
		"pass": _run(_res(heist, stealth, {"difficulty": Enums.Difficulty.CATACLYSM}), {}, "cataclysm"),
		"miss": [_run(_res(heist, stealth, {"difficulty": Enums.Difficulty.LETHAL}), {}, "lethal")],
	}


# --- Helpers --------------------------------------------------------------------------------------

func _heist_defs() -> Array[AchievementDef]:
	var out: Array[AchievementDef] = []
	for a: AchievementDef in Achievements.all():
		if HEISTS.has(a.category):
			out.append(a)
	return out


func _pay(p: PlayerProfile, run: Array) -> Array[StringName]:
	return Achievements.on_payday(p, run[0] as Dictionary, {"success": bool((run[0] as Dictionary)["success"])}, false,
			run[1] as Dictionary)


func _run(result: Dictionary, facts: Dictionary, label: String) -> Array:
	return [result, facts, label]


## A plain clear: slow (no speed run), crew with kills and a down, 1 pager, no loot, Routine.
func _res(heist: StringName, stealth: bool, over: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {
		"heist_id": heist, "success": true, "stealth": stealth, "time_s": 2400.0, "difficulty": Enums.Difficulty.ROUTINE,
		"contract_pay": 0, "loot": [], "small_loot": 0, "crew": [_row(3, 0, 1)], "pagers_answered": 1, "seed": 7,
		"variants": {}, "fail_reason": &"",
	}
	r.merge(over, true)
	return r


func _row(kills: int, civilians: int, downs: int) -> Dictionary:
	return {"slot": 0, "is_ai": false, "name": "", "kills": kills, "specials_killed": 0, "downs": downs,
		"civilians_killed": civilians, "shots": 0, "hits": 0, "headshots": 0, "in_custody": false, "escaped": true}


func _bag(id: StringName) -> Dictionary:
	return {"loot_id": id, "value": 1000}


func _bags(id: StringName, n: int) -> Array:
	var out: Array = []
	for i: int in range(n):
		out.append(_bag(id))
	return out


## A recorded log: events [[signal, args], ...]; objectives id -> state, or [state, skipped[, open_method]].
func _facts(events: Array, objectives: Dictionary) -> Dictionary:
	var f: HeistFacts = HeistFacts.new()
	for id: StringName in objectives:
		var v: Variant = objectives[id]
		var st: int = int((v as Array)[0]) if v is Array else int(v)
		var skipped: bool = bool((v as Array)[1]) if v is Array else false
		var data: Dictionary = {"skipped": skipped} if skipped else {}
		if v is Array and (v as Array).size() > 2:
			data["open_method"] = (v as Array)[2]
		f.record(&"objective_updated", [id, st, data])
	for e: Variant in events:
		f.record(StringName((e as Array)[0]), (e as Array)[1] as Array)
	return f.snapshot()


## events.md v1.7 fact 1: HeistResult.loot_available. "All bags" = counted secured bags reach it; no field, a
## zero, or one bag short never unlocks; no fact log is needed.
func test_loot_available_fact() -> void:
	var c: Dictionary = {"all_loot_secured": true}
	var four: Array = _bags(&"loot.cash", 4)
	assert_true(HeistConditions.passes(c, {"loot": four, "loot_available": 4}, {}), "4 of 4")
	assert_true(HeistConditions.passes(c, {"loot": four, "loot_available": 3}, {}), "more than offered (thrown-in extra)")
	assert_false(HeistConditions.passes(c, {"loot": four, "loot_available": 5}, {}), "one left behind")
	assert_false(HeistConditions.passes(c, {"loot": four}, {}), "no loot_available: fails closed")
	assert_false(HeistConditions.passes(c, {"loot": [], "loot_available": 0}, {}), "nothing offered is not a clear")
	assert_false(HeistConditions.needs_facts(c), "a result fact, not a log fact")


## events.md v1.7 facts 2 and 3: objective_updated data["open_method"] (GH safe, SL cage). HeistFacts keeps the
## method once seen (it comes before COMPLETED); the condition needs the objective done, not skipped, by that method.
func test_open_method_facts() -> void:
	var f: HeistFacts = HeistFacts.new()
	f.record(&"objective_updated", [&"safe", ACTIVE, {}])
	f.record(&"objective_updated", [&"safe", ACTIVE, {"open_method": &"code"}])
	f.record(&"objective_updated", [&"safe", DONE, {}])
	assert_eq(StringName((f.objectives[&"safe"] as Dictionary).get("open_method", &"")), &"code", "kept through COMPLETED")
	var gh: Dictionary = {"objectives_open_method": {&"safe": &"code"}}
	assert_true(HeistConditions.passes(gh, {}, f.snapshot()), "GH safe by code")
	assert_true(HeistConditions.needs_facts(gh))
	for m: StringName in [&"keycard", &"lockpick", &"drill", &"left_open"]:
		var g: HeistFacts = HeistFacts.new()
		g.record(&"objective_updated", [&"safe", DONE, {"open_method": m}])
		assert_false(HeistConditions.passes(gh, {}, g.snapshot()), "GH safe by %s" % m)
	var sl: Dictionary = {"objectives_open_method": {&"cage": &"code"}}
	for m2: StringName in [&"code", &"saw", &"left_open"]:
		var h: HeistFacts = HeistFacts.new()
		h.record(&"objective_updated", [&"cage", DONE, {"open_method": String(m2)}])  # String or StringName on the wire
		assert_eq(HeistConditions.passes(sl, {}, h.snapshot()), m2 == &"code", "SL cage by %s" % m2)
	var open: HeistFacts = HeistFacts.new()
	open.record(&"objective_updated", [&"cage", ACTIVE, {"open_method": &"code"}])
	assert_false(HeistConditions.passes(sl, {}, open.snapshot()), "method known but the cage objective not completed")
	assert_false(HeistConditions.passes(sl, {}, {}), "no log")
