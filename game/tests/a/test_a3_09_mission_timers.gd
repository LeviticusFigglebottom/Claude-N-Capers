## A3-09: HeistMission timed events: elapsed_s / schedule_at (heist-time marks, e.g. Night Deposit's
## armoured car at 12:00) and relative to an event, spawn_guards at `scripted` GUARD SpawnPoints.
extends TestCase

const CAR_POINT: Vector3 = Vector3(6, 0.05, 8)

var _rt: HeistRuntime = null


func before_each() -> void:
	var specs: Array[Dictionary] = [
		{"kind": SpawnPoint.Kind.GUARD, "tags": [HeistRuntime.SCRIPTED_SPAWN_TAG, &"armored_car"], "pos": CAR_POINT, "name": "CarGuard"},
	]
	_rt = await HeistLauncher.launch(&"unit_mission_timers", 7272, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_tagged_spawns(specs, 1, 0), "skip_casing": true, "crew_ai": false})


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func test_scripted_guard_points_not_spawned_at_load() -> void:
	assert_eq(_rt.npcs(&"guard").size(), 1, "only the ordinary guard spawned at load")
	for g: Node in _rt.npcs(&"guard"):
		assert_true((g as Node3D).global_position.distance_to(CAR_POINT) > 1.0, "nobody at the scripted point")


func test_elapsed_and_schedule_at() -> void:
	var m: HeistMission = _rt.mission
	var t0: float = m.elapsed_s
	await wait_seconds(0.3)
	assert_true(m.elapsed_s >= t0 + 0.25, "heist time advances (%.2f -> %.2f)" % [t0, m.elapsed_s])
	var fired: Array[float] = []
	var mark: float = m.elapsed_s + 0.5
	m.schedule_at(mark, &"armored_car", func() -> void: fired.append(m.elapsed_s))
	assert_true(m.timer_left(&"armored_car") > 0.3, "pending, time left exposed")
	await wait_seconds(0.25)
	assert_true(fired.is_empty(), "not yet")
	var ok: bool = await wait_until(func() -> bool: return not fired.is_empty(), 1.0)
	assert_true(ok, "fired")
	if ok:
		assert_true(absf(fired[0] - mark) < 0.1, "at the heist-time mark (%.2f vs %.2f)" % [fired[0], mark])
	var late: Array[int] = []
	m.schedule_at(0.0, &"passed", func() -> void: late.append(1))
	await wait_physics_frames(3)
	assert_eq(late.size(), 1, "a passed mark fires right away")
	var cancelled: Array[int] = []
	m.schedule_at(m.elapsed_s + 0.2, &"cancel_me", func() -> void: cancelled.append(1))
	m.cancel_timer(&"cancel_me")
	await wait_seconds(0.4)
	assert_true(cancelled.is_empty(), "cancel_timer works")


func test_schedule_after_event_once() -> void:
	var m: HeistMission = _rt.mission
	var fired: Array[int] = []
	assert_true(m.schedule_at(0.3, &"after_loot", func() -> void: fired.append(1), &"small_loot_taken"))
	assert_false(m.schedule_at(1.0, &"x", func() -> void: pass, &"no_such_signal"), "unknown signal refused")
	await wait_seconds(0.4)
	assert_true(fired.is_empty(), "waits for the event")
	EventBus.small_loot_taken.emit(100, 0)
	assert_true(m.timer_left(&"after_loot") > 0.2, "timer started at the event")
	EventBus.small_loot_taken.emit(100, 0)
	var ok: bool = await wait_until(func() -> bool: return not fired.is_empty(), 1.0)
	assert_true(ok, "fired after the delay")
	await wait_seconds(0.5)
	assert_eq(fired.size(), 1, "one-shot")


func test_spawn_guards_at_tagged_points() -> void:
	var m: HeistMission = _rt.mission
	var spawned: Array[Node] = []
	m.schedule_at(m.elapsed_s + 0.2, &"armored_car", func() -> void: spawned.append_array(m.spawn_guards(2, &"armored_car")))
	var ok: bool = await wait_until(func() -> bool: return not spawned.is_empty(), 1.0)
	assert_true(ok, "timed spawn ran")
	assert_eq(spawned.size(), 2, "2 guards")
	assert_eq(_rt.npcs(&"guard").size(), 3, "1 + 2 guards")
	if spawned.size() == 2:
		var a: Node3D = spawned[0] as Node3D
		var b: Node3D = spawned[1] as Node3D
		assert_true(a.global_position.distance_to(CAR_POINT) < 0.5, "first at the point")
		assert_true(absf(b.global_position.distance_to(a.global_position) - 0.8) < 0.3, "second offset 0.8 m")
		assert_true((spawned[0] as NpcBase).role == &"guard", "guards")
	assert_eq(m.spawn_guards(1, &"no_such_tag").size(), 0, "unknown tag: none")


func test_mission_dominated_callbacks_receive_nodes() -> void:
	var ps: PackedScene = ATestMaps.basic(1, 1)
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_dom", 5, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ps, "crew_ai": false})
	var got: Array[Node] = []
	var m: HeistMission = rt.mission
	var civ: Node = rt.npcs(&"civilian")[0]
	var probe: Callable = func(id: int, _s: int) -> void: got.append(Ids.lookup(id))
	EventBus.civilian_intimidated.connect(probe)
	EventBus.civilian_intimidated.emit(NetIds.of(civ), 0)
	EventBus.civilian_intimidated.disconnect(probe)
	assert_eq(got.size(), 1)
	assert_true(got[0] == civ, "net_id resolves to the civilian node the mission hook receives")
	assert_true(m.has_method(&"_on_civilian_dominated"), "HeistMission exposes the civilian-dominated hook")
	rt.teardown()
	await wait_frames(1)
