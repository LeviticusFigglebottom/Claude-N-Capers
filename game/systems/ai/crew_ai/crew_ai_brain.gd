## AI teammate brain (A1-10): child `CrewAiBrain` of an AI CrewController. Owner: ENV A.
## Server only. Produces one CrewIntent per physics tick and feeds it through the single entry point
## `CrewController.apply_intent` (crew_intent.md). Inactive while a test bot drives the slot
## (`HeistRuntime.has_bot_intent`), while the slot is human, or with launch option "crew_ai": false.
## Fidelity rows:
## - L6.1 / D-014 stealth: the AI waits at its spawn ("in the van"): it never moves and
##   `crew.stealth_hidden = true`, so the StealthDirector never observes it. P4: a "follow" order
##   will make it detectable like a player (hook: `receive_order`).
## - L6.1 loud: unhidden and masked (the alarm masks everyone). Priorities each tick:
##   1. revive a DOWNED crew member (humans first, then AI; each downed member is assigned the nearest
##      free AI) — walk to revive_range_m, hold interact with interact_target_net_id for the full
##      revive (L2.7, 6 s), and keep at it under fire (re-press after a damage interrupt, S9.1);
##   2. fight: nearest visible hostile police/special/guard (guards only when ALARMED/COMBAT), aim
##      at chest/head with an aim error (GameRng &"crew_ai"), pulse the trigger, reload when empty
##      (or tactically when no enemy is visible);
##   3. follow the nearest alive human (slot 0 fallback) within follow_min_m..follow_max_m, taking a
##      free COVER TacticalPoint near the leader while enemies are visible.
##   No objectives, no bags (L6.1 bag carrying on order is P3).
## Movement: NavigationServer3D path on the crew's world navigation map, straight-line fallback.
## All numbers: CrewAiTweak (crew_ai_tweak.tres).
class_name CrewAiBrain
extends Node

enum Mode { INACTIVE, STEALTH_WAIT, IDLE, REVIVE, COVER, FOLLOW }

const NODE_NAME: String = "CrewAiBrain"
const RNG_STREAM: StringName = &"crew_ai"
const TWEAK_PATH: String = "res://systems/ai/crew_ai/crew_ai_tweak.tres"
const WORLD_MASK: int = (1 << 0) | (1 << 1)
const HOSTILE_ROLES: Array[StringName] = [&"police", &"special", &"guard"]

@export var tweak: CrewAiTweak

var mode: Mode = Mode.INACTIVE
## Current enemy target (null when none is visible).
var target_enemy: NpcBase = null
## Downed crew member this AI is reviving (null when none is assigned to it).
var revive_target: CrewController = null
## Cover point currently used (null when none).
var cover_point: Node3D = null
## Last order received from a human (P3/P4 hook; stored only, no behaviour yet).
var order: StringName = &""
var order_target_net_id: int = 0
var order_position: Vector3 = Vector3.ZERO

var _crew: CrewController = null
var _rt: HeistRuntime = null
var _yaw: float = 0.0
var _pitch: float = 0.0
var _following: bool = false
var _path: PackedVector3Array = PackedVector3Array()
var _path_idx: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_left: float = 0.0
var _scan_left: float = 0.0
var _since_acquire: float = 0.0
var _shot_left: float = 0.0
var _fire_latch: bool = false
var _reload_latch: bool = false
var _aim_offset: Vector3 = Vector3.ZERO
var _aim_head: bool = false
var _interact_ticks: int = 0


func _ready() -> void:
	name = NODE_NAME
	_crew = get_parent() as CrewController
	if _crew == null:
		Log.error(&"crew_ai", "CrewAiBrain must be a child of a CrewController")
		set_physics_process(false)
		return
	if tweak == null:
		tweak = load(TWEAK_PATH) as CrewAiTweak
	# Before CrewController (0) simulates, after HeistRuntime (-100) applies bot intents.
	process_physics_priority = -50
	_rt = HeistRuntime.of(self)


## The brain of an AI crew member (null for humans / scenes without one).
static func of(crew: Node) -> CrewAiBrain:
	return crew.get_node_or_null(NODE_NAME) as CrewAiBrain if crew != null else null


## True while this brain drives its crew member.
func is_active() -> bool:
	if _crew == null or not _crew.is_ai or not Net.is_authority():
		return false
	if _rt == null:
		_rt = HeistRuntime.of(self)
	if _rt == null or _rt.has_bot_intent(_crew.slot):
		return false
	return bool(_rt.options.get("crew_ai", true))


## P3/P4 hook: a human ordered this AI (crew_intent.md orders). Stored only for now.
func receive_order(p_order: StringName, target_net_id: int = 0, position: Vector3 = Vector3.ZERO) -> void:
	order = p_order
	order_target_net_id = target_net_id
	order_position = position


func _physics_process(delta: float) -> void:
	if not is_active():
		if mode != Mode.INACTIVE and _crew != null:
			_crew.stealth_hidden = false
		mode = Mode.INACTIVE
		return
	if mode == Mode.INACTIVE:
		_yaw = _crew.look_yaw
		_pitch = _crew.look_pitch
		_path = PackedVector3Array()
	if not _rt.went_loud:
		# D-014: wait at the van, undetectable.
		mode = Mode.STEALTH_WAIT
		_crew.stealth_hidden = true
		_crew.apply_intent(_idle_intent())
		return
	_crew.stealth_hidden = false
	if not _crew.masked:
		_crew.set_masked(true)
	_crew.apply_intent(_think(delta))


func _idle_intent() -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	_yaw = _crew.look_yaw
	_pitch = _crew.look_pitch
	i.look_yaw = _yaw
	i.look_pitch = _pitch
	return i


# --- Loud ----------------------------------------------------------------------------------------

func _think(delta: float) -> CrewIntent:
	var st: int = _crew.crew_state
	var mobile: bool = st == Enums.CrewState.NORMAL or st == Enums.CrewState.SWAN_SONG
	if not mobile and st != Enums.CrewState.DOWNED:
		mode = Mode.IDLE
		target_enemy = null
		_interact_ticks = 0
		return _idle_intent()
	var i: CrewIntent = CrewIntent.new()
	_tick_scan(delta)
	var eye: Vector3 = _crew.eye_position()
	var look_point: Vector3 = Vector3.INF
	var wish: Vector3 = Vector3.ZERO
	var goal_dist: float = 0.0
	var interacting: bool = false
	revive_target = _pick_revive_target() if st == Enums.CrewState.NORMAL else null
	if revive_target != null:
		mode = Mode.REVIVE
		cover_point = null
		var d: float = _flat_dist(_crew.global_position, revive_target.global_position)
		if d > tweak.revive_range_m:
			wish = _steer(revive_target.global_position, delta)
			goal_dist = d
			_interact_ticks = 0
		else:
			look_point = revive_target.global_position + Vector3(0.0, 0.4, 0.0)
			interacting = _hold_revive(i)
	elif mobile:
		var goal: Vector3 = _follow_goal()
		if goal != Vector3.INF:
			goal_dist = _flat_dist(_crew.global_position, goal)
			wish = _steer(goal, delta)
		_interact_ticks = 0
	if not mobile:
		wish = Vector3.ZERO
	if look_point == Vector3.INF and target_enemy != null and not interacting:
		look_point = _aim_point(target_enemy)
	if look_point == Vector3.INF and wish.length() > 0.01:
		look_point = eye + wish * 5.0
	_turn_toward(look_point, eye, delta)
	i.look_yaw = _yaw
	i.look_pitch = _pitch
	if wish.length() > 0.01:
		var local: Vector3 = Basis(Vector3.UP, _yaw).inverse() * wish
		i.move = Vector2(local.x, -local.z).limit_length(1.0)
		i.sprint = target_enemy == null and goal_dist > tweak.sprint_beyond_m
	_weapon_controls(i, eye, delta, interacting)
	return i


## Hold interact on the assigned downed crew member once settled. Returns true while holding.
func _hold_revive(i: CrewIntent) -> bool:
	var hv: float = Vector2(_crew.velocity.x, _crew.velocity.z).length()
	if hv > tweak.revive_settle_speed:
		_interact_ticks = 0
		return false
	var sess: Dictionary = _rt.interaction.session(_crew.slot) if _rt.interaction != null else {}
	if _interact_ticks > 0 and sess.is_empty():
		# Cancelled (damage interrupt S9.1) or refused: release for one tick, then press again.
		_interact_ticks = 0
		return false
	i.interact = true
	i.interact_target_net_id = revive_target.net_id
	_interact_ticks += 1
	return true


## Downed crew members in priority order (humans first, then by slot), each assigned the nearest
## free AI; returns the one assigned to this AI (deterministic: every brain computes the same).
func _pick_revive_target() -> CrewController:
	var downed: Array[CrewController] = []
	var free_ai: Array[CrewController] = []
	for c: CrewController in _rt.crew_members():
		if c.crew_state == Enums.CrewState.DOWNED:
			downed.append(c)
		elif c.is_ai and c.crew_state == Enums.CrewState.NORMAL:
			var b: CrewAiBrain = CrewAiBrain.of(c)
			if b != null and b.is_active():
				free_ai.append(c)
	if downed.is_empty() or not free_ai.has(_crew):
		return null
	downed.sort_custom(func(a: CrewController, b: CrewController) -> bool:
		if a.is_ai != b.is_ai:
			return not a.is_ai
		return a.slot < b.slot)
	for t: CrewController in downed:
		var best: CrewController = null
		var best_d: float = INF
		for c: CrewController in free_ai:
			var d: float = c.global_position.distance_to(t.global_position)
			if d < best_d - 0.001:
				best = c
				best_d = d
		if best == null:
			return null
		if best == _crew:
			return t
		free_ai.erase(best)
	return null


## Movement goal while following (cover near the leader when enemies are visible), or INF.
func _follow_goal() -> Vector3:
	var leader: CrewController = _pick_leader()
	if leader == null:
		mode = Mode.IDLE
		return Vector3.INF
	if target_enemy != null:
		var cp: Node3D = _pick_cover(leader)
		cover_point = cp
		if cp != null:
			mode = Mode.COVER
			_following = false
			if _flat_dist(_crew.global_position, cp.global_position) <= tweak.cover_arrive_m:
				return Vector3.INF
			return cp.global_position
	else:
		cover_point = null
	mode = Mode.FOLLOW
	var d: float = _flat_dist(_crew.global_position, leader.global_position)
	if _following and d <= tweak.follow_stop_m:
		_following = false
	elif not _following and d > tweak.follow_max_m:
		_following = true
	if not _following:
		return Vector3.INF
	# Aim for a point follow_min_m short of the leader, on our side, so AI never crowd the human.
	var to_me: Vector3 = _crew.global_position - leader.global_position
	to_me.y = 0.0
	if to_me.length() < 0.01:
		return Vector3.INF
	return leader.global_position + to_me.normalized() * tweak.follow_min_m


## Nearest alive human (not this crew member), else slot 0.
func _pick_leader() -> CrewController:
	var best: CrewController = null
	var best_d: float = INF
	for c: CrewController in _rt.crew_members():
		if c == _crew or c.is_ai or c.crew_state == Enums.CrewState.CUSTODY:
			continue
		var d: float = c.global_position.distance_to(_crew.global_position)
		if d < best_d:
			best = c
			best_d = d
	if best == null:
		var s0: CrewController = _rt.crew_controller(0) as CrewController
		if s0 != null and s0 != _crew and s0.crew_state != Enums.CrewState.CUSTODY:
			best = s0
	return best


func _pick_cover(leader: CrewController) -> Node3D:
	if cover_point != null and is_instance_valid(cover_point) and _cover_ok(cover_point, leader):
		return cover_point
	var best: Node3D = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(G.COVER_POINT):
		var p: Node3D = n as Node3D
		if p == null or not _rt.is_ancestor_of(p) or not _cover_ok(p, leader):
			continue
		var d: float = p.global_position.distance_to(_crew.global_position)
		if d < best_d:
			best = p
			best_d = d
	return best


func _cover_ok(p: Node3D, leader: CrewController) -> bool:
	if _flat_dist(p.global_position, leader.global_position) > tweak.cover_search_radius_m:
		return false
	for c: CrewController in _rt.crew_members():
		if c == _crew:
			continue
		if _flat_dist(c.global_position, p.global_position) < tweak.cover_taken_m:
			return false
		var b: CrewAiBrain = CrewAiBrain.of(c)
		if b != null and b.cover_point == p:
			return false
	return true


# --- Navigation ----------------------------------------------------------------------------------

## Horizontal unit direction toward `goal` along the nav path (straight line without a navmesh).
func _steer(goal: Vector3, delta: float) -> Vector3:
	_repath_left -= delta
	if _path.is_empty() or _repath_left <= 0.0 or goal.distance_to(_path_goal) > tweak.repath_goal_move_m:
		_plan(goal)
	var pos: Vector3 = _crew.global_position
	while _path_idx < _path.size() - 1 and _flat_dist(pos, _path[_path_idx]) < tweak.waypoint_reach_m:
		_path_idx += 1
	var next: Vector3 = _path[_path_idx] if _path_idx < _path.size() else goal
	if _door_hold(pos):
		return Vector3.ZERO
	var dir: Vector3 = next - pos
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.05 else Vector3.ZERO


func _plan(goal: Vector3) -> void:
	_path_goal = goal
	_repath_left = tweak.repath_interval_s
	_path_idx = 0
	_path = PackedVector3Array()
	var nav_map: RID = _crew.get_world_3d().navigation_map
	if nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0 \
			and not NavigationServer3D.map_get_regions(nav_map).is_empty():
		_path = NavigationServer3D.map_get_path(nav_map, _crew.global_position, goal, true)
	if _path.size() < 2:
		_path = PackedVector3Array([goal])
	elif _flat_dist(_path[_path.size() - 1], goal) > 0.5:
		_path.append(goal)


## A2-01 (QA-11): a closed door within reach on the path: ask it to open (unlocked doors only) and
## hold position until it is open; a locked door stops the AI in front of it.
func _door_hold(pos: Vector3) -> bool:
	var tw: InteractionTweak = Tweak.interaction()
	var pts: PackedVector3Array = PackedVector3Array([pos])
	for i: int in range(_path_idx, _path.size()):
		pts.append(_path[i])
	var hit: Dictionary = Door.first_closed_on_path(get_tree(), pts, tw.npc_door_lookahead_m)
	var door: Door = hit.get("door") as Door
	if door == null or float(hit["distance"]) > tw.npc_door_reach_m:
		return false
	door.npc_open(_crew)
	return true


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Fighting ------------------------------------------------------------------------------------

func _tick_scan(delta: float) -> void:
	_since_acquire += delta
	if target_enemy != null and (not is_instance_valid(target_enemy) or not _is_hostile(target_enemy)):
		target_enemy = null
		_scan_left = 0.0
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = tweak.scan_interval_s
	var eye: Vector3 = _crew.eye_position()
	var best: NpcBase = null
	var best_d: float = INF
	for role: StringName in HOSTILE_ROLES:
		for n: Node in _rt.npcs(role):
			var npc: NpcBase = n as NpcBase
			if npc == null or not _is_hostile(npc):
				continue
			var p: Vector3 = npc.global_position + Vector3(0.0, tweak.chest_height_m, 0.0)
			var d: float = eye.distance_to(p)
			if d > tweak.engage_range_m or d >= best_d or not _has_los(eye, p):
				continue
			best = npc
			best_d = d
	if best != target_enemy:
		_since_acquire = 0.0
		_roll_aim()
	target_enemy = best


func _is_hostile(npc: NpcBase) -> bool:
	if not npc.alive or NpcBase.BLIND_STATES.has(npc.alert_state):
		return false
	if npc.role == &"guard":
		return npc.alert_state == Enums.AlertState.COMBAT or npc.alert_state == Enums.AlertState.ALARMED
	return HOSTILE_ROLES.has(npc.role)


func _has_los(from: Vector3, to: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	q.exclude = [_crew.get_rid()]
	return _crew.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _roll_aim() -> void:
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	_aim_head = rng.randf() < tweak.head_aim_chance
	var v: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
	_aim_offset = v.limit_length(1.0) * tweak.aim_error_m


func _aim_point(npc: NpcBase) -> Vector3:
	var base: Vector3 = npc.head_position() if _aim_head else npc.global_position + Vector3(0.0, tweak.chest_height_m, 0.0)
	return base + _aim_offset


func _weapon_controls(i: CrewIntent, eye: Vector3, delta: float, interacting: bool) -> void:
	_shot_left -= delta
	var w: CrewWeapons = _crew.weapons
	var fire: bool = false
	var reload: bool = false
	if w != null and not interacting and not w.reloading:
		var ws: int = w.equipped_slot
		var mag: int = w.mag(ws)
		if mag <= 0:
			if w.reserve(ws) > 0:
				reload = true
			else:
				_switch_to_loaded(i, w)
		elif target_enemy != null:
			var to: Vector3 = _aim_point(target_enemy) - eye
			var view: Vector3 = _view_dir()
			if w.can_fire() and _since_acquire >= tweak.reaction_time_s and _shot_left <= 0.0 \
					and not _fire_latch and view.angle_to(to) <= deg_to_rad(tweak.fire_cone_deg):
				fire = true
				_shot_left = tweak.shot_interval_s
		elif mag < int(ceil(float(w.mag_size(ws)) * tweak.tactical_reload_frac)) and w.reserve(ws) > 0:
			reload = true
	i.fire = fire
	if fire:
		_roll_aim()
	_fire_latch = fire
	i.reload = reload and not _reload_latch
	_reload_latch = i.reload


func _switch_to_loaded(i: CrewIntent, w: CrewWeapons) -> void:
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if ws != w.equipped_slot and w.has_weapon(ws) and w.mag(ws) + w.reserve(ws) > 0:
			i.weapon_slot = ws
			return


# --- Look ----------------------------------------------------------------------------------------

func _view_dir() -> Vector3:
	return Vector3(-sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch))


func _turn_toward(point: Vector3, eye: Vector3, delta: float) -> void:
	if point == Vector3.INF:
		return
	var d: Vector3 = point - eye
	if d.length() < 0.01:
		return
	var want_yaw: float = atan2(-d.x, -d.z)
	var want_pitch: float = atan2(d.y, Vector2(d.x, d.z).length())
	var step: float = deg_to_rad(tweak.turn_speed_deg) * delta
	var dy: float = angle_difference(_yaw, want_yaw)
	_yaw = wrapf(_yaw + clampf(dy, -step, step), -PI, PI)
	_pitch += clampf(want_pitch - _pitch, -step, step)
