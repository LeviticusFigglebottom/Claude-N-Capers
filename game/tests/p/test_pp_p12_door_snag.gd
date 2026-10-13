## PP-P-12: head-on door snag (CrewController._edge_assist, CrewTweak edge_assist_m / edge_assist_door_m).
## PD2 feel: walking into a door frame slightly off-centre slides round the jamb into the doorway; walking
## straight into a flat wall, a pillar or a wall end still stops.
## Real input only (PInputDriver: InputMap actions + mouse look). Each approach is placed once with a setup
## teleport before its input starts; no teleports or intents during a walk. Waits are game time (physics ticks).
## Owner: ENV P.
extends TestCase

## Glasshouse SalonDoor: the G5 / G6 wall runs along z at x = 13.0, opening z 9.5..10.5 (door at z 10).
const DOOR_Z: float = 10.0
const START_X: float = 11.3
const PAST_X: float = 13.8
## Head-on approach offsets from the doorway centre (m, +z / -z). 0.7 = PP-P-12's z 9.3 / 10.7.
const OFFSETS: Array[float] = [0.0, 0.3, -0.3, 0.55, -0.55, 0.7, -0.7]
## Game seconds to cover START_X -> PAST_X (2.5 m: 0.7 s at walk speed) including the slide round the jamb.
const PASS_BUDGET_S: float = 2.0

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_inp = PInputDriver.new(self)
	Engine.time_scale = 1.0


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _c() -> CrewController:
	return _rt.crew_controller(0) as CrewController


## Setup placement (before this approach's input starts), then mouse-look to `yaw` and settle on the floor.
func _place(pos: Vector3, yaw: float) -> CrewController:
	var c: CrewController = _c()
	c.teleport(Transform3D(Basis(Vector3.UP, yaw), pos))
	await wait_physics_frames(3)
	assert_true(await _inp.turn_to_yaw(c, yaw), "mouse-look to heading %.2f" % yaw)
	assert_true(await wait_until(func() -> bool: return c.grounded, 2.0), "grounded at the start")
	return c


## Mouse-look until the view points at `p`.
func _look_at(p: Vector3) -> void:
	var c: CrewController = _c()
	var d: Vector3 = p - c.eye_position()
	await _inp.turn_to_yaw(c, atan2(-d.x, -d.z), 0.03, 3.0)
	var rpp: float = PInputDriver.mouse_radians_per_px()
	for _i: int in 12:
		var err: float = atan2(d.y, Vector2(d.x, d.z).length()) - c.look_pitch
		if absf(err) < 0.03:
			return
		_inp.look(0.0, -err / rpp)
		await wait_physics_frames(4)


## Hold W along `yaw` for `secs` of game time; returns {"ok", "slow": ticks below 0.3 m/s inside the window,
## "max_dx", "max_dz": largest drift from the start}.
func _walk(c: CrewController, cond: Callable, secs: float, slow_if: Callable = Callable()) -> Dictionary:
	var p0: Vector3 = c.global_position
	var s: Dictionary = {"slow": 0, "max_dx": 0.0, "max_dz": 0.0}
	var ok: bool = await _inp.walk_until(&"move_forward", cond, secs, func() -> void:
		s["max_dx"] = maxf(s["max_dx"], absf(c.global_position.x - p0.x))
		s["max_dz"] = maxf(s["max_dz"], absf(c.global_position.z - p0.z))
		if slow_if.is_valid() and slow_if.call() and Vector2(c.velocity.x, c.velocity.z).length() < 0.3:
			s["slow"] += 1)
	s["ok"] = ok
	return s


## PP-P-12: Glasshouse SalonDoor (lockpicked open by holding F, masked) walked head-on from the G5 side at
## every offset in OFFSETS: through the doorway within PASS_BUDGET_S, no stop at the frame.
func test_salon_door_head_on_offsets_pass() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 1002, Enums.Difficulty.ROUTINE, self, {"ai_teammates": 0})
	if _rt == null:
		fail("launch glasshouse")
		return
	_rt.isolate_npc(null)  # setup only: no guard / civilian interferes with the walks
	_inp.capture_mouse()
	await wait_physics_frames(5)
	var door: Door = null
	for n: Node in _rt.map.find_children("SalonDoor", "Door", true, false):
		door = n as Door
	assert_true(door != null, "glasshouse has SalonDoor")
	if door == null:
		return
	# Open it like a player: stand on the UsePoint, mask up, look at the prompt, hold F until it opens.
	var up: Vector3 = door.use_point.global_position
	var comp: InteractableComponent = door.interactable
	var to_door: Vector3 = comp.global_position - up
	await _place(up + Vector3.UP * 0.05, atan2(-to_door.x, -to_door.z))
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.3)
	assert_true(await wait_until(func() -> bool: return _c().masked, 1.0), "masked up")
	await _look_at(comp.global_position)
	_inp.press(&"interact")
	var opened: bool = await wait_until(func() -> bool: return door.is_open, comp.interaction_time_s + 3.0)
	_inp.release(&"interact")
	assert_true(opened, "SalonDoor opened by holding F (aimed %s)" % _rt.interaction.aimed_component(_c()))
	if not opened:
		return
	await wait_physics_frames(4)
	var yaw: float = -PI * 0.5  # facing +X (G5 -> G6)
	for off: float in OFFSETS:
		var c: CrewController = await _place(Vector3(START_X, 0.05, DOOR_Z + off), yaw)
		var t0: int = Engine.get_physics_frames()
		var r: Dictionary = await _walk(c, func() -> bool: return c.global_position.x > PAST_X, PASS_BUDGET_S,
			func() -> bool: return c.global_position.x > 12.0 and c.global_position.x < 13.4)
		var took: float = float(Engine.get_physics_frames() - t0) / Engine.physics_ticks_per_second
		var tag: String = "SalonDoor head-on off %+.2f (z %.2f)" % [off, DOOR_Z + off]
		print("[PP-P-12] %s: %s in %.2f s game, end (%.2f, %.2f), slow ticks %d" % [tag,
			"through" if r["ok"] else "STOPPED", took, c.global_position.x, c.global_position.z, r["slow"]])
		assert_true(r["ok"], "%s: through within %.1f s (end x %.2f z %.2f)" % [tag, PASS_BUDGET_S,
			c.global_position.x, c.global_position.z])
		assert_true(int(r["slow"]) < 12, "%s: no stop at the frame (%d slow ticks)" % [tag, r["slow"]])


# --- guards (unit map: exact geometry) ------------------------------------------------------------------

func _unit_map() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp.capture_mouse()


func _box(center: Vector3, size: Vector3) -> void:
	ATestMaps.add_wall(_rt.map, center, size)


## A face-on walk into a flat wall (at z = -3, 10 m wide) stops at the wall and does not slide sideways.
func test_flat_wall_face_on_stops_no_slide() -> void:
	await _unit_map()
	_box(Vector3(0.0, 1.25, -3.0), Vector3(10.0, 2.5, 0.2))
	await wait_physics_frames(2)
	for x0: float in [0.0, 2.0]:
		var c: CrewController = await _place(Vector3(x0, 0.05, 0.0), 0.0)
		var r: Dictionary = await _walk(c, func() -> bool: return c.global_position.z < -3.0, 2.5)
		var tag: String = "flat wall x0 %.1f" % x0
		assert_false(r["ok"], "%s: did not pass the wall (z %.2f)" % [tag, c.global_position.z])
		assert_true(c.global_position.z > -2.6 and c.global_position.z < -2.4,
			"%s: stopped against the face (z %.3f)" % [tag, c.global_position.z])
		assert_true(r["max_dx"] < 0.02, "%s: no sideways slide (max |dx| %.3f m)" % [tag, r["max_dx"]])


## Dead-centre into a 0.4 m pillar (needs a 0.55 m sidestep: past edge_assist_m, and unframed) still stops.
func test_pillar_dead_centre_stops() -> void:
	await _unit_map()
	_box(Vector3(0.0, 1.25, -3.0), Vector3(0.4, 2.5, 0.4))
	await wait_physics_frames(2)
	var c: CrewController = await _place(Vector3(0.0, 0.05, 0.0), 0.0)
	var r: Dictionary = await _walk(c, func() -> bool: return c.global_position.z < -3.5, 2.5)
	assert_false(r["ok"], "pillar: did not slip round it (x %.2f z %.2f)" % [c.global_position.x, c.global_position.z])
	assert_true(r["max_dx"] < 0.05, "pillar: no sideways slide (max |dx| %.3f m)" % r["max_dx"])


## The same 0.5 m sidestep: toward a wall end (open edge) it stops; toward a 0.9 m door (framed) it slides in.
func test_framed_reach_door_only_not_wall_end() -> void:
	await _unit_map()
	# Wall end: wall for x <= 0.2 at z = -3 (passing needs centre x >= 0.55; start 0.05 -> 0.5 m sidestep).
	_box(Vector3(-4.9, 1.25, -3.0), Vector3(10.2, 2.5, 0.2))
	await wait_physics_frames(2)
	var c: CrewController = await _place(Vector3(0.05, 0.05, 0.0), 0.0)
	var r: Dictionary = await _walk(c, func() -> bool: return c.global_position.z < -3.5, 2.5)
	assert_false(r["ok"], "wall end 0.5 m in: stopped (x %.2f z %.2f)" % [c.global_position.x, c.global_position.z])
	assert_true(r["max_dx"] < 0.05, "wall end: no slide round the corner (max |dx| %.3f m)" % r["max_dx"])
	# Door: 0.9 m opening at x 10 +- 0.45 in a wall at z = -3 (passing needs |x - 10| <= 0.1; start 10.6).
	_box(Vector3(10.0 - 0.45 - 2.0, 1.25, -3.0), Vector3(4.0, 2.5, 0.2))
	_box(Vector3(10.0 + 0.45 + 2.0, 1.25, -3.0), Vector3(4.0, 2.5, 0.2))
	await wait_physics_frames(2)
	for x0: float in [10.6, 9.4]:
		c = await _place(Vector3(x0, 0.05, 0.0), 0.0)
		r = await _walk(c, func() -> bool: return c.global_position.z < -3.5, 2.0)
		assert_true(r["ok"], "door 0.5 m off the lane (x0 %.1f): slid through (x %.2f z %.2f)" % [x0,
			c.global_position.x, c.global_position.z])
