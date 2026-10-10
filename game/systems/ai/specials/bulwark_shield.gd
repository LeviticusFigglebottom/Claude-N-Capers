## Bulwark ballistic shield (A3-01b L4.5, A3-06 L3.4). Owner: ENV A. Root `Shield` of bulwark_shield.tscn
## (characters.md: separate scene with a `Collision` child). A separate static body on physics layer 2
## `world_dynamic`, so it blocks bullets (CombatTweak.hitscan_mask), crew and NPC movement (doorways),
## and also LOS of crew shots behind it (the server LOS check). NPC LOS ignores shields
## (CombatSystem.has_npc_los). It is carried as a child of its Bulwark and is reparented in place to
## the heist's dynamic root when the Bulwark dies: a dropped shield still blocks (L4.5).
## Hits (docs/contracts/damage.md: the shield is a hit target): BULLET without `info.shield_pierce` and
## MELEE are blocked (amount 0, no damage_applied: nothing was damaged). A shield-piercing BULLET
## (WeaponStats.shield_pierce / weapon.shield_pierce) continues along its direction and hits whatever is
## behind at x CombatTweak.shield_pierce_damage_mult (0.25); FIRE passes at shield_fire_damage_mult.
## The forwarded hit is the single take_hit of that target (the shield itself takes no damage).
## Explosions go around shields (Explosion ignores this group for LOS, PD2 behaviour).
class_name BulwarkShield
extends AnimatableBody3D

signal blocked(info: Dictionary)

const GROUP: StringName = &"bulwark_shield"
const LAYER_WORLD_DYNAMIC: int = 1 << 1

## The carrying Bulwark (null once dropped).
var carrier: NpcBase = null
var dropped: bool = false
var blocked_hits: int = 0
var pierced_hits: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD_DYNAMIC
	collision_mask = 0
	sync_to_physics = false


## Server: attach to `npc` at `local_pos` (the shield never collides with its carrier).
func attach_to(npc: NpcBase, local_pos: Vector3) -> void:
	carrier = npc
	if get_parent() != npc:
		if get_parent() != null:
			get_parent().remove_child(self)
		npc.add_child(self)
	position = local_pos
	rotation = Vector3.ZERO
	npc.add_collision_exception_with(self)


## The Bulwark died: the shield stays where it is (reparented under `new_parent`, transform kept).
func drop(new_parent: Node) -> void:
	if dropped:
		return
	dropped = true
	var xf: Transform3D = global_transform
	if carrier != null and is_instance_valid(carrier):
		carrier.remove_collision_exception_with(self)
	carrier = null
	if new_parent != null and get_parent() != new_parent:
		var was_in_tree: bool = is_inside_tree()
		if get_parent() != null:
			get_parent().remove_child(self)
		new_parent.add_child(self)
		if was_in_tree:
			global_transform = xf


func take_hit(info: Dictionary, attacker_net_id: int = 0) -> Dictionary:
	var out: Dictionary = info.duplicate()
	out["amount"] = 0.0
	out["killed"] = false
	out["blocked_by_shield"] = true
	if not Net.is_authority():
		return out
	var tw: CombatTweak = CombatTweak.data()
	var type: int = int(info.get("type", Enums.DamageType.BULLET))
	var mult: float = 0.0
	if type == Enums.DamageType.FIRE:
		mult = tw.shield_fire_damage_mult
	elif type == Enums.DamageType.BULLET and bool(info.get("shield_pierce", false)):
		mult = tw.shield_pierce_damage_mult
	if mult <= 0.0:
		blocked_hits += 1
		blocked.emit(info)
		return out
	var behind: Dictionary = _trace_behind(info, tw)
	if behind.is_empty():
		return out
	pierced_hits += 1
	var fwd: Dictionary = info.duplicate()
	fwd["amount"] = float(info.get("amount", 0.0)) * mult
	fwd["zone"] = int(behind["zone"])
	fwd["position"] = behind["position"]
	fwd["shield_pierced"] = true
	return CombatSystem.deliver_hit(behind["target"] as Object, fwd, attacker_net_id)


## What the round hits after passing this shield: {target, zone, position} or {}.
func _trace_behind(info: Dictionary, tw: CombatTweak) -> Dictionary:
	var dir: Vector3 = info.get("direction", Vector3.ZERO)
	var pos: Variant = info.get("position")
	if dir.length() < 0.001 or not pos is Vector3 or not is_inside_tree():
		return {}
	dir = dir.normalized()
	var from: Vector3 = (pos as Vector3) - dir * 0.05
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + dir * tw.shield_pierce_reach_m, tw.hitscan_mask)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var col: Object = hit.get("collider")
	var target: Object = CombatSystem.resolve_collider(col)
	if target == null or target == self:
		return {}
	return {"target": target, "zone": Damage.zone_of(col), "position": hit.get("position", from)}
