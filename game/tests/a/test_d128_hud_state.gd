## D-128 / ui_hud v1.17: detection rows carry the observer's `state` (&"curious" / &"investigating") and a
## CURIOUS or INVESTIGATING observer gets a value-0 row while the tracked crew member is in its view or within
## its stealth range, so the HUD can draw its "?".
extends TestCase

var _rt: HeistRuntime = null
var _st: StealthDirector = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false})
	_st = _rt.stealth
	_crew().loadout.detection_risk = 35


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _place(pos: Vector3) -> void:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(3)


func _row(rows: Array, g: Node) -> Dictionary:
	for r: Variant in rows:
		if r is Dictionary and int((r as Dictionary)["observer_net_id"]) == NetIds.of(g):
			return r
	return {}


func test_d128_investigating_guard_in_range_gets_a_state_row() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	await _place(Vector3(0, 0.05, 8))  # 8 m behind the guard: in range (20 m), out of view, no meter
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3.ZERO, Vector3.FORWARD)
	await wait_physics_frames(8)
	assert_true(_row(_st.detection_entries(0), g).is_empty(), "calm guard, no meter: no row")
	g.set_alert_state(Enums.AlertState.INVESTIGATING)
	var r: Dictionary = _row(_st.detection_entries(0), g)
	assert_false(r.is_empty(), "investigating guard in range: a row")
	assert_near(float(r.get("value", -1.0)), 0.0, 0.0001, "at value 0")
	assert_eq(r.get("state"), &"investigating")
	_rt.hud_model.refresh()
	var h: Dictionary = _row(_rt.hud_model.detection, g)
	assert_false(h.is_empty(), "LocalHudModel keeps the value-0 state row")
	assert_eq(h.get("state"), &"investigating", "state passed to the HUD row")
	g.set_alert_state(Enums.AlertState.CURIOUS)
	assert_eq(_row(_st.detection_entries(0), g).get("state"), &"curious")
	await _place(Vector3(0, 0.05, 30))  # 30 m behind: out of range and out of view
	assert_true(_row(_st.detection_entries(0), g).is_empty(), "curious guard out of range and view: no row")
	_rt.hud_model.refresh()
	assert_true(_row(_rt.hud_model.detection, g).is_empty(), "no HUD row either")


func test_d128_meter_rows_carry_empty_state() -> void:
	var c: CrewController = _crew()
	c.set_masked()
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3.ZERO, Vector3.FORWARD)
	await _place(Vector3(0, 0.05, -10))
	var ok: bool = await wait_until(func() -> bool: return _st.detection_value(g, 0) > 0.0, 1.0)
	assert_true(ok, "meter rising")
	var r: Dictionary = _row(_st.detection_entries(0), g)
	assert_eq(r.get("state"), &"", "calm guard filling: state empty")
	_rt.hud_model.refresh()
	var h: Dictionary = _row(_rt.hud_model.detection, g)
	assert_false(h.is_empty(), "meter row on the HUD")
	assert_false(h.has("state"), "v1.16 shape when there is no state")
