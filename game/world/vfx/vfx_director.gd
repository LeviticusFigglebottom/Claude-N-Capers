## Combat VFX director (impact_fx.md 1.0 §3, D-105). Owner: ENV C. Presentation only, every peer.
## Instance `res://world/vfx/vfx_director.tscn` once per heist scene (or `VfxDirector.new()`); it listens
## to `EventBus.shot_fx` / `EventBus.explosion_fx` and drives the pooled effect layers:
##   Impacts (per-surface debris bursts), Decals (bullet holes / scorch, cap 128, 60 s), Tracers,
##   Muzzles (third-person flash + smoke), Lights (0.05 s flash lights, layer 1 + 21), Shells, Explosions.
## The same entry points are public (`on_shot_fx`, `on_explosion_fx`) for tests and tools.
## Caps / quality: VfxSettings, synced from ENV B's GameSettings (effects_quality, reduce_motion).
## Per-shot rules (flags: bit0 suppressed, bit1 first-person shooter on this peer, bit2 headshot):
## - a "pellet group" = consecutive shot_fx from one shooter, same weapon class and origin within one
##   frame: one muzzle flash / casing / light per group, tracer on 1 in N pellets (TracerFx.EVERY_NTH);
## - first-person (bit1): no muzzle, casing or tracer (ENV P draws them at the viewmodel), impacts yes;
## - suppressed (bit0): small puff instead of flash, no light, no tracer;
## - miss (`surface` &"" or `normal` ZERO): tracer only; melee: debris + cue, no decal/tracer/muzzle.
class_name VfxDirector
extends Node3D

const FLAG_SUPPRESSED: int = 1
const FLAG_FIRST_PERSON: int = 2
const FLAG_HEADSHOT: int = 4
const MELEE: StringName = &"melee"
## Same pellet group when the next ray starts within this distance (m) in the same frame.
const GROUP_ORIGIN_EPS_M: float = 0.05
const EXPLOSION_LIGHT_COLOR: Color = Color(1.0, 0.6, 0.3)
const EXPLOSION_LIGHT_S: float = 0.2
## Minimum seconds between two impact cues of the same surface.
const CUE_SURFACE_GAP_S: float = 0.04
## Impact cues started per frame at most (CuePlayer shares 32 3D voices); nearest to the camera first.
const MAX_IMPACT_CUES_PER_FRAME: int = 4

## Listen to EventBus.shot_fx / explosion_fx (off for tools/tests that call the entry points).
@export var listen_to_event_bus: bool = true
## Advance effects in _process (off for tests that call advance(delta) themselves).
@export var auto_advance: bool = true
## Also draw tracers for first-person shots (ENV P draws its own by default, impact_fx.md §2).
@export var draw_fp_tracers: bool = false
## Read effects quality / reduce motion from GameSettings.current() (off in tests that set VfxSettings).
@export var use_game_settings: bool = true
## Request `cue.impact_<surface>` through EventBus.audio_cue_requested when the cue exists.
@export var play_impact_cues: bool = true

## Counters (tests/bench).
var shots: int = 0
var cues_requested: int = 0

var impacts: VfxImpacts
var decals: VfxDecals
var tracers: TracerFx
var muzzles: MuzzleFx
var lights: VfxLights
var shells: ShellFx
var explosions: ExplosionFx

var _rev: int = -1
var _tick: int = 0
## shooter key -> [tick, origin, weapon_class, pellet index]
var _groups: Dictionary[int, Array] = {}
## shooter key -> shots counted for tracer cadence
var _cadence: Dictionary[int, int] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time_s: float = 0.0
var _cue_tokens: float = VfxSettings.IMPACT_CUES_PER_S
var _cue_last: Dictionary[StringName, float] = {}
var _cue_known: Dictionary[StringName, bool] = {}
## Impacts of this frame waiting for a cue: [surface, position]; flushed in advance().
var _cue_pending: Array[Array] = []


func _init() -> void:
	_rng.seed = 0xF0C5  # presentation-only variation (decal spin)
	impacts = VfxImpacts.new()
	decals = VfxDecals.new()
	tracers = TracerFx.new()
	tracers.auto_advance = false
	muzzles = MuzzleFx.new()
	lights = VfxLights.new()
	shells = ShellFx.new()
	explosions = ExplosionFx.new()
	for n: Node in [impacts, decals, tracers, muzzles, lights, shells, explosions]:
		add_child(n)
	apply_settings()


func _ready() -> void:
	if use_game_settings:
		var gs: GameSettings = GameSettings.current()
		VfxSettings.sync_from_game_settings(gs)
		if gs != null and not gs.changed.is_connected(_on_game_settings_changed):
			gs.changed.connect(_on_game_settings_changed)
	if listen_to_event_bus:
		if not EventBus.shot_fx.is_connected(on_shot_fx):
			EventBus.shot_fx.connect(on_shot_fx)
		if not EventBus.explosion_fx.is_connected(on_explosion_fx):
			EventBus.explosion_fx.connect(on_explosion_fx)


func _exit_tree() -> void:
	if use_game_settings:
		var gs: GameSettings = GameSettings.current()
		if gs != null and gs.changed.is_connected(_on_game_settings_changed):
			gs.changed.disconnect(_on_game_settings_changed)
	if EventBus.shot_fx.is_connected(on_shot_fx):
		EventBus.shot_fx.disconnect(on_shot_fx)
	if EventBus.explosion_fx.is_connected(on_explosion_fx):
		EventBus.explosion_fx.disconnect(on_explosion_fx)


func _on_game_settings_changed(_section: StringName, _key: StringName) -> void:
	VfxSettings.sync_from_game_settings()


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


## Re-read VfxSettings (quality / reduce motion): resizes every pool to its scaled cap.
func apply_settings() -> void:
	_rev = VfxSettings.revision()
	var per_surface: int = VfxSettings.scaled_cap(VfxSettings.IMPACT_SETS_PER_SURFACE)
	impacts.set_caps(per_surface, VfxSettings.scaled_cap(VfxSettings.IMPACT_SETS_TOTAL, per_surface))
	decals.set_cap(VfxSettings.decal_cap())
	tracers.set_cap(VfxSettings.scaled_cap(VfxSettings.TRACER_CAP, 8))
	muzzles.set_cap(VfxSettings.scaled_cap(VfxSettings.MUZZLE_CAP, 4))
	lights.set_cap(VfxSettings.scaled_cap(VfxSettings.LIGHT_CAP, 2))
	shells.set_cap(VfxSettings.scaled_cap(VfxSettings.SHELL_CAP, 16))
	explosions.set_cap(VfxSettings.scaled_cap(VfxSettings.EXPLOSION_CAP, 2))


## Step every effect by `delta` seconds (called from _process when auto_advance).
func advance(delta: float) -> void:
	if _rev != VfxSettings.revision():
		apply_settings()
	_tick += 1
	_time_s += delta
	_cue_tokens = minf(_cue_tokens + delta * VfxSettings.IMPACT_CUES_PER_S, VfxSettings.IMPACT_CUES_PER_S)
	_flush_cues()
	impacts.advance(delta)
	decals.advance(delta)
	tracers.advance(delta)
	muzzles.advance(delta)
	lights.advance(delta)
	shells.advance(delta)
	explosions.advance(delta)


## EventBus.shot_fx handler (events.md 1.2).
func on_shot_fx(origin: Vector3, end: Vector3, normal: Vector3, surface: StringName, weapon_class: StringName,
		shooter_net_id: int, flags: int) -> void:
	shots += 1
	var fp: bool = flags & FLAG_FIRST_PERSON != 0
	var suppressed: bool = flags & FLAG_SUPPRESSED != 0
	var melee: bool = weapon_class == MELEE
	var dir: Vector3 = end - origin
	var pellet: int = _pellet_index(origin, weapon_class, shooter_net_id)
	if not melee:
		if pellet == 0 and not fp:
			muzzles.fire(origin, dir, weapon_class, suppressed)
			if not suppressed:
				lights.flash(origin + dir.normalized() * 0.1, MuzzleFx.LIGHT_COLOR, MuzzleFx.LIGHT_ENERGY,
					MuzzleFx.LIGHT_RANGE_M, MuzzleFx.LIGHT_S)
			shells.eject(weapon_class, origin, dir)
		if not suppressed and (not fp or draw_fp_tracers) and _tracer_due(weapon_class, shooter_net_id, pellet):
			tracers.spawn(origin, end)
	if surface == &"" or normal == Vector3.ZERO:
		return
	var s: StringName = surface if ImpactFx.is_surface(surface) else ImpactFx.DEFAULT_SURFACE
	var k: float = 1.0
	if flags & FLAG_HEADSHOT != 0 and s == &"flesh":
		k = 1.5
	elif melee:
		k = 0.6
	impacts.fire(s, end, normal, k)
	if not melee and ImpactFx.has_decal(s):
		decals.place(s, end, normal, ImpactFx.decal_size(s) * _rng.randf_range(0.85, 1.15),
			VfxSettings.DECAL_HOLD_S, _rng.randf_range(-PI, PI))
	_impact_cue(s, end)


## EventBus.explosion_fx handler (events.md 1.2).
func on_explosion_fx(pos: Vector3, radius: float, kind: StringName) -> void:
	explosions.fire(pos, radius, kind)
	var soft: bool = kind in ExplosionFx.SOFT_KINDS
	lights.flash(pos + Vector3.UP * 0.5, Color(1, 1, 1) if soft else EXPLOSION_LIGHT_COLOR, 8.0,
		maxf(radius * 2.5, 6.0), EXPLOSION_LIGHT_S)
	if soft:
		return
	var ground: Array = _ground_below(pos)
	decals.place(&"scorch", ground[0], ground[1], clampf(radius * 0.8, 1.0, 5.0), VfxSettings.DECAL_HOLD_S,
		_rng.randf_range(-PI, PI))


## Remove every live effect (map reset).
func clear() -> void:
	decals.clear()
	tracers.clear()
	muzzles.clear()
	lights.clear()
	shells.clear()
	explosions.clear()
	_groups.clear()
	_cadence.clear()
	_cue_pending.clear()


## Live counts vs caps (tests, perf probes).
func stats() -> Dictionary:
	return {
		"decals": decals.live, "decal_slots": decals.slot_count(), "decal_cap": decals.cap(),
		"tracers": tracers.live, "tracer_cap": tracers.cap(),
		"muzzle_sets": muzzles.set_count(), "muzzle_cap": muzzles.cap(),
		"lights": lights.light_count(), "lights_live": lights.live(),
		"shells": shells.live, "shell_cap": shells.cap(),
		"impact_sets": impacts.set_count(), "impact_caps": impacts.caps(),
		"explosion_sets": explosions.set_count(), "explosion_cap": explosions.cap(),
	}


## Index of this ray within its pellet group (0 = a new shot).
func _pellet_index(origin: Vector3, weapon_class: StringName, shooter_net_id: int) -> int:
	var key: int = shooter_net_id if shooter_net_id != 0 else hash(origin.snapped(Vector3.ONE * 0.1))
	var g: Array = _groups.get(key, [])
	if not g.is_empty() and int(g[0]) == _tick and StringName(g[2]) == weapon_class \
			and (g[1] as Vector3).distance_to(origin) <= GROUP_ORIGIN_EPS_M:
		g[3] = int(g[3]) + 1
		return int(g[3])
	if _groups.size() > 256:
		_groups.clear()
	_groups[key] = [_tick, origin, weapon_class, 0]
	return 0


## Tracer cadence: 1 in N shots per shooter+class; shotguns 1 in N pellets of each group (first included).
func _tracer_due(weapon_class: StringName, shooter_net_id: int, pellet: int) -> bool:
	var n: int = TracerFx.every_nth(weapon_class)
	if n <= 0:
		return false
	if n == 1:
		return true
	if weapon_class == &"shotgun":
		return pellet % n == 0
	var key: int = hash([shooter_net_id, weapon_class])
	var c: int = int(_cadence.get(key, 0))
	if _cadence.size() > 256:
		_cadence.clear()
	_cadence[key] = c + 1
	return c % n == 0


func _impact_cue(surface: StringName, pos: Vector3) -> void:
	if not play_impact_cues:
		return
	var id: StringName = ImpactFx.cue_id(surface)
	if not _cue_known.has(id):
		var reg: AudioCueRegistry = AudioCueLib.registry()
		_cue_known[id] = reg != null and reg.has_cue(id)
	if _cue_known[id] and _cue_pending.size() < 64:
		_cue_pending.append([surface, pos])


## Start this frame's impact cues: nearest to the active camera first, at most MAX_IMPACT_CUES_PER_FRAME,
## one per surface per CUE_SURFACE_GAP_S, within the IMPACT_CUES_PER_S token bucket.
func _flush_cues() -> void:
	if _cue_pending.is_empty():
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and _cue_pending.size() > 1:
		var eye: Vector3 = cam.global_position
		_cue_pending.sort_custom(func(a: Array, b: Array) -> bool:
			return eye.distance_squared_to(a[1]) < eye.distance_squared_to(b[1]))
	var started: int = 0
	for c: Array in _cue_pending:
		if started >= MAX_IMPACT_CUES_PER_FRAME or _cue_tokens < 1.0:
			break
		var surface: StringName = c[0]
		if _time_s - float(_cue_last.get(surface, -1.0)) < CUE_SURFACE_GAP_S:
			continue
		_cue_tokens -= 1.0
		_cue_last[surface] = _time_s
		started += 1
		cues_requested += 1
		EventBus.audio_cue_requested.emit(ImpactFx.cue_id(surface), c[1], 0)
	_cue_pending.clear()


## [point, normal] of the floor under `pos` (one ray, world_static), else [pos, UP].
func _ground_below(pos: Vector3) -> Array:
	if is_inside_tree():
		var w: World3D = get_world_3d()
		if w != null and w.direct_space_state != null:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3,
				pos + Vector3.DOWN * 3.0, ShellFx.FLOOR_MASK)
			var hit: Dictionary = w.direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				return [hit["position"], hit["normal"]]
	return [pos, Vector3.UP]
