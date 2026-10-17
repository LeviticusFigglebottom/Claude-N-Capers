## B-DB / B-SL strings audit (B 7f86b156, LEAD 2026-10-16): Dockside Burn mission lines and objectives.
## - the burn finding the product says no "product found / bring the thermite" lines;
## - the empty-container hint plays once;
## - [cartel] fails (not completes) when no gunman went down before the police;
## - walking into the product's room completes [product];
## - Reyes' payday plays when the escape completes, not when the ride arrives;
## - Shadow Ledger [secure] starts with drives_secured 0 (the HUD shows 0/2).
extends TestCase

var _rt: HeistRuntime = null
var _lines: Array[StringName] = []
var _cb: Callable


func after_each() -> void:
	if _cb.is_valid() and EventBus.voice_line_requested.is_connected(_cb):
		EventBus.voice_line_requested.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(heist: StringName) -> HeistMission:
	_rt = await HeistLauncher.launch(heist, 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "ai_teammates": 0})
	assert_true(_rt != null, "launched")
	await wait_physics_frames(3)
	_lines = []
	_cb = func(_speaker: StringName, line_id: StringName, _ctx: Dictionary) -> void: _lines.append(line_id)
	EventBus.voice_line_requested.connect(_cb)
	return _rt.map.get_node(^"Mission") as HeistMission


func _count(id: StringName) -> int:
	return _lines.count(id)


func test_db_burn_start_finds_the_product_silently() -> void:
	var m: HeistMission = await _launch(&"dockside_burn")
	m.call(&"_product_found", false)
	assert_eq(m.objective_state(&"product"), Enums.ObjectiveState.COMPLETED, "[product] done")
	assert_eq(m.objective_state(&"burn"), Enums.ObjectiveState.ACTIVE, "[burn] active")
	assert_eq(_count(&"vo.mercer.dockside_burn_thermite_reminder"), 0, "no thermite reminder")
	assert_eq(_count(&"vo.mercer.dockside_burn_product_found"), 0, "no product found line")


func test_db_empty_container_hint_once() -> void:
	var m: HeistMission = await _launch(&"dockside_burn")
	var weapons: Array = m.get(&"_weapons")
	var empties: Array[String] = []
	for k: String in ["k1", "k2", "k3", "k4", "k5", "k6"]:
		if not weapons.has(k):
			empties.append(k)
	assert_true(empties.size() >= 2, "at least two empty containers (%s)" % [empties])
	for k: String in empties:
		m.call(&"_open_container", k)
	assert_eq(_count(&"vo.mercer.dockside_burn_containers_hint"), 1, "hint once for %d empty containers" % empties.size())


func test_db_cartel_fails_with_no_gunman_down() -> void:
	var m: HeistMission = await _launch(&"dockside_burn")
	m.call(&"_on_police_called")
	assert_eq(m.objective_state(&"cartel"), Enums.ObjectiveState.FAILED, "[cartel] failed with 0 down")


func test_db_cartel_completes_with_a_gunman_down() -> void:
	var m: HeistMission = await _launch(&"dockside_burn")
	m.set(&"_gunmen_down", 1)
	m.call(&"_on_police_called")
	assert_eq(m.objective_state(&"cartel"), Enums.ObjectiveState.COMPLETED, "[cartel] done with 1 down")


func test_db_product_room_entry_completes_product() -> void:
	var m: HeistMission = await _launch(&"dockside_burn")
	var prods: Array[Node] = m.find_tagged(&"product")
	assert_false(prods.is_empty(), "product loot spawns")
	if prods.is_empty():
		return
	assert_false(bool(m.call(&"product_seen")), "the crew at the spawn does not see the product")
	var p: Node3D = prods[0] as Node3D
	var snap: Vector3 = NavigationServer3D.map_get_closest_point(_rt.map.get_world_3d().navigation_map, p.global_position)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, snap + Vector3(0, 0.05, 0)))
	await wait_physics_frames(3)
	var ok: bool = await wait_until(func() -> bool:
		return m.objective_state(&"product") == Enums.ObjectiveState.COMPLETED, 3.0)
	assert_true(ok, "[product] completes on entering the room (crew at %s, product at %s)" % [snap, p.global_position])
	assert_eq(_count(&"vo.mercer.dockside_burn_product_found"), 1, "product found said once")


func test_db_payday_on_escape_completed() -> void:
	var m: HeistMission = await _launch(&"dockside_burn")
	m.activate(&"escape")
	assert_eq(_count(&"vo.reyes.dockside_burn_payday"), 0, "no payday while the ride waits")
	m.complete(&"escape")
	assert_eq(_count(&"vo.reyes.dockside_burn_payday"), 1, "payday once the crew got away")


func test_sl_secure_seeds_drives_zero() -> void:
	var m: HeistMission = await _launch(&"shadow_ledger")
	var data: Dictionary = {}
	for o: Dictionary in m.objectives():
		if o.get("id") == &"secure":
			data = o.get("data", {})
	assert_eq(int(data.get("drives_secured", -1)), 0, "drives_secured 0 at start")
	assert_eq(bool(data.get("laptop_secured", true)), false, "laptop_secured false at start")
