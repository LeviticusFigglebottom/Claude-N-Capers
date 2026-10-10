## A2-07 S6.4: dominated / surrendered / tied guards carry a `hostage` stimulus (guards -> alarm,
## civilians -> panic); tied civilians carry `restrained` (guards -> alarm).
extends TestCase

var _rt: HeistRuntime = null
var _st: StealthDirector = null


func _launch(guards: int, civilians: int) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(guards, civilians), "ai_teammates": 0, "skip_casing": true})
	_st = _rt.stealth
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(25, 0.05, 25)))


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _stims(source: Node, kind: StringName) -> int:
	var n: int = 0
	for s: Dictionary in _st.stimuli():
		if s.get("source") == source and StringName(s["kind"]) == kind:
			n += 1
	return n


func test_s6_4_hostage_stimulus_follows_alert_state() -> void:
	await _launch(0, 0)
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(0, 0, -5), Vector3.BACK)
	assert_eq(_stims(g, &"hostage"), 0, "calm guard: no stimulus")
	g.set_alert_state(Enums.AlertState.SURRENDERED)
	assert_eq(_stims(g, &"hostage"), 1, "surrendered guard is a hostage stimulus")
	g.set_alert_state(Enums.AlertState.DOMINATED)
	g.set_alert_state(Enums.AlertState.TIED)
	assert_eq(_stims(g, &"hostage"), 1, "one stimulus through DOMINATED -> TIED (cuffed)")
	g.set_alert_state(Enums.AlertState.CALM)
	assert_eq(_stims(g, &"hostage"), 0, "released: unregistered")
	g.set_alert_state(Enums.AlertState.DOMINATED)
	assert_eq(_stims(g, &"hostage"), 1)
	g.die()
	assert_eq(_stims(g, &"hostage"), 0, "dead: the corpse stimulus takes over")
	assert_eq(_stims(g, &"corpse"), 1)


func test_s6_4_civilians_and_foreign_registrations_skipped() -> void:
	await _launch(0, 0)
	var c: NpcBase = ATestMaps.add_npc_observer(_rt, &"civilian", Vector3(0, 0, -5), Vector3.BACK)
	c.set_alert_state(Enums.AlertState.TIED)
	assert_eq(_stims(c, &"hostage"), 0, "civilians are CivilianBrain's (restrained)")
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(2, 0, -5), Vector3.BACK)
	var id: int = _st.register_stimulus(g, &"hostage")
	g.set_alert_state(Enums.AlertState.DOMINATED)
	assert_eq(_stims(g, &"hostage"), 1, "an existing hostage stimulus is not duplicated")
	_st.unregister_stimulus(id)


func test_s6_4_guard_seeing_dominated_guard_raises_alarm() -> void:
	await _launch(1, 0)
	var watcher: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var fwd: Vector3 = -watcher.global_basis.z
	var hostage: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", watcher.global_position + fwd * 5.0, -fwd)
	var seen: Array[StringName] = []
	watcher.stimulus_spotted.connect(func(_i: int, k: StringName, _p: Vector3) -> void: seen.append(k))
	hostage.set_alert_state(Enums.AlertState.DOMINATED)
	var ok: bool = await wait_until(func() -> bool: return seen.has(&"hostage"), 4.0)
	assert_true(ok, "S6.4 the guard notices the dominated guard")
	ok = await wait_until(func() -> bool: return _st.alarm_raised, Tweak.stealth().guard_radio_call_s + 3.0)
	assert_true(ok, "guard reaction to `hostage` is the alarm (radio call)")


func test_s6_4_guard_seeing_tied_civilian_raises_alarm() -> void:
	await _launch(1, 0)
	var watcher: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	var fwd: Vector3 = -watcher.global_basis.z
	var tied: NpcBase = ATestMaps.add_npc_observer(_rt, &"civilian", watcher.global_position + fwd * 5.0, -fwd)
	tied.set_alert_state(Enums.AlertState.TIED)
	_st.register_stimulus(tied, &"restrained")  # what CivilianBrain registers on tie
	var ok: bool = await wait_until(func() -> bool: return _st.alarm_raised, Tweak.stealth().guard_radio_call_s + 4.0)
	assert_true(ok, "guard reaction to `restrained` is the alarm")


func test_s6_4_civilian_seeing_dominated_guard_panics() -> void:
	await _launch(0, 1)
	var civ: NpcBase = _rt.npcs(&"civilian")[0] as NpcBase
	var fwd: Vector3 = -civ.global_basis.z
	var hostage: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", civ.global_position + fwd * 4.0, -fwd)
	hostage.set_alert_state(Enums.AlertState.DOMINATED)
	var ok: bool = await wait_until(func() -> bool: return civ.alert_state == Enums.AlertState.PANICKED, 4.0)
	assert_true(ok, "S6.4 civilians seeing a hostage panic (got %s)" % Enums.AlertState.keys()[civ.alert_state])
