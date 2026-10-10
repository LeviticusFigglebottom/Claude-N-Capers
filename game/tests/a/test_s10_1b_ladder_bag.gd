## A3-10 (QC-17, D-042; fidelity S10.1b): crew cannot climb a ladder while carrying a bag.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_ladder_bag", 1313, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _hold(interact: bool, yaw: float) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.interact = interact
	i.look_yaw = yaw
	_rt.set_bot_intent(0, i)


func test_no_climb_with_bag_then_climb_after_dropping() -> void:
	var l: Ladder = ATestMaps.add_prefab(_rt, "ladder", Vector3(0, 0, -6)) as Ladder
	ATestMaps.add_wall(_rt.map, Vector3(0, 1.5, -4.9), Vector3(3, 3, 2))
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, c.global_position))
	assert_true(loot.carry(bag, c), "carrying")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, l.bottom_position() + Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	_hold(true, PI)
	await wait_physics_frames(10)
	assert_false(l.is_climbing(0), "S10.1b: no ladder with a bag (interact)")
	assert_false(l.start_climb(c, true), "start_climb refused with a bag")
	assert_true(c.is_carrying_bag(), "still carrying")
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)
	loot.drop_bag(c, false)
	assert_false(c.is_carrying_bag())
	_hold(true, PI)
	var ok: bool = await wait_until(func() -> bool: return l.is_climbing(0), 1.0)
	assert_true(ok, "without the bag the same crew climbs")
	_rt.clear_bot_intent(0)
