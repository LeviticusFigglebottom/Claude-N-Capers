## patrols: PatrolGraph integrity (heist_map.md §4): links resolve inside the graph, are
## bidirectional, the graph is connected, linked points are mutually reachable on the navmesh,
## and every guard post on a graph serving >= 2 guards has >= 3 loop options.
## Loop option = distinct simple cycle (>= 3 points) through the post's start point (the patrol
## point nearest the guard spawn); a cycle and its reverse count once.
class_name LcCheckPatrols
extends LcCheck

const MIN_LOOPS: int = 3
const GUARDS_FOR_LOOP_RULE: int = 2


func _init() -> void:
	id = &"patrols"
	title = "Patrol graphs"


func run(ctx: LcContext) -> void:
	var graphs: Array[Node] = ctx.map.find_children("*", "PatrolGraph", true, false)
	for gn: Node in graphs:
		_check_graph(ctx, gn as PatrolGraph)
	for pp: Node in ctx.map.find_children("*", "PatrolPoint", true, false):
		var owner_graph: Node = pp.get_parent()
		while owner_graph != null and not (owner_graph is PatrolGraph):
			owner_graph = owner_graph.get_parent()
		if owner_graph == null:
			fail(ctx, pp, null, "PatrolPoint is not inside a PatrolGraph")
	note("%d patrol graph(s)" % graphs.size())


func _check_graph(ctx: LcContext, g: PatrolGraph) -> void:
	var pts: Array[PatrolPoint] = g.points()
	if pts.is_empty():
		fail(ctx, g, null, "PatrolGraph has no PatrolPoints")
		return
	var index: Dictionary = {}
	for i: int in range(pts.size()):
		index[pts[i]] = i
	var adj: Dictionary = {}
	var directed: Dictionary = {}
	for i: int in range(pts.size()):
		adj[i] = []
	for i2: int in range(pts.size()):
		var p: PatrolPoint = pts[i2]
		if p.links.is_empty():
			fail(ctx, p, null, "PatrolPoint has no links (disconnected)")
		for lp: NodePath in p.links:
			var t: Node = p.get_node_or_null(lp)
			if t == null or not index.has(t):
				fail(ctx, p, null, "link `%s` does not resolve to a PatrolPoint of graph `%s`" % [lp, g.graph_id])
				continue
			var j: int = index[t]
			if j == i2:
				fail(ctx, p, null, "links to itself")
				continue
			directed["%d>%d" % [i2, j]] = true
			if not (j in (adj[i2] as Array)):
				(adj[i2] as Array).append(j)
				(adj[j] as Array).append(i2)
	for key: String in directed.keys():
		var parts: PackedStringArray = key.split(">")
		if not directed.has("%s>%s" % [parts[1], parts[0]]):
			var a: PatrolPoint = pts[int(parts[0])]
			var b: PatrolPoint = pts[int(parts[1])]
			fail(ctx, a, null, "link to `%s` is not bidirectional (add the reverse link)" % ctx.node_path(b))
	# Connectivity.
	var comp: Dictionary = {0: true}
	var stack: Array[int] = [0]
	while not stack.is_empty():
		var c: int = stack.pop_back()
		for nb: int in adj[c]:
			if not comp.has(nb):
				comp[nb] = true
				stack.append(nb)
	if comp.size() < pts.size():
		for i3: int in range(pts.size()):
			if not comp.has(i3):
				fail(ctx, pts[i3], null, "not connected to the rest of graph `%s` (%d/%d reachable from `%s`)"
					% [g.graph_id, comp.size(), pts.size(), pts[0].name])
	# Linked points mutually reachable on the navmesh.
	if ctx.has_navmesh():
		for i4: int in range(pts.size()):
			for j4: int in adj[i4]:
				if j4 <= i4:
					continue
				var path: PackedVector3Array = ctx.nav_path(pts[i4].global_position, pts[j4].global_position)
				if not LcCheckReachability.reached(path, pts[j4].global_position):
					fail(ctx, pts[i4], null, "no navmesh path to linked point `%s`" % ctx.node_path(pts[j4]))
	_check_posts(ctx, g, pts, adj)


func _check_posts(ctx: LcContext, g: PatrolGraph, pts: Array[PatrolPoint], adj: Dictionary) -> void:
	var guards: Array[SpawnPoint] = []
	for n: Node in ctx.map.find_children("*", "SpawnPoint", true, false):
		var s: SpawnPoint = n
		if s.kind == SpawnPoint.Kind.GUARD and not s.patrol_graph.is_empty() and s.get_node_or_null(s.patrol_graph) == g:
			guards.append(s)
	note("graph `%s`: %d points, %d guard(s)" % [g.graph_id, pts.size(), guards.size()])
	if guards.size() < GUARDS_FOR_LOOP_RULE:
		return
	for s2: SpawnPoint in guards:
		var best: int = 0
		var best_d: float = INF
		for i: int in range(pts.size()):
			var d: float = pts[i].global_position.distance_to(s2.global_position)
			if d < best_d:
				best_d = d
				best = i
		var loops: int = LcGeom.count_cycles_through(adj, best, MIN_LOOPS)
		if loops < MIN_LOOPS:
			fail(ctx, s2, null, "guard post start `%s` has %d loop option(s) in graph `%s`, need >= %d"
				% [ctx.node_path(pts[best]), loops, g.graph_id, MIN_LOOPS])
