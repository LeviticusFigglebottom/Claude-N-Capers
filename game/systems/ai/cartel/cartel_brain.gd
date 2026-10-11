## Cartel gunman brain (QC-36, L4.10 "gangsters: no pagers, can't be dominated", D-064). Owner: ENV A.
## Server only. Child `Brain` of npc_cartel.tscn (siblings Motor = NpcMotor, Gunner = NpcGunner).
## Role &"cartel": spawned on GUARD SpawnPoints tagged `cartel` (HeistRuntime) with enemy.cartel_gunman;
## not a police unit (AssaultDirector.alive_units), but alive gunmen take from the police budget
## (AssaultDirector.police_budget, shared enemy_cap). Hostile to the crew only.
## - CALM: patrols its PatrolGraph (PatrolRouteGenerator, like guards) or holds its post.
## - wakes (-> COMBAT, woken_by) on a noise of CartelTweak.wake_noise_kinds that reaches it, a sighting
##   (crew in sight_range_m / sight_fov_deg with LOS for sight_time_s), damage, or a crew shout; a waking
##   gunman wakes every sleeping gunman within alert_share_radius_m.
## - COMBAT: holds its post: claims a COVER TacticalPoint within cover_search_m of the post with LOS to the
##   target (else stands at the post), never leaves post_leash_m; shoots the nearest visible crew member.
## - no pager, no cuffing, never dominated (on_shouted wakes it and fails), never surrenders.
## Numbers: CartelTweak (cartel_tweak.tres).
class_name CartelBrain
extends Node

const ROLE: StringName = &"cartel"
const SPAWN_TAG: StringName = &"cartel"
const ENEMY_DEF: String = "res://systems/ai/data/enemies/cartel_gunman.tres"
const DEFAULT_TWEAK: String = "res://systems/ai/cartel/cartel_tweak.tres"
const RNG_STREAM: StringName = &"cartel_ai"

@export var tweak: CartelTweak

## NpcGunner hooks.
var wants_to_fire: bool = false
var combat_target: Node = null
var anim_hint: StringName = &"idle"
var cover_point: TacticalPoint = null
## Why this gunman woke (&"sight", &"damage", &"shout", &"gunshot"...), &"" while asleep.
var woken_by: StringName = &""
var route: PackedVector3Array = PackedVector3Array()

var _npc: NpcBase = null
var _motor: NpcMotor = null
var _runtime: HeistRuntime = null
var _started: bool = false
var _post_pos: Vector3 = Vector3.ZERO
var _route_index: int = 0
var _walking: bool = false
var _pause_left: float = 0.0
var _sight: Dictionary[int, float] = {}
var _retarget_left: float = 0.0
var _target_visible: bool = false


func _ready() -> void:
	_npc = get_parent() as NpcBase
	_motor = get_node_or_null("../Motor") as NpcMotor
	if tweak == null:
		tweak = load(DEFAULT_TWEAK) as CartelTweak
	_start.call_deferred()


func _start() -> void:
	if _npc == null or not is_inside_tree():
		return
	_runtime = HeistRuntime.of(self)
	_post_pos = _npc.global_position
	_build_route()
	if _runtime != null:
		_runtime.noise_made.connect(_on_noise)
	EventBus.damage_applied.connect(_on_damage)
	_started = true


func _exit_tree() -> void:
	_release_cover()
	if _runtime != null and is_instance_valid(_runtime) and _runtime.noise_made.is_connected(_on_noise):
		_runtime.noise_made.disconnect(_on_noise)
	if EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.disconnect(_on_damage)


## Server: wake up (COMBAT) and wake the sleeping gunmen around (alert_share_radius_m).
func wake(reason: StringName) -> void:
	if _npc == null or not _npc.alive or _npc.alert_state == Enums.AlertState.COMBAT or not Net.is_authority():
		return
	woken_by = reason
	_npc.set_alert_state(Enums.AlertState.COMBAT)
	_motor.stop()
	_walking = false
	if _runtime == null:
		return
	for n: Node in _runtime.npcs(ROLE):
		var other: NpcBase = n as NpcBase
		if other == null or other == _npc or other.global_position.distance_to(_npc.global_position) > tweak.alert_share_radius_m:
			continue
		var b: CartelBrain = other.get_node_or_null("Brain") as CartelBrain
		if b != null:
			b.wake(&"shout")


## ShoutSystem hook: gangsters are never dominated (L4.10); a shout only wakes them.
func on_shouted(_crew: Node) -> bool:
	wake(&"shout")
	return false


func _physics_process(delta: float) -> void:
	if not _started or _npc == null or not _npc.alive or not Net.is_authority():
		return
	if _npc.is_stunned():
		wants_to_fire = false
		return
	if _npc.alert_state == Enums.AlertState.COMBAT:
		_tick_combat(delta)
	elif _npc.alert_state == Enums.AlertState.CALM:
		_tick_patrol(delta)
		_tick_sight(delta)


# --- Asleep ------------------------------------------------------------------------------------

func _build_route() -> void:
	var graph: PatrolGraph = _npc.spawn_info.get("patrol_graph") as PatrolGraph
	if graph == null and _runtime != null:
		var graphs: Array[Node] = []
		for g: Node in get_tree().get_nodes_in_group(G.PATROL_GRAPH):
			if _runtime.is_ancestor_of(g):
				graphs.append(g)
		graph = PatrolRouteGenerator.nearest_graph(graphs, _post_pos, tweak.route_tag, tweak.nearest_graph_max_m)
	if graph == null:
		return
	var res: Dictionary = PatrolRouteGenerator.build(graph, _post_pos, GameRng.stream(RNG_STREAM),
		tweak.route_min_points, tweak.route_max_points, tweak.route_tag, tweak.route_attempts)
	var pts: Array[PatrolPoint] = res["points"]
	if pts.size() < 2:
		return
	for p: PatrolPoint in PatrolRouteGenerator.visit_order(pts, bool(res["loop"])):
		route.append(p.global_position)


func _tick_patrol(delta: float) -> void:
	if route.is_empty():
		anim_hint = &"idle"
		return
	if _walking:
		if _motor.arrived:
			_walking = false
			_route_index = (_route_index + 1) % route.size()
			_pause_left = GameRng.stream(RNG_STREAM).randf_range(1.0, 4.0)
			anim_hint = &"idle"
		return
	_pause_left -= delta
	if _pause_left > 0.0:
		return
	_motor.go_to(route[_route_index], tweak.patrol_speed)
	_walking = true
	anim_hint = &"walk"


func _tick_sight(delta: float) -> void:
	if _runtime == null:
		return
	var eye: Vector3 = _npc.eye_position()
	var fwd: Vector3 = _npc.look_forward()
	var cos_half: float = cos(deg_to_rad(tweak.sight_fov_deg * 0.5))
	for c: CrewController in _runtime.crew_members():
		var seen: bool = false
		if c.crew_state != Enums.CrewState.CUSTODY:
			var to: Vector3 = c.eye_position() - eye
			var flat: Vector3 = Vector3(to.x, 0.0, to.z)
			seen = to.length() <= tweak.sight_range_m and flat.length() > 0.01 \
				and flat.normalized().dot(Vector3(fwd.x, 0.0, fwd.z).normalized()) >= cos_half \
				and CombatSystem.has_npc_los(_npc, eye, c.eye_position(), [_npc, c])
		var t: float = maxf(float(_sight.get(c.slot, 0.0)) + (delta if seen else -delta), 0.0)
		_sight[c.slot] = t
		if t >= tweak.sight_time_s:
			wake(&"sight")
			return


func _on_noise(position: Vector3, radius: float, kind: StringName, _source: int) -> void:
	if _npc == null or not _npc.alive or _npc.alert_state != Enums.AlertState.CALM:
		return
	if tweak.wake_noise_kinds.has(kind) and position.distance_to(_npc.global_position) <= radius:
		wake(kind)


func _on_damage(victim_net_id: int, _attacker: int, _info: Dictionary) -> void:
	if _npc != null and victim_net_id == _npc.net_id:
		wake(&"damage")


# --- Awake: hold the post ------------------------------------------------------------------------

func _tick_combat(delta: float) -> void:
	_retarget_left -= delta
	if _retarget_left <= 0.0 or combat_target == null or not is_instance_valid(combat_target):
		_retarget_left = tweak.retarget_s
		combat_target = _pick_target()
	var t: CrewController = combat_target as CrewController
	if t == null:
		wants_to_fire = false
		_hold_post()
		return
	_target_visible = CombatSystem.has_npc_los(_npc, _npc.eye_position(), t.eye_position(), [_npc, t])
	wants_to_fire = _target_visible and _npc.global_position.distance_to(t.global_position) <= tweak.fire_range_m
	if cover_point == null or not is_instance_valid(cover_point):
		var cp: TacticalPoint = _find_cover(t)
		if cp != null:
			cover_point = cp
			cp.set_meta(PoliceBrain.CLAIM_META, _npc.get_instance_id())
	if cover_point != null:
		if _motor.target.distance_to(cover_point.global_position) > 0.3 or (_motor.arrived and _flat_dist(cover_point.global_position) > 0.6):
			_motor.go_to(cover_point.global_position, tweak.run_speed)
	else:
		_hold_post()
	if _motor.arrived:
		_motor.face(t.global_position - _npc.global_position)
	anim_hint = &"aim" if wants_to_fire else &"run"


func _hold_post() -> void:
	if _flat_dist(_post_pos) > 1.0 and (_motor.arrived or _motor.target.distance_to(_post_pos) > 0.3):
		_motor.go_to(_post_pos, tweak.run_speed)


func _pick_target() -> CrewController:
	if _runtime == null:
		return null
	var best: CrewController = null
	var best_d: float = INF
	var eye: Vector3 = _npc.eye_position()
	for c: CrewController in _runtime.crew_members():
		if c.crew_state == Enums.CrewState.CUSTODY:
			continue
		var d: float = _npc.global_position.distance_to(c.global_position)
		if not CombatSystem.has_npc_los(_npc, eye, c.eye_position(), [_npc, c]):
			d += 1000.0  # prefer someone in sight
		if d < best_d:
			best = c
			best_d = d
	return best


func _find_cover(t: Node3D) -> TacticalPoint:
	if _runtime == null or _runtime.map == null:
		return null
	var best: TacticalPoint = null
	var best_d: float = INF
	for n: Node in _runtime.map.get_slots(G.COVER_POINT):
		var tp: TacticalPoint = n as TacticalPoint
		if tp == null or _claimed_by_other(tp):
			continue
		var d_post: float = Vector2(tp.global_position.x - _post_pos.x, tp.global_position.z - _post_pos.z).length()
		if d_post > minf(tweak.cover_search_m, tweak.post_leash_m) or d_post >= best_d:
			continue
		var d_t: float = tp.global_position.distance_to(t.global_position)
		if d_t < tweak.cover_min_m or d_t > tweak.cover_max_m:
			continue
		var c: CrewController = t as CrewController
		var to: Vector3 = c.eye_position() if c != null else t.global_position + Vector3.UP * 1.5
		if CombatSystem.has_los(_npc, tp.global_position + Vector3(0.0, _npc.head_height, 0.0), to, [_npc, t]):
			best = tp
			best_d = d_post
	return best


func _claimed_by_other(tp: TacticalPoint) -> bool:
	if not tp.has_meta(PoliceBrain.CLAIM_META):
		return false
	var owner_id: int = int(tp.get_meta(PoliceBrain.CLAIM_META))
	if owner_id == _npc.get_instance_id():
		return false
	var o: NpcBase = instance_from_id(owner_id) as NpcBase
	return o != null and is_instance_valid(o) and o.alive


func _release_cover() -> void:
	if cover_point != null and is_instance_valid(cover_point) and cover_point.has_meta(PoliceBrain.CLAIM_META) \
			and _npc != null and int(cover_point.get_meta(PoliceBrain.CLAIM_META)) == _npc.get_instance_id():
		cover_point.remove_meta(PoliceBrain.CLAIM_META)
	cover_point = null


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - _npc.global_position.x, p.z - _npc.global_position.z).length()
