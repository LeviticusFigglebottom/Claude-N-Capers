## OF-A4 (D-136 §3b.4): CivilianRoute. A bound civilian walks its stops in order (LOOP / PING_PONG), dwells per
## stop pause_range, climbs to another floor on the navmesh, skips an unreachable stop (logged once), opens / closes
## the away window, and panic / intimidation preempt the route.
extends TestCase

var _rt: HeistRuntime = null
var _arrivals: Dictionary = {}  # NpcBase -> Array[Array] [index, physics frame, rolled dwell]
var _skips: Array[int] = []
var _away_events: Array[Array] = []


func before_each() -> void:
	_arrivals = {}
	_skips = []
	_away_events = []


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _route(nm: String, order: CivilianRoute.Order, stops: Array[Dictionary], bind_tags: Array[StringName] = []) -> CivilianRoute:
	var r: CivilianRoute = CivilianRoute.new()
	r.name = nm
	r.order = order
	r.bind_tags = bind_tags
	_rt.map.get_node(^"Patrols").add_child(r)
	for i: int in range(stops.size()):
		var spec: Dictionary = stops[i]
		var s: CivilianRouteStop = CivilianRouteStop.new()
		s.name = "Stop%d" % i
		s.pause_range = spec.get("dwell", Vector2.ZERO)
		s.pause_anim = spec.get("anim", &"idle")
		s.away_window = spec.get("away", &"")
		r.add_child(s)
		s.global_position = spec["pos"]
	r.stop_reached.connect(_on_reached.bind(r))
	r.stop_skipped.connect(func(_n: NpcBase, i: int) -> void: _skips.append(i))
	r.away_changed.connect(func(n: NpcBase, w: StringName, away: bool) -> void: _away_events.append([n, w, away]))
	return r


func _on_reached(npc: NpcBase, index: int, r: CivilianRoute) -> void:
	var b: CivilianBrain = npc.get_node(^"Brain") as CivilianBrain
	if not _arrivals.has(npc):
		_arrivals[npc] = []
	(_arrivals[npc] as Array).append([index, Engine.get_physics_frames(), b._route_dwell, r])


func _civ(pos: Vector3, info: Dictionary) -> NpcBase:
	return _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), info)


func _order(npc: NpcBase) -> Array[int]:
	var out: Array[int] = []
	for a: Array in _arrivals.get(npc, []):
		out.append(int(a[0]))
	return out


func test_of_a4_order_and_dwell_loop_and_ping_pong() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4101, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	var y: float = 0.05
	var loop: CivilianRoute = _route("LoopRoute", CivilianRoute.Order.LOOP, [
		{"pos": Vector3(-2, y, -2), "dwell": Vector2(0.5, 0.5), "anim": &"phone"},
		{"pos": Vector3(0, y, -2), "dwell": Vector2(1.0, 1.0), "anim": &"teller"},
		{"pos": Vector3(0, y, -4), "dwell": Vector2(0.3, 0.9)}], [&"civ_route_a"])
	var pp: CivilianRoute = _route("PingRoute", CivilianRoute.Order.PING_PONG, [
		{"pos": Vector3(6, y, -2), "dwell": Vector2(0.2, 0.2)},
		{"pos": Vector3(8, y, -2), "dwell": Vector2(0.2, 0.2)},
		{"pos": Vector3(8, y, -4), "dwell": Vector2(0.2, 0.2)}])
	assert_eq(loop.stop_count(), 3, "children are the stops")
	assert_eq(loop.id(), &"LoopRoute", "id defaults to the node name")
	assert_eq(CivilianRoute.find(_rt, &"PingRoute"), pp, "find by id")
	assert_eq(loop.stop_at(0).tags, [&"civilian_route"] as Array[StringName], "route stops are not wander points")
	# Bound by spawn tag (a mark-bound desk activity: the route overrides the mark) / by the SpawnPoint patrol_graph.
	var a: NpcBase = _civ(Vector3(-2, y, -2), {"idle_activity": &"desk", "tags": [&"civ_route_a"] as Array[StringName]})
	var b: NpcBase = _civ(Vector3(6, y, -2), {"idle_activity": &"idle", "tags": [] as Array[StringName], "patrol_graph": pp})
	var ba: CivilianBrain = a.get_node(^"Brain") as CivilianBrain
	var bb: CivilianBrain = b.get_node(^"Brain") as CivilianBrain
	await wait_physics_frames(3)
	assert_eq(ba.current_route(), loop, "bound by spawn tag")
	assert_eq(bb.current_route(), pp, "bound by spawn_info patrol_graph")
	assert_has(loop.bound_civilians(), a, "route lists its civilian")
	assert_false(ba.mark_bound(), "a routed civilian is not mark-bound")
	var departs: Array[Array] = []  # [index, frame] when ba sets off
	var was_walking: bool = ba._route_walking
	var done: bool = false
	var deadline: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		await wait_physics_frames(1)
		if ba._route_walking and not was_walking:
			departs.append([ba.route_stop_index(), Engine.get_physics_frames()])
		was_walking = ba._route_walking
		if ba.mode == CivilianBrain.Mode.WANDER:
			assert_true(ba._route_walking, "routed: never a random wander")
		if _order(a).size() >= 5 and _order(b).size() >= 5:
			done = true
			break
	assert_true(done, "both civilians reached 5 stops")
	assert_eq(_order(a).slice(0, 5), [0, 1, 2, 0, 1] as Array[int], "LOOP order")
	assert_eq(_order(b).slice(0, 5), [0, 1, 2, 1, 0] as Array[int], "PING_PONG order")
	var tps: float = float(Engine.physics_ticks_per_second)
	var ranges: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(1.0, 1.0), Vector2(0.3, 0.9)]
	var arr: Array = _arrivals[a]
	for k: int in range(4):
		var idx: int = int(arr[k][0])
		var rolled: float = float(arr[k][2])
		assert_true(rolled >= ranges[idx].x - 0.001 and rolled <= ranges[idx].y + 0.001,
			"dwell at stop %d rolled in its pause_range (%.2f)" % [idx, rolled])
		var dep_frame: int = -1
		for d: Array in departs:
			if int(d[1]) > int(arr[k][1]):
				dep_frame = int(d[1])
				break
		var waited: float = float(dep_frame - int(arr[k][1])) / tps
		assert_true(dep_frame > 0 and absf(waited - rolled) <= 3.0 / tps + 0.001,
			"stop %d: left after its dwell (%.3f s vs %.3f s)" % [idx, waited, rolled])
	assert_true(_skips.is_empty(), "nothing skipped on one floor")


func test_of_a4_cross_floor_and_unreachable_stop_skipped() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4102, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_two_floors()})
	assert_true(await ATestMaps.await_nav_synced(_rt), "navmesh synced")
	var r: CivilianRoute = _route("Floors", CivilianRoute.Order.LOOP, [
		{"pos": Vector3(-2, 0.05, -3), "dwell": Vector2(0.2, 0.2)},
		{"pos": Vector3(-8, 2.55, -8), "dwell": Vector2(0.2, 0.2)},  # the island: no way up
		{"pos": Vector3(8, 2.55, -3), "dwell": Vector2(0.2, 0.2)}], [&"civ_floors"])
	var c: NpcBase = _civ(Vector3(-2, 0.05, -3), {"idle_activity": &"idle", "tags": [&"civ_floors"] as Array[StringName]})
	var bc: CivilianBrain = c.get_node(^"Brain") as CivilianBrain
	var upstairs: Array[bool] = [false]
	var ok: bool = await wait_until(func() -> bool:
		if bc.route_stop_index() == 2 and bc.mode == CivilianBrain.Mode.IDLE:
			upstairs[0] = upstairs[0] or c.global_position.y > 2.2
		return _skips.size() >= 2, 40.0)
	assert_true(ok, "walked the route twice past the island stop (skips %s, order %s)" % [_skips, _order(c)])
	assert_eq(_order(c).slice(0, 3), [0, 2, 0] as Array[int], "the unreachable stop is skipped")
	assert_true(upstairs[0], "dwelt on the upper floor (cross-floor navmesh path)")
	assert_eq(_skips.slice(0, 2), [1, 1] as Array[int], "stop 1 skipped each lap")
	assert_eq(bc._route_logged.size(), 1, "logged once")
	assert_eq(bc.current_route(), r, "still routed")


func test_of_a4_away_window_flips() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4103, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	var r: CivilianRoute = _route("MgrVault", CivilianRoute.Order.LOOP, [
		{"pos": Vector3(-2, 0.05, -2), "dwell": Vector2(0.3, 0.3), "anim": &"desk"},
		{"pos": Vector3(1, 0.05, -2), "dwell": Vector2(0.5, 0.5), "away": &"manager_away"}], [&"civ_manager_test"])
	var m: NpcBase = _civ(Vector3(-2, 0.05, -2), {"idle_activity": &"idle", "tags": [&"civ_manager_test"] as Array[StringName]})
	var bm: CivilianBrain = m.get_node(^"Brain") as CivilianBrain
	assert_true(await wait_until(func() -> bool: return _order(m).size() >= 1, 5.0), "at the office")
	assert_false(r.is_away(), "at the office: not away")
	assert_eq(r.away_window(), &"", "no window")
	assert_true(await wait_until(func() -> bool: return r.is_away(&"manager_away"), 5.0), "window opens")
	assert_eq(bm.mode, CivilianBrain.Mode.WANDER, "opens as it sets off for the away stop")
	assert_eq(r.away_window(), &"manager_away", "window named")
	assert_true(CivilianRoute.any_away(_rt, &"manager_away"), "runtime-wide query")
	assert_eq(_away_events[0], [m, &"manager_away", true], "away_changed(true)")
	assert_true(await wait_until(func() -> bool: return _order(m).size() >= 2, 6.0), "reached the away stop")
	assert_true(r.is_away(&"manager_away"), "still away while there")
	assert_true(await wait_until(func() -> bool: return _order(m).size() >= 3, 8.0), "back at the office")
	assert_false(r.is_away(), "back at the post: window closed")
	assert_false(CivilianRoute.any_away(_rt, &"manager_away"), "closed runtime-wide")
	assert_eq(_away_events.size(), 2, "one open, one close")
	assert_eq(_away_events[1], [m, &"manager_away", false], "away_changed(false)")


func test_of_a4_panic_and_intimidation_interrupt_route() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4104, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	var r: CivilianRoute = _route("Teller", CivilianRoute.Order.LOOP, [
		{"pos": Vector3(-2, 0.05, -2), "dwell": Vector2(0.2, 0.2), "anim": &"teller"},
		{"pos": Vector3(2, 0.05, -2), "dwell": Vector2(0.2, 0.2), "away": &"teller_away"}], [&"civ_teller_test"])
	var r2: CivilianRoute = _route("Coffee", CivilianRoute.Order.LOOP, [
		{"pos": Vector3(4, 0.05, -6), "dwell": Vector2(30.0, 30.0)},
		{"pos": Vector3(7, 0.05, -6), "dwell": Vector2(0.2, 0.2)}], [&"civ_officer_test"])
	var t: NpcBase = _civ(Vector3(-2, 0.05, -2), {"idle_activity": &"idle", "tags": [&"civ_teller_test"] as Array[StringName]})
	var o: NpcBase = _civ(Vector3(4, 0.05, -6), {"idle_activity": &"idle", "tags": [&"civ_officer_test"] as Array[StringName]})
	var bt: CivilianBrain = t.get_node(^"Brain") as CivilianBrain
	var bo: CivilianBrain = o.get_node(^"Brain") as CivilianBrain
	assert_true(await wait_until(func() -> bool: return r.is_away(&"teller_away"), 5.0), "teller sets off for BR")
	assert_true(bt._route_walking, "walking the route")
	bt.panic(Vector3(-4, 0.05, -2))
	assert_true(bt.mode != CivilianBrain.Mode.WANDER and bt.mode != CivilianBrain.Mode.IDLE, "panic preempts the route")
	assert_eq(t.alert_state, Enums.AlertState.PANICKED, "panicked")
	assert_false(r.is_away(), "the away window closes on panic")
	assert_eq(_away_events.back(), [t, &"teller_away", false], "away_changed(false)")
	assert_true(await wait_until(func() -> bool: return _order(o).size() >= 1, 5.0), "officer at the coffee stop")
	assert_true(bo.on_mark(), "held on the stop while dwelling")
	assert_true(bo.on_shouted(null), "a calm routed civilian goes down to a shout")
	assert_eq(bo.mode, CivilianBrain.Mode.DOWN, "intimidation preempts the route")
	var before_t: int = _order(t).size()
	await wait_seconds(2.0)
	assert_eq(_order(t).size(), before_t, "a panicked civilian does not resume its route")
	assert_eq(_order(o).size(), 1, "an intimidated civilian does not resume its route")
	assert_false(bt.mode == CivilianBrain.Mode.WANDER and bt._route_walking, "no route walk after panic")
	assert_eq(r2.stop_count(), 2, "coffee route intact")
