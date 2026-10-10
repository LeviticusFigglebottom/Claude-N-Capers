## A3-04 / L5.1 shout makes low-tier cops surrender (chance 0.2 + 0.5(1-hp%) + 0.1 per nearby crew ◇,
## specials / top factions immune), then a cable tie makes them a hostage (L5.3: counts for the
## assault delay and trades).
extends TestCase

var _rt: HeistRuntime = null
var _dominated: Array[Array] = []
var _saved: Dictionary = {}


func before_each() -> void:
	_dominated.clear()
	var tw: CustodyTweak = CustodyTweak.data()
	_saved = {"base": tw.surrender_base_chance, "hurt": tw.surrender_hurt_chance,
		"per": tw.surrender_per_crew_chance, "skill": tw.surrender_requires_skill}
	EventBus.guard_dominated.connect(_on_dominated)
	_rt = await HeistLauncher.launch(&"unit_map", 5151, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false})
	await wait_physics_frames(1)


func after_each() -> void:
	var tw: CustodyTweak = CustodyTweak.data()
	tw.surrender_base_chance = _saved["base"]
	tw.surrender_hurt_chance = _saved["hurt"]
	tw.surrender_per_crew_chance = _saved["per"]
	tw.surrender_requires_skill = _saved["skill"]
	if EventBus.guard_dominated.is_connected(_on_dominated):
		EventBus.guard_dominated.disconnect(_on_dominated)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(2)


func _on_dominated(npc_id: int, slot: int) -> void:
	_dominated.append([npc_id, slot])


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


## Crew at (0, 0, 4) looking at -Z; a cop at the origin. `def` overrides the EnemyDef.
func _setup(def: EnemyDef = null, loud: bool = false) -> NpcBase:
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 4)))
	_crew().set_masked()
	var info: Dictionary = {}
	if def != null:
		info["enemy_def"] = def
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), info)
	if loud:
		_rt.stealth.raise_alarm(&"test", 0)
	var i: CrewIntent = CrewIntent.new()
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(3)
	return cop


func _shout() -> void:
	var i: CrewIntent = CrewIntent.new()
	i.shout = true
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)


func _always() -> void:
	CustodyTweak.data().surrender_base_chance = 1.0


func test_l5_1_chance_formula() -> void:
	var cop: NpcBase = await _setup()
	assert_near(PoliceSurrender.chance(cop, _rt), 0.2 + 0.1, 0.001, "full hp, 1 crew nearby")
	cop.health = cop.max_health * 0.5
	assert_near(PoliceSurrender.chance(cop, _rt), 0.2 + 0.25 + 0.1, 0.001, "half hp")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 25)))
	await wait_physics_frames(2)
	assert_near(PoliceSurrender.chance(cop, _rt), 0.2 + 0.25, 0.001, "nobody within 10 m")


func test_l5_1_specials_and_top_factions_immune() -> void:
	var base: EnemyDef = load("res://systems/ai/data/enemies/patrol_officer.tres") as EnemyDef
	var special: EnemyDef = base.duplicate() as EnemyDef
	special.is_special = true
	var top: EnemyDef = base.duplicate() as EnemyDef
	top.params = base.params.duplicate()
	top.params["surrender_immune"] = true
	var cop: NpcBase = await _setup(special)
	assert_true(PoliceSurrender.is_immune(cop), "special immune")
	_always()
	await _shout()
	assert_ne(cop.alert_state, Enums.AlertState.SURRENDERED, "special does not surrender")
	var cop2: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.IDENTITY, Vector3(5, 0.05, 0)), {"enemy_def": top})
	assert_true(PoliceSurrender.is_immune(cop2), "params.surrender_immune")
	assert_false(PoliceSurrender.is_immune(_rt.spawn_npc(&"police", Transform3D.IDENTITY)), "patrol officer can surrender")


func test_l5_1_shout_surrender_then_tie_counts_as_hostage() -> void:
	var cop: NpcBase = await _setup(null, true)
	_always()
	await _shout()
	assert_eq(cop.alert_state, Enums.AlertState.SURRENDERED, "surrendered")
	assert_has(_dominated, [cop.net_id, 0], "guard_dominated(cop, slot)")
	var brain: PoliceBrain = cop.get_node("Brain") as PoliceBrain
	assert_false(brain.wants_to_fire, "surrendered cop holds fire")
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_false(dir.alive_units().has(cop), "not a police unit any more")
	var ties: int = _crew().cable_ties
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 1)))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, cop.net_id)
	var ok: bool = await wait_until(func() -> bool: return cop.alert_state == Enums.AlertState.TIED,
		Tweak.stealth().cable_tie_s + 2.0)
	_rt.set_bot_intent(0, CrewIntent.new())
	assert_true(ok, "tied with a cable tie")
	assert_eq(_crew().cable_ties, ties - 1, "cable tie used")
	assert_true(cop.is_in_group(G.HOSTAGE), "hostage group")
	assert_eq(dir.hostages, 1, "director counts the cop hostage (L5.3)")
	assert_true(CustodySystem.of(_rt).hostage_candidates().has(cop), "tradeable")


func test_l5_1_failed_roll_and_skill_gate() -> void:
	var cop: NpcBase = await _setup(null, true)
	var tw: CustodyTweak = CustodyTweak.data()
	tw.surrender_base_chance = 0.0
	tw.surrender_hurt_chance = 0.0
	tw.surrender_per_crew_chance = 0.0
	await _shout()
	assert_ne(cop.alert_state, Enums.AlertState.SURRENDERED, "zero chance: no surrender")
	_always()
	tw.surrender_requires_skill = true
	await wait_seconds(Tweak.stealth().shout_cooldown_s + 0.1)
	await _shout()
	assert_ne(cop.alert_state, Enums.AlertState.SURRENDERED, "skill required")
	Modifiers.set_source(0, &"test", {&"ability.intimidate_cops": true})
	await wait_seconds(Tweak.stealth().shout_cooldown_s + 0.1)
	await _shout()
	assert_eq(cop.alert_state, Enums.AlertState.SURRENDERED, "with ability.intimidate_cops")


func test_l5_1_untied_cop_gets_back_up() -> void:
	var cop: NpcBase = await _setup(null, true)
	_always()
	await _shout()
	assert_eq(cop.alert_state, Enums.AlertState.SURRENDERED)
	var s: PoliceSurrender = PoliceSurrender.of(cop)
	assert_near(s.surrender_left, CustodyTweak.data().surrender_duration_s, 0.2, "surrender timer")
	assert_true(CustodySystem.of(_rt).hostage_candidates().has(cop), "a surrendered cop can be traded")
	s.surrender_left = 0.02
	await wait_physics_frames(4)
	assert_eq(cop.alert_state, Enums.AlertState.COMBAT, "back in the fight")
