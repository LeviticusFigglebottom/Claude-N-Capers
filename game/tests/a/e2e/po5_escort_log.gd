## LEAD D-151 (RT Hazardous clean stop, 18-20 dmg/s on the pilot in its first 20 s): the per-unit timeline from the
## convoy's stop. At the stop every enemy NPC (EnemyDef id, alert state, range to the pilot); then for `window_s` each
## alert change, each hit on a crew member (shooter, its alert state, range) and a 5 s alive census by alert state.
## Harness only: listens, never touches the game. Lines start "ESCORT t+<s>". Owner: ENV A (test support).
class_name Po5EscortLog
extends RefCounted

var _rt: HeistRuntime = null
var _note: Callable
var _t0: float = 0.0
var _hooked: Dictionary = {}  # instance id -> true
var _on_damage: Callable


func start(host: Node, rt: HeistRuntime, note: Callable, window_s: float = 60.0) -> void:
	_rt = rt
	_note = note
	_t0 = rt.heist_time_s
	for npc: NpcBase in _enemies():
		_line("at the stop: %s" % _desc(npc))
		_hook(npc)
	_on_damage = func(victim: int, attacker: int, info: Dictionary) -> void:
		var crew: CrewController = Ids.lookup(victim) as CrewController
		if crew == null or not _live():
			return
		var npc: NpcBase = Ids.lookup(attacker) as NpcBase
		_line("hit slot %d %.1f dmg from %s" % [crew.slot, float(info.get("amount", 0.0)),
			_desc(npc, crew) if npc != null else "net %d" % attacker])
	EventBus.damage_applied.connect(_on_damage)
	var t: float = 0.0
	while t < window_s and _live():
		await host.get_tree().create_timer(1.0, true, true).timeout
		t += 1.0
		if not _live():
			break
		for npc: NpcBase in _enemies():
			if not _hooked.has(npc.get_instance_id()):
				_line("new: %s" % _desc(npc))
				_hook(npc)
		if int(t) % 5 == 0:
			_census()
	EventBus.damage_applied.disconnect(_on_damage)


func _live() -> bool:
	return _rt != null and is_instance_valid(_rt) and _rt.phase != Enums.HeistPhase.ENDED


func _enemies() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	for n: Node in _rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.enemy_def != null and npc.is_alive():
			out.append(npc)
	return out


func _hook(npc: NpcBase) -> void:
	_hooked[npc.get_instance_id()] = true
	var id: int = npc.net_id
	var def: StringName = npc.enemy_def.id
	npc.alert_state_changed.connect(func(old: int, new: int) -> void:
		if _live():
			_line("alert %s #%d %s -> %s" % [def, id, Enums.AlertState.keys()[old], Enums.AlertState.keys()[new]]))


func _census() -> void:
	var by: Dictionary = {}
	for npc: NpcBase in _enemies():
		var k: String = Enums.AlertState.keys()[npc.alert_state]
		by[k] = int(by.get(k, 0)) + 1
	_line("alive by alert %s" % by)


func _desc(npc: NpcBase, to: Node3D = null) -> String:
	var me: Node3D = to if to != null else _rt.crew_controller(0) as Node3D
	var d: float = npc.global_position.distance_to(me.global_position) if me != null else -1.0
	return "%s #%d %s %.0f m" % [npc.enemy_def.id, npc.net_id, Enums.AlertState.keys()[npc.alert_state], d]


func _line(s: String) -> void:
	_note.call("ESCORT t+%.1f %s" % [_rt.heist_time_s - _t0, s])
