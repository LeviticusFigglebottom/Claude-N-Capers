## One hit zone of a firing-range target (B1-05). Owner: ENV B.
## A StaticBody3D on physics layer 5 "hitboxes" (project.godot). A hitscan that hits it resolves
## the target with get_damage_target() and the zone with get_hit_zone() (Enums.HitZone).
## The same two values are also on node metadata (`damage_target`, `hit_zone`) for duck-typed code.
class_name RangeHitbox
extends StaticBody3D

## project.godot 3d_physics/layer_5 = "hitboxes".
const LAYER_HITBOXES: int = 1 << 4

var zone: Enums.HitZone = Enums.HitZone.BODY
var target: RangeTarget = null


func _init() -> void:
	collision_layer = LAYER_HITBOXES
	collision_mask = 0


func setup(owner_target: RangeTarget, hit_zone: Enums.HitZone, size: Vector3) -> void:
	target = owner_target
	zone = hit_zone
	set_meta(&"damage_target", owner_target)
	set_meta(&"hit_zone", int(hit_zone))
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)


func get_damage_target() -> RangeTarget:
	return target


func get_hit_zone() -> int:
	return int(zone)


func set_active(active: bool) -> void:
	collision_layer = LAYER_HITBOXES if active else 0
