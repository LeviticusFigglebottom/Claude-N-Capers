## A3-04 / L2.10 hostage trade (+ S7.3 trade delay, L1.6 no negotiation during an assault, L2.9 solo
## auto-trade, L6.3 AI teammates traded like players).
extends TestCase

var _rt: HeistRuntime = null
var _traded: Array[Array] = []


func before_each() -> void:
	_traded.clear()
	EventBus.crew_traded.connect(_on_traded)
	_rt = await HeistLauncher.launch(&"unit_map", 1010, Enums.Difficulty.HAZARDOUS, self,
		{"map_packed": ATestMaps.basic(0, 2), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})


func after_each() -> void:
	if EventBus.crew_traded.is_connected(_on_traded):
		EventBus.crew_traded.disconnect(_on_traded)
	if _rt != null and is_instance_valid(_rt):
		_rt.clear_bot_intent(0)
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_traded(slot: int, hostage_id: int) -> void:
	_traded.append([slot, hostage_id])


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _custody() -> CustodySystem:
	return CustodySystem.of(_rt)


func _director() -> AssaultDirector:
	return _rt.service(G.SVC_DIRECTOR) as AssaultDirector


## Tie civilian `index` (intimidate + cable tie by slot 0). Returns it.
func _tie_civilian(index: int) -> NpcBase:
	var civ: NpcBase = _rt.npcs(&"civilian")[index] as NpcBase
	var brain: CivilianBrain = civ.get_node("Brain") as CivilianBrain
	brain.on_shouted(_crew(0))
	brain._on_tie_completed(_crew(0))
	return civ


func test_l2_10_negotiation_time_and_civilian_kills() -> void:
	var cs: CustodySystem = _custody()
	assert_near(cs.trade_time_for(1), 5.0, 0.001, "5 s base")
	EventBus.civilian_killed.emit(9001, 1)
	EventBus.civilian_killed.emit(9002, 1)
	EventBus.civilian_killed.emit(9003, 0)
	assert_eq(cs.civilians_killed(1), 2, "kills counted per slot")
	assert_near(cs.trade_time_for(1), 65.0, 0.001, "+30 s per civilian killed (S7.3)")
	_crew(1).health.go_to_custody()
	assert_near(cs.negotiation_left(1), 65.0, 0.001, "negotiation starts at 65 s")
	cs.tick(60.0)
	assert_false(cs.is_trade_ready(1), "not ready at 60 s")
	cs.tick(5.5)
	assert_true(cs.is_trade_ready(1), "ready after 65 s")


func test_l2_10_no_negotiation_during_assault() -> void:
	var cs: CustodySystem = _custody()
	_crew(1).health.go_to_custody()
	var dir: AssaultDirector = _director()
	for p: int in [Enums.AssaultPhase.ANTICIPATION, Enums.AssaultPhase.BUILD, Enums.AssaultPhase.SUSTAIN]:
		dir.assault_phase = p as Enums.AssaultPhase
		assert_true(cs.is_negotiation_locked(), "locked in phase %d" % p)
		cs.tick(20.0)
		assert_near(cs.negotiation_left(1), 5.0, 0.001, "no progress in phase %d" % p)
	dir.assault_phase = Enums.AssaultPhase.FADE
	cs.tick(5.5)
	assert_true(cs.is_trade_ready(1), "negotiates outside the assault")
	dir.assault_phase = Enums.AssaultPhase.NONE


func test_l2_10_human_trades_ai_teammate_by_interaction() -> void:
	var cs: CustodySystem = _custody()
	var civ: NpcBase = _tie_civilian(0)
	var hid: int = civ.net_id
	var ai: CrewController = _crew(1)
	ai.health.go_to_custody()
	cs.tick(1.0)
	assert_eq(cs.highlighted_hostage(), null, "no highlight while negotiating")
	cs.tick(4.5)
	assert_true(cs.is_trade_ready(1), "negotiation over")
	assert_eq(cs.highlighted_hostage(), civ, "tied civilian highlighted")
	assert_eq(ai.crew_state, Enums.CrewState.CUSTODY, "a human is free: no automatic trade")
	var comp: InteractableComponent = civ.get_node_or_null(CustodySystem.TRADE_NAME) as InteractableComponent
	assert_true(comp != null and comp.enabled, "trade interactable enabled")
	assert_eq(comp.kind, &"trade_hostage")
	var human: CrewController = _crew(0)
	human.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, civ.global_position + Vector3(0.8, 0, 0)))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, hid)
	var ok: bool = await wait_until(func() -> bool: return not _traded.is_empty(),
		CustodyTweak.data().trade_interaction_s + 2.0)
	_rt.clear_bot_intent(0)
	assert_true(ok, "trade completed")
	assert_eq(_traded, [[1, hid]] as Array[Array], "crew_traded(1, hostage)")
	assert_eq(ai.crew_state, Enums.CrewState.NORMAL, "AI teammate back (L6.3)")
	assert_near(ai.health.health, ai.health.max_health, 0.001, "full health")
	await wait_frames(1)
	assert_false(is_instance_valid(civ) and civ.is_inside_tree(), "hostage released (removed)")
	var targets: CivilianTargets = _rt.service(CivilianTargets.SERVICE) as CivilianTargets
	assert_eq(targets.hostage_count, 0, "hostage count updated")


func test_l2_10_solo_auto_trade_when_human_in_custody() -> void:
	var cs: CustodySystem = _custody()
	var civ: NpcBase = _tie_civilian(1)
	var hid: int = civ.net_id
	var human: CrewController = _crew(0)
	human.health.go_to_custody()
	cs.tick(4.0)
	assert_eq(human.crew_state, Enums.CrewState.CUSTODY, "negotiating")
	cs.tick(1.5)
	assert_eq(_traded, [[0, hid]] as Array[Array], "AI trades automatically (solo with AI)")
	assert_eq(human.crew_state, Enums.CrewState.NORMAL, "human back")


func test_l2_10_highlight_waits_for_hostage() -> void:
	var cs: CustodySystem = _custody()
	_crew(1).health.go_to_custody()
	cs.tick(6.0)
	assert_true(cs.is_trade_ready(1), "ready")
	assert_eq(cs.highlighted_hostage(), null, "no hostage to highlight")
	var civ: NpcBase = _tie_civilian(0)
	cs.tick(0.1)
	assert_eq(cs.highlighted_hostage(), civ, "first hostage taken is highlighted")
	assert_false(cs.trade(0, civ), "slot 0 is not in custody")
	assert_true(cs.trade(1, civ), "direct trade API")
	assert_eq(_crew(1).crew_state, Enums.CrewState.NORMAL)
