## P's PO-3 probe (LEAD 2026-10-20): an assault-event vehicle never has an invisible collider. The turret van's
## movement collider (`Body`, AnimatableBody3D, world_dynamic) sits inside its visual (`Prop`: ENV C's
## prop_turret_van, else the placeholder): visual AABB contains the collider AABB (tolerance TOL_M per side). The
## helicopter has no movement collider (it flies; rappellers leave it by rope).
extends TestCase

const TOL_M: float = 0.15

var _e: Node3D = null


func after_each() -> void:
	if _e != null and is_instance_valid(_e):
		_e.queue_free()
	_e = null
	await wait_frames(1)


static func _mesh_aabb(root: Node3D, space: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b: AABB = space.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _shape_aabb(body: CollisionObject3D, space: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in body.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		var bs: BoxShape3D = cs.shape as BoxShape3D
		if bs == null:
			continue
		var b: AABB = space.global_transform.affine_inverse() * cs.global_transform * AABB(-bs.size * 0.5, bs.size)
		out = b if first else out.merge(b)
		first = false
	return out


func _check_van(e: AssaultTurretVan, what: String) -> void:
	var prop: Node3D = e.get_node_or_null(^"Prop") as Node3D
	assert_true(prop != null, "%s: a visual (Prop)" % what)
	assert_true(e.body != null, "%s: the movement collider (Body)" % what)
	if prop == null or e.body == null:
		return
	var vis: AABB = _mesh_aabb(prop, e)
	var col: AABB = _shape_aabb(e.body, e)
	assert_true(vis.size.length() > 1.0, "%s: the visual has meshes (%s)" % [what, vis])
	var grown: AABB = vis.grow(TOL_M)
	assert_true(grown.encloses(col), "%s: collider %s inside the visual %s" % [what, col, vis])


func test_turret_van_collider_inside_its_visual() -> void:
	_e = AssaultTurretVan.new()
	add_child(_e)
	await wait_frames(1)
	_check_van(_e as AssaultTurretVan, "turret van (%s)" % AssaultEventsTweak.data().van_scene)


func test_turret_van_placeholder_collider_inside_its_visual() -> void:
	_e = AssaultTurretVan.new()
	(_e as AssaultTurretVan).params = {"van_scene": "assault_event/__missing__.tscn"}
	add_child(_e)
	await wait_frames(1)
	_check_van(_e as AssaultTurretVan, "turret van placeholder")
