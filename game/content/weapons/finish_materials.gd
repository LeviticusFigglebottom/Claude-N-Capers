## Builds the runtime materials of weapon finishes (B7-04). Owner: ENV B. Static, cached per finish layer.
##
## Every material is NEW (a StandardMaterial3D, or a duplicate of the layer's library `base_material`), so the
## shared library resources and the imported meshes' materials are never changed. Built materials carry meta
## `finish_id` (FinishApplier uses it to find its own overrides) and are never modified after the build, so
## every WeaponVisual wearing the same finish shares them.
##
## Patterns are procedural (Godot's NoiseTexture2D + FastNoiseLite, seeded from the layer; no texture files):
## * `mottle`  smooth blotches between albedo and pattern colour (case-hardened colour).
## * `camo`    hard-edged two-tone blotches with a mid tone.
## * `patina`  fine speckled patches (verdigris, wear).
## * `engrave` a cellular line network darkened into the metal plus a matching normal map (scrollwork).
## * `brushed` a very flat noise strip stretched along V (directional brush streaks).
class_name FinishMaterials
extends RefCounted

const PATTERNS: Array[StringName] = [&"", &"mottle", &"camo", &"patina", &"engrave", &"brushed"]
const META_FINISH: StringName = &"finish_id"
## Generated pattern texture size (px). Brushed uses a strip PATTERN_SIZE x BRUSHED_HEIGHT.
const PATTERN_SIZE: int = 256
const BRUSHED_HEIGHT: int = 4

## "<finish id>#<layer index>" -> Material
static var _cache: Dictionary = {}


## The material for layer `index` of `def` (cached). Null for a bad index.
static func material_for(def: FinishDef, index: int) -> Material:
	if def == null or index < 0 or index >= def.layers.size() or def.layers[index] == null:
		return null
	var key: String = "%s#%d" % [def.id, index]
	if _cache.has(key):
		return _cache[key]
	var m: BaseMaterial3D = build(def.layers[index])
	m.resource_name = "F_%s_%d" % [String(def.id).trim_prefix("finish."), index]
	m.set_meta(META_FINISH, def.id)
	_cache[key] = m
	return m


## A fresh material for `layer` (not cached, no meta).
static func build(layer: FinishLayer) -> BaseMaterial3D:
	var m: BaseMaterial3D
	if layer.base_material is BaseMaterial3D:
		m = (layer.base_material as BaseMaterial3D).duplicate() as BaseMaterial3D
	else:
		m = StandardMaterial3D.new()
	m.albedo_color = layer.albedo
	m.metallic = layer.metallic
	m.roughness = layer.roughness
	if layer.clearcoat > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = layer.clearcoat
		m.clearcoat_roughness = 0.1
	if layer.pattern != &"":
		_apply_pattern(m, layer)
	return m


## True when `pattern` is a known pattern name (&"" = none).
static func is_pattern(pattern: StringName) -> bool:
	return PATTERNS.has(pattern)


## Drop the cache (tests, hot reload).
static func clear_cache() -> void:
	_cache.clear()


static func _apply_pattern(m: BaseMaterial3D, layer: FinishLayer) -> void:
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.width = PATTERN_SIZE
	tex.height = BRUSHED_HEIGHT if layer.pattern == &"brushed" else PATTERN_SIZE
	tex.seamless = true
	tex.noise = _noise(layer)
	tex.color_ramp = _ramp(layer)
	m.albedo_texture = tex
	m.albedo_color = Color.WHITE  # the ramp carries both colours
	m.uv1_scale = Vector3(layer.pattern_scale, layer.pattern_scale, 1.0)
	if layer.pattern == &"engrave":
		var nrm: NoiseTexture2D = NoiseTexture2D.new()
		nrm.width = PATTERN_SIZE
		nrm.height = PATTERN_SIZE
		nrm.seamless = true
		nrm.as_normal_map = true
		nrm.bump_strength = 6.0
		nrm.noise = tex.noise
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 0.6


static func _noise(layer: FinishLayer) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = layer.pattern_seed
	match layer.pattern:
		&"engrave":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.frequency = 0.035
			n.domain_warp_enabled = true
			n.domain_warp_amplitude = 18.0
		&"camo":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.012
			n.fractal_octaves = 3
		&"patina":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.frequency = 0.03
			n.fractal_octaves = 5
		&"brushed":
			n.noise_type = FastNoiseLite.TYPE_VALUE
			n.frequency = 0.35
			n.fractal_octaves = 2
		_:
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.02
			n.fractal_octaves = 4
	return n


static func _ramp(layer: FinishLayer) -> Gradient:
	var g: Gradient = Gradient.new()
	var a: Color = layer.albedo
	var b: Color = layer.pattern_color
	match layer.pattern:
		&"camo":
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			g.offsets = PackedFloat32Array([0.0, 0.45, 0.62])
			g.colors = PackedColorArray([a, a.lerp(b, 0.5), b])
		&"engrave":
			g.offsets = PackedFloat32Array([0.0, 0.08, 0.2])
			g.colors = PackedColorArray([b, b.lerp(a, 0.6), a])
		&"patina":
			g.offsets = PackedFloat32Array([0.0, 0.55, 0.75])
			g.colors = PackedColorArray([a, a, b])
		_:
			g.offsets = PackedFloat32Array([0.0, 1.0])
			g.colors = PackedColorArray([a, b])
	return g
