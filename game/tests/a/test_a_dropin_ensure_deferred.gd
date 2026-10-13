## HeistRuntime creates the host HeistDropIn service deferred (no "parent busy" add_child error at heist start).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_host_drop_in_service_exists_after_start() -> void:
	var old: Node = get_tree().root.get_node_or_null(NodePath(String(HeistDropIn.NODE_NAME)))
	if old != null:
		old.free()
	_rt = await HeistLauncher.launch(&"unit_map", 5, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false})
	await wait_frames(2)
	var svc: Node = get_tree().root.get_node_or_null(NodePath(String(HeistDropIn.NODE_NAME)))
	assert_true(svc is HeistDropIn, "host drop-in service under the root")
	assert_true(svc != null and svc.is_inside_tree(), "added (deferred)")
