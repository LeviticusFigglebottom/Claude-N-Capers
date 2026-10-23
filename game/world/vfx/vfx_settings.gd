## Combat VFX budget and settings hook (impact_fx.md 1.0 §3, D-105). Owner: ENV C.
## Source of truth in game: ENV B's GameSettings (video/effects_quality, accessibility/reduce_motion);
## VfxDirector calls `sync_from_game_settings()` at start and on GameSettings.changed, which maps
## `GameSettings.EFFECTS_SCALE[effects_quality()]` (0.3 / 0.6 / 1.0) here. Tests/tools may set
##   VfxSettings.set_quality(VfxSettings.Quality.MEDIUM)  /  VfxSettings.effects_quality = 0.5
## directly (with VfxDirector.use_game_settings = false). VfxDirector polls `revision()` and re-applies
## (pool sizes, particle counts) when it changes.
## All pool caps live here; every cap is the HIGH (1.0) value and scales down with quality.
class_name VfxSettings
extends RefCounted

enum Quality { LOW, MEDIUM, HIGH }

## Quality level -> effects_quality scale (same values as GameSettings.EFFECTS_SCALE).
const QUALITY_SCALE: Array[float] = GameSettings.EFFECTS_SCALE

## --- Pool caps (HIGH). A cap is a hard upper bound on live nodes / instances of that kind. ---
## Bullet-hole decals per map (contract: 128). Oldest recycled when full.
const DECAL_CAP: int = 128
## Seconds a decal stays at full strength, then fades over DECAL_FADE_S and its slot frees.
const DECAL_HOLD_S: float = 60.0
const DECAL_FADE_S: float = 2.0
## Impact emitter sets per surface (round-robin; a re-fired set restarts its burst).
const IMPACT_SETS_PER_SURFACE: int = 6
## Impact emitter sets over all surfaces (lazily created per surface, never above this).
const IMPACT_SETS_TOTAL: int = 48
## Tracer streaks alive at once (one MultiMesh, one draw call).
const TRACER_CAP: int = 48
## Muzzle flash sets (flash mesh + smoke puff).
const MUZZLE_CAP: int = 16
## Muzzle/explosion OmniLights alive at once (each lives 0.05 s / 0.2 s; further flashes skip the light).
const LIGHT_CAP: int = 4
## Ejected casings alive at once (one MultiMesh, one draw call).
const SHELL_CAP: int = 64
## Explosion sets (flash, fireball, smoke, debris ring).
const EXPLOSION_CAP: int = 4
## Smoke clouds alive at once (D-163, Sicario's smoke bomb; oldest reused).
const SMOKE_CAP: int = 3
## Tag Team gas tethers (D-163; 4 crew -> at most 4 pairs).
const TETHER_CAP: int = 4
## Impact audio cues started per second (rest are dropped; CuePlayer pools 32 3D voices). Also at most
## VfxDirector.MAX_IMPACT_CUES_PER_FRAME (4) per frame, nearest to the camera first.
const IMPACT_CUES_PER_S: float = 24.0

## --- Blood (D-113). Every cap is the HIGH value (quality-scaled). Gore Reduced: no pools / drips, fainter. ---
## Blood spray sets (mist + droplets) alive at once, round-robin.
const BLOOD_SPRAY_CAP: int = 12
## Splatter / drip / smear decals (own pool: blood never evicts bullet holes). Oldest recycled.
const BLOOD_DECAL_CAP: int = 64
const MIN_BLOOD_DECALS: int = 16
## Growing pools under bodies (own pool). Oldest recycled.
const BLOOD_POOL_CAP: int = 10
## Splatter ray from the hit (or exit) point along the shot, world layers only (no characters).
const BLOOD_SPLATTER_RANGE_M: float = 2.5
const BLOOD_DRIP_RANGE_M: float = 3.0
## world_static | world_dynamic (project.godot physics layers 1-2).
const BLOOD_WORLD_MASK: int = 1 | 2
const BLOOD_HOLD_S: float = 90.0
const BLOOD_FADE_S: float = 6.0
## A pool grows over POOL_GROW_S (at bleed rate 1; slower at lower rates) up to POOL_MAX_M across.
const POOL_GROW_S: float = 8.0
const POOL_MAX_M: float = 1.5
const POOL_HOLD_S: float = 240.0
const POOL_FADE_S: float = 12.0

## --- Gore option (ENV B: gameplay/gore, GameSettings.current().gore() -> &"full" / &"reduced" / &"off"). ---
const GORE_FULL: StringName = &"full"
const GORE_REDUCED: StringName = &"reduced"
const GORE_OFF: StringName = &"off"
## The single seam into GameSettings for the gore option (method name; read defensively, default Full).
const GORE_METHOD: StringName = &"gore"

## Pools never drop below these at LOW.
const MIN_DECALS: int = 32
const MIN_SETS: int = 2

## Effects quality scale, 0..1 (1 = HIGH). Scales caps and particle counts.
static var effects_quality: float = 1.0:
	set(v):
		var c: float = clampf(v, 0.0, 1.0)
		if c != effects_quality:
			effects_quality = c
			_revision += 1
## Reduce Motion: halves debris counts and speeds, drops the explosion debris ring and long smoke
## drift, dims flash lights. Tracers stay (they are gameplay-readable).
static var reduce_motion: bool = false:
	set(v):
		if v != reduce_motion:
			reduce_motion = v
			_revision += 1
## Gore level (GORE_FULL / GORE_REDUCED / GORE_OFF), mirrored from GameSettings by sync_from_game_settings().
static var gore: StringName = GORE_FULL:
	set(v):
		var g: StringName = v if v in [GORE_FULL, GORE_REDUCED, GORE_OFF] else GORE_FULL
		if g != gore:
			gore = g
			_revision += 1
## Tests/tools: force CPUParticles3D (true), GPUParticles3D (false) or auto (null = renderer default).
static var force_cpu_particles: Variant = null
## Tests/tools: force Decal nodes (true) or projected quads (false); null = auto (quads on Compatibility).
static var force_decal_nodes: Variant = null
## Tests: >= 0 replaces Engine.get_frames_drawn() in frame_drawn_since / frames_drawn and lifts the headless shortcut, so
## a headless test can hold a frame undrawn (the hitch case). -1 = off.
static var test_frames: int = -1

static var _revision: int = 0


static func set_quality(level: Quality) -> void:
	effects_quality = QUALITY_SCALE[clampi(int(level), 0, QUALITY_SCALE.size() - 1)]


## Pull effects quality / reduce motion from ENV B's GameSettings.current().
static func sync_from_game_settings(s: GameSettings = null) -> void:
	var gs: GameSettings = s if s != null else GameSettings.current()
	if gs == null:
		return
	var level: int = clampi(gs.effects_quality(), 0, GameSettings.EFFECTS_SCALE.size() - 1)
	effects_quality = GameSettings.EFFECTS_SCALE[level]
	reduce_motion = bool(gs.get_value(GameSettings.ACCESSIBILITY, &"reduce_motion"))
	gore = gore_from(gs)


## Gore level of a settings object: `gore()` when it has one (ENV B), else Full. Unknown values -> Full.
static func gore_from(gs: Object) -> StringName:
	if gs == null or not gs.has_method(GORE_METHOD):
		return GORE_FULL
	var g: StringName = StringName(str(gs.call(GORE_METHOD)))
	return g if g in [GORE_FULL, GORE_REDUCED, GORE_OFF] else GORE_FULL


static func blood_enabled() -> bool:
	return gore != GORE_OFF


## Pools, drips and smears: Full only.
static func blood_pools_enabled() -> bool:
	return gore == GORE_FULL


## Spray / splatter size multiplier for the gore level.
static func blood_scale() -> float:
	return 1.0 if gore == GORE_FULL else 0.6


static func revision() -> int:
	return _revision


## Restore defaults (tests).
static func reset() -> void:
	effects_quality = 1.0
	reduce_motion = false
	gore = GORE_FULL
	force_cpu_particles = null
	force_decal_nodes = null
	test_frames = -1


## A cap scaled by quality, never below `min_value`.
static func scaled_cap(cap: int, min_value: int = MIN_SETS) -> int:
	return clampi(roundi(float(cap) * effects_quality), mini(min_value, cap), cap)


## Particle count for a burst of `base` particles at the current quality / reduce-motion.
static func scaled_count(base: int) -> int:
	var k: float = effects_quality * (0.5 if reduce_motion else 1.0)
	return maxi(1, roundi(float(base) * maxf(k, 0.15)))


static func motion_scale() -> float:
	return 0.6 if reduce_motion else 1.0


static func decal_cap() -> int:
	return scaled_cap(DECAL_CAP, MIN_DECALS)


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Compatibility (OpenGL 3) renderer: GPU particles work there, but Decal nodes do not render.
static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


static func use_cpu_particles() -> bool:
	if force_cpu_particles != null:
		return bool(force_cpu_particles)
	return false


static func use_decal_nodes() -> bool:
	if force_decal_nodes != null:
		return bool(force_decal_nodes)
	return not is_compatibility()


## True once at least one frame has been drawn since `drawn_at` (Engine.get_frames_drawn()), so a short flash
## survives a hitch longer than its life (< 20 fps). Headless never draws, so it never waits there; nor with the render
## loop off (harness fast mode): nothing is drawn until it is back on, so every flash fired meanwhile stayed up and the
## next screenshot showed them frozen in the air where the shooters had been (ENV A, PO "frozen muzzle flashes").
static func frame_drawn_since(drawn_at: int) -> bool:
	if test_frames >= 0:
		return drawn_at < 0 or test_frames > drawn_at
	return drawn_at < 0 or is_headless() or not RenderingServer.render_loop_enabled \
		or Engine.get_frames_drawn() > drawn_at


## Frames drawn so far (Engine.get_frames_drawn(), or `test_frames` when a test sets it).
static func frames_drawn() -> int:
	return test_frames if test_frames >= 0 else Engine.get_frames_drawn()
