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
## PO-10 personal space: NPC bodies do not collide with each other (MASK_WORLD), so the motor steers a moving
## NPC away from live NPCs of its heist within StealthTweak.npc_separation_radius_m (veering right when the push
## opposes its heading), lets stacked standing CALM NPCs drift apart, and stops short of a target another
## NPC already stands on (npc_crowd_*). Neighbours come from a per-physics-frame grid shared by all motors.
## X-5 hold mark: a brain sets `hold_check` (asked every tick, from the very first one, so nothing pushes the body
## before the brain has run) or `hold_mark` while its NPC stands idle at an authored activity mark (a teller behind
## the counter, the jeweler at the bench, a seated clerk, a cartel gunman in his chair). With no target and no
## yield, a held body does not move_and_slide at all: no idle drift away from a neighbour and no depenetration out of
## a counter / chair placed right against (or under) the mark, which is where the clip lines up with the prop. It
## still turns, and settles onto the floor below its root (a ray from just above the feet; a box it starts inside,
## the chair under a seated NPC, is ignored) instead of falling. With a `mark_anchor` (a brain whose NPC was pushed
## off its mark: a yield, a drift while not calm) it slides straight back onto it (_slide_to_anchor).
## X-5 floors: arrival is horizontal (arrive_distance) AND within arrive_dy of the target's height. It was flat
## only, so a cop chasing a crew member on the floor above stood right under him "arrived" (stop -> the brain
## re-issues the same go_to -> arrived again) for minutes (GH: a first responder parked by the WorkshopDoor below
## the crew upstairs). The same applies to the PO-10 crowded-target stop. A target the navmesh cannot reach (its
## path already ended here, or no navmesh) still arrives flat, as before.
## X-5 body: every NPC capsule is r 0.30, the navmesh bake's agent_radius (D-025), so a path never hugs a
## collider closer than the body is wide.
class_name NpcMotor
extends Node

signal arrived_at(target: Vector3)
## A2-01: the path is blocked by a closed door this NPC may not open (it stopped in front of it).
signal door_blocked(door: Node)

## Alert states whose body holds a pose: no idle drift (cowering, on the floor, tied, hands up, dead).
const DRIFT_FROZEN: Array[int] = [
	Enums.AlertState.PANICKED, Enums.AlertState.INTIMIDATED, Enums.AlertState.TIED, Enums.AlertState.SURRENDERED,
	Enums.AlertState.DOMINATED, Enums.AlertState.DEAD,
]

## PO-10: every motor in the tree, and the neighbour grid rebuilt once per physics frame.
## D-122: roles whose agents also path over Door.NAV_LAYER_BREACH links (they breach locked doors in loud).
const BREACH_ROLES: Array[StringName] = [&"police", &"special"]
## P6 #3: a body this close (beyond arrive distance) to its path's end counts as there (m).
const NAV_END_SLACK_M: float = 0.3
## P6 #3 (AH Cataclysm loud: ~97 ms a frame in path queries): brains re-target a moving crew member every tick, and each
## new NavigationAgent3D.target_position is a synchronous path query over the whole navmesh. The agent's target follows
## `target` only once it moved REPATH_M, or every REPATH_S; `target` itself (arrival, steering) stays exact.
const REPATH_M: float = 0.75
const REPATH_S: float = 0.5
## P6 #3: an unreachable target (the path ends this far from it, flat m, or off its level) makes NavigationAgent3D
## re-query every frame at the path's end (~100 ms a frame for the police at the cap with the crew off the navmesh). The
## agent is pointed at the path's end instead and asked for the real target again every UNREACHABLE_RECHECK_S (or once
## the target moved REPATH_M across: a target only moving up / down, e.g. falling, stays unreachable).
const UNREACHABLE_M: float = 1.0
const UNREACHABLE_RECHECK_S: float = 1.0
static var _all: Array[NpcMotor] = []
static var _grid: Dictionary = {}
static var _grid_frame: int = -1
static var _grid_cell: float = 1.0


@export var arrive_distance: float = 0.4
## X-5 ◇: a target more than this above / below the body (m) is not reached by standing under / over it (an
## agent height: stimulus points sit up to ~1.5 m above the floor; storeys are 3 m+ apart).
@export var arrive_dy: float = 1.8
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
## X-5: the brain holds this NPC on its activity mark while idle (see the header): a flag, or a check asked each
## tick (returns bool).
var hold_mark: bool = false
var hold_check: Callable = Callable()
## X-5: while held, the body slides back onto this point (the brain's mark after a push); INF = stay put.
var mark_anchor: Vector3 = Vector3.INF

var _body: CharacterBody3D = null
var _agent: NavigationAgent3D = null
## Physics frame of the last agent re-target (REPATH_S throttle).
var _repath_frame: int = -1000000
## The unreachable target the agent is parked on its path's end for (INF = none), and since which physics frame.
var _proxy_for: Vector3 = Vector3.INF
var _proxy_frame: int = -1000000
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
## PO-10: HeistRuntime instance id (0 outside a heist): only NPCs of the same heist keep space.
var _rt_key: int = -1
var _own_nb: Array[NpcMotor] = []
var _own_nb_frame: int = -1
## Body position when the neighbour grid was last built (read by other motors' queries that frame).
var _grid_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body != null:
		_body.wall_min_slide_angle = deg_to_rad(wall_min_slide_deg)
	_agent = _body.get_node_or_null("NavAgent") as NavigationAgent3D if _body != null else null
	if _body != null and _agent == null:
		_agent = NavigationAgent3D.new()
		_agent.name = "NavAgent"
		_agent.radius = 0.3  # X-5: the body capsule = the nav bake's agent_radius (D-025)
		_agent.height = 1.8
		_agent.path_desired_distance = 0.5
		_agent.target_desired_distance = arrive_distance
		_body.add_child.call_deferred(_agent)
	if _agent != null:
		NavPath.configure_agent(_agent)  # LEAD / C: OF's navmesh is over the 4096-polygon search default
		_agent.link_reached.connect(_on_link_reached)
		_agent.path_changed.connect(func() -> void: _corner = 1)
	var npc: NpcBase = _body as NpcBase
	if npc != null:
		npc.died.connect(func(_i: Dictionary, _k: int) -> void: _retire())
		if _agent != null and BREACH_ROLES.has(npc.role):
			_agent.navigation_layers |= Door.NAV_LAYER_BREACH  # D-122: police breach locked doors in loud


## The NPC died: a corpse keeps no navigation agent and no motor work (ND stall hunt: 30 corpses kept 30 agents
## registered on the navigation map), and leaves the personal-space grid.
func _retire() -> void:
	stop()
	set_physics_process(false)
	_all.erase(self)
	if _agent != null and is_instance_valid(_agent):
		_agent.queue_free()
	_agent = null


func _enter_tree() -> void:
	if not _all.has(self):
		_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)
	_rt_key = -1


func go_to(pos: Vector3, move_speed: float) -> void:
	var fresh: bool = target == Vector3.INF  # a new order after stop(): path at once
	target = pos
	speed = move_speed
	arrived = false
	blocked_door = null
	_door_check_left = 0.0
	_retarget_agent(fresh)


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


## X-5: held on its activity mark (hold_mark or hold_check).
func holding() -> bool:
	return hold_mark or (hold_check.is_valid() and bool(hold_check.call()))


## PO-5: true while stepping aside for a crew member (or holding the side spot).
func yielding() -> bool:
	return _yield_point != Vector3.INF


func distance_to_target() -> float:
	if target == Vector3.INF or _body == null:
		return 0.0
	return Vector2(target.x - _body.global_position.x, target.z - _body.global_position.z).length()


## X-5: the target is on this body's level (|dy| <= arrive_dy), so a flat distance means reaching it; or the path
## toward it is done (unreachable height: as close as it gets) or there is no navigation agent.
func target_on_level() -> bool:
	if target == Vector3.INF or _body == null:
		return false
	if absf(target.y - _body.global_position.y) <= arrive_dy:
		return true
	return _agent == null or not _agent.is_inside_tree() or _nav_finished()


## Whether the agent's path toward the target is done: no path, or this body within arrive distance of its end. Read off
## the path get_next_path_position() keeps current each tick (it was NavigationAgent3D.is_navigation_finished(), whose
## navigation update ran a synchronous path query for a target on another level: ~98 ms a frame on AH Cataclysm loud).
func _nav_finished() -> bool:
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	if path.is_empty():
		return true
	var end: Vector3 = path[path.size() - 1]
	var reach: float = maxf(arrive_distance, _agent.target_desired_distance) + NAV_END_SLACK_M
	return Vector2(end.x - _body.global_position.x, end.z - _body.global_position.z).length() <= reach \
		and absf(end.y - _body.global_position.y) <= arrive_dy + NAV_END_SLACK_M


## Point the agent at `target` when it moved REPATH_M since the agent's target, or REPATH_S passed (`force`: always).
func _retarget_agent(force: bool = false) -> void:
	if _agent == null or not _agent.is_inside_tree() or target == Vector3.INF or _agent.target_position == target:
		return
	var frame: int = Engine.get_physics_frames()
	if not force and _proxy_for != Vector3.INF \
			and Vector2(_proxy_for.x - target.x, _proxy_for.z - target.z).length() <= REPATH_M \
			and frame - _proxy_frame < int(UNREACHABLE_RECHECK_S * Engine.physics_ticks_per_second):
		return  # parked on the reachable end of the path to an unreachable target
	_proxy_for = Vector3.INF
	var due: bool = frame - _repath_frame >= int(REPATH_S * Engine.physics_ticks_per_second)
	if force or due or _agent.target_position.distance_squared_to(target) > REPATH_M * REPATH_M:
		_agent.target_position = target
		_repath_frame = frame


## The agent's fresh path toward `target` ends short of it (UNREACHABLE_M flat, or off its level): point the agent at
## that end (no per-frame re-query), remembering the real target (_retarget_agent asks again later).
func _park_if_unreachable() -> void:
	if _proxy_for != Vector3.INF or target == Vector3.INF or _agent.target_position != target:
		return
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	var end: Vector3 = path[path.size() - 1] if not path.is_empty() else _body.global_position  # no path at all: stay
	if not path.is_empty() and Vector2(end.x - target.x, end.z - target.z).length() <= UNREACHABLE_M \
			and absf(end.y - target.y) <= arrive_dy + 0.5:
		return
	_agent.target_position = end
	_proxy_for = target
	_proxy_frame = Engine.get_physics_frames()


func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"npc_motor", fp)


func _physics_step(delta: float) -> void:
	if _body == null or not Net.is_authority():
		return
	var npc: NpcBase = _body as NpcBase
	if npc != null and (not npc.alive or npc.is_stunned()):  # A2-03: stunned NPCs hold still
		return
	if rappelling:
		_tick_rappel(delta)
		return
	var horiz: Vector3 = Vector3.ZERO
	var fy: int = FrameProf.begin()
	_tick_yield(delta, npc)
	FrameProf.end(&"npc_motor.yield", fy)
	if _yield_point != Vector3.INF:
		var dy: Vector3 = _yield_point - _body.global_position
		dy.y = 0.0
		if dy.length() > 0.1:
			horiz = dy.normalized() * Tweak.stealth().npc_yield_speed
			_turn_toward(dy, delta)
	elif not arrived and target != Vector3.INF:
		var fc: int = FrameProf.begin()
		var on_level: bool = target_on_level()
		FrameProf.end(&"npc_motor.on_level", fc)
		var fc2: int = FrameProf.begin()
		var at_target: bool = on_level and (distance_to_target() <= arrive_distance or _target_crowded())
		FrameProf.end(&"npc_motor.crowded", fc2)
		if at_target:
			var t: Vector3 = target
			stop()
			arrived_at.emit(t)
		else:
			var next: Vector3 = target
			if _agent != null and _agent.is_inside_tree():
				var fn: int = FrameProf.begin()
				_retarget_agent()
				var nav_next: Vector3 = _agent.get_next_path_position()
				_park_if_unreachable()
				FrameProf.end(&"npc_motor.nav_path", fn)
				if nav_next.distance_to(_body.global_position) > 0.05 and not _nav_finished():
					var fs: int = FrameProf.begin()
					next = _steer_corner(nav_next)
					FrameProf.end(&"npc_motor.steer_corner", fs)
			var d: Vector3 = next - _body.global_position
			d.y = 0.0
			var fd: int = FrameProf.begin()
			var door_held: bool = _door_hold(delta)
			FrameProf.end(&"npc_motor.door_hold", fd)
			if door_held:
				horiz = _breach_stand(delta)
				if horiz == Vector3.INF and _door_point != Vector3.INF:
					_turn_toward(_door_point - _body.global_position, delta)
				horiz = Vector3.ZERO if horiz == Vector3.INF else horiz
			elif d.length() > 0.001:
				var fsep: int = FrameProf.begin()
				horiz = _separate(d.normalized()) * speed
				FrameProf.end(&"npc_motor.separate", fsep)
				_turn_toward(d, delta)
	else:
		if holding():
			if face_dir != Vector3.ZERO:
				_turn_toward(face_dir, delta)
			_body.velocity = Vector3.ZERO
			_slide_to_anchor(delta)
			_settle_held(delta)
			return  # X-5: held on its mark: no drift, no depenetration push
		horiz = _idle_drift(npc)
		if face_dir != Vector3.ZERO:
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
	var fm: int = FrameProf.begin()
	_body.move_and_slide()
	FrameProf.end(&"npc_motor.move_and_slide", fm)


## X-5: a held body with a mark_anchor slides straight onto it (horizontal, npc_mark_settle_speed, no physics: the
## mark may sit closer to its counter / chair than the navmesh edge, where the clip lines up with the prop).
func _slide_to_anchor(delta: float) -> void:
	if mark_anchor == Vector3.INF:
		return
	var d: Vector3 = mark_anchor - _body.global_position
	d.y = 0.0
	var step: float = Tweak.stealth().npc_mark_settle_speed * delta
	if d.length() <= step:
		_body.global_position += d
	else:
		_body.global_position += d.normalized() * step


## X-5: a held body drops onto the floor right below its root (at most gravity's fall this tick), no physics push.
func _settle_held(delta: float) -> void:
	var p: Vector3 = _body.global_position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.25,
		p + Vector3.DOWN * 0.6, _body.collision_mask, [_body.get_rid()])
	q.hit_from_inside = false
	var hit: Dictionary = _body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var drop: float = p.y - (hit["position"] as Vector3).y
	if drop > 0.001:
		_body.global_position.y = p.y - minf(drop, maxf(gravity * delta, 0.05))


# --- Personal space (PO-10) -----------------------------------------------------------------

func _heist_key() -> int:
	if _rt_key < 0:
		var rt: HeistRuntime = HeistRuntime.of(_body)
		_rt_key = rt.get_instance_id() if rt != null else 0
	return _rt_key


static func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / _grid_cell), floori(p.z / _grid_cell))


## _neighbours(own position), cached for the physics frame (_separate and _idle_drift share one query).
func _own_neighbours() -> Array[NpcMotor]:
	var frame: int = Engine.get_physics_frames()
	if _own_nb_frame != frame or frame != _grid_frame:
		_own_nb = _neighbours(_body.global_position)
		_own_nb_frame = frame
	return _own_nb


## Live NPC motors of this heist around `center` (the grid's 3x3 cells: everything within one cell size, at
## least npc_separation_radius_m), from a grid built once per physics frame. Excludes this motor.
func _neighbours(center: Vector3) -> Array[NpcMotor]:
	var out: Array[NpcMotor] = []
	var frame: int = Engine.get_physics_frames()
	if frame != _grid_frame:
		_grid_frame = frame
		_grid.clear()
		_grid_cell = maxf(Tweak.stealth().npc_separation_radius_m, 0.5)
		for m: NpcMotor in _all:
			if not is_instance_valid(m) or m._body == null or not m._body.is_inside_tree():
				continue
			var nb: NpcBase = m._body as NpcBase
			if nb != null and not nb.alive:
				continue
			m._grid_pos = m._body.global_position
			var c: Vector2i = _cell_of(m._grid_pos)
			if _grid.has(c):
				(_grid[c] as Array).append(m)
			else:
				_grid[c] = [m]
	var me: Vector2i = _cell_of(center)
	var key: int = _heist_key()
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var cell: Variant = _grid.get(Vector2i(me.x + dx, me.y + dz))
			if cell == null:
				continue
			for m: NpcMotor in cell as Array:
				if m != self and is_instance_valid(m) and m._heist_key() == key:
					out.append(m)
	return out


## Closeness-weighted horizontal push away from neighbours within `radius` (ZERO when none). `closest`
## receives the nearest neighbour distance.
func _push_from(neigh: Array[NpcMotor], radius: float, closest: Array[float]) -> Vector3:
	var dy_max: float = Tweak.stealth().npc_separation_dy_m
	var p: Vector3 = _body.global_position
	var r2_max: float = radius * radius
	var push: Vector3 = Vector3.ZERO
	for m: NpcMotor in neigh:
		var q: Vector3 = m._grid_pos  # cached when the grid was built this physics frame
		if absf(q.y - p.y) >= dy_max:
			continue
		var off: Vector3 = Vector3(p.x - q.x, 0.0, p.z - q.z)
		var r2: float = off.length_squared()
		if r2 >= r2_max:
			continue
		var r: float = sqrt(r2)
		closest[0] = minf(closest[0], r)
		if r < 0.001:  # exactly stacked: split by instance id so the two go opposite ways
			off = Vector3.RIGHT if get_instance_id() > m.get_instance_id() else Vector3.LEFT
			r = 0.001
		push += off / r * (1.0 - r / radius)
	return push


## Heading `dir` (unit, horizontal) bent away from nearby NPCs; unit length or ZERO.
func _separate(dir: Vector3) -> Vector3:
	var tw: StealthTweak = Tweak.stealth()
	if tw.npc_separation_gain <= 0.0 or tw.npc_separation_radius_m <= 0.0:
		return dir
	var closest: Array[float] = [INF]
	var push: Vector3 = _push_from(_own_neighbours(), tw.npc_separation_radius_m, closest)
	if push == Vector3.ZERO:
		return dir
	var against: float = push.dot(dir)
	if against < 0.0:  # coming at us: keep right so both sides pass
		push += Vector3(-dir.z, 0.0, dir.x) * -against
	var steer: Vector3 = dir + push * tw.npc_separation_gain
	return steer.normalized() if steer.length() > 0.05 else Vector3.ZERO


## Standing NPC stacked on another: a slow drift apart (ZERO otherwise). Calm or fighting alike (P PO-pass: a GH
## police pair stood 0.33 m apart for 20 s); never for a posed body (DRIFT_FROZEN states: cowering, on the floor,
## tied, hands up).
func _idle_drift(npc: NpcBase) -> Vector3:
	var tw: StealthTweak = Tweak.stealth()
	if npc == null or DRIFT_FROZEN.has(npc.alert_state) or waiting_door != null \
			or tw.npc_separation_idle_m <= 0.0 or tw.npc_separation_idle_speed <= 0.0:
		return Vector3.ZERO
	var closest: Array[float] = [INF]
	var push: Vector3 = _push_from(_own_neighbours(), tw.npc_separation_idle_m, closest)
	if push.length() < 0.001:
		return Vector3.ZERO
	return push.normalized() * tw.npc_separation_idle_speed


## True when another (standing) NPC already holds this motor's target and we are within npc_crowd_arrive_m.
func _target_crowded() -> bool:
	var tw: StealthTweak = Tweak.stealth()
	if tw.npc_crowd_occupied_m <= 0.0 or distance_to_target() > tw.npc_crowd_arrive_m:
		return false
	for m: NpcMotor in _neighbours(target):
		var q: Vector3 = m._grid_pos
		if not m.arrived or absf(q.y - target.y) >= tw.npc_separation_dy_m:
			continue
		if Vector2(q.x - target.x, q.z - target.z).length() <= tw.npc_crowd_occupied_m:
			return true
	return false


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


## D-116: while this NPC breaches its waiting_door, step to the door's breach stand and face the door normal
## (door_kick_<fam> plays square to the door); the horizontal velocity, or Vector3.INF when not breaching.
func _breach_stand(delta: float) -> Vector3:
	var door: Door = waiting_door
	if door == null or not is_instance_valid(door) or door.breach_elapsed_s(_body) < 0.0:
		return Vector3.INF
	var at: Array = door.breach_stand(_body.global_position)
	_turn_toward(at[1] as Vector3, delta)
	var d: Vector3 = (at[0] as Vector3) - _body.global_position
	d.y = 0.0
	if d.length() <= 0.03:
		return Vector3.ZERO
	return d.normalized() * minf(maxf(speed, 1.0), d.length() / maxf(delta, 0.001))


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
