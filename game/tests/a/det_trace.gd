## DET (loud-path determinism audit): a per-physics-tick gameplay trace of a running heist, hashed per game
## second, so two runs of one seed can be compared and the first divergence located. Owner: ENV A (tests).
## Records (server): EventBus facts (spawns, shots, damage, kills, downs, assault phases / events) as they
## happen, and every `sample_ticks` physics ticks a snapshot of each NPC (net id, role, alive, position,
## health, brain mode / target) and each crew member (position, health, armor, downs).
class_name DetTrace
extends Node

var rt: HeistRuntime = null
var sample_ticks: int = 15
## Physics ticks per bucket (one game second at time_scale 1 is physics_ticks_per_second).
var bucket_ticks: int = 60
var lines: Array[String] = []
var bucket_of_line: PackedInt32Array = PackedInt32Array()
var tick: int = 0
var recording: bool = false


func start(p_rt: HeistRuntime) -> void:
	rt = p_rt
	tick = 0
	recording = true
	EventBus.weapon_fired.connect(_on_fired)
	EventBus.damage_applied.connect(_on_damage)
	EventBus.npc_killed.connect(_on_killed)
	EventBus.crew_downed.connect(_on_downed)
	EventBus.assault_phase_changed.connect(_on_phase)
	EventBus.assault_event_started.connect(_on_event)
	rt.npc_spawned.connect(_on_spawned)
	get_tree().physics_frame.connect(_on_physics_frame)


func stop() -> void:
	if not recording:
		return
	recording = false
	EventBus.weapon_fired.disconnect(_on_fired)
	EventBus.damage_applied.disconnect(_on_damage)
	EventBus.npc_killed.disconnect(_on_killed)
	EventBus.crew_downed.disconnect(_on_downed)
	EventBus.assault_phase_changed.disconnect(_on_phase)
	EventBus.assault_event_started.disconnect(_on_event)
	if is_instance_valid(rt) and rt.npc_spawned.is_connected(_on_spawned):
		rt.npc_spawned.disconnect(_on_spawned)
	get_tree().physics_frame.disconnect(_on_physics_frame)


func _exit_tree() -> void:
	stop()


func _add(s: String) -> void:
	lines.append("t%d %s" % [tick, s])
	bucket_of_line.append(tick / bucket_ticks)


static func v3(p: Vector3) -> String:
	if OS.get_environment("DET_PREC") != "":  # diagnostics: more decimals (the first sub-cm divergence)
		var f: String = "%%.%sf" % OS.get_environment("DET_PREC")
		return "(%s,%s,%s)" % [f % p.x, f % p.y, f % p.z]
	return "(%.2f,%.2f,%.2f)" % [p.x, p.y, p.z]


func _on_physics_frame() -> void:
	if not recording or not is_instance_valid(rt):
		return
	tick += 1
	if tick % sample_ticks != 0:
		return
	var npcs: Array[NpcBase] = []
	for n: Node in rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.is_inside_tree():
			npcs.append(npc)
	npcs.sort_custom(func(a: NpcBase, b: NpcBase) -> bool: return a.net_id < b.net_id)
	for npc: NpcBase in npcs:
		var brain: Node = npc.get_node_or_null(^"Brain")
		var mode: Variant = brain.get(&"mode") if brain != null else null
		var tgt: Variant = brain.get(&"combat_target") if brain != null else null
		var tgt_s: String = "-"
		if tgt is Node and is_instance_valid(tgt):
			tgt_s = str((tgt as Node).get(&"net_id"))
		_add("npc %d %s %s a=%s hp=%.1f m=%s tg=%s" % [npc.net_id, npc.name, v3(npc.global_position), npc.alive,
			npc.health, mode, tgt_s])
	for c: CrewController in rt.crew_members():
		var h: CrewHealth = c.health
		_add("crew %d %s hp=%.1f ar=%.1f dn=%d%s" % [c.slot, v3(c.global_position), h.health if h else -1.0,
			h.armor if h else -1.0, h.downs_used if h else -1,
			(" v=%s st=%d yaw=%.5f mv=%s" % [v3(c.velocity), c.crew_state, c.look_yaw, c.intent.move])
				if OS.get_environment("DET_PREC") != "" else ""])


func _on_spawned(npc: NpcBase) -> void:
	_add("spawn %d %s %s %s" % [npc.net_id, npc.name, npc.role, v3(npc.global_position)])


func _on_fired(shooter: int, weapon_id: StringName, _suppressed: bool, position: Vector3) -> void:
	_add("fire %d %s %s" % [shooter, weapon_id, v3(position)])


func _on_damage(victim: int, attacker: int, info: Dictionary) -> void:
	_add("dmg %d<-%d %.2f z=%s" % [victim, attacker, float(info.get("amount", 0.0)), info.get("zone", -1)])


func _on_killed(victim: int, killer: int, _info: Dictionary) -> void:
	_add("kill %d<-%d" % [victim, killer])


func _on_downed(slot: int, downs: int) -> void:
	_add("down %d %d" % [slot, downs])


func _on_phase(phase: int, wave: int) -> void:
	_add("phase %d w%d" % [phase, wave])


func _on_event(kind: StringName, net_id: int, position: Vector3) -> void:
	_add("event %s %d %s" % [kind, net_id, v3(position)])


## Per-bucket hash of the recorded lines (bucket = bucket_ticks physics ticks).
func bucket_hashes() -> PackedInt64Array:
	var n: int = (tick / bucket_ticks) + 1
	var parts: Array[PackedStringArray] = []
	for i: int in n:
		parts.append(PackedStringArray())
	for i: int in lines.size():
		parts[bucket_of_line[i]].append(lines[i])
	var out: PackedInt64Array = PackedInt64Array()
	for p: PackedStringArray in parts:
		out.append("\n".join(p).hash())
	return out


## Index of the first line that differs between two traces (-1 = identical).
static func first_divergence(a: Array[String], b: Array[String]) -> int:
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return -1 if a.size() == b.size() else mini(a.size(), b.size())
