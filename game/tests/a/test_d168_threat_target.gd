## D-168 ◇ (P's Glasshouse deck runs: every hit on the forward bot, none on the human peeking from cover): police target
## scoring weighs threat like PD2's attention. A crew member who hurt this unit or a squadmate within threat_squad_m in
## the last threat_window_s scores distance² x threat_dist_mult; the current target gets sticky_dist_mult.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_d168_the_shooter_draws_fire_over_a_nearer_bot() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1682, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var human: CrewController = _rt.crew_controller(0) as CrewController
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	assert_true(bot.is_ai and not human.is_ai)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(10, 0.05, 0)))  # 10 m from the cop
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 8)))  # 8 m from the cop
	human.set_masked()
	bot.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var mate: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(-4, 0.05, 0)))
	var far_cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(-25, 0.05, 0)))
	await wait_physics_frames(4)
	var b: PoliceBrain = cop.get_node(^"Brain") as PoliceBrain
	var tw: PoliceTweak = b.tweak
	cop.global_position = Vector3(0, 0.05, 0)
	b._pick_target()
	assert_eq(b.combat_target, bot, "no threat: the nearest visible crew member (the bot, 8 m vs 10 m)")
	cop.damaged.emit({"amount": 10.0}, human.net_id)  # the human shoots this cop
	b._pick_target()
	assert_eq(b.combat_target, human, "the shooter: 10² x %.2f beats the bot's 8² x %.2f (sticky)" % [
		tw.threat_dist_mult, tw.sticky_dist_mult])
	var mb: PoliceBrain = mate.get_node(^"Brain") as PoliceBrain
	assert_true(mb._threat.has(human.net_id), "a squadmate within %.0f m shares the threat" % tw.threat_squad_m)
	assert_false((far_cop.get_node(^"Brain") as PoliceBrain)._threat.has(human.net_id), "a unit 25 m off does not")
	b._threat[human.net_id] = _rt.heist_time_s - tw.threat_window_s - 0.5  # the window ran out
	b._pick_target()
	assert_eq(b.combat_target, bot, "after the window: back to the nearest (10² x sticky > 8²)")
	assert_true(tw.threat_dist_mult < 1.0 and tw.sticky_dist_mult < 1.0 and tw.sticky_dist_mult > tw.threat_dist_mult,
		"◇ levers: threat weighs more than stickiness")
