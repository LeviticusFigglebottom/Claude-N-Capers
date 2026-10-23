## D-158 (P's real-input RT Hazardous verdicts): 1. a unit still seated in its vehicle neither sees nor hears until it
## dismounts; 2. after the RT stop (clean or crash) the first assault's BUILD waits for stop + TRUCK_WINDOW_S
## (AssaultDirector.first_build_hold_s; later waves ignore it); 3. AI teammates take cover (or crouch) when the
## human they follow is in cover or crouched in combat, with no enemy targeted.
extends TestCase

const RT_HEIST: StringName = &"rolling_thunder"

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch_unit(ai: int) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1580, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": ai, "crew_ai": ai > 0})
	await wait_physics_frames(2)
	for s: int in range(4):
		Modifiers.set_source(s, &"test.immune", {&"defense.damage_taken_mult": 0.0})


func test_seated_unit_has_no_detection_until_it_dismounts() -> void:
	await _launch_unit(0)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.set_masked(true)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"police", Vector3(0, 0.05, -10), Vector3.BACK)
	g.set_meta(HeistMission.META_SEATED_IN, 1)
	assert_false(g.can_observe(), "seated: cannot observe")
	await wait_seconds(2.0)
	assert_near(_rt.stealth.detection_value(g, 0), 0.0, 0.0001, "the crew in plain view 10 m away: the gauge stays at 0")
	_rt.stealth.call(&"_on_noise", crew.global_position, 30.0, &"gunshot", 0)
	assert_eq(g.alert_state, Enums.AlertState.CALM, "seated: does not hear a shot")
	g.remove_meta(HeistMission.META_SEATED_IN)
	assert_true(g.can_observe(), "dismounted: observes")
	assert_true(await wait_until(func() -> bool: return _rt.stealth.detection_value(g, 0) > 0.0, 3.0),
		"dismounted: the gauge rises")


func test_first_build_waits_for_the_hold_and_later_waves_ignore_it() -> void:
	await _launch_unit(0)
	_rt.stealth.raise_alarm(&"test", 0)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(await wait_until(func() -> bool: return dir.running, 10.0), "the director runs")
	assert_eq(dir.wave_index, 1, "first assault")
	dir.first_build_hold_s = 2.5
	dir._enter(Enums.AssaultPhase.ANTICIPATION, 0.1)
	await wait_seconds(1.2)
	assert_eq(dir.assault_phase, Enums.AssaultPhase.ANTICIPATION, "anticipation over, the hold still on: no BUILD")
	assert_true(await wait_until(func() -> bool: return dir.assault_phase == Enums.AssaultPhase.BUILD, 3.0),
		"BUILD once the hold ran out")
	dir.wave_index = 2
	dir.first_build_hold_s = 30.0
	dir._enter(Enums.AssaultPhase.ANTICIPATION, 0.1)
	assert_true(await wait_until(func() -> bool: return dir.assault_phase == Enums.AssaultPhase.BUILD, 1.0),
		"wave 2 ignores the hold")


func _rt_stop(clean: bool) -> RollingThunderMission:
	_rt = await HeistLauncher.launch(RT_HEIST, 4101, Enums.Difficulty.HAZARDOUS, self,
		{"crew_ai": false, "ai_teammates": 0, "skip_casing": true})
	await wait_physics_frames(3)
	var m: RollingThunderMission = _rt.mission as RollingThunderMission
	if clean:
		m.signals_rigged = true
	else:
		_rt.stealth.raise_alarm(&"test")  # early alarm: police at once, crash stop
		await wait_physics_frames(3)
	m._convoy_arrives()
	Engine.time_scale = 4.0
	var ok: bool = await wait_until(func() -> bool: return m._stop_done, 30.0)
	Engine.time_scale = 1.0
	assert_true(ok, "the convoy stopped")
	return m


func test_rt_stop_holds_the_first_build_for_the_truck_window() -> void:
	var path: String = HeistLauncher.map_path(RT_HEIST, {})
	if path == "" or not ResourceLoader.exists(path):
		skip("rolling_thunder map not on this branch")
		return
	for clean: bool in [false, true]:
		await _rt_stop(clean)
		var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
		assert_true(dir.first_build_hold_s > RollingThunderMission.TRUCK_WINDOW_S - 2.0,
			"%s stop: the first BUILD is held (%.1f s)" % ["clean" if clean else "crash", dir.first_build_hold_s])
		Engine.time_scale = 4.0
		var t0: int = Time.get_ticks_msec()
		var build: bool = await wait_until(func() -> bool: return dir.assault_phase == Enums.AssaultPhase.BUILD,
			(RollingThunderMission.TRUCK_WINDOW_S + 20.0) / 4.0)
		var waited: float = (Time.get_ticks_msec() - t0) / 1000.0 * 4.0
		Engine.time_scale = 1.0
		if build:
			assert_true(waited >= RollingThunderMission.TRUCK_WINDOW_S - 3.0,
				"%s stop: BUILD came %.0f s after the stop (>= window)" % ["clean" if clean else "crash", waited])
		_rt.teardown()
		_rt = null
		await wait_frames(2)


func test_bots_take_cover_when_the_leader_does() -> void:
	await _launch_unit(1)
	var leader: CrewController = _rt.crew_controller(0) as CrewController
	var bot: CrewController = null
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			bot = c
	var b: CrewAiBrain = CrewAiBrain.of(bot)
	leader.set_masked(true)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4)))
	_rt.teleport_crew(bot.slot, Transform3D(Basis.IDENTITY, Vector3(1.5, 0.05, -4)))
	await wait_seconds(1.0)
	assert_eq(b.cover_point, null, "no enemy, leader standing in the open: no cover")
	assert_false(bot.crouched, "and the bot stands")
	var ci: CrewIntent = CrewIntent.new()
	ci.crouch = true
	_rt.set_bot_intent(0, ci)
	assert_true(await wait_until(func() -> bool: return bot.crouched, 3.0),
		"the leader crouches in combat, no cover point: the bot crouches beside them (mode %d)" % b.mode)
	var cover: Marker3D = Marker3D.new()
	cover.add_to_group(G.COVER_POINT)
	_rt.map.add_child(cover)
	cover.global_position = Vector3(3, 0.05, -1)
	assert_true(await wait_until(func() -> bool: return b.cover_point == cover and bot.crouched \
		and bot.global_position.distance_to(cover.global_position) < 1.0, 6.0),
		"a cover point within 8 m: the bot takes it and crouches (mode %d)" % b.mode)
	_rt.clear_bot_intent(0)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(-3, 0.05, -1.5)))
	var stand_cover: Marker3D = Marker3D.new()
	stand_cover.add_to_group(G.COVER_POINT)
	_rt.map.add_child(stand_cover)
	stand_cover.global_position = Vector3(-3, 0.05, -1)
	b.cover_point = null
	await wait_physics_frames(3)
	assert_true(b._leader_takes_cover(leader), "a standing leader at a cover point is in cover")
	assert_true(b.cover_point != null, "and the bot seeks cover")


# --- LEAD r286 levers (tweak knobs, defaults = the shipped behaviour) ----------------------------

func test_rt_tweak_defaults_are_todays_behaviour() -> void:
	var t: RtTweak = RtTweak.data()
	assert_eq(t.truck_window_from, RtTweak.FROM_STOP, "the window counts from the stop")
	assert_near(t.truck_window_s, RollingThunderMission.TRUCK_WINDOW_S, 0.0001, "30 s")
	assert_eq(t.wave1_exclude, [] as Array[StringName], "no wave-1 exclusion")
	assert_eq((load(CrewAiBrain.TWEAK_PATH) as CrewAiTweak).cover_prefer_behind_leader_m, 0.0, "nearest cover")


func test_truck_window_from_escort_down() -> void:
	var path: String = HeistLauncher.map_path(RT_HEIST, {})
	if path == "" or not ResourceLoader.exists(path):
		skip("rolling_thunder map not on this branch")
		return
	var t: RtTweak = RtTweak.data()
	t.truck_window_from = RtTweak.FROM_ESCORT_DOWN
	var m: RollingThunderMission = await _rt_stop(false)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(dir.first_build_hold_s > t.escort_down_max_s - 3.0, "held up to stop + escort_down_max_s (%.1f)"
		% dir.first_build_hold_s)
	for u: NpcBase in m._units:
		if is_instance_valid(u) and u.alive:
			u.die()
	assert_true(await wait_until(func() -> bool: return m.objective_state(&"escort") == Enums.ObjectiveState.COMPLETED,
		4.0), "the escort is down")
	t.truck_window_from = RtTweak.FROM_STOP
	assert_true(dir.first_build_hold_s <= t.truck_window_s + 0.01, "then truck_window_s from the last death (%.1f)"
		% dir.first_build_hold_s)


func test_wave1_exclude_keeps_stingers_out_of_the_first_assault() -> void:
	await _launch_unit(0)
	_rt.stealth.raise_alarm(&"test", 0)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(await wait_until(func() -> bool: return dir.running, 10.0), "the director runs")
	var g: SpawnGroupDef = load("res://systems/ai/data/groups/control_stinger.tres") as SpawnGroupDef
	dir.wave_index = 1
	assert_false(dir._wave1_excluded(&"enemy.stinger"), "default: nothing excluded")
	dir.wave1_exclude = [&"stinger"] as Array[StringName]
	assert_true(dir._wave1_excluded(&"enemy.stinger"), "a bare name matches the unit id")
	assert_false(dir._group_spawnable(g), "a Stinger-only group cannot spawn in wave 1")
	dir.wave_index = 2
	assert_false(dir._wave1_excluded(&"enemy.stinger"), "wave 2: allowed again")


func test_rt_sets_wave1_exclude_from_the_tweak_at_hazardous() -> void:
	var path: String = HeistLauncher.map_path(RT_HEIST, {})
	if path == "" or not ResourceLoader.exists(path):
		skip("rolling_thunder map not on this branch")
		return
	var t: RtTweak = RtTweak.data()
	t.wave1_exclude = [&"stinger"] as Array[StringName]
	await _rt_stop(false)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	t.wave1_exclude = [] as Array[StringName]
	assert_eq(dir.wave1_exclude, [&"stinger"] as Array[StringName], "Hazardous: the stop hands the list to the director")


func test_cover_prefer_behind_leader() -> void:
	await _launch_unit(1)
	var leader: CrewController = _rt.crew_controller(0) as CrewController
	var bot: CrewController = null
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			bot = c
	var b: CrewAiBrain = CrewAiBrain.of(bot)
	leader.set_masked(true)
	_rt.stealth.raise_alarm(&"test", 0)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_rt.teleport_crew(bot.slot, Transform3D(Basis.IDENTITY, Vector3(2, 0.05, -1)))
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -15)), {})
	cop.get_node("Brain").set_physics_process(false)
	var front: Marker3D = Marker3D.new()
	front.add_to_group(G.COVER_POINT)
	_rt.map.add_child(front)
	front.global_position = Vector3(2, 0.05, -2.5)  # toward the threat, nearest to the bot
	var back: Marker3D = Marker3D.new()
	back.add_to_group(G.COVER_POINT)
	_rt.map.add_child(back)
	back.global_position = Vector3(2, 0.05, 2.5)  # behind the leader
	await wait_physics_frames(3)
	b.cover_point = null
	assert_eq(b._pick_cover(leader), front, "default: the nearest free point")
	var tw: CrewAiTweak = b.tweak
	tw.cover_prefer_behind_leader_m = 4.0
	b.cover_point = null
	var picked: Node3D = b._pick_cover(leader)
	tw.cover_prefer_behind_leader_m = 0.0
	assert_eq(picked, back, "preferring cover behind the leader")


# --- LEAD r287 escort knobs ----------------------------------------------------------------------

func test_escort_knob_defaults_are_today() -> void:
	var t: RtTweak = RtTweak.data()
	assert_eq(t.escort_engage_delay_s, 0.0, "no extra engage delay")
	assert_eq(t.escort_accuracy_mult, 1.0, "full accuracy")


func test_gunner_engage_hold_then_fires() -> void:
	await _launch_unit(0)
	_rt.stealth.raise_alarm(&"test", 0)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.set_masked(true)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -8)), {})
	await wait_physics_frames(2)
	var g: NpcGunner = cop.get_node("Gunner") as NpcGunner
	var shots: Array[int] = [0]
	g.shot.connect(func(_t: Object, _h: bool) -> void: shots[0] += 1)
	g.engage_hold_left = 2.0
	await wait_seconds(1.5)
	assert_eq(shots[0], 0, "held: no shot")
	assert_true(await wait_until(func() -> bool: return shots[0] > 0, 6.0), "fires once the hold is over")
	g.hit_chance_mult = 0.5
	g.hit_chance_mult_left = 1.0
	assert_eq(g._timed_hit_mult(), 0.5, "the timed mult applies")
	g.hit_chance_mult_left = 0.0
	assert_eq(g._timed_hit_mult(), 1.0, "and lapses")


func test_rt_escort_knobs_reach_the_convoy() -> void:
	var path: String = HeistLauncher.map_path(RT_HEIST, {})
	if path == "" or not ResourceLoader.exists(path):
		skip("rolling_thunder map not on this branch")
		return
	var t: RtTweak = RtTweak.data()
	t.escort_engage_delay_s = 1.5
	t.escort_accuracy_mult = 0.7
	var m: RollingThunderMission = await _rt_stop(false)  # crash stop: the escorts get out at once
	var held_any: bool = await wait_until(func() -> bool:
		return m._units.any(func(u: NpcBase) -> bool:
			var gg: NpcGunner = u.get_node_or_null(^"Gunner") as NpcGunner if is_instance_valid(u) else null
			return gg != null and gg.engage_hold_left > 0.0), 4.0)  # after the exit clip (_dismounted)
	t.escort_engage_delay_s = 0.0
	t.escort_accuracy_mult = 1.0
	var held: int = 0
	var damped: int = 0
	for u: NpcBase in m._units:
		var g: NpcGunner = u.get_node_or_null(^"Gunner") as NpcGunner if is_instance_valid(u) else null
		if g == null:
			continue
		if g.hit_chance_mult_left > 0.0 and is_equal_approx(g.hit_chance_mult, 0.7):
			damped += 1
		if g.engage_hold_left > 0.0:
			held += 1
	assert_true(damped >= 6, "every convoy unit hits at x0.7 after the stop (%d)" % damped)
	assert_true(held_any and held >= 1, "the escorts that got out hold fire (%d)" % held)
