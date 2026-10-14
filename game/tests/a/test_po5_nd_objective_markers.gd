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


## PO-5 (Night Deposit loud run): the lockdown disables code / server (args.disabled); like the objectives
## panel, the HUD then shows no markers for them, and the vault drill is marked instead.
func test_po5_nd_lockdown_hides_disabled_markers() -> void:
	_rt = await HeistLauncher.launch(&"night_deposit", 7, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	await wait_seconds(0.5)
	(_rt.stealth as StealthDirector).raise_alarm(&"test", 0)
	await wait_seconds(0.5)
	var ids: Array[StringName] = []
	for m: Dictionary in _rt.hud_model.objective_markers:
		if not ids.has(StringName(m["id"])):
			ids.append(StringName(m["id"]))
	assert_false(ids.has(&"server"), "no server marker in a lockdown (got %s)" % [ids])
	assert_false(ids.has(&"code"), "no code marker in a lockdown (got %s)" % [ids])
	assert_true(ids.has(&"vault_drill"), "the vault drill is marked (got %s)" % [ids])
