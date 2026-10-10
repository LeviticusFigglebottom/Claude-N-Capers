## Pure geometry helpers for levelcheck (no scene access, deterministic). Owner: ENV C.
class_name LcGeom
extends RefCounted


## Oriented box from a transform (may carry scale) and an AABB in that transform's local space.
## Returns { "c": Vector3 centre, "ax": Array[Vector3] unit axes, "h": Vector3 half extents (m) }.
static func obb(xf: Transform3D, local: AABB) -> Dictionary:
	var axes: Array[Vector3] = []
	var h: Vector3 = local.size * 0.5
	for i: int in range(3):
		var col: Vector3 = xf.basis[i]
		var s: float = col.length()
		axes.append(col / s if s > 1e-9 else Vector3.ZERO)
		h[i] *= s
	return {"c": xf * local.get_center(), "ax": axes, "h": h}


## Separating-axis test between two OBBs (see obb()). Returns the smallest overlap over all 15
## axes: > 0 means the boxes intersect by (at least) that depth, <= 0 means separated.
static func obb_overlap(a: Dictionary, b: Dictionary) -> float:
	var aa: Array[Vector3] = a["ax"]
	var ba: Array[Vector3] = b["ax"]
	var test: Array[Vector3] = []
	test.append_array(aa)
	test.append_array(ba)
	for i: int in range(3):
		for j: int in range(3):
			var c: Vector3 = aa[i].cross(ba[j])
			if c.length_squared() > 1e-8:
				test.append(c.normalized())
	var d: Vector3 = (b["c"] as Vector3) - (a["c"] as Vector3)
	var best: float = INF
	for axis: Vector3 in test:
		var o: float = _radius(a, axis) + _radius(b, axis) - absf(d.dot(axis))
		if o <= 0.0:
			return o
		best = minf(best, o)
	return best


static func _radius(o: Dictionary, axis: Vector3) -> float:
	var ax: Array[Vector3] = o["ax"]
	var h: Vector3 = o["h"]
	return h.x * absf(axis.dot(ax[0])) + h.y * absf(axis.dot(ax[1])) + h.z * absf(axis.dot(ax[2]))


static func point_in_obb(p: Vector3, o: Dictionary, inflate: float = 0.0) -> bool:
	var ax: Array[Vector3] = o["ax"]
	var h: Vector3 = o["h"]
	var d: Vector3 = p - (o["c"] as Vector3)
	for i: int in range(3):
		if absf(d.dot(ax[i])) > h[i] + inflate:
			return false
	return true


## Distance between two world AABBs (0 when touching/overlapping).
static func aabb_gap(a: AABB, b: AABB) -> float:
	var d: Vector3 = Vector3.ZERO
	for i: int in range(3):
		var lo: float = maxf(a.position[i], b.position[i])
		var hi: float = minf(a.end[i], b.end[i])
		d[i] = maxf(0.0, lo - hi)
	return d.length()


static func tri_area(a: Vector3, b: Vector3, c: Vector3) -> float:
	return (b - a).cross(c - a).length() * 0.5


static func tri_area_2d(a: Vector2, b: Vector2, c: Vector2) -> float:
	return absf((b - a).cross(c - a)) * 0.5


static func polygon_area(poly: PackedVector2Array) -> float:
	var s: float = 0.0
	var n: int = poly.size()
	for i: int in range(n):
		s += poly[i].cross(poly[(i + 1) % n])
	return absf(s) * 0.5


## Area of the intersection of two 2D triangles (convex clip, Sutherland-Hodgman).
static func tri_overlap_area_2d(t1: PackedVector2Array, t2: PackedVector2Array) -> float:
	var poly: PackedVector2Array = t1.duplicate()
	# Make t2 counter-clockwise so "inside" is the left side of each edge.
	var clip: PackedVector2Array = t2.duplicate()
	if (clip[1] - clip[0]).cross(clip[2] - clip[0]) < 0.0:
		clip = PackedVector2Array([clip[0], clip[2], clip[1]])
	for e: int in range(3):
		if poly.is_empty():
			return 0.0
		var a: Vector2 = clip[e]
		var b: Vector2 = clip[(e + 1) % 3]
		var out: PackedVector2Array = PackedVector2Array()
		var n: int = poly.size()
		for i: int in range(n):
			var p: Vector2 = poly[i]
			var q: Vector2 = poly[(i + 1) % n]
			var pin: bool = (b - a).cross(p - a) >= 0.0
			var qin: bool = (b - a).cross(q - a) >= 0.0
			if pin:
				out.append(p)
			if pin != qin:
				var dp: float = (b - a).cross(p - a)
				var dq: float = (b - a).cross(q - a)
				var t: float = dp / (dp - dq)
				out.append(p.lerp(q, t))
		poly = out
	if poly.size() < 3:
		return 0.0
	return polygon_area(poly)


## Triangles of a mesh surface as a flat array (3 vertices per triangle) plus UVs (may be empty).
## Only PRIMITIVE_TRIANGLES surfaces produce triangles.
static func surface_triangles(mesh: Mesh, surface: int) -> Dictionary:
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var empty: Dictionary = {"v": verts, "uv": uvs}
	if mesh == null or surface >= mesh.get_surface_count():
		return empty
	var am: ArrayMesh = mesh as ArrayMesh
	if am != null and am.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
		return empty
	var arrays: Array = mesh.surface_get_arrays(surface)
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return empty
	var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var puv: PackedVector2Array = PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		puv = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		idx = arrays[Mesh.ARRAY_INDEX]
	var has_uv: bool = puv.size() == pv.size()
	if idx.is_empty():
		var n: int = pv.size() - pv.size() % 3
		for i: int in range(n):
			verts.append(pv[i])
			if has_uv:
				uvs.append(puv[i])
	else:
		var n2: int = idx.size() - idx.size() % 3
		for i: int in range(n2):
			verts.append(pv[idx[i]])
			if has_uv:
				uvs.append(puv[idx[i]])
	return {"v": verts, "uv": uvs}


## Inward-facing frustum planes (Plane.distance_to(p) >= 0 inside).
## fov_deg is vertical; for orthographic pass ortho_size (vertical size in m) > 0.
static func frustum_planes(xf: Transform3D, fov_deg: float, aspect: float, near: float, far: float,
		ortho_size: float = 0.0) -> Array[Plane]:
	var o: Vector3 = xf.origin
	var fwd: Vector3 = -xf.basis.z.normalized()
	var up: Vector3 = xf.basis.y.normalized()
	var right: Vector3 = xf.basis.x.normalized()
	var planes: Array[Plane] = []
	planes.append(Plane(fwd, o + fwd * near))
	planes.append(Plane(-fwd, o + fwd * far))
	if ortho_size > 0.0:
		var hh: float = ortho_size * 0.5
		var hw: float = hh * aspect
		planes.append(Plane(right, o - right * hw))
		planes.append(Plane(-right, o + right * hw))
		planes.append(Plane(up, o - up * hh))
		planes.append(Plane(-up, o + up * hh))
		return planes
	var v: float = deg_to_rad(fov_deg) * 0.5
	var h: float = atan(tan(v) * aspect)
	planes.append(Plane((right * cos(h) + fwd * sin(h)).normalized(), o))
	planes.append(Plane((-right * cos(h) + fwd * sin(h)).normalized(), o))
	planes.append(Plane((up * cos(v) + fwd * sin(v)).normalized(), o))
	planes.append(Plane((-up * cos(v) + fwd * sin(v)).normalized(), o))
	return planes


static func aabb_in_frustum(box: AABB, planes: Array[Plane]) -> bool:
	for pl: Plane in planes:
		var p: Vector3 = box.position
		if pl.normal.x >= 0.0:
			p.x += box.size.x
		if pl.normal.y >= 0.0:
			p.y += box.size.y
		if pl.normal.z >= 0.0:
			p.z += box.size.z
		if pl.distance_to(p) < 0.0:
			return false
	return true


static func sphere_in_frustum(c: Vector3, r: float, planes: Array[Plane]) -> bool:
	for pl: Plane in planes:
		if pl.distance_to(c) < -r:
			return false
	return true


static func path_length(path: PackedVector3Array) -> float:
	var s: float = 0.0
	for i: int in range(1, path.size()):
		s += path[i].distance_to(path[i - 1])
	return s


## Counts distinct simple cycles (length >= 3) through `start` in an undirected graph given as
## adjacency { key: PackedInt32Array/Array of neighbour keys } with int keys. Stops at `cap`.
## Cycles that are reversals of each other count once. Deterministic (neighbours sorted).
static func count_cycles_through(adj: Dictionary, start: int, cap: int, step_budget: int = 200000) -> int:
	var seen: Dictionary = {}
	var state: Dictionary = {"steps": 0, "budget": step_budget}
	var path: Array[int] = [start]
	var on_path: Dictionary = {start: true}
	_cycle_dfs(adj, start, start, path, on_path, seen, cap, state)
	return mini(seen.size(), cap)


static func _cycle_dfs(adj: Dictionary, start: int, cur: int, path: Array[int], on_path: Dictionary,
		seen: Dictionary, cap: int, state: Dictionary) -> void:
	if seen.size() >= cap or int(state["steps"]) >= int(state["budget"]):
		return
	state["steps"] = int(state["steps"]) + 1
	var nbrs: Array = (adj.get(cur, []) as Array).duplicate()
	nbrs.sort()
	for nb: int in nbrs:
		if nb == start and path.size() >= 3:
			var key: String = _cycle_key(path)
			seen[key] = true
			if seen.size() >= cap:
				return
			continue
		if on_path.has(nb):
			continue
		path.append(nb)
		on_path[nb] = true
		_cycle_dfs(adj, start, nb, path, on_path, seen, cap, state)
		path.pop_back()
		on_path.erase(nb)


static func _cycle_key(path: Array[int]) -> String:
	var edges: PackedStringArray = PackedStringArray()
	var n: int = path.size()
	for i: int in range(n):
		var a: int = path[i]
		var b: int = path[(i + 1) % n]
		edges.append("%d-%d" % [mini(a, b), maxi(a, b)])
	edges.sort()
	return ",".join(edges)
