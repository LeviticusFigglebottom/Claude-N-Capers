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
## Alive police (roles &"police" + &"special") never exceed police_budget(): force_cap() (PO-5.4:
## DifficultyDef.enemy_cap x PD2 crew balance x L1.3 stage force) and enemy_cap minus cartel. CONTROL
## spawns are low-rate; BUILD/SUSTAIN spawn a group every assault_group_interval_s / assault_intensity
## until the assault's _force_pool() is spent (then FADE, as PD2's task_spawn_allowance).
## PO6-16 (D-114 §5 horde pacing): while alive < police_budget() in BUILD/SUSTAIN the group timer is
## assault_refill_interval_s instead (same scaling), and BUILD starts with a group at once, so the force is
## topped back up within seconds of losses (PD2 sustain); every wave still ends FADE -> CONTROL.
## FADE (L1.1): the director stops reinforcing and orders its units to retreat (fade_retreat): each
## unit with a PoliceBrain walks to the nearest spawn point and leaves the map there out of crew LOS.
## A3-03 drama (L1.2): `drama` 0..1 rises with crew damage taken, crew downs and shots/kills within
## drama_combat_radius_m of the crew; decays drama_decay_per_s. BUILD/SUSTAIN spawn rate x
## (1 - drama_spawn_scale * drama). After the sustain timer FADE also comes once drama stayed below
## drama_fade_level for drama_fade_window_s (fade_wait_cap_s stays as a hard cap).
## A3-03 escalation (L1.3): stage() = wave_stage[wave - 1] (50/75/100%) drives sustain length,
## group weights (SpawnGroupDef.stage_weight_mult) and the spawn rate (stage_spawn_rate_mult).
## Specials also come between waves: CONTROL (wave >= 2) rolls control_special_groups.
## A3-03 factions (L1.5): faction() by difficulty (TAC / FRD / Sentinel / Zero Division) remaps each
## role id to enemies/<suffix>/<role>.tres when it exists and filters SpawnGroupDef.factions.
## A3-03 special caps (L4.11): a special unit spawns only while alive units sharing its limit key
## (D-022: every enemy.wrecker_* counts as enemy.wrecker) < DifficultyDef.special_limits[key].
## Units without an EnemyDef (specials not implemented yet) are skipped. Longshots spawn only on a
## free SNIPER_PERCH point (SpecialSpawner.spawn_special places and claims it).
## A3-02 (L4.9): Commander Brandt + Aegis squad live in the child AegisCaptain; while he is on the
## map FADE never comes. NpcBase.take_hit calls modify_npc_hit() (resistance + per-hit cap).
## PO6-17 (D-114 §5): RNG assault events (turret van, helicopter, breach points) live in the child
## AssaultEventRunner `AssaultEvents`, ticked from the phase machine (GameRng &"assault_events").
class_name AssaultDirector
extends Node

signal phase_changed(phase: int, wave_index: int)
signal unit_spawned(npc: NpcBase, spawn_point: Node3D)

## QC-83 (b/c): spawn_enemy `extra` key of a mission-spawned unit (HeistMission.spawn_units: not an assault spawn);
## NPC meta of a non-police unit that shares the police cap.
const MISSION_UNIT: String = "mission_unit"
const META_SHARES_CAP: StringName = &"shares_police_cap"
const DEFAULT_TWEAK: String = "res://systems/director/director_tweak.tres"
const RNG_DIRECTOR: StringName = &"director"
const RNG_SPAWNS: StringName = &"spawns"
const POLICE_ROLES: Array[StringName] = [&"police", &"special"]
const LONGSHOT_ID: StringName = &"enemy.longshot"
## QC-42 (D-064): a POLICE_SPAWN / ENTRY point tagged this is never a spawn (police only enter through it:
## interior ENTRY points such as Dockside's quay doors are breach / entry targets, not spawns).
const BREACH_ONLY_TAG: StringName = &"breach_only"

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
## QC-35 (D-064, Dockside Burn cartel phase): seconds the police start is held once begin() is called
## (> 0 = waiting; HeistMission.police_delay_s sets it). Setting 0 while waiting starts the police now.
var start_delay_s: float = 0.0:
	set(v):
		start_delay_s = maxf(v, 0.0)
		if _start_held and start_delay_s <= 0.0:
			_start_held = false
			begin()
## D-158 (RT truck window): seconds until the FIRST assault's BUILD may begin (ticks down from the moment a mission
## sets it, running or not). ANTICIPATION ending earlier waits for it; a later one is unaffected. Later waves ignore it.
var first_build_hold_s: float = 0.0:
	set(v):
		first_build_hold_s = maxf(v, 0.0)
## Units spawned by the director (alive or not), in order.
var spawned_total: int = 0
## PO-5.4: units spawned in the current assault's BUILD/SUSTAIN (_force_pool() spending).
var assault_spawned: int = 0
## PO-5.4 (L1.1): units ordered to retreat in this FADE.
var retreating: Array[NpcBase] = []
## D-099: corpses removed by the loud-phase body cleanup (tests / telemetry).
var bodies_despawned: int = 0
## A3-03 (L1.2): pressure 0..1.
var drama: float = 0.0
## A3-02 (L4.9): Commander Brandt + Aegis squad.
var captain: AegisCaptain = null
## A3-03 (L1.5, L4.11): faction EnemyDefs and special caps.
var roster: EnemyRoster = null
## PO6-17: RNG assault events.
var events: AssaultEventRunner = null

var _start_held: bool = false
var _runtime: HeistRuntime = null
var _queue: Array[StringName] = []
var _queue_index: int = 0
var _unit_left: float = 0.0
var _group_left: float = 0.0
var _first_responder_groups_left: int = 0
var _sustain_over_t: float = -1.0
var _spawn_counter: int = 0
## Seconds of drama < drama_fade_level since the sustain timer ended.
var _low_drama_t: float = 0.0
## Seconds until Brandt's scheduled arrival in this assault (-1 = none).
var _captain_due_t: float = -1.0
var _control_special_left: float = 0.0
## D-099 body cleanup: corpse -> body clock time it was first seen dead.
var _body_died_at: Dictionary = {}
var _body_clock: float = 0.0
var _body_check_left: float = 0.0
## _prewarm(): scene paths queued for a background load (kept for tests / logs).
var _warm_paths: PackedStringArray = PackedStringArray()


func _ready() -> void:
	if tweak == null:
		tweak = load(DEFAULT_TWEAK) as DirectorTweak
	_runtime = HeistRuntime.of(self)
	roster = EnemyRoster.new(self)
	captain = AegisCaptain.new()
	captain.name = "AegisCaptain"
	captain.setup(self)
	add_child(captain)
	events = AssaultEventRunner.new()
	events.name = "AssaultEvents"
	events.setup(self)
	add_child(events)
	if _runtime != null:
		var override: DirectorTweak = _runtime.options.get("director_tweak") as DirectorTweak
		if override != null:
			tweak = override
		_runtime.phase_changed.connect(_on_heist_phase_changed)
		if _runtime.went_loud or _runtime.phase == Enums.HeistPhase.LOUD:
			begin.call_deferred()
		if Net.is_authority():
			_prewarm.call_deferred()
	EventBus.hostage_count_changed.connect(_on_hostage_count_changed)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.crew_downed.connect(_on_crew_downed)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.npc_killed.connect(_on_npc_killed)


## ND loud FrameProf: the first spawn of each unit type loaded its NPC scene and character on the main thread
## (3-10 s frames on llvmpipe). Server, at director start: load every scene the spawn tables can use (in parallel on
## worker threads, collected before returning), so spawning only instantiates. Returns how many paths were queued.
func _prewarm() -> int:
	var groups: Array[SpawnGroupDef] = []
	if tweak.first_responder_group != null:
		groups.append(tweak.first_responder_group)
	groups.append_array(tweak.assault_groups)
	groups.append_array(tweak.control_special_groups)
	var ids: Array[StringName] = []
	for g: SpawnGroupDef in groups:
		if g != null:
			for id: StringName in g.unit_ids:
				if not ids.has(id):
					ids.append(id)
	var defs: Array[EnemyDef] = []
	for id: StringName in ids:
		defs.append(_enemy_def(id))
	if captain != null:
		defs.append_array([captain.captain_def(), captain.shield_def()])
	var paths: PackedStringArray = PackedStringArray()
	for def: EnemyDef in defs:
		if def == null:
			continue
		var scene: Variant = def.params.get("scene", "")
		var sp: String = String(scene) if scene is String and String(scene) != "" \
			else String(HeistRuntime.NPC_SCENES.get(_spawn_role(def), ""))
		for p: String in [sp] + Array(NpcVisuals.def_scene_paths(def, _difficulty())):
			if p != "" and not paths.has(p):
				paths.append(p)
	var queued: int = 0
	for p: String in paths:
		if WarmLoader.request(p):  # GN-8: collected as they finish; spawning never load()s beside them
			queued += 1
			_warm_paths.append(p)
	# GN-8 / P ND-2 hang (main thread parked on a condvar right after "prewarm queued", CASING): heist-start spawns
	# load characters on the main thread while the workers load the same sub-resources. Wait for the workers here,
	# at heist start (parallel loads, one blocking step), so no background load ever runs beside gameplay loads.
	var t0: int = Time.get_ticks_msec()
	WarmLoader.collect_all()
	Log.info(&"director", "prewarm: %d of %d scenes loaded in %d ms" % [queued, paths.size(), Time.get_ticks_msec() - t0])
	return queued


func _exit_tree() -> void:
	# GN-8: collect the background loads still in flight (none may run into the next scene) and drop the holds.
	if not _warm_paths.is_empty():
		WarmLoader.release()
	_warm_paths.clear()
	if EventBus.hostage_count_changed.is_connected(_on_hostage_count_changed):
		EventBus.hostage_count_changed.disconnect(_on_hostage_count_changed)
	for pair: Array in [[EventBus.damage_applied, _on_damage_applied], [EventBus.crew_downed, _on_crew_downed],
			[EventBus.weapon_fired, _on_weapon_fired], [EventBus.npc_killed, _on_npc_killed]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


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


## D-064 (QC-36): police may fill enemy_cap() minus the alive cartel gunmen (they share the cap).
## QC-83 (c) (Rolling Thunder convoy units): likewise any alive non-police NPC with meta META_SHARES_CAP (police-role
## mission units are alive police already). PO-5.4: and never more than force_cap().
func police_budget() -> int:
	return mini(force_cap(), enemy_cap() - _shared_cap_count())


## Alive NPCs outside the police roles that share the police cap (cartel gunmen, QC-83 convoy units).
func _shared_cap_count() -> int:
	if _runtime == null:
		return 0
	var n: int = 0
	for node: Node in _runtime.npcs():
		var npc: NpcBase = node as NpcBase
		if npc == null or POLICE_ROLES.has(npc.role):
			continue
		if npc.role == CartelBrain.ROLE or npc.has_meta(META_SHARES_CAP):
			n += 1
	return n


## PO-5.4: PD2 force crew count (GroupAIStateBase:_get_balancing_multiplier): crew not in custody,
## AI teammates counted as max(1, floor(bots / 2)) when tweak.bots_count_half. At least 1.
func _force_crew_count() -> int:
	if _runtime == null:
		return 1
	var humans: int = 0
	var bots: int = 0
	for c: CrewController in _active_crew():
		if c.is_ai:
			bots += 1
		else:
			humans += 1
	var n: int = humans + ((maxi(1, bots / 2) if tweak.bots_count_half else bots) if bots > 0 else 0)
	return maxi(n, 1)


## PO-5.4 (L1.1/L1.3): alive police the director fills to in `wave` (default: the current one) =
## enemy_cap x force_crew_mult[force_crew_count] x stage_force_mult[stage], clamped to
## [force_min, enemy_cap].
func force_cap(wave: int = 0) -> int:
	return _force_cap_at(stage_for_wave(wave if wave > 0 else maxi(wave_index, 1)))


## PO-5.4: units the BUILD/SUSTAIN of `wave` may spawn in total (0 = unlimited): ceil(full-stage
## force cap x force_pool_per_force[stage]) (PD2 force_pool / force).
func _force_pool(wave: int = 0) -> int:
	if tweak.force_pool_per_force.is_empty():
		return 0
	var st: int = stage_for_wave(wave if wave > 0 else maxi(wave_index, 1))
	var ratio: float = tweak.force_pool_per_force[clampi(st, 0, tweak.force_pool_per_force.size() - 1)]
	if ratio <= 0.0:
		return 0
	var dmult: float = DirectorTweak.by_difficulty(tweak.force_pool_difficulty_mult, _difficulty())  # PO-17
	return ceili(float(_force_cap_at(tweak.stage_force_mult.size() - 1)) * ratio * dmult)


func _force_cap_at(stage_i: int) -> int:
	var cap: int = enemy_cap()
	var mult: float = 1.0
	if not tweak.force_crew_mult.is_empty():
		mult *= tweak.force_crew_mult[clampi(_force_crew_count() - 1, 0, tweak.force_crew_mult.size() - 1)]
	if not tweak.stage_force_mult.is_empty():
		mult *= tweak.stage_force_mult[clampi(stage_i, 0, tweak.stage_force_mult.size() - 1)]
	return clampi(roundi(float(cap) * mult), mini(tweak.force_min, cap), cap)


func is_assault_active() -> bool:
	return assault_phase == Enums.AssaultPhase.BUILD or assault_phase == Enums.AssaultPhase.SUSTAIN \
		or assault_phase == Enums.AssaultPhase.FADE


## Server: start the loud cycle now (idempotent). Called on the LOUD phase change.
func begin() -> void:
	if running or not Net.is_authority():
		return
	if _runtime != null and _runtime.heist_mode == Enums.HeistMode.STEALTH_ONLY:
		return  # S11.3: a stealth-only alarm aborts the heist, no assault
	if start_delay_s > 0.0:
		_start_held = true  # QC-35: _physics_process counts start_delay_s down, then begins
		return
	running = true
	wave_index = 1
	_first_responder_groups_left = tweak.first_responder_groups
	_group_left = 0.0
	_enter(Enums.AssaultPhase.CONTROL, tweak.first_control_s)


func runtime() -> HeistRuntime:
	return _runtime


## L1.3: escalation stage index for `wave` (0 = 50%, 1 = 75%, 2 = 100%).
func stage_for_wave(wave: int) -> int:
	if tweak.wave_stage.is_empty():
		return 0
	return tweak.wave_stage[clampi(wave - 1, 0, tweak.wave_stage.size() - 1)]


## L1.3: stage of the current assault.
func stage() -> int:
	return stage_for_wave(maxi(wave_index, 1))


## L1.5: faction of this run (&"faction.tac", &"faction.frd", &"faction.sentinel", &"faction.zero").
func faction() -> StringName:
	return roster.faction()


## L1.5: EnemyDef for a role id under the current faction (faction file if present, else the base
## file), or null when neither exists (unimplemented specials).
func enemy_def_for(enemy_id: StringName) -> EnemyDef:
	return roster.enemy_def(enemy_id)


## L1.2: add pressure (clamped 0..1). Server.
func add_drama(amount: float) -> void:
	drama = clampf(drama + amount, 0.0, 1.0)


## A3-02 (L4.9): current Aegis damage resistance for every enemy (0 when Brandt is absent). HUD.
func aegis_resistance() -> float:
	return captain.resistance if captain != null else 0.0


## A3-02: Brandt is on the map (assault locked).
func captain_active() -> bool:
	return captain != null and captain.locks_assault()


## NpcBase.take_hit hook (server): final hit amount after Aegis resistance / captain per-hit cap.
func modify_npc_hit(npc: NpcBase, amount: float, info: Dictionary) -> float:
	if captain == null or npc == null:
		return amount
	return captain.modify_hit(npc, amount, info)


## Server: spawn one enemy with `def` at `xf` (facing the crew centroid). Role: def.params.spawn_role,
## else a HeistRuntime.NPC_SCENES entry named like the id (&"phantom"), else &"police".
func spawn_enemy(def: EnemyDef, xf: Transform3D, point: Node3D = null, extra: Dictionary = {}) -> NpcBase:
	if _runtime == null:
		return null
	var look: Vector3 = _flat(_centroid(_active_crew()) - xf.origin)
	if look.length() > 0.1:
		xf.basis = Basis.looking_at(look, Vector3.UP)
	var info: Dictionary = {"spawn_point": point, "assault_wave": wave_index, "faction": faction(),
		"tags": point.get(&"tags") if point != null and point.get(&"tags") is Array else []}
	info.merge(extra, true)
	if def != null:
		info["enemy_def"] = def
	var npc: NpcBase = _runtime.spawn_npc(_spawn_role(def), xf, info)
	if npc != null:
		spawned_total += 1
		if not extra.has("captain") and not extra.has("aegis") and not extra.has(MISSION_UNIT):
			_count_assault_spawn()  # Brandt's squad and mission units (QC-83) are outside the force pool
		unit_spawned.emit(npc, point)
	return npc


## Sustain length for `wave` with `crew_count` crew (L1.1 table).
func sustain_duration(wave: int, crew_count: int) -> float:
	var stage_i: int = stage_for_wave(wave)
	var base: float = tweak.sustain_by_stage_s[clampi(stage_i, 0, tweak.sustain_by_stage_s.size() - 1)]
	var mult: float = 1.0
	if not tweak.sustain_crew_mult.is_empty():
		mult = tweak.sustain_crew_mult[clampi(crew_count - 1, 0, tweak.sustain_crew_mult.size() - 1)]
	return base * mult


## Spawn points valid right now (L1.4), nearest to the crew centroid first. Points tagged BREACH_ONLY_TAG
## are skipped (QC-42).
func valid_spawn_points() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _runtime == null or _runtime.map == null:
		return out
	var crew: Array[CrewController] = _active_crew()
	var cands: Array[Node3D] = []
	for g: StringName in [G.POLICE_SPAWN, G.ENTRY_POINT]:
		for n: Node in _runtime.map.get_slots(g):
			var p: Node3D = n as Node3D
			var tags: Variant = p.get(&"tags") if p != null else null
			if tags is Array and (tags as Array).has(BREACH_ONLY_TAG):
				continue
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
	var fp: int = FrameProf.begin()
	if not _warm_paths.is_empty() and WarmLoader.pending_count() > 0:
		WarmLoader.poll()  # GN-8: collect each finished prewarm load at once
	_physics_step(delta)
	FrameProf.end(&"assault_director", fp)


func _physics_step(delta: float) -> void:
	first_build_hold_s -= delta
	if _start_held and Net.is_authority():
		start_delay_s -= delta  # the setter begins at 0
		return
	if not running or not Net.is_authority() or _runtime == null:
		return
	if _runtime.phase == Enums.HeistPhase.ENDED:
		running = false
		_queue.clear()
		return
	phase_time += delta
	phase_time_left -= delta
	drama = maxf(drama - tweak.drama_decay_per_s * delta, 0.0)
	_tick_captain(delta)
	_tick_bodies(delta)
	match assault_phase:
		Enums.AssaultPhase.CONTROL:
			_tick_control_spawns(delta)
			if phase_time_left <= 0.0:
				_enter(Enums.AssaultPhase.ANTICIPATION, tweak.anticipation_s)
				_maybe_hostage_bonus()
		Enums.AssaultPhase.ANTICIPATION:
			if phase_time_left <= 0.0 and (wave_index > 1 or first_build_hold_s <= 0.0):
				assault_spawned = 0
				_group_left = 0.0  # PO6-16: the first assault group arrives with BUILD (no CONTROL timer carry-over)
				_enter(Enums.AssaultPhase.BUILD, tweak.build_s)
				_roll_captain()
		Enums.AssaultPhase.BUILD:
			_tick_assault_spawns(delta)
			if phase_time_left <= 0.0:
				_sustain_over_t = -1.0
				_low_drama_t = 0.0
				_enter(Enums.AssaultPhase.SUSTAIN, sustain_duration(wave_index, _runtime.crew_members().size()))
		Enums.AssaultPhase.SUSTAIN:
			_tick_sustain(delta)
		Enums.AssaultPhase.FADE:
			_tick_retreat()
			if phase_time_left <= 0.0:
				_end_retreat()
				wave_index += 1
				_enter(Enums.AssaultPhase.CONTROL, tweak.control_between_waves_s)
	_tick_queue(delta)
	events.tick(delta)


func _tick_sustain(delta: float) -> void:
	if phase_time_left > 0.0:
		_tick_assault_spawns(delta)
		return
	if captain_active():
		_tick_assault_spawns(delta)  # L4.9: assault locked while Brandt is on the map
		return
	if _sustain_over_t < 0.0:
		_sustain_over_t = 0.0
	_sustain_over_t += delta
	_low_drama_t = _low_drama_t + delta if drama < tweak.drama_fade_level else 0.0
	var thr: int = tweak.fade_threshold[clampi(_runtime.difficulty, 0, tweak.fade_threshold.size() - 1)] \
		if not tweak.fade_threshold.is_empty() else 0
	if alive_count() < thr or _low_drama_t >= tweak.drama_fade_window_s or _sustain_over_t >= tweak.fade_wait_cap_s:
		_enter_fade()


## L1.1 FADE: stop spawning (queue dropped) and retreat.
func _enter_fade() -> void:
	_queue.clear()
	_enter(Enums.AssaultPhase.FADE, tweak.fade_s)
	_begin_retreat()


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


## A3-02: at BUILD, roll Brandt's arrival for this assault (eligible difficulty, wave, once a day).
func _roll_captain() -> void:
	_captain_due_t = -1.0
	if captain == null or captain.spawned_today or wave_index < tweak.captain_min_wave or not captain.eligible():
		return
	if GameRng.stream(RNG_DIRECTOR).randf() < tweak.captain_chance:
		_captain_due_t = tweak.captain_delay_s


func _tick_captain(delta: float) -> void:
	if _captain_due_t < 0.0:
		return
	if assault_phase != Enums.AssaultPhase.BUILD and assault_phase != Enums.AssaultPhase.SUSTAIN:
		_captain_due_t = -1.0
		return
	_captain_due_t -= delta
	if _captain_due_t > 0.0:
		return
	_captain_due_t = -1.0 if captain.summon() else tweak.no_point_retry_s


# --- Spawning -------------------------------------------------------------------------------------

func _tick_control_spawns(delta: float) -> void:
	if wave_index > 1 and not tweak.control_special_groups.is_empty():
		_control_special_left -= delta  # L1.3: specials between waves (low rate)
		if _control_special_left <= 0.0:
			_control_special_left = tweak.control_special_interval_s
			if _queue_empty() and GameRng.stream(RNG_DIRECTOR).randf() < tweak.control_special_chance:
				_enqueue(_pick_group(Enums.AssaultPhase.CONTROL, tweak.control_special_groups))
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
	var pool: int = _force_pool()
	if pool > 0 and assault_spawned >= pool and _queue_empty() and not captain_active():
		Log.info(&"director", "force pool spent (%d units): FADE" % assault_spawned)
		_enter_fade()  # PD2: task_spawn_allowance <= 0 -> fade (BUILD or SUSTAIN)
		return
	_group_left -= delta
	if _group_left > 0.0 or not _queue_empty():
		return
	var intensity: float = _runtime.difficulty_def.assault_intensity if _runtime.difficulty_def != null else 1.0
	var stage_mult: float = 1.0
	if not tweak.stage_spawn_rate_mult.is_empty():
		stage_mult = tweak.stage_spawn_rate_mult[clampi(stage(), 0, tweak.stage_spawn_rate_mult.size() - 1)]
	var rate: float = maxf(intensity * stage_mult * _drama_spawn_scale(), 0.05)
	var under_cap: bool = alive_count() < police_budget()
	var interval: float = tweak.assault_group_interval_s
	var refill: float = _refill_interval()
	if under_cap and refill > 0.0:
		interval = minf(interval, refill)  # PO6-16: top the force back up
	_group_left = interval / rate
	if under_cap:
		_enqueue_assault()
	elif refill > 0.0:
		# PO6-16: at the cap there is nothing to spawn, so re-check at the refill cadence instead of sleeping a whole
		# (drama-stretched) group interval: kills are topped back up promptly (PD2 force balancing).
		_group_left = refill


## PO6-16 refill cadence x the PO-17 low-difficulty multiplier (0 = refill off).
func _refill_interval() -> float:
	if tweak.assault_refill_interval_s <= 0.0:
		return 0.0
	return tweak.assault_refill_interval_s * DirectorTweak.by_difficulty(tweak.refill_interval_difficulty_mult, _difficulty())


func _difficulty() -> int:
	return _runtime.difficulty if _runtime != null else Enums.Difficulty.ROUTINE


## A BUILD/SUSTAIN pick: the plain weighted squad (as before), plus, with DirectorTweak.assault_special_share[stage],
## the specials of a special-carrying group riding in front of it (PD2: shields / tasers / cloakers / dozers come
## WITH the assault squads). Specials are added, never swapped for the squad, so the force refills at the same rate;
## only specials that can spawn now (L4.11 caps, a free perch) are rolled.
func _enqueue_assault() -> void:
	_enqueue(_pick_group(assault_phase))
	var extra: Array[StringName] = _assault_specials()
	if extra.is_empty():
		return
	var rest: Array[StringName] = _queue.slice(_queue_index)
	_queue = extra
	_queue.append_array(rest)
	_queue_index = 0


## The special units (expanded by count) of one special-carrying assault group, when the stage's share roll hits
## and at least one of its specials can spawn now; else none.
func _assault_specials() -> Array[StringName]:
	var out: Array[StringName] = []
	var shares: PackedFloat32Array = tweak.assault_special_share
	var share: float = shares[clampi(stage(), 0, shares.size() - 1)] if not shares.is_empty() else 0.0
	share *= DirectorTweak.by_difficulty(tweak.special_share_difficulty_mult, _difficulty())  # PO-17
	if share <= 0.0 or GameRng.stream(RNG_DIRECTOR).randf() >= share:
		return out
	var cands: Array[SpawnGroupDef] = []
	for g: SpawnGroupDef in tweak.assault_groups:
		if g != null and _special_can_spawn(g):
			cands.append(g)
	var picked: SpawnGroupDef = _pick_group(assault_phase, cands) if not cands.is_empty() else null
	if picked == null:
		return out
	for id: StringName in picked.expanded_units():
		var def: EnemyDef = _enemy_def(id)
		if def != null and def.is_special:
			out.append(id)
	return out


## `g` carries a special that can spawn now (under its L4.11 cap; a Longshot needs a free SNIPER_PERCH).
func _special_can_spawn(g: SpawnGroupDef) -> bool:
	for id: StringName in g.unit_ids:
		var def: EnemyDef = _enemy_def(id)
		if def == null or not def.is_special or not roster.can_spawn_special(def):
			continue
		if _perch_only(def) and SpecialSpawner.free_perch(_runtime, _centroid(_active_crew()), null) == null:
			continue
		return true
	return false


func _carries_special(g: SpawnGroupDef) -> bool:
	for id: StringName in g.unit_ids:
		var def: EnemyDef = _enemy_def(id)
		if def != null and def.is_special:
			return true
	return false


## L1.2: spawn-rate scale from drama, (1 - drama_spawn_scale * drama).
func _drama_spawn_scale() -> float:
	return clampf(1.0 - tweak.drama_spawn_scale * drama, 0.0, 1.0)


## Weighted pick among `groups` (default tweak.assault_groups) allowed in `phase`, weighted by
## difficulty x stage (L1.3) for the current faction (L1.5); groups with no spawnable unit are skipped.
func _pick_group(phase: int, groups: Array[SpawnGroupDef] = []) -> SpawnGroupDef:
	if groups.is_empty():
		groups = tweak.assault_groups
	var total: float = 0.0
	var cands: Array[SpawnGroupDef] = []
	var ws: Array[float] = []
	var st: int = stage()
	var fac: StringName = faction()
	for g: SpawnGroupDef in groups:
		if g == null or not g.allows_phase(phase):
			continue
		var w: float = g.weight_for(_runtime.difficulty, st, fac)
		if w > 0.0 and _group_spawnable(g):
			cands.append(g)
			ws.append(w)
			total += w
	if cands.is_empty():
		return null
	var r: float = GameRng.stream(RNG_DIRECTOR).randf() * total
	for i: int in range(cands.size()):
		r -= ws[i]
		if r <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


## A group can spawn when at least one of its units has an EnemyDef, is under its special cap and
## (Longshot) has a free SNIPER_PERCH.
func _group_spawnable(g: SpawnGroupDef) -> bool:
	for id: StringName in g.unit_ids:
		var def: EnemyDef = _enemy_def(id)
		if def == null or not roster.can_spawn_special(def):
			continue
		if _perch_only(def) and SpecialSpawner.free_perch(_runtime, _centroid(_active_crew()), null) == null:
			continue
		return true
	return false


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
	if alive_count() >= police_budget():
		_queue.clear()
		return
	_spawn_next()


## Spawn the next queued unit. A3-03: an id without EnemyDef or over its L4.11 cap is skipped;
## L4.7 Longshots go to a free SNIPER_PERCH (SpecialSpawner places and claims it) or nowhere.
func _spawn_next() -> void:
	var id: StringName = _queue[_queue_index]
	var def: EnemyDef = _enemy_def(id)
	if def == null or not roster.can_spawn_special(def):
		_queue_index += 1
	elif _perch_only(def):
		_queue_index += 1
		_unit_left = tweak.unit_spawn_interval_s
		var info: Dictionary = {"assault_wave": wave_index, "faction": faction()}
		for sniper: NpcBase in SpecialSpawner.spawn_special(_runtime, def.id, Transform3D(), info):
			spawned_total += 1
			_count_assault_spawn()
			unit_spawned.emit(sniper, null)
	else:
		var points: Array[Node3D] = valid_spawn_points()
		if points.is_empty():
			_unit_left = tweak.no_point_retry_s
			return
		_unit_left = tweak.unit_spawn_interval_s
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
	return spawn_enemy(def, xf, point)


func _enemy_def(enemy_id: StringName) -> EnemyDef:
	return roster.enemy_def(enemy_id)


func _spawn_role(def: EnemyDef) -> StringName:
	if def != null:
		var r: StringName = StringName(str(def.params.get("spawn_role", "")))
		if r != &"" and HeistRuntime.NPC_SCENES.has(r):
			return r
		var short: StringName = StringName(String(def.id).trim_prefix("enemy."))
		if HeistRuntime.NPC_SCENES.has(short):
			return short
	return &"police"


func _perch_only(def: EnemyDef) -> bool:
	return def.id == LONGSHOT_ID or SpecialSpawner.PERCH_ONLY.has(def.id)



func _count_assault_spawn() -> void:
	if assault_phase == Enums.AssaultPhase.BUILD or assault_phase == Enums.AssaultPhase.SUSTAIN:
		assault_spawned += 1


# --- FADE retreat (L1.1) ------------------------------------------------------------------------

## Order every alive police unit with a PoliceBrain (not Brandt's squad) to its nearest spawn point.
func _begin_retreat() -> void:
	retreating.clear()
	if not tweak.fade_retreat or _runtime == null or _runtime.map == null:
		return
	var points: Array[Node3D] = _retreat_points()
	if points.is_empty():
		return
	var crew: Array[CrewController] = _active_crew()
	for npc: NpcBase in alive_units():
		var brain: PoliceBrain = npc.get_node_or_null(^"Brain") as PoliceBrain
		if brain == null or (captain != null and (npc == captain.brandt or captain.shields.has(npc))):
			continue
		var best: Vector3 = _retreat_point_for(npc, points, crew, Vector3.INF)
		brain.set_order_position(best)
		npc.set_meta(&"retreat_to", best)
		retreating.append(npc)


## PD2: retreating units leave where the crew can't see them. The nearest retreat point out of every crew
## member's sight (else the nearest at all), skipping `avoid` (a point the unit reached but is watched at).
func _retreat_point_for(npc: NpcBase, points: Array[Node3D], crew: Array[CrewController], avoid: Vector3) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_seen: bool = true
	for p: Node3D in points:
		var pos: Vector3 = p.global_position
		if avoid != Vector3.INF and _flat(pos - avoid).length() < 0.5:
			continue
		var seen: bool = _point_seen_by_crew(pos, crew)
		var closer: bool = best == Vector3.INF or pos.distance_to(npc.global_position) < best.distance_to(npc.global_position)
		if (best_seen and not seen) or (seen == best_seen and closer):
			best = pos
			best_seen = seen
	return best if best != Vector3.INF else npc.global_position


## Despawn retreating units that reached their point unseen by the crew.
func _tick_retreat() -> void:
	if retreating.is_empty():
		return
	var crew: Array[CrewController] = _active_crew()
	for i: int in range(retreating.size() - 1, -1, -1):
		var npc: NpcBase = retreating[i]
		if not is_instance_valid(npc) or not npc.alive or not POLICE_ROLES.has(npc.role) \
				or NpcBase.BLIND_STATES.has(npc.alert_state):
			retreating.remove_at(i)
			continue
		var to: Vector3 = npc.get_meta(&"retreat_to", npc.global_position)
		if _flat(to - npc.global_position).length() > tweak.retreat_arrive_m:
			continue
		if _seen_by_crew(npc, crew):
			# Arrived but watched: move on to another point out of sight (if there is one).
			var other: Vector3 = _retreat_point_for(npc, _retreat_points(), crew, to)
			var brain: PoliceBrain = npc.get_node_or_null(^"Brain") as PoliceBrain
			if brain != null and _flat(other - to).length() > 0.5 and not _point_seen_by_crew(other, crew):
				brain.set_order_position(other)
				npc.set_meta(&"retreat_to", other)
			continue
		retreating.remove_at(i)
		npc.get_parent().remove_child(npc)
		npc.queue_free()


## D-099: loud-phase corpse cleanup. Bodies dead for body_despawn_delay_s that no crew member can see are
## removed (like retreating units; the node free replicates as for them).
func _tick_bodies(delta: float) -> void:
	_body_clock += delta
	_body_check_left -= delta
	if tweak.body_despawn_delay_s <= 0.0 or _body_check_left > 0.0:
		return
	_body_check_left = tweak.body_despawn_check_s
	var crew: Array[CrewController] = _active_crew()
	var seen_now: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(G.BODY):
		var npc: NpcBase = n as NpcBase
		if npc == null or npc.alive or not _runtime.is_ancestor_of(npc):
			continue
		seen_now[npc] = true
		if not _body_died_at.has(npc):
			_body_died_at[npc] = _body_clock
			continue
		if _body_clock - _body_died_at[npc] < tweak.body_despawn_delay_s or _seen_by_crew(npc, crew):
			continue
		_body_died_at.erase(npc)
		npc.clear_corpse()
		npc.get_parent().remove_child(npc)
		npc.queue_free()
		bodies_despawned += 1
	for k: Variant in _body_died_at.keys():
		if not is_instance_valid(k) or not seen_now.has(k):
			_body_died_at.erase(k)  # bagged or freed elsewhere


## FADE over: units still on the map fight on.
func _end_retreat() -> void:
	for npc: NpcBase in retreating:
		if is_instance_valid(npc):
			npc.remove_meta(&"retreat_to")
			var brain: PoliceBrain = npc.get_node_or_null(^"Brain") as PoliceBrain
			if brain != null:
				brain.clear_order()
	retreating.clear()


## POLICE_SPAWN / ENTRY points a unit may leave through (breach_only entries excluded).
func _retreat_points() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for g: StringName in [G.POLICE_SPAWN, G.ENTRY_POINT]:
		for n: Node in _runtime.map.get_slots(g):
			var p: Node3D = n as Node3D
			var tags: Variant = p.get(&"tags") if p != null else null
			if p != null and not (tags is Array and (tags as Array).has(BREACH_ONLY_TAG)):
				out.append(p)
	return out


## A standing unit at `pos` would be in some crew member's line of sight.
func _point_seen_by_crew(pos: Vector3, crew: Array[CrewController]) -> bool:
	var space: PhysicsDirectSpaceState3D = _runtime.map.get_world_3d().direct_space_state
	var probe: Vector3 = pos + Vector3(0.0, tweak.los_check_height_m, 0.0)
	for c: CrewController in crew:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c.eye_position(), probe,
			StealthDirector.VISION_MASK)
		q.exclude = [c.get_rid()]
		if space.intersect_ray(q).is_empty():
			return true
	return false


func _seen_by_crew(npc: NpcBase, crew: Array[CrewController]) -> bool:
	var space: PhysicsDirectSpaceState3D = _runtime.map.get_world_3d().direct_space_state
	var probe: Vector3 = npc.global_position + Vector3(0.0, tweak.los_check_height_m, 0.0)
	for c: CrewController in crew:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(c.eye_position(), probe,
			StealthDirector.VISION_MASK)
		q.exclude = [c.get_rid(), npc.get_rid()]
		if space.intersect_ray(q).is_empty():
			return true
	return false


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
	var path: PackedVector3Array = NavPath.query(nav_map, from, to, true, 1 | Door.NAV_LAYER_BREACH)
	if path.size() < 2 or path[path.size() - 1].distance_to(to) > 2.0:
		return straight
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _on_heist_phase_changed(old_phase: int, new_phase: int) -> void:
	if new_phase != Enums.HeistPhase.LOUD:
		return
	if old_phase == Enums.HeistPhase.LOADING:
		begin.call_deferred()  # QC-35: loud at load (LOUD_ONLY): after the mission's start hook may hold it
	else:
		begin()


func _on_hostage_count_changed(count: int) -> void:
	hostages = count
	_maybe_hostage_bonus()


# --- Drama (L1.2) -------------------------------------------------------------------------------

func _on_damage_applied(victim_net_id: int, _attacker: int, info: Dictionary) -> void:
	if not running or not Net.is_authority():
		return
	var amount: float = float(info.get("amount", 0.0))
	if amount > 0.0 and Ids.lookup(victim_net_id) is CrewController:
		add_drama(amount * tweak.drama_per_damage)


func _on_crew_downed(_slot: int, _downs: int) -> void:
	if running and Net.is_authority():
		add_drama(tweak.drama_per_down)


## DET: drama is measured from the shooter's body when it resolves, not the event position: that is the muzzle
## marker of an animated weapon visual (posed per render frame), which would make spawn pacing frame-timing-dependent.
func _on_weapon_fired(shooter: int, _weapon_id: StringName, _suppressed: bool, position: Vector3) -> void:
	if not running or not Net.is_authority():
		return
	var body: Node3D = Ids.lookup(shooter) as Node3D
	if body != null and body.is_inside_tree():
		position = body.global_position
	if _near_crew(position):
		add_drama(tweak.drama_per_nearby_shot)


func _on_npc_killed(npc_net_id: int, _killer: int, _info: Dictionary) -> void:
	if not running or not Net.is_authority():
		return
	var n: Node3D = Ids.lookup(npc_net_id) as Node3D
	if n != null and n.is_inside_tree() and _near_crew(n.global_position):
		add_drama(tweak.drama_per_nearby_kill)


func _near_crew(pos: Vector3) -> bool:
	for c: CrewController in _active_crew():
		if c.global_position.distance_to(pos) <= tweak.drama_combat_radius_m:
			return true
	return false


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
