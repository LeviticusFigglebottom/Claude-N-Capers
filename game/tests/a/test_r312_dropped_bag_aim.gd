## LEAD r312 (harness "aimed <none>" on loose bags with LOS clear, angle 0): a player looking at a just-dropped bag gets
## its prompt on every frame after the drop, settling or not. The harness misses were a stale aim point (po5_pilot
## captured the bag's position before the walk; a loose bag moves meanwhile), not the interaction filter.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _aim(c: CrewController, p: Vector3) -> void:
	var to: Vector3 = p - c.eye_position()
	c.look_yaw = atan2(-to.x, -to.z)
	c.look_pitch = atan2(to.y, Vector2(to.x, to.z).length())


func test_r312_a_dropped_bag_is_aimable_every_frame_while_it_settles() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 312, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(3)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	for weight_id: StringName in [&"loot.cash_bricks", &"loot.parcels"]:
		_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
		var bag: LootBag = lm.spawn_bag(weight_id, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, -1.2)))
		await wait_physics_frames(20)
		assert_true(lm.carry(bag, c), "%s picked up" % weight_id)
		await wait_physics_frames(5)
		lm.drop_bag(c, false)
		var misses: Array[int] = []
		for f: int in 60:
			await get_tree().physics_frame
			_aim(c, bag.interactable.global_position)  # where the bag is now, like a player's crosshair on it
			if _rt.interaction.aimed_component(c) != bag.interactable:
				misses.append(f)
		assert_eq(misses, [] as Array[int], "%s: aimed on every frame after the drop (missed %s, last why '%s')" % [
			weight_id, misses, _rt.interaction.explain_miss(c, bag.interactable)])
		assert_true(lm.carry(bag, c), "and picked up again")
		await wait_physics_frames(2)
		bag.queue_free()
		await wait_physics_frames(2)


func test_r312_explain_miss_names_the_failing_filter() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 313, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(3)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var bag: LootBag = lm.spawn_bag(&"loot.cash_bricks", Transform3D(Basis.IDENTITY, Vector3(0, 0.3, -1.2)))
	await wait_physics_frames(20)
	_aim(c, bag.interactable.global_position)
	assert_eq(_rt.interaction.explain_miss(c, bag.interactable), "", "aimed at: no reason")
	_aim(c, bag.interactable.global_position + Vector3(2, 0, 0))
	assert_eq(_rt.interaction.explain_miss(c, bag.interactable), "outside the cone", "looking 2 m to the side")
	bag.interactable.enabled = false
	assert_eq(_rt.interaction.explain_miss(c, bag.interactable), "disabled")
