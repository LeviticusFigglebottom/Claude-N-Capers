## A3-03 L1.5 factions by difficulty: TAC (Routine/Tense), FRD (Hazardous/Brutal), Sentinel Corp
## (Lethal), Zero Division (Cataclysm). Same role ids, faction-specific EnemyDefs and groups.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(difficulty: Enums.Difficulty) -> HeistRuntime:
	_rt = await HeistLauncher.launch(&"dev_sandbox", 1501, difficulty, self, {"ai_teammates": 0, "captain": false})
	for g: Node in _rt.npcs(&"guard"):
		(g as NpcBase).die()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	return _rt


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func test_l1_5_faction_by_difficulty() -> void:
	await _launch(Enums.Difficulty.ROUTINE)
	var d: AssaultDirector = _director()
	assert_eq(d.faction(), &"faction.tac", "Routine -> TAC")
	assert_eq(d.roster.faction_for(Enums.Difficulty.TENSE), &"faction.tac", "Tense -> TAC")
	assert_eq(d.roster.faction_for(Enums.Difficulty.HAZARDOUS), &"faction.frd", "Hazardous -> FRD")
	assert_eq(d.roster.faction_for(Enums.Difficulty.BRUTAL), &"faction.frd", "Brutal -> FRD")
	assert_eq(d.roster.faction_for(Enums.Difficulty.LETHAL), &"faction.sentinel", "Lethal -> Sentinel Corp")
	assert_eq(d.roster.faction_for(Enums.Difficulty.CATACLYSM), &"faction.zero", "Cataclysm -> Zero Division")
	var tac: EnemyDef = d.enemy_def_for(&"enemy.tac_light")
	assert_true(tac != null and tac.display_name == "TAC Light", "TAC uses the base TAC Light def")


func _check_faction(difficulty: Enums.Difficulty, faction: StringName, variant: StringName) -> void:
	await _launch(difficulty)
	var d: AssaultDirector = _director()
	assert_eq(d.faction(), faction, "faction %s" % faction)
	var def: EnemyDef = d.enemy_def_for(&"enemy.tac_light")
	assert_true(def != null, "faction TAC Light def")
	if def == null:
		return
	assert_eq(def.id, &"enemy.tac_light", "role id kept (groups.md)")
	assert_eq(StringName(def.params.get("faction", &"")), faction, "faction-specific def")
	assert_eq(StringName(def.params.get("visual_variant", &"")), variant, "visual variant")
	var po: EnemyDef = d.enemy_def_for(&"enemy.patrol_officer")
	assert_true(po != null and po.display_name == "Patrol Officer", "beat cops stay first responders")
	# A unit the director spawns carries the faction def.
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	var pts: Array[Node3D] = d.valid_spawn_points()
	assert_false(pts.is_empty(), "a valid spawn point")
	if pts.is_empty():
		return
	var npc: NpcBase = d._spawn_unit(&"enemy.tac_light", pts[0])
	assert_true(npc != null and npc.enemy_def == def, "spawned with the %s def" % faction)
	if npc != null:
		assert_eq(StringName(npc.spawn_info.get("faction", &"")), faction, "spawn_info.faction")


func test_l1_5_frd_on_hazardous() -> void:
	await _check_faction(Enums.Difficulty.HAZARDOUS, &"faction.frd", &"frd")


func test_l1_5_sentinel_on_lethal() -> void:
	await _check_faction(Enums.Difficulty.LETHAL, &"faction.sentinel", &"sentinel")


func test_l1_5_zero_on_cataclysm() -> void:
	await _check_faction(Enums.Difficulty.CATACLYSM, &"faction.zero", &"zero")


func test_l1_5_faction_groups() -> void:
	var frd: SpawnGroupDef = load("res://systems/ai/data/groups/frd_agents.tres") as SpawnGroupDef
	assert_eq(frd.weight_for(Enums.Difficulty.ROUTINE, 0, &"faction.tac"), 0.0, "no FRD agents for TAC")
	assert_true(frd.weight_for(Enums.Difficulty.HAZARDOUS, 0, &"faction.frd") > 0.0, "FRD agents on Hazardous")
	var zero: SpawnGroupDef = load("res://systems/ai/data/groups/zero_heavy_squad.tres") as SpawnGroupDef
	assert_eq(zero.weight_for(Enums.Difficulty.CATACLYSM, 1, &"faction.sentinel"), 0.0, "Zero squad not for Sentinel")
	assert_true(zero.weight_for(Enums.Difficulty.CATACLYSM, 1, &"faction.zero") > 0.0, "Zero squad on Cataclysm")
	await _launch(Enums.Difficulty.HAZARDOUS)
	var d: AssaultDirector = _director()
	var agent: EnemyDef = d.enemy_def_for(&"enemy.frd_agent")
	assert_true(agent != null and agent.id == &"enemy.frd_agent", "FRD agent def exists")
