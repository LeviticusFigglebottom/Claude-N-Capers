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
