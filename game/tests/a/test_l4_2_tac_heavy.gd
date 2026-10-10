## A3-06 L4.2 TAC Heavy: frontal plate (non-AP body hits from the front x0), head vulnerable, back and
## AP rounds deal full damage; a real frontal body shot is stopped, a real headshot is not.
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


func _heavy() -> NpcBase:
	var npc: NpcBase = ACombatSpecials.spawn(_rt, "tac_heavy", Vector3(0, 0.05, -6), Vector3(0, 0, 1))
	for nm: String in ["Brain", "Motor", "Gunner"]:
		npc.get_node(nm).set_physics_process(false)
	return npc


func test_l4_2_tac_heavy_def() -> void:
	var d: EnemyDef = ACombatSpecials.def("tac_heavy")
	assert_eq(d.id, &"enemy.tac_heavy")
	assert_false(d.is_special, "TAC Heavy is a regular unit (suppressible)")
	assert_eq(d.health.size(), 6)
	var light: EnemyDef = ACombatSpecials.def("tac_light")
	for i: int in range(6):
		assert_true(d.health[i] > light.health[i], "heavier than TAC Light on difficulty %d" % i)
	assert_true(float(d.params["frontal_plate_arc_deg"]) > 0.0, "frontal plate configured")
	var npc: NpcBase = _heavy()
	assert_true(npc.get_node("Brain") is PoliceBrain, "uses the police brain (npc_police scene)")


func test_l4_2_frontal_plate_rules() -> void:
	var npc: NpcBase = _heavy()
	await wait_physics_frames(1)
	var front: Vector3 = npc.global_position + Vector3(0, 1, 5)
	var back: Vector3 = npc.global_position + Vector3(0, 1, -5)
	var r: Dictionary = ACombatSpecials.hit(npc, 30.0, Enums.HitZone.BODY, front)
	assert_near(float(r["amount"]), 0.0, 0.0001, "front body x0")
	assert_true(bool(r.get("frontal_plate", false)), "frontal_plate flag")
	r = ACombatSpecials.hit(npc, 30.0, Enums.HitZone.LIMB, front)
	assert_near(float(r["amount"]), 0.0, 0.0001, "front limb x0")
	r = ACombatSpecials.hit(npc, 30.0, Enums.HitZone.BODY, front, Enums.DamageType.BULLET, true)
	assert_near(float(r["amount"]), 30.0, 0.0001, "AP round pierces the plate")
	r = ACombatSpecials.hit(npc, 30.0, Enums.HitZone.BODY, back)
	assert_near(float(r["amount"]), 30.0, 0.0001, "back unprotected")
	r = ACombatSpecials.hit(npc, 10.0, Enums.HitZone.HEAD, front)
	assert_near(float(r["amount"]), 10.0 * npc.enemy_def.headshot_mult[0], 0.0001, "head vulnerable from the front")
	r = ACombatSpecials.hit(npc, 20.0, Enums.HitZone.BODY, front, Enums.DamageType.EXPLOSION)
	assert_near(float(r["amount"]), 20.0, 0.0001, "explosions ignore the plate")


func test_l4_2_real_shots() -> void:
	await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	var npc: NpcBase = _heavy()
	await wait_physics_frames(3)
	var max_h: float = npc.health
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(npc))
	assert_near(npc.health, max_h, 0.001, "frontal body shot stopped by the plate")
	await wait_seconds(0.3)
	await ACombatSpecials.shoot_at(_rt, 0, npc.head_position())
	assert_true(npc.health < max_h, "headshot lands (%.1f / %.1f)" % [npc.health, max_h])
