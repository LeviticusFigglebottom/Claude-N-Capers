## D-014 / L6.1 regression (P's ND stealth pass, round 164): in casing and masked stealth, solo human, the AI teammates
## wait at the van: they never follow the leader, step to formation slots or unstack, until loud (or the D-014 P4
## order takes them out).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _bots() -> Array[CrewController]:
	var out: Array[CrewController] = []
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			out.append(c)
	return out


func _check_stay(heist: StringName, map_opts: Dictionary) -> void:
	_rt = await HeistLauncher.launch(heist, 4401, Enums.Difficulty.ROUTINE, self, map_opts)
	await wait_physics_frames(3)
	var bots: Array[CrewController] = _bots()
	assert_true(bots.size() >= 1, "%s: AI teammates present (%d)" % [heist, bots.size()])
	var start: Dictionary = {}
	for b: CrewController in bots:
		start[b.slot] = b.global_position
	var leader: CrewController = _rt.crew_controller(0) as CrewController
	var lp: Vector3 = leader.global_position
	Engine.time_scale = 3.0
	for step: int in range(6):  # the leader walks off in 2 m hops (casing, then masked)
		if step == 3:
			leader.set_masked(true)
		var to: Vector3 = lp + Vector3(0, 0, -2.0 * float(step + 1))
		_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, to))
		await wait_seconds(0.5 * 3.0)
	Engine.time_scale = 1.0
	assert_false(_rt.went_loud, "%s: still stealth" % heist)
	for b: CrewController in bots:
		var moved: float = Vector2(b.global_position.x - start[b.slot].x, b.global_position.z - start[b.slot].z).length()
		assert_true(moved < 0.3, "%s: bot slot %d waits at the van (moved %.2f m, mode %d)" % [heist, b.slot, moved,
			CrewAiBrain.of(b).mode])


func test_l6_1_bots_wait_at_the_van_unit_map() -> void:
	await _check_stay(&"unit_map", {"map_packed": ATestMaps.basic(0, 0)})


func test_l6_1_bots_wait_at_the_van_night_deposit() -> void:
	await _check_stay(&"night_deposit", {})


## P PO-pass: a human walking onto a waiting (or idle loud) bot gets personal_radius_m of room: the waiting bot
## steps aside (a short step), a loud bot steps back to its slot.
func test_l6_1_bot_steps_out_of_a_humans_personal_radius() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4402, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(3)
	var bot: CrewController = _bots()[0]
	var radius: float = CrewAiBrain.of(bot).tweak.personal_radius_m
	for loud: bool in [false, true]:
		if loud:
			_rt.stealth.raise_alarm(&"test", 0)
			await wait_seconds(4.0)  # the bots regroup on the leader first
		var at: Vector3 = bot.global_position
		_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, at + Vector3(0.15, 0.0, 0.1)))
		var leader: CrewController = _rt.crew_controller(0) as CrewController
		var clear: bool = await wait_until(func() -> bool:
			return Vector2(bot.global_position.x - leader.global_position.x,
				bot.global_position.z - leader.global_position.z).length() >= radius * 0.9, 3.0)
		var moved: float = Vector2(bot.global_position.x - at.x, bot.global_position.z - at.z).length()
		var tag: String = "loud" if loud else "stealth"
		assert_true(clear, "%s: the bot stepped out of the player's %.1f m" % [tag, radius])
		if not loud:  # loud, the unstack sends it back to its formation slot (follow_min_m out)
			assert_true(moved < 1.5, "%s: a short step (%.2f m)" % [tag, moved])
			assert_eq(CrewAiBrain.of(bot).mode, CrewAiBrain.Mode.STEALTH_WAIT, "still waiting at the van")


## LEAD r311 (P's RT smoke: a casing bot idled 1 m dead ahead of the player for the first minute): a waiting bot that the
## player faces from closer than view_clear_m steps sideways out of his view cone, a short step, still waiting.
func test_r311_waiting_bot_steps_out_of_the_players_view() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 4403, Enums.Difficulty.ROUTINE, self, {"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(3)
	var bot: CrewController = _bots()[0]
	var tw: CrewAiTweak = CrewAiBrain.of(bot).tweak
	var at: Vector3 = bot.global_position
	var leader: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, at + Vector3(0.05, 0.0, 1.0)))  # 1 m behind it, looking at it (-Z)
	leader.look_yaw = 0.0
	leader.look_pitch = 0.0
	var in_view: Callable = func() -> bool:
		var to: Vector3 = bot.global_position - leader.global_position
		to.y = 0.0
		var fwd: Vector3 = leader.aim_direction()
		fwd.y = 0.0
		return to.length() < tw.view_clear_m and rad_to_deg(fwd.angle_to(to)) < tw.view_clear_deg
	assert_true(in_view.call(), "starts dead ahead at 1 m")
	var clear: bool = await wait_until(func() -> bool: return not in_view.call(), 3.0)
	assert_true(clear, "stepped out of the player's view")
	var moved: float = Vector2(bot.global_position.x - at.x, bot.global_position.z - at.z).length()
	assert_true(moved < 1.5, "a short sideways step (%.2f m)" % moved)
	assert_eq(CrewAiBrain.of(bot).mode, CrewAiBrain.Mode.STEALTH_WAIT, "still waiting at the van")
	var p: Vector3 = bot.global_position
	await wait_seconds(1.0)
	assert_true(bot.global_position.distance_to(p) < 0.2, "and settles there (no jitter on the cone edge)")
