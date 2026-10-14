## AI teammate brain (A1-10): child `CrewAiBrain` of an AI CrewController. Owner: ENV A.
## Server only. Produces one CrewIntent per physics tick and feeds it through the single entry point
## `CrewController.apply_intent` (crew_intent.md). Inactive while a test bot drives the slot
## (`HeistRuntime.has_bot_intent`), while the slot is human, or with launch option "crew_ai": false.
## Fidelity rows:
## - L6.1 / D-014 stealth: the AI waits at its spawn ("in the van"): it never moves and
##   `crew.stealth_hidden = true`, so the StealthDirector never observes it. P4: a "follow" order
##   makes it detectable like a player (A3-05, tweak `stealth_follow_enabled`): it is then unhidden,
##   follows its leader, mirrors the leader's mask and crouch, and stays detectable for the rest of
##   the stealth phase (even when later ordered to hold).
## - L6.1 loud: unhidden and masked (the alarm masks everyone). Priorities each tick:
##   1. revive a DOWNED, CLOAKER_DOWNED or TASED crew member (needs_help; humans first, then AI; each is assigned the nearest
##      free AI) — walk to revive_range_m, hold interact with interact_target_net_id for the full
##      revive (L2.7, 6 s), and keep at it under fire (re-press after a damage interrupt, S9.1);
##   2. fight: nearest visible hostile police/special/guard (guards only when ALARMED/COMBAT; a Stinger
##      tasing a crew member first, tasing_stinger_score_mult), aim
##      at chest/head with an aim error (GameRng &"crew_ai"), pulse the trigger, reload when empty
##      (or tactically when no enemy is visible);
##   3. follow the nearest alive human (slot 0 fallback) within follow_min_m..follow_max_m, taking a
##      free COVER TacticalPoint near the leader while enemies are visible.
##   No objectives. Bags only on order.
## - L6.1 orders (A3-05, CrewOrders resolves the receiver): `stance` follow (default) / hold (stay at
##   the hold point, still fight, revive only within hold_revive_radius_m); `task` carry_bag (walk to
##   the bag, pick it up via LootManager.carry, follow the leader, drop it facing a known SECURE_LOOT
##   zone within secure_seek_radius_m) / revive (this AI takes that downed crew member before the
##   automatic assignment); drop_bag (one-shot). The ordering human becomes the leader. Each
##   accepted order requests `vo.crew.ack_<order>` (voice_line_requested [R]).
## Movement: NavigationServer3D path on the crew's world navigation map, straight-line fallback.
## All numbers: CrewAiTweak (crew_ai_tweak.tres).
class_name CrewAiBrain
extends Node

enum Mode { INACTIVE, STEALTH_WAIT, IDLE, REVIVE, COVER, FOLLOW, HOLD, FETCH_BAG, SECURE_BAG }

## Hip height probed by _sees_any (m).
const SIGHT_HIPS_M: float = 0.9
const NODE_NAME: String = "CrewAiBrain"
const RNG_STREAM: StringName = &"crew_ai"
const TWEAK_PATH: String = "res://systems/ai/crew_ai/crew_ai_tweak.tres"
const WORLD_MASK: int = (1 << 0) | (1 << 1)
const HOSTILE_ROLES: Array[StringName] = [&"police", &"special", &"guard", &"cartel"]

@export var tweak: CrewAiTweak

var mode: Mode = Mode.INACTIVE
## Current enemy target (null when none is visible).
var target_enemy: NpcBase = null
## Downed crew member this AI is reviving (null when none is assigned to it).
var revive_target: CrewController = null
## Cover point currently used (null when none).
var cover_point: Node3D = null
## Last order received from a human (crew_intent.md orders).
var order: StringName = &""
var order_target_net_id: int = 0
var order_position: Vector3 = Vector3.ZERO
## Standing order: &"follow" (default) or &"hold".
var stance: StringName = &"follow"
## Current task: &"" / &"carry_bag" / &"revive" (target: task_target_net_id).
var task: StringName = &""
var task_target_net_id: int = 0
## Hold point while stance == &"hold".
var hold_point: Vector3 = Vector3.ZERO
## D-014 P4 option: ordered out of the van in stealth (detectable like a player).
var stealth_engaged: bool = false
## Slot of the human who gave the last order (the leader), -1 = nearest human.
var leader_slot: int = -1

var _crew: CrewController = null
var _rt: HeistRuntime = null
var _yaw: float = 0.0
var _pitch: float = 0.0
var _following: bool = false
var _path: PackedVector3Array = PackedVector3Array()
var _path_idx: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_left: float = 0.0
## Blocked-by-an-uncarved-body recovery (_unstick): time spent stuck, detour time left and direction.
var _stuck_s: float = 0.0
var _detour_left: float = 0.0
var _detour_dir: Vector3 = Vector3.ZERO
var _moving_s: float = 0.0
var _scan_left: float = 0.0
var _since_acquire: float = 0.0
var _shot_left: float = 0.0
var _fire_latch: bool = false
var _reload_latch: bool = false
var _aim_offset: Vector3 = Vector3.ZERO
var _aim_head: bool = false
var _interact_ticks: int = 0
var _drop_pending: bool = false
var _secure_look: Vector3 = Vector3.INF
## Orders routed by the crew tick handler, applied at the start of the next brain tick so every
## brain resolves the receiver on the same state.
var _pending: Array[Dictionary] = []
## Per human slot: the last routed order key (rising-edge, idempotent across repeated ticks).
var _order_keys: Dictionary[int, String] = {}


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
	if _rt != null:
		_rt.add_crew_tick_handler(_on_crew_tick)


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


## A human ordered this AI (crew_intent.md orders; normally routed by `_on_crew_tick`). Returns true
## when the order was accepted (and acknowledged with a voice line request).
## `position` Vector3.ZERO = "here". `issuer_slot` becomes the leader (-1 = keep the current one).
func receive_order(p_order: StringName, target_net_id: int = 0, position: Vector3 = Vector3.ZERO,
		issuer_slot: int = -1) -> bool:
	order = p_order
	order_target_net_id = target_net_id
	order_position = position
	var stealth: bool = _rt != null and not _rt.went_loud
	if not _order_allowed(p_order, stealth) or not _apply_order(p_order, target_net_id, position):
		return false
	if stealth:
		stealth_engaged = true
	if issuer_slot >= 0:
		leader_slot = issuer_slot
	var line: StringName = StringName("vo.crew.ack_%s" % p_order)
	EventBus.voice_line_requested.emit(&"crew_ai", line, {})
	Net.replicate_event(&"voice_line_requested", [&"crew_ai", line, {}])
	return true


## In stealth only the D-014 P4 option (stealth_follow_enabled) lets an order take the AI out of the
## van; hold / drop_bag never do.
func _order_allowed(p_order: StringName, stealth: bool) -> bool:
	if _crew == null or not CrewOrders.is_order(p_order):
		return false
	if stealth and not stealth_engaged:
		return tweak.stealth_follow_enabled and p_order != &"hold" and p_order != &"drop_bag"
	return true


func _apply_order(p_order: StringName, target_net_id: int, position: Vector3) -> bool:
	match p_order:
		&"follow":
			stance = &"follow"
		&"hold":
			stance = &"hold"
			hold_point = position if position != Vector3.ZERO else _crew.global_position
		&"carry_bag":
			if _crew.is_carrying_bag():
				return false
			var bag: LootBag = Ids.lookup(target_net_id) as LootBag if target_net_id != 0 else null
			if bag == null and _rt != null:
				bag = CrewOrders.nearest_free_bag(_rt, position, tweak.bag_search_radius_m)
			if bag == null or bag.secured or bag.is_carried():
				return false
			task = &"carry_bag"
			task_target_net_id = bag.net_id
			stance = &"follow"
		&"drop_bag":
			if not _crew.is_carrying_bag():
				return false
			_drop_pending = true
		&"revive":
			var t: CrewController = Ids.lookup(target_net_id) as CrewController
			if t == null or t == _crew or not needs_help(t):
				return false
			task = &"revive"
			task_target_net_id = target_net_id
	return true


## Crew tick handler (server): a human's intent carrying an order is routed to the AI CrewOrders
## resolves; only the receiver queues it. Repeated identical orders (held intents) route once.
func _on_crew_tick(crew: CrewController, intent: CrewIntent, _delta: float) -> void:
	if crew == null or crew.is_ai or intent == null or _crew == null:
		return
	if intent.order == &"":
		_order_keys.erase(crew.slot)
		return
	var key: String = "%s|%d|%s" % [intent.order, intent.order_target_net_id, intent.order_position]
	if _order_keys.get(crew.slot, "") == key:
		return
	_order_keys[crew.slot] = key
	if not is_active():
		return
	var rx: CrewController = CrewOrders.resolve_receiver(_rt, crew, intent.order, intent.order_target_net_id,
		intent.order_position, tweak)
	if rx == _crew:
		_pending.append({"order": intent.order, "target": intent.order_target_net_id,
			"position": intent.order_position, "issuer": crew.slot})


## The downed crew member this AI was ordered to revive (null when none / no longer downed).
func ordered_revive_target() -> CrewController:
	if task != &"revive":
		return null
	var t: CrewController = Ids.lookup(task_target_net_id) as CrewController
	return t if t != null and needs_help(t) else null


## L2.7/L2.8 (P3 gate): crew members the ReviveInteractable frees: DOWNED, CLOAKER_DOWNED (kicked)
## and TASED (also freed by killing the Stinger, which AI then prioritises).
static func needs_help(c: CrewController) -> bool:
	return c.crew_state == Enums.CrewState.DOWNED or c.crew_state == Enums.CrewState.CLOAKER_DOWNED \
		or c.crew_state == Enums.CrewState.TASED


## Automatic revive assignment may send this AI to `t` (hold: only within hold_revive_radius_m).
func may_auto_revive(t: CrewController) -> bool:
	if stance != &"hold":
		return true
	return _flat_dist(hold_point, t.global_position) <= tweak.hold_revive_radius_m


func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"crew_ai_brain", fp)


func _physics_step(delta: float) -> void:
	if not is_active():
		if mode != Mode.INACTIVE and _crew != null:
			_crew.stealth_hidden = false
		mode = Mode.INACTIVE
		return
	if mode == Mode.INACTIVE:
		_yaw = _crew.look_yaw
		_pitch = _crew.look_pitch
		_path = PackedVector3Array()
	while not _pending.is_empty():
		var o: Dictionary = _pending.pop_front()
		receive_order(o["order"], o["target"], o["position"], o["issuer"])
	if not _rt.went_loud:
		if not stealth_engaged:
			# D-014: wait at the van, undetectable.
			mode = Mode.STEALTH_WAIT
			_crew.stealth_hidden = true
			_crew.apply_intent(_idle_intent())
			return
		# D-014 P4 option: ordered out of the van; detectable like a player, mirrors the leader.
		_crew.stealth_hidden = false
		var leader: CrewController = _pick_leader()
		if leader != null and leader.masked and not _crew.masked:
			_crew.set_masked()
		var si: CrewIntent = _think(delta)
		si.crouch = leader != null and leader.crouched
		_crew.apply_intent(si)
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
	if task == &"revive" and ordered_revive_target() == null:
		task = &""
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
		mode = Mode.FOLLOW
		var goal: Vector3 = _bag_goal()
		if mode != Mode.FETCH_BAG and mode != Mode.SECURE_BAG:
			goal = _hold_goal() if stance == &"hold" else _follow_goal()
		elif _secure_look != Vector3.INF:
			look_point = _secure_look
		if goal != Vector3.INF:
			goal_dist = _flat_dist(_crew.global_position, goal)
			wish = _steer(goal, delta)
		_interact_ticks = 0
	if _drop_pending:
		_drop_pending = false
		if _crew.is_carrying_bag():
			i.drop_bag = true
			task = &"" if task == &"carry_bag" else task
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
## A3-05: ordered revives are assigned first; a holding AI only takes downed crew near its hold point.
func _pick_revive_target() -> CrewController:
	var downed: Array[CrewController] = []
	var free_ai: Array[CrewController] = []
	for c: CrewController in _rt.crew_members():
		if needs_help(c):
			downed.append(c)
		elif c.is_ai and c.crew_state == Enums.CrewState.NORMAL:
			var b: CrewAiBrain = CrewAiBrain.of(c)
			if b != null and b.is_active():
				free_ai.append(c)
	if downed.is_empty() or not free_ai.has(_crew):
		return null
	for c: CrewController in free_ai.duplicate():
		var ot: CrewController = CrewAiBrain.of(c).ordered_revive_target()
		if ot != null and downed.has(ot):
			if c == _crew:
				return ot
			free_ai.erase(c)
			downed.erase(ot)
	downed.sort_custom(func(a: CrewController, b: CrewController) -> bool:
		if a.is_ai != b.is_ai:
			return not a.is_ai
		return a.slot < b.slot)
	for t: CrewController in downed:
		var best: CrewController = null
		var best_d: float = INF
		for c: CrewController in free_ai:
			var d: float = c.global_position.distance_to(t.global_position)
			if d < best_d - 0.001 and CrewAiBrain.of(c).may_auto_revive(t):
				best = c
				best_d = d
		if best == null:
			continue
		if best == _crew:
			return t
		free_ai.erase(best)
	return null


## Movement goal while following (cover near the leader when enemies are visible), or INF.
## L6.1 hold position: stay at the hold point (still fights; revives nearby only).
func _hold_goal() -> Vector3:
	mode = Mode.HOLD
	cover_point = null
	_following = false
	return Vector3.INF if _flat_dist(_crew.global_position, hold_point) <= tweak.hold_arrive_m else hold_point


func _follow_goal() -> Vector3:
	var leader: CrewController = _pick_leader()
	if leader == null:
		mode = Mode.IDLE
		return Vector3.INF
	# Lead (ND): take cover whenever enemies are known near the leader, not only while one is targeted.
	cover_point = _pick_cover(leader) if target_enemy != null or _enemies_near(leader) else null
	if cover_point != null:
		mode = Mode.COVER
		_following = false
		var at_cover: bool = _flat_dist(_crew.global_position, cover_point.global_position) <= tweak.cover_arrive_m
		return Vector3.INF if at_cover else cover_point.global_position
	mode = Mode.FOLLOW
	var d: float = _flat_dist(_crew.global_position, leader.global_position)
	# PO-5.3: the leash is "close AND in sight". A bot 3 m away through a wall walks to the leader
	# (the nav path goes round), instead of counting as close and staying put.
	var seen: bool = _has_los(_crew.eye_position(), leader.eye_position())
	if not seen:
		_following = true
		return leader.global_position
	var loud: bool = _rt.went_loud
	var stop_m: float = tweak.follow_stop_loud_m if loud else tweak.follow_stop_m
	var max_m: float = tweak.follow_max_loud_m if loud else tweak.follow_max_m
	var slot_pos: Vector3 = _formation_slot(leader)
	if _following and d <= stop_m and _flat_dist(_crew.global_position, slot_pos) <= tweak.follow_slot_arrive_m:
		_following = false
	elif not _following and (d > max_m or _stacked()):
		_following = true  # too far, or standing inside another crew member (P PO-pass #3)
	if not _following:
		return Vector3.INF
	return slot_pos


## This AI's own spot near the leader: follow_min_m out on our side, fanned by its rank among the AI crew
## (follow_spread_deg apart), so bots following the same leader never share a point.
func _formation_slot(leader: CrewController) -> Vector3:
	# One shared base direction (leader -> the AI group's centroid) so every bot's slot is stable and distinct.
	var ais: Array[int] = []
	var centroid: Vector3 = Vector3.ZERO
	for c: CrewController in _rt.crew_members():
		if c.is_ai and c.crew_state == Enums.CrewState.NORMAL:
			ais.append(c.slot)
			centroid += c.global_position
	ais.sort()
	var base: Vector3 = (centroid / float(maxi(ais.size(), 1))) - leader.global_position
	base.y = 0.0
	if base.length() < 0.01:
		base = leader.global_basis.z  # behind the leader
		base.y = 0.0
	var rank: int = maxi(ais.find(_crew.slot), 0)
	var centre: float = float(ais.size() - 1) * 0.5
	var angle: float = deg_to_rad(tweak.follow_spread_deg) * (float(rank) - centre)
	var dir: Vector3 = base.normalized().rotated(Vector3.UP, angle)
	return leader.global_position + dir * tweak.follow_min_m


## True while another crew member stands within unstack_m of this AI (horizontal, same floor).
func _stacked() -> bool:
	for c: CrewController in _rt.crew_members():
		if c == _crew or c.crew_state == Enums.CrewState.CUSTODY:
			continue
		if absf(c.global_position.y - _crew.global_position.y) < 1.0 \
				and _flat_dist(c.global_position, _crew.global_position) < tweak.unstack_m:
			return true
	return false


## The human who gave the last order (when not in custody), else the nearest alive human, else slot 0.
func _pick_leader() -> CrewController:
	if leader_slot >= 0:
		var ld: CrewController = _rt.crew_controller(leader_slot) as CrewController
		if ld != null and ld != _crew and ld.crew_state != Enums.CrewState.CUSTODY:
			return ld
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


## Bags (A3-05 carry_bag): fetch the ordered bag, or carry it to a known SECURE_LOOT zone within
## secure_seek_radius_m and drop it facing the zone centre. Sets mode FETCH_BAG / SECURE_BAG when
## handling a bag (else leaves it); returns the movement goal or INF.
func _bag_goal() -> Vector3:
	_secure_look = Vector3.INF
	if _crew.is_carrying_bag():
		return _secure_goal() if stance != &"hold" else Vector3.INF
	return _fetch_goal()


func _secure_goal() -> Vector3:
	var zone: Area3D = _nearest_secure_zone()
	if zone == null:
		return Vector3.INF
	mode = Mode.SECURE_BAG
	var center: Vector3 = _zone_center(zone)
	var goal: Vector3 = _secure_point(center)
	var inside: bool = ZoneUtil.contains(zone, _crew.global_position + Vector3.UP * 0.5)
	if not inside and _flat_dist(_crew.global_position, goal) > tweak.secure_arrive_m:
		return goal
	_secure_look = Vector3(center.x, _crew.global_position.y + 0.5, center.z)
	var to: Vector3 = center - _crew.global_position
	to.y = 0.0
	var view: Vector3 = _view_dir()
	view.y = 0.0
	if to.length() < 0.3 or view.angle_to(to) <= deg_to_rad(tweak.secure_face_deg):
		_drop_pending = true
	return Vector3.INF


func _fetch_goal() -> Vector3:
	if task != &"carry_bag":
		return Vector3.INF
	var bag: LootBag = Ids.lookup(task_target_net_id) as LootBag
	if bag == null or bag.secured or bag.is_carried() or bag.is_queued_for_deletion():
		task = &""
		return Vector3.INF
	mode = Mode.FETCH_BAG
	if _flat_dist(_crew.global_position, bag.global_position) <= tweak.bag_pickup_range_m:
		var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
		if lm != null:
			lm.carry(bag, _crew)
		return Vector3.INF
	return bag.global_position


## Nearest SECURE_LOOT zone of this heist whose centre is within secure_seek_radius_m, or null.
func _nearest_secure_zone() -> Area3D:
	var best: Area3D = null
	var best_d: float = tweak.secure_seek_radius_m
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		var a: Area3D = n as Area3D
		if a == null or not a.is_inside_tree() or not _rt.is_ancestor_of(a):
			continue
		var d: float = _flat_dist(_zone_center(a), _crew.global_position)
		if d <= best_d:
			best = a
			best_d = d
	return best


static func _zone_center(zone: Area3D) -> Vector3:
	for c: Node in zone.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs != null:
			return Vector3(cs.global_position.x, zone.global_position.y, cs.global_position.z)
	return zone.global_position


## Closest navmesh point to the zone centre (the van body may sit on the centre), else the centre.
func _secure_point(center: Vector3) -> Vector3:
	var nav_map: RID = _crew.get_world_3d().navigation_map
	if nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0 \
			and not NavigationServer3D.map_get_regions(nav_map).is_empty():
		return NavigationServer3D.map_get_closest_point(nav_map, center)
	return center


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
	# PO-5.3: cover must see the leader (no cover through a wall, e.g. the alley behind the workshop).
	if not _has_los(p.global_position + Vector3(0.0, tweak.cover_eye_height_m, 0.0), leader.eye_position()):
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
		_stuck_s = 0.0
		return Vector3.ZERO
	var dir: Vector3 = next - pos
	dir.y = 0.0
	if dir.length() <= 0.05:
		_stuck_s = 0.0
		return Vector3.ZERO
	return _unstick(dir.normalized(), goal, delta)


## The navmesh is baked without some collision bodies (variant prefabs such as an escape van are not
## carved), so a path can run into a wall the bot cannot pass. A bot steering at no speed for
## stuck_time_s side-steps along the blocking surface (toward the goal's side) for stuck_detour_s, then
## re-plans from there.
func _unstick(dir: Vector3, goal: Vector3, delta: float) -> Vector3:
	if _detour_left > 0.0:
		_detour_left -= delta
		if _detour_left <= 0.0:
			_path = PackedVector3Array()
		return _detour_dir
	var hv: float = Vector2(_crew.velocity.x, _crew.velocity.z).length()
	_stuck_s = _stuck_s + delta if hv < tweak.stuck_speed else 0.0
	_moving_s = 0.0 if hv < tweak.stuck_speed else _moving_s + delta
	if _moving_s > tweak.stuck_detour_s * 2.0:
		_detour_dir = Vector3.ZERO  # moving freely again: the next block is a new obstacle
	if _stuck_s < tweak.stuck_time_s:
		return dir
	_stuck_s = 0.0
	var normal: Vector3 = -dir
	var hit: KinematicCollision3D = _crew.get_last_slide_collision()
	if hit != null and Vector2(hit.get_normal().x, hit.get_normal().z).length() > 0.1:
		normal = hit.get_normal()
	normal.y = 0.0
	var side: Vector3 = normal.normalized().cross(Vector3.UP)
	var to_goal: Vector3 = goal - _crew.global_position
	to_goal.y = 0.0
	# Toward the goal's side of the obstacle; stuck again right after a detour that way: the other way.
	side = side if side.dot(to_goal) >= 0.0 else -side
	if side.is_equal_approx(_detour_dir):
		side = -side
	_detour_dir = side
	_detour_left = tweak.stuck_detour_s
	return _detour_dir


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
	else:
		_path = offset_corners(_path, tweak.corner_margin_m)  # D-085
		if _flat_dist(_path[_path.size() - 1], goal) > 0.5:
			_path.append(goal)


## D-085: copy of `path` with each interior corner moved `margin` m (horizontally) away from the inside of
## its turn, i.e. away from the obstacle corner the navmesh path wraps around. End points stay put.
static func offset_corners(path: PackedVector3Array, margin: float) -> PackedVector3Array:
	var out: PackedVector3Array = path.duplicate()
	if margin <= 0.0 or path.size() < 3:
		return out
	for i: int in range(1, path.size() - 1):
		var a: Vector3 = path[i - 1] - path[i]
		var b: Vector3 = path[i + 1] - path[i]
		a.y = 0.0
		b.y = 0.0
		if a.length() < 0.01 or b.length() < 0.01:
			continue
		var inner: Vector3 = a.normalized() + b.normalized()
		if inner.length() < 0.01:
			continue  # straight through
		out[i] = path[i] - inner.normalized() * margin
	return out


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
	if _crew.is_casing():  # PO-11 (S1.1): an unmasked bot stays passive (no aiming at NPCs while casing)
		target_enemy = null
		_scan_left = 0.0
		return
	if target_enemy != null and (not is_instance_valid(target_enemy) or not target_enemy.is_inside_tree()
			or not _is_hostile(target_enemy)):  # D-070: an NPC taken out of the tree is no target
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
			# L4.4 / P3 gate: a Stinger tasing a crew member is shot first (killing it breaks the tase).
			var score: float = d * (tweak.tasing_stinger_score_mult if _is_tasing_crew(npc) else 1.0)
			if d > tweak.engage_range_m or score >= best_d or not _sees_any(eye, npc):
				continue
			best = npc
			best_d = score
	if best != target_enemy:
		_since_acquire = 0.0
		_roll_aim()
	target_enemy = best


static func _is_tasing_crew(npc: NpcBase) -> bool:
	var sb: StingerBrain = npc.get_node_or_null("Brain") as StingerBrain
	return sb != null and sb.tase_victim != null and is_instance_valid(sb.tase_victim)


func _is_hostile(npc: NpcBase) -> bool:
	if not npc.alive or NpcBase.BLIND_STATES.has(npc.alert_state):
		return false
	if npc.role == &"guard" or npc.role == CartelBrain.ROLE:  # QC-36: sleeping cartel posts are left alone
		return npc.alert_state == Enums.AlertState.COMBAT or npc.alert_state == Enums.AlertState.ALARMED
	return HOSTILE_ROLES.has(npc.role)


## ND attempts 9-21: a cop behind the vault bars / a counter hides its chest from one ray; like a player, the bot
## sees it when its chest, head or hips is in line of sight.
func _sees_any(eye: Vector3, npc: NpcBase) -> bool:
	var base: Vector3 = npc.global_position
	for h: float in [tweak.chest_height_m, npc.head_height, SIGHT_HIPS_M]:
		if _has_los(eye, base + Vector3(0.0, h, 0.0)):
			return true
	return false


## Any hostile NPC in combat within cover_search_radius_m + engage range of the leader (enemies are known).
func _enemies_near(leader: CrewController) -> bool:
	var r: float = tweak.cover_search_radius_m + tweak.engage_range_m * 0.5
	for role: StringName in HOSTILE_ROLES:
		for n: Variant in _rt.npcs(role):
			if not is_instance_valid(n):
				continue  # freed this frame (the runtime list is refreshed lazily)
			var npc: NpcBase = n as NpcBase
			if npc != null and _is_hostile(npc) and _flat_dist(npc.global_position, leader.global_position) <= r:
				return true
	return false


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
	# PO-5.3 (L2.5): police leave a downed crew member alone unless it shoots; a downed bot holds fire
	# so it keeps its whole bleedout for a revive.
	var hold_fire: bool = _crew.crew_state == Enums.CrewState.DOWNED and tweak.downed_hold_fire
	if w != null and not interacting and not w.reloading and not hold_fire:
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
