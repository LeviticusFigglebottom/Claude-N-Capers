## LEAD r287 (C's metal_reflection sweep): HeistLauncher renders every UPDATE_ONCE ReflectionProbe of the map before
## launch() returns, so no metal reads dark on a probe's first view. HeistRuntime enters CASING inside start(), before
## a frame can be drawn, so the hand-over point is launch() returning (the menu gives control after it). Headless draws
## nothing and skips the warm-up unless options.probe_prewarm forces it, as here.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _add_probes(rt: HeistRuntime) -> Node:
	for i: int in 5:
		var p: ReflectionProbe = ReflectionProbe.new()
		p.name = "TestProbe%d" % i
		p.size = Vector3(6, 4, 6)
		rt.map.add_child(p)
		p.position = Vector3(i * 8.0 - 16.0, 2.0, -10.0)
	var always: ReflectionProbe = ReflectionProbe.new()
	always.name = "AlwaysProbe"
	always.update_mode = ReflectionProbe.UPDATE_ALWAYS
	rt.map.add_child(always)
	return null


func test_every_probe_warmed_before_launch_returns() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "probe_prewarm": true, "extra_services": [_add_probes]})
	assert_true(_rt != null, "launched")
	assert_eq(_rt.phase, Enums.HeistPhase.CASING, "the heist is in CASING when it is handed over")
	var once: Array[ReflectionProbe] = ProbeWarmup.probes(_rt.map)
	assert_eq(once.size(), 5, "five UPDATE_ONCE probes (back in their mode)")
	for p: ReflectionProbe in once:
		assert_true(bool(p.get_meta(ProbeWarmup.META_WARMED, false)), "%s rendered during loading" % p.name)
	var always: ReflectionProbe = _rt.map.get_node(^"AlwaysProbe") as ReflectionProbe
	assert_eq(always.update_mode, ReflectionProbe.UPDATE_ALWAYS, "an UPDATE_ALWAYS probe is left alone")
	assert_false(always.has_meta(ProbeWarmup.META_WARMED), "and needs no warm-up")
	assert_true(_rt.map.get_node_or_null(^"ProbeWarmup") == null or _rt.map.get_node(^"ProbeWarmup").is_queued_for_deletion(),
		"the warm-up viewport is gone")


func test_real_map_probes_all_warmed() -> void:
	var path: String = HeistLauncher.map_path(&"glasshouse", {})
	if path == "" or not ResourceLoader.exists(path):
		skip("glasshouse not on this branch")
		return
	_rt = await HeistLauncher.launch(&"glasshouse", 7, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "probe_prewarm": true})
	var list: Array[ReflectionProbe] = ProbeWarmup.probes(_rt.map)
	assert_true(list.size() >= 10, "Glasshouse has its probes (%d)" % list.size())
	var cold: Array[String] = []
	for p: ReflectionProbe in list:
		if not bool(p.get_meta(ProbeWarmup.META_WARMED, false)):
			cold.append(String(p.name))
	assert_eq(cold, [] as Array[String], "every probe rendered before the hand-over")


func test_headless_default_skips() -> void:
	assert_eq(ProbeWarmup.wanted({}), DisplayServer.get_name() != "headless", "rendering peers only by default")
	assert_true(ProbeWarmup.wanted({"probe_prewarm": true}), "forced by the option")
