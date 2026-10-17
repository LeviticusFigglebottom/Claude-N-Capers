## A2-04 S9.11: bag zipline (P2) and ladder climbing (P1 row; S1.1 casing crew cannot climb).
extends TestCase

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []


func before_each() -> void:
	_events.clear()
	_rt = await HeistLauncher.launch(&"unit_zipline", 1111, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	for pair: Array in [[EventBus.loot_dropped, &"loot_dropped"], [EventBus.loot_secured, &"loot_secured"]]:
		var tag: StringName = pair[1]
		var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			_events.append([tag, a, b, c])
		(pair[0] as Signal).connect(cb)
		_conns.append([pair[0], cb])


func after_each() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _hold(interact: bool, move: Vector2 = Vector2.ZERO, yaw: float = 0.0) -> void:
	var i: CrewIntent = CrewIntent.new()
	i.interact = interact
	i.move = move
	i.look_yaw = yaw
	_rt.set_bot_intent(0, i)


func test_zipline_carries_bag_to_end_and_secures_it() -> void:
	var end: Marker3D = Marker3D.new()
	end.name = "ZipEnd"
	_rt.map.get_node(^"Gameplay").add_child(end)
	end.global_position = Vector3(10, 1.0, -4)
	var zone: SecureZone = ATestMaps.add_prefab(_rt, "secure_zone", Vector3(10, 0, -4), func(n: Node) -> void:
		(n as SecureZone).vehicle_collision = false) as SecureZone
	var zip: Zipline = ATestMaps.add_prefab(_rt, "zipline", Vector3(0, 0, -4), func(n: Node) -> void:
		(n as Zipline).end = NodePath("../ZipEnd")) as Zipline
	await wait_physics_frames(2)
	assert_true(zone != null)
	var c: CrewController = _crew()
	c.set_masked()
	assert_eq(zip.interactable.availability(c), Zipline.BLOCK_REQUIRES_BAG, "needs a carried bag")
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, c.global_position))
	assert_true(loot.carry(bag, c), "carrying")
	assert_eq(zip.interactable.availability(c), InteractableComponent.BLOCK_NONE)
	_rt.teleport_crew(0, zip.use_point.global_transform)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, zip.net_id)
	await wait_seconds(Tweak.interaction().zipline_attach_s + 0.15)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(1)
	assert_false(c.is_carrying_bag(), "bag left the crew")
	assert_eq(_of(&"loot_dropped").size(), 1, "loot_dropped [R]")
	assert_eq(zip.riding.size(), 1, "bag on the line")
	var mid_x: float = bag.global_position.x
	await wait_seconds(zip.travel_time() * 0.4)
	assert_true(bag.global_position.x > mid_x + 1.0, "sliding toward the end")
	assert_true(bag.freeze, "frozen while sliding")
	var arrived: bool = await wait_until(func() -> bool: return zip.riding.is_empty(), zip.travel_time() + 1.0)
	assert_true(arrived, "arrived")
	var ok: bool = await wait_until(func() -> bool: return not _of(&"loot_secured").is_empty(), 3.0)
	assert_true(ok, "dropped at the end into the secure zone")


func _ladder_setup() -> Ladder:
	var l: Ladder = ATestMaps.add_prefab(_rt, "ladder", Vector3(0, 0, -6)) as Ladder
	# Ledge on the +Z side, top at 3 m.
	ATestMaps.add_wall(_rt.map, Vector3(0, 1.5, -4.9), Vector3(3, 3, 2))
	return l


func test_ladder_climb_up_and_down_casing_blocked() -> void:
	var l: Ladder = _ladder_setup()
	await wait_physics_frames(2)
	var c: CrewController = _crew()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, l.bottom_position() + Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	_hold(true, Vector2.ZERO, PI)
	await wait_physics_frames(10)
	assert_false(l.is_climbing(0), "S1.1: casing crew cannot climb")
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)
	c.set_masked()
	_hold(true, Vector2.ZERO, PI)
	await wait_physics_frames(3)
	assert_true(l.is_climbing(0), "masked: holding interact at Bottom climbs")
	await wait_seconds(l.climb_time() * 0.5)
	assert_true(c.global_position.y > 0.8 and c.global_position.y < 3.0, "mid-climb (y %.2f)" % c.global_position.y)
	var up: bool = await wait_until(func() -> bool: return not l.is_climbing(0), l.climb_time() + 1.0)
	assert_true(up, "climb ends")
	assert_true(c.global_position.distance_to(l.top_position()) < 0.3, "at Top (%s)" % c.global_position)
	await wait_physics_frames(5)
	assert_false(l.is_climbing(0), "held interact does not re-grab")
	assert_true(c.global_position.y > 2.8, "standing on the ledge")
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)
	_hold(true, Vector2.ZERO, 0.0)
	await wait_physics_frames(3)
	assert_true(l.is_climbing(0), "interact at Top climbs down")
	var down: bool = await wait_until(func() -> bool: return not l.is_climbing(0), l.climb_time() + 1.0)
	assert_true(down)
	assert_true(c.global_position.distance_to(l.bottom_position()) < 0.3, "at Bottom")
	_rt.clear_bot_intent(0)


func test_ladder_forward_into_it_climbs() -> void:
	var l: Ladder = _ladder_setup()
	await wait_physics_frames(2)
	var c: CrewController = _crew()
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, l.bottom_position() + Vector3(0, 0.05, -0.3)))
	await wait_physics_frames(2)
	_hold(false, Vector2(0, 1), 0.0)  # facing -Z: away from the ladder
	await wait_physics_frames(3)
	assert_false(l.is_climbing(0), "walking away does not climb")
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, l.bottom_position() + Vector3(0, 0.05, -0.3)))
	_hold(false, Vector2(0, 1), PI)  # facing +Z: into the ladder
	var ok: bool = await wait_until(func() -> bool: return l.is_climbing(0), 1.0)
	assert_true(ok, "moving forward into the ladder climbs")
	var up: bool = await wait_until(func() -> bool: return not l.is_climbing(0), l.climb_time() + 1.0)
	assert_true(up)
	assert_true(c.global_position.y > 2.8, "on top")
	_rt.clear_bot_intent(0)


## PO-16 (ENV P free climb): a free climber is not teleport-climbed by the walk-in / interact trigger, start_climb still
## works, and the geometry helpers match the markers.
func test_ladder_free_climber_opt_out_and_geometry() -> void:
	var l: Ladder = _ladder_setup()
	await wait_physics_frames(2)
	var c: CrewController = _crew()
	c.set_masked()
	var b: Vector3 = l.bottom_position()
	var t: Vector3 = l.top_position()
	var line: Array[Vector3] = l.climb_line()
	assert_true(line[0].is_equal_approx(b) and line[1].is_equal_approx(Vector3(b.x, t.y, b.z)), "climb line")
	assert_true(l.face_normal().is_equal_approx(Vector3.BACK), "face normal +Z (%s)" % l.face_normal())
	assert_true(l.top_step_off().is_equal_approx(t) and l.bottom_step_off().is_equal_approx(b), "step-off points")
	Ladder.set_free_climber(c, true)
	assert_true(Ladder.is_free_climber(c))
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, b + Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	_hold(true, Vector2(0, 1), PI)
	await wait_physics_frames(10)
	assert_false(l.is_climbing(0), "a free climber is not teleport-climbed")
	_rt.clear_bot_intent(0)
	assert_true(l.start_climb(c, true), "start_climb still works for a free climber")
	assert_true(await wait_until(func() -> bool: return not l.is_climbing(0), l.climb_time() + 1.0))
	assert_true(c.global_position.y > 2.8, "on top")
	Ladder.set_free_climber(c, false)
	assert_false(Ladder.is_free_climber(c))
	await wait_physics_frames(2)
	_hold(true, Vector2.ZERO, 0.0)
	await wait_physics_frames(3)
	assert_true(l.is_climbing(0), "cleared: the trigger climbs again")
	_rt.clear_bot_intent(0)
