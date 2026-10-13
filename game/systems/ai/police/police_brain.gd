## Loud police brain (A1-09, L4.2): Patrol Officer and TAC Light. Owner: ENV A. Server only.
## Child `Brain` of npc_police.tscn (siblings: Motor = NpcMotor, Gunner = NpcGunner).
## Active once the heist is loud (HeistRuntime.went_loud); before that the unit stands idle, so a
## police NPC spawned during stealth (tests) never opens fire on its own.
## Behaviour (all distances flat, meters; numbers in PoliceTweak):
## - target: every retarget_s (0.5-1 s) the nearest non-custody crew member, preferring one in LOS
##   that is not downed (the gunner applies L2.5 itself).
## - flank-lite: a fresh unit rolls flank_chance; on success it first runs to the FLANK
##   TacticalPoint nearest to the target (within flank_max_from_target_m), then fights normally.
## - cover-lite: a free COVER TacticalPoint cover_min_m..cover_max_m from the target with LOS to it
##   is claimed (one unit per point, node meta) and held; otherwise approach to a standoff band
##   standoff_min_m..standoff_max_m (closing in while the target is out of LOS).
## - fire: `wants_to_fire` / `combat_target` for NpcGunner (fires while moving too).
## - FADE (L1.1): no retreat in P1. Units keep fighting; the director just stops reinforcing.
## - L2.12 (A3-04): a DOWNED target that is not shooting within CustodyTweak.police_cuff_approach_m
##   is walked up to and cuffed at police_cuff_range_m (CrewCuffs.cuff_downed).
## - Squad order (A3-02 L4.9, AegisCaptain): `order_position` set = run there and hold it (no cover,
##   flank or standoff; targeting and fire as usual) until clear_order().
## - L5.1 (A3-04): SURRENDERED / TIED / CONVERTED are owned by PoliceSurrender (not ACTIVE_STATES).
class_name PoliceBrain
extends Node

const DEFAULT_TWEAK: String = "res://systems/ai/police/police_tweak.tres"
const RNG_STREAM: StringName = &"police_ai"
const CLAIM_META: StringName = &"police_claim"
const FLANK_GROUP: StringName = &"flank_point"
## Alert states this brain drives; anything else (DOMINATED, TIED, DEAD...) is owned elsewhere.
const ACTIVE_STATES: Array[int] = [Enums.AlertState.CALM, Enums.AlertState.COMBAT]

@export var tweak: PoliceTweak

## Combat hook (NpcGunner): true when the target is visible and in range.
var wants_to_fire: bool = false
## Combat hook (NpcGunner): the CrewController engaged, or null.
var combat_target: Node = null
## &"idle", &"flank", &"cover", &"approach", &"hold", &"back_off" (debug/tests).
var mode: StringName = &"idle"
## Claimed COVER point, or null.
var cover_point: TacticalPoint = null
## Animation hint for the visual layer (characters.md names).
var anim_hint: StringName = &"idle"
var spawn_position: Vector3 = Vector3.ZERO
## Squad order (L4.9): position to move to and hold, Vector3.INF = none.
var order_position: Vector3 = Vector3.INF

var _npc: NpcBase = null
var _motor: NpcMotor = null
var _runtime: HeistRuntime = null
var _started: bool = false
var _active: bool = false
var _retarget_left: float = 0.0
var _target_visible: bool = false
var _flank_point: Node3D = null
var _flank_left: float = 0.0


func _ready() -> void:
	if tweak == null:
		tweak = load(DEFAULT_TWEAK) as PoliceTweak
	_npc = get_parent() as NpcBase
	_motor = _npc.get_node_or_null("Motor") as NpcMotor if _npc != null else null
	if _npc == null or _motor == null:
		Log.error(&"ai", "PoliceBrain needs an NpcBase parent with a Motor (NpcMotor) child")
		return
	_npc.alert_state_changed.connect(_on_alert_state_changed)
	_npc.died.connect(_on_died)
	_start.call_deferred()  # spawn_npc sets the transform after add_child


func _exit_tree() -> void:
	_release_cover()


func _start() -> void:
	if _npc == null or not is_inside_tree() or not Net.is_authority():
		return
	_runtime = HeistRuntime.of(_npc)
	spawn_position = _npc.global_position
	_started = true


func _physics_process(delta: float) -> void:
	if not _started or _npc == null or not _npc.alive or not Net.is_authority():
		return
	if _npc.is_stunned():  # A2-03 (S8.6): ECM feedback stun
		wants_to_fire = false
		return
	if NpcSuppression.is_diving(_npc):  # A3-06 (L3.5): diving for cover, the motor is driven there
		wants_to_fire = false
		return
	if not _active:
		if _runtime == null or not _runtime.went_loud or not ACTIVE_STATES.has(_npc.alert_state):
			return
		_activate()
	if not ACTIVE_STATES.has(_npc.alert_state):
		return
	_retarget_left -= delta
	if _retarget_left <= 0.0 or combat_target == null or not is_instance_valid(combat_target):
		_retarget_left = _roll(tweak.retarget_s)
		_pick_target()
		_choose_position()
	_tick_move(delta)
	var t: Node3D = combat_target as Node3D
	wants_to_fire = t != null and _target_visible \
		and _flat(t.global_position - _npc.global_position).length() <= tweak.fire_range_m


func _activate() -> void:
	_active = true
	_npc.set_alert_state(Enums.AlertState.COMBAT)
	_retarget_left = 0.0
	if GameRng.stream(RNG_STREAM).randf() < tweak.flank_chance:
		_flank_left = tweak.flank_timeout_s
		_pick_target()
		_flank_point = _find_flank_point()


## Server: move to `pos` and hold it (squad formation, L4.9).
func set_order_position(pos: Vector3) -> void:
	order_position = pos
	_flank_point = null
	_release_cover()


func clear_order() -> void:
	order_position = Vector3.INF


func has_order() -> bool:
	return order_position != Vector3.INF


# --- Targeting ---------------------------------------------------------------------------

func _pick_target() -> void:
	combat_target = null
	_target_visible = false
	if _runtime == null:
		return
	var best: float = INF
	var best_any: float = INF
	var any: CrewController = null
	for c: CrewController in _runtime.crew_members():
		if c.crew_state == Enums.CrewState.CUSTODY:
			continue
		var d: float = c.global_position.distance_squared_to(_npc.global_position)
		if c.crew_state != Enums.CrewState.NORMAL and not _cuffable_near(c, d):
			d += 1.0e6  # prefer standing targets (L2.12: a cuffable downed one nearby counts as standing)
		d /= PerkHooks.aggro_weight(c, _npc)  # perk hook (QB-62: perk target-selection weight)
		if d < best_any:
			best_any = d
			any = c
		if d < best and _can_see(c):
			best = d
			combat_target = c
	if combat_target != null:
		_target_visible = true
	else:
		combat_target = any


func _cuffable_near(c: CrewController, dist_sq: float) -> bool:
	var r: float = CustodyTweak.data().police_cuff_approach_m
	return dist_sq <= r * r and CrewCuffs.can_police_cuff(c)


func _can_see(c: CrewController) -> bool:
	return CombatSystem.has_npc_los(_npc, _npc.eye_position(), c.eye_position(), [_npc, c])  # A3-06: shields


# --- Positioning -------------------------------------------------------------------------

func _choose_position() -> void:
	var t: Node3D = combat_target as Node3D
	if t == null:
		_release_cover()
		return
	if _flank_point != null or has_order():
		return
	if cover_point != null and not _cover_ok(cover_point, t):
		_release_cover()
	if cover_point == null:
		var cp: TacticalPoint = _find_cover(t)
		if cp != null:
			cover_point = cp
			cp.set_meta(CLAIM_META, _npc.get_instance_id())


func _tick_move(delta: float) -> void:
	var t: Node3D = combat_target as Node3D
	if has_order():
		if _flat(order_position - _npc.global_position).length() > tweak.arrive_m:
			_move_to(order_position, &"order")
		elif t != null:
			_hold(t.global_position)
		else:
			mode = &"hold"
			anim_hint = &"idle_alert"
			_motor.stop()
		return
	if t == null:
		_motor.stop()
		mode = &"idle"
		anim_hint = &"idle_alert"
		return
	var tpos: Vector3 = t.global_position
	if _tick_cuff(t):
		return
	if _flank_point != null:
		_flank_left -= delta
		if not is_instance_valid(_flank_point) or _flank_left <= 0.0 \
				or _flat(_flank_point.global_position - _npc.global_position).length() <= tweak.arrive_m:
			_flank_point = null
			_retarget_left = 0.0
		else:
			_move_to(_flank_point.global_position, &"flank")
			return
	if cover_point != null:
		if _flat(cover_point.global_position - _npc.global_position).length() > tweak.arrive_m:
			_move_to(cover_point.global_position, &"cover")
		else:
			_hold(tpos)
		return
	var d: float = _flat(tpos - _npc.global_position).length()
	var pushing: bool = _assault_pushing()
	var s_min: float = tweak.assault_standoff_min_m if pushing else tweak.standoff_min_m
	var s_pref: float = tweak.assault_standoff_pref_m if pushing else tweak.standoff_pref_m
	if not _target_visible or d > tweak.standoff_max_m or (mode == &"approach" and d > s_pref):
		_move_to(tpos, &"approach")
	elif d < s_min:
		var away: Vector3 = _flat(_npc.global_position - tpos).normalized()
		_move_to(_npc.global_position + away * (s_pref - d), &"back_off")
	else:
		_hold(tpos)


## PO-5.14: an assault is building or sustaining (L1.1): units push in (assault standoff band).
func _assault_pushing() -> bool:
	var rt: HeistRuntime = HeistRuntime.of(_npc)
	var dir: AssaultDirector = rt.service(G.SVC_DIRECTOR) as AssaultDirector if rt != null else null
	return dir != null and (dir.assault_phase == Enums.AssaultPhase.BUILD or dir.assault_phase == Enums.AssaultPhase.SUSTAIN)


## L2.12: go for / apply the cuffs on a downed, non-shooting target. True while doing so.
func _tick_cuff(t: Node3D) -> bool:
	var tc: CrewController = t as CrewController
	if tc == null or not CrewCuffs.can_police_cuff(tc):
		return false
	var ct: CustodyTweak = CustodyTweak.data()
	var d: float = _flat(tc.global_position - _npc.global_position).length()
	if d > ct.police_cuff_approach_m:
		return false
	_flank_point = null
	_release_cover()
	if d <= ct.police_cuff_range_m:
		_motor.stop()
		_motor.face_point(tc.global_position)
		var cuffs: CrewCuffs = CrewCuffs.of(tc, true)
		if cuffs != null and cuffs.cuff_downed(_npc.net_id):
			mode = &"cuff"
			anim_hint = &"melee"
			_retarget_left = 0.0
		return true
	_move_to(tc.global_position, &"cuff")
	return true


func _move_to(pos: Vector3, new_mode: StringName) -> void:
	mode = new_mode
	var sp: float = _move_speed(new_mode)
	anim_hint = &"run" if sp >= _run_speed() else &"walk"
	if _motor.target == Vector3.INF or _motor.target.distance_to(pos) > 0.5 or not is_equal_approx(_motor.speed, sp):
		_motor.go_to(pos, sp)


## Motor speed for a move in `move_mode` (&"approach", &"cover", &"flank", &"order", ...). Default: run
## (EnemyDef.move_speed); heavy specials walk while advancing (BulwarkBrain / WreckerBrain).
func _move_speed(_move_mode: StringName) -> float:
	return _run_speed()


func _hold(tpos: Vector3) -> void:
	mode = &"hold"
	anim_hint = &"aim"
	_motor.stop()
	_motor.face_point(tpos)


func _find_cover(t: Node3D) -> TacticalPoint:
	if _runtime == null or _runtime.map == null:
		return null
	var best: TacticalPoint = null
	var best_d: float = INF
	for n: Node in _runtime.map.get_slots(G.COVER_POINT):
		var tp: TacticalPoint = n as TacticalPoint
		if tp == null or _claimed_by_other(tp):
			continue
		var d_self: float = _flat(tp.global_position - _npc.global_position).length()
		if d_self > tweak.cover_search_m or d_self >= best_d:
			continue
		if _cover_ok(tp, t):
			best = tp
			best_d = d_self
	return best


func _cover_ok(tp: TacticalPoint, t: Node3D) -> bool:
	if not is_instance_valid(tp):
		return false
	var d: float = _flat(t.global_position - tp.global_position).length()
	if d < tweak.cover_min_m or d > tweak.cover_max_m:
		return false
	var c: CrewController = t as CrewController
	var to: Vector3 = c.eye_position() if c != null else t.global_position + Vector3.UP * 1.5
	return CombatSystem.has_los(_npc, tp.global_position + Vector3(0.0, _npc.head_height, 0.0), to, [_npc, t])


func _claimed_by_other(tp: TacticalPoint) -> bool:
	if not tp.has_meta(CLAIM_META):
		return false
	var owner_id: int = int(tp.get_meta(CLAIM_META))
	if owner_id == _npc.get_instance_id():
		return false
	var o: NpcBase = instance_from_id(owner_id) as NpcBase
	return o != null and is_instance_valid(o) and o.alive


func _release_cover() -> void:
	if cover_point != null and is_instance_valid(cover_point) and cover_point.has_meta(CLAIM_META) \
			and _npc != null and int(cover_point.get_meta(CLAIM_META)) == _npc.get_instance_id():
		cover_point.remove_meta(CLAIM_META)
	cover_point = null


func _find_flank_point() -> Node3D:
	var t: Node3D = combat_target as Node3D
	if t == null or _runtime == null:
		return null
	var best: Node3D = null
	var best_d: float = tweak.flank_max_from_target_m
	for n: Node in _runtime.map.get_slots(FLANK_GROUP):
		var p: Node3D = n as Node3D
		if p == null:
			continue
		var d: float = _flat(p.global_position - t.global_position).length()
		if d < best_d:
			best_d = d
			best = p
	return best


# --- Signals / helpers ---------------------------------------------------------------------

func _on_alert_state_changed(_old_state: int, new_state: int) -> void:
	if ACTIVE_STATES.has(new_state):
		return
	wants_to_fire = false
	combat_target = null
	_release_cover()
	if _motor != null:
		_motor.stop()
		_motor.face(Vector3.ZERO)


func _on_died(_info: Dictionary, _killer_net_id: int) -> void:
	wants_to_fire = false
	combat_target = null
	_release_cover()
	anim_hint = &""
	set_physics_process(false)


func _run_speed() -> float:
	return _npc.enemy_def.move_speed if _npc.enemy_def != null else tweak.fallback_run_speed


func _roll(r: Vector2) -> float:
	return GameRng.stream(RNG_STREAM).randf_range(minf(r.x, r.y), maxf(r.x, r.y))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
