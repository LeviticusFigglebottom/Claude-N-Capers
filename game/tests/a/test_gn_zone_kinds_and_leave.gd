## D-103 §6 / QC-51 (Gallery Night last call): HeistMission.set_zone_kind flips a MapZone's kind for the rest of the
## run (stealth reads it live; replicated through the HeistNetSync "zones" service), and civilians_leave() walks every
## calm civilian to the nearest PatrolPoint tagged &"exit" where it despawns: no alarm, no kill. Refused once loud.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1107, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func test_gn_set_zone_kind_flips_the_zone_and_replicates() -> void:
	await _launch()
	var z: MapZone = ATestMaps.add_zone(_rt.map, MapZone.Kind.PUBLIC, Vector3(0, 1, -8), Vector3(4, 2, 4))
	await wait_physics_frames(2)
	var p: Vector3 = Vector3(0, 1, -8)
	assert_true(_rt.stealth.in_zone(p, MapZone.Kind.PUBLIC), "public before last call")
	_rt.mission.set_zone_kind(_rt.map.get_path_to(z), MapZone.Kind.RESTRICTED)
	assert_true(_rt.stealth.in_zone(p, MapZone.Kind.RESTRICTED), "restricted now")
	assert_false(_rt.stealth.in_zone(p, MapZone.Kind.PUBLIC), "no longer public")
	assert_true(z.is_in_group(G.RESTRICTED_AREA) and not z.is_in_group(G.CASING_PUBLIC_AREA), "group moved")
	var svc: Dictionary = _rt.net_sync.services_state()
	assert_true(svc.has(HeistNetSync.SVC_ZONES), "zones in the service state")
	# A client copy: put the zone back to PUBLIC and apply what the host sends.
	ZoneKinds.apply_kind(z, MapZone.Kind.PUBLIC)
	assert_true(z.is_in_group(G.CASING_PUBLIC_AREA), "reset for the client check")
	_rt.net_sync.apply_services({HeistNetSync.SVC_ZONES: svc[HeistNetSync.SVC_ZONES]})
	assert_eq(z.kind, MapZone.Kind.RESTRICTED, "client applies the override")
	assert_true(z.is_in_group(G.RESTRICTED_AREA) and not z.is_in_group(G.CASING_PUBLIC_AREA), "client group moved")


func test_gn_calm_civilians_walk_out_and_despawn_without_alarm() -> void:
	await _launch()
	var exit_pp: PatrolPoint = PatrolPoint.new()
	exit_pp.tags = [&"exit"]
	_rt.map.add_child(exit_pp)
	exit_pp.global_position = Vector3(6, 0.05, 0)
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(1, 0.05, 0)), {"idle_activity": &"browse"})
	var tied: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(-3, 0.05, 2)), {"idle_activity": &"browse"})
	await wait_physics_frames(2)
	var tb: CivilianBrain = tied.get_node(^"Brain") as CivilianBrain
	tb.mode = CivilianBrain.Mode.TIED
	var brain: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	assert_eq(_rt.mission.civilians_leave(), 1, "only the calm one leaves")
	assert_eq(brain.mode, CivilianBrain.Mode.LEAVE, "walking out")
	assert_eq(tb.mode, CivilianBrain.Mode.TIED, "a tied hostage stays")
	var civ_id: int = civ.get_instance_id()
	Engine.time_scale = 3.0
	var gone: bool = await wait_until(func() -> bool: return not is_instance_id_valid(civ_id), 12.0 * 3.0)
	Engine.time_scale = 1.0
	assert_true(gone, "despawned at the exit")
	assert_false(_rt.went_loud, "no alarm")
	assert_eq(_rt.npcs(&"civilian").size(), 1, "the hostage is still there")


func test_gn_civilians_leave_refused_when_loud() -> void:
	await _launch()
	var exit_pp: PatrolPoint = PatrolPoint.new()
	exit_pp.tags = [&"exit"]
	_rt.map.add_child(exit_pp)
	exit_pp.global_position = Vector3(6, 0.05, 0)
	var civ: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(1, 0.05, 0)), {"idle_activity": &"browse"})
	await wait_physics_frames(2)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	assert_eq(_rt.mission.civilians_leave(), 0, "loud: nobody walks out")
	assert_false((civ.get_node(^"Brain") as CivilianBrain).mode == CivilianBrain.Mode.LEAVE, "panics instead")
