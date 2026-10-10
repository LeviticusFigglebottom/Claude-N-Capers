## One dressing prop as seen by levelcheck: bounds, colliders, metadata. Owner: ENV C.
## Conventions (metas/groups): tools/levelcheck/README.md §Conventions.
class_name LcProp
extends RefCounted

var node: Node3D
## Root global transform (may include scale).
var xform: Transform3D = Transform3D.IDENTITY
## Merged bounds of the prop's geometry (or its collision shapes) in root-local space.
var local_aabb: AABB = AABB()
var global_aabb: AABB = AABB()
## LcGeom.obb() of local_aabb.
var obb: Dictionary = {}
var has_geometry: bool = false
var has_visuals: bool = false
var kind: StringName = &""
## &"" (rests on a support), &"wall" or &"ceiling".
var mount: StringName = &""
var is_support: bool = false
var is_door: bool = false
var is_window: bool = false
## Collision bodies belonging to the prop (StaticBody3D etc., not Areas).
var bodies: Array[CollisionObject3D] = []
var rids: Array[RID] = []
## { "shape": Shape3D, "xf": Transform3D } for every enabled CollisionShape3D of the prop.
var shapes: Array[Dictionary] = []
## Enclosing VariantSlot (or null).
var slot: VariantSlot = null


func center() -> Vector3:
	return obb["c"]


func bottom_y() -> float:
	return global_aabb.position.y


func has_colliders() -> bool:
	return not shapes.is_empty()


## Footprint sample points (world) on the prop's bottom face: centre + 4 inset corners.
func footprint_samples(inset: float = 0.15) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var c: Vector3 = local_aabb.get_center()
	var h: Vector3 = local_aabb.size * 0.5 * (1.0 - inset)
	var y: float = local_aabb.position.y
	out.append(xform * Vector3(c.x, y, c.z))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			out.append(xform * Vector3(c.x + sx * h.x, y, c.z + sz * h.z))
	return out
