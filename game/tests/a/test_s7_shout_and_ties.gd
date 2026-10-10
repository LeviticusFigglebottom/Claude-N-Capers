## A1-06 / S7.1 shout-intimidate, S7.2 cable ties, S1.1 (shout while casing, no tie while casing).
extends TestCase

var _rt: HeistRuntime = null
var _saved_duration: float = 45.0
var _events: Array[Array] = []


func before_each() -> void:
	_saved_duration = Tweak.stealth().intimidate_duration_s
	_events.clear()
	EventBus.civilian_intimidated.connect(_on_intimidated)
	EventBus.civilian_tied.connect(_on_tied)
	EventBus.hostage_count_changed.connect(_on_hostages)
	_rt = await HeistLauncher.launch(&"unit_map", 77, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 1)})


func after_each() -> void:
	Tweak.stealth().intimidate_duration_s = _saved_duration
	for pair: Array in [[EventBus.civilian_intimidated, _on_intimidated], [EventBus.civilian_tied, _on_tied],
			[EventBus.hostage_count_changed, _on_hostages]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_intimidated(npc_id: int, slot: int) -> void:
	_events.append([&"intimidated", npc_id, slot])


func _on_tied(npc_id: int, slot: int) -> void:
	_events.append([&"tied", npc_id, slot])


func _on_hostages(count: int) -> void:
	_events.append([&"hostages", count])


func _civ() -> NpcBase:
	return _rt.npcs(&"civilian")[0] as NpcBase


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


## Civilian at the origin; crew at `crew_pos` looking along `yaw`.
func _place(crew_pos: Vector3, yaw: float) -> NpcBase:
	var civ: NpcBase = _civ()
	civ.global_position = Vector3(0, 0.05, 0)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, crew_pos))
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = yaw
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(3)
	return civ


func _shout(yaw: float) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = yaw
	i.shout = true
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	var r: CrewIntent = CrewIntent.new()
	r.look_yaw = yaw
	_rt.set_bot_intent(0, r)
	await wait_physics_frames(2)


func _count(kind: StringName) -> int:
	var n: int = 0
	for e: Array in _events:
		if e[0] == kind:
			n += 1
	return n


func test_s7_1_shout_in_cone_at_10m_intimidates_while_casing() -> void:
	var civ: NpcBase = await _place(Vector3(0, 0.05, 10), 0.0)  # looking -Z at the civilian
	assert_true(_crew().is_casing(), "S1.1: casing crew can shout")
	await _shout(0.0)
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED, "in cone at 10 m")
	assert_eq(_count(&"intimidated"), 1, "civilian_intimidated emitted")
	assert_eq(_events[0][1], civ.net_id)
	assert_eq(_events[0][2], 0, "slot 0")


func test_s7_1_shout_outside_cone_at_10m_does_nothing() -> void:
	var civ: NpcBase = await _place(Vector3(0, 0.05, 10), PI * 0.5)  # looking -X
	await _shout(PI * 0.5)
	assert_eq(civ.alert_state, Enums.AlertState.CALM, "outside cone at 10 m")
	assert_eq(_count(&"intimidated"), 0)


func test_s7_1_shout_within_6m_any_direction() -> void:
	var civ: NpcBase = await _place(Vector3(0, 0.05, 5), PI)  # looking +Z, away from the civilian
	await _shout(PI)
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED, "within 6 m, behind the crew")


func test_s7_1_out_of_range_in_cone() -> void:
	var civ: NpcBase = await _place(Vector3(0, 0.05, 14), 0.0)
	await _shout(0.0)
	assert_eq(civ.alert_state, Enums.AlertState.CALM, "14 m > 12 m range")


func test_s7_1_timer_expiry_gets_up_and_reshout_resets() -> void:
	Tweak.stealth().intimidate_duration_s = 2.0
	var civ: NpcBase = await _place(Vector3(0, 0.05, 4), 0.0)
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	await _shout(0.0)
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED)
	await wait_seconds(1.2)
	await _shout(0.0)  # re-shout (after the 0.8 s cooldown) resets the timer
	assert_true(b.intimidate_left > 1.8, "timer reset (left %f)" % b.intimidate_left)
	await wait_seconds(1.2)
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED, "still down 2.4 s after the first shout")
	assert_true(await wait_until(func() -> bool: return civ.alert_state != Enums.AlertState.INTIMIDATED, 2.0),
		"gets back up")
	assert_eq(civ.alert_state, Enums.AlertState.PANICKED, "back to panicked")


func test_s7_1_shout_cooldown() -> void:
	var civ: NpcBase = await _place(Vector3(0, 0.05, 4), 0.0)
	await _shout(0.0)
	await _shout(0.0)  # within 0.8 s: ignored
	assert_eq(_count(&"intimidated"), 1, "one shout per cooldown")
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED)


func test_s7_2_tie_intimidated_civilian() -> void:
	var civ: NpcBase = await _place(Vector3(0, 0.05, 3), 0.0)
	await _shout(0.0)
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED)
	var c: CrewController = _crew()
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 1.0)))
	await wait_physics_frames(2)
	var ties_before: int = c.cable_ties
	var i: CrewIntent = CrewIntent.new()
	i.interact = true
	i.interact_target_net_id = civ.net_id
	_rt.set_bot_intent(0, i)
	await wait_seconds(Tweak.stealth().cable_tie_s * 0.5)
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED, "not tied yet at half hold")
	await wait_seconds(Tweak.stealth().cable_tie_s * 0.5 + 0.3)
	_rt.set_bot_intent(0, CrewIntent.new())
	assert_eq(civ.alert_state, Enums.AlertState.TIED, "tied after 2 s")
	assert_eq(c.cable_ties, ties_before - 1, "cable tie used")
	assert_eq(_count(&"tied"), 1, "civilian_tied emitted")
	assert_has(_events, [&"hostages", 1], "hostage_count_changed(1)")
	assert_false(civ.can_observe(), "tied civilians do not observe")
	assert_true(civ.is_in_group(G.HOSTAGE), "in hostage group")
	var st: StealthDirector = _rt.stealth
	var restrained: bool = false
	for s: Dictionary in st.stimuli():
		if s["kind"] == &"restrained" and s["source"] == civ:
			restrained = true
	assert_true(restrained, "restrained stimulus registered (S6.4)")
	await wait_seconds(0.3)
	await _shout(0.0)
	assert_eq(civ.alert_state, Enums.AlertState.TIED, "tied is permanent")
	civ.die({}, 0)
	assert_has(_events, [&"hostages", 0], "hostage count drops when the hostage dies")


func test_s7_2_casing_crew_cannot_tie() -> void:
	var civ: NpcBase = await _place(Vector3(0, 0.05, 1.0), 0.0)
	await _shout(0.0)
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED)
	var c: CrewController = _crew()
	assert_true(c.is_casing())
	var i: CrewIntent = CrewIntent.new()
	i.interact = true
	i.interact_target_net_id = civ.net_id
	_rt.set_bot_intent(0, i)
	await wait_seconds(Tweak.stealth().cable_tie_s + 0.3)
	_rt.set_bot_intent(0, CrewIntent.new())
	assert_eq(civ.alert_state, Enums.AlertState.INTIMIDATED, "not tied while casing")
	assert_eq(_rt.interaction.blocked_reason(0), InteractableComponent.BLOCK_CASING, "blocked: casing")
	assert_eq(c.cable_ties, Tweak.crew().cable_ties_base, "no tie used")


func test_s7_2_calm_civilian_cannot_be_tied() -> void:
	var civ: NpcBase = await _place(Vector3(0, 0.05, 1.0), 0.0)
	_crew().set_masked()
	var i: CrewIntent = CrewIntent.new()
	i.interact = true
	i.interact_target_net_id = civ.net_id
	_rt.set_bot_intent(0, i)
	await wait_seconds(Tweak.stealth().cable_tie_s + 0.3)
	_rt.set_bot_intent(0, CrewIntent.new())
	assert_ne(civ.alert_state, Enums.AlertState.TIED, "only intimidated civilians can be tied")
