## Procedural VFX textures and materials (impact_fx.md §3; style_guide §8). Owner: ENV C.
## Everything is generated in code from fixed seeds (no assets): soft puffs, the flash star, bullet holes
## per surface, the scorch mark. Built once per process and cached (static); deterministic.
class_name VfxTextures
extends RefCounted

const PUFF_SIZE: int = 64
const HOLE_SIZE: int = 64
const FLASH_SIZE: int = 64
const SCORCH_SIZE: int = 128
## Bullet-hole looks: [core colour, ring colour, ring radius (0..1), crack count, roughness of the edge].
const HOLE_LOOKS: Dictionary[StringName, Array] = {
	&"concrete": [Color(0.08, 0.08, 0.08), Color(0.62, 0.61, 0.58), 0.62, 0, 0.35],
	&"brick": [Color(0.09, 0.06, 0.05), Color(0.62, 0.36, 0.26), 0.66, 0, 0.4],
	&"plaster": [Color(0.12, 0.11, 0.1), Color(0.9, 0.88, 0.84), 0.7, 0, 0.3],
	&"tile": [Color(0.07, 0.07, 0.08), Color(0.92, 0.93, 0.94), 0.5, 7, 0.15],
	&"wood": [Color(0.07, 0.04, 0.02), Color(0.66, 0.48, 0.3), 0.55, 0, 0.5],
	&"metal": [Color(0.05, 0.05, 0.06), Color(0.78, 0.8, 0.82), 0.45, 0, 0.08],
	&"glass": [Color(0.15, 0.17, 0.18), Color(0.95, 0.97, 1.0), 0.35, 11, 0.1],
	&"fabric": [Color(0.04, 0.04, 0.04), Color(0.3, 0.3, 0.3), 0.5, 0, 0.6],
	&"dirt": [Color(0.06, 0.04, 0.03), Color(0.28, 0.2, 0.13), 0.8, 0, 0.5],
}

static var _cache: Dictionary[StringName, Resource] = {}


static func clear_cache() -> void:
	_cache.clear()


## Soft round puff (white, alpha falls off with a little noise), for dust, smoke, mist, splash.
static func puff() -> Texture2D:
	return _cached(&"puff", func() -> Resource: return _make_puff(0xD057))


## Flash star (white core with 6 soft spikes) for muzzle and explosion flashes.
static func flash() -> Texture2D:
	return _cached(&"flash", func() -> Resource: return _make_flash())


## Bullet hole albedo+alpha for `surface` (null for surfaces without a decal).
static func hole(surface: StringName) -> Texture2D:
	if not HOLE_LOOKS.has(surface):
		return null
	return _cached(StringName("hole_" + String(surface)), func() -> Resource: return _make_hole(surface))


static func scorch() -> Texture2D:
	return _cached(&"scorch", func() -> Resource: return _make_scorch())


## Unshaded additive billboard material (flash, sparks glow, fireball), colour from the particle/vertex.
static func additive_material(tex: Texture2D, billboard: bool = true) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


## Alpha-blended lit-ish billboard (dust, smoke, blood mist): unshaded so it reads at night, colour
## from the particle colour ramp.
static func puff_material() -> StandardMaterial3D:
	return _cached(&"mat_puff", func() -> Resource:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = puff()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m) as StandardMaterial3D


## Lit solid debris (chips, splinters, clods, casings), colour from the particle / instance colour.
static func debris_material() -> StandardMaterial3D:
	return _cached(&"mat_debris", func() -> Resource:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		return m) as StandardMaterial3D


## Glass shards: transparent, glossy.
static func glass_material() -> StandardMaterial3D:
	return _cached(&"mat_glass", func() -> Resource:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic_specular = 1.0
		m.rim_enabled = true
		m.rim = 0.6
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m) as StandardMaterial3D


## Emissive unshaded streak (sparks, tracers).
static func glow_material() -> StandardMaterial3D:
	return _cached(&"mat_glow", func() -> Resource:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		return m) as StandardMaterial3D


static func casing_material() -> StandardMaterial3D:
	return _cached(&"mat_casing", func() -> Resource:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.85
		m.roughness = 0.3
		return m) as StandardMaterial3D


static func _cached(key: StringName, make: Callable) -> Resource:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


static func _tex(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _make_puff(seed_value: int) -> ImageTexture:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var n: int = PUFF_SIZE
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	for y: int in range(n):
		for x: int in range(n):
			var d: float = Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			a *= 0.75 + 0.25 * noise.get_noise_2d(x, y)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return _tex(img)


static func _make_flash() -> ImageTexture:
	var n: int = FLASH_SIZE
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in range(n):
		for x: int in range(n):
			var v: Vector2 = Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var d: float = v.length()
			var ang: float = v.angle()
			var spikes: float = pow(absf(cos(ang * 2.0 + 0.3)), 6.0) * 0.55 + pow(absf(cos(ang * 2.5 + 1.1)), 10.0) * 0.3
			var core: float = clampf(1.0 - d * 1.8, 0.0, 1.0)
			core = core * core * (3.0 - 2.0 * core)
			var ray: float = pow(clampf(1.0 - d, 0.0, 1.0), 1.5) * spikes
			var a: float = clampf(core + ray, 0.0, 1.0)
			var c: Color = Color(1.0, 0.95 + 0.05 * core, 0.8 + 0.2 * core, a)
			img.set_pixel(x, y, c)
	return _tex(img)


static func _make_hole(surface: StringName) -> ImageTexture:
	var look: Array = HOLE_LOOKS[surface]
	var core: Color = look[0]
	var ring: Color = look[1]
	var ring_r: float = float(look[2])
	var cracks: int = int(look[3])
	var rough: float = float(look[4])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(surface)) & 0x7FFFFFFF
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.18
	var n: int = HOLE_SIZE
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var crack_angles: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(cracks):
		crack_angles.append(TAU * float(i) / float(maxi(cracks, 1)) + rng.randf_range(-0.25, 0.25))
	var core_r: float = 0.17 if surface != &"metal" else 0.13
	for y: int in range(n):
		for x: int in range(n):
			var v: Vector2 = Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var d: float = v.length()
			var jitter: float = noise.get_noise_2d(x, y) * rough
			var c: Color = Color(0, 0, 0, 0)
			var rr: float = ring_r * (1.0 + jitter * 0.6)
			if surface == &"wood":
				rr *= 1.0 + 0.6 * absf(v.normalized().y) if d > 0.0 else 1.0
			if d < rr:
				var t: float = clampf((d - core_r) / maxf(rr - core_r, 0.01), 0.0, 1.0)
				var ring_col: Color = ring.lerp(ring * 0.75, clampf(jitter + 0.5, 0.0, 1.0))
				c = ring_col
				c.a = (1.0 - t * t) * 0.9
				if surface == &"glass":
					c.a *= 0.55
			for ca: float in crack_angles:
				var dir: Vector2 = Vector2.from_angle(ca)
				var along: float = v.dot(dir)
				var across: float = absf(v.cross(dir))
				var reach: float = 0.95 - 0.25 * absf(sin(ca * 7.0))
				if along > 0.0 and along < reach and across < 0.025 + 0.015 * (1.0 - along):
					var ca_col: Color = ring if surface == &"glass" else core.lerp(ring, 0.35)
					var aa: float = (1.0 - along / reach) * (0.95 if surface == &"glass" else 0.8)
					if aa > c.a:
						c = Color(ca_col.r, ca_col.g, ca_col.b, aa)
			if surface == &"glass" and absf(d - 0.55) < 0.02:
				c = Color(ring.r, ring.g, ring.b, maxf(c.a, 0.6))
			var cr: float = core_r * (1.0 + jitter * 0.4)
			if d < cr:
				var k: float = clampf(d / cr, 0.0, 1.0)
				c = core.lerp(core * 2.0, k * k)
				c.a = 1.0
			img.set_pixel(x, y, c)
	return _tex(img)


static func _make_scorch() -> ImageTexture:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 0x5C02
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	var n: int = SCORCH_SIZE
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in range(n):
		for x: int in range(n):
			var v: Vector2 = Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var d: float = v.length() * (1.0 + 0.35 * noise.get_noise_2d(x * 0.7, y * 0.7))
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 0.7) * (0.8 + 0.2 * noise.get_noise_2d(x * 3.0, y * 3.0))
			img.set_pixel(x, y, Color(0.03, 0.025, 0.02, clampf(a * 0.92, 0.0, 1.0)))
	return _tex(img)
