## PO-5 (D-086): walks the local player like a person would. Owner: ENV A (test support).
## Everything goes through PlayerInputDriver (Input.parse_input_event): mouse motion turns, WASD moves,
## F interacts, G masks. The route comes from the navmesh (what a player who knows the map would walk);
## the pilot never teleports, never sets bot intents and never writes game state.
## Stuck detection: holding forward with < stuck_min_m progress in stuck_window_s is logged as a
## blocker row (position + what is in front), then the pilot tries jump / strafe before giving up.
class_name Po5Pilot
extends RefCounted

var d: Node = null  # po5_flow driver (note(), shot())
var inp: PlayerInputDriver = null
var crew: CrewController = null
var stuck_window_s: float = 2.0
var stuck_min_m: float = 0.35
## Max mouse travel per physics tick (px): a fast but human flick.
var max_px_per_tick: float = 120.0
var stuck_spots: Array[Dictionary] = []
## Loud: shoot enemies in sight while walking / waiting.
var combat: bool = false
var shots_fired: int = 0
var _last_engage: float = -1.0
var _door_tries: Dictionary[Door, int] = {}
var _rad_px: Vector2 = Vector2.ONE
var _look_pending: int = 0
var _look_seen: Vector2 = Vector2.ZERO


func _init(driver: Node, p_crew: CrewController) -> void:
	d = driver
	crew = p_crew
	inp = PlayerInputDriver.new(driver)
	inp.capture_mouse()
	_rad_px = PlayerInputDriver.mouse_radians_per_px()


func dt() -> float:
	return 1.0 / Engine.physics_ticks_per_second


func tick() -> void:
	await d.get_tree().physics_frame


## One mouse correction toward (yaw, pitch); returns the remaining yaw error (rad).
func steer(yaw: float, pitch: float) -> float:
	var ey: float = wrapf(yaw - crew.look_yaw, -PI, PI)
	var ep: float = pitch - crew.look_pitch
	# A look event reaches crew.look_yaw one physics tick later: wait for it before correcting again.
	var seen: Vector2 = Vector2(crew.look_yaw, crew.look_pitch)
	if _look_pending > 0 and seen == _look_seen:
		_look_pending -= 1
		return ey
	_look_pending = 0
	var px: Vector2 = Vector2(-ey / _rad_px.x, -ep / _rad_px.y)
	if px.length() > max_px_per_tick:
		px = px.normalized() * max_px_per_tick
	if px.length() > 0.05:
		inp.look(px.x, px.y)
		_look_seen = seen
		_look_pending = 4
	return ey


func face(point: Vector3, tol: float = 0.03, timeout_s: float = 3.0) -> bool:
	var t: float = 0.0
	while t < timeout_s:
		var v: Vector3 = point - crew.eye_position()
		var yaw: float = atan2(-v.x, -v.z)
		var pitch: float = atan2(v.y, Vector2(v.x, v.z).length())
		var ey: float = steer(yaw, pitch)
		if absf(ey) <= tol and absf(pitch - crew.look_pitch) <= tol:
			return true
		await tick()
		t += dt()
	return false


func nav_path(to: Vector3) -> PackedVector3Array:
	var map: RID = crew.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, crew.global_position, to, true)


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Walks to `target` along the navmesh until within `arrive_m` (horizontal). Returns success.
func goto(target: Vector3, arrive_m: float = 0.8, timeout_s: float = 60.0, sprint: bool = false) -> bool:
	var t: float = 0.0
	var path: PackedVector3Array = PackedVector3Array()
	var repath_t: float = 0.0
	var hist_pos: Vector3 = crew.global_position
	var hist_t: float = 0.0
	var recover: int = 0
	var ok: bool = false
	while t < timeout_s:
		if flat_dist(crew.global_position, target) <= arrive_m:
			ok = true
			break
		if repath_t <= 0.0:
			path = nav_path(target)
			repath_t = 0.5
			if path.is_empty():
				d.note("pilot: NO NAV PATH from %s to %s" % [_v(crew.global_position), _v(target)])
				break
		var door: Door = door_ahead()
		if door != null:
			inp.release(&"move_forward")
			await open_door(door)
			repath_t = 0.0
			hist_pos = crew.global_position
			hist_t = 0.0
			continue
		if combat and t - _last_engage >= 2.5:
			var foe: NpcBase = nearest_enemy(10.0)
			if foe != null:
				inp.release(&"move_forward")
				await engage(foe, 1.5)
				_last_engage = t
				repath_t = 0.0
				hist_pos = crew.global_position
				hist_t = 0.0
		var corner: Vector3 = target
		for p: Vector3 in path:
			if flat_dist(p, crew.global_position) > 0.45:
				corner = p
				break
		var v: Vector3 = corner - crew.global_position
		var ey: float = steer(atan2(-v.x, -v.z), 0.0)
		var want_fwd: bool = absf(ey) < 0.6
		if want_fwd and not inp.is_held(&"move_forward"):
			inp.press(&"move_forward")
		elif not want_fwd and inp.is_held(&"move_forward"):
			inp.release(&"move_forward")
		if sprint and want_fwd and not inp.is_held(&"sprint"):
			inp.press(&"sprint")
		await tick()
		t += dt()
		if int(t / 5.0) != int((t - dt()) / 5.0):
			d.note("pilot: t=%.0f at %s corner %s yaw_err %.2f fwd=%s path=%d" % [t, _v(crew.global_position),
				_v(corner), ey, inp.is_held(&"move_forward"), path.size()]
				+ " mouse_mode=%d state=%d look=(%.2f,%.2f)" % [Input.mouse_mode, crew.crew_state, crew.look_yaw, crew.look_pitch])
		repath_t -= dt()
		hist_t += dt()
		if hist_t >= stuck_window_s:
			var moved: float = flat_dist(crew.global_position, hist_pos)
			if moved < stuck_min_m and inp.is_held(&"move_forward"):
				_log_stuck(corner)
				recover += 1
				await _unstick(recover)
			hist_pos = crew.global_position
			hist_t = 0.0
	inp.release(&"move_forward")
	inp.release(&"sprint")
	await inp.ticks(2)
	if not ok:
		d.note("pilot: goto %s FAILED at %s after %.1f s" % [_v(target), _v(crew.global_position), t])
	return ok


func _log_stuck(corner: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	var dir: Vector3 = (corner - crew.global_position)
	dir.y = 0.0
	dir = dir.normalized()
	var hits: PackedStringArray = PackedStringArray()
	for h: float in [0.05, 0.2, 0.4, 1.0]:
		var from: Vector3 = crew.global_position + Vector3(0, h, 0)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 0.8)
		q.exclude = [crew.get_rid()]
		var r: Dictionary = space.intersect_ray(q)
		if not r.is_empty():
			var col: Object = r["collider"]
			hits.append("h%.2f:%s@%s" % [h, (col as Node).get_path() if col is Node else str(col), _v(r["position"])])
	var row: Dictionary = {"pos": crew.global_position, "toward": corner, "hits": hits}
	stuck_spots.append(row)
	d.note("pilot: STUCK at %s heading to %s; rays: %s" % [_v(crew.global_position), _v(corner), ", ".join(hits)])


func _unstick(attempt: int) -> void:
	if attempt % 2 == 1:
		await inp.tap(&"jump")
		await inp.ticks(20)
	else:
		var side: StringName = &"move_left" if attempt % 4 == 0 else &"move_right"
		await inp.hold(side, 0.4)


## Walks within reach of `comp`, aims at it and holds interact until it completes (or `done` returns true).
func use(comp: InteractableComponent, timeout_s: float = 30.0, done: Callable = Callable(), walk: bool = true) -> bool:
	var target: Vector3 = comp.global_position
	var stand: Vector3 = stand_point(target)
	if walk and not await goto(stand, 0.5, 60.0):
		d.note("pilot: could not reach %s (%s)" % [comp.get_path(), comp.kind])
	await face(target)
	var isys: InteractionSystem = HeistRuntime.of(crew).interaction
	var aimed: InteractableComponent = isys.aimed_component(crew)
	if aimed != comp:
		d.note("pilot: aimed %s, wanted %s (dist %.2f)" % [aimed.get_path() if aimed != null else ^"<none>",
			comp.get_path(), crew.eye_position().distance_to(target)])
	var completed: Array[bool] = [false]
	var cb: Callable = func(_c: Node) -> void: completed[0] = true
	comp.completed.connect(cb)
	inp.press(&"interact")
	var t: float = 0.0
	while t < timeout_s and not completed[0] and not (done.is_valid() and bool(done.call())):
		if crew.crew_state != Enums.CrewState.NORMAL:
			break
		var foe: NpcBase = nearest_enemy(8.0) if combat else null
		if foe != null:
			inp.release(&"interact")
			await engage(foe, 2.0)
			inp.press(&"interact")
		await face(target, 0.03, dt())
		t += dt()
	inp.release(&"interact")
	if comp.completed.is_connected(cb):
		comp.completed.disconnect(cb)
	await inp.ticks(3)
	var ok: bool = completed[0] or (done.is_valid() and bool(done.call()))
	d.note("pilot: use %s (%s) -> %s in %.1f s" % [comp.owner_node().name if comp.owner_node() else comp.name,
		comp.kind, "OK" if ok else "FAILED", t])
	return ok


## A closed door within 1.8 m in front of the crew (the pilot opens it like a player: aim + hold F).
func door_ahead() -> Door:
	var fwd: Vector3 = Vector3(-sin(crew.look_yaw), 0.0, -cos(crew.look_yaw))
	for n: Node in crew.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var door: Door = c.owner_node() as Door if c != null else null
		if door == null or door.is_open or not c.enabled or _door_tries.get(door, 0) >= 3:
			continue
		var to: Vector3 = c.global_position - crew.global_position
		if absf(to.y - 1.0) > 1.2:
			continue  # another floor
		to.y = 0.0
		if to.length() < 1.8 and fwd.dot(to.normalized()) > 0.4:
			return door
	return null


func open_door(door: Door) -> bool:
	_door_tries[door] = _door_tries.get(door, 0) + 1
	var comp: InteractableComponent = door.get_node_or_null(^"Interactable") as InteractableComponent
	if comp == null:
		return false
	var why: StringName = comp.availability(crew)
	if why != InteractableComponent.BLOCK_NONE:
		d.note("pilot: door %s (%s) blocked: %s" % [door.name, comp.kind, why])
		return false
	var ok: bool = await use(comp, 30.0, func() -> bool: return door.is_open, false)
	await inp.ticks(20)  # leaf swing
	return ok


## Nearest live enemy within `range_m` the crew can see (eye -> head ray hits nothing static first).
func nearest_enemy(range_m: float) -> NpcBase:
	var best: NpcBase = null
	var best_d: float = range_m
	for n: Node in crew.get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.is_alive():
			continue
		var dd: float = crew.eye_position().distance_to(npc.head_position())
		if dd < best_d and has_los(npc.head_position(), npc):
			best = npc
			best_d = dd
	return best


func has_los(point: Vector3, target: Node = null) -> bool:
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(crew.eye_position(), point)
	q.exclude = [crew.get_rid()]
	var r: Dictionary = space.intersect_ray(q)
	if r.is_empty():
		return true
	var col: Node = r["collider"] as Node
	return target != null and col != null and (col == target or target.is_ancestor_of(col))


## Aim at the head and fire in short bursts for up to `max_s` or until it dies / leaves sight.
func engage(npc: NpcBase, max_s: float) -> void:
	var t: float = 0.0
	while t < max_s and npc.is_alive():
		var aim_pt: Vector3 = npc.head_position()
		await face(aim_pt, 0.03, 0.25)
		if not has_los(aim_pt, npc):
			break
		inp.press(&"fire")
		await inp.ticks(2)
		inp.release(&"fire")
		shots_fired += 1
		await inp.ticks(6)
		t += 0.25 + 8.0 * dt()
	inp.release(&"fire")


## Fights whatever is in sight for `seconds` (standing still), reloading between targets.
func hold_position(seconds: float, until: Callable = Callable()) -> void:
	var t: float = 0.0
	while t < seconds:
		if until.is_valid() and bool(until.call()):
			return
		var foe: NpcBase = nearest_enemy(30.0) if combat else null
		if foe != null:
			await engage(foe, 2.0)
			t += 2.0
		else:
			await inp.tap(&"reload")
			await inp.ticks(28)
			t += 0.5


## The closest navmesh point to `target` (where a person would stand to reach it).
func stand_point(target: Vector3) -> Vector3:
	var map: RID = crew.get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, target)


static func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
