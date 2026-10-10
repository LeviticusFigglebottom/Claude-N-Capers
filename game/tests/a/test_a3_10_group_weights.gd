## A3-10 (QC-18, D-042): per-difficulty slot weights on slot-group rules
## ("weights_by_difficulty": {difficulty: {slot_id: weight}}). Backward compatible and deterministic.
extends TestCase

var _slots: Dictionary = {}


func after_each() -> void:
	for g: Variant in _slots:
		for vs: VariantSlot in _slots[g]:
			if is_instance_valid(vs):
				vs.free()
	_slots = {}


func _make_slots(group: StringName, ids: Array, weights: Array = []) -> void:
	var arr: Array = []
	for i: int in range(ids.size()):
		var vs: VariantSlot = VariantSlot.new()
		vs.slot_group = group
		vs.slot_id = StringName(ids[i])
		if i < weights.size():
			vs.weight = float(weights[i])
		arr.append(vs)
	arr.sort_custom(func(a: VariantSlot, b: VariantSlot) -> bool: return String(a.slot_id) < String(b.slot_id))
	_slots[group] = arr


func _roll(t: HeistVariantTable, seed_value: int, difficulty: int) -> Dictionary:
	GameRng.begin_run(seed_value)
	return VariantResolver.resolve(t, _slots, difficulty)


func _table(rules: Array[Dictionary]) -> HeistVariantTable:
	var t: HeistVariantTable = HeistVariantTable.new()
	t.rules = rules
	return t


## Shadow Ledger `guard_extra`: Brutal 1, 1, 0 (extra_none never), Routine slot weights 1, 1, 2.
func _guard_extra_table() -> HeistVariantTable:
	return _table([{"group": &"guard_extra", "pick": Vector2i(1, 1),
		"weights_by_difficulty": {
			Enums.Difficulty.BRUTAL: {&"stair_watch": 1.0, &"roof_watch": 1.0, &"extra_none": 0.0},
			Enums.Difficulty.LETHAL: {"extra_none": 0.0},
		}}])


func test_difficulty_weights_override_slot_weights() -> void:
	_make_slots(&"guard_extra", [&"stair_watch", &"roof_watch", &"extra_none"], [1.0, 1.0, 2.0])
	var t: HeistVariantTable = _guard_extra_table()
	var none_routine: int = 0
	for s: int in range(200):
		var r: Dictionary = _roll(t, 3000 + s, Enums.Difficulty.BRUTAL)
		assert_false((r[&"guard_extra"] as Array).has(&"extra_none"), "Brutal: extra_none weight 0 (seed %d)" % (3000 + s))
		var r2: Dictionary = _roll(t, 3000 + s, Enums.Difficulty.LETHAL)
		assert_false((r2[&"guard_extra"] as Array).has(&"extra_none"), "String slot keys accepted")
		var r3: Dictionary = _roll(t, 3000 + s, Enums.Difficulty.ROUTINE)
		if (r3[&"guard_extra"] as Array).has(&"extra_none"):
			none_routine += 1
	assert_true(none_routine > 70 and none_routine < 130, "unlisted difficulty keeps VariantSlot.weight (2/4: %d/200)" % none_routine)


func test_weights_shift_distribution() -> void:
	# Night Deposit laser_pattern: Routine 0.5/0.2/0.3 (slot weights), Brutal 0.2/0.4/0.4.
	_make_slots(&"laser_pattern", [&"laser_static", &"laser_sweep", &"laser_timed"], [0.5, 0.2, 0.3])
	var t: HeistVariantTable = _table([{"group": &"laser_pattern", "pick": Vector2i(1, 1),
		"weights_by_difficulty": {Enums.Difficulty.BRUTAL: {&"laser_static": 0.2, &"laser_sweep": 0.4, &"laser_timed": 0.4}}}])
	var static_r: int = 0
	var static_b: int = 0
	for s: int in range(400):
		if (_roll(t, 9000 + s, Enums.Difficulty.ROUTINE)[&"laser_pattern"] as Array).has(&"laser_static"):
			static_r += 1
		if (_roll(t, 9000 + s, Enums.Difficulty.BRUTAL)[&"laser_pattern"] as Array).has(&"laser_static"):
			static_b += 1
	assert_true(static_r > 160 and static_r < 240, "Routine static ~50%% (%d/400)" % static_r)
	assert_true(static_b > 50 and static_b < 115, "Brutal static ~20%% (%d/400)" % static_b)


func test_deterministic_and_backward_compatible() -> void:
	_make_slots(&"guard_extra", [&"stair_watch", &"roof_watch", &"extra_none"], [1.0, 1.0, 2.0])
	var with_field: HeistVariantTable = _guard_extra_table()
	var plain: HeistVariantTable = _table([{"group": &"guard_extra", "pick": Vector2i(1, 1)}])
	for s: int in range(30):
		assert_eq(_roll(with_field, 70 + s, Enums.Difficulty.BRUTAL), _roll(with_field, 70 + s, Enums.Difficulty.BRUTAL), "same seed, same roll")
		assert_eq(_roll(with_field, 70 + s, Enums.Difficulty.ROUTINE), _roll(plain, 70 + s, Enums.Difficulty.ROUTINE),
			"unlisted difficulty rolls exactly as a table without the field")


func test_later_rules_keep_their_draws() -> void:
	# The field never adds or removes draws, so a later group rolls the same.
	_make_slots(&"a", [&"a1", &"a2", &"a3"])
	_make_slots(&"b", [&"b1", &"b2", &"b3", &"b4"])
	var t1: HeistVariantTable = _table([{"group": &"a", "pick": Vector2i(1, 1)}, {"group": &"b", "pick": Vector2i(1, 2)}])
	var t2: HeistVariantTable = _table([
		{"group": &"a", "pick": Vector2i(1, 1), "weights_by_difficulty": {Enums.Difficulty.TENSE: {&"a1": 5.0}}},
		{"group": &"b", "pick": Vector2i(1, 2)}])
	for s: int in range(30):
		var b1: Variant = _roll(t1, 500 + s, Enums.Difficulty.TENSE)[&"b"]
		assert_eq(b1, _roll(t2, 500 + s, Enums.Difficulty.TENSE)[&"b"], "b unchanged (seed %d)" % (500 + s))
