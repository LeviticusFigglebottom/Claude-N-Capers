## PO6-07 (D-114 §3): a device removed while running emits device_jammed (stop fact of cue.drill_loop) and
## never device_finished.
extends TestCase

var _rt: HeistRuntime = null
var _facts: Array[StringName] = []


func before_each() -> void:
	_facts.clear()
	_rt = await HeistLauncher.launch(&"unit_devices", 909, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true})
	EventBus.device_jammed.connect(_on_jammed)
	EventBus.device_finished.connect(_on_finished)


func after_each() -> void:
	EventBus.device_jammed.disconnect(_on_jammed)
	EventBus.device_finished.disconnect(_on_finished)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_jammed(_id: int) -> void:
	_facts.append(&"jammed")


func _on_finished(_id: int) -> void:
	_facts.append(&"finished")


func test_po6_07_device_removed_mid_run_stops_its_loop() -> void:
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 1, -4), func(n: Node) -> void:
		(n as DrillPoint).duration_s = 60.0) as DrillPoint
	await wait_physics_frames(1)
	dp.runner.place(0, dp.effective_duration())
	dp.runner.jams.clear()
	await wait_physics_frames(2)
	assert_eq(_facts.size(), 0, "nothing yet")
	dp.queue_free()
	await wait_frames(2)
	assert_eq(_facts, [&"jammed"] as Array[StringName], "removed while running: one device_jammed, no finish")


func test_po6_07_idle_device_removed_is_silent() -> void:
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 1, -4)) as DrillPoint
	await wait_physics_frames(1)
	dp.queue_free()
	await wait_frames(2)
	assert_eq(_facts.size(), 0, "idle device: no facts")


## PO6-04 follow-up: a safe opened another way while its drill runs stops the drill (device_finished, no open
## twice, no done cue).
func test_po6_04_safe_opened_stops_running_drill() -> void:
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(3, 0, -4), func(n: Node) -> void:
		(n as Safe).methods = [&"drill", &"code"] as Array[StringName]) as Safe
	await wait_physics_frames(1)
	safe.runner.place(0, 60.0)
	safe.runner.jams.clear()
	await wait_physics_frames(2)
	safe.swing_open()
	await wait_physics_frames(2)
	assert_eq(safe.runner.state, DeviceRunner.State.DONE, "drill stopped")
	assert_eq(_facts, [&"finished"] as Array[StringName], "one device_finished stops the loop")


## D-115 (DB-5 / SL-1): a safe's drill_duration_s / saw_duration_s override its size's run time.
func test_d115_safe_run_time_overrides() -> void:
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(-3, 0, -4), func(n: Node) -> void:
		(n as Safe).methods = [&"drill", &"saw"] as Array[StringName]
		(n as Safe).size = Safe.Size.LARGE) as Safe
	await wait_physics_frames(1)
	var by_size: float = safe.drill_duration()
	safe.drill_duration_s = 120.0
	safe.saw_duration_s = 90.0
	assert_eq(safe.drill_duration(), 120.0, "drill override")
	assert_eq(safe.saw_duration(), 90.0, "saw override")
	safe.drill_duration_s = -1.0
	assert_eq(safe.drill_duration(), by_size, "back to the size table")
