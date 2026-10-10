## A2-05 / S3.2 (P2): a guard reaching "!" yells, pauses ~5 s, walks over and cuffs; moving > 1.7 m
## or shooting makes him open fire (alarm); cuffed -> CrewState.CUFFED and the radio call follows;
## 4 min cuff cooldown per crew member; 60 s self-free or a teammate frees them.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0), "crew_ai": false})
	await wait_physics_frames(2)
	_crew().set_masked(true)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(5.0, 0.05, -1.5)))
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _guard() -> NpcBase:
	return _rt.npcs(&"guard")[0] as NpcBase


func _brain() -> GuardBrain:
	return _guard().get_node("Brain") as GuardBrain


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _alarms() -> Array[StringName]:
	var out: Array[StringName] = []
	EventBus.alarm_raised.connect(func(r: StringName, _s: int) -> void: out.append(r), CONNECT_ONE_SHOT)
	return out


func test_s3_2_yell_pause_walk_cuff_then_radio_alarm() -> void:
	var lines: Array[StringName] = []
	var on_line: Callable = func(_sp: StringName, line: StringName, _c: Dictionary) -> void: lines.append(line)
	EventBus.voice_line_requested.connect(on_line)
	var reasons: Array[StringName] = _alarms()
	var b: GuardBrain = _brain()
	_guard().notify_crew_spotted(_crew())
	await wait_physics_frames(1)
	EventBus.voice_line_requested.disconnect(on_line)
	assert_eq(b.state_name(), &"alarmed", "! -> ALARMED")
	assert_eq(b.cuff_phase, GuardBrain.CuffPhase.PAUSE, "S3.2 cuff flow instead of the P1 radio call")
	assert_near(b.radio_time_left, 0.0, 0.0001, "no radio call yet")
	assert_has(lines, Tweak.stealth().cuff_yell_line, "guard yells (voice line)")
	var g0: Vector3 = _guard().global_position
	await wait_seconds(Tweak.stealth().cuff_pause_s - 0.5)
	assert_eq(b.cuff_phase, GuardBrain.CuffPhase.PAUSE, "still pausing at 4.5 s")
	assert_true(_guard().global_position.distance_to(g0) < 0.1, "the guard holds still while pausing")
	assert_true(reasons.is_empty(), "no alarm during the pause")
	assert_true(await wait_until(func() -> bool: return _crew().crew_state == Enums.CrewState.CUFFED, 8.0),
		"guard walked over and cuffed the crew member")
	assert_true(_flat_dist(_guard().global_position, _crew().global_position) <= Tweak.stealth().cuff_reach_m + 0.1,
		"cuffed from within reach")
	assert_true(b.radio_time_left > 0.0, "cuffed: the radio call follows")
	assert_true(reasons.is_empty(), "alarm not raised yet")
	await wait_seconds(Tweak.stealth().guard_radio_call_s + 0.3)
	assert_eq(reasons, [&"guard_radio"] as Array[StringName], "radio call raised the alarm")
	assert_eq(_crew().crew_state, Enums.CrewState.CUFFED, "still cuffed after the alarm")


func test_s3_2_moving_beyond_1_7_m_makes_guard_open_fire() -> void:
	var reasons: Array[StringName] = _alarms()
	_guard().notify_crew_spotted(_crew())
	await wait_seconds(1.0)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, _crew().global_position + Vector3(1.2, 0.0, 0.0)))
	await wait_seconds(0.3)
	assert_true(reasons.is_empty(), "1.2 m: within tolerance")
	assert_eq(_brain().cuff_phase, GuardBrain.CuffPhase.PAUSE)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, _crew().global_position + Vector3(0.7, 0.0, 0.0)))
	await wait_seconds(0.3)
	assert_eq(reasons, [&"guard_radio"] as Array[StringName], "moved 1.9 m: alarm")
	assert_eq(_brain().state_name(), &"combat", "guard opens fire")
	assert_eq(_crew().crew_state, Enums.CrewState.NORMAL, "not cuffed")


func test_s3_2_shooting_makes_guard_open_fire() -> void:
	var reasons: Array[StringName] = _alarms()
	_guard().notify_crew_spotted(_crew())
	await wait_seconds(1.0)
	var fire: CrewIntent = CrewIntent.new()
	fire.look_yaw = _crew().look_yaw
	fire.look_pitch = -0.5
	fire.fire = true
	_rt.set_bot_intent(0, fire)
	await wait_seconds(0.5)
	_rt.set_bot_intent(0, CrewIntent.new())
	assert_eq(reasons, [&"guard_radio"] as Array[StringName], "target shot: alarm")
	assert_eq(_brain().state_name(), &"combat")


func test_s3_2_killing_guard_during_flow_cancels() -> void:
	var reasons: Array[StringName] = _alarms()
	var g: NpcBase = _guard()
	var b: GuardBrain = _brain()
	g.notify_crew_spotted(_crew())
	await wait_seconds(2.0)
	g.die()
	await wait_seconds(Tweak.stealth().cuff_pause_s + 2.0)
	assert_true(reasons.is_empty(), "no alarm")
	assert_eq(b.cuff_phase, GuardBrain.CuffPhase.NONE)
	assert_eq(_crew().crew_state, Enums.CrewState.NORMAL)


func test_s3_2_cooldown_means_radio_straight_away() -> void:
	var cuffs: CrewCuffs = CrewCuffs.of(_crew(), true)
	await wait_physics_frames(1)
	assert_true(cuffs.cuff(999), "cuff")
	assert_near(cuffs.cooldown_left, Tweak.stealth().cuff_cooldown_s, 0.05, "4 min cooldown starts")
	assert_near(Tweak.stealth().cuff_cooldown_s, 240.0, 0.001, "S3.2: 4 min")
	cuffs.free_crew(1)
	assert_eq(_crew().crew_state, Enums.CrewState.NORMAL)
	assert_false(CrewCuffs.can_cuff(_crew()), "cooldown running")
	assert_false(cuffs.cuff(999), "cannot be cuffed during the cooldown")
	_guard().notify_crew_spotted(_crew())
	await wait_physics_frames(1)
	assert_eq(_brain().cuff_phase, GuardBrain.CuffPhase.NONE, "no cuff attempt on cooldown")
	assert_true(_brain().radio_time_left > 0.0, "P1 radio call instead")
	cuffs.cooldown_left = 0.0
	assert_true(CrewCuffs.can_cuff(_crew()), "cooldown over")


func test_s3_2_cuffed_cannot_move_and_frees_after_timer() -> void:
	var cuffs: CrewCuffs = CrewCuffs.of(_crew(), true)
	await wait_physics_frames(1)
	cuffs.cuff(999)
	assert_eq(_crew().crew_state, Enums.CrewState.CUFFED)
	assert_near(cuffs.cuffed_left, 60.0, 0.05, "S3.2: escaping takes 60 s")
	var walk: CrewIntent = CrewIntent.new()
	walk.move = Vector2(0.0, 1.0)
	_rt.set_bot_intent(0, walk)
	var p0: Vector3 = _crew().global_position
	await wait_seconds(0.5)
	assert_true(_flat_dist(_crew().global_position, p0) < 0.05, "cuffed crew cannot move")
	cuffs.cuffed_left = 0.3
	await wait_seconds(0.5)
	assert_eq(_crew().crew_state, Enums.CrewState.NORMAL, "broke free by themselves")


func test_s3_2_teammate_frees_cuffed_crew() -> void:
	var cuffs: CrewCuffs = CrewCuffs.of(_crew(), true)
	await wait_physics_frames(1)
	cuffs.cuff(999)
	var helper: CrewController = _rt.crew_controller(1) as CrewController
	helper.set_masked(true)
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, _crew().global_position + Vector3(0.8, 0.0, 0.0)))
	await wait_physics_frames(2)
	var freed_by: Array[int] = []
	cuffs.freed.connect(func(s: int) -> void: freed_by.append(s))
	ATestMaps.hold_interact(_rt, 1, _crew().net_id)
	await wait_seconds(Tweak.stealth().uncuff_s + 0.5)
	_rt.clear_bot_intent(1)
	assert_eq(_crew().crew_state, Enums.CrewState.NORMAL, "teammate removed the cuffs")
	assert_eq(freed_by, [1] as Array[int])


func test_s3_2_flag_off_keeps_p1_radio() -> void:
	var tw: StealthTweak = Tweak.stealth()
	var was: bool = tw.guard_cuffs_enabled
	tw.guard_cuffs_enabled = false
	_guard().notify_crew_spotted(_crew())
	await wait_physics_frames(1)
	tw.guard_cuffs_enabled = was
	assert_eq(_brain().cuff_phase, GuardBrain.CuffPhase.NONE)
	assert_true(_brain().radio_time_left > 0.0, "P1 simplification")


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
