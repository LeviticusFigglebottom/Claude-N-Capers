## frame_proud (all stages, PO-7): a door / window frame's COLLIDERS must be flush with the wall.
## Visual trim (architraves, plinth blocks) may stand proud of the wall faces, but a collider that
## does is a sharp step a crew capsule cutting round the jamb stalls on (Glasshouse LobbyDoor, gate-3:
## 1.8 cm architrave boxes 7 cm beside the reveal). Measured in the prefab's local space (origin at
## the bottom-centre of the opening on the wall line), leaves closed (rotation 0), against every
## CollisionShape3D under the prefab's visual root that is not inside a leaf (Leaf / Leaf2).
## (1) proud: the wall faces beside each jamb (wall *collision* rays from 1 m out toward the wall
##     line, 0.03 m outside the reveal, y 0.3 / 1.0 / 1.6 m; this prefab excluded) vs every vertex
##     of the frame colliders on that side: a vertex more than PROUD_TOL_M beyond its face fails.
## (2) narrowing: at y 0.15 / 0.5 / 0.7 / 1.5 / 2.0 m (within the leaf, clear of hinge knuckles), the leaf's own span at that
##     height (closed leaf triangles cut by the plane) is the clear opening; rays from its middle
##     outward along +-X on the wall line and near both wall faces, against the frame colliders only:
##     a collider face more than NARROW_TOL_M inside the leaf span fails.
class_name LcCheckFrameProud
extends LcCheck

const PROUD_TOL_M: float = 0.01
const NARROW_TOL_M: float = 0.01
const WALL_REACH_M: float = 1.0
const FACE_YS: Array[float] = [0.3, 1.0, 1.6]
## Clear of hinge knuckles (0.25 / 1.05 / 1.85 m +-0.06), which reach past the leaf edge into the lining.
const NARROW_YS: Array[float] = [0.15, 0.5, 0.7, 1.5, 2.0]
const LEAF_NAMES: Array[String] = ["Leaf", "Leaf2"]
## Float slack: a collider exactly at the tolerance (greybox frames 1 cm proud) passes.
const EPS_M: float = 0.0005

var _checked: int = 0
var _with_colliders: int = 0
var _worst_proud: float = 0.0
var _worst_narrow: float = 0.0


func _init() -> void:
	id = &"frame_proud"
	title = "Door / window frame colliders are flush with the wall (no proud or narrowing collision)"


func run(ctx: LcContext) -> void:
	var items: Array[GameplayPrefab] = []
	for n: Node in ctx.map.find_children("*", "", true, false):
		var pf: GameplayPrefab = n as GameplayPrefab
		if pf != null and (pf is Door or pf is WindowPrefab) and ctx.is_active(pf) and pf.visual_root != null:
			items.append(pf)
	if items.is_empty():
		note("no door or window prefabs")
		return
	var saved: Array[Array] = []
	for it: GameplayPrefab in items:
		if it is Door:
			for ln: String in LEAF_NAMES:
				var leaf: Node3D = it.visual_node(ln) as Node3D
				if leaf != null:
					saved.append([leaf, leaf.rotation])
					leaf.rotation = Vector3(leaf.rotation.x, 0.0, leaf.rotation.z)
	await ctx.await_sync(1)
	for it2: GameplayPrefab in items:
		_check_item(ctx, it2)
	for s: Array in saved:
		(s[0] as Node3D).rotation = s[1]
	note(("%d door / window prefab(s), %d with frame colliders; proud > %.2f m and narrowing > %.2f m fail; "
		+ "worst proud %.3f m, narrowing %.3f m")
		% [_checked, _with_colliders, PROUD_TOL_M, NARROW_TOL_M, _worst_proud, _worst_narrow])


static func _leaves(it: GameplayPrefab) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if it is Door:
		for ln: String in LEAF_NAMES:
			var l: Node3D = it.visual_node(ln) as Node3D
			if l != null:
				out.append(l)
	return out


static func _in_any(n: Node, roots: Array[Node3D]) -> bool:
	for r: Node3D in roots:
		if r.is_ancestor_of(n):
			return true
	return false


## Frame collision shapes: CollisionShape3Ds under the visual root, outside the leaves, enabled.
static func frame_shapes(it: GameplayPrefab, leaves: Array[Node3D]) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for n: Node in it.visual_root.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		if cs.disabled or cs.shape == null or _in_any(cs, leaves) or not (cs.get_parent() is CollisionObject3D):
			continue
		out.append(cs)
	return out


## Shape vertices in the shape's local space.
static func shape_points(shape: Shape3D) -> PackedVector3Array:
	if shape is ConcavePolygonShape3D:
		return (shape as ConcavePolygonShape3D).get_faces()
	if shape is ConvexPolygonShape3D:
		return (shape as ConvexPolygonShape3D).points
	if shape is BoxShape3D:
		var h: Vector3 = (shape as BoxShape3D).size * 0.5
		var pts: PackedVector3Array = PackedVector3Array()
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					pts.append(Vector3(sx * h.x, sy * h.y, sz * h.z))
		return pts
	var dm: ArrayMesh = shape.get_debug_mesh()
	if dm == null or dm.get_surface_count() == 0:
		return PackedVector3Array()
	return dm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _check_item(ctx: LcContext, it: GameplayPrefab) -> void:
	_checked += 1
	var leaves: Array[Node3D] = _leaves(it)
	var shapes: Array[CollisionShape3D] = frame_shapes(it, leaves)
	if shapes.is_empty():
		return
	_with_colliders += 1
	var xf: Transform3D = it.global_transform.orthonormalized()
	var inv: Transform3D = xf.affine_inverse()
	var pts: PackedVector3Array = PackedVector3Array()
	for cs: CollisionShape3D in shapes:
		var to_local: Transform3D = inv * cs.global_transform
		for p: Vector3 in shape_points(cs.shape):
			pts.append(to_local * p)
	if pts.is_empty():
		return
	var lo_x: float = INF
	var hi_x: float = -INF
	for p2: Vector3 in pts:
		lo_x = minf(lo_x, p2.x)
		hi_x = maxf(hi_x, p2.x)
	# reveal per side: wall collision ray from the centre outward (on the wall line and +-0.04 m)
	var edge: Array[float] = [INF, INF]
	var reach: float = maxf(absf(lo_x), absf(hi_x)) + WALL_REACH_M
	for si: int in range(2):
		var sg: float = -1.0 if si == 0 else 1.0
		for y: float in FACE_YS:
			edge[si] = minf(edge[si], _dwz(ctx, it, xf, Vector3(0.0, y, 0.0), Vector3(sg * reach, y, 0.0)))
	# wall faces beside each reveal: [side][face] distance of the face from the wall line
	var faces: Array[Array] = [[-INF, -INF], [-INF, -INF]]
	for si2: int in range(2):
		if edge[si2] == INF:
			continue
		var x: float = (-1.0 if si2 == 0 else 1.0) * (edge[si2] + 0.03)
		for fi: int in range(2):
			var dz: float = -1.0 if fi == 0 else 1.0
			for y2: float in FACE_YS:
				var t: float = _dw(ctx, it, xf, Vector3(x, y2, dz * WALL_REACH_M), Vector3(x, y2, 0.0))
				if t != INF:
					faces[si2][fi] = maxf(faces[si2][fi], WALL_REACH_M - t)
	var reported: Dictionary = {}
	for p3: Vector3 in pts:
		var si3: int = 0 if p3.x < 0.0 else 1
		var fi3: int = 0 if p3.z < 0.0 else 1
		var face: float = faces[si3][fi3]
		if face == -INF:
			face = faces[1 - si3][fi3]
		if face == -INF:
			continue
		var proud: float = absf(p3.z) - face
		_worst_proud = maxf(_worst_proud, proud)
		if proud > PROUD_TOL_M + EPS_M:
			var key: String = "%d%d" % [si3, fi3]
			if not reported.has(key) or float((reported[key] as Array)[0]) < proud:
				reported[key] = [proud, p3, face]
	var keys: Array = reported.keys()
	keys.sort()
	for k: Variant in keys:
		var r: Array = reported[k]
		var sk: String = String(k)
		fail(ctx, it, xf * (r[1] as Vector3), ("frame collider stands %.3f m proud of the %s wall face beside the %s jamb "
			+ "(collider %.3f m from the wall line vs wall face %.3f m; > %.2f m): collision must be flush, trim is visual only")
			% [float(r[0]), "-Z" if sk[1] == "0" else "+Z", "-X" if sk[0] == "0" else "+X",
			absf((r[1] as Vector3).z), float(r[2]), PROUD_TOL_M])
	if leaves.is_empty():
		return
	_check_narrowing(ctx, it, xf, inv, leaves, shapes, faces)


func _check_narrowing(ctx: LcContext, it: GameplayPrefab, xf: Transform3D, inv: Transform3D, leaves: Array[Node3D],
		shapes: Array[CollisionShape3D], faces: Array[Array]) -> void:
	var half: float = 0.0
	for side: Array in faces:
		for f: float in side:
			half = maxf(half, f)
	if half <= 0.0:
		half = 0.1
	var zs: Array[float] = [0.0, -(half - 0.005), half - 0.005]
	var bodies: Array[Node] = []
	for cs: CollisionShape3D in shapes:
		bodies.append(cs.get_parent())
	var worst: Array = [0.0, Vector3.ZERO, ""]
	for y: float in NARROW_YS:
		var span: Vector2 = _leaf_span(ctx, inv, leaves, y)
		if span.x == INF:
			continue
		var cx: float = (span.x + span.y) * 0.5
		for z: float in zs:
			for si: int in range(2):
				var sg: float = -1.0 if si == 0 else 1.0
				var leaf_x: float = span.x if si == 0 else span.y
				var a: Vector3 = Vector3(cx, y, z)
				var b: Vector3 = Vector3(cx + sg * (absf(leaf_x - cx) + 1.0), y, z)
				var hit: Dictionary = ctx.ray(xf * a, xf * b, func(h: Dictionary) -> bool:
					return h.get("collider") in bodies)
				if hit.is_empty():
					continue
				var hx: float = (inv * (hit["position"] as Vector3)).x
				var narrow: float = sg * (leaf_x - hx)
				_worst_narrow = maxf(_worst_narrow, narrow)
				if narrow > NARROW_TOL_M + EPS_M and narrow > float(worst[0]):
					worst = [narrow, Vector3(hx, y, z), "%s jamb at y %.2f, z %.2f" % ["-X" if si == 0 else "+X", y, z]]
	if float(worst[0]) > 0.0:
		fail(ctx, it, xf * (worst[1] as Vector3),
			"frame collider narrows the clear opening by %.3f m at the %s (inside the closed leaf's span; > %.2f m)"
			% [float(worst[0]), worst[2], NARROW_TOL_M])


## X span (prefab-local) of the closed leaves' triangles cut by the plane y; Vector2(INF, -INF) if none.
static func _leaf_span(ctx: LcContext, inv: Transform3D, leaves: Array[Node3D], y: float) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for l: Node3D in leaves:
		for n: Node in l.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var m: Transform3D = inv * mi.global_transform
			for s: int in range(mi.mesh.get_surface_count()):
				var v: PackedVector3Array = LcVisual.triangles(ctx, mi.mesh, s)["v"]
				for t: int in range(0, v.size() - 2, 3):
					var tri: Array[Vector3] = [m * v[t], m * v[t + 1], m * v[t + 2]]
					for e: int in range(3):
						var p: Vector3 = tri[e]
						var q: Vector3 = tri[(e + 1) % 3]
						if (p.y - y) * (q.y - y) > 0.0 or p.y == q.y:
							continue
						var x: float = lerpf(p.x, q.x, (y - p.y) / (q.y - p.y))
						lo = minf(lo, x)
						hi = maxf(hi, x)
	return Vector2(lo, hi)


## Distance along local a->b to the first wall collision hit (shell, not this prefab), or INF.
static func _dw(ctx: LcContext, it: GameplayPrefab, xf: Transform3D, a: Vector3, b: Vector3) -> float:
	var hit: Dictionary = ctx.ray(xf * a, xf * b, func(h: Dictionary) -> bool:
		var col: Node = h.get("collider") as Node
		return col != null and not it.is_ancestor_of(col) and ctx.accept_shell(h) and _same_slot_ok(it, col))
	return INF if hit.is_empty() else (xf * a).distance_to(hit["position"])


static func _dwz(ctx: LcContext, it: GameplayPrefab, xf: Transform3D, a: Vector3, b: Vector3) -> float:
	var off: Vector3 = Vector3(0.0, 0.0, 0.04)
	return minf(_dw(ctx, it, xf, a, b), minf(_dw(ctx, it, xf, a - off, b - off), _dw(ctx, it, xf, a + off, b + off)))


## False when `n` lies in a different slot of the same variant group as `it`.
static func _same_slot_ok(it: Node, n: Node) -> bool:
	var mine: VariantSlot = LcUtil.slot_of(it)
	var theirs: VariantSlot = LcUtil.slot_of(n)
	return not (mine != null and theirs != null and mine != theirs and mine.get_parent() == theirs.get_parent())
