## SL-6: Shadow Ledger objective paths (shadow_ledger.md §Objectives, §Variable table, §Rare events, §Escape): one
## test per path / branch, driven through the mission API with pinned variants or a variant table with the rare at
## chance 1. The stealth end-to-end of the alternative routes: test_sl6_e2e_paths.gd.
extends "res://tests/a/sl6_case.gd"


# --- [laptop]: 4 places, Moor's rule (§Variable table: laptop, late_partner) --------------------------------

func test_sl6_laptop_each_slot_found_and_bagged() -> void:
	for slot: StringName in [&"lap_kessler", &"lap_moor", &"lap_study", &"lap_boardroom"]:
		var partner: StringName = &"moor_late" if slot == &"lap_moor" else &"moor_gone"
		var m: HeistMission = await _launch({&"laptop": [slot], &"late_partner": [partner]})
		assert_eq(_slot(&"laptop"), [slot], "laptop pinned to %s" % slot)
		var laptops: Array[Node] = _rt.find_by_tag(&"laptop")
		assert_eq(laptops.size(), 1, "%s: one laptop on the map (the other slots are freed)" % slot)
		if laptops.size() == 1:
			assert_true(String(laptops[0].get_path()).contains("Slot_%s" % slot), "%s: it is the slot's laptop" % slot)
			assert_eq(StringName(laptops[0].get(&"loot_id")), &"loot.ledger_laptop", "loot.ledger_laptop")
			assert_true(_enabled(laptops[0]), "%s: baggable" % slot)
			assert_eq(_data(&"laptop").get("location"), [slot], "[laptop] names the location")
			_lines.clear()
			EventBus.interaction_completed.emit(_nid(laptops[0]), 0, &"bag_loot")
			assert_eq(m.objective_state(&"laptop"), DONE, "%s: [laptop] done when bagged" % slot)
			assert_eq(_count(&"vo.mercer.shadow_ledger_laptop_found"), 1, "laptop line")
		await _teardown()


func test_sl6_moor_late_puts_the_laptop_on_her_desk() -> void:
	for s: int in [1, 2, 3]:
		await _launch({&"late_partner": [&"moor_late"]}, null, Enums.Difficulty.ROUTINE, s)
		assert_eq(_slot(&"late_partner"), [&"moor_late"], "seed %d: Moor working late" % s)
		assert_eq(_slot(&"laptop"), [&"lap_moor"], "seed %d: rule 1 requires moor_late -> lap_moor" % s)
		await _teardown()


# --- [keycard] / [server_door]: srv_locked vs srv_contractor ------------------------------------------------

func test_sl6_srv_locked_needs_a_keycard_and_the_reader() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	assert_eq(m.objective_state(&"keycard"), ACTIVE, "srv_locked: find a keycard")
	assert_eq(m.objective_state(&"server_door"), ACTIVE, "server door shut")
	assert_eq(_rt.find_by_tag(&"keycard").size(), 2, "pick 2 keycards")
	var door: Node = _one(&"server_door")
	assert_true(door != null and not bool(door.get(&"is_open")), "the server door starts closed")
	_lines.clear()
	EventBus.item_picked_up.emit(&"item.keycard", 0)
	assert_eq(m.objective_state(&"keycard"), DONE, "[keycard] done on pickup")
	assert_eq(_count(&"vo.mercer.shadow_ledger_keycard_found"), 1, "keycard line")
	assert_eq(m.objective_state(&"server_door"), ACTIVE, "the door still needs the reader")
	EventBus.interaction_completed.emit(_nid(_one(&"server_reader")), 0, &"keycard")
	assert_eq(m.objective_state(&"server_door"), DONE, "[server_door] done at the reader")


## B-SL audit: on the contractor variant [keycard] / [server_door] are born COMPLETED (never published ACTIVE first),
## so ContactRadio's first sighting is silent and the Accountant's keycard / server-room lines never fire.
func test_sl6_srv_contractor_steps_complete_silently() -> void:
	var seen: Dictionary = {}
	var cb: Callable = func(oid: StringName, state: int, _d: Dictionary) -> void:
		if not seen.has(oid):
			seen[oid] = state
	EventBus.objective_updated.connect(cb)
	var m: HeistMission = await _launch({&"server_room": [&"srv_contractor"], &"code_note": [&"code_contractor"]})
	EventBus.objective_updated.disconnect(cb)
	for oid: StringName in [&"keycard", &"server_door"]:
		assert_eq(int(seen.get(oid, -1)), DONE, "[%s] first published COMPLETED, never ACTIVE" % oid)
		assert_eq(m.objective_state(oid), DONE, "[%s] done" % oid)


func test_sl6_srv_contractor_skips_keycard_and_props_the_door() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_contractor"], &"code_note": [&"code_contractor"]})
	assert_eq(m.objective_state(&"keycard"), DONE, "[keycard] skipped")
	assert_true(bool(_data(&"keycard").get("skipped", false)), "marked skipped")
	assert_eq(m.objective_state(&"server_door"), DONE, "[server_door] done: the door is propped")
	var door: Node = _one(&"server_door")
	assert_true(door != null and bool(door.get(&"is_open")), "the server door starts open")
	assert_eq(_slot(&"code_note"), [&"code_contractor"], "the code is on the contractor's laptop")
	assert_eq(_rt.find_by_tag(&"cage_code").size(), 1, "one code note")


# --- [cage]: code, saw, handheld saw, cage_left_open --------------------------------------------------------

func _cage() -> Safe:
	return _one(&"cage") as Safe


func _assert_cage_open(m: HeistMission, method: StringName) -> void:
	assert_eq(m.objective_state(&"cage"), DONE, "[cage] done (%s)" % method)
	assert_eq(StringName(_data(&"cage").get("open_method", &"")), method, "open_method %s" % method)
	var gate: Node = _one(&"cage_gate")
	assert_true(gate != null and bool(gate.get(&"is_open")), "the cage gate swung open")
	assert_true(_cage().opened, "the cage lock is open")
	var hack: Node = _one(&"hack")
	assert_true(hack != null and _enabled(hack), "the hack terminal is live")
	assert_eq(m.objective_state(&"hack"), ACTIVE, "[hack] shown")
	assert_eq(_count(&"vo.mercer.shadow_ledger_cage_open"), 1, "cage-open line once")


func test_sl6_cage_by_code() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	var cage: Safe = _cage()
	assert_eq(cage.methods, [&"code", &"saw"] as Array[StringName], "cage methods [code, saw]")
	assert_true(bool(_data(&"cage_code").get("optional", false)), "[cage_code] optional")
	assert_eq(StringName(_data(&"cage_code").get("alternative", &"")), &"saw", "its alternative is the saw")
	assert_false(_enabled(_one(&"hack")), "the hack waits for the cage")
	_lines.clear()
	EventBus.item_picked_up.emit(&"item.code_note", 0)
	assert_eq(m.objective_state(&"cage_code"), DONE, "[cage_code] done on reading the note")
	assert_eq(_count(&"vo.mercer.shadow_ledger_code_found"), 1, "code line")
	cage.call(&"_lock_beaten", &"code")  # Safe._on_completed for kind enter_code
	EventBus.interaction_completed.emit(cage.net_id, 0, &"enter_code")
	_assert_cage_open(m, &"code")
	assert_false(bool(_data(&"cage_code").get("skipped", false)), "the code was used, not skipped")


func test_sl6_cage_by_saw_waits_for_the_cut() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	var cage: Safe = _cage()
	assert_near(cage.saw_duration(), 90.0, 0.01, "the cage saw runs 90 s")
	# Placing and fixing the saw only (re)start the cut: the cage is still shut (was: opened on place_saw).
	EventBus.interaction_completed.emit(cage.net_id, 0, &"place_saw")
	EventBus.interaction_completed.emit(cage.net_id, 0, &"fix_drill")
	await wait_physics_frames(2)
	assert_eq(m.objective_state(&"cage"), ACTIVE, "placing / fixing the saw does not open the cage")
	assert_false(_enabled(_one(&"hack")), "hack still locked")
	_lines.clear()
	cage.open_by_device()  # the saw's DeviceRunner finished
	EventBus.device_finished.emit(cage.net_id)
	_assert_cage_open(m, &"saw")
	assert_eq(m.objective_state(&"cage_code"), DONE, "the code note is moot")
	assert_true(bool(_data(&"cage_code").get("skipped", false)), "[cage_code] skipped")


func test_sl6_cage_by_handheld_saw() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	var cage: Safe = _cage()
	assert_true(cage.is_in_group(G.SAW_TARGET), "the cage lock is a saw target")
	_lines.clear()
	cage.saw_cut(1000.0, 0)  # QC-37: no interaction or device fact
	var ok: bool = await wait_until(func() -> bool: return m.objective_state(&"cage") == DONE, 2.0)
	assert_true(ok, "the mission notices the cut lock")
	_assert_cage_open(m, &"saw")


func test_sl6_cage_left_open_rare() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_contractor"]}, _table_with_rare([&"cage_left_open"]))
	assert_true(_rare_on(&"cage_left_open"), "cage_left_open rolled (requires srv_contractor)")
	_assert_cage_open(m, &"left_open")
	assert_false(_enabled(_cage()), "the lock offers no code / saw")
	assert_true(bool(_data(&"cage").get("left_open", false)), "[cage] data left_open")
	assert_eq(m.objective_state(&"cage_code"), DONE, "[cage_code] skipped")


func test_sl6_cage_left_open_needs_the_contractor() -> void:
	await _launch({&"server_room": [&"srv_locked"]}, _table_with_rare([&"cage_left_open"]))
	assert_false(_rare_on(&"cage_left_open"), "no cage_left_open without srv_contractor")
	assert_eq(_rt.mission.objective_state(&"cage"), ACTIVE, "the cage is shut")


# --- [hack] -> [drives] ------------------------------------------------------------------------------------

func test_sl6_hack_start_interrupt_done_releases_drives() -> void:
	var m: HeistMission = await _launch({&"server_room": [&"srv_locked"]})
	var ht: Node = _one(&"hack")
	assert_near(float(ht.get(&"duration_s")), 45.0, 0.01, "45 s hack")
	assert_eq(ht.get(&"interruptions"), Vector2i(1, 2), "1-2 interruptions")
	for d: Node in _rt.find_by_tag(&"drives"):
		assert_false(_enabled(d), "drive sleds locked before the hack")
	_open_cage_now(m)
	_lines.clear()
	EventBus.device_started.emit(_nid(ht), &"hack", 45.0)
	assert_eq(_count(&"vo.mercer.shadow_ledger_hack_started"), 1, "hack started line")
	assert_eq(int(_line_ctx(&"vo.mercer.shadow_ledger_hack_started").get("seconds", 0)), 45, "with the seconds")
	EventBus.device_jammed.emit(_nid(ht))
	assert_eq(_count(&"vo.mercer.shadow_ledger_hack_interrupted"), 1, "interrupted line")
	assert_eq(m.objective_state(&"hack"), ACTIVE, "an interruption is not the end")
	EventBus.device_finished.emit(_nid(ht))
	assert_eq(m.objective_state(&"hack"), DONE, "[hack] done")
	assert_eq(_count(&"vo.mercer.shadow_ledger_hack_done"), 1, "hack done line")
	assert_eq(m.objective_state(&"drives"), ACTIVE, "[drives] shown")
	var sleds: Array[Node] = _rt.find_by_tag(&"drives")
	assert_eq(sleds.size(), 3, "3 drive sleds")
	for d: Node in sleds:
		assert_true(_enabled(d), "drive sled baggable")
		assert_eq(StringName(d.get(&"loot_id")), &"loot.ledger_drives", "loot.ledger_drives")


func _open_cage_now(m: HeistMission) -> void:
	_cage().open_by_device()
	EventBus.device_finished.emit(_cage().net_id)
	assert_eq(m.objective_state(&"cage"), DONE, "cage open")


# --- [secure] -> [escape]: heli (45 s), line, service lift -------------------------------------------------

func test_sl6_secure_laptop_and_two_drives_opens_each_escape() -> void:
	var keys: Dictionary = {
		&"esc_heli": [&"escape_heli", &"ui.escape.heli", 45.0],
		&"esc_line": [&"escape_line", &"ui.escape.line", 0.0],
		&"esc_service": [&"escape_service", &"ui.escape.lift", 0.0],
	}
	for slot: StringName in keys:
		var m: HeistMission = await _launch({&"escape": [slot]})
		var tag: StringName = keys[slot][0]
		assert_eq(_slot(&"escape"), [slot], "escape pinned %s" % slot)
		for other: StringName in [&"escape_heli", &"escape_line", &"escape_service"]:
			assert_eq(_rt.find_by_tag(other).size(), 1 if other == tag else 0, "%s: only the active escape exists (%s)"
				% [slot, other])
		assert_eq(_rt.find_by_tag(&"loot_secure").size(), 1, "%s: one secure zone" % slot)
		assert_eq(m.objective_state(&"escape"), Enums.ObjectiveState.HIDDEN, "escape hidden")
		_lines.clear()
		EventBus.loot_secured.emit(92001, &"loot.ledger_drives", 1000)
		EventBus.loot_secured.emit(92002, &"loot.ledger_drives", 1000)
		EventBus.loot_secured.emit(92003, &"loot.ledger_books", 1000)
		assert_eq(m.objective_state(&"secure"), ACTIVE, "%s: drives without the laptop are not enough" % slot)
		EventBus.loot_secured.emit(92004, &"loot.ledger_laptop", 1000)
		assert_eq(m.objective_state(&"secure"), DONE, "%s: laptop + 2 drives: [secure] done" % slot)
		assert_eq(_data(&"secure").get("drives_secured"), 2, "HUD drives count")
		assert_eq(m.objective_state(&"escape"), ACTIVE, "%s: [escape] shown" % slot)
		assert_eq(_count(&"vo.mercer.shadow_ledger_required_secured"), 1, "required-loot line")
		assert_eq(_line_ctx(&"vo.mercer.shadow_ledger_escape").get("escape"), keys[slot][1], "escape line names it")
		assert_eq(_rt.phase, Enums.HeistPhase.ESCAPE, "ESCAPE phase")
		var zone: EscapeZone = _one(tag) as EscapeZone
		assert_true(zone != null and zone.active, "%s: the zone is active" % slot)
		if zone != null:
			assert_near(zone.arrival_delay_s, float(keys[slot][2]), 0.01, "%s arrival delay" % slot)
			assert_eq(zone.has_arrived(), float(keys[slot][2]) == 0.0, "%s: usable at once unless the heli" % slot)
		await _teardown()


# --- Optional: study safe (keycard + time lock), paintings, archive safe ------------------------------------

func test_sl6_study_safe_keycard_time_lock_books() -> void:
	var m: HeistMission = await _launch()
	var safe: Safe = _one(&"study_safe") as Safe
	var lock_s: float = float(_rt.variants.get(&"time_lock_s", 90.0))
	assert_true(lock_s == 90.0 or lock_s == 120.0, "time_lock_s 90 / 120")
	assert_near(safe.time_lock_s, lock_s, 0.01, "the safe's time lock is the scalar")
	assert_near(float(_data(&"study_safe").get("time_lock_s", 0.0)), lock_s, 0.01, "HUD data")
	assert_true(safe.methods.has(&"keycard"), "KEYCARD method")
	assert_eq(m.objective_state(&"study_safe"), ACTIVE, "[study_safe] optional, active")
	safe.open_by_keycard()
	assert_eq(safe.stage, Safe.Stage.TIME_LOCK, "the swipe arms the time lock")
	assert_false(safe.opened, "not open yet")
	_lines.clear()
	EventBus.device_started.emit(safe.net_id, &"time_lock", lock_s)
	assert_eq(_count(&"vo.mercer.shadow_ledger_time_lock_started"), 1, "time lock started line")
	EventBus.device_finished.emit(safe.net_id)
	assert_eq(m.objective_state(&"study_safe"), DONE, "[study_safe] done when the lock runs out")
	assert_eq(_count(&"vo.mercer.shadow_ledger_time_lock_open"), 1, "time lock open line")
	EventBus.device_finished.emit(safe.net_id)
	assert_eq(_count(&"vo.mercer.shadow_ledger_time_lock_open"), 1, "once")
	var books: int = 0
	for c: Node in safe.get_children():
		if c is LootSpawn and (c as LootSpawn).loot_id == &"loot.ledger_books":
			books += 1
	assert_eq(books, 1, "1 bag of ledger_books in the study safe")


func test_sl6_timelock_extended_adds_60s_brutal_only() -> void:
	await _launch({}, _table_with_rare([&"timelock_extended"]), Enums.Difficulty.BRUTAL)
	assert_true(_rare_on(&"timelock_extended"), "timelock_extended on Brutal")
	var lock_s: float = float(_rt.variants.get(&"time_lock_s", 90.0))
	assert_near((_one(&"study_safe") as Safe).time_lock_s, lock_s + 60.0, 0.01, "+60 s")
	await _teardown()
	await _launch({}, _table_with_rare([&"timelock_extended"]), Enums.Difficulty.HAZARDOUS)
	assert_false(_rare_on(&"timelock_extended"), "not below Brutal (min_difficulty)")
	assert_near((_one(&"study_safe") as Safe).time_lock_s, float(_rt.variants.get(&"time_lock_s", 90.0)), 0.01,
		"no extension")


func test_sl6_paintings_both_taken() -> void:
	var m: HeistMission = await _launch()
	var paintings: Array[Node] = _rt.find_by_tag(&"paintings")
	assert_eq(paintings.size(), 2, "2 paintings")
	paintings[0].set(&"remaining", 0)
	EventBus.interaction_completed.emit(_nid(paintings[0]), 0, &"bag_loot")
	assert_eq(m.objective_state(&"paintings"), ACTIVE, "one left")
	paintings[1].set(&"remaining", 0)
	EventBus.interaction_completed.emit(_nid(paintings[1]), 0, &"bag_loot")
	assert_eq(m.objective_state(&"paintings"), DONE, "[paintings] done")


func test_sl6_archive_safe_by_saw() -> void:
	var m: HeistMission = await _launch()
	var safe: Safe = _one(&"archive_safe") as Safe
	assert_eq(safe.methods, [&"saw"] as Array[StringName], "archive safe: saw only")
	EventBus.interaction_completed.emit(safe.net_id, 0, &"place_saw")
	assert_eq(m.objective_state(&"archive_safe"), ACTIVE, "placing the saw is not the open")
	safe.open_by_device()
	EventBus.device_finished.emit(safe.net_id)
	assert_eq(m.objective_state(&"archive_safe"), DONE, "[archive_safe] done")


func test_sl6_archive_safe_by_handheld_saw() -> void:
	var m: HeistMission = await _launch()
	(_one(&"archive_safe") as Safe).saw_cut(1000.0, 0)
	var ok: bool = await wait_until(func() -> bool: return m.objective_state(&"archive_safe") == DONE, 2.0)
	assert_true(ok, "[archive_safe] done after the handheld saw")


# --- Rare events -------------------------------------------------------------------------------------------

func test_sl6_ledger_printout_only_with_the_rare() -> void:
	await _launch({}, _table_with_rare([]))
	var p: LootSpawn = _one(&"printout") as LootSpawn
	assert_true(p != null, "the printout spawn is on the map")
	assert_false(p.visible or p.interactable.enabled, "no printout: hidden and disabled")
	assert_eq(p.remaining, 0, "and not counted as loot on offer")
	await _teardown()
	await _launch({}, _table_with_rare([&"ledger_printout"]))
	p = _one(&"printout") as LootSpawn
	assert_true(_rare_on(&"ledger_printout"), "ledger_printout rolled")
	assert_true(p.visible and p.interactable.enabled, "the K1 printout is baggable")
	assert_eq(p.loot_id, &"loot.ledger_books", "+1 ledger_books")
	assert_eq(p.remaining, 1, "one bag")


func test_sl6_kessler_sleepover_puts_kessler_in_m5() -> void:
	await _launch({}, _table_with_rare([&"kessler_sleepover"]))
	assert_true(_rare_on(&"kessler_sleepover"), "kessler_sleepover rolled")
	assert_eq(_slot(&"kessler"), [&"kessler_in"], "kessler slot pinned")
	var found: bool = false
	for c: Node in _rt.npcs(&"civilian"):
		var tags: Variant = (c as NpcBase).spawn_info.get("tags", [])
		if tags is Array and (tags as Array).has(&"civ_kessler"):
			found = true
	assert_true(found, "Victor Kessler spawned (civ_kessler)")
