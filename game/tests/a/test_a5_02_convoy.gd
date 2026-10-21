## A5-02 (Rolling Thunder QC-82, D-149.1 / D-149.8): convoy_vehicle drives a Path3D onto its stop marker with braking,
## ends static there (vehicle_stopped) and carries its children (an armored_truck); ConvoyLayouts swaps the stopped
## layout's pre-baked nav, cover and bodies in and every other layout (and the open-road nav) out.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_convoy", 502, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _path(points: Array[Vector3]) -> Path3D:
	var p: Path3D = Path3D.new()
	p.name = "Route"
	p.curve = Curve3D.new()
	for v: Vector3 in points:
		p.curve.add_point(v)
	_rt.map.add_child(p)
	return p


func _marker(pos: Vector3, yaw_deg: float) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	_rt.map.add_child(m)
	m.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	return m


func test_drives_the_path_brakes_and_stops_on_the_marker_carrying_its_truck() -> void:
	var path: Path3D = _path([Vector3(-30, 0, -20), Vector3(-10, 0, -20), Vector3(0, 0, -12)] as Array[Vector3])
	var stop: Marker3D = _marker(Vector3(2, 0, -8), 30.0)
	var made: Array[Node] = []
	var v: ConvoyVehicle = ATestMaps.add_prefab(_rt, "convoy_vehicle", Vector3(-40, 0, -40), func(n: Node) -> void:
		var truck: Node3D = (load("res://systems/prefabs/armored_truck/armored_truck.tscn") as PackedScene).instantiate()
		truck.name = "Truck"
		n.add_child(truck)
		made.append(truck)) as ConvoyVehicle
	await wait_physics_frames(2)
	var truck: ArmoredTruck = made[0] as ArmoredTruck
	var stopped: Array[int] = []
	var started: Array[int] = []
	v.vehicle_stopped.connect(func(id: int) -> void: stopped.append(id))
	v.drive_started.connect(func(id: int) -> void: started.append(id))
	assert_eq(v.seats().size(), 4, "placeholder Seat0..3")
	v.drive(path, stop)
	assert_eq(v.stage, ConvoyVehicle.Stage.DRIVING)
	assert_eq(started, [v.net_id] as Array[int], "drive_started")
	assert_true(v.global_position.distance_to(Vector3(-30, 0, -20)) < 0.1, "starts at the path start")
	var top: Array[float] = [0.0]  # lambdas capture locals by value
	var ok: bool = await wait_until(func() -> bool:
		top[0] = maxf(top[0], v.speed)
		return v.is_stopped(), 30.0)
	assert_true(ok, "stopped within 30 s (route %.1f m)" % v.route_m)
	assert_true(top[0] <= v.speed_mps + 0.001 and top[0] > v.speed_mps * 0.5, "drove up to speed_mps (top %.2f)" % top[0])
	assert_eq(stopped, [v.net_id] as Array[int], "vehicle_stopped once")
	assert_true(v.global_position.distance_to(stop.global_position) < 0.01, "on the stop marker")
	assert_true(v.global_basis.z.angle_to(stop.global_basis.z) < 0.01, "turned onto the marker's heading")
	assert_true(truck.global_position.distance_to(v.global_position) < 0.01, "the truck rode along")
	await wait_physics_frames(10)
	v.drive(path, stop)
	assert_eq(v.stage, ConvoyVehicle.Stage.STOPPED, "never moves again")
	assert_true(v.global_position.distance_to(stop.global_position) < 0.01, "still on the marker")


func test_park_pops_in_and_brakes_to_zero_at_the_end() -> void:
	var v: ConvoyVehicle = ATestMaps.add_prefab(_rt, "convoy_vehicle", Vector3(-40, 0, -40)) as ConvoyVehicle
	await wait_physics_frames(2)
	var stop: Marker3D = _marker(Vector3(5, 0, -5), -90.0)
	v.park(stop)
	assert_true(v.is_stopped() and v.global_position.distance_to(stop.global_position) < 0.001, "popped in")
	var path: Path3D = _path([Vector3(0, 0, -30), Vector3(0, 0, -10)] as Array[Vector3])
	var w: ConvoyVehicle = ATestMaps.add_prefab(_rt, "convoy_vehicle", Vector3(-40, 0, 40)) as ConvoyVehicle
	await wait_physics_frames(2)
	var end: Marker3D = _marker(Vector3(0, 0, -10), 0.0)
	w.drive(path, end)
	var last_speed: Array[float] = [INF]
	await wait_until(func() -> bool:
		if w.stage == ConvoyVehicle.Stage.DRIVING:
			last_speed[0] = w.speed
		return w.is_stopped(), 20.0)
	assert_true(last_speed[0] < 1.0, "braked to a crawl before the marker (%.2f m/s)" % last_speed[0])


func _layout(id: String, x: float) -> Dictionary:
	var l: Node3D = Node3D.new()
	l.name = "Layout_" + id
	l.set_meta(ConvoyLayouts.META, id)
	_rt.map.add_child(l)
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	l.add_child(nav)
	var link: NavigationLink3D = NavigationLink3D.new()
	l.add_child(link)
	var tp: TacticalPoint = TacticalPoint.new()
	tp.kind = TacticalPoint.Kind.COVER
	tp.position = Vector3(x, 0, -20)
	l.add_child(tp)
	var body: StaticBody3D = StaticBody3D.new()
	l.add_child(body)
	return {"node": l, "nav": nav, "link": link, "tp": tp, "body": body}


func _assert_on(d: Dictionary, on: bool, what: String) -> void:
	assert_eq((d["node"] as Node3D).visible, on, what + " visible")
	assert_eq((d["nav"] as NavigationRegion3D).enabled, on, what + " nav region")
	assert_eq((d["link"] as NavigationLink3D).enabled, on, what + " nav link")
	assert_eq((d["tp"] as TacticalPoint).is_in_group(G.COVER_POINT), on, what + " cover point")
	assert_eq((d["body"] as Node).process_mode == Node.PROCESS_MODE_DISABLED, not on, what + " body collides")


func test_layout_swap_nav_cover_bodies_and_open_road() -> void:
	var a: Dictionary = _layout("north_clean", 1.0)
	var b: Dictionary = _layout("north_crash", 3.0)
	var open: NavigationRegion3D = NavigationRegion3D.new()
	open.set_meta(ConvoyLayouts.META_OPEN_NAV, true)
	_rt.map.add_child(open)
	await wait_physics_frames(1)
	assert_true(_rt.set_convoy_layout(""), "none")
	_assert_on(a, false, "start: clean")
	_assert_on(b, false, "start: crash")
	assert_true(open.enabled, "the open road is walkable before the stop")
	assert_true(_rt.set_convoy_layout("north_crash"))
	assert_eq(_rt.convoy_layout, "north_crash")
	_assert_on(a, false, "crash stop: clean")
	_assert_on(b, true, "crash stop: crash")
	assert_false(open.enabled, "the stopped convoy replaces the open road")
	assert_false(_rt.set_convoy_layout("south_clean"), "unknown layout refused")
	assert_eq(_rt.convoy_layout, "north_crash", "unchanged")
	_assert_on(b, true, "after a refused id")
	assert_eq(ConvoyLayouts.layouts(_rt.map).size(), 2)
	assert_eq(ConvoyLayouts.find(_rt.map, "north_clean"), a["node"])


func test_layout_groups_switch_independently() -> void:
	var stop: Dictionary = _layout("north_clean", 1.0)
	var gone: Dictionary = _layout("mixer_gone", 5.0)
	(gone["node"] as Node).set_meta(ConvoyLayouts.META_GROUP, "mixer")
	var road: NavigationRegion3D = NavigationRegion3D.new()
	road.set_meta(ConvoyLayouts.META_OPEN_NAV, true)
	_rt.map.add_child(road)
	var mixer_road: NavigationRegion3D = NavigationRegion3D.new()
	mixer_road.set_meta(ConvoyLayouts.META_OPEN_NAV, "mixer")
	_rt.map.add_child(mixer_road)
	await wait_physics_frames(1)
	ConvoyLayouts.reset(_rt.map)
	_assert_on(stop, false, "start: convoy")
	_assert_on(gone, false, "start: mixer")
	assert_true(road.enabled and mixer_road.enabled, "both open navs before")
	assert_false(_rt.set_layout("mixer_gone"), "not a convoy-group layout")
	assert_true(_rt.set_convoy_layout("north_clean"))
	assert_true(_rt.set_layout("mixer_gone", "mixer"))
	_assert_on(stop, true, "convoy stopped")
	_assert_on(gone, true, "mixer gone, the convoy layout kept")
	assert_false(road.enabled or mixer_road.enabled, "each open nav swapped out by its own group")
	assert_eq(_rt.layouts, {"convoy": "north_clean", "mixer": "mixer_gone"})
	assert_true(_rt.set_layout("", "mixer"))
	_assert_on(gone, false, "mixer back")
	_assert_on(stop, true, "the convoy layout untouched")
	assert_true(mixer_road.enabled and not road.enabled, "only the mixer's open nav back")
