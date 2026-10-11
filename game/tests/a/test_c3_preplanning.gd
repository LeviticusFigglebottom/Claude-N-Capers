## A2-07 / A3-08 C3: ENV A applies a PreplanResult (docs/contracts/preplanning.md v1.0, D-038):
## TEAM modifier sources (cleared at teardown), drops at `<Map>/Preplan/<point id>` Marker3Ds, spawn
## and escape choice, forced variants and reveals. The dev `options["preplanning"]` ids path goes
## through ENV B's resolver (PreplanPlan), never ENV A's own catalog lookup.
extends TestCase

const TIES: StringName = &"stealth.cable_ties_extra"

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	PreplanAssets.unregister_drop(&"unit_crate")
	await wait_frames(1)


func _def() -> HeistDef:
	var def: HeistDef = HeistDef.new()
	def.id = &"unit_preplan"
	return def


func _table() -> HeistVariantTable:
	var t: HeistVariantTable = HeistVariantTable.new()
	t.rules = [{"group": &"keycard", "pick": Vector2i(1, 1)}]
	return t


func _launch(options: Dictionary, seed_value: int = 11) -> HeistRuntime:
	var map: PackedScene = ATestMaps.with_preplan_markers(_def(), [&"preplan_spawn_alley"] as Array[StringName],
		{"pp_alley": Vector3(4, 0, 4), "pp_dumpsters": {"pos": Vector3(-4, 0, 4), "category": &"drop_zone"}},
		{&"keycard": [&"k1", &"k2", &"k3"]}, _table())
	var o: Dictionary = {"map_packed": map, "ai_teammates": 1, "skip_casing": true}
	o.merge(options, true)
	_rt = await HeistLauncher.launch(&"unit_preplan", seed_value, Enums.Difficulty.ROUTINE, self, o)
	return _rt


## A contract-shaped PreplanResult (version 1).
static func _result(extra: Dictionary) -> Dictionary:
	var r: Dictionary = {
		"version": 1, "modifier_sources": {}, "drops": [], "spawn_tag": &"", "escape_tag": &"",
		"force_variants": {}, "reveals": [], "cash_spent": {}, "plan": {},
	}
	r.merge(extra, true)
	return r


func _reset() -> void:
	_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_c3_modifier_sources_apply_and_clear_at_teardown() -> void:
	await _launch({})
	var base: int = (_rt.crew_controller(0) as CrewController).cable_ties
	assert_false(_rt.preplan.is_active(), "no pre-planning without the option")
	await _reset()
	await _launch({"preplan": _result({"modifier_sources": {&"asset.extra_cable_ties": {TIES: 2}}})})
	assert_near(Modifiers.add(0, TIES), 2.0, 0.001, "TEAM source applies to slot 0")
	assert_near(Modifiers.add(1, TIES), 2.0, 0.001, "and to slot 1")
	assert_eq((_rt.crew_controller(0) as CrewController).cable_ties, base + 2, "applied before the crew reads modifiers")
	assert_true(_rt.preplan.has_asset(&"asset.extra_cable_ties"))
	await _reset()
	assert_near(Modifiers.add(0, TIES), 0.0, 0.001, "cleared at teardown")


func test_c3_spawn_tag_uses_preplan_spawns() -> void:
	await _launch({})
	for c: CrewController in _rt.crew_members():
		assert_true(c.global_position.x < 0.0, "default spawns (x < 0) without a spawn tag, got %s" % c.global_position)
	await _reset()
	await _launch({"preplan": _result({"spawn_tag": &"preplan_spawn_alley"})})
	for c: CrewController in _rt.crew_members():
		assert_true(c.global_position.x > 9.0, "preplan_spawn_alley spawns (x >= 10), got %s" % c.global_position)


func test_c3_drops_spawn_at_preplan_markers_by_node_name() -> void:
	PreplanAssets.register_drop(&"unit_crate", func(_id: StringName, _d: Dictionary) -> Node3D:
		var n: PreplanDrop = PreplanDrop.new()
		n.set_meta(&"from_factory", true)
		return n)
	await _launch({"preplan": _result({"drops": [
		{"asset": &"asset.ammo_bag_drop", "kind": &"deployable.ammo_bag", "point": &"pp_alley", "params": {}},
		{"asset": &"asset.crate", "kind": &"unit_crate", "point": &"pp_dumpsters", "params": {"n": 1}},
		{"asset": &"asset.lost", "kind": &"unit_crate", "point": &"pp_missing", "params": {}},
	]})})
	var ammo: Node3D = _rt.preplan.drops.get(&"pp_alley") as Node3D
	assert_true(ammo != null, "ammo bag dropped at pp_alley")
	if ammo != null:
		assert_true(ammo.global_position.distance_to(Vector3(4, 0, 4)) < 0.01, "at the <Map>/Preplan/pp_alley marker")
		assert_true(ammo is DeployablePrefab, "deployable.* kinds spawn a DeployablePrefab, got %s" % ammo)
		if ammo is DeployablePrefab:
			assert_eq((ammo as DeployablePrefab).kind, &"ammo_bag")
			assert_eq((ammo as DeployablePrefab).owner_slot, -1, "pre-planned bags belong to no one")
		assert_eq(_rt.find_by_tag(&"asset.ammo_bag_drop").size(), 1, "findable by objective tag asset.<id>")
		assert_true(NetIds.of(ammo) != 0, "has a net id")
	var crate: Node3D = _rt.preplan.drops.get(&"pp_dumpsters") as Node3D
	assert_true(crate != null and crate.has_meta(&"from_factory"), "registered drop factory used")
	if crate != null:
		assert_true(crate.global_position.distance_to(Vector3(-4, 0, 4)) < 0.01, "at pp_dumpsters")
	assert_false(_rt.preplan.drops.has(&"pp_missing"), "a drop on an unknown point is skipped")


func test_c3_escape_tag_selects_escape_zone() -> void:
	await _launch({"preplan": _result({"escape_tag": &"escape_back"})})
	var front: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(0, 0, -12),
		func(p: GameplayPrefab) -> void: p.objective_tag = &"escape_front") as EscapeZone
	var back: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(0, 0, 12),
		func(p: GameplayPrefab) -> void: p.objective_tag = &"escape_back") as EscapeZone
	await wait_physics_frames(1)
	_rt.mission.activate_escape()
	assert_true(back.active, "chosen escape is activated")
	assert_false(front.active, "the other escape stays closed")


func test_c3_force_variants_pin_and_reveals() -> void:
	for s: int in [1, 2, 3, 4, 5]:
		await _launch({"preplan": _result({"force_variants": {&"keycard": [&"k3"]}, "reveals": [&"keycard"]})}, s)
		assert_eq(_rt.variants.get(&"keycard"), [&"k3"] as Array[StringName], "seed %d: forced k3" % s)
		assert_eq(_rt.preplan.revealed_variants(_rt.variants), {&"keycard": _rt.variants[&"keycard"]}, "revealed")
		assert_eq(_rt.preplan.reveals(), [&"keycard"] as Array[StringName])
		await _reset()


func test_c3_normalize_accepts_env_b_handoff_keys() -> void:
	var b_shape: Dictionary = {
		"version": 1, "heist_id": &"unit_preplan",
		"modifier_sources": {&"asset.spare_body_bags": {&"stealth.body_bags_extra": 1}},
		"spawns": [{"asset": &"asset.doctor_bag_drop", "item": &"deployable.doctor_bag", "point": &"pp_alley"}],
		"reveal_variant_groups": [&"camera"],
		"force_variants": [{"asset": &"asset.escape_position", "group": &"escape", "slot": &"van_back"}],
		"player_spawn_tag": &"preplan_spawn_alley", "cash_spent": {0: 1600}, "plan": {"selections": []},
	}
	var r: Dictionary = PreplanAssets.normalize(b_shape)
	assert_eq(r["drops"], [{"asset": &"asset.doctor_bag_drop", "kind": &"deployable.doctor_bag", "point": &"pp_alley", "params": {}}])
	assert_eq(r["reveals"], [&"camera"] as Array[StringName])
	assert_eq(r["force_variants"], {&"escape": [&"van_back"]})
	assert_eq(r["spawn_tag"], &"preplan_spawn_alley")
	assert_eq(r["escape_tag"], &"")
	assert_eq(r["cash_spent"], {0: 1600})
	assert_eq((r["modifier_sources"] as Dictionary).keys(), [&"asset.spare_body_bags"])


func test_c3_dev_ids_resolve_through_env_b() -> void:
	await _launch({"preplanning": [&"asset.extra_cable_ties", &"asset.intel_keycards"]})
	assert_true(_rt.preplan.is_active(), "ids resolved into a PreplanResult")
	var grants: Dictionary = PreplanBoard.generic_assets()[&"asset.extra_cable_ties"].grants
	assert_eq((_rt.preplan.result["modifier_sources"] as Dictionary).get(&"asset.extra_cable_ties"), grants,
		"grants come from ENV B's asset library")
	assert_near(Modifiers.add(0, TIES), float(grants[TIES]), 0.001, "applied as a TEAM source")
	assert_eq(_rt.preplan.reveals(), [&"keycard"] as Array[StringName], "intel asset reveals its group")
	assert_true(_rt.preplan.has_asset(&"asset.intel_keycards"), "plan selections recorded")


func test_c3_preplan_option_wins_over_dev_ids() -> void:
	await _launch({"preplan": _result({"reveals": [&"guard_post"]}), "preplanning": [&"asset.intel_keycards"]})
	assert_eq(_rt.preplan.reveals(), [&"guard_post"] as Array[StringName])


func test_c3_unknown_dev_id_ignored() -> void:
	await _launch({"preplanning": [&"asset.not_in_catalog"]})
	assert_true(_rt != null, "launch still succeeds")
	assert_false(_rt.preplan.is_active(), "unknown id ignored")


## D-068: a `loot.<id>` drop kind spawns a loot bag of that id at the point (asset.thermite_drop -> loot.thermite).
func test_d068_loot_drop_kind_spawns_a_bag() -> void:
	await _launch({"preplan": _result({"drops": [
		{"asset": &"asset.thermite_drop", "kind": &"loot.jewelry", "point": &"pp_alley", "params": {}},
	]})})
	var bag: LootBag = _rt.preplan.drops.get(&"pp_alley") as LootBag
	assert_true(bag != null, "a LootBag at pp_alley")
	if bag != null:
		assert_eq(bag.loot_id, &"loot.jewelry", "of the drop's loot id")
		assert_true(bag.global_position.distance_to(Vector3(4, 0, 4)) < 0.6, "at the marker")
		assert_true(NetIds.of(bag) != 0, "replicated (net id)")
