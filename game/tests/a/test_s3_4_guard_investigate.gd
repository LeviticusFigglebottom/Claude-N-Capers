## A1-05 / S3.4: suspicious stimulus/noise -> CURIOUS ("?") -> INVESTIGATING (walks over, budget)
## -> back to CALM; alarm-reaction stimuli (corpse) and gunshots -> ALARMED.
extends TestCase

var _rt: HeistRuntime = null
var _saved_budget: float = 0.0


func before_each() -> void:
	_saved_budget = Tweak.stealth().investigate_budget_s
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(1, 0)})
	await wait_physics_frames(1)


func after_each() -> void:
	Tweak.stealth().investigate_budget_s = _saved_budget
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _guard() -> NpcBase:
	return _rt.npcs(&"guard")[0] as NpcBase


func _brain() -> GuardBrain:
	return _guard().get_node("Brain") as GuardBrain


func test_s3_4_investigate_stimulus_curious_then_walks_to_it() -> void:
	var npc: NpcBase = _guard()
	var target: Vector3 = npc.global_position + Vector3(6, 0, 0)
	npc.notify_stimulus(1, &"bag", target)
	await wait_physics_frames(1)
	assert_eq(_brain().state_name(), &"curious", "? -> CURIOUS")
	var start_d: float = npc.global_position.distance_to(target)
	await wait_seconds(_brain().tweak.curious_beat_s * 0.5)
	assert_near(npc.global_position.distance_to(target), start_d, 0.05, "stops for the curious beat")
	var ok: bool = await wait_until(func() -> bool: return _brain().state_name() == &"investigating", 3.0)
	assert_true(ok, "CURIOUS -> INVESTIGATING")
	ok = await wait_until(func() -> bool:
		return Vector2(npc.global_position.x - target.x, npc.global_position.z - target.z).length() \
			<= _brain().tweak.investigate_arrive_m + 0.2, 8.0)
	assert_true(ok, "walked to the stimulus")
	assert_eq(_brain().state_name(), &"investigating", "looks around there")
	assert_false(_rt.stealth.alarm_raised, "investigating raises nothing")


func test_s3_4_budget_expires_back_to_calm() -> void:
	Tweak.stealth().investigate_budget_s = 2.0
	var npc: NpcBase = _guard()
	npc.notify_noise(npc.global_position + Vector3(0, 0, 3), &"glass", 0)
	await wait_physics_frames(1)
	assert_eq(_brain().state_name(), &"curious", "glass noise -> CURIOUS")
	var ok: bool = await wait_until(func() -> bool: return _brain().state_name() == &"calm", 6.0)
	assert_true(ok, "nothing confirmed -> CALM")
	assert_false(_rt.stealth.alarm_raised)


func test_s3_4_corpse_stimulus_alarms() -> void:
	var npc: NpcBase = _guard()
	npc.notify_stimulus(2, &"corpse", npc.global_position + Vector3(4, 0, 0))
	await wait_physics_frames(1)
	assert_eq(_brain().state_name(), &"alarmed", "corpse -> ALARMED")
	assert_true(_brain().radio_time_left > 0.0, "radio call (S3.3)")


func test_s3_4_curious_escalates_to_alarm() -> void:
	var npc: NpcBase = _guard()
	npc.notify_stimulus(1, &"drill", npc.global_position + Vector3(5, 0, 0))
	await wait_physics_frames(1)
	assert_eq(_brain().state_name(), &"curious")
	npc.notify_noise(npc.global_position + Vector3(5, 0, 0), &"gunshot", 0)
	await wait_physics_frames(1)
	assert_eq(_brain().state_name(), &"alarmed", "gunshot -> ALARMED")


func test_s3_4_ignored_stimulus_kind_does_nothing() -> void:
	var npc: NpcBase = _guard()
	npc.notify_stimulus(1, &"open_vault", npc.global_position + Vector3(5, 0, 0))
	await wait_physics_frames(2)
	assert_eq(_brain().state_name(), &"calm", "S4.2: unknown/ignored kinds")
