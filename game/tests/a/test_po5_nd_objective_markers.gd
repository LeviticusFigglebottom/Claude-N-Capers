## D-089 / ui_hud v1.8 on Night Deposit: the active objectives carry markers on the real map (keycard, vault
## gate, secure zone of the rolled escape).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_po5_night_deposit_objective_markers() -> void:
	_rt = await HeistLauncher.launch(&"night_deposit", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null and _rt.hud_model != null, "launched")
	await wait_seconds(0.5)
	var ids: Array[StringName] = []
	for m: Dictionary in _rt.hud_model.objective_markers:
		if not ids.has(StringName(m["id"])):
			ids.append(StringName(m["id"]))
	for want: StringName in [&"keycard", &"vault_gate", &"secure"]:
		assert_true(ids.has(want), "marker for %s (got %s)" % [want, ids])
	assert_false(ids.has(&"escape"), "escape hidden until it opens")
