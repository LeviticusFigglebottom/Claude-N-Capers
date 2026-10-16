## SL-6: Shadow Ledger loud rules (shadow_ledger.md §Modes, §Loud): alarm -> Mercer's SL abort line (once, not the
## generic one) -> heist_ended(fail, stealth_only_alarm) after 5 s; no assault, nothing spawns, guards COMBAT,
## civilians panic; the mission stays quiet and opens no escape in the abort window, and an escape inside it is
## not a win.
extends "res://tests/a/sl6_case.gd"


# --- Loud: alarm = fail (§Modes, §Loud) ------------------------------------------------------------------

func test_sl6_alarm_aborts_with_sl_line_and_fails_without_assault() -> void:
	var m: HeistMission = await _launch()
	var director: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var npcs_before: int = _rt.npcs().size()
	assert_eq(_rt.heist_mode, Enums.HeistMode.STEALTH_ONLY, "HeistDef.mode STEALTH_ONLY (S11.3)")
	assert_true(m.own_abort_line, "SL says its own abort line")
	_lines.clear()
	_rt.stealth.raise_alarm(&"camera", 0)
	await wait_physics_frames(3)
	assert_eq(_count(ABORT_SL), 1, "Mercer: \"They're wiping the array. It's over.\"")
	assert_eq(_count(ABORT_GENERIC), 0, "the generic abort line is not said on top of it")
	assert_near(_rt.stealth_abort_left, Tweak.stealth().stealth_only_abort_s - 3.0 / 60.0, 0.1, "5 s abort window")
	for g: Node in _rt.npcs(&"guard"):
		assert_eq((g as NpcBase).alert_state, Enums.AlertState.COMBAT, "guards switch to COMBAT (%s)" % g.name)
	await wait_seconds(1.0)
	for c: Node in _rt.npcs(&"civilian"):
		assert_true((c as NpcBase).alert_state != Enums.AlertState.CALM, "civilians panic (%s)" % c.name)
	var ok: bool = await wait_until(func() -> bool: return not _ended.is_empty(), 6.0)
	assert_true(ok, "heist_ended within the abort window")
	if ok:
		assert_false(bool(_ended[0]["success"]), "failed")
		assert_eq(StringName(_ended[0]["fail_reason"]), HeistRuntime.FAIL_STEALTH_ONLY_ALARM, "fail_reason")
		assert_false(bool(_ended[0]["stealth"]), "not a stealth result")
	# Nothing continues: no assault, no police, no spawns, ever.
	await wait_seconds(2.0)
	assert_eq(_ended.size(), 1, "heist_ended once")
	assert_eq(_rt.phase, Enums.HeistPhase.ENDED, "phase ENDED")
	assert_false(director.running, "the assault director never ran")
	assert_eq(director.assault_phase, Enums.AssaultPhase.NONE, "no assault phase")
	assert_eq(_rt.npcs(&"police").size() + _rt.npcs(&"special").size(), 0, "no police, no specials")
	assert_true(_rt.npcs().size() <= npcs_before, "nothing spawned (%d -> %d)" % [npcs_before, _rt.npcs().size()])


func test_sl6_mission_silent_and_no_escape_after_alarm() -> void:
	var m: HeistMission = await _launch()
	m.call(&"_on_hack_done")
	_rt.stealth.raise_alarm(&"guard_radio", 0)
	await wait_physics_frames(1)
	_lines.clear()
	# Progress facts inside the abort window: no Mercer progress lines, no escape.
	EventBus.item_picked_up.emit(&"item.keycard", 0)
	EventBus.loot_secured.emit(91001, &"loot.ledger_laptop", 1000)
	EventBus.loot_secured.emit(91002, &"loot.ledger_drives", 1000)
	EventBus.loot_secured.emit(91003, &"loot.ledger_drives", 1000)
	m.call(&"_on_camera_meter", 0.9)
	assert_eq(_lines.filter(func(l: Array) -> bool: return l[0] == &"mercer").size(), 0,
		"Mercer stays quiet after the abort line (%s)" % [_lines])
	assert_eq(m.objective_state(&"secure"), ACTIVE, "[secure] does not complete in the abort window")
	assert_false(bool(m.get(&"_escape_open")), "no escape opens")
	for tag: StringName in [&"escape_heli", &"escape_line", &"escape_service"]:
		for z: Node in _rt.find_by_tag(tag):
			assert_false(bool(z.get(&"active")), "%s stays inactive" % tag)
	# An escape zone (or anything) ending the heist as a win inside the window is still the alarm fail.
	var r: Dictionary = _rt.end_heist(true, [0])
	assert_false(bool(r.get("success", true)), "no win after the alarm")
	assert_eq(StringName(r.get("fail_reason", &"")), HeistRuntime.FAIL_STEALTH_ONLY_ALARM, "the alarm fail reason")


func test_sl6_alarm_while_casing_is_not_the_casing_step() -> void:
	var m: HeistMission = await _launch()
	assert_eq(_rt.phase, Enums.HeistPhase.CASING, "the crew starts unmasked (casing)")
	_rt.stealth.raise_alarm(&"civilian_phone", 0)
	await wait_physics_frames(2)
	assert_ne(m.objective_state(&"casing"), DONE, "an alarm does not complete [casing]")


func test_sl6_casing_completes_on_mask_up() -> void:
	var m: HeistMission = await _launch()
	assert_eq(m.objective_state(&"casing"), ACTIVE, "[casing] optional, active")
	assert_true(bool(_data(&"casing").get("optional", false)), "optional")
	(_rt.crew_controller(0) as CrewController).set_masked()
	await wait_physics_frames(2)
	assert_eq(_rt.phase, Enums.HeistPhase.STEALTH, "masked: STEALTH")
	assert_eq(m.objective_state(&"casing"), DONE, "[casing] done when the casing ends")
