## D-121: the server's gunshot noise starts at the shooter's eye (deterministic), not the animated muzzle.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_d121_gunshot_noise_at_eye() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 2121, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(int(ceil(c.weapons.stats(c.weapons.equipped_slot).equip_time_s * 60.0)) + 4)
	var noises: Array[Vector3] = []
	_rt.noise_made.connect(func(pos: Vector3, _r: float, kind: StringName, src: int) -> void:
		if kind == &"gunshot" and src == c.net_id:
			noises.append(pos))
	var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), Vector3(0, 1.4, -10))
	i.fire = true
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(3)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)
	assert_false(noises.is_empty(), "a gunshot noise was made")
	if not noises.is_empty():
		assert_true(noises[0].distance_to(c.eye_position()) < 0.05, "noise at the eye (%s vs %s)" % [noises[0], c.eye_position()])
