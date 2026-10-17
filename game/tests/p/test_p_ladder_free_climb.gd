## PO-16 / D-145: PD2 free ladder climbing by real input (Po5Pilot: mouse look, WASD, jump). A 3 m ladder on the unit
## map with a box ledge under its Top marker. Walking into the ladder attaches (no forced animation: the Ladder
## prefab's own climb never starts for a human), W climbs with the look pitched up, the player can look around while
## attached, climbing past the top steps off onto the landing, look down + W from the landing climbs down to the floor,
## jump lets go, and casing (unmasked) crew cannot climb (S1.1). Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null
var _pilot: Po5Pilot = null
var _lad: Ladder = null


func after_each() -> void:
	if _pilot != null:
		_pilot.inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	_pilot = null
	_lad = null
	await wait_frames(1)


func note(msg: String) -> void:
	print("[LADDER] %s" % msg)


func shot(_label: String) -> void:
	pass


func _setup(masked: bool = true) -> CrewController:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_lad = ATestMaps.add_prefab(_rt, "ladder", Vector3(0, 0, -6)) as Ladder
	await wait_physics_frames(3)
	# Ledge on the wall side (+Z of the prefab) under the Top marker.
	var top: Vector3 = _lad.top_position()
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	var depth: float = absf(top.z - _lad.global_position.z) + 2.0
	box.size = Vector3(4.0, top.y, depth)
	shape.shape = box
	body.add_child(shape)
	_rt.map.add_child(body)
	body.global_position = Vector3(_lad.global_position.x, top.y * 0.5, _lad.global_position.z + 0.15 + depth * 0.5)
	var c: CrewController = _rt.crew_controller(Net.local_slot()) as CrewController
	await wait_physics_frames(20)
	_pilot = Po5Pilot.new(self, c)
	_pilot.quiet = true
	_pilot.inp.capture_mouse()
	await _pilot.calibrate()
	if masked:
		await _pilot.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	return c


func _to_bottom(c: CrewController) -> void:
	var b: Vector3 = _lad.bottom_position()
	var off: Vector3 = -_lad.global_basis.z
	off.y = 0.0
	_rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, b + off.normalized() * 0.9 + Vector3(0, 0.05, 0)))
	await wait_physics_frames(10)


## Hold W for up to `max_s` game seconds or until `until` is true.
func _hold_w(until: Callable, max_s: float) -> bool:
	_pilot.inp.press(&"move_forward")
	var ok: bool = await wait_until(until, max_s)
	_pilot.inp.release(&"move_forward")
	return ok


func test_walk_in_climbs_up_and_steps_off_no_forced_animation() -> void:
	var c: CrewController = await _setup()
	await _to_bottom(c)
	var top: Vector3 = _lad.top_position()
	await _pilot.face(_lad.global_position + Vector3(0, 2.2, 0), 0.03, 1.5)  # at the ladder, a little up
	var teleported: Array[bool] = [false]
	var on_top: Callable = func() -> bool:
		teleported[0] = teleported[0] or _lad.is_climbing(c.slot)
		return c.global_position.y > top.y - 0.15 and not c.ladder.is_climbing()
	var ok: bool = await _hold_w(on_top, _lad.height_m / Tweak.crew().ladder_climb_speed_mps + 4.0)
	assert_true(ok, "climbed to the landing and stepped off (at %s, top %s)" % [c.global_position, top])
	assert_false(teleported[0], "the Ladder prefab's own (forced) climb never ran for the human")
	assert_true(Vector2(c.global_position.x - top.x, c.global_position.z - top.z).length() < 0.9,
		"stood on the landing near the Top marker")


func test_full_look_while_attached() -> void:
	var c: CrewController = await _setup()
	await _to_bottom(c)
	await _pilot.face(_lad.global_position + Vector3(0, 2.2, 0), 0.03, 1.5)
	_pilot.inp.press(&"move_forward")
	await wait_until(func() -> bool: return c.ladder.is_climbing() and c.global_position.y > 0.8, 3.0)
	_pilot.inp.release(&"move_forward")
	assert_true(c.ladder.is_climbing(), "attached mid-ladder")
	var y0: float = c.global_position.y
	var yaw0: float = c.look_yaw
	await _pilot.face(c.global_position + Vector3(3.0, 0.0, 0.0), 0.05, 1.5)  # look 90 deg away
	await wait_physics_frames(10)
	assert_true(absf(wrapf(c.look_yaw - yaw0, -PI, PI)) > 1.0, "the view turned freely (no camera lock)")
	assert_true(c.ladder.is_climbing(), "still on the ladder while looking away")
	assert_near(c.global_position.y, y0, 0.1, "no input: holds its height (no gravity on the ladder)")


func test_look_down_and_forward_climbs_down_from_the_landing() -> void:
	var c: CrewController = await _setup()
	var top: Vector3 = _lad.top_position()
	var wall: Vector3 = _lad.global_basis.z
	wall.y = 0.0
	_rt.teleport_crew(c.slot, Transform3D(Basis.IDENTITY, top + wall.normalized() * 0.6 + Vector3(0, 0.05, 0)))
	await wait_physics_frames(15)
	await _pilot.face(_lad.bottom_position() + Vector3(0, 0.2, 0), 0.03, 1.5)  # over the edge, looking down
	var max_fall: Array[float] = [0.0]  # fastest descent: a climb holds ladder_climb_speed_mps, a fall exceeds it
	var climbed: Array[bool] = [false]
	var down: Callable = func() -> bool:
		climbed[0] = climbed[0] or c.ladder.is_climbing()
		max_fall[0] = maxf(max_fall[0], -c.velocity.y)
		return c.global_position.y < _lad.bottom_position().y + 0.1 and not c.ladder.is_climbing()
	var ok: bool = await _hold_w(down, _lad.height_m / Tweak.crew().ladder_climb_speed_mps + 4.0)
	assert_true(ok, "look down + W climbed down to the floor (at %s)" % c.global_position)
	assert_true(climbed[0], "attached to the ladder from the landing")
	assert_true(max_fall[0] <= Tweak.crew().ladder_climb_speed_mps + 0.5, "climbed down, did not fall (%.2f m/s)" % max_fall[0])


func test_jump_lets_go() -> void:
	var c: CrewController = await _setup()
	await _to_bottom(c)
	await _pilot.face(_lad.global_position + Vector3(0, 2.2, 0), 0.03, 1.5)
	_pilot.inp.press(&"move_forward")
	await wait_until(func() -> bool: return c.ladder.is_climbing() and c.global_position.y > 1.2, 3.0)
	_pilot.inp.release(&"move_forward")
	assert_true(c.ladder.is_climbing(), "attached")
	await _pilot.inp.tap(&"jump")
	await wait_physics_frames(5)
	assert_false(c.ladder.is_climbing(), "jump detached")
	await wait_until(func() -> bool: return c.grounded, 3.0)
	assert_true(c.global_position.y < 0.3, "fell back to the floor")


func test_casing_crew_cannot_climb() -> void:
	var c: CrewController = await _setup(false)
	await _to_bottom(c)
	await _pilot.face(_lad.global_position + Vector3(0, 2.2, 0), 0.03, 1.5)
	await _hold_w(func() -> bool: return c.ladder.is_climbing(), 2.0)
	assert_false(c.ladder.is_climbing(), "S1.1: unmasked (casing) crew cannot climb")
	assert_true(c.global_position.y < 0.3, "stayed on the floor")
