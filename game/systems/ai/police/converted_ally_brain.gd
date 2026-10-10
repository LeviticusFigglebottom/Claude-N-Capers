## Converted cop ally AI (A3-04, L5.2): child `AllyBrain` of a CONVERTED police NPC (added by
## PoliceSurrender.convert_to). Owner: ENV A. Server only. The PoliceBrain sibling idles (CONVERTED is
## not one of its ACTIVE_STATES); this small brain:
## - follows its owner (crew `owner_slot`, else the nearest non-custody crew member) inside
##   CustodyTweak.convert_follow_min_m..convert_follow_max_m;
## - every convert_retarget_s picks the nearest hostile NPC (police / special / alerted guard, alive,
##   not surrendered / tied / converted) within convert_engage_range_m with line of sight;
## - fires at it with the NPC's EnemyDef cadence and damage (x owner's ability.convert_damage_mult),
##   hit chance convert_hit_chance on GameRng &"convert_fire"; one take_hit per hit (damage.md).
## The visual layer shows an ally outline for NPCs in PoliceSurrender.CONVERT_GROUP.
class_name ConvertedAllyBrain
extends Node

const NODE_NAME: String = "AllyBrain"
const RNG_STREAM: StringName = &"convert_fire"
const HOSTILE_ROLES: Array[StringName] = [&"police", &"special", &"guard"]

## Crew slot that owns this convert.
var owner_slot: int = -1
## Current enemy target (NpcBase) or null.
var target: NpcBase = null
## &"follow", &"hold", &"fight" (debug/tests).
var mode: StringName = &"hold"
var anim_hint: StringName = &"idle_alert"
## Shots fired / hits landed (tests, stats).
var shots: int = 0
var hits: int = 0

var _npc: NpcBase = null
var _motor: NpcMotor = null
var _retarget_left: float = 0.0
var _cooldown: float = 0.0


func _ready() -> void:
	_npc = get_parent() as NpcBase
	if _npc == null:
		Log.error(&"ai", "ConvertedAllyBrain must be a child of an NpcBase")
		return
	_motor = _npc.get_node_or_null(^"Motor") as NpcMotor
	_npc.died.connect(func(_i: Dictionary, _k: int) -> void: set_physics_process(false))


func _physics_process(delta: float) -> void:
	if _npc == null or not _npc.alive or not Net.is_authority() or _npc.alert_state != Enums.AlertState.CONVERTED:
		return
	var tw: CustodyTweak = CustodyTweak.data()
	_cooldown = maxf(_cooldown - delta, 0.0)
	_retarget_left -= delta
	if _retarget_left <= 0.0 or target == null or not is_instance_valid(target) or not _is_hostile(target):
		_retarget_left = tw.convert_retarget_s
		target = _pick_target(tw)
	_tick_follow(tw)
	if target != null and _cooldown <= 0.0:
		_cooldown = _fire_interval()
		_fire(target)


func _pick_target(tw: CustodyTweak) -> NpcBase:
	var rt: HeistRuntime = HeistRuntime.of(_npc)
	if rt == null:
		return null
	var best: NpcBase = null
	var best_d: float = tw.convert_engage_range_m
	for n: Node in rt.npcs():
		var e: NpcBase = n as NpcBase
		if e == null or e == _npc or not _is_hostile(e):
			continue
		var d: float = _npc.global_position.distance_to(e.global_position)
		if d > best_d:
			continue
		if not CombatSystem.has_los(_npc, _npc.eye_position(), e.global_position + Vector3(0.0, 1.2, 0.0), [_npc, e]):
			continue
		best = e
		best_d = d
	return best


func _is_hostile(e: NpcBase) -> bool:
	if not e.alive or not HOSTILE_ROLES.has(e.role) or NpcBase.BLIND_STATES.has(e.alert_state):
		return false
	if e.is_in_group(PoliceSurrender.CONVERT_GROUP):
		return false
	if e.role == &"guard":
		return e.alert_state == Enums.AlertState.COMBAT or e.alert_state == Enums.AlertState.ALARMED
	return true


func _tick_follow(tw: CustodyTweak) -> void:
	if _motor == null:
		return
	var lead: CrewController = _leader()
	if lead == null:
		_motor.stop()
		mode = &"hold"
		return
	var d: float = Vector2(lead.global_position.x - _npc.global_position.x,
		lead.global_position.z - _npc.global_position.z).length()
	if d > tw.convert_follow_max_m:
		mode = &"follow"
		anim_hint = &"run"
		if _motor.target == Vector3.INF or _motor.target.distance_to(lead.global_position) > 1.0:
			_motor.go_to(lead.global_position, tw.convert_run_speed)
	elif d <= tw.convert_follow_min_m or _motor.arrived:
		_motor.stop()
		mode = &"fight" if target != null else &"hold"
		anim_hint = &"aim" if target != null else &"idle_alert"
		if target != null:
			_motor.face_point(target.global_position)


func _leader() -> CrewController:
	var rt: HeistRuntime = HeistRuntime.of(_npc)
	if rt == null:
		return null
	var own: CrewController = rt.crew_controller(owner_slot) as CrewController
	if own != null and own.crew_state != Enums.CrewState.CUSTODY:
		return own
	var best: CrewController = null
	var best_d: float = INF
	for c: CrewController in rt.crew_members():
		if c.crew_state == Enums.CrewState.CUSTODY:
			continue
		var d: float = c.global_position.distance_to(_npc.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _fire_interval() -> float:
	var def: EnemyDef = _npc.enemy_def
	if def != null and def.params.has("fire_interval_s"):
		return float(def.params["fire_interval_s"])
	return CombatTweak.data().npc_fire_interval_s


func _shot_damage() -> float:
	var def: EnemyDef = _npc.enemy_def
	var base: float = CombatTweak.data().npc_fallback_damage
	if def != null and def.damage.size() > 0:
		base = def.damage[clampi(_npc.difficulty, 0, def.damage.size() - 1)]
	return base * Modifiers.mult(owner_slot, &"ability.convert_damage_mult")


func _fire(e: NpcBase) -> void:
	var from: Vector3 = _npc.eye_position()
	var aim: Vector3 = e.global_position + Vector3(0.0, 1.2, 0.0)
	var weapon_id: StringName = _npc.enemy_def.weapon if _npc.enemy_def != null else &""
	shots += 1
	EventBus.weapon_fired.emit(_npc.net_id, weapon_id, false, from)
	if GameRng.stream(RNG_STREAM).randf() >= CustodyTweak.data().convert_hit_chance:
		return
	hits += 1
	var info: Dictionary = Damage.info(_shot_damage(), Enums.DamageType.BULLET, Enums.HitZone.BODY,
		weapon_id, aim, (aim - from).normalized(), _npc.net_id)
	e.take_hit(info, _npc.net_id)
