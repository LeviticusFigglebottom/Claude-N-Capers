## Stair handrails / guards (level_standards §2, lead ruling): per flight (`kind = "stairs"`).
## Samples 5 handrail stations along the flight between its bottom and top riser lines, keeping
## 0.3 m clear of both ends (a taller landing divider or newel there must not mask the sloped
## rail). The nosing line is the real one: top of the first riser (first tread nosing) to the top
## of the last riser, from the visual step profile.
## At each station and side (flight-local -X / +X), from 0.25 m inside the flight edge, horizontal
## collision rays run outward at heights above the nosing line; only hits within 0.35 m beyond the
## edge count (walls / guards stand at the edge, not across a well). A railing/handrail prop
## (meta kind railing/handrail, with or without collision) counts as a hit where its box is.
##  * wall: hits at both 0.3 m and 1.5 m above the nosing line;
##  * rail top: highest hit in 0.5..1.25 m (every 0.025 m) on the *nearest* barrier (hits within
##    0.08 m of the closest one) that stands >= 0.03 m proud of the wall plane (any hit when there
##    is no wall);
##  * drop: on a side without a wall, ray down 0.1 m outside the edge (0 if that point is inside
##    a solid); drop > 0.6 m = open edge.
## Rules: (a) handrail, judged on >= 80% of the 5 stations: one side at least has a rail (wall side
## 0.85-1.1 m, open side 1.0-1.1 m above the nosing line); (b) guards, zero tolerance: on a dense
## pass (a station every <= 0.2 m along the flight, so a 0.5 m gap cannot slip between stations)
## every station on an open side with a drop > 0.6 m must have a guard whose top is >= 1.0 m
## (taller barriers protect too; the 1.0-1.1 m grip band applies to the handrail rule only).
## Barrier tops are scanned every 0.025 m and refined by bisection to < 1 mm.
## Rails therefore need collision, or a railing/handrail `kind` meta.
class_name LcStairRails
extends RefCounted

const STATIONS: int = 5
## Handrail stations keep this far from the flight ends along the run (m).
const END_CLEAR: float = 0.3
const INSET: float = 0.25
const REACH: float = 0.6
## Guards/walls must stand within this distance beyond the flight edge (m).
const ZONE: float = 0.35
## Drop is measured this far beyond the edge (m).
const DROP_OUT: float = 0.1
## Hits within this distance of the nearest one belong to the same barrier (m).
const NEAR_BAND: float = 0.08
const WALL_LOW: float = 0.3
const WALL_HIGH: float = 1.5
const SCAN_LO: float = 0.5
const SCAN_HI: float = 1.25
const SCAN_STEP: float = 0.025
const PROUD: float = 0.03
const RAIL_GUARD: Vector2 = Vector2(1.0, 1.1)
const RAIL_WALL: Vector2 = Vector2(0.85, 1.1)
const HEIGHT_TOL: float = 0.02
const OPEN_DROP: float = 0.6
const MAJORITY: float = 0.8
## Max spacing of the dense guard stations along the flight (m).
const GUARD_SPACING: float = 0.2
const RAIL_KINDS: Array[StringName] = [&"railing", &"handrail"]

var notes: PackedStringArray = PackedStringArray()


## Returns failure messages for this flight. lo/hi: flight-local (x, nosing height, z) of the
## first and last riser lines (height = absolute y of the first / last riser top).
func check(ctx: LcContext, st: Node3D, xf: Transform3D, local: AABB, lo: Vector3, hi: Vector3) -> PackedStringArray:
	var fails: PackedStringArray = PackedStringArray()
	# Railing/handrail nodes anywhere in the map (Geometry included, where props are not collected):
	# their geometry box as an OBB.
	var rail_props: Array[Dictionary] = []
	for n: Node in ctx.map.find_children("*", "Node3D", true, false):
		if LcUtil.meta_s(n, &"kind") in RAIL_KINDS and ctx.is_active(n):
			var box: Variant = LcCheckClipping._leaf_box(n as Node3D)
			if box is AABB:
				rail_props.append(LcGeom.obb((n as Node3D).global_transform, box as AABB))
	var summary: Dictionary = {}
	var railed_sides: int = 0
	for side: float in [-1.0, 1.0]:
		var sname: String = "-X" if side < 0.0 else "+X"
		var walls: int = 0
		var good_rail: int = 0
		var open_unguarded: int = 0
		var open_n: int = 0
		var tops: PackedStringArray = PackedStringArray()
		var max_drop: float = 0.0
		var worst: float = 0.0
		var where: PackedStringArray = PackedStringArray()
		var run: float = absf(hi.z - lo.z)
		var f0: float = clampf(END_CLEAR / maxf(run, 0.001), 0.0, 0.45)
		for k: int in range(STATIONS):
			var f: float = lerpf(f0, 1.0 - f0, (float(k) + 0.5) / float(STATIONS))
			var z: float = lerpf(lo.z, hi.z, f)
			var nose_y: float = lerpf(lo.y, hi.y, f)
			var edge: float = local.position.x if side < 0.0 else local.end.x
			var st_res: Dictionary = _station(ctx, st, xf, edge, side, z, nose_y, rail_props)
			var wall: bool = st_res["wall"]
			var top: float = st_res["top"]
			if wall:
				walls += 1
			tops.append("-" if top < 0.0 else "%.2f" % top)
			var rng: Vector2 = RAIL_WALL if wall else RAIL_GUARD
			var rail_ok: bool = top >= rng.x - HEIGHT_TOL and top <= rng.y + HEIGHT_TOL
			if rail_ok:
				good_rail += 1
			if not wall:
				max_drop = maxf(max_drop, float(st_res["drop"]))
		# (b) zero-tolerance guard pass on dense stations.
		var n_dense: int = maxi(STATIONS, ceili(absf(hi.z - lo.z) / GUARD_SPACING) + 1)
		for k2: int in range(n_dense):
			var f2: float = (float(k2) + 0.5) / float(n_dense)
			var edge2: float = local.position.x if side < 0.0 else local.end.x
			var r2: Dictionary = _station(ctx, st, xf, edge2, side, lerpf(lo.z, hi.z, f2), lerpf(lo.y, hi.y, f2), rail_props)
			var d2: float = r2["drop"]
			var t2: float = r2["top"]
			if not bool(r2["wall"]) and d2 > OPEN_DROP:
				max_drop = maxf(max_drop, d2)
				open_n += 1
				if t2 < RAIL_GUARD.x - HEIGHT_TOL:
					open_unguarded += 1
					worst = maxf(worst, d2)
					var wp: Vector3 = xf * Vector3(edge2, 0.0, lerpf(lo.z, hi.z, f2))
					wp.y = lerpf(lo.y, hi.y, f2)
					where.append("%s (drop %.2f, top %s)" % [LcCheck.fmt_v(wp), d2, "-" if t2 < 0.0 else "%.2f" % t2])
		var need: int = ceili(MAJORITY * STATIONS)
		if good_rail >= need:
			railed_sides += 1
		var kind: String = "wall" if walls >= need else ("open" if walls == 0 else "partly walled")
		summary[sname] = "%s, rail tops [%s] m above nosing, max drop %.2f m" % [kind, ", ".join(tops), max_drop]
		if open_unguarded > 0:
			fails.append(("%s side: open edge unguarded at %d of %d stations (drop up to %.2f m > %.1f m) without a "
				+ ">= %.1f m guard (rail tops [%s] m above the nosing line); at %s")
				% [sname, open_unguarded, n_dense, worst, OPEN_DROP, RAIL_GUARD.x, ", ".join(tops),
					", ".join(where.slice(0, 3))])
	notes.append("`%s` rails: -X %s; +X %s" % [ctx.node_path(st), summary["-X"], summary["+X"]])
	if railed_sides == 0:
		fails.append("no handrail/railing on either side (wall handrail 0.85-1.1 m, railing 1.0-1.1 m above the nosing line): -X %s; +X %s"
			% [summary["-X"], summary["+X"]])
	return fails


func _station(ctx: LcContext, st: Node3D, xf: Transform3D, edge: float, side: float, z: float, nose_y: float,
		rail_props: Array[Dictionary]) -> Dictionary:
	var out_dir: Vector3 = (xf.basis.x * side).normalized()
	var base: Vector3 = xf * Vector3(edge - side * INSET, 0.0, z)
	base.y = nose_y
	var not_flight: Callable = func(h: Dictionary) -> bool:
		var c: Node = h.get("collider") as Node
		return c == null or (not (c == st or st.is_ancestor_of(c)) and ctx.is_active(c))
	var dist: Callable = func(h: float) -> float:
		var a: Vector3 = base + Vector3.UP * h
		var best: float = INF
		var r: Dictionary = ctx.ray(a, a + out_dir * (INSET + REACH), not_flight)
		if not r.is_empty():
			best = a.distance_to(r["position"])
		for ob: Dictionary in rail_props:
			for t: float in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]:
				var q: Vector3 = a + out_dir * t
				if t < best and LcGeom.point_in_obb(q, ob, 0.003):
					best = t
					break
		return best
	var zone: float = INSET + ZONE
	var d_low: float = dist.call(WALL_LOW)
	var d_high: float = dist.call(WALL_HIGH)
	var wall: bool = d_low <= zone and d_high <= zone
	var wall_d: float = minf(d_low, d_high) if wall else INF
	# Rail top = top of the *nearest* barrier in the zone (a neighbouring flight's rail or a higher
	# step further out must not stand in for this edge's guard).
	var hits: Array[Vector2] = []
	var near: float = INF
	var h: float = SCAN_LO
	while h <= SCAN_HI + 0.0001:
		var d: float = dist.call(h)
		if d <= zone and (not wall or d < wall_d - PROUD):
			hits.append(Vector2(h, d))
			near = minf(near, d)
		h += SCAN_STEP
	var top: float = -1.0
	for hd: Vector2 in hits:
		if hd.y <= near + NEAR_BAND:
			top = maxf(top, hd.x)
	# Refine the top between the last hit and the next scan height (bisection, < 1 mm).
	if top > 0.0 and top + SCAN_STEP <= SCAN_HI + 0.0001:
		var a: float = top
		var b: float = top + SCAN_STEP
		for i: int in range(5):
			var m: float = (a + b) * 0.5
			var dm: float = dist.call(m)
			if dm <= near + NEAR_BAND and (not wall or dm < wall_d - PROUD):
				a = m
			else:
				b = m
		top = a
	var drop: float = 0.0
	if not wall:
		var o: Vector3 = base + out_dir * (INSET + DROP_OUT) + Vector3.UP * 0.2
		var pq: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
		pq.position = o
		pq.collision_mask = LcContext.QUERY_MASK
		if ctx.space().intersect_point(pq, 1).is_empty():
			var r2: Dictionary = ctx.ray(o, o + Vector3.DOWN * 20.0, ctx.accept_any_active)
			drop = 20.0 if r2.is_empty() else maxf(0.0, nose_y - (r2["position"] as Vector3).y)
	return {"wall": wall, "top": top, "drop": drop}
