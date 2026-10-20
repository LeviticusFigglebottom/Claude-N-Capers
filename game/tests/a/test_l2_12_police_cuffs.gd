## A3-04 / L2.12: police walk up to a downed crew member who is not shooting and cuff them at 1 m
## (CUFFED, bleedout paused); they free themselves after 60 s (◇) or a teammate uncuffs them, and are
## downed again. D-145: police cuff downed players only from CustodyTweak.police_cuff_min_difficulty (Hazardous) up,
## so these run on Hazardous; on Routine / Tense the bleed-out timer alone decides custody.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _d108_cop: NpcBase = null


func before_each() -> void:
	_events.clear()
	EventBus.crew_cuffed.connect(_on_cuffed)
	EventBus.crew_uncuffed.connect(_on_uncuffed)
	await _launch(Enums.Difficulty.HAZARDOUS)


func _launch(difficulty: int) -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
		await wait_frames(2)
	_rt = await HeistLauncher.launch(&"unit_map", 1212, difficulty, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false})
	await wait_physics_frames(1)


func after_each() -> void:
	for pair: Array in [[EventBus.crew_cuffed, _on_cuffed], [EventBus.crew_uncuffed, _on_uncuffed]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _on_cuffed(slot: int, by: int) -> void:
	_events.append([&"cuffed", slot, by])


func _on_uncuffed(slot: int, by: int) -> void:
	_events.append([&"uncuffed", slot, by])


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


## Loud, slot 0 downed at the origin, slot 1 far away; a patrol officer 6 m away.
func _setup() -> NpcBase:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(-20, 0.05, 20)))
	_crew(0).set_masked()
	_crew(1).set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	_crew(0).health.go_down()
	return _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)))


func test_l2_12_tweak_values() -> void:
	var tw: CustodyTweak = CustodyTweak.data()
	assert_near(tw.police_cuff_range_m, 1.0, 0.001, "1 m")
	assert_near(tw.police_cuff_self_free_s, 60.0, 0.001, "60 s self-free")


## D-145 (P's GH Tense run: cuffed 3 s after the down): on Routine and Tense police never cuff a downed player.
func test_d145_no_police_cuffs_on_routine_and_tense() -> void:
	assert_eq(CustodyTweak.data().police_cuff_min_difficulty, Enums.Difficulty.HAZARDOUS, "cuffs from Hazardous up")
	for d: int in [Enums.Difficulty.ROUTINE, Enums.Difficulty.TENSE]:
		await _launch(d)
		_events.clear()
		await _setup()
		var c: CrewController = _crew(0)
		await wait_seconds(6.0)
		assert_eq(c.crew_state, Enums.CrewState.DOWNED, "difficulty %d: still downed, bleeding out (not cuffed)" % d)
		assert_false(CrewCuffs.can_police_cuff(c), "difficulty %d: never cuffable" % d)
		assert_true(_events.is_empty(), "difficulty %d: no crew_cuffed (%s)" % [d, _events])


func test_l2_12_police_cuff_downed_player() -> void:
	var cop: NpcBase = await _setup()
	var c: CrewController = _crew(0)
	var ok: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.CUFFED, 8.0)
	assert_true(ok, "cuffed by the police")
	assert_has(_events, [&"cuffed", 0, cop.net_id], "crew_cuffed(slot, cop)")
	var flat: float = Vector2(cop.global_position.x - c.global_position.x, cop.global_position.z - c.global_position.z).length()
	assert_true(flat <= CustodyTweak.data().police_cuff_range_m + 0.05, "cuffed from 1 m (%.2f)" % flat)
	var cuffs: CrewCuffs = CrewCuffs.of(c)
	assert_true(cuffs.cuffed_left > 55.0, "60 s self-free timer")
	var bleed: float = c.health.bleedout_left
	await wait_seconds(0.5)
	assert_near(c.health.bleedout_left, bleed, 0.001, "bleedout paused while cuffed")
	assert_false(c.weapons.can_fire(), "cuffed: cannot shoot")
	cuffs.cuffed_left = 0.05
	await wait_physics_frames(6)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "freed: downed again")
	assert_has(_events, [&"uncuffed", 0, -1], "freed themselves")


func test_l2_12_shooting_downed_player_not_cuffed() -> void:
	var c: CrewController = _crew(0)
	c.health.go_down()
	c.weapons.last_shot_age = 0.0
	assert_false(CrewCuffs.can_police_cuff(c), "a downed player who is shooting cannot be cuffed")
	c.weapons.last_shot_age = INF
	assert_false(CrewCuffs.can_police_cuff(c), "D-108: not within police_cuff_grace_s of going down")
	c.health.down_s = CustodyTweak.data().police_cuff_grace_s
	assert_true(CrewCuffs.can_police_cuff(c), "down and quiet for the grace: can be cuffed")
	c.health.revive(1)
	assert_false(CrewCuffs.can_police_cuff(c), "standing players are not police-cuffed")


func test_l2_12_teammate_uncuffs() -> void:
	var c: CrewController = _crew(0)
	c.health.go_down()
	var cuffs: CrewCuffs = CrewCuffs.of(c, true)
	c.health.down_s = CustodyTweak.data().police_cuff_grace_s  # D-108 grace elapsed
	assert_true(cuffs.cuff_downed(777), "cuff_downed")
	await wait_physics_frames(2)
	assert_eq(c.crew_state, Enums.CrewState.CUFFED)
	cuffs.free_crew(1)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "uncuffed by a teammate: downed again")
	assert_has(_events, [&"uncuffed", 0, 1])
	var rev: InteractableComponent = c.get_node("ReviveInteractable") as InteractableComponent
	assert_true(rev.enabled, "still revivable")


## Lead (D-082, PD2): police never cuff / arrest AI crew. A downed AI teammate with an officer next to it
## is not cuffed; it bleeds out and goes into custody.
func test_l2_12_police_never_cuff_downed_ai_crew() -> void:
	var bot: CrewController = _crew(1)
	assert_true(bot.is_ai, "slot 1 is an AI teammate")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(-20, 0.05, 20)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_crew(0).set_masked()
	bot.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	bot.health.go_down()
	bot.weapons.last_shot_age = INF
	assert_false(CrewCuffs.can_police_cuff(bot), "a downed, non-shooting AI is not police-cuffable")
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -2)))
	var closest: float = INF
	for _i: int in 30:  # 3 s
		await wait_physics_frames(6)
		closest = minf(closest, Vector2(cop.global_position.x, cop.global_position.z).length())
	assert_true(closest <= CustodyTweak.data().police_cuff_range_m + 0.5,
		"the officer reached the downed bot (closest %.2f m)" % closest)
	assert_eq(bot.crew_state, Enums.CrewState.DOWNED, "still downed, not cuffed")
	assert_true(_events.filter(func(e: Array) -> bool: return e[0] == &"cuffed").is_empty(), "no crew_cuffed")
	var bleed: float = bot.health.bleedout_left
	await wait_seconds(0.5)
	assert_true(bot.health.bleedout_left < bleed, "bleedout keeps running")
	bot.health.bleedout_left = 0.3  # skip the rest of the bleedout timer
	var gone: bool = await wait_until(func() -> bool: return bot.crew_state == Enums.CrewState.CUSTODY, 3.0)
	assert_true(gone, "bled out into custody (%s)" % Enums.CrewState.keys()[bot.crew_state])
	assert_true(_events.filter(func(e: Array) -> bool: return e[0] == &"cuffed").is_empty(), "never cuffed")


## D-108: going down right next to a cop is not an instant arrest. The cop may start only after
## police_cuff_grace_s down without firing, then needs police_cuff_time_s of uninterrupted hold.
func test_d108_cuff_grace_and_hold_when_down_next_to_cop() -> void:
	var c: CrewController = _crew(0)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(-20, 0.05, 20)))
	c.set_masked()
	_crew(1).set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.8)))
	await wait_physics_frames(2)
	c.health.go_down()
	var ct: CustodyTweak = CustodyTweak.data()
	var t0: int = Time.get_ticks_msec()
	await wait_seconds(ct.police_cuff_grace_s * 0.8)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "not cuffed within the grace")
	var ok: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.CUFFED, 6.0)
	assert_true(ok, "cuffed after the grace + hold")
	var took: float = float(Time.get_ticks_msec() - t0) / 1000.0
	assert_true(took >= ct.police_cuff_grace_s + ct.police_cuff_time_s - 0.1,
		"arrest took grace + hold (%.2f s)" % took)
	assert_has(_events, [&"cuffed", 0, cop.net_id])


## D-108: a downed player who keeps firing from the floor is never arrested.
func test_d108_firing_from_the_floor_prevents_arrest() -> void:
	var c: CrewController = await _d108_setup()
	var ct: CustodyTweak = CustodyTweak.data()
	var t: float = 0.0
	while t < ct.police_cuff_grace_s + ct.police_cuff_time_s + 1.0:
		c.weapons.last_shot_age = 0.0  # firing from the floor
		await wait_physics_frames(6)
		t += 0.1
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "a downed player who keeps firing is never cuffed")


## D-108: a hit on the arresting cop restarts the hold.
func test_d108_hurting_the_cop_restarts_the_hold() -> void:
	var c: CrewController = await _d108_setup()
	var cop: NpcBase = _d108_cop
	var ct: CustodyTweak = CustodyTweak.data()
	await wait_seconds(ct.police_cuff_grace_s + ct.police_cuff_time_s * 0.6)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "mid-hold")
	var info: Dictionary = Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"weapon.test",
		cop.global_position, Vector3.FORWARD, 0)
	cop.take_hit(info, c.net_id)
	await wait_seconds(ct.police_cuff_time_s * 0.6)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "the hit restarted the hold (would have finished by now)")



func _d108_setup() -> CrewController:
	var c: CrewController = _crew(0)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(-20, 0.05, 20)))
	c.set_masked()
	_crew(1).set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	_d108_cop = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.8)))
	await wait_physics_frames(2)
	c.health.go_down()
	return c
