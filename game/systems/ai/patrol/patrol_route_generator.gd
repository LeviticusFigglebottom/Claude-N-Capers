## Builds per-run guard patrol routes from a PatrolGraph (S5.1, heist_map.md §4). Owner: ENV A.
## Server only. Start at the tagged point nearest the spawn, random-walk the links (weighted by
## PatrolPoint.weight) on the RNG passed in (GameRng &"patrols"), close a loop back to the start
## when the graph allows it, else walk the path back and forth (ping-pong).
## Deterministic: same graph + same RNG state -> same route.
class_name PatrolRouteGenerator
extends RefCounted


## Result: {"points": Array[PatrolPoint] (unique, in walk order), "loop": bool}.
## Empty "points" when the graph has no point carrying `tag`.
static func build(graph: PatrolGraph, start_pos: Vector3, rng: RandomNumberGenerator, min_points: int,
		max_points: int, tag: StringName, attempts: int = 1) -> Dictionary:
	var pts: Array[PatrolPoint] = tagged_points(graph, tag)
	var out: Dictionary = {"points": [] as Array[PatrolPoint], "loop": false}
	if pts.is_empty():
		return out
	var adj: Dictionary = adjacency(pts)
	var start: PatrolPoint = nearest_point(pts, start_pos)
	var length: int = rng.randi_range(maxi(1, min_points), maxi(min_points, max_points))
	var best: Array[PatrolPoint] = [start]
	for _a: int in range(maxi(1, attempts)):
		var walk: Array[PatrolPoint] = _walk(start, adj, mini(min_points, length), length, rng)
		if walk.size() >= 3 and (adj[walk[-1]] as Array).has(start):
			out["points"] = walk
			out["loop"] = true
			return out
		if walk.size() > best.size():
			best = walk
	out["points"] = best
	return out


## Hub loops (OF-A6, LEAD 2026-10-20; doc ostrander_federal.md rover_dock / rover_basement (a)/(b)/(c)): from `hub`,
## walk each loop's stops in turn (shortest paths by distance over the whole graph) and back to the hub, the loops in an
## order the RNG shuffles once. `loops` = Array of Array[PatrolPoint] (stops per loop); empty = derived: one loop per
## pause point (pause_range.y > 0) reachable from the hub. Returns the cyclic visiting order starting at the hub (the
## closing hub visit dropped), or [] when nothing is reachable.
static func hub_route(graph: PatrolGraph, hub: PatrolPoint, loops: Array, rng: RandomNumberGenerator) -> Array[PatrolPoint]:
	var out: Array[PatrolPoint] = []
	if graph == null or hub == null:
		return out
	var adj: Dictionary = adjacency(tagged_points(graph, &""))
	if not adj.has(hub):
		return out
	var plan: Array = loops.duplicate()
	if plan.is_empty():
		for p: PatrolPoint in adj:
			if p != hub and p.pause_range.y > 0.0 and not _path(adj, hub, p).is_empty():
				plan.append([p])
		plan.sort_custom(func(a: Array, b: Array) -> bool: return String((a[0] as Node).name) < String((b[0] as Node).name))
	for i: int in range(plan.size() - 1, 0, -1):  # Fisher-Yates on the run's patrol stream
		var j: int = rng.randi_range(0, i)
		var t: Variant = plan[i]
		plan[i] = plan[j]
		plan[j] = t
	out.append(hub)
	for loop: Variant in plan:
		var cur: PatrolPoint = hub
		for stop: Variant in (loop as Array) + [hub]:
			var seg: Array[PatrolPoint] = _path(adj, cur, stop as PatrolPoint)
			if seg.is_empty():
				continue
			out.append_array(seg.slice(1))
			cur = stop as PatrolPoint
	if out.size() > 1 and out[-1] == hub:
		out.pop_back()
	return out if out.size() > 1 else [] as Array[PatrolPoint]


## Shortest path `a` -> `b` by link distance (Dijkstra), both ends included; [] when unreachable.
static func _path(adj: Dictionary, a: PatrolPoint, b: PatrolPoint) -> Array[PatrolPoint]:
	var dist: Dictionary = {a: 0.0}
	var prev: Dictionary = {}
	var open: Array[PatrolPoint] = [a]
	while not open.is_empty():
		var bi: int = 0
		for i: int in range(1, open.size()):
			if float(dist[open[i]]) < float(dist[open[bi]]):
				bi = i
		var u: PatrolPoint = open[bi]
		open.remove_at(bi)
		if u == b:
			break
		for v: PatrolPoint in adj[u]:
			var d: float = float(dist[u]) + u.global_position.distance_to(v.global_position)
			if not dist.has(v) or d < float(dist[v]):
				dist[v] = d
				prev[v] = u
				if not open.has(v):
					open.append(v)
	if not dist.has(b):
		return [] as Array[PatrolPoint]
	var path: Array[PatrolPoint] = [b]
	while path[0] != a:
		path.push_front(prev[path[0]] as PatrolPoint)
	return path

## Expand a route into the cyclic visiting order: loop [a,b,c] -> [a,b,c]; ping-pong [a,b,c] -> [a,b,c,b].
static func visit_order(points: Array[PatrolPoint], loop: bool) -> Array[PatrolPoint]:
	var order: Array[PatrolPoint] = points.duplicate()
	if not loop:
		for i: int in range(points.size() - 2, 0, -1):
			order.append(points[i])
	return order


static func tagged_points(graph: PatrolGraph, tag: StringName) -> Array[PatrolPoint]:
	var out: Array[PatrolPoint] = []
	if graph == null:
		return out
	for p: PatrolPoint in graph.points():
		if tag == &"" or p.tags.has(tag):
			out.append(p)
	return out


## Bidirectional adjacency restricted to `pts`: {PatrolPoint: Array[PatrolPoint]} (link order kept).
static func adjacency(pts: Array[PatrolPoint]) -> Dictionary:
	var adj: Dictionary = {}
	for p: PatrolPoint in pts:
		adj[p] = [] as Array[PatrolPoint]
	for p: PatrolPoint in pts:
		for np: NodePath in p.links:
			var q: PatrolPoint = p.get_node_or_null(np) as PatrolPoint
			if q == null or q == p or not adj.has(q):
				continue
			if not (adj[p] as Array).has(q):
				(adj[p] as Array).append(q)
			if not (adj[q] as Array).has(p):
				(adj[q] as Array).append(p)
	return adj


static func nearest_point(pts: Array[PatrolPoint], pos: Vector3) -> PatrolPoint:
	var best: PatrolPoint = null
	var best_d: float = INF
	for p: PatrolPoint in pts:
		var d: float = p.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


## Nearest graph to `pos` (by its closest point carrying `tag`) among `graphs`, within max_m.
static func nearest_graph(graphs: Array[Node], pos: Vector3, tag: StringName, max_m: float) -> PatrolGraph:
	var best: PatrolGraph = null
	var best_d: float = max_m * max_m
	for n: Node in graphs:
		var g: PatrolGraph = n as PatrolGraph
		var p: PatrolPoint = nearest_point(tagged_points(g, tag), pos) if g != null else null
		if p == null:
			continue
		var d: float = p.global_position.distance_squared_to(pos)
		if d <= best_d:
			best_d = d
			best = g
	return best


## Random walk of up to `length` points; stops early (closing a loop) once it has `min_len` (>= 3)
## points and stands next to the start.
static func _walk(start: PatrolPoint, adj: Dictionary, min_len: int, length: int,
		rng: RandomNumberGenerator) -> Array[PatrolPoint]:
	var path: Array[PatrolPoint] = [start]
	var cur: PatrolPoint = start
	while path.size() < length:
		if path.size() >= maxi(3, min_len) and (adj[cur] as Array).has(start):
			break
		var cands: Array[PatrolPoint] = []
		var weights: PackedFloat32Array = PackedFloat32Array()
		for q: PatrolPoint in adj[cur]:
			if not path.has(q):
				cands.append(q)
				weights.append(maxf(q.weight, 0.001))
		if cands.is_empty():
			break
		cur = cands[rng.rand_weighted(weights)]
		path.append(cur)
	return path
