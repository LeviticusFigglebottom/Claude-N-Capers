## Ostrander Federal hoist panel (OF-C1, ENV P's burn run 7df78180 "Hoist panel 1 not used"): on the built map in a real
## HeistRuntime, as it is after the burn (the lid off, the hoist and the rope ladder enabled, loud), a crew member
## standing where the burn route puts them (ENV P's car-side stand 1.2 m south of the car, the rope ladder's Bottom) has a
## navmesh path to the hoist's UsePoint, and from there the vault panel (landing 0, send_lift) is the aimed target
## (InteractionSystem.aimed_component: the layer-1 LOS ray is not stopped by the hoist rig, which is world_dynamic), is
## usable, and a held interact sends the car up. The TW panel (landing 1) is aimable from the TW floor beside the hole.
## The panel is a plate on ShaftE's east face square in front of the UsePoint (ostrander_federal_content.HOIST_PANEL).
## Owner: ENV C.
extends TestCase

const HEIST: StringName = &"ostrander_federal"
const SEED: int = 1002
const HOIST: String = "Gameplay/Lifts/Hoist"
const ROPE: String = "Gameplay/Ladders/RopeLadder"
const LID: String = "Gameplay/Devices/Lid"
## ENV P of_g1_pass._lift_to / _bag_into_car: the car-side stand is the bottom landing + 1.2 m south.
const CAR_STAND_OFF: Vector3 = Vector3(0.0, 0.0, 1.2)
## A path end this close to the UsePoint counts as reaching it (the pilot's goto tolerance is 0.5 m).
const REACH_M: float = 0.5

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.clear_bot_intent(0)
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_hoist_panel_usable_from_the_burn_route() -> void:
	_rt = await HeistLauncher.launch(HEIST, SEED, Enums.Difficulty.ROUTINE, self,
		{"ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	if _rt == null:
		fail("launch %s" % HEIST)
		return
	var c: CrewController = _rt.crew_controller(0) as CrewController
	assert_true(await wait_until(func() -> bool: return BotUtil.nav_ready(c), 10.0), "nav ready")
	_rt.isolate_npc(null)
	var lift: BagLift = _rt.map.get_node_or_null(HOIST) as BagLift
	var rope: Ladder = _rt.map.get_node_or_null(ROPE) as Ladder
	var lid: GameplayPrefab = _rt.map.get_node_or_null(LID) as GameplayPrefab
	if lift == null or rope == null:
		fail("hoist (%s) / rope ladder (%s) missing" % [lift, rope])
		return
	# As after the burn (OF-A6's burn-through): lid off, ladder and hoist on, loud.
	if lid != null:
		lid.set_enabled(false)
	rope.set_enabled(true)
	lift.set_enabled(true)
	c.set_masked()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(3)
	assert_eq(lift.landing, 0, "the car stands at the vault floor (landing 0)")
	assert_eq(lift.landing_count(), 2, "two landings (vault floor, TW)")
	var panel: InteractableComponent = lift.interactable
	assert_eq(panel.kind, &"send_lift", "the vault panel sends")
	# The panel plate (the external `Panel` on ShaftE's east face) carries the Interactable, and is copied to TW.
	assert_true(lift.panel_external and lift.panel_node != null and lift.panel_node.is_visible_in_tree(),
		"the hoist's external Panel plate is shown")
	if lift.panel_node != null:
		assert_true(panel.global_position.distance_to(lift.panel_node.global_position) < 0.01,
			"the vault Interactable sits on the plate %s" % lift.panel_node.global_position)
	assert_true(lift.get_node_or_null(^"LandingPanelVisual1") != null, "the plate is copied to the TW landing")
	var up: Node3D = lift.get_node_or_null(^"UsePoint") as Node3D
	assert_true(up != null, "the hoist has a UsePoint")
	if up == null:
		return
	# 1. The UsePoint is on the navmesh and reachable from the burn route's standing spots.
	var nav: RID = c.get_world_3d().navigation_map
	var use_at: Vector3 = NavigationServer3D.map_get_closest_point(nav, up.global_position)
	assert_true(_flat(use_at, up.global_position) <= 0.2 and absf(use_at.y - up.global_position.y) < 0.3,
		"UsePoint %s on the navmesh (closest %s)" % [up.global_position, use_at])
	var car_stand: Vector3 = NavigationServer3D.map_get_closest_point(nav,
		lift.landing_transform(0).origin + CAR_STAND_OFF)
	var ladder_bottom: Vector3 = NavigationServer3D.map_get_closest_point(nav, rope.bottom_position())
	for from: Vector3 in [car_stand, ladder_bottom]:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, from, use_at, true)
		var end: Vector3 = path[path.size() - 1] if not path.is_empty() else Vector3.INF
		assert_true(not path.is_empty() and end.distance_to(use_at) <= REACH_M,
			"navmesh path %s -> UsePoint %s (ends %s)" % [from, use_at, end])
		print("  hoist panel: path %s -> UsePoint %s: %d points, ends %s" % [from, use_at, path.size(), end])
	# 2. From the UsePoint the panel is the aimed target: the LOS ray (mask 1) is not stopped by the rig.
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, use_at + Vector3.UP * 0.05))
	await wait_physics_frames(3)
	var eye: Vector3 = c.eye_position()
	assert_true(eye.distance_to(panel.global_position) <= Tweak.interaction().reach_m,
		"panel %s within reach from the UsePoint (%.2f m)" % [panel.global_position, eye.distance_to(panel.global_position)])
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, panel.global_position, 1)
	q.exclude = [c.get_rid()]
	var hit: Dictionary = c.get_world_3d().direct_space_state.intersect_ray(q)
	assert_true(hit.is_empty() or lift.is_ancestor_of(hit["collider"] as Node),
		"interaction ray eye -> panel clear (hit %s)" % [(hit["collider"] as Node).get_path() if not hit.is_empty() else ^"-"])
	_rt.set_bot_intent(0, BotUtil.look_at_intent(eye, panel.global_position))
	await wait_physics_frames(3)
	var aimed: InteractableComponent = _rt.interaction.aimed_component(c)
	assert_true(aimed == panel, "the vault panel is the aimed target from the UsePoint (aimed %s)" % [
		aimed.get_path() if aimed != null else ^"<none>"])
	assert_eq(panel.availability(c), InteractableComponent.BLOCK_NONE, "the vault panel is usable")
	print("  hoist panel: vault panel %s from eye %s (%.2f m): aimed %s, ray hit %s" % [panel.global_position, eye,
		eye.distance_to(panel.global_position), aimed.name if aimed != null else "<none>",
		(hit["collider"] as Node).name if not hit.is_empty() else "-"])
	# 3. A held interact on the aimed panel sends the car to the TW landing.
	var hold: CrewIntent = BotUtil.look_at_intent(eye, panel.global_position)
	hold.interact = true
	_rt.set_bot_intent(0, hold)
	assert_true(await wait_until(func() -> bool: return lift.is_moving() or lift.landing == 1,
		Tweak.interaction().bag_lift_send_s + 2.0), "holding the vault panel sends the hoist")
	_rt.clear_bot_intent(0)
	assert_true(await wait_until(func() -> bool: return not lift.is_moving() and lift.landing == 1, lift.travel_s + 3.0),
		"the car arrives at TW")
	# 4. The TW panel (landing 1, call_lift once the car is back down; send_lift now) is aimable from the TW floor.
	var p1: InteractableComponent = lift.get_node_or_null("%s1" % BagLift.PANEL_PREFIX) as InteractableComponent
	assert_true(p1 != null, "TW landing panel")
	if p1 == null:
		return
	var tw_at: Vector3 = _stand_near(nav, p1.global_position, c)
	assert_true(tw_at != Vector3.INF, "a TW floor stand within reach of the TW panel %s" % p1.global_position)
	if tw_at == Vector3.INF:
		return
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, tw_at + Vector3.UP * 0.05))
	await wait_physics_frames(3)
	_rt.set_bot_intent(0, BotUtil.look_at_intent(c.eye_position(), p1.global_position))
	await wait_physics_frames(3)
	var aimed1: InteractableComponent = _rt.interaction.aimed_component(c)
	assert_true(aimed1 == p1, "the TW panel is the aimed target from %s (aimed %s)" % [tw_at,
		aimed1.get_path() if aimed1 != null else ^"<none>"])
	assert_eq(p1.availability(c), InteractableComponent.BLOCK_NONE, "the TW panel is usable")
	print("  hoist panel: TW panel %s from %s: aimed %s" % [p1.global_position, tw_at,
		aimed1.name if aimed1 != null else "<none>"])


## A navmesh point on the panel's floor (within 0.3 m of its height - 1.15) whose eye is within reach of `at`.
func _stand_near(nav: RID, at: Vector3, c: CrewController) -> Vector3:
	var floor_y: float = at.y - 1.15
	var eye_h: float = c.eye_position().y - c.global_position.y
	for r: float in [0.5, 0.8, 1.1]:
		for k: int in 16:
			var a: float = TAU * float(k) / 16.0
			var p: Vector3 = NavigationServer3D.map_get_closest_point(nav,
				Vector3(at.x + cos(a) * r, floor_y, at.z + sin(a) * r))
			if absf(p.y - floor_y) < 0.3 and (p + Vector3.UP * eye_h).distance_to(at) <= Tweak.interaction().reach_m:
				return p
	return Vector3.INF


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
