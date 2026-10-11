## A3-12 throwables (CrewThrowables + ThrownItem): frag explodes on its fuse (L3.6 falloff, noise), concussion
## stuns without damage, incendiary lights a fire pool that sets NPCs burning; one used per throw, none while
## casing or empty, no shooting while throwing; the count syncs from ammo pickups.
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Dictionary] = []
var _cb: Callable = Callable()


func after_each() -> void:
	if EventBus.damage_applied.is_connected(_cb):
		EventBus.damage_applied.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	ContentDB.clear_cache()
	await wait_frames(2)


func _def(kind: StringName, damage: float, radius: float, fuse: float = 1.0) -> ThrowableDef:
	var d: ThrowableDef = ThrowableDef.new()
	d.id = StringName("throwable.test_%s" % kind)
	d.kind = kind
	d.count = 3
	d.damage = damage
	d.radius_m = radius
	d.fuse_s = fuse
	ContentDB.inject(ContentDB.THROWABLES, d.id, d)
	return d


func _launch(def: ThrowableDef, skip_casing: bool = true) -> CrewController:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.throwable = def.id
	_rt = await HeistLauncher.launch(&"unit_map", 31201, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": skip_casing,
		"loadouts": {0: l}})
	await wait_physics_frames(2)
	_events = []
	_cb = func(v: int, _a: int, info: Dictionary) -> void: _events.append({"victim": v, "info": info})
	EventBus.damage_applied.connect(_cb)
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	return _rt.crew_controller(0) as CrewController


func _target(pos: Vector3) -> NpcBase:
	var n: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", pos, Vector3(0, 0, 1))
	n.max_health = 100000.0
	n.health = 100000.0
	return n


func _hits(n: NpcBase, type: int) -> int:
	var k: int = 0
	for e: Dictionary in _events:
		if int(e["victim"]) == n.net_id and int((e["info"] as Dictionary)["type"]) == type:
			k += 1
	return k


## Press throw aimed at `at`, release the key, wait `wait_s`.
func _throw(c: CrewController, at: Vector3, wait_s: float) -> void:
	var i: CrewIntent = BotUtil.look_at_intent(c.eye_position(), at)
	i.throw_item = true
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, BotUtil.look_at_intent(c.eye_position(), at))
	await wait_seconds(wait_s)


func test_frag_explodes_on_fuse() -> void:
	var def: ThrowableDef = _def(ThrownItem.KIND_FRAG, 800.0, 5.0, 1.0)
	var c: CrewController = await _launch(def)
	c.set_masked()
	var n: NpcBase = _target(Vector3(0, 0.05, -6))
	var noises: Array = []
	_rt.noise_made.connect(func(_p: Vector3, _r: float, k: StringName, _s: int) -> void: noises.append(k))
	assert_eq(c.weapons.throwable_count, 3, "ThrowableDef.count")
	await _throw(c, Vector3(0, 0.0, -6), 0.15)
	assert_true(c.throwables.busy(), "throwing")
	assert_false(c.weapons.can_fire(), "no shooting while throwing")
	await wait_seconds(CombatTweak.data().throw_windup_s)
	assert_eq(c.weapons.throwable_count, 2, "one used at the release")
	var items: Array[Node] = get_tree().get_nodes_in_group(ThrownItem.GROUP)
	assert_eq(items.size(), 1, "a grenade in flight")
	assert_true(items.size() == 1 and NetIds.of(items[0]) != 0, "replicated (net_id)")
	assert_eq(_hits(n, Enums.DamageType.EXPLOSION), 0, "not before the fuse")
	await wait_seconds(def.fuse_s + 0.3)
	assert_eq(_hits(n, Enums.DamageType.EXPLOSION), 1, "frag: one explosion hit")
	assert_true(noises.has(&"explosion"), "loud")
	assert_true(get_tree().get_nodes_in_group(ThrownItem.GROUP).is_empty(), "gone after the blast")


func test_concussion_stuns_without_damage() -> void:
	var c: CrewController = await _launch(_def(ThrownItem.KIND_CONCUSSION, 0.0, 6.0, 1.0))
	c.set_masked()
	var n: NpcBase = _target(Vector3(0, 0.05, -6))
	await _throw(c, Vector3(0, 0.0, -6), CombatTweak.data().throw_windup_s + 1.4)
	assert_true(n.is_stunned(), "concussion stun")
	assert_eq(_hits(n, Enums.DamageType.EXPLOSION), 0, "no damage")


func test_incendiary_pool_sets_npcs_burning() -> void:
	var c: CrewController = await _launch(_def(ThrownItem.KIND_INCENDIARY, 0.0, 3.0))
	c.set_masked()
	var n: NpcBase = _target(Vector3(0, 0.05, -5))
	await _throw(c, Vector3(0, 0.0, -5), CombatTweak.data().throw_windup_s + 1.5)
	var pools: Array[Node] = get_tree().get_nodes_in_group(ThrownItem.GROUP)
	assert_eq(pools.size(), 1, "the pool burns")
	if pools.size() == 1:
		var item: ThrownItem = pools[0] as ThrownItem
		assert_true(item.pool_left > 0.0, "burning")
		assert_true(Vector2(item.global_position.x, item.global_position.z).distance_to(Vector2(0, -5)) < 3.0,
			"landed near the aim point")
	assert_true(n.get_node_or_null(BurnStatus.NODE_NAME) != null, "the NPC in the pool burns")
	await wait_seconds(1.0)
	assert_true(_hits(n, Enums.DamageType.FIRE) > 0, "fire damage")
	var self_burns: int = 0
	for e: Dictionary in _events:
		if int(e["victim"]) == c.net_id:
			self_burns += 1
	assert_eq(self_burns, 0, "the crew is never burnt (no friendly fire)")


func test_gates_and_count_sync() -> void:
	var c: CrewController = await _launch(_def(ThrownItem.KIND_FRAG, 100.0, 4.0), false)
	await _throw(c, Vector3(0, 0, -6), 0.1)
	assert_false(c.throwables.busy(), "S1.1: no throwing while casing")
	c.set_masked()
	CrewThrowables.set_count(c, 0)
	await _throw(c, Vector3(0, 0, -6), 0.1)
	assert_false(c.throwables.busy(), "none left")
	CrewThrowables.set_count(c, 1)
	assert_eq(c.weapons.throwable_count, 1, "set_count")
	await _throw(c, Vector3(0, 0, -6), CombatTweak.data().throw_windup_s + 0.1)
	assert_eq(c.weapons.throwable_count, 0, "thrown")
