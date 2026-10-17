## X-4 / OF-A6: Ostrander Federal (ostrander_federal) loud end-to-end (doc §Loud; next_heist_ostrander.md §4: "run the
## loud e2e through LOUD -> ESCAPE on >= 3 seeds"), the X4OfLoud flow (game/tests/a/e2e/x4_of_loud.gd, its header lists
## the harness shortcuts and the D-133 dev option crew_damage_taken_mult 0.25) on 3 seeds that cover both drill drops
## and all three escapes (the rolls are printed by the flow's launch line):
##   seed 5: drop_terrace (drill_eta_s 45), the van at the dock (escape_eta_s 90);
##   seed 1: drop_dock (60), the heli over the terrace (120);
##   seed 6: drop_terrace (60), the van on Tannery Street (120).
## Win: alarm -> lockdown -> both drill parts placed -> burn-through -> every [secure] bag up the hoist -> the loud
## escape -> heist_ended(success, not stealth). SKIPs "pending C G1" while ENV C's map is not on the branch.
extends TestCase

const HEIST: StringName = &"ostrander_federal"
const MAP_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const PENDING: String = "pending C G1: no ostrander_federal map on this branch (OF-C1)"
## Headless budget per flow (wall seconds): the 360 s burn and the escape wait run at X4StealthFlow.FAST.
const BUDGET_S: float = 600.0
const LOUD_ORDER: Array[StringName] = [&"drill_delivery", &"vault_drill", &"vault_breach", &"secure", &"escape_wait",
	&"escape"]

var flow: X4StealthFlow = null


func after_each() -> void:
	HeistLauncher.dev_options.erase("crew_damage_taken_mult")
	if flow != null:
		await flow.teardown()
	flow = null
	await wait_frames(2)


func _pending() -> bool:
	if ResourceLoader.exists(MAP_PATH):
		return false
	skip(PENDING)
	return true


func _run(seed_value: int) -> void:
	var t0: int = Time.get_ticks_msec()
	flow = X4StealthFlow.new(self)
	if not await X4OfLoud.launch(flow, HEIST, seed_value):
		_report()
		return
	var loud: X4OfLoud = X4OfLoud.new(flow)
	var ok: bool = await loud.play()
	var wall_s: float = float(Time.get_ticks_msec() - t0) / 1000.0
	flow.note("loud route %s in %.1f s wall, %.1f s heist; objectives %s; secured %s; jams fixed %d; hoist trips %d; downs %d" % [
		"done" if ok else "FAILED", wall_s, flow.rt.heist_time_s, flow.completed, flow.secured_loot, loud.jams_fixed,
		loud.hoist_trips, loud.downs])
	_report()
	assert_true(ok, "OF loud route completed (seed %d)" % seed_value)
	assert_true(flow.rt.went_loud, "went loud")
	assert_eq(loud.custody, 0, "the bot never went into custody")
	assert_eq(flow.ended.size(), 1, "heist_ended once")
	if not flow.ended.is_empty():
		var r: Dictionary = flow.ended[0]
		assert_true(bool(r.get("success", false)), "heist_ended(success)")
		assert_false(bool(r.get("stealth", true)), "a loud result")
	assert_eq(flow.rt.phase, Enums.HeistPhase.ENDED, "phase ENDED")
	var pos: int = -1
	for id: StringName in LOUD_ORDER:
		var at: int = flow.completed.find(id)
		assert_true(at > pos, "objective %s completed after the previous step (order %s)" % [id, flow.completed])
		pos = maxi(pos, at)
	assert_true(flow.completed_at_end.has(&"escape"), "escape completed before heist_ended (%s)" % [flow.completed_at_end])
	assert_true(loud.hoist_trips >= 2, "the bags came up the hoist (%d trips)" % loud.hoist_trips)
	assert_true(wall_s < BUDGET_S, "under the headless budget (%.1f s)" % wall_s)


func _report() -> void:
	for f: String in flow.failures:
		fail(f)


func test_x4_of_loud_seed_5_terrace_drop_dock_van() -> void:
	if _pending():
		return
	await _run(5)


func test_x4_of_loud_seed_1_dock_drop_heli() -> void:
	if _pending():
		return
	await _run(1)


func test_x4_of_loud_seed_6_terrace_drop_tannery_van() -> void:
	if _pending():
		return
	await _run(6)
