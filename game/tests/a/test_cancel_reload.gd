## LEAD (for ENV P, PD2): CrewWeapons.cancel_reload stops a running reload (a sprint start), the magazine unchanged.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_cancel_reload_keeps_the_rounds() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1300, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "loadouts": {0: CrewWeapons.build_loadout(null)}})
	await wait_physics_frames(2)
	var w: CrewWeapons = (_rt.crew_controller(0) as CrewController).weapons
	var ws: int = w.equipped_slot
	assert_false(w.cancel_reload(), "nothing to cancel")
	w.set_ammo(ws, 2, w.reserve(ws))
	var reserve: int = w.reserve(ws)
	assert_true(w.start_reload(), "a reload starts")
	var cancelled: Array[int] = []
	w.reload_cancelled.connect(func(slot: int) -> void: cancelled.append(slot))
	assert_false(w.cancel_reload(ws + 1), "another slot: not this reload")
	assert_true(w.cancel_reload(ws), "cancelled")
	assert_false(w.reloading, "no longer reloading")
	assert_eq(cancelled, [ws] as Array[int], "reload_cancelled emitted")
	await wait_seconds(0.2)
	assert_eq(w.mag(ws), 2, "the magazine did not fill")
	assert_eq(w.reserve(ws), reserve, "the reserve untouched")
	assert_true(w.start_reload(), "a new reload can start")
