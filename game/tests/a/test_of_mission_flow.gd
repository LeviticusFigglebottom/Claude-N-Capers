## OF-A6: the Ostrander Federal mission's stealth line on ENV C's G1 map: every objective of the HeistDef with resolving
## marker_tags (ui_hud 1.8), the keycard -> code -> gate -> time lock -> vault flow (Night Deposit pattern, D-136.1), the
## rack hack starting the time lock, [code_hint] revealing the code PC (QC-63), [secure] counts (6 / 4 on Routine; cash,
## gold, bonds count, drives and tools never) and the stealth escapes (van at once, heli after its 45 s). SKIPs "pending
## C G1" without the map.
extends "res://tests/a/of_mission_case.gd"

const OBJECTIVES: Array[StringName] = [&"casing", &"keycard", &"code_hint", &"code_pc", &"server", &"vault_gate", &"lasers",
	&"time_lock", &"time_lock_wait", &"vault_loot", &"gold_cage", &"secure", &"deposit_boxes", &"bond_safe",
	&"president_safe", &"server_drives", &"drill_delivery", &"vault_drill", &"vault_breach", &"escape_wait", &"escape"]
const STARTS_HIDDEN: Array[StringName] = [&"time_lock", &"time_lock_wait", &"vault_loot", &"gold_cage", &"bond_safe",
	&"drill_delivery", &"vault_drill", &"vault_breach", &"escape_wait", &"escape"]


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


## P's ghost-line loops walk the vault guard through the locked gate (Door.npc_open keeps `locked`): that open is not
## the crew's gate, so [vault_gate] stays active until the reader unlocks it.
func test_of_guard_passing_the_locked_gate_is_not_vault_gate() -> void:
	if _pending() or not await _launch():
		return
	var gate: Door = null
	for n: Node in _m().find_tagged(&"vault_gate"):
		if n is Door:
			gate = n as Door
	assert_true(gate != null and gate.locked and not gate.is_open, "the vault gate starts shut and locked")
	gate.set_open(true)  # what Door._npc_apply_open does for a staff pass
	await wait_physics_frames(1)
	assert_true(gate.locked, "still locked after the guard's pass")
	assert_eq(_state(&"vault_gate"), ACTIVE, "[vault_gate] not completed by a guard opening it")
	gate.set_open(false)
	gate.unlock()
	gate.open()
	await wait_physics_frames(1)
	assert_eq(_state(&"vault_gate"), DONE, "[vault_gate] on an unlocked open")


## LEAD OF-done (Cataclysm loud, 3 GPU runs): the pilot walked to the bond safe and the vault-wall boxes through the
## sealed vault's wall. Inside-the-vault markers wait for the vault (open or burned through); the SD hall's boxes don't.
func test_of_vault_side_loot_marked_once_the_vault_is_reachable() -> void:
	if _pending() or not await _launch():
		return
	await wait_seconds(0.5)
	var before: Dictionary = _marker_names()
	assert_eq(_state(&"bond_safe"), HIDDEN, "[bond_safe] hidden while the vault is sealed")
	assert_false(before.has(&"bond_safe"), "no bond safe marker yet")
	var boxes: Array = before.get(&"deposit_boxes", [])
	assert_true(not boxes.is_empty(), "the SD hall's boxes are marked (%s)" % [boxes])
	for n: Variant in boxes:
		assert_true(String(n).begins_with("HallBox"), "only hall boxes before the vault (%s)" % n)
	(_m() as Object).call(&"open_vault")
	await wait_seconds(0.5)
	var after: Dictionary = _marker_names()
	assert_eq(_state(&"bond_safe"), ACTIVE, "[bond_safe] once the vault is open")
	assert_true(after.has(&"bond_safe"), "bond safe marked")
	var vault_marked: bool = false
	for n: Variant in after.get(&"deposit_boxes", []):
		vault_marked = vault_marked or String(n).begins_with("VaultBox")
	assert_true(vault_marked, "the vault-wall boxes are marked once it is open")
	# [vault_loot]: the cash cage's way in (padlock, keypad) while its gate is shut, then the cash.
	var cage: Array = after.get(&"vault_loot", [])
	assert_true(cage.has("Padlock"), "the cage padlock is marked while the cage is shut (%s)" % [cage])
	assert_false(cage.has("VaultCash") or cage.has("CashCageGate"), "not the cash or the gate yet (%s)" % [cage])
	var lock: Padlock = null
	for n: Node in _m().find_tagged(&"cash_cage"):
		if n is Padlock:
			lock = n as Padlock
	lock.open_lock(true, &"saw")
	await wait_seconds(0.5)
	var opened: Array = _marker_names().get(&"vault_loot", [])
	assert_true(opened.has("VaultCash") and not opened.has("Padlock"), "the cash once the cage is open (%s)" % [opened])


## objective id -> the names of the nodes the HUD marks for it (positions matched to the tagged nodes).
func _marker_names() -> Dictionary:
	var out: Dictionary = {}
	var found: Dictionary = _rt.find_by_tags([&"bond_safe", &"deposit_boxes", &"cash_cage", &"vault_loot"])
	for m: Dictionary in _rt.hud_model.objective_markers:
		var id: StringName = StringName(m["id"])
		var tags: Array = [&"cash_cage", &"vault_loot"] if id == &"vault_loot" else [id]
		for n: Node in tags.reduce(func(acc: Array, t: StringName) -> Array: return acc + found.get(t, []), []):
			if n is Node3D and (n as Node3D).global_position.is_equal_approx(m["position"]):
				var names: Array = out.get(id, [])
				names.append(String(n.name))
				out[id] = names
	return out


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


## B's audit (OF-B1): the side objectives complete on their real triggers: a safe opened by any method (polled) and
## every server drive bag secured (bagging alone is not taking them out).
func test_of_side_safes_and_drives_complete() -> void:
	if _pending() or not await _launch(Enums.Difficulty.ROUTINE, {&"president_safe": &"ps_bonds"}):
		return
	_m().call(&"open_vault")  # the bond safe is in the vault: its objective appears with it
	for tag: StringName in [&"bond_safe", &"president_safe"]:
		var safe: Safe = null
		for n: Node in _m().find_tagged(tag):
			if n is Safe:
				safe = n as Safe
		assert_true(safe != null, "a %s Safe in the map" % tag)
		if safe == null:
			continue
		assert_eq(_state(tag), ACTIVE, "[%s] active while shut" % tag)
		safe.open_by_device()
		await wait_seconds(0.7)
		assert_eq(_state(tag), DONE, "[%s] completes once the safe is open" % tag)
	assert_eq(_state(&"server_drives"), ACTIVE, "[server_drives] active")
	await _secure(&"loot.server_drives", 1)
	assert_eq(_state(&"server_drives"), ACTIVE, "one drive bag of 2 is not all of them")
	EventBus.loot_secured.emit(9100, &"loot.server_drives", 1000)
	await wait_physics_frames(1)
	assert_eq(_state(&"server_drives"), DONE, "[server_drives] completes with both drive bags secured")
