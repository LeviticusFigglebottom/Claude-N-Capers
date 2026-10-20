## PO-5 run statistics (D-145 acceptance evidence): per crew slot downs / custody / revives, the health AI bots regained
## outside a revive (D-145.4a regen), each slot's loadout (primary, armor), and the police composition (every NPC that
## was alive with an EnemyDef at a 1 s sample, by EnemyDef id; specials flagged). Harness only: listens to EventBus and
## samples the runtime, never touches the game. Owner: ENV A (test support).
class_name Po5Stats
extends RefCounted

var downs: Dictionary = {}  # slot -> int
var custody: Dictionary = {}
var revives: Dictionary = {}
## slot -> health regained while NORMAL between two samples (a revive restores health while DOWNED -> NORMAL: not counted)
var regained: Dictionary = {}
var loadouts: Dictionary = {}  # slot -> "primary / armor"
var enemies: Dictionary = {}  # EnemyDef id -> count of distinct units seen
var specials: Dictionary = {}
var peak_alive: int = 0
var difficulty: int = -1
var _seen: Dictionary = {}  # instance id -> true
var _last: Dictionary = {}  # slot -> [health, state]
var _rt: HeistRuntime = null
var _host: Node = null


func start(host: Node, rt: HeistRuntime) -> void:
	_host = host
	_rt = rt
	difficulty = rt.difficulty
	EventBus.crew_downed.connect(func(slot: int, _u: int) -> void: downs[slot] = int(downs.get(slot, 0)) + 1)
	EventBus.crew_custody.connect(func(slot: int) -> void: custody[slot] = int(custody.get(slot, 0)) + 1)
	EventBus.crew_revived.connect(func(slot: int, _by: int) -> void: revives[slot] = int(revives.get(slot, 0)) + 1)
	for c: CrewController in rt.crew_members():
		var l: Loadout = c.loadout
		loadouts[c.slot] = "%s / %s" % [l.primary, l.armor] if l != null else "-"
	_loop()


func _loop() -> void:
	while _rt != null and is_instance_valid(_rt) and _rt.phase != Enums.HeistPhase.ENDED:
		_sample()
		await _host.get_tree().create_timer(1.0, true, true).timeout


func _sample() -> void:
	var alive: int = 0
	for n: Node in _rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc == null or npc.enemy_def == null:
			continue
		alive += 1
		var key: int = npc.get_instance_id()
		if _seen.has(key):
			continue
		_seen[key] = true
		var id: StringName = npc.enemy_def.id
		enemies[id] = int(enemies.get(id, 0)) + 1
		if npc.enemy_def.is_special:
			specials[id] = int(specials.get(id, 0)) + 1
	peak_alive = maxi(peak_alive, alive)
	for c: CrewController in _rt.crew_members():
		if c.health == null:
			continue
		var h: float = c.health.health
		var st: int = c.crew_state
		var prev: Array = _last.get(c.slot, [])
		if not prev.is_empty() and st == Enums.CrewState.NORMAL and int(prev[1]) == Enums.CrewState.NORMAL \
				and h > float(prev[0]):
			regained[c.slot] = float(regained.get(c.slot, 0.0)) + h - float(prev[0])
		_last[c.slot] = [h, st]


func summary() -> String:
	var units: int = 0
	for k: Variant in enemies:
		units += int(enemies[k])
	var crew: PackedStringArray = PackedStringArray()
	for slot: Variant in loadouts:
		crew.append("slot %d [%s] downs %d custody %d revived %d regained %.0f" % [slot, loadouts[slot],
			int(downs.get(slot, 0)), int(custody.get(slot, 0)), int(revives.get(slot, 0)), float(regained.get(slot, 0.0))])
	return "STATS difficulty=%d police=%d peak_alive=%d specials=%s composition=%s | %s" % [difficulty, units,
		peak_alive, specials, enemies, "; ".join(crew)]
