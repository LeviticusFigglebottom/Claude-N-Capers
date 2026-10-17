## PO6-14 (D-114 §6): AI teammates catch a bag a human throws at them (through the real CrewIntent.throw_bag
## path), fetch one a human threw that landed next to them, carry it while following and secure it at a near
## SECURE_LOOT zone. A plainly dropped bag is not taken.
extends TestCase

const TIME_SCALE: float = 3.0

var _rt: HeistRuntime = null


func after_each() -> void:
	Engine.time_scale = 1.0
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	Modifiers.clear_all()
	await wait_frames(1)


func _launch_unit() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	await wait_physics_frames(2)


func _crew(slot: int) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _loot() -> LootManager:
	return _rt.service(G.SVC_LOOT) as LootManager


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The human (slot 0, bot-driven) issues `o` for a few ticks, then stands still.
func _order(o: StringName, target: int = 0, pos: Vector3 = Vector3.ZERO) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.order = o
	i.order_target_net_id = target
	i.order_position = pos
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(3)
	_rt.set_bot_intent(0, CrewIntent.new())
	await wait_physics_frames(2)


## Order every AI to hold at its spot in `spots` (slot -> position) and wait until they are there.
func _hold_at(spots: Dictionary) -> void:
	for slot: int in spots:
		await _order(&"hold", _crew(slot).net_id, spots[slot])
	var ok: bool = await wait_until(func() -> bool:
		for s: int in spots:
			if _flat(_crew(s).global_position, spots[s]) > 0.9:
				return false
		return true, 10.0)
	assert_true(ok, "the AI crew reached their hold points")


## The human picks up a fresh bag and throws (or drops) it along `yaw` through the CrewIntent path.
func _human_throws(yaw: float, thrown: bool = true, loot_id: StringName = &"loot.jewelry") -> LootBag:
	var human: CrewController = _crew(0)
	var bag: LootBag = _loot().spawn_bag(loot_id, Transform3D(Basis.IDENTITY, human.global_position))
	await wait_physics_frames(1)
	assert_true(_loot().carry(bag, human), "the human carries the bag")
	var face: CrewIntent = CrewIntent.new()
	face.look_yaw = yaw
	_rt.set_bot_intent(0, face)
	await wait_physics_frames(2)
	var t: CrewIntent = CrewIntent.new()
	t.look_yaw = yaw
	t.throw_bag = thrown
	t.drop_bag = not thrown
	_rt.set_bot_intent(0, t)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, face)
	return bag


func test_po6_14_bot_catches_bag_thrown_at_it() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	var h: Vector3 = _crew(0).global_position
	await _hold_at({1: h + Vector3(0.0, 0.0, -3.0), 2: Vector3(6.0, 0.05, -6.0), 3: Vector3(8.0, 0.05, -6.0)})
	var bag: LootBag = await _human_throws(0.0)  # yaw 0 = -Z, straight at slot 1
	assert_true(bag.in_flight, "the bag was thrown")
	var ok: bool = await wait_until(func() -> bool: return bag.is_carried(), 3.0)
	assert_true(ok, "the bag was caught within a few seconds")
	assert_eq(bag.carrier, _crew(1), "the bot it was thrown at carries it")
	assert_eq(CrewAiBrain.of(_crew(1)).leader_slot, 0, "the thrower leads the carrier")


func test_po6_14_bot_fetches_thrown_bag_landing_nearby() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	var h: Vector3 = _crew(0).global_position
	# Beside the flight path (out of catch range), next to where the bag lands (~4 m ahead).
	await _hold_at({1: h + Vector3(-2.2, 0.0, -4.0), 2: Vector3(6.0, 0.05, -6.0), 3: Vector3(8.0, 0.05, -6.0)})
	var bag: LootBag = await _human_throws(0.0)
	await wait_seconds(0.5)
	assert_false(bag.is_carried() and bag.carrier != _crew(1), "no other bot took it")
	var ok: bool = await wait_until(func() -> bool: return bag.is_carried(), 6.0)
	assert_true(ok, "the bot picked up the bag that landed next to it")
	assert_eq(bag.carrier, _crew(1), "the nearby bot carries it")


## OF-X2 (DB thermite read "disabled"): a thrown tool bag (D-068: thermite, drill parts; never secured) is not caught or
## fetched; it stays where the human put it for the human to use.
func test_of_x2_bot_leaves_thrown_tool_bag() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	var h: Vector3 = _crew(0).global_position
	await _hold_at({1: h + Vector3(0.0, 0.0, -3.0), 2: h + Vector3(-2.2, 0.0, -4.0), 3: Vector3(8.0, 0.05, -6.0)})
	var bag: LootBag = await _human_throws(0.0, true, &"loot.thermite")
	assert_true(bag.in_flight, "the tool bag was thrown at slot 1")
	await wait_seconds(4.0)
	assert_false(bag.is_carried(), "no bot caught or fetched the thermite")
	assert_true(bag.interactable != null and bag.interactable.enabled, "the human can pick it up again")


func test_po6_14_dropped_bag_not_taken() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	var h: Vector3 = _crew(0).global_position
	await _hold_at({1: h + Vector3(0.0, 0.0, -1.8), 2: Vector3(6.0, 0.05, -6.0), 3: Vector3(8.0, 0.05, -6.0)})
	var bag: LootBag = await _human_throws(0.0, false)
	await wait_seconds(2.0)
	assert_false(bag.is_carried(), "a dropped (not thrown) bag stays on the floor")


func test_po6_14_caught_bag_secured_near_zone() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)
	var h: Vector3 = _crew(0).global_position
	await _hold_at({1: h + Vector3(0.0, 0.0, -3.0), 2: Vector3(6.0, 0.05, -6.0), 3: Vector3(8.0, 0.05, -6.0)})
	var secured: Array[int] = []
	var on_sec: Callable = func(id: int, _l: StringName, _v: int) -> void: secured.append(id)
	EventBus.loot_secured.connect(on_sec)
	var bag: LootBag = await _human_throws(0.0)
	var bag_id: int = bag.net_id
	var ok: bool = await wait_until(func() -> bool: return bag.is_carried(), 3.0)
	assert_true(ok, "caught")
	# A secure zone shows up within secure_seek_radius_m; the carrier, back on follow, secures the bag there.
	ATestMaps.add_zone(_rt.map, MapZone.Kind.SECURE_LOOT, h + Vector3(4.0, 1.0, -6.0), Vector3(3, 2, 3))
	await _order(&"follow", _crew(1).net_id)
	ok = await wait_until(func() -> bool: return secured.has(bag_id), 12.0)
	EventBus.loot_secured.disconnect(on_sec)
	assert_true(ok, "the bot dropped the bag in the secure zone and it was secured")


func test_po6_14_stealth_bot_at_van_catches_and_leaves() -> void:
	await _launch_unit()
	Engine.time_scale = TIME_SCALE
	var b1: CrewAiBrain = CrewAiBrain.of(_crew(1))
	assert_eq(b1.mode, CrewAiBrain.Mode.STEALTH_WAIT, "waiting at the van")
	var bag: LootBag = await _human_throws(-PI * 0.5)  # +X, toward the AI spawns
	var ok: bool = await wait_until(func() -> bool: return bag.is_carried(), 3.0)
	assert_true(ok, "a bot at the van caught the bag")
	assert_true(bag.carrier != null and bag.carrier.is_ai, "an AI carries it")
	if bag.carrier != null:
		assert_true(CrewAiBrain.of(bag.carrier).stealth_engaged, "it left the van (D-014 P4 option)")
