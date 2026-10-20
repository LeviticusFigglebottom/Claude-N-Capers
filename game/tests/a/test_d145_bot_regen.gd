## D-145 §4a (PO, ◇): an AI bot regains CrewAiTweak.bot_regen_frac_per_s of max health per second once
## bot_regen_delay_s has passed without damage; any hit restarts the wait; human crew do not regenerate (L2.1).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _hit(c: CrewController, amount: float) -> void:
	c.health.take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", c.global_position,
		Vector3.FORWARD, 0))


func test_d145_bot_regenerates_after_a_quiet_spell() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1450, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var me: CrewController = _rt.crew_controller(0) as CrewController
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	assert_true(bot.is_ai and not me.is_ai, "slot 1 is a bot, slot 0 human")
	var tw: CrewAiTweak = CrewHealth._bot_tweak()
	for c: CrewController in [me, bot]:
		c.health.armor = 0.0
		_hit(c, c.health.max_health * 0.5)
	var bot_after_hit: float = bot.health.health
	var me_after_hit: float = me.health.health
	await wait_seconds(tw.bot_regen_delay_s - 1.0)
	assert_near(bot.health.health, bot_after_hit, 0.01, "no regen before the delay")
	_hit(bot, 1.0)  # restarts the wait
	var restarted: float = bot.health.health
	await wait_seconds(tw.bot_regen_delay_s - 1.0)
	assert_near(bot.health.health, restarted, 0.01, "a hit restarted the delay")
	await wait_seconds(3.0)
	var gained: float = bot.health.health - restarted
	var want: float = bot.health.max_health * tw.bot_regen_frac_per_s * 2.0  # >= 2 s of regen inside the 3 s
	assert_true(gained >= want * 0.9, "the bot regained %.1f (>= %.1f)" % [gained, want])
	assert_true(me.health.health <= me_after_hit + 0.01, "the human did not regenerate")
