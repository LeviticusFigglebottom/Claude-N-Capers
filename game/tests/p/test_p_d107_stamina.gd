## D-107: stamina and jumping follow PD2 (playermovement.lua / playerstandard.lua). Real input (PInputDriver).
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 107, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()


func after_each() -> void:
	_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _apex(c: CrewController, ticks: int = 60) -> float:
	var y0: float = c.global_position.y
	var top: float = 0.0
	for _k: int in ticks:
		await wait_physics_frames(1)
		top = maxf(top, c.global_position.y - y0)
	return top


func test_sprint_starts_above_threshold_and_runs_to_zero() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	await wait_physics_frames(5)
	c.stamina.value = tw.stamina_min_threshold - 1.0
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await wait_physics_frames(10)
	assert_false(c.sprinting, "no sprint start at %.1f (threshold %.1f)" % [c.stamina.value, tw.stamina_min_threshold])
	assert_true(c.stamina.exhausted, "exhausted below the threshold")
	_inp.release(&"sprint")
	await wait_physics_frames(2)
	c.stamina.value = tw.stamina_min_threshold + 2.0
	_inp.press(&"sprint")
	await wait_physics_frames(5)
	assert_true(c.sprinting, "starts above the threshold")
	assert_false(c.stamina.exhausted, "not exhausted while sprinting")
	c.stamina.value = 1.0  # below the threshold, still running
	await wait_physics_frames(10)
	assert_true(c.sprinting, "a running sprint continues below the threshold (%.2f)" % c.stamina.value)
	var ok: bool = await wait_until(func() -> bool: return not c.sprinting, 2.0)
	assert_true(ok, "stops when stamina runs out")
	assert_near(c.stamina.value, 0.0, 0.05, "ran to 0")


func test_regen_waits_one_second_after_the_sprint() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	await wait_physics_frames(5)
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await wait_seconds(1.0)
	_inp.release(&"sprint")
	_inp.release(&"move_forward")
	assert_true(await wait_until(func() -> bool: return not c.sprinting, 1.0), "stopped")
	await wait_physics_frames(1)
	c.stamina.value = 20.0  # deeper than a 1 s sprint drains, so regeneration is not capped at max
	var v0: float = c.stamina.value
	await wait_seconds(tw.stamina_regen_delay_s * 0.8)
	assert_near(c.stamina.value, v0, 0.01, "no regen during the %.1f s delay" % tw.stamina_regen_delay_s)
	await wait_seconds(tw.stamina_regen_delay_s * 0.2 + 1.0)
	assert_true(c.stamina.value > v0 + tw.stamina_regen_per_s * 0.7, "regenerates at %.0f/s after it" % tw.stamina_regen_per_s)


func test_jumps_never_blocked_and_only_run_jumps_cost() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	await wait_physics_frames(5)
	c.stamina.value = 0.0
	_inp.press(&"jump")
	var top: float = await _apex(c)
	_inp.release(&"jump")
	assert_true(top > 0.8, "jumps at 0 stamina (apex %.2f m)" % top)
	await wait_physics_frames(10)
	c.stamina.value = 30.0
	_inp.press(&"jump")
	await wait_physics_frames(3)
	_inp.release(&"jump")
	assert_true(c.stamina.value >= 30.0 - 0.01, "a standing jump costs nothing (%.2f)" % c.stamina.value)
	await _apex(c, 60)
	_inp.press(&"move_forward")
	_inp.press(&"sprint")
	await wait_seconds(tw.stamina_run_jump_min_s + 0.3)
	var before: float = c.stamina.value
	var y0: float = c.global_position.y
	_inp.press(&"jump")
	await wait_physics_frames(6)
	_inp.release(&"jump")
	var after: float = c.stamina.value
	assert_true(c.global_position.y > y0 + 0.05, "jumped")
	var run_drain: float = tw.stamina_drain_per_s * 6.0 / Engine.physics_ticks_per_second
	assert_near(before - after, tw.stamina_jump_cost + run_drain, 0.12,
		"a run-jump costs %.0f on top of the sprint drain (%.2f -> %.2f)" % [tw.stamina_jump_cost, before, after])


func test_jump_cooldown() -> void:
	var c: CrewController = _crew()
	var tw: CrewTweak = Tweak.crew()
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	await wait_physics_frames(5)
	# A very heavy bag (jump x0.25) lands in ~0.24 s, inside the 0.55 s cooldown.
	var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, c.global_position), true,
		Enums.LootWeight.VERY_HEAVY)
	await wait_physics_frames(1)
	loot.carry(bag, c)
	await wait_physics_frames(5)
	var takeoffs: Array[float] = []
	var air: bool = false
	var landed: int = 0
	var y0: float = c.global_position.y
	_inp.press(&"jump")
	for k: int in 90:
		await wait_physics_frames(1)
		var up: bool = c.global_position.y - y0 > 0.005
		if up and not air:
			takeoffs.append(float(k) / Engine.physics_ticks_per_second)
		if air and not up:
			landed += 1
			if landed == 1:  # re-press right after the first landing (a held jump fires once, PI-05)
				_inp.release(&"jump")
				await wait_physics_frames(1)
				_inp.press(&"jump")
		air = up
	_inp.release(&"jump")
	assert_true(takeoffs.size() >= 2, "a re-press jumps again (%d takeoffs)" % takeoffs.size())
	if takeoffs.size() >= 2:
		assert_true(takeoffs[1] - takeoffs[0] >= tw.jump_cooldown_s - 0.04,
			"%.2f s between jumps (cooldown %.2f)" % [takeoffs[1] - takeoffs[0], tw.jump_cooldown_s])


func test_jump_while_crouched_stands_up() -> void:
	var c: CrewController = _crew()
	await wait_physics_frames(5)
	_inp.press(&"crouch")
	await wait_physics_frames(10)
	assert_true(c.crouched, "crouched")
	_inp.press(&"jump")
	var top: float = await _apex(c, 20)
	_inp.release(&"jump")
	assert_false(c.crouched, "jump stands up")
	assert_true(top < 0.05, "no jump out of a crouch (%.3f m)" % top)
	await wait_physics_frames(10)
	assert_false(c.crouched, "stays up while crouch is still held")
	_inp.release(&"crouch")
	await wait_physics_frames(3)
	_inp.press(&"crouch")
	await wait_physics_frames(10)
	assert_true(c.crouched, "a new crouch press crouches again")
