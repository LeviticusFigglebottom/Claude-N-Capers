## QC-35 (D-064): HeistMission.police_delay_s holds the AssaultDirector after the heist goes loud (Dockside
## Burn's cartel phase); 0 starts the police at once (police tipped); no hold = the usual start.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> AssaultDirector:
	_rt = await HeistLauncher.launch(&"unit_map", 3501, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false})
	await wait_physics_frames(2)
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


func test_no_hold_starts_on_loud() -> void:
	var d: AssaultDirector = await _launch()
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(2)
	assert_true(d.running, "the director starts once loud")


func test_hold_then_start_after_delay() -> void:
	var d: AssaultDirector = await _launch()
	d.start_delay_s = 0.5  # what HeistMission.police_delay_s forwards to
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	assert_false(d.running, "held")
	assert_true(d.start_delay_s > 0.0 and d.start_delay_s < 0.5, "counting down (%.2f)" % d.start_delay_s)
	await wait_seconds(0.6)
	assert_true(d.running, "started after the delay")
	assert_eq(d.assault_phase, Enums.AssaultPhase.CONTROL)


func test_zero_while_held_starts_now() -> void:
	var d: AssaultDirector = await _launch()
	d.start_delay_s = 60.0
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	assert_false(d.running, "held for the cartel phase")
	d.start_delay_s = 0.0
	assert_true(d.running, "police tipped off: start at once")


func test_mission_property_forwards() -> void:
	var d: AssaultDirector = await _launch()
	var m: HeistMission = HeistMission.new()
	_rt.add_child(m)
	m._bind(_rt)
	m.police_delay_s = 90.0
	assert_near(d.start_delay_s, 90.0, 0.001, "HeistMission.police_delay_s -> AssaultDirector.start_delay_s")
	assert_near(m.police_delay_s, 90.0, 0.001, "reads back")
	m._unbind()
	m.queue_free()
