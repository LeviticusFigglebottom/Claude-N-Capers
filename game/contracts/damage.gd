## Hit/damage plumbing shared by every damageable thing (NPCs, crew, range targets, cameras, glass).
## Owner: LEAD. Contract: docs/contracts/damage.md (v1.0).
class_name Damage
extends RefCounted


## Walk up from a physics collider to the object that receives hits: the first node (self or
## ancestor) that has `take_hit`. Hitbox bodies may instead implement `get_damage_target()`.
static func find_target(collider: Object) -> Object:
	var n: Node = collider as Node
	while n != null:
		if n.has_method(&"get_damage_target"):
			var t: Object = n.call(&"get_damage_target")
			if t != null:
				return t
		if n.has_method(&"take_hit"):
			return n
		n = n.get_parent()
	return null


## Hit zone of a collider (hitbox bodies implement `get_hit_zone()`), default BODY.
static func zone_of(collider: Object) -> int:
	if collider != null and collider.has_method(&"get_hit_zone"):
		return int(collider.call(&"get_hit_zone"))
	return Enums.HitZone.BODY


## Canonical DamageInfo dictionary (contracts/events.md). `amount` = BODY damage after weapon
## falloff and attacker-side modifiers, BEFORE zone/armor/resistance (the target applies those).
static func info(amount: float, type: int, zone: int, weapon_id: StringName, position: Vector3,
		direction: Vector3, attacker_net_id: int = 0) -> Dictionary:
	return {
		"amount": amount, "type": type, "zone": zone, "weapon_id": weapon_id,
		"position": position, "direction": direction, "crit": false, "pierced_armor": false,
		"killed": false, "attacker_net_id": attacker_net_id, "headshot_bonus": 1.0,
	}
