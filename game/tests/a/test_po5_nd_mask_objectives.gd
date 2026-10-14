## Lead finding (P's Night Deposit capture): masking up must complete only the casing step; the keycard step
## stays ACTIVE until a keycard is picked up.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_po5_nd_masking_completes_only_casing() -> void:
	_rt = await HeistLauncher.launch(&"night_deposit", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": true})
	await wait_physics_frames(5)
	assert_eq(_rt.mission.objective_state(&"keycard"), Enums.ObjectiveState.ACTIVE, "keycard active at start")
	(_rt.crew_controller(0) as CrewController).set_masked()
	await wait_seconds(1.0)
	assert_eq(_rt.mission.objective_state(&"casing"), Enums.ObjectiveState.COMPLETED, "casing done on masking")
	assert_eq(_rt.mission.objective_state(&"keycard"), Enums.ObjectiveState.ACTIVE, "keycard still to find")
