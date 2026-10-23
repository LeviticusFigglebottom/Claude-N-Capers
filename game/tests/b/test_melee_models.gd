## P5 melee roster: every MeleeDef ships a model (tools/blender/weapons/melee_roster.py; the folding knife has its own
## test) that follows the item contract (visual_slots.md "Items", D-069): origin on the handle axis 20 mm below the top
## of the fist, handle / head along +Y, edge or striking face toward -Z. Meters.
extends TestCase

## The longest models (bat, axe, sledgehammer) reach furthest (MeleeDef.range_m); knives and hammers stay short.
const LONG_M: float = 0.7
const SHORT_M: float = 0.35


func before_all() -> void:
	ContentDB.clear_cache()


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
		var b: AABB = (root.global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## The AABB of `mi`'s own mesh (no children: guards and rivets hang off the handle), in `root`'s frame.
func _own(root: Node3D, mi: MeshInstance3D) -> AABB:
	return (root.global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb()


func _each(fn: Callable) -> void:
	for r: Variant in ContentDB.all_melees():
		var d: MeleeDef = r as MeleeDef
		assert_true(d.model != null, "%s has a model" % d.id)
		if d.model == null:
			continue
		var n: Node3D = d.model.instantiate() as Node3D
		add_child(n)
		await fn.call(d, n)
		n.queue_free()


func test_models_have_materials_and_budget() -> void:
	await _each(func(d: MeleeDef, n: Node3D) -> void:
		var tris: int = 0
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s: int in (mesh.get_surface_count() if mesh != null else 0):
				tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				assert_true(mesh.surface_get_material(s) != null, "%s %s surface %d material" % [d.id, mi.name, s])
		assert_true(tris > 150 and tris < 6000, "%s: LOD0 triangles %d" % [d.id, tris])
		assert_true(n.find_child("Handle", true, false) is MeshInstance3D, "%s: Handle mesh" % d.id)
		assert_true(n.find_child("Head", true, false) is MeshInstance3D or n.find_child("Blade", true, false) != null,
				"%s: Head (or the knife's Blade) mesh" % d.id))


func test_models_follow_the_item_contract() -> void:
	await _each(func(d: MeleeDef, n: Node3D) -> void:
		var box: AABB = _bounds(n)
		assert_true(box.position.y < -0.06 and box.position.y > -0.16, "%s: butt 6-16 cm below the fist origin: %s" % [d.id, box])
		assert_true(box.end.y > 0.08, "%s: extends up from the fist: %s" % [d.id, box])
		assert_true(box.position.x < 0.0 and box.end.x > 0.0, "%s: origin centred in thickness" % d.id)
		assert_true(box.position.z < 0.0 and box.end.z > 0.0, "%s: origin on the handle axis" % d.id)
		var handle: AABB = _own(n, n.find_child("Handle", true, false) as MeshInstance3D)
		assert_true(handle.position.y < -0.06 and handle.size.x < 0.06 and handle.size.z < 0.06,
				"%s: the handle fills the fist: %s" % [d.id, handle])
		var head_node: Node3D = (n.find_child("Head", true, false) if n.find_child("Head", true, false) != null
				else n.find_child("Blade", true, false)) as Node3D
		var head: AABB = _bounds(n, head_node)
		assert_true(head.get_center().y > 0.04, "%s: the head / blade sits above the fist: %s" % [d.id, head])
		# blades: the cutting edge toward -Z, so the blade reaches at least as far to -Z as to +Z (a hammer's claw
		# rightly outreaches its face)
		if d.anim_set != &"melee_blunt":
			assert_true(-head.position.z >= head.end.z - 0.002, "%s: edge side (-Z) is the long side: %s" % [d.id, head])
		var length: float = box.size.y
		if length > LONG_M:
			assert_true(d.range_m >= 2.0, "%s (%.2f m long) reaches 2 m+ (%.2f)" % [d.id, length, d.range_m])
		elif length < SHORT_M:
			assert_true(d.range_m <= 1.8, "%s (%.2f m long) reaches 1.8 m at most (%.2f)" % [d.id, length, d.range_m]))
