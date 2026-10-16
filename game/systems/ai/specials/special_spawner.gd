## Special-enemy spawn helper (A3-01a). Owner: ENV A. Server only. API for the AssaultDirector (A3-03):
##   SpecialSpawner.spawn_special(rt, kind, xform = Transform3D(), info = {}) -> Array[NpcBase]
## `kind` is a short special type (&"phantom", &"stinger", &"longshot") or a canonical enemy id
## (&"enemy.phantom", groups.md). It loads systems/ai/data/enemies/<type>.tres and calls
## rt.spawn_npc(&"special", xform, info + {"enemy_def": def}); HeistRuntime.spawn_npc picks the scene
## from EnemyDef.params.scene, so a plain director spawn_npc(<any role>, xf, {"enemy_def": def}) of a
## special also gets the right scene. Every special brain emits special_spawned [R] on start.
## - EnemyDef.params.group_size (Stinger: 2, "deploy in pairs") units are spawned side by side
##   (EnemyDef.params.group_spread_m apart); the director's special_limits (L4.11) count each unit.
## - Longshot (L4.7): `xform` is ignored; the unit spawns on a free SNIPER_PERCH TacticalPoint (the
##   one nearest the crew centroid) and nothing spawns when every perch is taken or the map has none.
## - DB-6 (QC-25 hook): a mission may close perches by tag (set_perches_open, CLOSED_META on the TacticalPoint;
##   HeistMission.set_sniper_perches_open): a closed perch is no perch at all (no spawn, no snap) until reopened,
##   e.g. Dockside Burn's S3 viaduct walkway with `fog_lifts` (closed until the fog thins at 6:00).
class_name SpecialSpawner
extends RefCounted

const ENEMY_DIR: String = "res://systems/ai/data/enemies/"
const PERCH_ONLY: Array[StringName] = [&"enemy.longshot"]
## DB-6: TacticalPoint meta of a SNIPER_PERCH the mission has closed.
const CLOSED_META: StringName = &"perch_closed"


static func enemy_def(kind: StringName) -> EnemyDef:
	var short: String = String(kind).trim_prefix("enemy.")
	var path: String = ENEMY_DIR + short + ".tres"
	if not ResourceLoader.exists(path):
		Log.error(&"ai", "SpecialSpawner: no EnemyDef for %s (%s)" % [kind, path])
		return null
	return load(path) as EnemyDef


static func spawn_special(rt: HeistRuntime, kind: StringName, xform: Transform3D = Transform3D(),
		info: Dictionary = {}) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	if rt == null or not Net.is_authority():
		return out
	var def: EnemyDef = enemy_def(kind)
	if def == null:
		return out
	var n: int = maxi(int(def.params.get("group_size", 1)), 1)
	var spread: float = float(def.params.get("group_spread_m", 1.2))
	for i: int in range(n):
		var xf: Transform3D = xform
		if PERCH_ONLY.has(def.id):
			var p: TacticalPoint = free_perch(rt, _crew_centroid(rt), null)
			if p == null:
				Log.info(&"ai", "SpecialSpawner: no free SNIPER_PERCH for %s" % def.id)
				return out
			xf = p.global_transform
		elif i > 0:
			var side: Vector3 = xform.basis.x.normalized() if xform.basis.x.length() > 0.001 else Vector3.RIGHT
			xf.origin += side * spread * ceilf(float(i) * 0.5) * (1.0 if i % 2 == 1 else -1.0)
		var inf: Dictionary = info.duplicate()
		inf["enemy_def"] = def
		var npc: NpcBase = rt.spawn_npc(&"special", xf, inf)
		if npc != null:
			out.append(npc)
			if PERCH_ONLY.has(def.id):
				_claim_now(rt, npc, xf.origin)
	return out


## Alive units of `enemy_id` in this heist (L4.11 limit checks).
static func alive_count(rt: HeistRuntime, enemy_id: StringName) -> int:
	var n: int = 0
	if rt == null:
		return 0
	for node: Node in rt.npcs():
		var npc: NpcBase = node as NpcBase
		if npc != null and npc.enemy_def != null and npc.enemy_def.id == enemy_id:
			n += 1
	return n


## The SNIPER_PERCH within `snap_m` of `pos` (free or claimed by `self_npc`), or null.
static func perch_at(rt: HeistRuntime, pos: Vector3, snap_m: float, self_npc: Node) -> TacticalPoint:
	for tp: TacticalPoint in _perches(rt):
		if tp.global_position.distance_to(pos) <= snap_m and not _claimed_by_other(tp, self_npc):
			return tp
	return null


## Nearest free SNIPER_PERCH to `pos` (null when none).
static func free_perch(rt: HeistRuntime, pos: Vector3, self_npc: Node) -> TacticalPoint:
	var best: TacticalPoint = null
	var best_d: float = INF
	for tp: TacticalPoint in _perches(rt):
		if _claimed_by_other(tp, self_npc):
			continue
		var d: float = tp.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = tp
	return best


static func _perches(rt: HeistRuntime) -> Array[TacticalPoint]:
	var out: Array[TacticalPoint] = []
	for tp: TacticalPoint in _all_perches(rt):
		if not tp.has_meta(CLOSED_META):
			out.append(tp)
	return out


static func _all_perches(rt: HeistRuntime) -> Array[TacticalPoint]:
	var out: Array[TacticalPoint] = []
	if rt == null or rt.map == null:
		return out
	for n: Node in rt.map.get_slots(G.SNIPER_PERCH):
		var tp: TacticalPoint = n as TacticalPoint
		if tp != null and tp.kind == TacticalPoint.Kind.SNIPER_PERCH:
			out.append(tp)
	return out


## DB-6 (server): open / close every SNIPER_PERCH of `rt`'s map tagged `tag` (TacticalPoint.tags). Returns how
## many perches matched. Closing does not move a Longshot already on the perch.
static func set_perches_open(rt: HeistRuntime, tag: StringName, open: bool) -> int:
	var n: int = 0
	for tp: TacticalPoint in _all_perches(rt):
		if not tp.tags.has(tag):
			continue
		n += 1
		if open:
			tp.remove_meta(CLOSED_META)
		else:
			tp.set_meta(CLOSED_META, true)
	return n


## DB-6: the open (usable) SNIPER_PERCH points of `rt`'s map.
static func open_perches(rt: HeistRuntime) -> Array[TacticalPoint]:
	return _perches(rt)


static func _claimed_by_other(tp: TacticalPoint, self_npc: Node) -> bool:
	if not tp.has_meta(SpecialBrain.CLAIM_META):
		return false
	var id: int = int(tp.get_meta(SpecialBrain.CLAIM_META))
	if self_npc != null and id == self_npc.get_instance_id():
		return false
	var o: NpcBase = instance_from_id(id) as NpcBase
	return o != null and is_instance_valid(o) and o.alive


## Claim the perch at spawn time (the brain re-claims on start) so a second spawn in the same frame
## picks another perch.
static func _claim_now(rt: HeistRuntime, npc: NpcBase, pos: Vector3) -> void:
	var tp: TacticalPoint = perch_at(rt, pos, 0.1, npc)
	if tp != null:
		tp.set_meta(SpecialBrain.CLAIM_META, npc.get_instance_id())


static func _crew_centroid(rt: HeistRuntime) -> Vector3:
	var s: Vector3 = Vector3.ZERO
	var n: int = 0
	for c: CrewController in rt.crew_members():
		if c.crew_state != Enums.CrewState.CUSTODY:
			s += c.global_position
			n += 1
	return s / float(n) if n > 0 else Vector3.ZERO
