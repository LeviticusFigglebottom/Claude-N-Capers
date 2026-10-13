## PO-5.3 (D-086): AI teammates' leash is "close and in sight": a bot behind a wall walks to the leader,
## and cover must see the leader (no cover in the alley behind the room the human is in).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 7, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _place(slot: int, pos: Vector3) -> void:
	_rt.teleport_crew(slot, Transform3D(Basis.IDENTITY, pos))


func test_po5_bot_behind_wall_follows_leader() -> void:
	var b: CrewAiBrain = CrewAiBrain.of(_rt.crew_controller(1))
	_place(0, Vector3(0, 0, 0))
	_place(1, Vector3(0, 0, 3))
	await wait_physics_frames(2)
	assert_eq(b.call(&"_follow_goal"), Vector3.INF, "3 m away and in sight: stays put")
	ATestMaps.add_wall(_rt, Vector3(0, 1.5, 1.5), Vector3(6, 3, 0.3))
	await wait_physics_frames(2)
	var goal: Vector3 = b.call(&"_follow_goal")
	assert_true(goal != Vector3.INF, "3 m away behind a wall: walks to the leader")
	assert_true(goal.distance_to(_rt.crew_controller(0).global_position) < 0.5, "goal is the leader")


func test_po5_cover_must_see_leader() -> void:
	var b: CrewAiBrain = CrewAiBrain.of(_rt.crew_controller(1))
	_place(0, Vector3(0, 0, 0))
	_place(1, Vector3(4, 0, 0))
	var front: Node3D = Node3D.new()
	var behind: Node3D = Node3D.new()
	for p: Node3D in [front, behind]:
		p.add_to_group(G.COVER_POINT)
		_rt.add_child(p)
	front.global_position = Vector3(0, 0, -3)
	behind.global_position = Vector3(0, 0, 3)
	ATestMaps.add_wall(_rt, Vector3(0, 1.5, 1.5), Vector3(6, 3, 0.3))
	await wait_physics_frames(2)
	var leader: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(b.call(&"_cover_ok", front, leader), "cover in sight of the leader is fine")
	assert_false(b.call(&"_cover_ok", behind, leader), "cover behind a wall from the leader is refused")
