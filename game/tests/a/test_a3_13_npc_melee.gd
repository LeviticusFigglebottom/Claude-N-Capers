## A3-13 enemy close-range melee (PD2 shove / strike): a police unit next to its target strikes instead of
## shooting (windup, one MELEE hit of npc_melee_damage[difficulty], a shove, reload cancelled, cooldown);
## defense.melee_damage_taken_mult scales it; defense.melee_counter with a melee charge knocks the unit down
## and takes nothing; a target out of reach is shot as before.
extends TestCase

var _rt: HeistRuntime = null
var _hits: Array[Dictionary] = []
var _cb: Callable = Callable()


func after_each() -> void:
	if EventBus.damage_applied.is_connected(_cb):
		EventBus.damage_applied.disconnect(_cb)
	Modifiers.clear_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	_rt = await HeistLauncher.launch(&"unit_map", 31301, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_hits = []
	_cb = func(v: int, _a: int, info: Dictionary) -> void: _hits.append({"victim": v, "info": info})
	EventBus.damage_applied.connect(_cb)
	await wait_physics_frames(2)
	return c


func _cop(pos: Vector3) -> NpcBase:
	var npc: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, pos), {})
	var b: Node = npc.get_node_or_null("Brain")
	if b != null:
		b.set_physics_process(false)
	var m: Node = npc.get_node_or_null("Motor")
	if m != null:
		m.set_physics_process(false)
	return npc


func _melee_on(c: CrewController) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h: Dictionary in _hits:
		if int(h["victim"]) == c.net_id and int((h["info"] as Dictionary)["type"]) == Enums.DamageType.MELEE:
			out.append(h["info"])
	return out


func test_point_blank_strike_shove_and_cooldown() -> void:
	var c: CrewController = await _launch()
	var cop: NpcBase = _cop(Vector3(0, 0.05, -1.0))
	var g: NpcGunner = cop.get_node("Gunner") as NpcGunner
	var res: Array[StringName] = []
	g.melee_resolved.connect(func(_t: Node, r: StringName) -> void: res.append(r))
	var shots: Array[int] = [0]
	g.shot.connect(func(_t: Node, _h: bool) -> void: shots[0] += 1)
	c.weapons.set_ammo(c.weapons.equipped_slot, 1, 50)
	c.weapons.start_reload()
	g.fire_at(c)
	await wait_seconds(CombatTweak.data().npc_melee_windup_s + 0.2)
	assert_eq(res, [&"hit"] as Array[StringName], "struck at point blank")
	var hits: Array[Dictionary] = _melee_on(c)
	assert_eq(hits.size(), 1, "one MELEE hit")
	if hits.size() == 1:
		assert_near(float(hits[0]["amount"]), CombatTweak.data().npc_melee_damage[Enums.Difficulty.ROUTINE], 0.01,
			"npc_melee_damage[ROUTINE]")
	assert_false(c.weapons.reloading, "the shove cancels the reload")
	assert_eq(shots[0], 0, "no shots while striking")
	await wait_seconds(1.0)
	assert_eq(_melee_on(c).size(), 1, "cooldown between strikes")
	g.hold_fire()


func test_melee_damage_taken_mult() -> void:
	var c: CrewController = await _launch()
	Modifiers.set_source(0, &"skills", {&"defense.melee_damage_taken_mult": 0.5})
	var g: NpcGunner = _cop(Vector3(0, 0.05, -1.0)).get_node("Gunner") as NpcGunner
	g.fire_at(c)
	await wait_seconds(CombatTweak.data().npc_melee_windup_s + 0.2)
	var hits: Array[Dictionary] = _melee_on(c)
	assert_eq(hits.size(), 1)
	if hits.size() == 1:
		assert_near(float(hits[0]["amount"]), CombatTweak.data().npc_melee_damage[0] * 0.5, 0.01, "x0.5")
	g.hold_fire()


func test_counterstrike_knocks_the_cop_down() -> void:
	var c: CrewController = await _launch()
	Modifiers.set_source(0, &"skills", {&"defense.melee_counter": true})
	var cop: NpcBase = _cop(Vector3(0, 0.05, -1.0))
	var g: NpcGunner = cop.get_node("Gunner") as NpcGunner
	var res: Array[StringName] = []
	g.melee_resolved.connect(func(_t: Node, r: StringName) -> void: res.append(r))
	var hold: CrewIntent = BotUtil.look_at_intent(c.eye_position(), CombatSystem.target_center(cop))
	hold.melee = true
	_rt.set_bot_intent(0, hold)
	await wait_physics_frames(2)
	assert_eq(c.melee.state, &"charging", "charging the melee")
	g.fire_at(c)
	await wait_seconds(CombatTweak.data().npc_melee_windup_s + 0.2)
	assert_eq(res, [&"countered"] as Array[StringName], "defense.melee_counter")
	assert_eq(_melee_on(c).size(), 0, "no damage")
	assert_true(cop.is_stunned(), "the cop is knocked down")
	g.hold_fire()


func test_out_of_reach_shoots() -> void:
	var c: CrewController = await _launch()
	var g: NpcGunner = _cop(Vector3(0, 0.05, -6.0)).get_node("Gunner") as NpcGunner
	var started: Array[int] = [0]
	g.melee_started.connect(func(_t: Node) -> void: started[0] += 1)
	var shots: Array[int] = [0]
	g.shot.connect(func(_t: Node, _h: bool) -> void: shots[0] += 1)
	g.fire_at(c)
	await wait_seconds(2.0)
	assert_eq(started[0], 0, "no melee at 6 m")
	assert_true(shots[0] > 0, "shoots instead")
	g.hold_fire()
