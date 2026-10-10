## Navigation + locomotion helper for NPC brains (server). Owner: ENV A.
## Usage (brain): `motor.go_to(pos, speed)`; poll `motor.arrived`; `motor.face(dir)`; `motor.stop()`.
## Uses a NavigationAgent3D child (created if missing) on the map's default navigation map; falls
## back to straight-line movement when no navmesh path exists (unit-test maps without navigation).
class_name NpcMotor
extends Node

signal arrived_at(target: Vector3)

@export var arrive_distance: float = 0.4
@export var turn_speed_deg: float = 360.0
@export var gravity: float = 9.8

var target: Vector3 = Vector3.INF
var speed: float = 0.0
var arrived: bool = true
## Desired facing when idle (horizontal unit vector), or ZERO to keep current facing.
var face_dir: Vector3 = Vector3.ZERO

var _body: CharacterBody3D = null
var _agent: NavigationAgent3D = null


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


func go_to(pos: Vector3, move_speed: float) -> void:
	target = pos
	speed = move_speed
	arrived = false
	if _agent != null and _agent.is_inside_tree():
		_agent.target_position = pos


func stop() -> void:
	target = Vector3.INF
	arrived = true
	speed = 0.0


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
	if npc != null and not npc.alive:
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
			if d.length() > 0.001:
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


func _turn_toward(dir: Vector3, delta: float) -> void:
	var want: float = atan2(-dir.x, -dir.z)
	var cur: float = _body.rotation.y
	var step: float = deg_to_rad(turn_speed_deg) * delta
	_body.rotation.y = cur + clampf(wrapf(want - cur, -PI, PI), -step, step)
