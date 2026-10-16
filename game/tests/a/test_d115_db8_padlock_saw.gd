## D-115 DB-8 (S9.4): a padlock with `place_saw` takes a placed saw once loud (DeviceRunner kind &"saw": per-padlock
## saw_duration_s, PD2 jams and fix, device facts and the HUD device row); still lockpicked in stealth; the handheld
## saw still cuts it. A padlock without place_saw is unchanged.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_padlock_saw", 815, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	for pair: Array in [[EventBus.device_started, &"device_started"], [EventBus.device_finished, &"device_finished"],
			[EventBus.device_jammed, &"device_jammed"], [EventBus.device_restarted, &"device_restarted"]]:
		var tag: StringName = pair[1]
		var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			_events.append([tag, a, b, c])
		(pair[0] as Signal).connect(cb)
		_conns.append([pair[0], cb])
	Modifiers.set_source(Modifiers.TEAM, &"test_db8", {&"interaction.device_jam_chance_mult": 0.0})
	await wait_physics_frames(2)


func after_each() -> void:
	Engine.time_scale = 1.0
	Modifiers.clear_source(Modifiers.TEAM, &"test_db8")
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _door_and_lock(x: float, setup: Callable = Callable()) -> Array:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(x, 0, -6), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.LOCKPICK) as Door
	var lock: Padlock = ATestMaps.add_prefab(_rt, "padlock", Vector3(x, 1, -5.8), setup) as Padlock
	lock.targets = [lock.get_path_to(door)]
	await wait_physics_frames(1)
	return [door, lock]


func _go_loud() -> void:
	EventBus.alarm_raised.emit(&"test", 0)
	await wait_physics_frames(1)
	assert_true(_rt.went_loud, "loud")


func _use(p: GameplayPrefab, seconds: float) -> void:
	(_rt.crew_controller(0) as CrewController).set_masked()
	_rt.set_bot_intent(0, CrewIntent.new())  # release a previous hold first
	await wait_physics_frames(2)
	_rt.teleport_crew(0, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.2)


func _saw_lock(duration: float) -> Callable:
	return func(p: GameplayPrefab) -> void:
		(p as Padlock).place_saw = true
		(p as Padlock).saw_duration_s = duration


func test_db8_stealth_lockpick_loud_placed_saw() -> void:
	var pair: Array = await _door_and_lock(0.0, _saw_lock(2.0))
	var door: Door = pair[0]
	var lock: Padlock = pair[1]
	assert_true(lock.runner != null and lock.runner.kind == &"saw", "a saw runner")
	(_rt.crew_controller(0) as CrewController).set_masked()
	assert_eq(lock.interactable.availability(_rt.crew_controller(0)), InteractableComponent.BLOCK_NONE)
	assert_eq(lock.interactable.kind, &"lockpick", "stealth: still picked by hand")
	await _go_loud()
	lock.interactable.availability(_rt.crew_controller(0))
	assert_eq(lock.interactable.kind, &"place_saw", "loud: place the saw")
	assert_near(lock.interactable.duration_for(_rt.crew_controller(0)), Tweak.interaction().drill_place_s, 0.01,
		"placing takes drill_place_s")
	await _use(lock, Tweak.interaction().drill_place_s)
	var started: Array[Array] = _of(&"device_started")
	assert_eq(started.size(), 1, "saw placed")
	if started.is_empty():
		return
	assert_eq(int(started[0][1]), lock.net_id)
	assert_eq(started[0][2], &"saw")
	assert_near(float(started[0][3]), 2.0, 0.001, "the padlock's saw_duration_s")
	assert_false(lock.opened, "not cut yet")
	assert_false(lock.interactable.enabled, "nothing to do while it runs")
	if ResourceLoader.exists(G.PROPS_DIR + DrillPoint.DEFAULT_SAW):
		assert_true(lock.device_node != null and lock.device_node.get_parent() == lock, "the saw device is shown")
	await wait_physics_frames(2)
	var row: Dictionary = {}
	for d: Dictionary in _rt.hud_model.devices:
		if int(d["net_id"]) == lock.net_id:
			row = d
	assert_eq(StringName(row.get("kind", &"")), &"saw", "HUD device row for the padlock saw")
	await wait_seconds(2.3)
	assert_true(lock.opened, "the placed saw cut it")
	assert_eq(_of(&"device_finished").size(), 1, "device_finished once")
	assert_false(door.locked, "target unlocked")
	assert_true(door.is_open, "and opened")
	assert_true(lock.device_node == null, "the saw is removed when done")


func test_db8_default_duration_and_jam_fix() -> void:
	Modifiers.set_source(Modifiers.TEAM, &"test_db8", {&"interaction.device_jam_chance_mult": 1.0,
		&"interaction.device_auto_restart_chance": -1.0})
	var pair: Array = await _door_and_lock(3.0, _saw_lock(-1.0))
	var lock: Padlock = pair[1]
	assert_near(lock.effective_saw_duration(), Tweak.interaction().padlock_saw_duration_s, 0.001, "default saw time")
	await _go_loud()
	lock.interactable.availability(_rt.crew_controller(0))
	await _use(lock, Tweak.interaction().drill_place_s)
	assert_eq(_of(&"device_started").size(), 1, "placed")
	lock.runner.progress = lock.runner.jams[0] - 0.0001 if not lock.runner.jams.is_empty() else 0.0
	assert_false(lock.runner.jams.is_empty(), "jams rolled (jam chance 1)")
	await wait_physics_frames(3)
	assert_eq(lock.runner.state, DeviceRunner.State.JAMMED, "jammed")
	assert_eq(_of(&"device_jammed").size(), 1, "device_jammed")
	assert_true(lock.interactable.enabled, "fix offered")
	lock.interactable.availability(_rt.crew_controller(0))
	assert_eq(lock.interactable.kind, &"fix_drill", "fix the saw")
	await _use(lock, Tweak.interaction().drill_fix_s)
	assert_eq(lock.runner.state, DeviceRunner.State.RUNNING, "fixed: running again")
	assert_eq(_of(&"device_restarted").size(), 1, "device_restarted")


func test_db8_hand_saw_still_cuts_and_stops_the_placed_saw() -> void:
	var pair: Array = await _door_and_lock(-3.0, _saw_lock(30.0))
	var lock: Padlock = pair[1]
	await _go_loud()
	lock.interactable.availability(_rt.crew_controller(0))
	await _use(lock, Tweak.interaction().drill_place_s)
	assert_eq(lock.runner.state, DeviceRunner.State.RUNNING, "placed saw runs")
	for i: int in range(int(ceil(Tweak.interaction().hand_saw_padlock_s / 0.5))):
		lock.saw_cut(0.5, 0)
	assert_true(lock.opened, "the handheld saw cut it")
	assert_eq(lock.runner.state, DeviceRunner.State.DONE, "the placed saw stopped")
	assert_eq(_of(&"device_finished").size(), 1, "its loop stops (device_finished)")


func test_db8_plain_padlock_unchanged_when_loud() -> void:
	var pair: Array = await _door_and_lock(6.0)
	var lock: Padlock = pair[1]
	assert_true(lock.runner == null, "no placed saw without place_saw")
	await _go_loud()
	lock.interactable.availability(_rt.crew_controller(0))
	assert_eq(lock.interactable.kind, &"lockpick", "still a lockpick")
	await _use(lock, lock.interactable.duration_for(_rt.crew_controller(0)))
	assert_true(lock.opened, "picked")
	assert_true(_of(&"device_started").is_empty(), "no device")
