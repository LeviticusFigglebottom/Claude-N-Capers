## AH-A1 (LEAD r305 plan (b)): the Afterhours stealth (civilian) line on the REAL menus. po5_flow.gd clicks main menu ->
## Planning Table -> Afterhours -> difficulty -> Briefing -> Start Heist (the seed via --po5-seed); this flow then
## plays the same route as test_x4_ah_stealth.gd (X4StealthRoutes, route afterhours: gear -> mask -> keycard ->
## office -> safe -> 3 cash bags -> van, with its stated harness shortcuts) on that menu-launched runtime, checks the
## stealth win (no alarm, no laser, no pager, never loud,
## heist_ended(success, stealth), escape completed before the end) and clicks the payday back to the hub.
## run: game/tests/a/e2e/run_po5.sh ah_stealth <seed> 1800 <out> "Afterhours"
extends RefCounted


func play(driver: Node) -> int:
	var rt: HeistRuntime = driver.get(&"rt") as HeistRuntime
	var flow: X4StealthFlow = X4StealthFlow.new(driver)
	flow.sink = func(line: String) -> void: driver.call(&"note", line)
	if not await flow.attach(rt, rt.run_seed):
		return _fail(driver, flow, "attach to the menu-launched runtime")
	var ok: bool = await X4StealthRoutes.play(flow)
	flow.note("route %s at %.1f s heist; objectives %s; secured %s; laser waits %d" % [
		"done" if ok else "FAILED", rt.heist_time_s, flow.completed, flow.secured_loot, flow.laser_waits])
	flow.check(ok, "stealth route completed")
	flow.check(flow.alarms.is_empty(), "no alarm_raised (%s)" % [flow.alarms])
	flow.check(flow.lasers_tripped == 0, "no laser tripped (%d)" % flow.lasers_tripped)
	flow.check(flow.pagers == 0, "no pager (%d)" % flow.pagers)
	flow.check(not rt.went_loud, "never went loud")
	flow.check(flow.ended.size() == 1, "heist_ended once (%d)" % flow.ended.size())
	if not flow.ended.is_empty():
		flow.check(bool(flow.ended[0].get("success", false)), "heist_ended(success)")
		flow.check(bool(flow.ended[0].get("stealth", false)), "heist_ended(stealth)")
	flow.check(flow.completed_at_end.has(&"escape"), "escape completed before heist_ended (%s)" % [flow.completed_at_end])
	flow.detach()
	if not flow.failures.is_empty():
		return _fail(driver, flow, "%d check(s)" % flow.failures.size())
	driver.call(&"note", "RESULT ah_stealth route PASS seed %d: %s" % [rt.run_seed, flow.completed])
	return await driver.call(&"payday_to_hub")


func _fail(driver: Node, flow: X4StealthFlow, what: String) -> int:
	flow.detach()
	driver.call(&"note", "FAIL ah_stealth: %s; failures %s" % [what, flow.failures])
	return 1
