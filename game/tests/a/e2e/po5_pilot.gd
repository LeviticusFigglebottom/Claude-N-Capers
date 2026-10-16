# gdlint:disable=max-public-methods
## PO-5 (D-086): walks the local player like a person would. Owner: ENV A (test support).
## Everything goes through PlayerInputDriver (Input.parse_input_event): mouse motion turns, WASD moves,
## F interacts, G masks. The route comes from the navmesh (what a player who knows the map would walk);
## the pilot never teleports, never sets bot intents and never writes game state.
## Stuck detection: holding forward with < stuck_min_m progress in stuck_window_s is logged as a
## blocker row (position + what is in front), then the pilot tries jump / strafe before giving up.
class_name Po5Pilot
extends RefCounted

## Ticks without an interaction session before use() presses interact again (interrupted hold).
const REPRESS_TICKS: int = 20
## use() on a door walks (opening doors on the way) to within this of it before open_door() squares up (m).
const DOOR_NEAR_M: float = 1.8
## "Near" is also within this height (m): a target one floor up / down is not near (ND: the pilot stood over the
## basement VaultGate and pressed its reader through the slab).
const NEAR_DY_M: float = 1.5
## Loud: a visible enemy within this range is fought before / during a hold (S9.1: damage cancels holds) (m).
const HOLD_THREAT_M: float = 20.0
## Longest clearing fight before holding anyway (s).
const CLEAR_MAX_S: float = 15.0
## Eye-ray probe drops below the head for visibility / aim: head, chest, hips (m).
const AIM_DROPS: Array[float] = [0.0, 0.45, 0.8]

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
## Where to look while holding a position with nobody in sight (the doorway the police come through).
var watch_point: Vector3 = Vector3.INF
var shots_fired: int = 0
## Stealth hook: every goto / use tick (not while answering a pager) the pilot asks `hook_need`
## (`func() -> bool`, synchronous); when true it lets go of its keys and awaits `hook` (`func() -> bool`,
## may take over the input: shout a civilian...; returns true when it acted), then carries on.
var hook_need: Callable = Callable()
var hook: Callable = Callable()
## goto() does not log its timeouts (short step-wise gotos while stalking).
var quiet: bool = false
## _unstick shouts at a civilian blocking the way at once (loud flows). Stealth turns it off: it backs off
## and lets them pass first, and shouts only after 4 tries (a shouted civilian gets up panicked when the
## intimidation runs out, so the stealth flow then has to keep them down).
var shout_blockers: bool = true
## With shout_blockers off: unstick tries before the pilot shouts at a civilian anyway.
var block_shout_after: int = 4
## goto() also needs |dy| <= this to arrive (INF = horizontal distance only; stealth flows set it for stairs).
var arrive_dy: float = NEAR_DY_M
## The closed door the last goto() gave up at because the crew cannot open it now (GN loud: the lockdown-BARRED
## Calloway shutter; the navmesh still runs through the doorway), else null.
var last_blocked_door: Door = null
## Stealth: never press F unless the component is aimed (a press with nothing usable aimed is a shout,
## S7.1: it puts every civilian within shout_all_within_m down, the sales floor through the wall).
var no_blind_press: bool = false
var _in_hook: bool = false
var _last_engage: float = -1.0
var _door_tries: Dictionary[Door, int] = {}
var _rad_px: Vector2 = Vector2.ONE


func _init(driver: Node, p_crew: CrewController) -> void:
	d = driver
	crew = p_crew
	inp = PlayerInputDriver.new(driver)
	# PO-5.1: the game captures the mouse itself (MouseCapture, D-087); po5_flow clicks like a player
	_rad_px = PlayerInputDriver.mouse_radians_per_px()


func dt() -> float:
	return 1.0 / Engine.physics_ticks_per_second


func tick() -> void:
	await d.get_tree().physics_frame


## One mouse correction toward (yaw, pitch); returns the remaining yaw error (rad).
## The error is measured against PlayerInput's own look (read-only peek): injected mouse events are flushed into
## it synchronously, while crew.look_yaw follows a physics tick later (several ticks bunch up under load).
## Steering from the lagging crew value made corrections stack and limit-cycle across +-PI.
func steer(yaw: float, pitch: float) -> float:
	var cur: Vector2 = _view()
	var ey: float = wrapf(yaw - cur.x, -PI, PI)
	var ep: float = pitch - cur.y
	var px: Vector2 = Vector2(-ey / _rad_px.x, -ep / _rad_px.y)
	if px.length() > max_px_per_tick:
		px = px.normalized() * max_px_per_tick
	if px.length() > 0.05:
		inp.look(px.x, px.y)
	return ey


## (yaw, pitch) the player is steering: PlayerInput's accumulators, else the crew's look.
func _view() -> Vector2:
	var pin: Node = crew.get_node_or_null(^"PlayerInput")
	var y: Variant = pin.get(&"_yaw") if pin != null else null
	var p: Variant = pin.get(&"_pitch") if pin != null else null
	if y is float and p is float:
		return Vector2(float(y), float(p))
	return Vector2(crew.look_yaw, crew.look_pitch)


## Measure the live mouse -> look mapping like a player getting used to the sensitivity: nudge the mouse,
## see how far (and which way) the view moved. Sets _rad_px (radians per px; the sign included), so the
## steering does not depend on settings / sensitivity formulas staying as the harness assumes.
func calibrate() -> void:
	for axis: int in 2:
		var px: Vector2 = Vector2(40.0, 0.0) if axis == 0 else Vector2(0.0, 30.0)
		var before: float = _view().x if axis == 0 else _view().y
		inp.look(px.x, px.y)
		var moved: float = 0.0
		for _f: int in 12:
			await d.get_tree().process_frame
			await tick()
			moved = (_view().x if axis == 0 else _view().y) - before
			if absf(moved) > 1e-5:
				break
		if absf(moved) <= 1e-5:
			d.note("FINDING calibrate: mouse %s motion did not move the view" % ["X" if axis == 0 else "Y"])
			continue
		var per_px: float = -moved / (px.x if axis == 0 else px.y)  # steer: look delta = -px * rad_px
		if axis == 0:
			_rad_px.x = per_px
		else:
			_rad_px.y = per_px
		inp.look(-px.x, -px.y)  # put the view back
		for _g: int in 3:
			await d.get_tree().process_frame
	d.note("pilot: calibrated %.6f rad/px yaw, %.6f rad/px pitch (settings formula said %s)" % [_rad_px.x, _rad_px.y,
		PlayerInputDriver.mouse_radians_per_px()])


func steer_at(point: Vector3) -> void:
	var v: Vector3 = point - crew.eye_position()
	steer(atan2(-v.x, -v.z), atan2(v.y, Vector2(v.x, v.z).length()))


func face(point: Vector3, tol: float = 0.03, timeout_s: float = 3.0) -> bool:
	var t: float = 0.0
	while t < timeout_s:
		var v: Vector3 = point - crew.eye_position()
		var yaw: float = atan2(-v.x, -v.z)
		var pitch: float = atan2(v.y, Vector2(v.x, v.z).length())
		var ey: float = steer(yaw, pitch)
		if absf(ey) <= tol and absf(pitch - _view().y) <= tol:
			await tick()  # the crew applies the look a physics tick later
			await tick()
			return true
		await tick()
		t += dt()
	return false


func nav_path(to: Vector3) -> PackedVector3Array:
	var map: RID = crew.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, crew.global_position, to, true)


## Within `r` horizontally AND on the same floor (|dy| <= NEAR_DY_M).
func near(a: Vector3, b: Vector3, r: float) -> bool:
	return flat_dist(a, b) <= r and absf(a.y - b.y) <= NEAR_DY_M


func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Walks to `target` along the navmesh until within `arrive_m` (horizontal). Returns success.
func goto(target: Vector3, arrive_m: float = 0.8, timeout_s: float = 60.0, sprint: bool = false,
		doors: bool = true) -> bool:
	var t: float = 0.0
	var path: PackedVector3Array = PackedVector3Array()
	var repath_t: float = 0.0
	var hist_pos: Vector3 = crew.global_position
	var hist_t: float = 0.0
	var recover: int = 0
	var ok: bool = false
	last_blocked_door = null
	while t < timeout_s:
		if combat and crew.crew_state != Enums.CrewState.NORMAL:
			d.note("pilot: goto aborted, crew state %d (fight from the floor)" % crew.crew_state)
			break  # ND attempt 14: walking on while downed meant never shooting, so police cuffed the pilot
		if flat_dist(crew.global_position, target) <= arrive_m and absf(crew.global_position.y - target.y) <= arrive_dy:
			ok = true
			break
		if repath_t <= 0.0:
			path = nav_path(target)
			repath_t = 0.5
			if path.is_empty():
				d.note("pilot: NO NAV PATH from %s to %s" % [_v(crew.global_position), _v(target)])
				break
		if combat and t - _last_engage >= 2.5:
			var foe: NpcBase = nearest_enemy(10.0)
			if foe != null:
				inp.release(&"move_forward")
				await engage(foe, 1.5)
				_last_engage = t
				repath_t = 0.0
				hist_pos = crew.global_position
				hist_t = 0.0
		if _hook_wanted() and await _run_hook():
			repath_t = 0.0
			hist_pos = crew.global_position
			hist_t = 0.0
			continue
		var corner: Vector3 = target
		for p: Vector3 in path:
			if flat_dist(p, crew.global_position) > 0.45:
				corner = p
				break
		var door: Door = door_ahead(corner) if doors else null
		if door != null and _door_blocked(door):
			inp.release(&"move_forward")
			d.note("pilot: goto blocked by %s (%s); giving up this leg" % [door.name, _door_why(door)])
			last_blocked_door = door
			break  # P (GN loud): the lockdown-BARRED art door; pushing into it stalled the flow from t=480
		if door != null:
			inp.release(&"move_forward")
			await open_door(door)
			repath_t = 0.0
			hist_pos = crew.global_position
			hist_t = 0.0
			continue
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
				+ " mouse_mode=%d state=%d look=(%.2f,%.2f) pin_yaw=%s bot=%s" % [Input.mouse_mode, crew.crew_state, crew.look_yaw,
					crew.look_pitch, crew.get_node(^"PlayerInput").get(&"_yaw"), HeistRuntime.of(crew).has_bot_intent(crew.slot)])
		repath_t -= dt()
		hist_t += dt()
		if hist_t >= stuck_window_s:
			var moved: float = flat_dist(crew.global_position, hist_pos)
			if moved < stuck_min_m and inp.is_held(&"move_forward"):
				await _log_stuck(corner)
				recover += 1
				await _unstick(recover)
			hist_pos = crew.global_position
			hist_t = 0.0
	inp.release(&"move_forward")
	inp.release(&"sprint")
	await inp.ticks(2)
	if not ok and not quiet:
		d.note("pilot: goto %s FAILED at %s after %.1f s" % [_v(target), _v(crew.global_position), t])
	return ok


func _hook_wanted() -> bool:
	return hook.is_valid() and hook_need.is_valid() and not _in_hook and bool(hook_need.call())


## Runs `hook` once (not re-entrant); true when it took over the input.
func _run_hook() -> bool:
	if not hook.is_valid() or _in_hook:
		return false
	_in_hook = true
	var took: bool = bool(await hook.call())
	_in_hook = false
	if took:
		inp.release(&"move_forward")
		inp.release(&"sprint")
	return took


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
	for i: int in crew.get_slide_collision_count():
		var kc: KinematicCollision3D = crew.get_slide_collision(i)
		var cn: Node = kc.get_collider() as Node
		hits.append("slide:%s@%s n=%s" % [cn.get_path() if cn != null else ^"?", _v(kc.get_position()), _v(kc.get_normal())])
	hits.append("vel=%s floor=%s state=%d" % [_v(crew.velocity), crew.is_on_floor(), crew.crew_state])
	var row: Dictionary = {"pos": crew.global_position, "toward": corner, "hits": hits}
	stuck_spots.append(row)
	d.note("pilot: STUCK at %s heading to %s; rays: %s" % [_v(crew.global_position), _v(corner), ", ".join(hits)])
	if stuck_spots.size() <= 3:
		await d.shot("stuck_%d" % stuck_spots.size())


func _unstick(attempt: int) -> void:
	for i: int in crew.get_slide_collision_count():
		var blocker: NpcBase = crew.get_slide_collision(i).get_collider() as NpcBase
		if not shout_blockers and attempt < block_shout_after and blocker != null and blocker.is_in_group(G.CIVILIAN) and blocker.is_alive():
			# Stealth: step back and sidestep away from the civilian instead of shouting.
			var to_b: Vector3 = blocker.global_position - crew.global_position
			var right: Vector3 = Vector3(cos(crew.look_yaw), 0.0, -sin(crew.look_yaw))
			var cb: Node = blocker.get_node_or_null(^"Brain")
			d.note("pilot: civilian %s (mode %s) blocks the way: back off and let them pass" % [blocker.name,
				cb.get(&"mode") if cb != null else "?"])
			await inp.hold(&"move_back", 0.3 + 0.3 * float(mini(attempt, 3)))
			await inp.hold(&"move_left" if right.dot(to_b) > 0.0 else &"move_right", 0.5)
			await inp.ticks(int(2.5 * Engine.physics_ticks_per_second))
			return
		if blocker != null and blocker.is_in_group(G.CIVILIAN) and blocker.is_alive():
			d.note("pilot: civilian %s blocks the way: shout" % blocker.name)
			await face(blocker.head_position() - Vector3(0, 0.4, 0), 0.05, 1.0)
			await inp.tap(&"shout")
			await inp.ticks(40)
			return
	if attempt % 2 == 1:
		await inp.tap(&"jump")
		await inp.ticks(20)
	else:
		var side: StringName = &"move_left" if attempt % 4 == 0 else &"move_right"
		await inp.hold(side, 0.4)


## Walks within reach of `comp`, aims at it and holds interact until it completes (or `done` returns true).
func use(comp: InteractableComponent, timeout_s: float = 30.0, done: Callable = Callable(), walk: bool = true) -> bool:
	var door: Door = comp.owner_node() as Door
	if walk and door != null:
		# ND attempts 15/16: the generic stand spot missed the lock and F became a shout. Walk there with normal
		# routing first (it opens the doors on the way: attempt 17 stuck at the TellerDoor heading for the
		# VaultGate), then square up with open_door().
		if not near(crew.global_position, door.global_position, DOOR_NEAR_M):
			await goto(stand_point(door.global_position), DOOR_NEAR_M, 60.0)
		if door.is_open:
			return true  # the walk's own door handling already opened it (a second use would close it)
		return await open_door(door)
	var target: Vector3 = comp.global_position
	var stand: Vector3 = _use_stand(comp)
	if walk and not await goto(stand, 0.5, 60.0) and is_instance_valid(comp):
		d.note("pilot: could not reach %s (%s)" % [comp.get_path(), comp.kind])
		if last_blocked_door != null:
			return false  # behind a door it cannot open: pressing F through the wall for 30 s does nothing (P GN-P1)
	if not is_instance_valid(comp):
		return false
	await face(target)
	var isys: InteractionSystem = HeistRuntime.of(crew).interaction
	var aimed: InteractableComponent = isys.aimed_component(crew)
	if aimed != comp:
		var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(crew.eye_position(), target, 1)
		q.exclude = [crew.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		var ang: float = rad_to_deg(crew.aim_direction().angle_to(target - crew.eye_position()))
		d.note("pilot: aimed %s, wanted %s (dist %.2f, angle %.1f deg, avail '%s', LOS ray hit %s at %s)" % [
			aimed.get_path() if aimed != null else ^"<none>", comp.get_path(), crew.eye_position().distance_to(target),
			ang, comp.availability(crew), (hit["collider"] as Node).get_path() if not hit.is_empty() else ^"-",
			_v(hit["position"]) if not hit.is_empty() else "-"])
	if no_blind_press and not await _aim_on(comp, target):
		d.note("pilot: use %s (%s) NOT PRESSED: not aimed (a blind F press is a shout)" % [comp.get_path(), comp.kind])
		return done.is_valid() and bool(done.call())
	var completed: Array[bool] = [false]
	var cb: Callable = func(_c: Node) -> void: completed[0] = true
	comp.completed.connect(cb)
	if combat and await _clear_threats():  # S9.1: damage cancels a hold, so clear the area first like a player
		await face(target, 0.03, 1.0)
	inp.press(&"interact")
	var t: float = 0.0
	var idle_ticks: int = 0
	while t < timeout_s and not completed[0] and is_instance_valid(comp) and not (done.is_valid() and bool(done.call())):
		if crew.crew_state != Enums.CrewState.NORMAL:
			break
		# A player keeps holding while nothing cancels the hold (ND attempt 20: letting go at 94 % to shoot a
		# visible cop threw the pick away); threats are cleared only once a hit has dropped it (below).
		if comp.kind != &"answer_pager" and _hook_wanted():
			inp.release(&"interact")
			if await _run_hook():
				await face(target, 0.03, 1.0)
			if no_blind_press and not await _aim_on(comp, target):
				break
			inp.press(&"interact")
		steer_at(target)
		await tick()
		t += dt()
		# Interrupted (a hit, S9.1, or a block needing a release): press again like a player would, but only
		# once no session has existed for REPRESS_TICKS (a fresh press needs a few ticks to start one).
		idle_ticks = idle_ticks + 1 if isys.session(crew.slot).is_empty() else 0
		if idle_ticks >= REPRESS_TICKS and not completed[0] and is_instance_valid(comp):
			idle_ticks = 0
			inp.release(&"interact")
			await inp.ticks(2)
			if combat and await _clear_threats():  # S9.1: a hit dropped the hold, so clear the shooters first
				d.note("pilot: use %s hold dropped, cleared threats before re-pressing" % comp.kind)
			# Re-aim before pressing again: an F press with the crosshair on a cop is a shout (ND attempts 15-18).
			await face(target, 0.03, 1.0)
			if no_blind_press and not await _aim_on(comp, target):
				break
			if isys.aimed_component(crew) == comp:
				d.note("pilot: use %s hold dropped (hit or blocked), re-pressing" % comp.kind)
				inp.press(&"interact")  # never re-press off target: F with nothing aimed is a shout
			else:
				var am: InteractableComponent = isys.aimed_component(crew)
				d.note("pilot: use %s re-press skipped: aimed %s (dist %.2f, angle %.1f deg)" % [comp.kind,
					am.get_path() if am != null else ^"<none>", crew.eye_position().distance_to(target),
					rad_to_deg(crew.aim_direction().angle_to(target - crew.eye_position()))])
	inp.release(&"interact")
	if is_instance_valid(comp) and comp.completed.is_connected(cb):
		comp.completed.disconnect(cb)
	await inp.ticks(3)
	var ok: bool = completed[0] or (done.is_valid() and bool(done.call()))
	if is_instance_valid(comp):
		d.note("pilot: use %s (%s) -> %s in %.1f s" % [comp.owner_node().name if comp.owner_node() else comp.name,
			comp.kind, "OK" if ok else "FAILED", t])
	return ok


## Loud: fight every visible enemy within HOLD_THREAT_M until none is left (or CLEAR_MAX_S). True when it fought.
func _clear_threats() -> bool:
	var fought: bool = false
	var t0: float = HeistRuntime.of(crew).heist_time_s
	while HeistRuntime.of(crew).heist_time_s - t0 < CLEAR_MAX_S and crew.crew_state == Enums.CrewState.NORMAL:
		var foe: NpcBase = nearest_enemy(HOLD_THREAT_M)
		if foe == null:
			break
		fought = true
		await engage(foe, 2.0)
	return fought


## True once `comp` is the aimed interactable (re-aims for up to ~1.5 s). Usable components only.
func _aim_on(comp: InteractableComponent, target: Vector3) -> bool:
	var isys: InteractionSystem = HeistRuntime.of(crew).interaction
	for i: int in 5:
		if not is_instance_valid(comp) or not comp.enabled:
			return false
		if isys.aimed_component(crew) == comp:
			return true
		await face(target + Vector3(0.0, 0.05 * float(i % 3 - 1), 0.0), 0.02, 0.3)
		await tick()
	return is_instance_valid(comp) and isys.aimed_component(crew) == comp


## A closed door within 1.8 m in front of the crew (the pilot opens it like a player: aim + hold F).
func door_ahead(corner: Vector3 = Vector3.INF) -> Door:
	var fwd: Vector3 = Vector3(-sin(crew.look_yaw), 0.0, -cos(crew.look_yaw))
	for n: Node in crew.get_tree().get_nodes_in_group(G.INTERACTABLE):
		var c: InteractableComponent = n as InteractableComponent
		var door: Door = c.owner_node() as Door if c != null else null
		if door == null or door.is_open:
			continue
		var to: Vector3 = c.global_position - crew.global_position
		if absf(to.y - 1.0) > 1.2:
			continue  # another floor
		to.y = 0.0
		if to.length() < 1.8 and fwd.dot(to.normalized()) > 0.4:
			# Only a door the route goes through (near the segment to the next corner), not a side door.
			if corner != Vector3.INF:
				var seg: Vector3 = corner - crew.global_position
				seg.y = 0.0
				var along: float = clampf(to.dot(seg.normalized()), 0.0, seg.length() + 0.6) if seg.length() > 0.01 else 0.0
				var off: float = (to - seg.normalized() * along).length() if seg.length() > 0.01 else to.length()
				if off > 0.7:
					continue
			return door
	return null


## A closed door on the route the crew cannot open now (BARRED / VAULT / ELECTRONIC, a keycard without a card) or
## that already beat three attempts.
func _door_blocked(door: Door) -> bool:
	return _door_tries.get(door, 0) >= 3 or _door_why(door) != InteractableComponent.BLOCK_NONE


func _door_why(door: Door) -> StringName:
	var comp: InteractableComponent = door.get_node_or_null(^"Interactable") as InteractableComponent
	return comp.availability(crew) if comp != null and comp.enabled else &"disabled"


func open_door(door: Door) -> bool:
	_door_tries[door] = _door_tries.get(door, 0) + 1
	var comp: InteractableComponent = door.get_node_or_null(^"Interactable") as InteractableComponent
	if comp == null:
		return false
	# Square up in front of the door, 0.8 m out on the crew's side, like a person reaching for the handle.
	var n: Vector3 = door.global_transform.basis.z
	n.y = 0.0
	n = n.normalized()
	if n.dot(crew.global_position - door.global_position) < 0.0:
		n = -n
	await goto(stand_point(comp.global_position + n * 0.8), 0.25, 8.0, false, false)
	var why: StringName = comp.availability(crew)
	if why != InteractableComponent.BLOCK_NONE:
		d.note("pilot: door %s (%s) blocked: %s" % [door.name, comp.kind, why])
		return false
	var ok: bool = await use(comp, 30.0, func() -> bool: return door.is_open, false)
	await inp.ticks(20)  # leaf swing
	return ok


## Nearest live enemy within `range_m` the crew can see (an eye ray to its head, chest or hips hits it first:
## a cop behind bars or a counter still shows some of its body, like it does to a player).
func nearest_enemy(range_m: float) -> NpcBase:
	var best: NpcBase = null
	var best_d: float = range_m
	for n: Node in crew.get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.is_alive():
			continue
		var sur: PoliceSurrender = PoliceSurrender.of(npc)
		if sur != null and sur.is_surrendered():
			continue  # hands up / tied: not a threat (shooting or shouting at it wastes the hold)
		var dd: float = crew.eye_position().distance_to(npc.head_position())
		if dd < best_d and _aim_point(npc) != Vector3.INF:
			best = npc
			best_d = dd
	return best


## The first visible point of `npc` (head, chest, hips), or Vector3.INF when none is.
func _aim_point(npc: NpcBase) -> Vector3:
	var head: Vector3 = npc.head_position()
	for drop: float in AIM_DROPS:
		var pt: Vector3 = head + Vector3.DOWN * drop
		if has_los(pt, npc):
			return pt
	return Vector3.INF


func has_los(point: Vector3, target: Node = null) -> bool:
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	# The player's own bullet mask (CombatTweak.hitscan_mask): teammates never block it (ND attempts 10/12: bots
	# bunched at the pilot's side read as "no line of sight" while the cops shot them).
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(crew.eye_position(), point,
		CombatTweak.data().hitscan_mask)
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
		var aim_pt: Vector3 = _aim_point(npc)
		if aim_pt == Vector3.INF:
			break
		await face(aim_pt, 0.03, 0.25)
		if not has_los(aim_pt, npc):
			break
		if not await _ensure_ammo():
			break  # both weapons dry: nothing to shoot with
		inp.press(&"fire")
		await inp.ticks(2)
		inp.release(&"fire")
		shots_fired += 1
		await inp.ticks(6)
		t += 0.25 + 8.0 * dt()
	inp.release(&"fire")


## P's GN-P1 rerun (b): the pilot sat at 0/90 firing an empty gun. Like a player: an empty mag with reserve left is
## reloaded (R, then wait for it to finish); with no reserve it switches to the other weapon if that one has ammo.
## False when neither weapon can shoot. Through input only (reload / slot_primary / slot_secondary).
func _ensure_ammo() -> bool:
	var w: CrewWeapons = crew.weapons
	if w == null:
		return true
	var ws: int = w.equipped_slot
	if w.mag(ws) > 0 and not w.reloading:
		return true
	if w.reserve(ws) > 0 or w.reloading:
		if not w.reloading:
			inp.release(&"fire")
			d.note("pilot: mag empty (%d/%d), reloading" % [w.mag(ws), w.reserve(ws)])
			await inp.tap(&"reload")
		var t: float = 0.0
		while w.reloading and t < 8.0:
			await tick()
			t += dt()
		return w.mag(w.equipped_slot) > 0
	var other: int = Enums.WeaponSlot.PRIMARY if ws == Enums.WeaponSlot.SECONDARY else Enums.WeaponSlot.SECONDARY
	if w.has_weapon(other) and w.mag(other) + w.reserve(other) > 0:
		inp.release(&"fire")
		d.note("pilot: %s dry, switching weapons" % w.weapon_id(ws))
		await inp.tap(&"slot_primary" if other == Enums.WeaponSlot.PRIMARY else &"slot_secondary")
		var t2: float = 0.0
		while w.equipped_slot != other and t2 < 3.0:
			await tick()
			t2 += dt()
		await inp.ticks(30)  # draw
		return await _ensure_ammo() if w.equipped_slot == other else false
	return false


## Fights whatever is in sight for `seconds` (standing still), reloading between targets.
func hold_position(seconds: float, until: Callable = Callable()) -> void:
	var t: float = 0.0
	while t < seconds:
		if until.is_valid() and bool(until.call()):
			return
		var foe: NpcBase = nearest_enemy(40.0) if combat else null
		if foe != null:
			await engage(foe, 2.0)
			t += 2.0
		else:
			if watch_point != Vector3.INF:
				await face(watch_point, 0.05, 0.3)
			await inp.tap(&"reload")
			await inp.ticks(10)
			t += 0.5


## The active, in-tree secure zone (variant slot chosen) nearest to the crew.
func secure_zone() -> SecureZone:
	var best: SecureZone = null
	for n: Node in crew.get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		var z: Node = n
		while z != null and not (z is SecureZone):
			z = z.get_parent()
		var sz: SecureZone = z as SecureZone
		if sz != null and sz.is_visible_in_tree() and (best == null or flat_dist(sz.global_position, crew.global_position)
				< flat_dist(best.global_position, crew.global_position)):
			best = sz
	return best


## Carries the bag on our back to `zone` and throws it in (G while masked + carrying), like a player
## tossing a bag into the van. Returns true when loot_secured fired for it.
func secure_carried_bag(zone: Node3D) -> bool:
	var secured: Array[int] = [0]
	var cb: Callable = func(_b: int, _l: StringName, _v: int) -> void: secured[0] += 1
	EventBus.loot_secured.connect(cb)
	var target: Vector3 = zone.global_position
	await goto(stand_point(target), 3.0, 120.0)
	if crew.crew_state != Enums.CrewState.NORMAL:
		EventBus.loot_secured.disconnect(cb)
		return false  # downed on the way: the flow fights from the floor, then carries on
	await face(target + Vector3(0, 0.8, 0), 0.05, 2.0)
	var tries: int = 0
	while crew.is_carrying_bag() and tries < 3:
		await inp.tap(&"drop_bag")
		await inp.ticks(10)
		tries += 1
	var t: float = 0.0
	while secured[0] == 0 and t < 8.0:
		await tick()
		t += dt()
	if secured[0] == 0 and not crew.is_carrying_bag():
		d.note("pilot: thrown bag not secured within 8 s (zone at %s, crew at %s)" % [_v(target), _v(crew.global_position)])
	EventBus.loot_secured.disconnect(cb)
	return secured[0] > 0


## The escape zone the mission activated (null until then).
func active_escape() -> EscapeZone:
	for n: Node in crew.get_tree().get_nodes_in_group(G.ESCAPE_ZONE):
		var z: Node = n
		while z != null and not (z is EscapeZone):
			z = z.get_parent()
		var ez: EscapeZone = z as EscapeZone
		if ez != null and ez.active:
			return ez
	return null


## The closest navmesh point to `target` (where a person would stand to reach it).
func stand_point(target: Vector3) -> Vector3:
	var map: RID = crew.get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, target)


## Where a player stands to use `comp`: the prefab's UsePoint if it has one (map-authored, the right side of
## counters / glass; not doors, usable from either side), else the nearest navmesh point with a clear line of
## sight to it (ring search).
func _use_stand(comp: InteractableComponent) -> Vector3:
	var owner_n: Node = comp.owner_node()
	var up: Node3D = null
	if owner_n != null and not (owner_n is Door):
		up = owner_n.get_node_or_null(^"UsePoint") as Node3D
	if up != null:
		return stand_point(up.global_position)
	var target: Vector3 = comp.global_position
	var near: Vector3 = stand_point(target)
	# GN probe 8: standing on a dropped bag, the crosshair never lands on it (aimed <none> at 0.67 m, 15 s of
	# skipped presses). Stand a step back from a loose bag, like a player looking down at it.
	var bag: bool = owner_n is LootBag
	if not bag and _clear_to(near, target):
		return near
	for r: float in [0.7, 1.1, 1.5]:
		for k: int in 12:
			var a: float = TAU * float(k) / 12.0
			var cand: Vector3 = stand_point(target + Vector3(cos(a), 0.0, sin(a)) * r)
			if flat_dist(cand, target) <= 1.6 and (not bag or flat_dist(cand, target) >= 0.9) and _clear_to(cand, target):
				return cand
	return near


func _clear_to(stand: Vector3, target: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(stand + Vector3.UP * 1.5, target, 1)
	q.exclude = [crew.get_rid()]
	var hit: Dictionary = crew.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 0.25


static func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
