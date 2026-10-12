## A4-01 phase-2/4 modifier keys: interaction.speed_mult, interaction.device_fix_speed_mult,
## defense.healing_received_mult.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 24, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	await wait_physics_frames(1)


func after_each() -> void:
	Modifiers.clear_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_interaction_speed_and_fix_speed_mults() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var ic: InteractableComponent = InteractableComponent.new()
	ic.interaction_time_s = 4.0
	_rt.add_child(ic)
	assert_near(ic.duration_for(c), 4.0, 0.001)
	Modifiers.set_source(0, &"test", {&"interaction.speed_mult": 0.5, &"interaction.device_fix_speed_mult": 0.5})
	assert_near(ic.duration_for(c), 2.0, 0.001, "interaction.speed_mult")
	ic.kind = &"fix_drill"
	assert_near(ic.duration_for(c), 1.0, 0.001, "device_fix_speed_mult on fix holds only")
	ic.queue_free()


func test_healing_received_mult() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.health.health = 100.0
	Modifiers.set_source(0, &"test", {&"defense.healing_received_mult": 1.5})
	c.health.heal(20.0)
	assert_near(c.health.health, 130.0, 0.001, "20 x 1.5")


func test_a4_04_fire_rate_mult() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var s: Variant = c.weapons._states[c.weapons.equipped_slot]
	var base: float = c.weapons._shot_interval(s)
	Modifiers.set_source(0, &"test", {&"weapon.fire_rate_mult.all": 2.0})
	assert_near(c.weapons._shot_interval(s), base * 0.5, 0.0001, "x2 rate = half interval")


func test_a4_04_bleedout_health_mult() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	Modifiers.set_source(0, &"test", {&"defense.bleedout_health_mult": 2.0})
	c.health.armor = 0.0
	c.take_hit(Damage.info(10000.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"t", c.global_position,
		Vector3.FORWARD, 0))
	assert_eq(c.crew_state, Enums.CrewState.DOWNED)
	assert_near(c.health.bleedout_health, Tweak.crew().bleedout_health * 2.0, 0.001)


func test_a4_04_small_loot_value_mult() -> void:
	var got: Array = []
	var cb: Callable = func(v: int, slot: int) -> void: got.append([v, slot])
	EventBus.small_loot_taken.connect(cb)
	Modifiers.set_source(0, &"test", {&"loot.small_loot_value_mult": 1.5})
	var sl: Node = ATestMaps.add_prefab(_rt, "small_loot", Vector3(0, 0, -3), func(n: Node) -> void:
		n.set(&"value", 1000))
	await wait_physics_frames(1)
	sl.call(&"_on_completed", _rt.crew_controller(0))
	EventBus.small_loot_taken.disconnect(cb)
	assert_eq(got, [[1500, 0]], "1000 x 1.5")
