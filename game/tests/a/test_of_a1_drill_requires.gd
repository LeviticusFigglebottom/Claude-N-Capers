## OF-A1 (QC-60, D-136 §3b.9): drill_point.requires_loot / requires_count (the thermal drill delivered as tool bags,
## consumed like burn_point's thermite) and HeistMission.spawn_loot(loot_id, tag, count, respawn) (markers cycled;
## a destroyed or off-map part comes back at its marker, a consumed one does not).
extends TestCase

const PART: StringName = &"loot.test_drill_part"

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	ContentDB.clear_cache()
	LootManager._loot_cache.clear()
	await wait_frames(1)


func _launch(run_seed: int) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", run_seed, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	var tool: LootDef = LootDef.new()
	tool.id = PART
	tool.is_tool = true
	tool.weight = Enums.LootWeight.HEAVY
	ContentDB.inject(ContentDB.LOOT, tool.id, tool)
	LootManager._loot_cache.clear()  # loot_info caches ContentDB on first use
	await wait_physics_frames(2)


func _parts(loot: LootManager) -> Array[LootBag]:
	var out: Array[LootBag] = []
	for b: LootBag in loot.bags():
		if b.loot_id == PART and b.is_inside_tree():
			out.append(b)
	return out


func test_drill_needs_its_parts_delivered() -> void:
	await _launch(6001)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 0, -4), func(p: GameplayPrefab) -> void:
		(p as DrillPoint).device = DrillPoint.Device.THERMAL
		(p as DrillPoint).requires_loot = PART
		(p as DrillPoint).requires_count = 2) as DrillPoint
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -3.0)))
	await wait_physics_frames(2)
	assert_eq(dp.interactable.availability(c), InteractableComponent.BLOCK_ITEM, "no part: burn_point's BLOCK_ITEM hint")
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var carried: LootBag = loot.spawn_bag(PART, Transform3D(Basis.IDENTITY, c.global_position))
	await wait_physics_frames(1)
	assert_true(loot.carry(carried, c), "carrying a part")
	assert_eq(dp.interactable.availability(c), InteractableComponent.BLOCK_NONE, "part in hand: can deliver it")
	dp.interactable.completed.emit(c)
	assert_eq(dp.delivered, 1, "one part delivered")
	assert_false(c.is_carrying_bag(), "the carried part is consumed")
	assert_true(carried.has_meta(LootManager.META_CONSUMED), "marked consumed")
	assert_eq(dp.device_state(), DeviceRunner.State.IDLE, "1 of 2: the drill is not placed yet")
	assert_eq(dp.interactable.availability(c), InteractableComponent.BLOCK_ITEM, "the second part is still owed")
	assert_eq(NetEntityCodec.state_of(dp).get("delivered"), 1, "delivered replicates")
	var loose: LootBag = loot.spawn_bag(PART, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.3, -4)))
	await wait_physics_frames(3)
	assert_eq(dp.part_for(c), loose, "a part lying next to the spot is used too")
	dp.interactable.completed.emit(c)
	assert_eq(dp.delivered, 2, "both parts delivered")
	assert_eq(dp.device_state(), DeviceRunner.State.RUNNING, "the last part places and starts the thermal drill")
	await wait_frames(1)
	assert_false(is_instance_valid(loose), "the loose part is consumed")


func test_spawn_loot_cycles_markers_and_respawns_parts() -> void:
	await _launch(6002)
	var m0: Marker3D = Marker3D.new()
	m0.position = Vector3(4, 0.3, 4)
	m0.set_meta(&"objective_tag", &"drill_drop")
	var m1: Marker3D = Marker3D.new()
	m1.position = Vector3(-4, 0.3, 4)
	m1.set_meta(&"objective_tag", &"drill_drop")
	_rt.map.add_child(m0)
	_rt.map.add_child(m1)
	var mission: HeistMission = _rt.mission
	assert_eq(mission.loot_markers(&"drill_drop").size(), 2, "both markers found")
	assert_true(mission.spawn_loot(PART, &"nowhere", 1).is_empty(), "no marker: nothing")
	var bags: Array = mission.spawn_loot(PART, &"drill_drop", 3, true)
	assert_eq(bags.size(), 3, "three bags")
	var b0: LootBag = bags[0] as LootBag
	assert_near((bags[1] as LootBag).global_position.x, -4.0, 0.01, "second bag at the second marker")
	assert_near((bags[2] as LootBag).global_position.y, b0.global_position.y + 0.4, 0.01, "third cycles, stacked")
	assert_eq(b0.weight, Enums.LootWeight.HEAVY, "the LootDef's weight")
	assert_false(b0.moved, "S4.1: placed loot, no guard / camera reacts until first picked up (AH seed 2)")
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	# Consumed by a device: gone for good.
	LootManager.consume_bag(bags[2] as LootBag)
	await wait_frames(3)
	assert_eq(_parts(loot).size(), 2, "a consumed part is not respawned")
	# Destroyed: back at its marker.
	var lost: LootBag = bags[1] as LootBag
	lost.get_parent().remove_child(lost)
	lost.queue_free()
	await wait_frames(3)
	var now: Array[LootBag] = _parts(loot)
	assert_eq(now.size(), 2, "§3b.9: a destroyed part respawns")
	var back: bool = false
	for b: LootBag in now:
		back = back or b.global_position.distance_to(m1.global_position) < 0.5
	assert_true(back, "at its marker")
	# Off the map: put back at the marker.
	b0.global_position = Vector3(4, -60, 4)
	b0.freeze = true
	await wait_seconds(HeistMission.LOOT_WATCH_S + 0.3)
	assert_true(is_instance_valid(b0) and b0.global_position.y > -2.0, "a part that fell off the map is back (y %.1f)"
		% b0.global_position.y)
