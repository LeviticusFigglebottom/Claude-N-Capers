## Bulwark-style shield of a firing-range dummy (B4-13, pd2_fidelity L3.4/L4.5). Owner: ENV B.
## A Node3D in front of the dummy's board holding the shield mesh and its RangeHitbox (part
## PART_SHIELD), whose get_damage_target() is this node. The attacker calls `take_hit` here exactly
## once (damage.md single hit path); the shield forwards it to its RangeTarget as a shield hit, and
## the TARGET applies x shield_pierce_mult (info.shield_pierce) or blocks it, and emits
## damage_applied once. The shield has no health and emits nothing itself.
class_name RangeShield
extends Node3D

var owner_target: RangeTarget = null


func take_hit(info: Dictionary, attacker_net_id: int) -> Dictionary:
	if owner_target == null or not is_instance_valid(owner_target):
		return {}
	return owner_target.take_shield_hit(info, attacker_net_id)
