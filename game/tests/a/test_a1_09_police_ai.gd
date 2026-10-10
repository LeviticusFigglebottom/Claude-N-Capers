## A1-09 PoliceBrain (Patrol Officer / TAC Light, L4.2): idle in stealth, path toward the crew,
## cover-lite, flank-lite, and shooting a visible crew member through the NpcGunner.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch_unit() -> HeistRuntime:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0})
	await wait_physics_frames(1)
	return _rt


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _total(c: CrewController) -> float:
	return c.health.health + c.health.armor


func _spawn(pos: Vector3, def_path: String = "") -> NpcBase:
	var info: Dictionary = {}
	if def_path != "":
		info["enemy_def"] = load(def_path) as EnemyDef
	return _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, pos), info)


func _flat_dist(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func test_a1_09_enemy_defs() -> void:
	for id: String in ["patrol_officer", "tac_light"]:
		var def: EnemyDef = load("res://systems/ai/data/enemies/%s.tres" % id) as EnemyDef
		assert_true(def != null, "%s loads" % id)
		assert_eq(def.id, StringName("enemy." + id))
		assert_eq(def.health.size(), 6, "%s health per difficulty" % id)
		assert_eq(def.headshot_mult.size(), 6, "%s headshot per difficulty" % id)
		assert_eq(def.damage.size(), 6, "%s damage per difficulty" % id)
		assert_eq(def.detection_preset, &"police")
		assert_true(def.move_speed > 0.0 and def.weapon != &"", "%s speed + weapon" % id)
		for i: int in range(1, 6):
			assert_true(def.health[i] >= def.health[i - 1], "%s health rises with difficulty" % id)
	await _launch_unit()
	var tac: NpcBase = _spawn(Vector3(0, 0.05, -10), "res://systems/ai/data/enemies/tac_light.tres")
	assert_eq(tac.enemy_def.id, &"enemy.tac_light", "spawn_npc info.enemy_def applied")
	assert_near(tac.max_health, tac.enemy_def.health[Enums.Difficulty.ROUTINE], 0.001, "health from def")
	var cop: NpcBase = _spawn(Vector3(3, 0.05, -10))
	assert_eq(cop.enemy_def.id, &"enemy.patrol_officer", "npc_police defaults to Patrol Officer")
	assert_eq(cop.role, &"police")
	assert_true(cop.get_node_or_null("Brain") is PoliceBrain, "Brain")
	assert_true(cop.get_node_or_null("Motor") is NpcMotor, "Motor")


func test_a1_09_idle_while_stealth() -> void:
	await _launch_unit()
	var c: CrewController = _crew()
	var p: NpcBase = _spawn(c.global_position + Vector3(0, 0, -10))
	var before: Vector3 = p.global_position
	await wait_seconds(1.5)
	var b: PoliceBrain = p.get_node("Brain") as PoliceBrain
	assert_false(b.wants_to_fire, "no fire before the alarm")
	assert_true(p.global_position.distance_to(before) < 0.3, "does not move before the alarm")


func test_a1_09_police_shoot_visible_crew() -> void:
	await _launch_unit()
	var c: CrewController = _crew()
	c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	var p: NpcBase = _spawn(c.global_position + Vector3(0, 0, -12))
	var b: PoliceBrain = p.get_node("Brain") as PoliceBrain
	var before: float = _total(c)
	var hurt: bool = await wait_until(func() -> bool: return _total(c) < before, 10.0)
	assert_eq(p.alert_state, Enums.AlertState.COMBAT, "police in COMBAT once loud")
	assert_true(b.combat_target == c, "targets the crew member")
	assert_true(hurt, "crew took damage from police fire (%f -> %f)" % [before, _total(c)])


func test_a1_09_cover_lite() -> void:
	await _launch_unit()
	var c: CrewController = _crew()
	c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	var cover: TacticalPoint = TacticalPoint.new()
	cover.name = "TestCover"
	cover.kind = TacticalPoint.Kind.COVER
	_rt.map.get_node("Tactical").add_child(cover)
	cover.global_position = c.global_position + Vector3(4, 0, -12)
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	var p: NpcBase = _spawn(c.global_position + Vector3(0, 0, -26))
	var b: PoliceBrain = p.get_node("Brain") as PoliceBrain
	var at_cover: bool = await wait_until(func() -> bool:
		return b.cover_point == cover and _flat_dist(p, cover) < 1.0 and b.mode == &"hold", 12.0)
	assert_true(at_cover, "moved to and holds the cover point (mode %s, %.1f m)" % [b.mode, _flat_dist(p, cover)])
	assert_true(b.wants_to_fire, "fires from cover")
	# A second unit cannot claim the same point: it uses a standoff instead.
	var p2: NpcBase = _spawn(c.global_position + Vector3(-3, 0, -26))
	var b2: PoliceBrain = p2.get_node("Brain") as PoliceBrain
	await wait_seconds(1.5)
	assert_true(b2.cover_point == null, "occupied cover is not shared")


func test_a1_09_flank_lite() -> void:
	await _launch_unit()
	var c: CrewController = _crew()
	c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	var flank: TacticalPoint = TacticalPoint.new()
	flank.name = "TestFlank"
	flank.kind = TacticalPoint.Kind.FLANK
	_rt.map.get_node("Tactical").add_child(flank)
	flank.global_position = c.global_position + Vector3(12, 0, -6)
	var p: NpcBase = _spawn(c.global_position + Vector3(0, 0, -20))
	var b: PoliceBrain = p.get_node("Brain") as PoliceBrain
	var tw: PoliceTweak = b.tweak.duplicate() as PoliceTweak
	tw.flank_chance = 1.0
	b.tweak = tw
	var flanking: bool = await wait_until(func() -> bool: return b.mode == &"flank", 2.0)
	assert_true(flanking, "unit heads for the FLANK point first")
	var reached: bool = await wait_until(func() -> bool: return _flat_dist(p, flank) < 1.2, 10.0)
	assert_true(reached, "reaches the flank point")
	var engaged: bool = await wait_until(func() -> bool: return b.mode != &"flank", 3.0)
	assert_true(engaged, "then engages normally (mode %s)" % b.mode)


func test_a1_09_police_path_toward_crew_on_sandbox() -> void:
	_rt = await HeistLauncher.launch(&"dev_sandbox", 1001, Enums.Difficulty.ROUTINE, self, {"ai_teammates": 0})
	for g: Node in _rt.npcs(&"guard"):
		(g as NpcBase).die()
	Modifiers.set_source(0, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var c: CrewController = _crew()
	var first: Array[NpcBase] = []
	var start_d: Array[float] = []
	var cb: Callable = func(npc: NpcBase, _p: Node3D) -> void:
		if first.is_empty():
			first.append(npc)
			start_d.append(_flat_dist(npc, c))
	d.unit_spawned.connect(cb)
	EventBus.alarm_raised.emit(&"test", 0)
	var spawned: bool = await wait_until(func() -> bool: return not first.is_empty(), 10.0)
	d.unit_spawned.disconnect(cb)
	assert_true(spawned, "first responders spawn after the alarm")
	if not spawned:
		return
	await wait_seconds(5.0)
	var now: float = _flat_dist(first[0], c)
	assert_true(now < start_d[0] - 3.0, "police closed in on the crew (%.1f -> %.1f m)" % [start_d[0], now])
