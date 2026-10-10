## A3-06 L3.6 explosives: Explosion.apply damage x (1 - d/r)^0.1 with LOS, DamageType.EXPLOSION, one hit
## per target; walls block, Bulwark shields do not (PD2), Wrecker x1.1; crew blasts spare the crew.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Dictionary] = []
var _cb: Callable = Callable()


func before_each() -> void:
	_rt = await ACombatSpecials.launch(self)
	_events = []
	_cb = func(v: int, a: int, info: Dictionary) -> void: _events.append({"victim": v, "attacker": a, "info": info})
	EventBus.damage_applied.connect(_cb)


func after_each() -> void:
	if EventBus.damage_applied.is_connected(_cb):
		EventBus.damage_applied.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _npc(id: String, pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> NpcBase:
	var n: NpcBase = ACombatSpecials.spawn(_rt, id, pos, facing)
	for nm: String in ["Brain", "Motor", "Gunner"]:
		var c: Node = n.get_node_or_null(nm)
		if c != null:
			c.set_physics_process(false)
	n.max_health = 100000.0
	n.health = 100000.0
	return n


func _events_for(n: NpcBase) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events:
		if int(e["victim"]) == n.net_id:
			out.append(e["info"])
	return out


func test_l3_6_formula() -> void:
	assert_near(Explosion.damage_at(100.0, 0.0, 5.0), 100.0, 0.001, "centre: full")
	assert_near(Explosion.damage_at(100.0, 2.5, 5.0), 100.0 * pow(0.5, 0.1), 0.001, "(1 - d/r)^0.1")
	assert_near(Explosion.damage_at(100.0, 4.5, 5.0), 100.0 * pow(0.1, 0.1), 0.001, "near the edge")
	assert_near(Explosion.damage_at(100.0, 5.0, 5.0), 0.0, 0.001, "edge: none")
	assert_near(Explosion.damage_at(100.0, 6.0, 5.0), 0.0, 0.001, "outside: none")


func test_l3_6_apply_radius_los_and_type() -> void:
	var blast: Vector3 = Vector3(0, 0.9, -10)
	var near: NpcBase = _npc("patrol_officer", Vector3(2, 0.05, -10))
	var far: NpcBase = _npc("patrol_officer", Vector3(9, 0.05, -10))
	var hidden: NpcBase = _npc("patrol_officer", Vector3(-3, 0.05, -10))
	ATestMaps.add_wall(_rt.map, Vector3(-1.5, 1, -10), Vector3(0.3, 3, 3))
	await wait_physics_frames(3)
	var res: Array[Dictionary] = Explosion.apply(_rt.map, blast, 6.0, 200.0, 0, &"throwable.test_c4")
	var ev: Array[Dictionary] = _events_for(near)
	assert_eq(ev.size(), 1, "one hit on the near NPC")
	if ev.size() == 1:
		assert_eq(int(ev[0]["type"]), Enums.DamageType.EXPLOSION, "explosive damage type")
		var d: float = CombatSystem.target_center(near).distance_to(blast)
		assert_near(float(ev[0]["amount"]), Explosion.damage_at(200.0, d, 6.0), 0.01, "formula amount")
		assert_eq(StringName(ev[0]["weapon_id"]), &"throwable.test_c4")
	assert_eq(_events_for(far).size(), 0, "outside the radius")
	assert_eq(_events_for(hidden).size(), 0, "a wall blocks the blast")
	assert_eq(res.size(), 1, "result per target hit")


func test_l3_6_wrecker_takes_x1_1_and_shield_does_not_block() -> void:
	var blast: Vector3 = Vector3(0, 0.9, -10)
	var wr: NpcBase = _npc("wrecker", Vector3(2, 0.05, -10))
	var bw: NpcBase = _npc("bulwark", Vector3(-2, 0.05, -10), Vector3(1, 0, 0))  # shield faces the blast
	await wait_physics_frames(3)
	assert_true((bw.get_node("Brain") as BulwarkBrain).shield != null, "shield up")
	Explosion.apply(_rt.map, blast, 6.0, 200.0, 0)
	var ew: Array[Dictionary] = _events_for(wr)
	var eb: Array[Dictionary] = _events_for(bw)
	assert_eq(ew.size(), 1, "Wrecker hit")
	if ew.size() == 1:
		var d: float = CombatSystem.target_center(wr).distance_to(blast)
		assert_near(float(ew[0]["amount"]), Explosion.damage_at(200.0, d, 6.0) * 1.1, 0.01, "Wrecker x1.1 explosive")
	assert_eq(eb.size(), 1, "explosions go around the Bulwark's shield")
	if eb.size() == 1:
		var d2: float = CombatSystem.target_center(bw).distance_to(blast)
		assert_near(float(eb[0]["amount"]), Explosion.damage_at(200.0, d2, 6.0), 0.01, "full damage")


func test_l3_6_crew_blast_spares_crew_world_blast_does_not() -> void:
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, -5))
	await wait_physics_frames(2)
	var total: float = c.health.health + c.health.armor
	Explosion.apply(_rt.map, c.global_position + Vector3(1, 0.5, 0), 5.0, 50.0, c.net_id)
	assert_near(c.health.health + c.health.armor, total, 0.001, "no friendly fire from crew explosives")
	Explosion.apply(_rt.map, c.global_position + Vector3(1, 0.5, 0), 5.0, 50.0, 0)
	assert_true(c.health.health + c.health.armor < total, "world/NPC explosives hurt the crew")
