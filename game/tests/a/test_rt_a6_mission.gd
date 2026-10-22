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


## doc Rare events gold_rush: "forces trucks_3 + t3_bullion" (both pins, force_active as an Array).
func test_gold_rush_pins_a_bullion_third_truck() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch(4101, [&"gold_rush"])
	assert_has(m.variant(&"truck_count") as Array, &"trucks_3", "gold_rush: three trucks")
	assert_has(m.variant(&"cargo_t3") as Array, &"t3_bullion", "gold_rush: T3 is bullion")


## B's RT HUD run: an alarm during the drive-in left no ACTIVE objective (ambush done, the stop's not up yet). The
## ambush now springs when the stop is done, with [trucks] / [escort] / [secure] up in the same step.
func test_alarm_during_the_drive_in_keeps_an_objective_up() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch()
	m._convoy_arrives()  # crash stop: the movers drive in
	await wait_physics_frames(2)
	if m._stop_done:
		skip("no drive-in on this map (pop-in)")
		return
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	assert_eq(m.objective_state(&"ambush"), Enums.ObjectiveState.ACTIVE, "[ambush] stays up during the drive-in")
	await _stopped(m)
	await wait_physics_frames(2)
	assert_eq(m.objective_state(&"ambush"), Enums.ObjectiveState.COMPLETED, "sprung at the stop")
	assert_eq(m.objective_state(&"escort"), Enums.ObjectiveState.ACTIVE, "[escort] up with it")
	assert_eq(m.objective_state(&"trucks"), Enums.ObjectiveState.ACTIVE, "[trucks] up with it")


## doc Variants controller: ctrl_locked = the cabinet's padlock gates the signal rig (C's TODO(A) on the padlock).
func test_locked_cabinet_gates_the_rig() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = null
	for s: int in [4101, 4102, 4103, 4104, 4105]:
		m = await _launch(s)
		if m._slot_active(&"controller", &"ctrl_locked"):
			break
		after_each()
		await wait_frames(1)
		m = null
	if m == null:
		skip("no ctrl_locked roll in 5 seeds")
		return
	var rig: HackTerminal = null
	var lock: Padlock = null
	for n: Node in m.find_tagged(RollingThunderMission.TAG_SIGNALS):
		if n is HackTerminal:
			rig = n as HackTerminal
		elif n is Padlock:
			lock = n as Padlock
	assert_true(rig != null and lock != null, "the rig and the cabinet padlock")
	if rig == null or lock == null:
		return
	assert_true(rig.is_paused(), "the rig is blocked while the cabinet is locked")
	assert_eq(rig._availability(null), HackTerminal.BLOCK_PAUSED)
	lock.open_lock(false, &"lockpick")
	await wait_physics_frames(1)
	assert_false(rig.is_paused(), "the padlock off: the rig can be worked")


## QC-85 (audio_cues v1.9): the mission's RT one-shots: approach at the sighting, the signal heads click when the rig
## is done, a brake per stopped mover, the mixer's ram, the trucks' doors; the freight train, held during a Phantom
## charge.
func test_qc85_rt_cues() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch()
	var cues: Array[StringName] = []
	var on_cue: Callable = func(id: StringName, _p: Vector3, _n: int) -> void: cues.append(id)
	EventBus.audio_cue_requested.connect(on_cue)
	m._sighted()
	assert_has(cues, RollingThunderMission.CUE_APPROACH, "the convoy sighted: approach")
	var rig: HackTerminal = null
	for n: Node in m.find_tagged(RollingThunderMission.TAG_SIGNALS):
		if n is HackTerminal:
			rig = n as HackTerminal
	EventBus.device_finished.emit(rig.net_id)
	await wait_physics_frames(1)
	assert_eq(cues.count(RollingThunderMission.CUE_SIGNAL_CLICK), 4, "every signal head clicks (%s)" % [cues])
	m._convoy_arrives()
	await _stopped(m)
	var rammed: bool = await wait_until(func() -> bool: return cues.has(RollingThunderMission.CUE_MIXER_RAM),
		RollingThunderMission.MIXER_MOVE_S + 1.0)
	assert_true(rammed, "the mixer rams (clean: stop + %.0f s)" % RollingThunderMission.MIXER_MOVE_S)
	if m._movers_left == 0 and not cues.has(RollingThunderMission.CUE_BRAKE):
		assert_true(false, "a drive-in stop brakes each mover (%s)" % [cues])
	for t: ArmoredTruck in m._trucks:
		t.open_by_device()
	await wait_physics_frames(2)
	assert_eq(cues.count(ArmoredTruck.CUE_DOORS_OPEN), m._trucks.size(), "each truck's doors")
	cues.clear()
	m._train()
	assert_has(cues, RollingThunderMission.CUE_TRAIN, "the freight train passes")
	var ph: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"enemy.phantom", Transform3D(Basis(), Vector3(30, 0, 0)))
	await wait_physics_frames(2)
	if not ph.is_empty():
		(ph[0].get_node(^"Brain") as PhantomBrain).goggles_glowing = true
		cues.clear()
		m._train()
		assert_false(cues.has(RollingThunderMission.CUE_TRAIN), "held back while a Phantom charge is live")
		assert_true(m.timer_left(&"freight_train") <= RollingThunderMission.TRAIN_HOLD_S + 0.01, "re-checked soon")
	EventBus.audio_cue_requested.disconnect(on_cue)


## RT phase 2 (C f2c05253): `<slot>/Convoy/Movers/Mixer` stays out of the stop's drive-in; at _mixer_move the Door(s)
## with meta opens_with = "mixer_move" swing open, the "mixer" COVER goes off and the Mixer drives (here: parks, no
## MixerPath) onto the layout's MixerStop.
func test_phase2_mixer_drives_to_its_stop() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch()
	var movers: Node = m._route_slot().get_node(NodePath(RollingThunderMission.MOVERS_PATH))
	var mixer: ConvoyVehicle = (load("res://systems/prefabs/convoy_vehicle/convoy_vehicle.tscn") as PackedScene) \
		.instantiate() as ConvoyVehicle
	mixer.name = "Mixer"
	movers.add_child(mixer)
	mixer.global_position = Vector3(-30, 0, -16)
	var gate: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-40, 0, -30), func(n: Node) -> void:
		n.set_meta(&"opens_with", "mixer_move")
		(n as Door).lock = Door.Lock.LOCKPICK) as Door
	var cover: TacticalPoint = TacticalPoint.new()
	cover.kind = TacticalPoint.Kind.COVER
	cover.tags = [&"mixer"] as Array[StringName]
	_rt.map.add_child(cover)
	await wait_physics_frames(3)
	assert_true(m._mixer() == mixer, "C's Mixer under the route's Convoy/Movers")
	assert_false(m._movers().has(mixer), "the Mixer is no stop leg")
	m._convoy_arrives()
	await _stopped(m)
	var layout: Node3D = ConvoyLayouts.find(_rt.map, m.layout_id)
	var stop: Marker3D = Marker3D.new()
	stop.name = "MixerStop"
	layout.add_child(stop)
	stop.global_position = layout.global_position + Vector3(4.0, 0.0, 4.0)
	m._mixer_move()
	await wait_physics_frames(3)
	assert_true(mixer.global_position.distance_to(stop.global_position) < 0.1, "the mixer on its MixerStop")
	assert_true(gate.is_open, "the opens_with gate swung open")
	assert_false(cover.enabled, "the mixer's cover goes with it")


## RT-A6 "every VO line said": the e2e batch (auto_loud 1004 / 4102, rt_clean 1005) said 25 of the 34 RT lines; the
## other nine hang on what the pilot never does or never rolls (the intro before its logger, the site stores' C4 /
## thermite, the heli escape, the S2 / S3 Longshots). Each one's trigger here.
func test_the_nine_lines_the_e2e_does_not_reach() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var said: Array[StringName] = []
	var on_vo: Callable = func(_s: StringName, id: StringName, _c: Dictionary) -> void: said.append(id)
	EventBus.voice_line_requested.connect(on_vo)
	var m: RollingThunderMission = null
	for s: int in range(4101, 4131):  # a seed with the heli escape
		m = await _launch(s, [&"crane_sniper"], Enums.Difficulty.BRUTAL)
		if m._heli():
			break
		after_each()
		await wait_frames(1)
		said.clear()
		m = null
	if m == null:
		EventBus.voice_line_requested.disconnect(on_vo)
		skip("no esc_heli_roof roll in 30 seeds")
		return
	for id: StringName in [RollingThunderMission.VO_INTRO, RollingThunderMission.VO_REYES_READY]:
		assert_has(said, id, "%s at the start" % id)
	EventBus.item_picked_up.emit(RollingThunderMission.ITEM_C4, 0)
	var lm: LootManager = _rt.get_node(^"LootManager") as LootManager
	var bag: LootBag = lm.spawn_bag(RollingThunderMission.LOOT_THERMITE, Transform3D(Basis(), Vector3(0, 1, 0)))
	EventBus.loot_picked.emit(bag.net_id, 0)
	m._convoy_arrives()
	await _stopped(m)
	var truck: ArmoredTruck = m._trucks[0]
	EventBus.device_started.emit(truck.net_id, &"c4", 5.0)
	EventBus.device_started.emit(truck.net_id, &"thermite", 30.0)
	m._call_escape()
	for tag: StringName in [&"s2", &"s3"]:  # a Longshot takes the free perch nearest the crew: only `tag` is open
		for t: StringName in [&"s1", &"s2", &"s3", &"s4"]:
			m.set_sniper_perches_open(t, t == tag)
		var ls: Array[NpcBase] = SpecialSpawner.spawn_special(_rt, &"enemy.longshot")
		assert_false(ls.is_empty(), "a Longshot on %s" % tag)
		if not ls.is_empty():
			m._on_special_spawned(ls[0].net_id, &"longshot")
	await wait_physics_frames(2)
	EventBus.voice_line_requested.disconnect(on_vo)
	for id: StringName in [RollingThunderMission.VO_C4_FOUND, RollingThunderMission.VO_THERMITE_FOUND,
			RollingThunderMission.VO_C4_ARMED, RollingThunderMission.VO_THERMITE_BURN, RollingThunderMission.VO_HELI_ETA,
			RollingThunderMission.VO_SNIPER_RAIL, RollingThunderMission.VO_SNIPER_CRANE]:
		assert_has(said, id, "%s said by its trigger" % id)


## D-154.2 (revised, B fd41028a): an early alarm brings the convoy at min(ETA, alarm + EARLY_PUSH_S = 25 s); a later alarm
## (ETA already under it) leaves it.
func test_early_alarm_pushes_the_convoy_through() -> void:
	if not _available():
		skip("rolling_thunder map not on this branch")
		return
	var m: RollingThunderMission = await _launch()
	assert_true(m.timer_left(&"convoy") > RollingThunderMission.EARLY_PUSH_S, "ETA is over the push at the start")
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	assert_near(m.timer_left(&"convoy"), RollingThunderMission.EARLY_PUSH_S, 0.5, "the convoy pushes through: alarm + 25 s")
	for id: StringName in [&"eta_60", &"eta_30", &"marshal"]:
		assert_true(m.timer_left(id) <= RollingThunderMission.EARLY_PUSH_S, "%s does not come after the arrival" % id)
	assert_true(m.timer_left(&"sighted") > 0.0, "sighted re-timed before the arrival")
	assert_near(m.police_delay_s, 0.0, 0.001, "police at once (D-075) unchanged")
