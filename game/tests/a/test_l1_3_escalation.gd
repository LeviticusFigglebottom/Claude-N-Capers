## A3-03 L1.3 escalation: assault_index -> stage (wave 1 = 50%, 2 = 75%, 3+ = 100%) driving sustain
## length and group composition; specials also spawn between waves (CONTROL, low rate); units
## without an EnemyDef yet are skipped.
extends TestCase

const DEFAULT_TWEAK: String = "res://systems/director/director_tweak.tres"

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(options: Dictionary = {}, difficulty: Enums.Difficulty = Enums.Difficulty.ROUTINE) -> HeistRuntime:
	options["ai_teammates"] = 0
	options["captain"] = false
	_rt = await HeistLauncher.launch(&"dev_sandbox", 1301, difficulty, self, options)
	for g: Node in _rt.npcs(&"guard"):
		(g as NpcBase).die()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	return _rt


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func _tweak() -> DirectorTweak:
	return (load(DEFAULT_TWEAK) as DirectorTweak).duplicate() as DirectorTweak


func _group(id: StringName, units: Array[StringName], stage_mult: PackedFloat32Array,
		phases: PackedInt32Array = PackedInt32Array()) -> SpawnGroupDef:
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.id = id
	g.unit_ids = units
	var counts: PackedInt32Array = PackedInt32Array()
	for u: StringName in units:
		counts.append(1)
	g.unit_counts = counts
	g.stage_weight_mult = stage_mult
	g.phases = phases
	return g


func test_l1_3_stage_curve_and_sustain() -> void:
	await _launch()
	var d: AssaultDirector = _director()
	assert_eq(d.stage_for_wave(1), 0, "wave 1 = 50% stage")
	assert_eq(d.stage_for_wave(2), 1, "wave 2 = 75% stage")
	assert_eq(d.stage_for_wave(3), 2, "wave 3 = 100% stage")
	assert_eq(d.stage_for_wave(9), 2, "wave 3+ stays at 100%")
	assert_near(d.sustain_duration(2, 1), 120.0, 0.01, "wave 2 sustain")
	assert_near(d.sustain_duration(3, 1), 160.0, 0.01, "wave 3 sustain")
	var pp: SpawnGroupDef = load("res://systems/ai/data/groups/patrol_pair.tres") as SpawnGroupDef
	assert_true(pp.weight_for(0, 2) < pp.weight_for(0, 0), "beat cops thin out with escalation")
	var wr: SpawnGroupDef = load("res://systems/ai/data/groups/special_wrecker_g.tres") as SpawnGroupDef
	assert_eq(wr.weight_for(3, 0), 0.0, "no Wrecker on the 50% stage")
	assert_true(wr.weight_for(3, 2) > 0.0, "Wreckers on the 100% stage")


func test_l1_3_wave_stage_drives_composition() -> void:
	var tw: DirectorTweak = _tweak()
	var early: SpawnGroupDef = _group(&"group.t_early", [&"enemy.patrol_officer"], PackedFloat32Array([1, 0, 0]))
	var late: SpawnGroupDef = _group(&"group.t_late", [&"enemy.tac_light"], PackedFloat32Array([0, 1, 1]))
	tw.assault_groups = [early, late]
	await _launch({"director_tweak": tw})
	var d: AssaultDirector = _director()
	d.wave_index = 1
	for i: int in range(5):
		assert_eq(d._pick_group(Enums.AssaultPhase.BUILD), early, "wave 1 picks the 50% group")
	d.wave_index = 2
	for i: int in range(5):
		assert_eq(d._pick_group(Enums.AssaultPhase.BUILD), late, "wave 2 picks the 75% group")
	d.wave_index = 3
	assert_eq(d._pick_group(Enums.AssaultPhase.SUSTAIN), late, "wave 3 picks the 100% group")


func test_l1_3_second_wave_runs_at_75_percent() -> void:
	var tw: DirectorTweak = _tweak()
	tw.first_control_s = 0.5
	tw.control_between_waves_s = 0.5
	tw.anticipation_s = 0.5
	tw.build_s = 0.5
	tw.sustain_by_stage_s = PackedFloat32Array([1.0, 2.0, 3.0])
	tw.fade_wait_cap_s = 0.5
	tw.fade_s = 0.5
	await _launch({"director_tweak": tw})
	var d: AssaultDirector = _director()
	var sustains: Dictionary[int, float] = {}
	var cb: Callable = func(p: int, w: int) -> void:
		if p == Enums.AssaultPhase.SUSTAIN:
			sustains[w] = d.phase_time_left
	d.phase_changed.connect(cb)
	_rt.stealth.raise_alarm(&"test", 0)
	var ok: bool = await wait_until(func() -> bool: return sustains.has(3), 30.0)
	d.phase_changed.disconnect(cb)
	assert_true(ok, "three waves ran (%s)" % [sustains])
	assert_near(sustains.get(1, 0.0), 1.0, 0.05, "wave 1 sustain = 50% stage")
	assert_near(sustains.get(2, 0.0), 2.0, 0.05, "wave 2 sustain = 75% stage")
	assert_near(sustains.get(3, 0.0), 3.0, 0.05, "wave 3 sustain = 100% stage")


func test_l1_3_specials_between_waves_in_control() -> void:
	var tw: DirectorTweak = _tweak()
	tw.first_control_s = 100.0
	tw.first_responder_groups = 0
	tw.assault_groups = []
	tw.control_special_interval_s = 0.5
	tw.control_special_chance = 1.0
	# enemy.aegis is a special EnemyDef that exists now; it stands in for the real specials here.
	var ctrl: PackedInt32Array = PackedInt32Array([Enums.AssaultPhase.CONTROL])
	tw.control_special_groups = [_group(&"group.t_ctrl_special", [&"enemy.aegis"], PackedFloat32Array(), ctrl)]
	await _launch({"director_tweak": tw})
	var d: AssaultDirector = _director()
	var specials: Array[NpcBase] = []
	d.unit_spawned.connect(func(npc: NpcBase, _p: Node3D) -> void:
		if npc.enemy_def != null and npc.enemy_def.is_special:
			specials.append(npc))
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_seconds(2.0)
	assert_eq(specials.size(), 0, "no between-wave specials during the first CONTROL")
	d.wave_index = 2  # the CONTROL after a FADE
	var ok: bool = await wait_until(func() -> bool: return specials.size() > 0, 5.0)
	assert_true(ok, "a special spawned in CONTROL between waves")
	assert_eq(d.assault_phase, Enums.AssaultPhase.CONTROL, "still CONTROL")


func test_l1_3_missing_enemy_defs_are_skipped() -> void:
	var tw: DirectorTweak = _tweak()
	tw.first_control_s = 100.0
	tw.first_responder_groups = 0
	tw.assault_groups = []
	await _launch({"director_tweak": tw})
	var d: AssaultDirector = _director()
	var only_missing: SpawnGroupDef = _group(&"group.t_missing", [&"enemy.not_a_real_unit"], PackedFloat32Array())
	assert_false(d._group_spawnable(only_missing), "a group with no EnemyDef cannot be picked")
	var mixed: SpawnGroupDef = _group(&"group.t_mixed", [&"enemy.not_a_real_unit", &"enemy.tac_light"], PackedFloat32Array())
	assert_true(d._group_spawnable(mixed), "a group with one real unit can")
	var spawned: Array[NpcBase] = []
	d.unit_spawned.connect(func(npc: NpcBase, _p: Node3D) -> void: spawned.append(npc))
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	d._enqueue(mixed)
	await wait_seconds(2.0)
	assert_eq(spawned.size(), 1, "only the real unit spawned")
	if spawned.size() == 1:
		assert_eq(spawned[0].enemy_def.id, &"enemy.tac_light", "TAC Light spawned")
