## Gap measuring helpers for door_frame_gap and seam_gaps (PO-7). Owner: ENV C.
## Visual proxies tagged with their source node, source classification (an opening prefab's own
## visual, its leaves, the building shell) and see-through scan lines with bisection-refined runs.
class_name LcGaps
extends RefCounted

## Meta on each proxy body: the GeometryInstance3D it mirrors.
const META_SRC: StringName = &"lc_gap_src"
## Bisection steps that refine a run edge between a closed and an open sample (step / 2^n).
const REFINE_STEPS: int = 6


## Single-sided trimesh proxies (LcContext.PROXY_LAYER) of every visible render piece whose world
## AABB touches one of `regions` (all pieces when empty). Each body carries META_SRC.
static func build_proxies(ctx: LcContext, regions: Array[AABB]) -> void:
	LcVisual.free_proxies(ctx)
	ctx.proxy_root = Node3D.new()
	ctx.proxy_root.name = "_LcGapProxies"
	ctx.map.add_child(ctx.proxy_root)
	for piece: Dictionary in LcVisual.render_pieces(ctx):
		var mesh: Mesh = piece["mesh"]
		var xf: Transform3D = piece["xf"]
		if not regions.is_empty() and not _touches(xf * mesh.get_aabb(), regions):
			continue
		var mats: Array = piece["materials"]
		for s: int in range(mesh.get_surface_count()):
			var tri: Dictionary = LcVisual.triangles(ctx, mesh, s)
			var v: PackedVector3Array = tri["v"]
			if v.is_empty():
				continue
			var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
			shape.set_faces(v)
			var bm: BaseMaterial3D = mats[s] as BaseMaterial3D if s < mats.size() else null
			shape.backface_collision = bm != null and bm.cull_mode == BaseMaterial3D.CULL_DISABLED
			var body: StaticBody3D = StaticBody3D.new()
			body.collision_layer = LcContext.PROXY_LAYER
			body.collision_mask = 0
			body.set_meta(META_SRC, piece["node"])
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			ctx.proxy_root.add_child(body)
			body.global_transform = xf
	await ctx.await_sync(2)


static func _touches(box: AABB, regions: Array[AABB]) -> bool:
	for r: AABB in regions:
		if r.intersects(box):
			return true
	return false


## Source GeometryInstance3D of a proxy hit (or null).
static func src_of(hit: Dictionary) -> Node:
	var col: Object = hit.get("collider")
	if col == null or not (col as Node).has_meta(META_SRC):
		return null
	return (col as Node).get_meta(META_SRC) as Node


## Nearest GameplayPrefab ancestor of `n` (or null).
static func prefab_of(n: Node, stop: Node) -> GameplayPrefab:
	var cur: Node = n
	while cur != null and cur != stop:
		if cur is GameplayPrefab:
			return cur as GameplayPrefab
		cur = cur.get_parent()
	return null


## True when `src` is part of the building as seen through an opening: shell geometry (not a
## prop), or the visual of a door / window / stair prop. Attachments (padlocks, drill points,
## keypads) and dressing are ignored, as are nodes inside an inactive variant slot.
static func is_shell(ctx: LcContext, src: Node) -> bool:
	if src == null or not ctx.is_active(src):
		return false
	var p: LcProp = ctx.prop_of(src)
	if p == null:
		return true
	if p.kind == LcContext.SHUTTER_KIND or not (p.is_door or p.is_window or p.kind in LcContext.SHELL_KINDS):
		return false
	var pf: GameplayPrefab = prefab_of(src, ctx.map)
	if pf == null:
		return true
	if not (pf is Door or pf is WindowPrefab):
		return false
	return pf.visual_root != null and pf.visual_root.is_ancestor_of(src)


## Proxy ray from `a` to `b` accepting only hits whose source passes `accept(src) -> bool`.
static func ray(ctx: LcContext, a: Vector3, b: Vector3, accept: Callable) -> Dictionary:
	return ctx.ray(a, b, func(hit: Dictionary) -> bool: return bool(accept.call(src_of(hit))), LcContext.PROXY_LAYER)


## Distance from `a` along a->b to the first accepted hit, or INF.
static func dist(ctx: LcContext, a: Vector3, b: Vector3, accept: Callable) -> float:
	var hit: Dictionary = ray(ctx, a, b, accept)
	if hit.is_empty():
		return INF
	return a.distance_to(hit["position"])


## Open runs of a scan line. `open_at(t) -> bool` is sampled every `step` over [t0, t1]; each run
## edge between a closed and an open sample is refined by bisection. Returns
## [{ "a": float, "b": float, "lo_end": bool, "hi_end": bool }] (lo_end / hi_end: the run reaches
## the scan line's end, so its true extent is unknown).
static func open_runs(open_at: Callable, t0: float, t1: float, step: float) -> Array[Dictionary]:
	var n: int = maxi(1, ceili((t1 - t0) / step - 1e-6))
	var ts: PackedFloat32Array = PackedFloat32Array()
	var open: Array[bool] = []
	for i: int in range(n + 1):
		var t: float = minf(t0 + float(i) * step, t1)
		ts.append(t)
		open.append(bool(open_at.call(t)))
	var out: Array[Dictionary] = []
	var i2: int = 0
	while i2 <= n:
		if not open[i2]:
			i2 += 1
			continue
		var j: int = i2
		while j + 1 <= n and open[j + 1]:
			j += 1
		var a: float = ts[i2] if i2 == 0 else _edge(open_at, ts[i2 - 1], ts[i2])
		var b: float = ts[j] if j == n else _edge(open_at, ts[j + 1], ts[j])
		out.append({"a": a, "b": b, "lo_end": i2 == 0, "hi_end": j == n})
		i2 = j + 1
	return out


## Bisects between a closed sample `closed_t` and an open sample `open_t`; returns the boundary.
static func _edge(open_at: Callable, closed_t: float, open_t: float) -> float:
	var c: float = closed_t
	var o: float = open_t
	for k: int in range(REFINE_STEPS):
		var m: float = (c + o) * 0.5
		if bool(open_at.call(m)):
			o = m
		else:
			c = m
	return (c + o) * 0.5
