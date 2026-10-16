## Hitbox area on physics layer 5 `hitboxes` (docs/contracts/damage.md). Owner: ENV A.
## Routes hits to `target` (an object implementing `take_hit`) with zone `hit_zone` (Enums.HitZone).
## Resolve with `Damage.find_target(collider)` / `Damage.zone_of(collider)`.
class_name Hitbox
extends Area3D

const LAYER_HITBOXES: int = 1 << 4

@export var hit_zone: Enums.HitZone = Enums.HitZone.BODY
## D-123: A-side limb sub-zone (NpcLimbHitboxes.SUB_*: shoulder_l / shoulder_r / leg_l / leg_r) of a limb box, &""
## for any other box. A limb box keeps `hit_zone` BODY (damage, armor, headshot and stat rules see a body hit); the
## sub-zone only travels as `limb` in the hit claim / DamageInfo for the AnimDriver hit-zone flinch.
@export var limb: StringName = &""

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


## D-123: the limb sub-zone (&"" = not a limb box).
func get_hit_limb() -> StringName:
	return limb


## D-123: the limb sub-zone of a physics collider (&"" for anything but a limb Hitbox).
static func limb_of(collider: Object) -> StringName:
	var hb: Hitbox = collider as Hitbox
	return hb.limb if hb != null else &""


## Enable/disable hits (a dead NPC's hitboxes stop colliding).
func set_active(on: bool) -> void:
	collision_layer = LAYER_HITBOXES if on else 0
