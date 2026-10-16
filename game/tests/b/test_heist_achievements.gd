## D-115: per-heist achievements (5-6 each for Golden Hour, Nightfall Depository, Shadow Ledger, Dockside Burn,
## Gallery Night). Every one unlocks from a scripted HeistResult + in-heist fact log (HeistFacts) that satisfies
## it, and a near miss (one condition broken) does not; rewards are granted; strings, categories and condition
## keys are valid; fact conditions fail closed without a log; the PaydayScreen hands its log to on_payday.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const SLOT: int = 0
const HEISTS: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn", &"gallery_night"]
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
		assert_true(HeistCatalog.ids().has(heist), "%s names an offered heist" % a.id)
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
		row["top"] = bool(row["top"]) or int(c.get("difficulty_min", 0)) == Enums.Difficulty.CATACLYSM
		per[heist] = row
	for h: StringName in HEISTS:
		assert_true(per.has(h), "%s has achievements" % h)
		var row: Dictionary = per.get(h, {"n": 0, "speed": false, "top": false}) as Dictionary
		assert_true(int(row["n"]) >= 4 and int(row["n"]) <= 6, "%s: 4-6 achievements (%d)" % [h, int(row["n"])])
		assert_true(bool(row["speed"]), "%s has a speed run" % h)
		assert_true(bool(row["top"]), "%s has a Cataclysm clear" % h)
	var parts: Array[StringName] = []
	for a: AchievementDef in _heist_defs():
		for id: StringName in a.rewards:
			assert_false(parts.has(id), "%s: reward %s used once" % [a.id, id])
			parts.append(id)


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
	# a spawned thermite bag that is consumed (never secured) does not break "no bag left behind"
	var f: HeistFacts = HeistFacts.new()
	f.record(&"loot_spawned", [1, &"loot.thermite"])
	f.record(&"loot_spawned", [2, &"loot.jewelry"])
	f.record(&"loot_secured", [2, &"loot.jewelry", 6500])
	assert_true(HeistConditions.passes({"all_loot_secured": true}, r, f.snapshot()))
	f.record(&"loot_spawned", [3, &"loot.jewelry"])
	assert_false(HeistConditions.passes({"all_loot_secured": true}, r, f.snapshot()), "bag 3 left behind")
	assert_true(HeistConditions.passes({"all_loot_secured": true}, {"loot": [_bag(&"loot.jewelry")], "loot_available": 1},
			{"recorded": true}), "a loot_available fact (ENV A request) replaces the log check")


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
	var spawned: Array = _spawn_secure(&"loot.jewelry", 4, 4)
	out[&"achievement.gh_whole_consignment"] = {
		"pass": _run(_res(gh, true, {"loot": jew}), _facts(spawned, {&"safe_loot": DONE}), "consignment"),
		"miss": [
			_run(_res(gh, true, {"loot": jew}), _facts(_spawn_secure(&"loot.jewelry", 5, 4), {&"safe_loot": DONE}), "bag left"),
			_run(_res(gh, true, {"loot": _bags(&"loot.jewelry", 3)}), _facts(_spawn_secure(&"loot.jewelry", 3, 3),
					{&"safe_loot": DONE}), "3 bags"),
			_run(_res(gh, true, {"loot": jew}), _facts(spawned, {&"safe_loot": ACTIVE}), "safe not emptied"),
		],
	}
	var code_objs: Dictionary = {&"code": DONE, &"safe": DONE, &"keycard": [DONE, true]}
	var code_ev: Array = [[&"item_picked_up", [&"item.code_note", 0]], [&"interaction_completed", [12, 0, &"keypad"]]]
	out[&"achievement.gh_managers_combination"] = {
		"pass": _run(_res(gh, true), _facts(code_ev, code_objs), "code"),
		"miss": [
			_run(_res(gh, true), _facts(code_ev + [[&"device_started", [9, &"drill", 120.0]]], code_objs), "drill"),
			_run(_res(gh, true), _facts(code_ev + [[&"item_picked_up", [&"item.keycard", 1]]], code_objs), "keycard"),
			_run(_res(gh, true), _facts([], {&"code": [DONE, true], &"safe": DONE}), "code skipped"),
		],
	}
	out[&"achievement.gh_window_shopping"] = {
		"pass": _run(_res(gh, true), _facts([[&"small_loot_taken", [500, 0]]], {}), "no glass"),
		"miss": [
			_run(_res(gh, true), _facts([[&"glass_broken", [4, Vector3.ZERO]]], {}), "glass"),
			_run(_res(gh, false), _facts([], {}), "loud"),
		],
	}
	out[&"achievement.gh_cataclysm"] = {
		"pass": _run(_res(gh, true, {"difficulty": Enums.Difficulty.CATACLYSM}), {}, "stealth cataclysm"),
		"miss": [
			_run(_res(gh, false, {"difficulty": Enums.Difficulty.CATACLYSM}), {}, "loud"),
			_run(_res(gh, true, {"difficulty": Enums.Difficulty.LETHAL}), {}, "lethal"),
		],
	}
	# --- Nightfall Depository
	out[&"achievement.nd_quiet_deposit"] = _quiet_case(nd)
	out[&"achievement.nd_bankers_hours"] = _speed_case(nd, 700.0, 760.0)
	var nd_objs: Dictionary = {&"vault_loot": DONE, &"depository": DONE}
	out[&"achievement.nd_cleaned_out"] = {
		"pass": _run(_res(nd, true, {"loot": _bags(&"loot.cash", 9)}), _facts(_spawn_secure(&"loot.cash", 9, 9), nd_objs), "all"),
		"miss": [
			_run(_res(nd, true, {"loot": _bags(&"loot.cash", 9)}), _facts(_spawn_secure(&"loot.cash", 9, 9),
					{&"vault_loot": DONE, &"depository": ACTIVE}), "depository shut"),
			_run(_res(nd, true, {"loot": _bags(&"loot.cash", 8)}), _facts(_spawn_secure(&"loot.cash", 8, 8), nd_objs), "8 bags"),
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
		"pass": _run(_res(sl, true, {"loot": sl_loot}), _facts(_spawn_secure(&"loot.ledger_drives", 8, 8), sl_objs), "all"),
		"miss": [
			_run(_res(sl, true, {"loot": sl_loot.slice(0, 5) + _bags(&"loot.painting", 2)}),
					_facts(_spawn_secure(&"loot.ledger_drives", 7, 7), sl_objs), "2 drives"),
			_run(_res(sl, true, {"loot": sl_loot}), _facts(_spawn_secure(&"loot.ledger_drives", 8, 8),
					{&"study_safe": DONE, &"paintings": DONE}), "archive safe shut"),
		],
	}
	var cage: Dictionary = {&"cage_code": DONE, &"cage": DONE}
	out[&"achievement.sl_measure_twice"] = {
		"pass": _run(_res(sl, true), _facts([[&"device_started", [5, &"time_lock", 90.0]]], cage), "code"),
		"miss": [
			_run(_res(sl, true), _facts([[&"device_started", [6, &"saw", 90.0]]], cage), "saw"),
			_run(_res(sl, true), _facts([], {&"cage_code": ACTIVE, &"cage": DONE}), "no code"),
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
	var pier_ev: Array = _spawn_secure(&"loot.cash_bricks", 12, 12) + [[&"loot_spawned", [99, &"loot.thermite"]]]
	out[&"achievement.db_strip_the_pier"] = {
		"pass": _run(_res(db, false, {"loot": pier + [_bag(&"loot.thermite")]}), _facts(pier_ev, {}), "all"),
		"miss": [
			_run(_res(db, false, {"loot": pier.slice(0, 11) + _bags(&"loot.cash_bricks", 1)}), _facts(pier_ev, {}), "3 product"),
			_run(_res(db, false, {"loot": pier}), _facts(pier_ev + [[&"loot_spawned", [77, &"loot.contraband"]]], {}), "burned bag"),
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
		"pass": _run(_res(gn, true, {"loot": art + [_bag(&"loot.painting_study")]}), _facts(_spawn_secure(LANTERN, 5, 5), {}), "all"),
		"miss": [
			_run(_res(gn, true, {"loot": art}), _facts(_spawn_secure(LANTERN, 4, 4), {}), "no study"),
			_run(_res(gn, true, {"loot": art.slice(1) + _bags(&"loot.painting_study", 2)}), _facts(_spawn_secure(LANTERN, 5, 5), {}),
					"no Lantern Bearer"),
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


## `spawned` loot_spawned facts (bag ids 1..n), the first `secured` of them secured.
func _spawn_secure(id: StringName, spawned: int, secured: int) -> Array:
	var out: Array = []
	for i: int in range(spawned):
		out.append([&"loot_spawned", [i + 1, id]])
	for i: int in range(secured):
		out.append([&"loot_secured", [i + 1, id, 1000]])
	return out


## A recorded log: events [[signal, args], ...]; objectives id -> state, or [state, skipped].
func _facts(events: Array, objectives: Dictionary) -> Dictionary:
	var f: HeistFacts = HeistFacts.new()
	for id: StringName in objectives:
		var v: Variant = objectives[id]
		var st: int = int((v as Array)[0]) if v is Array else int(v)
		var skipped: bool = bool((v as Array)[1]) if v is Array else false
		f.record(&"objective_updated", [id, st, {"skipped": skipped} if skipped else {}])
	for e: Variant in events:
		f.record(StringName((e as Array)[0]), (e as Array)[1] as Array)
	return f.snapshot()
