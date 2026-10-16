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


# --- DB-4: the thermite bag of the crew's spawn -----------------------------------------------------------

func _thermite_bag(tag: StringName) -> LootSpawn:
	var ls: LootSpawn = (load("res://systems/prefabs/loot_spawn/loot_spawn.tscn") as PackedScene).instantiate() as LootSpawn
	ls.loot_id = &"loot.thermite"
	ls.objective_tag = tag
	ls.name = "TestThermite_%s" % tag
	_rt.map.add_child(ls)
	return ls


func _usable(n: Node) -> bool:
	var ls: LootSpawn = n as LootSpawn
	return ls.visible and ls.interactable.enabled and ls.remaining > 0


func test_db4_thermite_bag_at_the_spawn() -> void:
	await _launch(&"dockside_burn", 9001)
	var m: HeistMission = _rt.mission
	var gate_today: Array[Node] = m.find_tagged(&"thermite")
	gate_today.append_array(m.find_tagged(&"thermite_gate"))  # after C retags the gate bag
	assert_eq(gate_today.size(), 1, "one gate bag on the map")
	assert_true(_usable(gate_today[0]), "default (gate) spawn: the gate bag is usable")
	# Today's map, lane spawn: no lane bag yet, the gate bag stays.
	_rt.preplan.result["spawn_tag"] = &"preplan_spawn_lane"
	if m.find_tagged(&"thermite_lane").is_empty():
		m.call(&"_apply_thermite")
		assert_true(_usable(gate_today[0]), "no thermite_lane bag: the gate bag is kept")
	# C's per-spawn bags exist: only the lane bag stays.
	var lane: LootSpawn = _thermite_bag(&"thermite_lane")
	var pontoon: LootSpawn = _thermite_bag(&"thermite_pontoon")
	var gate: LootSpawn = _thermite_bag(&"thermite_gate")
	await wait_physics_frames(1)
	m.call(&"_apply_thermite")
	assert_true(_usable(lane), "lane spawn: the lane bag")
	assert_false(_usable(pontoon), "the pontoon bag is hidden and disabled")
	assert_false(_usable(gate), "the gate bag is hidden and disabled")
	assert_false(_usable(gate_today[0]), "the untagged-by-spawn gate bag too")
	assert_false(pontoon.visible or pontoon.interactable.enabled, "hidden, not interactable")


func test_db4_thermite_pontoon_and_gate_spawns() -> void:
	await _launch(&"dockside_burn", 9001)
	var m: HeistMission = _rt.mission
	var lane: LootSpawn = _thermite_bag(&"thermite_lane")
	var pontoon: LootSpawn = _thermite_bag(&"thermite_pontoon")
	var gate: LootSpawn = _thermite_bag(&"thermite_gate")
	await wait_physics_frames(1)
	_rt.preplan.result["spawn_tag"] = &"preplan_spawn_pontoon"
	m.call(&"_apply_thermite")
	assert_true(_usable(pontoon), "pontoon spawn: the pontoon bag")
	assert_false(_usable(lane) or _usable(gate), "the others are off")
	await _teardown_and_launch_gate()


func _teardown_and_launch_gate() -> void:
	_rt.teardown()
	await wait_frames(2)
	await _launch(&"dockside_burn", 9001)
	var lane: LootSpawn = _thermite_bag(&"thermite_lane")
	var gate: LootSpawn = _thermite_bag(&"thermite_gate")
	await wait_physics_frames(1)
	_rt.mission.call(&"_apply_thermite")
	assert_true(_usable(gate), "default spawn: the thermite_gate bag")
	assert_false(_usable(lane), "the lane bag is off")
	for legacy: Node in _rt.mission.find_tagged(&"thermite"):
		assert_false(_usable(legacy), "with a thermite_gate bag the legacy gate bag is off")


# --- DB-13: the Longshot line names the perch ---------------------------------------------------------------

func _perch(tag: StringName) -> TacticalPoint:
	for n: Node in _rt.map.get_slots(G.SNIPER_PERCH):
		var tp: TacticalPoint = n as TacticalPoint
		if tp != null and tp.tags.has(tag):
			return tp
	return null


func test_db13_longshot_line_by_perch() -> void:
	await _launch(&"dockside_burn", 9001)
	var roof: TacticalPoint = _perch(&"s2")
	var crane: TacticalPoint = _perch(&"s1")
	assert_true(roof != null and crane != null, "S1 and S2 perches")
	var def: EnemyDef = SpecialSpawner.enemy_def(&"enemy.longshot")
	# The roof Longshot shows up first: the roof line, not the crane's.
	var a: NpcBase = _rt.spawn_npc(&"special", roof.global_transform, {"enemy_def": def})
	await wait_physics_frames(3)
	assert_eq(_count(&"vo.mercer.dockside_burn_sniper_roof"), 1, "first Longshot on the roof: roof line")
	assert_eq(_count(&"vo.mercer.dockside_burn_sniper_crane"), 0, "not the crane line")
	var b: NpcBase = _rt.spawn_npc(&"special", crane.global_transform, {"enemy_def": def})
	await wait_physics_frames(3)
	assert_eq(_count(&"vo.mercer.dockside_burn_sniper_crane"), 1, "then the crane")
	EventBus.special_spawned.emit(a.net_id, &"longshot")
	EventBus.special_spawned.emit(b.net_id, &"longshot")
	assert_eq(_count(&"vo.mercer.dockside_burn_sniper_roof"), 1, "once per perch")
	assert_eq(_count(&"vo.mercer.dockside_burn_sniper_crane"), 1, "once per perch")


# --- DB-16: [containers] is optional; cash or crates ----------------------------------------------------

func test_db16_containers_optional_cash_alternative() -> void:
	await _launch(&"dockside_burn", 9001)
	var countroom: bool = (_rt.variants.get(&"cash_location", []) as Array).has(&"cash_countroom")
	var cash_id: StringName = &"count_cage" if countroom else &"strongroom"
	var cont: Dictionary = _obj(&"containers")["data"] as Dictionary
	assert_true(bool(cont.get("optional", false)), "[containers] optional")
	assert_eq(StringName(cont.get("alternative", &"")), cash_id, "its alternative is the run's cash objective")
	for oid: StringName in [&"strongroom", &"count_cage"]:
		assert_eq(StringName((_obj(oid)["data"] as Dictionary).get("alternative", &"")), &"containers",
			"%s: cash and/or crates" % oid)
	assert_eq(_rt.mission.objective_state(cash_id), Enums.ObjectiveState.ACTIVE, "the run's cash objective is shown")


# --- DB-17 / QC-36: [cartel] counts cartel kills only; the wake line is the cartel's ---------------------

func test_db17_cartel_thin_out_counts_cartel_kills_only() -> void:
	await _launch(&"dockside_burn", 9001)
	var m: HeistMission = _rt.mission
	var gunmen: Array[Node] = _rt.npcs(CartelBrain.ROLE)
	assert_true(gunmen.size() >= 2, "cartel posts spawned")
	var guard_xf: Transform3D = (gunmen[0] as Node3D).global_transform
	guard_xf.origin += Vector3(1.5, 0.0, 0.0)
	var other: NpcBase = _rt.spawn_npc(&"civilian", guard_xf, {})
	assert_true(other != null, "a civilian")
	other.die({}, 0)
	await wait_physics_frames(1)
	assert_eq(int(m.get(&"_gunmen_down")), 0, "a civilian kill does not thin the cartel")
	(gunmen[0] as NpcBase).die({}, 0)
	await wait_physics_frames(1)
	assert_eq(int(m.get(&"_gunmen_down")), 1, "a cartel kill counts")
	assert_eq(int((_obj(&"cartel")["data"] as Dictionary).get("gunmen_down", -1)), 1, "HUD data follows")
	EventBus.npc_killed.emit(987654, 0, {})
	assert_eq(int(m.get(&"_gunmen_down")), 1, "an unknown net id does not count")


func test_qc36_cartel_awake_line_only_for_cartel() -> void:
	await _launch(&"dockside_burn", 9001)
	var gunmen: Array[Node] = _rt.npcs(CartelBrain.ROLE)
	var xf: Transform3D = (gunmen[0] as Node3D).global_transform
	xf.origin += Vector3(1.5, 0.0, 0.0)
	var civ: NpcBase = _rt.spawn_npc(&"civilian", xf, {})
	EventBus.npc_alert_state_changed.emit(civ.net_id, Enums.AlertState.CALM, Enums.AlertState.COMBAT)
	assert_eq(_count(&"vo.mercer.dockside_burn_cartel_awake"), 0, "not a gunman: no cartel line")
	var g: NpcBase = gunmen[0] as NpcBase
	EventBus.npc_alert_state_changed.emit(g.net_id, Enums.AlertState.CALM, Enums.AlertState.COMBAT)
	EventBus.npc_alert_state_changed.emit(g.net_id, Enums.AlertState.CALM, Enums.AlertState.COMBAT)
	assert_eq(_count(&"vo.mercer.dockside_burn_cartel_awake"), 1, "the first gunman awake: once")


# --- SL-5: [drives] completes at 2 of 3 -------------------------------------------------------------------

func test_sl5_drives_complete_at_two_of_three() -> void:
	await _launch(&"shadow_ledger", 777)
	var m: HeistMission = _rt.mission
	m.call(&"_on_hack_done")
	assert_eq(m.objective_state(&"drives"), Enums.ObjectiveState.ACTIVE, "drives open after the hack")
	var sleds: Array[Node] = m.find_tagged(&"drives")
	assert_eq(sleds.size(), 3, "three drive sleds")
	var take: Callable = func(n: Node) -> void:
		n.set(&"remaining", int(n.get(&"remaining")) - 1)
		EventBus.interaction_completed.emit(int(n.get(&"net_id")), 0, &"bag_loot")
	take.call(sleds[0])
	assert_eq(m.objective_state(&"drives"), Enums.ObjectiveState.ACTIVE, "1 of 2 required")
	take.call(sleds[1])
	assert_eq(m.objective_state(&"drives"), Enums.ObjectiveState.COMPLETED, "2 taken: [drives] done (the 3rd is a bonus)")

