## OF-A6: the Ostrander Federal mission's stealth line on ENV C's G1 map: every objective of the HeistDef with resolving
## marker_tags (ui_hud 1.8), the keycard -> code -> gate -> time lock -> vault flow (Night Deposit pattern, D-136.1), the
## rack hack starting the time lock, [code_hint] revealing the code PC (QC-63), [secure] counts (6 / 4 on Routine; cash,
## gold, bonds count, drives and tools never) and the stealth escapes (van at once, heli after its 45 s). SKIPs "pending
## C G1" without the map.
extends "res://tests/a/of_mission_case.gd"

const OBJECTIVES: Array[StringName] = [&"casing", &"keycard", &"code_hint", &"code_pc", &"server", &"vault_gate", &"lasers",
	&"time_lock", &"time_lock_wait", &"vault_loot", &"gold_cage", &"secure", &"deposit_boxes", &"bond_safe",
	&"president_safe", &"server_drives", &"drill_delivery", &"vault_drill", &"vault_breach", &"escape_wait", &"escape"]
const STARTS_HIDDEN: Array[StringName] = [&"time_lock", &"time_lock_wait", &"vault_loot", &"gold_cage", &"drill_delivery",
	&"vault_drill", &"vault_breach", &"escape_wait", &"escape"]


func test_of_every_objective_has_resolving_marker_tags() -> void:
	if _pending() or not await _launch():
		return
	var ids: Array[StringName] = []
	for o: Dictionary in _m().objectives():
		var id: StringName = StringName(o["id"])
		ids.append(id)
		var tags: Array = (o.get("data", {}) as Dictionary).get("marker_tags", [])
		assert_true(not tags.is_empty(), "%s carries marker_tags (ui_hud 1.8)" % id)
		var found: bool = false
		for t: Variant in tags:
			found = found or not _rt.find_by_tag(StringName(t)).is_empty()
		assert_true(found, "%s marker_tags %s resolve to a map node" % [id, tags])
		assert_eq(StringName(o.get("text_key", (o.get("data", {}) as Dictionary).get("text_key", &""))),
			StringName("objective.ostrander_federal.%s" % id), "%s text key" % id)
	for id: StringName in OBJECTIVES:
		assert_has(ids, id, "objective %s (doc §HeistDef)" % id)
		assert_eq(_state(id), HIDDEN if id in STARTS_HIDDEN else ACTIVE, "%s start state" % id)
	assert_eq(ids.size(), OBJECTIVES.size(), "no objective beyond the doc's 21 (%s)" % [ids])
	if _rt.map.heist_def != null:
		for id: StringName in _rt.map.heist_def.objectives:
			assert_has(ids, id, "HeistDef objective %s is added" % id)


func test_of_stealth_line_keycard_code_gate_time_lock_vault() -> void:
	if _pending() or not await _launch(Enums.Difficulty.ROUTINE, {&"security_room_staffed": &"sec_empty"}):
		return
	var m: HeistMission = _m()
	assert_eq(int(_data(&"secure").get("total", 0)), 4, "Routine: 4 bags (D-075)")
	# The console and the rack never open the vault door themselves: the time lock owns it (D-136.1).
	for tag: StringName in [&"time_lock", &"server"]:
		for n: Node in m.find_tagged(tag):
			var t: Variant = n.get(&"targets")
			assert_true(t is Array and (t as Array).is_empty(), "%s %s has no door target" % [tag, n.name])
	EventBus.item_picked_up.emit(&"item.keycard", 0)
	await wait_physics_frames(1)
	assert_eq(_state(&"keycard"), DONE, "[keycard] on the card")
	assert_eq(_count(&"vo.mercer.ostrander_federal_keycard"), 1, "keycard line")
	var pc: Node = m.find_tagged(&"code_pc")[0]
	assert_eq(StringName(pc.get(&"reveals_code_group")), &"vault", "the code PC reveals code group vault (QC-63)")
	await _fact(&"device_started", [_net_id(pc), &"hack", 45.0])
	await _fact(&"device_finished", [_net_id(pc)])
	assert_eq(_state(&"code_pc"), DONE, "[code_pc] on the hack")
	assert_eq(_count(&"vo.mercer.ostrander_federal_pc_found"), 1, "pc_found line")
	assert_eq(_count(&"vo.mercer.ostrander_federal_code"), 1, "code line")
	var reader: Node = null
	for n: Node in m.find_tagged(&"vault_gate"):
		if n is KeycardReader:
			reader = n
	assert_true(reader != null, "the vault gate reader")
	await _fact(&"interaction_completed", [_net_id(reader), 0, &"swipe"])
	assert_eq(_state(&"vault_gate"), DONE, "[vault_gate]")
	assert_eq(_state(&"time_lock"), ACTIVE, "[time_lock] is next")
	var console: Node = m.find_tagged(&"time_lock")[0]
	await _fact(&"interaction_completed", [_net_id(console), 0, &"enter_code"])
	assert_eq(_state(&"time_lock"), DONE, "[time_lock] on the code")
	assert_eq(_state(&"time_lock_wait"), ACTIVE, "[time_lock_wait] runs")
	assert_true(bool(m.get(&"time_lock_running")), "time lock running")
	var expect: float = float(m.variant(&"time_lock_s"))
	assert_near(m.timer_left(&"time_lock"), expect, 0.5, "the lock runs time_lock_s (%s)" % expect)
	assert_eq(_count(&"vo.mercer.ostrander_federal_time_lock_started"), 1, "time_lock_started line")
	var vault: Door = m.find_tagged(&"vault_door")[0] as Door
	assert_true(vault != null and vault.locked and not vault.is_open, "vault door shut while the lock runs")
	m.call(&"_on_time_lock_done")
	await wait_physics_frames(2)
	assert_eq(_state(&"time_lock_wait"), DONE, "[time_lock_wait] released")
	assert_true(not vault.locked and vault.is_open, "vault door open")
	assert_eq(_state(&"vault_loot"), ACTIVE, "[vault_loot] next")
	assert_eq(_state(&"gold_cage"), ACTIVE, "[gold_cage] next")
	assert_eq(_count(&"vo.mercer.ostrander_federal_time_lock_open"), 1, "time_lock_open line")
	assert_true(_ended.is_empty(), "nothing ended the heist")


func test_of_rack_hack_starts_the_time_lock() -> void:
	if _pending() or not await _launch():
		return
	var rack: Node = null
	for n: Node in _m().find_tagged(&"server"):
		if n is HackTerminal:
			rack = n
	assert_true(rack != null, "the vault-control rack")
	await _fact(&"device_started", [_net_id(rack), &"hack", 90.0])
	assert_eq(_count(&"vo.mercer.ostrander_federal_server_hack"), 1, "server_hack line")
	await _fact(&"device_jammed", [_net_id(rack)])
	assert_eq(_count(&"vo.mercer.ostrander_federal_hack_interrupt"), 1, "hack_interrupt on a stall")
	await _fact(&"device_finished", [_net_id(rack)])
	assert_eq(_state(&"server"), DONE, "[server]")
	assert_eq(_state(&"code_pc"), DONE, "[code_pc] skipped by the rack")
	assert_true(bool(_m().get(&"time_lock_running")), "the rack started the time lock")
	assert_eq(_state(&"time_lock_wait"), ACTIVE, "[time_lock_wait]")


func test_of_code_hint_reveals_the_code_pc() -> void:
	if _pending() or not await _launch():
		return
	assert_eq(_data(&"code_pc").get("marker_tags", []), [&"code_hint"], "unknown PC: the marker is the planner")
	assert_true(_m().reveal_variant_group(&"code_pc"), "the planner reveals code_pc (QC-63)")
	await wait_physics_frames(1)
	assert_true(_m().is_variant_revealed(&"code_pc"), "revealed")
	assert_eq(_data(&"code_pc").get("marker_tags", []), [&"code_pc"], "the marker moves to the PC")
	assert_eq(_state(&"code_hint"), DONE, "[code_hint]")
	assert_eq(_count(&"vo.mercer.ostrander_federal_code_hint"), 1, "code_hint line")


func test_of_secure_counts_and_van_escape() -> void:
	if _pending() or not await _launch(Enums.Difficulty.HAZARDOUS, {&"escape": &"esc_van_dock"}):
		return
	assert_eq(int(_data(&"secure").get("total", 0)), 6, "Hazardous: 6 bags (D-075)")
	await _secure(&"loot.server_drives", 2)
	await _secure(&"loot.thermal_drill_part", 1)
	assert_eq(int(_m().get(&"required_secured")), 0, "drives and tools never count toward [secure]")
	await _secure(&"loot.cash_bricks", 3)
	await _secure(&"loot.gold", 1)
	await _secure(&"loot.bearer_bonds", 1)
	assert_eq(_state(&"secure"), ACTIVE, "5 of 6")
	assert_eq(_state(&"escape"), HIDDEN, "no escape yet")
	await _secure(&"loot.cash_bricks", 1)
	assert_eq(_state(&"secure"), DONE, "6 secured")
	assert_eq(_state(&"escape"), ACTIVE, "stealth: the escape opens at once (D-136.10)")
	var zone: EscapeZone = _m().find_tagged(&"escape")[0] as EscapeZone
	assert_true(zone != null and zone.active, "the van's escape zone is active")
	assert_eq(_count(&"vo.mercer.ostrander_federal_required_secured"), 1, "required_secured line")
	assert_eq(_count(&"vo.mercer.ostrander_federal_escape"), 1, "escape line")
	assert_eq(_count(&"vo.accountant.ostrander_federal_payday"), 1, "the Accountant's payday line")
	assert_eq(_state(&"keycard"), DONE, "moot access steps leave the list at the escape")


func test_of_stealth_heli_called_on_secure() -> void:
	if _pending() or not await _launch(Enums.Difficulty.ROUTINE, {&"escape": &"esc_heli_terrace"}):
		return
	await _secure(&"loot.cash_bricks", 4)
	var zone: EscapeZone = _m().find_tagged(&"escape")[0] as EscapeZone
	assert_true(zone != null and zone.escape_type == &"heli", "the heli zone")
	assert_true(zone.active, "the heli is called on [secure]")
	assert_near(zone.arrival_delay_s, 45.0, 0.01, "it lands 45 s later (doc §Escape)")
	var said: Array = _lines.filter(func(l: Array) -> bool: return l[1] == &"vo.mercer.ostrander_federal_heli_eta")
	assert_eq(said.size(), 1, "heli_eta line")
	assert_eq(int((said[0][2] as Dictionary).get("seconds", 0)) if not said.is_empty() else 0, 45, "45 s")
