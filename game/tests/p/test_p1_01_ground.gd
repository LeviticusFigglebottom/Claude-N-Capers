## P1-01: step-up, floor snapping and slope limits (CrewController._move_grounded, CrewTweak "Ground").
## The crew member is placed once per course (setup), then driven only by movement intents, the way a
## player's input drives it: no teleports during the traversal. Waits are conditions with game-time timeouts.
extends TestCase

const LANE_START_Z: float = 1.0
## Max camera rise in one physics tick while climbing (m). One tick at walk speed is ~6 cm of travel.
const MAX_CAM_STEP_M: float = 0.06

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## A static box (world_static) under the map.
func _box(center: Vector3, size: Vector3, rot_x: float = 0.0) -> StaticBody3D:
	var b: StaticBody3D = ATestMaps.add_wall(_rt.map, center, size)
	b.rotation = Vector3(rot_x, 0.0, 0.0)
	return b


## A ramp of `angle_deg` rising toward -Z from the floor at z = `z0` to height `h`, `width` wide at x.
func _ramp(x: float, z0: float, h: float, angle_deg: float, width: float = 2.5) -> float:
	var a: float = deg_to_rad(angle_deg)
	var d: float = h / tan(a)
	var s: float = sqrt(d * d + h * h)
	var t: float = 0.3
	var normal: Vector3 = Vector3(0.0, cos(a), sin(a))
	var top_mid: Vector3 = Vector3(x, h * 0.5, z0 - d * 0.5)
	_box(top_mid - normal * t * 0.5, Vector3(width, t, s), a)
	return z0 - d


## Place crew `slot` at the start of a course (setup) and wait until it stands on the floor.
func _start(slot: int, pos: Vector3, yaw: float = 0.0) -> CrewController:
	var c: CrewController = _rt.crew_controller(slot) as CrewController
	_rt.teleport_crew(slot, Transform3D(Basis(Vector3.UP, yaw), pos))
	_rt.set_bot_intent(slot, _walk_intent(yaw, 0.0))
	assert_true(await wait_until(func() -> bool: return c.grounded, 2.0), "grounded at the start")
	return c


func _walk_intent(yaw: float, fwd: float = 1.0) -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0.0, fwd)
	i.look_yaw = yaw
	return i


## Walk crew `slot` along `yaw` until `cond` or `timeout_s`; records per-tick samples. Returns
## {"ok", "cam": PackedFloat32Array, "body": PackedFloat32Array, "airborne_ticks": int}.
func _walk(slot: int, yaw: float, cond: Callable, timeout_s: float) -> Dictionary:
	var c: CrewController = _rt.crew_controller(slot) as CrewController
	var cam_node: Node3D = c.get_node(^"Head/Camera") as Node3D
	var cam: PackedFloat32Array = PackedFloat32Array()
	var body: PackedFloat32Array = PackedFloat32Array()
	var air: Array[int] = [0]
	_rt.set_bot_intent(slot, _walk_intent(yaw))
	var ok: bool = await wait_until(func() -> bool:
		cam.append(cam_node.global_position.y)
		body.append(c.global_position.y)
		if not c.grounded:
			air[0] += 1
		return cond.call(), timeout_s)
	_rt.set_bot_intent(slot, _walk_intent(yaw, 0.0))
	return {"ok": ok, "cam": cam, "body": body, "airborne_ticks": air[0]}


## Largest single-tick camera rise and the largest drop while the course only goes up.
func _cam_stats(cam: PackedFloat32Array) -> Dictionary:
	var max_rise: float = 0.0
	var max_drop: float = 0.0
	for k: int in range(1, cam.size()):
		var dy: float = cam[k] - cam[k - 1]
		max_rise = maxf(max_rise, dy)
		max_drop = maxf(max_drop, -dy)
	return {"max_rise": max_rise, "max_drop": max_drop}


func test_tweak_values_match_level_scale() -> void:
	var tw: CrewTweak = Tweak.crew()
	assert_true(tw.step_height_m >= 0.3, "climbs navmesh agent_max_climb (0.3 m)")
	assert_true(tw.step_height_m >= 0.19, "climbs the tallest standard stair riser (level_standards 0.19 m)")
	assert_true(tw.step_height_m < 0.45, "does not walk onto a chair seat (0.45 m)")
	assert_true(tw.max_slope_deg >= 40.0, "walks every navmesh slope (agent_max_slope 40)")


## 5/10/15/20/30 cm lips are walked up and back down without jumping; 40 cm blocks.
func test_step_series_up_and_down() -> void:
	var heights: Array[float] = [0.05, 0.10, 0.15, 0.20, 0.30, 0.40]
	var face_z: float = -2.0
	for k: int in range(heights.size()):
		var h: float = heights[k]
		var x: float = -12.0 + 4.5 * k
		_box(Vector3(x, h * 0.5, face_z - 2.0), Vector3(2.5, h, 4.0))
	await wait_physics_frames(2)
	for k: int in range(heights.size()):
		var h: float = heights[k]
		var x: float = -12.0 + 4.5 * k
		var c: CrewController = await _start(0, Vector3(x, 0.05, LANE_START_Z))
		var up: Dictionary = await _walk(0, 0.0, func() -> bool: return c.global_position.z < face_z - 1.5, 3.0)
		var climbs: bool = h <= Tweak.crew().step_height_m
		if not climbs:
			assert_false(up["ok"], "%d cm: blocked (z %.2f)" % [int(h * 100.0), c.global_position.z])
			assert_true(c.global_position.z > face_z, "%d cm: stopped at the face" % int(h * 100.0))
			assert_true(c.global_position.y < 0.05, "%d cm: did not climb (y %.3f)" % [int(h * 100.0), c.global_position.y])
			continue
		assert_true(up["ok"], "%d cm: walked up (z %.2f y %.3f)" % [int(h * 100.0), c.global_position.z, c.global_position.y])
		assert_near(c.global_position.y, h, 0.02, "%d cm: standing on top" % int(h * 100.0))
		assert_eq(up["airborne_ticks"], 0, "%d cm: never airborne climbing" % int(h * 100.0))
		var st: Dictionary = _cam_stats(up["cam"])
		assert_true(st["max_rise"] <= MAX_CAM_STEP_M, "%d cm: camera rise per tick %.3f m" % [int(h * 100.0), st["max_rise"]])
		assert_true(st["max_drop"] <= 0.005, "%d cm: camera never dips going up (%.3f m)" % [int(h * 100.0), st["max_drop"]])
		var cam: Node3D = c.get_node(^"Head/Camera") as Node3D
		assert_true(await wait_until(func() -> bool: return absf(cam.global_position.y - (h + Tweak.crew().eye_standing)) < 0.005, 1.0),
			"%d cm: camera settles at eye height" % int(h * 100.0))
		var down: Dictionary = await _walk(0, PI, func() -> bool: return c.global_position.z > face_z + 1.0, 3.0)
		assert_true(down["ok"], "%d cm: walked back down" % int(h * 100.0))
		assert_near(c.global_position.y, 0.0, 0.02, "%d cm: back on the floor" % int(h * 100.0))
		assert_eq(down["airborne_ticks"], 0, "%d cm: followed the floor down, no fall" % int(h * 100.0))
		var dst: Dictionary = _cam_stats(down["cam"])
		assert_true(dst["max_drop"] <= MAX_CAM_STEP_M, "%d cm: camera drop per tick %.3f m" % [int(h * 100.0), dst["max_drop"]])


## Casing (unmasked: no jump) walks up a curb, the case that blocked players before P1-01.
func test_casing_walks_up_curb() -> void:
	_box(Vector3(0.0, 0.075, -4.0), Vector3(3.0, 0.15, 4.0))
	await wait_physics_frames(2)
	var c: CrewController = await _start(0, Vector3(0.0, 0.05, LANE_START_Z))
	assert_true(c.is_casing(), "unmasked")
	var r: Dictionary = await _walk(0, 0.0, func() -> bool: return c.global_position.z < -4.0, 3.0)
	assert_true(r["ok"], "walked onto the curb while casing (y %.3f)" % c.global_position.y)


## 20 deg ramp up to a 1 m platform and back down: constant contact, no hop at the top or bottom edge.
## A 55 deg ramp is a wall.
func test_ramps() -> void:
	var top_z: float = _ramp(-6.0, -1.0, 1.0, 20.0)
	_box(Vector3(-6.0, 0.5, top_z - 1.5), Vector3(2.5, 1.0, 3.0))
	_ramp(6.0, -1.0, 1.5, 55.0)
	await wait_physics_frames(2)
	var c: CrewController = await _start(0, Vector3(-6.0, 0.05, LANE_START_Z))
	var up: Dictionary = await _walk(0, 0.0, func() -> bool: return c.global_position.z < top_z - 1.0, 5.0)
	assert_true(up["ok"], "walked up the 20 deg ramp (z %.2f y %.2f)" % [c.global_position.z, c.global_position.y])
	assert_near(c.global_position.y, 1.0, 0.03, "on the platform")
	assert_eq(up["airborne_ticks"], 0, "never airborne going up")
	var down: Dictionary = await _walk(0, PI, func() -> bool: return c.global_position.z > 0.0, 5.0)
	assert_true(down["ok"], "walked down the ramp")
	assert_eq(down["airborne_ticks"], 0, "no bouncing down the ramp")
	assert_near(c.global_position.y, 0.0, 0.03, "back on the floor")
	var s: CrewController = await _start(0, Vector3(6.0, 0.05, LANE_START_Z))
	var steep: Dictionary = await _walk(0, 0.0, func() -> bool: return s.global_position.y > 0.4, 2.0)
	assert_false(steep["ok"], "55 deg is not walkable (max y reached %.2f)" % s.global_position.y)


## Stairs (riser 0.18, tread 0.28; level_standards) up to a landing and down the far side, with an AI slot
## driven by the same intents (AI crew run the same movement code).
func test_stairs_up_and_down_human_and_ai() -> void:
	var riser: float = 0.18
	var tread: float = 0.28
	var n: int = 6
	var top: float = riser * n
	for x: float in [-4.0, 4.0]:
		for k: int in range(n):
			var h: float = riser * (k + 1)
			_box(Vector3(x, h * 0.5, -1.0 - tread * (k + 0.5)), Vector3(1.4, h, tread))
		var land_z: float = -1.0 - tread * n - 1.0
		_box(Vector3(x, top * 0.5, land_z), Vector3(1.4, top, 2.0))
		for k: int in range(n):
			var h2: float = top - riser * (k + 1)
			if h2 > 0.0:
				_box(Vector3(x, h2 * 0.5, land_z - 1.0 - tread * (k + 0.5)), Vector3(1.4, h2, tread))
	await wait_physics_frames(2)
	var far_z: float = -1.0 - tread * n - 2.0 - tread * n - 1.0
	var slots: Array[int] = [0, 1]
	for idx: int in range(2):
		var slot: int = slots[idx]
		var x: float = -4.0 if idx == 0 else 4.0
		var c: CrewController = await _start(slot, Vector3(x, 0.05, LANE_START_Z))
		var who: String = "AI" if c.is_ai else "human"
		var peak: Array[float] = [0.0]
		var r: Dictionary = await _walk(slot, 0.0, func() -> bool:
			peak[0] = maxf(peak[0], c.global_position.y)
			return c.global_position.z < far_z, 8.0)
		assert_true(r["ok"], "%s: crossed the stairs (z %.2f y %.2f)" % [who, c.global_position.z, c.global_position.y])
		assert_near(peak[0], top, 0.03, "%s: reached the landing" % who)
		assert_near(c.global_position.y, 0.0, 0.03, "%s: down on the far side" % who)
		assert_eq(r["airborne_ticks"], 0, "%s: never airborne on the stairs" % who)
		var st: Dictionary = _cam_stats(r["cam"])
		assert_true(st["max_rise"] <= MAX_CAM_STEP_M, "%s: camera rise per tick %.3f" % [who, st["max_rise"]])
		assert_true(st["max_drop"] <= MAX_CAM_STEP_M, "%s: camera drop per tick %.3f" % [who, st["max_drop"]])
		_rt.clear_bot_intent(slot)
	assert_true((_rt.crew_controller(1) as CrewController).is_ai, "slot 1 is an AI teammate")


## Jumping still works and a real ledge drop (> step height) is a fall, not a snap.
func test_jump_and_ledge_fall() -> void:
	_box(Vector3(0.0, 0.5, -3.0), Vector3(3.0, 1.0, 4.0))
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.05, -2.5)))
	assert_true(await wait_until(func() -> bool: return c.grounded, 2.0), "on the 1 m block")
	var r: Dictionary = await _walk(0, PI, func() -> bool: return c.global_position.z > 0.5, 3.0)
	assert_true(r["ok"], "walked off")
	assert_true(r["airborne_ticks"] > 5, "fell off a 1 m ledge (airborne %d ticks)" % r["airborne_ticks"])
	assert_true(await wait_until(func() -> bool: return c.grounded and c.global_position.y < 0.02, 2.0), "landed")
	var j: CrewIntent = CrewIntent.new()
	j.jump = true
	_rt.set_bot_intent(0, j)
	var peak: Array[float] = [0.0]
	await wait_until(func() -> bool:
		peak[0] = maxf(peak[0], c.global_position.y)
		return peak[0] > 0.5, 1.0)
	assert_true(peak[0] > 0.5, "jumped (peak %.2f)" % peak[0])
