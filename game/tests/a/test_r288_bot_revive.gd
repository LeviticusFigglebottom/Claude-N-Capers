## LEAD r288 (RT done path: P's verdict 2/4, three bot downs nobody revived, all cuffed): PD2 bots revive anyone downed
## (bots too) as their top loud task, and shoot the cop going for the cuffs on a downed teammate first.
extends TestCase

const TIME_SCALE: float = 3.0

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _ai_slots() -> Array[int]:
	var out: Array[int] = []
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			out.append(c.slot)
	return out


func _go_loud() -> void:
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)


class FakeCuffBrain extends Node:
	var mode: StringName = &"cuff"


## LEAD r288 (RT done path: downs -> cuffs -> custody): a cop going for the cuffs on a downed teammate (PoliceBrain mode
## &"cuff") is the bot's first target even when another cop stands nearer (cuffer_score_mult); clearing it at the patient
## before kneeling (cuffer_clear_first) ships OFF: the A/B showed it costs revives in a race decided on revive time.
func test_r288_bots_shoot_the_cuffing_cop_first() -> void:
	await _go_loud()
	var bot: CrewController = _crew(_ai_slots()[0])
	var b: CrewAiBrain = CrewAiBrain.of(bot)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(6, 0.05, -6)))
	_rt.teleport_crew(bot.slot, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var near: NpcBase = ATestMaps.add_npc_observer(_rt, &"police", Vector3(0, 0.05, -5), Vector3.BACK)
	var cuffer: NpcBase = ATestMaps.add_npc_observer(_rt, &"police", Vector3(6.6, 0.05, -6.4), Vector3.LEFT)
	for n: NpcBase in [near, cuffer]:
		n.max_health = 1.0e9
		n.health = n.max_health
		n.set_alert_state(Enums.AlertState.COMBAT)
	await wait_physics_frames(2)
	b._scan_left = 0.0
	b._tick_scan(0.1)
	assert_eq(b.target_enemy, near, "no cuffer: the nearest cop")
	var fake: FakeCuffBrain = FakeCuffBrain.new()
	fake.name = "Brain"
	cuffer.add_child(fake)
	b._scan_left = 0.0
	b._tick_scan(0.1)
	assert_eq(b.target_enemy, cuffer, "the cop going for the cuffs, before the nearer one")
	var c: CrewController = _crew(0)
	c.health.go_down()
	c.health.bleedout_left = 1.0  # last stand: revive_clear would skip an ordinary cop
	assert_eq(b._revive_threat(c, 0.1), null, "shipped (LEAD r288 A/B ruling): no clear-first, the revive is not delayed")
	b.tweak.cuffer_clear_first = true
	b._clear_for_net_id = 0
	var cleared: NpcBase = b._revive_threat(c, 0.1)
	b.tweak.cuffer_clear_first = false
	assert_eq(cleared, cuffer, "with the knob on, a cuffer at the patient is cleared even in a last stand")


## LEAD r288 (PD2 bots revive anyone downed): a downed BOT is revived by another bot.
func test_r288_bots_revive_bots() -> void:
	Engine.time_scale = TIME_SCALE
	await _go_loud()
	var slots: Array[int] = _ai_slots()
	assert_true(slots.size() >= 2, "two bots")
	var downed: CrewController = _crew(slots[0])
	_rt.teleport_crew(downed.slot, Transform3D(Basis.IDENTITY, Vector3(3, 0.05, 0)))
	await wait_physics_frames(2)
	downed.health.go_down()
	var ok: bool = await wait_until(func() -> bool: return downed.crew_state == Enums.CrewState.NORMAL,
		Tweak.crew().revive_time_s + 15.0)
	assert_true(ok, "another bot revived the downed bot (state %d)" % downed.crew_state)
