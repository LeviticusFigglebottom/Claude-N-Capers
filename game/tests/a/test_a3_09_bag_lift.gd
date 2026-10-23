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


func _lift(capacity: int = 2, extra: Callable = Callable()) -> BagLift:
	var top: Marker3D = Marker3D.new()
	top.name = "LiftTop"
	_rt.map.get_node(^"Gameplay").add_child(top)
	top.global_position = LIFT_POS + Vector3(0, TOP_Y, 0)
	ATestMaps.add_wall(_rt.map, Vector3(0, TOP_Y - 0.1, -9.4), Vector3(6, 0.2, 5.4))  # upper floor in front of the shaft
	return ATestMaps.add_prefab(_rt, "bag_lift", LIFT_POS, func(n: Node) -> void:
		var l: BagLift = n as BagLift
		l.targets = [NodePath("../LiftTop")] as Array[NodePath]
		l.travel_s = 2.0
		l.capacity = capacity
		if extra.is_valid():
			extra.call(l)) as BagLift


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
	for n: String in ["Car", "DoorL", "DoorR", "Panel"]:  # Panel: optional, in the placeholder
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


## Door travel follows car_size_m (car-sized shafts); explicit door_open_m; door_fold keeps the leaves
## inside the car's side walls.
func test_door_travel_scales_with_car_size() -> void:
	var tw: InteractionTweak = Tweak.interaction()
	var lift: BagLift = _lift(2, func(l: BagLift) -> void: l.car_size_m = Vector3(2.0, 1.2, 1.6))
	await wait_physics_frames(2)
	assert_near(lift.door_travel(), 1.0 - tw.bag_lift_door_margin_m, 0.001, "half the car width minus the margin")
	var door_r: Node3D = lift.visual_node("DoorR") as Node3D
	assert_near(door_r.position.x, 0.3 + lift.door_travel(), 0.001, "DoorR slid by the travel")
	var shape: BoxShape3D = (lift.get_node("CarBody/Shape") as CollisionShape3D).shape as BoxShape3D
	assert_near(shape.size.x, 2.0, 0.001, "CarBody floor follows car_size_m.x")
	assert_near(shape.size.z, 1.6, 0.001, "CarBody floor follows car_size_m.z")
	lift.door_open_m = 0.3
	assert_near(lift.door_travel(), 0.3, 0.001, "explicit door_open_m")
	lift.door_open_m = -1.0
	lift.door_fold = true
	lift._set_doors(true)
	var s: float = tw.bag_lift_door_fold_scale
	assert_near(lift.door_travel(), 0.3 * (1.0 - s), 0.001, "fold: the outer edge stays")
	var door_l: Node3D = lift.visual_node("DoorL") as Node3D
	assert_near(door_l.scale.x, s, 0.001, "leaf folded")
	assert_true(door_l.position.x - 0.3 * s >= -0.6 - 0.001, "folded leaf stays inside the car width")
	lift._set_doors(false)
	assert_near(door_l.scale.x, 1.0, 0.001, "closed: full width")
	assert_near(door_l.position.x, -0.3, 0.001, "closed: at rest")


## A `Panel` child of the prefab root (outside the car visual) replaces the visual's Panel, carries the
## interaction and is copied to the other landing.
func test_external_panel() -> void:
	var lift: BagLift = _lift(2, func(l: BagLift) -> void:
		var m: MeshInstance3D = MeshInstance3D.new()
		m.name = "Panel"
		m.mesh = BoxMesh.new()
		m.position = Vector3(1.1, 1.3, -0.75)
		l.add_child(m))
	await wait_physics_frames(3)
	assert_true(lift.panel_external, "root Panel used")
	assert_eq(lift.panel_node, lift.get_node("Panel"))
	assert_false((lift.visual_node("Panel") as Node3D).visible, "the visual's Panel is hidden")
	assert_true(lift.interactable.global_position.distance_to(lift.panel_node.global_position) < 0.001,
		"landing 0's Interactable sits on the panel")
	var copy: Node3D = lift.get_node_or_null("LandingPanelVisual1") as Node3D
	assert_true(copy != null, "panel copied to landing 1")
	if copy != null:
		assert_true(copy.global_position.distance_to(lift.panel_node.global_position + Vector3(0, TOP_Y, 0)) < 0.01,
			"same offset from landing 1")
	assert_true(lift.panels[1].global_position.distance_to(copy.global_position if copy != null else Vector3.INF) < 0.01,
		"landing 1's panel interaction on the copy")
	assert_false(lift.required_visual_nodes().has("Panel"), "Panel is optional in the visual")


## A bag that falls into the open shaft (car away) goes back in front of the landing it fell in at.
func test_bag_falling_into_shaft_returns_to_landing() -> void:
	var lift: BagLift = _lift()
	await wait_physics_frames(2)
	lift.travel_s = 0.0
	assert_true(lift.send(1), "empty car up")
	assert_eq(lift.landing, 1)
	var loot: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	var bag: LootBag = loot.spawn_bag(&"loot.cash", Transform3D(Basis.IDENTITY, LIFT_POS + Vector3(0, 1.0, 0)))
	var back: bool = await wait_until(func() -> bool: return lift.returned_bags >= 1, 3.0)
	assert_true(back, "returned")
	await wait_physics_frames(10)
	assert_true(bag.global_position.z < LIFT_POS.z - 0.8, "in front of the car (z %.2f)" % bag.global_position.z)
	assert_true(absf(bag.global_position.y) < 0.6, "at landing 0 (y %.2f)" % bag.global_position.y)
	assert_true(bag.interactable.enabled and not bag.freeze, "pick-up-able again")


## P's OF burn run (C's note): the PO-5 pilot stands at landing i's own spot for panel LandingPanel<i>, the lift's
## UsePoint offset carried from landing 0 to landing i (not landing 0's UsePoint for every panel).
func test_pilot_stand_per_landing_panel() -> void:
	var lift: BagLift = await _lift()
	var up: Marker3D = Marker3D.new()
	up.name = "UsePoint"
	lift.add_child(up)
	up.global_position = LIFT_POS + Vector3(0.0, 0.0, 1.2)
	await wait_physics_frames(2)
	var panel1: InteractableComponent = lift.get_node_or_null("%s1" % BagLift.PANEL_PREFIX) as InteractableComponent
	assert_true(panel1 != null, "landing 1 panel spawned")
	if panel1 == null:
		return
	var at1: Vector3 = Po5Pilot._landing_use_point(lift, panel1, up.global_position)
	assert_true(at1.distance_to(up.global_position + Vector3(0, TOP_Y, 0)) < 0.01, "panel 1 stand at the top (%s)" % at1)
	var at0: Vector3 = Po5Pilot._landing_use_point(lift, lift.interactable, up.global_position)
	assert_true(at0.distance_to(up.global_position) < 0.01, "landing 0's own panel keeps the UsePoint")


## P's OF probe: a loud-only lift in stealth says why on every panel (phase_block_key), not the generic "Not now".
func test_phase_block_key_on_every_panel() -> void:
	var lift: BagLift = await _lift(2, func(l: BagLift) -> void:
		l.loud_only = true
		l.phase_block_key = &"ui.blocked.after_breach")
	await wait_physics_frames(2)
	assert_false(_rt.went_loud, "stealth")
	var panel1: InteractableComponent = lift.get_node_or_null("%s1" % BagLift.PANEL_PREFIX) as InteractableComponent
	assert_eq(lift.interactable._phase_block(), &"ui.blocked.after_breach", "landing 0's panel")
	assert_true(panel1 != null and panel1._phase_block() == &"ui.blocked.after_breach", "the runtime landing-1 panel")
	lift.interactable.phase_block_key = &""
	assert_eq(lift.interactable._phase_block(), InteractableComponent.BLOCK_PHASE, "no key: the generic reason")


## OF co-op parity (coop2: the Hoist car at the host's landing 1, the client's at 0): a client places the car from the
## replicated landing / destination / trip_t (NetEntityCodec generic props), mid-trip included.
func test_client_mirrors_the_replicated_car() -> void:
	var lift: BagLift = _lift()
	await wait_physics_frames(2)
	var car: Node3D = lift.visual_node("Car") as Node3D
	assert_true(car != null, "the lift has a Car")
	if car == null:
		return
	var y0: float = car.global_position.y
	NetEntityCodec.apply_state(lift, {"landing": 0, "destination": 1, "trip_t": 0.5})
	lift.mirror_car()
	assert_near(car.global_position.y, y0 + TOP_Y * 0.5, 0.05, "mid-trip: the car halfway up")
	lift.mirror_car(lift.travel_s * 0.25)
	assert_near(car.global_position.y, y0 + TOP_Y * 0.75, 0.05, "the trip runs on between snapshots")
	NetEntityCodec.apply_state(lift, {"landing": 1, "destination": -1, "trip_t": 0.0})
	lift.mirror_car()
	assert_near(car.global_position.y, y0 + TOP_Y, 0.05, "arrived: the car at the top landing")
	assert_eq(lift.panels[1].kind, &"send_lift", "the top panel sends from where the car stands")


## LEAD r304 (PD2 freight lifts): with 3+ landings each landing's panel offers a send to EVERY other landing, so
## ground -> roof is one send (here with 2 bags); the landing's own panel is then only the call.
func test_three_landings_send_straight_to_the_roof() -> void:
	var mid: Marker3D = Marker3D.new()
	mid.name = "LiftMid"
	_rt.map.get_node(^"Gameplay").add_child(mid)
	mid.global_position = LIFT_POS + Vector3(0, TOP_Y, 0)
	var roof: Marker3D = Marker3D.new()
	roof.name = "LiftRoof"
	_rt.map.get_node(^"Gameplay").add_child(roof)
	roof.global_position = LIFT_POS + Vector3(0, TOP_Y * 2.0, 0)
	var lift: BagLift = ATestMaps.add_prefab(_rt, "bag_lift", LIFT_POS, func(n: Node) -> void:
		var l: BagLift = n as BagLift
		l.targets = [NodePath("../LiftMid"), NodePath("../LiftRoof")] as Array[NodePath]
		l.send_prompt_keys = [&"ui.prompt.send_lift_ground", &"", &"ui.prompt.send_lift_roof"] as Array[StringName]
		l.travel_s = 2.0) as BagLift
	var bags: Array[LootBag] = _bags(2)
	await wait_physics_frames(3)
	await wait_until(func() -> bool: return lift.bags_in_car().size() == 2, 3.0)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	assert_eq((lift.send_buttons[0] as Dictionary).size(), 2, "ground: a send to Deck 2 and to the roof")
	var to_roof: InteractableComponent = lift.send_buttons[0][2]
	var to_mid: InteractableComponent = lift.send_buttons[0][1]
	assert_eq(to_roof.prompt_key, &"ui.prompt.send_lift_roof", "labelled with the landing")
	assert_eq(to_mid.prompt_key, &"ui.prompt.send_lift_to_1", "the fallback key when the map names none")
	assert_false(lift.interactable.enabled, "the car is here: the panel is only the call, off")
	assert_eq(to_roof.availability(c), &"", "the roof send is available")
	assert_ne((lift.send_buttons[2][0] as InteractableComponent).availability(c), &"", "not from the roof (car below)")
	to_roof.completed.emit(c)
	assert_true(lift.is_moving() and lift.destination == 2, "one send: straight to the roof")
	assert_eq(lift.riding.size(), 2, "with both bags")
	assert_true(await wait_until(func() -> bool: return not lift.is_moving(), 4.0), "arrived")
	assert_eq(lift.landing, 2, "at the roof")
	await wait_physics_frames(10)
	for b: LootBag in bags:
		assert_true(absf(b.global_position.y - TOP_Y * 2.0) < 0.4, "bag on the roof (y %.2f)" % b.global_position.y)
	assert_true(lift.interactable.enabled, "the ground panel calls it back again")
	assert_false(to_roof.enabled, "ground sends are off while the car is elsewhere")
