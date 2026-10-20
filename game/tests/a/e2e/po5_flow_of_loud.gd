## OF-A6 phase 2: the Ostrander Federal loud line on the REAL menus. po5_flow.gd clicks through the menus to Start Heist
## (seed via --po5-seed; run_po5.sh passes the D-133 harness-only --po5-crew-dmg); this flow then plays the same line as
## test_x4_of_loud.gd (X4OfLoud: alarm -> lockdown -> drill parts -> burn-through -> cage -> hoist -> [secure] -> loud
## escape, with its stated harness shortcuts; the AI teammates are the lobby's) on that menu-launched runtime, checks the
## loud win (went loud, the loud objective order, heist_ended(success, not stealth), escape completed before the end,
## the bags came up the hoist, the bot never in custody) and clicks the payday back to the hub.
## run: game/tests/a/e2e/run_po5.sh of_loud <seed> 2400 <out> "Ostrander Federal"   (with --po5-crew-dmg=0.25)
extends RefCounted

const LOUD_ORDER: Array[StringName] = [&"drill_delivery", &"vault_drill", &"vault_breach", &"secure", &"escape_wait",
	&"escape"]


func play(driver: Node) -> int:
	var rt: HeistRuntime = driver.get(&"rt") as HeistRuntime
	var flow: X4StealthFlow = X4StealthFlow.new(driver)
	flow.sink = func(line: String) -> void: driver.call(&"note", line)
	if not await flow.attach(rt, rt.run_seed):
		return _fail(driver, flow, "attach to the menu-launched runtime")
	flow.note("crew_damage_taken_mult=%s (D-133 harness-only); AI teammates %d" % [
		HeistLauncher.dev_options.get("crew_damage_taken_mult", 1.0), rt.crew_members().size() - 1])
	var loud: X4OfLoud = X4OfLoud.new(flow)
	var ok: bool = await loud.play()
	flow.note(("loud route %s at %.1f s heist; objectives %s; secured %s; jams fixed %d; hoist trips %d; downs %d; "
		+ "custody %d") % ["done" if ok else "FAILED", rt.heist_time_s, flow.completed, flow.secured_loot,
		loud.jams_fixed, loud.hoist_trips, loud.downs, loud.custody])
	flow.check(ok, "loud route completed")
	flow.check(rt.went_loud, "went loud")
	flow.check(loud.custody == 0, "the bot never went into custody")
	flow.check(loud.hoist_trips >= 2, "the bags came up the hoist (%d trips)" % loud.hoist_trips)
	flow.check(flow.ended.size() == 1, "heist_ended once (%d)" % flow.ended.size())
	if not flow.ended.is_empty():
		flow.check(bool(flow.ended[0].get("success", false)), "heist_ended(success)")
		flow.check(not bool(flow.ended[0].get("stealth", true)), "a loud result")
	var pos: int = -1
	for id: StringName in LOUD_ORDER:
		var at: int = flow.completed.find(id)
		flow.check(at > pos, "objective %s after the previous step (%s)" % [id, flow.completed])
		pos = maxi(pos, at)
	flow.check(flow.completed_at_end.has(&"escape"), "escape completed before heist_ended (%s)" % [flow.completed_at_end])
	flow.detach()
	if not flow.failures.is_empty():
		return _fail(driver, flow, "%d check(s)" % flow.failures.size())
	driver.call(&"note", "RESULT of_loud route PASS seed %d: %s" % [rt.run_seed, flow.completed])
	return await driver.call(&"payday_to_hub")


func _fail(driver: Node, flow: X4StealthFlow, what: String) -> int:
	flow.detach()
	driver.call(&"note", "FAIL of_loud: %s; failures %s" % [what, flow.failures])
	return 1
