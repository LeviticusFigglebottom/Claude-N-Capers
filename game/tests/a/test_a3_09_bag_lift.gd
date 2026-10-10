## A3-09 (QC-11, D-040): bag_lift: bags placed in the car travel with it to the other landing
## (`travel_s`, `capacity`), doors close / open, call from the other landing, cues.
extends TestCase

const LIFT_POS: Vector3 = Vector3(0, 0, -6)
const TOP_Y: float = 4.0

var _rt: HeistRuntime = null
var _cues: Array[StringName] = []
var _cb: Callable = Callable()


func before_each() -> void:
	_cues.clear()
	_rt = await HeistLauncher.launch(&"unit_bag_lift", 4242, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	_cb = func(cue_id: StringName, _p: Vector3, _id: int) -> void: _cues.append(cue_id)
	EventBus.audio_cue_requested.connect(_cb)


func after_each() -> void:
	if EventBus.audio_cue_requested.is_connected(_cb):
		EventBus.audio_cue_requested.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _lift(capacity: int = 2) -> BagLift:
	var top: Marker3D = Marker3D.new()
	top.name = "LiftTop"
	_rt.map.get_node(^"Gameplay").add_child(top)
	top.global_position = LIFT_POS + Vector3(0, TOP_Y, 0)
	ATestMaps.add_wall(_rt.map, Vector3(0, TOP_Y - 0.1, -9.4), Vector3(6, 0.2, 5.4))  # upper floor in front of the shaft
	return ATestMaps.add_prefab(_rt, "bag_lift", LIFT_POS, func(n: Node) -> void:
		var l: BagLift = n as BagLift
		l.targets = [NodePath("../LiftTop")] as Array[NodePath]
		l.travel_s = 2.0
		l.capacity = capacity) as BagLift


func _bags(n: int) -> Array[LootBag]:
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var out: Array[LootBag] = []
	for i: int in range(n):
		var x: float = -0.35 + 0.35 * float(i)
		out.append(loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, LIFT_POS + Vector3(x, 0.1, 0.1))))
	return out


func _use_panel(lift: BagLift, at: Vector3) -> void:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, at))
	await wait_physics_frames(2)
	ATestMaps.hold_interact(_rt, 0, lift.net_id)
	await wait_seconds(Tweak.interaction().bag_lift_send_s + 0.2)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(1)


func test_bags_ride_to_the_other_landing_and_back() -> void:
	var lift: BagLift = _lift()
	var bags: Array[LootBag] = _bags(2)
	await wait_physics_frames(3)
	var settled: bool = await wait_until(func() -> bool:
		return bags[0].linear_velocity.length() < 0.05 and bags[1].linear_velocity.length() < 0.05, 3.0)
	assert_true(settled, "bags rest on the car floor")
	assert_eq(lift.landing_count(), 2)
	assert_eq(lift.bags_in_car().size(), 2, "both bags in the car")
	assert_eq(lift.panels.size(), 2, "a panel per landing")
	assert_eq(lift.interactable.kind, &"send_lift", "landing 0 panel sends")
	assert_eq(lift.panels[1].kind, &"call_lift", "landing 1 panel calls")
	for n: String in ["Car", "DoorL", "DoorR", "Panel"]:
		assert_true(lift.visual_node(n) != null, "visual node %s" % n)
	var door_l: Node3D = lift.visual_node("DoorL") as Node3D
	var open_x: float = door_l.position.x
	await _use_panel(lift, lift.use_point.global_position + Vector3(0, 0.05, 0))
	assert_true(lift.is_moving(), "car travels after the send hold")
	assert_eq(lift.riding.size(), 2, "both bags ride")
	assert_true(bags[0].freeze and not bags[0].interactable.enabled, "riding bags are frozen, not pick-up-able")
	assert_true(door_l.position.x > open_x + 0.1, "doors closed while moving")
	assert_has(_cues, &"cue.bag_lift_start")
	assert_true(lift.travel_left() > 0.5, "travel time left exposed")
	await wait_seconds(0.8)
	var y_mid: float = bags[0].global_position.y
	assert_true(y_mid > 0.5 and y_mid < TOP_Y, "bag moves with the car (y %.2f)" % y_mid)
	var arrived: bool = await wait_until(func() -> bool: return not lift.is_moving(), 3.0)
	assert_true(arrived, "arrived")
	assert_eq(lift.landing, 1, "at the top landing")
	assert_has(_cues, &"cue.bag_lift_arrive")
	assert_true(absf(door_l.position.x - open_x) < 0.01, "doors open at the other landing")
	await wait_physics_frames(10)
	for b: LootBag in bags:
		assert_false(b.freeze, "released")
		assert_true(absf(b.global_position.y - TOP_Y) < 0.3, "bag at the top landing (y %.2f)" % b.global_position.y)
	assert_eq(lift.bags_in_car().size(), 2, "still in the car")
	assert_eq(lift.interactable.kind, &"call_lift", "landing 0 panel now calls")
	# Call it back from the bottom landing: the bags come down with it.
	await _use_panel(lift, lift.use_point.global_position + Vector3(0, 0.05, 0))
	assert_true(lift.is_moving(), "called back")
	var back: bool = await wait_until(func() -> bool: return not lift.is_moving(), 3.0)
	assert_true(back)
	assert_eq(lift.landing, 0)
	await wait_physics_frames(5)
	assert_true(bags[0].global_position.y < 0.5, "bags came back down")


func test_capacity_blocks_and_top_panel_sends() -> void:
	var lift: BagLift = _lift(2)
	var bags: Array[LootBag] = _bags(3)
	await wait_physics_frames(3)
	await wait_until(func() -> bool: return bags[2].linear_velocity.length() < 0.05, 3.0)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	assert_eq(lift.bags_in_car().size(), 3)
	assert_eq(lift.interactable.availability(c), BagLift.BLOCK_LIFT_FULL, "over capacity: blocked")
	assert_false(lift.send(1), "send refused over capacity")
	bags[2].global_position = LIFT_POS + Vector3(0, 0.1, -3)
	await wait_physics_frames(3)
	assert_eq(lift.interactable.availability(c), InteractableComponent.BLOCK_NONE, "at capacity: ok")
	# Call the empty-ish car up from the top landing panel.
	var top_use: Vector3 = lift.landing_transform(1) * (lift.global_transform.affine_inverse() * lift.use_point.global_position)
	await _use_panel(lift, top_use + Vector3(0, 0.1, 0))
	assert_true(lift.is_moving(), "top panel calls the car")
	assert_eq(lift.destination, 1)
	assert_eq(lift.interactable.availability(c), InteractableComponent.BLOCK_STATE, "busy while moving")
	var ok: bool = await wait_until(func() -> bool: return not lift.is_moving(), 3.0)
	assert_true(ok)
	assert_eq(lift.panels[1].kind, &"send_lift", "top panel sends now")
