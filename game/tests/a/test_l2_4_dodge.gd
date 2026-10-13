## A2-06 / L2.4: dodge. Per ranged (BULLET) hit, chance = ArmorDef.dodge + defense.dodge_add (a
## negative total = no dodge) on GameRng &"dodge"; a dodge does nothing and restarts the armor delay.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 24, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "skip_casing": true})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _hit(c: CrewController, amount: float, type: int = Enums.DamageType.BULLET) -> Dictionary:
	return c.take_hit(Damage.info(amount, type, Enums.HitZone.BODY, &"test", c.global_position, Vector3.FORWARD), 0)


func test_l2_4_dodge_add_one_dodges_every_ranged_hit() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	Modifiers.set_source(0, &"test", {&"defense.dodge_add": 1.0})
	assert_near(c.health.dodge_chance(), 1.0, 0.0001, "clamped to 1")
	var armor: float = c.health.armor
	var health: float = c.health.health
	for k: int in range(20):
		c.health.regen_delay_left = 0.0
		var out: Dictionary = _hit(c, 15.0)
		assert_true(bool(out.get("dodged", false)), "hit %d dodged" % k)
		assert_near(float(out["amount"]), 0.0, 0.0001)
		var delay: float = Tweak.crew().armor_regen_delay_s * Modifiers.mult(0, &"defense.armor_regen_delay_mult")
		assert_near(c.health.regen_delay_left, delay, 0.0001, "dodge restarts the armor delay")
	assert_near(c.health.armor, armor, 0.0001, "armor untouched")
	assert_near(c.health.health, health, 0.0001, "health untouched")


func test_l2_4_melee_can_be_dodged() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	Modifiers.set_source(0, &"test", {&"defense.dodge_add": 1.0})
	var out: Dictionary = _hit(c, 5.0, Enums.DamageType.MELEE)
	assert_true(bool(out.get("dodged", false)), "L2.4: melee can be dodged (knockback is the caller's)")
	assert_near(float(out["amount"]), 0.0, 0.001)


func test_l2_4_negative_total_never_dodges() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	Modifiers.set_source(0, &"test", {&"defense.dodge_add": -1.0})
	assert_near(c.health.dodge_chance(), 0.0, 0.0001, "negative total = 0")
	var dodged: int = 0
	for k: int in range(40):
		c.health.reset_full()
		if bool(_hit(c, 1.0).get("dodged", false)):
			dodged += 1
	assert_eq(dodged, 0, "no dodges")


func test_l2_4_seeded_rate_matches_chance() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var base: float = c.health.dodge_chance()
	Modifiers.set_source(0, &"test", {&"defense.dodge_add": 0.5 - base})
	assert_near(c.health.dodge_chance(), 0.5, 0.0001, "armor dodge + dodge_add")
	var dodged: int = 0
	for k: int in range(400):
		c.health.reset_full()
		if bool(_hit(c, 1.0).get("dodged", false)):
			dodged += 1
	assert_true(dodged > 150 and dodged < 250, "about half dodged (%d / 400)" % dodged)
