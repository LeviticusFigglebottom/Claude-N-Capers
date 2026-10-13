## PP audit (Night Deposit ATMs): small loot targeted by a DrillPoint (cash behind a saw) is locked until the
## device finishes; before, the cash could be taken (even while casing with S1.1) without sawing.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_pp_atm_cash_locked_until_saw_finishes() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 41, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	var cash: SmallLoot = ATestMaps.add_prefab(_rt, "small_loot", Vector3(0, 0.45, -6)) as SmallLoot
	var saw: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 0.6, -5.6), func(n: Node) -> void:
		var d: DrillPoint = n as DrillPoint
		d.device = DrillPoint.Device.SAW
		d.target = d.get_path_to(cash) if d.is_inside_tree() else NodePath("../%s" % cash.name)) as DrillPoint
	await wait_physics_frames(3)
	assert_true(cash.locked, "locked behind the saw")
	assert_false(cash.interactable.enabled, "no take prompt yet")
	cash._on_completed(_rt.crew_controller(0))
	assert_false(cash.taken, "cannot be taken while locked")
	DrillPoint.open_target(cash)
	assert_false(cash.locked)
	assert_true(cash.interactable.enabled, "prompt after the saw")
	assert_true(is_instance_valid(saw))
