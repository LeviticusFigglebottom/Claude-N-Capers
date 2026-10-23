## Smoke clouds (D-163, Sicario's smoke bomb; `EventBus.smoke_cloud_fx(position, radius, duration_s)`). Owner: ENV C.
## Child of VfxDirector. Presentation only: the cloud's gameplay (vision / AI) is ENV A's, on the same numbers.
## Cheap on Compatibility: no particles, a fixed set of large billboarded puff quads per cloud (PUFFS, scaled by
## quality) laid out in a dome about one radius tall and wide (_layout), one shared material per cloud whose alpha follows
## fade-in (FADE_IN_S) / hold / fade-out (FADE_OUT_S) inside the duration; the puffs swell and drift slowly.
## Pool: VfxSettings.SMOKE_CAP clouds, the oldest reused.
class_name SmokeCloudFx
extends Node3D

const PUFFS: int = 36
## Never fewer, at any quality: the cloud hides what is in it (gameplay-readable, like tracers).
const MIN_PUFFS: int = 24
const FADE_IN_S: float = 1.0
const FADE_OUT_S: float = 2.0
const COLOR: Color = Color(0.7, 0.7, 0.68)
## Peak opacity of one puff (they overlap, so the cloud's core reads near-opaque).
const ALPHA: float = 1.0
## Puff diameter as a fraction of the radius (min, max), and the swell over the cloud's life.
const PUFF_SIZE: Vector2 = Vector2(0.7, 1.0)
const SWELL: float = 0.25
## Puff layers in turn: (centre height, horizontal spread) as fractions of the radius: ground, body, crown.
const LAYERS: Array[Vector2] = [Vector2(0.2, 0.8), Vector2(0.5, 0.7), Vector2(0.8, 0.45)]
const DRIFT_M_PER_S: float = 0.08

## Clouds fired (tests).
var fired: int = 0

var _clouds: Array[Node3D] = []
## Per cloud: [age_s, duration_s, radius]
var _state: Array[PackedFloat32Array] = []
var _cursor: int = -1
var _cap: int = VfxSettings.SMOKE_CAP


func _init() -> void:
	name = "SmokeClouds"


func cap() -> int:
	return _cap


func set_cap(c: int) -> void:
	_cap = maxi(1, c)
	for s: Node3D in _clouds:
		s.queue_free()
	_clouds.clear()
	_state.clear()
	_cursor = -1


## Build every cloud to the cap now, hidden (VfxDirector.prewarm).
func prewarm() -> void:
	while _clouds.size() < _cap:
		_clouds.append(_build_cloud())
		_state.append(PackedFloat32Array([0.0, 0.0, 0.0]))
	_cursor = _clouds.size() - 1


func active_count() -> int:
	var n: int = 0
	for s: Node3D in _clouds:
		if s.visible:
			n += 1
	return n


func fire(pos: Vector3, radius: float, duration_s: float) -> Node3D:
	var i: int = _take()
	var s: Node3D = _clouds[i]
	if s.is_inside_tree():
		s.global_position = pos
	else:
		s.position = pos
	_state[i] = PackedFloat32Array([0.0, maxf(duration_s, FADE_IN_S + FADE_OUT_S), maxf(radius, 0.5)])
	_layout(s, radius)
	s.visible = true
	_apply(i)
	fired += 1
	return s


## Opacity factor (0..1) of a cloud `age_s` into a `duration_s` life.
static func fade(age_s: float, duration_s: float) -> float:
	if age_s <= 0.0 or age_s >= duration_s:
		return 0.0
	return clampf(minf(age_s / FADE_IN_S, (duration_s - age_s) / FADE_OUT_S), 0.0, 1.0)


func advance(delta: float) -> void:
	for i: int in range(_clouds.size()):
		if not _clouds[i].visible:
			continue
		_state[i][0] += delta
		if _state[i][0] >= _state[i][1]:
			_clouds[i].visible = false
			continue
		_apply(i)


func clear() -> void:
	for s: Node3D in _clouds:
		s.visible = false


func _apply(i: int) -> void:
	var st: PackedFloat32Array = _state[i]
	var k: float = fade(st[0], st[1])
	var s: Node3D = _clouds[i]
	(s.get_meta(&"mat") as StandardMaterial3D).albedo_color = Color(COLOR, ALPHA * k)
	var grow: float = 1.0 + SWELL * clampf(st[0] / st[1], 0.0, 1.0)
	for c: Node in s.get_children():
		var q: MeshInstance3D = c as MeshInstance3D
		var home: Vector3 = q.get_meta(&"home")
		var dir: Vector3 = q.get_meta(&"drift")
		q.position = home * grow + dir * DRIFT_M_PER_S * st[0]
		q.scale = Vector3.ONE * float(q.get_meta(&"size")) * grow


## Deterministic puff layout for this radius (same cloud every time: presentation only).
## Deterministic puff layout for this radius (same cloud every time: presentation only). Three layers, in turn: a
## ground layer that engulfs whatever stands in the cloud, a body layer and a crown, so the dome stands about one radius
## tall (>= 2.5 m at a 4 m radius: it hides a standing crew member).
func _layout(s: Node3D, radius: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x5A0C
	var n: int = 0
	for c: Node in s.get_children():
		var q: MeshInstance3D = c as MeshInstance3D
		var layer: Vector2 = LAYERS[n % LAYERS.size()]   # (centre height, spread) as fractions of the radius
		var a: float = rng.randf() * TAU
		var r: float = 0.0 if n == 0 else sqrt(rng.randf()) * radius * layer.y
		var size: float = rng.randf_range(PUFF_SIZE.x, PUFF_SIZE.y) * radius
		n += 1
		q.set_meta(&"home", Vector3(cos(a) * r, radius * layer.x * (0.85 + 0.3 * rng.randf()), sin(a) * r))
		q.set_meta(&"drift", Vector3(cos(a), 0.3, sin(a)).normalized())
		q.set_meta(&"size", size)


func _take() -> int:
	if _clouds.size() < _cap:
		_clouds.append(_build_cloud())
		_state.append(PackedFloat32Array([0.0, 0.0, 0.0]))
		_cursor = _clouds.size() - 1
		return _cursor
	_cursor = (_cursor + 1) % _clouds.size()
	return _cursor


func _build_cloud() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Cloud%d" % _clouds.size()
	root.visible = false
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = VfxTextures.puff()
	mat.albedo_color = Color(COLOR, 0.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.proximity_fade_enabled = true  # no hard line where a puff cuts the floor or a wall
	mat.proximity_fade_distance = 0.2
	root.set_meta(&"mat", mat)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	for p: int in range(maxi(MIN_PUFFS, VfxSettings.scaled_count(PUFFS))):
		var q: MeshInstance3D = MeshInstance3D.new()
		q.name = "Puff%d" % p
		q.mesh = quad
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(q)
	add_child(root)
	return root
