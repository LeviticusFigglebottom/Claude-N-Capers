## A1-02: CrewController + CrewIntent (crew_intent.md), casing limits (S1.1), mask-up (S1.2),
## no movement noise (S1.5).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _place(c: CrewController, pos: Vector3) -> void:
	_rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(2)


func test_walk_moves_forward_along_yaw() -> void:
	var c: CrewController = _crew()
	await _place(c, Vector3(0, 0.05, 0))
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.look_yaw = 0.0
	_rt.set_bot_intent(0, i)
	await wait_seconds(1.0)
	_rt.clear_bot_intent(0)
	assert_true(c.global_position.z < -2.0, "moved along -Z (got %s)" % c.global_position)
	assert_near(c.global_position.x, 0.0, 0.2, "no drift")


func test_s1_1_casing_blocks_sprint_crouch_jump() -> void:
	var c: CrewController = _crew()
	await _place(c, Vector3(0, 0.05, 0))
	assert_true(c.is_casing(), "starts unmasked")
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.sprint = true
	i.crouch = true
	i.jump = true
	_rt.set_bot_intent(0, i)
	var max_y: float = 0.0
	for k: int in range(30):
		await wait_physics_frames(1)
		max_y = maxf(max_y, c.global_position.y)
		assert_false(c.sprinting, "no sprint while casing")
		assert_false(c.crouched, "no crouch while casing")
	_rt.clear_bot_intent(0)
	assert_true(max_y < 0.2, "no jump while casing (max y %f)" % max_y)
	var speed: float = Vector2(c.velocity.x, c.velocity.z).length()
	assert_true(speed <= Tweak.crew().walk_speed + 0.01, "walk speed cap while casing")


func test_s1_2_mask_up_hold_is_irreversible() -> void:
	var c: CrewController = _crew()
	var masked_events: Array[int] = []
	var cb: Callable = func(s: int) -> void: masked_events.append(s)
	EventBus.crew_masked.connect(cb)
	var i: CrewIntent = CrewIntent.new()
	i.mask_up = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(Tweak.crew().mask_up_time_s * 0.5)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)
	assert_false(c.masked, "released early: not masked")
	assert_near(c.mask_progress, 0.0, 0.001, "progress resets on release")
	_rt.set_bot_intent(0, i)
	await wait_seconds(Tweak.crew().mask_up_time_s + 0.2)
	assert_true(c.masked, "masked after full hold")
	assert_eq(masked_events, [0] as Array[int], "crew_masked once")
	assert_eq(_rt.phase, Enums.HeistPhase.STEALTH, "first mask: CASING -> STEALTH")
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(3)
	assert_true(c.masked, "irreversible")
	EventBus.crew_masked.disconnect(cb)


func test_s1_4_masked_can_sprint_crouch_jump() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	await _place(c, Vector3(0, 0.05, 0))
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.sprint = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(0.6)
	assert_true(c.sprinting, "sprinting when masked")
	assert_true(Vector2(c.velocity.x, c.velocity.z).length() > Tweak.crew().walk_speed + 0.5, "sprint faster than walk")
	var j: CrewIntent = CrewIntent.new()
	j.jump = true
	_rt.set_bot_intent(0, j)
	var max_y: float = 0.0
	for k: int in range(30):
		await wait_physics_frames(1)
		max_y = maxf(max_y, c.global_position.y)
	assert_true(max_y > 0.5, "jumped (max y %f)" % max_y)
	var cr: CrewIntent = CrewIntent.new()
	cr.crouch = true
	_rt.set_bot_intent(0, cr)
	await wait_physics_frames(3)
	assert_true(c.crouched, "crouched")
	assert_near(c.eye_height(), Tweak.crew().eye_crouched, 0.001)


func test_s1_5_movement_makes_no_noise() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var noises: Array[float] = []
	var cb: Callable = func(_p: Vector3, r: float, _k: StringName, _s: int) -> void: noises.append(r)
	_rt.noise_made.connect(cb)
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(1, 1)
	i.sprint = true
	i.jump = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(1.5)
	_rt.noise_made.disconnect(cb)
	assert_eq(noises.size(), 0, "S1.5: sprinting/jumping emits no NoiseEvent")


func test_eye_height_and_aim_direction() -> void:
	var c: CrewController = _crew()
	await _place(c, Vector3(1, 0, 2))
	assert_near(c.eye_position().y - c.global_position.y, 1.65, 0.001, "heist_map §7 eye height")
	var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), c.eye_position() + Vector3(1, 0, 0))
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	assert_true(c.aim_direction().distance_to(Vector3(1, 0, 0)) < 0.01, "aim follows BotUtil yaw convention")


func test_teleport_sets_facing() -> void:
	var c: CrewController = _crew()
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(3, 0, 3))
	_rt.teleport_crew(0, xf)
	assert_true(c.global_position.distance_to(Vector3(3, 0, 3)) < 0.01)
	assert_true(c.aim_direction().distance_to(-xf.basis.z) < 0.01, "faces -Z of the transform")


func test_inventory_from_modifiers() -> void:
	_rt.teardown()
	Modifiers.set_source(0, &"skills", {&"stealth.body_bags_extra": 1, &"stealth.cable_ties_extra": 2})
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	var c: CrewController = _crew()
	assert_eq(c.body_bags, Tweak.crew().body_bags_base + 1, "S6.2 stealth.body_bags_extra")
	assert_eq(c.cable_ties, Tweak.crew().cable_ties_base + 2, "S7.2 stealth.cable_ties_extra")
	var c1: CrewController = _rt.crew_controller(1) as CrewController
	assert_eq(c1.body_bags, Tweak.crew().body_bags_base, "per-slot modifier")
