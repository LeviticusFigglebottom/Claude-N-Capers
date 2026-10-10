## Shared base for special-enemy brains (A3-01a: Phantom, Stinger, Longshot). Owner: ENV A. Server only.
## Child `Brain` of npc_<special>.tscn (siblings: Motor = NpcMotor, optional Gunner = NpcGunner).
## Like PoliceBrain it is idle until the heist is loud (HeistRuntime.went_loud). On start (server) it
## emits `special_spawned(net_id, special_type)` [R] (events.md), whoever spawned the unit
## (AssaultDirector via spawn_npc + enemy_def, SpecialSpawner.spawn_special, tests).
## Subclasses override `_tick_active(delta)` (and optionally `_on_activate`, `_on_npc_died`).
## Combat hook for NpcGunner: `wants_to_fire` / `combat_target` (duck-typed like PoliceBrain).
class_name SpecialBrain
extends Node

const RNG_STREAM: StringName = &"special_ai"
const CLAIM_META: StringName = &"special_claim"
const FLANK_GROUP: StringName = &"flank_point"
## Alert states this brain drives (anything else is owned elsewhere, e.g. DEAD).
const ACTIVE_STATES: Array[int] = [Enums.AlertState.CALM, Enums.AlertState.COMBAT]

## &"phantom", &"stinger", &"longshot" (special_spawned type; HUD warnings use phantom / stinger).
@export var special_type: StringName = &""
@export var tweak: SpecialTweak

var wants_to_fire: bool = false
var combat_target: Node = null
## Behaviour mode (debug / tests / animation driver).
var mode: StringName = &"idle"
## Animation hint for the visual layer (characters.md names).
var anim_hint: StringName = &"idle"

var _npc: NpcBase = null
var _motor: NpcMotor = null
var _runtime: HeistRuntime = null
var _started: bool = false
var _active: bool = false
var _retarget_left: float = 0.0


func _ready() -> void:
	if tweak == null:
		tweak = SpecialTweak.data()
	_npc = get_parent() as NpcBase
	_motor = _npc.get_node_or_null("Motor") as NpcMotor if _npc != null else null
	if _npc == null or _motor == null:
		Log.error(&"ai", "SpecialBrain needs an NpcBase parent with a Motor (NpcMotor) child")
		return
	_npc.alert_state_changed.connect(_on_alert_state_changed)
	_npc.died.connect(_on_died)
	_start.call_deferred()  # spawn_npc sets the transform after add_child


func _start() -> void:
	if _npc == null or not is_inside_tree() or not Net.is_authority():
		return
	_runtime = HeistRuntime.of(_npc)
	_started = true
	_on_started()
	if _npc.alive:
		PoliceSpecialKit.announce(_npc, special_type)  # special_spawned [R], once per unit


func _physics_process(delta: float) -> void:
	if not _started or _npc == null or not _npc.alive or not Net.is_authority():
		return
	if _npc.is_stunned():
		wants_to_fire = false
		_on_stunned_tick(delta)
		return
	if not _active:
		if _runtime == null or not _runtime.went_loud or not ACTIVE_STATES.has(_npc.alert_state):
			return
		_active = true
		_npc.set_alert_state(Enums.AlertState.COMBAT)
		_retarget_left = 0.0
		_on_activate()
	if not ACTIVE_STATES.has(_npc.alert_state):
		return
	_tick_active(delta)


func is_active() -> bool:
	return _active


# --- Overridables ------------------------------------------------------------------------------

func _on_started() -> void:
	pass


func _on_activate() -> void:
	pass


func _tick_active(_delta: float) -> void:
	pass


func _on_stunned_tick(_delta: float) -> void:
	pass


func _on_npc_died() -> void:
	pass


# --- Targeting helpers ----------------------------------------------------------------------------

## Crew members that are standing (NORMAL / SWAN_SONG) in this heist.
func standing_crew() -> Array[CrewController]:
	var out: Array[CrewController] = []
	if _runtime == null:
		return out
	for c: CrewController in _runtime.crew_members():
		if c.crew_state == Enums.CrewState.NORMAL or c.crew_state == Enums.CrewState.SWAN_SONG:
			out.append(c)
	return out


## Nearest standing crew member accepted by `filter` (Callable(CrewController) -> bool, optional),
## preferring one in LOS. Returns {"crew": CrewController or null, "visible": bool}.
func nearest_standing(filter: Callable = Callable()) -> Dictionary:
	var best_vis: CrewController = null
	var best_any: CrewController = null
	var dv: float = INF
	var da: float = INF
	for c: CrewController in standing_crew():
		if filter.is_valid() and not bool(filter.call(c)):
			continue
		var d: float = c.global_position.distance_squared_to(_npc.global_position)
		if d < da:
			da = d
			best_any = c
		if d < dv and can_see(c):
			dv = d
			best_vis = c
	if best_vis != null:
		return {"crew": best_vis, "visible": true}
	return {"crew": best_any, "visible": false}


func can_see(c: CrewController) -> bool:
	return CombatSystem.has_los(_npc, _npc.eye_position(), c.eye_position(), [_npc, c])


func flat_dist_to(n: Node3D) -> float:
	return _flat(n.global_position - _npc.global_position).length()


## Nearest FLANK TacticalPoint to `t` within `max_from_target` (null if none).
func find_flank_point(t: Node3D, max_from_target: float) -> Node3D:
	if t == null or _runtime == null or _runtime.map == null:
		return null
	var best: Node3D = null
	var best_d: float = max_from_target
	for n: Node in _runtime.map.get_slots(FLANK_GROUP):
		var p: Node3D = n as Node3D
		if p == null:
			continue
		var d: float = _flat(p.global_position - t.global_position).length()
		if d < best_d:
			best_d = d
			best = p
	return best


# --- Movement / presentation helpers ----------------------------------------------------------------

func move_to(pos: Vector3, new_mode: StringName, speed: float = -1.0) -> void:
	mode = new_mode
	anim_hint = &"run"
	var sp: float = speed if speed > 0.0 else run_speed()
	if _motor.target == Vector3.INF or _motor.target.distance_to(pos) > 0.5 or not is_equal_approx(_motor.speed, sp):
		_motor.go_to(pos, sp)


func hold(face_at: Vector3, new_mode: StringName = &"hold") -> void:
	mode = new_mode
	anim_hint = &"aim"
	_motor.stop()
	_motor.face_point(face_at)


func run_speed() -> float:
	return _npc.enemy_def.move_speed if _npc.enemy_def != null else tweak.fallback_run_speed


## [R] 3D cue at the NPC (audio_cues.md: emitter decides replication; specials replicate).
func cue(cue_id: StringName, pos: Vector3 = Vector3.INF) -> void:
	var p: Vector3 = _npc.global_position if pos == Vector3.INF else pos
	EventBus.audio_cue_requested.emit(cue_id, p, _npc.net_id)
	Net.replicate_event(&"audio_cue_requested", [cue_id, p, _npc.net_id])


## Stretch a beam node (unit-length along -Z, origin at one end) from `from` to `to`.
static func aim_beam(beam: Node3D, from: Vector3, to: Vector3) -> void:
	if beam == null or not beam.is_inside_tree():
		return
	var seg: Vector3 = to - from
	var length: float = seg.length()
	if length < 0.01:
		beam.visible = false
		return
	var up: Vector3 = Vector3.UP if absf(seg.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	beam.global_transform = Transform3D(Basis.looking_at(seg, up), from)
	beam.scale = Vector3(1.0, 1.0, length)


func roll(r: Vector2) -> float:
	return GameRng.stream(RNG_STREAM).randf_range(minf(r.x, r.y), maxf(r.x, r.y))


func chance(p: float) -> bool:
	return p > 0.0 and GameRng.stream(RNG_STREAM).randf() < p


# --- Signals ---------------------------------------------------------------------------------------

func _on_alert_state_changed(_old_state: int, new_state: int) -> void:
	if ACTIVE_STATES.has(new_state):
		return
	wants_to_fire = false
	combat_target = null
	if _motor != null:
		_motor.stop()


func _on_died(_info: Dictionary, _killer_net_id: int) -> void:
	wants_to_fire = false
	_on_npc_died()
	combat_target = null
	anim_hint = &""
	set_physics_process(false)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
