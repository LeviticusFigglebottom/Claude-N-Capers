## A3-04 / L2.8: Taser and Phantom takedowns (CrewHealth.incapacitate) don't use bleedout and don't
## count as downs; the victim is helpless until a teammate revives them (D-093: or custody after the
## bleedout time).
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []


func before_each() -> void:
	_events.clear()
	EventBus.crew_tased.connect(_on_tased)
	EventBus.crew_cloaker_downed.connect(_on_cloaker)
	EventBus.crew_revived.connect(_on_revived)
	_rt = await HeistLauncher.launch(&"unit_map", 808, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})


func after_each() -> void:
	for pair: Array in [[EventBus.crew_tased, _on_tased], [EventBus.crew_cloaker_downed, _on_cloaker],
			[EventBus.crew_revived, _on_revived]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_tased(slot: int, by: int) -> void:
	_events.append([&"tased", slot, by])


func _on_cloaker(slot: int, by: int) -> void:
	_events.append([&"cloaker", slot, by])


func _on_revived(slot: int, by: int) -> void:
	_events.append([&"revived", slot, by])


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func test_l2_8_tased_no_down_no_bleedout_helpless() -> void:
	var c: CrewController = _crew(0)
	var h: CrewHealth = c.health
	var hp: float = h.health
	assert_true(h.incapacitate(Enums.CrewState.TASED, 4242), "tase applied")
	assert_eq(c.crew_state, Enums.CrewState.TASED)
	assert_true(h.is_incapacitated(), "is_incapacitated")
	assert_eq(h.downs_used, 0, "not a down")
	assert_eq(h.bleedout_left, 0.0, "no bleedout")
	assert_has(_events, [&"tased", 0, 4242], "crew_tased event")
	var start: Vector3 = c.global_position
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.sprint = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(0.5)
	assert_true(c.global_position.distance_to(start) < 0.05, "helpless: cannot move")
	assert_false(c.weapons.can_fire(), "helpless: cannot fire")
	assert_eq(c.crew_state, Enums.CrewState.TASED, "stays tased (no timer)")
	assert_near(h.health, hp, 0.001, "health untouched")
	assert_false(h.incapacitate(Enums.CrewState.CLOAKER_DOWNED, 1), "no double takedown")


func test_l2_8_revive_by_teammate() -> void:
	var c: CrewController = _crew(0)
	var mate: CrewController = _crew(1)
	c.health.incapacitate(Enums.CrewState.CLOAKER_DOWNED, 99)
	assert_has(_events, [&"cloaker", 0, 99], "crew_cloaker_downed event")
	var rev: InteractableComponent = c.get_node("ReviveInteractable") as InteractableComponent
	assert_true(rev.enabled, "revive interactable enabled")
	assert_eq(rev.availability(c), InteractableComponent.BLOCK_STATE, "cannot revive yourself")
	mate.set_masked()
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, c.global_position + Vector3(0.8, 0, 0)))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 1, c.net_id)
	var ok: bool = await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.NORMAL,
		Tweak.crew().revive_time_s + 2.0)
	_rt.clear_bot_intent(1)
	assert_true(ok, "revived by the teammate")
	assert_has(_events, [&"revived", 0, mate.slot], "crew_revived event")
	assert_eq(c.health.downs_used, 0, "still no down used")
	assert_false(rev.enabled, "revive interactable off again")


func test_l2_8_damage_while_tased_can_down() -> void:
	var c: CrewController = _crew(0)
	c.health.incapacitate(Enums.CrewState.TASED, 1)
	c.health.invuln_left = 0.0
	var info: Dictionary = Damage.info(10000.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO, Vector3.FORWARD)
	info["pierced_armor"] = true
	c.take_hit(info, 0)
	assert_eq(c.crew_state, Enums.CrewState.DOWNED, "zero health while tased -> downed")
	assert_eq(c.health.downs_used, 1, "that one is a down")


func test_l2_8_rejects_other_states() -> void:
	var c: CrewController = _crew(0)
	assert_false(c.health.incapacitate(Enums.CrewState.DOWNED, 0), "only TASED / CLOAKER_DOWNED")
	assert_eq(c.crew_state, Enums.CrewState.NORMAL)
	c.health.go_down()
	assert_false(c.health.incapacitate(Enums.CrewState.TASED, 0), "a downed crew member cannot be tased")
	assert_eq(c.crew_state, Enums.CrewState.DOWNED)


## D-093: a helpless member nobody revives within bleedout_time_s goes to custody, without a down.
func test_d093_helpless_not_revived_goes_to_custody() -> void:
	var c: CrewController = _crew(0)
	var h: CrewHealth = c.health
	assert_true(h.incapacitate(Enums.CrewState.CLOAKER_DOWNED, 7), "kicked down")
	assert_near(h.helpless_left, Tweak.crew().bleedout_time_s, 0.01, "helpless timer = bleedout time")
	h.helpless_left = 0.3  # shorten the 30 s wait
	assert_true(await wait_until(func() -> bool: return c.crew_state == Enums.CrewState.CUSTODY, 2.0), "custody")
	assert_eq(h.downs_used, 0, "no down counted")
