## RT-A5 (Rolling Thunder QC-83, D-149.7): the mission's ambush hooks. raise_alarm(reason) from the mission; a convoy
## unit (meta alarm_reason) turns its radio call or its death into that alarm, never a pager; spawn_units seats units
## in a ConvoyVehicle (paused, hidden in an armoured one, not a bot target) sharing the police cap, dismount_units puts
## them on the road awake; civilians_flee empties the street at the alarm (run to a civ_flee exit, despawn).
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1130, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_mission_raise_alarm_reason() -> void:
	assert_false(_rt.went_loud)
	_rt.mission.raise_alarm(&"ambush")
	await wait_physics_frames(3)
	assert_true(_rt.went_loud, "the mission's alarm goes loud")
	assert_eq(_rt.stealth.alarm_reason, &"ambush")


func test_convoy_unit_death_is_the_ambush_not_a_pager() -> void:
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(4, 0.05, -6), Vector3.BACK)
	g.set_meta(StealthDirector.META_ALARM_REASON, &"ambush")
	await wait_physics_frames(2)
	var pagers: PagerSystem = _rt.service(G.SVC_PAGERS) as PagerSystem
	assert_eq(pagers.start_pager(g), 0, "no pager for a convoy unit")
	await wait_physics_frames(3)
	assert_true(_rt.went_loud, "its death raised the alarm")
	assert_eq(_rt.stealth.alarm_reason, &"ambush", "as the ambush")


func test_convoy_unit_radio_call_is_the_ambush() -> void:
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(4, 0.05, -6), Vector3.BACK)
	g.set_meta(StealthDirector.META_ALARM_REASON, &"ambush")
	await wait_physics_frames(1)
	_rt.stealth.raise_alarm(&"guard_radio", g.net_id)
	await wait_physics_frames(2)
	assert_eq(_rt.stealth.alarm_reason, &"ambush")


func test_seated_units_share_the_cap_and_dismount() -> void:
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	var truck: ConvoyVehicle = ATestMaps.add_prefab(_rt, "convoy_vehicle", Vector3(0, 0, -12), func(n: Node) -> void:
		(n as ConvoyVehicle).vehicle_kind = &"truck"
		(n as ConvoyVehicle).rotation = Vector3(deg_to_rad(8.0), 0.0, 0.0)) as ConvoyVehicle  # a stop on a ramp (RT east)
	await wait_physics_frames(2)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var units: Array[NpcBase] = _rt.mission.spawn_units(&"enemy.security_officer", 2, &"", true, truck)
	assert_eq(units.size(), 2, "two units")
	var others: int = units.filter(func(u: NpcBase) -> bool: return not AssaultDirector.POLICE_ROLES.has(u.role)).size()
	assert_eq(dir.police_budget(), mini(dir.force_cap(), dir.enemy_cap() - others),
		"non-police units take police cap (%d of 2 non-police)" % others)
	var bot: CrewAiBrain = CrewAiBrain.of(_rt.crew_controller(1) as CrewController)
	for u: NpcBase in units:
		assert_true(u.has_meta(HeistMission.META_SEATED_IN), "seated")
		assert_eq(u.process_mode, Node.PROCESS_MODE_DISABLED, "paused in the cab")
		assert_false(u.visible, "hidden in an armoured truck")
		assert_true(u.global_position.distance_to(truck.global_position) < 2.5, "on a seat")
		assert_false(bot._is_hostile(u), "not a bot target while seated")
	assert_eq(_rt.mission.dismount_units(units), 2, "both got out")
	for u: NpcBase in units:
		assert_false(u.has_meta(HeistMission.META_SEATED_IN))
		assert_true(u.visible and u.process_mode == Node.PROCESS_MODE_INHERIT, "out and running")
		assert_eq(u.alert_state, Enums.AlertState.COMBAT, "awake: it is loud")
		assert_true(u.global_basis.y.angle_to(Vector3.UP) < 0.01, "stands upright off a tilted seat")
		var local: Vector3 = truck.to_local(u.global_position)
		assert_true(absf(local.x) > 1.5, "beside the truck, not inside (x %.2f)" % local.x)
		assert_true(bot._is_hostile(u), "a target once out")


func test_civilians_flee_the_street_at_the_alarm() -> void:
	var exit_pp: PatrolPoint = PatrolPoint.new()
	exit_pp.tags = [&"civ_flee"]
	_rt.map.add_child(exit_pp)
	exit_pp.global_position = Vector3(8, 0.05, 0)
	var civs: Array[NpcBase] = []
	for z: float in [0.0, 2.0, -2.0]:
		civs.append(_rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(2, 0.05, z)), {"idle_activity": &"browse"}))
	await wait_physics_frames(2)
	_rt.mission.raise_alarm(&"ambush")
	await wait_physics_frames(3)
	assert_eq(_rt.mission.civilians_flee(&"civ_flee"), 3, "all three run")
	for c: NpcBase in civs:
		assert_eq((c.get_node(^"Brain") as CivilianBrain).mode, CivilianBrain.Mode.LEAVE, "running out")
	var gone: bool = await wait_until(func() -> bool:
		return civs.all(func(c: Variant) -> bool: return not is_instance_valid(c) or not (c as Node).is_inside_tree()), 15.0)
	assert_true(gone, "they reached the exit and despawned")
	assert_eq(_rt.mission.civilians_flee(&"nowhere"), 0, "no exit: nobody moves")
