## RT-A6 stage 1 (D-151): rolling_thunder_mission on C's G1 map. Objectives and the setup clock; signals rigged ->
## clean stop (layout in, convoy units beside the G1 bodies, the 8 s window raises the ambush alarm, units awake);
## an early alarm -> police at once, crash stop, trucks locked down; a truck opening spawns its cargo; four bags
## secured call the ride after escape_eta_s. The stop is called directly (no 150-210 s wait).
extends TestCase

const HEIST: StringName = &"rolling_thunder"
const VARIANTS: String = "res://world/heists/rolling_thunder/rolling_thunder_variants.tres"
const TRUCK: PackedScene = preload("res://systems/prefabs/armored_truck/armored_truck.tscn")

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
	await wait_physics_frames(2)
	assert_true(m.clean_stop, "rigged signals: clean stop")
	assert_true(m.layout_id.ends_with("_clean"), "clean layout %s" % m.layout_id)
	assert_eq(_rt.convoy_layout, m.layout_id, "the layout swapped in")
	assert_false(_rt.went_loud, "the window is still quiet")
	assert_true(m._units.size() >= 6, "convoy units at the stop (%d)" % m._units.size())
	for u: NpcBase in m._units:
		assert_eq(StringName(u.get_meta(StealthDirector.META_ALARM_REASON, &"")), &"ambush", "their alarm is the ambush")
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
	var truck: ArmoredTruck = TRUCK.instantiate() as ArmoredTruck
	ConvoyLayouts.find(_rt.map, layout_id).add_child(truck)  # G1 has no prefab trucks yet: one in the crash layout
	await wait_physics_frames(1)
	m._convoy_arrives()
	await wait_physics_frames(2)
	assert_false(m.clean_stop, "crash stop")
	assert_eq(m.layout_id, layout_id)
	assert_true(m._trucks.has(truck), "the layout's truck is in play")
	assert_true(truck.locked_down, "locked down: deadbolts thrown")
	await _open_and_secure(m, truck)


func _open_and_secure(m: RollingThunderMission, truck: ArmoredTruck) -> void:
	truck.open_by_device()
	await wait_seconds(RollingThunderMission.POLL_S + 0.3)
	var bags: Array[Node] = _rt.dynamic_root.find_children("*", "LootBag", true, false)
	assert_true(bags.size() >= 4, "cargo spawned at the opened truck (%d bags)" % bags.size())
	assert_eq(m.objective_state(&"trucks"), Enums.ObjectiveState.COMPLETED, "every truck opened")
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
