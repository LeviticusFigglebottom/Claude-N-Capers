## A1-04: detection meters (S2.1), fill-rate formula (S2.2), DR table (S2.3), crouch (S2.5) and
## the loud transition stopping all stealth processing (S11.2).
extends TestCase

var _rt: HeistRuntime = null
var _st: StealthDirector = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0})
	_st = _rt.stealth
	# The resolved default loadout now sets a real DR (D-026 follow-up); these formula tests use DR 35.
	(_rt.crew_controller(0) as CrewController).loadout.detection_risk = Tweak.stealth().default_detection_risk


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _place(pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> void:
	_rt.teleport_crew(0, Transform3D(Basis.looking_at(facing, Vector3.UP), pos))
	await wait_physics_frames(2)


func _guard(pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> NpcBase:
	return ATestMaps.add_npc_observer(_rt, &"guard", pos, facing)


func test_s2_1_meter_starts_at_dr_fills_with_los_and_decays() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	await _place(Vector3(0, 0.05, 12))  # behind the guard: no LOS cone
	var g: NpcBase = _guard(Vector3.ZERO)
	var events: Array[float] = []
	var cb: Callable = func(_oid: int, slot: int, v: float, _k: int) -> void:
		if slot == 0:
			events.append(v)
	EventBus.detection_progress.connect(cb)
	await wait_physics_frames(10)
	assert_near(_st.detection_value(g, 0), 0.0, 0.0001, "no LOS: no fill")
	await _place(Vector3(0, 0.05, -8))
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.0, 1.0)
	assert_true(ok, "meter starts filling with LOS")
	var first: float = _st.detection_value(g, 0)
	assert_true(first >= 0.35 - 0.001 and first < 0.55, "S2.1 starts at DR/100 = 0.35 (got %f)" % first)
	await _place(Vector3(0, 0.05, 6))  # out of view again
	var v0: float = _st.detection_value(g, 0)
	await wait_seconds(0.6)
	var v1: float = _st.detection_value(g, 0)
	assert_true(v1 < v0, "S2.1 decays without LOS (%f -> %f)" % [v0, v1])
	# D-128: PD2 drain, 0.125 progress/s, shown through the DR offset (x (1 - 0.35)).
	assert_near(v0 - v1, Tweak.stealth().npc_decay_per_s * 0.65 * 0.6, 0.04, "PD2 decay 0.125/s")
	ok = await wait_until(func() -> bool: return _st.detection_value(g, 0) <= 0.0, 9.0)
	assert_true(ok, "decays to 0")
	await wait_physics_frames(2)
	EventBus.detection_progress.disconnect(cb)
	assert_true(events.size() >= 2, "detection_progress emitted for the local crew member")
	assert_true(events.max() >= 0.35, "progress carried the meter value")
	assert_near(events[events.size() - 1], 0.0, 0.0001, "final progress is 0 (indicator cleared)")


func test_s2_2_fill_rate_formula_distance_and_angle() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _guard(Vector3.ZERO)
	await _place(Vector3(0, 0.05, -4))
	var r_near: float = _st.fill_rate(g, c)
	# S2.2 / D-128: rate = 1 / PD2 delay; d from eye (1.62) to chest (1.05 above feet).
	var d: float = Vector3(0, 1.62, 0).distance_to(Vector3(0, 1.05, -4))
	assert_near(1.0 / r_near, lerpf(0.4, 2.0, 0.75 * d / 20.0), 0.01, "S2.2 PD2 delay at 4 m, centred")
	await _place(Vector3(0, 0.05, -18))
	var r_far: float = _st.fill_rate(g, c)
	assert_true(r_far > 0.0 and r_far < r_near, "closer fills faster (%f vs %f)" % [r_near, r_far])
	await _place(Vector3(0, 0.05, -10))
	var r_centre: float = _st.fill_rate(g, c)
	var off: Vector3 = Vector3(-sin(deg_to_rad(45.0)), 0, -cos(deg_to_rad(45.0))) * 10.0
	await _place(off + Vector3(0, 0.05, 0))
	var r_edge: float = _st.fill_rate(g, c)
	assert_true(r_edge < r_centre, "centre fills faster than the edge")
	var de: float = Vector3(0, 1.62, 0).distance_to(off + Vector3(0, 1.05, 0))
	assert_near(1.0 / r_edge, lerpf(0.4, 2.0, 0.75 * de / 20.0 + 0.25 * 45.0 / 60.0), 0.01, "S2.2 PD2 angle term")
	# PD2: the view narrows to +-60 deg only from 8.5 m (all round within 1.5 m), so test 75 deg at 10 m.
	var outside: Vector3 = Vector3(-sin(deg_to_rad(75.0)), 0, -cos(deg_to_rad(75.0))) * 10.0
	await _place(outside + Vector3(0, 0.05, 0))
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "outside half FOV: no fill")
	var before: float = _st.detection_value(g, 0)
	await wait_seconds(0.4)
	assert_true(_st.detection_value(g, 0) < before or before <= 0.0, "outside FOV: meter only decays")


func test_s2_2_beyond_far_and_wall_no_fill() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _guard(Vector3(0, 0, 25))
	await _place(Vector3(0, 0.05, -6.5))  # 31.5 m > PD2 range min(40, 20) at DR 35
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "beyond range: no fill")
	await _place(Vector3(0, 0.05, 15))
	assert_true(_st.fill_rate(g, c) > 0.0, "in range")
	ATestMaps.add_wall(_rt.map, Vector3(0, 2, 20), Vector3(6, 4, 0.4))
	await wait_physics_frames(2)
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "wall blocks LOS")


func test_s2_3_dr_table_and_rates() -> void:
	assert_near(_st.detection_risk_mult(3), 1.55, 0.0001, "DR3 x1.55")
	assert_near(_st.detection_risk_mult(35), 1.0, 0.0001, "DR35 x1.0")
	assert_near(_st.detection_risk_mult(75), 0.3, 0.0001, "DR75 x0.3")
	assert_near(_st.detection_risk_mult(5), 1.5125, 0.0001, "interpolated")
	var c: CrewController = _crew()
	c.set_masked()
	c.loadout = Loadout.new()
	var g: NpcBase = _guard(Vector3(0, 0, 20))
	await _place(Vector3(0, 0.05, 12))
	c.loadout.detection_risk = 3
	var r3: float = _st.fill_rate(g, c)
	c.loadout.detection_risk = 75
	var r75: float = _st.fill_rate(g, c)
	assert_true(r3 > 0.0 and r3 < r75, "S2.3 DR 3 slower than DR 75 (%f vs %f)" % [r3, r75])
	await _place(Vector3(0, 0.05, -6))  # 26 m: beyond 20/sqrt(1.55) = 16.1 (D-128 PD2 range)
	c.loadout.detection_risk = 3
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "DR 3: range shrinks below 26 m")
	c.loadout.detection_risk = 75
	assert_true(_st.fill_rate(g, c) > 0.0, "DR 75: range 20/sqrt(0.3) = 36.5 m")
	await _place(Vector3(0, 0.05, 12))
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.0, 1.0)
	assert_true(ok)
	assert_true(_st.detection_value(g, 0) >= 0.75 - 0.001, "S2.1 DR 75 starts at 0.75")


func test_s2_5_crouch_multiplies_rate() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _guard(Vector3.ZERO)
	await _place(Vector3(0, 0.05, -6))
	var stand: float = _st.fill_rate(g, c)
	var i: CrewIntent = CrewIntent.new()
	i.crouch = true
	_rt.set_bot_intent(0, i)
	var ok: bool = await wait_until(func() -> bool: return c.crouched, 1.0)
	assert_true(ok, "crouched")
	var crouch: float = _st.fill_rate(g, c)
	# D-128 S2.5: PD2 crouch shrinks the guard's range to 12 m (whisper_mode_crouch), not a rate multiplier.
	var d: float = g.eye_position().distance_to(c.global_position + Vector3.UP * minf(1.0, c.eye_height()))
	assert_true(crouch > 0.0 and crouch < stand, "crouched fills slower at 6 m (%f vs %f)" % [crouch, stand])
	assert_near(1.0 / crouch, _st.fill_time(&"guard", 35, d, 0.0, true), 0.02, "S2.5 PD2 crouch delay")
	await _place(Vector3(0, 0.05, -14))
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "crouched at 14 m: beyond the 12 m crouch range")


func test_s2_2_modifier_and_difficulty_scale_rate() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _guard(Vector3.ZERO)
	await _place(Vector3(0, 0.05, -6))
	var base: float = _st.fill_rate(g, c)
	Modifiers.set_source(0, &"test", {&"stealth.detection_rate_mult": 0.5})
	assert_near(_st.fill_rate(g, c), base * 0.5, 0.001, "Modifiers stealth.detection_rate_mult")
	Modifiers.clear_source(0, &"test")
	# A copy: the DifficultyDef is the cached shared resource, and mutating it leaked x2 into later tests
	# (test_s3_8_cameras' crouch delay read exactly half in the round-229 gate).
	_rt.difficulty_def = _rt.difficulty_def.duplicate() as DifficultyDef
	_rt.difficulty_def.detection_speed_mult = 2.0
	assert_near(_st.fill_rate(g, c), base * 2.0, 0.001, "difficulty detection_speed_mult")


func test_s11_2_detection_stops_when_loud() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _guard(Vector3.ZERO)
	var detected: Array[Node] = []
	_st.crew_detected.connect(func(_o: Node, cr: Node) -> void: detected.append(cr))
	var heard: Array[StringName] = []
	g.noise_heard.connect(func(_p: Vector3, k: StringName, _s: int) -> void: heard.append(k))
	await _place(Vector3(0, 0.05, -15))  # D-128: inside the PD2 20 m range at DR 35
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.0, 1.0)
	assert_true(ok, "filling before the alarm")
	_st.raise_alarm(&"test")
	await wait_physics_frames(3)
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD, "S11.2 STEALTH -> LOUD")
	assert_false(_st.is_stealth())
	assert_near(_st.detection_value(g, 0), 0.0, 0.0001, "meters cleared on loud")
	await _place(Vector3(0, 0.05, -2))
	await wait_seconds(1.0)
	assert_near(_st.detection_value(g, 0), 0.0, 0.0001, "no detection while loud")
	assert_eq(detected.size(), 0, "no crew_detected while loud")
	_rt.make_noise(Vector3(0, 1, -1), 20.0, &"gunshot")
	assert_eq(heard.size(), 0, "no stealth noise propagation while loud")
