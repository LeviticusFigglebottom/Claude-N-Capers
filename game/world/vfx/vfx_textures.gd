## Procedural VFX textures and materials (impact_fx.md §3; style_guide §8). Owner: ENV C.
## Everything is generated in code from fixed seeds (no assets): soft puffs, the flash star, bullet holes
## per surface, the scorch mark, the muzzle flash atlas and blood splatter / pool / drip / smear shapes (D-113).
## Built once per process and cached (static); deterministic.
## Muzzle flash API (stable; ENV P reuses it for the first-person flash):
##   muzzle_atlas()  512x256 RGBA, a 4x2 grid of 128 px cells: row 0 (MUZZLE_ROW_FRONT) = front "star" views
##                   (4-8 petals around a hot core, seen down the barrel), row 1 (MUZZLE_ROW_SIDE) = side cone views
##                   (base on the bottom edge, tip on the top). Colour is baked (white-yellow core, orange petals,
##                   soft falloff): draw additive with a white albedo.
##   muzzle_uv(row, variant) -> Rect2      UV rect of one cell (variant 0..MUZZLE_VARIANTS-1, wraps).
##   muzzle_material(row, variant, billboard) -> cached additive unshaded material offset to that cell (QuadMesh).
##   muzzle_core()   64 px hot core sprite.
class_name VfxTextures
extends RefCounted

const PUFF_SIZE: int = 64
const HOLE_SIZE: int = 64
const FLASH_SIZE: int = 64
const SCORCH_SIZE: int = 128
const MUZZLE_CELL: int = 128
const MUZZLE_VARIANTS: int = 4
const MUZZLE_ROW_FRONT: int = 0
const MUZZLE_ROW_SIDE: int = 1
const BLOOD_SIZE: int = 128
## Splatter shapes: blood_splat_0 .. blood_splat_3.
const BLOOD_SPLATS: int = 4
## Blood decal kinds understood by blood() and VfxDecals.
const BLOOD_KINDS: Array[StringName] = [
	&"blood_splat_0", &"blood_splat_1", &"blood_splat_2", &"blood_splat_3", &"blood_pool", &"blood_drip",
	&"blood_smear",
]
## Fresh blood (dark red, never neon) and the near-black thick centre.
const BLOOD_RED: Color = Color(0.3, 0.02, 0.018)
const BLOOD_DARK: Color = Color(0.13, 0.006, 0.005)
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


## Muzzle flash atlas (see the header). Cached.
static func muzzle_atlas() -> Texture2D:
	return _cached(&"muzzle_atlas", func() -> Resource: return _make_muzzle_atlas())


## Hot white-yellow core (round, soft) for the billboard at the muzzle.
static func muzzle_core() -> Texture2D:
	return _cached(&"muzzle_core", func() -> Resource: return _make_muzzle_core())


## UV rect of atlas cell (row, variant).
static func muzzle_uv(row: int, variant: int) -> Rect2:
	var v: int = posmod(variant, MUZZLE_VARIANTS)
	return Rect2(float(v) / float(MUZZLE_VARIANTS), float(clampi(row, 0, 1)) * 0.5, 1.0 / float(MUZZLE_VARIANTS), 0.5)


## Additive unshaded material showing one atlas cell on a QuadMesh (cached per row / variant / billboard).
static func muzzle_material(row: int, variant: int, billboard: bool = false) -> StandardMaterial3D:
	var r: Rect2 = muzzle_uv(row, variant)
	var key: StringName = StringName("mat_muzzle_%d_%d_%d" % [row, posmod(variant, MUZZLE_VARIANTS), int(billboard)])
	return _cached(key, func() -> Resource:
		var m: StandardMaterial3D = additive_material(muzzle_atlas(), false)
		m.vertex_color_use_as_albedo = false
		m.uv1_scale = Vector3(r.size.x, r.size.y, 1.0)
		m.uv1_offset = Vector3(r.position.x, r.position.y, 0.0)
		if billboard:
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
		return m) as StandardMaterial3D


## Blood decal texture for one of BLOOD_KINDS (null otherwise). Splatters throw streaks and droplets toward +V
## (texture down = decal +Z), so a decal whose +Z follows the shot reads directional.
static func blood(kind: StringName) -> Texture2D:
	if not kind in BLOOD_KINDS:
		return null
	return _cached(kind, func() -> Resource: return _make_blood(kind))


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
		m.billboard_keep_scale = true  # else the particle scale is dropped and every sprite draws 1 m wide
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
		m.billboard_keep_scale = true  # D-113: the authored puff sizes apply (they drew 1 m wide before)
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


# --- Muzzle flash (D-113) ----------------------------------------------------------------------------------

## Heat 0..1 -> colour: deep orange edge, orange, yellow, white-yellow core.
static func _heat(h: float) -> Color:
	var stops: Array[Color] = [Color(0.85, 0.24, 0.04), Color(1.0, 0.52, 0.14), Color(1.0, 0.8, 0.42),
		Color(1.0, 0.97, 0.86)]
	var x: float = clampf(h, 0.0, 1.0) * float(stops.size() - 1)
	var i: int = mini(int(x), stops.size() - 2)
	return stops[i].lerp(stops[i + 1], x - float(i))


static func _make_muzzle_atlas() -> ImageTexture:
	var n: int = MUZZLE_CELL
	var img: Image = Image.create(n * MUZZLE_VARIANTS, n * 2, false, Image.FORMAT_RGBA8)
	for v: int in range(MUZZLE_VARIANTS):
		_paint_muzzle_front(img, v * n, 0, v)
		_paint_muzzle_side(img, v * n, n, v)
	return _tex(img)


## Front view: a hot core with 4-8 tapered flame petals of uneven length, broken up by noise.
static func _paint_muzzle_front(img: Image, ox: int, oy: int, variant: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x3F1A0 + variant * 7919
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.07
	var petals: int = 4 + variant + (1 if variant == 3 else 0)
	var ang: PackedFloat32Array = PackedFloat32Array()
	var length: PackedFloat32Array = PackedFloat32Array()
	var width: PackedFloat32Array = PackedFloat32Array()
	var base: float = rng.randf_range(-PI, PI)
	for i: int in range(petals):
		ang.append(base + TAU * float(i) / float(petals) + rng.randf_range(-0.35, 0.35))
		length.append(rng.randf_range(0.55, 0.97))
		width.append(rng.randf_range(0.28, 0.46))
	var n: int = MUZZLE_CELL
	for y: int in range(n):
		for x: int in range(n):
			var p: Vector2 = Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var r: float = p.length()
			var a: float = p.angle()
			var petal: float = 0.0
			var heat_p: float = 0.0
			for i: int in range(petals):
				var da: float = absf(angle_difference(a, ang[i]))
				var w: float = width[i] * (1.0 - 0.55 * clampf(r / length[i], 0.0, 1.0)) + 0.03
				var along: float = clampf(1.0 - r / length[i], 0.0, 1.0)
				var val: float = exp(-pow(da / w, 2.0)) * smoothstep(0.0, 0.35, along)
				if val > petal:
					petal = val
					heat_p = val * along
			petal *= clampf(0.7 + 0.55 * noise.get_noise_2d(x + ox, y), 0.0, 1.0)
			var core: float = exp(-pow(r / 0.27, 2.0))
			var c: Color = _heat(core * 1.1 + heat_p * 0.85)
			c.a = clampf(core + petal * 0.85, 0.0, 1.0)
			img.set_pixel(ox + x, oy + y, c)


## Side view of the forward cone: hot narrow throat at the base (bottom), a bulb, a bright "shock" knot,
## then ragged noise-torn tongues toward the tip (top).
static func _paint_muzzle_side(img: Image, ox: int, oy: int, variant: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x51DE0 + variant * 104729
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.06
	var bulb_t: float = rng.randf_range(0.22, 0.4)
	var bulb_w: float = rng.randf_range(0.5, 0.7)
	var knot_t: float = rng.randf_range(0.12, 0.22)
	var lean: float = rng.randf_range(-0.08, 0.08)
	var n: int = MUZZLE_CELL
	for y: int in range(n):
		for x: int in range(n):
			var t: float = 1.0 - (float(y) + 0.5) / float(n)  # 0 at the base (bottom row), 1 at the tip
			var u: float = (float(x) + 0.5) / float(n) * 2.0 - 1.0
			u += noise.get_noise_2d(x * 0.3 + ox, y * 0.9) * 0.2 * t - lean * t
			var w: float = 0.14 + bulb_w * sin(PI * clampf(t / (bulb_t * 2.4), 0.0, 1.0)) * (1.0 - 0.5 * t)
			w = maxf(w * (1.0 - t * 0.55), 0.03)
			var body: float = exp(-pow(u / w, 2.0) * 1.4)
			var tip: float = pow(clampf(1.0 - t, 0.0, 1.0), 0.7)
			var tear: float = clampf(0.55 + 0.75 * noise.get_noise_2d(x * 1.3 + ox, y * 0.8 + 50.0), 0.0, 1.0)
			body *= lerpf(1.0, tear, smoothstep(0.15, 0.6, t))
			var base_fade: float = smoothstep(0.0, 0.05, t)
			var knot: float = exp(-pow((t - knot_t) / 0.05, 2.0)) * exp(-pow(u / 0.1, 2.0)) * 0.7
			var c: Color = _heat(body * pow(1.0 - t, 0.9) * 1.05 + knot)
			c.a = clampf((body * tip + knot) * base_fade, 0.0, 1.0)
			img.set_pixel(ox + x, oy + y, c)


static func _make_muzzle_core() -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in range(n):
		for x: int in range(n):
			var r: float = Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var core: float = exp(-pow(r / 0.32, 2.0))
			var halo: float = exp(-pow(r / 0.7, 2.0)) * 0.35
			var c: Color = _heat(core * 1.15 + halo * 0.6)
			c.a = clampf(core + halo, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return _tex(img)


# --- Blood (D-113) -----------------------------------------------------------------------------------------

static func _make_blood(kind: StringName) -> ImageTexture:
	var n: int = BLOOD_SIZE
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(BLOOD_RED.r, BLOOD_RED.g, BLOOD_RED.b, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(kind)) & 0x7FFFFFFF
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.08
	var dens: PackedFloat32Array = PackedFloat32Array()
	dens.resize(n * n)
	match kind:
		&"blood_pool":
			_blood_pool(dens, noise)
		&"blood_drip":
			_blood_drops(dens, rng, 7, Vector2.ZERO, 0.55, Vector2(0.06, 0.18))
		&"blood_smear":
			_blood_smear(dens, noise)
		_:
			_blood_splat(dens, rng, noise)
	for y: int in range(n):
		for x: int in range(n):
			var d: float = dens[y * n + x]
			if d <= 0.0:
				continue
			var c: Color = BLOOD_RED.lerp(BLOOD_DARK, clampf((d - 0.6) * 1.6, 0.0, 1.0))
			c = c.lerp(c * 0.8, clampf(noise.get_noise_2d(x * 2.0, y * 2.0) * 0.5 + 0.5, 0.0, 1.0))
			c.a = clampf(smoothstep(0.0, 0.35, d) * 0.94, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return _tex(img)


## Density-field helpers: coordinates -1..1, +Y = texture down = the shot's travel direction.
static func _blood_px(n: int, i: int) -> Vector2:
	return Vector2(float(i % n) + 0.5, float(i / n) + 0.5) / (float(n) * 0.5) - Vector2.ONE


## A main blob thrown back from the travel direction, 6-10 tapering streaks and 18-30 satellite droplets.
static func _blood_splat(dens: PackedFloat32Array, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var n: int = BLOOD_SIZE
	var c0: Vector2 = Vector2(rng.randf_range(-0.1, 0.1), -0.32)
	var r0: float = rng.randf_range(0.18, 0.26)
	var streaks: Array[Vector3] = []  # angle, length, width
	for i: int in range(rng.randi_range(6, 10)):
		streaks.append(Vector3(rng.randf_range(-0.75, 0.75), rng.randf_range(0.35, 0.95), rng.randf_range(0.025, 0.06)))
	for i: int in range(n * n):
		var q: Vector2 = _blood_px(n, i) - c0
		var edge: float = r0 * (1.0 + 0.35 * noise.get_noise_2d(q.angle() * 20.0, 3.0))
		var d: float = clampf((edge - q.length()) / 0.05 + 0.5, 0.0, 1.5)
		for s: Vector3 in streaks:
			var dir: Vector2 = Vector2(sin(s.x), cos(s.x))
			var along: float = q.dot(dir)
			if along < 0.0 or along > s.y:
				continue
			var w: float = s.z * (1.0 - 0.7 * along / s.y)
			d = maxf(d, clampf((w - absf(q.cross(dir))) / 0.015, 0.0, 1.0) * (1.0 - 0.4 * along / s.y))
		dens[i] = d
	_blood_drops(dens, rng, rng.randi_range(18, 30), c0, 1.2, Vector2(0.012, 0.05))


## `count` round drops around `from`: in a forward cone when reach > 1 (splatter), else scattered (drip).
static func _blood_drops(dens: PackedFloat32Array, rng: RandomNumberGenerator, count: int, from: Vector2, reach: float,
		radius: Vector2) -> void:
	var n: int = BLOOD_SIZE
	var cone: bool = reach > 1.0
	for k: int in range(count):
		var a: float = rng.randf_range(-0.9, 0.9) if cone else rng.randf_range(-PI, PI)
		var dist: float = rng.randf_range(0.15, reach) if cone else rng.randf_range(0.0, reach)
		var c: Vector2 = from + Vector2(sin(a), cos(a)) * dist
		var r: float = lerpf(radius.y, radius.x, clampf(dist / reach, 0.0, 1.0)) * rng.randf_range(0.7, 1.2)
		var lo: Vector2i = Vector2i(((c - Vector2.ONE * r + Vector2.ONE) * n * 0.5).floor()).clampi(0, n - 1)
		var hi: Vector2i = Vector2i(((c + Vector2.ONE * r + Vector2.ONE) * n * 0.5).ceil()).clampi(0, n - 1)
		for y: int in range(lo.y, hi.y + 1):
			for x: int in range(lo.x, hi.x + 1):
				var i: int = y * n + x
				dens[i] = maxf(dens[i], clampf((r - _blood_px(n, i).distance_to(c)) / maxf(r * 0.35, 0.008), 0.0, 1.0))


static func _blood_pool(dens: PackedFloat32Array, noise: FastNoiseLite) -> void:
	var n: int = BLOOD_SIZE
	for i: int in range(n * n):
		var p: Vector2 = _blood_px(n, i)
		var a: float = p.angle()
		var edge: float = 0.74 + 0.16 * noise.get_noise_2d(cos(a) * 9.0, sin(a) * 9.0) + 0.03 * noise.get_noise_2d(cos(a) * 60.0, 0.0)
		dens[i] = clampf((edge - p.length()) / 0.06, 0.0, 1.0) * (0.75 + 0.6 * clampf(1.0 - p.length() / edge, 0.0, 1.0))


## A streaky band along V (a body dragged / bagged).
static func _blood_smear(dens: PackedFloat32Array, noise: FastNoiseLite) -> void:
	var n: int = BLOOD_SIZE
	for i: int in range(n * n):
		var p: Vector2 = _blood_px(n, i)
		var half: float = 0.42 + 0.12 * noise.get_noise_2d(p.y * 30.0, 1.0)
		var band: float = clampf((half - absf(p.x)) / 0.08, 0.0, 1.0)
		var streak: float = clampf(0.45 + 0.8 * noise.get_noise_2d(p.x * 160.0, p.y * 8.0), 0.0, 1.0)
		var ends: float = clampf((0.95 - absf(p.y)) / 0.25, 0.0, 1.0)
		dens[i] = band * streak * ends * 0.8
