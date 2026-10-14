## Ejected casings, physics-lite (impact_fx.md §3). Owner: ENV C. Child of VfxDirector.
## Simple ballistic flight from the ejection point (right of the shot direction), one damped bounce on
## the floor found by a single downward ray at spawn (fallback: FALLBACK_DROP_M below), then rest and
## vanish after REST_S. No RigidBody. All casings are instances of ONE MultiMesh; cap VfxSettings.SHELL_CAP.
class_name ShellFx
extends MultiMeshInstance3D

const GRAVITY: float = 9.8
const BOUNCE_DAMP: float = 0.35
const REST_S: float = 3.0
const FALLBACK_DROP_M: float = 1.3
const FLOOR_RAY_M: float = 3.0
## World physics layers the floor ray hits (layer 1 world_static).
const FLOOR_MASK: int = 1
const BRASS: Color = Color(0.78, 0.6, 0.25)
const HULL: Color = Color(0.55, 0.08, 0.06)
## Casing per weapon class: [length m, radius m, colour] (classes without an entry eject nothing).
const CASINGS: Dictionary[StringName, Array] = {
	&"pistol": [0.02, 0.0048, BRASS], &"smg": [0.02, 0.0048, BRASS], &"assault_rifle": [0.045, 0.005, BRASS],
	&"lmg": [0.045, 0.005, BRASS], &"sniper": [0.065, 0.006, BRASS], &"shotgun": [0.065, 0.0105, HULL],
}

## Live casing count (tests).
var live: int = 0

var _cap: int = VfxSettings.SHELL_CAP
var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _floor: PackedFloat32Array = PackedFloat32Array()
var _bounces: PackedInt32Array = PackedInt32Array()
var _rest: PackedFloat32Array = PackedFloat32Array()
var _spin: PackedVector3Array = PackedVector3Array()
var _rot: Array[Basis] = []
var _size: PackedVector3Array = PackedVector3Array()
var _color: PackedColorArray = PackedColorArray()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "Shells"
	top_level = true
	_rng.seed = 0x5E11  # presentation-only variation
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.material = VfxTextures.casing_material()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cyl
	multimesh = mm
	multimesh.instance_count = _cap
	multimesh.visible_instance_count = 0
	custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))


static func ejects(weapon_class: StringName) -> bool:
	return CASINGS.has(weapon_class)


func cap() -> int:
	return _cap


func set_cap(c: int) -> void:
	_cap = maxi(1, c)
	while live > _cap:
		_remove(0)
	multimesh.instance_count = _cap
	_write_all()


## Eject one casing for `weapon_class` from a muzzle at `origin` firing along `dir`.
func eject(weapon_class: StringName, origin: Vector3, dir: Vector3) -> void:
	if not CASINGS.has(weapon_class):
		return
	if live >= _cap:
		_remove(0)
	var spec: Array = CASINGS[weapon_class]
	var fwd: Vector3 = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.FORWARD
	var right: Vector3 = fwd.cross(Vector3.UP)
	right = right.normalized() if right.length_squared() > 1e-6 else Vector3.RIGHT
	# Ejection port ~0.25 m behind the muzzle on the right.
	var p: Vector3 = origin - fwd * 0.25 + right * 0.04
	var v: Vector3 = right * _rng.randf_range(1.6, 2.6) + Vector3.UP * _rng.randf_range(1.2, 2.2) - fwd * 0.4
	_pos.append(p)
	_vel.append(v * VfxSettings.motion_scale())
	_floor.append(_floor_y(p))
	_bounces.append(0)
	_rest.append(-1.0)
	_spin.append(Vector3(_rng.randf_range(-25, 25), _rng.randf_range(-10, 10), _rng.randf_range(-25, 25)))
	_rot.append(Basis.looking_at(right, Vector3.UP))
	_size.append(Vector3(float(spec[1]), float(spec[0]), float(spec[1])))
	_color.append(spec[2])
	live += 1
	_write(live - 1)
	multimesh.visible_instance_count = live


func advance(delta: float) -> void:
	var i: int = 0
	while i < live:
		if _rest[i] >= 0.0:
			_rest[i] += delta
			if _rest[i] > REST_S:
				_remove(i)
				continue
			i += 1
			continue
		var v: Vector3 = _vel[i]
		v.y -= GRAVITY * delta
		var p: Vector3 = _pos[i] + v * delta
		var fy: float = _floor[i] + _size[i].x
		if p.y <= fy and v.y < 0.0:
			p.y = fy
			if _bounces[i] == 0:
				v = Vector3(v.x * 0.5, -v.y * BOUNCE_DAMP, v.z * 0.5)
				_spin[i] *= 0.4
				_bounces[i] = 1
			else:
				v = Vector3.ZERO
				_rest[i] = 0.0
				# Lie on its side.
				_rot[i] = Basis(Vector3.UP, _rot[i].get_euler().y) * Basis(Vector3.RIGHT, PI * 0.5)
		_vel[i] = v
		_pos[i] = p
		if _rest[i] < 0.0:
			var s: Vector3 = _spin[i] * delta
			_rot[i] = (_rot[i] * Basis.from_euler(s)).orthonormalized()
		i += 1
	_write_all()


func clear() -> void:
	while live > 0:
		_remove(0)
	multimesh.visible_instance_count = 0


func _floor_y(p: Vector3) -> float:
	if is_inside_tree():
		var w: World3D = get_world_3d()
		if w != null and w.direct_space_state != null:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * FLOOR_RAY_M,
				FLOOR_MASK)
			var hit: Dictionary = w.direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				return (hit["position"] as Vector3).y
	return p.y - FALLBACK_DROP_M


func _remove(i: int) -> void:
	_pos.remove_at(i)
	_vel.remove_at(i)
	_floor.remove_at(i)
	_bounces.remove_at(i)
	_rest.remove_at(i)
	_spin.remove_at(i)
	_rot.remove_at(i)
	_size.remove_at(i)
	_color.remove_at(i)
	live -= 1


func _write(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(_rot[i].scaled_local(_size[i]), _pos[i]))
	multimesh.set_instance_color(i, _color[i])


func _write_all() -> void:
	for k: int in range(live):
		_write(k)
	multimesh.visible_instance_count = live
