## A1-11: LocalHudModel (ui_hud.md property list, change signals, event sources).
extends TestCase

const UI_HUD_KEYS: Array[StringName] = [
	&"health", &"max_health", &"armor", &"max_armor", &"downs_left", &"crew_state", &"bleedout_time_left",
	&"ammo_mag", &"ammo_reserve", &"equipped_slot", &"deployable_count", &"throwable_count",
	&"cable_ties", &"body_bags", &"carried_bag_loot_id", &"carried_bag_weight",
	&"interaction_prompt_key", &"interaction_progress", &"interaction_blocked_reason",
	&"suspicious_action_blocked", &"suspicious_action_prompt_key",
	&"detection_indicators", &"marked_targets", &"pager_timers", &"ecm_time_left", &"camera_countdown",
	&"objectives", &"assault_phase", &"assault_wave", &"hostages", &"phantom_warning", &"stinger_warning",
	&"teammates", &"masked", &"casing", &"mask_progress", &"heist_phase",
]


func _launch(seed_value: int) -> HeistRuntime:
	return await HeistLauncher.launch(&"unit_map", seed_value, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0)})


func test_snapshot_has_every_property() -> void:
	var rt: HeistRuntime = await _launch(1101)
	var hud: LocalHudModel = rt.hud_model
	assert_true(hud != null and hud.get_parent() == rt, "hud model under runtime")
	hud.refresh()
	var snap: Dictionary = hud.snapshot()
	for k: StringName in UI_HUD_KEYS:
		assert_has(snap, k)
	assert_eq(hud.tracked_slot_resolved, 0, "tracks local slot")
	assert_near(hud.health, 230.0, 0.001, "default health from Tweak")
	assert_near(hud.max_armor, 20.0, 0.001, "default armor from Tweak")
	assert_eq(hud.downs_left, 3, "default downs")
	assert_eq(hud.carried_bag_weight, -1, "no bag")
	assert_eq(hud.heist_phase, Enums.HeistPhase.CASING)
	assert_true(hud.casing and not hud.masked, "starts in casing")
	rt.teardown()
	await wait_frames(1)


func test_masking_flips_masked_and_casing() -> void:
	var rt: HeistRuntime = await _launch(1102)
	var hud: LocalHudModel = rt.hud_model
	hud.refresh()
	var seen: Array[StringName] = []
	var cb: Callable = func(p: StringName) -> void: seen.append(p)
	hud.changed.connect(cb)
	(rt.crew_controller(0) as CrewController).set_masked(false)
	hud.refresh()
	assert_true(hud.masked, "masked")
	assert_false(hud.casing, "not casing")
	assert_has(seen, &"masked")
	assert_has(seen, &"casing")
	seen.clear()
	hud.refresh()
	assert_false(seen.has(&"masked"), "no re-emit without change")
	hud.changed.disconnect(cb)
	rt.teardown()
	await wait_frames(1)


func test_assault_phase_event() -> void:
	var rt: HeistRuntime = await _launch(1103)
	var hud: LocalHudModel = rt.hud_model
	var got: Array[int] = []
	var cb: Callable = func(p: int, w: int) -> void: got.append_array([p, w])
	hud.assault_changed.connect(cb)
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.BUILD, 2)
	assert_eq(hud.assault_phase, Enums.AssaultPhase.BUILD)
	assert_eq(hud.assault_wave, 2)
	assert_eq(got, [Enums.AssaultPhase.BUILD, 2] as Array[int])
	EventBus.hostage_count_changed.emit(4)
	assert_eq(hud.hostages, 4)
	hud.assault_changed.disconnect(cb)
	rt.teardown()
	await wait_frames(1)


func test_objectives_show_up() -> void:
	var rt: HeistRuntime = await _launch(1104)
	var hud: LocalHudModel = rt.hud_model
	assert_true(rt.mission != null, "mission bound")
	hud.refresh()
	var fired: Array[bool] = []
	var cb: Callable = func() -> void: fired.append(true)
	hud.objectives_changed.connect(cb)
	rt.mission.add_objective(&"x", &"obj.x")
	var found: bool = false
	for o: Dictionary in hud.objectives:
		if o["id"] == &"x" and o["text_key"] == &"obj.x":
			found = true
	assert_true(found, "objective x listed")
	assert_true(not fired.is_empty(), "objectives_changed emitted")
	hud.objectives_changed.disconnect(cb)
	rt.teardown()
	await wait_frames(1)


func test_teammates_solo_plus_three_ai() -> void:
	var rt: HeistRuntime = await _launch(1105)
	var hud: LocalHudModel = rt.hud_model
	hud.refresh()
	assert_eq(hud.teammates.size(), 3, "3 teammates")
	var slots: Array[int] = []
	for t: Dictionary in hud.teammates:
		for k: String in ["slot", "name", "health_frac", "armor_frac", "state", "downs_left", "carried_bag_loot_id", "is_ai"]:
			assert_has(t, k)
		assert_true(bool(t["is_ai"]), "teammate is AI")
		slots.append(int(t["slot"]))
	assert_eq(slots, [1, 2, 3] as Array[int])
	rt.teardown()
	await wait_frames(1)


func test_pager_events_populate_timers() -> void:
	var rt: HeistRuntime = await _launch(1106)
	var hud: LocalHudModel = rt.hud_model
	var guard_id: int = NetIds.of(rt.npcs(&"guard")[0])
	EventBus.pager_started.emit(7, guard_id)
	assert_eq(hud.pager_timers.size(), 1, "one pager")
	var p: Dictionary = hud.pager_timers[0]
	assert_eq(p["pager_id"], 7)
	assert_eq(p["guard_net_id"], guard_id)
	assert_false(bool(p["answering"]))
	assert_near(float(p["time_left"]), hud.pager_window_s, 0.2)
	assert_true(p.has("world_pos"), "world_pos")
	EventBus.pager_answer_started.emit(7, 0)
	assert_true(bool(hud.pager_timers[0]["answering"]), "answering")
	EventBus.pager_answered.emit(7, 0, 1)
	assert_eq(hud.pager_timers.size(), 0, "answered pager removed")
	EventBus.pager_started.emit(8, guard_id)
	EventBus.pager_failed.emit(8, &"timeout")
	assert_eq(hud.pager_timers.size(), 0, "failed pager removed")
	rt.teardown()
	await wait_frames(1)


func test_detection_filters_tracked_slot() -> void:
	var rt: HeistRuntime = await _launch(1107)
	var hud: LocalHudModel = rt.hud_model
	var guard_id: int = NetIds.of(rt.npcs(&"guard")[0])
	EventBus.detection_progress.emit(guard_id, 1, 0.5, Enums.ObserverKind.GUARD)
	assert_eq(hud.detection_indicators.size(), 0, "other slot ignored")
	EventBus.detection_progress.emit(guard_id, 0, 0.4, Enums.ObserverKind.GUARD)
	assert_eq(hud.detection_indicators.size(), 1, "local slot shown")
	assert_near(float(hud.detection_indicators[0]["value"]), 0.4, 0.001)
	EventBus.detection_progress.emit(guard_id, 0, 0.0, Enums.ObserverKind.GUARD)
	assert_eq(hud.detection_indicators.size(), 0, "cleared at zero")
	EventBus.ecm_started.emit(55, 20.0)
	assert_near(hud.ecm_time_left, 20.0, 0.2)
	EventBus.ecm_ended.emit(55)
	assert_near(hud.ecm_time_left, 0.0, 0.001)
	rt.teardown()
	await wait_frames(1)
