## A1-05 / S3.6: an unalerted Security Officer dies to any hit; an alerted one does not.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(2, 0)})
	await wait_physics_frames(1)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_s3_6_calm_guard_dies_to_any_hit() -> void:
	var npc: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	assert_true(npc.one_shot_when_unalerted, "guard prefab has the one-shot rule")
	assert_eq(npc.alert_state, Enums.AlertState.CALM)
	var out: Dictionary = npc.apply_damage({"amount": 1.0, "zone": Enums.HitZone.BODY})
	assert_true(bool(out["killed"]), "one-shot")
	assert_false(npc.alive)


func test_s3_6_curious_guard_dies_to_any_hit() -> void:
	var npc: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	npc.notify_stimulus(1, &"bag", npc.global_position + Vector3(5, 0, 0))
	await wait_physics_frames(1)
	assert_eq(npc.alert_state, Enums.AlertState.CURIOUS)
	assert_true(bool(npc.apply_damage({"amount": 1.0, "zone": Enums.HitZone.BODY})["killed"]))


func test_s3_6_alarmed_guard_survives_small_hit() -> void:
	var npc: NpcBase = _rt.npcs(&"guard")[1] as NpcBase
	npc.notify_crew_spotted(_rt.crew_controller(0))
	await wait_physics_frames(1)
	assert_eq(npc.alert_state, Enums.AlertState.ALARMED)
	var out: Dictionary = npc.apply_damage({"amount": 1.0, "zone": Enums.HitZone.BODY})
	assert_false(bool(out["killed"]), "alerted guard is not one-shot")
	assert_true(npc.alive)
	assert_near(npc.health, npc.max_health - 1.0, 0.001)
