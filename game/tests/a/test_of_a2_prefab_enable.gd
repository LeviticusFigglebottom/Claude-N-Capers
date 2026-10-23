## OF-A2 (QC-61): runtime enable for pre-placed prefabs. GameplayPrefab.set_enabled / enabled_at_start: disabled =
## hidden, no collision, no interaction, nav links off; replicated (NetEntityCodec "pe"). Ladder (`usable` composes
## with it) and BagLift; a RAPPEL point tagged RappelLinks.TAG_START_DISABLED enabled at runtime opens a path.
extends TestCase

const LIFT_POS: Vector3 = Vector3(0, 2.0, -6)
const TOP_Y: float = 6.0
## Roof slab top for the rappel test (an island: no way down but the rappel link).
const ROOF_Y: float = 6.0
const ROOF_GOAL: Vector3 = Vector3(0, ROOF_Y, -6)
const FLOOR_GOAL: Vector3 = Vector3(6, 0, 6)
const HOLE_TAG: StringName = &"hole"
## Rappel links are on the breach layer (88c955bc): query the way police / specials do.
const POLICE_LAYERS: int = 1 | Door.NAV_LAYER_BREACH

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _launch(map: PackedScene) -> void:
	_rt = await HeistLauncher.launch(&"unit_of_a2", 6102, Enums.Difficulty.ROUTINE, self,
		{"map_packed": map, "skip_casing": true, "crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(2)


func _lift(enabled_at_start: bool) -> BagLift:
	var top: Marker3D = Marker3D.new()
	top.name = "LiftTop"
	_rt.map.get_node(^"Gameplay").add_child(top)
	top.global_position = LIFT_POS + Vector3(0, TOP_Y - LIFT_POS.y, 0)
	return ATestMaps.add_prefab(_rt, "bag_lift", LIFT_POS, func(n: Node) -> void:
		var l: BagLift = n as BagLift
		l.targets = [NodePath("../LiftTop")] as Array[NodePath]
		l.travel_s = 1.0
		l.enabled_at_start = enabled_at_start) as BagLift


## True when a ray straight down through the car floor hits the lift's CarBody.
func _car_hit(lift: BagLift) -> bool:
	var from: Vector3 = LIFT_POS + Vector3(0, 0.5, 0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 1.0, 0), 0xFFFF)
	var hit: Dictionary = lift.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.get("collider") == lift.get_node(^"CarBody")


func _masked_crew() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func test_bag_lift_disabled_then_enabled() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var lift: BagLift = _lift(false)
	await wait_physics_frames(3)
	var c: CrewController = _masked_crew()
	assert_false(lift.is_enabled(), "placed disabled (enabled_at_start false)")
	assert_false(lift.visible, "hidden")
	assert_eq(lift.process_mode, Node.PROCESS_MODE_DISABLED, "no physics processing")
	assert_false(PhysicsServer3D.body_get_space((lift.get_node(^"CarBody") as CollisionObject3D).get_rid()).is_valid(),
		"CarBody out of the physics space")
	assert_false(_car_hit(lift), "no collision")
	assert_eq(lift.panels.size(), 2, "panels still built while disabled")
	for p: InteractableComponent in lift.panels:
		assert_eq(p.availability(c), InteractableComponent.BLOCK_DISABLED, "no interaction at %s" % p.name)
	assert_true(_rt.interaction.aimed_component(c) == null or _rt.interaction.aimed_component(c).owner_node() != lift,
		"never the aimed target")
	var events: Array[bool] = []
	lift.enabled_changed.connect(func(on: bool) -> void: events.append(on))
	lift.set_enabled(true)
	await wait_physics_frames(2)
	assert_eq(events, [true] as Array[bool], "enabled_changed(true)")
	assert_true(lift.visible, "shown")
	assert_true(_car_hit(lift), "collision back")
	assert_eq(lift.interactable.availability(c), InteractableComponent.BLOCK_NONE, "usable")
	assert_true(lift.send(1), "the car runs")
	var arrived: bool = await wait_until(func() -> bool: return not lift.is_moving(), 3.0)
	assert_true(arrived and lift.landing == 1, "arrived at the top landing")
	lift.set_enabled(false)
	await wait_physics_frames(1)
	assert_false(_car_hit(lift), "disabled again: no collision")


func test_ladder_disabled_no_climb_no_link_then_enabled() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var l: Ladder = ATestMaps.add_prefab(_rt, "ladder", Vector3(0, 0, -6), func(n: Node) -> void:
		(n as Ladder).enabled_at_start = false) as Ladder
	await wait_physics_frames(2)
	var c: CrewController = _masked_crew()
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, l.bottom_position() + Vector3(0, 0.05, 0)))
	await wait_physics_frames(2)
	assert_false(l.visible, "hidden")
	assert_false(l.nav_link().enabled, "NavLink off")
	assert_false(l.is_climbable(), "not climbable")
	assert_false(l.start_climb(c, true), "no climb")
	l.set_enabled(true)
	assert_true(l.visible and l.nav_link().enabled and l.is_climbable(), "enabled: shown, link on, climbable")
	# `usable` composes: an enabled but unusable ladder stays visible, link off.
	l.usable = false
	assert_true(l.visible, "unusable ladder still shown")
	assert_false(l.nav_link().enabled, "unusable: link off")
	l.set_enabled(false)
	l.set_enabled(true)
	assert_false(l.nav_link().enabled, "re-enable keeps an unusable ladder's link off")
	l.usable = true
	assert_true(l.nav_link().enabled, "usable again: link on")
	assert_true(l.start_climb(c, true), "climbs")


func test_enabled_state_round_trips_through_the_codec() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var a: Ladder = ATestMaps.add_prefab(_rt, "ladder", Vector3(0, 0, -6)) as Ladder
	var b: Ladder = ATestMaps.add_prefab(_rt, "ladder", Vector3(4, 0, -6)) as Ladder
	await wait_physics_frames(1)
	a.set_enabled(false)
	var st: Dictionary = NetEntityCodec.state_of(a)
	assert_true(st.has("pe") and st["pe"] == false, "state carries pe false (%s)" % st)
	var wire: Dictionary = bytes_to_var(var_to_bytes(st)) as Dictionary
	NetEntityCodec.apply_state(b, wire)
	assert_false(b.is_enabled(), "replica disabled")
	assert_false(b.visible, "replica hidden")
	assert_false(b.nav_link().enabled, "replica link off")
	NetEntityCodec.apply_state(b, {"pe": true})
	assert_true(b.is_enabled() and b.visible and b.nav_link().enabled, "replica re-enabled")
	# A prefab with its own _net_state (Door) carries it too.
	var d: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-6, 0, -6)) as Door
	await wait_physics_frames(1)
	d.set_enabled(false)
	var ds: Dictionary = NetEntityCodec.state_of(d)
	assert_eq(ds.get("pe"), false, "custom-state prefab carries pe")
	d.set_enabled(true)
	NetEntityCodec.apply_state(d, ds)
	assert_false(d.is_enabled(), "applied over a custom-state prefab")
	# A4-03: a mission hiding an enabled prefab on the host (Dockside's unrolled crate stacks) replicates it.
	a.set_enabled(true)
	a.visible = false
	var hs: Dictionary = bytes_to_var(var_to_bytes(NetEntityCodec.state_of(a))) as Dictionary
	assert_eq(hs.get("vis"), false, "state carries vis")
	NetEntityCodec.apply_state(b, hs)
	assert_true(b.is_enabled() and not b.visible, "replica enabled but hidden like the host")


func test_runtime_rappel_link_opens_the_path() -> void:
	var map: PackedScene = ATestMaps.with_slabs(
		[[Vector3(0, ROOF_Y - 0.2, -6), Vector3(6, 0.4, 6)]],
		[{"name": "HoleRappel", "pos": Vector3(0, ROOF_Y, -3.4), "tags": [RappelLinks.TAG_START_DISABLED, HOLE_TAG]}])
	await _launch(map)
	assert_true(await ATestMaps.await_nav_synced(_rt), "navigation synced")
	var tp: TacticalPoint = _rt.map.get_node(^"Tactical/HoleRappel") as TacticalPoint
	var link: NavigationLink3D = RappelLinks.link_of(tp)
	assert_true(link != null, "link built at load")
	if link == null:
		return
	assert_false(link.enabled, "TAG_START_DISABLED: built disabled")
	var nav_map: RID = _rt.get_viewport().world_3d.navigation_map
	var off: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, ROOF_GOAL, FLOOR_GOAL, true, POLICE_LAYERS)
	assert_true(off.size() >= 1 and off[off.size() - 1].y > ROOF_Y - 0.5, "no way off the roof while disabled")
	assert_eq(RappelLinks.set_enabled(_rt.map, HOLE_TAG, true), 1, "one link enabled")
	assert_true(link.enabled, "enabled")
	await wait_physics_frames(1)  # D-121: sync navigation commits at the end of this physics frame
	var on: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, ROOF_GOAL, FLOOR_GOAL, true, POLICE_LAYERS)
	assert_true(on.size() >= 2 and on[on.size() - 1].distance_to(FLOOR_GOAL) < 0.3,
		"the rappel link opens the path down (ends at %s)" % (on[on.size() - 1] if not on.is_empty() else Vector3.INF))
	assert_eq(RappelLinks.set_enabled(_rt.map, HOLE_TAG, true), 0, "idempotent")
	assert_eq(RappelLinks.set_enabled(_rt.map, HOLE_TAG, false), 1, "and off again")


## P OF-P1 (6208602e): a lift placed disabled and enabled at runtime is aimable again: standing in front of its panel
## the interaction ray targets it and a hold works (the OF hoist after the burn).
func test_bag_lift_enabled_at_runtime_is_aimable() -> void:
	await _launch(ATestMaps.basic(0, 0))
	var lift: BagLift = _lift(false)
	await wait_physics_frames(3)
	var c: CrewController = _masked_crew()
	lift.set_enabled(true)
	await wait_physics_frames(3)
	var panel: InteractableComponent = lift.interactable
	var at: Vector3 = panel.global_position
	var n: Vector3 = (c.global_position - at)
	n.y = 0.0
	n = n.normalized() if n.length() > 0.01 else Vector3.BACK
	var stand: Vector3 = Vector3(at.x, LIFT_POS.y, at.z) + n * 1.0
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, stand))
	await wait_physics_frames(2)
	_rt.set_bot_intent(0, BotUtil.look_at_intent(c.eye_position(), at))
	await wait_physics_frames(3)
	var aimed: InteractableComponent = _rt.interaction.aimed_component(c)
	assert_true(aimed != null and aimed.owner_node() == lift, "the enabled lift's panel is the aimed target (%s)" % aimed)
	assert_eq(panel.availability(c), InteractableComponent.BLOCK_NONE, "usable")
	_rt.clear_bot_intent(0)
