## A3-04 / L2.12: police walk up to a downed crew member who is not shooting and cuff them at 1 m
## (CUFFED, bleedout paused); they free themselves after 60 s (◇) or a teammate uncuffs them, and are
## downed again.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []


func before_each() -> void:
	_events.clear()
	EventBus.crew_cuffed.connect(_on_cuffed)
	EventBus.crew_uncuffed.connect(_on_uncuffed)
	_rt = await HeistLauncher.launch(&"unit_map", 1212, Enums.Difficulty.ROUTINE, self,
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
	assert_true(CrewCuffs.can_police_cuff(c), "not shooting: can be cuffed")
	c.health.revive(1)
	assert_false(CrewCuffs.can_police_cuff(c), "standing players are not police-cuffed")


func test_l2_12_teammate_uncuffs() -> void:
	var c: CrewController = _crew(0)
	c.health.go_down()
	var cuffs: CrewCuffs = CrewCuffs.of(c, true)
	assert_true(cuffs.cuff_downed(777), "cuff_downed")
	await wait_physics_frames(2)
	assert_eq(c.crew_state, Enums.CrewState.CUFFED)
	cuffs.free_crew(1)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "uncuffed by a teammate: downed again")
	assert_has(_events, [&"uncuffed", 0, 1])
	var rev: InteractableComponent = c.get_node("ReviveInteractable") as InteractableComponent
	assert_true(rev.enabled, "still revivable")
