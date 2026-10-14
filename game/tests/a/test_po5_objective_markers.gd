## D-089 / ui_hud v1.8: LocalHudModel.objective_markers on the real Glasshouse map: one marker per tagged node
## of each ACTIVE objective with marker_tags; the loud transition skips the keycard step (board finding).
extends TestCase

var _rt: HeistRuntime = null
var _signalled: int = 0


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for m: Dictionary in _rt.hud_model.objective_markers:
		if not out.has(StringName(m["id"])):
			out.append(StringName(m["id"]))
	return out


func _poll() -> void:
	await wait_seconds(0.3)


func test_po5_glasshouse_objective_markers() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null and _rt.hud_model != null, "launched with a hud model")
	_rt.hud_model.objective_markers_changed.connect(func(_m: Array[Dictionary]) -> void: _signalled += 1)
	await _poll()
	var ids: Array[StringName] = _ids()
	for want: StringName in [&"keycard", &"workshop_door", &"safe", &"secure"]:
		assert_true(ids.has(want), "marker for %s (got %s)" % [want, ids])
	assert_false(ids.has(&"safe_loot"), "no marker for a hidden objective")
	assert_true(_signalled > 0, "objective_markers_changed emitted")
	for m: Dictionary in _rt.hud_model.objective_markers:
		assert_true(m["position"] is Vector3 and m.has("text_key") and int(m["state"]) == Enums.ObjectiveState.ACTIVE,
			"marker shape %s" % [m])
	var kc: Node3D = _rt.mission.find_tagged(&"keycard")[0] as Node3D
	var km: Array = _rt.hud_model.objective_markers.filter(func(m: Dictionary) -> bool: return m["id"] == &"keycard")
	assert_true((km[0]["position"] as Vector3).distance_to(kc.global_position) < 0.01, "keycard marker sits on the keycard")
	# Loud: the reader locks down, the keycard step is skipped, its marker goes away.
	(_rt.stealth as StealthDirector).raise_alarm(&"test", 0)
	await _poll()
	assert_eq(_rt.mission.objective_state(&"keycard"), Enums.ObjectiveState.COMPLETED, "keycard step skipped when loud")
	assert_false(_ids().has(&"keycard"), "no keycard marker when loud")
	assert_true(_ids().has(&"safe"), "the safe stays marked")


## QC-60: a node tagged at runtime (objective_tag set by the mission) gets a marker once the objective's data
## is updated, on the same objective with the same marker_tags.
func test_qc60_runtime_tag_resolves_on_data_update() -> void:
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	_rt.mission.update_objective_data(&"safe", {"marker_tags": [&"qc60_found"]})
	await _poll()
	assert_false(_ids().has(&"safe"), "nothing carries the tag yet: no marker")
	var kc: Node3D = _rt.mission.find_tagged(&"keycard")[0] as Node3D
	kc.set(&"objective_tag", &"qc60_found")
	_rt.mission.update_objective_data(&"safe", {"found": 1})
	await _poll()
	var sm: Array = _rt.hud_model.objective_markers.filter(func(m: Dictionary) -> bool: return m["id"] == &"safe")
	assert_eq(sm.size(), 1, "runtime-tagged node marked after the data update")
	if sm.size() == 1:
		assert_true((sm[0]["position"] as Vector3).distance_to(kc.global_position) < 0.01, "marker on the tagged node")
