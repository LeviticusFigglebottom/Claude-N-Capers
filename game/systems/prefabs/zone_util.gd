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
