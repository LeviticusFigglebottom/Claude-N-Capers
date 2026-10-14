## PO-7 frame_proud (lead gate-3 stealth run): a bag-carrying crew capsule lost ~80 s at Glasshouse
## LobbyDoor (17.0, 0, 4.5), snagged on the door frame collider (1.8 cm proud architrave boxes with
## sharp corners 7 cm beside the reveal) and the wall end G_Corridor_N_E_02 on its way from the
## corridor to the path corner (16.9, 0.2, 4.5). A plain CharacterBody3D (crew capsule r 0.35 m,
## 1.8 m, the crew's world mask) driven by move_and_slide at walk speed (3.5 m/s) and heavy / very
## heavy bag speed (x 0.5 / x 0.25) from corridor starts (hugging the wall, mid-corridor, from the
## east) to the corner and on into the lobby, (a) straight at the corner, (b) along the navmesh path,
## must arrive in time. Before the fix the heavy-bag walk from the corridor wall stalled at
## (16.31, 0, 4.95) wedged between G_Corridor_N_E_02 and the architrave collider (16.43, 4.62).
extends TestCase

const MAP: String = "res://world/heists/glasshouse/glasshouse.tscn"
const CORNER: Vector3 = Vector3(16.9, 0.0, 4.5)
const BEYOND: Vector3 = Vector3(16.9, 0.0, 3.4)
## Corridor starts along G_Corridor_N_E_02 (wall-hugging, as in the gate-3 stall), mid-corridor and from the
## east. Not west of x 15.8: a straight steer from there drags the capsule through the closed G9 door's
## recess (14.8-15.8), a different pocket a navmesh path never takes.
const STARTS: Array[Vector3] = [Vector3(15.9, 0.0, 4.96), Vector3(15.6, 0.0, 5.3), Vector3(16.1, 0.0, 4.98),
	Vector3(16.2, 0.0, 5.6), Vector3(17.4, 0.0, 5.1)]
const RADIUS: float = 0.35
const HEIGHT: float = 1.8
const WALK_MPS: float = 3.5
const HEAVY_MULT: float = 0.5  # crew_tweak bag_speed_mult[2] (heavy)
const VERY_HEAVY_MULT: float = 0.25  # bag_speed_mult[3]
const ARRIVE_M: float = 0.2
const GRAVITY: float = 9.8

var _map: HeistMap = null
var _ctx: LcContext = null


func before_all() -> void:
	_map = (load(MAP) as PackedScene).instantiate() as HeistMap
	_ctx = await LcRunner.prepare(_map, self)
	var door: Door = _map.get_node("Gameplay/Doors/LobbyDoor") as Door
	door.set_open(true, true)
	await wait_physics_frames(4)


func after_all() -> void:
	if _map != null and is_instance_valid(_map):
		remove_child(_map)
		_map.free()
	await wait_physics_frames(2)


func test_lobby_door_open_for_the_sweep() -> void:
	var door: Door = _map.get_node("Gameplay/Doors/LobbyDoor") as Door
	assert_true(door.is_open, "LobbyDoor open")


func test_walk_straight_to_the_corner() -> void:
	for spd: float in [WALK_MPS, WALK_MPS * HEAVY_MULT, WALK_MPS * VERY_HEAVY_MULT]:
		for s: Vector3 in STARTS:
			await _sweep(s, PackedVector3Array([CORNER, BEYOND]), spd, "straight")


func test_walk_navmesh_path() -> void:
	var rid: RID = _map.get_world_3d().navigation_map
	for spd: float in [WALK_MPS, WALK_MPS * HEAVY_MULT, WALK_MPS * VERY_HEAVY_MULT]:
		for s: Vector3 in STARTS:
			var a: Vector3 = NavigationServer3D.map_get_closest_point(rid, s)
			var b: Vector3 = NavigationServer3D.map_get_closest_point(rid, BEYOND)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, a, b, true)
			assert_true(path.size() >= 2, "nav path from %s" % s)
			if path.size() < 2:
				continue
			path.remove_at(0)
			await _sweep(s, path, spd, "navmesh")


## Drives a crew capsule from `start` through `pts` (XZ steering, gravity, move_and_slide); fails
## when a point is not reached within 1.5 x its straight-line time + 0.5 s.
func _sweep(start: Vector3, pts: PackedVector3Array, speed: float, label: String) -> void:
	var body: CharacterBody3D = CharacterBody3D.new()
	body.collision_layer = CrewController.COLLISION_LAYER_PLAYERS
	body.collision_mask = CrewController.COLLISION_MASK_WORLD
	body.floor_max_angle = deg_to_rad(40.0)
	body.floor_snap_length = 0.3
	body.floor_constant_speed = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	body.add_child(cs)
	_map.add_child(body)
	body.global_position = start + Vector3(0.0, 0.05, 0.0)
	await wait_physics_frames(2)
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t_total: float = 0.0
	var from: Vector3 = body.global_position
	for p: Vector3 in pts:
		var flat_d: float = Vector2(p.x - from.x, p.z - from.z).length()
		var budget: float = flat_d / speed * 1.5 + 0.5
		var t: float = 0.0
		while Vector2(p.x - body.global_position.x, p.z - body.global_position.z).length() > ARRIVE_M and t < budget:
			var d: Vector3 = Vector3(p.x - body.global_position.x, 0.0, p.z - body.global_position.z)
			var v: Vector3 = d.normalized() * speed
			body.velocity = Vector3(v.x, 0.0 if body.is_on_floor() else body.velocity.y - GRAVITY * dt, v.z)
			body.move_and_slide()
			await wait_physics_frames(1)
			t += dt
		t_total += t
		var miss: float = Vector2(p.x - body.global_position.x, p.z - body.global_position.z).length()
		if miss > ARRIVE_M:
			var hits: PackedStringArray = PackedStringArray()
			for i: int in range(body.get_slide_collision_count()):
				var k: KinematicCollision3D = body.get_slide_collision(i)
				hits.append("%s @ %s n %s" % [(k.get_collider() as Node).name if k.get_collider() is Node else "?",
					k.get_position().snapped(Vector3.ONE * 0.01), k.get_normal().snapped(Vector3.ONE * 0.01)])
			fail("%s sweep from %s at %.2f m/s stalled %.2f m short of %s after %.1f s at %s (contacts: %s)"
				% [label, start, speed, miss, p.snapped(Vector3.ONE * 0.01), t, body.global_position.snapped(Vector3.ONE * 0.01),
				", ".join(hits)])
			break
		from = body.global_position
	print("[PO-7 sweep] %s from %s at %.2f m/s: %.2f s" % [label, start, speed, t_total])
	_map.remove_child(body)
	body.free()
