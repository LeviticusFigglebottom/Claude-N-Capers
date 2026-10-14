## door_frame_gap (all stages, PO-7): every Door and WindowPrefab instance must close its wall
## opening without visible gaps or clipping. Measured in the prefab's local space (origin at the
## bottom-centre of the opening on the wall line, -Z front), leaves closed (rotation 0). The prefab's
## own visual and the building shell's visual are single-sided proxies of the render meshes
## (LcGaps); dressing, attachments (padlocks, drill points) and sibling variant slots are ignored.
## (1) opening: a visual shell ray along Z through the opening centre must not hit within 0.35 m
##     of the wall line ("sits in no wall opening"). Wall *collision* rays (on the wall line and
##     +-0.04 m off it) from the centre along +-X, up and (windows) down find the reveals, head and
##     sill; no wall within 1 m on a side fails ("no wall beside").
## (2) frame vs opening: rays from inside the wall toward the opening, against the frame only, find
##     the frame's outer faces. Opening wider / taller than the frame by > 0.02 m fails (gap); the
##     frame reaching > 0.01 m past a reveal fails (clips into the wall).
## (3) trim: just outside the reveal, the frame face that meets the wall (ray from the wall line
##     outward) must lie on the wall face: buried > 0.01 m fails, standing off > 0.02 m fails.
## (4) leaves (doors): at the leaf plane, leaf to jamb on both sides (y 0.5 and 1.5 m, clear of
##     hinges and levers), leaf to head, leaf to leaf (doubles), leaf to sill / floor; > 0.02 m fails.
## (5) see-through: scan lines (horizontal and vertical, every 0.2 m; 0.01 m samples, bisection-
##     refined edges) over the opening (reveals, head, sill) + 0.05 m, cast along Z through the wall
##     zone both ways. An open run 0.02-0.3 m wide, bounded by solid on both ends and as wide across
##     (so a curved gap is measured fairly), fails, except inside a leaf's own outline (grilles).
## (6) WARN (D-105): a door whose leaves look glass / metal (surface_map.json `props` override for
##     the visual, else the leaf materials' area vote through SurfaceTags) but whose
##     Door.leaf_surface_id() resolves to wood. Counts per surface go to the report notes.
class_name LcCheckDoorFrameGap
extends LcCheck

const GAP_TOL_M: float = 0.02
const CLIP_TOL_M: float = 0.01
const SCAN_STEP_M: float = 0.01
const SCAN_MARGIN_M: float = 0.05
const SCAN_SPACING_M: float = 0.2
## Open runs wider than this are openings in their own right (another doorway, a pass).
const SLIT_MAX_M: float = 0.3
const WALL_REACH_M: float = 1.0
## Shell hits closer than this to the wall line, through the opening centre: no opening.
const THROUGH_M: float = 0.35
const LEAF_YS: Array[float] = [0.5, 1.5]
const LEAF_NAMES: Array[String] = ["Leaf", "Leaf2"]

var _checked: int = 0
## Door leaf surfaces: surface id -> count, and doors whose leaves look glass / metal but resolve to wood.
var _surfaces: Dictionary = {}
var _wood_mismatch: int = 0


func _init() -> void:
	id = &"door_frame_gap"
	title = "Doors and windows fill their wall openings (no gaps, no clipping)"


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
	var regions: Array[AABB] = []
	for it: GameplayPrefab in items:
		if it is Door:
			for ln: String in LEAF_NAMES:
				var leaf: Node3D = it.visual_node(ln) as Node3D
				if leaf != null:
					saved.append([leaf, leaf.rotation])
					leaf.rotation = Vector3(leaf.rotation.x, 0.0, leaf.rotation.z)
		var box: Variant = _box(it, it.visual_root, [])
		if box is AABB:
			regions.append((it.global_transform * (box as AABB)).grow(WALL_REACH_M + 0.5))
	await LcGaps.build_proxies(ctx, regions)
	for it2: GameplayPrefab in items:
		_check_item(ctx, it2)
		if it2 is Door:
			_check_leaf_surface(ctx, it2 as Door)
	LcVisual.free_proxies(ctx)
	for s: Array in saved:
		(s[0] as Node3D).rotation = s[1]
	note("%d door / window prefab(s) measured; gap > %.2f m and clip > %.2f m fail" % [_checked, GAP_TOL_M, CLIP_TOL_M])
	note("leaf bullet surfaces (D-105, Door.leaf_surface_id): %s; %d look glass / metal but resolve to wood (WARN)"
		% [_surface_counts(), _wood_mismatch])


## D-105 leaf surface: WARN when the leaves *look* glass / metal (the visual's asset override in
## surface_map.json `props`, else the triangle-area vote of the leaf meshes' materials through
## SurfaceTags) but `Door.leaf_surface_id()` resolves to wood (bullets would chip and splinter).
func _check_leaf_surface(ctx: LcContext, door: Door) -> void:
	var sid: StringName = door.leaf_surface_id()
	_surfaces[sid] = int(_surfaces.get(sid, 0)) + 1
	var looks: StringName = leaf_look(ctx, door)
	if sid == Door.SURFACE_WOOD and (looks == Door.SURFACE_GLASS or looks == Door.SURFACE_METAL):
		_wood_mismatch += 1
		warn(ctx, door, null, "leaf looks %s but its bullet surface resolves to wood: set `leaf_surface = &\"%s\"`"
			% [looks, looks])


## The surface a door's leaves look like (see _check_leaf_surface), or &"" when unknown.
static func leaf_look(ctx: LcContext, door: Door) -> StringName:
	var asset: String = door.visual_scene.resource_path.get_file().get_basename() if door.visual_scene != null else ""
	var over: Dictionary = SurfaceTags.table().get("props", {})
	if asset != "" and over.has(asset):
		return StringName(over[asset])
	var votes: Dictionary = {}
	for ln: String in LEAF_NAMES:
		var leaf: Node = door.visual_node(ln)
		if leaf == null:
			continue
		for n: Node in leaf.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue
			for si: int in range(mi.mesh.get_surface_count()):
				var surf: StringName = SurfaceTags.for_material(mi.get_active_material(si))
				if surf == &"":
					continue
				var v: PackedVector3Array = LcVisual.triangles(ctx, mi.mesh, si)["v"]
				var area: float = 0.0
				for t: int in range(0, v.size() - 2, 3):
					area += (v[t + 1] - v[t]).cross(v[t + 2] - v[t]).length() * 0.5
				votes[surf] = float(votes.get(surf, 0.0)) + area
	var best: StringName = &""
	var best_a: float = 0.0
	var keys: Array = votes.keys()
	keys.sort()
	for k: Variant in keys:
		if float(votes[k]) > best_a:
			best_a = float(votes[k])
			best = StringName(k)
	return best


func _surface_counts() -> String:
	var keys: Array = _surfaces.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys:
		parts.append("%s %d" % [k, int(_surfaces[k])])
	return ", ".join(parts) if not parts.is_empty() else "no doors"


## Merged AABB, in `it`-local space, of the GeometryInstance3Ds under `root` that are not under
## any of `skip`; null when there are none.
static func _box(it: Node3D, root: Node, skip: Array[Node3D]) -> Variant:
	if root == null:
		return null
	var inv: Transform3D = it.global_transform.affine_inverse()
	var out: Variant = null
	for c: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = c as GeometryInstance3D
		if not gi.is_visible_in_tree() or skip.any(func(s: Node3D) -> bool: return s.is_ancestor_of(gi)):
			continue
		var b: Variant = LcVisual.geometry_local_aabb(gi)
		if not (b is AABB):
			continue
		var rel: AABB = (inv * gi.global_transform) * (b as AABB)
		out = rel if out == null else (out as AABB).merge(rel)
	return out


func _check_item(ctx: LcContext, it: GameplayPrefab) -> void:
	var vis: Variant = _box(it, it.visual_root, [])
	if not (vis is AABB):
		return
	_checked += 1
	var f: _Measure = _Measure.new(ctx, it, vis as AABB)
	var what: String = "door" if it is Door else "window"
	# (1) opening
	if f.through_z != INF:
		fail(ctx, it, f.world(Vector3(0.0, f.ys[1], f.through_z)),
			"%s sits in no wall opening: shell geometry crosses the opening %.2f m from the wall line" % [what, absf(f.through_z - f.zc)])
		return
	if f.edge[0] == INF and f.edge[1] == INF and f.head == INF:
		fail(ctx, it, null, "%s sits in no wall opening: no wall within %.1f m of its frame" % [what, WALL_REACH_M])
		return
	for si: int in range(2):
		if f.edge[si] == INF:
			fail(ctx, it, f.world(Vector3(f.sgn(si) * f.vis.end.x, f.ys[1], f.zc)),
				"no wall beside the %s on its %s side (open reveal within %.1f m)" % [what, f.side(si), WALL_REACH_M])
	# (2) frame vs opening, (3) architraves
	for r: Dictionary in f.frame_results:
		if r["gap"] > GAP_TOL_M:
			fail(ctx, it, f.world(r["at"]), "frame-wall gap %.3f m at the %s (opening %.3f m from centre, frame %.3f m; > %.2f m)"
				% [r["gap"], r["where"], r["open"], r["frame"], GAP_TOL_M])
		elif -r["gap"] > CLIP_TOL_M:
			fail(ctx, it, f.world(r["at"]), "frame clips %.3f m into the wall at the %s (opening %.3f m from centre, frame %.3f m; > %.2f m)"
				% [-r["gap"], r["where"], r["open"], r["frame"], CLIP_TOL_M])
	for a: Dictionary in f.arch_results:
		if a["off"] < -CLIP_TOL_M:
			fail(ctx, it, f.world(a["at"]), "frame trim buried %.3f m inside the %s wall face at the %s (frame %.3f m deep vs wall %.3f m)"
				% [-a["off"], a["face"], a["where"], a["frame_d"], a["wall_d"]])
		elif a["off"] > GAP_TOL_M:
			fail(ctx, it, f.world(a["at"]), "frame trim stands %.3f m off the %s wall face at the %s (gap; frame %.3f m deep vs wall %.3f m)"
				% [a["off"], a["face"], a["where"], a["frame_d"], a["wall_d"]])
	# (4) leaves
	for l: Dictionary in f.leaf_results:
		if l["gap"] > GAP_TOL_M:
			fail(ctx, it, f.world(l["at"]), "leaf gap %.3f m: %s (> %.2f m)" % [l["gap"], l["where"], GAP_TOL_M])
	# (5) see-through
	if not f.slits.is_empty():
		var worst: Dictionary = f.slits[0]
		for s: Dictionary in f.slits:
			if s["w"] > worst["w"]:
				worst = s
		fail(ctx, it, f.world(worst["at"]), "see-through gap %.3f m wide %s (%d slit run(s) > %.2f m)"
			% [worst["w"], worst["where"], f.slits.size(), GAP_TOL_M])


## All measurements of one door / window (prefab-local space).
class _Measure:
	extends RefCounted
	var ctx: LcContext
	var it: GameplayPrefab
	var xf: Transform3D
	var vis: AABB
	var frame_box: Variant = null
	var leaves: Array[Node3D] = []
	var leaf_boxes: Array[AABB] = []
	var zc: float = 0.0
	var ys: Array[float] = []
	var through_z: float = INF
	## Reveal distance from the centre line per side (0 = -X, 1 = +X), head and sill height.
	var edge: Array[float] = [INF, INF]
	var head: float = INF
	var sill: float = -INF
	var wall_face: Array[float] = [INF, INF]  # local z of the -Z and +Z wall faces beside the opening
	var frame_results: Array[Dictionary] = []
	var arch_results: Array[Dictionary] = []
	var leaf_results: Array[Dictionary] = []
	var slits: Array[Dictionary] = []
	var _zr: float = 0.3
	var _accept_shell: Callable
	var _accept_frame: Callable
	var _accept_leaf: Callable
	var _accept_surround: Callable
	var _accept_solid: Callable

	func _init(p_ctx: LcContext, p_it: GameplayPrefab, p_vis: AABB) -> void:
		ctx = p_ctx
		it = p_it
		vis = p_vis
		xf = it.global_transform.orthonormalized()
		if it is Door:
			for ln: String in LcCheckDoorFrameGap.LEAF_NAMES:
				var l: Node3D = it.visual_node(ln) as Node3D
				if l != null:
					var lb: Variant = LcCheckDoorFrameGap._box(it, l, [])
					if lb is AABB:
						leaves.append(l)
						leaf_boxes.append(lb as AABB)
		frame_box = LcCheckDoorFrameGap._box(it, it.visual_root, leaves)
		zc = ((frame_box as AABB) if frame_box is AABB else vis).get_center().z
		var h: float = vis.end.y
		var y0: float = maxf(vis.position.y, 0.0)
		ys = [y0 + (h - y0) * 0.15, y0 + (h - y0) * 0.5, y0 + (h - y0) * 0.85]
		_accept_shell = func(src: Node) -> bool:
			return src != null and not it.is_ancestor_of(src) and LcGaps.is_shell(ctx, src) and not _other_slot(src)
		_accept_frame = func(src: Node) -> bool:
			return src != null and it.visual_root.is_ancestor_of(src) and not _in_leaf(src)
		_accept_leaf = func(src: Node) -> bool:
			return src != null and _in_leaf(src)
		_accept_surround = func(src: Node) -> bool:
			return bool(_accept_frame.call(src)) or bool(_accept_shell.call(src))
		_accept_solid = func(src: Node) -> bool:
			return src != null and (it.visual_root.is_ancestor_of(src) or bool(_accept_shell.call(src)))
		_measure_opening()
		if through_z != INF or (edge[0] == INF and edge[1] == INF and head == INF):
			return
		_measure_frame()
		_measure_trim()
		if not leaves.is_empty():
			_measure_leaves()
		_scan()

	func world(p: Vector3) -> Vector3:
		return xf * p

	func sgn(si: int) -> float:
		return -1.0 if si == 0 else 1.0

	func side(si: int) -> String:
		return "-X" if si == 0 else "+X"

	func _in_leaf(src: Node) -> bool:
		for l: Node3D in leaves:
			if l.is_ancestor_of(src):
				return true
		return false

	## Distance along local a->b to the first wall *collision* hit (building shell, not this prefab,
	## not a sibling variant slot), or INF. Walls are measured on collision: merged visual shells
	## leave out faces the frame hides (soffits, sills).
	func dw(a: Vector3, b: Vector3) -> float:
		var hit: Dictionary = ctx.ray(xf * a, xf * b, func(h: Dictionary) -> bool:
			var col: Node = h.get("collider") as Node
			return col != null and not it.is_ancestor_of(col) and ctx.accept_shell(h) and not _other_slot(col))
		return INF if hit.is_empty() else (xf * a).distance_to(hit["position"])

	## dw() on the wall line and +-0.04 m off it (nearest): a ray exactly on the wall line can slip
	## between two half-thickness skins that meet there; thin glazing sits on the line itself.
	func dwz(a: Vector3, b: Vector3) -> float:
		var off: Vector3 = Vector3(0.0, 0.0, 0.04)
		return minf(dw(a, b), minf(dw(a - off, b - off), dw(a + off, b + off)))

	## True when `n` lies in a different slot of the same variant group as this prefab.
	func _other_slot(n: Node) -> bool:
		var mine: VariantSlot = LcUtil.slot_of(it)
		var theirs: VariantSlot = LcUtil.slot_of(n)
		return mine != null and theirs != null and mine != theirs and mine.get_parent() == theirs.get_parent()

	## Distance along local a->b to the first hit accepted by `acc`, or INF.
	func d(a: Vector3, b: Vector3, acc: Callable) -> float:
		return LcGaps.dist(ctx, xf * a, xf * b, acc)

	func _measure_opening() -> void:
		for dz: float in [-1.0, 1.0]:
			var a: Vector3 = Vector3(0.0, ys[1], zc + dz * 0.8)
			var t: float = d(a, Vector3(0.0, ys[1], zc - dz * 0.8), _accept_shell)
			if t != INF and absf(0.8 - t) <= LcCheckDoorFrameGap.THROUGH_M:
				through_z = zc + dz * (0.8 - t)
				return
		var reach: float = maxf(absf(vis.position.x), absf(vis.end.x)) + LcCheckDoorFrameGap.WALL_REACH_M
		for si: int in range(2):
			for y: float in ys:
				var t2: float = dwz(Vector3(0.0, y, zc), Vector3(sgn(si) * reach, y, zc))
				edge[si] = minf(edge[si], t2)
		var top: float = vis.end.y + LcCheckDoorFrameGap.WALL_REACH_M
		for x: float in _xs():
			var t3: float = dwz(Vector3(x, ys[1], zc), Vector3(x, top, zc))
			if t3 != INF:
				head = minf(head, ys[1] + t3)
		if it is WindowPrefab:
			for x2: float in _xs():
				var t4: float = dwz(Vector3(x2, ys[1], zc), Vector3(x2, vis.position.y - 1.0, zc))
				if t4 != INF:
					sill = maxf(sill, ys[1] - t4)

	## Three stations across the opening (centre and +-quarter of the visual's width).
	func _xs() -> Array[float]:
		var c: float = vis.get_center().x
		var q: float = vis.size.x * 0.25
		return [c - q, c, c + q]

	func _measure_frame() -> void:
		if not (frame_box is AABB):
			return
		for si: int in range(2):
			if edge[si] == INF:
				continue
			for y: float in ys:
				var e: float = dwz(Vector3(0.0, y, zc), Vector3(sgn(si) * (edge[si] + 1.0), y, zc))
				if e == INF:
					continue
				var from_x: float = e + 0.3
				var t: float = d(Vector3(sgn(si) * from_x, y, zc), Vector3(0.0, y, zc), _accept_frame)
				if t == INF:
					continue
				var fo: float = from_x - t
				frame_results.append({"gap": e - fo, "open": e, "frame": fo, "where": "%s jamb, y %.2f" % [side(si), y],
					"at": Vector3(sgn(si) * e, y, zc)})
		if head != INF:
			for x: float in _xs():
				var hy: float = dwz(Vector3(x, ys[1], zc), Vector3(x, head + 1.0, zc))
				if hy == INF:
					continue
				var hh: float = ys[1] + hy
				var t2: float = d(Vector3(x, hh + 0.3, zc), Vector3(x, ys[1], zc), _accept_frame)
				if t2 == INF:
					continue
				var ft: float = hh + 0.3 - t2
				frame_results.append({"gap": hh - ft, "open": hh, "frame": ft, "where": "head, x %.2f" % x,
					"at": Vector3(x, hh, zc)})
		if it is WindowPrefab and sill != -INF:
			for x2: float in _xs():
				var sy: float = dwz(Vector3(x2, ys[1], zc), Vector3(x2, sill - 1.0, zc))
				if sy == INF:
					continue
				var ss: float = ys[1] - sy
				var t3: float = d(Vector3(x2, ss - 0.3, zc), Vector3(x2, ys[1], zc), _accept_frame)
				if t3 == INF:
					continue
				var fb: float = ss - 0.3 + t3
				frame_results.append({"gap": fb - ss, "open": ss, "frame": fb, "where": "sill, x %.2f" % x2,
					"at": Vector3(x2, ss, zc)})

	## Trim (architraves) just outside the reveal: the frame face meeting the wall vs the wall face.
	func _measure_trim() -> void:
		if not (frame_box is AABB):
			return
		var fb: AABB = frame_box
		var stations: Array[Array] = []  # [point on the wall line just outside the reveal, label]
		for si: int in range(2):
			if edge[si] != INF and absf(sgn(si) * (edge[si] + 0.03)) < maxf(absf(fb.position.x), absf(fb.end.x)):
				stations.append([Vector3(sgn(si) * (edge[si] + 0.03), ys[1], zc), "%s jamb" % side(si)])
		if head != INF and head + 0.03 < fb.end.y:
			stations.append([Vector3(vis.get_center().x, head + 0.03, zc), "head"])
		for st: Array in stations:
			var p: Vector3 = st[0]
			for fi: int in range(2):
				var dz: float = -1.0 if fi == 0 else 1.0
				var out_p: Vector3 = p + Vector3(0.0, 0.0, dz * 1.0)
				var wall_t: float = dw(out_p, p)  # wall face, from outside
				var trim_t: float = d(p, out_p, _accept_frame)  # trim face meeting the wall, from inside
				if wall_t == INF or trim_t == INF:
					continue
				var wall_z: float = 1.0 - wall_t  # distance of the wall face from the wall line
				wall_face[fi] = wall_z
				var frame_d: float = absf(fb.position.z - zc) if fi == 0 else absf(fb.end.z - zc)
				arch_results.append({"off": trim_t - wall_z, "face": "-Z" if fi == 0 else "+Z", "where": st[1],
					"frame_d": frame_d * 2.0, "wall_d": wall_z * 2.0, "at": p + Vector3(0.0, 0.0, dz * wall_z)})

	func _measure_leaves() -> void:
		var lb: AABB = leaf_boxes[0]
		for b: AABB in leaf_boxes:
			lb = lb.merge(b)
		var zl: float = lb.get_center().z
		var cx: float = lb.get_center().x
		var reach: float = lb.size.x * 0.5 + 0.5
		for y: float in _leaf_ys(lb):
			for si: int in range(2):
				var tj: float = d(Vector3(cx, y, zl), Vector3(cx + sgn(si) * reach, y, zl), _accept_surround)
				if tj == INF:
					continue
				var jx: float = cx + sgn(si) * tj
				var px: float = jx - sgn(si) * 0.0005
				var tl: float = d(Vector3(px, y, zl), Vector3(cx, y, zl), _accept_leaf)
				var g: float = 0.0 if tl == INF or _leaf_at(px, y, zl) else tl + 0.0005
				leaf_results.append({"gap": g, "where": "leaf to %s jamb at y %.2f" % [side(si), y], "at": Vector3(jx, y, zl)})
			if leaf_boxes.size() == 2:
				var a0: AABB = leaf_boxes[0]
				var a1: AABB = leaf_boxes[1]
				var mid: float = ((a0.end.x + a1.position.x) * 0.5) if a0.get_center().x < a1.get_center().x \
					else ((a1.end.x + a0.position.x) * 0.5)
				var g2: float = 0.0
				for si2: int in range(2):
					var t2: float = d(Vector3(mid, y, zl), Vector3(mid + sgn(si2) * 0.5, y, zl), _accept_leaf)
					if t2 == INF:
						g2 = 0.0
						break
					g2 += t2
				leaf_results.append({"gap": g2, "where": "meeting leaves at y %.2f" % y, "at": Vector3(mid, y, zl)})
		for b2: AABB in leaf_boxes:
			var x: float = b2.get_center().x
			var th: float = d(Vector3(x, b2.get_center().y, zl), Vector3(x, b2.end.y + 0.5, zl), _accept_surround)
			if th != INF:
				var hy: float = b2.get_center().y + th
				var tl2: float = d(Vector3(x, hy - 0.0005, zl), Vector3(x, b2.get_center().y, zl), _accept_leaf)
				leaf_results.append({"gap": 0.0 if tl2 == INF or _leaf_at(x, hy - 0.0005, zl) else tl2 + 0.0005, "where": "leaf to head at x %.2f" % x,
					"at": Vector3(x, hy, zl)})
			var tf: float = d(Vector3(x, b2.get_center().y, zl), Vector3(x, b2.position.y - 0.5, zl), _accept_surround)
			if tf != INF:
				var fy: float = b2.get_center().y - tf
				var tb: float = d(Vector3(x, fy + 0.0005, zl), Vector3(x, b2.get_center().y, zl), _accept_leaf)
				var gb: float = 0.0 if tb == INF or _leaf_at(x, fy + 0.0005, zl) else tb + 0.0005
				leaf_results.append({"gap": gb, "where": "leaf to sill / floor at x %.2f" % x, "at": Vector3(x, fy, zl)})

	## True when (x, y) lies within a leaf's face (a ray along Z hits it): the leaf reaches there,
	## so a ray starting there would begin inside the leaf and miss its single-sided faces.
	func _leaf_at(x: float, y: float, zl: float) -> bool:
		return d(Vector3(x, y, zl - 0.5), Vector3(x, y, zl + 0.5), _accept_leaf) != INF \
			or d(Vector3(x, y, zl + 0.5), Vector3(x, y, zl - 0.5), _accept_leaf) != INF

	## LEAF_YS for standard leaves; for taller (industrial) leaves, the same fractions of the height.
	func _leaf_ys(lb: AABB) -> Array[float]:
		var h: float = lb.size.y
		if h < 2.4:
			return LcCheckDoorFrameGap.LEAF_YS
		return [lb.position.y + h * 0.25, lb.position.y + h * 0.7]

	func _scan() -> void:
		var half_wall: float = 0.0
		for wf: float in wall_face:
			if wf != INF:
				half_wall = maxf(half_wall, wf)
		if half_wall == 0.0:
			half_wall = 0.3
		var zr: float = minf(maxf(maxf(absf(vis.position.z - zc), absf(vis.end.z - zc)), half_wall) + 0.05, 0.6)
		_zr = zr
		var mg: float = LcCheckDoorFrameGap.SCAN_MARGIN_M
		# The door / window and its junction with the wall: up to the reveals and head (+ margin),
		# not the wall beyond (a palisade fence beside a gate is see-through by design).
		var x0: float = (-edge[0] if edge[0] != INF else vis.position.x) - mg
		var x1: float = (edge[1] if edge[1] != INF else vis.end.x) + mg
		var y0: float = maxf(vis.position.y, 0.0) + 0.05 if it is Door else (sill if sill != -INF else vis.position.y) - mg
		var y1: float = (head if head != INF else vis.end.y) + mg
		var sp: float = LcCheckDoorFrameGap.SCAN_SPACING_M
		var step: float = LcCheckDoorFrameGap.SCAN_STEP_M
		var y: float = y0
		while y <= y1 + 1e-6:
			var yy: float = y
			for r: Dictionary in LcGaps.open_runs(func(x: float) -> bool: return _open(x, yy, zr), x0, x1, step):
				_slit(r, true, yy)
			y += sp
		var x: float = x0
		while x <= x1 + 1e-6:
			var xx: float = x
			for r2: Dictionary in LcGaps.open_runs(func(t: float) -> bool: return _open(xx, t, zr), y0, y1, step):
				_slit(r2, false, xx)
			x += sp

	## Open extent through `p` across a scan line (vertical for a horizontal scan), capped.
	func _cross_extent(p: Vector3, horizontal: bool) -> float:
		var total: float = 0.0
		for dir: float in [-1.0, 1.0]:
			var closed_t: float = -1.0
			var open_t: float = 0.0
			var t: float = 0.005
			while t <= LcCheckDoorFrameGap.SLIT_MAX_M:
				if not _open_at(p, horizontal, dir * t):
					closed_t = t
					break
				open_t = t
				t += 0.005
			if closed_t < 0.0:
				return LcCheckDoorFrameGap.SLIT_MAX_M
			for k: int in range(LcGaps.REFINE_STEPS):
				var m: float = (open_t + closed_t) * 0.5
				if _open_at(p, horizontal, dir * m):
					open_t = m
				else:
					closed_t = m
			total += (open_t + closed_t) * 0.5
		return total

	func _open_at(p: Vector3, horizontal: bool, off: float) -> bool:
		return _open(p.x, p.y + off, _zr) if horizontal else _open(p.x + off, p.y, _zr)

	func _open(x: float, y: float, zr: float) -> bool:
		var a: Vector3 = xf * Vector3(x, y, zc - zr)
		var b: Vector3 = xf * Vector3(x, y, zc + zr)
		return LcGaps.ray(ctx, a, b, _accept_solid).is_empty() and LcGaps.ray(ctx, b, a, _accept_solid).is_empty()

	func _slit(r: Dictionary, horizontal: bool, fixed: float) -> void:
		if r["lo_end"] or r["hi_end"]:
			return
		var w: float = float(r["b"]) - float(r["a"])
		if w <= LcCheckDoorFrameGap.GAP_TOL_M or w > LcCheckDoorFrameGap.SLIT_MAX_M:
			return
		var c: float = (float(r["a"]) + float(r["b"])) * 0.5
		var p: Vector3 = Vector3(c, fixed, zc) if horizontal else Vector3(fixed, c, zc)
		for b: AABB in leaf_boxes:
			var inner: AABB = b.grow(-0.02)
			if p.x > inner.position.x and p.x < inner.end.x and p.y > inner.position.y and p.y < inner.end.y:
				var lo: float = inner.position.x if horizontal else inner.position.y
				var hi: float = inner.end.x if horizontal else inner.end.y
				if float(r["a"]) >= lo and float(r["b"]) <= hi:
					return  # an opening designed into the leaf (glazing bars, grille)
		# Width across the slit: a curved gap (a round vault plug in its bore) cut by a horizontal
		# line reads wider than it is, so the narrower of the two directions counts.
		w = minf(w, _cross_extent(p, horizontal))
		if w <= LcCheckDoorFrameGap.GAP_TOL_M:
			return
		var where: String = "in the frame"
		var fb: AABB = (frame_box as AABB) if frame_box is AABB else vis
		if p.x < fb.position.x or p.x > fb.end.x or p.y > fb.end.y or p.y < fb.position.y:
			where = "between the frame and the wall"
		for b2: AABB in leaf_boxes:
			if b2.grow(0.1).has_point(Vector3(p.x, p.y, b2.get_center().z)):
				where = "beside the leaf"
		slits.append({"w": w, "at": p, "where": "%s (local x %.2f, y %.2f, %s scan)" % [where, p.x, p.y,
			"horizontal" if horizontal else "vertical"]})
