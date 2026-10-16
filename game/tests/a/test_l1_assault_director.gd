## A1-09 AssaultDirector on the dev sandbox: L1.1 phase cycle (one wave) and hostage bonus,
## L1.4 spawn rules (out of crew LOS, >= 15 m, enemy cap), S11.2 director starts on the alarm.
extends TestCase

const DEFAULT_TWEAK: String = "res://systems/director/director_tweak.tres"

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


## Solo dev sandbox, guards removed, crew 0 immune (Modifiers) so the run state stays stable.
func _launch(options: Dictionary = {}) -> HeistRuntime:
	options["ai_teammates"] = 0
	_rt = await HeistLauncher.launch(&"dev_sandbox", 1001, Enums.Difficulty.ROUTINE, self, options)
	for g: Node in _rt.npcs(&"guard"):
		(g as NpcBase).die()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	return _rt


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func _fast_tweak() -> DirectorTweak:
	var tw: DirectorTweak = (load(DEFAULT_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 2.0
	tw.anticipation_s = 1.0
	return tw


func test_l1_1_director_registered_and_idle_in_stealth() -> void:
	await _launch()
	var d: AssaultDirector = _director()
	assert_true(d != null, "director registered as G.SVC_DIRECTOR")
	assert_true(HeistRuntime.get_service(G.SVC_DIRECTOR) == d, "get_service(director)")
	await wait_seconds(0.5)
	assert_eq(d.assault_phase, Enums.AssaultPhase.NONE, "no assault while stealth")
	assert_eq(_rt.npcs(&"police").size(), 0, "no police while stealth")


func test_l1_1_full_cycle_in_order() -> void:
	await _launch()
	var d: AssaultDirector = _director()
	var phases: Array[int] = []
	var waves: Array[int] = []
	var cb: Callable = func(p: int, w: int) -> void:
		phases.append(p)
		waves.append(w)
	EventBus.assault_phase_changed.connect(cb)
	EventBus.alarm_raised.emit(&"test", 0)
	Engine.time_scale = 4.0
	var t0: int = Engine.get_physics_frames()
	var faded: bool = await wait_until(func() -> bool: return Enums.AssaultPhase.FADE in phases, 300.0)
	var game_s: float = float(Engine.get_physics_frames() - t0) / float(Engine.physics_ticks_per_second) * 4.0
	EventBus.assault_phase_changed.disconnect(cb)
	assert_true(faded, "reached FADE (phases %s)" % [phases])
	assert_eq(phases, [Enums.AssaultPhase.CONTROL, Enums.AssaultPhase.ANTICIPATION, Enums.AssaultPhase.BUILD,
		Enums.AssaultPhase.SUSTAIN, Enums.AssaultPhase.FADE], "CONTROL -> ANTICIPATION -> BUILD -> SUSTAIN -> FADE")
	assert_eq(waves, [1, 1, 1, 1, 1], "all wave 1")
	assert_true(game_s < 300.0, "cycle took %.0f game s (< 300)" % game_s)
	assert_true(d.spawned_total > 0, "police spawned during the cycle")
	assert_near(d.sustain_duration(1, 1), 40.0, 0.01, "wave 1 solo sustain (50% stage)")
	assert_near(d.sustain_duration(1, 4), 52.0, 0.01, "wave 1 four-crew sustain")
	assert_near(d.sustain_duration(3, 4), 208.0, 0.01, "100% stage four-crew sustain")


func test_l1_1_fade_then_control_next_wave() -> void:
	var tw: DirectorTweak = _fast_tweak()
	tw.build_s = 1.0
	tw.sustain_by_stage_s = PackedFloat32Array([1.0, 1.0, 1.0])
	tw.fade_wait_cap_s = 1.0
	tw.fade_s = 1.0
	await _launch({"director_tweak": tw})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	var ok: bool = await wait_until(func() -> bool: return d.wave_index == 2, 20.0)
	assert_true(ok, "after FADE the director returns to CONTROL")
	assert_eq(d.assault_phase, Enums.AssaultPhase.CONTROL, "CONTROL after FADE")


func test_l1_1_hostage_bonus_applies_once() -> void:
	await _launch({"director_tweak": _fast_tweak()})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	assert_eq(d.assault_phase, Enums.AssaultPhase.CONTROL, "loud starts in CONTROL (first responders)")
	EventBus.hostage_count_changed.emit(1)
	var ok: bool = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.ANTICIPATION, 5.0)
	assert_true(ok, "ANTICIPATION reached")
	assert_true(d.hostage_bonus_applied, "bonus applied")
	assert_true(d.phase_time_left > d.tweak.anticipation_s + 25.0, "anticipation extended by 30 s (%.1f left)" % d.phase_time_left)
	var left: float = d.phase_time_left
	EventBus.hostage_count_changed.emit(2)
	await wait_physics_frames(1)
	assert_true(d.phase_time_left <= left, "a second hostage adds nothing")
	EventBus.hostage_count_changed.emit(0)


func test_l1_1_no_hostage_no_bonus() -> void:
	await _launch({"director_tweak": _fast_tweak()})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	var ok: bool = await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.ANTICIPATION, 5.0)
	assert_true(ok, "ANTICIPATION reached")
	assert_false(d.hostage_bonus_applied, "no hostage, no bonus")
	assert_true(d.phase_time_left <= d.tweak.anticipation_s, "plain anticipation")


func test_l1_4_spawns_out_of_los_15m_and_capped() -> void:
	var tw: DirectorTweak = _fast_tweak()
	tw.build_s = 60.0
	tw.assault_group_interval_s = 0.5
	tw.unit_spawn_interval_s = 0.2
	tw.force_crew_mult = PackedFloat32Array([1.0])  # PO-5.4 force scaling off: the enemy cap alone binds
	tw.stage_force_mult = PackedFloat32Array([1.0])
	# L1.4 rules and the plain BUILD groups' make-up: no added specials (the assault special share is
	# test_director_assault_specials' subject; with a cap of 5 they would fill it ahead of the squads).
	tw.assault_special_share = PackedFloat32Array([0.0])
	var diff: DifficultyDef = DifficultyDef.new()
	diff.enemy_cap = 5
	diff.assault_intensity = 1.0
	await _launch({"director_tweak": tw, "difficulty_def": diff})
	var d: AssaultDirector = _director()
	var bad: Array[String] = []
	var max_alive: Array[int] = [0]
	var spawned: Array[NpcBase] = []
	var cb: Callable = func(npc: NpcBase, _p: Node3D) -> void:
		spawned.append(npc)
		max_alive[0] = maxi(max_alive[0], d.alive_count())
		for c: CrewController in _rt.crew_members():
			var dist: float = Vector2(c.global_position.x - npc.global_position.x,
				c.global_position.z - npc.global_position.z).length()
			if dist < 15.0:
				bad.append("%s %.1f m from crew %d" % [npc.name, dist, c.slot])
			if _rt.stealth.has_los(c.eye_position(), npc.eye_position(), [c.get_rid(), npc.get_rid()]):
				bad.append("%s in LOS of crew %d" % [npc.name, c.slot])
	d.unit_spawned.connect(cb)
	_rt.stealth.raise_alarm(&"test", 0)
	Engine.time_scale = 4.0
	await wait_until(func() -> bool: return d.assault_phase == Enums.AssaultPhase.BUILD, 20.0)
	await wait_seconds(15.0)
	d.unit_spawned.disconnect(cb)
	assert_true(spawned.size() >= 5, "spawned up to the cap (%d)" % spawned.size())
	assert_true(bad.is_empty(), "L1.4 rule violations: %s" % [bad])
	assert_true(max_alive[0] <= 5, "enemy cap respected (max %d)" % max_alive[0])
	assert_true(d.alive_count() <= 5, "enemy cap respected now")
	var tac: int = 0
	for n: NpcBase in spawned:
		if is_instance_valid(n) and n.enemy_def != null and n.enemy_def.id == &"enemy.tac_light":
			tac += 1
	assert_true(tac > 0, "TAC Light units in BUILD groups")


func test_l1_4_nearest_valid_point_to_crew() -> void:
	await _launch()
	var d: AssaultDirector = _director()
	await wait_physics_frames(2)
	var pts: Array[Node3D] = d.valid_spawn_points()
	assert_false(pts.is_empty(), "the sandbox has a valid police spawn for the crew at the van")
	for p: Node3D in pts:
		assert_true(d.is_spawn_valid(p.global_position), "%s valid" % p.name)
	# Crew right next to a spawn point invalidates it (15 m rule).
	var first: Node3D = pts[0]
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, first.global_position + Vector3(2.0, 0.0, 0.0)))
	await wait_physics_frames(2)
	assert_false(d.valid_spawn_points().has(first), "a point near the crew is invalid")
