## Hitbox area on physics layer 5 `hitboxes` (docs/contracts/damage.md). Owner: ENV A.
## Routes hits to `target` (an object implementing `take_hit`) with zone `hit_zone` (Enums.HitZone).
## Resolve with `Damage.find_target(collider)` / `Damage.zone_of(collider)`.
class_name Hitbox
extends Area3D

const LAYER_HITBOXES: int = 1 << 4

@export var hit_zone: Enums.HitZone = Enums.HitZone.BODY

## Receiver of hits (NpcBase, crew, range target...). Null = nearest ancestor with take_hit.
var target: Object = null


func _init() -> void:
	collision_layer = LAYER_HITBOXES
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_damage_target() -> Object:
	if target != null and is_instance_valid(target):
		return target
	var n: Node = get_parent()
	while n != null:
		if n.has_method(&"take_hit"):
			return n
		n = n.get_parent()
	return null


func get_hit_zone() -> Enums.HitZone:
	return hit_zone


## Enable/disable hits (a dead NPC's hitboxes stop colliding).
func set_active(on: bool) -> void:
	collision_layer = LAYER_HITBOXES if on else 0
