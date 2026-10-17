## GN-8: the signal-11 crash at LOUD -> ESCAPE (Gallery Night seed 99; the crash handler ran on a worker thread).
## The director's prewarm left threaded loads in flight / uncollected while spawning load()ed the same scenes on the
## main thread. WarmLoader: a main-thread load never runs beside a background load (collected first), finished loads
## are collected at once and held, and teardown collects what is left.
extends TestCase

const CHAR_DIR: String = "res://world/characters/"

var _rt: HeistRuntime = null


func after_each() -> void:
	WarmLoader.release()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## Up to `n` character scenes nobody has loaded yet in this test process (so a threaded request really runs).
func _uncached(n: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for d: String in DirAccess.get_directories_at(CHAR_DIR):
		if d.begins_with("_"):
			continue
		var p: String = "%s%s/%s.tscn" % [CHAR_DIR, d, d]
		if ResourceLoader.exists(p) and not ResourceLoader.has_cached(p):
			out.append(p)
			if out.size() >= n:
				break
	return out


func test_gn8_sync_load_right_after_a_threaded_request_waits_for_it() -> void:
	var paths: PackedStringArray = _uncached(3)
	if paths.is_empty():
		skip("every character scene is already cached in this process")
		return
	for p: String in paths:
		assert_true(WarmLoader.request(p), "queued %s" % p)
		assert_false(WarmLoader.request(p), "not queued twice")
	# The spawn path: the same scene at once on the main thread (the GN-8 race). It must collect, not race.
	var ps: PackedScene = WarmLoader.get_or_load(paths[0]) as PackedScene
	assert_true(ps != null, "the scene comes back")
	assert_eq(WarmLoader.pending_count(), 0, "every background load collected before the sync load")
	for p: String in paths:
		assert_eq(ResourceLoader.load_threaded_get_status(p), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
			"nothing left uncollected in ResourceLoader: %s" % p)
		assert_true(ResourceLoader.has_cached(p), "held, so it stays cached: %s" % p)
	var npc: Node = ps.instantiate()
	assert_true(npc != null, "instantiates")
	npc.free()


func test_gn8_poll_collects_finished_loads_and_release_drops_the_holds() -> void:
	var paths: PackedStringArray = _uncached(2)
	if paths.is_empty():
		skip("every character scene is already cached in this process")
		return
	for p: String in paths:
		WarmLoader.request(p)
	assert_true(await wait_until(func() -> bool: return WarmLoader.poll() == 0, 30.0), "poll collects them all")
	for p: String in paths:
		assert_true(WarmLoader.is_held(p), "held: %s" % p)
		assert_eq(ResourceLoader.load_threaded_get_status(p), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
			"collected: %s" % p)
	assert_true(WarmLoader.get_or_load(paths[0]) != null, "served from the hold")
	WarmLoader.release()
	for p: String in paths:
		assert_false(WarmLoader.is_held(p), "released: %s" % p)


func test_gn8_release_mid_load_collects_everything() -> void:
	var paths: PackedStringArray = _uncached(2)
	if paths.is_empty():
		skip("every character scene is already cached in this process")
		return
	for p: String in paths:
		WarmLoader.request(p)
	WarmLoader.release()  # teardown straight after the request (a heist left at once)
	assert_eq(WarmLoader.pending_count(), 0, "nothing in flight after teardown")
	for p: String in paths:
		assert_eq(ResourceLoader.load_threaded_get_status(p), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
			"collected: %s" % p)


## The director path: prewarm, then the first spawn on the same frame (loud at load) never runs beside the loads,
## and teardown leaves nothing in flight.
func test_gn8_director_prewarm_then_immediate_spawn() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 2201, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(dir != null, "director")
	if dir == null:
		return
	dir._warm_paths.clear()
	WarmLoader.release()
	var queued: int = dir._prewarm()
	var paths: PackedStringArray = dir._warm_paths.duplicate()
	var npc: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis(), Vector3(0, 0, 3)))
	assert_true(npc != null, "spawned")
	assert_eq(WarmLoader.pending_count(), 0, "the spawn collected the %d prewarm loads first" % queued)
	for p: String in paths:
		assert_eq(ResourceLoader.load_threaded_get_status(p), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
			"collected: %s" % p)
	dir._exit_tree()
	assert_eq(WarmLoader.pending_count(), 0, "nothing in flight after the director leaves")
