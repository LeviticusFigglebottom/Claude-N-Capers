## ND loud FrameProf (attempt 22): the first spawn of each unit type loaded its scene and character on the main
## thread (3-10 s frames windowed). The director queues a background load of every NPC scene and character its
## spawn tables can use when it starts; spawning then finds them cached.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_director_prewarms_spawnable_scenes_in_the_background() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 2201, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(dir != null, "director")
	var paths: PackedStringArray = dir._warm_paths.duplicate()
	assert_true(await wait_until(func() -> bool:
		for p: String in paths:
			if ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return false
		return true, 30.0), "background loads finish (%d queued)" % paths.size())
	for p: String in paths:
		assert_true(ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_FAILED, "%s loaded" % p)
	var bulwark: EnemyDef = dir.enemy_def_for(&"enemy.bulwark")
	if bulwark != null:
		for p: String in NpcVisuals.def_scene_paths(bulwark):
			assert_true(ResourceLoader.has_cached(p) or paths.has(p), "bulwark character warmed: %s" % p)
	assert_true(dir._prewarm() == 0, "a second call queues nothing (everything cached)")
	dir._exit_tree()
	for p: String in paths:
		assert_eq(ResourceLoader.load_threaded_get_status(p), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
			"collected on exit: %s" % p)
