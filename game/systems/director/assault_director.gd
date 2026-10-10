## Loud assault director (A1-09; L1.1 one wave cycle, L1.4 spawning, S11.2). Owner: ENV A. Server only.
## Service G.SVC_DIRECTOR (HeistRuntime child). Starts when the heist goes LOUD (or is loud at start).
## Phase machine (Enums.AssaultPhase): CONTROL (first responders, first_control_s) -> ANTICIPATION
## (anticipation_s, +anticipation_hostage_bonus_s once if hostages > 0) -> BUILD (build_s) ->
## SUSTAIN (sustain_by_stage_s[stage(wave)] x sustain_crew_mult[crew count]) -> FADE once the sustain
## timer is over and (alive police < fade_threshold[difficulty] or fade_wait_cap_s passed) ->
## fade_s without spawning -> CONTROL (wave + 1, control_between_waves_s) -> ANTICIPATION ...
## Every change emits EventBus.assault_phase_changed(phase, wave_index) [R]. `wave_index` is the
## 1-based assault the phase belongs to (the first CONTROL already carries wave 1; the CONTROL after
## wave 1's FADE carries wave 2).
## Spawning (L1.4): SpawnGroupDef groups are queued and their units spawned one by one at the valid
## spawn point nearest to the crew centroid (nav path length when a navmesh path exists, else
## straight). Valid = a POLICE SpawnPoint or ENTRY TacticalPoint with no LOS from any non-custody
## crew eye and >= min_crew_distance_m from every one of them, re-checked at each unit's spawn time.
## Alive police (roles &"police" + &"special") never exceed DifficultyDef.enemy_cap. CONTROL spawns
## are low-rate; BUILD/SUSTAIN spawn a group every assault_group_interval_s / assault_intensity.
## FADE: the director stops reinforcing; units keep fighting (no retreat in P1).
## Drama (L1.2, P3): hook `_drama_spawn_scale()` (always 1.0 for now).
## Faction (L1.5, P3): P1 uses Patrol Officer + TAC Light on every difficulty via group weights.
class_name AssaultDirector
extends Node

signal phase_changed(phase: int, wave_index: int)
signal unit_spawned(npc: NpcBase, spawn_point: Node3D)

const DEFAULT_TWEAK: String = "res://systems/director/director_tweak.tres"
const ENEMY_DIR: String = "res://systems/ai/data/enemies/"
const RNG_DIRECTOR: StringName = &"director"
const RNG_SPAWNS: StringName = &"spawns"
const POLICE_ROLES: Array[StringName] = [&"police", &"special"]

@export var tweak: DirectorTweak

var assault_phase: Enums.AssaultPhase = Enums.AssaultPhase.NONE
var wave_index: int = 0
## Seconds left in the current timed phase (ANTICIPATION, BUILD, SUSTAIN, FADE, CONTROL).
var phase_time_left: float = 0.0
## Seconds spent in the current phase.
var phase_time: float = 0.0
var hostages: int = 0
var hostage_bonus_applied: bool = false
var running: bool = false
## Units spawned by the director (alive or not), in order.
var spawned_total: int = 0

var _runtime: HeistRuntime = null
var _queue: Array[StringName] = []
var _queue_index: int = 0
var _unit_left: float = 0.0
var _group_left: float = 0.0
var _first_responder_groups_left: int = 0
var _sustain_over_t: float = -1.0
var _defs: Dictionary[StringName, EnemyDef] = {}
var _spawn_counter: int = 0


func _ready() -> void:
	if tweak == null:
		tweak = load(DEFAULT_TWEAK) as DirectorTweak
	_runtime = HeistRuntime.of(self)
	if _runtime != null:
		var override: DirectorTweak = _runtime.options.get("director_tweak") as DirectorTweak
		if override != null:
			tweak = override
		_runtime.phase_changed.connect(_on_heist_phase_changed)
		if _runtime.went_loud or _runtime.phase == Enums.HeistPhase.LOUD:
			begin.call_deferred()
	EventBus.hostage_count_changed.connect(_on_hostage_count_changed)


func _exit_tree() -> void:
	if EventBus.hostage_count_changed.is_connected(_on_hostage_count_changed):
		EventBus.hostage_count_changed.disconnect(_on_hostage_count_changed)


# --- Public API ------------------------------------------------------------------------------

## Alive police units (roles &"police" / &"special") in this heist: AI teammates' target list.
## A3-04 (L5.1/L5.2): surrendered, tied and converted cops (NpcBase.BLIND_STATES) are not units.
func alive_units() -> Array[NpcBase]:
	var out: Array[NpcBase] = []
	if _runtime == null:
		return out
	for n: Node in _runtime.npcs():
		var npc: NpcBase = n as NpcBase
		if npc != null and POLICE_ROLES.has(npc.role) and not NpcBase.BLIND_STATES.has(npc.alert_state):
			out.append(npc)
	return out


func alive_count() -> int:
	return alive_units().size()


func enemy_cap() -> int:
	return _runtime.difficulty_def.enemy_cap if _runtime != null and _runtime.difficulty_def != null else 20


func is_assault_active() -> bool:
	return assault_phase == Enums.AssaultPhase.BUILD or assault_phase == Enums.AssaultPhase.SUSTAIN \
		or assault_phase == Enums.AssaultPhase.FADE


## Server: start the loud cycle now (idempotent). Called on the LOUD phase change.
func begin() -> void:
	if running or not Net.is_authority():
		return
	if _runtime != null and _runtime.heist_mode == Enums.HeistMode.STEALTH_ONLY:
		return  # S11.3: a stealth-only alarm aborts the heist, no assault
	running = true
	wave_index = 1
	_first_responder_groups_left = tweak.first_responder_groups
	_group_left = 0.0
	_enter(Enums.AssaultPhase.CONTROL, tweak.first_control_s)


## Sustain length for `wave` with `crew_count` crew (L1.1 table).
func sustain_duration(wave: int, crew_count: int) -> float:
	var stage: int = 0
	if not tweak.wave_stage.is_empty():
		stage = tweak.wave_stage[clampi(wave - 1, 0, tweak.wave_stage.size() - 1)]
	var base: float = tweak.sustain_by_stage_s[clampi(stage, 0, tweak.sustain_by_stage_s.size() - 1)]
	var mult: float = 1.0
	if not tweak.sustain_crew_mult.is_empty():
		mult = tweak.sustain_crew_mult[clampi(crew_count - 1, 0, tweak.sustain_crew_mult.size() - 1)]
	return base * mult


## Spawn points valid right now (L1.4), nearest to the crew centroid first.
func valid_spawn_points() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _runtime == null or _runtime.map == null:
		return out
	var crew: Array[CrewController] = _active_crew()
	var cands: Array[Node3D] = []
	for g: StringName in [G.POLICE_SPAWN, G.ENTRY_POINT]:
		for n: Node in _runtime.map.get_slots(g):
			var p: Node3D = n as Node3D
			if p != null and is_spawn_valid(p.global_position, crew):
				cands.append(p)
	if cands.is_empty():
		return out
	var centroid: Vector3 = _centroid(crew)
	var cost: Dictionary[Node3D, float] = {}
	for p: Node3D in cands:
		cost[p] = _path_cost(p.global_position, centroid)
	cands.sort_custom(func(a: Node3D, b: Node3D) -> bool: return cost[a] < cost[b])
	return cands


## L1.4: no LOS from any non-custody crew member and >= min_crew_distance_m from all of them.
func is_spawn_valid(pos: Vector3, crew: Array[CrewController] = []) -> bool:
	if crew.is_empty():
		crew = _active_crew()
	var exclude: Array[RID] = []
	for c: CrewController in crew:
		exclude.append(c.get_rid())
	var probe: Vector3 = pos + Vector3(0.0, tweak.los_check_height_m, 0.0)
	var space: PhysicsDirectSpaceState3D = _runtime.map.get_world_3d().direct_space_state
	for c: CrewController in crew:
		if _flat(c.global_position - pos).length() < tweak.min_crew_distance_m:
			return false
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c.eye_position(), probe,
			StealthDirector.VISION_MASK)
		q.exclude = exclude
		if space.intersect_ray(q).is_empty():
			return false
	return true


# --- Phase machine ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not running or not Net.is_authority() or _runtime == null:
		return
	if _runtime.phase == Enums.HeistPhase.ENDED:
		running = false
		_queue.clear()
		return
	phase_time += delta
	phase_time_left -= delta
	match assault_phase:
		Enums.AssaultPhase.CONTROL:
			_tick_control_spawns(delta)
			if phase_time_left <= 0.0:
				_enter(Enums.AssaultPhase.ANTICIPATION, tweak.anticipation_s)
				_maybe_hostage_bonus()
		Enums.AssaultPhase.ANTICIPATION:
			if phase_time_left <= 0.0:
				_enter(Enums.AssaultPhase.BUILD, tweak.build_s)
		Enums.AssaultPhase.BUILD:
			_tick_assault_spawns(delta)
			if phase_time_left <= 0.0:
				_sustain_over_t = -1.0
				_enter(Enums.AssaultPhase.SUSTAIN, sustain_duration(wave_index, _runtime.crew_members().size()))
		Enums.AssaultPhase.SUSTAIN:
			_tick_sustain(delta)
		Enums.AssaultPhase.FADE:
			if phase_time_left <= 0.0:
				wave_index += 1
				_enter(Enums.AssaultPhase.CONTROL, tweak.control_between_waves_s)
	_tick_queue(delta)


func _tick_sustain(delta: float) -> void:
	if phase_time_left > 0.0:
		_tick_assault_spawns(delta)
		return
	if _sustain_over_t < 0.0:
		_sustain_over_t = 0.0
	_sustain_over_t += delta
	var thr: int = tweak.fade_threshold[clampi(_runtime.difficulty, 0, tweak.fade_threshold.size() - 1)] \
		if not tweak.fade_threshold.is_empty() else 0
	if alive_count() < thr or _sustain_over_t >= tweak.fade_wait_cap_s:
		_queue.clear()
		_enter(Enums.AssaultPhase.FADE, tweak.fade_s)


func _enter(p: Enums.AssaultPhase, duration: float) -> void:
	assault_phase = p
	phase_time = 0.0
	phase_time_left = duration
	Log.info(&"director", "assault phase %s (wave %d, %.0f s)" % [Enums.AssaultPhase.keys()[p], wave_index, duration])
	phase_changed.emit(p, wave_index)
	EventBus.assault_phase_changed.emit(p, wave_index)
	Net.replicate_event(&"assault_phase_changed", [p, wave_index])


func _maybe_hostage_bonus() -> void:
	if assault_phase != Enums.AssaultPhase.ANTICIPATION or hostage_bonus_applied or hostages <= 0:
		return
	hostage_bonus_applied = true  # L1.1: once per heist, not per hostage
	phase_time_left += tweak.anticipation_hostage_bonus_s
	Log.info(&"director", "hostage held: anticipation +%.0f s" % tweak.anticipation_hostage_bonus_s)


# --- Spawning -------------------------------------------------------------------------------------

func _tick_control_spawns(delta: float) -> void:
	_group_left -= delta
	if _group_left > 0.0 or not _queue_empty():
		return
	if _first_responder_groups_left > 0:
		if _enqueue(tweak.first_responder_group):
			_first_responder_groups_left -= 1
		_group_left = tweak.first_responder_interval_s
		return
	if wave_index > 1 and alive_count() < tweak.control_alive_max:
		_enqueue(_pick_group(Enums.AssaultPhase.CONTROL))
	_group_left = tweak.control_group_interval_s


func _tick_assault_spawns(delta: float) -> void:
	_group_left -= delta
	if _group_left > 0.0 or not _queue_empty():
		return
	var intensity: float = _runtime.difficulty_def.assault_intensity if _runtime.difficulty_def != null else 1.0
	_group_left = tweak.assault_group_interval_s / maxf(intensity * _drama_spawn_scale(), 0.05)
	if alive_count() < enemy_cap():
		_enqueue(_pick_group(assault_phase))


## L1.2 hook (P3): spawn-rate scale from drama, (1 - 0.5 * drama). P1: no drama.
func _drama_spawn_scale() -> float:
	return 1.0


func _pick_group(phase: int) -> SpawnGroupDef:
	var total: float = 0.0
	var cands: Array[SpawnGroupDef] = []
	for g: SpawnGroupDef in tweak.assault_groups:
		if g != null and g.allows_phase(phase) and g.weight(_runtime.difficulty) > 0.0:
			cands.append(g)
			total += g.weight(_runtime.difficulty)
	if cands.is_empty():
		return null
	var r: float = GameRng.stream(RNG_DIRECTOR).randf() * total
	for g: SpawnGroupDef in cands:
		r -= g.weight(_runtime.difficulty)
		if r <= 0.0:
			return g
	return cands[cands.size() - 1]


func _enqueue(g: SpawnGroupDef) -> bool:
	if g == null:
		return false
	_queue = g.expanded_units()
	_queue_index = 0
	_spawn_counter = 0
	return not _queue.is_empty()


func _queue_empty() -> bool:
	return _queue_index >= _queue.size()


func _tick_queue(delta: float) -> void:
	if _queue_empty():
		return
	if assault_phase == Enums.AssaultPhase.FADE or assault_phase == Enums.AssaultPhase.ANTICIPATION:
		_queue.clear()
		return
	_unit_left -= delta
	if _unit_left > 0.0:
		return
	if alive_count() >= enemy_cap():
		_queue.clear()
		return
	var points: Array[Node3D] = valid_spawn_points()
	if points.is_empty():
		_unit_left = tweak.no_point_retry_s
		return
	_unit_left = tweak.unit_spawn_interval_s
	var id: StringName = _queue[_queue_index]
	_queue_index += 1
	_spawn_unit(id, points[0])


func _spawn_unit(enemy_id: StringName, point: Node3D) -> NpcBase:
	var def: EnemyDef = _enemy_def(enemy_id)
	var xf: Transform3D = point.global_transform
	var crew: Array[CrewController] = _active_crew()
	# Spread units of one group sideways; keep the base point if the offset would be invalid.
	var side: Vector3 = xf.basis.x.normalized()
	var k: int = _spawn_counter
	_spawn_counter += 1
	var offset: Vector3 = side * tweak.unit_spread_m * floorf(float(k + 1) * 0.5) * (1.0 if k % 2 == 1 else -1.0)
	if k > 0 and is_spawn_valid(xf.origin + offset, crew):
		xf.origin += offset
	var centroid: Vector3 = _centroid(crew)
	var look: Vector3 = _flat(centroid - xf.origin)
	if look.length() > 0.1:
		xf.basis = Basis.looking_at(look, Vector3.UP)
	var info: Dictionary = {"spawn_point": point, "assault_wave": wave_index, "tags": point.get(&"tags")}
	if def != null:
		info["enemy_def"] = def
	var npc: NpcBase = _runtime.spawn_npc(&"police", xf, info)
	if npc != null:
		spawned_total += 1
		unit_spawned.emit(npc, point)
	return npc


func _enemy_def(enemy_id: StringName) -> EnemyDef:
	if _defs.has(enemy_id):
		return _defs[enemy_id]
	var path: String = ENEMY_DIR + String(enemy_id).trim_prefix("enemy.") + ".tres"
	var def: EnemyDef = load(path) as EnemyDef if ResourceLoader.exists(path) else null
	if def == null:
		Log.error(&"director", "no EnemyDef for %s (%s)" % [enemy_id, path])
	_defs[enemy_id] = def
	return def


# --- Helpers ----------------------------------------------------------------------------------

func _active_crew() -> Array[CrewController]:
	var out: Array[CrewController] = []
	if _runtime == null:
		return out
	for c: CrewController in _runtime.crew_members():
		if c.crew_state != Enums.CrewState.CUSTODY:
			out.append(c)
	return out


func _centroid(crew: Array[CrewController]) -> Vector3:
	if crew.is_empty():
		return Vector3.ZERO
	var s: Vector3 = Vector3.ZERO
	for c: CrewController in crew:
		s += c.global_position
	return s / float(crew.size())


## Nav path length from `from` to `to` when the map has a path, else the straight distance.
func _path_cost(from: Vector3, to: Vector3) -> float:
	var straight: float = from.distance_to(to)
	var nav_map: RID = _runtime.map.get_world_3d().navigation_map
	if not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return straight
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, from, to, true)
	if path.size() < 2 or path[path.size() - 1].distance_to(to) > 2.0:
		return straight
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _on_heist_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase == Enums.HeistPhase.LOUD:
		begin()


func _on_hostage_count_changed(count: int) -> void:
	hostages = count
	_maybe_hostage_bonus()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
