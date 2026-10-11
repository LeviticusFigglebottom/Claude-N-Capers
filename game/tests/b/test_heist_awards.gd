## B6-02: payday award math (HeistAwards over CrewStats rows): winners (humans only, D-071), the tie-break
## (lowest slot, D-071), thresholds, shared "zero" awards, and awards skipped
## when their counter is missing (shots / hits / headshots are not in HeistResult yet).
extends TestCase


static func _row(slot: int, is_ai: bool, kills: int, specials: int, downs: int, civs: int) -> Dictionary:
	return {"slot": slot, "is_ai": is_ai, "kills": kills, "specials_killed": specials, "downs": downs,
			"civilians_killed": civs}


static func _find(awards: Array[Dictionary], id: StringName) -> Dictionary:
	for a: Dictionary in awards:
		if StringName(a["id"]) == id:
			return a
	return {}


static func _slots(a: Dictionary) -> String:
	return str(Array(a.get("slots", []) as Array))


func test_table_is_valid_and_has_strings() -> void:
	var t: HeistAwardTable = HeistAwardTable.load_default()
	var table: Dictionary = StringTable.parse_csv()
	var seen: Dictionary = {}
	for a: Dictionary in t.awards:
		var id: String = String(a.get("id", ""))
		assert_false(seen.has(id), "unique award id %s" % id)
		seen[id] = true
		assert_has(CrewStats.STATS, StringName(String(a.get("stat", ""))), "%s names a known stat" % id)
		assert_has(HeistAwardTable.RULES, StringName(String(a.get("rule", ""))), "%s rule" % id)
		assert_has(table, "ui.awards.%s.name" % id)
		assert_has(table, "ui.awards.%s.desc" % id)
	for id: StringName in [&"most_kills", &"most_specials", &"most_accurate", &"most_headshots", &"iron", &"civilian_friendly"]:
		assert_has(t.ids(), id)


func test_most_kills_and_specials() -> void:
	var rows: Array = [_row(0, false, 5, 1, 0, 0), _row(1, true, 9, 0, 0, 0), _row(2, false, 2, 3, 1, 0)]
	var awards: Array[Dictionary] = HeistAwards.compute(rows)
	assert_eq(_slots(_find(awards, &"most_kills")), "[0]", "the AI's 9 kills never win (D-071): best human")
	assert_near(float(_find(awards, &"most_kills")["value"]), 5.0)
	assert_eq(_slots(_find(awards, &"most_specials")), "[2]")
	assert_eq(_find(awards, &"most_kills")["name_key"], &"ui.awards.most_kills.name")


func test_tie_break_lowest_human_slot() -> void:
	var rows: Array = [_row(3, false, 4, 0, 0, 0), _row(0, true, 4, 0, 0, 0), _row(1, false, 4, 0, 0, 0)]
	assert_eq(_slots(_find(HeistAwards.compute(rows), &"most_kills")), "[1]", "human slot 1 (AI slot 0 is no candidate)")
	var ai_only: Array = [_row(2, true, 4, 0, 0, 0), _row(1, true, 4, 0, 0, 0)]
	assert_eq(HeistAwards.compute(ai_only).size(), 0, "Crew AI never earns honours")
	var solo: Array = [_row(0, false, 1, 0, 0, 0), _row(1, true, 7, 0, 0, 0), _row(2, true, 9, 0, 0, 0)]
	assert_eq(_slots(_find(HeistAwards.compute(solo), &"most_kills")), "[0]", "a solo player still earns awards")
	# Input order never matters (deterministic).
	rows.reverse()
	assert_eq(_slots(_find(HeistAwards.compute(rows), &"most_kills")), "[1]")


func test_thresholds_skip_empty_awards() -> void:
	var rows: Array = [_row(0, false, 0, 0, 2, 1), _row(1, true, 0, 0, 3, 2)]
	var awards: Array[Dictionary] = HeistAwards.compute(rows)
	assert_true(_find(awards, &"most_kills").is_empty(), "nobody killed anyone: no Body Count")
	assert_true(_find(awards, &"most_specials").is_empty())
	assert_true(_find(awards, &"iron").is_empty(), "fewest downs is 2 > threshold 1")
	assert_true(_find(awards, &"civilian_friendly").is_empty(), "everybody hurt civilians")


func test_iron_and_civilian_friendly() -> void:
	var rows: Array = [_row(0, false, 1, 0, 1, 0), _row(1, true, 1, 0, 0, 0), _row(2, false, 1, 0, 0, 1),
			_row(3, false, 1, 0, 2, 0)]
	var awards: Array[Dictionary] = HeistAwards.compute(rows)
	assert_eq(_slots(_find(awards, &"iron")), "[2]", "0 downs: human slot 2 (the AI's 0 does not count)")
	assert_eq(_slots(_find(awards, &"civilian_friendly")), "[0, 3]", "shared by every human at 0, by slot")


func test_missing_counters_skip_awards() -> void:
	var rows: Array = [_row(0, false, 3, 0, 0, 0), _row(1, true, 2, 0, 0, 0)]
	var awards: Array[Dictionary] = HeistAwards.compute(rows)
	assert_true(_find(awards, &"most_accurate").is_empty(), "no shots/hits: no accuracy award")
	assert_true(_find(awards, &"most_headshots").is_empty(), "no headshots counter: skipped")
	assert_false(_find(awards, &"most_kills").is_empty())
	var bare: Array = [{"slot": 0, "is_ai": false}, {"slot": 1, "is_ai": true}]
	assert_eq(HeistAwards.compute(bare).size(), 0, "rows without any counter give no award")
	assert_eq(HeistAwards.compute([]).size(), 0)


func test_accuracy_award_uses_only_rows_with_counters() -> void:
	var a: Dictionary = _row(0, false, 1, 0, 0, 0)
	a.merge({"shots": 40, "hits": 20, "headshots": 3})
	var b: Dictionary = _row(1, false, 1, 0, 0, 0)
	b.merge({"shots": 30, "hits": 24, "headshots": 3})
	var c: Dictionary = _row(2, false, 1, 0, 0, 0)
	c.merge({"shots": 5, "hits": 5, "headshots": 5})  # 100% but under min_shots (20)
	var d: Dictionary = _row(3, true, 9, 0, 0, 0)  # AI without the counters
	var awards: Array[Dictionary] = HeistAwards.compute([a, b, c, d])
	var acc: Dictionary = _find(awards, &"most_accurate")
	assert_eq(_slots(acc), "[1]")
	assert_near(float(acc["value"]), 80.0, 0.001, "percentage")
	assert_eq(_slots(_find(awards, &"most_headshots")), "[2]", "5 headshots; min_shots only gates accuracy")
	assert_eq(CrewStats.accuracy_pct(d), -1)
	assert_eq(CrewStats.accuracy_pct({"shots": 0, "hits": 0}), -1, "0 shots = undefined")
	assert_eq(CrewStats.accuracy_pct(a), 50)


func test_awards_follow_table_order() -> void:
	var r: Dictionary = _row(0, false, 3, 1, 0, 0)
	r.merge({"shots": 30, "hits": 15, "headshots": 2})
	var awards: Array[Dictionary] = HeistAwards.compute([r])
	var ids: Array[StringName] = []
	for a: Dictionary in awards:
		ids.append(StringName(a["id"]))
	assert_eq(ids, HeistAwardTable.load_default().ids(), "every award once, in table order")
