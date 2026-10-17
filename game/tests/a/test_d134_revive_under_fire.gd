## D-134 (LEAD, from ND-1: two bots inside revive range never finished a revive under fire): a revive in progress is
## never interrupted by damage, for a human reviver and a bot alike; a stun / flash (and going down, a tase, leaving
## range, releasing) still cancels it. Other hold interactions keep S9.1 (damage cancels).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1340, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	for c: CrewController in _rt.crew_members():
		c.set_masked()


## `reviver` holds interact on `downed` while taking a small hit every 0.4 s; returns whether the revive completed.
func _revive_under_fire(reviver: CrewController, downed: CrewController) -> bool:
	downed.health.go_down()
	_rt.teleport_crew(reviver.slot, Transform3D(Basis.IDENTITY, downed.global_position + Vector3(0.8, 0, 0)))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, reviver.slot, downed.net_id)
	var t: float = 0.0
	var hits: int = 0
	while t < Tweak.crew().revive_time_s + 1.5 and downed.crew_state != Enums.CrewState.NORMAL:
		await wait_seconds(0.4)
		t += 0.4
		reviver.health.take_hit(Damage.info(1.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"test", reviver.global_position,
			Vector3.FORWARD, 0))
		hits += 1
	_rt.clear_bot_intent(reviver.slot)
	assert_true(hits >= 10, "the reviver was hit throughout (%d hits)" % hits)
	return downed.crew_state == Enums.CrewState.NORMAL


func test_d134_bot_revive_completes_under_fire() -> void:
	await _launch()
	var me: CrewController = _rt.crew_controller(0) as CrewController
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	assert_true(await _revive_under_fire(bot, me), "the bot's revive finishes while it is being shot")


func test_d134_human_revive_completes_under_fire() -> void:
	await _launch()
	var me: CrewController = _rt.crew_controller(0) as CrewController
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	assert_true(await _revive_under_fire(me, bot), "the human's revive finishes while being shot")


func test_d134_flash_still_cancels_a_revive() -> void:
	await _launch()
	var me: CrewController = _rt.crew_controller(0) as CrewController
	var bot: CrewController = _rt.crew_controller(1) as CrewController
	me.health.go_down()
	_rt.teleport_crew(1, Transform3D(Basis.IDENTITY, me.global_position + Vector3(0.8, 0, 0)))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 1, me.net_id)
	await wait_seconds(1.0)
	assert_true(_rt.interaction.progress(1) > 0.0, "setup: reviving")
	bot.health.flash(1.0)
	await wait_physics_frames(1)
	assert_true(_rt.interaction.session(1).is_empty() or _rt.interaction.progress(1) < 0.05,
		"a flash cancels the revive (progress %.2f)" % _rt.interaction.progress(1))
	_rt.clear_bot_intent(1)


func test_d134_damage_still_cancels_other_interactions() -> void:
	await _launch()
	var me: CrewController = _rt.crew_controller(0) as CrewController
	var comp: InteractableComponent = InteractableComponent.new()
	comp.kind = &"test_hold"
	_rt.interaction._sessions[0] = {"comp": comp, "crew": me, "progress": 0.3, "duration": 5.0,
		"start_pos": me.global_position, "aimed": true, "owner_id": 0}
	_rt.interaction.interrupt_on_damage(0)
	assert_true(_rt.interaction.session(0).is_empty(), "S9.1: damage cancels a non-revive hold")
	comp.free()
