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
## D-154 close (B / LEAD): Brandt's Aegis shields (META_AEGIS at first sight; they are enemy.bulwark units) count here
## only, never in police / specials / composition, so the Bulwark share (bulwark / police) is the director funnel's.
var aegis: int = 0
var peak_alive: int = 0
## LEAD (D-145, DB vs GH Tense): damage the pilot (slot 0) took while standing, by attacker EnemyDef id
## (id -> [hits landed, damage, hits that did nothing (graced / dodged / invulnerable)]) and by attacker distance band.
var intake: Dictionary = {}
var intake_bands: Dictionary = {}  # "<10" / "10-20" / "20-30" / "30+" -> damage
## Seconds the pilot stood (NORMAL) after the alarm, and the sum of alive enemies within 20 m over those samples.
var loud_up_s: float = 0.0
var near_sum: float = 0.0
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
	EventBus.damage_applied.connect(_on_damage)
	for c: CrewController in rt.crew_members():
		var l: Loadout = c.loadout
		loadouts[c.slot] = "%s / %s" % [l.primary, l.armor] if l != null else "-"
	_loop()


func _on_damage(victim_net_id: int, attacker_net_id: int, info: Dictionary) -> void:
	var me: CrewController = _rt.crew_controller(0) as CrewController if _rt != null else null
	if me == null or victim_net_id != me.net_id or me.crew_state != Enums.CrewState.NORMAL:
		return
	var npc: NpcBase = Ids.lookup(attacker_net_id) as NpcBase
	var id: String = String(npc.enemy_def.id) if npc != null and npc.enemy_def != null else "other"
	var row: Array = intake.get(id, [0, 0.0, 0])
	var amount: float = float(info.get("amount", 0.0))
	if amount > 0.0:
		row[0] = int(row[0]) + 1
		row[1] = float(row[1]) + amount
		if npc != null:
			var d: float = npc.global_position.distance_to(me.global_position)
			var band: String = "<10" if d < 10.0 else ("10-20" if d < 20.0 else ("20-30" if d < 30.0 else "30+"))
			intake_bands[band] = float(intake_bands.get(band, 0.0)) + amount
	else:
		row[2] = int(row[2]) + 1
	intake[id] = row


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
		if npc.has_meta(AegisCaptain.META_AEGIS):
			aegis += 1
			continue
		var id: StringName = npc.enemy_def.id
		enemies[id] = int(enemies.get(id, 0)) + 1
		if npc.enemy_def.is_special:
			specials[id] = int(specials.get(id, 0)) + 1
	peak_alive = maxi(peak_alive, alive)
	var me: CrewController = _rt.crew_controller(0) as CrewController
	if me != null and _rt.went_loud and me.crew_state == Enums.CrewState.NORMAL:
		loud_up_s += 1.0
		for n: Node in _rt.npcs():
			var npc: NpcBase = n as NpcBase
			if npc != null and npc.enemy_def != null and npc.is_alive() \
					and npc.global_position.distance_to(me.global_position) <= 20.0:
				near_sum += 1.0
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
	var total: float = 0.0
	for k: Variant in intake:
		total += float((intake[k] as Array)[1])
	var dps: float = total / maxf(loud_up_s, 1.0)
	var head: String = "STATS difficulty=%d police=%d peak_alive=%d specials=%s composition=%s | %s" % [difficulty, units,
		peak_alive, specials, enemies, "; ".join(crew)]
	head += "\nSTATS aegis=%d (Brandt's shields: not in police / specials / composition)" % aegis
	var tail: String = "INTAKE pilot standing loud %.0f s, %.0f dmg, %.2f dmg/s, %.1f enemies within 20 m on average" % [
		loud_up_s, total, dps, near_sum / maxf(loud_up_s, 1.0)]
	return "%s\n%s | by attacker [hits, dmg, nulled] %s | by range %s" % [head, tail, intake, intake_bands]
