## A1-07: loot bags (S10.1 weight limits/throw, S10.2 securing), loot_spawn, carrier drops (S4.1 moved).
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_loot", 1010, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	_listen(EventBus.loot_picked, &"loot_picked")
	_listen(EventBus.loot_dropped, &"loot_dropped")
	_listen(EventBus.loot_secured, &"loot_secured")
	_listen(EventBus.loot_spawned, &"loot_spawned")


func after_each() -> void:
	Engine.time_scale = 1.0
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _listen(sig: Signal, tag: StringName) -> void:
	var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
		_events.append([tag, a, b, c])
	sig.connect(cb)
	_conns.append([sig, cb])


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _loot() -> LootManager:
	return _rt.service(G.SVC_LOOT) as LootManager


func _crew_at(pos: Vector3) -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos))
	return c


func _give_bag(c: CrewController, loot_id: StringName, w: int = -1) -> LootBag:
	var bag: LootBag = _loot().spawn_bag(loot_id, Transform3D(Basis.IDENTITY, c.global_position), true, w)
	await wait_physics_frames(1)
	_loot().carry(bag, c)
	return bag


## Throw the carried bag along the crew's facing (-Z) and return how far it ended up (m).
func _throw(c: CrewController) -> float:
	var start: Vector3 = c.global_position
	var bag: LootBag = c.carried_bag as LootBag
	var t: CrewIntent = CrewIntent.new()
	t.throw_bag = true
	_rt.set_bot_intent(0, t)
	await wait_physics_frames(2)
	_rt.clear_bot_intent(0)
	await wait_seconds(2.0)
	var d: Vector3 = bag.global_position - start
	return Vector2(d.x, d.z).length()


func test_s10_1_sprint_and_jump_limits_per_weight() -> void:
	var tw: CrewTweak = Tweak.crew()
	for w: int in [Enums.LootWeight.LIGHT, Enums.LootWeight.MEDIUM, Enums.LootWeight.HEAVY, Enums.LootWeight.VERY_HEAVY]:
		var c: CrewController = _crew_at(Vector3(0, 0.05, 0))
		await wait_physics_frames(2)
		var bag: LootBag = await _give_bag(c, &"loot.cash", w)
		assert_eq(int(c.carried_bag.get(&"weight")), w)
		var i: CrewIntent = CrewIntent.new()
		i.move = Vector2(0, 1)
		i.sprint = true
		_rt.set_bot_intent(0, i)
		await wait_seconds(0.5)
		assert_eq(c.sprinting, tw.bag_can_sprint[w], "weight %d sprint" % w)
		var j: CrewIntent = CrewIntent.new()
		j.jump = true
		_rt.set_bot_intent(0, j)
		var max_y: float = 0.0
		for k: int in range(30):
			await wait_physics_frames(1)
			max_y = maxf(max_y, c.global_position.y)
		_rt.clear_bot_intent(0)
		# D-102: bags never block a jump; the jump velocity is scaled by bag_jump_mult[w].
		var v: float = tw.jump_velocity * tw.bag_jump_mult[w]
		var apex: float = v * v / (2.0 * tw.gravity)
		assert_true(absf(max_y - apex) <= maxf(apex * 0.15, 0.03),
				"weight %d jump apex %.2f m (expected %.2f)" % [w, max_y, apex])
		await wait_seconds(0.6)
		_loot().drop_bag(c, false)
		bag.queue_free()
		await wait_physics_frames(2)


func test_s10_1_throw_distance_ordering() -> void:
	var dists: Array[float] = []
	for w: int in [Enums.LootWeight.LIGHT, Enums.LootWeight.MEDIUM, Enums.LootWeight.HEAVY, Enums.LootWeight.VERY_HEAVY]:
		var c: CrewController = _crew_at(Vector3(0, 0.05, 6))
		await wait_physics_frames(2)
		var bag: LootBag = await _give_bag(c, &"loot.cash", w)
		var d: float = await _throw(c)
		dists.append(d)
		var nominal: float = Tweak.crew().bag_throw_distance_m[w] + LootTweak.get_default().drop_forward_m
		assert_true(absf(d - nominal) < 1.5, "weight %d thrown %.2f m (nominal %.2f)" % [w, d, nominal])
		assert_false(bag.in_flight, "landed")
		bag.queue_free()
		await wait_physics_frames(2)
	for k: int in range(1, dists.size()):
		assert_true(dists[k] <= dists[k - 1] + 0.05, "heavier never flies further: %s" % [dists])
	var thrown: Array[Array] = _of(&"loot_dropped")
	assert_eq(thrown.size(), 4)
	assert_true(bool(thrown[0][3]), "loot_dropped(thrown = true)")


func test_s10_1_throw_distance_modifier() -> void:
	var c: CrewController = _crew_at(Vector3(0, 0.05, 6))
	await wait_physics_frames(2)
	var bag: LootBag = await _give_bag(c, &"loot.cash", Enums.LootWeight.MEDIUM)
	var base: float = await _throw(c)
	bag.queue_free()
	Modifiers.set_source(0, &"test", {&"loot.throw_distance_mult": 1.5})
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 6)))
	await wait_physics_frames(2)
	bag = await _give_bag(c, &"loot.cash", Enums.LootWeight.MEDIUM)
	var far: float = await _throw(c)
	assert_true(far > base + 1.0, "loot.throw_distance_mult (%.2f vs %.2f)" % [far, base])


func test_s10_2_throw_into_secure_zone_secures() -> void:
	ATestMaps.add_zone(_rt.map, MapZone.Kind.SECURE_LOOT, Vector3(0, 1, -4.5), Vector3(3, 2, 3))
	var c: CrewController = _crew_at(Vector3(0, 0.05, 0))
	await wait_physics_frames(2)
	var bag: LootBag = await _give_bag(c, &"loot.cash")
	var id: int = bag.net_id
	var t: CrewIntent = CrewIntent.new()
	t.throw_bag = true
	_rt.set_bot_intent(0, t)
	var ok: bool = await wait_until(func() -> bool: return not _of(&"loot_secured").is_empty(), 4.0)
	_rt.clear_bot_intent(0)
	assert_true(ok, "secured")
	if ok:
		var e: Array = _of(&"loot_secured")[0]
		assert_eq(int(e[1]), id)
		assert_eq(e[2], &"loot.cash")
		assert_eq(int(e[3]), LootManager.loot_info(&"loot.cash")["value"], "value from ContentDB")
	await wait_frames(2)
	assert_false(is_instance_valid(bag), "secured bag freed")
	assert_false(c.is_carrying_bag())


func test_s10_2_bag_must_rest_in_zone() -> void:
	ATestMaps.add_zone(_rt.map, MapZone.Kind.SECURE_LOOT, Vector3(0, 1, -10), Vector3(3, 2, 3))
	var c: CrewController = _crew_at(Vector3(0, 0.05, 0))
	await wait_physics_frames(2)
	await _give_bag(c, &"loot.cash")
	await _throw(c)
	assert_true(_of(&"loot_secured").is_empty(), "bag outside the zone is not secured")


func test_s10_carrier_downed_drops_bag() -> void:
	var c: CrewController = _crew_at(Vector3(0, 0.05, 0))
	await wait_physics_frames(2)
	var bag: LootBag = await _give_bag(c, &"loot.cash")
	assert_eq(_of(&"loot_picked").size(), 1, "loot_picked")
	c.set_crew_state(Enums.CrewState.DOWNED)
	await wait_physics_frames(2)
	assert_false(c.is_carrying_bag(), "downed -> dropped")
	assert_false(bag.is_carried())
	assert_eq(_of(&"loot_dropped").size(), 1)
	assert_false(bool(_of(&"loot_dropped")[0][3]), "dropped, not thrown")
	c.set_crew_state(Enums.CrewState.NORMAL)


## S10.5 (A4-01 audit): a bag dropped by a player taken into custody stays where it fell (no despawn, no return).
func test_s10_5_custody_drop_stays() -> void:
	var c: CrewController = _crew_at(Vector3(0, 0.05, 0))
	await wait_physics_frames(2)
	var bag: LootBag = await _give_bag(c, &"loot.cash")
	c.health.go_to_custody()
	await wait_physics_frames(3)
	assert_false(c.is_carrying_bag(), "custody drops the bag")
	var at: Vector3 = bag.global_position
	Engine.time_scale = 4.0
	await wait_seconds(5.0)
	Engine.time_scale = 1.0
	assert_true(is_instance_valid(bag) and bag.is_inside_tree(), "still in the world after 20 s")
	assert_false(bag.is_carried() or bag.secured, "loose, not secured or carried away")
	assert_true(bag.global_position.distance_to(at) < 0.5, "where it fell (%s -> %s)" % [at, bag.global_position])


func test_s10_pick_bag_rules_casing_and_one_at_a_time() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var bag: LootBag = _loot().spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -1)))
	await wait_physics_frames(2)
	assert_eq(bag.interactable.availability(c), InteractableComponent.BLOCK_CASING, "S1.1: no bags while casing")
	c.set_masked()
	ATestMaps.hold_interact(_rt, 0, bag.net_id)
	var ok: bool = await wait_until(func() -> bool: return c.is_carrying_bag(), 2.0)
	_rt.clear_bot_intent(0)
	assert_true(ok, "picked up when masked")
	var other: LootBag = _loot().spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, Vector3(0.5, 0.05, -1)))
	await wait_physics_frames(2)
	assert_eq(other.interactable.availability(c), InteractableComponent.BLOCK_STATE, "one bag at a time")
	assert_false(_loot().carry(other, c))


func test_s4_1_preplaced_bag_ignored_until_moved() -> void:
	var st: StealthDirector = _rt.service(G.SVC_STEALTH) as StealthDirector
	var noticed: Array[int] = []
	var cb: Callable = func(_o: Node, sid: int) -> void: noticed.append(sid)
	st.stimulus_noticed.connect(cb)
	ATestMaps.add_npc_observer(_rt, &"guard", Vector3(0, 0.05, -14), Vector3(0, 0, 1))
	var bag: LootBag = _loot().spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -6)), false)
	await wait_seconds(2.5)
	assert_false(noticed.has(bag.stimulus_id()), "pre-placed (moved = false) bag ignored")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_loot().carry(bag, c)
	assert_true(bag.moved, "moved after first pickup")
	await wait_physics_frames(1)
	bag.release(Vector3(0, 0.05, -6), Vector3.ZERO, false)
	c.set_carried_bag(null)
	await wait_seconds(2.5)
	st.stimulus_noticed.disconnect(cb)
	assert_true(noticed.has(bag.stimulus_id()), "moved bag noticed")


func test_loot_spawn_gives_bags_until_empty() -> void:
	var ls: LootSpawn = ATestMaps.add_prefab(_rt, "loot_spawn", Vector3(0, 0, -3), func(n: Node) -> void:
		(n as LootSpawn).loot_id = &"loot.jewelry"
		(n as LootSpawn).count = 2) as LootSpawn
	await wait_physics_frames(2)
	var c: CrewController = _crew_at(ls.use_point.global_position)
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, ls.net_id)
	var ok: bool = await wait_until(func() -> bool: return c.is_carrying_bag(), 2.5)
	_rt.clear_bot_intent(0)
	assert_true(ok, "bag on the back")
	var bag: LootBag = c.carried_bag as LootBag
	assert_eq(bag.loot_id, &"loot.jewelry")
	assert_true(bag.moved, "spawned bags are moved")
	assert_eq(ls.remaining, 1)
	assert_eq(_of(&"loot_spawned").size(), 1, "loot_spawned")
	assert_eq(ls.interactable.availability(c), InteractableComponent.BLOCK_STATE, "not while carrying")
	_loot().drop_bag(c, false)
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, ls.net_id)
	ok = await wait_until(func() -> bool: return c.is_carrying_bag(), 2.5)
	_rt.clear_bot_intent(0)
	assert_true(ok, "second bag")
	assert_eq(ls.remaining, 0)
	assert_false(ls.interactable.enabled, "empty spawn disabled")


func test_loot_info_fallback_and_body_bag_weight() -> void:
	var bb: Dictionary = LootManager.loot_info(&"loot.body_bag")
	assert_eq(int(bb["weight"]), Enums.LootWeight.HEAVY, "body bag HEAVY (S6.3)")
	assert_eq(int(bb["value"]), 0)
	var unknown: Dictionary = LootManager.loot_info(&"loot.does_not_exist")
	assert_false(bool(unknown["known"]))
	assert_eq(int(unknown["weight"]), int(LootTweak.get_default().unknown_weight))


## PO-5 (ENV P, PD2): the throw follows the camera pitch: looking up lobs higher, looking down drops short.
func test_s10_1_throw_follows_look_pitch() -> void:
	var c: CrewController = _crew_at(Vector3(0, 0.05, 6))
	await wait_physics_frames(2)
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var fwd: Vector3 = Vector3(0, 0, -1)
	c.look_pitch = 0.0
	var level: Vector3 = lm.call(&"_throw_velocity", c, Enums.LootWeight.MEDIUM, fwd)
	c.look_pitch = deg_to_rad(40.0)
	var up: Vector3 = lm.call(&"_throw_velocity", c, Enums.LootWeight.MEDIUM, fwd)
	c.look_pitch = deg_to_rad(-45.0)
	var down: Vector3 = lm.call(&"_throw_velocity", c, Enums.LootWeight.MEDIUM, fwd)
	assert_near(level.length(), up.length(), 0.001, "same launch speed")
	assert_true(up.y > level.y * 1.5, "looking up lobs higher (%.2f vs %.2f)" % [up.y, level.y])
	assert_true(down.y < 0.0 or down.y < level.y * 0.2, "looking down throws low (%.2f)" % down.y)
	var lt: LootTweak = LootTweak.get_default()
	assert_near(rad_to_deg(atan2(level.y, Vector2(level.x, level.z).length())), lt.throw_elevation_deg, 0.5,
		"looking level keeps the tuned elevation")
