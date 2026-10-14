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


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
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
	if not arrived and target != Vector3.INF:
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
					next = nav_next
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
	if not _body.is_on_floor():
		_body.velocity.y -= gravity * delta
	else:
		_body.velocity.y = minf(_body.velocity.y, 0.0)
	_body.move_and_slide()


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
