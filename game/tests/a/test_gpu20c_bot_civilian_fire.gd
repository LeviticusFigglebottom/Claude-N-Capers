## GPU-20c (OF loud Cataclysm 1037: the AI crew killed 6 civilians): like PD2 bots, an AI teammate never fires
## through a civilian. With a civilian kept on its line of fire to a cop it holds fire (no round spent); once the
## civilian steps aside it kills the cop.
extends TestCase

const TIME_SCALE: float = 3.0
const COP_POS: Vector3 = Vector3(-8.5, 0.05, -2.0)

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1})
	await wait_physics_frames(2)


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _bot() -> CrewController:
	for c: CrewController in _rt.crew_members():
		if c.is_ai:
			return c
	return null


func _rounds(c: CrewController) -> int:
	var w: CrewWeapons = c.weapons
	var n: int = 0
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if w.has_weapon(ws):
			n += w.mag(ws) + w.reserve(ws)
	return n


func test_bot_holds_fire_with_a_civilian_in_the_line_then_shoots() -> void:
	Engine.time_scale = TIME_SCALE
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	var bot: CrewController = _bot()
	assert_true(bot != null, "one AI teammate")
	var civ: NpcBase = ATestMaps.add_npc_observer(_rt, &"civilian", COP_POS, Vector3.FORWARD)
	var shield: Callable = func() -> void:  # keep the civilian 1.2 m in front of the cop, on the bot's line
		var to_bot: Vector3 = bot.global_position - COP_POS
		to_bot.y = 0.0
		civ.global_position = COP_POS + to_bot.normalized() * 1.2
	shield.call()
	get_tree().physics_frame.connect(shield)
	var cop: NpcBase = _rt.spawn_npc(&"police", Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), COP_POS))
	var rounds: int = _rounds(bot)
	await wait_seconds(4.0)
	get_tree().physics_frame.disconnect(shield)
	assert_eq(_rounds(bot), rounds, "no round fired through the civilian")
	assert_true(civ.alive and is_equal_approx(civ.health, civ.max_health), "the civilian is unharmed")
	civ.global_position = COP_POS + Vector3(6.0, 0.0, -6.0)  # steps aside
	var ok: bool = await wait_until(func() -> bool: return not cop.alive, 8.0)
	assert_true(ok, "with the line clear the bot kills the cop")
	assert_true(civ.alive, "the civilian off the line survives")
