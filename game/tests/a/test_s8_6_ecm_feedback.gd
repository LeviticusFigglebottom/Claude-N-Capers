## A2-03 / S8.6: ECM feedback. Interacting with a placed ECM (built into every ECM, D-038) stuns non-Cloaker
## enemies within 15 m for 6 s (no radio progress, blind, motor still); in stealth it is an ALARM
## stimulus, so alerted guards radio once they recover. 4 min recharge, retrigger needs
## stealth.ecm_feedback_retrigger.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func after_each() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	_events.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch(deprecated_flag: Variant = null) -> void:
	if deprecated_flag != null:  # D-038: the deprecated key is ignored either way
		Modifiers.set_source(0, &"test", {&"stealth.ecm_feedback": deprecated_flag})
	var l: Loadout = Loadout.new()
	l.deployable = &"deployable.ecm"
	_rt = await HeistLauncher.launch(&"unit_map", 86, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(2, 0), "ai_teammates": 0, "skip_casing": true, "loadouts": {0: l}})
	_listen(EventBus.ecm_feedback_triggered, &"feedback")
	_listen(EventBus.alarm_raised, &"alarm_raised")


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null) -> void:
		_events.append([tag, a, b])
	sig.connect(cb)
	_conns.append([sig, cb])


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


## Crew at the origin facing -Z (away from the guards' line of sight), ECM placed in front.
func _place_ecm() -> DeployablePrefab:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(3)
	var sys: DeployableSystem = _rt.service(DeployableSystem.SERVICE) as DeployableSystem
	var p: DeployablePrefab = sys.place(c) as DeployablePrefab
	await wait_physics_frames(2)
	return p


## Guards: the near one 6 m from the ECM behind a wall (no LOS to the crew), the far one 30 m away.
func _guards() -> Array[NpcBase]:
	var gs: Array[NpcBase] = []
	for n: Node in _rt.npcs(&"guard"):
		gs.append(n as NpcBase)
	ATestMaps.add_wall(_rt.map, Vector3(0, 1.5, -3.5), Vector3(8, 3, 0.4))
	gs[0].global_transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3(0, 0.05, -6))
	gs[1].global_position = Vector3(25, 0.05, -20)
	return gs


func _trigger(p: DeployablePrefab) -> void:
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(DeployableTweak.data().use_time_s[&"ecm"] + 0.3)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)


func test_s8_6_feedback_built_into_every_ecm() -> void:
	await _launch()
	var p: DeployablePrefab = await _place_ecm()
	assert_eq(p.interactable.kind, &"ecm_feedback")
	assert_eq(p.interactable.availability(_rt.crew_controller(0)), InteractableComponent.BLOCK_NONE,
		"feedback available without any skill (D-038 QA-16)")
	await _trigger(p)
	assert_eq(_of(&"feedback").size(), 1, "triggered without stealth.ecm_feedback")


func test_s8_6_deprecated_flag_false_is_ignored() -> void:
	await _launch(false)
	var p: DeployablePrefab = await _place_ecm()
	assert_eq(p.interactable.availability(_rt.crew_controller(0)), InteractableComponent.BLOCK_NONE,
		"stealth.ecm_feedback = false does not disable it")


func test_s8_6_feedback_stuns_in_radius_and_alerts_in_stealth() -> void:
	await _launch()
	var gs: Array[NpcBase] = _guards()
	var p: DeployablePrefab = await _place_ecm()
	var phantom: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(3, 0.05, -6), Vector3(0, 0, -1))
	var def: EnemyDef = EnemyDef.new()
	def.id = &"enemy.phantom"
	phantom.enemy_def = def
	await wait_physics_frames(2)
	await _trigger(p)
	assert_eq(_of(&"feedback").size(), 1, "ecm_feedback_triggered [R]")
	assert_eq(int(_of(&"feedback")[0][1]), p.net_id)
	assert_true(gs[0].is_stunned(), "near guard stunned")
	assert_false(gs[0].can_observe(), "stunned guards are blind")
	assert_false(gs[1].is_stunned(), "guard outside 15 m not stunned")
	assert_false(phantom.is_stunned(), "Phantom (Cloaker) immune")
	var brain: GuardBrain = gs[0].get_node(^"Brain") as GuardBrain
	assert_eq(gs[0].alert_state, Enums.AlertState.ALARMED, "the stun is an ALARM stimulus in stealth")
	var radio: float = brain.radio_time_left
	await wait_seconds(2.0)
	assert_near(brain.radio_time_left, radio, 0.001, "no radio progress while stunned")
	assert_true(_of(&"alarm_raised").is_empty(), "no alarm during the stun")
	gs[0].stun_left = 0.05
	var ok: bool = await wait_until(func() -> bool: return not _of(&"alarm_raised").is_empty(),
		Tweak.stealth().guard_radio_call_s + 1.5)
	assert_true(ok, "guard radios once recovered")
	if ok:
		assert_eq(_of(&"alarm_raised")[0][1], &"guard_radio")


func test_s8_6_stun_duration_and_recharge() -> void:
	await _launch()
	var gs: Array[NpcBase] = _guards()
	var p: DeployablePrefab = await _place_ecm()
	var ecm: EcmSystem = HeistRuntime.get_service(&"ecm") as EcmSystem
	var n: int = ecm.trigger_feedback(p, 0)
	assert_eq(n, 1, "one enemy stunned")
	assert_near(gs[0].stun_left, DeployableTweak.data().ecm_feedback_stun_s, 0.05, "6 s stun")
	assert_true(p.feedback_used, "used")
	assert_near(p.feedback_recharge_left, DeployableTweak.data().ecm_feedback_recharge_s, 0.05, "4 min recharge")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_ne(ecm.feedback_block(p, c), InteractableComponent.BLOCK_NONE, "no retrigger without the skill")
	Modifiers.set_source(0, &"test2", {&"stealth.ecm_feedback_retrigger": true})
	assert_ne(ecm.feedback_block(p, c), InteractableComponent.BLOCK_NONE, "retrigger waits for the recharge")
	p.feedback_recharge_left = 0.01
	await wait_physics_frames(2)
	assert_eq(ecm.feedback_block(p, c), InteractableComponent.BLOCK_NONE, "retrigger after the recharge")
	await wait_seconds(0.5)
	assert_true(gs[0].stun_left < DeployableTweak.data().ecm_feedback_stun_s - 0.3, "stun ticks down")
