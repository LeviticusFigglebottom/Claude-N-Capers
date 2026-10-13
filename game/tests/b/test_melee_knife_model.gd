## PO-4: the default melee (melee.folding_knife) ships a model, built by tools/blender/weapons/folding_knife.py.
## Item contract (visual_slots.md "Items", D-069): origin on the handle axis 20 mm below the top of the fist,
## handle along +Y, cutting edge toward -Z. Meters.
extends TestCase

const KNIFE: StringName = &"melee.folding_knife"


func before_all() -> void:
	ContentDB.clear_cache()


## Union of the AABBs of `under` (default `root`) and its mesh descendants, in `root`'s local frame.
func _bounds(root: Node3D, under: Node3D = null) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var base: Node3D = under if under != null else root
	var nodes: Array[Node] = base.find_children("*", "MeshInstance3D", true, false)
	if base is MeshInstance3D:
		nodes.append(base)
	for n: Node in nodes:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		var b: AABB = xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _instance() -> Node3D:
	var def: MeleeDef = ContentDB.melee(KNIFE)
	if def == null or def.model == null:
		return null
	var n: Node3D = def.model.instantiate() as Node3D
	add_child(n)
	return n


func test_knife_def_has_model_with_geometry() -> void:
	var def: MeleeDef = ContentDB.melee(KNIFE)
	assert_true(def != null, "MeleeDef loads")
	assert_true(def != null and def.model != null, "MeleeDef.model is set")
	var knife: Node3D = _instance()
	assert_true(knife != null, "model instantiates as a Node3D")
	if knife == null:
		return
	var tris: int = 0
	for n: Node in knife.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for s: int in (mesh.get_surface_count() if mesh != null else 0):
			tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			assert_true(mesh.surface_get_material(s) != null, "%s surface %d has a material" % [n.name, s])
	assert_true(tris > 500 and tris < 6000, "modest LOD0 triangle count: %d" % tris)
	for part: String in ["Blade", "Handle", "Frame"]:
		assert_true(knife.find_child(part, true, false) is MeshInstance3D, "%s mesh" % part)
	knife.queue_free()


func test_knife_follows_item_contract() -> void:
	var knife: Node3D = _instance()
	if knife == null:
		assert_true(false, "model instantiates")
		return
	var box: AABB = _bounds(knife)
	assert_true(box.size.y > 0.18 and box.size.y < 0.22, "18-22 cm long along +Y: %s" % box)
	assert_true(box.size.x < 0.02 and box.size.z < 0.04, "slim across X / Z: %s" % box)
	# origin inside the handle: the butt is 6-11 cm below it, the handle surrounds it in X and Z
	assert_true(box.position.y < -0.06 and box.position.y > -0.11, "butt 6-11 cm below the origin: %s" % box)
	assert_true(box.position.x < 0.0 and box.end.x > 0.0, "origin centred in thickness")
	assert_true(box.position.z < -0.008 and box.end.z > 0.008, "origin on the handle axis (Z)")
	var blade_node: Node3D = knife.find_child("Blade", true, false) as Node3D
	var blade: AABB = _bounds(knife, blade_node)
	assert_true(blade.end.y > 0.09, "blade reaches beyond the fist along +Y: %s" % blade)
	assert_true(blade.get_center().y > 0.04, "blade mostly above the handle: %s" % blade)
	var handle: AABB = _bounds(knife, knife.find_child("Handle", true, false) as Node3D)
	assert_true(handle.end.y < 0.035 and handle.end.y > 0.02, "handle tops out just above the fist: %s" % handle)
	# cutting edge toward -Z: the blade's belly reaches further to -Z than its spine reaches to +Z
	assert_true(-blade.position.z > blade.end.z, "edge side (-Z) is the wide side: %s" % blade)
	knife.queue_free()
