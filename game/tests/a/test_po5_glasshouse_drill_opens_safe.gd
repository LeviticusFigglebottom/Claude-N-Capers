## PO-5.8 (D-086): on the real Glasshouse map a finished safe drill opens the safe door and enables
## the bags inside (the mission's device_finished handler used to set `opened` only, which made the
## Safe ignore the drill's own open_by_device: the "drill never opens" report).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _tagged(tag: StringName) -> Node:
	for n: Node in _rt.mission.find_tagged(tag):
		return n
	return null


func test_po5_drill_finish_opens_glasshouse_safe() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched glasshouse")
	await wait_physics_frames(5)
	var drill: DrillPoint = _tagged(&"safe_drill") as DrillPoint
	var safe: Safe = _tagged(&"safe") as Safe
	var loot: GameplayPrefab = _tagged(&"safe_loot") as GameplayPrefab
	assert_true(drill != null and safe != null and loot != null, "safe, drill and loot are tagged")
	assert_false(loot.interactable.enabled, "bags locked while the safe is shut")
	drill.runner.place(0, 0.5)
	drill.runner.jams.clear()
	assert_true(await wait_until(func() -> bool: return drill.runner.state == DeviceRunner.State.DONE, 3.0), "drill done")
	await wait_physics_frames(2)
	assert_true(safe.opened, "safe opened")
	assert_true(loot.interactable.enabled, "the bags inside can be taken")
	assert_eq(_rt.mission.objective_state(&"safe_loot"), Enums.ObjectiveState.ACTIVE, "safe_loot objective active")
