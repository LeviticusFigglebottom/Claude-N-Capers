## OF-A6 robustness probe (LEAD 2026-10-20): the Ostrander Federal loud line on Hazardous and Cataclysm (2 seeds each)
## and the stealth ghost line on Cataclysm, so the higher difficulties do not hide a soft lock (drill jams, the hoist
## under heavy assaults, the escape ETA). Same flows and stated harness shortcuts as test_x4_of_loud.gd /
## test_x4_of_stealth.gd (loud: D-133 crew_damage_taken_mult 0.25, the bot does not shoot back; 3 AI teammates).
## OPT-IN (each loud run is several minutes headless): runs only with CNC_OF_HARD=1, else SKIP.
##   CNC_OF_HARD=1 tools/ci/run_tests.sh a test_x4_of_hard
extends TestCase

const HEIST: StringName = &"ostrander_federal"
const MAP_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const LOUD_ORDER: Array[StringName] = [&"drill_delivery", &"vault_drill", &"vault_breach", &"secure", &"escape_wait",
	&"escape"]
const PC_LINE: Array[StringName] = [&"keycard", &"code_pc", &"vault_gate", &"time_lock", &"time_lock_wait", &"secure",
	&"escape"]

var flow: X4StealthFlow = null


func after_each() -> void:
	HeistLauncher.dev_options.erase("crew_damage_taken_mult")
	if flow != null:
		await flow.teardown()
	flow = null
	await wait_frames(2)


func _skip() -> bool:
	if OS.get_environment("CNC_OF_HARD") != "1":
		skip("opt-in: CNC_OF_HARD=1")
		return true
	if not ResourceLoader.exists(MAP_PATH):
		skip("no ostrander_federal map")
		return true
	return false


func test_of_loud_hazardous_seed_5() -> void:
	await _loud(5, Enums.Difficulty.HAZARDOUS)


func test_of_loud_hazardous_seed_1() -> void:
	await _loud(1, Enums.Difficulty.HAZARDOUS)


func test_of_loud_cataclysm_seed_5() -> void:
	await _loud(5, Enums.Difficulty.CATACLYSM)


func test_of_loud_cataclysm_seed_6() -> void:
	await _loud(6, Enums.Difficulty.CATACLYSM)


func test_of_stealth_cataclysm_seed_7() -> void:
	if _skip():
		return
	var t0: int = Time.get_ticks_msec()
	flow = X4StealthFlow.new(self)
	flow.difficulty = Enums.Difficulty.CATACLYSM
	if not await flow.launch(HEIST, 7):
		_report()
		return
	var ok: bool = await X4StealthRoutes.play(flow)
	flow.note("CATACLYSM stealth route %s in %.1f s wall, %.1f s heist; objectives %s; laser waits %d" % [
		"done" if ok else "FAILED", (Time.get_ticks_msec() - t0) / 1000.0, flow.rt.heist_time_s, flow.completed,
		flow.laser_waits])
	_report()
	assert_true(ok, "stealth route completed on Cataclysm")
	assert_eq(flow.alarms, [] as Array[StringName], "no alarm_raised")
	assert_false(flow.rt.went_loud, "never went loud")
	assert_eq(flow.ended.size(), 1, "heist_ended once")
	if not flow.ended.is_empty():
		assert_true(bool(flow.ended[0].get("success", false)) and bool(flow.ended[0].get("stealth", false)),
			"heist_ended(success, stealth)")
	_assert_order(PC_LINE)


func _loud(seed_value: int, difficulty: int) -> void:
	if _skip():
		return
	var t0: int = Time.get_ticks_msec()
	flow = X4StealthFlow.new(self)
	flow.difficulty = difficulty
	if not await X4OfLoud.launch(flow, HEIST, seed_value):
		_report()
		return
	var loud: X4OfLoud = X4OfLoud.new(flow)
	var ok: bool = await loud.play()
	flow.note(("%s loud route %s in %.1f s wall, %.1f s heist; objectives %s; jams fixed %d; hoist trips %d; downs %d; "
		+ "custody %d; police alive at the end %d") % [Enums.Difficulty.keys()[difficulty], "done" if ok else "FAILED",
		(Time.get_ticks_msec() - t0) / 1000.0, flow.rt.heist_time_s, flow.completed, loud.jams_fixed, loud.hoist_trips,
		loud.downs, loud.custody, flow.rt.npcs(&"police").size()])
	_report()
	assert_true(ok, "OF loud route completed (%s seed %d)" % [Enums.Difficulty.keys()[difficulty], seed_value])
	assert_eq(flow.ended.size(), 1, "heist_ended once")
	if not flow.ended.is_empty():
		assert_true(bool(flow.ended[0].get("success", false)), "heist_ended(success)")
	_assert_order(LOUD_ORDER)


func _assert_order(order: Array[StringName]) -> void:
	var pos: int = -1
	for id: StringName in order:
		var at: int = flow.completed.find(id)
		assert_true(at > pos, "objective %s after the previous step (%s)" % [id, flow.completed])
		pos = maxi(pos, at)
	assert_true(flow.completed_at_end.has(&"escape"), "escape completed before heist_ended (%s)" % [flow.completed_at_end])


func _report() -> void:
	for f: String in flow.failures:
		fail(f)
