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
