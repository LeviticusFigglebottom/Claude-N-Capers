## LEAD (P's throws pass, RT SiteManGate): a padlock picked on a BARRED gate unlocks and opens it at once; the crew's
## very next interaction on that gate (here: close it, then open it again) is not refused with ui.blocked.state.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_padlock_gate", 1390, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func test_gate_usable_right_after_the_pick() -> void:
	var gate: Door = ATestMaps.add_prefab(_rt, "door", Vector3(0, 0, -6), func(p: GameplayPrefab) -> void:
		(p as Door).lock = Door.Lock.BARRED) as Door
	var lock: Padlock = ATestMaps.add_prefab(_rt, "padlock", Vector3(0, 1, -5.8)) as Padlock
	lock.targets = [lock.get_path_to(gate)]
	await wait_physics_frames(1)
	_crew().set_masked()
	_rt.teleport_crew(0, lock.use_point.global_transform)
	await wait_physics_frames(1)
	var sys: InteractionSystem = _rt.interaction
	var log: Array[String] = []
	ATestMaps.hold_interact(_rt, 0, lock.net_id)
	for _i: int in 900:
		await wait_physics_frames(1)
		if lock.opened:
			break
	assert_true(lock.opened, "picked")
	assert_false(gate.locked, "the gate is unlocked at once")
	# P's pass: the player keeps holding and turns to the gate (no release frame).
	log.append("avail %s open %s swinging %s" % [gate.interactable.availability(_crew()), gate.is_open, gate.is_swinging()])
	ATestMaps.hold_interact(_rt, 0, gate.net_id)
	await wait_physics_frames(2)
	log.append("blocked '%s' session %s" % [sys.blocked_reason(0), not sys.session(0).is_empty()])
	assert_eq(sys.blocked_reason(0), &"", "the first press on the gate is not refused (%s)" % ", ".join(log))


## The real RT SiteManGate (P's report): pick by aim like a player, then press on the gate by aim.
func test_rt_site_man_gate_by_aim() -> void:
	var path: String = HeistLauncher.map_path(&"rolling_thunder", {})
	if path == "" or not ResourceLoader.exists(path):
		skip("rolling_thunder not on this branch")
		return
	_rt.teardown()
	_rt = await HeistLauncher.launch(&"rolling_thunder", 4101, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0, "skip_casing": true})
	await wait_physics_frames(3)
	var gate: Door = _rt.map.get_node(^"Gameplay/Doors/SiteManGate") as Door
	var lock: Padlock = gate.get_node(^"Padlock") as Padlock
	var c: CrewController = _crew()
	c.set_masked()
	_rt.teleport_crew(0, lock.use_point.global_transform)
	await wait_physics_frames(2)
	var sys: InteractionSystem = _rt.interaction
	var aim: Callable = func(target: Vector3) -> CrewIntent:
		var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), target)
		i.interact = true
		return i
	_rt.set_bot_intent(0, aim.call(lock.global_position))
	for _i: int in 1200:
		await wait_physics_frames(1)
		if lock.opened:
			break
	assert_true(lock.opened, "picked by aim")
	var trace: Array[String] = []
	for f: int in 6:
		_rt.set_bot_intent(0, CrewIntent.new() if f < 2 else aim.call(gate.global_position + Vector3.UP))
		await wait_physics_frames(1)
		var aimed: InteractableComponent = sys.aimed_component(c)
		trace.append("f%d aimed %s avail %s blocked '%s' locked %s open %s" % [f,
			aimed.owner_node().name if aimed != null else "-", aimed.availability(c) if aimed != null else "-",
			sys.blocked_reason(0), gate.locked, gate.is_open])
	assert_eq(sys.blocked_reason(0), &"", "the first press on the gate is not refused:\n%s" % "\n".join(trace))
