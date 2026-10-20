## OF-A6: the Ostrander Federal loud line on ENV C's G1 map: the lockdown (D-136.1: a running time lock cancelled, the
## console and the rack dead, the gate reader dead, the gate BARRED, the bronze doors relocked; no heist fail, D-136.9),
## an alarm after the vault opened (no drill), the drill delivery (2 respawning tool bags at the rolled drop, QC-60 /
## D-136.9) on a DrillPoint needing 2 parts, the burn-through enabling the hoist, the rope ladder and the hole rappel
## (QC-61), and the loud escape on [secure] + escape_eta_s (D-136.10). SKIPs "pending C G1" without the map.
extends "res://tests/a/of_mission_case.gd"


func _alarm() -> void:
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)


func _lid_drill() -> DrillPoint:
	for n: Node in _m().find_tagged(&"vault_drill"):
		if n is DrillPoint:
			return n as DrillPoint
	return null


func _hoist() -> BagLift:
	for n: Node in _m().find_tagged(&"hoist"):
		if n is BagLift:
			return n as BagLift
	return null


func _hole_link() -> NavigationLink3D:
	for n: Node in _rt.map.find_children("*", "TacticalPoint", true, false):
		var tp: TacticalPoint = n as TacticalPoint
		if tp != null and tp.tags.has(&"hole_rappel"):
			return RappelLinks.link_of(tp)
	return null


func test_of_lockdown_cancels_the_time_lock_and_seals_the_vault() -> void:
	if _pending() or not await _launch(Enums.Difficulty.ROUTINE, {&"drill_delivery": &"drop_dock"}):
		return
	var m: HeistMission = _m()
	var console: Node = m.find_tagged(&"time_lock")[0]
	await _fact(&"interaction_completed", [_net_id(console), 0, &"enter_code"])
	assert_true(bool(m.get(&"time_lock_running")), "time lock running before the alarm")
	await _alarm()
	assert_true(bool(m.get(&"lockdown")), "lockdown")
	assert_false(bool(m.get(&"time_lock_running")), "the time lock is cancelled")
	assert_near(m.timer_left(&"time_lock"), 0.0, 0.001, "its timer is gone")
	assert_eq(_state(&"time_lock_wait"), Enums.ObjectiveState.FAILED, "[time_lock_wait] fails (doc Mission notes)")
	var it: Node = console.get_node_or_null(^"Interactable")
	assert_true(it != null and not bool(it.get(&"enabled")), "the console is dead")
	for n: Node in m.find_tagged(&"server"):
		if n is HackTerminal:
			assert_true((n as HackTerminal).pause_reasons().has(&"lockdown"), "the rack is paused (lockdown)")
	for n: Node in m.find_tagged(&"vault_gate"):
		if n is KeycardReader:
			assert_true((n as KeycardReader).disabled, "the gate reader is dead")
		elif n is Door:
			assert_eq((n as Door).lock, Door.Lock.BARRED, "the vault gate is BARRED")
			assert_false((n as Door).is_open, "and shut")
	var vault: Door = m.find_tagged(&"vault_door")[0] as Door
	assert_true(vault.locked and not vault.is_open and vault.lock == Door.Lock.VAULT, "the vault door stays sealed")
	for n: Node in m.find_tagged(&"bronze_doors"):
		if n is Door:
			assert_true((n as Door).locked and not (n as Door).is_open, "%s shut and locked" % n.name)
	assert_eq(_state(&"drill_delivery"), ACTIVE, "[drill_delivery] next")
	var first: StringName = &""
	for o: Dictionary in m.objectives():  # ENV B (LEAD r245 1): the HUD shows the first ACTIVE non-side step
		if int(o["state"]) == ACTIVE and not bool((o["data"] as Dictionary).get("side", false)):
			first = o["id"]
			break
	assert_eq(first, &"drill_delivery", "the HUD objective line reads the drill delivery, not [secure]")
	assert_eq(_state(&"keycard"), DONE, "the card step is moot (skipped)")
	assert_eq(_count(&"vo.mercer.ostrander_federal_lockdown"), 1, "lockdown line")
	assert_eq(_count(&"vo.mercer.ostrander_federal_drill_inbound_dock"), 1, "drill_inbound line for the dock")
	assert_near(m.timer_left(&"drill_delivery"), float(m.variant(&"drill_eta_s")), 0.5, "the rig arrives drill_eta_s later")
	await wait_physics_frames(5)
	assert_true(_ended.is_empty(), "the alarm never fails the heist (D-136.9)")


func test_of_alarm_after_the_vault_opened_skips_the_drill() -> void:
	if _pending() or not await _launch():
		return
	_m().call(&"open_vault")
	await wait_physics_frames(1)
	await _alarm()
	assert_eq(_count(&"vo.mercer.ostrander_federal_lockdown_vault_open"), 1, "lockdown_vault_open line")
	assert_eq(_count(&"vo.mercer.ostrander_federal_lockdown"), 0, "not the drill line")
	assert_eq(_state(&"drill_delivery"), HIDDEN, "no drill")
	for n: Node in _m().find_tagged(&"vault_gate"):
		if n is Door:
			assert_ne((n as Door).lock, Door.Lock.BARRED, "the gate stays passable with the vault open")
	var vault: Door = _m().find_tagged(&"vault_door")[0] as Door
	assert_true(vault.is_open, "the vault door stays open")


func test_of_drill_delivery_two_respawning_parts() -> void:
	if _pending() or not await _launch(Enums.Difficulty.ROUTINE, {&"drill_delivery": &"drop_terrace"}):
		return
	var drill: DrillPoint = _lid_drill()
	assert_true(drill != null, "the lid drill")
	assert_eq(drill.requires_loot, &"loot.thermal_drill_part", "it needs the drill parts (QC-60)")
	assert_eq(drill.requires_count, 2, "two of them")
	assert_true(drill.needs_delivery(), "nothing delivered yet")
	await _alarm()
	assert_true(_drill_parts().is_empty(), "no parts before drill_eta_s")
	_m().call(&"_deliver_drill", &"terrace")
	await wait_physics_frames(2)
	var parts: Array[LootBag] = _drill_parts()
	assert_eq(parts.size(), 2, "2 parts at the drop")
	var marker: Node3D = _m().loot_markers(&"drill_delivery")[0]
	for b: LootBag in parts:
		assert_true(b.global_position.distance_to(marker.global_position) < 2.0, "at the terrace drop")
	assert_eq(_state(&"vault_drill"), ACTIVE, "[vault_drill] next")
	assert_eq(_count(&"vo.mercer.ostrander_federal_drill_delivered_terrace"), 1, "drill_delivered line")
	parts[0].queue_free()  # destroyed: comes back at the drop (D-136.9)
	await wait_physics_frames(4)
	assert_eq(_drill_parts().size(), 2, "the lost part respawned")
	drill.add_delivered(2)
	assert_false(drill.needs_delivery(), "both parts delivered")


func test_of_burn_through_enables_hoist_ladder_and_rappel() -> void:
	if _pending() or not await _launch():
		return
	var hoist: BagLift = _hoist()
	assert_true(hoist != null, "the hoist")
	assert_false(hoist.is_enabled(), "the hoist starts disabled (QC-61)")
	var ladders: Array = _m().call(&"rope_ladders")
	assert_false(ladders.is_empty(), "the rope ladder")
	for l: Ladder in ladders:
		assert_false(l.is_climbable(), "the rope ladder starts unclimbable")
		assert_false(l.is_enabled(), "and disabled (QC-61)")
	var link: NavigationLink3D = _hole_link()
	assert_true(link != null and not link.enabled, "the hole rappel starts disabled")
	await _alarm()
	var drill: DrillPoint = _lid_drill()
	await _fact(&"device_started", [drill.net_id, &"thermal", 360.0])
	assert_eq(_count(&"vo.mercer.ostrander_federal_drill_started"), 1, "drill_started line")
	await _fact(&"device_jammed", [drill.net_id])
	assert_eq(_count(&"vo.mercer.ostrander_federal_drill_jam"), 1, "drill_jam line")
	await _fact(&"device_finished", [drill.net_id])
	await wait_physics_frames(2)
	assert_true(bool(_m().get(&"burned_through")), "burned through")
	assert_true(hoist.is_enabled() and hoist.visible, "the hoist is on")
	for l: Ladder in ladders:
		assert_true(l.is_climbable() and l.visible, "the rope ladder is down")
		if l.has_meta(&"burn_height_m"):
			var h: float = float(l.get_meta(&"burn_height_m"))
			assert_near(l.height_m, h, 0.001, "the rope ladder drops to its burn_height_m (%.1f m)" % h)
			assert_near(l.top_position().y - l.global_position.y, h, 0.05, "its Top follows the new height")
			var lnk: NavigationLink3D = l.nav_link()
			assert_true(lnk != null and lnk.enabled, "its NavLink is on")
			assert_near(l.to_global(lnk.end_position).y if lnk != null else 0.0, l.top_position().y, 0.01, "the NavLink reaches the new Top")
	assert_true(link != null and link.enabled, "police can rappel down the hole")
	for n: Node in _rt.map.find_children("*", "", true, false):
		if n.has_meta(&"burn_lid"):
			assert_false((n as Node3D).visible, "the lid is gone")
			if n is CollisionObject3D:
				assert_eq((n as CollisionObject3D).collision_layer, 0, "the lid no longer collides")
	for id: StringName in [&"drill_delivery", &"vault_drill", &"vault_breach"]:
		assert_eq(_state(id), DONE, "[%s]" % id)
	assert_eq(_state(&"vault_loot"), ACTIVE, "[vault_loot] next")
	assert_eq(_count(&"vo.mercer.ostrander_federal_burn_through"), 1, "burn_through line")
	var hoist_it: int = hoist.net_id
	await _fact(&"interaction_completed", [hoist_it, 0, &"lift"])
	assert_eq(_count(&"vo.mercer.ostrander_federal_hoist"), 1, "hoist line on first use")


func test_of_loud_escape_after_secure_and_eta() -> void:
	if _pending() or not await _launch(Enums.Difficulty.HAZARDOUS, {&"escape": &"esc_van_tannery"}):
		return
	await _alarm()
	await _secure(&"loot.cash_bricks", 6)
	assert_eq(_state(&"secure"), DONE, "6 secured")
	assert_eq(_state(&"escape_wait"), ACTIVE, "[escape_wait]: the van comes back")
	assert_eq(_state(&"escape"), HIDDEN, "not open yet")
	var eta: float = float(_m().variant(&"escape_eta_s"))
	for ob: Dictionary in _m().objectives():  # ENV B HUD: "ESCAPE mm:ss" counts down objective data `seconds`
		if ob["id"] == &"escape_wait":
			assert_near(float((ob["data"] as Dictionary).get("seconds", -1.0)), _m().loud_escape_eta(), 0.01, "ETA on the HUD")
	assert_near(_m().timer_left(&"escape_eta"), eta, 0.5, "escape_eta_s after [secure] (D-136.10)")
	assert_eq(_count(&"vo.mercer.ostrander_federal_van_eta"), 1, "van_eta line")
	_m().call(&"open_escape")
	await wait_physics_frames(1)
	assert_eq(_state(&"escape_wait"), DONE, "[escape_wait] done")
	assert_eq(_state(&"escape"), ACTIVE, "[escape]")
	var zone: EscapeZone = _m().find_tagged(&"escape")[0] as EscapeZone
	assert_true(zone.active and zone.arrival_delay_s == 0.0, "the van is there")
	assert_true(_ended.is_empty(), "no fail")


## B's OF-B1 row: Mercer calls Brandt (captain_arrived, AegisCaptain L4.9) on each arrival.
func test_of_captain_arrived_line() -> void:
	if _pending() or not await _launch():
		return
	await _alarm()
	await _fact(&"captain_arrived", [4242])
	assert_eq(_count(&"vo.mercer.ostrander_federal_captain_arrived"), 1, "Mercer: Brandt is here")
	await _fact(&"captain_retreated", [4242])
	await _fact(&"captain_arrived", [4243])
	assert_eq(_count(&"vo.mercer.ostrander_federal_captain_arrived"), 2, "and again when he comes back")
