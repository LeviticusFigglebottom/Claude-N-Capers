## One muzzle flash (impact_fx.md §3, D-113). Owner: ENV C. Root of `res://world/vfx/muzzle_flash.tscn`; used by
## both the third-person pool (MuzzleFx) and ENV P's first-person viewmodel.
## Root -Z points down the barrel; at size 1 a rifle flash is ~1 m long (ENV P scales the root to ~0.12 m).
## API (P's FP contract):
##   flash(size, suppressed, weapon_class = &"", variant = -1, brake = -1)  show one shot. weapon_class picks the
##       shape (&"pistol", &"smg", &"rifle", &"shotgun", &"lmg", &"sniper"; &"" / &"assault_rifle" / unknown = rifle);
##       variant 0..3 picks the atlas petals, -1 = random from GameRng.stream(RNG_STREAM). Random roll and scale per shot.
##       brake: 1 = the muzzle has a brake/compensator (shorter forward cone + two side-port jets), 0 = bare muzzle,
##       -1 = by class (BRAKE_SHAPES). The root sits at the brake's `Muzzle` marker (its front face, PO6-13).
##   burst_end()       play the trailing smoke wisp now (after the last shot of a burst).
##   fp_scale(enabled) shrink sparks and wisp for a camera ~0.5 m away (first person).
##   tick(delta)       advance (automatic in _process while `auto_tick`; set it false and drive tick() yourself).
## Children (built in code): `Star` (billboard hot core), `Flame` (two crossed side-cone quads along -Z),
## `Petals` (a front star quad facing down the barrel + side petal quads), `Sparks` (2-5 short streaks),
## `Wisp` (trailing smoke, 0.6-1.2 s, world space, rises and fades), `Smoke` (world-size puff emitter; ENV P hides
## it in first person). Suppressed = Smoke only (no flash, sparks or light). Textures: VfxTextures.muzzle_atlas().
## The flash stays up for FLASH_S and at least one drawn frame (VfxSettings.frame_drawn_since; never waits headless).
## No light here (P has its own; MuzzleFx asks VfxLights for third person).
class_name MuzzleFlash
extends Node3D

## PO6-13 / D-114 §8: toned down from D-113 (0.05 s, size x1): about half the size, 3 -> 2 frames at 60 fps.
const FLASH_S: float = 0.034
## Global size factor on every class shape (keeps the proportions; FP and TP alike).
const SIZE_K: float = 0.6
## Classes that carry a muzzle brake / compensator by default (ENV B brake meshes on long guns).
const BRAKE_SHAPES: Array[StringName] = [&"rifle", &"lmg", &"sniper", &"shotgun"]
## With a brake: forward cone length factor, and the side-port jets (size-1 metres: width, length; angle off
## the barrel in degrees; offset behind the front face along +Z).
const BRAKE_CONE_K: float = 0.75
const PORT_JET: Vector2 = Vector2(0.16, 0.34)
const PORT_ANGLE: float = 80.0
const PORT_BACK: float = 0.03
const RNG_STREAM: StringName = &"vfx_muzzle"
const SMOKE_LAYER: Dictionary = {
	"kind": &"puff", "count": 4, "life": 0.7, "speed": Vector2(0.3, 0.9), "spread": 25.0, "gravity": -0.4,
	"size": Vector2(0.1, 0.2), "c0": Color(0.5, 0.5, 0.49, 0.2), "c1": Color(0.48, 0.48, 0.47, 0.0), "mesh": &"chip",
}
## Class shape at size 1 (m): core = billboard core size; cone = Vector2(width, length) of the forward cone;
## petals = side petal count; petal = Vector2(width, length); angle = petal angle off the barrel (deg);
## front = front star size; sparks = Vector2i(min, max) spark count.
const SHAPES: Dictionary[StringName, Dictionary] = {
	&"pistol": {"core": 0.42, "cone": Vector2(0.38, 0.62), "petals": 3, "petal": Vector2(0.2, 0.3), "angle": 62.0,
		"front": 0.55, "sparks": Vector2i(1, 2)},
	&"smg": {"core": 0.4, "cone": Vector2(0.36, 0.72), "petals": 3, "petal": Vector2(0.18, 0.3), "angle": 58.0,
		"front": 0.5, "sparks": Vector2i(1, 2)},
	&"rifle": {"core": 0.42, "cone": Vector2(0.5, 1.4), "petals": 4, "petal": Vector2(0.2, 0.42), "angle": 55.0,
		"front": 0.7, "sparks": Vector2i(1, 2)},
	&"lmg": {"core": 0.46, "cone": Vector2(0.54, 1.5), "petals": 4, "petal": Vector2(0.22, 0.48), "angle": 55.0,
		"front": 0.75, "sparks": Vector2i(1, 3)},
	&"shotgun": {"core": 0.62, "cone": Vector2(0.75, 0.8), "petals": 6, "petal": Vector2(0.3, 0.55), "angle": 68.0,
		"front": 1.05, "sparks": Vector2i(1, 3)},
	&"sniper": {"core": 0.6, "cone": Vector2(0.6, 1.9), "petals": 4, "petal": Vector2(0.3, 0.7), "angle": 60.0,
		"front": 1.0, "sparks": Vector2i(1, 3)},
}
const MAX_PETALS: int = 6
const MAX_SPARKS: int = 5
## Other weapon class names in the game -> shape.
const CLASS_ALIASES: Dictionary[StringName, StringName] = {
	&"assault_rifle": &"rifle", &"ar": &"rifle", &"carbine": &"rifle", &"dmr": &"sniper", &"marksman": &"sniper",
	&"handgun": &"pistol", &"revolver": &"pistol", &"akimbo": &"pistol",
}
const SPARK_COLOR: Color = Color(1.0, 0.72, 0.36)
const SPARK_LIFE_S: Vector2 = Vector2(0.05, 0.11)
const SPARK_SPEED: Vector2 = Vector2(6.0, 12.0)
const WISP_PUFFS: int = 3
const WISP_LIFE_S: Vector2 = Vector2(0.6, 1.2)
const WISP_COLOR: Color = Color(0.55, 0.55, 0.53, 0.2)
## First person: sparks and wisp scale (camera ~0.5 m from the muzzle).
const FP_SCALE: float = 0.45

## Hide the flash after FLASH_S in _process (MuzzleFx pools and ENV P set false and call tick()).
@export var auto_tick: bool = true
## Start a light wisp automatically after every shot (third person). ENV P may set false and call burst_end().
@export var auto_wisp: bool = true

## Last shot's resolved shape and atlas variant (tests / tools).
var last_shape: StringName = &"rifle"
var last_variant: int = 0
## Last shot had brake side-port jets (tests / tools).
var last_brake: bool = false

var _left: float = 0.0
## Engine.get_frames_drawn() when the flash started: it stays up for at least one drawn frame (hitch-proof).
var _drawn_at: int = -1
var _smoke_left: float = 0.0
var _wisp_delay: float = -1.0
var _wisp_k: float = 1.0
var _size: float = 1.0
var _fp: bool = false
var _star: MeshInstance3D
var _flame: Node3D
var _petals: Node3D
var _front: MeshInstance3D
var _sparks: Node3D
var _wisp: Node3D
var _smoke: GeometryInstance3D
var _flame_quads: Array[MeshInstance3D] = []
var _petal_quads: Array[MeshInstance3D] = []
var _port_quads: Array[MeshInstance3D] = []
var _spark_vel: PackedVector3Array = PackedVector3Array()
var _spark_left: PackedFloat32Array = PackedFloat32Array()
var _spark_len: PackedFloat32Array = PackedFloat32Array()
var _wisp_vel: PackedVector3Array = PackedVector3Array()
var _wisp_age: PackedFloat32Array = PackedFloat32Array()
var _wisp_life: PackedFloat32Array = PackedFloat32Array()
var _wisp_size: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	_build()


func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)


## Shape key for a weapon class (&"" and unknown classes -> &"rifle").
static func shape_of(weapon_class: StringName) -> StringName:
	if SHAPES.has(weapon_class):
		return weapon_class
	return CLASS_ALIASES.get(weapon_class, &"rifle")


## Show the flash. `size` scales everything (1 = rifle cone ~1 m, relative to the root's own scale).
func flash(size: float = 1.0, suppressed: bool = false, weapon_class: StringName = &"", variant: int = -1,
		brake: int = -1) -> void:
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	size *= SIZE_K
	_size = size
	var shown: bool = not suppressed
	_star.visible = shown
	_flame.visible = shown
	_petals.visible = shown
	_sparks.visible = shown
	if shown:
		last_shape = shape_of(weapon_class)
		last_variant = posmod(variant, VfxTextures.MUZZLE_VARIANTS) if variant >= 0 \
			else rng.randi_range(0, VfxTextures.MUZZLE_VARIANTS - 1)
		last_brake = BRAKE_SHAPES.has(last_shape) if brake < 0 else brake == 1
		_shape(SHAPES[last_shape], size, last_variant, rng)
		_ports(size, last_variant, rng)
		_left = FLASH_S
		_drawn_at = Engine.get_frames_drawn()
	_smoke.scale = Vector3.ONE * (0.6 if suppressed else 1.0)
	_smoke.visible = true
	ImpactFx.restart_emitter(_smoke)
	_smoke_left = float(SMOKE_LAYER["life"]) + 0.1
	if auto_wisp and shown:
		_wisp_delay = FLASH_S
		_wisp_k = 0.45


## Trailing smoke after a burst (louder than the per-shot wisp).
func burst_end() -> void:
	_wisp_delay = -1.0
	_start_wisp(1.0)


## First-person scaling of sparks and wisp (camera ~0.5 m away). The flash itself follows the root scale.
func fp_scale(enabled: bool) -> void:
	_fp = enabled


func is_flashing() -> bool:
	return _star.visible


func is_wisp_visible() -> bool:
	return _wisp.visible


## Petal quads shown by the last flash (tests).
func petal_count() -> int:
	var n: int = 0
	for q: MeshInstance3D in _petal_quads:
		if q.visible:
			n += 1
	return n


## Forward cone length (m, local) of the last flash (tests).
func cone_length() -> float:
	return _flame.scale.z


func tick(delta: float) -> void:
	if _smoke_left > 0.0:
		_smoke_left -= delta
		if _smoke_left <= 0.0:
			_smoke.visible = false  # idle emitter: no draw call
	_tick_sparks(delta)
	if _wisp_delay >= 0.0:
		_wisp_delay -= delta
		if _wisp_delay < 0.0:
			_start_wisp(_wisp_k)
	_tick_wisp(delta)
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0 and VfxSettings.frame_drawn_since(_drawn_at):
		hide_flash()


func hide_flash() -> void:
	_left = 0.0
	_star.visible = false
	_flame.visible = false
	_petals.visible = false


## Hide everything including sparks, smoke and wisp (map reset).
func reset_all() -> void:
	hide_flash()
	_sparks.visible = false
	_wisp.visible = false
	_wisp_delay = -1.0
	_smoke.visible = false
	_smoke_left = 0.0


func _shape(sh: Dictionary, size: float, variant: int, rng: RandomNumberGenerator) -> void:
	var jitter: float = rng.randf_range(0.82, 1.18)
	var roll: float = rng.randf_range(-PI, PI)
	var core: float = float(sh["core"]) * size * rng.randf_range(0.85, 1.15)
	_star.scale = Vector3.ONE * core
	var cone: Vector2 = sh["cone"]
	var cone_k: float = BRAKE_CONE_K if last_brake else 1.0
	_flame.scale = Vector3(cone.x * size * jitter, cone.x * size * jitter,
		cone.y * size * cone_k * rng.randf_range(0.85, 1.2))
	_flame.rotation = Vector3(0.0, 0.0, roll)
	for k: int in range(_flame_quads.size()):
		_set_cell(_flame_quads[k], VfxTextures.MUZZLE_ROW_SIDE, variant + k * 2)
	_set_cell(_front, VfxTextures.MUZZLE_ROW_FRONT, variant)
	var front: float = float(sh["front"]) * size * jitter
	_front.transform = Transform3D(Basis(Vector3.BACK, rng.randf_range(-PI, PI)).scaled(Vector3(front, front, 1.0)),
		Vector3(0.0, 0.0, -0.04 * size))
	var n: int = int(sh["petals"])
	var petal: Vector2 = sh["petal"]
	var ang: float = deg_to_rad(float(sh["angle"]))
	for i: int in range(MAX_PETALS):
		var q: MeshInstance3D = _petal_quads[i]
		q.visible = i < n
		if i >= n:
			continue
		var phi: float = roll + TAU * float(i) / float(n) + rng.randf_range(-0.3, 0.3)
		var a: float = ang * rng.randf_range(0.8, 1.15)
		var radial: Vector3 = Vector3(cos(phi), sin(phi), 0.0)
		var d: Vector3 = (Vector3.FORWARD * cos(a) + radial * sin(a)).normalized()
		var x: Vector3 = d.cross(radial.cross(Vector3.FORWARD)).normalized()  # in the plane of d and the barrel
		var y: Vector3 = d
		var plen: float = petal.y * size * rng.randf_range(0.7, 1.25)
		var wid: float = petal.x * size * rng.randf_range(0.8, 1.2)
		q.transform = Transform3D(Basis(x * wid, y * plen, x.cross(y).normalized()), Vector3(0.0, 0.0, -0.03 * size))
		_set_cell(q, VfxTextures.MUZZLE_ROW_SIDE, variant + i)
	var sparks: Vector2i = sh["sparks"]
	var count: int = mini(VfxSettings.scaled_count(rng.randi_range(sparks.x, sparks.y)), MAX_SPARKS)
	var k_fp: float = FP_SCALE if _fp else 1.0
	for i: int in range(MAX_SPARKS):
		var sp: MeshInstance3D = _sparks.get_child(i) as MeshInstance3D
		sp.visible = i < count
		_spark_left[i] = rng.randf_range(SPARK_LIFE_S.x, SPARK_LIFE_S.y) if i < count else 0.0
		var off: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), 0.0) * 0.35
		var v: Vector3 = (Vector3.FORWARD + off).normalized()
		_spark_vel[i] = v * rng.randf_range(SPARK_SPEED.x, SPARK_SPEED.y) * size * k_fp * VfxSettings.motion_scale()
		_spark_len[i] = rng.randf_range(0.08, 0.18) * size * k_fp
		sp.position = Vector3(0.0, 0.0, -0.05 * size)
		_orient_spark(i)


## Brake side-port jets: two short petals almost square to the barrel, left and right, just behind the front face.
func _ports(size: float, variant: int, rng: RandomNumberGenerator) -> void:
	for i: int in range(_port_quads.size()):
		var q: MeshInstance3D = _port_quads[i]
		q.visible = last_brake
		if not last_brake:
			continue
		var radial: Vector3 = Vector3.RIGHT if i == 0 else Vector3.LEFT
		if last_shape == &"shotgun":  # ENV B's shotgun comps vent up-and-out (~45 deg), not square to the side
			radial = (radial + Vector3.UP).normalized()
		var a: float = deg_to_rad(PORT_ANGLE) * rng.randf_range(0.92, 1.05)
		var d: Vector3 = (Vector3.FORWARD * cos(a) + radial * sin(a)).normalized()
		var x: Vector3 = d.cross(radial.cross(Vector3.FORWARD)).normalized()
		var plen: float = PORT_JET.y * size * rng.randf_range(0.8, 1.2)
		var wid: float = PORT_JET.x * size * rng.randf_range(0.85, 1.15)
		q.transform = Transform3D(Basis(x * wid, d * plen, x.cross(d).normalized()), Vector3(0.0, 0.0, PORT_BACK * size))
		_set_cell(q, VfxTextures.MUZZLE_ROW_SIDE, variant + 3 + i)


## Side-port jets shown by the last flash (tests).
func port_count() -> int:
	var n: int = 0
	for q: MeshInstance3D in _port_quads:
		if q.visible and _petals.visible:
			n += 1
	return n


## Point a quad's own material at atlas cell (row, variant). Each quad owns its material (ENV P may swap it for
## an alpha-blended duplicate; the UV change then lands on that copy).
func _set_cell(q: MeshInstance3D, row: int, variant: int) -> void:
	var m: BaseMaterial3D = q.material_override as BaseMaterial3D
	if m == null:
		return
	var r: Rect2 = VfxTextures.muzzle_uv(row, variant)
	m.uv1_scale = Vector3(r.size.x, r.size.y, 1.0)
	m.uv1_offset = Vector3(r.position.x, r.position.y, 0.0)


func _orient_spark(i: int) -> void:
	var sp: MeshInstance3D = _sparks.get_child(i) as MeshInstance3D
	var v: Vector3 = _spark_vel[i]
	if v.length_squared() < 1e-8:
		return
	var y: Vector3 = v.normalized()
	var ref: Vector3 = Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT
	var x: Vector3 = ref.cross(y).normalized()
	var w: float = maxf(_spark_len[i] * 0.06, 0.002 * _size)
	sp.basis = Basis(x * w, y * _spark_len[i], x.cross(y).normalized() * w)


func _tick_sparks(delta: float) -> void:
	if not _sparks.visible:
		return
	var any: bool = false
	for i: int in range(MAX_SPARKS):
		if _spark_left[i] <= 0.0:
			continue
		_spark_left[i] -= delta
		var sp: MeshInstance3D = _sparks.get_child(i) as MeshInstance3D
		if _spark_left[i] <= 0.0 and VfxSettings.frame_drawn_since(_drawn_at):
			sp.visible = false
			continue
		any = true
		_spark_vel[i] = _spark_vel[i] * maxf(1.0 - 6.0 * delta, 0.0) + Vector3(0.0, -2.0 * delta, 0.0)
		sp.position += _spark_vel[i] * delta
	if not any:
		_sparks.visible = false


func _start_wisp(k: float) -> void:
	if not is_inside_tree():
		return
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	var g: Transform3D = global_transform
	var root_scale: float = g.basis.get_scale().x
	var fwd: Vector3 = -g.basis.z.normalized()
	var s: float = maxf(_size, 0.05) * root_scale * (FP_SCALE if _fp else 1.0)
	_wisp.visible = true
	for i: int in range(WISP_PUFFS):
		var q: MeshInstance3D = _wisp.get_child(i) as MeshInstance3D
		q.visible = true
		q.global_position = g.origin + fwd * s * (0.1 + 0.25 * float(i)) \
			+ Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.02, 0.02), rng.randf_range(-0.03, 0.03)) * s
		_wisp_age[i] = -0.04 * float(i)  # staggered
		_wisp_life[i] = rng.randf_range(WISP_LIFE_S.x, WISP_LIFE_S.y)
		_wisp_size[i] = s * rng.randf_range(0.28, 0.42) * k
		_wisp_vel[i] = (Vector3.UP * rng.randf_range(0.14, 0.26) + fwd * rng.randf_range(0.04, 0.12)
			+ Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))) * s / 0.3 * VfxSettings.motion_scale()
		q.transparency = 1.0
		q.rotation = Vector3(0.0, 0.0, rng.randf_range(-PI, PI))


func _tick_wisp(delta: float) -> void:
	if not _wisp.visible:
		return
	var any: bool = false
	for i: int in range(WISP_PUFFS):
		var q: MeshInstance3D = _wisp.get_child(i) as MeshInstance3D
		if not q.visible:
			continue
		_wisp_age[i] += delta
		var t: float = _wisp_age[i] / _wisp_life[i]
		if t >= 1.0:
			q.visible = false
			continue
		any = true
		if t < 0.0:
			continue
		q.global_position += _wisp_vel[i] * delta
		_wisp_vel[i] *= maxf(1.0 - 1.2 * delta, 0.0)
		var a: float = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.35, 1.0, t))
		q.transparency = 1.0 - a
		q.scale = Vector3.ONE * _wisp_size[i] * lerpf(0.6, 2.2, sqrt(t))
	if not any:
		_wisp.visible = false


func _quad(node_name: String, mat: Material, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = node_name
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	q.center_offset = offset
	m.mesh = q
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _build() -> void:
	var core_mat: StandardMaterial3D = VfxTextures.additive_material(VfxTextures.muzzle_core(), false)
	core_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	core_mat.billboard_keep_scale = true  # the core follows _star.scale and the root scale (ENV P FP note)
	core_mat.vertex_color_use_as_albedo = false
	_star = _quad("Star", core_mat)
	_star.visible = false
	add_child(_star)
	# Forward cone: quads whose +Y runs down the barrel (-Z), base at the muzzle; scale.z = cone length.
	_flame = Node3D.new()
	_flame.name = "Flame"
	_flame.visible = false
	var side: StandardMaterial3D = VfxTextures.muzzle_material(VfxTextures.MUZZLE_ROW_SIDE, 0)
	var front: StandardMaterial3D = VfxTextures.muzzle_material(VfxTextures.MUZZLE_ROW_FRONT, 0)
	for b: Basis in [Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)]:
		var q: MeshInstance3D = _quad("Cone%d" % _flame_quads.size(), side.duplicate(), Vector3(0.0, 0.5, 0.0))
		q.basis = b
		_flame.add_child(q)
		_flame_quads.append(q)
	add_child(_flame)
	_petals = Node3D.new()
	_petals.name = "Petals"
	_petals.visible = false
	_front = _quad("Front", front.duplicate())
	_petals.add_child(_front)
	for i: int in range(MAX_PETALS):
		var q: MeshInstance3D = _quad("Petal%d" % i, side.duplicate(), Vector3(0.0, 0.5, 0.0))
		_petals.add_child(q)
		_petal_quads.append(q)
	for side_name: String in ["PortR", "PortL"]:
		var q: MeshInstance3D = _quad(side_name, side.duplicate(), Vector3(0.0, 0.5, 0.0))
		q.visible = false
		_petals.add_child(q)
		_port_quads.append(q)
	add_child(_petals)
	_sparks = Node3D.new()
	_sparks.name = "Sparks"
	_sparks.visible = false
	var spark_mat: StandardMaterial3D = VfxTextures.glow_material().duplicate() as StandardMaterial3D
	spark_mat.vertex_color_use_as_albedo = false
	spark_mat.albedo_color = SPARK_COLOR
	var spark_mesh: BoxMesh = BoxMesh.new()
	spark_mesh.size = Vector3(1.0, 1.0, 1.0)
	spark_mesh.material = spark_mat
	for i: int in range(MAX_SPARKS):
		var sp: MeshInstance3D = MeshInstance3D.new()
		sp.name = "Spark%d" % i
		sp.mesh = spark_mesh
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.visible = false
		_sparks.add_child(sp)
		_spark_vel.append(Vector3.ZERO)
		_spark_left.append(0.0)
		_spark_len.append(0.1)
	add_child(_sparks)
	_wisp = Node3D.new()
	_wisp.name = "Wisp"
	_wisp.visible = false
	var wisp_mat: StandardMaterial3D = StandardMaterial3D.new()
	wisp_mat.albedo_texture = VfxTextures.puff()
	wisp_mat.albedo_color = WISP_COLOR
	wisp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	wisp_mat.billboard_keep_scale = true
	wisp_mat.roughness = 1.0
	wisp_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i: int in range(WISP_PUFFS):
		var w: MeshInstance3D = _quad("Puff%d" % i, wisp_mat)
		w.top_level = true  # drifts in world space, not with the gun
		w.visible = false
		_wisp.add_child(w)
		_wisp_vel.append(Vector3.ZERO)
		_wisp_age.append(0.0)
		_wisp_life.append(1.0)
		_wisp_size.append(0.1)
	add_child(_wisp)
	var layer: Dictionary = SMOKE_LAYER.duplicate()
	_smoke = ImpactFx.build_emitter(layer, VfxSettings.scaled_count(int(layer["count"])))
	_smoke.name = "Smoke"
	_smoke.visible = false
	# Emitters fire along local +Y; turn it down the barrel (-Z).
	_smoke.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.08))
	add_child(_smoke)
