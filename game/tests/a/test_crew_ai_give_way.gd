## PO6-15 (PD2 bots step aside; P's ND loud run: Crew1 body-blocked the player in the B5 basement corridor): a human
## walking into an idle bot in a corridor makes it sidestep off the human's line toward free navmesh, hold, then
## resume. A reviving bot never moves. The same seed gives the same sidestep. A moving leader's formation slot ahead
## of it in a narrow passage is mirrored behind it.
extends TestCase

const SEED: int = 4545
const BOT_START: Vector3 = Vector3(0.0, 0.05, 0.0)
const HUMAN_START: Vector3 = Vector3(0.0, 0.05, 4.5)
const FAR_A: Vector3 = Vector3(8.0, 0.05, 9.0)
const FAR_B: Vector3 = Vector3(10.0, 0.05, 9.0)

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	await _teardown()


func _teardown() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


## Loud, in a 2.4 m corridor along Z: the human (slot 0) at HUMAN_START facing -Z, bot 1 idle at BOT_START (inside
## the follow band, not following), bots 2 / 3 ordered to hold far outside the corridor.
func _launch(seed_value: int) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", seed_value, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_corridor(2.4, 16.0)})
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "nav synced")
	for s: int in range(4):
		Modifiers.set_source(s, &"test.immune", {&"defense.damage_taken_mult": 0.0})
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, HUMAN_START))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, BOT_START))
	_rt.teleport_crew(2, Transform3D(Basis.IDENTITY, FAR_A))
	_rt.teleport_crew(3, Transform3D(Basis.IDENTITY, FAR_B))
	CrewAiBrain.of(_crew(2)).receive_order(&"hold", 0, FAR_A)
	CrewAiBrain.of(_crew(3)).receive_order(&"hold", 0, FAR_B)
	CrewAiBrain.of(_crew(1))._following = false
	await wait_physics_frames(2)


## The human walks straight down the corridor (-Z) on a scripted intent.
func _walk_human() -> void:
	var ci: CrewIntent = CrewIntent.new()
	ci.look_yaw = 0.0
	ci.move = Vector2(0.0, 1.0)
	_rt.set_bot_intent(0, ci)


## Runs the walk-into scenario on `seed_value`; returns {side, target, at_cross_x, off_by_s, passed, bot_after}.
func _give_way_run(seed_value: int) -> Dictionary:
	await _launch(seed_value)
	var bot: CrewController = _crew(1)
	var human: CrewController = _crew(0)
	var brain: CrewAiBrain = CrewAiBrain.of(bot)
	assert_eq(brain.mode, CrewAiBrain.Mode.FOLLOW, "setup: the bot idles in follow mode")
	assert_true(absf(bot.global_position.x) < 0.05, "setup: the bot stands on the human's line")
	_walk_human()
	var out: Dictionary = {"side": 0, "target": Vector3.INF, "at_cross_x": 0.0, "off_by_s": INF, "passed": false}
	var trigger_frame: int = -1
	var crossed: bool = false
	for f: int in range(300):
		await wait_physics_frames(1)
		if trigger_frame < 0 and brain.give_way_side != 0:
			trigger_frame = f
			out["side"] = brain.give_way_side
			out["target"] = brain.give_way_target
		if trigger_frame >= 0 and out["off_by_s"] == INF and absf(bot.global_position.x) >= 0.6:
			out["off_by_s"] = float(f - trigger_frame) / float(Engine.physics_ticks_per_second)
		if not crossed and human.global_position.z <= BOT_START.z:
			crossed = true
			out["at_cross_x"] = absf(bot.global_position.x)
		if human.global_position.z < BOT_START.z - 1.5:
			out["passed"] = true
			break
	out["bot_after"] = bot.global_position
	_rt.clear_bot_intent(0)
	return out


func test_po6_15_idle_bot_gives_way_in_a_corridor() -> void:
	var r: Dictionary = await _give_way_run(SEED)
	assert_true(r["side"] != 0, "the bot started giving way")
	assert_true(float(r["off_by_s"]) <= 1.0, "off the human's line by 0.6 m within 1 s (%.2f s)" % float(r["off_by_s"]))
	assert_true(float(r["at_cross_x"]) >= 0.6,
		"aside (%.2f m off the line) when the human reached its spot" % float(r["at_cross_x"]))
	assert_true(bool(r["passed"]), "the human walked on past the bot's spot")
	# Hold briefly, then resume (the leader is gone down the corridor: the bot follows again).
	var brain: CrewAiBrain = CrewAiBrain.of(_crew(1))
	assert_true(await wait_until(func() -> bool: return brain.give_way_left <= 0.0, 4.0), "the give-way ends")
	assert_eq(brain.give_way_side, 0, "and resets")


func test_po6_15_reviving_bot_does_not_move() -> void:
	await _launch(SEED)
	var bot: CrewController = _crew(1)
	var brain: CrewAiBrain = CrewAiBrain.of(bot)
	_rt.teleport_crew(3, Transform3D(Basis.IDENTITY, Vector3(0.7, 0.05, -0.7)))
	await wait_physics_frames(2)
	_crew(3).health.go_down()
	var reviving: bool = await wait_until(func() -> bool:
		return brain.mode == CrewAiBrain.Mode.REVIVE and not _rt.interaction.session(1).is_empty(), 4.0)
	assert_true(reviving, "setup: bot 1 holds the revive")
	var start: Vector3 = bot.global_position
	_walk_human()
	var human: CrewController = _crew(0)
	var moved: float = 0.0
	var gave_way: bool = false
	var dropped: bool = false
	for _f: int in range(240):
		await wait_physics_frames(1)
		moved = maxf(moved, Vector2(bot.global_position.x - start.x, bot.global_position.z - start.z).length())
		gave_way = gave_way or brain.give_way_left > 0.0
		dropped = dropped or (_crew(3).crew_state == Enums.CrewState.DOWNED and _rt.interaction.session(1).is_empty())
		if human.global_position.z < start.z - 1.5:
			break
	_rt.clear_bot_intent(0)
	assert_true(human.global_position.z < start.z - 1.5, "the human walked through")
	assert_false(gave_way, "a reviving bot never gives way")
	assert_true(moved < 0.05, "and does not move (%.3f m)" % moved)
	assert_false(dropped, "the revive session was never dropped")


func test_po6_15_give_way_is_deterministic() -> void:
	var a: Dictionary = await _give_way_run(SEED)
	await _teardown()
	var b: Dictionary = await _give_way_run(SEED)
	assert_true(int(a["side"]) != 0, "run 1 gave way")
	assert_eq(int(a["side"]), int(b["side"]), "same seed: same side")
	assert_true((a["target"] as Vector3).is_equal_approx(b["target"] as Vector3),
		"same seed: same sidestep target (%s vs %s)" % [a["target"], b["target"]])
	assert_true((a["bot_after"] as Vector3).distance_to(b["bot_after"] as Vector3) < 0.01,
		"same seed: same place after the pass (%s vs %s)" % [a["bot_after"], b["bot_after"]])


func test_po6_15_formation_slot_not_ahead_of_a_leader_walking_a_corridor() -> void:
	await _launch(SEED)
	for s: int in [1, 2, 3]:  # all three bots ahead of the leader, down the corridor
		_rt.teleport_crew(s, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 1.0 - float(s))))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 4.0)))
	await wait_physics_frames(2)
	var leader: CrewController = _crew(0)
	var brain: CrewAiBrain = CrewAiBrain.of(_crew(2))
	leader.velocity = Vector3.ZERO
	assert_true(brain._formation_slot(leader).z < leader.global_position.z, "standing leader: the slot toward the bots")
	leader.velocity = Vector3(0.0, 0.0, -3.5)
	assert_true(brain._formation_slot(leader).z > leader.global_position.z,
		"leader walking down the corridor at the bots: the slot is behind it")
	leader.velocity = Vector3(0.0, 0.0, 3.5)
	assert_true(brain._formation_slot(leader).z < leader.global_position.z, "walking away: the slot unchanged")
