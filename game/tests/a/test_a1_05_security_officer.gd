## A1-05: Security Officer data (L4.1), prefab wiring and the S11.2 loud switch to combat AI.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_a1_05_enemy_def_data() -> void:
	var def: EnemyDef = load("res://systems/ai/data/enemies/security_officer.tres") as EnemyDef
	assert_true(def != null, "security_officer.tres loads")
	assert_eq(def.id, &"enemy.security_officer")
	assert_eq(def.health.size(), Enums.Difficulty.size(), "health per difficulty")
	assert_eq(def.headshot_mult.size(), Enums.Difficulty.size(), "headshot_mult per difficulty")
	assert_eq(def.damage.size(), Enums.Difficulty.size(), "damage per difficulty")
	for i: int in range(1, def.health.size()):
		assert_true(def.health[i] >= def.health[i - 1], "health non-decreasing with difficulty")
	assert_eq(def.weapon, &"weapon.npc_pistol")
	assert_eq(def.detection_preset, &"guard")
	assert_true(float(def.params.get("patrol_speed", 0.0)) < def.move_speed, "walks slower than it runs")


func test_a1_05_guard_prefab_wiring() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.HAZARDOUS, self,
		{"map_packed": ATestMaps.basic(1, 0)})
	var npc: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	assert_true(npc.get_node_or_null("Brain") is GuardBrain, "Brain child")
	assert_true(npc.get_node_or_null("Motor") is NpcMotor, "Motor child")
	assert_true(npc.get_node_or_null("Collision") != null and npc.get_node_or_null("Visual/Placeholder") != null)
	assert_eq(npc.enemy_def.id, &"enemy.security_officer")
	assert_near(npc.max_health, npc.enemy_def.health[Enums.Difficulty.HAZARDOUS], 0.001, "health from EnemyDef")
	assert_eq((npc.get_node("Brain") as GuardBrain).state_name(), &"calm")


func test_s11_2_alarm_switches_guards_to_combat_and_approach() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(2, 0), "crew_ai": false})
	await wait_physics_frames(1)
	var brains: Array[GuardBrain] = []
	for n: Node in _rt.npcs(&"guard"):
		brains.append(n.get_node("Brain") as GuardBrain)
	_rt.stealth.raise_alarm(&"alarm_button", 0)
	await wait_physics_frames(1)
	for b: GuardBrain in brains:
		assert_eq(b.state_name(), &"combat", "S11.2: guards switch to combat AI")
	var b0: GuardBrain = brains[0]
	var npc: NpcBase = b0.get_parent() as NpcBase
	var tw: GuardTweak = b0.tweak
	var dist: Callable = func() -> float:
		var t: Node3D = b0.combat_target as Node3D
		if t == null:
			return INF
		return Vector2(t.global_position.x - npc.global_position.x, t.global_position.z - npc.global_position.z).length()
	await wait_physics_frames(2)
	assert_true(b0.combat_target is CrewController, "targets a crew member")
	var d0: float = dist.call()
	assert_true(d0 > tw.combat_standoff_max_m, "test starts outside the standoff band (%.1f m)" % d0)
	var ok: bool = await wait_until(func() -> bool: return float(dist.call()) <= tw.combat_standoff_pref_m + 0.5, 10.0)
	assert_true(ok, "closed to the standoff distance (now %.1f m)" % float(dist.call()))
	await wait_seconds(0.5)
	var d1: float = dist.call()
	assert_true(d1 >= tw.combat_standoff_min_m - 0.5 and d1 <= tw.combat_standoff_max_m, "holds the standoff band")
	assert_true(b0.wants_to_fire, "exposes wants_to_fire for the combat system")
