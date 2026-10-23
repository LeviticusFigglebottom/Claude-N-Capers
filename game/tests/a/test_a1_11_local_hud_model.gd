## A1-11: LocalHudModel (ui_hud.md v1.1 exact binding shape, D-024).
extends TestCase

## ui_hud.md v1.1..v1.5: signal -> properties.
const BINDING: Dictionary = {
	&"vitals_changed": [&"health", &"max_health", &"armor", &"max_armor", &"downs_left", &"crew_state", &"bleedout_s"],
	&"ammo_changed": [&"ammo", &"equipped_slot"],
	&"inventory_changed": [&"deployable_id", &"throwable_id", &"deployable_count", &"throwable_count", &"cable_ties", &"body_bags"],
	&"carried_bag_changed": [&"carried_bag"],
	&"interaction_changed": [&"interaction"],
	&"detection_changed": [&"detection"],
	&"marked_targets_changed": [&"marked_targets"],
	&"pagers_changed": [&"pagers", &"pagers_answered", &"pagers_max"],
	&"timers_changed": [&"ecm_time_left_s", &"camera_alarm_s"],
	&"objectives_changed": [&"objectives"],
	&"assault_changed": [&"assault_phase", &"assault_wave"],
	&"hostages_changed": [&"hostages"],
	&"warnings_changed": [&"warnings"],
	&"crew_changed": [&"crew"],
	&"masked_changed": [&"masked", &"casing"],
	&"custody_changed": [&"custody"],
	&"captain_changed": [&"captain_resistance", &"captain_present"],
	&"stamina_changed": [&"stamina", &"exhausted"],
	&"weapon_charge_changed": [&"weapon_charge"],
	&"weapon_spin_changed": [&"weapon_spin"],
	&"player_mode_changed": [&"player_mode"],
	&"pocket_ecm_changed": [&"pocket_ecm"],  # v1.20 (D-161)
}


func _launch(seed_value: int) -> HeistRuntime:
	return await HeistLauncher.launch(&"unit_map", seed_value, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0)})


func _counter(obj: Object, sig: StringName) -> Array[int]:
	var hits: Array[int] = [0]
	obj.connect(sig, func() -> void: hits[0] += 1)
	return hits


func test_binding_shape_and_group() -> void:
	var rt: HeistRuntime = await _launch(1101)
	var hud: LocalHudModel = rt.hud_model
	assert_true(hud != null and hud.get_parent() == rt, "hud model under runtime")
	var in_group: Array[Node] = get_tree().get_nodes_in_group(G.LOCAL_HUD_MODEL)
	assert_eq(in_group.size(), 1, "exactly one LOCAL_HUD_MODEL")
	assert_true(in_group[0] == hud, "group member is the runtime's model")
	hud.refresh()
	var snap: Dictionary = hud.snapshot()
	for sig: StringName in BINDING:
		assert_true(hud.has_signal(sig), "signal %s" % sig)
		for p: StringName in BINDING[sig]:
			assert_has(snap, p)
			assert_true(hud.get(p) != null, "get(%s)" % p)
	assert_near(hud.health, 230.0, 0.001, "default health from Tweak")
	assert_near(hud.max_armor, 20.0, 0.001, "default armor from Tweak")
	assert_eq(hud.downs_left, 3, "default downs")
	assert_true(hud.bleedout_s < 0.0, "not bleeding out")
	assert_eq(hud.carried_bag, {}, "no bag")
	assert_true(hud.ammo.has(Enums.WeaponSlot.PRIMARY) and (hud.ammo[Enums.WeaponSlot.PRIMARY] as Dictionary).has("mag"), "ammo shape")
	assert_true(hud.ecm_time_left_s < 0.0 and hud.camera_alarm_s < 0.0, "timers inactive")
	assert_eq(hud.pagers_max, Tweak.stealth().pager_max_answers)
	assert_true(hud.casing and not hud.masked, "starts in casing")
	rt.teardown()
	await wait_frames(1)


func test_masking_flips_masked_and_casing() -> void:
	var rt: HeistRuntime = await _launch(1102)
	var hud: LocalHudModel = rt.hud_model
	hud.refresh()
	var hits: Array[int] = _counter(hud, &"masked_changed")
	var before: Array[Dictionary] = hud.crew
	(rt.crew_controller(0) as CrewController).set_masked(false)
	hud.refresh()
	assert_true(hud.masked, "masked")
	assert_false(hud.casing, "not casing")
	assert_eq(hits[0], 1, "masked_changed once for masked + casing")
	hud.refresh()
	assert_eq(hits[0], 1, "no re-emit without change")
	assert_true(is_same(before, hud.crew), "unchanged crew array is not reassigned")
	rt.teardown()
	await wait_frames(1)


func test_assault_and_hostages_events() -> void:
	var rt: HeistRuntime = await _launch(1103)
	var hud: LocalHudModel = rt.hud_model
	var hits: Array[int] = _counter(hud, &"assault_changed")
	var hh: Array[int] = _counter(hud, &"hostages_changed")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.BUILD, 2)
	assert_eq(hud.assault_phase, Enums.AssaultPhase.BUILD)
	assert_eq(hud.assault_wave, 2)
	assert_eq(hits[0], 1, "assault_changed once")
	EventBus.hostage_count_changed.emit(4)
	assert_eq(hud.hostages, 4)
	assert_eq(hh[0], 1)
	rt.teardown()
	await wait_frames(1)


func test_objectives_show_up() -> void:
	var rt: HeistRuntime = await _launch(1104)
	var hud: LocalHudModel = rt.hud_model
	assert_true(rt.mission != null, "mission bound")
	hud.refresh()
	var old: Array[Dictionary] = hud.objectives
	var hits: Array[int] = _counter(hud, &"objectives_changed")
	rt.mission.add_objective(&"x", &"obj.x", Enums.ObjectiveState.ACTIVE, {"count": 1})
	var found: Dictionary = {}
	for o: Dictionary in hud.objectives:
		if o["id"] == &"x":
			found = o
	assert_eq(found.get("text_key"), &"obj.x")
	assert_eq(found.get("args"), {"count": 1})
	assert_eq(found.get("state"), Enums.ObjectiveState.ACTIVE)
	assert_eq(found.get("device_net_id"), -1, "PO6-03 (ui_hud v1.9): no device serves it")
	assert_eq(found.keys().size(), 5, "exactly id, text_key, args, state, device_net_id")
	assert_true(hits[0] >= 1, "objectives_changed emitted")
	assert_false(is_same(old, hud.objectives), "new array assigned")
	rt.teardown()
	await wait_frames(1)


func test_crew_is_teammates_only() -> void:
	var rt: HeistRuntime = await _launch(1105)
	var hud: LocalHudModel = rt.hud_model
	hud.refresh()
	assert_eq(hud.crew.size(), 3, "3 teammates")
	var slots: Array[int] = []
	for t: Dictionary in hud.crew:
		for k: String in ["slot", "name", "is_ai", "health_frac", "armor_frac", "state", "downs_left", "carried_loot_id"]:
			assert_has(t, k)
		assert_true(bool(t["is_ai"]), "teammate is AI")
		slots.append(int(t["slot"]))
	assert_eq(slots, [1, 2, 3] as Array[int])
	rt.teardown()
	await wait_frames(1)


func test_pager_events_populate_pagers() -> void:
	var rt: HeistRuntime = await _launch(1106)
	var hud: LocalHudModel = rt.hud_model
	var svc: Node = rt.service(G.SVC_PAGERS)
	if svc != null and svc.has_method(&"pager_entries"):
		skip("PagerSystem present: pagers come from pager_entries()")
		rt.teardown()
		await wait_frames(1)
		return
	var guard_id: int = NetIds.of(rt.npcs(&"guard")[0])
	var hits: Array[int] = _counter(hud, &"pagers_changed")
	EventBus.pager_started.emit(7, guard_id)
	assert_eq(hud.pagers.size(), 1, "one pager")
	var p: Dictionary = hud.pagers[0]
	assert_eq(p.keys().size(), 4, "pager_id, time_left_s, answering, progress")
	assert_eq(p["pager_id"], 7)
	assert_false(bool(p["answering"]))
	assert_near(float(p["time_left_s"]), Tweak.stealth().pager_window_s, 0.2)
	EventBus.pager_answer_started.emit(7, 0)
	assert_true(bool(hud.pagers[0]["answering"]), "answering")
	EventBus.pager_answered.emit(7, 0, 1)
	assert_eq(hud.pagers.size(), 0, "answered pager removed")
	assert_eq(hud.pagers_answered, 1)
	EventBus.pager_started.emit(8, guard_id)
	EventBus.pager_failed.emit(8, &"timeout")
	assert_eq(hud.pagers.size(), 0, "failed pager removed")
	assert_true(hits[0] >= 4, "pagers_changed emitted")
	rt.teardown()
	await wait_frames(1)


func test_detection_and_timers() -> void:
	var rt: HeistRuntime = await _launch(1107)
	var hud: LocalHudModel = rt.hud_model
	var guard_id: int = NetIds.of(rt.npcs(&"guard")[0])
	var st: Node = rt.service(G.SVC_STEALTH)
	if st != null and st.has_method(&"detection_entries"):
		# Host: rows come from the stealth director, filtered to the tracked slot and value > 0, plus (ui_hud
		# v1.17, D-128) value-0 rows of CURIOUS / INVESTIGATING observers.
		hud.refresh()
		var expected: int = 0
		for e: Dictionary in st.call(&"detection_entries", 0):
			if float(e["value"]) > 0.0 or StringName(e.get("state", &"")) != &"":
				expected += 1
		assert_eq(hud.detection.size(), expected, "director rows for slot 0")
	else:
		EventBus.detection_progress.emit(guard_id, 1, 0.5, Enums.ObserverKind.GUARD)
		assert_eq(hud.detection.size(), 0, "other slot ignored")
		EventBus.detection_progress.emit(guard_id, 0, 0.4, Enums.ObserverKind.GUARD)
		assert_eq(hud.detection.size(), 1, "local slot shown")
		assert_near(float(hud.detection[0]["value"]), 0.4, 0.001)
	for row: Dictionary in hud.detection:
		for k: String in ["observer_net_id", "world_pos", "value", "kind"]:
			assert_has(row, k)
	var th: Array[int] = _counter(hud, &"timers_changed")
	EventBus.ecm_started.emit(55, 20.0)
	assert_near(hud.ecm_time_left_s, 20.0, 0.2)
	EventBus.ecm_ended.emit(55)
	assert_true(hud.ecm_time_left_s < 0.0, "ECM inactive")
	assert_eq(th[0], 2)
	rt.teardown()
	await wait_frames(1)


## ui_hud v1.2 (D-043): custody of the tracked crew member from the CustodySystem service.
func test_v1_2_custody_from_custody_system() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 1111, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	var hud: LocalHudModel = rt.hud_model
	var ai: CrewController = rt.crew_controller(1) as CrewController
	var by_node: Node = ai
	hud.track(by_node)
	assert_true(hud.tracked_crew == ai, "track(crew: Node) sets tracked_crew")
	assert_eq(hud.custody, {}, "not in custody")
	var hits: Array[int] = _counter(hud, &"custody_changed")
	ai.health.go_to_custody()
	hud.refresh()
	assert_eq(hits[0], 1, "custody_changed once")
	var c: Dictionary = hud.custody
	assert_eq(c.get("in_custody"), true)
	assert_near(float(c.get("auto_release_left_s", 0.0)), 119.0, 0.01, "auto release timer")
	assert_near(float(c.get("negotiation_left_s", -1.0)), CustodySystem.of(rt).trade_time_for(1), 0.01, "negotiation")
	assert_true(c.has("highlighted_hostage_net_id"), "highlight key")
	assert_eq(c.keys().size(), 4, "exact v1.2 keys")
	hud.refresh()
	assert_eq(hits[0], 1, "no re-emit without change")
	assert_true(is_same(c, hud.custody), "unchanged dict is not reassigned")
	CustodySystem.of(rt).tick(5.0)
	hud.refresh()
	assert_eq(hits[0], 2, "timer change emits")
	assert_false(is_same(c, hud.custody), "new dict assigned")
	assert_near(float(hud.custody["auto_release_left_s"]), 114.0, 0.01)
	CustodySystem.of(rt).tick(200.0)
	hud.refresh()
	assert_eq(hud.custody, {}, "released -> {}")
	hud.track(null)
	assert_true(hud.tracked_crew == null, "track(null) back to slot mode")
	rt.teardown()
	await wait_frames(1)


func test_v1_16_scope_fields_are_writer_owned() -> void:
	var rt: HeistRuntime = await _launch(1116)
	var hud: LocalHudModel = rt.hud_model
	assert_eq(hud.get(&"scoped_ads"), false, "scoped_ads defaults false")
	assert_eq(hud.get(&"scope_ring"), Rect2(), "scope_ring defaults empty")
	var ring: Rect2 = Rect2(400.0, 120.0, 480.0, 480.0)
	hud.set(&"scoped_ads", true)  # ENV P's scope overlay writes them every frame
	hud.set(&"scope_ring", ring)
	hud.refresh()
	await wait_physics_frames(3)
	assert_eq(hud.get(&"scoped_ads"), true, "a poll never overwrites scoped_ads")
	assert_eq(hud.get(&"scope_ring"), ring, "nor scope_ring")
	rt.teardown()
	await wait_frames(1)
