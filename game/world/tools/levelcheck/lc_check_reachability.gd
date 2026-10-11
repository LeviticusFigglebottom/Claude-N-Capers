## reachability: every objective / loot / zone / UsePoint and every NPC marker is reachable on
## the navmesh from every PLAYER spawn, for each variant option (--variants=all).
## Variant handling (README §Variants): the navmesh is baked once; slots that change navigation
## carry their own NavigationRegion3D / NavigationLink3D children, which are enabled only while
## the slot is active. Doors count as open (players can always breach them).
class_name LcCheckReachability
extends LcCheck

const END_H_TOL: float = 0.3
const END_V_TOL: float = 0.5


func _init() -> void:
	id = &"reachability"
	title = "Reachability (per variant)"


## Baseline config: for every slot group, only the first slot (by slot_id) is active.
static func baseline(ctx: LcContext) -> Dictionary:
	var groups: Dictionary = groups_of(ctx)
	var active: Dictionary = {}
	for g: StringName in groups.keys():
		var slots: Array = groups[g]
		for i: int in range(slots.size()):
			active[slots[i]] = i == 0
	return active


## { group: [VariantSlot sorted by slot_id] }
static func groups_of(ctx: LcContext) -> Dictionary:
	var groups: Dictionary = {}
	for s: VariantSlot in ctx.variant_slots():
		if not groups.has(s.slot_group):
			groups[s.slot_group] = []
		(groups[s.slot_group] as Array).append(s)
	for g: StringName in groups.keys():
		(groups[g] as Array).sort_custom(func(a: VariantSlot, b: VariantSlot) -> bool:
			return String(a.slot_id) < String(b.slot_id))
	return groups


func run(ctx: LcContext) -> void:
	if not ctx.has_navmesh():
		fail(ctx, ctx.map, null, "no navmesh; reachability not checked")
		return
	var configs: Array[Dictionary] = []
	var base: Dictionary = baseline(ctx)
	configs.append({"label": "baseline", "active": base})
	if ctx.variants_all:
		var groups: Dictionary = groups_of(ctx)
		var names: Array = groups.keys()
		names.sort()
		for g: StringName in names:
			for s: VariantSlot in groups[g]:
				var act: Dictionary = base.duplicate()
				for o: VariantSlot in groups[g]:
					act[o] = o == s
				configs.append({"label": "%s=%s" % [g, s.slot_id], "active": act})
	var failures: Dictionary = {}  # key -> {node, pos, msg, labels}
	var pairs: int = 0
	for cfg: Dictionary in configs:
		await ctx.set_variant_config(cfg["active"])
		pairs += _run_config(ctx, String(cfg["label"]), failures)
	await ctx.set_variant_config({})
	var keys: Array = failures.keys()
	keys.sort()
	for k: String in keys:
		var f: Dictionary = failures[k]
		var labels: PackedStringArray = f["labels"]
		var lab: String = ", ".join(labels.slice(0, 6)) + (" ..." if labels.size() > 6 else "")
		fail(ctx, f["node"], f["pos"], "%s [variants: %s]" % [f["msg"], lab])
	note("%d variant configuration(s), %d spawn->target path queries" % [configs.size(), pairs])


func _run_config(ctx: LcContext, label: String, failures: Dictionary) -> int:
	var targets: Array[Dictionary] = LcTargets.collect(ctx)
	var seen: Dictionary = {}
	for t: Dictionary in targets:
		seen[t["node"]] = true
	for m: Node3D in LcTargets.nav_markers(ctx):
		if not seen.has(m) and not (m is SpawnPoint and (m as SpawnPoint).kind == SpawnPoint.Kind.PLAYER):
			targets.append({"name": ctx.node_path(m), "node": m, "pos": m.global_position, "kind": "marker", "zone": null})
	var n: int = 0
	for t2: Dictionary in targets:
		var z: MapZone = t2["zone"]
		if z != null and not LcTargets.zone_target_ok(z, t2["pos"]):
			_record(failures, ctx, z, null, "zone has no navmesh inside it", label)
	for sp: SpawnPoint in LcTargets.player_spawns(ctx):
		var from: Vector3 = sp.global_position
		var start: Vector3 = ctx.nav_closest(from)
		if Vector2(start.x - from.x, start.z - from.z).length() > END_H_TOL:
			_record(failures, ctx, sp, from, "player spawn is off the navmesh", label)
			continue
		for t3: Dictionary in targets:
			if t3["node"] == sp:
				continue
			n += 1
			var goal: Vector3 = t3["pos"]
			var path: PackedVector3Array = ctx.nav_path(from, goal)
			var ok: bool = reached(path, goal)
			if is_police_only(t3["node"]):
				# A police-only island (D-064 / QC-41: a roof spawn joined to the map by one-way rappel
				# links) must reach the crew, not the other way round.
				path = ctx.nav_path(goal, from)
				ok = reached(path, start)
			if not ok:
				var end_s: String = "no path" if path.is_empty() else "path ends %.2f m away" % path[path.size() - 1].distance_to(goal)
				_record(failures, ctx, t3["node"], goal, "%s `%s` unreachable from player spawn `%s` (%s)"
					% [t3["kind"], t3["name"], ctx.node_path(sp), end_s], label)
	return n


## NPC markers with meta `police_only = true` (police spawns on an island reached only through
## one-way links, e.g. a roof rappel spawn) are checked from the marker to each player spawn.
static func is_police_only(n: Node) -> bool:
	return n is SpawnPoint and (n as SpawnPoint).kind == SpawnPoint.Kind.POLICE and LcUtil.meta_b(n, &"police_only")


static func reached(path: PackedVector3Array, goal: Vector3) -> bool:
	if path.is_empty():
		return false
	var e: Vector3 = path[path.size() - 1]
	return Vector2(e.x - goal.x, e.z - goal.z).length() <= END_H_TOL and absf(e.y - goal.y) <= END_V_TOL


func _record(failures: Dictionary, ctx: LcContext, node: Node, pos: Variant, msg: String, label: String) -> void:
	var key: String = ctx.node_path(node) + "|" + msg
	if not failures.has(key):
		failures[key] = {"node": node, "pos": pos, "msg": msg, "labels": PackedStringArray()}
	var labels: PackedStringArray = failures[key]["labels"]
	if not (label in labels):
		labels.append(label)
		failures[key]["labels"] = labels
