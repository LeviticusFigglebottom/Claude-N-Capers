## A4-01 / S2.7: NPC loud targeting range follows the target's detection risk (80 m at DR 3, 180 m at DR 75).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_s2_7_range_lerps_on_detection_risk() -> void:
	var l: Loadout = Loadout.new()
	_rt = await HeistLauncher.launch(&"unit_map", 27, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false, "loadouts": {0: l}})
	await wait_physics_frames(1)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.loadout.detection_risk = 3
	assert_near(NpcGunner.target_range_for(c), 80.0, 0.01, "DR 3 -> 80 m")
	c.loadout.detection_risk = 75
	assert_near(NpcGunner.target_range_for(c), 180.0, 0.01, "DR 75 -> 180 m")
	c.loadout.detection_risk = 39
	assert_near(NpcGunner.target_range_for(c), 130.0, 0.01, "DR 39 -> 130 m")
