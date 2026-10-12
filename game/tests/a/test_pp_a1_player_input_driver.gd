## PP-A-1: PlayerInputDriver drives the crew through Input.parse_input_event only (no bot intents, no
## teleports): movement, mask, shout, release_all; mouse look where PlayerInput can receive it.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PlayerInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PlayerInputDriver.new(self)
	await wait_physics_frames(2)


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func test_pp_a1_crew_is_player_driven() -> void:
	var c: CrewController = _crew()
	assert_false(c.is_ai, "slot 0 is the local player")
	assert_true(c.get_node_or_null(^"PlayerInput") != null, "PlayerInput reads the input")


func test_pp_a1_walk_forward_by_input() -> void:
	var c: CrewController = _crew()
	var start: Vector3 = c.global_position
	var fwd: Vector3 = -c.global_transform.basis.z
	var moved: bool = await _inp.walk_until(&"move_forward",
		func() -> bool: return (c.global_position - start).dot(fwd) > 2.0, 3.0)
	assert_true(moved, "held move_forward walks the crew forward (%.2f m)" % (c.global_position - start).dot(fwd))
	assert_false(_inp.is_held(&"move_forward"), "released after walk_until")
	var stop: Vector3 = c.global_position
	await wait_seconds(0.5)
	assert_true(c.global_position.distance_to(stop) < 0.3, "stops when the key is released")


func test_pp_a1_mask_and_shout_by_input() -> void:
	var c: CrewController = _crew()
	assert_false(c.masked, "spawns unmasked (casing)")
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	assert_true(await wait_until(func() -> bool: return c.masked, 1.0), "holding mask_up masks")
	var shouts: Array[int] = []
	var cb: Callable = func(slot: int, _affected: Array) -> void: shouts.append(slot)
	ShoutSystem.ensure(_rt).shouted.connect(cb)
	await _inp.tap(&"shout")
	await wait_physics_frames(2)
	ShoutSystem.ensure(_rt).shouted.disconnect(cb)
	assert_eq(shouts, [0] as Array[int], "a shout tap shouts once")


func test_pp_a1_release_all_clears_input() -> void:
	_inp.press(&"move_forward")
	_inp.key(KEY_SHIFT, true)
	assert_true(Input.is_action_pressed(&"move_forward"))
	_inp.release_all()
	assert_false(Input.is_action_pressed(&"move_forward"), "action released")
	assert_false(Input.is_physical_key_pressed(KEY_SHIFT), "key released")


func test_pp_a1_mouse_look_aims() -> void:
	var c: CrewController = _crew()
	_inp.capture_mouse()
	if not _inp.can_mouse_look():
		skip("PlayerInput cannot read mouse motion headless: needs P's PlayerInput.test_assume_captured (env/p-play)")
		return
	var target: Vector3 = c.eye_position() + Vector3(4.0, -1.0, -3.0)
	assert_true(await _inp.aim_at(c, target), "mouse-look reaches the target")
	assert_true(c.aim_direction().angle_to(target - c.eye_position()) < 0.05, "aim points at the target")
