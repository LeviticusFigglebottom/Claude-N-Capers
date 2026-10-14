## Navigation + locomotion helper for NPC brains (server). Owner: ENV A.
## Usage (brain): `motor.go_to(pos, speed)`; poll `motor.arrived`; `motor.face(dir)`; `motor.stop()`.
## Uses a NavigationAgent3D child (created if missing) on the map's default navigation map; falls
## back to straight-line movement when no navmesh path exists (unit-test maps without navigation).
## A2-01 doors (QA-11): every `npc_door_check_interval_s` the motor scans its path ahead
## (`npc_door_lookahead_m`) for a closed Door. Within `npc_door_reach_m` of the doorway it holds
## position and calls `Door.npc_open(npc)` (`waiting_door` until it is open), or, when the NPC may
## not open it (locked), stops there: `blocked_door` is set, `arrived` becomes true and
## `door_blocked(door)` fires (P3 hook: police breach locked doors from this signal).
## QC-41 rappel: reaching a NavigationLink3D marked RappelLinks.META (one-way, built from RAPPEL
## TacticalPoints) the unit descends straight to the link's exit at `rappel_speed` (`rappelling`; no
## collision on the way, so skylight glass does not stop it), then resumes its path.
## PO-5 (D-086 playability) stairs: the navmesh climbs stair risers (max climb 0.3 m) but a capsule pushed
## into a riser only slides against it, so NPCs stood at the foot of every solid-step stair (Glasshouse G8).
## When the last move was blocked by a wall-like contact, the motor lifts the body onto a lip up to
## `step_height` (headroom, room ahead and a walkable top required), like CrewController's step-up.
## PO-5 yield: a CALM NPC that a crew member keeps walking into steps aside (StealthTweak npc_yield_*),
## then resumes (`yielding` while it does). The brain's go_to/stop still apply and take over afterwards;
## any alert state other than CALM cancels the yield at once.
class_name NpcMotor
extends Node

signal arrived_at(target: Vector3)
## A2-01: the path is blocked by a closed door this NPC may not open (it stopped in front of it).
signal door_blocked(door: Node)

@export var arrive_distance: float = 0.4
@export var turn_speed_deg: float = 360.0
@export var gravity: float = 9.8
## QC-41: descent speed on a rappel link (m/s) ◇; 2.5 matches ENV D's `rappel` clip (characters.md v1.8).
@export var rappel_speed: float = 2.5
## PO-5 ◇: tallest lip (stair riser, sill, curb) the NPC steps onto (m); the navmesh's max climb is 0.3 and
## level_standards §2.6 risers are 0.15-0.19 m (the crew's CrewTweak.step_height_m is 0.35).
@export var step_height: float = 0.35
## PO-5 ◇: CharacterBody3D.wall_min_slide_angle for the body (deg). Godot's default (15) stops a body dead
## when it meets a wall within 15 deg of head-on; the path's corner waypoints hug obstacles at the
## navmesh radius, so a nearly head-on graze (stair balustrade end, wall end at a stair foot) pinned
## NPCs in place. 0 = always slide along the obstacle.
@export var wall_min_slide_deg: float = 0.0
## PO-5 ◇: the motor steers at each corner of the nav path until it is this close (horizontal, m). The
## agent's own waypoint switch (path_desired_distance 0.5, measured in 3D) cut corners by up to 0.5 m,
## straight into stair balustrade ends and wall ends the path was routing around.
@export var corner_reach: float = 0.2

var target: Vector3 = Vector3.INF
var speed: float = 0.0
var arrived: bool = true
## Desired facing when idle (horizontal unit vector), or ZERO to keep current facing.
var face_dir: Vector3 = Vector3.ZERO

## A2-01: door this NPC is waiting on to open (null when none).
var waiting_door: Door = null
## A2-01: closed door that stopped the last go_to (null when none).
var blocked_door: Door = null
## QC-41: descending a rappel link (animation hint for the AnimDriver: &"rappel").
var rappelling: bool = false

var _body: CharacterBody3D = null
var _agent: NavigationAgent3D = null
var _door_check_left: float = 0.0
var _door_ahead: Door = null
var _door_point: Vector3 = Vector3.INF
var _rappel_to: Vector3 = Vector3.INF
## PO-5 yield state.
var _press_t: float = 0.0
var _yield_point: Vector3 = Vector3.INF
var _yield_t: float = 0.0
var _yield_clear_t: float = 0.0
var _yield_home: Vector3 = Vector3.INF
var _runtime: HeistRuntime = null
## PO-5: index of the nav path corner the motor steers at (reset when the agent's path changes).
var _corner: int = 1


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body != null:
		_body.wall_min_slide_angle = deg_to_rad(wall_min_slide_deg)
	_agent = _body.get_node_or_null("NavAgent") as NavigationAgent3D if _body != null else null
	if _body != null and _agent == null:
		_agent = NavigationAgent3D.new()
		_agent.name = "NavAgent"
		_agent.radius = 0.35
		_agent.height = 1.8
		_agent.path_desired_distance = 0.5
		_agent.target_desired_distance = arrive_distance
		_body.add_child.call_deferred(_agent)
	if _agent != null:
		_agent.link_reached.connect(_on_link_reached)
		_agent.path_changed.connect(func() -> void: _corner = 1)


func go_to(pos: Vector3, move_speed: float) -> void:
	target = pos
	speed = move_speed
	arrived = false
	blocked_door = null
	_door_check_left = 0.0
	if _agent != null and _agent.is_inside_tree():
		_agent.target_position = pos


func stop() -> void:
	target = Vector3.INF
	arrived = true
	speed = 0.0
	waiting_door = null
	_door_ahead = null


func face(dir: Vector3) -> void:
	dir.y = 0.0
	face_dir = dir.normalized() if dir.length() > 0.001 else Vector3.ZERO


func face_point(p: Vector3) -> void:
	if _body != null:
		face(p - _body.global_position)


## PO-5: true while stepping aside for a crew member (or holding the side spot).
func yielding() -> bool:
	return _yield_point != Vector3.INF


func distance_to_target() -> float:
	if target == Vector3.INF or _body == null:
		return 0.0
	return Vector2(target.x - _body.global_position.x, target.z - _body.global_position.z).length()


func _physics_process(delta: float) -> void:
	if _body == null or not Net.is_authority():
		return
	var npc: NpcBase = _body as NpcBase
	if npc != null and (not npc.alive or npc.is_stunned()):  # A2-03: stunned NPCs hold still
		return
	if rappelling:
		_tick_rappel(delta)
		return
	var horiz: Vector3 = Vector3.ZERO
	_tick_yield(delta, npc)
	if _yield_point != Vector3.INF:
		var dy: Vector3 = _yield_point - _body.global_position
		dy.y = 0.0
		if dy.length() > 0.1:
			horiz = dy.normalized() * Tweak.stealth().npc_yield_speed
			_turn_toward(dy, delta)
	elif not arrived and target != Vector3.INF:
		if distance_to_target() <= arrive_distance:
			var t: Vector3 = target
			stop()
			arrived_at.emit(t)
		else:
			var next: Vector3 = target
			if _agent != null and _agent.is_inside_tree():
				if _agent.target_position != target:
					_agent.target_position = target
				var nav_next: Vector3 = _agent.get_next_path_position()
				if nav_next.distance_to(_body.global_position) > 0.05 and not _agent.is_navigation_finished():
					next = _steer_corner(nav_next)
			var d: Vector3 = next - _body.global_position
			d.y = 0.0
			if _door_hold(delta):
				if _door_point != Vector3.INF:
					_turn_toward(_door_point - _body.global_position, delta)
			elif d.length() > 0.001:
				horiz = d.normalized() * speed
				_turn_toward(d, delta)
	elif face_dir != Vector3.ZERO:
		_turn_toward(face_dir, delta)
	_body.velocity.x = horiz.x
	_body.velocity.z = horiz.z
	if horiz != Vector3.ZERO and _body.is_on_wall():
		var rise: float = _step_up_rise(horiz * delta)
		if rise > 0.0:
			_body.global_position.y += rise
			_body.velocity.y = 0.0
	if not _body.is_on_floor():
		_body.velocity.y -= gravity * delta
	else:
		_body.velocity.y = minf(_body.velocity.y, 0.0)
	_body.move_and_slide()


# --- Yield (PO-5) -----------------------------------------------------------------------------

func _tick_yield(delta: float, npc: NpcBase) -> void:
	if npc == null or npc.alert_state != Enums.AlertState.CALM:
		_press_t = 0.0
		_yield_point = Vector3.INF
		_yield_home = Vector3.INF
		return
	var tw: StealthTweak = Tweak.stealth()
	var presser: CrewController = _pressing_crew(tw)
	_press_t = _press_t + delta if presser != null else 0.0
	if _yield_point != Vector3.INF:
		_yield_t += delta
		_yield_clear_t = 0.0 if _crew_within(tw.npc_yield_clear_m) else _yield_clear_t + delta
		if _yield_clear_t >= tw.npc_yield_hold_s or _yield_t >= tw.npc_yield_max_s:
			_yield_point = Vector3.INF
			_press_t = 0.0
			if _yield_home != Vector3.INF and (arrived or target == Vector3.INF):
				go_to(_yield_home, tw.npc_yield_speed)
			_yield_home = Vector3.INF
			return
	if _press_t < tw.npc_yield_press_s or presser == null:
		return
	_press_t = 0.0
	var p: Vector3 = _pick_yield_point(presser, tw)
	if p == Vector3.INF:
		return
	if _yield_point == Vector3.INF:
		_yield_home = _body.global_position if arrived or target == Vector3.INF else Vector3.INF
	_yield_point = p
	_yield_t = 0.0
	_yield_clear_t = 0.0


func _crew_list() -> Array[CrewController]:
	if _runtime == null or not is_instance_valid(_runtime):
		_runtime = HeistRuntime.of(_body)
	if _runtime == null:
		var none: Array[CrewController] = []
		return none
	return _runtime.crew_members()


func _crew_within(r: float) -> bool:
	var p: Vector3 = _body.global_position
	for c: CrewController in _crew_list():
		if absf(c.global_position.y - p.y) < 1.0 and Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length() <= r:
			return true
	return false


## The crew member walking into this NPC right now (null when none).
func _pressing_crew(tw: StealthTweak) -> CrewController:
	var p: Vector3 = _body.global_position
	var cos_face: float = cos(deg_to_rad(tw.npc_yield_face_deg))
	for c: CrewController in _crew_list():
		var to: Vector3 = p - c.global_position
		if absf(to.y) >= 1.0:
			continue
		to.y = 0.0
		if to.length() > tw.npc_yield_reach_m or to.length() < 0.001:
			continue
		if Vector2(c.velocity.x, c.velocity.z).length() > tw.npc_yield_press_speed:
			continue
		if c.intent == null or c.intent.move.length() < 0.2:
			continue
		var aim: Vector3 = c.aim_direction()
		aim.y = 0.0
		if aim.length() < 0.001 or aim.normalized().dot(to.normalized()) < cos_face:
			continue
		return c
	return null


## A free spot npc_yield_step_m to the side of (or back from) `crew`'s push: clear of walls on the way,
## on walkable ground (and on the navmesh when the map has one). INF when there is none.
func _pick_yield_point(crew: CrewController, tw: StealthTweak) -> Vector3:
	var p: Vector3 = _body.global_position
	var away: Vector3 = p - crew.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.001 else Vector3.FORWARD
	var side: Vector3 = Vector3(-away.z, 0.0, away.x)
	var nav_map: RID = _body.get_world_3d().navigation_map
	var nav: bool = not NavigationServer3D.map_get_regions(nav_map).is_empty()
	for scale: float in [1.0, 0.6]:
		for dir: Vector3 in [side, -side, away]:
			var c: Vector3 = p + dir * tw.npc_yield_step_m * scale
			if _body.test_move(_body.global_transform, c - p):
				continue
			if nav:
				var q: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, c)
				if Vector2(q.x - c.x, q.z - c.z).length() > 0.25 or absf(q.y - c.y) > 0.5:
					continue
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c + Vector3.UP * 0.3,
				c + Vector3.DOWN * 0.5, _body.collision_mask, [_body.get_rid()])
			if _body.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			if Vector2(c.x - crew.global_position.x, c.z - crew.global_position.z).length() < tw.npc_yield_reach_m:
				continue
			return c
	return Vector3.INF


## PO-5: the nav path corner to head for: the first corner past `_corner` farther than corner_reach
## (horizontal), never beyond the agent's own next waypoint `nav_next`'s index.
func _steer_corner(nav_next: Vector3) -> Vector3:
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	var agent_idx: int = _agent.get_current_navigation_path_index()
	if path.size() < 2 or agent_idx <= 0 or agent_idx >= path.size():
		return nav_next
	_corner = clampi(_corner, 1, agent_idx)
	var p: Vector3 = _body.global_position
	while _corner < agent_idx and Vector2(path[_corner].x - p.x, path[_corner].z - p.z).length() <= corner_reach:
		_corner += 1
	return path[_corner] if _corner < agent_idx else nav_next


## PO-5: how far to raise the body onto a lip ahead (<= step_height, walkable top) before `h_motion`;
## 0 when there is nothing to step onto (no wall ahead, too tall, no headroom, steep top).
func _step_up_rise(h_motion: Vector3) -> float:
	if step_height <= 0.0 or h_motion.length_squared() < 1e-8:
		return 0.0
	var col: KinematicCollision3D = KinematicCollision3D.new()
	var margin: float = _body.safe_margin
	if not _body.test_move(_body.global_transform, h_motion, col, margin, false, 4) or not _hit_wall(col):
		return 0.0
	var xf: Transform3D = _body.global_transform
	var up: Vector3 = Vector3.UP * step_height
	if _body.test_move(xf, up, col, margin, false, 1):
		up = col.get_travel()
	xf.origin += up
	var fwd: Vector3 = h_motion
	if _body.test_move(xf, h_motion, col, margin, false, 1):
		fwd = col.get_travel()
	xf.origin += fwd
	if up.y < 0.01 or fwd.length() < h_motion.length() * 0.25 \
			or not _body.test_move(xf, Vector3.DOWN * up.y, col, margin, false, 1):
		return 0.0
	var rise: float = xf.origin.y + col.get_travel().y - _body.global_position.y
	# The rounded capsule bottom lands on the riser's edge (steep contact normal): the walkable test is
	# the top just past the contact, and its height caps the step.
	var feet: Vector3 = col.get_position() + h_motion.normalized() * 0.03
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.05,
		feet + Vector3.DOWN * 0.11, _body.collision_mask, [_body.get_rid()])
	var hit: Dictionary = _body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).angle_to(_body.up_direction) > _body.floor_max_angle + 0.01:
		return 0.0
	if (hit["position"] as Vector3).y - _body.global_position.y > step_height + 0.005:
		return 0.0
	return rise if rise > 0.002 else 0.0


func _hit_wall(col: KinematicCollision3D) -> bool:
	for k: int in range(col.get_collision_count()):
		if col.get_angle(k, _body.up_direction) > _body.floor_max_angle + 0.01:
			return true
	return false


# --- Rappel (QC-41) ------------------------------------------------------------------------

## Start a rappel descent to `exit` (server). Called on link_reached for rappel links; tests may call it.
func start_rappel(exit: Vector3) -> void:
	if _body == null or exit.y >= _body.global_position.y - 0.2:
		return
	rappelling = true
	_rappel_to = exit


func _on_link_reached(details: Dictionary) -> void:
	var link: Node = details.get("owner") as Node
	if link != null and link.has_meta(RappelLinks.META):
		start_rappel(details.get("link_exit_position", details.get("position", Vector3.INF)) as Vector3)


func _tick_rappel(delta: float) -> void:
	var p: Vector3 = _body.global_position
	var flat: Vector2 = Vector2(_rappel_to.x - p.x, _rappel_to.z - p.z)
	var step: float = rappel_speed * delta
	p.y = maxf(p.y - step, _rappel_to.y)
	if flat.length() > 0.001:
		var f: Vector2 = flat.limit_length(step)
		p.x += f.x
		p.z += f.y
	_body.global_position = p
	_body.velocity = Vector3.ZERO
	if p.y <= _rappel_to.y + 0.01 and flat.length() <= step:
		rappelling = false


# --- Doors (A2-01) -------------------------------------------------------------------------

## True while the NPC must hold position for a door (opening, or blocked: then it also stops).
func _door_hold(delta: float) -> bool:
	if waiting_door != null:
		if is_instance_valid(waiting_door) and not waiting_door.is_open:
			return true
		waiting_door = null
		_door_ahead = null
		_door_check_left = 0.0
	var tw: InteractionTweak = Tweak.interaction()
	_door_check_left -= delta
	if _door_check_left <= 0.0:
		_door_check_left = tw.npc_door_check_interval_s
		var hit: Dictionary = Door.first_closed_on_path(get_tree(), _path_ahead(), tw.npc_door_lookahead_m)
		_door_ahead = hit.get("door") as Door
		_door_point = hit.get("point", Vector3.INF)
	if _door_ahead == null or not is_instance_valid(_door_ahead) or _door_ahead.is_open:
		_door_ahead = null
		return false
	var flat: Vector3 = _door_point - _body.global_position
	flat.y = 0.0
	if flat.length() > tw.npc_door_reach_m:
		return false
	var door: Door = _door_ahead
	if door.npc_open(_body):
		waiting_door = door
		return true
	var face_at: Vector3 = _door_point
	stop()
	_door_point = face_at
	blocked_door = door
	face(face_at - _body.global_position)
	door_blocked.emit(door)
	return true


## The NPC position followed by the rest of its path (nav path, or the straight line to target).
func _path_ahead() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array([_body.global_position])
	if _agent != null and _agent.is_inside_tree():
		var path: PackedVector3Array = _agent.get_current_navigation_path()
		if path.size() >= 2:
			for i: int in range(clampi(_agent.get_current_navigation_path_index(), 0, path.size() - 1), path.size()):
				out.append(path[i])
			return out
	if target != Vector3.INF:
		out.append(target)
	return out


func _turn_toward(dir: Vector3, delta: float) -> void:
	var want: float = atan2(-dir.x, -dir.z)
	var cur: float = _body.rotation.y
	var step: float = deg_to_rad(turn_speed_deg) * delta
	_body.rotation.y = cur + clampf(wrapf(want - cur, -PI, PI), -step, step)
