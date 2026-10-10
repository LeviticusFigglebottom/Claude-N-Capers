## A2-04 S9.4: placed saws share the DeviceRunner path (drill_point.device = SAW, safes listing
## `saw`): saw duration, saw noise (StealthTweak.saw_radius_m) and the S4.1 `saw` stimulus (10 m).
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _noises: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_noises.clear()
	_rt = await HeistLauncher.launch(&"unit_saws", 404, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	for pair: Array in [[EventBus.device_started, &"device_started"], [EventBus.device_finished, &"device_finished"]]:
		var tag: StringName = pair[1]
		var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			_events.append([tag, a, b, c])
		(pair[0] as Signal).connect(cb)
		_conns.append([pair[0], cb])
	_rt.noise_made.connect(func(p: Vector3, r: float, k: StringName, s: int) -> void: _noises.append([p, r, k, s]))
	Modifiers.set_source(Modifiers.TEAM, &"test", {&"interaction.device_jam_chance_mult": 0.0})


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


func _stim_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Dictionary in (_rt.service(G.SVC_STEALTH) as StealthDirector).stimuli():
		out.append(s["kind"])
	return out


func _use(p: GameplayPrefab, seconds: float) -> void:
	(_rt.crew_controller(0) as CrewController).set_masked()
	_rt.teleport_crew(0, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.15)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)


func test_saw_drill_point_opens_door_with_saw_noise_and_stimulus() -> void:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(0, 0, -6), func(n: Node) -> void:
		(n as Door).lock = Door.Lock.BARRED) as Door
	var dp: DrillPoint = ATestMaps.add_prefab(_rt, "drill_point", Vector3(0, 1, -5), func(n: Node) -> void:
		(n as DrillPoint).device = DrillPoint.Device.SAW
		(n as DrillPoint).target = NodePath("../%s" % door.name)) as DrillPoint
	await wait_physics_frames(2)
	assert_near(dp.effective_duration(), Tweak.interaction().saw_duration_s, 0.001, "saw default duration")
	dp.duration_s = 6.0
	await _use(dp, Tweak.interaction().drill_place_s)
	var started: Array[Array] = _of(&"device_started")
	assert_eq(started.size(), 1, "saw placed")
	if started.is_empty():
		return
	assert_eq(started[0][2], &"saw", "device kind")
	var kinds: Array[StringName] = _stim_kinds()
	assert_has(kinds, &"drill", "running device stimulus (25 m)")
	assert_has(kinds, &"saw", "S4.1 saw-cutting stimulus")
	assert_near(float(Tweak.stealth().stimuli[&"saw"]["range"]), 10.0, 0.001, "within 10 m")
	var ok: bool = await wait_until(func() -> bool: return dp.device_state() == DeviceRunner.State.DONE, 10.0)
	assert_true(ok, "saw finished")
	assert_true(door.is_open and not door.locked, "door cut open")
	var saw_noise: int = 0
	for e: Array in _noises:
		assert_ne(e[2], &"drill", "no drill noise from a saw")
		if e[2] == &"saw":
			saw_noise += 1
			assert_near(float(e[1]), Tweak.stealth().saw_radius_m, 0.001, "saw radius")
	assert_true(saw_noise >= 2, "saw noise every device_noise_interval_s (%d)" % saw_noise)
	assert_true(Tweak.stealth().noise_reactions.has(&"saw"), "guards react to saw noise")
	kinds = _stim_kinds()
	assert_false(kinds.has(&"saw") or kinds.has(&"drill"), "stimuli removed when done")


func test_safe_listing_saw_uses_a_saw() -> void:
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(0, 0, -6), func(n: Node) -> void:
		(n as Safe).methods = [&"saw"]
		(n as Safe).size = Safe.Size.SMALL) as Safe
	await wait_physics_frames(2)
	assert_eq(safe.interactable.kind, &"place_saw")
	await _use(safe, Tweak.interaction().drill_place_s)
	var started: Array[Array] = _of(&"device_started")
	assert_eq(started.size(), 1, "saw placed on the safe")
	if started.is_empty():
		return
	assert_eq(started[0][2], &"saw")
	assert_near(float(started[0][3]), Tweak.interaction().safe_saw_duration_s[0], 0.001, "saw time by size")
	assert_has(_stim_kinds(), &"saw")
