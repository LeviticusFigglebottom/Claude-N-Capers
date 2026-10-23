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
## - PO6-16 (D-114 §5, L1.1 BUILD/SUSTAIN): while the assault pushes, cover farther than assault_cover_max_m
##   from the target is not taken (released), and a unit without cover runs to a push slot: a navmesh point
##   on the assault_slot_radii_m rings around the target with LOS to it (inside the room the crew holds, or
##   its doorway), deepest free one first so a squad fans into the room instead of parking on the threshold;
##   closed doors on the way are opened / breached by the motor (Door.npc_open). No slot found: approach
##   the target itself (assault standoff band).
## - X-5 back-off (GH workshop doorway jam): under the standoff band the unit backs off to ONE latched stand point
##   (tweak back_off_*: s_pref from the target along the away heading, snapped to the navmesh), re-picked only
##   when the target moves. It was recomputed every tick from the unit's own position: in a doorway facing a
##   small room that point fell behind the corridor wall, its route forked east / west around the wall, and each
##   0.2 m step flipped the route, so the cop danced on the threshold (or pressed into a holder there) for the
##   whole ANTICIPATION. No headway for back_off_stall_s: side-step (the next back_off_side_deg heading); none
##   left: hold where it stands (it sees the target) until the target moves.
## - FADE (L1.1): no retreat in P1. Units keep fighting; the director just stops reinforcing.
## - L2.12 (A3-04): a DOWNED target that is not shooting within CustodyTweak.police_cuff_approach_m
##   is walked up to and cuffed at police_cuff_range_m (CrewCuffs.cuff_downed). D-167: regular police only (may_cuff).
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
## PO6-16: current assault push slot (Vector3.INF = none) and the target position it was computed for.
var push_slot: Vector3 = Vector3.INF
var _push_slot_for: Vector3 = Vector3.INF
## PO6-16: seconds the unit has made no headway toward its push slot, and the last slot given up on.
var _push_stall_t: float = 0.0
var _push_bad_slot: Vector3 = Vector3.INF
## X-5: latched back-off stand point (Vector3.INF = none), the target position it was picked for, the heading index
## tried (tweak back_off_side_deg), the farthest flat distance from the target reached and the seconds without gain.
## _back_off_hold_for: target position a blocked back-off gave up at (hold instead), Vector3.INF = none.
var _back_off_to: Vector3 = Vector3.INF
var _back_off_for: Vector3 = Vector3.INF
var _back_off_try: int = 0
var _back_off_best_d: float = 0.0
var _back_off_stall_t: float = 0.0
var _back_off_hold_for: Vector3 = Vector3.INF

var _npc: NpcBase = null
var _motor: NpcMotor = null
var _runtime: HeistRuntime = null
var _started: bool = false
var _active: bool = false
var _retarget_left: float = 0.0
var _target_visible: bool = false
var _flank_point: Node3D = null
var _flank_left: float = 0.0
## D-108: the arrest hold on a downed crew member (s), and the physics frame it last advanced.
var _cuff_hold: float = 0.0
var _cuff_frame: int = -1
var _cuff_target: CrewController = null
## D-168: crew net id -> heist time it last damaged this unit or a squadmate nearby (target scoring threat term).
var _threat: Dictionary[int, float] = {}


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
	_npc.damaged.connect(func(_i: Dictionary, _a: int) -> void: _cuff_hold = 0.0)  # D-108: hurt cop restarts
	_npc.damaged.connect(_on_damaged_threat)
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
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"police_brain", fp)


func _physics_step(delta: float) -> void:
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
			if _npc.alert_state == Enums.AlertState.CALM and _npc.spawn_info.get("idle_activity", &"") != &"":
				anim_hint = _calm_activity()  # D (AH cast): the off-duty cop sits in his booth before the alarm
			return
		_activate()
	if not ACTIVE_STATES.has(_npc.alert_state):
		return
	_retarget_left -= delta
	if _retarget_left <= 0.0 or combat_target == null or not is_instance_valid(combat_target):
		_retarget_left = _roll(tweak.retarget_s)
		var fp: int = FrameProf.begin()
		_pick_target()
		FrameProf.end(&"police_brain.pick_target", fp)
		fp = FrameProf.begin()
		_choose_position()
		FrameProf.end(&"police_brain.choose_position", fp)
	var fm: int = FrameProf.begin()
	_tick_move(delta)
	FrameProf.end(&"police_brain.move", fm)
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
	var prev: Node = combat_target
	combat_target = null
	_target_visible = false
	if _runtime == null:
		return
	var best: float = INF
	var best_any: float = INF
	var any: Node3D = null
	for c: CrewController in _runtime.crew_members():
		if c.crew_state == Enums.CrewState.CUSTODY:
			continue
		var d: float = c.global_position.distance_squared_to(_npc.global_position)
		if c.crew_state != Enums.CrewState.NORMAL and not _cuffable_near(c, d):
			d += 1.0e6  # prefer standing targets (L2.12: a cuffable downed one nearby counts as standing)
		d *= _threat_mult(c, prev)
		d /= PerkHooks.aggro_weight(c, _npc)  # perk hook (QB-62: perk target-selection weight)
		if d < best_any:
			best_any = d
			any = c
		if d < best and _can_see(c):
			best = d
			combat_target = c
	for n: Node in _npc.get_tree().get_nodes_in_group(SentryGun.GROUP):  # D-157: crew sentries draw fire (PD2)
		var sg: SentryGun = n as SentryGun
		if sg == null or not sg.alive() or HeistRuntime.of(sg) != _runtime:
			continue
		var ds: float = sg.global_position.distance_squared_to(_npc.global_position) / sg.threat_mult()
		if ds < best_any:
			best_any = ds
			any = sg
		if ds < best and CombatSystem.has_npc_los(_npc, _npc.eye_position(), sg.aim_point(), [_npc, sg]):
			best = ds
			combat_target = sg
	if combat_target != null:
		_target_visible = true
	else:
		combat_target = any


## D-168 ◇: distance² factor for crew `c`: threat_dist_mult when it hurt this unit or a squadmate within the threat
## window, sticky_dist_mult when it is the current target.
func _threat_mult(c: CrewController, prev: Node) -> float:
	var m: float = tweak.sticky_dist_mult if c == prev else 1.0
	var t: float = _threat.get(c.net_id, -INF)
	if _runtime != null and _runtime.heist_time_s - t <= tweak.threat_window_s:
		m *= tweak.threat_dist_mult
	return m


## Server (D-168): crew `attacker_net_id` hurt this unit: remember it here and on the squadmates within threat_squad_m.
func _on_damaged_threat(_info: Dictionary, attacker_net_id: int) -> void:
	if _runtime == null or not Ids.lookup(attacker_net_id) is CrewController:
		return
	var now: float = _runtime.heist_time_s
	_threat[attacker_net_id] = now
	var r2: float = tweak.threat_squad_m * tweak.threat_squad_m
	for node: Node in _runtime.npcs():
		var n: NpcBase = node as NpcBase
		if n == null or n == _npc or not n.alive or n.global_position.distance_squared_to(_npc.global_position) > r2:
			continue
		var b: PoliceBrain = n.get_node_or_null(^"Brain") as PoliceBrain
		if b != null:
			b._threat[attacker_net_id] = now


func _cuffable_near(c: CrewController, dist_sq: float) -> bool:
	var r: float = CustodyTweak.data().police_cuff_approach_m
	return dist_sq <= r * r and may_cuff(_npc) and CrewCuffs.can_police_cuff(c)


## D-167.1: only regular police arrest a downed heister; specials (Wrecker, Bulwark, Phantom, Stinger, Corpsman,
## Longshot) and Brandt / Aegis fight on (PD2: dozers and specials do not arrest).
static func may_cuff(npc: NpcBase) -> bool:
	if npc == null or AegisCaptain.is_aegis_unit(npc):
		return false
	return npc.enemy_def == null or not npc.enemy_def.is_special


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


## D (AH cast): a CALM unit placed at a SpawnPoint with an idle activity (the off-duty cop's `sit` in his booth) plays
## it (standing when there is no seat under him, PO6-06); otherwise the alert stand.
func _calm_activity() -> StringName:
	var act: StringName = StringName(_npc.spawn_info.get("idle_activity", &""))
	return CivilianBrain.seated_or_standing(_npc, act) if act != &"" else &"idle_alert"


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
		anim_hint = _calm_activity() if _npc.alert_state == Enums.AlertState.CALM else &"idle_alert"
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
	if not pushing:
		push_slot = Vector3.INF  # PO6-16: a slot only lives through BUILD / SUSTAIN
	elif _tick_push(t, d, delta):
		return
	var s_min: float = tweak.assault_standoff_min_m if pushing else tweak.standoff_min_m
	var s_pref: float = tweak.assault_standoff_pref_m if pushing else tweak.standoff_pref_m
	var backing: bool = false
	if not _target_visible or d > tweak.standoff_max_m or (mode == &"approach" and d > s_pref):
		_move_to(tpos, &"approach")
	elif d < s_min:
		backing = true
		_tick_back_off(tpos, d, s_pref, delta)
	else:
		_hold(tpos)
	if not backing:
		_back_off_to = Vector3.INF
		_back_off_hold_for = Vector3.INF


## X-5: back off from `tpos` (flat distance d < the standoff min) to a latched stand point; side-step / hold when
## blocked (see the header).
func _tick_back_off(tpos: Vector3, d: float, s_pref: float, delta: float) -> void:
	var refresh: float = tweak.back_off_refresh_m
	if _back_off_hold_for != Vector3.INF and _flat(tpos - _back_off_hold_for).length() <= refresh:
		_hold(tpos)  # backing off is blocked here: stand and fight until the target moves
		return
	_back_off_hold_for = Vector3.INF
	if _back_off_to == Vector3.INF or mode != &"back_off" or _flat(tpos - _back_off_for).length() > refresh:
		_back_off_try = 0
		_back_off_to = _pick_back_off(tpos, d, s_pref)
	elif d > _back_off_best_d + tweak.back_off_progress_m:
		_back_off_best_d = d
		_back_off_stall_t = 0.0
	else:
		_back_off_stall_t += delta
		if _back_off_stall_t >= tweak.back_off_stall_s:
			_back_off_try += 1
			_back_off_to = _pick_back_off(tpos, d, s_pref)
	if _back_off_to == Vector3.INF:
		_back_off_hold_for = tpos
		_hold(tpos)
		return
	_move_to(_back_off_to, &"back_off")


## X-5: the stand point for heading try _back_off_try and later ones: s_pref from `tpos` along the away heading
## turned by back_off_side_deg[i], snapped to the navmesh on this floor, and farther from the target than d +
## back_off_progress_m. Resets the stall clock; Vector3.INF when no heading is left.
func _pick_back_off(tpos: Vector3, d: float, s_pref: float) -> Vector3:
	_back_off_for = tpos
	_back_off_best_d = d
	_back_off_stall_t = 0.0
	var away: Vector3 = _flat(_npc.global_position - tpos)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var nav_map: RID = _npc.get_world_3d().navigation_map if _npc.is_inside_tree() else RID()
	var has_nav: bool = nav_map.is_valid() and not NavigationServer3D.map_get_regions(nav_map).is_empty()
	var sides: PackedFloat32Array = tweak.back_off_side_deg
	while _back_off_try < sides.size():
		var cand: Vector3 = tpos + away.rotated(Vector3.UP, deg_to_rad(sides[_back_off_try])) * s_pref
		cand.y = _npc.global_position.y
		if has_nav:
			cand = NavigationServer3D.map_get_closest_point(nav_map, cand)
		if absf(cand.y - _npc.global_position.y) <= tweak.assault_slot_max_dy_m \
				and _flat(cand - tpos).length() >= d + tweak.back_off_progress_m:
			return cand
		_back_off_try += 1
	return Vector3.INF


## PO6-16: run to / hold the push slot near `t` (d = flat distance to it). False when there is no slot (the
## caller approaches the target itself).
func _tick_push(t: Node3D, d: float, delta: float) -> bool:
	var tpos: Vector3 = t.global_position
	if push_slot == Vector3.INF or _push_slot_for == Vector3.INF \
			or _flat(tpos - _push_slot_for).length() > tweak.assault_slot_refresh_m:
		push_slot = _find_push_slot(t)
		_push_slot_for = tpos
		_push_stall_t = 0.0
	if push_slot == Vector3.INF:
		return false
	if d < tweak.assault_standoff_min_m and _target_visible:
		_hold(tpos)  # already at arm's length: no need to walk to the slot (cuffing has its own path)
		return true
	# No early hold inside the standoff band: in a small room that band ends at the doorway, where holders
	# stacked up and their separation push stopped the units behind them (PO6-16, Golden Hour office).
	if _flat(push_slot - _npc.global_position).length() > tweak.assault_slot_arrive_m:
		# Stalled (a unit standing on / next to the slot cancels the separation steer): in sight of the target,
		# hold here; out of sight, give the slot up and take another.
		var moving: bool = _flat(_npc.velocity).length() > tweak.assault_push_stall_speed \
			or _motor.waiting_door != null  # opening / breaching a door is not a stall
		_push_stall_t = 0.0 if moving or mode != &"push" else _push_stall_t + delta
		if _push_stall_t >= tweak.assault_push_stall_s:
			_push_stall_t = 0.0
			if _target_visible:
				push_slot = _npc.global_position
			else:
				_push_bad_slot = push_slot
				push_slot = _find_push_slot(t)
				_push_slot_for = tpos
				if push_slot == Vector3.INF:
					return false
		if _flat(push_slot - _npc.global_position).length() > tweak.assault_slot_arrive_m:
			_move_to(push_slot, &"push")
			return true
	if not _target_visible:
		push_slot = Vector3.INF  # the slot lost sight of the target (it moved behind something): re-pick
		return false
	_hold(tpos)
	return true


## PO6-16: a reachable navmesh point around `t` with LOS to its eyes (same room / its doorway): rings at
## assault_slot_radii_m x 8 angles (this unit's angle first). Score = distance to the target (deeper into the
## room first, so nobody parks on the threshold) + assault_slot_taken_penalty_m per other unit's slot within
## assault_slot_spacing_m. Vector3.INF when none.
func _find_push_slot(t: Node3D) -> Vector3:
	var tpos: Vector3 = t.global_position
	var c: CrewController = t as CrewController
	var eye: Vector3 = c.eye_position() if c != null else tpos + Vector3.UP * 1.5
	var nav_map: RID = _npc.get_world_3d().navigation_map if _npc.is_inside_tree() else RID()
	var has_nav: bool = nav_map.is_valid() and not NavigationServer3D.map_get_regions(nav_map).is_empty()
	var taken: Array[Vector3] = _other_push_slots()
	if _push_bad_slot != Vector3.INF:
		taken.append(_push_bad_slot)
	# X-5: the start angle comes from the net id (spawn order, the same every run of a seed). It was the instance id,
	# which shifts with every object allocated before (a batch run vs one test), so the push differed between runs.
	var base: float = float(posmod(_npc.net_id, 8)) * TAU / 8.0
	var best: Vector3 = Vector3.INF
	var best_score: float = INF
	for r: float in tweak.assault_slot_radii_m:
		for i: int in range(8):
			var a: float = base + float(i) * TAU / 8.0
			var cand: Vector3 = tpos + Vector3(cos(a), 0.0, sin(a)) * r
			if has_nav:
				var snap: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, cand)
				if _flat(snap - cand).length() > tweak.assault_slot_snap_m:
					continue
				cand = snap
			if absf(cand.y - tpos.y) > tweak.assault_slot_max_dy_m:
				continue
			var score: float = r + float(i) * 0.01  # own angle first among equals
			for q: Vector3 in taken:
				if _flat(q - cand).length() < tweak.assault_slot_spacing_m:
					score += tweak.assault_slot_taken_penalty_m
			if score >= best_score:
				continue
			if not CombatSystem.has_los(_npc, cand + Vector3(0.0, _npc.head_height, 0.0), eye, [_npc, t]):
				continue
			best_score = score
			best = cand
	return best


## PO6-16: push slots held by the other police brains of this heist.
func _other_push_slots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _runtime == null:
		return out
	for n: Node in _runtime.npcs():
		var o: NpcBase = n as NpcBase
		if o == null or o == _npc or not o.alive:
			continue
		var b: PoliceBrain = o.get_node_or_null(^"Brain") as PoliceBrain
		if b != null and b.push_slot != Vector3.INF:
			out.append(b.push_slot)
	return out


## PO-5.14: an assault is building or sustaining (L1.1): units push in (assault standoff band).
func _assault_pushing() -> bool:
	var rt: HeistRuntime = HeistRuntime.of(_npc)
	var dir: AssaultDirector = rt.service(G.SVC_DIRECTOR) as AssaultDirector if rt != null else null
	return dir != null and (dir.assault_phase == Enums.AssaultPhase.BUILD or dir.assault_phase == Enums.AssaultPhase.SUSTAIN)


## L2.12: go for / apply the cuffs on a downed, non-shooting target. True while doing so.
func _tick_cuff(t: Node3D) -> bool:
	var tc: CrewController = t as CrewController
	if tc == null or not may_cuff(_npc) or not CrewCuffs.can_police_cuff(tc):
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
		mode = &"cuff"
		anim_hint = &"cuff"  # D-115: kneel and cuff (interact_low), as GuardBrain; `melee` held a finished one-shot
		# D-108: the arrest takes police_cuff_time_s of uninterrupted hold (a skipped frame, i.e. stunned /
		# diving / retargeting, a new target or a hit on this cop restarts it).
		var frame: int = Engine.get_physics_frames()
		if _cuff_target != tc or _cuff_frame != frame - 1:
			_cuff_hold = 0.0
		_cuff_target = tc
		_cuff_frame = frame
		_cuff_hold += 1.0 / float(Engine.physics_ticks_per_second)
		if _cuff_hold < ct.police_cuff_time_s:
			return true
		_cuff_hold = 0.0
		var cuffs: CrewCuffs = CrewCuffs.of(tc, true)
		if cuffs != null and cuffs.cuff_downed(_npc.net_id):
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
	if d > tweak.assault_cover_max_m and _assault_pushing():
		return false  # PO6-16: no cover outside the room during the push
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
