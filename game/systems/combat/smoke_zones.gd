## D-163 smoke clouds (Sicario's Smoke Bomb, ThrownItem KIND_SMOKE). Owner: ENV A. Read-only queries over the live
## clouds (ThrownItems of kind smoke with time left), so they exist on every peer the item replicates to. The damage
## rules are server-side: CrewHealth gives crew inside an extra crew_bullet_avoid chance to avoid a bullet (a dodge),
## NpcGunner multiplies the hit chance of enemies inside by npc_accuracy_mult. No LOS blocking (PD2).
class_name SmokeZones
extends RefCounted

const CREW_BULLET_AVOID: float = 0.5
const NPC_ACCURACY_MULT: float = 0.5
## Vertical reach of a cloud above / below its centre (m).
const HALF_HEIGHT_M: float = 2.5


## The live smoke clouds in `ctx`'s tree.
static func clouds(ctx: Node) -> Array[ThrownItem]:
	var out: Array[ThrownItem] = []
	if ctx == null or not ctx.is_inside_tree():
		return out
	for n: Node in ctx.get_tree().get_nodes_in_group(ThrownItem.GROUP):
		var t: ThrownItem = n as ThrownItem
		if t != null and t.kind() == ThrownItem.KIND_SMOKE and t.pool_left > 0.0 and not t.is_queued_for_deletion():
			out.append(t)
	return out


## The cloud `pos` stands in (null when none).
static func cloud_at(ctx: Node, pos: Vector3) -> ThrownItem:
	for t: ThrownItem in clouds(ctx):
		var d: Vector3 = pos - t.global_position
		if Vector2(d.x, d.z).length() <= t.smoke_radius() and absf(d.y) <= HALF_HEIGHT_M:
			return t
	return null


static func in_smoke(n: Node3D) -> bool:
	return n != null and cloud_at(n, n.global_position) != null


## Server, CrewHealth: `crew` avoids this bullet thanks to the smoke it stands in (a roll on GameRng &"smoke").
static func crew_avoids(crew: Node3D) -> bool:
	var t: ThrownItem = cloud_at(crew, crew.global_position) if crew != null else null
	if t == null:
		return false
	return GameRng.stream(&"smoke").randf() < float(t.params.get("crew_bullet_avoid", CREW_BULLET_AVOID))


## Server, NpcGunner: hit-chance multiplier of `npc` (npc_accuracy_mult inside a cloud, else 1).
static func npc_accuracy_mult(npc: Node3D) -> float:
	var t: ThrownItem = cloud_at(npc, npc.global_position) if npc != null else null
	return float(t.params.get("npc_accuracy_mult", NPC_ACCURACY_MULT)) if t != null else 1.0
