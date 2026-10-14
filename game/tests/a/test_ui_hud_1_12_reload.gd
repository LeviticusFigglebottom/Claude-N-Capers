## ui_hud v1.12 (D-106): LocalHudModel.reloading / reload_progress for the local crew member's equipped weapon
## (ENV B's reload indicator): -1 when idle, rising 0..1 while reloading, back to -1 when done.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_ui_hud_reload_progress() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 812, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "skip_casing": true})
	await wait_seconds(1.5)  # initial draw
	var hud: LocalHudModel = _rt.hud_model
	var w: CrewWeapons = (_rt.crew_controller(0) as CrewController).weapons
	hud.refresh()
	assert_false(hud.reloading, "idle")
	assert_eq(hud.reload_progress, -1.0, "idle progress is -1")
	var ws: int = w.equipped_slot
	w.set_ammo(ws, 1, 60)
	assert_true(w.start_reload(), "reload started")
	var total: float = w.reload_left
	await wait_physics_frames(1)
	hud.refresh()
	assert_true(hud.reloading, "reloading")
	var p0: float = hud.reload_progress
	assert_true(p0 >= 0.0 and p0 < 0.3, "starts near 0 (%.2f)" % p0)
	await wait_seconds(total * 0.5)
	hud.refresh()
	assert_true(hud.reload_progress > p0 and hud.reload_progress < 1.0, "rises (%.2f)" % hud.reload_progress)
	await wait_seconds(total * 0.6 + 0.3)
	hud.refresh()
	assert_false(hud.reloading, "done")
	assert_eq(hud.reload_progress, -1.0, "back to -1")
