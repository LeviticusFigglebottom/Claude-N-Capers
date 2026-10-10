## One hit zone of a firing-range target (B1-05, B4-13). Owner: ENV B.
## A StaticBody3D on physics layer 5 "hitboxes" (project.godot). A hitscan that hits it resolves
## the target with get_damage_target() and the zone with get_hit_zone() (Enums.HitZone).
## The same two values are also on node metadata (`damage_target`, `hit_zone`) for duck-typed code.
## `part` tags armor pieces: PART_PLATE (WEAKPOINT face plate, routed to the plate pool by the
## target) and PART_SHIELD, whose hits go to `receiver` (the RangeShield node) instead of the target.
class_name RangeHitbox
extends StaticBody3D

## project.godot 3d_physics/layer_5 = "hitboxes".
const LAYER_HITBOXES: int = 1 << 4
const PART_PLATE: StringName = &"plate"
const PART_SHIELD: StringName = &"shield"

var zone: Enums.HitZone = Enums.HitZone.BODY
var target: RangeTarget = null
## &"" for the silhouette's own zones, else PART_PLATE / PART_SHIELD.
var part: StringName = &""
## Object that receives this hitbox's hits when it is not the target itself (the shield).
var receiver: Node = null


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


## The object whose take_hit receives this hitbox's hits (damage.md: Damage.find_target).
func get_damage_target() -> Node:
	return receiver if receiver != null else target


func get_hit_zone() -> int:
	return int(zone)


func set_active(active: bool) -> void:
	collision_layer = LAYER_HITBOXES if active else 0
