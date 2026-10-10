## Helpers shared by the volume prefabs (secure/escape zones, body container, laser grid). Owner: ENV A.
class_name ZoneUtil
extends RefCounted


## Give `area`'s `Shape` CollisionShape3D its own BoxShape3D of `size` with the bottom at the
## area's origin (floor).
static func size_box_zone(area: Area3D, size: Vector3) -> void:
	if area == null:
		Log.error(GameplayPrefab.LOG_CHANNEL, "volume prefab is missing its zone Area3D")
		return
	var cs: CollisionShape3D = area.get_node_or_null(^"Shape") as CollisionShape3D
	if cs == null:
		Log.error(GameplayPrefab.LOG_CHANNEL, "%s: missing `Shape` CollisionShape3D" % area.name)
		return
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)


## True when `pos` lies inside one of `area`'s box/sphere CollisionShape3D children (no physics
## query, so it works the same frame and while the area is not monitoring).
static func contains(area: Area3D, pos: Vector3) -> bool:
	if area == null or not area.is_inside_tree():
		return false
	for c: Node in area.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var local: Vector3 = cs.global_transform.affine_inverse() * pos
		var box: BoxShape3D = cs.shape as BoxShape3D
		if box != null:
			var h: Vector3 = box.size * 0.5
			if absf(local.x) <= h.x and absf(local.y) <= h.y and absf(local.z) <= h.z:
				return true
			continue
		var sph: SphereShape3D = cs.shape as SphereShape3D
		if sph != null and local.length() <= sph.radius:
			return true
	return false
