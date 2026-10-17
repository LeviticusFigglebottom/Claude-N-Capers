## D-128: detection follows PAYDAY 2's formula (pd2_fidelity S2). Pins the fill time (s, empty -> full) per
## observer preset, DR and distance, at the centre and the edge of the view, against the table derived from
## PD2's Lua (coplogicbase _upd_attention_obj_detection, securitycamera.lua, charactertweakdata ntl presets,
## attentiontweakdata whisper-mode player settings); then the same formula through real observers in the
## world, PD2's instant uncover, the HUD offset start and the drain without sight.
extends TestCase

## PD2 table: [preset, DR, distance m, angle deg, crouched] -> fill time s (0 = instant uncover, -1 = never).
## NPC edge = 58 deg (inside the 60 deg half angle at every range, outside the 55 deg uncover cone);
## camera edge = 29 deg (inside the 60 deg cone's 30 deg half angle).
const TABLE: Array = [
	[&"guard", 3, 1.0, 0.0, false, 0.0], [&"guard", 3, 1.0, 58.0, false, 1.018],
	[&"guard", 3, 10.0, 0.0, false, 1.264], [&"guard", 3, 10.0, 58.0, false, 1.598],
	[&"guard", 3, 20.0, 0.0, false, -1.0], [&"guard", 3, 20.0, 58.0, false, -1.0],
	[&"guard", 35, 1.0, 0.0, false, 0.0], [&"guard", 35, 1.0, 58.0, false, 0.847],
	[&"guard", 35, 10.0, 0.0, false, 1.000], [&"guard", 35, 10.0, 58.0, false, 1.387],
	[&"guard", 35, 20.0, 0.0, false, -1.0], [&"guard", 35, 20.0, 58.0, false, -1.0],
	[&"guard", 75, 1.0, 0.0, false, 0.0], [&"guard", 75, 1.0, 58.0, false, 0.613],
	[&"guard", 75, 10.0, 0.0, false, 0.506], [&"guard", 75, 10.0, 58.0, false, 0.960],
	[&"guard", 75, 20.0, 0.0, false, 0.892], [&"guard", 75, 20.0, 58.0, false, 1.347],
	[&"police", 3, 1.0, 0.0, false, 0.0], [&"police", 3, 1.0, 58.0, false, 1.018],
	[&"police", 3, 10.0, 0.0, false, 1.264], [&"police", 3, 10.0, 58.0, false, 1.598],
	[&"police", 3, 20.0, 0.0, false, -1.0], [&"police", 3, 20.0, 58.0, false, -1.0],
	[&"police", 35, 1.0, 0.0, false, 0.0], [&"police", 35, 1.0, 58.0, false, 0.847],
	[&"police", 35, 10.0, 0.0, false, 1.000], [&"police", 35, 10.0, 58.0, false, 1.387],
	[&"police", 35, 20.0, 0.0, false, -1.0], [&"police", 35, 20.0, 58.0, false, -1.0],
	[&"police", 75, 1.0, 0.0, false, 0.0], [&"police", 75, 1.0, 58.0, false, 0.613],
	[&"police", 75, 10.0, 0.0, false, 0.506], [&"police", 75, 10.0, 58.0, false, 0.960],
	[&"police", 75, 20.0, 0.0, false, 0.892], [&"police", 75, 20.0, 58.0, false, 1.347],
	[&"civilian", 3, 1.0, 0.0, false, 0.0], [&"civilian", 3, 1.0, 58.0, false, 1.196],
	[&"civilian", 3, 10.0, 0.0, false, 1.649], [&"civilian", 3, 10.0, 58.0, false, 2.261],
	[&"civilian", 3, 20.0, 0.0, false, -1.0], [&"civilian", 3, 20.0, 58.0, false, -1.0],
	[&"civilian", 35, 1.0, 0.0, false, 0.0], [&"civilian", 35, 1.0, 58.0, false, 1.054],
	[&"civilian", 35, 10.0, 0.0, false, 1.313], [&"civilian", 35, 10.0, 58.0, false, 1.965],
	[&"civilian", 35, 20.0, 0.0, false, -1.0], [&"civilian", 35, 20.0, 58.0, false, -1.0],
	[&"civilian", 75, 1.0, 0.0, false, 0.0], [&"civilian", 75, 1.0, 58.0, false, 0.853],
	[&"civilian", 75, 10.0, 0.0, false, 0.688], [&"civilian", 75, 10.0, 58.0, false, 1.391],
	[&"civilian", 75, 20.0, 0.0, false, 1.285], [&"civilian", 75, 20.0, 58.0, false, 1.989],
	[&"camera", 3, 1.0, 0.0, false, 4.779], [&"camera", 3, 1.0, 29.0, false, 4.594],
	[&"camera", 3, 10.0, 0.0, false, 3.154], [&"camera", 3, 10.0, 29.0, false, 2.968],
	[&"camera", 3, 20.0, 0.0, false, -1.0], [&"camera", 3, 20.0, 29.0, false, -1.0],
	[&"camera", 35, 1.0, 0.0, false, 3.154], [&"camera", 35, 1.0, 29.0, false, 3.097],
	[&"camera", 35, 10.0, 0.0, false, 2.746], [&"camera", 35, 10.0, 29.0, false, 2.689],
	[&"camera", 35, 20.0, 0.0, false, -1.0], [&"camera", 35, 20.0, 29.0, false, -1.0],
	[&"camera", 75, 1.0, 0.0, false, 1.005], [&"camera", 75, 1.0, 29.0, false, 1.109],
	[&"camera", 75, 10.0, 0.0, false, 1.407], [&"camera", 75, 10.0, 29.0, false, 1.511],
	[&"camera", 75, 20.0, 0.0, false, 1.854], [&"camera", 75, 20.0, 29.0, false, 1.958],
	# S2.5 PD2 crouch (attention whisper_mode_crouch: shorter range; civilians also a x3 delay_min).
	[&"guard", 35, 10.0, 0.0, true, 1.400], [&"guard", 35, 13.0, 0.0, true, -1.0],
	[&"civilian", 35, 10.0, 0.0, true, 1.800], [&"civilian", 35, 3.0, 0.0, true, 0.960],
	[&"camera", 35, 10.0, 0.0, true, 2.634], [&"camera", 35, 13.0, 0.0, true, -1.0],
]
const TOL_S: float = 0.01

var _rt: HeistRuntime = null
var _st: StealthDirector = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false})
	_st = _rt.stealth
	_crew().loadout.detection_risk = 35


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


func _target(c: CrewController) -> Vector3:
	return c.global_position + Vector3.UP * minf(1.0, c.eye_height())


func test_d128_fill_time_table_matches_pd2_formula() -> void:
	for row: Array in TABLE:
		var got: float = _st.fill_time(row[0], float(row[1]), float(row[2]), float(row[3]), bool(row[4]))
		var want: float = float(row[5])
		var label: String = "%s DR%d %.0f m %.0f deg%s" % [row[0], row[1], row[2], row[3], " crouched" if row[4] else ""]
		if want < 0.0:
			assert_true(is_inf(got), "%s: never notices (got %f)" % [label, got])
		else:
			assert_near(got, want, TOL_S, "%s: fill %.3f s" % [label, want])


func test_d128_presets_are_pd2_values() -> void:
	var p: Dictionary = Tweak.stealth().observer_presets
	for k: String in ["far", "fov_deg", "delay_min", "delay_max", "attention"]:
		assert_eq(p[&"guard"][k], p[&"police"][k], "PD2: security and cops share the ntl preset in stealth (%s)" % k)
	assert_near(float(p[&"guard"]["far"]), 40.0, 0.001, "ntl dis_max 4000 cm")
	assert_near(float(p[&"guard"]["fov_deg"]), 120.0, 0.001, "ntl angle_max 60 (half angle)")
	assert_near(float(p[&"civilian"]["delay_max"]), 3.0, 0.001, "civilian ntl delay {0.2, 3}")
	# D-130 (PO): cameras ~20 % faster than PD2's editor default delay {2, 3} (◇).
	assert_near(float(p[&"camera"]["delay_min"]), 1.6, 0.001, "camera delay_min 1.6 (D-130)")
	assert_near(float(p[&"camera"]["delay_max"]), 2.4, 0.001, "camera delay_max 2.4 (D-130)")
	assert_near(_st.detection_risk_mult(3), 1.55, 0.0001, "DR 3 = concealment[29] 1.55")
	assert_near(_st.detection_risk_mult(75), 0.3, 0.0001, "DR 75 = concealment[1] 0.3")


## The same formula through a real guard: fill_rate = 1 / fill_time at the measured distance and angle.
func test_d128_world_guard_rate_matches_formula() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3.ZERO, Vector3.FORWARD)
	for dr: int in [3, 35, 75]:
		c.loadout.detection_risk = dr
		for spot: Vector3 in [Vector3(0, 0.05, -10), Vector3(-4.9, 0.05, -4.9), Vector3(0, 0.05, -18)]:
			await _place(spot)
			var eye: Vector3 = g.eye_position()
			var to: Vector3 = _target(c) - eye
			var f: Vector3 = g.look_forward() if g.has_method(&"look_forward") else -g.global_basis.z
			var ang: float = rad_to_deg(absf(Vector2(f.x, f.z).angle_to(Vector2(to.x, to.z))))
			var want: float = _st.fill_time(&"guard", float(dr), to.length(), ang)
			var r: float = _st.fill_rate(g, c)
			if is_inf(want):
				assert_near(r, 0.0, 0.0001, "DR%d at %s: out of range, no fill" % [dr, spot])
			else:
				assert_near(1.0 / r, want, 0.02, "DR%d at %s: 1 / rate = PD2 delay %.3f" % [dr, spot, want])


func test_d128_uncover_is_instant_in_front_not_behind() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3.ZERO, Vector3.FORWARD)
	await _place(Vector3(0, 0.05, -1.4))
	assert_near(_st.fill_rate(g, c), StealthDirector.INSTANT_RATE, 0.001, "inside 2 m and 55 deg: instant")
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) >= 1.0, 1.0)
	assert_true(ok, "detected within a tick")
	var g2: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(10, 0, 0), Vector3.FORWARD)
	await _place(Vector3(10.3, 0.05, 1.2))  # behind him (~166 deg) inside 1.5 m: all-round vision, no uncover
	var r: float = _st.fill_rate(g2, c)
	assert_true(r > 0.0 and r < StealthDirector.INSTANT_RATE, "behind at 1.3 m: seen, not instant (rate %f)" % r)
	assert_near(1.0 / r, 0.4 + 1.6 * (0.75 * (_target(c) - g2.eye_position()).length() / 20.0 + 0.25), 0.02,
		"PD2 delay with the angle term capped at 1")


## The meter appears at DR/100 (PD2 HUD offset) and fills in the PD2 delay; without sight it drains
## 0.125 progress/s (shown: x (1 - DR/100)) and clears when progress reaches 0.
func test_d128_timed_fill_and_npc_drain() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	await _place(Vector3(0, 0.05, 12))  # behind the guard, beyond 1.5 m
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3.ZERO, Vector3.FORWARD)
	await wait_physics_frames(4)
	assert_near(_st.detection_value(g, 0), 0.0, 0.0001, "no sight: empty")
	await _place(Vector3(0, 0.05, -10))
	var want: float = 1.0 / _st.fill_rate(g, c)
	var t0: int = Time.get_ticks_msec()
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.0, 1.0)
	assert_true(ok, "meter appears")
	assert_true(_st.detection_value(g, 0) >= 0.35 - 0.001, "appears at DR/100 = 0.35")
	await wait_seconds(want * 0.5)
	await _place(Vector3(0, 0.05, 12))
	var v0: float = _st.detection_value(g, 0)
	assert_true(v0 > 0.35 and v0 < 1.0, "half filled (%f)" % v0)
	await wait_seconds(1.0)
	var v1: float = _st.detection_value(g, 0)
	assert_near(v0 - v1, Tweak.stealth().npc_decay_per_s * 0.65 * 1.0, 0.03, "PD2 drain 0.125/s x (1 - 0.35)")
	# Back in view: the remaining progress fills at the same rate, then full.
	await _place(Vector3(0, 0.05, -10))
	t0 = Time.get_ticks_msec()
	ok = await wait_until(func() -> bool: return _st.detection_value(g, 0) >= 1.0, want * 3.0)
	assert_true(ok, "fills to full")
	var left: float = (1.0 - (v1 - 0.35) / 0.65) * want
	var took: float = float(Time.get_ticks_msec() - t0) / 1000.0
	assert_true(took < left + 0.6, "full in about the remaining PD2 time (%.2f s vs %.2f s)" % [took, left])


func test_d128_npc_meter_clears_at_zero_progress() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3.ZERO, Vector3.FORWARD)
	await _place(Vector3(0, 0.05, -10))
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.45, 2.0)
	assert_true(ok, "partly filled")
	await _place(Vector3(0, 0.05, 12))
	ok = await wait_until(func() -> bool: return _st.detection_value(g, 0) <= 0.0, 6.0)
	assert_true(ok, "drains, then clears (progress < 0 drops the attention object)")


func test_d128_camera_drains_one_over_delay_max() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var setup: Callable = func(p: GameplayPrefab) -> void:
		p.transform = Transform3D(Basis.looking_at(Vector3(0, -2, -6), Vector3.UP), Vector3(0, 3, 0))
	var cam: SecurityCamera = ATestMaps.add_prefab(_rt, "security_camera", Vector3(0, 3, 0), setup) as SecurityCamera
	await _place(Vector3(0, 0.05, -6))
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(cam, 0) > 0.6, 4.0)
	assert_true(ok, "camera fills")
	await _place(Vector3(0, 0.05, 8))  # behind the camera
	var v0: float = _st.detection_value(cam, 0)
	await wait_seconds(0.6)
	var v1: float = _st.detection_value(cam, 0)
	assert_near(v0 - v1, 0.6 / 2.4 * 0.65, 0.04, "camera drain 1 / delay_max per s x (1 - 0.35)")
