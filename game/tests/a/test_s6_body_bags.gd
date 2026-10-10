## A1-07: body bagging (S6.2), body bags as HEAVY loot hidden in BODY_HIDE zones / containers (S6.3).
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_bodies", 616, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0)})
	_listen(EventBus.body_bagged, &"body_bagged")
	_listen(EventBus.loot_spawned, &"loot_spawned")
	_listen(EventBus.alarm_raised, &"alarm_raised")


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


func _stealth() -> StealthDirector:
	return _rt.service(G.SVC_STEALTH) as StealthDirector


## A dead civilian (no pager) next to masked crew 0.
func _corpse(pos: Vector3) -> NpcBase:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0, 1.2)))
	var npc: NpcBase = _rt.spawn_npc(&"civilian", Transform3D(Basis.IDENTITY, pos))
	await wait_physics_frames(2)
	npc.die({}, c.net_id)
	await wait_physics_frames(1)
	return npc


func test_s6_2_bagging_requires_and_consumes_a_body_bag() -> void:
	var npc: NpcBase = await _corpse(Vector3(0, 0.05, -4))
	var c: CrewController = _rt.crew_controller(0) as CrewController
	var comp: InteractableComponent = npc.get_node_or_null(^"BagBodyInteractable") as InteractableComponent
	assert_true(comp != null, "dead body has BagBodyInteractable")
	if comp == null:
		return
	assert_eq(comp.kind, &"bag_body")
	assert_false(comp.casing_allowed)
	c.body_bags = 0
	assert_eq(comp.availability(c), InteractableComponent.BLOCK_ITEM, "no body bag -> blocked")
	ATestMaps.hold_interact(_rt, 0, npc.net_id)
	await wait_seconds(Tweak.interaction().body_bag_s + 0.3)
	_rt.clear_bot_intent(0)
	assert_true(_of(&"body_bagged").is_empty(), "not bagged without a body bag")
	c.body_bags = 1
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, npc.net_id)
	await wait_seconds(Tweak.interaction().body_bag_s * 0.5)
	assert_true(_of(&"body_bagged").is_empty(), "3 s hold, not done at half")
	var ok: bool = await wait_until(func() -> bool: return not _of(&"body_bagged").is_empty(), 3.0)
	_rt.clear_bot_intent(0)
	assert_true(ok, "body_bagged")
	if not ok:
		return
	var e: Array = _of(&"body_bagged")[0]
	assert_eq(int(e[1]), npc.net_id, "body net id")
	assert_eq(int(e[3]), 0, "slot")
	assert_eq(c.body_bags, 0, "body bag consumed")
	var bag: LootBag = Ids.lookup(int(e[2])) as LootBag
	assert_true(bag != null, "bag spawned")
	if bag != null:
		assert_eq(bag.loot_id, &"loot.body_bag")
		assert_eq(bag.weight, Enums.LootWeight.HEAVY, "S6.3 HEAVY")
		assert_eq(bag.value, 0)
		assert_true(bag.moved, "player-made bag counts as moved")
		assert_true(bag.global_position.distance_to(npc.global_position) < 1.0, "bag at the body")
		assert_eq(_stealth().stimulus(bag.stimulus_id()).get("kind"), &"body_bag", "body_bag stimulus")
	assert_eq(npc.corpse_stimulus_id, 0, "corpse stimulus cleared")
	assert_false(npc.is_in_group(G.BODY), "no longer a corpse")
	assert_false(npc.visible, "body hidden")
	assert_true(Ids.lookup(npc.net_id) == npc, "net id lookup still safe")


func test_s6_2_bagging_blocked_while_pager_pending() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	var g: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4)))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -2.8)))
	await wait_physics_frames(2)
	g.die({}, c.net_id)
	await wait_physics_frames(1)
	var comp: InteractableComponent = g.get_node_or_null(^"BagBodyInteractable") as InteractableComponent
	assert_true(comp != null)
	if comp != null:
		assert_eq(comp.availability(c), InteractableComponent.BLOCK_STATE, "pager pending blocks bagging")
		assert_true((_rt.service(G.SVC_PAGERS) as PagerSystem).blocks_body(g), "PagerSystem.blocks_body")
		_stealth().raise_alarm(&"test", 0)
		await wait_physics_frames(2)
		assert_eq(comp.availability(c), InteractableComponent.BLOCK_NONE, "pager cancelled on loud -> baggable")


func test_s6_3_carry_body_bag_is_heavy() -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	var bag: LootBag = _loot().spawn_bag(&"loot.body_bag", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -1.0)))
	await wait_physics_frames(3)
	ATestMaps.hold_interact(_rt, 0, bag.net_id)
	var ok: bool = await wait_until(func() -> bool: return c.is_carrying_bag(), Tweak.interaction().bag_loot_s + 1.0)
	_rt.clear_bot_intent(0)
	assert_true(ok, "picked up")
	assert_true(c.carried_bag == bag)
	assert_eq(int(c.carried_bag.get(&"weight")), Enums.LootWeight.HEAVY)
	assert_eq(_stealth().stimulus(bag.stimulus_id()), {}, "carried bag is not a stimulus")
	var i: CrewIntent = CrewIntent.new()
	i.move = Vector2(0, 1)
	i.sprint = true
	_rt.set_bot_intent(0, i)
	await wait_seconds(0.8)
	var speed: float = Vector2(c.velocity.x, c.velocity.z).length()
	_rt.clear_bot_intent(0)
	assert_false(c.sprinting, "no sprint with HEAVY")
	assert_near(speed, Tweak.crew().walk_speed * Tweak.crew().bag_speed_mult[Enums.LootWeight.HEAVY], 0.1, "HEAVY speed")
	assert_true(bag.global_position.distance_to(c.global_position) < 1.5, "bag follows the carrier")


func test_s6_3_body_bag_in_body_hide_zone_is_never_noticed() -> void:
	var st: StealthDirector = _stealth()
	var noticed: Array[int] = []
	var cb: Callable = func(_o: Node, sid: int) -> void: noticed.append(sid)
	st.stimulus_noticed.connect(cb)
	ATestMaps.add_zone(_rt.map, MapZone.Kind.BODY_HIDE, Vector3(0, 1, -6), Vector3(3, 2, 3))
	ATestMaps.add_npc_observer(_rt, &"guard", Vector3(0, 0.05, -14), Vector3(0, 0, 1))
	await wait_physics_frames(2)
	# Crew drops a carried body bag into the zone (unmasked crew is not detected out here).
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4.8)))
	var hidden_bag: LootBag = _loot().spawn_bag(&"loot.body_bag", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -4.8)))
	await wait_physics_frames(2)
	assert_true(_loot().carry(hidden_bag, c), "carry")
	var d: CrewIntent = CrewIntent.new()
	d.drop_bag = true
	_rt.set_bot_intent(0, d)
	await wait_physics_frames(2)
	_rt.clear_bot_intent(0)
	assert_false(c.is_carrying_bag(), "dropped")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(-10, 0.05, 10)))
	var control: LootBag = _loot().spawn_bag(&"loot.body_bag", Transform3D(Basis.IDENTITY, Vector3(4, 0.05, -6)))
	await wait_seconds(4.0)
	st.stimulus_noticed.disconnect(cb)
	assert_true(hidden_bag.hidden_from_stealth, "S6.3 hidden in BODY_HIDE")
	assert_false(control.hidden_from_stealth)
	assert_false(noticed.has(hidden_bag.stimulus_id()), "hidden body bag never noticed")
	assert_true(noticed.has(control.stimulus_id()), "control body bag in view is noticed (19 m)")


func test_s6_3_body_container_capacity() -> void:
	var bc: BodyContainer = ATestMaps.add_prefab(_rt, "body_container", Vector3(0, 0, -6),
		func(n: Node) -> void: (n as BodyContainer).capacity = 1) as BodyContainer
	await wait_physics_frames(2)
	var a: LootBag = _loot().spawn_bag(&"loot.body_bag", Transform3D(Basis.IDENTITY, Vector3(-0.4, 1.7, -6)))
	await wait_seconds(1.0)
	var b: LootBag = _loot().spawn_bag(&"loot.body_bag", Transform3D(Basis.IDENTITY, Vector3(0.4, 1.7, -6)))
	await wait_seconds(1.0)
	assert_true(a.hidden_from_stealth, "first bag hidden")
	assert_true(a.container == bc, "stored in the container")
	assert_false(b.hidden_from_stealth, "over capacity -> visible")
	assert_eq(bc.stored, 1)
	var cash: LootBag = _loot().spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, Vector3(0, 1.7, -6.2)))
	await wait_seconds(0.5)
	assert_false(cash.hidden_from_stealth, "only body bags hide")
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(_loot().carry(a, c), "take it out again")
	assert_false(a.hidden_from_stealth)
	assert_eq(bc.stored, 0, "released from the container")
