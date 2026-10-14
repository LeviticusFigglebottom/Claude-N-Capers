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
## Impact audio cues started per second (rest are dropped; CuePlayer pools 32 3D voices). Also at most
## VfxDirector.MAX_IMPACT_CUES_PER_FRAME (4) per frame, nearest to the camera first.
const IMPACT_CUES_PER_S: float = 24.0

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
## Tests/tools: force CPUParticles3D (true), GPUParticles3D (false) or auto (null = renderer default).
static var force_cpu_particles: Variant = null
## Tests/tools: force Decal nodes (true) or projected quads (false); null = auto (quads on Compatibility).
static var force_decal_nodes: Variant = null

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


static func revision() -> int:
	return _revision


## Restore defaults (tests).
static func reset() -> void:
	effects_quality = 1.0
	reduce_motion = false
	force_cpu_particles = null
	force_decal_nodes = null


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
## survives a hitch longer than its life (< 20 fps). Headless never draws, so it never waits there.
static func frame_drawn_since(drawn_at: int) -> bool:
	return drawn_at < 0 or is_headless() or Engine.get_frames_drawn() > drawn_at
