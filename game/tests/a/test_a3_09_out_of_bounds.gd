## A3-09 (QC-14, D-040): MapZone.Kind.OUT_OF_BOUNDS: crew respawn at the nearest `oob_respawn`
## PLAYER SpawnPoint (fallback: any PLAYER spawn), loose / carried bags return to their last valid
## position, never an alarm. `oob_respawn` points are not start spawns.
extends TestCase

const QUAY_A: Vector3 = Vector3(14, 0.05, 0)
const QUAY_B: Vector3 = Vector3(-14, 0.05, -14)
const WATER: Vector3 = Vector3(10, 1.0, -10)

var _rt: HeistRuntime = null
var _alarms: Array[StringName] = []
var _cb: Callable = Callable()


func after_each() -> void:
	if EventBus.alarm_raised.is_connected(_cb):
		EventBus.alarm_raised.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(with_respawns: bool) -> void:
	_alarms.clear()
	var specs: Array[Dictionary] = []
	if with_respawns:
		specs = [
			{"kind": SpawnPoint.Kind.PLAYER, "tags": [&"oob_respawn"], "pos": QUAY_A, "name": "QuayA"},
			{"kind": SpawnPoint.Kind.PLAYER, "tags": [&"oob_respawn"], "pos": QUAY_B, "name": "QuayB"},
		]
	_rt = await HeistLauncher.launch(&"unit_oob", 5150, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.with_tagged_spawns(specs), "skip_casing": true, "crew_ai": false})
	_cb = func(reason: StringName, _src: int) -> void: _alarms.append(reason)
	EventBus.alarm_raised.connect(_cb)
	ATestMaps.add_zone(_rt.map, MapZone.Kind.OUT_OF_BOUNDS, WATER, Vector3(6, 3, 6))
	await wait_physics_frames(2)


func _oob() -> OutOfBoundsSystem:
	return _rt.service(OutOfBoundsSystem.SERVICE) as OutOfBoundsSystem


func test_crew_respawn_at_nearest_oob_point_no_alarm() -> void:
	await _launch(true)
	assert_true(_oob() != null, "service registered")
	for c: CrewController in _rt.crew_members():
		assert_true(c.global_position.distance_to(QUAY_A) > 2.0 and c.global_position.distance_to(QUAY_B) > 2.0,
			"slot %d did not start at an oob_respawn point" % c.slot)
	var c0: CrewController = _rt.crew_controller(0) as CrewController
	c0.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, WATER + Vector3(0, -0.95, 0)))
	var ok: bool = await wait_until(func() -> bool: return c0.global_position.distance_to(QUAY_A) < 0.5, 1.0)
	assert_true(ok, "respawned at the nearest oob_respawn (QuayA), at %s" % c0.global_position)
	assert_true(_alarms.is_empty(), "never an alarm")
	assert_eq(_rt.phase, Enums.HeistPhase.STEALTH, "still stealth")
	await wait_physics_frames(5)
	assert_true(c0.global_position.distance_to(QUAY_A) < 0.5, "stays (not out of bounds there)")


func test_fallback_any_player_spawn() -> void:
	await _launch(false)
	var c0: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, WATER + Vector3(0, -0.95, 0)))
	var ok: bool = await wait_until(func() -> bool: return c0.global_position.z > 9.0, 1.0)
	assert_true(ok, "respawned at a PLAYER spawn (z = 10 row), at %s" % c0.global_position)


func test_loose_bag_returns_to_last_valid_position() -> void:
	await _launch(true)
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var rest_pos: Vector3 = Vector3(4, 0.05, -4)
	var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, rest_pos))
	await wait_physics_frames(3)
	await wait_until(func() -> bool: return bag.linear_velocity.length() < 0.05, 2.0)
	await wait_physics_frames(2)
	var valid: Vector3 = _oob().last_valid_position(bag)
	assert_true(valid != Vector3.INF and valid.distance_to(rest_pos) < 0.3, "remembered rest position %s" % valid)
	bag.global_position = WATER + Vector3(0, -0.9, 0)
	await wait_physics_frames(3)
	assert_true(bag.global_position.distance_to(valid) < 0.3, "bag back at %s (now %s)" % [valid, bag.global_position])
	assert_true(_alarms.is_empty())


func test_carried_bag_dropped_and_returned_on_respawn() -> void:
	await _launch(true)
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var c0: CrewController = _rt.crew_controller(0) as CrewController
	c0.set_masked()
	var shore: Vector3 = Vector3(6, 0.05, -4)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, shore))
	await wait_physics_frames(3)
	var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, shore))
	assert_true(loot.carry(bag, c0), "carrying")
	await wait_physics_frames(3)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, WATER + Vector3(0, -0.95, 0)))
	var ok: bool = await wait_until(func() -> bool: return c0.global_position.distance_to(QUAY_A) < 0.5, 1.0)
	assert_true(ok, "respawned")
	assert_false(c0.is_carrying_bag(), "the bag does not travel with the respawn")
	assert_true(bag.global_position.distance_to(shore) < 0.8, "bag returned near the last shore position (%s)" % bag.global_position)
	assert_false(_oob().is_out_of_bounds(bag.global_position), "bag in bounds")
