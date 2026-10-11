## QB-B6-02 / D-071: CrewStats counts shots (one per trigger pull), hits (an enemy NPC struck, once per shot)
## and headshots (HitZone.HEAD on an enemy, once per shot); civilians and misses are shots without hits; melee
## is no shot. LocalHudModel.crew_stats (ui_hud v1.7) and HeistResult crew rows (events v1.1) carry them.
extends TestCase

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch() -> CrewController:
	_rt = await HeistLauncher.launch(&"unit_map", 6201, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 1, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = await ACombatSpecials.place_crew(_rt, 0, Vector3(0, 0.05, 0))
	c.set_masked()
	return c


func _npc(role: StringName, pos: Vector3) -> NpcBase:
	var n: NpcBase = ATestMaps.add_npc_observer(_rt, role, pos, Vector3(0, 0, 1))
	n.max_health = 100000.0
	n.health = 100000.0
	return n


func test_shots_hits_headshots() -> void:
	var c: CrewController = await _launch()
	var g: NpcBase = _npc(&"guard", Vector3(0, 0.05, -6))
	await wait_physics_frames(2)
	var st: CrewStats = _rt.stats
	assert_true(st != null and _rt.service(CrewStats.SERVICE) == st, "CrewStats service")
	await ACombatSpecials.shoot_at(_rt, 0, g.head_position())
	assert_eq(st.value(0, &"shots"), 1, "one trigger pull")
	assert_eq(st.value(0, &"hits"), 1, "an enemy struck")
	assert_eq(st.value(0, &"headshots"), 1, "in the head")
	await wait_seconds(0.3)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(g))
	assert_eq(st.value(0, &"shots"), 2)
	assert_eq(st.value(0, &"hits"), 2, "body hit")
	assert_eq(st.value(0, &"headshots"), 1, "not a headshot")
	await wait_seconds(0.3)
	await ACombatSpecials.shoot_at(_rt, 0, Vector3(6, 3, -6))
	assert_eq(st.value(0, &"shots"), 3, "a miss is still a shot")
	assert_eq(st.value(0, &"hits"), 2, "no hit")
	g.queue_free()
	var civ: NpcBase = _npc(&"civilian", Vector3(0, 0.05, -6))
	await wait_physics_frames(2)
	await wait_seconds(0.3)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(civ))
	assert_eq(st.value(0, &"shots"), 4)
	assert_eq(st.value(0, &"hits"), 2, "a civilian is no enemy hit")
	assert_eq(st.value(1, &"shots"), 0, "the AI teammate has its own row")
	_rt.hud_model.refresh()
	var rows: Array[Dictionary] = _rt.hud_model.crew_stats
	assert_eq(rows.size(), 2, "one row per crew member, local included")
	if rows.size() == 2:
		assert_eq(int(rows[0]["slot"]), 0)
		assert_true(bool(rows[0]["is_local"]) and not bool(rows[0]["is_ai"]), "local human")
		assert_true(bool(rows[1]["is_ai"]), "AI teammate")
		assert_eq(String(rows[0]["name"]), c.display_name)
		for k: String in ["kills", "specials_killed", "civilians_killed", "downs", "shots", "hits", "headshots"]:
			assert_true(rows[0].has(k), "row has %s" % k)
		assert_eq(int(rows[0]["shots"]), 4)
		assert_eq(int(rows[0]["headshots"]), 1)
	var res: Dictionary = _rt.end_heist(true)
	var crow: Dictionary = (res["crew"] as Array)[0]
	assert_eq(String(crow["name"]), c.display_name, "HeistResult v1.1 name")
	assert_eq(int(crow["shots"]), 4)
	assert_eq(int(crow["hits"]), 2)
	assert_eq(int(crow["headshots"]), 1)


func test_kills_and_stats_net_state() -> void:
	var c: CrewController = await _launch()
	var g: NpcBase = _npc(&"guard", Vector3(0, 0.05, -6))
	g.max_health = 1.0
	g.health = 1.0
	await wait_physics_frames(2)
	await ACombatSpecials.shoot_at(_rt, 0, CombatSystem.target_center(g))
	assert_false(g.alive)
	assert_eq(_rt.stats.value(0, &"kills"), 1, "kill counted")
	var snap: Dictionary = _rt.stats.net_state()
	assert_eq(int((snap[0] as Dictionary)[&"kills"]), 1, "net_state carries the rows")
	assert_true(_rt.net_sync.services_state().has(HeistNetSync.SVC_STATS), "replicated with the services state")
	assert_eq(c.slot, 0)
