## OF-A6: the Ostrander Federal rare events on ENV C's G1 map (doc §Rare events, B's OF-B1 effect keys): time_lock_glitch
## (a 30 s time lock), bond_delivery (+2 bond bags in the vault), vip_client (the VIP + bodyguard spawn, Mercer names
## them), armored_car_early (2 Vaultline crew at 15:00, Brutal+), tower_sniper (perch S3 open, the loud heli +30 s);
## without tower_sniper S3 stays closed. SKIPs "pending C G1" without the map.
extends "res://tests/a/of_mission_case.gd"


func _bags(loot_id: StringName) -> int:
	var n: int = 0
	for b: Node in _rt.find_children("*", "", true, false):
		if b is LootBag and (b as LootBag).loot_id == loot_id and not b.is_queued_for_deletion():
			n += 1
	return n


func _tower_open() -> bool:
	for tp: TacticalPoint in SpecialSpawner.open_perches(_rt):
		if tp.tags.has(&"tower_sniper"):
			return true
	return false


func test_of_time_lock_glitch_runs_30_s() -> void:
	if _pending() or not await _launch(Enums.Difficulty.ROUTINE, {}, [&"time_lock_glitch"]):
		return
	var console: Node = _m().find_tagged(&"time_lock")[0]
	await _fact(&"interaction_completed", [_net_id(console), 0, &"enter_code"])
	assert_near(_m().timer_left(&"time_lock"), 30.0, 0.5, "the maintenance window: 30 s")


func test_of_bond_delivery_adds_two_bond_bags() -> void:
	if _pending() or not await _launch(Enums.Difficulty.ROUTINE, {}, [&"bond_delivery"]):
		return
	assert_eq(_bags(&"loot.bearer_bonds"), 2, "+2 bond bags in the vault")


func test_of_no_rare_events_keeps_the_baseline() -> void:
	if _pending() or not await _launch():
		return
	assert_eq(_bags(&"loot.bearer_bonds"), 0, "no delivered bonds")
	assert_false(_tower_open(), "S3 closed without tower_sniper")
	assert_near(_m().timer_left(&"armored_car"), 0.0, 0.001, "no armoured car scheduled")


func test_of_bad_events_vip_car_tower() -> void:
	var rares: Array = [&"vip_client", &"armored_car_early", &"tower_sniper"]
	if _pending() or not await _launch(Enums.Difficulty.BRUTAL, {&"escape": &"esc_heli_terrace"}, rares):
		return
	var m: HeistMission = _m()
	var vip: Variant = m.variant(&"vip")
	assert_true(vip is Array and (vip as Array).has(&"vip_in"), "vip_client pins vip_in (%s)" % vip)
	var vip_civ: int = 0
	for n: Node in _rt.npcs(&"civilian"):
		if ((n as NpcBase).spawn_info.get("tags", []) as Array).has(&"civ_vip"):
			vip_civ += 1
	assert_eq(vip_civ, 1, "the VIP client is in the deposit hall")
	m.call(&"_schedule_rare_events")  # the VIP line timer, re-armed: fire it now
	await wait_physics_frames(1)
	assert_near(m.timer_left(&"armored_car"), 900.0 - m.elapsed_s, 1.0, "the armoured car at 15:00 elapsed")
	assert_true(_tower_open(), "tower_sniper opens S3")
	var guards_before: int = _rt.npcs(&"guard").size()
	m.call(&"_on_armored_car")
	await wait_physics_frames(2)
	var crew: int = 0
	for n: Node in _rt.npcs(&"guard"):
		if ((n as NpcBase).spawn_info.get("tags", []) as Array).has(&"guard_vaultline"):
			crew += 1
	assert_eq(crew, 2, "2 Vaultline crew step out (QC-25)")
	assert_eq(_rt.npcs(&"guard").size(), guards_before + 2, "+2 guards")
	assert_eq(_count(&"vo.mercer.ostrander_federal_armored_car"), 1, "armored_car line")
	var eta: float = float(m.variant(&"escape_eta_s"))
	assert_near(float(m.call(&"loud_escape_eta")), eta + 30.0, 0.01, "tower_sniper: the loud heli +30 s")
