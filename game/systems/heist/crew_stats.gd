## Per-crew heist counters (A3 / D-071: ui_hud v1.7 crew_stats, events v1.1 HeistResult crew rows). Owner: ENV A.
## Service SERVICE of HeistRuntime. Server counts, replicated to every peer through HeistNetSync's services
## state (SVC_STATS); clients only mirror. Rows per slot: kills, specials_killed, civilians_killed, downs,
## shots, hits, headshots.
## Counting rules (ui_hud v1.7): a shot = one accepted firearm claim (CombatSystem.validate_and_apply; a
## shotgun blast is 1; melee, throwables, deployables and sentries never come through there). A hit = the shot
## struck an enemy NPC (body, Bulwark shield or plate, even for 0 damage), at most once per shot. A headshot =
## it struck an enemy's HitZone.HEAD, at most once per shot. AI crew are counted the same way.
class_name CrewStats
extends Node

signal changed()

const SERVICE: StringName = &"crew_stats"
const COUNTERS: Array[StringName] = [
	&"kills", &"specials_killed", &"civilians_killed", &"downs", &"shots", &"hits", &"headshots",
]

## slot -> {counter: int}
var rows: Dictionary[int, Dictionary] = {}


static func of(node: Node) -> CrewStats:
	var rt: HeistRuntime = HeistRuntime.of(node) if node != null else null
	return rt.service(SERVICE) as CrewStats if rt != null else null


## Server: one accepted firearm shot by `crew` (hit / headshot on an enemy, each at most once per shot).
static func record_shot(crew: CrewController, hit: bool, headshot: bool) -> void:
	var s: CrewStats = of(crew)
	if s == null or not Net.is_authority():
		return
	s._add(crew.slot, &"shots")
	if hit:
		s._add(crew.slot, &"hits")
	if headshot:
		s._add(crew.slot, &"headshots")
	s.changed.emit()


## An enemy for the hit counters: a non-civilian NPC, or a Bulwark shield (its carrier).
static func enemy_of(target: Object) -> NpcBase:
	var npc: NpcBase = target as NpcBase
	if npc == null and target is BulwarkShield:
		npc = (target as BulwarkShield).carrier
	if npc == null or not is_instance_valid(npc) or npc.role == &"civilian":
		return null
	return npc


func _ready() -> void:
	EventBus.npc_killed.connect(_on_npc_killed)
	EventBus.civilian_killed.connect(_on_civilian_killed)
	EventBus.crew_downed.connect(_on_crew_downed)


func _exit_tree() -> void:
	for pair: Array in [
		[EventBus.npc_killed, _on_npc_killed], [EventBus.civilian_killed, _on_civilian_killed],
		[EventBus.crew_downed, _on_crew_downed],
	]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


## A zeroed row for `slot` (crew spawn / replica).
func ensure(slot: int) -> void:
	if rows.has(slot):
		return
	var r: Dictionary = {}
	for k: StringName in COUNTERS:
		r[k] = 0
	rows[slot] = r


func row(slot: int) -> Dictionary:
	return (rows.get(slot, {}) as Dictionary).duplicate()


func value(slot: int, counter: StringName) -> int:
	return int((rows.get(slot, {}) as Dictionary).get(counter, 0))


## Server -> clients (HeistNetSync services state).
func net_state() -> Dictionary:
	var out: Dictionary = {}
	for slot: int in rows:
		out[slot] = (rows[slot] as Dictionary).duplicate()
	return out


func apply_net_state(d: Dictionary) -> void:
	if Net.is_authority():
		return
	var any: bool = false
	for k: Variant in d:
		var slot: int = int(k)
		var r: Dictionary = (d[k] as Dictionary).duplicate()
		if rows.get(slot, {}) != r:
			rows[slot] = r
			any = true
	if any:
		changed.emit()


func _add(slot: int, counter: StringName) -> void:
	ensure(slot)
	rows[slot][counter] = int(rows[slot][counter]) + 1


func _on_npc_killed(npc_id: int, killer_id: int, _info: Dictionary) -> void:
	if not Net.is_authority():
		return
	var c: CrewController = Ids.lookup(killer_id) as CrewController
	if c == null:
		return
	_add(c.slot, &"kills")
	var npc: NpcBase = Ids.lookup(npc_id) as NpcBase
	if npc != null and npc.enemy_def != null and npc.enemy_def.is_special:
		_add(c.slot, &"specials_killed")
	changed.emit()


func _on_civilian_killed(_npc_id: int, slot: int) -> void:
	if Net.is_authority() and slot >= 0:
		_add(slot, &"civilians_killed")
		changed.emit()


func _on_crew_downed(slot: int, _downs: int) -> void:
	if Net.is_authority() and slot >= 0:
		_add(slot, &"downs")
		changed.emit()
