## D-121 (DET follow-up to PO6-19): the deterministic gameplay position of a corpse. Owner: ENV A.
## The server computes it once, at death, from the pose-at-death root and the killing hit alone (no physics
## simulation): root + flat push direction x RagdollTweak.anchor_offset_m (anchor_strong_offset_m for a
## throwing kill: explosion / point-blank shotgun), stopped short of a wall, snapped onto the navmesh (or the
## floor below). The NPC root moves there at once while its visual keeps its world transform, so the bag-body
## interaction, the corpse stimulus, the director's body despawn LOS and the corpse hitbox (a fixed box lying
## along the push) all read the same position on every run. A later blast on the corpse moves it on the same
## way (blast_push); bullet / melee nudges on a corpse are cosmetic only. The ragdoll (NpcRagdoll) is cosmetic: it moves the
## visual only, never the root or the hitbox.
## Net: NetEntityCodec replicates "ca" = [anchor, flat direction]; clients apply() it (root moved with the
## visual kept in place, the same hitbox), and a dead NPC's replicated transform never drags its visual.
class_name CorpseAnchor
extends RefCounted

## Height above the anchor the wall clamp probes along (m): over kerbs and steps, under tables.
const PROBE_UP_M: float = 0.4
## Floor probe span above / below the anchor (m).
const FLOOR_UP_M: float = 1.0
const FLOOR_DOWN_M: float = 2.0
## Largest navmesh snap height difference (m).
const NAV_SNAP_DY_M: float = 0.6


## Server: compute and apply the anchor of `npc`, killed by `info` (Damage.info, maybe {}). Returns it.
static func settle(npc: NpcBase, info: Dictionary) -> Vector3:
	var res: Array = compute(npc, info)
	apply(npc, res[0] as Vector3, res[1] as Vector3)
	return res[0] as Vector3


## Server: a blast pushing the corpse (Explosion.push_corpses) moves the anchor on along the blast, by
## anchor_strong_offset_m x the blast falloff (the ragdoll throws the visual the same way). Returns it.
static func blast_push(npc: NpcBase, info: Dictionary) -> Vector3:
	var tw: RagdollTweak = RagdollTweak.data()
	var rec: Dictionary = NpcRagdoll.hit_record(npc, info, tw)
	var f: float = float(rec.get("falloff", 1.0)) * tw.corpse_blast_mult
	var res: Array = compute(npc, info, tw.anchor_strong_offset_m * f)
	apply(npc, res[0] as Vector3, res[1] as Vector3)
	return res[0] as Vector3


## [anchor, flat unit direction] for `npc` killed by `info` (pure: physics queries on static / tick-driven
## geometry and the synchronous navmesh only). `dist` >= 0 overrides the offset.
static func compute(npc: NpcBase, info: Dictionary, dist: float = -1.0) -> Array:
	var tw: RagdollTweak = RagdollTweak.data()
	var origin: Vector3 = npc.global_position
	var dir: Vector3 = push_direction(npc, info)
	if dist < 0.0:
		dist = tw.anchor_strong_offset_m if strong_kill(npc, info, tw) else tw.anchor_offset_m
	var target: Vector3 = origin + dir * dist
	if not npc.is_inside_tree():
		return [target, dir]
	var space: PhysicsDirectSpaceState3D = npc.get_world_3d().direct_space_state
	var up: Vector3 = Vector3.UP * PROBE_UP_M
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin + up, target + up, NpcBase.MASK_WORLD)
	q.exclude = [npc.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		var reach: float = maxf(origin.distance_to((hit["position"] as Vector3) - up) - tw.anchor_wall_margin_m, 0.0)
		target = origin + dir * minf(reach, dist)
	target = _ground(npc, space, target, tw)
	return [target, dir]


## Flat unit push direction of the killing hit: away from a blast centre, else the hit direction, else the
## NPC's forward (a fall forward).
static func push_direction(npc: NpcBase, info: Dictionary) -> Vector3:
	var d: Vector3 = Vector3.ZERO
	if int(info.get("type", -1)) == Enums.DamageType.EXPLOSION and info.has("blast_center"):
		d = npc.global_position - (info["blast_center"] as Vector3)
	if Vector2(d.x, d.z).length() < 0.01:
		d = info.get("direction", Vector3.ZERO)
	d.y = 0.0
	if d.length() < 0.01:
		d = -npc.global_basis.z
		d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD


## True for the kills that throw the body (they start the ragdoll at once): explosions, a shotgun within
## shotgun_range_m, or a single hit at least min_impulse.
static func strong_kill(npc: NpcBase, info: Dictionary, tw: RagdollTweak) -> bool:
	var t: int = int(info.get("type", Enums.DamageType.BULLET))
	if t == Enums.DamageType.EXPLOSION:
		return true
	if t != Enums.DamageType.BULLET:
		return false
	var cls: StringName = ShotFx.npc_weapon_class(StringName(info.get("weapon_id", &"")))
	if cls == &"shotgun":
		return NpcRagdoll._range_of(npc, info) <= tw.shotgun_range_m
	return float(tw.bullet_impulse_by_class.get(cls, tw.bullet_impulse_default)) >= tw.min_impulse


static func _ground(npc: NpcBase, space: PhysicsDirectSpaceState3D, p: Vector3, tw: RagdollTweak) -> Vector3:
	var nav: RID = npc.get_world_3d().navigation_map
	if nav.is_valid() and NavigationServer3D.map_get_iteration_id(nav) > 0 \
			and not NavigationServer3D.map_get_regions(nav).is_empty():
		var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, p)
		if Vector2(c.x - p.x, c.z - p.z).length() <= tw.anchor_nav_snap_m and absf(c.y - p.y) <= NAV_SNAP_DY_M:
			return c
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * FLOOR_UP_M,
		p + Vector3.DOWN * FLOOR_DOWN_M, NpcBase.MASK_WORLD)
	q.exclude = [npc.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return hit["position"] as Vector3 if not hit.is_empty() else p


## Every peer: put `npc`'s root on `anchor` (its visual keeps its world transform) and its corpse hitbox on the
## fixed box lying along `dir` centred on the anchor.
static func apply(npc: NpcBase, anchor: Vector3, dir: Vector3) -> void:
	npc.corpse_anchor = anchor
	npc.corpse_dir = dir
	move_root(npc, anchor)
	var tw: RagdollTweak = RagdollTweak.data()
	var z: Vector3 = Vector3(dir.x, 0.0, dir.z)
	z = z.normalized() if z.length() > 0.001 else Vector3.FORWARD
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	var box: Vector3 = tw.corpse_box_default
	npc.set_corpse_hitbox(Transform3D(Basis(x, Vector3.UP, z), anchor + Vector3.UP * (box.y * 0.5)), box)


## Move `npc`'s root to `pos`, its visual staying where it is in the world.
static func move_root(npc: NpcBase, pos: Vector3) -> void:
	if npc.global_position.is_equal_approx(pos):
		return
	var vis: Node3D = npc.visual_root
	var vg: Transform3D = vis.global_transform if vis != null and vis.is_inside_tree() else Transform3D.IDENTITY
	npc.global_position = pos
	if vis != null and vis.is_inside_tree():
		vis.global_transform = vg


## Net: the replicated anchor ([] = none yet).
static func net_value(npc: NpcBase) -> Array:
	return [npc.corpse_anchor, npc.corpse_dir] if npc.corpse_anchor != Vector3.INF else []
