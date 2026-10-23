## L6.2 (PD2 Crew Management, LEAD r285): each AI teammate's ability (a grant on its slot; Inspire revives from range)
## and boost (crew-wide while the bot is in play). Values from BotCrew.def_for (B's defs, else the PD2-shaped defaults).
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(picks: Dictionary) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1262, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 2, "crew_ai": false, "bot_crew": picks})
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _grant(id: StringName) -> Dictionary:
	return BotCrew.def_for(id).get("grants", {})


## Abilities apply to the bot only; boosts to the whole crew while the bot is in play.
func test_ability_on_the_bot_boost_on_the_crew() -> void:
	await _launch({1: {"ability": &"bot_ability.quick", "boost": &"bot_boost.health"},
		2: {"ability": &"bot_ability.pied_piper", "boost": &"bot_boost.stamina"}})
	var quick: float = float(_grant(&"bot_ability.quick")[&"interaction.speed_mult"])
	assert_near(Modifiers.mult(1, &"interaction.speed_mult"), quick, 0.0001, "Quick: the bot interacts faster")
	assert_eq(Modifiers.mult(0, &"interaction.speed_mult"), 1.0, "not the player")
	assert_near(Modifiers.mult(2, &"ability.shout_range_mult"), float(_grant(&"bot_ability.pied_piper")[&"ability.shout_range_mult"]),
		0.0001, "Pied Piper: the other bot's reach")
	var hp: float = float(_grant(&"bot_boost.health")[&"defense.health_mult"])
	var st: float = float(_grant(&"bot_boost.stamina")[&"movement.stamina_mult"])
	for slot: int in 3:
		assert_near(Modifiers.mult(slot, &"defense.health_mult"), hp, 0.0001, "health boost on slot %d" % slot)
		assert_near(Modifiers.mult(slot, &"movement.stamina_mult"), st, 0.0001, "stamina boost on slot %d" % slot)
	_crew(1).health.go_to_custody()
	await wait_physics_frames(2)
	assert_eq(Modifiers.mult(0, &"defense.health_mult"), 1.0, "the bot in custody: its boost is gone")
	assert_near(Modifiers.mult(0, &"movement.stamina_mult"), st, 0.0001, "the other bot's stays")


## bot_ability.inspire: the bot revives a downed teammate in range and in sight, then waits out the cooldown.
func test_inspire_revives_from_range() -> void:
	await _launch({1: {"ability": BotCrew.INSPIRE, "boost": &""}})
	var p: Dictionary = BotCrew.def_for(BotCrew.INSPIRE)["params"]
	var bot: CrewController = _crew(1)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, bot.global_position + Vector3(float(p["range"]) + 4.0, 0, 0)))
	await wait_physics_frames(2)
	_crew(0).health.go_down()
	await wait_physics_frames(3)
	assert_eq(_crew(0).crew_state, Enums.CrewState.DOWNED, "out of range: still down")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, bot.global_position + Vector3(float(p["range"]) * 0.6, 0, 0)))
	var up: bool = await wait_until(func() -> bool: return _crew(0).crew_state == Enums.CrewState.NORMAL, 1.0)
	assert_true(up, "in range: the bot inspires the player up")
	assert_near(BotCrew.of(_rt).inspire_cd[1], float(p["cooldown"]), 0.2, "then a cooldown")
	_crew(0).health.go_down()
	await wait_physics_frames(3)
	assert_eq(_crew(0).crew_state, Enums.CrewState.DOWNED, "not again inside the cooldown")
