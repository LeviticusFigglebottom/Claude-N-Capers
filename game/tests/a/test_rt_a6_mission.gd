## RT-A6 stage 1 (D-151): rolling_thunder_mission on C's G1 map. Objectives and the setup clock; signals rigged ->
## clean stop (layout in, convoy units beside the G1 bodies, the 8 s window raises the ambush alarm, units awake);
## an early alarm -> police at once, crash stop, C's 2-3 real trucks locked down; a truck opening spawns its cargo; four bags
## secured call the ride after escape_eta_s. The stop is called directly (no 150-210 s wait).
extends TestCase

const HEIST: StringName = &"rolling_thunder"
const VARIANTS: String = "res://world/heists/rolling_thunder/rolling_thunder_variants.tres"

var _rt: HeistRuntime = null


func _available() -> bool:
	var path: String = HeistLauncher.map_path(HEIST, {})
	return path != "" and ResourceLoader.exists(path)


func _launch(seed_value: int = 4101, rares: Array = [], difficulty: int = Enums.Difficulty.ROUTINE) -> RollingThunderMission:
	var o: Dictionary = {"crew_ai": false, "ai_teammates": 0, "skip_casing": true}
	if not rares.is_empty():  # exactly these rare events roll (every other at 0)
		var vt: HeistVariantTable = (load(VARIANTS) as HeistVariantTable).duplicate(true) as HeistVariantTable
		var rows: Array[Dictionary] = []
		for ev: Dictionary in vt.rare_events:
			var e: Dictionary = ev.duplicate(true)
			e["chance"] = 1.0 if rares.has(StringName(e.get("id", &""))) else 0.0
			rows.append(e)
		vt.rare_events = rows
		o["variant_table"] = vt
	_rt = await HeistLauncher.launch(HEIST, seed_value, difficulty, self, o)
	await wait_physics_frames(3)
	return _rt.mission as RollingThunderMission


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_objectives_and_setup_clock() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch()
	assert_true(m != null, "the RT mission runs")
	for id: StringName in [&"signals", &"convoy"]:
		assert_eq(m.objective_state(id), Enums.ObjectiveState.ACTIVE, "%s active at the start" % id)
	for id: StringName in [&"ambush", &"trucks", &"secure", &"escape"]:
		assert_eq(m.objective_state(id), Enums.ObjectiveState.HIDDEN, "%s hidden until the stop" % id)
	assert_eq(m.convoy_state, &"en_route")
	assert_true(m.timer_left(&"convoy") > 100.0, "the convoy is minutes out (%.0f s)" % m.timer_left(&"convoy"))


func test_clean_stop_window_then_ambush() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch()
	m.signals_rigged = true
	m._convoy_arrives()
	await _stopped(m)
	assert_true(m.clean_stop, "rigged signals: clean stop")
	assert_true(m.layout_id.ends_with("_clean"), "clean layout %s" % m.layout_id)
	assert_eq(_rt.convoy_layout, m.layout_id, "the layout swapped in")
	assert_false(_rt.went_loud, "the window is still quiet")
	assert_true(m._units.size() >= 6, "convoy units at the stop (%d)" % m._units.size())
	var tags: Dictionary = {}
	for u: NpcBase in m._units:
		assert_eq(StringName(u.get_meta(StealthDirector.META_ALARM_REASON, &"")), &"ambush", "their alarm is the ambush")
		for t: Variant in u.spawn_info.get("tags", []) as Array:
			tags[StringName(t)] = true
	for t: StringName in [&"convoy_lead", &"convoy_t1", &"convoy_t2", &"convoy_rear"]:
		assert_true(tags.has(t), "a unit carries the look tag %s (D's npc_visual_tweak RT rows)" % t)
	var defs: Dictionary = {}
	for u: NpcBase in m._units:
		defs[u.enemy_def.id if u.enemy_def != null else &""] = true
	for d: StringName in [&"enemy.convoy_lead", &"enemy.convoy_rear", &"enemy.security_officer"]:
		assert_true(defs.has(d), "an escort / crew unit is %s (D-149.12; has %s)" % [d, defs.keys()])
	assert_false(defs.has(&"enemy.patrol_officer"), "the escort officers wear the convoy defs, not patrol_officer")
	Engine.time_scale = 4.0
	var loud: bool = await wait_until(func() -> bool: return _rt.went_loud, RollingThunderMission.WINDOW_S + 2.0)
	assert_true(loud, "the window ended in the alarm")
	assert_eq(_rt.stealth.alarm_reason, &"ambush")
	assert_eq(m.objective_state(&"ambush"), Enums.ObjectiveState.COMPLETED)
	assert_eq(m.objective_state(&"trucks"), Enums.ObjectiveState.ACTIVE)


func test_early_alarm_crash_stop_and_lockdown() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch()
	m.signals_rigged = true  # rigged, but blown before the convoy came
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	assert_true(m.alerted, "an alarm before the convoy alerts it")
	assert_near(m.police_delay_s, 0.0, 0.001, "police at once")
	var layout_id: String = "%s_crash" % m._route()
	m._convoy_arrives()
	await _stopped(m)
	assert_false(m.clean_stop, "crash stop")
	assert_eq(m.objective_state(&"signals"), Enums.ObjectiveState.COMPLETED, "unrigged [signals] closed at the stop")
	assert_true(bool(m.objectives().filter(func(o: Dictionary) -> bool: return o["id"] == &"signals")[0]["data"].get(
		"skipped", false)), "as skipped, not done")
	assert_eq(m.layout_id, layout_id)
	assert_true(m._trucks.size() >= 2 and m._trucks.size() <= 3, "C's 2-3 real trucks in play (%d)" % m._trucks.size())
	for t: ArmoredTruck in m._trucks:
		assert_true(t.locked_down, "%s locked down: deadbolts thrown" % t.name)
		assert_has(m.find_tagged(RollingThunderMission.TAG_TRUCK_IN_PLAY), t, "[trucks] marks %s" % t.name)
	assert_eq(m.objective_state(&"ambush"), Enums.ObjectiveState.COMPLETED, "an early alarm: the crash is the ambush")
	await _open_and_secure(m)


## The stop is done: the layout swapped in (pop-in at once; with C's movers after the drive-in).
func _stopped(m: RollingThunderMission) -> void:
	Engine.time_scale = 4.0
	var ok: bool = await wait_until(func() -> bool: return _rt.convoy_layout == m.layout_id and m.layout_id != "", 30.0)
	Engine.time_scale = 1.0
	assert_true(ok, "the convoy stopped in %s" % m.layout_id)


func _open_and_secure(m: RollingThunderMission) -> void:
	for t: ArmoredTruck in m._trucks:
		t.open_by_device()
	await wait_seconds(RollingThunderMission.POLL_S + 0.3)
	var bags: Array[Node] = _rt.dynamic_root.find_children("*", "LootBag", true, false)
	assert_true(bags.size() >= 4, "cargo at the opened trucks (%d bags)" % bags.size())
	assert_eq(m.objective_state(&"trucks"), Enums.ObjectiveState.COMPLETED, "every truck opened")
	for t: ArmoredTruck in m._trucks:
		assert_eq(t.objective_tag, RollingThunderMission.TAG_TRUCK_OPEN, "an opened %s is a [cargo] mark" % t.name)
	for i: int in RollingThunderMission.REQUIRED_BAGS:
		EventBus.loot_secured.emit(0, RollingThunderMission.LOOT_CASH, 1000)
	await wait_physics_frames(1)
	assert_eq(m.objective_state(&"secure"), Enums.ObjectiveState.COMPLETED, "four bags")
	assert_eq(m.objective_state(&"escape_wait"), Enums.ObjectiveState.ACTIVE, "the ride is called")
	assert_true(m.timer_left(&"escape_eta") > 60.0, "after escape_eta_s")


func test_rare_events_at_the_setup() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch(4101, [&"convoy_early", &"marshal_early", &"rush_hour", &"informant_tip"])
	var eta: float = float(m.variant(&"convoy_eta_s")) - RollingThunderMission.CONVOY_EARLY_S
	assert_near(m.timer_left(&"convoy") + m.elapsed_s, eta, 1.0, "convoy_early: 45 s sooner")
	assert_near(m.timer_left(&"marshal") + m.elapsed_s, eta - RollingThunderMission.MARSHAL_EARLY_LEAD_S, 1.0,
		"marshal_early: ETA - 90")
	assert_true(m.is_variant_revealed(&"convoy_route") and m.is_variant_revealed(&"marshal_walk"), "informant_tip")
	var street: int = 0
	for n: Node in _rt.npcs(&"civilian"):
		if ((n as NpcBase).spawn_info.get("tags", []) as Array).has(&"civ_street"):
			street += 1
	assert_eq(street, 12, "rush_hour: 12 pedestrians on the street")
	var crane_open: bool = SpecialSpawner.open_perches(_rt).any(func(tp: TacticalPoint) -> bool:
		return tp.tags.has(RollingThunderMission.PERCH_CRANE))
	assert_false(crane_open, "no crane_sniper: S3 closed")
	var ashby_open: bool = SpecialSpawner.open_perches(_rt).any(func(tp: TacticalPoint) -> bool:
		return tp.tags.has(RollingThunderMission.PERCH_ASHBY))
	assert_false(ashby_open, "Routine: S4 closed")
	var diner: int = 0
	for n: Node in _rt.npcs(&"civilian"):
		if ((n as NpcBase).spawn_info.get("tags", []) as Array).has(RollingThunderMission.TAG_CIV_DINER):
			diner += 1
	assert_eq(diner, RollingThunderMission.DINER_CUSTOMERS + 2, "rush_hour: +2 diner customers")
	# marshal_early: he walks his own check, then a second one
	m._spawn_marshal()
	await wait_physics_frames(2)
	var marshal: NpcBase = null
	for n: Node in _rt.npcs(&"guard"):
		if ((n as NpcBase).spawn_info.get("tags", []) as Array).has(RollingThunderMission.TAG_MARSHAL_SPAWN):
			marshal = n as NpcBase
	assert_true(marshal != null, "the marshal is out")
	if marshal == null:
		return
	var graphs: Dictionary = {}
	for p: PatrolPoint in (marshal.get_node(^"Brain") as GuardBrain).route_points:
		graphs[(p.get_parent() as PatrolGraph).graph_id] = true
	assert_eq(graphs.size(), 2, "marshal_early: two checks (%s)" % [graphs.keys()])


func test_no_rare_marshal_walks_one_check_and_diner_has_three() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch(4101, [&"informant_tip"])
	var diner: int = 0
	for n: Node in _rt.npcs(&"civilian"):
		if ((n as NpcBase).spawn_info.get("tags", []) as Array).has(RollingThunderMission.TAG_CIV_DINER):
			diner += 1
	assert_eq(diner, RollingThunderMission.DINER_CUSTOMERS, "diner customers without rush_hour")
	m._spawn_marshal()
	await wait_physics_frames(2)
	for n: Node in _rt.npcs(&"guard"):
		if ((n as NpcBase).spawn_info.get("tags", []) as Array).has(RollingThunderMission.TAG_MARSHAL_SPAWN):
			var graphs: Dictionary = {}
			for p: PatrolPoint in (n.get_node(^"Brain") as GuardBrain).route_points:
				graphs[(p.get_parent() as PatrolGraph).graph_id] = true
			assert_eq(graphs.size(), 1, "one check (%s)" % [graphs.keys()])


## doc Variants goods_lift: lift_dead = an unpowered lift from the start; the plant-room breaker's hack restores it.
func test_lift_dead_and_the_breaker() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch()
	var lifts: Array[Node] = _rt.get_tree().get_nodes_in_group(&"goods_lift")
	assert_false(lifts.is_empty(), "the goods lift")
	var lift: BagLift = lifts[0] as BagLift
	var dead: bool = m._slot_active(&"goods_lift", &"lift_dead")
	assert_eq(lift.powered, not dead, "powered unless lift_dead (dead=%s)" % dead)
	m._power_lift(false)
	assert_eq(lift._availability(null, 0), InteractableComponent.BLOCK_DISABLED, "a dead lift's panels are blocked")
	var breaker: Node = null
	for n: Node in m.find_tagged(RollingThunderMission.TAG_LIFT_BREAKER):
		if n is HackTerminal:
			breaker = n
	assert_true(breaker != null, "the plant-room breaker")
	if breaker == null:
		return
	EventBus.device_finished.emit((breaker as GameplayPrefab).net_id)
	await wait_physics_frames(1)
	assert_true(lift.powered, "the breaker restores the lift")
