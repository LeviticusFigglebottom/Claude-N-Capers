## A1-10 AI teammates (L6.1, D-014): stealth = wait at the van, undetectable; loud = follow the
## human, revive downed crew (LEAD gate step 10), fight police/guards in COMBAT.
extends TestCase

const TIME_SCALE: float = 3.0

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _ai_slots() -> Array[int]:
	var out: Array[int] = []
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			out.append(c.slot)
	return out


func _go_loud() -> void:
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)


func test_l6_1_ai_crew_have_brains() -> void:
	assert_eq(_ai_slots(), [1, 2, 3] as Array[int], "solo: AI teammates in slots 1..3")
	for s: int in _ai_slots():
		assert_true(CrewAiBrain.of(_crew(s)) != null, "slot %d has a CrewAiBrain" % s)
	assert_true(CrewAiBrain.of(_crew(0)) == null, "the human has no brain")


func test_l6_1_stealth_ai_wait_and_are_never_detected() -> void:
	var start: Dictionary = {}
	for s: int in _ai_slots():
		start[s] = _crew(s).global_position
		assert_true(_crew(s).stealth_hidden, "slot %d hidden in stealth (D-014)" % s)
	var ai: CrewController = _crew(1)
	ai.set_masked()
	_rt.teleport_crew(1, Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), Vector3(0, 0.05, -6)))
	start[1] = Vector3(0, 0.05, -6)
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3.ZERO, Vector3.FORWARD)
	await wait_seconds(2.0)
	assert_near(_rt.detection_value(g, 1), 0.0, 0.0001, "a guard staring at a waiting AI stays at 0")
	assert_false(_rt.went_loud, "no alarm")
	for s: int in _ai_slots():
		assert_true(_crew(s).global_position.distance_to(start[s]) < 0.1, "slot %d did not move" % s)
	# Control: the (unhidden) human at the same spot is seen.
	_crew(0).set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), Vector3(0.6, 0.05, -6)))
	var seen: bool = await wait_until(func() -> bool: return _rt.detection_value(g, 0) > 0.0, 1.0)
	assert_true(seen, "the human in the same spot is detected")


func test_l6_1_loud_ai_unhide_mask_and_follow_human() -> void:
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	for s: int in _ai_slots():
		assert_false(_crew(s).stealth_hidden, "slot %d unhidden in loud" % s)
		assert_true(_crew(s).masked, "slot %d masked" % s)
	var human: CrewController = _crew(0)
	var walk: CrewIntent = CrewIntent.new()
	walk.look_yaw = 0.0  # -Z
	walk.move = Vector2(0.0, 1.0)
	_rt.set_bot_intent(0, walk)
	await wait_seconds(5.0)
	var stop: CrewIntent = CrewIntent.new()
	_rt.set_bot_intent(0, stop)
	assert_true(human.global_position.z < -5.0, "the human walked away (z=%.1f)" % human.global_position.z)
	await wait_seconds(4.0)
	var tw: CrewAiTweak = CrewAiBrain.of(_crew(1)).tweak
	for s: int in _ai_slots():
		var d: float = Vector2(_crew(s).global_position.x - human.global_position.x,
			_crew(s).global_position.z - human.global_position.z).length()
		assert_true(d <= tw.follow_max_m + 0.5, "slot %d follows within %.1f m (got %.1f)" % [s, tw.follow_max_m, d])
		assert_true(d >= tw.follow_min_m - 1.0, "slot %d does not crowd the human (%.1f m)" % [s, d])
		assert_eq(CrewAiBrain.of(_crew(s)).mode, CrewAiBrain.Mode.FOLLOW)


func test_l6_1_gate10_ai_revives_downed_human() -> void:
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(4, 0.05, 0)))
	await wait_physics_frames(2)
	var revives: Array[Vector2i] = []
	var cb: Callable = func(slot: int, by: int) -> void: revives.append(Vector2i(slot, by))
	EventBus.crew_revived.connect(cb)
	_crew(0).health.go_down()
	assert_eq(_crew(0).crew_state, Enums.CrewState.DOWNED)
	var t0: int = Time.get_ticks_msec()
	var ok: bool = await wait_until(func() -> bool: return _crew(0).crew_state == Enums.CrewState.NORMAL, 20.0)
	var real_s: float = float(Time.get_ticks_msec() - t0) / 1000.0
	EventBus.crew_revived.disconnect(cb)
	assert_true(ok, "an AI teammate revived the human within 20 s")
	assert_eq(revives.size(), 1, "one crew_revived")
	if revives.size() == 1:
		assert_eq(revives[0].x, 0, "slot 0 revived")
		assert_true(_ai_slots().has(revives[0].y), "by an AI slot (%d)" % revives[0].y)
	var game_s: float = real_s * TIME_SCALE
	assert_true(game_s >= Tweak.crew().revive_time_s - 0.5, "the full 6 s revive hold (%.1f s)" % game_s)


func test_l6_1_ai_revives_downed_ai() -> void:
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	_crew(2).health.go_down()
	var ok: bool = await wait_until(func() -> bool: return _crew(2).crew_state == Enums.CrewState.NORMAL, 20.0)
	assert_true(ok, "a downed AI teammate is revived by another AI")


func test_l6_1_one_reviver_per_downed_and_humans_first() -> void:
	await _go_loud()
	_crew(1).health.go_down()
	_crew(0).health.go_down()
	await wait_physics_frames(2)
	var on_human: int = 0
	var on_ai: int = 0
	for s: int in [2, 3]:
		var b: CrewAiBrain = CrewAiBrain.of(_crew(s))
		if b.revive_target == _crew(0):
			on_human += 1
		elif b.revive_target == _crew(1):
			on_ai += 1
	assert_eq(on_human, 1, "exactly one AI goes to the human")
	assert_eq(on_ai, 1, "the other goes to the downed AI")
	# Humans first: with a single free AI it picks the human.
	_crew(3).health.go_down()
	await wait_physics_frames(2)
	assert_true(CrewAiBrain.of(_crew(2)).revive_target == _crew(0), "the last free AI picks the human")


func test_l6_1_ai_shoot_police() -> void:
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	var killers: Array[int] = []
	var cb: Callable = func(_npc: int, killer: int, _info: Dictionary) -> void: killers.append(killer)
	EventBus.npc_killed.connect(cb)
	var pos: Vector3 = Vector3(-8.5, 0.05, -2.0)
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), pos))
	var ok: bool = await wait_until(func() -> bool: return not cop.alive, 8.0)
	EventBus.npc_killed.disconnect(cb)
	assert_true(ok, "the AI crew killed the police NPC")
	var by_ai: bool = false
	for k: int in killers:
		var c: CrewController = Ids.lookup(k) as CrewController
		by_ai = by_ai or (c != null and c.is_ai)
	assert_true(by_ai, "killed by an AI teammate")


func test_l6_1_ai_shoot_guard_in_combat_not_calm() -> void:
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	var pos: Vector3 = Vector3(-8.5, 0.05, -2.0)
	# Brainless guard observer: holds whatever alert state the test sets.
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", pos, Vector3.BACK)
	await wait_seconds(1.0)
	assert_near(g.health, g.max_health, 0.001, "a CALM guard is not a target")
	g.set_alert_state(Enums.AlertState.COMBAT)
	var ok: bool = await wait_until(func() -> bool: return not g.alive or g.health < g.max_health, 8.0)
	assert_true(ok, "the AI crew shot the guard in COMBAT")


func test_l6_1_follow_paths_through_door_on_navmesh() -> void:
	_rt.teardown()
	await wait_frames(1)
	_rt = await HeistLauncher.launch(&"dev_sandbox", 42, Enums.Difficulty.ROUTINE, self)
	await wait_physics_frames(2)
	Engine.time_scale = TIME_SCALE
	for role: StringName in [&"guard", &"civilian"]:
		for n: Node in _rt.npcs(role):
			(n as NpcBase).die({}, 0)
	await _go_loud()
	_open_all_doors(_rt.map)
	# Inside the building's west room: the straight line from the van spawns hits the south wall.
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(-5.0, 0.1, -8.0)))
	var human: CrewController = _crew(0)
	var tw: CrewAiTweak = CrewAiBrain.of(_crew(1)).tweak
	var ok: bool = await wait_until(func() -> bool:
		for s: int in _ai_slots():
			if _crew(s).global_position.distance_to(human.global_position) > tw.follow_max_m + 0.5:
				return false
		return true, 15.0)
	assert_true(ok, "every AI teammate reached the human inside the building via the navmesh")
	for s: int in _ai_slots():
		assert_true(_crew(s).global_position.z < 0.5, "slot %d is inside (z=%.1f)" % [s, _crew(s).global_position.z])


## AI teammates do not open doors (P1): open every door prefab so the path is physically clear.
func _open_all_doors(root: Node) -> void:
	for n: Node in root.find_children("*", "", true, false):
		if n.has_method(&"set_open") and n.has_method(&"unlock"):
			n.call(&"unlock")
			n.call(&"set_open", true)
