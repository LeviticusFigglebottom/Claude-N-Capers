## Blood presentation (D-113): directional spray, exit spurt, wall/floor splatter, drips, growing pools under
## bodies, a smear when a body is bagged. Owner: ENV C. Child of VfxDirector, which feeds it from
## EventBus.blood_hit / bleed_changed (or the shot_fx-flag fallback) and advances it.
## Gore option (VfxSettings.gore): Full = everything; Reduced = smaller fainter spray, one faint splatter, no drips,
## pools or smears; Off = nothing here (the director shows a dust puff instead).
## Caps (quality-scaled, VfxSettings): BLOOD_SPRAY_CAP spray sets (round-robin), BLOOD_DECAL_CAP splatter / drip /
## smear decals and BLOOD_POOL_CAP pools, each its own VfxDecals pool (oldest recycled).
## Splatter: one ray from the hit (or exit) point along the shot, BLOOD_SPLATTER_RANGE_M, world layers only.
## Randomness: GameRng.stream(RNG_STREAM) (presentation only; deterministic for a fixed run seed).
class_name VfxBlood
extends Node3D

const RNG_STREAM: StringName = &"vfx_blood"
## Spray recipe (ImpactFx layer dictionaries; emits along local +Y = the shot direction). 0.15-0.3 s.
const SPRAY_LAYERS: Array[Dictionary] = [
	{"kind": &"puff", "count": 8, "life": 0.26, "speed": Vector2(0.8, 2.4), "spread": 16.0, "gravity": 1.5,
		"size": Vector2(0.09, 0.2), "c0": Color(0.24, 0.015, 0.012, 0.6), "c1": Color(0.13, 0.008, 0.006, 0.0),
		"mesh": &"chip"},
	{"kind": &"puff", "count": 10, "life": 0.16, "speed": Vector2(3.0, 7.0), "spread": 8.0, "gravity": 0.0,
		"size": Vector2(0.03, 0.07), "c0": Color(0.3, 0.02, 0.016, 0.8), "c1": Color(0.16, 0.01, 0.008, 0.0),
		"mesh": &"chip"},
	{"kind": &"solid", "count": 18, "life": 0.3, "speed": Vector2(2.5, 6.5), "spread": 15.0, "gravity": 9.8,
		"size": Vector2(0.01, 0.024), "c0": Color(0.28, 0.015, 0.012), "c1": Color(0.16, 0.008, 0.006),
		"mesh": &"drop"},
]
## Splatter size (m) near the wall .. at full range (spray widens with distance).
const SPLAT_SIZE_M: Vector2 = Vector2(0.32, 0.8)
const DRIP_SIZE_M: Vector2 = Vector2(0.12, 0.26)
const DRIP_CHANCE: float = 0.35
const HEADSHOT_K: float = 1.6
## Pool size scales with the bleed rate (0..1): lerp(POOL_MIN_K, 1) x VfxSettings.POOL_MAX_M.
const POOL_MIN_K: float = 0.55
const POOL_START_K: float = 0.12
## A new bleed position within this distance keeps the current pool.
const POOL_SAME_M: float = 0.35
const SMEAR_SIZE_M: Vector2 = Vector2(0.4, 0.9)
## Bodies tracked at once (oldest forgotten; their pools keep fading on their own).
const MAX_BODIES: int = 64

## Counters (tests).
var sprays_fired: int = 0
var splatters: int = 0
var pools_started: int = 0

var splats: VfxDecals
var pools: VfxDecals

var _sprays: Array[Node3D] = []
var _left: Dictionary[Node3D, float] = {}
var _cursor: int = -1
var _spray_cap: int = VfxSettings.BLOOD_SPRAY_CAP
## body id -> [pool node, pool serial, position]
var _bodies: Dictionary[int, Array] = {}


func _init() -> void:
	name = "Blood"
	splats = VfxDecals.new()
	splats.name = "BloodDecals"
	pools = VfxDecals.new()
	pools.name = "BloodPools"
	pools.quad_offset_m = VfxDecals.QUAD_OFFSET_M * 0.5  # under splatter / drips on the same floor
	add_child(splats)
	add_child(pools)


func set_caps(spray_cap: int, decal_cap: int, pool_cap: int) -> void:
	_spray_cap = maxi(1, spray_cap)
	for s: Node3D in _sprays:
		s.queue_free()
	_sprays.clear()
	_left.clear()
	_cursor = -1
	splats.set_cap(decal_cap)
	pools.set_cap(pool_cap)


func spray_count() -> int:
	return _sprays.size()


func spray_cap() -> int:
	return _spray_cap


func body_count() -> int:
	return _bodies.size()


## Pool node of a tracked body (null if none or recycled).
func pool_of(body_id: int) -> Node3D:
	var b: Array = _bodies.get(body_id, [])
	if b.is_empty() or pools.serial_of(b[0]) != int(b[1]):
		return null
	return b[0]


## A flesh hit: spray along `direction` from `point`, an exit spurt from `exit_point` (when finite and non-zero),
## a splatter on the wall / floor behind, sometimes a drip below. `strength` 0..1 (damage / max health).
func hit(point: Vector3, direction: Vector3, strength: float, headshot: bool, exit_point: Vector3) -> void:
	if not VfxSettings.blood_enabled():
		return
	var dir: Vector3 = direction.normalized() if direction.length_squared() > 1e-6 else Vector3.FORWARD
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	var full: bool = VfxSettings.blood_pools_enabled()
	var k: float = VfxSettings.blood_scale() * lerpf(0.75, 1.3, clampf(strength, 0.0, 1.0))
	if headshot:
		k *= HEADSHOT_K
	_spray(point, dir, k)
	var exits: bool = exit_point.is_finite() and exit_point != Vector3.ZERO
	var from: Vector3 = point
	if exits:
		_spray(exit_point, dir, k * 1.25)
		from = exit_point
	splatter(from, dir, k, rng)
	if full and (headshot or exits):
		var jitter: Vector3 = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.25, 0.1), rng.randf_range(-0.2, 0.2))
		splatter(from, (dir + jitter).normalized(), k * 0.7, rng)
	if full and rng.randf() < DRIP_CHANCE * (2.0 if headshot else 1.0):
		_drip(point, rng)


## One splatter decal where a ray from `from` along `dir` meets the world (nothing when it does not).
func splatter(from: Vector3, dir: Vector3, k: float, rng: RandomNumberGenerator = null) -> Node3D:
	if not VfxSettings.blood_enabled():
		return null
	var r: RandomNumberGenerator = rng if rng != null else GameRng.stream(RNG_STREAM)
	var hit_d: Dictionary = _ray(from + dir * 0.02, from + dir * VfxSettings.BLOOD_SPLATTER_RANGE_M)
	if hit_d.is_empty():
		return null
	var n: Vector3 = (hit_d["normal"] as Vector3).normalized()
	var p: Vector3 = hit_d["position"]
	var dist: float = from.distance_to(p) / VfxSettings.BLOOD_SPLATTER_RANGE_M
	var size: float = lerpf(SPLAT_SIZE_M.x, SPLAT_SIZE_M.y, dist) * k * r.randf_range(0.8, 1.2)
	# Texture +V follows the shot's travel across the surface (streaks run away from the source).
	var along: Vector3 = (dir - n * dir.dot(n))
	if along.length_squared() < 0.02:
		along = ImpactFx.basis_from_normal(n).z.rotated(n, r.randf_range(-PI, PI))
	along = along.normalized().rotated(n, r.randf_range(-0.35, 0.35))
	var b: Basis = Basis(n.cross(along).normalized(), n, along)
	var stretch: float = clampf(1.0 + (1.0 - absf(dir.dot(n))) * 0.6, 1.0, 1.6)  # grazing hits elongate
	var kind: StringName = StringName("blood_splat_%d" % r.randi_range(0, VfxTextures.BLOOD_SPLATS - 1))
	var alpha: float = 1.0 if VfxSettings.blood_pools_enabled() else 0.6
	splatters += 1
	return splats.place_basis(kind, p, b, Vector2(size, size * stretch), VfxSettings.BLOOD_HOLD_S,
		VfxSettings.BLOOD_FADE_S, alpha)


## bleed_changed: start (or keep) a growing pool at `position`; stop freezes it. A start more than POOL_SAME_M away
## restarts the body's pool there (one pool per body). Full gore only.
func bleed(body_id: int, bleeding: bool, position: Vector3, rate: float) -> void:
	var b: Array = _bodies.get(body_id, [])
	var pool: Node3D = pool_of(body_id)
	if not bleeding:
		if pool != null:
			pools.stop_growing(pool)
		return
	if not VfxSettings.blood_pools_enabled():
		return
	if pool != null and (b[2] as Vector3).distance_to(position) <= POOL_SAME_M:
		return
	if pool != null:
		# PO6-19: a repeated start for the same body (the ragdoll settled elsewhere) restarts its one pool there.
		pools.release(pool)
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	var floor_hit: Dictionary = _ray(position + Vector3.UP * 0.6, position + Vector3.DOWN * VfxSettings.BLOOD_DRIP_RANGE_M)
	var p: Vector3 = floor_hit.get("position", position)
	var n: Vector3 = floor_hit.get("normal", Vector3.UP)
	var r: float = clampf(rate, 0.0, 1.0)
	var size: float = VfxSettings.POOL_MAX_M * lerpf(POOL_MIN_K, 1.0, r) * rng.randf_range(0.85, 1.1)
	var grow_s: float = VfxSettings.POOL_GROW_S * lerpf(1.6, 1.0, r)
	var b2: Basis = ImpactFx.basis_from_normal(n).rotated(n.normalized(), rng.randf_range(-PI, PI))
	var node: Node3D = pools.place_basis(&"blood_pool", p, b2, Vector2(size, size * rng.randf_range(0.8, 1.0)),
		VfxSettings.POOL_HOLD_S, VfxSettings.POOL_FADE_S, 1.0, POOL_START_K, grow_s)
	if _bodies.size() >= MAX_BODIES and not _bodies.has(body_id):
		_bodies.erase(_bodies.keys()[0])
	_bodies[body_id] = [node, pools.serial_of(node), position]
	pools_started += 1


## A small smear beside a body's pool (body bagged). Full gore only; nothing without a pool.
func smear(body_id: int) -> Node3D:
	var pool: Node3D = pool_of(body_id)
	if pool == null or not VfxSettings.blood_pools_enabled():
		return null
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	var p: Vector3 = pool.global_position if pool.is_inside_tree() else pool.position
	var n: Vector3 = pool.global_basis.y.normalized() if pool.is_inside_tree() else Vector3.UP
	var b: Basis = ImpactFx.basis_from_normal(n).rotated(n, rng.randf_range(-PI, PI))
	var off: Vector3 = b.z * rng.randf_range(0.3, 0.55)
	return splats.place_basis(&"blood_smear", p + off, b, SMEAR_SIZE_M * rng.randf_range(0.8, 1.15),
		VfxSettings.BLOOD_HOLD_S, VfxSettings.BLOOD_FADE_S, 0.85)


func advance(delta: float) -> void:
	splats.advance(delta)
	pools.advance(delta)
	for s: Node3D in _left.keys():
		var t: float = _left[s] - delta
		if t <= 0.0:
			_left.erase(s)
			if is_instance_valid(s):
				s.visible = false
		else:
			_left[s] = t


func clear() -> void:
	splats.clear()
	pools.clear()
	_bodies.clear()
	for s: Node3D in _sprays:
		s.visible = false
	_left.clear()


func _spray(pos: Vector3, dir: Vector3, k: float) -> void:
	var s: Node3D = _take_spray()
	var xf: Transform3D = Transform3D(ImpactFx.basis_from_normal(dir).scaled(Vector3.ONE * k), pos)
	if s.is_inside_tree():
		s.global_transform = xf
	else:
		s.transform = xf
	s.visible = true
	for e: Node in s.get_children():
		ImpactFx.restart_emitter(e as GeometryInstance3D)
	_left[s] = float(s.get_meta(&"life", 0.5))
	sprays_fired += 1


func _take_spray() -> Node3D:
	if _sprays.size() < _spray_cap:
		var root: Node3D = Node3D.new()
		root.name = "Spray%d" % _sprays.size()
		var life: float = 0.0
		for layer: Dictionary in SPRAY_LAYERS:
			life = maxf(life, float(layer["life"]))
			root.add_child(ImpactFx.build_emitter(layer, VfxSettings.scaled_count(int(layer["count"]))))
		root.set_meta(&"life", life + 0.1)
		root.visible = false
		add_child(root)
		_sprays.append(root)
		_cursor = _sprays.size() - 1
		return root
	_cursor = (_cursor + 1) % _sprays.size()
	return _sprays[_cursor]


func _drip(point: Vector3, rng: RandomNumberGenerator) -> void:
	var off: Vector3 = Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15))
	var hit_d: Dictionary = _ray(point + off, point + off + Vector3.DOWN * VfxSettings.BLOOD_DRIP_RANGE_M)
	if hit_d.is_empty():
		return
	var n: Vector3 = hit_d["normal"]
	var b: Basis = ImpactFx.basis_from_normal(n).rotated(n.normalized(), rng.randf_range(-PI, PI))
	var size: float = rng.randf_range(DRIP_SIZE_M.x, DRIP_SIZE_M.y)
	splats.place_basis(&"blood_drip", hit_d["position"], b, Vector2(size, size), VfxSettings.BLOOD_HOLD_S,
		VfxSettings.BLOOD_FADE_S, 0.9)


## World-only ray (VfxSettings.BLOOD_WORLD_MASK: no characters / hitboxes). {} when nothing is hit.
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var w: World3D = get_world_3d()
	if w == null or w.direct_space_state == null:
		return {}
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, VfxSettings.BLOOD_WORLD_MASK)
	q.hit_from_inside = false
	return w.direct_space_state.intersect_ray(q)
