## Impact effects static API (impact_fx.md 1.0 §1/§3, D-105). Owner: ENV C. Autoload-free.
## - `ImpactFx.surface_of(collider)`: the surface id of a hit collider (§1 lookup rules).
## - `ImpactFx.profile(surface)`: the per-surface particle recipe (layers of debris / dust / sparks).
## - `ImpactFx.build_emitter(layer)`: a one-shot GPUParticles3D (or CPUParticles3D fallback) for a layer.
## - `ImpactFx.cue_id(surface)`: `cue.impact_<surface>`.
## Playback (pools, decals, audio) is VfxDirector's (`vfx_director.gd`); this file holds no state.
class_name ImpactFx
extends RefCounted

const SURFACES: Array[StringName] = [
	&"concrete", &"brick", &"plaster", &"tile", &"wood", &"metal", &"glass", &"fabric", &"dirt", &"water",
	&"flesh", &"armor", &"shield",
]
const DEFAULT_SURFACE: StringName = &"concrete"
## Impact profile used for flesh when the gore option is Off (D-113).
const FLESH_DUST: StringName = &"flesh_dust"
const META_SURFACE: StringName = &"surface"
## Parents walked above the collider for `metadata/surface` (contract: up to 3).
const MAX_PARENT_WALK: int = 3
## Ancestors walked when deciding "this collider belongs to a character" (hitboxes sit under
## <npc>/Hitboxes/<Area>; a crew body is the CharacterBody3D itself).
const MAX_CHARACTER_WALK: int = 4
## Duck-typed seams into ENV A (no hard paths into game/systems): BulwarkShield.GROUP, Hitbox.get_hit_zone().
const SHIELD_GROUP: StringName = &"bulwark_shield"
const HIT_ZONE_METHOD: StringName = &"get_hit_zone"
## Surfaces that get no bullet-hole decal (moving bodies / liquids).
const NO_DECAL: Array[StringName] = [&"water", &"flesh", &"armor", &"shield"]
## Decal size (m) per surface (default 0.09).
const DECAL_SIZE: Dictionary[StringName, float] = {
	&"glass": 0.17, &"tile": 0.11, &"metal": 0.06, &"fabric": 0.06, &"dirt": 0.11, &"wood": 0.09,
}

# Layer kinds.
const SOLID: StringName = &"solid"
const PUFF: StringName = &"puff"
const SPARK: StringName = &"spark"
const GLASS: StringName = &"glass"

const _C_DUST: Color = Color(0.7, 0.68, 0.64, 0.45)

## Recipe per surface: layers {kind, count, life, speed [min,max], spread (deg), gravity (m/s^2 down),
## size [min,max] (m), colors [start, end], mesh (solid: chip|splinter|shard|clod|drop|fiber)}.
static var _profiles: Dictionary[StringName, Array] = {}


## Surface id for a hit collider (impact_fx.md §1):
## 1. `metadata/surface` on the collider or up to 3 parents (first found wins; explicit tags beat 2-3),
## 2. a Bulwark shield (group `bulwark_shield`, or an ancestor in it) -> `shield`,
## 3. a Hitbox (has `get_hit_zone()`): WEAKPOINT (Wrecker faceplate/visor plates) -> `armor`, else `flesh`,
## 4. a character (ancestor in group npc/crew/body, or a CharacterBody3D with `take_hit`) -> `flesh`,
## 5. else `concrete`. Null / freed colliders -> `concrete`.
static func surface_of(collider: Object) -> StringName:
	if collider == null or not is_instance_valid(collider):
		return DEFAULT_SURFACE
	var node: Node = collider as Node
	var tagged: StringName = _tagged_surface(collider)
	if tagged != &"":
		return tagged
	if node == null:
		return DEFAULT_SURFACE
	var n: Node = node
	for i: int in range(MAX_CHARACTER_WALK + 1):
		if n == null:
			break
		if n.is_in_group(SHIELD_GROUP):
			return &"shield"
		if n.has_method(HIT_ZONE_METHOD):
			return &"armor" if int(n.call(HIT_ZONE_METHOD)) == Enums.HitZone.WEAKPOINT else &"flesh"
		if n.is_in_group(G.NPC) or n.is_in_group(G.CREW) or n.is_in_group(G.BODY):
			return &"flesh"
		if n is CharacterBody3D and n.has_method(&"take_hit"):
			return &"flesh"
		n = n.get_parent()
	return DEFAULT_SURFACE


## Explicit `metadata/surface` on the collider or its first 3 parents, &"" if none (or not a known id).
static func _tagged_surface(collider: Object) -> StringName:
	if collider.has_meta(META_SURFACE):
		return _valid(collider.get_meta(META_SURFACE))
	var n: Node = collider as Node
	if n == null:
		return &""
	var p: Node = n.get_parent()
	for i: int in range(MAX_PARENT_WALK):
		if p == null:
			break
		if p.has_meta(META_SURFACE):
			return _valid(p.get_meta(META_SURFACE))
		p = p.get_parent()
	return &""


static func _valid(v: Variant) -> StringName:
	var s: StringName = StringName(str(v))
	return s if s in SURFACES else DEFAULT_SURFACE


static func is_surface(s: StringName) -> bool:
	return s in SURFACES


static func cue_id(surface: StringName) -> StringName:
	return StringName("cue.impact_" + String(surface))


static func has_decal(surface: StringName) -> bool:
	return surface in SURFACES and not surface in NO_DECAL


static func decal_size(surface: StringName) -> float:
	return DECAL_SIZE.get(surface, 0.09)


## Basis whose +Y is `normal` (emitters fire along +Y, decals project along -Y).
static func basis_from_normal(normal: Vector3) -> Basis:
	var y: Vector3 = normal.normalized() if normal.length_squared() > 1e-6 else Vector3.UP
	var ref: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x: Vector3 = ref.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Basis(x, y, z)


## The layered recipe for `surface` (unknown -> concrete).
static func profile(surface: StringName) -> Array:
	if _profiles.is_empty():
		_build_profiles()
	return _profiles.get(surface, _profiles[DEFAULT_SURFACE])


static func _layer(kind: StringName, count: int, life: float, speed: Vector2, spread: float, gravity: float,
		size: Vector2, c0: Color, c1: Color, mesh: StringName = &"chip") -> Dictionary:
	return {"kind": kind, "count": count, "life": life, "speed": speed, "spread": spread, "gravity": gravity,
		"size": size, "c0": c0, "c1": c1, "mesh": mesh}


static func _build_profiles() -> void:
	var dust: Callable = func(c: Color, n: int, life: float, size: float) -> Dictionary:
		return _layer(PUFF, n, life, Vector2(0.4, 1.4), 40.0, -0.3, Vector2(size * 0.5, size * 0.8), c,
			Color(c.r, c.g, c.b, 0.0))
	_profiles[&"concrete"] = [
		_layer(SOLID, 10, 0.9, Vector2(2.0, 5.0), 55.0, 9.8, Vector2(0.012, 0.03), Color(0.6, 0.59, 0.56),
			Color(0.42, 0.41, 0.39)),
		dust.call(_C_DUST, 6, 0.9, 0.32),
	]
	_profiles[&"brick"] = [
		_layer(SOLID, 10, 0.9, Vector2(2.0, 4.5), 55.0, 9.8, Vector2(0.01, 0.025), Color(0.6, 0.3, 0.2),
			Color(0.45, 0.22, 0.15)),
		dust.call(Color(0.66, 0.45, 0.36, 0.5), 5, 0.9, 0.3),
	]
	_profiles[&"plaster"] = [
		_layer(SOLID, 5, 0.7, Vector2(1.5, 3.5), 50.0, 9.8, Vector2(0.006, 0.015), Color(0.93, 0.92, 0.88),
			Color(0.82, 0.8, 0.76)),
		dust.call(Color(0.95, 0.94, 0.9, 0.55), 8, 1.2, 0.38),
	]
	_profiles[&"tile"] = [
		_layer(SOLID, 9, 0.8, Vector2(2.5, 5.5), 60.0, 9.8, Vector2(0.01, 0.025), Color(0.95, 0.96, 0.97),
			Color(0.7, 0.75, 0.78), &"shard"),
		dust.call(Color(0.85, 0.85, 0.85, 0.45), 4, 0.7, 0.25),
	]
	_profiles[&"wood"] = [
		_layer(SOLID, 9, 1.0, Vector2(2.0, 4.5), 50.0, 9.8, Vector2(0.02, 0.05), Color(0.72, 0.52, 0.32),
			Color(0.5, 0.33, 0.18), &"splinter"),
		dust.call(Color(0.6, 0.47, 0.33, 0.45), 4, 0.8, 0.24),
	]
	_profiles[&"metal"] = [
		_layer(SPARK, 16, 0.32, Vector2(3.0, 7.0), 65.0, 7.0, Vector2(0.05, 0.12), Color(1.0, 0.78, 0.4),
			Color(1.0, 0.35, 0.05, 0.0)),
		_layer(PUFF, 3, 0.45, Vector2(0.3, 0.8), 30.0, -0.2, Vector2(0.12, 0.2), Color(0.55, 0.55, 0.55, 0.35),
			Color(0.5, 0.5, 0.5, 0.0)),
	]
	_profiles[&"glass"] = [
		_layer(GLASS, 14, 1.0, Vector2(1.5, 4.5), 70.0, 9.8, Vector2(0.012, 0.035), Color(0.85, 0.95, 1.0, 0.75),
			Color(0.75, 0.9, 1.0, 0.6), &"shard"),
		dust.call(Color(0.92, 0.96, 1.0, 0.3), 3, 0.5, 0.2),
	]
	_profiles[&"fabric"] = [
		_layer(SOLID, 8, 1.6, Vector2(0.6, 1.8), 60.0, 1.2, Vector2(0.008, 0.02), Color(0.75, 0.73, 0.7),
			Color(0.55, 0.53, 0.5), &"fiber"),
		dust.call(Color(0.85, 0.83, 0.8, 0.3), 3, 1.0, 0.16),
	]
	_profiles[&"dirt"] = [
		_layer(SOLID, 10, 0.9, Vector2(1.5, 4.0), 40.0, 9.8, Vector2(0.012, 0.03), Color(0.32, 0.24, 0.16),
			Color(0.22, 0.16, 0.1), &"clod"),
		dust.call(Color(0.45, 0.36, 0.26, 0.55), 6, 1.1, 0.4),
	]
	_profiles[&"water"] = [
		_layer(GLASS, 16, 0.7, Vector2(2.0, 4.5), 25.0, 9.8, Vector2(0.01, 0.025), Color(0.8, 0.9, 1.0, 0.7),
			Color(0.7, 0.85, 1.0, 0.0), &"drop"),
		dust.call(Color(0.85, 0.9, 0.95, 0.22), 3, 0.45, 0.16),
	]
	_profiles[&"flesh"] = [
		# Back-spatter toward the shooter: a short, dark, tight mist (D-113: gritty, not a red glow).
		_layer(PUFF, 5, 0.25, Vector2(0.3, 0.9), 28.0, 2.5, Vector2(0.06, 0.13), Color(0.22, 0.014, 0.011, 0.55),
			Color(0.12, 0.008, 0.006, 0.0)),
		_layer(SOLID, 6, 0.55, Vector2(1.5, 3.5), 40.0, 9.8, Vector2(0.008, 0.016), Color(0.32, 0.02, 0.02),
			Color(0.2, 0.01, 0.01), &"drop"),
	]
	# Gore Off (D-113): flesh hits show a cloth/dust puff and no blood. Not a surface id (never tagged).
	_profiles[FLESH_DUST] = [
		dust.call(Color(0.56, 0.54, 0.5, 0.5), 6, 0.8, 0.26),
		_layer(SOLID, 5, 1.2, Vector2(0.6, 1.6), 55.0, 1.5, Vector2(0.006, 0.014), Color(0.5, 0.48, 0.45),
			Color(0.4, 0.38, 0.36), &"fiber"),
	]
	var armor_sparks: Array = [
		_layer(SPARK, 12, 0.25, Vector2(4.0, 8.0), 60.0, 6.0, Vector2(0.04, 0.1), Color(1.0, 0.88, 0.6),
			Color(1.0, 0.45, 0.1, 0.0)),
		_layer(PUFF, 2, 0.35, Vector2(0.3, 0.7), 30.0, -0.2, Vector2(0.1, 0.16), Color(0.6, 0.6, 0.62, 0.3),
			Color(0.6, 0.6, 0.62, 0.0)),
	]
	_profiles[&"armor"] = armor_sparks
	_profiles[&"shield"] = armor_sparks.duplicate()


## Mesh for a layer.
static func layer_mesh(layer: Dictionary) -> Mesh:
	var kind: StringName = layer["kind"]
	if kind == PUFF:
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		q.material = VfxTextures.puff_material()
		return q
	if kind == SPARK:
		var b: BoxMesh = BoxMesh.new()
		b.size = Vector3(0.12, 1.0, 0.12)  # scaled by particle scale (0.05..0.12 m long, thin)
		b.material = VfxTextures.glow_material()
		return b
	var mesh_kind: StringName = layer["mesh"]
	var box: BoxMesh = BoxMesh.new()
	match mesh_kind:
		&"splinter":
			box.size = Vector3(0.2, 1.0, 0.2)
		&"shard":
			box.size = Vector3(1.0, 0.15, 0.7)
		&"fiber":
			box.size = Vector3(0.15, 1.0, 0.15)
		&"drop":
			var s: SphereMesh = SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 6
			s.rings = 3
			s.material = VfxTextures.glass_material() if kind == GLASS else VfxTextures.debris_material()
			return s
		_:
			box.size = Vector3(1.0, 0.7, 0.85)
	box.material = VfxTextures.glass_material() if kind == GLASS else VfxTextures.debris_material()
	return box


## One-shot burst emitter for a layer (emits along local +Y). `count` already quality-scaled.
## GPUParticles3D by default; CPUParticles3D when VfxSettings.use_cpu_particles().
static func build_emitter(layer: Dictionary, count: int) -> GeometryInstance3D:
	var pm: ParticleProcessMaterial = process_material(layer)
	var gpu: GPUParticles3D = GPUParticles3D.new()
	gpu.amount = maxi(1, count)
	gpu.one_shot = true
	gpu.explosiveness = 1.0
	gpu.emitting = false
	gpu.lifetime = float(layer["life"])
	gpu.local_coords = false
	gpu.process_material = pm
	gpu.draw_pass_1 = layer_mesh(layer)
	gpu.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	gpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if layer["kind"] == SPARK:
		gpu.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	if not VfxSettings.use_cpu_particles():
		return gpu
	var cpu: CPUParticles3D = CPUParticles3D.new()
	cpu.convert_from_particles(gpu)
	cpu.one_shot = true
	cpu.emitting = false
	cpu.local_coords = false
	cpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpu.free()
	return cpu


## Re-fire a one-shot burst emitter (GPU or CPU particles; anything else is ignored).
static func restart_emitter(e: GeometryInstance3D) -> void:
	if e is GPUParticles3D:
		(e as GPUParticles3D).restart()
	elif e is CPUParticles3D:
		(e as CPUParticles3D).restart()


static func process_material(layer: Dictionary) -> ParticleProcessMaterial:
	var kind: StringName = layer["kind"]
	var speed: Vector2 = layer["speed"]
	var size: Vector2 = layer["size"]
	var ms: float = VfxSettings.motion_scale()
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = float(layer["spread"])
	pm.initial_velocity_min = speed.x * ms
	pm.initial_velocity_max = speed.y * ms
	pm.gravity = Vector3(0.0, -float(layer["gravity"]), 0.0)
	pm.scale_min = size.x
	pm.scale_max = size.y
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.015
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, layer["c0"])
	ramp.set_color(1, layer["c1"])
	var rt: GradientTexture1D = GradientTexture1D.new()
	rt.gradient = ramp
	rt.width = 32
	pm.color_ramp = rt
	if kind == PUFF:
		pm.damping_min = 2.0
		pm.damping_max = 4.0
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		var grow: Curve = Curve.new()
		grow.add_point(Vector2(0.0, 0.35))
		grow.add_point(Vector2(1.0, 1.0))
		var gt: CurveTexture = CurveTexture.new()
		gt.curve = grow
		pm.scale_curve = gt
	elif kind == SPARK:
		pm.particle_flag_align_y = true
		pm.damping_min = 1.0
		pm.damping_max = 3.0
	else:
		pm.angular_velocity_min = -720.0
		pm.angular_velocity_max = 720.0
		pm.particle_flag_rotate_y = true
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		var fade: Curve = Curve.new()
		fade.add_point(Vector2(0.0, 1.0))
		fade.add_point(Vector2(0.75, 1.0))
		fade.add_point(Vector2(1.0, 0.0))
		var ft: CurveTexture = CurveTexture.new()
		ft.curve = fade
		pm.scale_curve = ft
	return pm
