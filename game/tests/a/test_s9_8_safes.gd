## A2-04 S9.8: safe methods (drill / saw / c4 / lockpick / code), time locks, size -> duration.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _noises: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_noises.clear()
	_rt = await HeistLauncher.launch(&"unit_safes", 808, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	for pair: Array in [
		[EventBus.device_started, &"device_started"], [EventBus.device_finished, &"device_finished"],
		[EventBus.audio_cue_requested, &"audio_cue_requested"],
	]:
		var tag: StringName = pair[1]
		var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			_events.append([tag, a, b, c])
		(pair[0] as Signal).connect(cb)
		_conns.append([pair[0], cb])
	_rt.noise_made.connect(func(p: Vector3, r: float, k: StringName, s: int) -> void: _noises.append([p, r, k, s]))


func after_each() -> void:
	Engine.time_scale = 1.0
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


func _crew() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _safe(pos: Vector3, methods: Array[StringName], size: Safe.Size = Safe.Size.MEDIUM, extra: Callable = Callable()) -> Safe:
	return ATestMaps.add_prefab(_rt, "safe", pos, func(n: Node) -> void:
		var s: Safe = n as Safe
		s.methods = methods
		s.size = size
		if extra.is_valid():
			extra.call(s)) as Safe


func _use(p: GameplayPrefab, seconds: float) -> void:
	_crew()
	_rt.teleport_crew(0, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.15)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)


func test_methods_gate_lockpick_code_c4_drill() -> void:
	var c: CrewController = _crew()
	var medium_pick: Safe = _safe(Vector3(-6, 0, -6), [&"lockpick"], Safe.Size.MEDIUM)
	var small_pick: Safe = _safe(Vector3(-3, 0, -6), [&"lockpick"], Safe.Size.SMALL)
	var code_safe: Safe = _safe(Vector3(0, 0, -6), [&"code"], Safe.Size.MEDIUM, func(s: Safe) -> void: s.code_group = &"s1")
	var c4_safe: Safe = _safe(Vector3(3, 0, -6), [&"c4"])
	var mixed: Safe = _safe(Vector3(6, 0, -6), [&"drill", &"lockpick"], Safe.Size.SMALL)
	var none: Safe = _safe(Vector3(9, 0, -6), [])
	await wait_physics_frames(2)
	assert_false(none.interactable.enabled, "no methods: only drill_point / mission")
	# Lockpick: skill + SMALL only.
	assert_eq(small_pick.interactable.availability(c), InteractableComponent.BLOCK_STATE, "lockpick needs the skill")
	assert_eq(mixed.method_for(c), &"drill", "without the skill the drill is offered")
	Modifiers.set_source(Modifiers.TEAM, &"test", {&"interaction.can_lockpick_safes": true})
	assert_eq(medium_pick.interactable.availability(c), InteractableComponent.BLOCK_STATE, "SMALL safes only")
	assert_eq(small_pick.interactable.availability(c), InteractableComponent.BLOCK_NONE)
	assert_eq(small_pick.interactable.kind, &"lockpick")
	assert_eq(mixed.method_for(c), &"lockpick", "silent lockpick preferred over the drill")
	assert_near(small_pick.interactable.duration_for(c), Tweak.interaction().safe_lockpick_s, 0.001)
	await _use(small_pick, Tweak.interaction().safe_lockpick_s)
	assert_true(small_pick.opened, "lockpicked")
	assert_eq(small_pick.beaten_by, &"lockpick")
	# Code.
	assert_eq(code_safe.interactable.availability(c), CodeRegistry.BLOCK_CODE_UNKNOWN, "code unknown")
	CodeRegistry.of(_rt).reveal(&"s1", 0)
	assert_eq(code_safe.interactable.availability(c), InteractableComponent.BLOCK_NONE)
	assert_eq(code_safe.interactable.kind, &"enter_code")
	await _use(code_safe, Tweak.interaction().keypad_s)
	assert_true(code_safe.opened, "opened with the code")
	# C4: needs the item, consumes it, blows after the fuse.
	assert_eq(c4_safe.interactable.availability(c), InteractableComponent.BLOCK_ITEM, "no C4")
	c.add_item(Safe.C4_ITEM, 1)
	assert_eq(c4_safe.method_for(c), &"c4")
	await _use(c4_safe, Tweak.interaction().c4_place_s)
	assert_eq(c.item_count(Safe.C4_ITEM), 0, "C4 consumed")
	assert_eq(c4_safe.stage, Safe.Stage.C4_ARMED, "armed")
	assert_false(c4_safe.opened, "not yet")
	Engine.time_scale = 4.0
	var ok: bool = await wait_until(func() -> bool: return c4_safe.opened, Tweak.interaction().c4_fuse_s + 2.0)
	Engine.time_scale = 1.0
	assert_true(ok, "C4 blew the door")
	var boom: int = 0
	for e: Array in _noises:
		if e[2] == &"explosion":
			boom += 1
			assert_near(float(e[1]), Tweak.interaction().c4_noise_radius_m, 0.001)
	assert_eq(boom, 1, "explosion noise")
	var cues: Array[StringName] = []
	for e: Array in _of(&"audio_cue_requested"):
		cues.append(e[1])
	assert_has(cues, &"cue.c4_explode")


func test_time_lock_delays_opening() -> void:
	var tl: float = 2.0
	var safe: Safe = _safe(Vector3(0, 0, -6), [&"code"], Safe.Size.LARGE, func(s: Safe) -> void:
		s.code_group = &"vault"
		s.time_lock_s = tl
		var sl: SmallLoot = (load("res://systems/prefabs/small_loot/small_loot.tscn") as PackedScene).instantiate() as SmallLoot
		sl.name = "Cash"
		sl.position = Vector3(0, 0.5, 0)
		s.add_child(sl))
	await wait_physics_frames(2)
	var cash: SmallLoot = safe.get_node(^"Cash") as SmallLoot
	CodeRegistry.of(_rt).reveal(&"vault", 0)
	await _use(safe, Tweak.interaction().keypad_s)
	assert_false(safe.opened, "time lock: not open after the code")
	assert_eq(safe.stage, Safe.Stage.TIME_LOCK)
	assert_eq(safe.interactable.availability(_crew()), InteractableComponent.BLOCK_NONE)
	assert_eq(safe.interactable.kind, &"start_time_lock")
	assert_false(cash.interactable.enabled, "loot still locked")
	# An interrupted start hold does nothing.
	await _use(safe, Tweak.interaction().time_lock_start_s * 0.3)
	assert_eq(safe.stage, Safe.Stage.TIME_LOCK, "interrupted: start again")
	await _use(safe, Tweak.interaction().time_lock_start_s)
	assert_eq(safe.stage, Safe.Stage.TIME_LOCK_RUNNING, "timer running")
	var started: Array[Array] = _of(&"device_started")
	assert_eq(started.size(), 1, "device_started for the time lock")
	if not started.is_empty():
		assert_eq(started[0][2], &"time_lock")
		assert_near(float(started[0][3]), tl, 0.001)
	assert_eq(safe.interactable.availability(_crew()), InteractableComponent.BLOCK_STATE, "nothing to do while it runs")
	await wait_seconds(tl * 0.5)
	assert_false(safe.opened, "still waiting")
	var ok: bool = await wait_until(func() -> bool: return safe.opened, tl + 1.0)
	assert_true(ok, "door swings after time_lock_s")
	assert_eq(_of(&"device_finished").size(), 1)
	assert_true(cash.interactable.enabled, "loot usable")
	assert_true(absf((safe.visual_node("Door") as Node3D).rotation.y) > 1.0, "door swung")


func test_drill_finish_with_time_lock_and_size_durations() -> void:
	var tw: InteractionTweak = Tweak.interaction()
	var s: Safe = _safe(Vector3(-4, 0, -6), [&"drill"], Safe.Size.SMALL)
	var m: Safe = _safe(Vector3(0, 0, -6), [&"drill"], Safe.Size.MEDIUM)
	var l: Safe = _safe(Vector3(4, 0, -6), [&"saw"], Safe.Size.LARGE, func(x: Safe) -> void: x.time_lock_s = 1.0)
	await wait_physics_frames(2)
	assert_near(s.drill_duration(), tw.safe_drill_duration_s[0], 0.001, "SMALL")
	assert_near(m.drill_duration(), tw.safe_drill_duration_s[1], 0.001, "MEDIUM")
	assert_near(l.saw_duration(), tw.safe_saw_duration_s[2], 0.001, "LARGE saw")
	assert_true(s.drill_duration() < m.drill_duration(), "bigger safe -> longer")
	assert_eq(l.method_for(_crew()), &"saw")
	assert_eq(l.runner.kind, &"saw")
	await _use(m, tw.drill_place_s)
	var started: Array[Array] = _of(&"device_started")
	assert_eq(started.size(), 1, "drill placed")
	if not started.is_empty():
		assert_eq(started[0][2], &"drill")
		assert_near(float(started[0][3]), tw.safe_drill_duration_s[1], 0.001, "duration by size")
	# A finished device on a time-locked safe arms the time lock instead of opening.
	l.open_by_device()
	assert_false(l.opened)
	assert_eq(l.stage, Safe.Stage.TIME_LOCK)
	l.swing_open()
	assert_true(l.opened, "missions can force it")


## S9.5 / A5-03: charges_required C4 items, or trip mines as shaped charges with interaction.shaped_charge.
func test_s9_5_charges_required_c4_or_shaped_charges() -> void:
	var c: CrewController = _crew()
	var safe: Safe = _safe(Vector3(3, 0, -6), [&"c4"], Safe.Size.MEDIUM, func(s: Safe) -> void: s.charges_required = 2)
	await wait_physics_frames(2)
	c.add_item(Safe.C4_ITEM, 1)
	assert_eq(safe.interactable.availability(c), InteractableComponent.BLOCK_ITEM, "1 C4 < 2 required")
	var dep: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	dep.give(c.slot, &"deployable.trip_mine")
	assert_eq(dep.count_of_kind(c.slot, &"trip_mine"), 3, "3 base trip mines")
	assert_eq(safe.charge_source(c), &"", "trip mines need interaction.shaped_charge")
	Modifiers.set_source(c.slot, &"test", {&"interaction.shaped_charge": true})
	assert_eq(safe.charge_source(c), &"shaped")
	assert_eq(safe.interactable.availability(c), InteractableComponent.BLOCK_NONE)
	await _use(safe, Tweak.interaction().c4_place_s)
	assert_eq(safe.stage, Safe.Stage.C4_ARMED, "shaped charges armed")
	assert_eq(dep.count_of_kind(c.slot, &"trip_mine"), 1, "2 trip mines spent")
	assert_eq(c.item_count(Safe.C4_ITEM), 1, "C4 untouched")
