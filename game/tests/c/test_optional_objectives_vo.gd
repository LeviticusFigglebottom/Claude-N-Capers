## B VO coverage (vo_coverage.md, UNSAID_C): the optional objectives whose completion plays a Vance radio line.
## Glasshouse: extra_bags (> 2 bags secured), salon (both salon cases emptied), display_cases (every sales-floor
## case emptied). Gallery Night: lockers (every kept consignment locker emptied).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _empty(cases: Array[Node]) -> void:
	for c: Node in cases:
		c.set(&"taken", true)
		EventBus.small_loot_taken.emit(100, 0)


func test_glasshouse_optional_extras_complete() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched glasshouse")
	await wait_physics_frames(3)
	var m: HeistMission = _rt.mission
	for id: StringName in [&"extra_bags", &"salon", &"display_cases"]:
		assert_eq(m.objective_state(id), Enums.ObjectiveState.ACTIVE, "%s active from the start" % id)
	var salon: Array[Node] = m.find_tagged(&"salon_case")
	var floor_cases: Array[Node] = m.find_tagged(&"display_case")
	assert_eq(salon.size(), 2, "two salon cases tagged")
	assert_eq(floor_cases.size(), 6, "six sales-floor cases tagged")
	_empty(salon.slice(0, 1))
	assert_eq(m.objective_state(&"salon"), Enums.ObjectiveState.ACTIVE, "one salon case is not the salon")
	_empty(salon.slice(1))
	assert_eq(m.objective_state(&"salon"), Enums.ObjectiveState.COMPLETED, "salon done")
	assert_eq(m.objective_state(&"display_cases"), Enums.ObjectiveState.ACTIVE, "floor cases still full")
	_empty(floor_cases)
	assert_eq(m.objective_state(&"display_cases"), Enums.ObjectiveState.COMPLETED, "display_cases done")
	for i: int in 2:
		EventBus.loot_secured.emit(9000 + i, &"loot.jewelry", 1000)
	assert_eq(m.objective_state(&"extra_bags"), Enums.ObjectiveState.ACTIVE, "the minimum is not extra")
	EventBus.loot_secured.emit(9002, &"loot.jewelry", 1000)
	assert_eq(m.objective_state(&"extra_bags"), Enums.ObjectiveState.COMPLETED, "a third bag is extra")


func test_gallery_night_lockers_complete() -> void:
	_rt = await HeistLauncher.launch(&"gallery_night", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched gallery_night")
	await wait_physics_frames(3)
	var m: HeistMission = _rt.mission
	var kept: Array[Node] = []
	for n: Node in m.find_tagged(&"lockers"):
		if (n as Node3D).visible:
			kept.append(n)
	assert_true(kept.size() >= 4, "consignment lockers kept (%d)" % kept.size())
	assert_eq(m.objective_state(&"lockers"), Enums.ObjectiveState.ACTIVE, "lockers active")
	for i: int in kept.size():
		EventBus.interaction_completed.emit(int(kept[i].get(&"net_id")), 0, &"take_loot")
		if i < kept.size() - 1:
			assert_eq(m.objective_state(&"lockers"), Enums.ObjectiveState.ACTIVE, "lockers left after %d" % (i + 1))
	assert_eq(m.objective_state(&"lockers"), Enums.ObjectiveState.COMPLETED, "every kept locker emptied")
	assert_eq(m.objective_state(&"extras"), Enums.ObjectiveState.ACTIVE, "extras still needs the list and the safe")
