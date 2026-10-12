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
