## A2-04 S9.10: laser grids (static / timed_off / sweeping) trip laser_tripped + the alarm, even
## for casing (unmasked) crew.
extends TestCase

var _rt: HeistRuntime = null
var _trips: Array[int] = []
var _alarms: Array[StringName] = []
var _conns: Array[Array] = []


func before_each() -> void:
	_trips.clear()
	_alarms.clear()
	_rt = await HeistLauncher.launch(&"unit_lasers", 1010, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	var a: Callable = func(id: int) -> void: _trips.append(id)
	var b: Callable = func(reason: StringName, _src: int) -> void: _alarms.append(reason)
	EventBus.laser_tripped.connect(a)
	EventBus.alarm_raised.connect(b)
	_conns = [[EventBus.laser_tripped, a], [EventBus.alarm_raised, b]]


func after_each() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _grid(pos: Vector3, pattern: StringName, setup: Callable = Callable()) -> LaserGrid:
	return ATestMaps.add_prefab(_rt, "laser_grid", pos, func(n: Node) -> void:
		(n as LaserGrid).pattern = pattern
		if setup.is_valid():
			setup.call(n)) as LaserGrid


func _put(pos: Vector3) -> void:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos))


func test_static_grid_trips_alarm_even_while_casing() -> void:
	var g: LaserGrid = _grid(Vector3(0, 0, -6), &"static")
	await wait_physics_frames(2)
	assert_eq(g.beam_areas.size(), 4, "one Area3D per beam")
	assert_true(g.beams_on())
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(c.is_casing(), "unmasked crew")
	_put(Vector3(0, 0.05, -6))
	var ok: bool = await wait_until(func() -> bool: return g.tripped, 1.0)
	assert_true(ok, "crew body trips the beams")
	assert_eq(_trips, [g.net_id] as Array[int], "laser_tripped(grid net_id) once")
	assert_has(_alarms, &"laser", "alarm_raised(&\"laser\")")
	assert_true(_rt.went_loud, "heist goes loud")
	# A second grid after the alarm stays quiet.
	var g2: LaserGrid = _grid(Vector3(6, 0, -6), &"static")
	await wait_physics_frames(2)
	_put(Vector3(6, 0.05, -6))
	await wait_physics_frames(4)
	assert_false(g2.tripped, "no trips once loud")
	assert_eq(_trips.size(), 1)


func test_timed_off_window_lets_crew_pass() -> void:
	var g: LaserGrid = _grid(Vector3(0, 0, -6), &"timed_off", func(n: Node) -> void:
		(n as LaserGrid).period_s = 2.0
		(n as LaserGrid).off_s = 1.0) as LaserGrid
	await wait_physics_frames(2)
	assert_true(g.beams_on(), "on at the start of a cycle")
	var off: bool = await wait_until(func() -> bool: return not g.beams_on(), 3.0)
	assert_true(off, "off window reached")
	_put(Vector3(0, 0.05, -6))
	await wait_physics_frames(6)
	assert_false(g.tripped, "beams off: crew stands in the grid unharmed")
	_put(Vector3(0, 0.05, -8))
	await wait_physics_frames(2)
	var on: bool = await wait_until(func() -> bool: return g.beams_on(), 3.0)
	assert_true(on, "beams back on")
	await wait_physics_frames(4)
	assert_false(g.tripped, "passed through during the window")
	assert_true(_trips.is_empty())
	_put(Vector3(0, 0.05, -6))
	var ok: bool = await wait_until(func() -> bool: return g.tripped, 1.0)
	assert_true(ok, "on: trips")
	assert_has(_alarms, &"laser")


func test_sweeping_beam_reaches_the_crew() -> void:
	var g: LaserGrid = _grid(Vector3(0, 0, -6), &"sweeping", func(n: Node) -> void:
		(n as LaserGrid).period_s = 4.0) as LaserGrid
	await wait_physics_frames(2)
	assert_eq(g.beam_areas.size(), 1, "sweep_beams = 1")
	var x0: float = g.beam_offset(0)
	assert_true(x0 < -0.5, "starts at the left edge (%.2f)" % x0)
	_put(Vector3(0.8, 0.05, -6))
	await wait_seconds(0.5)
	assert_false(g.tripped, "beam far from the crew")
	assert_true(g.beam_offset(0) > x0, "beam moves across")
	var ok: bool = await wait_until(func() -> bool: return g.tripped, 3.0)
	assert_true(ok, "sweeping beam reaches the crew")
	assert_eq(_trips.size(), 1)


## D-103 §6 / QC-53: a grid can start off (enabled_at_start false) and the mission switches it with set_enabled
## (Gallery Night's landing curtain at last call). Off = no beams, the crew walks through; on = it trips.
func test_gn_set_enabled_switches_a_grid_off_and_on() -> void:
	var g: LaserGrid = _grid(Vector3(0, 0, -6), &"static", func(n: Node) -> void:
		(n as LaserGrid).enabled_at_start = false)
	await wait_physics_frames(2)
	assert_false(g.active or g.beams_on(), "starts switched off")
	_put(Vector3(0, 0.05, -6))
	await wait_physics_frames(6)
	assert_false(g.tripped, "walking through a switched-off grid trips nothing")
	_put(Vector3(0, 0.05, -2))
	await wait_physics_frames(2)
	g.set_enabled(true)
	assert_true(g.active and g.beams_on(), "switched on")
	var state: Dictionary = NetEntityCodec.state_of(g)
	assert_true(bool(state.get("active", false)), "replicated as `active`")
	_put(Vector3(0, 0.05, -6))
	var ok: bool = await wait_until(func() -> bool: return g.tripped, 1.0)
	assert_true(ok, "the switched-on grid trips")
	assert_has(_alarms, &"laser", "alarm_raised(&\"laser\")")


## LEAD r314 (C 10f91e29: AH's slots wrote "sweep" / "timed", which LaserGrid silently ran as static grids): an unknown
## pattern is a logged error naming it, not a silent fallback; the three known ones are not.
func test_r314_unknown_pattern_is_an_error() -> void:
	Log.capture = true
	Log.captured.clear()
	_grid(Vector3(0, 0, -6), &"sweep")
	for p: StringName in LaserGrid.PATTERNS:
		_grid(Vector3(4, 0, -6), p)
	await wait_physics_frames(2)
	Log.capture = false
	var errs: Array = Log.captured.filter(func(l: String) -> bool: return l.begins_with("[ERROR]") and l.contains("laser pattern"))
	assert_eq(errs.size(), 1, "one error, for 'sweep' only: %s" % [errs])
	assert_true(errs.size() == 1 and String(errs[0]).contains("'sweep'"), "the error names the bad pattern")
