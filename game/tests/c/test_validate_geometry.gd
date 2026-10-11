## Unit tests for levelcheck geometry helpers (LcGeom, whitelist parsing).
extends TestCase

const REVIEW_SHOTS: GDScript = preload("res://world/tools/review_shots.gd")


func test_obb_overlap() -> void:
	var a: Dictionary = LcGeom.obb(Transform3D.IDENTITY, AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE))
	var b: Dictionary = LcGeom.obb(Transform3D(Basis(), Vector3(0.9, 0, 0)), AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE))
	assert_near(LcGeom.obb_overlap(a, b), 0.1, 1e-4)
	var c: Dictionary = LcGeom.obb(Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(1.3, 0, 0)),
		AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE))
	assert_true(LcGeom.obb_overlap(a, c) < 0.0, "rotated box 1.3 m away is separated")


func test_cycle_count() -> void:
	# K4: 7 simple cycles in total; through node 0 there are 3 triangles + 3 quads = 6.
	var adj: Dictionary = {0: [1, 2, 3], 1: [0, 2, 3], 2: [0, 1, 3], 3: [0, 1, 2]}
	assert_eq(LcGeom.count_cycles_through(adj, 0, 100), 6)
	assert_eq(LcGeom.count_cycles_through(adj, 0, 3), 3)
	var ring: Dictionary = {0: [1, 3], 1: [0, 2], 2: [1, 3], 3: [2, 0]}
	assert_eq(LcGeom.count_cycles_through(ring, 0, 3), 1)
	var line: Dictionary = {0: [1], 1: [0, 2], 2: [1]}
	assert_eq(LcGeom.count_cycles_through(line, 0, 3), 0)


func test_tri_overlap_area() -> void:
	var t1: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)])
	var t2: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 0)])
	assert_near(LcGeom.tri_overlap_area_2d(t1, t2), 0.5, 1e-5)
	var t3: PackedVector2Array = PackedVector2Array([Vector2(2, 2), Vector2(3, 2), Vector2(2, 3)])
	assert_near(LcGeom.tri_overlap_area_2d(t1, t3), 0.0, 1e-6)


func test_walkthrough_whitelist() -> void:
	var sp: Node3D = Node3D.new()
	sp.name = "PlayerSpawn1"
	var t: Node3D = Node3D.new()
	t.name = "Vault"
	var lines: PackedStringArray = PackedStringArray(["# comment", "PlayerSpawn1 Gameplay/Vault  # ok"])
	assert_true(LcCheckWalkthrough.whitelisted(lines, sp, "Spawns/PlayerSpawn1", t, "Gameplay/Vault"))
	assert_false(LcCheckWalkthrough.whitelisted(lines, sp, "Spawns/PlayerSpawn1", t, "Gameplay/Other"))
	assert_true(LcCheckWalkthrough.whitelisted(PackedStringArray(["* Vault"]), sp, "x", t, "y/Vault"))
	sp.free()
	t.free()


func test_frustum() -> void:
	var planes: Array[Plane] = LcGeom.frustum_planes(Transform3D.IDENTITY, 60.0, 16.0 / 9.0, 0.05, 100.0)
	assert_true(LcGeom.aabb_in_frustum(AABB(Vector3(-0.5, -0.5, -10.5), Vector3.ONE), planes), "in front")
	assert_false(LcGeom.aabb_in_frustum(AABB(Vector3(-0.5, -0.5, 9.5), Vector3.ONE), planes), "behind")
	assert_false(LcGeom.aabb_in_frustum(AABB(Vector3(50, -0.5, -10.5), Vector3.ONE), planes), "far right")


func test_floor_names_by_height() -> void:
	var rs: GDScript = REVIEW_SHOTS
	var fh: PackedFloat32Array = PackedFloat32Array([-4.0, 0.0, 4.2])
	assert_eq(rs.call(&"floor_name", fh, 0), "BASEMENT B1")
	assert_eq(rs.call(&"floor_name", fh, 1), "GROUND FLOOR")
	assert_eq(rs.call(&"floor_name", fh, 2), "FLOOR 1")
	assert_eq(rs.call(&"fmt_height", -4.0), "−4.0 m")
	assert_eq(rs.call(&"fmt_height", 4.2), "+4.2 m")


func test_walk_objectives_skip_observers() -> void:
	var obj: Node3D = Node3D.new()
	obj.set_script(load("res://tests/c/fixtures/lc_fixture_objective.gd"))
	obj.set(&"objective_tag", &"security_camera")
	assert_false(LcTargets.is_walk_objective(obj), "tagged node without UsePoint/Interactable")
	var up: Marker3D = Marker3D.new()
	up.name = "UsePoint"
	obj.add_child(up)
	assert_true(LcTargets.is_walk_objective(obj), "tagged node with a UsePoint")
	obj.set_meta(&"kind", "camera")
	assert_false(LcTargets.is_walk_objective(obj), "cameras are never walk targets")
	obj.free()


func test_map_floor_names_override_height_names() -> void:
	var rs: GDScript = REVIEW_SHOTS
	var m: HeistMap = HeistMap.new()
	m.floor_heights = PackedFloat32Array([-4.0, 0.0, 4.2])
	assert_eq(rs.call(&"display_floor_name", m, 0), "BASEMENT B1", "no floor_names: height naming")
	m.floor_names = PackedStringArray(["Vault Level", "", "Mezzanine"])
	assert_eq(rs.call(&"display_floor_name", m, 0), "Vault Level")
	assert_eq(rs.call(&"display_floor_name", m, 1), "GROUND FLOOR", "empty entry falls back")
	assert_eq(rs.call(&"display_floor_name", m, 2), "Mezzanine")
	m.free()
