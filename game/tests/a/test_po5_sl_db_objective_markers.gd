## D-089 / ui_hud v1.8 on Shadow Ledger and Dockside Burn: every objective (bar the map-wide ones) carries
## marker_tags that resolve to a map node (the readiness gate's test_01), and the HUD places the active ones.
extends TestCase

## Map-wide objectives: casing (as the gate) and Dockside's [cartel] (thin out the gunmen, no location).
const AREA_OBJECTIVES: Array[StringName] = [&"casing", &"cartel"]
## Cover the escape / cash variants: SL 1 = esc_service, 4242 = esc_line, 7 = esc_heli; DB 1 = cash_countroom +
## esc_van_gate, 3 = cash_countroom + esc_boat, 4242 = cash_strongroom + van, 7 = cash_strongroom + boat.
const SEEDS: Array[int] = [1, 3, 7, 4242]

var _rt: HeistRuntime = null


func after_each() -> void:
	await _teardown()


func _teardown() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _check_markers(heist: StringName, seed_value: int) -> void:
	_rt = await HeistLauncher.launch(heist, seed_value, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null and _rt.mission != null, "%s launched (seed %d)" % [heist, seed_value])
	if _rt == null or _rt.mission == null:
		return
	await wait_physics_frames(5)
	for o: Dictionary in _rt.mission.objectives():
		var oid: StringName = StringName(o["id"])
		if oid in AREA_OBJECTIVES:
			continue
		var tags: Array = (o.get("data", {}) as Dictionary).get("marker_tags", [])
		assert_true(not tags.is_empty(), "%s/%d objective %s has marker_tags" % [heist, seed_value, oid])
		var found: int = 0
		for t: Variant in tags:
			found += _rt.find_by_tag(StringName(t)).size()
		assert_true(found > 0, "%s/%d objective %s: marker_tags %s resolve to a map node" % [heist, seed_value, oid, tags])


func _marker_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for m: Dictionary in _rt.hud_model.objective_markers:
		if not ids.has(StringName(m["id"])):
			ids.append(StringName(m["id"]))
	return ids


func test_po5_shadow_ledger_markers_resolve() -> void:
	for s: int in SEEDS:
		await _check_markers(&"shadow_ledger", s)
		await _teardown()


func test_po5_dockside_burn_markers_resolve() -> void:
	for s: int in SEEDS:
		await _check_markers(&"dockside_burn", s)
		await _teardown()


func test_po5_shadow_ledger_hud_markers() -> void:
	_rt = await HeistLauncher.launch(&"shadow_ledger", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null and _rt.hud_model != null, "launched")
	await wait_seconds(0.5)
	var ids: Array[StringName] = _marker_ids()
	for want: StringName in [&"laptop", &"secure"]:
		assert_true(ids.has(want), "marker for %s (got %s)" % [want, ids])
	assert_false(ids.has(&"hack"), "hack hidden until the cage opens")
	assert_false(ids.has(&"escape"), "escape hidden until it opens")


func test_po5_dockside_burn_hud_markers() -> void:
	_rt = await HeistLauncher.launch(&"dockside_burn", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null and _rt.hud_model != null, "launched")
	await wait_seconds(0.5)
	var ids: Array[StringName] = _marker_ids()
	for want: StringName in [&"breach", &"product", &"containers", &"secure"]:
		assert_true(ids.has(want), "marker for %s (got %s)" % [want, ids])
	assert_false(ids.has(&"cartel"), "cartel is map-wide (no marker)")
	assert_false(ids.has(&"escape"), "escape hidden until it opens")
