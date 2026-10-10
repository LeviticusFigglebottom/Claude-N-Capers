## A1-04: casing detection rules (S1.1, S2.8, S3.8), force-mask on detection (S1.2), masked in
## public (S1.4) and movement making no difference behind a guard (S1.5).
extends TestCase

var _rt: HeistRuntime = null
var _st: StealthDirector = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0})
	_st = _rt.stealth


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


func _observer(role: StringName, pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> NpcBase:
	return ATestMaps.add_npc_observer(_rt, role, pos, facing)


func test_s1_1_unmasked_in_restricted_fills_at_casing_rate() -> void:
	var c: CrewController = _crew()
	var g: NpcBase = _observer(&"guard", Vector3.ZERO)
	await _place(Vector3(0, 0.05, -6))
	assert_true(c.is_casing())
	assert_near(_st.fill_rate(g, c), 0.0, 0.0001, "unmasked outside RESTRICTED at 6 m: no fill")
	ATestMaps.add_zone(_rt.map, MapZone.Kind.RESTRICTED, Vector3(0, 1, -6), Vector3(4, 3, 4))
	await wait_physics_frames(2)
	var unmasked: float = _st.fill_rate(g, c)
	assert_true(unmasked > 0.0, "S1.1 unmasked in RESTRICTED fills")
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.0, 1.0)
	assert_true(ok, "meter fills while trespassing")
	c.set_masked()
	var masked: float = _st.fill_rate(g, c)
	assert_near(unmasked / masked, Tweak.stealth().casing_rate_mult, 0.001, "S1.1 casing rate x0.35")


func test_s1_1_unmasked_outside_restricted_stays_zero() -> void:
	var c: CrewController = _crew()
	var g: NpcBase = _observer(&"guard", Vector3.ZERO)
	await _place(Vector3(0, 0.05, -6))
	await wait_seconds(1.0)
	assert_near(_st.detection_value(g, 0), 0.0, 0.0001, "S1.1 unmasked in the open at 6 m: 0")
	await _place(Vector3(0, 0.05, -2))
	assert_true(_st.fill_rate(g, c) > 0.0, "S1.1 too close (<= 3 m) to a guard outside PUBLIC fills")


func test_s1_1_unmasked_in_public_next_to_guard_stays_zero_5s() -> void:
	var c: CrewController = _crew()
	var g: NpcBase = _observer(&"guard", Vector3.ZERO)
	ATestMaps.add_zone(_rt.map, MapZone.Kind.PUBLIC, Vector3(0, 1, -2), Vector3(8, 3, 8))
	await _place(Vector3(0, 0.05, -1.5))
	var max_v: float = 0.0
	for k: int in range(20):
		await wait_seconds(0.25)
		max_v = maxf(max_v, _st.detection_value(g, 0))
	assert_near(max_v, 0.0, 0.0001, "P1 gate: unmasked in PUBLIC next to a guard for 5 s -> 0")
	assert_true(c.is_casing(), "still unmasked")
	var tw: StealthTweak = Tweak.stealth()
	tw.casing_too_close_applies_in_public = true
	var r: float = _st.fill_rate(g, c)
	tw.casing_too_close_applies_in_public = false
	assert_true(r > 0.0, "flag casing_too_close_applies_in_public enables the 3 m rule in PUBLIC")


func test_s1_1_civilians_never_fill_on_unmasked() -> void:
	var c: CrewController = _crew()
	var civ: NpcBase = _observer(&"civilian", Vector3.ZERO)
	ATestMaps.add_zone(_rt.map, MapZone.Kind.RESTRICTED, Vector3(0, 1, -2), Vector3(6, 3, 6))
	await _place(Vector3(0, 0.05, -1.5))
	assert_near(_st.fill_rate(civ, c), 0.0, 0.0001, "civilian, unmasked, RESTRICTED, 1.5 m: no fill")
	await wait_seconds(1.5)
	assert_near(_st.detection_value(civ, 0), 0.0, 0.0001, "S1.1 civilians never fill on unmasked")
	c.set_masked()
	assert_true(_st.fill_rate(civ, c) > 0.0, "S1.4 civilians fill on masked crew")


func test_s1_4_masked_in_public_is_detected() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _observer(&"guard", Vector3.ZERO)
	ATestMaps.add_zone(_rt.map, MapZone.Kind.PUBLIC, Vector3(0, 1, -6), Vector3(8, 3, 8))
	var detected: Array[Node] = []
	_st.crew_detected.connect(func(o: Node, cr: Node) -> void:
		if o == g and cr == c:
			detected.append(cr))
	await _place(Vector3(0, 0.05, -6))
	var ok: bool = await wait_until(func() -> bool: return not detected.is_empty(), 4.0)
	assert_true(ok, "S1.4/S2.8 masked crew in PUBLIC is detected")
	assert_near(_st.detection_value(g, 0), 1.0, 0.0001, "meter full")


func test_s1_2_full_detection_force_masks() -> void:
	var c: CrewController = _crew()
	var g: NpcBase = _observer(&"guard", Vector3.ZERO)
	ATestMaps.add_zone(_rt.map, MapZone.Kind.RESTRICTED, Vector3(0, 1, -3), Vector3(6, 3, 6))
	var spotted: Array[Node] = []
	g.crew_spotted.connect(func(cr: Node) -> void: spotted.append(cr))
	var detected: Array[Node] = []
	_st.crew_detected.connect(func(_o: Node, cr: Node) -> void: detected.append(cr))
	await _place(Vector3(0, 0.05, -2.5))
	assert_false(c.masked)
	var ok: bool = await wait_until(func() -> bool: return c.masked, 6.0)
	assert_true(ok, "S1.2 detection force-masks the crew member")
	assert_eq(detected, [c] as Array[Node], "crew_detected once")
	assert_eq(spotted, [c] as Array[Node], "observer.notify_crew_spotted called")
	await wait_seconds(0.5)
	assert_near(_st.detection_value(g, 0), 1.0, 0.0001, "meter stays at 1.0")
	assert_eq(detected.size(), 1, "not re-detected")


func test_s1_5_sprint_jump_behind_guard_stays_zero() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = _observer(&"guard", Vector3.ZERO, Vector3.FORWARD)
	var noises: Array[float] = []
	_rt.noise_made.connect(func(_p: Vector3, r: float, _k: StringName, _s: int) -> void: noises.append(r))
	await _place(Vector3(-2.5, 0.05, 1.0), Vector3.RIGHT)
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.look_yaw = -PI * 0.5  # aim_direction (+X)
	i.sprint = true
	i.jump = true
	_rt.set_bot_intent(0, i)
	var max_v: float = 0.0
	var min_d: float = 100.0
	for k: int in range(48):
		await wait_physics_frames(1)
		max_v = maxf(max_v, _st.detection_value(g, 0))
		min_d = minf(min_d, Vector2(c.global_position.x, c.global_position.z).length())
	_rt.clear_bot_intent(0)
	assert_true(min_d < 1.3, "passed within ~1 m behind the guard (min %f)" % min_d)
	assert_near(max_v, 0.0, 0.0001, "S1.5 sprint + jump behind a guard: no detection")
	assert_eq(noises.size(), 0, "S1.5 no movement noise")
