## D-139 heist freshness: the formula table (repeat n = 0..10, rotation k = 0..12, never completed), the memory
## (record), the v8 -> v9 migration and schema repair, money / XP in PayoutCalculator, the payday line and reason, the
## heist select note, and two players with different memories in one crew.
extends TestCase

const PAYDAY_SCENE: PackedScene = preload("res://content/ui/results/payday.tscn")
const HEIST: StringName = &"glasshouse"
const OTHER: StringName = &"night_deposit"
const SLOT: int = 6

var _tw: PayoutTweak


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()
	DirAccess.make_dir_recursive_absolute(BTestUtil.profile_root())
	_tw = PayoutCalculator._load_tweak()


func after_each() -> void:
	SaveService.delete_profile(SLOT)
	Log.capture = false
	Log.captured.clear()


func after_all() -> void:
	SaveService.delete_profile(SLOT)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func test_tweak_values() -> void:
	assert_eq(_tw.freshness_memory, 10)
	assert_near(_tw.repeat_step, 0.10, 1e-6)
	assert_near(_tw.repeat_floor, 0.10, 1e-6)
	assert_near(_tw.rotation_step, 0.01, 1e-6)
	assert_near(_tw.rotation_cap, 0.10, 1e-6)


## n = times in the last 10: 1 - 0.10 n, floored at 0.10 (n = 10 -> 0.0 -> 0.10). Completed or not, a repeat wins.
func test_repeat_table() -> void:
	var want: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.1]
	for n: int in range(11):
		var p: PlayerProfile = PlayerProfile.new_default()
		for i: int in range(10 - n):
			HeistFreshness.record(p, OTHER, true, _tw)
		for i: int in range(n):
			HeistFreshness.record(p, HEIST, false, _tw)
		var ev: Dictionary = HeistFreshness.evaluate(p, HEIST, _tw)
		assert_eq(int(ev["n"]), n, "n=%d" % n)
		assert_near(float(ev["mult"]), want[n], 1e-6, "n=%d" % n)
		assert_eq(ev["kind"], HeistFreshness.KIND_REPEAT if n > 0 else HeistFreshness.KIND_NONE, "kind n=%d" % n)


## n = 0, completed: k = runs since its last run - 10; 1 + 0.01 min(k, 10).
func test_rotation_table() -> void:
	for k: int in range(13):
		var p: PlayerProfile = PlayerProfile.new_default()
		HeistFreshness.record(p, HEIST, true, _tw)
		for i: int in range(10 + k):
			HeistFreshness.record(p, OTHER, true, _tw)
		var ev: Dictionary = HeistFreshness.evaluate(p, HEIST, _tw)
		assert_eq(int(ev["n"]), 0, "k=%d" % k)
		assert_eq(int(ev["since"]), 10 + k, "since k=%d" % k)
		assert_eq(int(ev["k"]), k)
		assert_near(float(ev["mult"]), 1.0 + 0.01 * float(mini(k, 10)), 1e-6, "k=%d" % k)
		assert_eq(ev["kind"], HeistFreshness.KIND_ROTATION if k > 0 else HeistFreshness.KIND_NONE)


func test_never_completed_is_neutral() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_near(float(HeistFreshness.evaluate(p, HEIST, _tw)["mult"]), 1.0, 1e-6, "fresh profile")
	HeistFreshness.record(p, HEIST, false, _tw)
	for i: int in range(25):
		HeistFreshness.record(p, OTHER, true, _tw)
	var ev: Dictionary = HeistFreshness.evaluate(p, HEIST, _tw)
	assert_near(float(ev["mult"]), 1.0, 1e-6, "failed only, long gone: no rotation bonus")
	assert_eq(ev["kind"], HeistFreshness.KIND_NONE)
	assert_near(float(HeistFreshness.evaluate(null, HEIST, _tw)["mult"]), 1.0, 1e-6, "no profile")


func test_record_keeps_the_last_ten() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	for i: int in range(12):
		HeistFreshness.record(p, HEIST if i < 2 else OTHER, i == 0, _tw)
	var f: Dictionary = p.freshness
	assert_eq((f["recent"] as Array).size(), 10)
	assert_false((f["recent"] as Array).has(String(HEIST)), "the two oldest runs fell out")
	assert_eq(int(f["runs"]), 12)
	assert_eq(int((f["last_run"] as Dictionary)[String(HEIST)]), 2)
	assert_eq(f["completed"], [String(HEIST)], "only the won run counts as completed")
	HeistFreshness.record(p, &"", true, _tw)
	assert_eq(int(p.freshness["runs"]), 12, "no heist id: nothing recorded")


func test_texts() -> void:
	assert_eq(HeistFreshness.badge_text(1.0), "")
	assert_eq(HeistFreshness.badge_text(1.05), "+5 %")
	assert_eq(HeistFreshness.badge_text(0.8), "-20 %")
	var rep: Dictionary = {"kind": HeistFreshness.KIND_REPEAT, "n": 3}
	assert_eq(HeistFreshness.reason_text(rep, _tw), "Played 3× in your last 10 heists")
	var rot: Dictionary = {"kind": HeistFreshness.KIND_ROTATION, "since": 17}
	assert_eq(HeistFreshness.reason_text(rot, _tw), "Not played in 17 heists")
	assert_eq(HeistFreshness.reason_text({"kind": HeistFreshness.KIND_NONE}, _tw), "")


## v8 -> v9: empty memory; won career heists seed "completed" with last_run 0 (the bonus ramps from there).
func test_migration_seeds_completed_from_career() -> void:
	var v8: Dictionary = PlayerProfile.new_default().to_dict()
	v8["version"] = 8
	v8.erase("freshness")
	v8["career"]["heists"] = {"glasshouse": {"played": 3, "won": 2}, "night_deposit": {"played": 1, "won": 0}}
	var p: PlayerProfile = SaveService.profile_from_save(v8)
	assert_eq(p.version, 9)
	assert_eq(p.freshness["recent"], [])
	assert_eq(int(p.freshness["runs"]), 0)
	assert_eq(p.freshness["completed"], ["glasshouse"])
	assert_eq(p.freshness["last_run"], {"glasshouse": 0})
	assert_near(float(HeistFreshness.evaluate(p, HEIST, _tw)["mult"]), 1.0, 1e-6, "no bonus right after migrating")
	for i: int in range(15):
		HeistFreshness.record(p, OTHER, true, _tw)
	assert_near(float(HeistFreshness.evaluate(p, HEIST, _tw)["mult"]), 1.05, 1e-6, "15 runs later: k = 5")


func test_migration_keeps_existing_freshness() -> void:
	var d: Dictionary = PlayerProfile.new_default().to_dict()
	d["version"] = 8
	d["freshness"] = {"recent": ["glasshouse"], "runs": 4, "last_run": {"glasshouse": 4}, "completed": []}
	var m: Dictionary = SaveService.migrate(d)
	assert_eq(m["freshness"]["runs"], 4)


func test_schema_repairs_bad_freshness() -> void:
	Log.capture = true
	var d: Dictionary = PlayerProfile.new_default().to_dict()
	d["freshness"] = {"recent": ["glasshouse", 7], "runs": -3, "last_run": {"glasshouse": "x", "vault": 2}, "completed": "all"}
	var p: PlayerProfile = SaveService.profile_from_save(d)
	assert_eq(p.freshness["recent"], ["glasshouse"])
	assert_eq(int(p.freshness["runs"]), 0)
	assert_eq(p.freshness["last_run"], {"vault": 2})
	assert_eq(p.freshness["completed"], [])
	assert_true(Log.captured.size() >= 4, "each repair warns")


func test_profile_round_trip() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	HeistFreshness.record(p, HEIST, true, _tw)
	HeistFreshness.record(p, OTHER, false, _tw)
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var q: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(q.freshness, p.freshness)


## Money: on gross (after crew alive), the civilian penalty after and unscaled. XP: the last step, also on failure.
func test_calculator_money_and_xp() -> void:
	var r: Dictionary = HeistCatalog.sample_result()
	var base: Dictionary = PayoutCalculator.compute(r, null, _tw)
	var cut: Dictionary = PayoutCalculator.compute(r, null, _tw, false, -1, 1.0, 1.0, 0.0, 0.8)
	var alive: int = roundi(float(base["subtotal"]) * float(base["crew_alive_mult"]))
	assert_eq(int(base["freshness_money"]), 0)
	assert_eq(int(cut["freshness_money"]), roundi(float(alive) * -0.2))
	assert_eq(int(cut["gross"]), alive + int(cut["freshness_money"]))
	assert_eq(int(cut["civilian_penalty"]), int(base["civilian_penalty"]), "penalty unscaled")
	assert_eq(int(cut["total"]), int(cut["gross"]) - int(cut["civilian_penalty"]))
	var lines: Array = cut["xp_lines"] as Array
	assert_eq(lines.size(), 8)
	assert_eq(StringName(lines[7]["key"]), PayoutCalculator.XP_FRESHNESS)
	assert_eq(int(cut["xp_total"]), int(base["xp_total"]) + int(lines[7]["amount"]))
	assert_eq(int(lines[7]["amount"]), roundi(float(base["xp_total"]) * -0.2))
	var lost: Dictionary = r.duplicate(true)
	lost["success"] = false
	var fail_base: Dictionary = PayoutCalculator.compute(lost, null, _tw)
	var fail_cut: Dictionary = PayoutCalculator.compute(lost, null, _tw, false, -1, 1.0, 1.0, 0.0, 0.5)
	assert_eq(int(fail_cut["xp_total"]), roundi(float(fail_base["xp_total"]) * 0.5), "failed-heist XP scaled too")


## The payday screen shows "Heist freshness -20 %" on money and XP with the reason, then records the run.
func test_payday_line_and_record() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	var r: Dictionary = HeistCatalog.sample_result()
	var heist: StringName = StringName(r["heist_id"])
	HeistFreshness.record(p, heist, true, _tw)
	HeistFreshness.record(p, heist, true, _tw)
	assert_eq(SaveService.save_profile(p, SLOT), OK)
	var screen: PaydayScreen = PAYDAY_SCENE.instantiate() as PaydayScreen
	screen.profile_slot = SLOT
	add_child(screen)
	await wait_frames(1)
	screen.show_result(r)
	assert_near(float(screen.payout["freshness"]), 0.8, 1e-6)
	var money: Label = screen.value_labels[&"freshness"] as Label
	assert_true(money.visible)
	assert_eq(money.text, UiText.money(int(screen.payout["freshness_money"])))
	assert_true(int(screen.payout["freshness_money"]) < 0)
	var caption: Label = money.get_parent().get_child(money.get_index() - 1) as Label
	assert_eq(caption.text, "Heist freshness -20 %")
	assert_true((screen.value_labels[&"xp.ui.results.xp.freshness"] as Label).visible)
	var reason: Label = screen.find_child("FreshnessReason", true, false) as Label
	assert_true(reason != null, "reason label")
	assert_eq(reason.text, "Played 2× in your last 10 heists")
	var bonus: int = int(screen.payout["gross"]) - int(screen.payout["subtotal"]) - int(screen.payout["freshness_money"])
	assert_eq((screen.value_labels[&"crew_alive"] as Label).text, UiText.money(bonus), "crew alive line excludes freshness")
	var saved: PlayerProfile = SaveService.load_profile(SLOT)
	assert_eq(int(saved.freshness["runs"]), 3, "the payday recorded this run")
	assert_eq(HeistFreshness.evaluate(saved, heist, _tw)["n"], 3)
	screen.queue_free()
	await wait_frames(1)


func test_heist_select_note() -> void:
	var p: PlayerProfile = PlayerProfile.new_default()
	assert_eq(HeistSelect.freshness_note(HEIST, p), "", "neutral: hidden")
	HeistFreshness.record(p, HEIST, true, _tw)
	assert_eq(HeistSelect.freshness_note(HEIST, p), "Freshness -10 %  ·  Played 1× in your last 10 heists")
	assert_eq(HeistSelect.freshness_note(HEIST, null), "")


## One crew, one result: each player's payday uses their own memory.
func test_two_players_different_memories() -> void:
	var r: Dictionary = HeistCatalog.sample_result()
	var heist: StringName = StringName(r["heist_id"])
	var tired: PlayerProfile = PlayerProfile.new_default()
	for i: int in range(3):
		HeistFreshness.record(tired, heist, true, _tw)
	var rotated: PlayerProfile = PlayerProfile.new_default()
	HeistFreshness.record(rotated, heist, true, _tw)
	for i: int in range(15):
		HeistFreshness.record(rotated, OTHER, true, _tw)
	var slots: Array[int] = []
	for m: Dictionary in r.get("crew", []) as Array:
		slots.append(int(m.get("slot", 0)))
	var a: Dictionary = PaydayScreen.compute_payout(r, tired, slots[0] if slots.size() > 0 else 0)
	var b: Dictionary = PaydayScreen.compute_payout(r, rotated, slots[1] if slots.size() > 1 else 1)
	assert_near(float(a["freshness"]), 0.7, 1e-6)
	assert_near(float(b["freshness"]), 1.05, 1e-6)
	assert_true(int(a["freshness_money"]) < 0 and int(b["freshness_money"]) > 0)
	assert_true(int(a["xp_lines"][7]["amount"]) < 0 and int(b["xp_lines"][7]["amount"]) > 0)
