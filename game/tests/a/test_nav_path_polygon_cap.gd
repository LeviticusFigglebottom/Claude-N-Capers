## LEAD / C (OF loud: 1,498 "It's not expect to not find the most reachable polygons"): Godot 4.7 cancels a path search
## after 4096 polygons and OF's navmesh has 4,165. NavPath.query lifts the cap; C's repro is the police spawn P1 (street)
## to CoverMisc7 on the executive terrace. NpcMotor's agents get the same (NavPath.configure_agent). Evidence: test_x4_of_loud
## logged that error 357 times before (crew_ai_brain path queries after the burn-through) and 0 with NavPath.
extends TestCase

const MAP_PATH: String = "res://world/heists/ostrander_federal/ostrander_federal.tscn"
const P1: Vector3 = Vector3(-30.0, -0.75, 55.0)
const COVER_MISC7: Vector3 = Vector3(44.0, 8.6, 32.6)

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_of_long_path_reaches_the_terrace() -> void:
	if not ResourceLoader.exists(MAP_PATH):
		skip("no ostrander_federal map")
		return
	_rt = await HeistLauncher.launch(&"ostrander_federal", 5, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "OF launched")
	if _rt == null:
		return
	await wait_physics_frames(5)
	var map: RID = _rt.map.get_world_3d().navigation_map
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(map, COVER_MISC7)
	var path: PackedVector3Array = NavPath.query(map, P1, goal, true, 1)
	assert_true(path.size() > 1, "a path from P1 to CoverMisc7")
	if path.size() > 1:
		assert_true(path[path.size() - 1].distance_to(goal) < 1.0, "it reaches the terrace (ends %s, goal %s)"
			% [path[path.size() - 1], goal])
		assert_true(absf(path[path.size() - 1].y - COVER_MISC7.y) < 1.0, "on the terrace floor (y %.1f)"
			% path[path.size() - 1].y)


func test_agents_search_without_the_cap() -> void:
	var agent: NavigationAgent3D = NavigationAgent3D.new()
	NavPath.configure_agent(agent)
	assert_eq(agent.path_search_max_polygons, NavPath.MAX_POLYGONS, "agent search cap lifted")
	agent.free()
