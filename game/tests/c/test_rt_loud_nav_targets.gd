## Rolling Thunder loud nav targets (RT-C1b; cloned from test_of_loud_nav_targets.gd). On the built map in a real
## HeistRuntime, loud and fully breached (every door unlocked and open, so the Tannery gates are open as after the
## mixer's move), every loud-phase walk target is on the navmesh and reachable from a street police spawn: the police
## spawns, the AssaultEvents markers (turret vans, heli drops, each door breach's room-side approach and the street
## outside it), the Tactical points (the sniper perches S1-S4 excepted: police-only posts), the escape / secure zones
## and their wait markers, the ladder ends and the lift UsePoints, and per convoy route both ConvoyLayout sets (clean,
## crash): each vehicle's COVER points (enabled for the test, as the mission does at the stop) and each truck's
## rear-door marker (the UsePoint / DrillPoint / LootAnchor spot behind its doors).
## Without movers (A5-02) the layout vehicles have no collision and no per-layout nav region (D-149.1), so this checks
## the points against the street navmesh only; when the movers and the pre-baked layout regions land, the same test
## must enable the layout's region pair before the queries. One run per route (the convoy_route rule's weights forced
## through the launcher's `variant_table` option). Owner: ENV C.
extends TestCase

const HEIST: StringName = &"rolling_thunder"
const SEED: int = 1002
## Paths are taken from this police spawn (Orchard north, behind the traffic-management truck: the street network).
const REF_SPAWN: NodePath = ^"Spawns/P_N_1"
## Police-only perches (doc Sightlines): snipers spawn there and hold.
const SNIPER_POSTS: Array[String] = ["SniperS1Skyway", "SniperS2Gantry", "SniperS3Crane", "SniperS4Ashby"]
const OFF_H_M: float = 0.6
const OFF_V_M: float = 1.2
const REACH_M: float = 0.5
## A breach's room-side approach: this far into the room along the marker's -Z.
const BREACH_IN_M: float = 1.0

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_loud_targets_route_north() -> void:
	await _check_route(&"route_north")


func test_loud_targets_route_east() -> void:
	await _check_route(&"route_east")


func _check_route(route: StringName) -> void:
	var base: HeistVariantTable = _map_table()
	if base == null:
		fail("no variant table for %s" % HEIST)
		return
	_rt = await HeistLauncher.launch(HEIST, SEED, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true, "variant_table": _forced(base, route)})
	if _rt == null:
		fail("launch %s" % HEIST)
		return
	assert_eq(_rt.variants.get(&"convoy_route", []), [route], "convoy_route forced to %s" % route)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "nav ready")
	_rt.isolate_npc(null)
	_rt.stealth.raise_alarm(&"test", 0)
	for n: Node in _rt.map.find_children("*", "Door", true, false):
		var d: Door = n as Door
		if d.is_visible_in_tree():
			d.unlock()
			d.set_open(true, true)
			d.finish_swing()
	var layouts: Array[Node] = _rt.map.find_children("*", "Node3D", true, false).filter(
		func(x: Node) -> bool: return x.has_meta(&"convoy_layout"))
	assert_eq(layouts.size(), 2, "%s: the clean and crash ConvoyLayout sets survive the resolver" % route)
	for st: Node in layouts:
		for tp: Node in st.find_children("*", "TacticalPoint", true, false):
			(tp as TacticalPoint).set_enabled(true)
	await wait_physics_frames(10)
	var nav: RID = c.get_world_3d().navigation_map
	var ref: Vector3 = NavigationServer3D.map_get_closest_point(nav, (_rt.map.get_node(REF_SPAWN) as Node3D).global_position)
	var bad: PackedStringArray = PackedStringArray()
	var targets: Array[Array] = _targets(layouts)
	for t: Array in targets:
		var label: String = String(t[0])
		var want: Vector3 = t[1]
		var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
		var flat: float = Vector2(p.x - want.x, p.z - want.z).length()
		if flat > OFF_H_M or absf(p.y - want.y) > OFF_V_M:
			bad.append("OFF-MESH %s at %s (closest nav %s, %.2f m flat, %.2f m up)" % [label, want, p, flat, p.y - want.y])
			continue
		if label.begins_with("Spawns/P_"):
			continue   # police spawns are origins (P_SKY's deck island joins the street by one-way rappels)
		var end: Vector3 = _path_end(nav, ref, p)
		if end.distance_to(p) > REACH_M:
			bad.append("DISCONNECTED %s at %s (path from the police spawn ends at %s, %.1f m short)" % [label, p, end,
				end.distance_to(p)])
	var ae: Node = _rt.map.get_node_or_null(^"AssaultEvents")
	for sp: Array in targets:   # each police spawn reaches the street outside every door breach
		if not String(sp[0]).begins_with("Spawns/P_"):
			continue
		var from: Vector3 = NavigationServer3D.map_get_closest_point(nav, sp[1])
		for mk: Node in ae.get_children() if ae != null else []:
			if not String(mk.name).begins_with("Breach_"):
				continue
			var out_at: Vector3 = NavigationServer3D.map_get_closest_point(nav,
				(mk as Node3D).global_transform * Vector3(0.0, 0.0, 1.5))
			var e2: Vector3 = _path_end(nav, from, out_at)
			if e2.distance_to(out_at) > REACH_M:
				bad.append("POLICE %s cannot reach the street outside %s (%.1f m short)" % [sp[0], mk.name,
					e2.distance_to(out_at)])
	for line: String in bad:
		print("  loud nav %s: %s" % [route, line])
	print("  loud nav %s: %d targets, %d bad" % [route, targets.size(), bad.size()])
	assert_true(targets.size() >= 100, "targets collected (%d)" % targets.size())
	assert_true(bad.is_empty(), "%s: %d loud targets off the navmesh or disconnected (see the log)" % [route, bad.size()])


## The built map's variant table (the def is at its wip path until G1: read it off the map scene).
func _map_table() -> HeistVariantTable:
	var ps: PackedScene = load(HeistLauncher.map_path(HEIST)) as PackedScene
	if ps == null:
		return null
	var m: HeistMap = ps.instantiate() as HeistMap
	var vt: HeistVariantTable = m.variant_table
	m.free()
	return vt


## A copy of `base` whose convoy_route rule picks `route` on Routine.
static func _forced(base: HeistVariantTable, route: StringName) -> HeistVariantTable:
	var t: HeistVariantTable = base.duplicate(true) as HeistVariantTable
	var rules: Array = t.rules.duplicate(true)
	for r: Variant in rules:
		var rule: Dictionary = r
		if rule.get("group", &"") == &"convoy_route":
			var w: Dictionary = {&"route_north": 0.0, &"route_east": 0.0}
			w[route] = 1.0
			rule["weights_by_difficulty"] = {Enums.Difficulty.ROUTINE: w}
	t.rules = rules
	return t


## [label, world point] for every loud-phase walk target.
func _targets(layouts: Array[Node]) -> Array[Array]:
	var out: Array[Array] = []
	var m: Node = _rt.map
	var spawns: Node = m.get_node_or_null(^"Spawns")
	if spawns != null:
		for s: Node in spawns.get_children():
			if s is SpawnPoint and (s as SpawnPoint).kind == SpawnPoint.Kind.POLICE:
				out.append(["Spawns/" + String(s.name), (s as Node3D).global_position])
	var ae: Node = m.get_node_or_null(^"AssaultEvents")
	if ae != null:
		for mk: Node in ae.get_children():
			var n3: Node3D = mk as Node3D
			if n3 == null or String(mk.name).begins_with("HeliOrbit"):
				continue
			var at: Vector3 = n3.global_position
			if String(mk.name).begins_with("Breach_"):
				at = n3.global_transform * Vector3(0.0, 0.0, -BREACH_IN_M)
				out.append(["AssaultEvents/%s outside" % mk.name, n3.global_transform * Vector3(0.0, 0.0, 1.5)])
			out.append(["AssaultEvents/" + String(mk.name), at])
	var tac: Node = m.get_node_or_null(^"Tactical")
	if tac != null:
		for t: Node in tac.find_children("*", "Node3D", true, false):
			var link: NavigationLink3D = t as NavigationLink3D
			if link != null:   # a RAPPEL point's runtime link starts on the police-only deck: check where it lands
				out.append(["%s landing" % tac.get_path_to(t), link.global_transform * link.end_position])
			elif t.get_child_count() == 0 and not String(t.name) in SNIPER_POSTS:
				out.append([String(tac.get_path_to(t)), (t as Node3D).global_position])
	var esc: Node = m.get_node_or_null(^"Variants/Group_escape")
	if esc != null:
		for z: Node in esc.find_children("*", "Area3D", true, false):
			out.append([String(m.get_path_to(z)), (z as Node3D).global_position])
		for w: Node in esc.find_children("EscapeWait*", "Marker3D", true, false):
			out.append([String(m.get_path_to(w)), (w as Node3D).global_position])
	for p: String in ["Gameplay/Ladders", "Gameplay/Lifts"]:
		var g: Node = m.get_node_or_null(NodePath(p))
		if g == null:
			continue
		for n: Node in g.find_children("*", "Node3D", true, false):
			var nm: String = String(n.name)
			if nm in ["Bottom", "Top", "UsePoint"]:
				out.append([String(m.get_path_to(n)), (n as Node3D).global_position])
	for st: Node in layouts:
		var lid: String = String(st.get_meta(&"convoy_layout"))
		for tp: Node in st.find_children("*", "TacticalPoint", true, false):
			out.append(["%s/%s" % [lid, tp.name], (tp as Node3D).global_position])
		for mk2: Node in st.find_children("*RearDoor", "Marker3D", true, false):
			out.append(["%s/%s" % [lid, mk2.name], (mk2 as Node3D).global_position])
	return out


## The end of the navmesh path a -> b, searched without Godot's default 4096-polygon cap.
static func _path_end(nav: RID, a: Vector3, b: Vector3) -> Vector3:
	var qp: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
	qp.map = nav
	qp.start_position = a
	qp.target_position = b
	qp.path_search_max_polygons = 0
	var qr: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(qp, qr)
	return qr.path[qr.path.size() - 1] if not qr.path.is_empty() else a
