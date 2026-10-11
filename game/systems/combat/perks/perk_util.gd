## Spatial / crew queries shared by the perk components (QB-62). Owner: ENV A. Server-side.
class_name PerkUtil
extends RefCounted


## Living hostile NPCs (G.ENEMY) within `radius` m of `pos` (`ctx` = any node in the heist tree).
static func enemies_near(ctx: Node, pos: Vector3, radius: float) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	if ctx == null or not ctx.is_inside_tree() or radius <= 0.0:
		return out
	var r2: float = radius * radius
	for n: Node in ctx.get_tree().get_nodes_in_group(G.ENEMY):
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.alive and npc.global_position.distance_squared_to(pos) <= r2:
			out.append(npc)
	return out


## Living hostile NPCs within `radius` m of `crew`.
static func enemies_near_crew(crew: Node3D, radius: float) -> Array[NpcBase]:
	return enemies_near(crew, crew.global_position, radius) if crew != null else [] as Array[NpcBase]


## Crew members of `crew`'s heist (including `crew` itself), CUSTODY excluded when `active_only`.
static func crew_of(crew: Node, active_only: bool = false) -> Array[CrewController]:
	var out: Array[CrewController] = []
	var rt: HeistRuntime = HeistRuntime.of(crew) if crew != null else null
	if rt == null:
		var c: CrewController = crew as CrewController
		if c != null:
			out.append(c)
		return out
	for c: CrewController in rt.crew_members():
		if not active_only or c.crew_state != Enums.CrewState.CUSTODY:
			out.append(c)
	return out


## True when another (non-custody) crew member is within `radius` m.
static func near_teammate(crew: CrewController, radius: float) -> bool:
	for c: CrewController in crew_of(crew, true):
		if c != crew and c.global_position.distance_to(crew.global_position) <= radius:
			return true
	return false


## Standing still (horizontal speed under PerkTweak.still_speed_threshold) or crouched.
static func still_or_crouched(crew: CrewController) -> bool:
	if crew == null:
		return false
	var v: Vector3 = crew.velocity
	return crew.crouched or Vector2(v.x, v.z).length() < PerkTweak.data().still_speed_threshold


static func armor_id(crew: CrewController) -> StringName:
	var l: Loadout = crew.loadout if crew != null else null
	if l != null and l.armor != &"":
		return l.armor
	return CombatTweak.data().default_armor


## Hostages the crew holds (TeamModifiers.hostage_count: the CivilianTargets count).
static func hostage_count(ctx: Node) -> int:
	return TeamModifiers.hostage_count(ctx)


## Membership test for an id list from a PARAMS dict (Array of StringName or String).
static func id_in(list: Variant, id: StringName) -> bool:
	if not list is Array:
		return false
	for v: Variant in list as Array:
		if StringName(str(v)) == id:
			return true
	return false
