## A2-08 (D-037): VariantResolver force_if, slot_requires, rare min_difficulty, scalar
## weights_by_difficulty. Backward compatible: tables without the fields roll exactly as before.
extends TestCase

var _slots: Dictionary = {}


func after_each() -> void:
	for g: Variant in _slots:
		for vs: VariantSlot in _slots[g]:
			if is_instance_valid(vs):
				vs.free()
	_slots = {}


## group -> [slot ids] -> VariantSlots (sorted like collect_slots).
func _make_slots(spec: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for g: Variant in spec:
		var arr: Array = []
		for sid: Variant in spec[g]:
			var vs: VariantSlot = VariantSlot.new()
			vs.slot_group = StringName(g)
			vs.slot_id = StringName(sid)
			arr.append(vs)
		arr.sort_custom(func(a: VariantSlot, b: VariantSlot) -> bool: return String(a.slot_id) < String(b.slot_id))
		out[StringName(g)] = arr
	_slots = out
	return out


func _roll(t: HeistVariantTable, seed_value: int, difficulty: int) -> Dictionary:
	GameRng.begin_run(seed_value)
	return VariantResolver.resolve(t, _slots, difficulty)


func _table(rules: Array[Dictionary], rare: Array[Dictionary] = [], scalars: Array[Dictionary] = []) -> HeistVariantTable:
	var t: HeistVariantTable = HeistVariantTable.new()
	t.rules = rules
	t.rare_events = rare
	t.scalars = scalars
	return t


func test_force_if_pins_slots_when_condition_holds() -> void:
	_make_slots({&"smoker": [&"smk"], &"back_door": [&"closed", &"propped"]})
	var t: HeistVariantTable = _table([
		{"group": &"smoker", "pick": Vector2i(1, 1)},
		{"group": &"back_door", "pick": Vector2i(0, 0),
			"force_if": [{"if": {&"smoker": [&"smk"]}, "then": [&"propped"]}]},
	])
	for s: int in range(10):
		var r: Dictionary = _roll(t, 100 + s, Enums.Difficulty.ROUTINE)
		assert_eq(r[&"back_door"], [&"propped"], "smoker active -> propped forced (pick 0 exceeded)")
	# Condition not met (no smoker slot active).
	var t2: HeistVariantTable = _table([
		{"group": &"smoker", "pick": Vector2i(0, 0)},
		{"group": &"back_door", "pick": Vector2i(0, 0),
			"force_if": [{"if": {&"smoker": []}, "then": [&"propped"]}]},
	])
	assert_eq(_roll(t2, 5, Enums.Difficulty.ROUTINE)[&"back_door"], [], "condition unmet -> nothing forced")


func test_force_if_counts_toward_pick_and_beats_excludes() -> void:
	_make_slots({&"a": [&"s1"], &"b": [&"x1", &"x2", &"x3"], &"c": [&"y1", &"y2"]})
	var t: HeistVariantTable = _table([
		{"group": &"a", "pick": Vector2i(1, 1)},
		{"group": &"b", "pick": Vector2i(1, 1), "force_if": [{"if": {&"a": []}, "then": [&"x2"]}]},
		{"group": &"c", "pick": Vector2i(1, 1), "excludes": {&"a": []},
			"force_if": [{"if": {&"a": [&"s1"]}, "then": [&"y2"]}]},
	])
	for s: int in range(10):
		var r: Dictionary = _roll(t, 200 + s, Enums.Difficulty.ROUTINE)
		assert_eq(r[&"b"], [&"x2"], "forced slot fills the pick of 1")
		assert_eq(r[&"c"], [&"y2"], "force_if applies even when excludes zero the pick")
	var t3: HeistVariantTable = _table([
		{"group": &"a", "pick": Vector2i(1, 1)},
		{"group": &"b", "pick": Vector2i(2, 2), "force_if": [{"if": {&"a": []}, "then": [&"x3"]}]},
	])
	var r3: Dictionary = _roll(t3, 3, Enums.Difficulty.ROUTINE)
	assert_eq((r3[&"b"] as Array).size(), 2, "remaining picks rolled up to the pick count")
	assert_has(r3[&"b"], &"x3")


func test_slot_requires_gates_eligibility() -> void:
	_make_slots({&"a": [&"s1"], &"b": [&"x1", &"x2", &"x3"]})
	var t: HeistVariantTable = _table([
		{"group": &"a", "pick": Vector2i(1, 1)},
		{"group": &"b", "pick": Vector2i(3, 3), "slot_requires": {&"x2": {&"a": [&"nope"]}}},
	])
	for s: int in range(10):
		assert_eq(_roll(t, 300 + s, Enums.Difficulty.ROUTINE)[&"b"], [&"x1", &"x3"], "x2 ineligible")
	var t2: HeistVariantTable = _table([
		{"group": &"a", "pick": Vector2i(1, 1)},
		{"group": &"b", "pick": Vector2i(3, 3), "slot_requires": {"x2": {&"a": [&"s1"]}}},
	])
	assert_eq(_roll(t2, 9, Enums.Difficulty.ROUTINE)[&"b"], [&"x1", &"x2", &"x3"], "condition met (String key)")


func test_rare_min_difficulty_gates_without_shifting_other_events() -> void:
	_make_slots({&"g": [&"s1", &"s2", &"s3"]})
	var rules: Array[Dictionary] = [{"group": &"g", "pick": Vector2i(1, 1)}]
	var t_plain: HeistVariantTable = _table(rules, [
		{"id": &"rare.a", "chance": 0.5, "effects": {}},
		{"id": &"rare.b", "chance": 0.5, "effects": {}},
	])
	var t_gated: HeistVariantTable = _table(rules, [
		{"id": &"rare.a", "chance": 0.5, "effects": {}, "min_difficulty": Enums.Difficulty.LETHAL},
		{"id": &"rare.b", "chance": 0.5, "effects": {}},
	])
	var saw_b: bool = false
	for s: int in range(30):
		var rp: Dictionary = _roll(t_plain, 400 + s, Enums.Difficulty.ROUTINE)
		var rg: Dictionary = _roll(t_gated, 400 + s, Enums.Difficulty.ROUTINE)
		assert_false((rg["rare"] as Array).has(&"rare.a"), "below min_difficulty: never fires")
		assert_eq((rg["rare"] as Array).has(&"rare.b"), (rp["rare"] as Array).has(&"rare.b"), "other event unchanged")
		assert_eq(rg[&"g"], rp[&"g"], "rules unchanged")
		saw_b = saw_b or (rg["rare"] as Array).has(&"rare.b")
		var rl: Dictionary = _roll(t_gated, 400 + s, Enums.Difficulty.LETHAL)
		var rpl: Dictionary = _roll(t_plain, 400 + s, Enums.Difficulty.LETHAL)
		assert_eq(rl["rare"], rpl["rare"], "at min_difficulty it behaves like an ungated event")
	assert_true(saw_b, "sanity: rare.b fired at least once")
	# Effects are skipped below the gate.
	var t_fx: HeistVariantTable = _table([{"group": &"g", "pick": Vector2i(0, 0)}], [
		{"id": &"rare.f", "chance": 1.0, "min_difficulty": Enums.Difficulty.BRUTAL,
			"effects": {"force_active": {"group": &"g", "slot": &"s3"}}},
	])
	assert_eq(_roll(t_fx, 1, Enums.Difficulty.ROUTINE)[&"g"], [], "no force below min_difficulty")
	var rb: Dictionary = _roll(t_fx, 1, Enums.Difficulty.BRUTAL)
	assert_eq(rb[&"g"], [&"s3"], "forced at min_difficulty")
	assert_eq(rb["rare"], [&"rare.f"])


func test_scalar_weights_by_difficulty() -> void:
	_make_slots({})
	var sc: Array[Dictionary] = [{"id": &"guards", "values": [2, 4], "weights": PackedFloat32Array([1.0, 0.0]),
		"weights_by_difficulty": {Enums.Difficulty.BRUTAL: PackedFloat32Array([0.0, 1.0])}}]
	var t: HeistVariantTable = _table([], [], sc)
	for s: int in range(5):
		assert_eq(_roll(t, 500 + s, Enums.Difficulty.ROUTINE)[&"guards"], 2, "base weights")
		assert_eq(_roll(t, 500 + s, Enums.Difficulty.BRUTAL)[&"guards"], 4, "Brutal override")
		assert_eq(_roll(t, 500 + s, Enums.Difficulty.TENSE)[&"guards"], 2, "missing difficulty -> weights")


func test_new_fields_absent_or_empty_roll_identically() -> void:
	_make_slots({&"a": [&"s1", &"s2", &"s3"], &"b": [&"x1", &"x2", &"x3", &"x4"]})
	var sc: Array[Dictionary] = [{"id": &"esc", "values": [&"van", &"boat", &"heli"], "weights": PackedFloat32Array([1, 1, 1])}]
	var rare: Array[Dictionary] = [{"id": &"r1", "chance": 0.3, "effects": {}}]
	var plain: HeistVariantTable = _table([
		{"group": &"a", "pick": Vector2i(1, 2)},
		{"group": &"b", "pick": Vector2i(1, 3), "requires": {&"a": []}},
	], rare, sc)
	var empty: HeistVariantTable = _table([
		{"group": &"a", "pick": Vector2i(1, 2), "force_if": [], "slot_requires": {}},
		{"group": &"b", "pick": Vector2i(1, 3), "requires": {&"a": []}, "force_if": [], "slot_requires": {}},
	], rare, [{"id": &"esc", "values": [&"van", &"boat", &"heli"], "weights": PackedFloat32Array([1, 1, 1]),
		"weights_by_difficulty": {}}])
	var differs: bool = false
	var first: Dictionary = {}
	for s: int in range(20):
		var rp: Dictionary = _roll(plain, 600 + s, Enums.Difficulty.HAZARDOUS)
		assert_eq(_roll(empty, 600 + s, Enums.Difficulty.HAZARDOUS), rp, "empty A2-08 fields change nothing")
		if s == 0:
			first = rp
		elif rp != first:
			differs = true
	assert_true(differs, "seeds differ")


func test_deterministic_per_seed_with_all_features() -> void:
	_make_slots({&"a": [&"s1", &"s2"], &"b": [&"x1", &"x2", &"x3"]})
	var t: HeistVariantTable = _table([
		{"group": &"a", "pick": Vector2i(1, 1)},
		{"group": &"b", "pick": Vector2i(1, 2), "force_if": [{"if": {&"a": [&"s2"]}, "then": [&"x1"]}],
			"slot_requires": {&"x3": {&"a": [&"s1"]}}},
	], [{"id": &"r", "chance": 0.5, "effects": {}, "min_difficulty": Enums.Difficulty.TENSE}],
	[{"id": &"v", "values": [1, 2, 3], "weights": PackedFloat32Array([1, 1, 1]),
		"weights_by_difficulty": {Enums.Difficulty.TENSE: PackedFloat32Array([0, 1, 1])}}])
	for s: int in range(10):
		var r1: Dictionary = _roll(t, 700 + s, Enums.Difficulty.TENSE)
		assert_eq(_roll(t, 700 + s, Enums.Difficulty.TENSE), r1, "same seed, same result")
		assert_ne(r1[&"v"], 1, "per-difficulty weights")
		if (r1[&"a"] as Array).has(&"s2"):
			assert_has(r1[&"b"], &"x1", "force_if")
			assert_false((r1[&"b"] as Array).has(&"x3"), "slot_requires")


func test_forward_references_are_logged_and_not_active() -> void:
	_make_slots({&"a": [&"s1"], &"b": [&"x1", &"x2"]})
	var t: HeistVariantTable = _table([
		{"group": &"b", "pick": Vector2i(2, 2), "force_if": [{"if": {&"a": []}, "then": [&"x1"]}],
			"slot_requires": {&"x2": {&"a": []}}},
		{"group": &"a", "pick": Vector2i(1, 1)},
	])
	Log.capture = true
	Log.captured.clear()
	var r: Dictionary = _roll(t, 8, Enums.Difficulty.ROUTINE)
	Log.capture = false
	var force_logged: bool = false
	var slot_logged: bool = false
	for line: String in Log.captured:
		if line.contains("not resolved earlier") and line.contains("force_if"):
			force_logged = true
		if line.contains("not resolved earlier") and line.contains("slot_requires"):
			slot_logged = true
	assert_true(force_logged, "force_if forward ref logged")
	assert_true(slot_logged, "slot_requires forward ref logged")
	assert_eq(r[&"b"], [&"x1"], "forward refs count as not active: x1 not forced but rolled, x2 ineligible")


## GN (C's G1 rehearsal): a rare event's `requires` is honoured: it fires (and pins its slot) only when an
## earlier-resolved group has a listed slot active; the chance draw is made either way.
func test_gn_rare_requires_gates_event_and_its_pin() -> void:
	_make_slots({&"centrepiece": [&"cp_landing", &"cp_store"], &"couriers": [&"vaultline"]})
	var rare_ev: Dictionary = {"id": &"vaultline_early", "chance": 1.0,
		"requires": {&"centrepiece": [&"cp_landing"]},
		"effects": {"force_active": {"group": &"couriers", "slot": &"vaultline"}}}
	for cp: StringName in [&"cp_landing", &"cp_store"]:
		var t: HeistVariantTable = _table([
			{"group": &"centrepiece", "pick": Vector2i(1, 1), "weights_by_difficulty": {
				Enums.Difficulty.ROUTINE: {String(&"cp_landing" if cp == &"cp_store" else &"cp_store"): 0.0}}},
			{"group": &"couriers", "pick": Vector2i(0, 0)},
		], [rare_ev])
		var r: Dictionary = _roll(t, 7, Enums.Difficulty.ROUTINE)
		assert_eq(r[&"centrepiece"], [cp], "setup: centrepiece %s" % cp)
		var fires: bool = cp == &"cp_landing"
		assert_eq((r[VariantResolver.RARE_KEY] as Array).has(&"vaultline_early"), fires,
			"vaultline_early fires only with cp_landing (centrepiece %s)" % cp)
		assert_eq(r[&"couriers"], [&"vaultline"] if fires else [], "its force_active pin follows the condition")


## A conditional rare event without force_active is decided after all rules; `excludes` works the same way.
func test_gn_rare_excludes_and_late_decision() -> void:
	_make_slots({&"alarm": [&"armed"]})
	var t: HeistVariantTable = _table([{"group": &"alarm", "pick": Vector2i(1, 1)}], [
		{"id": &"needs_alarm", "chance": 1.0, "requires": {&"alarm": []}},
		{"id": &"no_alarm", "chance": 1.0, "excludes": {&"alarm": [&"armed"]}},
	])
	var r: Dictionary = _roll(t, 3, Enums.Difficulty.ROUTINE)
	assert_eq(r[VariantResolver.RARE_KEY], [&"needs_alarm"], "requires holds, excludes blocks")


## Adding `requires` to one event never shifts the other events' or rules' draws (same seed, same results).
func test_gn_rare_requires_keeps_draws() -> void:
	_make_slots({&"g": [&"a", &"b", &"c", &"d"]})
	var base: Array[Dictionary] = [{"id": &"e1", "chance": 0.5}, {"id": &"e2", "chance": 0.5}]
	var gated: Array[Dictionary] = [{"id": &"e1", "chance": 0.5, "requires": {&"g": [&"zz"]}}, {"id": &"e2", "chance": 0.5}]
	for s: int in range(20):
		var r1: Dictionary = _roll(_table([{"group": &"g", "pick": Vector2i(1, 3)}], base), 500 + s,
			Enums.Difficulty.ROUTINE)
		var r2: Dictionary = _roll(_table([{"group": &"g", "pick": Vector2i(1, 3)}], gated), 500 + s,
			Enums.Difficulty.ROUTINE)
		assert_eq(r2[&"g"], r1[&"g"], "same group roll (seed %d)" % s)
		assert_eq((r2[VariantResolver.RARE_KEY] as Array).has(&"e2"), (r1[VariantResolver.RARE_KEY] as Array).has(&"e2"),
			"e2 unaffected (seed %d)" % s)
		assert_false((r2[VariantResolver.RARE_KEY] as Array).has(&"e1"), "e1 never fires (no slot zz)")


## RT (C's ask: gold_rush pins trucks_3 AND t3_bullion): `force_active` may list several pins; each holds, and a
## conditional event decided at its first pinned group pins the later ones too (or none).
func test_rt_rare_force_active_several_pins() -> void:
	_make_slots({&"route": [&"r_north", &"r_east"], &"truck_count": [&"trucks_2", &"trucks_3"],
		&"cargo_t3": [&"t3_cash", &"t3_bullion"]})
	var pins: Array = [{"group": &"truck_count", "slot": &"trucks_3"}, {"group": &"cargo_t3", "slot": &"t3_bullion"}]
	var rules: Array[Dictionary] = [
		{"group": &"route", "pick": Vector2i(1, 1), "weights_by_difficulty": {Enums.Difficulty.ROUTINE: {"r_east": 0.0}}},
		{"group": &"truck_count", "pick": Vector2i(0, 0)},
		{"group": &"cargo_t3", "pick": Vector2i(0, 0)},
	]
	var r: Dictionary = _roll(_table(rules, [{"id": &"gold_rush", "chance": 1.0, "effects": {"force_active": pins}}]),
		11, Enums.Difficulty.ROUTINE)
	assert_eq(r[&"truck_count"], [&"trucks_3"], "first pin")
	assert_eq(r[&"cargo_t3"], [&"t3_bullion"], "second pin")
	for need: StringName in [&"r_north", &"r_east"]:
		var ev: Dictionary = {"id": &"gold_rush", "chance": 1.0, "requires": {&"route": [need]},
			"effects": {"force_active": pins}}
		var rc: Dictionary = _roll(_table(rules, [ev]), 11, Enums.Difficulty.ROUTINE)
		var fires: bool = need == &"r_north"
		assert_eq((rc[VariantResolver.RARE_KEY] as Array).has(&"gold_rush"), fires, "conditional: requires %s" % need)
		assert_eq(rc[&"truck_count"], [&"trucks_3"] if fires else [], "pin 1 follows the condition")
		assert_eq(rc[&"cargo_t3"], [&"t3_bullion"] if fires else [], "pin 2 follows the condition")
