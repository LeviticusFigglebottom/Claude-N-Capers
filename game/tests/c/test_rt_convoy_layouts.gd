## Rolling Thunder convoy layouts (RT-C2; D-149.1 / QC-RT1 / QC-RT8). On the built map in a real HeistRuntime, one run
## per convoy route (forced as test_rt_loud_nav_targets does):
## * before the stop (no layout active) the open-road region (`Navigation`, meta `convoy_open_nav`) is the only one on
##   and every truck's rear-step spot of both layouts is reachable on it from a police spawn (the road the convoy will
##   stop on connects);
## * for both of the route's layouts, switched on with A's API (HeistRuntime.set_convoy_layout) and the movers parked on
##   the layout's `<Veh>Stop` markers (as the mission's pop-in): the open road is off and the layout's own region on;
##   every truck's rear-step UsePoint (and the bullion thermite's) is on the navmesh and reachable from a police spawn
##   and a player spawn; no enabled navmesh polygon has its centre inside a stopped vehicle's footprint; every vehicle
##   stands on its stop marker.
## Disabled convoy regions are off the navigation map (Gameplay/ConvoyNav, rt_convoy_nav.gd). Paths are searched
## without Godot's default 4096-polygon cap. Owner: ENV C.
extends TestCase

const HEIST: StringName = &"rolling_thunder"
const SEED: int = 1002
const POLICE: NodePath = ^"Spawns/P_N_1"
const OFF_H_M: float = 0.6
const OFF_V_M: float = 1.2
const REACH_M: float = 0.5
## Vehicle boxes (rt_gameplay CONVOY_LEN / CONVOY_WIDTH, TRUCK_STEP): [length, width, rear step].
const SIZE: Dictionary = {"car": [5.0, 2.0, 0.0], "cash": [7.5, 2.5, 0.35], "bullion": [9.0, 2.5, 0.35]}
## A polygon centre this far inside a footprint counts (the obstruction is grown by the agent radius anyway).
const INSIDE_M: float = 0.05

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_route_north() -> void:
	await _check_route(&"route_north")


func test_route_east() -> void:
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
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "nav ready")
	_rt.isolate_npc(null)
	var nav: RID = c.get_world_3d().navigation_map
	var slot: Node = _rt.map.find_child("Slot_" + String(route), true, false)
	assert_true(slot != null, "the %s slot survives the resolver" % route)
	if slot == null:
		return
	var movers: Node = slot.get_node("Convoy/Movers")
	var police: Vector3 = _closest(nav, (_rt.map.get_node(POLICE) as Node3D).global_position)
	var player: Vector3 = _closest(nav, _player_spawn())
	var bad: PackedStringArray = PackedStringArray()
	# --- before the stop: the open road
	var open: Array[NavigationRegion3D] = _open_regions()
	assert_eq(open.size(), 1, "one open-road region (convoy_open_nav)")
	for r: NavigationRegion3D in open:
		assert_true(r.enabled, "%s on before the stop" % r.name)
	for l: Node3D in ConvoyLayouts.layouts(_rt.map):
		for r2: Node in l.find_children("*", "NavigationRegion3D", true, false):
			assert_false((r2 as NavigationRegion3D).enabled, "%s/%s off before the stop" % [l.name, r2.name])
			assert_false(NavigationServer3D.region_get_map((r2 as NavigationRegion3D).get_rid()).is_valid(),
				"%s/%s off the nav map while disabled (rt_convoy_nav.gd: no duplicate edges)" % [l.name, r2.name])
		for st: Node in l.get_children():
			var kind: String = String(st.get_meta(&"vehicle_kind", ""))
			if kind == "cash" or kind == "bullion":
				var spot: Vector3 = (st as Node3D).global_transform * Vector3(0.0, 0.0,
					-float(SIZE[kind][0]) * 0.5 - 0.9)
				if _under_a_waiting_mover(movers, spot):
					continue   # the north lead car / T1 wait upstream over part of the clean queue
				_expect_reach(nav, police, spot, "open road: %s/%s rear step (from %s)" % [l.name, st.name, POLICE],
					bad)
	# --- each layout
	var layouts: Array[Node3D] = ConvoyLayouts.layouts(_rt.map)
	assert_eq(layouts.size(), 2, "%s: the clean and crash layouts" % route)
	for lay: Node3D in layouts:
		var lid: String = String(lay.get_meta(&"convoy_layout"))
		assert_true(_rt.set_convoy_layout(lid), "set_convoy_layout(%s)" % lid)
		var foot: Array[Array] = []
		for v: Node in movers.get_children():
			var cv: ConvoyVehicle = v as ConvoyVehicle
			if cv == null:
				continue
			var stop: Node3D = lay.get_node_or_null(NodePath(String(cv.name) + "Stop")) as Node3D
			assert_true(stop != null, "%s: %sStop" % [lid, cv.name])
			if stop == null:
				continue
			cv.stage = ConvoyVehicle.Stage.PARKED   # the previous layout's park stopped it
			cv.park(stop)
			assert_true(cv.global_transform.origin.distance_to(stop.global_position) < 0.01, "%s: %s on its stop"
				% [lid, cv.name])
			foot.append([stop.global_transform, String(stop.get_meta(&"vehicle_kind", "car")), String(cv.name)])
		var r2s: Node3D = lay.get_node_or_null(^"RearStop2") as Node3D
		assert_true(r2s != null, "%s: RearStop2 (trucks_2)" % lid)
		await wait_physics_frames(6)
		for r3: NavigationRegion3D in open:
			assert_false(r3.enabled, "%s: %s off at the stop" % [lid, r3.name])
		for r4: Node in lay.find_children("*", "NavigationRegion3D", true, false):
			assert_true((r4 as NavigationRegion3D).enabled, "%s: %s on at the stop" % [lid, r4.name])
		var uses: int = 0
		for t: Node in movers.find_children("*", "ArmoredTruck", true, false):
			var truck: ArmoredTruck = t as ArmoredTruck
			if not truck.is_enabled():
				continue
			for up: Node in [truck.get_node_or_null(^"UsePoint"), truck.get_parent().get_node_or_null(^"Thermite/UsePoint")]:
				if up == null:
					continue
				uses += 1
				var at: Vector3 = (up as Node3D).global_position
				var label: String = "%s %s/%s" % [lid, truck.get_parent().name, truck.get_parent().get_path_to(up)]
				var p2: Vector3 = NavigationServer3D.map_get_closest_point(nav, at)
				var flat: float = Vector2(p2.x - at.x, p2.z - at.z).length()
				if flat > OFF_H_M or absf(p2.y - at.y) > OFF_V_M:
					bad.append("OFF-MESH %s at %s (closest %s, %.2f m)" % [label, at, p2, flat])
					continue
				_expect_reach(nav, police, p2, "%s from %s" % [label, POLICE], bad)
				_expect_reach(nav, player, p2, "%s from the player spawn" % label, bad)
		assert_true(uses >= 4, "%s: the trucks' use points (%d)" % [lid, uses])
		var inside: int = 0
		for r5: NavigationRegion3D in _enabled_regions():
			var m: NavigationMesh = r5.navigation_mesh
			var verts: PackedVector3Array = m.get_vertices()
			for i: int in m.get_polygon_count():
				var cen: Vector3 = Vector3.ZERO
				var poly: PackedInt32Array = m.get_polygon(i)
				for k: int in poly:
					cen += verts[k]
				cen = r5.global_transform * (cen / float(poly.size()))
				for f: Array in foot:
					if _in_footprint(f[0], String(f[1]), cen):
						inside += 1
						if inside <= 8:
							bad.append("POLYGON %s/%d centre %s inside %s" % [r5.name, i, cen, f[2]])
		assert_eq(inside, 0, "%s: no navmesh polygon centre inside a stopped vehicle" % lid)
	assert_true(_rt.set_convoy_layout(""), "back to no layout")
	for line: String in bad:
		print("  convoy %s: %s" % [route, line])
	assert_true(bad.is_empty(), "%s: %d convoy nav problems (see the log)" % [route, bad.size()])


func _expect_reach(nav: RID, from: Vector3, to: Vector3, label: String, bad: PackedStringArray) -> void:
	var p: Vector3 = _closest(nav, to)
	var end: Vector3 = _path_end(nav, from, p)
	if end.distance_to(p) > REACH_M:
		bad.append("DISCONNECTED %s (path ends %.1f m short at %s)" % [label, end.distance_to(p), end])


## True when `p` lies within 0.5 m (the agent radius + margin) of a mover's box where it waits before the drive.
static func _under_a_waiting_mover(movers: Node, p: Vector3) -> bool:
	for v: Node in movers.get_children():
		var cv: ConvoyVehicle = v as ConvoyVehicle
		if cv == null:
			continue
		var kind: String = "car" if cv.vehicle_kind == &"car" else String(cv.get_meta(&"kind", "")).trim_prefix("convoy_")
		var s: Array = SIZE.get(kind, SIZE["car"])
		var l: Vector3 = cv.global_transform.affine_inverse() * p
		var hl: float = float(s[0]) * 0.5 + 0.5
		if absf(l.x) < float(s[1]) * 0.5 + 0.5 and l.z < hl and l.z > -hl - float(s[2]):
			return true
	return false


func _open_regions() -> Array[NavigationRegion3D]:
	var out: Array[NavigationRegion3D] = []
	for n: Node in _rt.map.find_children("*", "NavigationRegion3D", true, false):
		if n.has_meta(ConvoyLayouts.META_OPEN_NAV):
			out.append(n as NavigationRegion3D)
	return out


func _enabled_regions() -> Array[NavigationRegion3D]:
	var out: Array[NavigationRegion3D] = []
	for n: Node in _rt.map.find_children("*", "NavigationRegion3D", true, false):
		if (n as NavigationRegion3D).enabled and n.is_inside_tree():
			out.append(n as NavigationRegion3D)
	return out


func _player_spawn() -> Vector3:
	for s: Node in _rt.map.get_node(^"Spawns").get_children():
		if s is SpawnPoint and (s as SpawnPoint).kind == SpawnPoint.Kind.PLAYER:
			return (s as Node3D).global_position
	return Vector3.ZERO


## The vehicle box at its stop (pivot bottom-centre, cab +Z, a truck's rear step behind -Z), shrunk by INSIDE_M.
static func _in_footprint(xf: Transform3D, kind: String, p: Vector3) -> bool:
	var s: Array = SIZE.get(kind, SIZE["car"])
	var l: Vector3 = xf.affine_inverse() * p
	var hl: float = float(s[0]) * 0.5
	return absf(l.x) < float(s[1]) * 0.5 - INSIDE_M and l.z < hl - INSIDE_M and l.z > -hl - float(s[2]) + INSIDE_M \
		and l.y > -1.0 and l.y < 3.0


static func _closest(nav: RID, p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(nav, p)


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
