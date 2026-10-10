## D1-02: outfit characters (tools/blender/characters/char_*.py). Run after `godot --import`.
## Each character glb has the shared 52-bone rig_humanoid Skeleton3D, only skinned meshes
## (Body, Hair, Outfit, Gear, Headwear) with no blend shapes (bodies are baked), every surface
## mapped to a library material res://world/materials/*.tres, and a plausible standing height.
extends TestCase

const CHARACTERS: Array[String] = [
	"char_security_officer",
	"char_security_officer_b",
	"char_civilian_customer_a",
	"char_civilian_customer_b",
	"char_civilian_sales",
	"char_civilian_jeweler",
	"char_civilian_manager",
	"char_patrol_officer",
	"char_tac_light",
	"char_crew_body",
	"char_crew_body_b",
]
const BONES: int = 52
const MIN_HEIGHT: float = 1.6
const MAX_HEIGHT: float = 2.0
const TRI_BUDGET: int = 35000
const ALLOWED_MESHES: Array[String] = ["Body", "Hair", "Outfit", "Gear", "Headwear"]


func _glb(id: String) -> String:
	return "res://assets/characters/%s/%s.glb" % [id, id]


func _load(id: String) -> Node3D:
	var packed: PackedScene = load(_glb(id)) as PackedScene
	if packed == null:
		fail("could not load %s (run godot --import first)" % _glb(id))
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _tris(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func test_skeleton_is_rig_humanoid() -> void:
	for id: String in CHARACTERS:
		var root: Node3D = _load(id)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node_or_null("rig_humanoid/Skeleton3D") as Skeleton3D
		assert_true(skel != null, "%s: Skeleton3D at rig_humanoid/Skeleton3D" % id)
		if skel != null:
			assert_eq(skel.get_bone_count(), BONES, "%s: bone count" % id)
			for b: String in ["hips", "chest", "head", "hand.R", "hand.L", "foot.L", "toe.R"]:
				assert_true(skel.find_bone(b) >= 0, "%s: bone %s" % [id, b])
		root.queue_free()


func test_meshes_are_skinned_without_blend_shapes() -> void:
	for id: String in CHARACTERS:
		var root: Node3D = _load(id)
		if root == null:
			continue
		var meshes: Array[MeshInstance3D] = _meshes(root)
		var names: Array[String] = []
		var tris: int = 0
		for mi: MeshInstance3D in meshes:
			names.append(String(mi.name))
			assert_has(ALLOWED_MESHES, String(mi.name), "%s: unexpected mesh %s" % [id, mi.name])
			assert_true(mi.get_parent() is Skeleton3D, "%s/%s: child of the Skeleton3D" % [id, mi.name])
			assert_true(mi.skin != null, "%s/%s: has a skin" % [id, mi.name])
			for s: int in range(mi.mesh.get_surface_count()):
				var bones: Variant = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_BONES]
				assert_true(bones != null and (bones as PackedInt32Array).size() > 0,
						"%s/%s surface %d: bone weights" % [id, mi.name, s])
			var am: ArrayMesh = mi.mesh as ArrayMesh
			if am != null:
				assert_eq(am.get_blend_shape_count(), 0, "%s/%s: no blend shapes (baked)" % [id, mi.name])
			tris += _tris(mi.mesh)
		for need: String in ["Body", "Outfit"]:
			assert_has(names, need, "%s: has %s" % [id, need])
		assert_true(tris <= TRI_BUDGET, "%s: %d triangles within %d" % [id, tris, TRI_BUDGET])
		root.queue_free()


func test_every_surface_uses_a_library_material() -> void:
	for id: String in CHARACTERS:
		var root: Node3D = _load(id)
		if root == null:
			continue
		for mi: MeshInstance3D in _meshes(root):
			for s: int in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(s)
				assert_true(m != null, "%s/%s surface %d has a material" % [id, mi.name, s])
				if m == null:
					continue
				var path: String = m.resource_path
				var ok: bool = path.begins_with("res://world/materials/") and path.ends_with(".tres")
				assert_true(ok, "%s/%s surface %d: %s (%s)" % [id, mi.name, s, path, m.resource_name])
		root.queue_free()


func test_height_and_facing_are_plausible() -> void:
	for id: String in CHARACTERS:
		var root: Node3D = _load(id)
		if root == null:
			continue
		var box: AABB = AABB()
		var first: bool = true
		for mi: MeshInstance3D in _meshes(root):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var h: float = box.end.y
		assert_true(h >= MIN_HEIGHT and h <= MAX_HEIGHT, "%s: height %.3f m in %.1f..%.1f" % [id, h, MIN_HEIGHT, MAX_HEIGHT])
		assert_true(box.position.y > -0.02 and box.position.y < 0.02, "%s: feet at y = 0 (%.3f)" % [id, box.position.y])
		assert_near(box.get_center().x, 0.0, 0.08, "%s: roughly centred in x" % id)
		var skel: Skeleton3D = root.get_node_or_null("rig_humanoid/Skeleton3D") as Skeleton3D
		if skel != null:
			var toe: Vector3 = skel.get_bone_global_rest(skel.find_bone("toe.R")).origin
			var heel: Vector3 = skel.get_bone_global_rest(skel.find_bone("foot.R")).origin
			assert_true(toe.z < heel.z, "%s: faces -Z (toe in front of the ankle)" % id)
		root.queue_free()
