## ui_hud v1.9 / v1.10: LocalHudModel.local_net_id, revive_progress / reviver_slot for the local crew member, and
## the per-teammate crew row keys bleedout_s / revive_progress (ENV B badges).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_ui_hud_local_net_id_and_revive_progress() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 808, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var hud: LocalHudModel = _rt.hud_model
	var me: CrewController = _rt.crew_controller(0) as CrewController
	var mate: CrewController = _rt.crew_controller(1) as CrewController
	hud.refresh()
	assert_eq(hud.local_net_id, me.net_id, "local_net_id is the HUD's crew member")
	assert_eq(hud.reviver_slot, -1, "nobody reviving")
	assert_eq(hud.revive_progress, 0.0, "no revive progress")
	me.health.go_down()
	mate.set_masked()
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, me.global_position + Vector3(0.8, 0, 0)))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 1, me.net_id)
	await wait_seconds(Tweak.crew().revive_time_s * 0.4)
	hud.refresh()
	assert_eq(hud.reviver_slot, 1, "slot 1 is reviving me")
	assert_true(hud.revive_progress > 0.1 and hud.revive_progress < 1.0, "progress %.2f" % hud.revive_progress)
	_rt.clear_bot_intent(1)


func test_ui_hud_crew_row_bleedout() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 808, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var hud: LocalHudModel = _rt.hud_model
	var mate: CrewController = _rt.crew_controller(1) as CrewController
	hud.refresh()
	var row: Dictionary = hud.crew.filter(func(r: Dictionary) -> bool: return int(r["slot"]) == 1)[0]
	assert_eq(float(row["bleedout_s"]), -1.0, "standing: no bleedout")
	assert_eq(float(row["revive_progress"]), -1.0, "nobody reviving")
	mate.health.go_down()
	hud.refresh()
	row = hud.crew.filter(func(r: Dictionary) -> bool: return int(r["slot"]) == 1)[0]
	assert_true(float(row["bleedout_s"]) > 0.0, "downed teammate shows its bleedout (%.1f)" % float(row["bleedout_s"]))
