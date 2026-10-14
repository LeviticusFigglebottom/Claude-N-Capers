## PO-5 (S7.5, D-086 playability): customers wander only between public `civilian` PatrolPoints (never
## into RESTRICTED / NO_CIVILIAN zones or onto staff points), staff only between the `staff` points of
## their own area (home point's `staff_*` tags), and nothing counts as "near" across floors.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _point(pos: Vector3, tags: Array[StringName]) -> PatrolPoint:
	var pp: PatrolPoint = PatrolPoint.new()
	pp.tags = tags
	_rt.map.add_child(pp)
	pp.global_position = pos
	return pp


func _civ(pos: Vector3, tags: Array[StringName]) -> NpcBase:
	return _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), {"idle_activity": &"browse", "tags": tags})


func test_po5_customer_and_staff_wander_options_unit_map() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 515, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	var public_pt: PatrolPoint = _point(Vector3(4, 0.05, 0), [&"civilian"])
	var restricted_pt: PatrolPoint = _point(Vector3(-4, 0.05, 0), [&"civilian"])
	var no_civ_pt: PatrolPoint = _point(Vector3(0, 0.05, 6), [&"civilian"])
	var upstairs_pt: PatrolPoint = _point(Vector3(1, 4.05, 2), [&"civilian"])
	var floor_home: PatrolPoint = _point(Vector3(10, 0.05, 0), [&"guard", &"staff", &"staff_floor"])
	var floor_other: PatrolPoint = _point(Vector3(13, 0.05, 2), [&"staff", &"staff_floor"])
	var boh_pt: PatrolPoint = _point(Vector3(12, 0.05, -4), [&"staff", &"staff_boh"])
	ATestMaps.add_zone(_rt.map, MapZone.Kind.RESTRICTED, Vector3(-4, 1, 0), Vector3(3, 3, 3))
	ATestMaps.add_zone(_rt.map, MapZone.Kind.NO_CIVILIAN, Vector3(0, 1, 6), Vector3(3, 3, 3))
	var customer: NpcBase = _civ(Vector3(0, 0.05, 0), [&"civ_customer"])
	var staff: NpcBase = _civ(Vector3(10.5, 0.05, 0.5), [&"civ_staff_floor"])
	await wait_physics_frames(3)
	var targets: CivilianTargets = CivilianTargets.ensure(_rt)
	var radius: float = Tweak.stealth().civilian_wander_radius_m
	var cp: Dictionary = targets.wander_profile(customer, customer.global_position)
	assert_false(bool(cp["staff"]), "a civ_customer is not staff")
	var c_opts: Array[PatrolPoint] = targets.wander_options(customer.global_position, cp, radius)
	assert_has(c_opts, public_pt, "customer may walk to the public civilian point")
	assert_false(c_opts.has(restricted_pt), "never into a RESTRICTED zone")
	assert_false(c_opts.has(no_civ_pt), "never into a NO_CIVILIAN zone")
	assert_false(c_opts.has(upstairs_pt), "a point on the floor above is not near (same-floor check)")
	for p: PatrolPoint in [floor_home, floor_other, boh_pt]:
		assert_false(c_opts.has(p), "customers never use staff points")
	var sp: Dictionary = targets.wander_profile(staff, staff.global_position)
	assert_true(bool(sp["staff"]), "civ_staff_* is staff")
	assert_eq(sp["areas"], [&"staff_floor"] as Array[StringName], "home point's staff area")
	var s_opts: Array[PatrolPoint] = targets.wander_options(staff.global_position, sp, radius)
	assert_has(s_opts, floor_other, "staff walks between the points of its own area")
	assert_false(s_opts.has(boh_pt), "not into another staff area")
	assert_false(s_opts.has(public_pt), "staff stays on staff points")
	# The brain itself only ever picks allowed points.
	var b: CivilianBrain = customer.get_node(^"Brain") as CivilianBrain
	for i: int in range(6):
		b.mode = CivilianBrain.Mode.IDLE
		b._wander_timer = 0.0
		await wait_physics_frames(2)
		assert_eq(b.mode, CivilianBrain.Mode.WANDER, "wanders")
		assert_eq(b.call_target.get("node"), public_pt, "picked the only allowed point")
		(customer.get_node(^"Motor") as NpcMotor).stop()


func test_po5_glasshouse_civilians_keep_to_their_areas() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched glasshouse")
	await wait_physics_frames(5)
	var targets: CivilianTargets = CivilianTargets.ensure(_rt)
	# The navmesh answers path queries a few frames after load: wait until a real query does.
	var civs: Array = _rt.npcs(&"civilian")
	assert_true(civs.size() >= 2, "glasshouse has civilians")
	var a: Vector3 = (civs[0] as Node3D).global_position
	var b: Vector3 = (civs[civs.size() - 1] as Node3D).global_position
	var ready: bool = await wait_until(func() -> bool: return targets.nav_path_length(a, b) < INF, 5.0)
	assert_true(ready, "navmesh answers path queries")
	var radius: float = Tweak.stealth().civilian_wander_radius_m
	var customers: int = 0
	var floor_staff: int = 0
	for n: Node in _rt.npcs(&"civilian"):
		var civ: NpcBase = n as NpcBase
		var tags: Array = civ.spawn_info.get("tags", [])
		# From the civilian's spawn point (it may already be walking, e.g. on the stair, a few frames in).
		var sp: Node3D = civ.spawn_info.get("spawn_point") as Node3D
		var home: Vector3 = sp.global_position if sp != null and is_instance_valid(sp) else civ.global_position
		var prof: Dictionary = targets.wander_profile(civ, home)
		var opts: Array[PatrolPoint] = targets.wander_options(home, prof, radius)
		for p: PatrolPoint in opts:
			assert_true(absf(p.global_position.y - home.y) < 1.0,
				"%s: %s is on its floor" % [tags, p.name])
		if tags.has(&"civ_customer"):
			customers += 1
			assert_false(bool(prof["staff"]), "customer profile")
			assert_false(opts.is_empty(), "customers have somewhere to wander")
			for p: PatrolPoint in opts:
				assert_true(p.tags.has(&"civilian"), "customer -> civilian point (%s)" % p.name)
				var probe: Vector3 = p.global_position + Vector3.UP * Tweak.stealth().zone_probe_height_m
				assert_false(_rt.stealth.in_zone(probe, MapZone.Kind.RESTRICTED), "customer stays public (%s)" % p.name)
		elif tags.has(&"civ_staff_floor"):
			floor_staff += 1
			assert_true(bool(prof["staff"]), "floor associate is staff")
			assert_false(opts.is_empty(), "floor associate circulates")
			for p: PatrolPoint in opts:
				assert_true(p.tags.has(&"staff_floor"), "floor associate -> staff_floor point (%s)" % p.name)
	assert_true(customers >= 1, "glasshouse has customers")
	assert_eq(floor_staff, 1, "glasshouse has the floor associate")
