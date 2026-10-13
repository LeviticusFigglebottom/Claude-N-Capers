## P3: special enemies + TAC Heavy (tools/blender/characters/char_specials.py, docs/contracts/characters.md
## "Specials add"). Every special is an assembled character scene in characters.json (the general scene
## contract is checked by test_scenes.gd) and carries its special nodes with exact names and types:
## Wrecker `Faceplate` / `Visor` / `HeadArmored` MeshInstance3D (A hides them on break), Phantom `Goggles`
## with an emissive material_override, Longshot `LaserOrigin` under HandR/Socket, and the separate Bulwark
## `Shield` scenes with a convex `Collision`.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const SPECIALS: Array[String] = [
	"tac_heavy", "phantom", "stinger", "bulwark", "bulwark_aegis", "wrecker", "longshot", "corpsman", "brandt",
]
const SHIELDS: Array[String] = ["char_bulwark_shield", "char_bulwark_aegis_shield"]
const TRI_BUDGET: int = 35000
const GOGGLE_MAT: String = "res://world/materials/char_goggle_glow.tres"


func _scene(id: String) -> String:
	return "%s%s/%s.tscn" % [Spec.OUT_DIR, id, id]


func _instance(id: String) -> Node3D:
	var packed: PackedScene = load(_scene(id)) as PackedScene
	if packed == null:
		fail("could not load %s (run tools/blender/characters/assemble.sh)" % _scene(id))
		return null
	var node: Node3D = packed.instantiate() as Node3D
	add_child(node)
	return node


static func _tris(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


static func _bounds(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var b: AABB = root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _skinned_mesh(root: Node3D, nm: String, tag: String) -> MeshInstance3D:
	var mi: MeshInstance3D = root.get_node_or_null("Skeleton3D/" + nm) as MeshInstance3D
	assert_true(mi != null, "%s: Skeleton3D/%s is a MeshInstance3D" % [tag, nm])
	if mi == null:
		return null
	assert_eq(String(mi.name), nm, "%s: exact node name %s" % [tag, nm])
	assert_true(mi.skin != null, "%s/%s: skinned (rigid to the head bone)" % [tag, nm])
	assert_true(mi.mesh != null and mi.mesh.get_surface_count() > 0, "%s/%s: has a mesh" % [tag, nm])
	# ENV A finds the nodes by name under its `Visual` root
	assert_true(root.find_child(nm, true, false) == mi, "%s: find_child(%s) resolves" % [tag, nm])
	return mi


func test_specials_are_indexed_at_contract_paths() -> void:
	var by_id: Dictionary = {}
	for e: Dictionary in Spec.read_index():
		by_id[String(e["id"])] = e
	for id: String in SPECIALS:
		assert_true(by_id.has(id), "characters.json lists %s" % id)
		if by_id.has(id):
			assert_eq(String(by_id[id]["scene"]), _scene(id), "%s scene path" % id)
			assert_false(bool(by_id[id]["test"]), "%s is cast, not a fixture" % id)


func test_tri_budget_and_scale() -> void:
	var heights: Dictionary = {}
	for id: String in SPECIALS:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		var tris: int = 0
		for n: Node in root.find_children("*", "MeshInstance3D", true, false):
			if String(n.name) != "CrowdLod":  # D4-01 LOD2 proxy (test_lod.gd)
				tris += _tris((n as MeshInstance3D).mesh)
		assert_true(tris <= TRI_BUDGET, "%s: %d triangles within %d" % [id, tris, TRI_BUDGET])
		var box: AABB = _bounds(root)
		heights[id] = box.end.y
		assert_true(box.end.y > 1.7 and box.end.y < 2.05, "%s: height %.3f" % [id, box.end.y])
		assert_near(box.position.y, 0.0, 0.03, "%s: feet on the floor" % id)
		root.queue_free()
	if heights.has("wrecker"):
		for id: String in heights:
			if id != "wrecker":
				assert_true(float(heights["wrecker"]) > float(heights[id]), "the Wrecker is taller than %s" % id)


func test_wrecker_head_states() -> void:
	var root: Node3D = _instance("wrecker")
	if root == null:
		return
	var face: MeshInstance3D = _skinned_mesh(root, "Faceplate", "wrecker")
	var visor: MeshInstance3D = _skinned_mesh(root, "Visor", "wrecker")
	var armored: MeshInstance3D = _skinned_mesh(root, "HeadArmored", "wrecker")
	if face == null or visor == null or armored == null:
		root.queue_free()
		return
	# stage order front to back: Faceplate in front of the Visor (Godot -Z = forward)
	var fb: AABB = face.get_aabb()
	var vb: AABB = visor.get_aabb()
	assert_true(fb.position.z < vb.position.z, "Faceplate is in front of the Visor")
	assert_true(fb.size.x >= vb.size.x and fb.size.y >= vb.size.y, "Faceplate covers the Visor")
	var paths: Array[String] = []
	for s: int in range(face.mesh.get_surface_count()):
		paths.append(face.mesh.surface_get_material(s).resource_path)
	assert_has(paths, "res://world/materials/char_hazard_yellow.tres", "Faceplate has the hazard-yellow rim")
	# hiding the stages (what WreckerArmor does) leaves the hood + the exposed face
	face.visible = false
	visor.visible = false
	armored.visible = false
	assert_true((root.get_node("Skeleton3D/Headwear") as MeshInstance3D).visible, "hood stays")
	assert_true((root.get_node("Skeleton3D/Body") as MeshInstance3D).visible, "face stays")
	root.queue_free()


func test_phantom_goggles_glow() -> void:
	var root: Node3D = _instance("phantom")
	if root == null:
		return
	var gog: MeshInstance3D = _skinned_mesh(root, "Goggles", "phantom")
	if gog != null:
		var m: BaseMaterial3D = gog.material_override as BaseMaterial3D
		assert_true(m != null, "Goggles.material_override is a BaseMaterial3D (PhantomBrain ramps it)")
		if m != null:
			assert_eq(m.resource_path, GOGGLE_MAT, "library goggle material")
			assert_true(m.emission_enabled, "goggle emission enabled")
			assert_true(m.emission.g > 0.9 and m.emission.r < 0.4 and m.emission.b < 0.6, "green emission %s" % m.emission)
			assert_true(m is ORMMaterial3D and (m as ORMMaterial3D).orm_texture != null, "ORM PBR like the library")
	root.queue_free()


func test_longshot_laser_origin() -> void:
	var root: Node3D = _instance("longshot")
	if root == null:
		return
	var lo: Node3D = root.get_node_or_null("Skeleton3D/HandR/Socket/LaserOrigin") as Node3D
	assert_true(lo is Marker3D, "Skeleton3D/HandR/Socket/LaserOrigin is a Marker3D")
	if lo != null:
		assert_true(lo.position.z < -0.3, "LaserOrigin ahead of the grip along the weapon's -Z")
		assert_true(root.find_child("LaserOrigin", true, false) == lo, "find_child(LaserOrigin) resolves")
	root.queue_free()


func test_shield_scenes() -> void:
	var listed: Array[String] = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Spec.INDEX_PATH))
	if data is Dictionary:
		for e: Variant in (data as Dictionary).get("props", []):
			listed.append(String((e as Dictionary)["scene"]))
	for asset: String in SHIELDS:
		var path: String = Spec.PROP_SCENES[asset]
		assert_has(listed, path, "characters.json props list %s" % path)
		var packed: PackedScene = load(path) as PackedScene
		assert_true(packed != null, "%s loads" % path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		assert_eq(String(root.name), "Shield", "%s root name" % path)
		add_child(root)
		assert_true(root is AnimatableBody3D, "%s root is an AnimatableBody3D" % path)
		if root is CollisionObject3D:
			assert_true(((root as CollisionObject3D).collision_layer & Spec.SHIELD_LAYER) != 0, "world_dynamic layer")
		var col: CollisionShape3D = root.get_node_or_null("Collision") as CollisionShape3D
		assert_true(col != null and col.shape is ConvexPolygonShape3D, "%s: Collision is a convex CollisionShape3D" % path)
		var vis: MeshInstance3D = root.get_node_or_null("Visual") as MeshInstance3D
		assert_true(vis != null and vis.mesh != null, "%s: Visual mesh" % path)
		if vis != null and vis.mesh != null:
			var b: AABB = vis.get_aabb()
			assert_true(b.size.x > 0.55 and b.size.x < 0.8, "%s width %.2f" % [path, b.size.x])
			assert_true(b.size.y > 1.0 and b.size.y < 1.2, "%s height %.2f" % [path, b.size.y])
			assert_true(b.position.z < -0.07, "%s: shield face at -Z, in front of the grip" % path)
			assert_true(b.position.y < 0.0 and b.end.y > 0.0, "%s: pivot (grip) inside the shield height" % path)
			for s: int in range(vis.mesh.get_surface_count()):
				assert_true(vis.mesh.surface_get_material(s) != null, "%s surface %d material" % [path, s])
		root.free()
