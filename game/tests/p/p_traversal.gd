## G1 traversal harness (next_heist.md §7, D-104; ENV P). Generic real-input checks that run on any map: give them
## world positions (or a prefab) and they drive the crew the way a player does (PInputDriver: keys + mouse look),
## then report what happened. Gallery Night's G1 tests call these with the greybox's markers; the self-test
## (test_p_g1_traversal.gd) runs them on a synthetic course today.
##   gap(from, to, crouch)            walk (crouched) from -> to; ok / time / where it stalled
##   route(points, weight, sprint)    walk a waypoint list (stairs, corridors), optionally carrying a bag
##   throw_bag(pos, yaw, pitch, w)    stand at pos carrying a bag of weight w, look (yaw, pitch), throw; landing point
##   ladder(ladder, and_down)         climb up (then down) a Ladder prefab with real input; ok / times
##   carry(from, to, w)               carry a bag of weight w along the navmesh route from -> to; ok / time / stall
## Every call teleports the crew first, so calls are independent. Owner: ENV P.
class_name PTraversal
extends RefCounted

const REACH_M: float = 0.45
const STALL_S: float = 2.0

var rt: HeistRuntime = null
var crew: CrewController = null
var inp: PInputDriver = null
var _t: Node = null


func _init(test: Node, runtime: HeistRuntime, slot: int = 0) -> void:
	_t = test
	rt = runtime
	crew = rt.crew_controller(slot) as CrewController
	inp = PInputDriver.new(test)
	inp.capture_mouse()


## Walk (crouched when `crouch`) from `from` toward `to` holding W, steering with the mouse. Dictionary:
## {ok, time_s, stalled_at (Vector3 or null), min_clear_m (closest approach to `to`)}.
func gap(from: Vector3, to: Vector3, crouch: bool = false, timeout_s: float = 10.0) -> Dictionary:
	await place(from, to)
	if crouch:
		inp.press(&"crouch")
		await _ticks(20)
	var r: Dictionary = await _steer_to([to], timeout_s, false)
	inp.release(&"crouch")
	return r


## Walk the waypoints in order from `points[0]` (W held, mouse steering), optionally carrying a bag of `weight`
## (-1 = none) and holding sprint. Dictionary: as gap() plus {carrying}.
func route(points: Array[Vector3], weight: int = -1, sprint: bool = false, timeout_s: float = 30.0) -> Dictionary:
	await place(points[0], points[1])
	var bag: LootBag = await give_bag(weight) if weight >= 0 else null
	if sprint:
		inp.press(&"sprint")
	var r: Dictionary = await _steer_to(points.slice(1), timeout_s, sprint)
	inp.release(&"sprint")
	r["carrying"] = crew.is_carrying_bag()
	if crew.is_carrying_bag():
		(rt.service(G.SVC_LOOT) as LootManager).drop_bag(crew, false)
	if bag != null and is_instance_valid(bag):
		bag.queue_free()
	return r


## Stand at `pos` carrying a bag of `weight`, look along (yaw, pitch) radians, throw (G tap), wait for it to land.
## Dictionary: {thrown, landing (Vector3), rest_s, bag}.
func throw_bag(pos: Vector3, yaw: float, pitch: float, weight: int, loot_id: StringName = &"loot.cash") -> Dictionary:
	await place(pos, pos + Basis(Vector3.UP, yaw) * Vector3.FORWARD)
	var bag: LootBag = await give_bag(weight, loot_id)
	await inp.turn_to_yaw(crew, yaw)
	await turn_to_pitch(pitch)
	await inp.tap(&"drop_bag")
	var t0: int = Engine.get_physics_frames()
	var ok: bool = await _until(func() -> bool: return is_instance_valid(bag) and not bag.in_flight and not crew.is_carrying_bag(),
		6.0)
	return {"thrown": ok and not crew.is_carrying_bag(), "landing": bag.global_position if is_instance_valid(bag) else
		Vector3.INF, "rest_s": float(Engine.get_physics_frames() - t0) / Engine.physics_ticks_per_second, "bag": bag}


## Climb `ladder` up from its bottom with real input (walk into it), then back down from the top.
## Dictionary: {up, down, up_s, down_s}.
func ladder(l: Ladder, and_down: bool = true) -> Dictionary:
	var out: Dictionary = {"up": false, "down": false, "up_s": 0.0, "down_s": 0.0}
	var bottom: Vector3 = l.bottom_position()
	var top: Vector3 = l.top_position()
	var away: Vector3 = (bottom - l.global_position)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	await place(bottom + away * 0.6, l.global_position)
	var t0: int = Engine.get_physics_frames()
	inp.press(&"move_forward")
	out["up"] = await _until(func() -> bool: return crew.global_position.y > top.y - 0.3 and not l.is_climbing(crew.slot),
		l.climb_time() + 6.0)
	inp.release(&"move_forward")
	out["up_s"] = float(Engine.get_physics_frames() - t0) / Engine.physics_ticks_per_second
	if not out["up"] or not and_down:
		return out
	await _ticks(10)
	await inp.turn_to_yaw(crew, _yaw_to(crew.global_position, l.global_position))
	t0 = Engine.get_physics_frames()
	inp.press(&"move_forward")
	out["down"] = await _until(func() -> bool: return crew.global_position.y < bottom.y + 0.3 and not l.is_climbing(crew.slot),
		l.climb_time() + 6.0)
	inp.release(&"move_forward")
	out["down_s"] = float(Engine.get_physics_frames() - t0) / Engine.physics_ticks_per_second
	return out


## Carry a bag of `weight` along the navmesh route from -> to (W + sprint held, mouse steering; a straight line on
## maps without a navmesh).
## Dictionary: {ok, time_s, path_m, stalled_at, carrying}.
func carry(from: Vector3, to: Vector3, weight: int, timeout_s: float = 120.0) -> Dictionary:
	var nav: RID = crew.get_world_3d().navigation_map
	var has_nav: bool = not NavigationServer3D.map_get_regions(nav).is_empty()
	var a: Vector3 = from
	var b: Vector3 = to
	var path: PackedVector3Array = PackedVector3Array()
	# A freshly launched heist's regions sync a few frames after the map's iteration counter (global across launches)
	# already moved on: poll for a real path before calling it "no nav path".
	var waited: float = 0.0
	while has_nav and path.size() < 2 and waited < 3.0:
		a = NavigationServer3D.map_get_closest_point(nav, from)
		b = NavigationServer3D.map_get_closest_point(nav, to)
		path = NavigationServer3D.map_get_path(nav, a, b, true)
		if path.size() < 2:
			await _ticks(6)
			waited += 0.1
	if path.size() < 2:
		if has_nav:
			return {"ok": false, "time_s": 0.0, "path_m": 0.0, "stalled_at": a, "carrying": false, "why": "no nav path"}
		path = PackedVector3Array([a, b])  # no navmesh (unit maps): the straight line
	path = CrewAiBrain.offset_corners(path, 0.45)
	await place(a, path[1])
	var bag: LootBag = await give_bag(weight)
	inp.press(&"sprint")
	var pts: Array[Vector3] = []
	for k: int in range(1, path.size()):
		pts.append(path[k])
	var r: Dictionary = await _steer_to(pts, timeout_s, true)
	inp.release(&"sprint")
	var plen: float = 0.0
	for k: int in range(1, path.size()):
		plen += path[k].distance_to(path[k - 1])
	r["path_m"] = plen
	r["carrying"] = crew.is_carrying_bag()
	if crew.is_carrying_bag():
		(rt.service(G.SVC_LOOT) as LootManager).drop_bag(crew, false)
	if is_instance_valid(bag):
		bag.queue_free()
	return r


# --- Building blocks (public: G1 tests compose their own checks) ---------------------------------------

## Teleport to `pos` facing `look_at` (horizontal), masked, settled.
func place(pos: Vector3, look_at: Vector3) -> void:
	inp.release_all()
	crew.set_masked()
	rt.teleport_crew(crew.slot, Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.05))
	await _ticks(4)
	await inp.turn_to_yaw(crew, _yaw_to(pos, look_at))
	await turn_to_pitch(0.0)
	await _ticks(4)


func give_bag(weight: int, loot_id: StringName = &"loot.cash") -> LootBag:
	var loot: LootManager = rt.service(G.SVC_LOOT) as LootManager
	if crew.is_carrying_bag():
		loot.drop_bag(crew, false)
	var bag: LootBag = loot.spawn_bag(loot_id, Transform3D(Basis.IDENTITY, crew.global_position), true, weight)
	await _ticks(1)
	loot.carry(bag, crew)
	await _ticks(2)
	return bag


func turn_to_pitch(pitch: float) -> void:
	for _k: int in 30:
		var err: float = pitch - crew.look_pitch
		if absf(err) < 0.01:
			return
		inp.look(0.0, -err / PInputDriver.mouse_radians_per_px())
		await _ticks(6)


func _steer_to(pts: Array[Vector3], timeout_s: float, sprinting: bool) -> Dictionary:
	var t0: int = Engine.get_physics_frames()
	var wp: int = 0
	var best: float = INF
	var best_t: int = t0
	var min_clear: float = INF
	var goal: Vector3 = pts[pts.size() - 1]
	inp.press(&"move_forward")
	var out: Dictionary = {"ok": false, "time_s": 0.0, "stalled_at": null, "min_clear_m": INF}
	while true:
		await _ticks(1)
		var p: Vector3 = crew.global_position
		var t: float = float(Engine.get_physics_frames() - t0) / Engine.physics_ticks_per_second
		while wp < pts.size() - 1 and _flat(p, pts[wp]) < REACH_M + 0.15:
			wp += 1
		var d_goal: float = _flat(p, goal)
		min_clear = minf(min_clear, d_goal)
		if d_goal < REACH_M:
			out["ok"] = true
			out["time_s"] = t
			break
		var err: float = wrapf(_yaw_to(p, pts[wp]) - crew.look_yaw, -PI, PI)
		if absf(err) > 0.02 and (Engine.get_physics_frames() - t0) % 3 == 0:
			inp.look(-clampf(err, -0.25, 0.25) / PInputDriver.mouse_radians_per_px(), 0.0)
		var rem: float = _flat(p, pts[wp])
		for k: int in range(wp + 1, pts.size()):
			rem += _flat(pts[k - 1], pts[k])
		if rem < best - 0.1:
			best = rem
			best_t = Engine.get_physics_frames()
		if float(Engine.get_physics_frames() - best_t) / Engine.physics_ticks_per_second > STALL_S or t > timeout_s:
			out["stalled_at"] = p
			out["time_s"] = t
			break
	inp.release(&"move_forward")
	out["min_clear_m"] = min_clear
	if sprinting:
		out["sprinted"] = crew.sprinting
	return out


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _yaw_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(-d.x, -d.z)


func _ticks(n: int) -> void:
	for _i: int in n:
		await _t.get_tree().physics_frame


func _until(cond: Callable, timeout_s: float) -> bool:
	var end: int = Engine.get_physics_frames() + int(timeout_s * Engine.physics_ticks_per_second)
	while Engine.get_physics_frames() < end:
		if bool(cond.call()):
			return true
		await _ticks(1)
	return bool(cond.call())
