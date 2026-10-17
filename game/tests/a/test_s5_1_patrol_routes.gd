## A1-05 / S5.1: per-run guard patrol routes from a PatrolGraph (GameRng &"patrols"), guards walk
## them; guards without a graph hold their post.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	_teardown()
	await wait_frames(1)


func _teardown() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null


func _launch(seed_value: int, map: PackedScene) -> void:
	_teardown()
	await wait_frames(1)
	_rt = await HeistLauncher.launch(&"unit_map", seed_value, Enums.Difficulty.ROUTINE, self, {"map_packed": map})
	await wait_physics_frames(1)


func _brains() -> Array[GuardBrain]:
	var out: Array[GuardBrain] = []
	for n: Node in _rt.npcs(&"guard"):
		out.append(n.get_node("Brain") as GuardBrain)
	return out


func _routes() -> Array:
	var out: Array = []
	for b: GuardBrain in _brains():
		out.append(b.route.duplicate())
	return out


func test_s5_1_routes_deterministic_per_seed_and_vary_across_seeds() -> void:
	var map: PackedScene = ATestMaps.with_patrol_grid(2, 0, 4, 4)
	await _launch(42, map)
	var a: Array = _routes()
	assert_eq(a.size(), 2, "two guards")
	assert_true((a[0] as Array).size() >= 2, "guard 0 has a route")
	await _launch(42, map)
	assert_eq(_routes(), a, "same seed -> same routes")
	var differs: bool = false
	for s: int in [1, 7, 99, 1234, 5555]:
		await _launch(s, map)
		if _routes() != a:
			differs = true
			break
	assert_true(differs, "routes vary across seeds on a branching graph")


func test_s5_1_route_shape_follows_links_and_tags() -> void:
	await _launch(42, ATestMaps.with_patrol_grid(1, 0, 4, 4))
	var b: GuardBrain = _brains()[0]
	var tw: GuardTweak = b.tweak
	var unique: Dictionary = {}
	for p: PatrolPoint in b.route_points:
		unique[p] = true
		assert_has(p.tags, &"guard", "only guard-tagged points")
	assert_true(unique.size() >= mini(3, tw.route_min_points) and unique.size() <= tw.route_max_points,
		"route length within tweak (%d)" % unique.size())
	var spawn: Vector3 = (b.get_parent() as Node3D).global_position
	assert_true(b.route[0].distance_to(spawn) < 0.5, "starts at the point nearest the spawn")
	var pts: Array[PatrolPoint] = []
	for p: PatrolPoint in unique:
		pts.append(p)
	var adj: Dictionary = PatrolRouteGenerator.adjacency(pts)
	var n: int = b.route_points.size()
	for i: int in range(n):
		var nxt: PatrolPoint = b.route_points[(i + 1) % n]
		assert_true((adj[b.route_points[i]] as Array).has(nxt), "consecutive route points are linked (%d)" % i)


func test_s5_1_guard_walks_along_route() -> void:
	await _launch(42, ATestMaps.with_patrol_grid(1, 0, 4, 4))
	var b: GuardBrain = _brains()[0]
	var npc: NpcBase = b.get_parent() as NpcBase
	assert_true(b.route.size() >= 3, "has a route")
	var best: float = INF
	for k: int in range(int(8.0 * Engine.physics_ticks_per_second)):
		await wait_physics_frames(1)
		var p: Vector3 = npc.global_position
		best = minf(best, Vector2(p.x - b.route[2].x, p.z - b.route[2].z).length())
	assert_true(best < 0.8, "guard reached the third route point (closest %.2f m)" % best)
	assert_eq(b.state_name(), &"calm", "still calm while patrolling")


func test_s5_1_pauses_at_points_with_pause_range() -> void:
	await _launch(42, ATestMaps.with_patrol_grid(1, 0, 3, 3, 3.0, true, Vector2(1.5, 1.5)))
	var b: GuardBrain = _brains()[0]
	var npc: NpcBase = b.get_parent() as NpcBase
	await wait_seconds(0.5)
	var p0: Vector3 = npc.global_position
	await wait_seconds(0.6)
	assert_true(npc.global_position.distance_to(p0) < 0.05, "pausing at the first point")
	await wait_seconds(2.0)
	assert_true(npc.global_position.distance_to(p0) > 0.5, "moves on after the pause")


func test_s5_1_no_graph_holds_post() -> void:
	await _launch(42, ATestMaps.basic(1, 0))
	var b: GuardBrain = _brains()[0]
	var npc: NpcBase = b.get_parent() as NpcBase
	var start: Vector3 = npc.global_position
	assert_eq(b.route.size(), 0, "no route without a graph")
	await wait_seconds(2.0)
	assert_true(Vector2(npc.global_position.x - start.x, npc.global_position.z - start.z).length() < 0.3, "holds post")
	assert_eq(b.state_name(), &"calm")


func test_s5_1_linear_graph_ping_pongs() -> void:
	var g: PatrolGraph = PatrolGraph.new()
	add_child(g)
	var pts: Array[PatrolPoint] = []
	for i: int in range(4):
		var p: PatrolPoint = PatrolPoint.new()
		p.name = "L%d" % i
		p.position = Vector3(i * 3.0, 0, 0)
		if i > 0:
			p.links.append(NodePath("../L%d" % (i - 1)))
		g.add_child(p)
		pts.append(p)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var res: Dictionary = PatrolRouteGenerator.build(g, Vector3(-1, 0, 0), rng, 4, 4, &"guard", 3)
	assert_false(bool(res["loop"]), "no loop on a chain")
	assert_eq(res["points"], pts, "walks the chain from the nearest point")
	var order: Array[PatrolPoint] = PatrolRouteGenerator.visit_order(res["points"], false)
	assert_eq(order, [pts[0], pts[1], pts[2], pts[3], pts[2], pts[1]] as Array[PatrolPoint], "ping-pong order")
	var civ_only: Dictionary = PatrolRouteGenerator.build(g, Vector3.ZERO, rng, 4, 4, &"civilian")
	assert_eq((civ_only["points"] as Array).size(), 0, "respects tags")
	g.free()


## P OF-A6 ghost run (OF Lane points tagged only `guard_dock`): a guard whose spawn names its patrol graph patrols it
## even without route_tag points; a guard that only finds the graph by proximity still needs route_tag points.
func test_s5_1_named_graph_without_route_tag_still_patrols() -> void:
	await _launch(42, ATestMaps.with_patrol_grid(0, 0, 3, 3, 3.0, true, Vector2(0.5, 1.5)))
	var graph: PatrolGraph = _rt.map.get_node(^"Patrols/Graph") as PatrolGraph
	for p: PatrolPoint in graph.points():
		p.tags = [&"guard_dock"] as Array[StringName]
	var named: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(5, 0.05, -5)), {"patrol_graph": graph})
	var near: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(6, 0.05, -5)), {})
	await wait_physics_frames(3)
	var b: GuardBrain = named.get_node(^"Brain") as GuardBrain
	assert_true(b.route.size() >= 2, "named graph: a route (%d points)" % b.route.size())
	assert_eq(b.patrol_graph, graph)
	assert_eq((near.get_node(^"Brain") as GuardBrain).route.size(), 0, "proximity: no route_tag points, holds post")
	_teardown()
