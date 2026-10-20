## OF-A6 hub-loop patrols (LEAD 2026-10-20, doc ostrander_federal.md rover_dock / rover_basement (a)/(b)/(c)):
## PatrolRouteGenerator.hub_route walks every loop from the hub and back each cycle, in an order the RNG shuffles once;
## derived loops = one per pause point. On the real OF map: rover_dock (derived from the Lane graph) visits Ledger Lane
## west, the Tannery corner smoke stop and the Tannery bay every cycle; rover_basement visits RC, SD + SS and CP + PL and
## never enters the vault concourse (VC*, the vault post's points on the same graph).
extends TestCase

const MAP_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"

var _root: Node = null


func after_each() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	await wait_frames(1)


## A graph on a line W(pause) - H(hub) - M - C(pause) - B(pause), plus a branch M - X(pause).
func _line_graph() -> PatrolGraph:
	var g: PatrolGraph = PatrolGraph.new()
	g.name = "Line"
	add_child(g)
	_root = g
	var spec: Dictionary = {"W": [-10.0, 6.0], "H": [0.0, 0.0], "M": [8.0, 0.0], "C": [20.0, 20.0], "B": [30.0, 6.0],
		"X": [8.0, 4.0]}
	for n: String in spec:
		var p: PatrolPoint = PatrolPoint.new()
		p.name = n
		p.pause_range = Vector2(float(spec[n][1]) * 0.5, float(spec[n][1]))
		g.add_child(p)
		p.position = Vector3(float(spec[n][0]), 0.0, 10.0 if n == "X" else 0.0)
	for e: Array in [["W", "H"], ["H", "M"], ["M", "C"], ["C", "B"], ["M", "X"]]:
		var a: PatrolPoint = g.get_node(e[0]) as PatrolPoint
		a.links.append(a.get_path_to(g.get_node(e[1])))
	return g


static func _names(order: Array[PatrolPoint]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: PatrolPoint in order:
		out.append(String(p.name))
	return out


func test_derived_loops_visit_every_pause_point_each_cycle() -> void:
	var g: PatrolGraph = _line_graph()
	await wait_frames(1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var order: Array[PatrolPoint] = PatrolRouteGenerator.hub_route(g, g.get_node("H") as PatrolPoint, [], rng)
	var names: PackedStringArray = _names(order)
	assert_eq(names[0], "H", "starts at the hub (%s)" % [names])
	for stop: String in ["W", "C", "B", "X"]:
		assert_true(names.has(stop), "pause point %s in every cycle (%s)" % [stop, names])
	assert_eq(names.count("H"), 4, "back at the hub after each of the 4 loops (%s)" % [names])
	for i: int in range(names.size()):
		assert_ne(names[i], names[(i + 1) % names.size()], "no point twice in a row (%s)" % [names])
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 7
	assert_eq(_names(PatrolRouteGenerator.hub_route(g, g.get_node("H") as PatrolPoint, [], rng2)), names, "deterministic")


func test_explicit_loops_walk_their_stops_in_order() -> void:
	var g: PatrolGraph = _line_graph()
	await wait_frames(1)
	var c: PatrolPoint = g.get_node("C") as PatrolPoint
	var b: PatrolPoint = g.get_node("B") as PatrolPoint
	var order: Array[PatrolPoint] = PatrolRouteGenerator.hub_route(g, g.get_node("H") as PatrolPoint, [[b, c]],
		RandomNumberGenerator.new())
	assert_eq(_names(order), PackedStringArray(["H", "M", "C", "B", "C", "M"]), "H -> B (via C), then C -> back")


func test_of_rover_dock_and_basement_loops() -> void:
	if not ResourceLoader.exists(MAP_PATH):
		skip("no ostrander_federal map")
		return
	_root = (load(MAP_PATH) as PackedScene).instantiate()
	add_child(_root)
	await wait_frames(1)
	var cfg: Dictionary = (load("res://systems/ai/data/guard_tweak.tres") as GuardTweak).hub_loops
	var cases: Dictionary = {
		&"guard_rover_dock": ["Patrols/Lane", ["LaneWest", "LaneCorner", "TanneryBay"], []],
		&"guard_rover_basement": ["Patrols/BankBasement", ["RCEast", "SDDesk", "SS", "CP", "PL"], ["VC"]],
	}
	for tag: StringName in cases:
		assert_true(cfg.has(tag), "GuardTweak.hub_loops has %s" % tag)
		var g: PatrolGraph = _root.get_node_or_null(String(cases[tag][0])) as PatrolGraph
		assert_true(g != null, "%s graph %s" % [tag, cases[tag][0]])
		if g == null or not cfg.has(tag):
			continue
		var c: Dictionary = cfg[tag]
		var hub: PatrolPoint = g.get_node_or_null(String(c["hub"])) as PatrolPoint
		assert_true(hub != null, "%s hub %s" % [tag, c["hub"]])
		var loops: Array = []
		for names: Variant in c["loops"]:
			var stops: Array = []
			for n: Variant in names:
				var p: PatrolPoint = g.get_node_or_null(String(n)) as PatrolPoint
				assert_true(p != null, "%s: point %s exists in %s (C renamed it?)" % [tag, n, g.name])
				stops.append(p)
			loops.append(stops)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1002
		var names: PackedStringArray = _names(PatrolRouteGenerator.hub_route(g, hub, loops, rng))
		for stop: String in cases[tag][1]:
			assert_true(names.has(stop), "%s visits %s every cycle (%s)" % [tag, stop, names])
		for prefix: String in cases[tag][2]:
			for n: String in names:
				assert_false(n.begins_with(prefix), "%s never enters %s* (%s)" % [tag, prefix, names])
