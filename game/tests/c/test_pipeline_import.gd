## C1-01/C1-02: the Blender -> glb -> Godot import pipeline maps M_<id> slots onto the material
## library, keeps exact dimensions, named nodes and collision. Run after `godot --import`.
extends TestCase

const ARCH: String = "res://assets/arch/"
const EPS: float = 0.001


func _load(asset_id: String) -> Node3D:
	var path: String = ARCH + asset_id + "/" + asset_id + ".glb"
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		fail("could not load %s (run godot --import first)" % path)
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func _mesh(root: Node, node_name: String) -> MeshInstance3D:
	return root.find_child(node_name, true, false) as MeshInstance3D


func _surface_paths(mi: MeshInstance3D) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(mi.mesh.get_surface_count()):
		var m: Material = mi.mesh.surface_get_material(i)
		out.append(m.resource_path if m != null else "<null>")
	return out


func test_interior_wall_uses_library_material_and_exact_size() -> void:
	var root: Node3D = _load("arch_wall_int_w200_h300")
	if root == null:
		return
	var wall: MeshInstance3D = _mesh(root, "Wall")
	assert_true(wall != null, "Wall mesh node exists")
	if wall == null:
		return
	for p: String in _surface_paths(wall):
		assert_eq(p, "res://world/materials/grey_wall.tres", "surface material from library")
	var box: AABB = wall.get_aabb()
	assert_near(box.size.x, 2.0, EPS, "width")
	assert_near(box.size.y, 3.0, EPS, "height")
	assert_near(box.size.z, 0.2, EPS, "thickness")
	assert_near(box.position.x, 0.0, EPS, "starts at the origin")
	assert_near(box.position.y, 0.0, EPS, "sits on the floor")
	assert_near(box.position.z, -0.1, EPS, "centred on the wall line")
	var col: StaticBody3D = root.find_child("Collision", true, false) as StaticBody3D
	assert_true(col != null, "Collision-colonly became StaticBody3D 'Collision'")
	if col != null:
		var shape: CollisionShape3D = col.get_child(0) as CollisionShape3D
		assert_true(shape != null and shape.shape is ConcavePolygonShape3D, "architecture collision is trimesh")
	root.queue_free()


func test_exterior_wall_has_two_library_surfaces() -> void:
	var root: Node3D = _load("arch_wall_ext_window_w200_h300")
	if root == null:
		return
	var wall: MeshInstance3D = _mesh(root, "Wall")
	var paths: Array[String] = _surface_paths(wall)
	assert_has(paths, "res://world/materials/grey_wall.tres")
	assert_has(paths, "res://world/materials/grey_wall_ext.tres")
	assert_near(wall.get_aabb().size.z, 0.4, EPS, "exterior thickness")
	root.queue_free()


func test_door_has_contract_nodes() -> void:
	var root: Node3D = _load("arch_door_single_t20")
	if root == null:
		return
	var leaf: Node3D = root.find_child("Leaf", true, false) as Node3D
	assert_true(root.find_child("Frame", true, false) is MeshInstance3D, "Frame mesh")
	assert_true(leaf != null, "Leaf pivot")
	if leaf != null:
		assert_near(leaf.position.x, -0.45, EPS, "Leaf pivot on the hinge axis")
		assert_true(leaf.find_child("Handle", true, false) != null, "Handle marker under Leaf")
		var leaf_mesh: MeshInstance3D = _mesh(leaf, "LeafMesh")
		assert_eq(_surface_paths(leaf_mesh)[0], "res://world/materials/grey_door.tres")
	root.queue_free()


func test_stair_matches_floor_to_floor() -> void:
	var root: Node3D = _load("arch_stair_landing_f350")
	if root == null:
		return
	var stair: MeshInstance3D = _mesh(root, "Stair")
	var box: AABB = stair.get_aabb()
	assert_near(box.position.y, 0.0, EPS, "starts on the floor")
	assert_near(box.end.y, 3.5, EPS, "top tread at floor-to-floor")
	assert_near(box.size.x, 1.2, EPS, "stair width")
	root.queue_free()


func test_every_arch_surface_has_a_material() -> void:
	var dir: DirAccess = DirAccess.open(ARCH)
	if dir == null:
		fail("no %s" % ARCH)
		return
	var checked: int = 0
	for asset_id: String in dir.get_directories():
		var root: Node3D = _load(asset_id)
		if root == null:
			continue
		for n: Node in root.find_children("*", "MeshInstance3D", true, false):
			for p: String in _surface_paths(n as MeshInstance3D):
				assert_true(p.begins_with("res://world/materials/grey_"), "%s/%s -> %s" % [asset_id, n.name, p])
				checked += 1
		root.free()
	assert_true(checked > 90, "checked %d surfaces" % checked)
