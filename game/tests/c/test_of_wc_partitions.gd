## Ostrander Federal LK cubicle partitions (OF-C2, ENV P r260 ghost run: a pilot stuck 60 s on WCPartitionLK2, the nav
## path ran through it). On the built map in a real HeistRuntime, a navmesh path from the west cubicle to the one east
## of WCPartitionLK2 (x 8.0, z 0.2-1.7, 5 cm thick) goes round the partition's open end: it crosses x 8.0 only at
## z > PARTITION_END_Z. The partitions are widened to two nav cells in the bake only (of_gameplay._box_row, _nav_thick).
## Owner: ENV C.
extends TestCase

const HEIST: StringName = &"ostrander_federal"
const SEED: int = 1002
const FROM: Vector3 = Vector3(7.25, -4.0, 0.5)
const TO: Vector3 = Vector3(8.5, -4.0, 0.5)
const PARTITION_X: float = 8.0
const PARTITION_END_Z: float = 1.7

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_cubicle_paths_go_round_the_partition() -> void:
	_rt = await HeistLauncher.launch(HEIST, SEED, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch %s" % HEIST)
		return
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "nav ready")
	var nav: RID = c.get_world_3d().navigation_map
	var a: Vector3 = NavigationServer3D.map_get_closest_point(nav, FROM)
	var b: Vector3 = NavigationServer3D.map_get_closest_point(nav, TO)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, a, b, true)
	assert_true(path.size() >= 2, "a path between the cubicles (%s -> %s)" % [a, b])
	for i: int in range(path.size() - 1):
		var p: Vector3 = path[i]
		var q: Vector3 = path[i + 1]
		if (p.x - PARTITION_X) * (q.x - PARTITION_X) < 0.0:
			var z: float = lerpf(p.z, q.z, (PARTITION_X - p.x) / (q.x - p.x))
			assert_true(z > PARTITION_END_Z, "the path crosses WCPartitionLK2's line at z %.2f (%s)" % [z, path])
