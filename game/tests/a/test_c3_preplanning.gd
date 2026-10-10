## A2-07 C3: pre-planning asset hooks (PreplanAssets, game/systems/heist/README.md): modifier assets
## (TEAM source `asset.<id>`, cleared at teardown), spawn-location choice, drops at PREPLAN_POINTs,
## escape choice and variant-pinning (insider) assets.
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
	def.preplanning = {
		&"asset.zip_ties": {"cost": 1000, "favors": 1, "type": &"modifier", "grants": {TIES: 2}},
		&"asset.spawn_alley": {"cost": 0, "favors": 1, "type": &"spawn", "spawn_tag": &"preplan_spawn_alley"},
		&"asset.ammo_drop": {"cost": 2000, "favors": 2, "type": &"drop", "slot": &"alley_drop", "drop": &"ammo_bag"},
		&"asset.bag_case": {"cost": 2000, "favors": 2, "type": &"drop", "slot": &"dumpsters", "drop": &"body_bag_case"},
		&"asset.van_back": {"cost": 500, "favors": 1, "type": &"escape", "escape_tag": &"escape_back"},
		&"asset.inside_man": {"cost": 3000, "favors": 2, "type": &"insider",
			"force_variants": {&"keycard": [&"k3"]}, "reveals": [&"keycard"]},
	}
	return def


func _table() -> HeistVariantTable:
	var t: HeistVariantTable = HeistVariantTable.new()
	t.rules = [{"group": &"keycard", "pick": Vector2i(1, 1)}]
	return t


func _launch(preplanning: Variant, seed_value: int = 11) -> HeistRuntime:
	var map: PackedScene = ATestMaps.with_heist_def(_def(), 0, 0, [&"preplan_spawn_alley"] as Array[StringName],
		{"alley_drop": Vector3(4, 0, 4), "meta:dumpsters": Vector3(-4, 0, 4)},
		{&"keycard": [&"k1", &"k2", &"k3"]}, _table())
	_rt = await HeistLauncher.launch(&"unit_preplan", seed_value, Enums.Difficulty.ROUTINE, self,
		{"map_packed": map, "ai_teammates": 1, "skip_casing": true, "preplanning": preplanning})
	return _rt


func test_c3_modifier_asset_applies_and_clears_at_teardown() -> void:
	var base: int = int(await _base_ties())
	await _launch([&"asset.zip_ties"])
	assert_near(Modifiers.add(0, TIES), 2.0, 0.001, "TEAM source applies to slot 0")
	assert_near(Modifiers.add(1, TIES), 2.0, 0.001, "and to slot 1")
	assert_eq((_rt.crew_controller(0) as CrewController).cable_ties, base + 2, "applied before the crew reads modifiers")
	assert_true(_rt.preplan.has_asset(&"asset.zip_ties"))
	_rt.teardown()
	_rt = null
	assert_near(Modifiers.add(0, TIES), 0.0, 0.001, "cleared at teardown")


func _base_ties() -> int:
	await _launch([])
	var n: int = (_rt.crew_controller(0) as CrewController).cable_ties
	_rt.teardown()
	_rt = null
	await wait_frames(1)
	return n


func test_c3_spawn_asset_uses_preplan_spawns() -> void:
	await _launch([])
	for c: CrewController in _rt.crew_members():
		assert_true(c.global_position.x < 0.0, "default spawns (x < 0) without the asset, got %s" % c.global_position)
	_rt.teardown()
	_rt = null
	await wait_frames(1)
	await _launch({&"asset.spawn_alley": true})
	for c: CrewController in _rt.crew_members():
		assert_true(c.global_position.x > 9.0, "preplan_spawn_alley spawns (x >= 10), got %s" % c.global_position)


func test_c3_drop_assets_spawn_at_their_points() -> void:
	PreplanAssets.register_drop(&"unit_crate", func(_id: StringName, _d: Dictionary) -> Node3D:
		var n: PreplanDrop = PreplanDrop.new()
		n.set_meta(&"from_factory", true)
		return n)
	await _launch({&"asset.ammo_drop": true, &"asset.bag_case": {"drop": &"unit_crate"}})
	var ammo: Array[Node] = _rt.find_by_tag(&"asset.ammo_drop")
	assert_eq(ammo.size(), 1, "ammo drop findable by objective tag")
	if ammo.size() == 1:
		var d: PreplanDrop = ammo[0] as PreplanDrop
		assert_true(d != null, "fallback PreplanDrop while no ammo_bag prefab exists")
		if d != null:
			assert_eq(d.kind, &"ammo_bag")
			assert_eq(d.asset_id, &"asset.ammo_drop")
			assert_true(d.global_position.distance_to(Vector3(4, 0, 4)) < 0.01, "at the named PREPLAN_POINT")
			assert_true(d.is_in_group(PreplanAssets.DROP_GROUP))
			assert_true(NetIds.of(d) != 0, "has a net id")
	var bag: Node3D = _rt.preplan.drops.get(&"asset.bag_case") as Node3D
	assert_true(bag != null, "bag case dropped")
	if bag != null:
		assert_true(bag.has_meta(&"from_factory"), "registered drop factory used (launch override of `drop`)")
		assert_true(bag.global_position.distance_to(Vector3(-4, 0, 4)) < 0.01, "point matched by asset_slot metadata")


func test_c3_escape_asset_selects_escape_zone() -> void:
	await _launch([&"asset.van_back"])
	var front: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(0, 0, -12),
		func(p: GameplayPrefab) -> void: p.objective_tag = &"escape_front") as EscapeZone
	var back: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(0, 0, 12),
		func(p: GameplayPrefab) -> void: p.objective_tag = &"escape_back") as EscapeZone
	await wait_physics_frames(1)
	_rt.mission.activate_escape()
	assert_true(back.active, "chosen escape is activated")
	assert_false(front.active, "the other escape stays closed")


func test_c3_insider_asset_pins_and_reveals_variant() -> void:
	for s: int in [1, 2, 3, 4, 5]:
		await _launch([&"asset.inside_man"], s)
		assert_eq(_rt.variants.get(&"keycard"), [&"k3"] as Array[StringName], "seed %d: forced k3" % s)
		assert_eq(_rt.preplan.revealed_variants(_rt.variants), {&"keycard": _rt.variants[&"keycard"]}, "revealed")
		_rt.teardown()
		_rt = null
		await wait_frames(1)


func test_c3_unknown_asset_ignored() -> void:
	await _launch([&"asset.not_in_catalog"])
	assert_true(_rt != null, "launch still succeeds")
	assert_true(_rt.preplan.chosen.is_empty(), "unknown id ignored")
