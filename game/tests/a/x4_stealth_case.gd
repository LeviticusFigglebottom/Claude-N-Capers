## X-4 shared test body (not a test file itself: no test_ prefix). Owner: ENV A.
## Each test_x4_<heist>_stealth.gd extends this and calls `run_stealth(heist, seed, expected_order)`: the
## X4StealthFlow route (game/tests/a/e2e/x4_stealth_flow.gd, its header lists the harness shortcuts) must finish
## the heist in stealth: no alarm_raised, no laser trip, no pager, heist_ended(success, stealth), the stealth
## objectives completed in route order, and the run under the headless budget.
extends TestCase

## Headless budget per flow (wall seconds; X-4: under ~3 minutes).
const BUDGET_S: float = 180.0

var flow: X4StealthFlow = null


func after_each() -> void:
	if flow != null:
		await flow.teardown()
	flow = null
	await wait_frames(2)


func run_stealth(heist: StringName, seed_value: int, expected_order: Array[StringName]) -> void:
	var t0: int = Time.get_ticks_msec()
	flow = X4StealthFlow.new(self)
	if not await flow.launch(heist, seed_value):
		_report()
		return
	var ok: bool = await X4StealthRoutes.play(flow)
	var wall_s: float = float(Time.get_ticks_msec() - t0) / 1000.0
	flow.note("route %s in %.1f s wall, %.1f s heist; objectives %s; secured %s; laser waits %d" % [
		"done" if ok else "FAILED", wall_s, flow.rt.heist_time_s, flow.completed, flow.secured_loot, flow.laser_waits])
	_report()
	assert_true(ok, "%s stealth route completed" % heist)
	assert_eq(flow.alarms, [] as Array[StringName], "no alarm_raised")
	assert_eq(flow.lasers_tripped, 0, "no laser tripped")
	assert_eq(flow.pagers, 0, "no pager (nobody was killed)")
	assert_false(flow.rt.went_loud, "never went loud")
	assert_eq(flow.ended.size(), 1, "heist_ended once")
	if not flow.ended.is_empty():
		var r: Dictionary = flow.ended[0]
		assert_true(bool(r.get("success", false)), "heist_ended(success)")
		assert_true(bool(r.get("stealth", false)), "heist_ended(stealth)")
	assert_eq(flow.rt.phase, Enums.HeistPhase.ENDED, "phase ENDED")
	var pos: int = -1
	for id: StringName in expected_order:
		var at: int = flow.completed.find(id)
		assert_true(at > pos, "objective %s completed after the previous step (order %s)" % [id, flow.completed])
		pos = maxi(pos, at)
	assert_ne(flow.objective(&"escape"), Enums.ObjectiveState.HIDDEN, "the mission opened the escape")
	assert_true(wall_s < BUDGET_S, "under the headless budget (%.1f s)" % wall_s)


func _report() -> void:
	for f: String in flow.failures:
		fail(f)
