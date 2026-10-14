## World-UV mesh accumulator for the Glasshouse generator. Owner: ENV C (C1-08).
## Faces are batched per (group, material) into one MeshInstance3D per group, with world-scaled UVs
## per tools/texgen/README.md: 1 UV unit = 2 m (uv = metres / 2), U horizontal along a wall,
## V down the wall (Godot v = 0 is the image top), floors/ceilings U = x, V = z. Front faces are
## clockwise (Godot), normals and tangents are generated for the ORM materials' normal maps.
extends RefCounted

const TILE_M: float = 2.0
## tile_groups: height band (m) of a cell group.
const TILE_BAND_Y: float = 2.0
## tile_groups: narrower quads (sills, copings, curbs, trim tops, markings) stay in the group's merged mesh.
const TILE_MIN_SPAN: float = 1.0

## Opt-in slab tiling, group -> tile edge (m); empty (the default) = no tiling. The Compatibility renderer lights a
## mesh instance with at most 8 omni / spot lights (rendering/limits/opengl/max_lights_per_object), so one merged
## floor / ceiling / grade mesh overlapped by every key light kept 8 arbitrary ones and other rooms' floors rendered
## black (Gallery Night 1639ea1c). An axis-aligned horizontal quad of a listed group is cut at the world grid lines
## x, z = k * tile and each piece goes to the cell group "<group>_T<ix>_<iy>_<iz>" (its own MeshInstance3D at flush;
## iy = 2 m height band, so a floor, the ceiling under it and the roof above never share an instance's 8 lights).
## Visual only: colliders and the navmesh never see these meshes.
var tile_groups: Dictionary = {}
## group -> { material key -> PackedVector3Array/normals/uvs }
var _groups: Dictionary = {}
## material key -> Material
var _materials: Dictionary = {}
## Trim-strip UV overrides: material key -> [v_top, v_bottom] (trim sheet V range of a strip).
var _strips: Dictionary = {}


func register_material(key: String, mat: Material, strip_v: Vector2 = Vector2(-1.0, -1.0)) -> void:
	_materials[key] = mat
	if strip_v.x >= 0.0:
		_strips[key] = strip_v


func has_material(key: String) -> bool:
	return _materials.has(key)


func _bucket(group: String, key: String) -> Dictionary:
	if not _groups.has(group):
		_groups[group] = {}
	var g: Dictionary = _groups[group]
	if not g.has(key):
		g[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
	return g[key]


## World-planar UV for a point on a face with normal n.
static func world_uv(p: Vector3, n: Vector3) -> Vector2:
	var an: Vector3 = n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) / TILE_M
	if an.x >= an.z:
		return Vector2(-p.z * signf(n.x), -p.y) / TILE_M
	return Vector2(p.x * signf(n.z), -p.y) / TILE_M


## Quad a-b-c-d (any winding); n = outward normal. strip: for trim keys, V is remapped so the
## face's vertical extent [y0, y1] spans the strip's V range.
func quad(group: String, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	if key == "":
		return
	if tile_groups.has(group) and absf(n.y) > 0.999 and _tile_quad(group, key, [a, b, c, d], n):
		return
	var pts: Array[Vector3] = [a, b, c, d]
	if (b - a).cross(d - a).dot(n) < 0.0:
		pts = [a, d, c, b]
	var uvs: Array[Vector2] = []
	for p: Vector3 in pts:
		uvs.append(world_uv(p, n))
	if _strips.has(key):
		var sv: Vector2 = _strips[key]
		var ylo: float = minf(minf(pts[0].y, pts[1].y), minf(pts[2].y, pts[3].y))
		var yhi: float = maxf(maxf(pts[0].y, pts[1].y), maxf(pts[2].y, pts[3].y))
		for i: int in range(4):
			var t: float = 0.0 if yhi - ylo < 1e-6 else (yhi - pts[i].y) / (yhi - ylo)
			uvs[i].y = lerpf(sv.x, sv.y, t)
	var bk: Dictionary = _bucket(group, key)
	var vs: PackedVector3Array = bk["v"]
	var ns: PackedVector3Array = bk["n"]
	var us: PackedVector2Array = bk["uv"]
	# Two clockwise (front-facing) triangles: (0, 2, 1), (0, 3, 2). Packed arrays are values:
	# append to locals, then store them back.
	for idx: int in [0, 2, 1, 0, 3, 2]:
		vs.append(pts[idx])
		ns.append(n)
		us.append(uvs[idx])
	bk["v"] = vs
	bk["n"] = ns
	bk["uv"] = us


## tile_groups: splits an axis-aligned horizontal rectangle (both sides >= TILE_MIN_SPAN) at the world tile grid
## into cell groups. Returns false (caller emits the quad as is) for any other shape.
func _tile_quad(group: String, key: String, q: Array[Vector3], n: Vector3) -> bool:
	var tile: float = float(tile_groups[group])
	var lo: Vector3 = q[0]
	var hi: Vector3 = q[0]
	for p: Vector3 in q:
		lo = lo.min(p)
		hi = hi.max(p)
	if hi.y - lo.y > 1e-6 or minf(hi.x - lo.x, hi.z - lo.z) < TILE_MIN_SPAN:
		return false
	var corners: Dictionary = {}
	for p2: Vector3 in q:
		var cx: int = 0 if absf(p2.x - lo.x) < 1e-6 else (1 if absf(p2.x - hi.x) < 1e-6 else -1)
		var cz: int = 0 if absf(p2.z - lo.z) < 1e-6 else (1 if absf(p2.z - hi.z) < 1e-6 else -1)
		if cx < 0 or cz < 0:
			return false
		corners[cx * 2 + cz] = true
	if corners.size() != 4:
		return false
	var xs: Array[float] = _cuts(lo.x, hi.x, tile)
	var zs: Array[float] = _cuts(lo.z, hi.z, tile)
	var y: float = lo.y
	for i: int in range(xs.size() - 1):
		for j: int in range(zs.size() - 1):
			var x0: float = xs[i]
			var x1: float = xs[i + 1]
			var z0: float = zs[j]
			var z1: float = zs[j + 1]
			var cell: String = "%s_T%d_%d_%d" % [group, floori((x0 + x1) * 0.5 / tile), floori(y / TILE_BAND_Y),
				floori((z0 + z1) * 0.5 / tile)]
			quad(cell, key, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), n)
	return true


## [a0, the tile grid lines strictly inside (a0, a1), a1].
static func _cuts(a0: float, a1: float, tile: float) -> Array[float]:
	var out: Array[float] = [a0]
	var k: int = floori(a0 / tile) + 1
	while float(k) * tile < a1 - 1e-4:
		if float(k) * tile > a0 + 1e-4:
			out.append(float(k) * tile)
		k += 1
	out.append(a1)
	return out


## Axis-aligned box. face_key: Callable(face_index, normal, centre) -> String (material key, "" =
## skip the face) or a plain String for all faces. Faces: 0 -X, 1 +X, 2 -Y, 3 +Y, 4 -Z, 5 +Z.
func box(group: String, mn: Vector3, mx: Vector3, face_key: Variant) -> void:
	var normals: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK]
	for f: int in range(6):
		var n: Vector3 = normals[f]
		var corners: Array[Vector3] = _face(mn, mx, f)
		var centre: Vector3 = (corners[0] + corners[2]) * 0.5
		var key: String = String(face_key) if face_key is String else String((face_key as Callable).call(f, n, centre))
		quad(group, key, corners[0], corners[1], corners[2], corners[3], n)


static func _face(mn: Vector3, mx: Vector3, f: int) -> Array[Vector3]:
	match f:
		0:
			return [Vector3(mn.x, mn.y, mn.z), Vector3(mn.x, mn.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3(mn.x, mx.y, mn.z)]
		1:
			return [Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mn.y, mx.z)]
		2:
			return [Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3(mn.x, mn.y, mx.z)]
		3:
			return [Vector3(mn.x, mx.y, mn.z), Vector3(mn.x, mx.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mx.y, mn.z)]
		4:
			return [Vector3(mn.x, mn.y, mn.z), Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mn.y, mn.z)]
		_:
			return [Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z)]


## Builds one MeshInstance3D per group (surfaces sorted by material key for determinism).
## only: flush just these groups (others stay queued); empty = all.
func flush(parent: Node3D, owner_root: Node, metas: Dictionary = {}, only: Array = []) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var groups: Array = _groups.keys() if only.is_empty() else only.filter(func(x: Variant) -> bool: return _groups.has(x))
	groups.sort()
	for g: Variant in groups:
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.resource_name = "gh_" + String(g)
		var keys: Array = (_groups[g] as Dictionary).keys()
		keys.sort()
		for k: Variant in keys:
			var bk: Dictionary = _groups[g][k]
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var vs: PackedVector3Array = bk["v"]
			var ns: PackedVector3Array = bk["n"]
			var us: PackedVector2Array = bk["uv"]
			for i: int in range(vs.size()):
				st.set_normal(ns[i])
				st.set_uv(us[i])
				st.add_vertex(vs[i])
			st.index()
			st.generate_tangents()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _materials[k])
			mesh.surface_set_name(mesh.get_surface_count() - 1, String(k))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Visual_" + String(g)
		mi.mesh = mesh
		for mk: Variant in metas.get(g, {}):
			mi.set_meta(StringName(String(mk)), metas[g][mk])
		parent.add_child(mi)
		mi.owner = owner_root
		out.append(mi)
		_groups.erase(g)
	return out
