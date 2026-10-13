## D-085: AI followers keep a margin from nav path corners: a follower passes a 0.9 m doorway at an angle
## without stalling (with_doorway_wall: 0.9 m gap at x = 0 in a wall along z = 0).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_d085_offset_corners_pushes_away_from_inner_side() -> void:
	var p: PackedVector3Array = PackedVector3Array([Vector3(-2, 0, 2), Vector3(0, 0, 0), Vector3(2, 0, 2)])
	var o: PackedVector3Array = CrewAiBrain.offset_corners(p, 0.1)
	assert_eq(o[0], p[0], "start kept")
	assert_eq(o[2], p[2], "end kept")
	assert_near(o[1].z, -0.1, 0.001, "corner pushed away from the inside of the turn")
	assert_near(o[1].x, 0.0, 0.001)


func test_d085_follower_passes_09m_door_at_angle() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 85, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0), "crew_ai": true, "skip_casing": true})
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "nav synced")
	for s: int in [2, 3]:
		_rt.teleport_crew(s, Transform3D(Basis.IDENTITY, Vector3(-6.0 - s, 0.05, 9.0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(-5.0, 0.05, -4.0)))  # follower, off-axis
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(5.0, 0.05, 6.0)))  # leader, other side, at an angle
	_rt.set_bot_intent(0, CrewIntent.new())
	_rt.stealth.raise_alarm(&"scripted")  # loud: the AI follows
	var ai: CrewController = _rt.crew_controller(1) as CrewController
	var last: Vector3 = ai.global_position
	var still: float = 0.0
	var t: float = 0.0
	var passed: bool = false
	while t < 12.0 and not passed:
		await wait_seconds(0.25)
		t += 0.25
		var moved: float = Vector2(ai.global_position.x - last.x, ai.global_position.z - last.z).length()
		still = still + 0.25 if moved < 0.05 else 0.0
		last = ai.global_position
		passed = ai.global_position.z > 1.0
		assert_true(still < 1.5 or passed, "follower stalled at (%.2f, %.2f)" % [last.x, last.z])
		if still >= 1.5:
			break
	assert_true(passed, "follower crossed the 0.9 m doorway (z=%.2f)" % ai.global_position.z)
