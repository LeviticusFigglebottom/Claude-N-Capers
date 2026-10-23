## AH-A1 (LEAD r305): the Afterhours loud line on the REAL menus, headless. Civilian start: the auto_loud pilot
## (po5_flow_auto_loud.gd, input only) takes the gear first (its _gear_up: the rolled gear_drop bag), masks up, goes
## loud and follows the objective markers. Checks: the gear before the mask, the loud order (gear -> office -> safe ->
## secure -> escape), lockdown on, the escape opened, heist_ended(success, not stealth). Logs the safe method, the
## couriers and the off-duty cop.
## run: DIRECT=1 HEADLESS=1 game/tests/a/e2e/run_po5.sh ah_loud <seed> 2400 <out> "Afterhours" Routine
extends RefCounted

const AUTO_LOUD: String = "res://tests/a/e2e/po5_flow_auto_loud.gd"
const LOUD_ORDER: Array[StringName] = [&"gear", &"office", &"safe", &"secure", &"escape"]


func play(driver: Node) -> int:
	var rt: HeistRuntime = driver.get(&"rt") as HeistRuntime
	if rt.heist_id != &"afterhours":
		driver.call(&"note", "FAIL ah_loud: not Afterhours (%s)" % rt.heist_id)
		return 1
	var completed: Array[StringName] = []
	var facts: Dictionary = {"masked_civilian": false}
	var on_obj: Callable = func(id: StringName, st: int, _d: Dictionary) -> void:
		if st == Enums.ObjectiveState.COMPLETED and not completed.has(id):
			completed.append(id)
	var on_mask: Callable = func(slot: int) -> void:
		var c: CrewController = rt.crew_controller(slot) as CrewController if is_instance_valid(rt) else null
		if c != null and c.civilian:
			facts["masked_civilian"] = true
	var ended: Array[Dictionary] = []
	var on_end: Callable = func(r: Dictionary) -> void:  # the payday frees the runtime: read the mission now
		ended.append(r)
		var m: Node = rt.mission
		facts.merge({"safe_open": m.get(&"safe_open"), "lockdown": m.get(&"lockdown"),
			"escape_open": m.get(&"escape_open"), "couriers": (m.get(&"couriers") as Array).size(),
			"off_duty_cop": m.get(&"off_duty_cop") != null, "alarm": rt.stealth.alarm_reason if rt.stealth else &"",
			"completed": completed.duplicate()}, true)
	EventBus.objective_updated.connect(on_obj)
	EventBus.heist_ended.connect(on_end)
	EventBus.crew_masked.connect(on_mask)
	var seed_v: int = rt.run_seed
	driver.call(&"note", "ah_loud: civilian start %s, gear_drop %s" % [(rt.crew_controller(0) as CrewController).civilian,
		rt.mission.call(&"gear_line")])
	var guards: int = rt.npcs(&"guard").size()
	driver.call(&"note", "DONECHECK D-140 guards at load %d, pager cap %d (margin %d)" % [guards,
		rt.mission.pager_cap(), guards - rt.mission.pager_cap()])
	if OS.get_environment("PO5_FORCE_CAPTAIN") == "1":
		# D-166 end-to-end (LEAD): harness only, Brandt always comes at his first eligible wave (captain_min_wave), so the
		# waiver path (secure done, SUSTAIN locked) runs; the shared tweak resource is not touched.
		var dir: AssaultDirector = rt.service(G.SVC_DIRECTOR) as AssaultDirector
		if dir != null:
			dir.tweak = dir.tweak.duplicate() as DirectorTweak
			dir.tweak.captain_chance = 1.0
			driver.call(&"note", "harness: PO5_FORCE_CAPTAIN, captain_chance 1.0 from wave %d" % dir.tweak.captain_min_wave)
	var loud: RefCounted = (load(AUTO_LOUD) as GDScript).new()
	var rc: int = await loud.call(&"play", driver)
	EventBus.objective_updated.disconnect(on_obj)
	EventBus.heist_ended.disconnect(on_end)
	EventBus.crew_masked.disconnect(on_mask)
	var fails: Array[String] = []
	if rc != 0:
		fails.append("auto_loud rc %d" % rc)
	if ended.is_empty():
		fails.append("no heist_ended")
	else:
		if not bool(ended[0].get("success", false)):
			fails.append("heist_ended not a success")
		if bool(ended[0].get("stealth", true)):
			fails.append("not a loud result")
	if bool(facts["masked_civilian"]):
		fails.append("masked while civilian")
	var pos: int = -1
	for id: StringName in LOUD_ORDER:
		var at: int = completed.find(id)
		if at <= pos:
			fails.append("objective %s out of order or missing (%s)" % [id, completed])
		pos = maxi(pos, at)
	if not bool(facts.get("lockdown", false)):
		fails.append("no lockdown")
	driver.call(&"note", "RESULT ah_loud %s seed %d: facts %s; %s" % ["PASS" if fails.is_empty() else "FAIL", seed_v,
		facts, fails])
	return 0 if fails.is_empty() else 1
