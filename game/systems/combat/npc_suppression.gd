## Suppression / "threat" on an NPC (A3-06, pd2_fidelity L3.5). Owner: ENV A. Server only.
## Child `Suppression` of an NpcBase, created on demand by `of(npc, true)` the first time threat is
## added. Numbers: CombatTweak (Suppression group).
## - Damaging hits add WeaponStats.suppression x threat_per_suppression_hit; near misses (the shot ray
##   passes within near_miss_radius_m of the NPC's centre line) add x threat_per_suppression_near_miss.
##   Suppressed weapons add no threat (CombatSystem never calls in for them). Threat decays per second.
## - threat >= threat_hunch: HUNCHED (NpcGunner: x1.5 shot delay, x1.5 aim time, x0.5 hit chance).
## - threat >= threat_dive: DIVING for dive_s: the brain pauses (PoliceBrain checks is_diving) while
##   the motor runs to the nearest free COVER point within dive_cover_search_m, else sidesteps away
##   from the threat. Then threat resets and gains are x suppression_resist_mult for suppression_resist_s.
## - Immune: specials (EnemyDef.is_special), EnemyDef.params.suppression_immune, civilians, and every
##   unit at difficulty >= suppression_immune_min_difficulty ("top factions").
class_name NpcSuppression
extends Node

signal state_changed(old_state: int, new_state: int)

enum State { NONE, HUNCHED, DIVING }

const NODE_NAME: String = "Suppression"

var threat: float = 0.0
var state: State = State.NONE
## Seconds of reduced threat gain left (after a dive).
var resist_left: float = 0.0
var dive_left: float = 0.0
## Where the last threat came from (dive direction).
var threat_origin: Vector3 = Vector3.INF

var _npc: NpcBase = null


func _ready() -> void:
	_npc = get_parent() as NpcBase


## The NPC's suppression component (created when `create`), or null.
static func of(npc: Node, create: bool = false) -> NpcSuppression:
	if npc == null or not is_instance_valid(npc):
		return null
	var s: NpcSuppression = npc.get_node_or_null(NODE_NAME) as NpcSuppression
	if s == null and create and npc is NpcBase:
		s = NpcSuppression.new()
		s.name = NODE_NAME
		npc.add_child(s)
	return s


static func is_immune(npc: NpcBase) -> bool:
	if npc == null or not npc.alive or npc.role == &"civilian":
		return true
	var def: EnemyDef = npc.enemy_def
	if def != null and (def.is_special or bool(def.params.get("suppression_immune", false))):
		return true
	return npc.difficulty >= CombatTweak.data().suppression_immune_min_difficulty


## Server: add `amount` threat to `npc` coming from `from`. Returns the threat actually added.
static func add_threat(npc: NpcBase, amount: float, from: Vector3 = Vector3.INF) -> float:
	if not Net.is_authority() or amount <= 0.0 or is_immune(npc):
		return 0.0
	var s: NpcSuppression = of(npc, true)
	return s.add(amount, from)


static func state_of(npc: Node) -> int:
	var s: NpcSuppression = of(npc)
	return s.state if s != null else State.NONE


static func is_hunched(npc: Node) -> bool:
	return state_of(npc) == State.HUNCHED


static func is_diving(npc: Node) -> bool:
	return state_of(npc) == State.DIVING


## NpcGunner multipliers (1.0 when not hunched).
static func shot_delay_mult(npc: Node) -> float:
	return CombatTweak.data().hunch_shot_delay_mult if is_hunched(npc) else 1.0


static func aim_delay_mult(npc: Node) -> float:
	return CombatTweak.data().hunch_aim_delay_mult if is_hunched(npc) else 1.0


static func hit_chance_mult(npc: Node) -> float:
	return CombatTweak.data().hunch_hit_chance_mult if is_hunched(npc) else 1.0


## Server: L3.5 near misses of one shot ray `from` -> `to`: every suppressible NPC whose centre line
## (feet+0.3 .. head) passes within near_miss_radius_m, except those in `exclude` (already hit).
static func near_misses(ctx: Node, from: Vector3, to: Vector3, suppression: float, exclude: Array = []) -> int:
	var tw: CombatTweak = CombatTweak.data()
	if suppression <= 0.0 or ctx == null or not ctx.is_inside_tree():
		return 0
	var n: int = 0
	for node: Node in ctx.get_tree().get_nodes_in_group(G.NPC):
		var npc: NpcBase = node as NpcBase
		if npc == null or exclude.has(npc) or is_immune(npc):
			continue
		var low: Vector3 = npc.global_position + Vector3(0.0, 0.3, 0.0)
		if _segment_distance(from, to, low, npc.head_position()) <= tw.near_miss_radius_m:
			if add_threat(npc, suppression * tw.threat_per_suppression_near_miss, from) > 0.0:
				n += 1
	return n


func add(amount: float, from: Vector3) -> float:
	if state == State.DIVING:
		return 0.0
	var tw: CombatTweak = CombatTweak.data()
	var gain: float = amount * (tw.suppression_resist_mult if resist_left > 0.0 else 1.0)
	threat += gain
	if from != Vector3.INF:
		threat_origin = from
	_update_state()
	return gain


func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"npc_suppression", fp)


func _physics_step(delta: float) -> void:
	if _npc == null or not Net.is_authority():
		return
	var tw: CombatTweak = CombatTweak.data()
	if resist_left > 0.0:
		resist_left = maxf(resist_left - delta, 0.0)
	if not _npc.alive:
		_set_state(State.NONE)
		return
	if state == State.DIVING:
		dive_left -= delta
		if dive_left <= 0.0:
			_end_dive()
		return
	threat = maxf(threat - tw.threat_decay_per_s * delta, 0.0)
	_update_state()


func _update_state() -> void:
	if state == State.DIVING:
		return
	var tw: CombatTweak = CombatTweak.data()
	if threat >= tw.threat_dive:
		_start_dive()
	elif threat >= tw.threat_hunch:
		_set_state(State.HUNCHED)
	else:
		_set_state(State.NONE)


func _start_dive() -> void:
	var tw: CombatTweak = CombatTweak.data()
	dive_left = tw.dive_s
	resist_left = tw.suppression_resist_s
	threat = 0.0
	_set_state(State.DIVING)
	var brain: Node = _npc.get_node_or_null("Brain")
	if brain != null and &"wants_to_fire" in brain:
		brain.set(&"wants_to_fire", false)
	if brain != null and &"anim_hint" in brain:
		brain.set(&"anim_hint", &"crouch_walk")
	var motor: NpcMotor = _npc.get_node_or_null("Motor") as NpcMotor
	if motor != null:
		var speed: float = (_npc.enemy_def.move_speed if _npc.enemy_def != null else 3.0) * tw.dive_speed_mult
		motor.go_to(_dive_point(tw), speed)


func _end_dive() -> void:
	dive_left = 0.0
	var motor: NpcMotor = _npc.get_node_or_null("Motor") as NpcMotor
	if motor != null:
		motor.stop()
	_set_state(State.NONE)
	_update_state()


## Nearest free COVER TacticalPoint within dive_cover_search_m, else a sidestep across the threat line.
func _dive_point(tw: CombatTweak) -> Vector3:
	var me: Vector3 = _npc.global_position
	var best: Vector3 = Vector3.INF
	var best_d: float = tw.dive_cover_search_m
	for n: Node in get_tree().get_nodes_in_group(G.COVER_POINT):
		var tp: Node3D = n as Node3D
		if tp == null:
			continue
		var d: float = tp.global_position.distance_to(me)
		if d < best_d:
			best_d = d
			best = tp.global_position
	if best != Vector3.INF:
		return best
	var away: Vector3 = Vector3.FORWARD
	if threat_origin != Vector3.INF:
		away = me - threat_origin
	away.y = 0.0
	if away.length() < 0.001:
		away = Vector3.FORWARD
	var side: Vector3 = away.normalized().cross(Vector3.UP)
	if GameRng.stream(&"suppression").randf() < 0.5:
		side = -side
	return me + side * tw.dive_sidestep_m


func _set_state(s: State) -> void:
	if s == state:
		return
	var old: State = state
	state = s
	state_changed.emit(old, s)


static func _segment_distance(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> float:
	# Closest distance between segments ab and cd (clamped parameters).
	var u: Vector3 = b - a
	var v: Vector3 = d - c
	var w: Vector3 = a - c
	var uu: float = u.dot(u)
	var vv: float = v.dot(v)
	var uv: float = u.dot(v)
	var uw: float = u.dot(w)
	var vw: float = v.dot(w)
	var den: float = uu * vv - uv * uv
	var s: float = 0.0
	if den > 0.000001:
		s = clampf((uv * vw - vv * uw) / den, 0.0, 1.0)
	var t: float = clampf((uv * s + vw) / vv, 0.0, 1.0) if vv > 0.000001 else 0.0
	s = clampf((uv * t - uw) / uu, 0.0, 1.0) if uu > 0.000001 else 0.0
	return (a + u * s).distance_to(c + v * t)
