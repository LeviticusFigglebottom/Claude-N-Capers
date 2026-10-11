## A1-01: HeistLauncher / HeistRuntime / VariantResolver / test hooks (test_hooks.md).
extends TestCase


func _table() -> HeistVariantTable:
	var t: HeistVariantTable = HeistVariantTable.new()
	t.rules = [
		{"group": &"keycard", "pick": Vector2i(1, 1)},
		{"group": &"guard_extra", "pick": Vector2i(0, 2)},
	]
	t.scalars = [{"id": &"escape_type", "values": [&"van", &"walk", &"boat"], "weights": PackedFloat32Array([1, 1, 1])}]
	return t


func _groups() -> Dictionary:
	return {&"keycard": [&"k1", &"k2", &"k3", &"k4"], &"guard_extra": [&"g1", &"g2", &"g3"]}


func _launch(seed_value: int, opts: Dictionary = {}) -> HeistRuntime:
	var o: Dictionary = {"map_packed": ATestMaps.basic(2, 1, _groups(), _table())}
	o.merge(opts, true)
	return await HeistLauncher.launch(&"unit_map", seed_value, Enums.Difficulty.ROUTINE, self, o)


func test_launch_spawns_crew_and_npcs() -> void:
	var rt: HeistRuntime = await _launch(1001)
	assert_true(rt != null, "runtime returned")
	if rt == null:
		return
	assert_eq(rt.phase, Enums.HeistPhase.CASING, "starts in casing")
	assert_eq(rt.crew_members().size(), 4, "solo + 3 AI")
	assert_true(rt.crew_controller(0) is CrewController, "crew_controller(0)")
	assert_eq(rt.npcs(&"guard").size(), 2)
	assert_eq(rt.npcs(&"civilian").size(), 1)
	assert_eq(rt.npcs().size(), 3)
	assert_true(NetIds.of(rt.crew_controller(0)) != 0, "crew has net_id")
	assert_true(Ids.lookup(NetIds.of(rt.npcs()[0])) == rt.npcs()[0], "npc registered in Ids")
	rt.teardown()
	await wait_frames(1)


func test_variants_deterministic_per_seed() -> void:
	var rt: HeistRuntime = await _launch(1001)
	var v1: Dictionary = rt.variants.duplicate(true)
	rt.teardown()
	rt = await _launch(1001)
	assert_eq(rt.variants, v1, "same seed, same variants")
	rt.teardown()
	var differs: bool = false
	for s: int in [1002, 1003, 1004, 1005]:
		rt = await _launch(s)
		if rt.variants != v1:
			differs = true
		rt.teardown()
	assert_true(differs, "other seeds differ")
	assert_eq((v1[&"keycard"] as Array).size(), 1, "pick 1 keycard")
	assert_true(v1.has(&"escape_type"), "scalar rolled")
	assert_true(v1.has("rare"), "rare list present")


func test_inactive_slots_are_emptied() -> void:
	var rt: HeistRuntime = await _launch(77)
	var active: Array = rt.variants[&"keycard"]
	for vs: VariantSlot in rt.map.get_variant_slots(&"keycard"):
		if active.has(vs.slot_id):
			assert_eq(vs.get_child_count(), 1, "active slot keeps content")
		else:
			assert_eq(vs.get_child_count(), 0, "inactive slot emptied")
	rt.teardown()


func test_resolver_requires_and_excludes() -> void:
	GameRng.begin_run(5)
	var t: HeistVariantTable = HeistVariantTable.new()
	t.rules = [
		{"group": &"a", "pick": Vector2i(1, 1)},
		{"group": &"b", "pick": Vector2i(1, 1), "requires": {&"a": [&"nope"]}},
		{"group": &"c", "pick": Vector2i(1, 1), "excludes": {&"a": []}},
		{"group": &"d", "pick": Vector2i(0, 0), "difficulty_add": [0, 0, 0, 2]},
	]
	var slots: Dictionary = {}
	for g: StringName in [&"a", &"b", &"c", &"d"]:
		var arr: Array = []
		for sid: StringName in [&"s1", &"s2", &"s3"]:
			var vs: VariantSlot = VariantSlot.new()
			vs.slot_group = g
			vs.slot_id = sid
			arr.append(vs)
		slots[g] = arr
	var r: Dictionary = VariantResolver.resolve(t, slots, Enums.Difficulty.BRUTAL)
	assert_eq((r[&"a"] as Array).size(), 1)
	assert_eq((r[&"b"] as Array).size(), 0, "requires unmet")
	assert_eq((r[&"c"] as Array).size(), 0, "excluded")
	assert_eq((r[&"d"] as Array).size(), 2, "difficulty_add on Brutal")
	for g: Variant in slots:
		for vs: VariantSlot in slots[g]:
			vs.free()


func test_alarm_goes_loud_without_scene_change() -> void:
	var rt: HeistRuntime = await _launch(9)
	var map_before: HeistMap = rt.map
	var phases: Array[int] = []
	var cb: Callable = func(_o: int, n: int) -> void: phases.append(n)
	assert_eq(rt.phase, Enums.HeistPhase.CASING, "starts casing")
	EventBus.heist_phase_changed.connect(cb)
	EventBus.alarm_raised.emit(&"test", 0)
	assert_eq(rt.phase, Enums.HeistPhase.LOUD)
	assert_eq(phases, [Enums.HeistPhase.LOUD] as Array[int], "alarm while casing: CASING -> LOUD directly (no STEALTH hop)")
	assert_true(rt.map == map_before and is_instance_valid(map_before), "S11.2 same map instance")
	for c: CrewController in rt.crew_members():
		assert_true(c.masked, "S1.2 alarm masks everyone")
	EventBus.heist_phase_changed.disconnect(cb)
	rt.teardown()


func test_end_heist_result_shape() -> void:
	var rt: HeistRuntime = await _launch(3)
	var got: Array[Dictionary] = []
	var cb: Callable = func(r: Dictionary) -> void: got.append(r)
	EventBus.heist_ended.connect(cb)
	rt.end_heist(true)
	EventBus.heist_ended.disconnect(cb)
	assert_eq(got.size(), 1)
	for k: String in ["heist_id", "success", "stealth", "time_s", "difficulty", "contract_pay", "loot",
			"small_loot", "crew", "pagers_answered", "seed", "variants"]:
		assert_has(got[0], k)
	assert_eq(rt.phase, Enums.HeistPhase.ENDED)
	rt.teardown()


func test_teardown_clears_services_and_ids() -> void:
	var rt: HeistRuntime = await _launch(4)
	var id: int = NetIds.of(rt.crew_controller(0))
	rt.teardown()
	assert_true(Ids.lookup(id) == null, "ids reset")
	assert_false(Services.has(&"interaction"), "services cleared")


func test_resolver_rejects_forward_references() -> void:
	GameRng.begin_run(6)
	var t: HeistVariantTable = HeistVariantTable.new()
	t.rules = [
		{"group": &"b", "pick": Vector2i(1, 1), "requires": {&"a": []}},
		{"group": &"a", "pick": Vector2i(1, 1)},
	]
	var slots: Dictionary = {}
	for g: StringName in [&"a", &"b"]:
		var vs: VariantSlot = VariantSlot.new()
		vs.slot_group = g
		vs.slot_id = &"s1"
		slots[g] = [vs]
	Log.capture = true
	Log.captured.clear()
	var r: Dictionary = VariantResolver.resolve(t, slots, Enums.Difficulty.ROUTINE)
	Log.capture = false
	var logged: bool = false
	for line: String in Log.captured:
		if line.contains("not resolved earlier"):
			logged = true
	assert_true(logged, "forward reference logged as contract violation (heist_map.md v1.1)")
	assert_eq((r[&"b"] as Array).size(), 0, "forward reference counts as not active")
	for g: Variant in slots:
		(slots[g][0] as VariantSlot).free()
