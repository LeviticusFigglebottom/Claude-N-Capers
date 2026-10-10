## A1-03 behaviour: escape zone (C10). Humans not in custody inside an active zone end the heist.
extends TestCase

var _rt: HeistRuntime = null
var _results: Array[Dictionary] = []
var _cb: Callable = Callable()


func before_each() -> void:
	_results.clear()
	_rt = await HeistLauncher.launch(&"unit_escape", 1100, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	_cb = func(r: Dictionary) -> void: _results.append(r)
	EventBus.heist_ended.connect(_cb)


func after_each() -> void:
	if EventBus.heist_ended.is_connected(_cb):
		EventBus.heist_ended.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_c10_escape_ends_heist_with_success() -> void:
	var ez: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(0, 0, -6)) as EscapeZone
	await wait_physics_frames(2)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	await wait_physics_frames(5)
	assert_true(_results.is_empty(), "inactive zone does nothing")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 6)))
	_rt.mission.activate_escape()
	await wait_physics_frames(5)
	assert_true(_results.is_empty(), "human outside: no escape yet")
	assert_eq(ez.escaping_slots(_rt), [] as Array[int])
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0.5, 0.05, -6.5)))
	var ok: bool = await wait_until(func() -> bool: return not _results.is_empty(), 2.0)
	assert_true(ok, "heist_ended")
	if not ok:
		return
	var r: Dictionary = _results[0]
	assert_true(bool(r["success"]), "success")
	assert_eq(_rt.phase, Enums.HeistPhase.ENDED)
	for row: Dictionary in r["crew"]:
		assert_true(bool(row["escaped"]), "slot %d escaped (AI teammates come along)" % int(row["slot"]))
	await wait_physics_frames(3)
	assert_eq(_results.size(), 1, "ends once")


func test_c10_custody_human_not_required_and_not_escaped() -> void:
	var ez: EscapeZone = ATestMaps.add_prefab(_rt, "escape_zone", Vector3(0, 0, -6)) as EscapeZone
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_crew_state(Enums.CrewState.CUSTODY)
	ez.activate()
	await wait_physics_frames(3)
	assert_eq(ez.escaping_slots(_rt), [] as Array[int], "nobody required -> no auto escape")
	var a1: CrewController = _rt.crew_controller(1) as CrewController
	a1.set_crew_state(Enums.CrewState.CUSTODY)
	c.set_crew_state(Enums.CrewState.NORMAL)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))
	var ok: bool = await wait_until(func() -> bool: return not _results.is_empty(), 2.0)
	assert_true(ok)
	if ok:
		for row: Dictionary in _results[0]["crew"]:
			assert_eq(bool(row["escaped"]), int(row["slot"]) != 1, "slot %d escaped flag" % int(row["slot"]))
