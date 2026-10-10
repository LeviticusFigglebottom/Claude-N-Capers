## Navigation targets and contract markers of a heist map (heist_map.md §3, level_standards §6).
## Owner: ENV C.
class_name LcTargets
extends RefCounted


## Navigation targets the crew must reach. Each: { name, node, pos, kind, zone }.
## kind: objective | loot_spawn | secure_zone | escape_zone | use_point.
static func collect(ctx: LcContext) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Node in ctx.map.find_children("*", "", true, false):
		if not ctx.is_active(n):
			continue
		if n is MapZone:
			var z: MapZone = n
			if z.kind == MapZone.Kind.SECURE_LOOT or z.kind == MapZone.Kind.ESCAPE:
				var k: String = "secure_zone" if z.kind == MapZone.Kind.SECURE_LOOT else "escape_zone"
				out.append({"name": ctx.node_path(z), "node": z, "pos": zone_target(ctx, z), "kind": k, "zone": z})
		elif n.name == &"UsePoint" and n is Node3D:
			out.append({"name": ctx.node_path(n), "node": n, "pos": (n as Node3D).global_position,
				"kind": "use_point", "zone": null})
		elif n is Node3D and is_loot_spawn(n):
			out.append({"name": ctx.node_path(n), "node": n, "pos": (n as Node3D).global_position,
				"kind": "loot_spawn", "zone": null})
		elif n is Node3D and objective_tag(n) != &"":
			var up: Node3D = n.get_node_or_null("UsePoint") as Node3D
			var pos: Vector3 = up.global_position if up != null else (n as Node3D).global_position
			out.append({"name": ctx.node_path(n), "node": n, "pos": pos, "kind": "objective", "zone": null})
	return out


## Markers that must sit on the navmesh (heist_map.md §3): patrol points, spawns (not sniper
## perches), UsePoints, loot spawns.
static func nav_markers(ctx: LcContext) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in ctx.map.find_children("*", "", true, false):
		if not ctx.is_active(n):
			continue
		if n is PatrolPoint:
			out.append(n as Node3D)
		elif n is SpawnPoint and (n as SpawnPoint).kind != SpawnPoint.Kind.SNIPER_PERCH:
			out.append(n as Node3D)
		elif n.name == &"UsePoint" and n is Node3D:
			out.append(n as Node3D)
		elif n is Node3D and is_loot_spawn(n):
			out.append(n as Node3D)
	return out


static func player_spawns(ctx: LcContext) -> Array[SpawnPoint]:
	var out: Array[SpawnPoint] = []
	for n: Node in ctx.map.find_children("*", "SpawnPoint", true, false):
		var s: SpawnPoint = n
		if s.kind == SpawnPoint.Kind.PLAYER and ctx.is_active(s):
			out.append(s)
	return out


static func is_loot_spawn(n: Node) -> bool:
	if LcUtil.meta_s(n, &"kind") == &"loot_spawn":
		return true
	if n.scene_file_path.get_file().begins_with("loot_spawn"):
		return true
	var sc: Script = n.get_script() as Script
	return sc != null and sc.resource_path.get_file().begins_with("loot_spawn")


static func objective_tag(n: Node) -> StringName:
	if not ("objective_tag" in n):
		return &""
	var v: Variant = n.get("objective_tag")
	return StringName(str(v)) if v != null else &""


## A point on the navmesh inside the zone (falls back to the closest navmesh point to its
## centre). Use zone_target_ok() to know whether it is really inside.
static func zone_target(ctx: LcContext, z: MapZone) -> Vector3:
	for p: Vector3 in LcAreas.floor_grid(z, 0.5, 0.2):
		var c: Vector3 = ctx.nav_closest(p + Vector3.UP * 0.3)
		if LcAreas.contains(z, c, 0.3):
			return c
	return ctx.nav_closest(LcAreas.world_aabb(z).get_center())


static func zone_target_ok(z: MapZone, p: Vector3) -> bool:
	return LcAreas.contains(z, p, 0.3)
