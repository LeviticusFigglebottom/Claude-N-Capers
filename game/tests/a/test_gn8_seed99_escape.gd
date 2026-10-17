## GN-8: Gallery Night seed 99 crashed (signal 11) at LOUD -> ESCAPE in a windowed pilot run (threaded loads: the
## director's prewarm overlapping main-thread loads; fixed by WarmLoader + a prewarm collected at heist start). The
## windowed pilot keeps losing to custody before the escape, so this drives the same transition headless: seed 99, the
## alarm, assault waves spawning, then the escape opens while the director keeps spawning. No crash, phase ESCAPE.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_gn8_seed99_loud_to_escape() -> void:
	_rt = await HeistLauncher.launch(&"gallery_night", 99, Enums.Difficulty.ROUTINE, self, {"crew_ai": false})
	assert_true(_rt != null, "launched")
	await wait_physics_frames(3)
	for s: int in _rt.crew_members().size():
		Modifiers.set_source(s, &"gn8.immune", {&"defense.damage_taken_mult": 0.0})
	assert_eq(WarmLoader.pending_count(), 0, "no background load running into gameplay")
	_rt.stealth.raise_alarm(&"test", 0)
	Engine.time_scale = 4.0
	await wait_seconds(20.0)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(dir != null and dir.alive_units().size() > 0, "assault units spawned before the escape")
	_rt.mission.call(&"_open_escape")
	await wait_seconds(10.0)
	Engine.time_scale = 1.0
	assert_eq(_rt.phase, Enums.HeistPhase.ESCAPE, "LOUD -> ESCAPE")
	assert_eq(WarmLoader.pending_count(), 0, "still no background load")
	for s: int in _rt.crew_members().size():
		Modifiers.clear_source(s, &"gn8.immune")
