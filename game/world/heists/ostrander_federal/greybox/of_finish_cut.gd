## Ostrander Federal G2 surface pass helper (OF-C2 zfight, ENV C): the other lanes' axis-aligned faces, and the cut of
## one of of_finish.gd's axis-aligned quads round the ones in its plane, so no lane-D piece is laid coplanar over a face
## another lane draws there. Used by of_finish.gd (_flush_pieces / _quad). Deterministic: tree order, no RNG.
extends RefCounted

## Plane tolerance (mm either side) of a foreign face that cuts a quad.
const EPS_MM: int = 3
## A cut cell's corners are tested this far inside it (a cell is cut only when wholly covered: never a see-through
## sliver round a curved face, e.g. the vault portal's ring on the VC wall).
const CORNER_INSET: float = 0.001

## A partly covered cell is split into sub-cells about this size (at most SUB_MAX a side) and the covered ones cut.
const SUB_M: float = 0.002
const SUB_MAX: int = 48

## Vector3i(axis, plane mm, facing sign) -> [[bounding rect [a0, b0, a1, b1], corner a, b, c (Vector2)], ...] (the
## other two axes). Facing: the sign of the triangle's winding normal on the axis (as validate_level's zfight reads it).
var faces: Dictionary = {}
## Quads cut so far.
var cuts: int = 0


## Indexes every visible mesh (and baked tile MultiMesh) under `roots` of `root`; `xform` returns a node's global
## transform (the generator's scene is not in the tree).
func index(root: Node, roots: Array[String], xform: Callable) -> void:
	faces.clear()
	for path: String in roots:
		var r: Node = root.get_node_or_null(path)
		if r == null:
			continue
		var nodes: Array[Node] = [r]
		nodes.append_array(r.find_children("*", "GeometryInstance3D", true, false))
		for pf: Node in r.find_children("*", "", true, false):
			_index_prefab_visual(pf, xform)
		for g: Node in nodes:
			var mesh: Mesh = null
			var xfs: Array[Transform3D] = []
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null and (g as MeshInstance3D).visible:
				mesh = (g as MeshInstance3D).mesh
				xfs.append(xform.call(g) as Transform3D)
			elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
				mesh = (g as MultiMeshInstance3D).multimesh.mesh
				xfs = _baked_xforms(g as MultiMeshInstance3D, xform.call(g) as Transform3D)
			if mesh == null or xfs.is_empty():
				continue
			for si: int in range(mesh.get_surface_count()):
				var tri: PackedVector3Array = _surface_faces(mesh, si)
				var two: bool = _two_sided(g as GeometryInstance3D, mesh, si)
				for xf: Transform3D in xfs:
					for t: int in range(0, tri.size() - 2, 3):
						_add(xf * tri[t], xf * tri[t + 1], xf * tri[t + 2], two)


## A surface drawn from both sides (cull disabled): it z-fights a coplanar face whichever way that one faces.
static func _two_sided(g: GeometryInstance3D, mesh: Mesh, si: int) -> bool:
	var m: Material = g.material_override
	if m == null and g is MeshInstance3D:
		m = (g as MeshInstance3D).get_active_material(si)
	if m == null:
		m = mesh.surface_get_material(si)
	return m is BaseMaterial3D and (m as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED


## A gameplay prefab's art (`visual_scene`) is instanced under its `Visual` node only at runtime: index a temporary
## instance at that node (the doors' frames, OF-C2).
func _index_prefab_visual(pf: Node, xform: Callable) -> void:
	var vs: Variant = pf.get(&"visual_scene")
	var vr: Node3D = pf.get_node_or_null(^"Visual") as Node3D
	if not vs is PackedScene or vr == null or vr.get_child_count() > 0:
		return
	var inst: Node3D = (vs as PackedScene).instantiate() as Node3D
	if inst == null:
		return
	var base: Transform3D = xform.call(vr) as Transform3D
	var geos: Array[Node] = [inst]
	geos.append_array(inst.find_children("*", "GeometryInstance3D", true, false))
	for g: Node in geos:
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		var xf: Transform3D = base * _rel_xform(mi, inst)
		for si: int in range(mi.mesh.get_surface_count()):
			var tri: PackedVector3Array = _surface_faces(mi.mesh, si)
			var two: bool = _two_sided(mi, mi.mesh, si)
			for t: int in range(0, tri.size() - 2, 3):
				_add(xf * tri[t], xf * tri[t + 1], xf * tri[t + 2], two)
	inst.free()


## `n`'s transform relative to its ancestor `top` (out of the tree).
static func _rel_xform(n: Node, top: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return (top as Node3D).transform * xf if top is Node3D else xf


## World transforms of a baked tile MultiMesh (multimesh_tiles.gd `instances`: origin + yaw per instance).
static func _baked_xforms(mmi: MultiMeshInstance3D, gx: Transform3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var inst: Variant = mmi.get(&"instances")
	if not inst is PackedFloat32Array:
		return out
	var fa: PackedFloat32Array = inst
	for k: int in range(fa.size() / 4):
		out.append(gx * Transform3D(Basis(Vector3.UP, fa[k * 4 + 3]), Vector3(fa[k * 4], fa[k * 4 + 1], fa[k * 4 + 2])))
	return out


static func _surface_faces(mesh: Mesh, si: int) -> PackedVector3Array:
	var arr: Array = mesh.surface_get_arrays(si)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if arr[Mesh.ARRAY_INDEX] == null:
		return v
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
		out.append(v[i])
	return out


## One triangle into the index when it lies in an axis plane (a two-sided one under both facings).
func _add(p0: Vector3, p1: Vector3, p2: Vector3, two_sided: bool) -> void:
	var cr: Vector3 = (p1 - p0).cross(p2 - p0)
	var ln: float = cr.length()
	if ln < 1e-6:
		return
	var nn: Vector3 = cr / ln
	var ax: int = nn.abs().max_axis_index()
	if absf(nn[ax]) < 0.999:
		return
	var u: int = (ax + 1) % 3
	var w: int = (ax + 2) % 3
	var a: Vector2 = Vector2(p0[u], p0[w])
	var b: Vector2 = Vector2(p1[u], p1[w])
	var c: Vector2 = Vector2(p2[u], p2[w])
	var r: Array = [minf(minf(a.x, b.x), c.x), minf(minf(a.y, b.y), c.y), maxf(maxf(a.x, b.x), c.x),
		maxf(maxf(a.y, b.y), c.y)]
	if (float(r[2]) - float(r[0])) * (float(r[3]) - float(r[1])) < 1e-6:
		return
	var key: Vector3i = Vector3i(ax, roundi(p0[ax] * 1000.0), 1 if nn[ax] > 0.0 else -1)
	for k: Vector3i in ([key, Vector3i(key.x, key.y, -key.z)] if two_sided else [key]):
		if not faces.has(k):
			faces[k] = []
		(faces[k] as Array).append([r, a, b, c])


## The axis-aligned quad q (facing n) minus the indexed faces in its plane that face the same way (a face back to back
## with it, e.g. a landmark's back on the wall, hides nothing and never z-fights): q is cut on their bounding lines,
## every cell they cover wholly (centre and corners) is dropped and a partly covered cell is cut in SUB_M sub-cells;
## the sub-quads keep q's corner order (same winding). `rects_minus`: of_finish._rects_minus (rect minus rects).
func minus(q: Array, n: Vector3, rects_minus: Callable) -> Array:
	var p0: Vector3 = q[0]
	var d: Vector3 = ((q[2] as Vector3) - p0).abs()
	var ax: int = 0 if d.x < 1e-5 else (1 if d.y < 1e-5 else 2)
	var u: int = (ax + 1) % 3
	var w: int = (ax + 2) % 3
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for c: Vector3 in q:
		lo = Vector2(minf(lo.x, c[u]), minf(lo.y, c[w]))
		hi = Vector2(maxf(hi.x, c[u]), maxf(hi.y, c[w]))
	var plane_mm: int = roundi(p0[ax] * 1000.0)
	# gh_mesh draws a quad facing n with the winding whose cross normal is -n (as every front face here)
	var sgn: int = -1 if n[ax] > 0.0 else 1
	var cands: Array = []
	for off: int in range(-EPS_MM, EPS_MM + 1):
		for t: Array in faces.get(Vector3i(ax, plane_mm + off, sgn), []):
			var h: Array = t[0]
			if float(h[0]) < hi.x - 0.001 and float(h[2]) > lo.x + 0.001 and float(h[1]) < hi.y - 0.001 \
					and float(h[3]) > lo.y + 0.001:
				cands.append(t)
	if cands.is_empty():
		return [q]
	var us: Array[float] = [lo.x, hi.x]
	var ws: Array[float] = [lo.y, hi.y]
	for t2: Array in cands:
		for k: int in [0, 2]:
			var uv: float = float(t2[0][k])
			if uv > lo.x and uv < hi.x and not us.has(uv):
				us.append(uv)
			var wv: float = float(t2[0][k + 1])
			if wv > lo.y and wv < hi.y and not ws.has(wv):
				ws.append(wv)
	us.sort()
	ws.sort()
	var holes: Array = []
	for iu: int in range(us.size() - 1):
		for iw: int in range(ws.size() - 1):
			var cell: Rect2 = Rect2(us[iu], ws[iw], us[iu + 1] - us[iu], ws[iw + 1] - ws[iw])
			if _covered(cell, cands):
				holes.append([us[iu], ws[iw], us[iu + 1], ws[iw + 1]])
			elif _touched(cell, cands):
				var nu: int = clampi(ceili(cell.size.x / SUB_M), 1, SUB_MAX)
				var nw: int = clampi(ceili(cell.size.y / SUB_M), 1, SUB_MAX)
				for su: int in range(nu):
					for sw: int in range(nw):
						var sub: Rect2 = Rect2(cell.position + cell.size * Vector2(float(su) / nu, float(sw) / nw),
							cell.size / Vector2(nu, nw))
						if _covered(sub, cands):
							holes.append([sub.position.x, sub.position.y, sub.end.x, sub.end.y])
	if holes.is_empty():
		return [q]
	var out: Array = []
	for r2: Array in rects_minus.call([lo.x, lo.y, hi.x, hi.y], holes):
		var sub: Array[Vector3] = []
		for c2: Vector3 in q:
			var nc: Vector3 = c2
			nc[u] = float(r2[0]) if c2[u] < (lo.x + hi.x) * 0.5 else float(r2[2])
			nc[w] = float(r2[1]) if c2[w] < (lo.y + hi.y) * 0.5 else float(r2[3])
			sub.append(nc)
		out.append(sub)
	cuts += 1
	return out


## A triangle reaches into the cell (its centre or a corner in a triangle, or a triangle corner in the cell).
static func _touched(cell: Rect2, cands: Array) -> bool:
	var pts: Array[Vector2] = [cell.get_center(), cell.position, Vector2(cell.end.x, cell.position.y), cell.end,
		Vector2(cell.position.x, cell.end.y)]
	for t: Array in cands:
		for k: int in [1, 2, 3]:
			if cell.has_point(t[k] as Vector2):
				return true
		for p: Vector2 in pts:
			if Geometry2D.point_is_inside_triangle(p, t[1], t[2], t[3]):
				return true
	return false


## A cell is covered when its centre and its four (inset) corners each lie in one of the triangles.
static func _covered(cell: Rect2, cands: Array) -> bool:
	var e: float = minf(CORNER_INSET, minf(cell.size.x, cell.size.y) * 0.25)
	var pts: Array[Vector2] = [cell.get_center(), cell.position + Vector2(e, e), Vector2(cell.end.x - e, cell.position.y + e),
		cell.end - Vector2(e, e), Vector2(cell.position.x + e, cell.end.y - e)]
	for p: Vector2 in pts:
		var hit: bool = false
		for t: Array in cands:
			if Geometry2D.point_is_inside_triangle(p, t[1], t[2], t[3]):
				hit = true
				break
		if not hit:
			return false
	return true
