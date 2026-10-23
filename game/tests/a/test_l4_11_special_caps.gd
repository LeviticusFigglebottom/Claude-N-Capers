## A3-03 L4.11 special caps: DifficultyDef.special_limits (PD2 shape) bound alive specials per key;
## all Wrecker variants share the enemy.wrecker limit (D-022); Aegis squad members do not count.
extends TestCase

const DEFAULT_TWEAK: String = "res://systems/director/director_tweak.tres"
const AEGIS_DEF: EnemyDef = preload("res://systems/ai/data/enemies/aegis.tres")

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(limits: Dictionary, difficulty: Enums.Difficulty = Enums.Difficulty.BRUTAL) -> HeistRuntime:
	var tw: DirectorTweak = (load(DEFAULT_TWEAK) as DirectorTweak).duplicate() as DirectorTweak
	tw.first_control_s = 100.0
	tw.first_responder_groups = 0
	tw.assault_groups = []
	tw.control_special_groups = []
	tw.unit_spawn_interval_s = 0.1
	var options: Dictionary = {"ai_teammates": 0, "captain": false, "director_tweak": tw}
	if not limits.is_empty():
		var diff: DifficultyDef = DifficultyDef.new()
		diff.difficulty = difficulty
		diff.enemy_cap = 30
		diff.special_limits = limits
		options["difficulty_def"] = diff
	_rt = await HeistLauncher.launch(&"dev_sandbox", 1411, difficulty, self, options)
	for g: Node in _rt.npcs(&"guard"):
		(g as NpcBase).die()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	return _rt


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func _special(id: StringName) -> EnemyDef:
	var def: EnemyDef = AEGIS_DEF.duplicate() as EnemyDef
	def.id = id
	def.params = {}
	return def


func _group(units: Array[StringName], counts: PackedInt32Array) -> SpawnGroupDef:
	var g: SpawnGroupDef = SpawnGroupDef.new()
	g.id = &"group.t_caps"
	g.unit_ids = units
	g.unit_counts = counts
	return g


func _count(id_prefix: String) -> int:
	var k: int = 0
	for npc: NpcBase in _director().alive_units():
		if npc.enemy_def != null and String(npc.enemy_def.id).begins_with(id_prefix):
			k += 1
	return k


func test_l4_11_limits_read_from_difficulty_def() -> void:
	await _launch({})
	var d: AssaultDirector = _director()
	assert_eq(d.roster.special_limit_key(&"enemy.wrecker_b"), &"enemy.wrecker", "Wrecker variants share a key")
	assert_eq(d.roster.special_limit_key(&"enemy.wrecker_m"), &"enemy.wrecker", "Wrecker M too")
	assert_eq(d.roster.special_limit_key(&"enemy.phantom"), &"enemy.phantom", "other ids are their own key")
	assert_eq(d.roster.special_limit(&"enemy.bulwark"), 4, "Brutal: 4 Bulwarks")
	assert_eq(d.roster.special_limit(&"enemy.stinger"), 2, "Brutal: 2 Stingers")
	assert_eq(d.roster.special_limit(&"enemy.corpsman"), 3, "Brutal: 3 Corpsmen")
	assert_eq(d.roster.special_limit(&"enemy.phantom"), 2, "Brutal: 2 Phantoms")
	assert_eq(d.roster.special_limit(&"enemy.wrecker_s"), 2, "Brutal: 2 Wreckers (shared)")
	# QA-31/D-049: ENV B sets Longshot caps (1/2/2/3/3/4); without the key the cap is -1 (perches limit them).
	var limits: Dictionary = _rt.difficulty_def.special_limits
	var want: int = int(limits.get(&"enemy.longshot", limits.get("enemy.longshot", -1)))
	assert_eq(d.roster.special_limit(&"enemy.longshot"), want, "Longshot cap read from DifficultyDef")


func test_l4_11_queue_respects_cap() -> void:
	await _launch({&"enemy.aegis": 2})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	d._enqueue(_group([&"enemy.aegis", &"enemy.tac_light"], PackedInt32Array([5, 1])))
	await wait_seconds(3.0)
	assert_eq(_count("enemy.aegis"), 2, "only 2 of 5 capped specials spawned")
	assert_eq(_count("enemy.tac_light"), 1, "the escort still spawned")


func test_l4_11_wrecker_variants_share_one_limit() -> void:
	await _launch({&"enemy.wrecker": 2})
	var d: AssaultDirector = _director()
	var g_def: EnemyDef = _special(&"enemy.wrecker_g")
	var b_def: EnemyDef = _special(&"enemy.wrecker_b")
	d.roster.set_def_override(&"enemy.wrecker_g", g_def)  # independent of A3-01b's Wrecker data
	d.roster.set_def_override(&"enemy.wrecker_b", b_def)
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	assert_true(d.roster.can_spawn_special(g_def), "room for a Wrecker")
	d._enqueue(_group([&"enemy.wrecker_g", &"enemy.wrecker_b"], PackedInt32Array([1, 3])))
	await wait_seconds(3.0)
	assert_eq(_count("enemy.wrecker"), 2, "G + B variants capped together at 2")
	assert_eq(d.roster.special_alive(&"enemy.wrecker"), 2, "special_alive counts every variant")
	assert_false(d.roster.can_spawn_special(b_def), "limit reached for every variant")
	assert_false(d.roster.can_spawn_special(_special(&"enemy.wrecker_m")), "limit reached for Wrecker M too")
	for npc: NpcBase in d.alive_units():
		if npc.enemy_def != null and String(npc.enemy_def.id).begins_with("enemy.wrecker"):
			npc.die()
			break
	assert_true(d.roster.can_spawn_special(b_def), "a death frees a slot")


func test_l4_11_aegis_squad_not_counted() -> void:
	await _launch({&"enemy.aegis": 1})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var def: EnemyDef = AEGIS_DEF
	var pts: Array[Node3D] = d.valid_spawn_points()
	assert_false(pts.is_empty(), "spawn point")
	var npc: NpcBase = d.spawn_enemy(def, pts[0].global_transform, pts[0])
	npc.set_meta(AegisCaptain.META_AEGIS, true)
	assert_true(d.roster.can_spawn_special(def), "Aegis squad members do not use the special limit")
	npc.remove_meta(AegisCaptain.META_AEGIS)
	assert_false(d.roster.can_spawn_special(def), "a normal one does")


## P's AH Hazardous read (LEAD): many distinct Stinger ids within a minute. The cap is on ALIVE specials: with the
## queue refilled again and again and the capped specials killed as soon as they appear (fresh ids every time), the
## alive count sampled every physics frame never exceeds the cap, and a dead one is replaced (more ids than the cap).
func test_l4_11_alive_never_exceeds_the_cap_under_churn() -> void:
	await _launch({&"enemy.aegis": 2})
	var d: AssaultDirector = _director()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var worst: int = 0
	var ids: Dictionary = {}
	for round_i: int in 6:
		d._enqueue(_group([&"enemy.aegis"], PackedInt32Array([6])))
		for f: int in 90:
			await wait_physics_frames(1)
			var n: int = _count("enemy.aegis")
			worst = maxi(worst, n)
			for npc: NpcBase in d.alive_units():
				if npc.enemy_def != null and npc.enemy_def.id == &"enemy.aegis":
					ids[npc.net_id] = true
		for npc: NpcBase in d.alive_units():
			if npc.enemy_def != null and npc.enemy_def.id == &"enemy.aegis":
				npc.die()
	assert_true(worst <= 2, "alive capped specials never above the cap (max %d)" % worst)
	assert_true(ids.size() > 2, "dead ones are replaced: %d distinct ids over the churn (the cap counts the alive)" % ids.size())
