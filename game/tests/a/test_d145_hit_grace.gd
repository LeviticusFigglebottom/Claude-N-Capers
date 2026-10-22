## D-145 (LEAD, PD2 _chk_dmg_too_soon): after a crew member takes or dodges a bullet hit, further bullet hits of equal
## or lower damage do nothing for CombatTweak.hit_grace_s_by_difficulty (0.45 s; bots bot_hit_grace_s_by_difficulty,
## 0.35 s); a stronger hit lands and raises the bar. Routine / Tense only for now (0 from Hazardous up).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	await _teardown()


func _teardown() -> void:
	Modifiers.clear_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(difficulty: int) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1451, difficulty, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)


func _hit(c: CrewController, amount: float, type: int = Enums.DamageType.BULLET) -> float:
	var out: Dictionary = c.health.take_hit(Damage.info(amount, type, Enums.HitZone.BODY, &"test", c.global_position,
		Vector3.FORWARD, 0))
	return float(out["amount"])


func _fresh(c: CrewController) -> void:
	Modifiers.set_source(c.slot, &"test", {&"defense.dodge_add": -1.0})  # no dodge rolls (a dodge opens the grace too)
	c.health.armor = 0.0  # health only: no armor gate in the way
	c.health.health = c.health.max_health
	c.health.grace_left = 0.0
	c.health.invuln_left = 0.0


func test_d145_tense_grace_ignores_equal_or_weaker_hits() -> void:
	await _launch(Enums.Difficulty.TENSE)
	var me: CrewController = _rt.crew_controller(0) as CrewController
	_fresh(me)
	assert_near(_hit(me, 10.0), 10.0, 0.01, "the first hit lands")
	assert_near(_hit(me, 8.0), 0.0, 0.01, "a weaker hit inside the grace does nothing")
	assert_near(_hit(me, 10.0), 0.0, 0.01, "an equal hit inside the grace does nothing")
	assert_near(_hit(me, 12.0), 12.0, 0.01, "a stronger hit lands")
	assert_near(_hit(me, 11.0), 0.0, 0.01, "...and raises the bar")
	assert_near(_hit(me, 5.0, Enums.DamageType.EXPLOSION), 5.0, 0.01, "non-bullet damage is not graced")
	await wait_seconds(0.55)
	assert_near(_hit(me, 8.0), 8.0, 0.01, "after 0.45 s hits land again")
	assert_near(me.health.health, me.health.max_health - 35.0, 0.01, "health took only the landed hits")


func test_d145_a_dodge_opens_the_grace() -> void:
	await _launch(Enums.Difficulty.TENSE)
	var me: CrewController = _rt.crew_controller(0) as CrewController
	_fresh(me)
	Modifiers.set_source(me.slot, &"test", {&"defense.dodge_add": 1.0})
	var out: Dictionary = me.health.take_hit(Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test",
		me.global_position, Vector3.FORWARD, 0))
	assert_true(bool(out.get("dodged", false)), "dodged")
	Modifiers.set_source(me.slot, &"test", {&"defense.dodge_add": -1.0})
	assert_near(_hit(me, 10.0), 0.0, 0.01, "PD2: a dodged hit sets the grace like a landed one")


func test_d145_bot_grace_is_shorter() -> void:
	await _launch(Enums.Difficulty.TENSE)
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	assert_true(bot.is_ai, "slot 1 is a bot")
	_fresh(bot)
	_hit(bot, 10.0)
	assert_near(bot.health.grace_left, 0.35, 0.02, "bots: 0.35 s (PD2 team AI)")


func test_d145_no_grace_from_hazardous() -> void:
	await _launch(Enums.Difficulty.HAZARDOUS)
	var me: CrewController = _rt.crew_controller(0) as CrewController
	_fresh(me)
	_hit(me, 10.0)
	assert_near(_hit(me, 8.0), 8.0, 0.01, "Hazardous: every hit lands (LEAD decides Hazardous+ later)")
