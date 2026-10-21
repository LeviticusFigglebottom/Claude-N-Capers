## PO-C (D-145 auto_loud pilot, seeds 1 / 3): the pilot wedged at (1.7, 3.6, 5.2) on the StairST top landing on its
## way to the count-room cage padlock, its stuck rays on Geometry/Building/StairST/Divider2 (the well divider's south
## end, x 1.4-1.6, z <= 4.53). A plain CharacterBody3D crew capsule (r 0.35 m, 1.8 m, the crew's world mask) driven
## by move_and_slide at walk speed (3.5 m/s) and very heavy bag speed (x 0.25) along the navmesh path from points on
## the landing (and the top of Flight1E) to the CountCagePadlock UsePoint, through the StairMezz and M1Corridor doors
## (opened by setup), must arrive in time; and the path from the landing must stay on the mezzanine (no corner
## behind the divider: down Flight1E / up Flight2W). Owner: ENV C.
extends TestCase

const SCENE: String = "res://world/heists/dockside_burn/dockside_burn.tscn"
const PADLOCK: String = "Gameplay/Doors/CountCageGate/CountCagePadlock"
const OPEN_DOORS: Array[String] = ["Gameplay/Doors/StairMezz", "Gameplay/Doors/M1Corridor"]
## The top of Flight1E, the landing in front of the divider end, the pilot's wedge spot, the Flight2W foot and the
## landing's east / west ends.
const STARTS: Array[Vector3] = [Vector3(2.2, 3.4, 4.2), Vector3(2.0, 3.6, 4.6), Vector3(1.7, 3.6, 5.2),
	Vector3(1.0, 3.6, 4.8), Vector3(2.6, 3.6, 5.5), Vector3(0.5, 3.6, 5.5)]
const MEZZ: float = 3.6
const RADIUS: float = 0.35
const HEIGHT: float = 1.8
const WALK_MPS: float = 3.5
const VERY_HEAVY_MULT: float = 0.25  # crew_tweak bag_speed_mult[3]
const ARRIVE_M: float = 0.2
const SNAP_M: float = 0.3
const GRAVITY: float = 9.8

var _map: Node3D = null
var _rid: RID = RID()


func before_all() -> void:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps == null:
		return
	_map = ps.instantiate() as Node3D
	add_child(_map)
	_rid = (_map.get_node("Navigation") as NavigationRegion3D).get_navigation_map()
	var up: Vector3 = _use_point()
	for i: int in range(120):
		await wait_physics_frames(1)
		if NavigationServer3D.map_get_iteration_id(_rid) > 0 \
				and NavigationServer3D.map_get_closest_point(_rid, up).distance_to(up) <= SNAP_M:
			break
	for p: String in OPEN_DOORS:
		(_map.get_node(p) as Door).set_open(true, true)
	await wait_physics_frames(4)


func after_all() -> void:
	if _map != null and is_instance_valid(_map):
		remove_child(_map)
		_map.free()
	await wait_physics_frames(2)


func _use_point() -> Vector3:
	var up: Node3D = _map.get_node_or_null(PADLOCK + "/UsePoint") as Node3D
	return up.global_position if up != null else Vector3.INF


func test_doors_open_for_the_sweep() -> void:
	assert_true(_map != null, "dockside_burn scene loads")
	for p: String in OPEN_DOORS:
		assert_true((_map.get_node(p) as Door).is_open, "%s open" % p)


func test_landing_path_stays_on_the_mezzanine() -> void:
	var up: Vector3 = _use_point()
	assert_true(up != Vector3.INF, "CountCagePadlock has a UsePoint")
	for s: Vector3 in STARTS:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(_rid, s, up, true)
		assert_true(path.size() >= 2 and path[path.size() - 1].distance_to(up) <= SNAP_M, "a path from %s to the padlock" % s)
		for q: Vector3 in path:
			assert_true(q.y > MEZZ - 0.6 and q.y < MEZZ + 0.6, "path corner %s from %s stays on the mezzanine" % [q, s])


func test_capsule_sweep_landing_to_padlock() -> void:
	var up: Vector3 = _use_point()
	if up == Vector3.INF:
		fail("CountCagePadlock UsePoint missing")
		return
	for spd: float in [WALK_MPS, WALK_MPS * VERY_HEAVY_MULT]:
		for s: Vector3 in STARTS:
			var a: Vector3 = NavigationServer3D.map_get_closest_point(_rid, s)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(_rid, a, up, true)
			assert_true(path.size() >= 2, "nav path from %s" % s)
			if path.size() < 2:
				continue
			path.remove_at(0)
			await _sweep(a, path, spd)


## Drives a crew capsule from `start` through `pts` (XZ steering, gravity, move_and_slide); fails when a point is not
## reached within 1.5 x its straight-line time + 0.5 s.
func _sweep(start: Vector3, pts: PackedVector3Array, speed: float) -> void:
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
		var miss: float = Vector2(p.x - body.global_position.x, p.z - body.global_position.z).length()
		if miss > ARRIVE_M:
			var hits: PackedStringArray = PackedStringArray()
			for i: int in range(body.get_slide_collision_count()):
				var k: KinematicCollision3D = body.get_slide_collision(i)
				hits.append("%s @ %s" % [(k.get_collider() as Node).name if k.get_collider() is Node else "?",
					k.get_position().snapped(Vector3.ONE * 0.01)])
			fail("sweep from %s at %.2f m/s stalled %.2f m short of %s at %s (contacts: %s)" % [start.snapped(Vector3.ONE * 0.01),
				speed, miss, p.snapped(Vector3.ONE * 0.01), body.global_position.snapped(Vector3.ONE * 0.01), ", ".join(hits)])
			break
		from = body.global_position
	_map.remove_child(body)
	body.free()
