## Area3D (RoomVolume / MapZone) geometry helpers for levelcheck: boxes, containment, footprint,
## floor sample grids. Shapes are cached per area until clear_cache(). Owner: ENV C.
class_name LcAreas
extends RefCounted

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## Boxes of an Area3D: [{ "xf": Transform3D (shape global), "aabb": AABB (shape local) }].
static func boxes(a: Area3D) -> Array[Dictionary]:
	var key: int = a.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var out: Array[Dictionary] = []
	for c: Node in a.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c
		if cs.disabled or cs.shape == null:
			continue
		var box: AABB
		if cs.shape is BoxShape3D:
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			box = AABB(-sz * 0.5, sz)
		else:
			box = cs.shape.get_debug_mesh().get_aabb()
		out.append({"xf": cs.global_transform, "aabb": box})
	_cache[key] = out
	return out


static func contains(a: Area3D, p: Vector3, grow: float = 0.0) -> bool:
	for b: Dictionary in boxes(a):
		var lp: Vector3 = (b["xf"] as Transform3D).affine_inverse() * p
		if (b["aabb"] as AABB).grow(grow).has_point(lp):
			return true
	return false


static func world_aabb(a: Area3D) -> AABB:
	var out: AABB = AABB(a.global_position, Vector3.ZERO)
	var first: bool = true
	for b: Dictionary in boxes(a):
		var w: AABB = (b["xf"] as Transform3D) * (b["aabb"] as AABB)
		out = w if first else out.merge(w)
		first = false
	return out


## Floor area (m²) of a room: sum of its boxes' XZ footprints.
static func footprint(a: Area3D) -> float:
	var s: float = 0.0
	for b: Dictionary in boxes(a):
		var xf: Transform3D = b["xf"]
		var sz: Vector3 = (b["aabb"] as AABB).size
		s += sz.x * xf.basis.x.length() * sz.z * xf.basis.z.length()
	return s


## Grid of sample points on the bottom face of an area's boxes (world space), `step` m apart,
## inset from the box edge by `inset`. Deterministic order.
static func floor_grid(a: Area3D, step: float, inset: float = 0.25) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for b: Dictionary in boxes(a):
		var xf: Transform3D = b["xf"]
		var box: AABB = b["aabb"]
		var sx: float = maxf(xf.basis.x.length(), 1e-6)
		var sz: float = maxf(xf.basis.z.length(), 1e-6)
		var x0: float = box.position.x + inset / sx
		var x1: float = box.end.x - inset / sx
		var z0: float = box.position.z + inset / sz
		var z1: float = box.end.z - inset / sz
		var nx: int = maxi(1, int(floor((x1 - x0) * sx / step)) + 1)
		var nz: int = maxi(1, int(floor((z1 - z0) * sz / step)) + 1)
		for i: int in range(nx):
			for j: int in range(nz):
				var lx: float = x0 + (x1 - x0) * ((float(i) + 0.5) / float(nx))
				var lz: float = z0 + (z1 - z0) * ((float(j) + 0.5) / float(nz))
				out.append(xf * Vector3(lx, box.position.y, lz))
	return out
