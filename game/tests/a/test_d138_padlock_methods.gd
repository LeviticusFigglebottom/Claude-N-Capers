## D-138.2: padlock options. `place_saw_stealth` (the placed saw also in stealth, saw noise), `place_drill` +
## `drill_duration_s` (and its node-meta fallback), `place_c4` (fuse, blast, forced open), `allow_lockpick`, the
## method priority when several are allowed, and `beaten_by` / `lock_opened` (the mission's open_method).
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _noises: Array[StringName] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_noises.clear()
	_rt = await HeistLauncher.launch(&"unit_d138_padlock", 1382, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	for pair: Array in [[EventBus.device_started, &"device_started"], [EventBus.device_finished, &"device_finished"]]:
		var tag: StringName = pair[1]
		var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			_events.append([tag, a, b, c])
		(pair[0] as Signal).connect(cb)
		_conns.append([pair[0], cb])
	_rt.noise_made.connect(_on_noise)
	Modifiers.set_source(Modifiers.TEAM, &"test_d138", {&"interaction.device_jam_chance_mult": 0.0})
	await wait_physics_frames(2)


func after_each() -> void:
	Engine.time_scale = 1.0
	Modifiers.clear_source(Modifiers.TEAM, &"test_d138")
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_noise(_pos: Vector3, _radius: float, kind: StringName, _src: int) -> void:
	_noises.append(kind)


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _door_and_lock(x: float, setup: Callable) -> Array:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(x, 0, -6), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.LOCKPICK) as Door
	var lock: Padlock = ATestMaps.add_prefab(_rt, "padlock", Vector3(x, 1, -5.8), setup) as Padlock
	lock.targets = [lock.get_path_to(door)]
	await wait_physics_frames(1)
	return [door, lock]


func _use(p: GameplayPrefab, seconds: float) -> void:
	_crew().set_masked()
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)
	_rt.teleport_crew(0, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.2)


func _go_loud() -> void:
	EventBus.alarm_raised.emit(&"test", 0)
	await wait_physics_frames(1)


func test_stealth_saw_needs_place_saw_stealth() -> void:
	var plain: Array = await _door_and_lock(-4.0, func(p: GameplayPrefab) -> void:
		(p as Padlock).place_saw = true
		(p as Padlock).allow_lockpick = false)
	var lock0: Padlock = plain[1]
	_crew().set_masked()
	assert_ne(lock0.interactable.availability(_crew()), InteractableComponent.BLOCK_NONE,
		"stealth, no place_saw_stealth, no lockpick: nothing to do")
	var pair: Array = await _door_and_lock(0.0, func(p: GameplayPrefab) -> void:
		(p as Padlock).place_saw = true
		(p as Padlock).place_saw_stealth = true
		(p as Padlock).saw_duration_s = 2.0
		(p as Padlock).allow_lockpick = false)
	var door: Door = pair[0]
	var lock: Padlock = pair[1]
	assert_false(_rt.went_loud, "stealth")
	assert_eq(lock.interactable.availability(_crew()), InteractableComponent.BLOCK_NONE, "stealth saw allowed")
	assert_eq(lock.interactable.kind, &"place_saw", "place the saw in stealth")
	var methods: Array[StringName] = []
	lock.lock_opened.connect(func(m: StringName) -> void: methods.append(m))
	await _use(lock, Tweak.interaction().drill_place_s)
	assert_eq(lock.runner.state, DeviceRunner.State.RUNNING, "the saw runs")
	assert_eq(lock.runner.kind, &"saw")
	assert_true(lock.device_node != null, "the saw is shown")
	await wait_seconds(1.2)
	assert_true(_noises.has(&"saw"), "the saw's own noise while stealth")
	await wait_seconds(1.3)
	assert_true(lock.opened, "cut")
	assert_true(door.is_open, "target open")
	assert_eq(lock.beaten_by, &"saw", "open_method saw")
	assert_eq(methods, [&"saw"] as Array[StringName], "lock_opened(saw)")
	assert_true(lock.device_node == null, "saw removed when done")


func test_drill_runs_drill_duration_and_opens() -> void:
	var pair: Array = await _door_and_lock(3.0, func(p: GameplayPrefab) -> void:
		(p as Padlock).place_drill = true
		(p as Padlock).drill_duration_s = 2.0
		(p as Padlock).allow_lockpick = false)
	var door: Door = pair[0]
	var lock: Padlock = pair[1]
	_crew().set_masked()
	assert_eq(lock.interactable.availability(_crew()), InteractableComponent.BLOCK_NONE)
	assert_eq(lock.interactable.kind, &"place_drill", "place the drill")
	await _use(lock, Tweak.interaction().drill_place_s)
	var started: Array[Array] = _of(&"device_started")
	assert_eq(started.size(), 1, "drill placed")
	if started.is_empty():
		return
	assert_eq(started[0][2], &"drill")
	assert_near(float(started[0][3]), 2.0, 0.001, "drill_duration_s")
	assert_true(lock.device_node != null, "the drill device is shown")
	await wait_seconds(2.3)
	assert_true(lock.opened, "drilled")
	assert_true(door.is_open and not door.locked, "target opened")
	assert_eq(lock.beaten_by, &"drill", "open_method drill")
	assert_eq(_of(&"device_finished").size(), 1, "device_finished once")


func test_drill_duration_meta_fallback_and_default() -> void:
	var pair: Array = await _door_and_lock(6.0, func(p: GameplayPrefab) -> void:
		(p as Padlock).place_drill = true)
	var lock: Padlock = pair[1]
	assert_near(lock.effective_drill_duration(), Tweak.interaction().drill_duration_s, 0.001, "default drill time")
	lock.set_meta(&"drill_duration_s", 120.0)
	assert_near(lock.effective_drill_duration(), 120.0, 0.001, "meta fallback")
	lock.drill_duration_s = 30.0
	assert_near(lock.effective_drill_duration(), 30.0, 0.001, "the export wins")


func test_c4_opens_targets() -> void:
	var pair: Array = await _door_and_lock(9.0, func(p: GameplayPrefab) -> void:
		(p as Padlock).place_c4 = true
		(p as Padlock).allow_lockpick = false)
	var door: Door = pair[0]
	var lock: Padlock = pair[1]
	_crew().set_masked()
	assert_eq(lock.interactable.availability(_crew()), InteractableComponent.BLOCK_ITEM, "needs a charge")
	_crew().add_item(Safe.C4_ITEM, 1)
	assert_eq(lock.interactable.availability(_crew()), InteractableComponent.BLOCK_NONE)
	assert_eq(lock.interactable.kind, &"place_c4")
	assert_near(lock.interactable.duration_for(_crew()), Tweak.interaction().c4_place_s, 0.01, "c4_place_s")
	await _use(lock, Tweak.interaction().c4_place_s)
	assert_true(lock.c4_armed(), "armed")
	assert_eq(_crew().item_count(Safe.C4_ITEM), 0, "charge used")
	var started: Array[Array] = _of(&"device_started")
	assert_true(started.size() == 1 and started[0][2] == &"c4", "device_started c4")
	await wait_physics_frames(2)
	var row: bool = false
	for d: Dictionary in _rt.hud_model.devices:
		row = row or (int(d["net_id"]) == lock.net_id and StringName(d["kind"]) == &"c4")
	assert_true(row, "HUD c4 row")
	await wait_seconds(Tweak.interaction().c4_fuse_s + 0.3)
	assert_true(lock.opened, "blown")
	assert_true(door.is_open and not door.locked, "target opened")
	assert_eq(lock.beaten_by, &"c4", "open_method c4")
	assert_true(_noises.has(&"explosion"), "loud: explosion noise")
	assert_eq(_of(&"device_finished").size(), 1, "device_finished once")


func test_priority_and_allow_lockpick() -> void:
	var pair: Array = await _door_and_lock(12.0, func(p: GameplayPrefab) -> void:
		(p as Padlock).place_saw = true
		(p as Padlock).place_drill = true)
	var lock: Padlock = pair[1]
	_crew().set_masked()
	lock.interactable.availability(_crew())
	assert_eq(lock.interactable.kind, &"lockpick", "stealth: the quiet lockpick first")
	lock.allow_lockpick = false
	lock.interactable.availability(_crew())
	assert_eq(lock.interactable.kind, &"place_drill", "no lockpick: drill (saw not allowed in stealth)")
	await _go_loud()
	lock.allow_lockpick = true
	lock.interactable.availability(_crew())
	assert_eq(lock.interactable.kind, &"place_drill", "loud: devices first, drill before saw")
	lock.place_drill = false
	lock.interactable.availability(_crew())
	assert_eq(lock.interactable.kind, &"place_saw", "loud: saw")


func test_lockpick_and_forced_open_methods() -> void:
	var pair: Array = await _door_and_lock(15.0, func(_p: GameplayPrefab) -> void: pass)
	var lock: Padlock = pair[1]
	await _use(lock, lock.interactable.duration_for(_crew()))
	assert_true(lock.opened, "picked")
	assert_eq(lock.beaten_by, &"lockpick")
	var pair2: Array = await _door_and_lock(18.0, func(p: GameplayPrefab) -> void:
		(p as Padlock).place_saw = true)
	var lock2: Padlock = pair2[1]
	lock2.open_lock()
	assert_true(lock2.opened and (pair2[0] as Door).is_open, "open_lock() with no args opens the targets")
	assert_eq(lock2.beaten_by, &"forced")
