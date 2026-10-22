## A2-02: the real SecurityCamera prefab as a stealth observer. S8.1 (cone from exports, pan,
## one-shot destroy -> camera_disabled + broken_camera stimulus, Titan), S3.5 (unstoppable countdown
## through a real camera), S4.4 (camera stimulus list, deaf), find_by_tag and LocalHudModel.
extends TestCase

var _rt: HeistRuntime = null
var _st: StealthDirector = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false})
	_st = _rt.stealth


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _place(pos: Vector3) -> void:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(2)


## Real camera prefab at `pos` looking at `target`; `props` are export overrides.
func _camera(pos: Vector3, target: Vector3, props: Dictionary = {}) -> SecurityCamera:
	var setup: Callable = func(p: GameplayPrefab) -> void:
		p.transform = Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)
		for k: String in props:
			p.set(k, props[k])
	var cam: SecurityCamera = ATestMaps.add_prefab(_rt, "security_camera", pos, setup) as SecurityCamera
	await wait_physics_frames(2)
	return cam


func _hit(cam: SecurityCamera, amount: float = 1.0) -> Dictionary:
	var info: Dictionary = Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test",
		cam.global_position, Vector3.FORWARD, _crew().net_id)
	var target: Object = Damage.find_target(cam.get_node(^"Collision"))
	assert_eq(target, cam, "damage.md: the Collision body resolves to the camera")
	return cam.take_hit(info, _crew().net_id)


func test_s8_1_camera_is_an_observer_in_find_by_tag() -> void:
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -6))
	assert_true(cam.is_in_group(G.OBSERVER), "observer protocol group")
	assert_eq(cam.observer_kind(), Enums.ObserverKind.CAMERA)
	assert_true(cam.can_observe())
	assert_has(_rt.find_by_tag(&"security_camera"), cam, "find_by_tag lists untagged cameras")
	assert_has(SecurityCamera.cameras_in(_rt), cam)
	assert_true(cam.look_forward().dot((Vector3(0, 1, -6) - cam.eye_position()).normalized()) > 0.99,
		"view along the Lens -Z")


func test_s8_1_detects_masked_crew_in_cone_not_outside() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -6))
	await _place(Vector3(0, 0.05, -6))
	assert_true(_st.fill_rate(cam, c) > 0.0, "masked crew in the cone fills")
	await _place(Vector3(8, 0.05, -6))
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "53 deg off-axis: outside the 60 deg cone")
	await _place(Vector3(0, 0.05, -24))
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "beyond range_m 20")
	await _place(Vector3(0, 0.05, -6))
	ATestMaps.add_wall(_rt.map, Vector3(0, 1.5, -3.5), Vector3(4, 3, 0.2))
	await wait_physics_frames(2)
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "LOS from the Lens is blocked by a wall")


## P (OF G2 throws: "CameraC9 disabled" at t=2, "ALARM camera by CameraC9" at t=36): a prefab-disabled camera is no
## observer (GameplayPrefab.set_enabled, OF-A2), and observes again once switched back on.
func test_s8_1_disabled_camera_sees_nothing() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -6))
	await _place(Vector3(0, 0.05, -6))
	assert_true(_st.fill_rate(cam, c) > 0.0, "on: masked crew in the cone fills")
	cam.set_enabled(false)
	assert_false(cam.can_observe(), "disabled: not an observer")
	assert_near(_st.fill_rate(cam, c), 0.0, 0.0001, "disabled: no fill")
	cam.set_enabled(true)
	assert_true(cam.can_observe() and _st.fill_rate(cam, c) > 0.0, "switched back on: observes again")


func test_s8_1_cone_from_exports() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var wide: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -6), {"fov_deg": 120.0, "range_m": 12.0})
	await _place(Vector3(6, 0.05, -4))
	assert_true(_st.fill_rate(wide, c) > 0.0, "fov_deg 120 sees 57 deg off-axis")
	await _place(Vector3(0, 0.05, -14))
	assert_near(_st.fill_rate(wide, c), 0.0, 0.0001, "range_m 12: 14 m away is out of range")


func test_s8_1_pans_between_half_arcs() -> void:
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -6), {"pan_deg": 90.0, "pan_period_s": 1.0})
	var rest: Vector3 = Vector3(0, 0, -1)
	var lo: float = INF
	var hi: float = -INF
	for i: int in range(70):
		await wait_physics_frames(1)
		var f: Vector3 = cam.look_forward()
		var yaw: float = rad_to_deg(Vector2(rest.x, rest.z).angle_to(Vector2(f.x, f.z)))
		lo = minf(lo, yaw)
		hi = maxf(hi, yaw)
		assert_true(absf(cam.pan_offset_deg) <= 45.001, "within +-pan_deg/2")
	assert_true(hi - lo > 75.0, "the Head sweeps the arc (got %.1f..%.1f)" % [lo, hi])
	assert_true(absf(cam.look_forward().y) > 0.2, "pan keeps the downward pitch")


func test_s8_1_one_shot_destroy_disables_and_breaks() -> void:
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -6))
	var events: Array = []
	var cb: Callable = func(id: int, reason: StringName) -> void: events.append([id, reason])
	EventBus.camera_disabled.connect(cb)
	var out: Dictionary = _hit(cam, 1.0)
	EventBus.camera_disabled.disconnect(cb)
	assert_true(bool(out["killed"]), "one shot kills below Lethal")
	assert_eq(events, [[cam.net_id, &"destroyed"]], "camera_disabled(id, destroyed) once")
	assert_true(cam.destroyed)
	assert_false(cam.can_observe(), "a broken camera sees nothing")
	var s: Dictionary = _st.stimulus(cam.broken_stimulus_id)
	assert_eq(StringName(s.get("kind", &"")), &"broken_camera", "broken_camera stimulus registered")
	assert_true(Tweak.stealth().stimuli.has(&"broken_camera"))
	var again: Dictionary = _hit(cam, 1.0)
	assert_false(bool(again["killed"]), "already broken")


func test_s8_1_broken_camera_noticed_by_guard() -> void:
	await _place(Vector3(-12, 0.05, 12))
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -6))
	var pos: Vector3 = Vector3(0, 0.05, -8)
	var guard: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.looking_at(Vector3(0, 0, 8), Vector3.UP), pos))
	await wait_physics_frames(3)
	var noticed: Array[int] = []
	var cb: Callable = func(obs: Node, id: int) -> void:
		if obs == guard:
			noticed.append(id)
	_st.stimulus_noticed.connect(cb)
	_hit(cam)
	var ok: bool = await wait_until(func() -> bool: return noticed.has(cam.broken_stimulus_id), 4.0)
	_st.stimulus_noticed.disconnect(cb)
	assert_true(ok, "S8.1 the guard notices the broken camera")
	assert_true(guard.alert_state == Enums.AlertState.CURIOUS or guard.alert_state == Enums.AlertState.INVESTIGATING,
		"broken_camera -> investigate (got %d)" % guard.alert_state)
	assert_false(_st.alarm_raised, "investigate, not alarm")


func test_s8_1_titan_camera_survives() -> void:
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -6), {"titan": true})
	var out: Dictionary = _hit(cam, 9999.0)
	assert_false(bool(out["killed"]), "Titan export: indestructible")
	assert_near(float(out["amount"]), 0.0, 0.0001)
	assert_true(cam.can_observe() and not cam.destroyed)
	var normal: SecurityCamera = await _camera(Vector3(4, 3, 0), Vector3(4, 1, -6))
	_rt.difficulty = Enums.Difficulty.LETHAL
	assert_true(normal.is_titan(), "Lethal+ cameras are Titan")
	assert_false(bool(_hit(normal)["killed"]), "Lethal: one shot does not kill")
	_rt.difficulty = Enums.Difficulty.BRUTAL
	assert_false(normal.is_titan())
	var nd: SecurityCamera = await _camera(Vector3(-4, 3, 0), Vector3(-4, 1, -6), {"destructible": false})
	assert_false(bool(_hit(nd)["killed"]), "destructible = false")


func test_s3_5_real_camera_countdown_unstoppable_and_hud() -> void:
	var tw: StealthTweak = Tweak.stealth()
	var old_delay: float = tw.camera_alarm_delay_s
	tw.camera_alarm_delay_s = 1.5
	var c: CrewController = _crew()
	c.set_masked()
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 1, -4))
	await _place(Vector3(0, 0.05, -4))
	var ok: bool = await wait_until(func() -> bool: return _st.camera_countdown() > 0.0, 6.0)
	assert_true(ok, "S3.5 the real camera starts the countdown")
	assert_true(cam.alerted)
	ok = await wait_until(func() -> bool: return _rt.hud_model.camera_alarm_s > 0.0, 1.0)
	assert_true(ok, "LocalHudModel camera_alarm_s reads the countdown")
	_hit(cam)  # destroying the camera does not stop it
	ok = await wait_until(func() -> bool: return _st.alarm_raised, 3.0)
	tw.camera_alarm_delay_s = old_delay
	assert_true(ok, "alarm after the countdown even with the camera destroyed")
	assert_eq(_st.alarm_reason, &"camera")


func test_s4_4_camera_stimuli_alert_and_deaf() -> void:
	var tw: StealthTweak = Tweak.stealth()
	var old_delay: float = tw.camera_alarm_delay_s
	tw.camera_alarm_delay_s = 30.0
	await _place(Vector3(-12, 0.05, 12))
	var cam: SecurityCamera = await _camera(Vector3(0, 3, 0), Vector3(0, 0, -6))
	var kinds: Array[StringName] = []
	cam.stimulus_spotted.connect(func(_id: int, kind: StringName, _p: Vector3) -> void: kinds.append(kind))
	var door: Node3D = Node3D.new()
	_rt.dynamic_root.add_child(door)
	door.global_position = Vector3(0.5, 0, -6)
	_st.register_stimulus(door, &"open_door")
	_rt.make_noise(Vector3(0, 2, -1), 30.0, &"gunshot")
	await wait_seconds(tw.stimuli[&"open_door"]["fill_time"] + 0.5)
	assert_false(kinds.has(&"open_door"), "S4.4 open doors are not a camera stimulus")
	assert_near(_st.camera_countdown(), -1.0, 0.0001, "cameras do not hear gunshots")
	# Another camera seeing a broken camera alerts (S4.4 broken cameras).
	var victim: SecurityCamera = await _camera(Vector3(0, 2.5, -7), Vector3(0, 2.5, -12))
	_hit(victim)
	var ok: bool = await wait_until(func() -> bool: return kinds.has(&"broken_camera"), 4.0)
	assert_true(ok, "S4.4 cameras see broken cameras")
	assert_true(_st.camera_countdown() > 0.0, "a confirmed camera stimulus starts the S3.5 countdown")
	tw.camera_alarm_delay_s = old_delay
