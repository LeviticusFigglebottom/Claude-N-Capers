## A1-06: civilian idle/wander (S7.5), loud panic (S11.2), guard alerting (S3.1), self-installed services.
extends TestCase

var _rt: HeistRuntime = null
var _fled: Array[int] = []
var _saved_interval: Vector2 = Vector2.ZERO


func before_each() -> void:
	_saved_interval = Tweak.stealth().civilian_wander_interval_s
	_fled.clear()
	EventBus.civilian_fled.connect(_on_fled)


func after_each() -> void:
	Tweak.stealth().civilian_wander_interval_s = _saved_interval
	if EventBus.civilian_fled.is_connected(_on_fled):
		EventBus.civilian_fled.disconnect(_on_fled)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _on_fled(npc_id: int) -> void:
	_fled.append(npc_id)


func _launch(guards: int, civilians: int) -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 606, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(guards, civilians)})


func test_a1_06_services_self_install() -> void:
	await _launch(0, 2)
	assert_true(_rt.service(ShoutSystem.SERVICE) is ShoutSystem, "shout service installed by a civilian brain")
	assert_true(_rt.service(CivilianTargets.SERVICE) is CivilianTargets, "civilian targets service")


func test_s11_2_alarm_panics_civilians() -> void:
	await _launch(0, 2)
	var civs: Array[Node] = _rt.npcs(&"civilian")
	for n: Node in civs:
		assert_eq((n as NpcBase).alert_state, Enums.AlertState.CALM, "calm before the alarm")
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	assert_eq(_rt.phase, Enums.HeistPhase.LOUD)
	for n: Node in civs:
		var civ: NpcBase = n as NpcBase
		var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
		assert_eq(civ.alert_state, Enums.AlertState.PANICKED, "S11.2: civilians panic")
		assert_true(b.mode == CivilianBrain.Mode.FLEE or b.mode == CivilianBrain.Mode.COWER, "fleeing/cowering")
		assert_has(_fled, civ.net_id, "civilian_fled emitted")
	var start: Vector3 = (civs[0] as NpcBase).global_position
	await wait_seconds(1.0)
	assert_true((civs[0] as NpcBase).global_position.distance_to(start) > 1.0, "running away")


func test_s7_5_idle_activity_and_wander() -> void:
	await _launch(0, 0)
	var seat: Node3D = Node3D.new()  # PO6-06: a seated activity needs a seating prop's `Seat` marker under it
	seat.name = "Seat"
	_rt.map.add_child(seat)
	seat.global_position = Vector3(0, 0.5, 0)
	var sit: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), {"idle_activity": &"sit"})
	await wait_physics_frames(1)
	assert_eq((sit.get_node(^"Brain") as CivilianBrain).anim_hint, &"sit", "idle activity -> anim hint")
	var pp: PatrolPoint = PatrolPoint.new()
	pp.tags = [&"civilian"]
	_rt.map.add_child(pp)
	pp.global_position = Vector3(6, 0.05, 0)
	var walker: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, Vector3(3, 0.05, 0)), {"idle_activity": &"browse"})
	var wb: CivilianBrain = walker.get_node(^"Brain") as CivilianBrain
	await wait_physics_frames(1)
	assert_eq(wb.anim_hint, &"browse")
	wb._wander_timer = 0.0
	await wait_physics_frames(2)
	assert_eq(wb.mode, CivilianBrain.Mode.WANDER, "wanders to the civilian patrol point")
	assert_true(await wait_until(func() -> bool: return wb.mode == CivilianBrain.Mode.IDLE, 6.0), "arrives")
	assert_true(walker.global_position.distance_to(pp.global_position) < 1.0, "at the point")
	assert_eq((sit.get_node(^"Brain") as CivilianBrain).mode, CivilianBrain.Mode.IDLE, "seated civilian stays")


func test_s3_1_no_phone_runs_to_guard() -> void:
	await _launch(1, 1)
	var civ: NpcBase = _rt.npcs(&"civilian")[0] as NpcBase
	var guard: NpcBase = _rt.npcs(&"guard")[0] as NpcBase
	civ.global_position = Vector3(0, 0.05, -5)
	guard.global_position = Vector3(6, 0.05, -5)
	await wait_physics_frames(2)
	var got: Array[StringName] = []
	var cb: Callable = func(_id: int, kind: StringName, _p: Vector3) -> void: got.append(kind)
	guard.stimulus_spotted.connect(cb)
	var b: CivilianBrain = civ.get_node(^"Brain") as CivilianBrain
	civ.notify_crew_spotted(_rt.crew_controller(0))
	assert_eq(b.mode, CivilianBrain.Mode.RUN_TO_CALL, "running to the guard")
	assert_eq(b.call_target.get("kind"), CivilianBrain.KIND_GUARD)
	var reached: bool = await wait_until(func() -> bool: return b.mode != CivilianBrain.Mode.RUN_TO_CALL, 5.0)
	assert_true(reached, "reached the guard")
	assert_true(got.has(&"alerted_npc") or guard.alert_state != Enums.AlertState.CALM, "guard alerted")
	guard.stimulus_spotted.disconnect(cb)
