## Target-side NPC hit rules (A3-06, A3-01b). Owner: ENV A. Called only from NpcBase.take_hit on the
## server (docs/contracts/damage.md: the TARGET applies zone, armor, plates and resistances).
##
## `pre_zone` runs before the HEAD zone multiplier. EnemyDef.params keys (all optional, ◇ data):
## - `explosive_mult` (float, default 1): DamageType.EXPLOSION multiplier (L4.6 Wrecker x1.1).
## - `frontal_plate_arc_deg` (float, 0 = none) + `frontal_plate_mult` (float, default 0): L4.2 TAC Heavy.
##   BULLET hits on BODY/LIMB coming from inside the frontal arc deal x frontal_plate_mult unless the
##   round pierced armor (`info.pierced_armor`, L3.4). The head stays vulnerable.
## - `body_armor_mult` (float, default 1): L3.4 generic body armor. Non-AP BULLET hits on BODY/LIMB
##   (outside a frontal plate) deal x body_armor_mult. Fire, explosions and melee ignore armor.
## - A child node `Weakpoints` with `is_head_armored() -> bool` (L4.6 WreckerArmor) turns HEAD hits
##   into x1 hits (no zone multiplier) while it returns true: `out.head_armored = true`.
## `lethal_intercept` runs when a hit would kill: L4.8 Corpsman revive (CorpsmanBrain.try_revive).
class_name NpcHitRules
extends RefCounted


## Adjusted body amount for `info` on `npc` (before the zone multiplier). May set out flags
## `head_armored`, `frontal_plate`, `armor_reduced`.
static func pre_zone(npc: NpcBase, info: Dictionary, amount: float, out: Dictionary) -> float:
	var p: Dictionary = npc.enemy_def.params if npc.enemy_def != null else {}
	var type: int = int(info.get("type", Enums.DamageType.BULLET))
	var zone: int = int(info.get("zone", Enums.HitZone.BODY))
	if type == Enums.DamageType.EXPLOSION:
		amount *= float(p.get("explosive_mult", 1.0))  # L3.6 / L4.6
	if zone == Enums.HitZone.HEAD:
		var wp: Node = npc.get_node_or_null("Weakpoints")
		if wp != null and wp.has_method(&"is_head_armored") and bool(wp.call(&"is_head_armored")):
			out["head_armored"] = true  # L4.6: headshot-immune until faceplate + visor are gone
		return amount
	if type != Enums.DamageType.BULLET or bool(info.get("pierced_armor", false)):
		return amount  # L3.4: AP rounds, fire and explosions ignore armor
	if zone != Enums.HitZone.BODY and zone != Enums.HitZone.LIMB:
		return amount
	var arc: float = float(p.get("frontal_plate_arc_deg", 0.0))
	if arc > 0.0 and is_from_front(npc, info, arc):
		out["frontal_plate"] = true  # L4.2 TAC Heavy frontal plate
		return amount * float(p.get("frontal_plate_mult", 0.0))
	var armor_mult: float = float(p.get("body_armor_mult", 1.0))
	if armor_mult != 1.0:
		out["armor_reduced"] = true
	return amount * armor_mult


## True when the shot direction of `info` comes from within `arc_deg` around the NPC's facing.
static func is_from_front(npc: NpcBase, info: Dictionary, arc_deg: float) -> bool:
	var dir: Vector3 = info.get("direction", Vector3.ZERO)
	dir.y = 0.0
	if dir.length() < 0.001:
		var pos: Variant = info.get("position")
		if not pos is Vector3:
			return false
		dir = npc.global_position - (pos as Vector3)  # fall back: from the hit point inward
		dir.y = 0.0
		if dir.length() < 0.001:
			return false
	var toward_shooter: Vector3 = -dir.normalized()
	return toward_shooter.dot(npc.look_forward()) >= cos(deg_to_rad(arc_deg * 0.5))


## A hit would kill `npc`: true when something saved it (L4.8 Corpsman revive). The saver sets
## npc.health and out["healed_by"].
static func lethal_intercept(npc: NpcBase, out: Dictionary) -> bool:
	return CorpsmanBrain.try_revive(npc, out)
