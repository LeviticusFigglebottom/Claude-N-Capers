## zfight (final): coplanar (offset < 2 mm), same-facing, overlapping triangles of different
## materials (overlap > 4 cm²). Triangles are binned by quantised plane; overlaps measured by 2D
## polygon clipping. Tessellated curved surfaces (planes < 2 cm² in total) are skipped.
class_name LcCheckZfight
extends LcCheck

const PLANE_EPS: float = 0.002
const NORMAL_DOT: float = 0.999
const MIN_OVERLAP_AREA: float = 0.0004
const CELL: float = 1.0
const MAX_REPORTS: int = 40


func _init() -> void:
	id = &"zfight"
	title = "Z-fighting"
	stages = PackedStringArray(["final"])


func run(ctx: LcContext) -> void:
	# tri record: [a, b, c, normal, mat_id, owner_id, two_sided, node]
	var bins: Dictionary = {}
	var tris: Array = []
	for piece: Dictionary in LcVisual.render_pieces(ctx):
		var mesh: Mesh = piece["mesh"]
		var xf: Transform3D = piece["xf"]
		var mats: Array = piece["materials"]
		var node: Node = piece["node"]
		for s: int in range(mesh.get_surface_count()):
			var mat: Material = mats[s] if s < mats.size() else null
			var mid: int = mat.get_instance_id() if mat != null else 0
			var bm: BaseMaterial3D = mat as BaseMaterial3D
			var two: bool = bm != null and bm.cull_mode == BaseMaterial3D.CULL_DISABLED
			var v: PackedVector3Array = LcVisual.triangles(ctx, mesh, s)["v"]
			for i: int in _planar_tris(ctx, mesh, s, v):
				var a: Vector3 = xf * v[i]
				var b: Vector3 = xf * v[i + 1]
				var c: Vector3 = xf * v[i + 2]
				var cr: Vector3 = (b - a).cross(c - a)
				if cr.length() < 1e-6:
					continue
				var n: Vector3 = cr.normalized()
				var idx: int = tris.size()
				tris.append([a, b, c, n, mid, node.get_instance_id() * 64 + s, two, node])
				var d: float = n.dot(a)
				var key: String = "%d,%d,%d" % [roundi(n.x * 40.0), roundi(n.y * 40.0), roundi(n.z * 40.0)]
				var db: int = int(floor(d / PLANE_EPS))
				var full: String = "%s|%d" % [key, db]
				if not bins.has(full):
					bins[full] = []
				(bins[full] as Array).append(idx)
	var pairs_seen: Dictionary = {}
	var reports: int = 0
	var bin_keys: Array = bins.keys()
	bin_keys.sort()
	for bk: String in bin_keys:
		var parts: PackedStringArray = bk.split("|")
		var db2: int = int(parts[1])
		var cand: Array = []
		for off: int in [0, 1]:
			var k2: String = "%s|%d" % [parts[0], db2 + off]
			if bins.has(k2):
				cand.append_array(bins[k2])
		var here: Array = bins[bk]
		if cand.size() < 2:
			continue
		# Spatial hash on the plane to keep pair tests local.
		var grid: Dictionary = {}
		for ti: int in cand:
			for cell: String in _cells(tris[ti]):
				if not grid.has(cell):
					grid[cell] = []
				(grid[cell] as Array).append(ti)
		for ti2: int in here:
			var t1: Array = tris[ti2]
			for cell2: String in _cells(t1):
				for tj: int in grid[cell2]:
					if tj == ti2:
						continue
					var t2: Array = tris[tj]
					if t1[4] == t2[4] or t1[5] == t2[5]:
						continue
					var pk: String = "%d-%d" % [mini(ti2, tj), maxi(ti2, tj)]
					if pairs_seen.has(pk):
						continue
					pairs_seen[pk] = true
					var dot: float = (t1[3] as Vector3).dot(t2[3])
					if dot < NORMAL_DOT and not ((t1[6] or t2[6]) and dot <= -NORMAL_DOT):
						continue
					if absf((t1[3] as Vector3).dot((t2[0] as Vector3) - (t1[0] as Vector3))) >= PLANE_EPS:
						continue
					var area: float = _overlap(t1, t2)
					if area > MIN_OVERLAP_AREA:
						var owners: String = "%d|%d" % [mini(t1[5], t2[5]), maxi(t1[5], t2[5])]
						if pairs_seen.has(owners):
							continue
						pairs_seen[owners] = true
						reports += 1
						if reports <= MAX_REPORTS:
							var centroid: Vector3 = ((t1[0] as Vector3) + (t1[1] as Vector3) + (t1[2] as Vector3)) / 3.0
							fail(ctx, t1[7], centroid, "z-fights with `%s` (coplanar overlap %.4f m2, different materials)"
								% [ctx.node_path(t2[7]), area])
	note("%d triangles in %d plane bins" % [tris.size(), bins.size()])
	if reports > MAX_REPORTS:
		fail(ctx, ctx.map, null, "%d more z-fighting pairs not listed" % (reports - MAX_REPORTS))


## Start indices of triangles lying on a (mesh-local) plane whose total area could reach the
## overlap threshold. Curved / finely tessellated surfaces drop out here, which keeps the check
## linear in planar triangles. Cached per mesh surface.
static func _planar_tris(ctx: LcContext, mesh: Mesh, s: int, v: PackedVector3Array) -> PackedInt32Array:
	var key: String = "zplanar:%d:%d" % [mesh.get_instance_id(), s]
	if ctx.cache.has(key):
		return ctx.cache[key]
	var by_plane: Dictionary = {}
	var area_of: Dictionary = {}
	for i: int in range(0, v.size() - 2, 3):
		var cr: Vector3 = (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
		var ln: float = cr.length()
		if ln < 1e-9:
			continue
		var n: Vector3 = cr / ln
		var k: Vector4i = Vector4i(roundi(n.x * 200.0), roundi(n.y * 200.0), roundi(n.z * 200.0),
			roundi(n.dot(v[i]) / (PLANE_EPS * 0.5)))
		if not by_plane.has(k):
			by_plane[k] = []
			area_of[k] = 0.0
		(by_plane[k] as Array).append(i)
		area_of[k] = float(area_of[k]) + ln * 0.5
	var out: PackedInt32Array = PackedInt32Array()
	for k2: Vector4i in by_plane.keys():
		# 0.5: tolerate instance scale down to ~0.7.
		if float(area_of[k2]) >= MIN_OVERLAP_AREA * 0.5:
			out.append_array(PackedInt32Array(by_plane[k2] as Array))
	out.sort()
	ctx.cache[key] = out
	return out


static func _basis2(n: Vector3) -> Array[Vector3]:
	var u: Vector3 = (Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).cross(n).normalized()
	return [u, n.cross(u)]


static func _cells(t: Array) -> PackedStringArray:
	var b: Array[Vector3] = _basis2(t[3])
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for k: int in range(3):
		var p: Vector3 = t[k]
		var q: Vector2 = Vector2(p.dot(b[0]), p.dot(b[1]))
		lo = lo.min(q)
		hi = hi.max(q)
	var out: PackedStringArray = PackedStringArray()
	for x: int in range(int(floor(lo.x / CELL)), int(floor(hi.x / CELL)) + 1):
		for y: int in range(int(floor(lo.y / CELL)), int(floor(hi.y / CELL)) + 1):
			out.append("%d,%d" % [x, y])
	return out


static func _overlap(t1: Array, t2: Array) -> float:
	var b: Array[Vector3] = _basis2(t1[3])
	var p1: PackedVector2Array = PackedVector2Array()
	var p2: PackedVector2Array = PackedVector2Array()
	for k: int in range(3):
		var a: Vector3 = t1[k]
		var c: Vector3 = t2[k]
		p1.append(Vector2(a.dot(b[0]), a.dot(b[1])))
		p2.append(Vector2(c.dot(b[0]), c.dot(b[1])))
	return LcGeom.tri_overlap_area_2d(p1, p2)
