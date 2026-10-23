## A2-03 / S8.4: ECM jammer. 2 s deploy, 20 s jam x stealth.ecm_duration_mult, flashing for the
## last 8 s, jams cameras (SecurityCamera.set_suppressed) and phones, chains sequentially,
## does not stop an already-started S3.5 camera countdown. stealth.ecm_extra adds units.
## S8.5: stealth.ecm_opens_doors on a keycard reader.
extends TestCase


var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func after_each() -> void:
	Engine.time_scale = 1.0
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	_events.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(civilians: int = 0) -> void:
	var l: Loadout = Loadout.new()
	l.deployable = &"deployable.ecm"
	ADeployableGateUtil.grant(l)  # D-111 gate flag, no extra units
	_rt = await HeistLauncher.launch(&"unit_map", 84, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, civilians), "ai_teammates": 0, "skip_casing": true, "loadouts": {0: l}})
	_listen(EventBus.ecm_started, &"ecm_started")
	_listen(EventBus.ecm_ended, &"ecm_ended")
	_listen(EventBus.alarm_raised, &"alarm_raised")


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null) -> void:
		_events.append([tag, a, b])
	sig.connect(cb)
	_conns.append([sig, cb])


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _sys() -> DeployableSystem:
	return _rt.service(DeployableSystem.SERVICE) as DeployableSystem


func _ecm() -> EcmSystem:
	return HeistRuntime.get_service(&"ecm") as EcmSystem


func _stand(pos: Vector3 = Vector3(0, 0.05, 0)) -> CrewController:
	var c: CrewController = _crew()
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(3)
	return c


## A SecurityCamera 6 m in front of `pos` looking back at it.
func _camera_facing(pos: Vector3) -> SecurityCamera:
	var at: Vector3 = pos + Vector3(0, 2.5, -6)
	var xf: Transform3D = Transform3D(Basis.looking_at(pos + Vector3(0, 1.0, 0) - at, Vector3.UP), at)
	return ATestMaps.add_prefab(_rt, "security_camera", at, func(p: GameplayPrefab) -> void:
		p.transform = xf) as SecurityCamera


func test_s8_4_deploy_2s_and_duration_and_flashing() -> void:
	await _launch()
	await _stand()
	assert_eq(_sys().deployable_count(0), 1, "1 ECM base")
	var i: CrewIntent = CrewIntent.new()
	i.deploy = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(1.5)
	assert_true(_sys().placed(&"ecm").is_empty(), "not yet at 1.5 s")
	await wait_seconds(0.8)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)
	assert_eq(_sys().placed(&"ecm").size(), 1, "placed after 2 s")
	assert_true(_ecm().is_jamming(), "jamming")
	assert_eq(_of(&"ecm_started").size(), 1, "ecm_started [R]")
	if _of(&"ecm_started").size() == 1:
		assert_near(float(_of(&"ecm_started")[0][2]), 20.0, 0.001, "20 s jam")
	assert_false(_ecm().is_flashing(), "not flashing at the start")
	await wait_seconds(0.3)
	assert_true(_rt.hud_model.ecm_time_left_s > 15.0, "HUD ecm_time_left_s (%.2f)" % _rt.hud_model.ecm_time_left_s)
	var p: DeployablePrefab = _sys().placed(&"ecm")[0] as DeployablePrefab
	p.jam_left = 7.9
	await wait_physics_frames(2)
	assert_true(_ecm().is_flashing() and p.flashing, "flashing during the last 8 s")
	p.jam_left = 0.05
	await wait_physics_frames(4)
	assert_false(_ecm().is_jamming(), "ended")
	assert_eq(_of(&"ecm_ended").size(), 1, "ecm_ended [R]")
	await wait_physics_frames(2)
	assert_true(_rt.hud_model.ecm_time_left_s < 0.0, "HUD timer cleared")


func test_s8_4_duration_mult_and_extra_units() -> void:
	Modifiers.set_source(0, &"test", {&"stealth.ecm_duration_mult": 1.25, &"stealth.ecm_extra": 1})
	await _launch()
	var c: CrewController = await _stand()
	assert_eq(_sys().deployable_count(0), 2, "stealth.ecm_extra +1")
	_sys().place(c)
	await wait_physics_frames(2)
	assert_eq(_of(&"ecm_started").size(), 1)
	if _of(&"ecm_started").size() == 1:
		assert_near(float(_of(&"ecm_started")[0][2]), 25.0, 0.001, "20 x 1.25")


func test_s8_4_jams_cameras_but_not_started_countdown() -> void:
	await _launch()
	var c: CrewController = await _stand()
	_sys().place(c)
	await wait_physics_frames(2)
	var cam: SecurityCamera = _camera_facing(c.global_position)
	await wait_physics_frames(3)
	assert_true(cam.is_suppressed(), "camera suppressed by the jam")
	assert_false(cam.can_observe(), "jammed camera is blind")
	await wait_seconds(1.5)
	assert_near(_rt.detection_value(cam, 0), 0.0, 0.0001, "jammed camera does not fill")
	assert_true(_rt.stealth.camera_countdown() < 0.0, "jammed camera never alerts")
	# End the jam: the camera sees again.
	var p: DeployablePrefab = _sys().placed(&"ecm")[0] as DeployablePrefab
	p.jam_left = 0.01
	await wait_physics_frames(3)
	assert_false(cam.is_suppressed(), "released after the jam")
	var ok: bool = await wait_until(func() -> bool: return _rt.stealth.camera_countdown() >= 0.0, 8.0)
	assert_true(ok, "unjammed camera alerts: countdown started")
	# S3.5: a new ECM does not stop it.
	_sys().give(0, &"deployable.ecm", 1)
	_sys().place(c)
	await wait_physics_frames(2)
	assert_true(_ecm().is_jamming(), "second ECM jamming")
	assert_true(_rt.stealth.camera_countdown() >= 0.0, "S3.5: countdown keeps running under ECM")
	ok = await wait_until(func() -> bool: return not _of(&"alarm_raised").is_empty(), Tweak.stealth().camera_alarm_delay_s + 1.0)
	assert_true(ok, "camera alarm still sounds")
	if ok:
		assert_eq(_of(&"alarm_raised")[0][1], &"camera")


func test_s8_4_ecms_chain_sequentially() -> void:
	await _launch()
	var c: CrewController = await _stand()
	_sys().give(0, &"deployable.ecm", 2)
	var a: DeployablePrefab = _sys().place(c) as DeployablePrefab
	var b: DeployablePrefab = _sys().place(c) as DeployablePrefab
	await wait_physics_frames(2)
	assert_eq(_of(&"ecm_started").size(), 1, "second does not start")
	assert_eq(_ecm().queued_count(), 1, "queued")
	assert_eq(b.ecm_state, DeployablePrefab.EcmState.QUEUED)
	assert_eq(_ecm().active_ecm_net_id(), a.net_id)
	a.jam_left = 0.01
	await wait_physics_frames(3)
	assert_eq(_of(&"ecm_ended").size(), 1, "first ended")
	assert_eq(int(_of(&"ecm_ended")[0][1]), a.net_id)
	assert_eq(_of(&"ecm_started").size(), 2, "second started when the first ended")
	assert_eq(int(_of(&"ecm_started")[1][1]), b.net_id)
	assert_true(_ecm().is_jamming(), "still jamming")
	assert_eq(b.ecm_state, DeployablePrefab.EcmState.JAMMING)
	assert_true(b.jam_left > 19.0, "full duration for the queued one")


func test_s8_4_jams_phones() -> void:
	await _launch()
	var c: CrewController = await _stand()
	var phone: Phone = ATestMaps.add_prefab(_rt, "phone", Vector3(4, 0, 4)) as Phone
	await wait_physics_frames(1)
	_sys().place(c)
	await wait_physics_frames(1)
	phone.call_police(0)
	await wait_physics_frames(2)
	assert_true(_of(&"alarm_raised").is_empty(), "jammed phone: no call")
	(_sys().placed(&"ecm")[0] as DeployablePrefab).jam_left = 0.01
	await wait_physics_frames(3)
	phone.call_police(0)
	await wait_physics_frames(2)
	assert_eq(_of(&"alarm_raised").size(), 1, "phone works after the jam")


func test_s8_4_civilian_cannot_complete_phone_call_while_jammed() -> void:
	await _launch(1)
	var c: CrewController = await _stand(Vector3(0, 0.05, 15))
	var civ: NpcBase = _rt.npcs(&"civilian")[0] as NpcBase
	civ.global_position = Vector3(0, 0.05, 0)
	var marker: Node3D = Node3D.new()
	marker.name = "TestPhone"
	_rt.dynamic_root.add_child(marker)
	marker.global_position = Vector3(0, 0.05, -6)
	CivilianTargets.add_call_point(marker, CivilianTargets.REASON_PHONE)
	await wait_physics_frames(2)
	_sys().place(c)
	civ.notify_crew_spotted(c)
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	assert_true(await wait_until(func() -> bool: return b.is_calling(), 5.0), "calling")
	await wait_seconds(Tweak.stealth().civilian_call_s + 1.0)
	assert_true(_of(&"alarm_raised").is_empty(), "jammed: the call never completes")
	assert_true(b.is_calling(), "keeps trying")
	(_sys().placed(&"ecm")[0] as DeployablePrefab).jam_left = 0.01
	assert_true(await wait_until(func() -> bool: return not _of(&"alarm_raised").is_empty(), 2.0), "completes after the jam")


func test_s8_5_ecm_on_keycard_reader_opens_doors() -> void:
	Modifiers.set_source(0, &"test", {&"stealth.ecm_opens_doors": true})
	await _launch()
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(3, 0, -4), func(d: GameplayPrefab) -> void:
		(d as Door).lock = Door.Lock.KEYCARD) as Door
	var reader: KeycardReader = ATestMaps.add_prefab(_rt, "keycard_reader", Vector3(0, 1.2, -1.5), func(r: GameplayPrefab) -> void:
		r.rotation = Vector3(0, PI, 0)) as KeycardReader
	reader.targets = [reader.get_path_to(door)]
	var c: CrewController = await _stand()
	var i: CrewIntent = CrewIntent.new()
	i.look_pitch = -0.1
	i.deploy = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(2.3)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)
	assert_eq(_sys().deployable_count(0), 0, "ECM used")
	assert_false(_ecm().is_jamming(), "a door ECM does not jam")
	assert_false(reader.used, "not yet open")
	await wait_seconds(DeployableTweak.data().ecm_door_open_s + 0.3)
	assert_true(reader.used, "reader opened by the ECM after 4 s")
	assert_true(_sys().placed(&"ecm").is_empty(), "ECM consumed")
	assert_true(c != null)


## A2-03 (S8.5, the ATM half): an ECM aimed at an ATM spot (DrillPoint.ecm_atm) is consumed and opens it after
## ecm_atm_open_s; a spot without the flag is not a target.
func test_s8_5_ecm_on_atm_spot_opens_it() -> void:
	Modifiers.set_source(0, &"test", {&"stealth.ecm_opens_doors": true})
	await _launch()
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(3, 0, -4), func(d: GameplayPrefab) -> void:
		(d as Door).lock = Door.Lock.KEYCARD) as Door
	var atm: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 1.2, -1.5), func(p: GameplayPrefab) -> void:
		p.rotation = Vector3(0, PI, 0)
		(p as DrillPoint).device = DrillPoint.Device.SAW
		(p as DrillPoint).ecm_atm = true) as DrillPoint
	atm.target = atm.get_path_to(door)
	assert_true(atm.ecm_openable(), "an idle ATM spot takes an ECM")
	await _stand()
	var i: CrewIntent = CrewIntent.new()
	i.look_pitch = -0.1
	i.deploy = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(2.3)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)
	assert_eq(_sys().deployable_count(0), 0, "ECM used")
	assert_false(_ecm().is_jamming(), "an ATM ECM does not jam")
	assert_false(door.is_open, "not yet open")
	assert_true(atm.interactable.enabled, "the ATM still waits")
	Engine.time_scale = 4.0
	var opened: bool = await wait_until(func() -> bool: return not atm.interactable.enabled, 12.0)
	Engine.time_scale = 1.0
	assert_true(opened, "opened by the ECM after ecm_atm_open_s (%.1f s)" % DeployableTweak.data().ecm_atm_open_s)
	assert_false(atm.ecm_openable(), "done: no second ECM")
	assert_true(_sys().placed(&"ecm").is_empty(), "ECM consumed")
	assert_true(door.is_open, "its target opened")
