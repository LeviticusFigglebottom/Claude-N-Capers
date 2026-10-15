## Lead review (PO6 GH capture): civilians react to a nearby execution (PD2). A gunshot within the player
## gunshot radius panics a calm civilian (S3.1 / stimuli "gunshot"); a kill in a civilian's view (corpse
## stimulus) panics it too. A silent kill out of view (the capture's injected damage) need not.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_civ_react", 31, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 20)))


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _civ(pos: Vector3, facing: Vector3) -> NpcBase:
	var b: Basis = Basis.looking_at(facing, Vector3.UP)
	return _rt.spawn_npc(&"civilian", Transform3D(b, pos), {"idle_activity": &"browse"})


func test_gunshot_nearby_panics_a_civilian() -> void:
	var civ: NpcBase = _civ(Vector3(0, 0.05, 0), Vector3(0, 0, -1))
	await wait_physics_frames(5)
	assert_eq(civ.alert_state, Enums.AlertState.CALM, "calm before")
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	_rt.make_noise(Vector3(2, 1, 0), Tweak.stealth().gunshot_player_radius_m, &"gunshot", crew.net_id)
	var ok: bool = await wait_until(func() -> bool: return civ.alert_state != Enums.AlertState.CALM, 2.0)
	assert_true(ok, "a gunshot 2 m away panics the civilian (state %d)" % civ.alert_state)


func test_kill_in_view_panics_a_civilian() -> void:
	var civ: NpcBase = _civ(Vector3(0, 0.05, 0), Vector3(0, 0, -1))
	var victim: NpcBase = _civ(Vector3(0, 0.05, -2.5), Vector3(0, 0, 1))
	await wait_physics_frames(5)
	victim.die({}, 0)
	var ok: bool = await wait_until(func() -> bool: return civ.alert_state != Enums.AlertState.CALM, 4.0)
	assert_true(ok, "a corpse 2.5 m ahead in view panics the civilian (state %d)" % civ.alert_state)
