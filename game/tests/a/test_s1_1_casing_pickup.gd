## A4-01 / S1.1: small item/loot pickups are available while casing only with stealth.casing_can_pickup_items.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func test_s1_1_casing_pickup_needs_flag() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 11, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false})
	await wait_physics_frames(1)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_false(c.masked, "starts unmasked (casing)")
	var item: InteractableComponent = InteractableComponent.new()
	item.casing_pickup_item = true
	var other: InteractableComponent = InteractableComponent.new()
	_rt.add_child(item)
	_rt.add_child(other)
	assert_eq(item._crew_block(c), InteractableComponent.BLOCK_CASING, "no flag: blocked while casing")
	Modifiers.set_source(0, &"test", {&"stealth.casing_can_pickup_items": true})
	assert_eq(item._crew_block(c), InteractableComponent.BLOCK_NONE, "flag: small pickup allowed")
	assert_eq(other._crew_block(c), InteractableComponent.BLOCK_CASING, "other interactions stay blocked")
	item.queue_free()
	other.queue_free()
