## ENV C's Gallery Night wiring gaps (GN-C1 step 2d, round 169): civilians_leave by spawn tag with stragglers
## kept, thin_civilians, set_zone_kinds, KeycardPickup.discard (curator_tipsy), an authorised NPC opening a push-bar
## door from outside (the dock smoker back into LD), and the HeistMission wrappers (has_asset, disable_alarm_group).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(map: PackedScene = null) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1120, Enums.Difficulty.ROUTINE, self,
		{"map_packed": map if map != null else ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func _civ(pos: Vector3, tags: Array) -> NpcBase:
	return _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos), {"idle_activity": &"browse", "tags": tags})


func _brain(n: NpcBase) -> CivilianBrain:
	return n.get_node(^"Brain") as CivilianBrain


func test_gn_leave_by_spawn_tag_keeps_staff_and_stragglers() -> void:
	await _launch()
	var exit_pp: PatrolPoint = PatrolPoint.new()
	exit_pp.tags = [&"exit_guests"]
	_rt.map.add_child(exit_pp)
	exit_pp.global_position = Vector3(8, 0.05, 0)
	var p1: NpcBase = _civ(Vector3(1, 0.05, 0), [&"civ_patron"])
	var p2: NpcBase = _civ(Vector3(1, 0.05, 2), [&"civ_patron"])
	var p3: NpcBase = _civ(Vector3(1, 0.05, -2), [&"civ_patron"])
	var curator: NpcBase = _civ(Vector3(-2, 0.05, 0), [&"civ_curator"])
	await wait_physics_frames(2)
	var left: int = _rt.mission.civilians_leave(&"exit_guests", [&"civ_patron"] as Array[StringName], 1)
	assert_eq(left, 2, "two patrons leave, one straggler stays")
	var leaving: int = 0
	for p: NpcBase in [p1, p2, p3]:
		if _brain(p).mode == CivilianBrain.Mode.LEAVE:
			leaving += 1
	assert_eq(leaving, 2, "two walking out")
	assert_false(_brain(curator).mode == CivilianBrain.Mode.LEAVE, "staff stay (spawn tag filter)")


func test_gn_thin_civilians_and_zone_kinds() -> void:
	await _launch()
	for i: int in range(4):
		_civ(Vector3(float(i), 0.05, -3), [&"civ_patron"])
	_civ(Vector3(0, 0.05, 3), [&"civ_curator"])
	await wait_physics_frames(2)
	assert_eq(_rt.mission.thin_civilians(&"civ_patron", 2), 2, "two of four patrons removed")
	await wait_physics_frames(2)
	assert_eq(_rt.npcs(&"civilian").size(), 3, "two patrons + the curator remain")
	var a: MapZone = ATestMaps.add_zone(_rt.map, MapZone.Kind.PUBLIC, Vector3(0, 1, -8), Vector3(3, 2, 3))
	var b: MapZone = ATestMaps.add_zone(_rt.map, MapZone.Kind.PUBLIC, Vector3(6, 1, -8), Vector3(3, 2, 3))
	var c: MapZone = ATestMaps.add_zone(_rt.map, MapZone.Kind.SECURE_LOOT, Vector3(-6, 1, -8), Vector3(3, 2, 3))
	await wait_physics_frames(2)
	assert_eq(_rt.mission.set_zone_kinds(MapZone.Kind.PUBLIC, MapZone.Kind.RESTRICTED), 2, "both public zones")
	assert_true(a.kind == MapZone.Kind.RESTRICTED and b.kind == MapZone.Kind.RESTRICTED, "restricted now")
	assert_eq(c.kind, MapZone.Kind.SECURE_LOOT, "other kinds untouched")


func test_gn_discard_carried_card_and_mission_wrappers() -> void:
	await _launch()
	var cur: NpcBase = _civ(Vector3(2, 0.05, -3), [&"civ_curator"])
	var card: KeycardPickup = ATestMaps.add_prefab(_rt, "keycard_pickup", Vector3(-5, 1, 5), func(p: GameplayPrefab) -> void:
		(p as KeycardPickup).carrier_tag = &"civ_curator") as KeycardPickup
	await wait_physics_frames(3)
	assert_eq(card.carrier_id, cur.net_id, "carried")
	var id: int = card.get_instance_id()
	card.discard()
	await wait_physics_frames(2)
	assert_false(is_instance_id_valid(id), "curator_tipsy: her card is gone")
	assert_false(_rt.mission.has_asset(&"asset.intel_list"), "no assets bought in a unit run")
	_rt.mission.disable_alarm_group(&"argus_upper")
	assert_false(AlarmGroups.is_live(_rt, &"argus_upper"), "disable_alarm_group wraps AlarmGroups")
	assert_true(_rt.mission.rare_effects().is_empty(), "no rare events on the unit map")


func test_gn_authorised_npc_opens_a_push_bar_door_from_outside() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1121, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_doorway_wall(0, 0)})
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "nav synced")
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, func(p: GameplayPrefab) -> void:
		(p as Door).push_bar = true
		(p as Door).npc_authorized_tags = [&"guard_mews"] as Array[StringName]) as Door
	await wait_physics_frames(2)
	# Outside is +Z (A2-08).
	var smoker: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 3)), {"tags": [&"guard_mews"]})
	var other: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(1, 0.05, 3)), {"tags": [&"guard_hall"]})
	await wait_physics_frames(2)
	assert_false(door.is_inside(smoker), "setup: outside")
	assert_true(door.can_npc_open(smoker), "the authorised smoker can come back in")
	assert_false(door.can_npc_open(other), "an unauthorised guard outside still cannot")
	assert_true((door.get_node("NavLink") as NavigationLink3D).bidirectional, "two-way link for the key holder")
