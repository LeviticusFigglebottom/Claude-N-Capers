## A3-04 / L2.12: police walk up to a downed crew member who is not shooting and cuff them at 1 m
## (CUFFED). LEAD 2026-10-21 (Cataclysm 2024: 15 CUFFED <-> DOWNED cycles in 15 min): no self-free, and
## the bleed-out keeps running while cuffed; a teammate uncuffs them (downed again, revivable), else custody.
## D-145: police cuff downed players only from CustodyTweak.police_cuff_min_difficulty (Hazardous) up, so these
## run on Hazardous; on Routine / Tense the bleed-out timer alone decides custody.
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
	assert_true(is_inf(cuffs.cuffed_left), "no self-free timer (PD2: wait for a teammate)")
	var bleed: float = c.health.bleedout_left
	await wait_seconds(0.5)
	assert_true(c.health.bleedout_left < bleed - 0.3, "the bleed-out keeps running while cuffed")
	assert_false(c.weapons.can_fire(), "cuffed: cannot shoot")
	assert_eq(c.crew_state, Enums.CrewState.CUFFED, "still cuffed: never flips back to DOWNED on its own")
	c.health.bleedout_left = 0.2  # skip the rest of the bleed-out
	var gone: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.CUSTODY, 3.0)
	assert_true(gone, "unrescued, the cuffed heister goes into custody when the bleed-out ends")
	assert_false(_events.has([&"uncuffed", 0, -1]) and c.crew_state == Enums.CrewState.DOWNED, "never freed themselves")


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


## D-167.1 (P AH Hazardous read #3: a Wrecker cuffed the pilot on his first down): only regular police arrest. Specials
## and Brandt / Aegis never start a police cuff; a Wrecker standing over a downed, quiet player fights on.
func test_d167_only_regular_police_cuff() -> void:
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var far: Transform3D = Transform3D(Basis.IDENTITY, Vector3(30, 0.05, 30))
	var cop: NpcBase = dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"), far, null)
	assert_true(PoliceBrain.may_cuff(cop), "a patrol officer arrests")
	for id: StringName in [&"enemy.wrecker_g", &"enemy.bulwark", &"enemy.corpsman", &"enemy.phantom", &"enemy.stinger",
			&"enemy.longshot"]:
		var def: EnemyDef = dir.enemy_def_for(id)
		assert_true(def != null and def.is_special, "%s is a special" % id)
		var sp: NpcBase = _rt.spawn_npc(&"police", far, {"enemy_def": def})
		assert_false(PoliceBrain.may_cuff(sp), "%s never cuffs" % id)
	var aegis: NpcBase = dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"), far, null)
	aegis.set_meta(AegisCaptain.META_AEGIS, true)
	assert_false(PoliceBrain.may_cuff(aegis), "an Aegis unit never cuffs")
	cop.queue_free()
	# live: a Wrecker next to a downed, quiet player
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, Vector3(-20, 0.05, 20)))
	_crew(0).set_masked()
	_crew(1).set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	_crew(0).health.go_down()
	_crew(0).health.down_s = CustodyTweak.data().police_cuff_grace_s
	var wrecker: NpcBase = dir.spawn_enemy(dir.enemy_def_for(&"enemy.wrecker_g"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -2)), null)
	assert_true(wrecker != null and wrecker.get_node(^"Brain") is PoliceBrain, "the Wrecker runs a PoliceBrain")
	await wait_seconds(5.0)
	assert_eq(_crew(0).crew_state, Enums.CrewState.DOWNED, "still downed: the Wrecker did not cuff")
	assert_true(_events.filter(func(e: Array) -> bool: return e[0] == &"cuffed").is_empty(), "no crew_cuffed")


## D-167.2: cuffed is not custody. Solo human cuffed with a bot in custody: no "all humans in custody" fail while the
## bleed-out runs; it fails once the bleed-out puts him in custody (solo custody = fail, D-167.3).
func test_d167_cuffed_is_not_custody_for_the_solo_fail() -> void:
	var cs: CustodySystem = CustodySystem.of(_rt)
	var human: CrewController = _crew(0)
	var bot: CrewController = _crew(1)
	human.set_masked()
	bot.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	bot.health.go_to_custody()
	human.health.go_down()
	human.health.down_s = CustodyTweak.data().police_cuff_grace_s
	assert_true(CrewCuffs.of(human, true).cuff_downed(777), "cuffed")
	await wait_physics_frames(2)
	assert_eq(human.crew_state, Enums.CrewState.CUFFED)
	assert_false(cs._should_fail(), "cuffed, bleeding out: not custody, no fail")
	await wait_seconds(CustodyTweak.data().all_custody_fail_delay_s + 1.0)
	assert_ne(_rt.phase, Enums.HeistPhase.ENDED, "no heist fail while cuffed")
	human.health.bleedout_left = 0.2
	var held: bool = await wait_until(func() -> bool: return human.crew_state == Enums.CrewState.CUSTODY, 3.0)
	assert_true(held, "the bleed-out ended: custody")
	assert_true(cs._should_fail(), "now every human is in custody, no free bot: the fail rule holds")
