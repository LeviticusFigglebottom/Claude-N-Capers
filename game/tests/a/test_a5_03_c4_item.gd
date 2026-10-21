## A5-03 (QC-84): C4 as an item. An item_pickup box grants `count` x `item.c4` and frees itself; four charges blow an
## armored_truck (charges_required 4); a pre-planning drop of kind `item.c4` (params.count) is such a box.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(extra: Dictionary = {}) -> void:
	var o: Dictionary = {"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false, "ai_teammates": 0}
	o.merge(extra, true)
	_rt = await HeistLauncher.launch(&"unit_c4", 503, Enums.Difficulty.ROUTINE, self, o)
	await wait_physics_frames(2)


func _use(c: CrewController, p: GameplayPrefab, seconds: float) -> void:
	_rt.teleport_crew(c.slot, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, c.slot, p.net_id)
	await wait_seconds(seconds + 0.2)
	_rt.clear_bot_intent(c.slot)
	await wait_physics_frames(2)


func test_magazine_box_gives_four_charges_that_open_a_truck() -> void:
	await _launch()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var box: ItemPickup = ATestMaps.add_prefab(_rt, "item_pickup", Vector3(3, 0, -4), func(n: Node) -> void:
		(n as ItemPickup).count = 4) as ItemPickup
	var truck: ArmoredTruck = ATestMaps.add_prefab(_rt, "armored_truck", Vector3(-4, 0, -14)) as ArmoredTruck
	await wait_physics_frames(2)
	assert_eq(truck.method_for(c), &"saw", "no C4: the saw")
	var picked: Array = []
	var cb: Callable = func(item: StringName, slot: int) -> void: picked.append([item, slot])
	EventBus.item_picked_up.connect(cb)
	await _use(c, box, Tweak.interaction().item_pickup_s)
	EventBus.item_picked_up.disconnect(cb)
	assert_eq(c.item_count(Safe.C4_ITEM), 4, "four charges from the box")
	assert_has(picked, [Safe.C4_ITEM, c.slot], "item_picked_up(item.c4)")
	assert_false(is_instance_valid(box) and box.is_inside_tree(), "the box is gone")
	assert_eq(truck.method_for(c), &"c4", "carrying 4 charges: the truck offers C4 before the saw")
	await _use(c, truck, Tweak.interaction().c4_place_s)
	assert_eq(truck.stage, Safe.Stage.C4_ARMED, "four charges placed")
	assert_eq(c.item_count(Safe.C4_ITEM), 0, "all four spent")
	var ok: bool = await wait_until(func() -> bool: return truck.opened, Tweak.interaction().c4_fuse_s + 2.0)
	assert_true(ok, "the rear doors blew open")
	assert_eq(truck.beaten_by, &"c4")


func test_preplan_item_drop_is_a_c4_box() -> void:
	var map: PackedScene = ATestMaps.with_preplan_markers(HeistDef.new(), [] as Array[StringName],
		{"pp_drop_carpark": Vector3(4, 0, 4)}, {}, HeistVariantTable.new())
	await _launch({"map_packed": map, "preplan": {"version": 1, "modifier_sources": {}, "spawn_tag": &"",
		"escape_tag": &"", "force_variants": {}, "reveals": [], "cash_spent": {}, "plan": {}, "drops": [
			{"asset": &"asset.c4_drop", "kind": &"item.c4", "point": &"pp_drop_carpark", "params": {"count": 3}}]}})
	var drop: ItemPickup = _rt.preplan.drops.get(&"pp_drop_carpark") as ItemPickup
	assert_true(drop != null, "an item_pickup at the drop point")
	assert_eq(drop.item_id, &"item.c4")
	assert_eq(drop.count, 3, "params.count")
	assert_true(drop.global_position.distance_to(Vector3(4, 0, 4)) < 0.01, "at the marker")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	await _use(c, drop, Tweak.interaction().item_pickup_s)
	assert_eq(c.item_count(&"item.c4"), 3, "the taker gets the charges")
