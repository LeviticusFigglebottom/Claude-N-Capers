## Security Officer brain (A1-05, L4.1). Owner: ENV A. Server only.
## Child `Brain` of npc_guard.tscn; listens to its NpcBase parent's observer signals and drives the
## sibling `Motor` (NpcMotor). States are NpcBase.alert_state (Enums.AlertState):
## - CALM: patrol a per-run route (S5.1, PatrolRouteGenerator) pausing per PatrolPoint, or stand at
##   the post with occasional look-arounds when there is no patrol graph.
## - CURIOUS: "?" (investigate stimulus/noise): stop and face the source for a short beat (S3.4).
## - INVESTIGATING: walk to the source and look around within investigate_budget_s, then CALM.
## - ALARMED: "!" / corpse / gunshot / alarm-reaction stimulus: stop, face, radio for
##   guard_radio_call_s, then StealthDirector.raise_alarm(&"guard_radio") (S3.2 P1, S3.3). Death,
##   domination or any non-brain state during the call cancels it.
## - COMBAT: after the alarm (S11.2): close to a standoff band on the nearest visible crew member,
##   face them and expose `wants_to_fire` / `combat_target` for the combat system (A1-08 shoots).
## - S3.2 (P2, StealthTweak.guard_cuffs_enabled): "!" on a cuffable crew member (CrewCuffs.can_cuff:
##   NORMAL, no 4 min cooldown) starts the cuff flow in ALARMED instead of the radio call: yell
##   (voice line), pause cuff_pause_s, walk over, cuff (CrewCuffs.cuff -> CrewState.CUFFED), then the
##   radio call. The target moving > cuff_move_tolerance_m from where it was spotted, or shooting,
##   makes the guard raise the alarm and open fire (COMBAT). Otherwise P1: radio straight away.
## - S3.7 misfire: dying in stealth to a non-head, non-shotgun bullet hit makes the gun go off with
##   misfire_chance (GameRng &"misfire"): NPC gunshot noise (gunshot_npc_radius_m).
## - S5.8 domination: for guard_dominate_window_s after "!" in stealth, a shout (ShoutSystem ->
##   `on_shouted`) from crew with `stealth.can_dominate_guards` makes the guard kneel and cuff himself
##   (DOMINATED, permanent, joins G.HOSTAGE, guard_dominated [R]). The PagerSystem starts his pager on
##   the DOMINATED state change (S5.2), so the pager still fires.
## Numbers: GuardTweak (guard_tweak.tres), StealthTweak (S3 timings), EnemyDef (speeds).
class_name GuardBrain
extends Node

## S3.2 cuff flow sub-phase while ALARMED.
enum CuffPhase { NONE, PAUSE, APPROACH, CUFFING }

## FrameProf keys per ticked AlertState.
const STATE_KEYS: Dictionary = {
	Enums.AlertState.CALM: &"guard_brain.calm", Enums.AlertState.CURIOUS: &"guard_brain.curious",
	Enums.AlertState.INVESTIGATING: &"guard_brain.investigating", Enums.AlertState.ALARMED: &"guard_brain.alarmed",
	Enums.AlertState.COMBAT: &"guard_brain.combat",
}
const DEFAULT_TWEAK: String = "res://systems/ai/data/guard_tweak.tres"
## Alert states this brain drives; anything else (DOMINATED, TIED, DEAD...) is owned elsewhere.
const ACTIVE_STATES: Array[int] = [
	Enums.AlertState.CALM, Enums.AlertState.CURIOUS, Enums.AlertState.INVESTIGATING,
	Enums.AlertState.ALARMED, Enums.AlertState.COMBAT,
]
const RNG_STREAM: StringName = &"patrols"
const MISFIRE_STREAM: StringName = &"misfire"

@export var tweak: GuardTweak

## Positions of the cyclic patrol visiting order (ping-pong routes include the way back). Empty
## when the guard holds a post.
var route: Array[Vector3] = []
var route_points: Array[PatrolPoint] = []
var route_loops: bool = false
## PO-10: the PatrolGraph this guard's route came from (null when it holds a post).
var patrol_graph: PatrolGraph = null
## Seconds left on the S3.3 radio call (0 when not calling).
var radio_time_left: float = 0.0
## Animation hint for the visual layer (characters.md names: idle, walk, run, radio_call, ...).
var anim_hint: StringName = &"idle"
## Position the guard is reacting to (Vector3.INF when none).
var focus_position: Vector3 = Vector3.INF
## Why the guard is ALARMED (&"crew_spotted", &"stimulus:<kind>", &"noise:<kind>").
var alarm_cause: StringName = &""
## Combat hook (A1-08): true when the guard has a visible target in range and should shoot.
var wants_to_fire: bool = false
## Combat hook (A1-08): the crew member the guard is engaging, or null.
var combat_target: Node = null
## S3.2 cuff flow phase (NONE outside it) and the crew member being arrested.
var cuff_phase: CuffPhase = CuffPhase.NONE
var cuff_target: CrewController = null
## S3.7: this guard's gun went off when he died.
var misfired: bool = false
## S5.8: seconds left in the domination window after "!" (0 = closed).
var dominate_window_left: float = 0.0
## S5.8: crew slot that dominated this guard (-1 = none).
var dominated_by_slot: int = -1

var _npc: NpcBase = null
var _motor: NpcMotor = null
var _runtime: HeistRuntime = null
var _started: bool = false
## extend_route graphs given before _start (they join the route it builds).
var _extra_graphs: Array[PatrolGraph] = []
var _route_index: int = 0
## D-152: hub-loop extra pause per patrol point (GuardTweak.hub_loops "dwell_add_s"), this difficulty.
var _dwell_add: Dictionary = {}
var _walking: bool = false
var _pause_left: float = 0.0
var _beat_left: float = 0.0
var _budget_left: float = 0.0
var _at_focus: bool = false
var _look_left: float = 0.0
var _look_side: int = 0
var _look_base: Vector3 = Vector3.FORWARD
var _post_pos: Vector3 = Vector3.ZERO
var _post_fwd: Vector3 = Vector3.FORWARD
var _retarget_left: float = 0.0
var _target_visible: bool = false
var _closing: bool = false
## Seconds in combat wanting to fire with the gunner not engaging (no shot line), _tick_combat.
var _no_shot_s: float = 0.0
var _cuff_left: float = 0.0
var _cuff_origin: Vector3 = Vector3.ZERO
## QC-57: a scripted post set by walk_to_post (kept by _start, no patrol route).
var _scripted_post: bool = false
## Seconds the current walk back to the post has taken (GuardTweak.post_walk_give_up_s).
var _post_walk_t: float = 0.0


func _ready() -> void:
	if tweak == null:
		tweak = load(DEFAULT_TWEAK) as GuardTweak
	_npc = get_parent() as NpcBase
	_motor = _npc.get_node_or_null("Motor") as NpcMotor if _npc != null else null
	if _npc == null or _motor == null:
		Log.error(&"ai", "GuardBrain needs an NpcBase parent with a Motor (NpcMotor) child")
		return
	_npc.crew_spotted.connect(_on_crew_spotted)
	_npc.stimulus_spotted.connect(_on_stimulus_spotted)
	_npc.noise_heard.connect(_on_noise_heard)
	_npc.alert_state_changed.connect(_on_alert_state_changed)
	_npc.died.connect(_on_died)
	EventBus.alarm_raised.connect(_on_alarm_raised)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	# Deferred: HeistRuntime.spawn_npc sets the transform after add_child, and all guards spawned
	# in one frame build their routes in spawn order (determinism per guard order).
	_start.call_deferred()


func _exit_tree() -> void:
	if EventBus.alarm_raised.is_connected(_on_alarm_raised):
		EventBus.alarm_raised.disconnect(_on_alarm_raised)
	if EventBus.weapon_fired.is_connected(_on_weapon_fired):
		EventBus.weapon_fired.disconnect(_on_weapon_fired)


## Current state as a lowercase name (&"calm", &"curious", &"investigating", &"alarmed", &"combat", ...).
func state_name() -> StringName:
	if _npc == null:
		return &""
	return StringName(String(Enums.AlertState.keys()[_npc.alert_state]).to_lower())


## Detection "?" hook (StealthDirector may call this when a meter crosses the suspicious mark).
func notice_suspicious(position: Vector3) -> void:
	_begin_curious(position)


## RT `marshal_early` (doc Rare events: "walks two checks instead of one"): `graph`'s points (in their authored order)
## join the end of the route, so the loop walks the first check, then this one. A guard holding a post starts patrolling
## it. Server.
func extend_route(graph: PatrolGraph) -> void:
	if graph == null:
		return
	if not _started:
		_extra_graphs.append(graph)  # joins once _start builds the route
		return
	_append_graph(graph)


func _append_graph(graph: PatrolGraph) -> void:
	var pts: Array[PatrolPoint] = graph.points()
	if pts.is_empty():
		return
	route_loops = true
	if patrol_graph == null:
		patrol_graph = graph
	for p: PatrolPoint in pts:
		route_points.append(p)
		route.append(p.global_position)


## QC-57 (GN Vaultline couriers): a scripted walk. The guard drops his patrol route, walks to `pos` at patrol speed and
## holds it as his post (CALM; after a "?" or an investigation he walks back to it). `forward` (flat) is the facing
## there; zero keeps the walking direction. Server.
func walk_to_post(pos: Vector3, forward: Vector3 = Vector3.ZERO) -> void:
	if _npc == null:
		return
	_scripted_post = true
	route.clear()
	route_points.clear()
	patrol_graph = null
	_pause_left = 0.0
	_post_pos = pos
	var fwd: Vector3 = _flat(forward)
	if fwd.length() < 0.01:
		fwd = _flat(pos - _npc.global_position)
	if fwd.length() > 0.01:
		_post_fwd = fwd.normalized()
	if _npc.alert_state == Enums.AlertState.CALM and _motor != null:
		_walking = false  # _tick_post re-issues the walk to the new post on the next tick


## QC-57: the guard stands at his post (flat distance within `tolerance_m`, same floor).
func at_post(tolerance_m: float = 1.0) -> bool:
	if _npc == null:
		return false
	return _flat(_npc.global_position - _post_pos).length() <= tolerance_m and absf(_npc.global_position.y - _post_pos.y) <= 1.5


## QC-57 / B3: the guard found something wrong at `pos` (a Vaultline courier at an empty canvas slot): the S3.3 alarm
## (stop, face it, radio call, then StealthDirector.raise_alarm). Killing or dominating him during the call stops it.
func report_alarm(pos: Vector3, cause: StringName) -> void:
	if _is_active():
		_react(&"alarm", pos, cause)


## S3.1: a panicked civilian reached this guard and reported the crew: alarm + radio call.
func alert_from_civilian(civ: Node3D) -> void:
	if _is_active():
		_react(&"alarm", civ.global_position if civ != null else _npc.global_position, &"civilian_report")


func _start() -> void:
	if _npc == null or not is_inside_tree() or not Net.is_authority():
		return
	_runtime = HeistRuntime.of(_npc)
	if not _scripted_post:
		_post_pos = _npc.global_position
		_post_fwd = _npc.look_forward()
		_build_route()
		for g: PatrolGraph in _extra_graphs:
			_append_graph(g)
		_stagger_patrol_start()
	_look_left = _roll(tweak.post_look_interval_s)
	_started = true
	if _runtime != null and _runtime.went_loud and _is_active():
		_enter_combat()


func _build_route() -> void:
	if bool(_npc.spawn_info.get("no_patrol", false)):
		return  # A2-02 S8.2: the camera operator holds his station (post), never patrols.
	var graph: PatrolGraph = _npc.spawn_info.get("patrol_graph") as PatrolGraph
	if graph == null and StringName(_npc.spawn_info.get("idle_activity", &"")) != &"":
		return  # D r16 (AH door bouncer): a post activity and no named graph = he holds the post, no nearest-graph patrol
	if graph == null and _runtime != null:
		var graphs: Array[Node] = []
		for g: Node in get_tree().get_nodes_in_group(G.PATROL_GRAPH):
			if _runtime.is_ancestor_of(g):
				graphs.append(g)
		graph = PatrolRouteGenerator.nearest_graph(graphs, _post_pos, tweak.route_tag, tweak.nearest_graph_max_m)
	if graph == null:
		return
	if _build_hub_route(graph):
		return
	var tag: StringName = tweak.route_tag
	# P OF-A6 ghost run: a spawn that names its graph patrols it even when its points carry only a local tag (OF Lane:
	# `guard_dock`, no `guard`), instead of silently holding the post.
	if _npc.spawn_info.get("patrol_graph") == graph and PatrolRouteGenerator.tagged_points(graph, tag).is_empty():
		tag = &""
	var res: Dictionary = PatrolRouteGenerator.build(graph, _post_pos, GameRng.stream(RNG_STREAM),
		tweak.route_min_points, tweak.route_max_points, tag, tweak.route_attempts)
	var pts: Array[PatrolPoint] = res["points"]
	if pts.size() < 2:
		if pts.size() == 1:  # A single reachable point: treat it as the post.
			_post_pos = pts[0].global_position
			if pts[0].face_marker_forward:
				_post_fwd = _flat(-pts[0].global_basis.z)
		return
	route_loops = bool(res["loop"])
	patrol_graph = graph
	route_points = PatrolRouteGenerator.visit_order(pts, route_loops)
	for p: PatrolPoint in route_points:
		route.append(p.global_position)


## OF-A6 hub loops (GuardTweak.hub_loops by spawn tag): the doc's fixed (a)/(b)/(c) loops from a hub, in an order the
## patrol stream shuffles once. False (the S5.1 random walk instead) when the spawn has no hub-loop tag or the named
## points are missing from `graph`.
func _build_hub_route(graph: PatrolGraph) -> bool:
	var cfg: Dictionary = {}
	for t: Variant in _npc.spawn_info.get("tags", []):
		if tweak.hub_loops.has(StringName(t)):
			cfg = tweak.hub_loops[StringName(t)]
			break
	if cfg.is_empty():
		return false
	var by_name: Dictionary = {}
	for p: PatrolPoint in graph.points():
		by_name[StringName(p.name)] = p
	var hub: PatrolPoint = by_name.get(StringName(cfg.get("hub", &"")))
	if hub == null:
		hub = PatrolRouteGenerator.nearest_point(PatrolRouteGenerator.tagged_points(graph, &""), _post_pos)
	var loops: Array = []
	for names: Variant in cfg.get("loops", []):
		var stops: Array = []
		for n: Variant in names:
			if not by_name.has(StringName(n)):
				Log.warn(&"ai", "%s hub loops: no point %s in %s; random walk instead" % [_npc.name, n, graph.name])
				return false
			stops.append(by_name[StringName(n)])
		loops.append(stops)
	var order: Array[PatrolPoint] = PatrolRouteGenerator.hub_route(graph, hub, loops, GameRng.stream(RNG_STREAM))
	if order.size() < 2:
		return false
	var max_d: int = int(cfg.get("dwell_add_max_difficulty", Enums.Difficulty.size()))
	if _runtime == null or _runtime.difficulty <= max_d:
		var add: Dictionary = cfg.get("dwell_add_s", {})
		for n: Variant in add:
			if by_name.has(StringName(n)):
				_dwell_add[by_name[StringName(n)]] = float(add[n])
	route_loops = true
	patrol_graph = graph
	route_points = order
	for p: PatrolPoint in route_points:
		route.append(p.global_position)
	return true

## PO-10: the k-th guard of this heist to start patrolling `patrol_graph` waits k x patrol_stagger_s (+ jitter)
## before its first leg, so guards sharing a route are not in lockstep.
func _stagger_patrol_start() -> void:
	if route.is_empty() or patrol_graph == null or _runtime == null:
		return
	var k: int = 0
	for n: Node in _runtime.npcs(&"guard"):
		var b: GuardBrain = n.get_node_or_null(^"Brain") as GuardBrain
		if b != null and b != self and b._started and b.patrol_graph == patrol_graph:
			k += 1
	if k > 0:
		_pause_left = float(k) * tweak.patrol_stagger_s \
			+ GameRng.stream(&"patrol_stagger").randf_range(0.0, maxf(tweak.patrol_stagger_jitter_s, 0.0))


func _physics_process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_physics_step(delta)
	FrameProf.end(&"guard_brain", fp)


func _physics_step(delta: float) -> void:
	if not _started or _npc == null or not _npc.alive or not Net.is_authority():
		return
	dominate_window_left = maxf(dominate_window_left - delta, 0.0)  # S5.8
	if _npc.is_stunned():  # A2-03 (S8.6): ECM feedback stun pauses everything (radio call too)
		wants_to_fire = false
		return
	var fp: int = FrameProf.begin()
	var st: int = _npc.alert_state
	match st:
		Enums.AlertState.CALM:
			if route.is_empty():
				_tick_post(delta)
			else:
				_tick_patrol(delta)
		Enums.AlertState.CURIOUS:
			_beat_left -= delta
			if _beat_left <= 0.0:
				_begin_investigating()
		Enums.AlertState.INVESTIGATING:
			_tick_investigating(delta)
		Enums.AlertState.ALARMED:
			_tick_alarmed(delta)
		Enums.AlertState.COMBAT:
			_tick_combat(delta)
	FrameProf.end(STATE_KEYS.get(st, &"guard_brain.other"), fp)  # LEAD (OF loud hitches): per alert state


# --- CALM -------------------------------------------------------------------------------

func _tick_patrol(delta: float) -> void:
	if _walking:
		if _motor.arrived:
			_walking = false
			_reach_point()
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left > 0.0:
			return
	_motor.go_to(route[_route_index], _walk_speed())
	_walking = true
	anim_hint = &"walk"


func _reach_point() -> void:
	var pp: PatrolPoint = route_points[_route_index]
	_route_index = (_route_index + 1) % route.size()
	anim_hint = &"idle"
	var extra: float = float(_dwell_add.get(pp, 0.0)) if pp != null else 0.0
	if pp == null or not is_instance_valid(pp) or (pp.pause_range.y <= 0.0 and extra <= 0.0):
		return
	_pause_left = (_roll(pp.pause_range) if pp.pause_range.y > 0.0 else 0.0) + extra
	anim_hint = CivilianBrain.seated_or_standing(_npc, pp.pause_anim)  # X-5 / PO6-06: no sitting on thin air
	if pp.face_marker_forward:
		_motor.face(-pp.global_basis.z)


func _tick_post(delta: float) -> void:
	if _walking:
		_post_walk_t += delta
		if _motor.arrived or (_post_walk_t >= tweak.post_walk_give_up_s and not _scripted_post):
			if not _motor.arrived:  # unreachable exact point: this spot is the post now (no walking on the spot)
				_motor.stop()
				_post_pos = _npc.global_position
			_walking = false
			_motor.face(_post_fwd)
			anim_hint = &"idle"
		return
	if _flat(_npc.global_position - _post_pos).length() > tweak.post_return_m:
		_motor.go_to(_post_pos, _walk_speed())
		_walking = true
		_post_walk_t = 0.0
		anim_hint = &"walk"
		return
	_look_left -= delta
	if _look_left > 0.0:
		return
	if _look_side == 0:
		_look_side = 1 if GameRng.stream(RNG_STREAM).randf() < 0.5 else -1
		_motor.face(_post_fwd.rotated(Vector3.UP, deg_to_rad(tweak.look_around_angle_deg * _look_side)))
		_look_left = tweak.look_hold_s
		anim_hint = &"investigate_look"
	else:
		_look_side = 0
		_motor.face(_post_fwd)
		_look_left = _roll(tweak.post_look_interval_s)
		anim_hint = &"idle"


func _resume_calm() -> void:
	focus_position = Vector3.INF
	_walking = false
	_pause_left = 0.0
	_look_side = 0
	_look_left = _roll(tweak.post_look_interval_s)
	anim_hint = &"idle"
	if not route.is_empty():
		var best: float = INF
		for i: int in range(route.size()):
			var d: float = _npc.global_position.distance_squared_to(route[i])
			if d < best:
				best = d
				_route_index = i
	_motor.stop()
	_npc.set_alert_state(Enums.AlertState.CALM)


# --- CURIOUS / INVESTIGATING (S3.4) -------------------------------------------------------------

func _begin_curious(pos: Vector3) -> void:
	if not _started or not _is_active():
		return
	var s: int = _npc.alert_state
	if s == Enums.AlertState.ALARMED or s == Enums.AlertState.COMBAT:
		return
	focus_position = pos
	if s == Enums.AlertState.INVESTIGATING:  # Something new: re-target, fresh budget.
		_budget_left = Tweak.stealth().investigate_budget_s
		_at_focus = false
		_motor.go_to(pos, _investigate_speed())
		anim_hint = &"walk"
		return
	_walking = false
	_motor.stop()
	_motor.face_point(pos)
	_beat_left = tweak.curious_beat_s
	anim_hint = &"idle_alert"
	_npc.set_alert_state(Enums.AlertState.CURIOUS)


func _begin_investigating() -> void:
	_budget_left = Tweak.stealth().investigate_budget_s
	_at_focus = false
	_motor.go_to(focus_position, _investigate_speed())
	anim_hint = &"walk"
	_npc.set_alert_state(Enums.AlertState.INVESTIGATING)


func _tick_investigating(delta: float) -> void:
	_budget_left -= delta
	if _budget_left <= 0.0:
		_resume_calm()  # Nothing confirmed within the budget.
		return
	if not _at_focus:
		if _motor.arrived or (_motor.target_on_level() and _motor.distance_to_target() <= tweak.investigate_arrive_m):
			_motor.stop()
			_at_focus = true
			var to_focus: Vector3 = _flat(focus_position - _npc.global_position)
			_look_base = to_focus.normalized() if to_focus.length() > 0.1 else _npc.look_forward()
			_look_side = 1
			_look_left = 0.0
			anim_hint = &"investigate_look"
		return
	_look_left -= delta
	if _look_left <= 0.0:
		_look_side = -_look_side
		_motor.face(_look_base.rotated(Vector3.UP, deg_to_rad(tweak.look_around_angle_deg * _look_side)))
		_look_left = tweak.look_hold_s


# --- ALARMED (S3.2 P1, S3.3) ----------------------------------------------------------------

func _begin_alarm(pos: Vector3, cause: StringName) -> void:
	if not _started or not _is_active():
		return
	if cuff_phase != CuffPhase.NONE:
		_cuff_to_radio()  # S3.2: something alarming (gunshot, corpse...) mid-arrest: radio it in
		return
	var s: int = _npc.alert_state
	if s == Enums.AlertState.ALARMED or s == Enums.AlertState.COMBAT:
		return
	if not _stealth_active():
		_enter_combat()
		return
	focus_position = pos
	alarm_cause = cause
	_walking = false
	_motor.stop()
	_motor.face_point(pos)
	radio_time_left = Tweak.stealth().guard_radio_call_s
	anim_hint = &"radio_call"
	_npc.set_alert_state(Enums.AlertState.ALARMED)


func _tick_alarmed(delta: float) -> void:
	if cuff_phase != CuffPhase.NONE:
		_tick_cuff(delta)
		return
	if focus_position != Vector3.INF:
		_motor.face_point(focus_position)
	radio_time_left -= delta
	if radio_time_left > 0.0:
		return
	radio_time_left = 0.0
	var st: StealthDirector = _stealth()
	if st != null:
		st.raise_alarm(&"guard_radio", _npc.net_id)  # -> EventBus.alarm_raised -> COMBAT
	if _npc.alive and _npc.alert_state == Enums.AlertState.ALARMED:
		_enter_combat()


# --- Cuffs (S3.2 P2) ----------------------------------------------------------------------------

func _cuffs_apply(crew: Node) -> bool:
	var c: CrewController = crew as CrewController
	return Tweak.stealth().guard_cuffs_enabled and c != null and _started and _is_active() \
		and _stealth_active() and CrewCuffs.can_cuff(c)


func _begin_cuff(crew: CrewController) -> void:
	var s: int = _npc.alert_state
	if s == Enums.AlertState.ALARMED or s == Enums.AlertState.COMBAT:
		return
	cuff_target = crew
	cuff_phase = CuffPhase.PAUSE
	_cuff_origin = crew.global_position
	_cuff_left = Tweak.stealth().cuff_pause_s
	focus_position = crew.global_position
	alarm_cause = &"crew_spotted"
	radio_time_left = 0.0
	_walking = false
	_motor.stop()
	_motor.face_point(crew.global_position)
	anim_hint = &"aim_pistol"
	_npc.set_alert_state(Enums.AlertState.ALARMED)
	_yell(crew)


func _yell(crew: CrewController) -> void:
	var def: EnemyDef = _npc.enemy_def
	var speaker: StringName = def.voice if def != null and def.voice != &"" else &"guard"
	var line: StringName = Tweak.stealth().cuff_yell_line
	var ctx: Dictionary = {"npc_net_id": _npc.net_id, "crew_slot": crew.slot, "position": _npc.global_position}
	EventBus.voice_line_requested.emit(speaker, line, ctx)
	Net.replicate_event(&"voice_line_requested", [speaker, line, ctx])


func _tick_cuff(delta: float) -> void:
	var t: CrewController = cuff_target
	if t == null or not is_instance_valid(t) or t.crew_state != Enums.CrewState.NORMAL:
		_cuff_to_radio()  # cuffed by another guard, downed...: the alarm still follows
		return
	var tw: StealthTweak = Tweak.stealth()
	if _flat(t.global_position - _cuff_origin).length() > tw.cuff_move_tolerance_m:
		_cuff_violation()
		return
	focus_position = t.global_position
	_cuff_left -= delta
	match cuff_phase:
		CuffPhase.PAUSE:
			_motor.face_point(t.global_position)
			if _cuff_left <= 0.0:
				cuff_phase = CuffPhase.APPROACH
				_cuff_left = tw.cuff_approach_timeout_s
				_motor.go_to(t.global_position, _walk_speed())
				anim_hint = &"walk"
		CuffPhase.APPROACH:
			if _flat(t.global_position - _npc.global_position).length() <= tw.cuff_reach_m:
				_motor.stop()
				_motor.face_point(t.global_position)
				cuff_phase = CuffPhase.CUFFING
				_cuff_left = tw.cuff_action_s
				anim_hint = &"cuff"
			elif _cuff_left <= 0.0 or _motor.blocked_door != null:
				_cuff_to_radio()  # cannot reach them
			elif _motor.arrived or _motor.target.distance_to(t.global_position) > 0.5:
				_motor.go_to(t.global_position, _walk_speed())
		CuffPhase.CUFFING:
			_motor.face_point(t.global_position)
			if _cuff_left <= 0.0:
				var cuffs: CrewCuffs = CrewCuffs.of(t, true)
				if cuffs != null:
					cuffs.cuff(_npc.net_id)
				_cuff_to_radio()  # cuffed: "the alarm follows soon" (S3.2)


## Leave the cuff flow for the S3.3 radio call (killing the guard during it still cancels it).
func _cuff_to_radio() -> void:
	_clear_cuff()
	_motor.stop()
	radio_time_left = Tweak.stealth().guard_radio_call_s
	anim_hint = &"radio_call"


## S3.2: the target moved away or shot: alarm and open fire.
func _cuff_violation() -> void:
	_clear_cuff()
	var st: StealthDirector = _stealth()
	if st != null:
		st.raise_alarm(&"guard_radio", _npc.net_id)
	_enter_combat()


func _clear_cuff() -> void:
	cuff_phase = CuffPhase.NONE
	cuff_target = null
	_cuff_left = 0.0


func _on_weapon_fired(shooter_net_id: int, _weapon_id: StringName, _suppressed: bool, _position: Vector3) -> void:
	if cuff_phase == CuffPhase.NONE or cuff_target == null or not is_instance_valid(cuff_target):
		return
	if shooter_net_id == cuff_target.net_id and Net.is_authority() and _is_active():
		_cuff_violation()


# --- Domination (S5.8) --------------------------------------------------------------------------

## S5.8: a shout from `crew` would dominate this guard now.
func can_be_dominated_by(crew: Node) -> bool:
	var c: CrewController = crew as CrewController
	return c != null and _started and _is_active() and dominate_window_left > 0.0 and _stealth_active() \
		and Modifiers.flag(c.slot, &"stealth.can_dominate_guards")


## ShoutSystem hook (S5.8). Returns true when the guard was dominated.
func on_shouted(crew: Node) -> bool:
	if not Net.is_authority() or not can_be_dominated_by(crew):
		return false
	dominate((crew as CrewController).slot)
	return true


## Server: kneel and cuff himself for crew `slot` (S5.8). Permanent; the pager follows (S5.2).
func dominate(slot: int) -> void:
	if not _is_active():
		return
	dominate_window_left = 0.0
	dominated_by_slot = slot
	_npc.set_alert_state(Enums.AlertState.DOMINATED)  # cancels the radio call / cuff flow
	anim_hint = &"kneel_cuffed"
	_npc.add_to_group(G.HOSTAGE)
	var targets: CivilianTargets = CivilianTargets.ensure(_runtime if _runtime != null else HeistRuntime.of(_npc))
	if targets != null:
		targets.recount_hostages()
	EventBus.guard_dominated.emit(_npc.net_id, slot)
	Net.replicate_event(&"guard_dominated", [_npc.net_id, slot])
	Log.info(&"ai", "guard %d dominated by slot %d" % [_npc.net_id, slot])


# --- Misfire (S3.7) -----------------------------------------------------------------------------

func _maybe_misfire(info: Dictionary) -> void:
	var rt: HeistRuntime = _runtime if _runtime != null else HeistRuntime.of(_npc)
	if not Net.is_authority() or rt == null or rt.stealth == null or not rt.stealth.is_stealth():
		return
	if not info.has("type") or int(info["type"]) != Enums.DamageType.BULLET:  # scripted die(): no hit
		return
	if int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD:
		return
	var wid: StringName = StringName(info.get("weapon_id", &""))
	var wdef: WeaponDef = ContentDB.weapon(wid) if wid != &"" else null
	if wdef != null and wdef.weapon_class == Enums.WeaponClass.SHOTGUN:
		return
	var tw: StealthTweak = Tweak.stealth()
	if GameRng.stream(MISFIRE_STREAM).randf() >= tw.misfire_chance:
		return
	misfired = true
	var pos: Vector3 = _npc.global_position + Vector3(0.0, 1.0, 0.0)
	var weapon: StringName = _npc.enemy_def.weapon if _npc.enemy_def != null else &""
	EventBus.weapon_fired.emit(_npc.net_id, weapon, false, pos)
	# PO-8: the stray round goes wide ahead of the guard (shot_fx here + relayed).
	ShotFx.npc_shot(_npc, pos, pos + _npc.look_forward() * 8.0 + Vector3.DOWN * 1.0, false)
	rt.make_noise(pos, tw.gunshot_npc_radius_m, &"gunshot", _npc.net_id)


# --- COMBAT stub (S11.2) ------------------------------------------------------------------

func _enter_combat() -> void:
	if not _is_active() or _npc.alert_state == Enums.AlertState.COMBAT:
		return
	radio_time_left = 0.0
	_clear_cuff()
	_walking = false
	_closing = false
	_retarget_left = 0.0
	anim_hint = &"idle_alert"
	var fp: int = FrameProf.begin()  # LEAD (OF loud hitches): the alarm's guard_brain frame (148-322 ms over 9 guards)
	_npc.set_alert_state(Enums.AlertState.COMBAT)
	FrameProf.end(&"guard_brain.enter_combat", fp)


func _tick_combat(delta: float) -> void:
	_retarget_left -= delta
	if _retarget_left <= 0.0 or combat_target == null or not is_instance_valid(combat_target):
		_retarget_left = tweak.combat_retarget_s
		var fp: int = FrameProf.begin()
		_pick_target()
		FrameProf.end(&"guard_brain.pick_target", fp)
	var target: Node3D = combat_target as Node3D
	if target == null:
		_motor.stop()
		wants_to_fire = false
		anim_hint = &"idle_alert"
		return
	var tpos: Vector3 = target.global_position
	var d: float = _flat(tpos - _npc.global_position).length()
	# D's GH Tense coverage: a guard who sees the crew through a pane bullets cannot pass (a glazed door leaf; D-142 vision)
	# held the standoff aiming for minutes. Like a PD2 guard he moves for a shot: no shot line for
	# combat_no_shot_close_s -> close in until the gunner engages.
	var gun: NpcGunner = _npc.get_node_or_null(^"Gunner") as NpcGunner
	var shot_line: bool = gun == null or gun.engaging or not wants_to_fire
	_no_shot_s = 0.0 if shot_line else _no_shot_s + delta
	if not _target_visible or d > tweak.combat_standoff_max_m or _no_shot_s >= tweak.combat_no_shot_close_s:
		_closing = true
	elif d <= tweak.combat_standoff_pref_m:
		_closing = false
	if _closing:
		if _motor.target == Vector3.INF or _motor.target.distance_to(tpos) > 0.5:
			_motor.go_to(tpos, _run_speed())
		anim_hint = &"run"
	elif d < tweak.combat_standoff_min_m:
		var away: Vector3 = _flat(_npc.global_position - tpos).normalized()
		_motor.go_to(_npc.global_position + away * (tweak.combat_standoff_pref_m - d), _run_speed())
		anim_hint = &"walk_back"
	else:
		_motor.stop()
		_motor.face_point(tpos)
		anim_hint = &"aim_pistol"
	# A1-08 HOOK: the combat system reads `wants_to_fire` + `combat_target` (and EnemyDef.weapon /
	# damage[difficulty]) to aim and shoot. This brain deals no damage itself.
	wants_to_fire = _target_visible and d <= tweak.combat_fire_range_m


func _pick_target() -> void:
	combat_target = null
	_target_visible = false
	if _runtime == null:
		return
	var best_vis: float = INF
	var best_any: float = INF
	var any: CrewController = null
	for c: CrewController in _runtime.crew_members():
		if c.crew_state == Enums.CrewState.CUSTODY or c.crew_state == Enums.CrewState.CUFFED:
			continue
		var d: float = c.global_position.distance_squared_to(_npc.global_position)
		d /= PerkHooks.aggro_weight(c, _npc)  # perk hook (QB-62: perk target-selection weight)
		if d < best_any:
			best_any = d
			any = c
		if d < best_vis and _can_see(c):
			best_vis = d
			combat_target = c
	if combat_target != null:
		_target_visible = true
	else:
		combat_target = any  # Last known position: close in until visible.


func _can_see(c: CrewController) -> bool:
	var st: StealthDirector = _stealth()
	if st == null:
		return true
	var exclude: Array[RID] = [_npc.get_rid(), c.get_rid()]
	return st.has_los(_npc.eye_position(), c.eye_position(), exclude)


# --- Signals --------------------------------------------------------------------------------

func _on_crew_spotted(crew: Node) -> void:
	if _started and _is_active() and _stealth_active() and dominate_window_left <= 0.0 \
			and _npc.alert_state != Enums.AlertState.ALARMED and _npc.alert_state != Enums.AlertState.COMBAT:
		dominate_window_left = Tweak.stealth().guard_dominate_window_s  # S5.8: window opens on "!"
	if _cuffs_apply(crew):
		_begin_cuff(crew as CrewController)  # S3.2 P2
		return
	var n3: Node3D = crew as Node3D
	_begin_alarm(n3.global_position if n3 != null else _npc.global_position, &"crew_spotted")


func _on_stimulus_spotted(_stimulus_id: int, kind: StringName, position: Vector3) -> void:
	var preset: Dictionary = Tweak.stealth().stimuli.get(kind, {})
	_react(StringName(preset.get("guard", &"ignore")), position, StringName("stimulus:%s" % kind))


func _on_noise_heard(position: Vector3, kind: StringName, _source_net_id: int) -> void:
	var preset: Dictionary = Tweak.stealth().noise_reactions.get(kind, {})
	_react(StringName(preset.get("guard", &"ignore")), position, StringName("noise:%s" % kind))


func _react(reaction: StringName, position: Vector3, cause: StringName) -> void:
	match reaction:
		&"alarm":
			_begin_alarm(position, cause)
		&"investigate":
			_begin_curious(position)


func _on_alarm_raised(_reason: StringName, _source_net_id: int) -> void:
	if not _started or _npc == null or not _npc.alive or not Net.is_authority():
		return
	if _runtime != null and not _runtime.is_ancestor_of(_npc):
		return
	_enter_combat()


func _on_alert_state_changed(_old_state: int, new_state: int) -> void:
	if ACTIVE_STATES.has(new_state):
		return
	# Dominated, tied, dead...: the radio call (S3.3) and any combat intent are cancelled.
	radio_time_left = 0.0
	_clear_cuff()
	wants_to_fire = false
	combat_target = null
	_walking = false
	if _motor != null:
		_motor.stop()
		_motor.face(Vector3.ZERO)


func _on_died(info: Dictionary, _killer_net_id: int) -> void:
	radio_time_left = 0.0
	dominate_window_left = 0.0
	_clear_cuff()
	_maybe_misfire(info)
	wants_to_fire = false
	combat_target = null
	anim_hint = &""
	set_physics_process(false)
	if _npc.is_in_group(G.HOSTAGE):  # S5.8: a dominated guard killed stops counting as a hostage
		_npc.remove_from_group(G.HOSTAGE)
		var targets: CivilianTargets = CivilianTargets.ensure(_runtime if _runtime != null else HeistRuntime.of(_npc))
		if targets != null:
			targets.recount_hostages()


# --- Helpers ----------------------------------------------------------------------------------

func _is_active() -> bool:
	return _npc != null and _npc.alive and ACTIVE_STATES.has(_npc.alert_state)


func _stealth() -> StealthDirector:
	if _runtime != null and _runtime.stealth != null:
		return _runtime.stealth
	return HeistRuntime.get_service(G.SVC_STEALTH) as StealthDirector


func _stealth_active() -> bool:
	var st: StealthDirector = _stealth()
	if st != null:
		return st.is_stealth()
	return _runtime == null or not _runtime.went_loud


func _walk_speed() -> float:
	var def: EnemyDef = _npc.enemy_def
	return float(def.params.get("patrol_speed", tweak.fallback_walk_speed)) if def != null else tweak.fallback_walk_speed


func _investigate_speed() -> float:
	var def: EnemyDef = _npc.enemy_def
	return float(def.params.get("investigate_speed", _walk_speed())) if def != null else _walk_speed()


func _run_speed() -> float:
	return _npc.enemy_def.move_speed if _npc.enemy_def != null else tweak.fallback_run_speed


func _roll(range_s: Vector2) -> float:
	return GameRng.stream(RNG_STREAM).randf_range(minf(range_s.x, range_s.y), maxf(range_s.x, range_s.y))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
