## A3-04 / L2.9 custody: auto-release after 119 s on Routine/Tense, trade-only above; release at full
## health with 50% ammo and no deployables refilled, next to the crew; the heist fails when every
## human is in custody and no trade is possible (fail_reason &"all_custody", D-038).
extends TestCase

var _rt: HeistRuntime = null
var _results: Array[Dictionary] = []


func before_each() -> void:
	_results.clear()
	EventBus.heist_ended.connect(_on_ended)


func after_each() -> void:
	if EventBus.heist_ended.is_connected(_on_ended):
		EventBus.heist_ended.disconnect(_on_ended)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_ended(result: Dictionary) -> void:
	_results.append(result)


func _launch(difficulty: Enums.Difficulty, ai: int, civilians: int = 0) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 919, difficulty, self,
		{"map_packed": ATestMaps.basic(0, civilians), "ai_teammates": ai, "crew_ai": false, "skip_casing": true})


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _custody() -> CustodySystem:
	return CustodySystem.of(_rt)


func test_l2_9_tweak_values() -> void:
	var tw: CustodyTweak = CustodyTweak.data()
	assert_near(tw.auto_release_for(Enums.Difficulty.ROUTINE), 119.0, 0.001, "Routine 119 s")
	assert_near(tw.auto_release_for(Enums.Difficulty.TENSE), 119.0, 0.001, "Tense 119 s")
	for d: int in [Enums.Difficulty.HAZARDOUS, Enums.Difficulty.BRUTAL, Enums.Difficulty.LETHAL, Enums.Difficulty.CATACLYSM]:
		assert_true(tw.auto_release_for(d) < 0.0, "trade only on difficulty %d" % d)
	assert_near(tw.release_ammo_frac, 0.5, 0.001, "50% ammo")


func test_l2_9_auto_release_routine() -> void:
	await _launch(Enums.Difficulty.ROUTINE, 1)
	var cs: CustodySystem = _custody()
	assert_true(cs != null, "custody service registered")
	var ai: CrewController = _crew(1)
	var w: CrewWeapons = ai.weapons
	var ws: int = w.equipped_slot
	var full: int = w.mag(ws) + w.reserve(ws)
	w.set_ammo(ws, 0, 0)
	var deploy_before: int = w.deployable_count
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(3, 0.05, 3)))
	ai.health.go_to_custody()
	assert_eq(ai.crew_state, Enums.CrewState.CUSTODY)
	assert_true(cs.in_custody(1), "custody entry")
	assert_near(cs.auto_release_left(1), 119.0, 0.01, "119 s timer")
	cs.tick(100.0)
	assert_eq(ai.crew_state, Enums.CrewState.CUSTODY, "still in custody at 100 s")
	cs.tick(19.5)
	assert_eq(ai.crew_state, Enums.CrewState.NORMAL, "auto-released after 119 s")
	assert_false(cs.in_custody(1), "entry cleared")
	assert_near(ai.health.health, ai.health.max_health, 0.001, "full health")
	assert_eq(ai.health.downs_used, 0, "downs reset")
	assert_eq(w.mag(ws) + w.reserve(ws), int(round(full * 0.5)), "50% ammo")
	assert_eq(w.deployable_count, deploy_before, "deployables not refilled")
	assert_true(ai.global_position.distance_to(_crew(0).global_position) < 3.0, "released next to the crew")


func test_l2_9_hazardous_trade_only() -> void:
	await _launch(Enums.Difficulty.HAZARDOUS, 1)
	var cs: CustodySystem = _custody()
	var ai: CrewController = _crew(1)
	ai.health.go_to_custody()
	assert_eq(cs.auto_release_left(1), -1.0, "no auto-release on Hazardous")
	cs.tick(500.0)
	assert_eq(ai.crew_state, Enums.CrewState.CUSTODY, "still in custody without a trade")
	assert_true(_results.is_empty(), "a human is free: no fail")


func test_l2_9_all_humans_in_custody_fails() -> void:
	await _launch(Enums.Difficulty.HAZARDOUS, 0)
	_crew(0).health.go_to_custody()
	await wait_seconds(CustodyTweak.data().all_custody_fail_delay_s + 0.3)
	assert_eq(_results.size(), 1, "heist ended")
	if _results.size() == 1:
		assert_false(bool(_results[0]["success"]), "failed")
		assert_eq(_results[0]["fail_reason"], &"all_custody", "fail_reason all_custody")
		assert_true(bool((_results[0]["crew"] as Array)[0]["in_custody"]), "crew row in custody")


func test_l2_9_hazardous_free_ai_keeps_heist_alive() -> void:
	await _launch(Enums.Difficulty.HAZARDOUS, 1)
	_crew(0).health.go_to_custody()
	_custody().tick(CustodyTweak.data().all_custody_fail_delay_s + 0.5)
	assert_true(_results.is_empty(), "a free AI teammate: no fail (trade still possible later)")
	_crew(1).health.go_to_custody()
	_custody().tick(CustodyTweak.data().all_custody_fail_delay_s + 0.1)
	assert_eq(_results.size(), 1, "human and AI in custody on a trade-only difficulty -> fail")


func test_l2_9_solo_ai_with_hostage_does_not_fail() -> void:
	await _launch(Enums.Difficulty.HAZARDOUS, 1, 1)
	var civ: NpcBase = _rt.npcs(&"civilian")[0] as NpcBase
	var brain: CivilianBrain = civ.get_node("Brain") as CivilianBrain
	brain.on_shouted(_crew(0))
	brain._on_tie_completed(_crew(0))
	assert_true(brain.is_tied(), "hostage tied")
	_crew(0).health.go_to_custody()
	_custody().tick(0.5)
	_custody().tick(CustodyTweak.data().all_custody_fail_delay_s + 0.1)
	assert_true(_results.is_empty(), "AI + hostage: a trade is possible, no fail")


func test_l2_9_routine_custody_with_ai_free_does_not_fail() -> void:
	await _launch(Enums.Difficulty.ROUTINE, 1)
	var human: CrewController = _crew(0)
	human.health.go_to_custody()
	_custody().tick(CustodyTweak.data().all_custody_fail_delay_s + 0.5)
	assert_true(_results.is_empty(), "Routine with the AI free: no fail")
	_custody().tick(119.0)
	assert_eq(human.crew_state, Enums.CrewState.NORMAL, "auto-released")
	assert_true(_results.is_empty(), "still running")


func test_l2_9_routine_whole_crew_in_custody_fails() -> void:
	await _launch(Enums.Difficulty.ROUTINE, 1)
	_crew(0).health.go_to_custody()
	_crew(1).health.go_to_custody()
	_custody().tick(CustodyTweak.data().all_custody_fail_delay_s + 0.1)
	assert_eq(_results.size(), 1, "every crew member in custody -> fail")
