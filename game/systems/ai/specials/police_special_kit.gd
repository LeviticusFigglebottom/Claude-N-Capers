## Shared helpers for the PoliceBrain-based specials (A3-01b: Bulwark, Wrecker, Corpsman). Owner: ENV A.
## - announce: special_spawned(net_id, special_type) [R] (events.md) once per unit (meta guard), the
##   same semantics as SpecialBrain (A3-01a): emitted by the unit's brain on start, whoever spawned it.
## - cue: [R] 3D audio cue (audio_cues.md: specials replicate their cues).
## - limit_key: the DifficultyDef.special_limits key of an enemy id (groups.md / D-022: every
##   `enemy.wrecker_*` variant counts toward `enemy.wrecker`).
## - Shield formation (L4.5 `shield_anchor`, dynamic anchor API): `spot_behind_bulwark(npc)` is the
##   position behind the nearest allied alive Bulwark within HeavySpecialTweak.formation_join_m
##   (Vector3.INF when none). Map-placed SHIELD_ANCHOR TacticalPoints are where Bulwarks stand.
class_name PoliceSpecialKit
extends RefCounted

const ANNOUNCED_META: StringName = &"special_announced"
## Group of alive Bulwarks (BulwarkBrain adds / removes its NPC).
const BULWARK_GROUP: StringName = &"bulwark_unit"
const LIMIT_PREFIXES: Array[String] = ["enemy.wrecker"]


static func announce(npc: NpcBase, special_type: StringName) -> void:
	if npc == null or special_type == &"" or not Net.is_authority() or npc.has_meta(ANNOUNCED_META):
		return
	npc.set_meta(ANNOUNCED_META, true)
	EventBus.special_spawned.emit(npc.net_id, special_type)
	Net.replicate_event(&"special_spawned", [npc.net_id, special_type])


static func cue(npc: NpcBase, cue_id: StringName, pos: Vector3 = Vector3.INF) -> void:
	if npc == null or not Net.is_authority():
		return
	var p: Vector3 = npc.global_position if pos == Vector3.INF else pos
	EventBus.audio_cue_requested.emit(cue_id, p, npc.net_id)
	Net.replicate_event(&"audio_cue_requested", [cue_id, p, npc.net_id])


## DifficultyDef.special_limits key for `enemy_id` (enemy.wrecker_g -> enemy.wrecker).
static func limit_key(enemy_id: StringName) -> StringName:
	var s: String = String(enemy_id)
	for prefix: String in LIMIT_PREFIXES:
		if s == prefix or s.begins_with(prefix + "_"):
			return StringName(prefix)
	return enemy_id


## Short special type of an enemy id (enemy.wrecker_s -> &"wrecker").
static func special_type_of(enemy_id: StringName) -> StringName:
	return StringName(String(limit_key(enemy_id)).trim_prefix("enemy."))


## Alive Bulwarks other than `npc`, nearest first is not guaranteed (group order).
static func bulwarks(ctx: Node) -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	if ctx == null or not ctx.is_inside_tree():
		return out
	for n: Node in ctx.get_tree().get_nodes_in_group(BULWARK_GROUP):
		var b: NpcBase = n as NpcBase
		if b != null and b != ctx and b.alive:
			out.append(b)
	return out


## L4.5 formation: the spot behind the nearest allied Bulwark (away from where its shield faces),
## or Vector3.INF when no Bulwark is within formation_join_m.
static func spot_behind_bulwark(npc: NpcBase) -> Vector3:
	var tw: HeavySpecialTweak = HeavySpecialTweak.data()
	var best: NpcBase = null
	var best_d: float = tw.formation_join_m
	for b: NpcBase in bulwarks(npc):
		var d: float = _flat(b.global_position - npc.global_position).length()
		if d < best_d:
			best_d = d
			best = b
	if best == null:
		return Vector3.INF
	var fwd: Vector3 = best.look_forward()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var lane: float = float(int(npc.get_instance_id() % 3) - 1)
	return best.global_position - fwd * tw.formation_behind_m + right * (lane * tw.formation_side_m)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
