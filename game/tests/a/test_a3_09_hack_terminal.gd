## A3-09 (QC-12, D-040): hack_terminal: silent timed hack, rolled interruptions (GameRng &"devices"),
## restart interaction, device_* events + cues, opens its targets on finish.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func before_each() -> void:
	await _launch(9091)


func after_each() -> void:
	await _teardown()


func _launch(seed_value: int) -> void:
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_hack", seed_value, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	_listen(EventBus.device_started, &"device_started")
	_listen(EventBus.device_jammed, &"device_jammed")
	_listen(EventBus.device_restarted, &"device_restarted")
	_listen(EventBus.device_finished, &"device_finished")
	_listen(EventBus.audio_cue_requested, &"cue")
	_listen(EventBus.alarm_raised, &"alarm")
	var ncb: Callable = func(_p: Vector3, _r: float, kind: StringName, _s: int) -> void: _events.append([&"noise", kind])
	_rt.noise_made.connect(ncb)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
		_events.append([tag, a, b, c])
	sig.connect(cb)
	_conns.append([sig, cb])


func _teardown() -> void:
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


func _cues() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Array in _of(&"cue"):
		out.append(StringName(e[1]))
	return out


func _setup(duration: float, inter: Vector2i) -> Array:
	var door: Door = ATestMaps.add_prefab(_rt, "door", Vector3(4, 0, -8), func(n: Node) -> void:
		n.name = "VaultDoor"
		(n as Door).lock = Door.Lock.ELECTRONIC) as Door
	var hack: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(0, 0, -6), func(n: Node) -> void:
		var h: HackTerminal = n as HackTerminal
		h.duration_s = duration
		h.interruptions = inter
		h.targets = [NodePath("../VaultDoor")] as Array[NodePath]) as HackTerminal
	return [hack, door]


func _use(p: GameplayPrefab, seconds: float) -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, p.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.2)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)


func test_hack_runs_interrupts_restarts_and_opens_target() -> void:
	var parts: Array = _setup(3.0, Vector2i(2, 2))
	var hack: HackTerminal = parts[0]
	var door: Door = parts[1]
	await wait_physics_frames(2)
	assert_true(door.locked, "door starts locked (ELECTRONIC)")
	assert_eq(hack.interactable.kind, &"start_hack")
	await _use(hack, Tweak.interaction().hack_start_s)
	assert_eq(hack.state, HackTerminal.State.RUNNING, "running after the start hold")
	assert_eq(_of(&"device_started").size(), 1, "device_started [R]")
	assert_eq(_of(&"device_started")[0][2], &"hack", "kind hack")
	assert_eq(hack.rolled_interruptions, 2, "interruptions [2, 2]")
	var seg: float = 1.0 / 3.0
	var jit: float = Tweak.interaction().hack_interruption_jitter * seg + 0.001
	assert_true(absf(hack.pending_interruptions[0] - seg) <= jit, "first interruption near 1/3 (%.3f)" % hack.pending_interruptions[0])
	assert_true(absf(hack.pending_interruptions[1] - 2.0 * seg) <= jit, "second near 2/3 (%.3f)" % hack.pending_interruptions[1])
	for k: int in range(2):
		var hit: bool = await wait_until(func() -> bool: return hack.state == HackTerminal.State.INTERRUPTED, 4.0)
		assert_true(hit, "interruption %d" % k)
		assert_eq(hack.interactable.kind, &"restart_hack", "restart interaction")
		var p0: float = hack.progress
		await wait_seconds(0.4)
		assert_eq(hack.progress, p0, "no progress while interrupted")
		await _use(hack, Tweak.interaction().hack_restart_s)
		assert_eq(hack.state, HackTerminal.State.RUNNING, "restarted %d" % k)
	assert_eq(_of(&"device_jammed").size(), 2, "device_jammed x2")
	assert_eq(_of(&"device_restarted").size(), 2, "device_restarted x2")
	var done: bool = await wait_until(func() -> bool: return hack.state == HackTerminal.State.DONE, 4.0)
	assert_true(done, "finished")
	assert_eq(_of(&"device_finished").size(), 1, "device_finished")
	assert_false(door.locked, "target unlocked")
	assert_true(door.is_open, "target opened")
	assert_false(hack.interactable.enabled, "terminal done")
	var cues: Array[StringName] = _cues()
	assert_has(cues, &"cue.hack_start")
	assert_has(cues, &"cue.hack_interrupt")
	assert_has(cues, &"cue.hack_done")
	assert_true(_of(&"noise").is_empty(), "silent: no NoiseEvents")
	assert_true(_of(&"alarm").is_empty(), "no alarm")


func test_interruptions_deterministic_per_seed() -> void:
	var parts: Array = _setup(30.0, Vector2i(1, 3))
	await wait_physics_frames(2)
	var a: HackTerminal = parts[0]
	a.start_hack(0)
	var first: Array[float] = a.pending_interruptions.duplicate()
	await _teardown()
	await _launch(9091)
	var parts2: Array = _setup(30.0, Vector2i(1, 3))
	await wait_physics_frames(2)
	var b: HackTerminal = parts2[0]
	b.start_hack(0)
	assert_eq(b.pending_interruptions, first, "same seed, same interruptions")
	assert_true(b.rolled_interruptions >= 1 and b.rolled_interruptions <= 3, "count in range")


func test_defaults_from_tweak_and_zero_interruptions() -> void:
	var hack: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(0, 0, -6)) as HackTerminal
	await wait_physics_frames(2)
	assert_eq(hack.effective_duration(), Tweak.interaction().hack_duration_s, "duration default")
	assert_eq(hack.interruption_range(), Tweak.interaction().hack_interruptions, "interruptions default")
	assert_true(hack.visual_node("Screen") != null and hack.visual_node("Panel") != null, "visual nodes")
	hack.duration_s = 0.3
	hack.interruptions = Vector2i(0, 0)
	hack.start_hack(0)
	var done: bool = await wait_until(func() -> bool: return hack.state == HackTerminal.State.DONE, 2.0)
	assert_true(done, "no interruptions: straight through")
	assert_true(_of(&"device_jammed").is_empty())


## Lockdowns: pause(reason) / resume(reason) stack by reason; paused = timer frozen, interaction
## blocked, device_jammed / device_restarted(-1) for the HUD.
func test_pause_resume_stacked_reasons() -> void:
	var hack: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(0, 0, -6), func(n: Node) -> void:
		var h: HackTerminal = n as HackTerminal
		h.duration_s = 1.5
		h.interruptions = Vector2i(0, 0)) as HackTerminal
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	hack.start_hack(0)
	await wait_seconds(0.3)
	hack.pause(&"lockdown")
	assert_true(hack.is_paused() and hack.is_jammed(), "paused, jammed for the HUD")
	assert_eq(hack.pause_reasons(), [&"lockdown"] as Array[StringName])
	assert_eq(_of(&"device_jammed").size(), 1, "pausing a running hack = device_jammed")
	assert_eq(hack.interactable.availability(c), HackTerminal.BLOCK_PAUSED, "blocked while paused")
	var p0: float = hack.progress
	assert_true(p0 > 0.05 and p0 < 1.0, "ran a little (%.2f)" % p0)
	await wait_seconds(0.4)
	assert_eq(hack.progress, p0, "timer frozen")
	hack.pause(&"mission")
	hack.pause(&"mission")
	hack.resume(&"lockdown")
	assert_true(hack.is_paused(), "still paused by the other reason")
	assert_true(_of(&"device_restarted").is_empty(), "no restart yet")
	hack.resume(&"mission")
	assert_false(hack.is_paused(), "all reasons gone")
	assert_eq(_of(&"device_restarted").size(), 1, "device_restarted on resume")
	assert_eq(_of(&"device_restarted")[0][2], -1, "by the mission (slot -1)")
	assert_eq(_of(&"device_jammed").size(), 1, "one jam for the whole pause")
	var done: bool = await wait_until(func() -> bool: return hack.state == HackTerminal.State.DONE, 3.0)
	assert_true(done, "finishes after the resume")


func test_pause_on_alarm_and_events() -> void:
	var hack: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(0, 0, -6), func(n: Node) -> void:
		var h: HackTerminal = n as HackTerminal
		h.duration_s = 30.0
		h.interruptions = Vector2i(0, 0)
		h.pause_on_alarm = true
		h.pause_on_event = &"voice_line_requested"
		h.resume_on_event = &"item_picked_up") as HackTerminal
	await wait_physics_frames(2)
	hack.start_hack(0)
	EventBus.voice_line_requested.emit(&"test", &"test.lockdown", {})
	assert_eq(hack.pause_reasons(), [&"voice_line_requested"] as Array[StringName], "event pauses (3 args)")
	EventBus.item_picked_up.emit(&"item.test", 0)
	assert_false(hack.is_paused(), "resume event (2 args)")
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	assert_true(hack.pause_reasons().has(HackTerminal.REASON_ALARM), "alarm pauses it")
	var p0: float = hack.progress
	await wait_seconds(0.3)
	assert_eq(hack.progress, p0, "frozen in the lockdown")
	hack.resume(HackTerminal.REASON_ALARM)
	await wait_seconds(0.2)
	assert_true(hack.progress > p0, "a mission script lifts the lockdown")


## D-103 §6 / QC-55: reconfigure() from the mission. Idle: the next run uses the new values. Running: the progress
## fraction is kept, the remaining time follows the new duration and the interruptions still ahead re-roll into the
## new range (Gallery Night: 60 s / 1-2 -> 120 s / 2-3 at the alarm).
func test_gn_reconfigure_idle_and_running_hack() -> void:
	var hack: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(0, 0, -6), func(n: Node) -> void:
		(n as HackTerminal).duration_s = 60.0
		(n as HackTerminal).interruptions = Vector2i(0, 0)) as HackTerminal
	await wait_physics_frames(2)
	hack.reconfigure(30.0, Vector2i(1, 1))
	assert_near(hack.effective_duration(), 30.0, 0.001, "idle: the next run uses the new duration")
	hack.start_hack(0)
	assert_eq(hack.rolled_interruptions, 1, "idle: the new interruption range")
	hack.progress = 0.6
	hack.pending_interruptions.clear()  # its one interruption already happened
	hack.reconfigure(120.0, Vector2i(3, 3))
	assert_near(hack.duration, 120.0, 0.001, "running: the new duration")
	assert_near(hack.progress, 0.6, 0.0001, "running: progress kept")
	assert_near(hack.time_left(), 48.0, 0.01, "remaining = 40 % of 120 s")
	assert_eq(hack.rolled_interruptions, 3, "total in the new range")
	assert_eq(hack.pending_interruptions.size(), 2, "only the ones still ahead (1 used)")
	for at: float in hack.pending_interruptions:
		assert_true(at > 0.6 and at < 1.0, "ahead of the current progress (%.3f)" % at)


## D-103 §6 / QC-54: a hack with clears_alarm_group takes that alarm group offline when it finishes.
func test_gn_finished_hack_disables_its_alarm_group() -> void:
	var hack: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(0, 0, -6), func(n: Node) -> void:
		(n as HackTerminal).duration_s = 0.2
		(n as HackTerminal).interruptions = Vector2i(0, 0)
		(n as HackTerminal).clears_alarm_group = &"argus") as HackTerminal
	await wait_physics_frames(2)
	assert_true(AlarmGroups.is_live(_rt, &"argus"), "sensors live before the hack")
	hack.start_hack(0)
	var done: bool = await wait_until(func() -> bool: return hack.state == HackTerminal.State.DONE, 2.0)
	assert_true(done, "hack finished")
	assert_false(AlarmGroups.is_live(_rt, &"argus"), "the finished hack took the group offline")
