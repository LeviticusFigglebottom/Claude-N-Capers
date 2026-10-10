## A3-06 L3.5 suppression ("threat"): near misses and damaging hits build threat (suppressed weapons
## none); threshold 1 hunches (NpcGunner x1.5 delay / x1.5 aim / x0.5 hit chance); threshold 2 dives for
## cover (brain paused), then 50% resistance for 30 s; specials and top-difficulty units are immune.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await ACombatSpecials.launch(self)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(2)


func _cop(pos: Vector3 = Vector3(0, 0.05, -10)) -> NpcBase:
	var npc: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", pos, Vector3(0, 0, 1))
	npc.max_health = 5000.0
	npc.health = 5000.0
	return npc


func _freeze(npc: NpcBase) -> void:
	for nm: String in ["Brain", "Motor", "Gunner"]:
		npc.get_node(nm).set_physics_process(false)


func test_l3_5_near_miss_builds_threat_suppressed_does_not() -> void:
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var npc: NpcBase = _cop()
	_freeze(npc)
	await wait_physics_frames(3)
	var beside: Vector3 = npc.head_position() + Vector3(0.6, 0, 0)
	# Default kestrel is suppressed: 0 threat.
	await ACombatSpecials.shoot_at(_rt, 0, beside)
	assert_true(NpcSuppression.of(npc) == null or NpcSuppression.of(npc).threat == 0.0, "suppressed weapon: no threat")
	var w: CrewWeapons = ACombatSpecials.arm(_rt, 0, &"weapon.corsair_ar")
	var sup: float = w.stats(w.equipped_slot).suppression
	await wait_seconds(0.3)
	var hp: float = npc.health
	await ACombatSpecials.shoot_at(_rt, 0, beside)
	assert_near(npc.health, hp, 0.001, "a near miss, not a hit")
	var s: NpcSuppression = NpcSuppression.of(npc)
	assert_true(s != null and s.threat > 0.0, "near miss built threat")
	if s != null:
		var expected: float = sup * CombatTweak.data().threat_per_suppression_near_miss
		assert_near(s.threat, expected, expected * 0.2 + 0.01, "threat = suppression x near-miss scale (decay aside)")
	# A damaging hit adds more than a near miss.
	var before: float = s.threat if s != null else 0.0
	await wait_seconds(0.3)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(npc))
	assert_true(npc.health < hp, "hit")
	assert_true(s != null and s.threat - before > sup * CombatTweak.data().threat_per_suppression_near_miss,
		"hit threat > near-miss threat")


func test_l3_5_thresholds_hunch_and_gunner_penalties() -> void:
	var npc: NpcBase = _cop()
	_freeze(npc)
	await wait_physics_frames(1)
	var tw: CombatTweak = CombatTweak.data()
	NpcSuppression.add_threat(npc, tw.threat_hunch + 0.1)
	assert_true(NpcSuppression.is_hunched(npc), "threshold 1: hunched")
	assert_near(NpcSuppression.shot_delay_mult(npc), 1.5, 0.0001, "+50% shot delay")
	assert_near(NpcSuppression.aim_delay_mult(npc), 1.5, 0.0001, "+50% aim time")
	assert_near(NpcSuppression.hit_chance_mult(npc), 0.5, 0.0001, "-50% hit chance")
	await wait_seconds(1.0)
	assert_false(NpcSuppression.is_hunched(npc), "threat decays below the threshold")
	assert_near(NpcSuppression.hit_chance_mult(npc), 1.0, 0.0001, "penalty gone")


func test_l3_5_dive_for_cover_then_resistance() -> void:
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	_rt.stealth.raise_alarm(&"test", 0)
	var npc: NpcBase = _cop()
	var cover: TacticalPoint = TacticalPoint.new()
	cover.kind = TacticalPoint.Kind.COVER
	_rt.map.get_node("Tactical").add_child(cover)
	cover.global_position = npc.global_position + Vector3(3, 0, 0)
	var b: PoliceBrain = npc.get_node("Brain") as PoliceBrain
	await wait_until(func() -> bool: return b.wants_to_fire, 5.0)
	var tw: CombatTweak = CombatTweak.data()
	NpcSuppression.add_threat(npc, tw.threat_dive + 0.1, c.global_position)
	assert_true(NpcSuppression.is_diving(npc), "threshold 2: dives")
	await wait_physics_frames(2)
	assert_false(b.wants_to_fire, "no firing while diving")
	var motor: NpcMotor = npc.get_node("Motor") as NpcMotor
	assert_true(motor.target.distance_to(cover.global_position) < 0.1, "runs for the nearest COVER point")
	var s: NpcSuppression = NpcSuppression.of(npc)
	assert_true(s.resist_left > 0.0, "resistance window started")
	var ended: bool = await wait_until(func() -> bool: return not NpcSuppression.is_diving(npc), tw.dive_s + 1.0)
	assert_true(ended, "dive ends")
	var gained: float = NpcSuppression.add_threat(npc, 0.4)
	assert_near(gained, 0.4 * tw.suppression_resist_mult, 0.0001, "50% resistance afterwards")


func test_l3_5_immunity() -> void:
	var bw: NpcBase = ACombatSpecials.spawn(_rt, "bulwark", Vector3(4, 0.05, -10))
	var cop: NpcBase = _cop()
	await wait_physics_frames(2)
	assert_near(NpcSuppression.add_threat(bw, 5.0), 0.0, 0.0001, "specials are immune")
	assert_false(NpcSuppression.is_diving(bw))
	cop.difficulty = CombatTweak.data().suppression_immune_min_difficulty
	assert_near(NpcSuppression.add_threat(cop, 5.0), 0.0, 0.0001, "top-faction (difficulty) units are immune")
	cop.difficulty = Enums.Difficulty.ROUTINE
	assert_true(NpcSuppression.add_threat(cop, 0.5) > 0.0, "regular units are not")


func test_l3_5_segment_distance() -> void:
	var d: float = NpcSuppression._segment_distance(Vector3(-5, 1, 0), Vector3(5, 1, 0), Vector3(0, 0.3, 0.8), Vector3(0, 1.6, 0.8))
	assert_near(d, 0.8, 0.001, "closest distance between the shot and the NPC line")
