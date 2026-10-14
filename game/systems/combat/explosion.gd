## Explosions (A3-06, pd2_fidelity L3.6). Owner: ENV A. Server only. Used by C4 (safes, breaching),
## grenades and launchers (P3+), and NPC explosives.
##   Explosion.apply(ctx, position, radius, damage, attacker_net_id, weapon_id) -> Array[Dictionary]
## - Every damageable target whose centre is within `radius` and in LOS of the blast gets ONE
##   `take_hit` (docs/contracts/damage.md) with DamageType.EXPLOSION, zone BODY and
##   amount = damage x (1 - d/r)^CombatTweak.explosion_falloff_pow (PD2: ^0.1).
## - Targets: NPCs (group G.NPC, alive), crew members (G.CREW) and anything with take_hit on
##   CombatTweak.explosion_target_mask (hitboxes, cameras, glass, range dummies...), deduplicated.
## - LOS: a ray on CombatTweak.explosion_los_mask from the blast to the target centre, ignoring the
##   target and Bulwark shields (PD2: explosions go around shields, so a Bulwark takes full damage).
## - Crew blasts (attacker is a CrewController) never damage crew members (PD2: no friendly fire);
##   NPC / world blasts (attacker 0 or an NPC) do. Explosion damage multipliers (Wrecker x1.1) are
##   applied by the target (NpcHitRules, EnemyDef.params.explosive_mult). No suppression threat.
## Returns the final DamageInfo of each target hit (with `victim` = the target object).
class_name Explosion
extends RefCounted


static func apply(ctx: Node3D, position: Vector3, radius: float, damage: float, attacker_net_id: int = 0,
		weapon_id: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if ctx == null or not ctx.is_inside_tree() or not Net.is_authority() or radius <= 0.0:
		return out
	ShotFx.explosion(ctx, position, radius, ShotFx.explosion_kind(weapon_id))  # PO-8: explosion_fx + relayed
	var tw: CombatTweak = CombatTweak.data()
	var crew_attack: bool = Ids.lookup(attacker_net_id) is CrewController
	for target: Object in targets_in_sphere(ctx, position, radius, tw):
		if crew_attack and target is CrewController:
			continue
		var center: Vector3 = _center(target, position)
		var d: float = center.distance_to(position)
		if d > radius or not blast_los(ctx, position, center, target, tw):
			continue
		var amount: float = damage_at(damage, d, radius)
		if amount <= 0.0:
			continue
		var dir: Vector3 = (center - position).normalized() if d > 0.001 else Vector3.DOWN
		var info: Dictionary = Damage.info(amount, Enums.DamageType.EXPLOSION, Enums.HitZone.BODY,
			weapon_id, center, dir, attacker_net_id)
		var res: Dictionary = CombatSystem.deliver_hit(target, info, attacker_net_id).duplicate()
		res["victim"] = target
		out.append(res)
	return out


## L3.6: damage x (1 - d/r)^pow, 0 outside the radius.
static func damage_at(damage: float, distance: float, radius: float) -> float:
	if radius <= 0.0 or distance >= radius:
		return 0.0
	return damage * pow(clampf(1.0 - distance / radius, 0.0, 1.0), CombatTweak.data().explosion_falloff_pow)


## Damageable targets around `position` (NPCs alive, hittable crew, hitboxes on explosion_target_mask).
static func targets_in_sphere(ctx: Node3D, position: Vector3, radius: float, tw: CombatTweak) -> Array[Object]:
	var found: Array[Object] = []
	for n: Node in ctx.get_tree().get_nodes_in_group(G.NPC):
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.alive and CombatSystem.target_center(npc).distance_to(position) <= radius + 1.0:
			found.append(npc)
	for n: Node in ctx.get_tree().get_nodes_in_group(G.CREW):
		var c: CrewController = n as CrewController
		if c != null and CombatSystem.can_take_hit(c) and not found.has(c):
			found.append(c)
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, position)
	q.collision_mask = tw.explosion_target_mask
	q.collide_with_areas = true
	q.collide_with_bodies = true
	for hit: Dictionary in ctx.get_world_3d().direct_space_state.intersect_shape(q, 64):
		var t: Object = CombatSystem.resolve_collider(hit.get("collider"))
		if t == null or t is BulwarkShield or t is WreckerArmor or found.has(t):
			continue
		var npc_t: NpcBase = t as NpcBase
		if npc_t != null and not npc_t.alive:
			continue
		found.append(t)
	return found


static func _center(target: Object, fallback: Vector3) -> Vector3:
	var body: CharacterBody3D = target as CharacterBody3D
	if body != null:
		return CombatSystem.target_center(body)
	var n3: Node3D = target as Node3D
	return n3.global_position if n3 != null else fallback


static func blast_los(ctx: Node3D, from: Vector3, to: Vector3, target: Object, tw: CombatTweak) -> bool:
	var seg: Vector3 = to - from
	if seg.length() < 0.05:
		return true
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to - seg.normalized() * 0.05,
		tw.explosion_los_mask)
	var ex: Array[RID] = []
	var co: CollisionObject3D = target as CollisionObject3D
	if co != null:
		ex.append(co.get_rid())
	for s: Node in ctx.get_tree().get_nodes_in_group(BulwarkShield.GROUP):
		var sb: CollisionObject3D = s as CollisionObject3D
		if sb != null:
			ex.append(sb.get_rid())
	var parent_co: CollisionObject3D = (target as Node).get_parent() as CollisionObject3D if target is Node else null
	if parent_co != null:
		ex.append(parent_co.get_rid())
	q.exclude = ex
	return ctx.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
