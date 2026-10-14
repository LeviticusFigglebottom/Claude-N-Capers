## PO-5 (S7.1, D-086 playability): the all-round shout (shout_all_within_m) reaches civilians that can
## hear it: same floor (shout_floor_dy_m) and clear line of sight or a short navmesh walk
## (shout_all_within_m x shout_path_mult). A wall or a floor in between blocks it; the open crowd still drops.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _civ_at(pos: Vector3) -> NpcBase:
	return _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), {"idle_activity": &"sit"})


func _aim(yaw: float) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = yaw
	_rt.set_bot_intent(0, i)


func test_po5_shout_blocked_by_wall_and_floor_open_crowd_drops() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 517, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	# Crew on a mezzanine slab (top at y 4) at (0, 4, 0), aiming -Z (yaw 0).
	ATestMaps.add_wall(_rt.map, Vector3(0, 3.9, 0), Vector3(6, 0.2, 6))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 4.05, 0)))
	_aim(0.0)
	var below: NpcBase = _civ_at(Vector3(1.0, 0.05, 1.0))  # floor below, 1.4 m flat
	var open_civ: NpcBase = _civ_at(Vector3(-1.5, 4.05, 2.0))  # same slab, behind the crew (outside the cone)
	await wait_physics_frames(3)
	var shout: ShoutSystem = ShoutSystem.ensure(_rt)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.set_masked()  # PO-11 (S1.1): only a masked shout reaches civilians
	var got: Array[NpcBase] = shout.targets_for(crew)
	assert_false(got.has(below), "a civilian on the floor below within 6 m is not reached")
	assert_has(got, open_civ, "a civilian next to the crew in the open is reached (no cone needed)")


func test_po5_shout_blocked_by_wall_same_floor() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 518, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_aim(0.0)
	ATestMaps.add_wall(_rt.map, Vector3(0, 1.5, 2.0), Vector3(8, 3, 0.3))
	var behind_wall: NpcBase = _civ_at(Vector3(0.5, 0.05, 4.0))  # 4 m behind the crew, wall in between
	var beside: NpcBase = _civ_at(Vector3(3.0, 0.05, 0.5))  # 3 m to the side, in the open
	var crowd: Array[NpcBase] = [beside, _civ_at(Vector3(-2.5, 0.05, -1.0)), _civ_at(Vector3(1.0, 0.05, -3.0))]
	await wait_physics_frames(3)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.set_masked()  # PO-11 (S1.1): only a masked shout reaches civilians
	var got: Array[NpcBase] = ShoutSystem.ensure(_rt).targets_for(crew)
	assert_false(got.has(behind_wall), "a civilian behind a wall within 6 m is not reached")
	for c: NpcBase in crowd:
		assert_has(got, c, "the open crowd around the crew is reached")
	# Through the real shout: the crowd goes down, the one behind the wall does not.
	var i: CrewIntent = CrewIntent.new()
	i.shout = true
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	_aim(0.0)
	await wait_physics_frames(2)
	for c: NpcBase in crowd:
		assert_eq((c.get_node(^"Brain") as CivilianBrain).mode, CivilianBrain.Mode.DOWN, "crowd intimidated")
	assert_ne((behind_wall.get_node(^"Brain") as CivilianBrain).mode, CivilianBrain.Mode.DOWN, "walled-off civilian unaffected")


func test_po5_glasshouse_shout_does_not_cross_corridor_wall() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched glasshouse")
	await wait_physics_frames(5)
	await ATestMaps.await_nav_synced(_rt)
	# Crew on the sales floor at (9, 0, 7.2), aiming south (away); a civilian in the G4 staff corridor
	# 2 m away through the corridor wall (z 6; doors at x 1-2 and 16-17), and one on the sales floor.
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(9.0, 0.05, 7.2)))
	_aim(PI)
	var corridor: NpcBase = _civ_at(Vector3(9.0, 0.05, 5.25))
	var floor_civ: NpcBase = _civ_at(Vector3(7.0, 0.05, 8.0))
	var upstairs: NpcBase = _civ_at(Vector3(9.0, 4.25, 7.6))
	await wait_physics_frames(3)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.set_masked()  # PO-11 (S1.1): only a masked shout reaches civilians
	var got: Array[NpcBase] = ShoutSystem.ensure(_rt).targets_for(crew)
	assert_false(got.has(corridor), "no shout through the corridor wall")
	assert_false(got.has(upstairs), "no shout through the ceiling")
	assert_has(got, floor_civ, "the civilian on the sales floor is reached")
