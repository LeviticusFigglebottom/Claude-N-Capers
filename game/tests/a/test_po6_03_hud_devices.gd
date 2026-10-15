## PO6-03 (ui_hud v1.9): LocalHudModel.devices lists a placed drill while running / jammed (with the fix
## prompt) and drops it when done; a hack terminal shows as kind &"hack".
extends TestCase

var _rt: HeistRuntime = null
var _hud: LocalHudModel = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_devices", 909, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true})
	_hud = LocalHudModel.new()
	_hud.name = "LocalHudModel"
	_rt.add_child(_hud)
	await wait_frames(1)


func after_each() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _row(net_id: int) -> Dictionary:
	_hud.refresh()
	for r: Dictionary in _hud.devices:
		if int(r["net_id"]) == net_id:
			return r
	return {}


func test_po6_03_drill_row_running_jammed_done() -> void:
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 1, -4), func(n: Node) -> void:
		(n as DrillPoint).duration_s = 60.0) as DrillPoint
	await wait_physics_frames(1)
	var fired: Array[int] = [0]
	_hud.devices_changed.connect(func() -> void: fired[0] += 1)
	assert_true(_row(dp.net_id).is_empty(), "idle drill: no row")
	dp.runner.place(0, dp.effective_duration())
	var r: Dictionary = _row(dp.net_id)
	assert_false(r.is_empty(), "placed drill has a row")
	assert_eq(r.get("kind"), &"drill")
	assert_eq(r.get("state"), &"running")
	assert_true(absf(float(r["duration_s"]) - 60.0) < 0.01, "duration 60 s")
	assert_true(float(r["time_left_s"]) > 59.0, "time left ~60 s")
	assert_true((r["world_pos"] as Vector3).y > dp.global_position.y, "panel above the device")
	assert_eq(r.get("fix_prompt_key"), &"", "no fix prompt while running")
	assert_true(fired[0] >= 1, "devices_changed fired")
	dp.runner.progress = 0.5
	dp.runner._jam()
	r = _row(dp.net_id)
	assert_eq(r.get("state"), &"jammed")
	assert_eq(r.get("fix_prompt_key"), &"ui.prompt.fix_drill")
	assert_true(absf(float(r["progress"]) - 0.5) < 0.01, "progress 0.5")
	assert_true(absf(float(r["time_left_s"]) - 30.0) < 0.2, "30 s left")
	dp.runner.fix(0)
	dp.runner.jams.clear()
	dp.runner.progress = 0.999
	await wait_seconds(0.3)
	assert_true(_row(dp.net_id).is_empty(), "done drill: row removed")


func test_po6_03_hack_row() -> void:
	var ht: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(2, 1, -4), func(n: Node) -> void:
		(n as HackTerminal).duration_s = 40.0) as HackTerminal
	await wait_physics_frames(1)
	ht.start_hack(0)
	var r: Dictionary = _row(ht.net_id)
	assert_false(r.is_empty(), "running hack has a row")
	assert_eq(r.get("kind"), &"hack")
	assert_eq(r.get("state"), &"running")
	assert_true(absf(float(r["duration_s"]) - 40.0) < 0.01, "duration 40 s")


func test_po6_03_extras_restart_offset_c4() -> void:
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 1, -4), func(n: Node) -> void:
		(n as DrillPoint).duration_s = 60.0) as DrillPoint
	await wait_physics_frames(1)
	dp.runner.place(0, dp.effective_duration())
	var r: Dictionary = _row(dp.net_id)
	assert_eq(float(r.get("auto_restart_in_s", 0.0)), -1.0, "running: no auto restart pending")
	var wp: Vector3 = r["world_pos"]
	var out: Vector3 = (wp - dp.global_position) * Vector3(1, 0, 1)
	assert_true(out.dot(dp.global_basis.z) > 0.1, "panel sits out of the lock face (+Z of the drill point)")
	dp.runner.auto_restart = true
	dp.runner.progress = 0.5
	dp.runner._jam()
	r = _row(dp.net_id)
	assert_true(float(r.get("auto_restart_in_s", -1.0)) >= 4.9, "jammed with auto restart: countdown shown")
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(3, 0, -4)) as Safe
	await wait_physics_frames(1)
	safe.stage = Safe.Stage.C4_ARMED
	safe.timer_left = Tweak.interaction().c4_fuse_s * 0.5
	EventBus.device_started.emit(safe.net_id, &"c4", Tweak.interaction().c4_fuse_s)
	r = _row(safe.net_id)
	assert_eq(r.get("kind"), &"c4", "armed C4 row")
	assert_true(absf(float(r.get("progress", 0.0)) - 0.5) < 0.05, "fuse half burnt")
	safe.timer_left = -1.0
	safe.stage = Safe.Stage.LOCKED
	assert_true(_row(safe.net_id).is_empty(), "fuse done: row removed")
