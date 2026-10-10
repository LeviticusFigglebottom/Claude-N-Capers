## D1-04: crew mask models (tools/blender/masks/). The mask glb has M_char_mask_* surfaces, a
## head-sized AABB and its pivot at the face centre with the front (beak) toward -Z.
## Run after `godot --import`.
extends TestCase

const MASK_PATH: String = "res://assets/masks/mask_gilded_heron/mask_gilded_heron.glb"
const MATERIAL_PREFIX: String = "M_char_mask_"
const LIBRARY_PREFIX: String = "res://world/materials/char_mask_"


func _load_mask() -> Node3D:
	var packed: PackedScene = load(MASK_PATH) as PackedScene
	if packed == null:
		fail("could not load %s (run godot --import first)" % MASK_PATH)
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in meshes:
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Front-most vertex (most negative Z) across all surfaces, in the mask root's space.
func _front_point(meshes: Array[MeshInstance3D]) -> Vector3:
	var best: Vector3 = Vector3(0.0, 0.0, INF)
	for mi: MeshInstance3D in meshes:
		for s: int in range(mi.mesh.get_surface_count()):
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var w: Vector3 = mi.global_transform * v
				if w.z < best.z:
					best = w
	return best


func test_mask_has_char_mask_surfaces() -> void:
	var root: Node3D = _load_mask()
	if root == null:
		return
	var meshes: Array[MeshInstance3D] = _meshes(root)
	assert_true(meshes.size() > 0, "mask has at least one mesh")
	var names: Array[String] = []
	for mi: MeshInstance3D in meshes:
		for s: int in range(mi.mesh.get_surface_count()):
			var m: Material = mi.mesh.surface_get_material(s)
			assert_true(m != null, "%s surface %d has a material" % [mi.name, s])
			if m == null:
				continue
			# placeholder keeps the M_ name; a library material comes from world/materials/char_mask_*
			var ok: bool = m.resource_name.begins_with(MATERIAL_PREFIX) or m.resource_path.begins_with(LIBRARY_PREFIX)
			assert_true(ok, "%s surface %d material %s / %s" % [mi.name, s, m.resource_name, m.resource_path])
			names.append(m.resource_name if m.resource_path.is_empty() else m.resource_path.get_file())
	assert_true(names.size() >= 2, "gold + lacquer (+ inner) surfaces, got %s" % [names])
	root.queue_free()


func test_mask_is_head_sized() -> void:
	var root: Node3D = _load_mask()
	if root == null:
		return
	var box: AABB = _bounds(_meshes(root))
	assert_true(box.size.x >= 0.14 and box.size.x <= 0.30, "width %.3f m in 0.14..0.30" % box.size.x)
	assert_true(box.size.y >= 0.18 and box.size.y <= 0.32, "height %.3f m in 0.18..0.32" % box.size.y)
	assert_true(box.size.z <= 0.30, "depth %.3f m" % box.size.z)
	assert_near(box.get_center().x, 0.0, 0.002, "mask is symmetric about x = 0")
	root.queue_free()


func test_pivot_is_face_centre_and_front_is_minus_z() -> void:
	var root: Node3D = _load_mask()
	if root == null:
		return
	var meshes: Array[MeshInstance3D] = _meshes(root)
	var box: AABB = _bounds(meshes)
	assert_true(box.position.x < 0.0 and box.end.x > 0.0, "origin inside the mask in X")
	assert_true(box.position.y < -0.05 and box.end.y > 0.05, "origin near the eye line, between brow and chin")
	assert_true(box.position.z < 0.0 and box.end.z > 0.0, "origin at eye depth, inside the shell's depth range")
	assert_true(-box.position.z > box.end.z, "the mask extends further to -Z (front) than to +Z")
	var tip: Vector3 = _front_point(meshes)
	assert_true(tip.z < -0.10, "beak tip well in front of the face (z = %.3f)" % tip.z)
	assert_near(tip.x, 0.0, 0.002, "beak tip on the centreline")
	assert_true(tip.y < 0.0, "beak points forward and down (y = %.3f)" % tip.y)
	root.queue_free()
