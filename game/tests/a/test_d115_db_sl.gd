## D-115 mission audit (docs/status/env_a.md 2026-10-15): the ENV A items on Dockside Burn (DB-) and Shadow Ledger
## (SL-), one test per item.
extends TestCase

var _rt: HeistRuntime = null
var _lines: Array[Array] = []
var _cb: Callable


func before_each() -> void:
	_lines.clear()
	_cb = func(speaker: StringName, line_id: StringName, ctx: Dictionary) -> void:
		_lines.append([speaker, line_id, ctx])
	EventBus.voice_line_requested.connect(_cb)


func after_each() -> void:
	if EventBus.voice_line_requested.is_connected(_cb):
		EventBus.voice_line_requested.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _launch(heist: StringName, run_seed: int, extra: Dictionary = {}) -> void:
	var opts: Dictionary = {"crew_ai": false, "ai_teammates": 0}
	opts.merge(extra, true)
	_rt = await HeistLauncher.launch(heist, run_seed, Enums.Difficulty.ROUTINE, self, opts)
	await wait_physics_frames(3)


func _count(line_id: StringName) -> int:
	return _lines.filter(func(l: Array) -> bool: return l[1] == line_id).size()


func _obj(oid: StringName) -> Dictionary:
	for o: Dictionary in _rt.mission.objectives():
		if StringName(o["id"]) == oid:
			return o
	return {}


# --- DB-3: cartel reinforcements are cartel gunmen, awake ------------------------------------------------

func test_db3_spawn_guards_cartel_tag_spawns_awake_cartel() -> void:
	await _launch(&"dockside_burn", 9001)
	assert_true(_rt != null and _rt.mission != null, "launched")
	var before: int = _rt.npcs(CartelBrain.ROLE).size()
	var spawned: Array[Node] = _rt.mission.spawn_guards(2, &"cartel_reinf")
	assert_eq(spawned.size(), 2, "two reinforcements")
	for n: Node in spawned:
		var npc: NpcBase = n as NpcBase
		assert_eq(npc.role, CartelBrain.ROLE, "a cartel gunman, not a guard")
		assert_true(npc.enemy_def != null and npc.enemy_def.resource_path == CartelBrain.ENEMY_DEF, "cartel EnemyDef")
		assert_true(npc.get_node_or_null(^"Brain") is CartelBrain, "CartelBrain")
		assert_eq(npc.alert_state, Enums.AlertState.COMBAT, "arrives awake")
	assert_eq(_rt.npcs(CartelBrain.ROLE).size(), before + 2, "counted with the cartel")
	await wait_physics_frames(3)
	for n: Node in spawned:
		assert_eq((n as NpcBase).alert_state, Enums.AlertState.COMBAT, "still awake after the brain started")


# --- DB-2: only cash bricks and weapon crates count toward the 4 ---------------------------------------

func test_db2_contraband_pays_but_does_not_count() -> void:
	await _launch(&"dockside_burn", 9001)
	var m: HeistMission = _rt.mission
	for i: int in range(3):
		EventBus.loot_secured.emit(9000 + i, &"loot.contraband", 1400)
	assert_eq(int((_obj(&"secure")["data"] as Dictionary)["count"]), 0, "product does not count")
	assert_eq(m.objective_state(&"secure"), Enums.ObjectiveState.ACTIVE, "secure still open")
	assert_eq(m.bags_secured, 3, "but the bags are secured (they pay)")
	EventBus.loot_secured.emit(9100, &"loot.cash_bricks", 1000)
	EventBus.loot_secured.emit(9101, &"loot.weapon_crate", 1000)
	EventBus.loot_secured.emit(9102, &"loot.cash_bricks", 1000)
	assert_eq(int((_obj(&"secure")["data"] as Dictionary)["count"]), 3, "HUD count: required bags only")
	assert_eq(m.objective_state(&"secure"), Enums.ObjectiveState.ACTIVE, "3 of 4")
	assert_eq(_count(&"vo.mercer.dockside_burn_required_secured"), 0)
	EventBus.loot_secured.emit(9103, &"loot.weapon_crate", 1000)
	assert_eq(m.objective_state(&"secure"), Enums.ObjectiveState.COMPLETED, "the 4th required bag completes it")
	assert_eq(_count(&"vo.mercer.dockside_burn_required_secured"), 1)
	assert_false(bool(m.get(&"_escape_open")), "no escape before the burn")
	m.call(&"_on_burn_done")
	assert_true(bool(m.get(&"_escape_open")), "burn + 4 required bags: the escape is called")
