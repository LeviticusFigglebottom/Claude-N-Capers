## PO-6 (D-105, impact_fx.md §5): door leaves swing (ease-out) over InteractionTweak.door_swing_open_s /
## door_swing_close_s / door_swing_breach_s; the leaf body follows the leaf every physics tick; a crew member
## in the sweep holds the leaf while the door stays logically open; load-time states snap.
extends TestCase

## Extra physics ticks allowed past a swing's nominal duration.
const MARGIN_TICKS: int = 3

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 6, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "ai_teammates": 0})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## A door at the origin (crew spawns at z 10), settled for a couple of ticks so its changes animate.
func _door(setup: Callable = Callable()) -> Door:
	var d: Door = ATestMaps.add_prefab(_rt, "door", Vector3.ZERO, setup) as Door
	await wait_physics_frames(2)
	return d


func _ticks(seconds: float) -> int:
	return int(ceil(seconds * Engine.physics_ticks_per_second))


func _open_yaw() -> float:
	return -deg_to_rad(Tweak.interaction().door_open_angle_deg)  # INWARD: Leaf swings toward +Z


func test_po6_open_takes_open_time() -> void:
	var d: Door = await _door()
	var leaf: Node3D = d.visual_node("Leaf") as Node3D
	var open_s: float = Tweak.interaction().door_swing_open_s
	assert_true(open_s > 0.1, "door_swing_open_s set")
	d.set_open(true)
	assert_true(d.is_open, "logically open at once")
	assert_true(d.is_swinging(), "swinging")
	await wait_physics_frames(maxi(_ticks(open_s * 0.5) - 1, 1))
	assert_true(d.leaf_open_fraction() > 0.05 and d.leaf_open_fraction() < 0.99,
		"half-way through: moving, not there (%.2f)" % d.leaf_open_fraction())
	assert_true(absf(leaf.rotation.y) < absf(_open_yaw()) - 0.01, "leaf short of the open angle at half time")
	await wait_physics_frames(_ticks(open_s * 0.5) + MARGIN_TICKS)
	assert_false(d.is_swinging(), "done within open_s + margin")
	assert_near(leaf.rotation.y, _open_yaw(), 0.001, "leaf at the open angle")


func test_po6_close_takes_close_time() -> void:
	var d: Door = await _door()
	d.set_open(true)
	d.finish_swing()
	var leaf: Node3D = d.visual_node("Leaf") as Node3D
	assert_near(leaf.rotation.y, _open_yaw(), 0.001, "finish_swing snaps open")
	var close_s: float = Tweak.interaction().door_swing_close_s
	d.set_open(false)
	assert_false(d.is_open, "logically closed at once")
	await wait_physics_frames(maxi(_ticks(close_s * 0.5) - 1, 1))
	assert_true(d.leaf_open_fraction() > 0.01, "half-way through the close: not shut yet (%.2f)" % d.leaf_open_fraction())
	var body: AnimatableBody3D = d.get_node(^"LeafBody") as AnimatableBody3D
	assert_eq(body.collision_layer, GameplayPrefab.LAYER_WORLD_DYNAMIC, "a closing leaf blocks")
	await wait_physics_frames(_ticks(close_s * 0.5) + MARGIN_TICKS)
	assert_false(d.is_swinging(), "done within close_s + margin")
	assert_near(leaf.rotation.y, 0.0, 0.001, "leaf shut")


func test_po6_breach_is_fast() -> void:
	var d: Door = await _door()
	var tw: InteractionTweak = Tweak.interaction()
	assert_true(tw.door_swing_breach_s < tw.door_swing_open_s, "breach faster than a normal open")
	d.set_open(true, false, true)
	await wait_physics_frames(_ticks(tw.door_swing_breach_s) + MARGIN_TICKS)
	assert_false(d.is_swinging(), "breach swing done within breach_s + margin")
	assert_near((d.visual_node("Leaf") as Node3D).rotation.y, _open_yaw(), 0.001, "leaf open")
	# The same tick count is not enough for a normal open.
	var n: Door = ATestMaps.add_prefab(_rt, "door", Vector3(4, 0, 0)) as Door
	await wait_physics_frames(2)
	n.set_open(true)
	await wait_physics_frames(_ticks(tw.door_swing_breach_s))
	assert_true(n.is_swinging(), "a normal open is still swinging after breach_s")


func test_po6_client_swings_on_replicated_state() -> void:
	var d: Door = await _door()
	var tw: InteractionTweak = Tweak.interaction()
	d._apply_net_state({"is_open": true, "sw": true})  # what HeistNetSync hands a client
	assert_true(d.is_open, "mirrored open")
	assert_true(d.is_swinging(), "the client animates locally")
	await wait_physics_frames(_ticks(tw.door_swing_breach_s) + MARGIN_TICKS)
	assert_false(d.is_swinging(), "replicated forced open uses the breach swing")
	var st: Dictionary = NetEntityCodec.state_of(d)
	assert_true(st.has("is_open") and st.has("locked") and st.has("sw"), "net state keys: %s" % [st.keys()])


func test_po6_body_in_the_sweep_stops_the_leaf() -> void:
	var d: Door = await _door()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	# Stand inside the INWARD swing arc (hinge at x -0.45, leaf sweeps the +Z quadrant to 0.9 m).
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0.05, 0.05, 0.55)))
	await wait_physics_frames(3)
	var open_s: float = Tweak.interaction().door_swing_open_s
	d.set_open(true)
	await wait_physics_frames(_ticks(open_s) + 2 * MARGIN_TICKS)
	assert_true(d.is_open, "door stays logically open")
	assert_true(d.swing_blocked, "leaf blocked by the crew member")
	assert_true(d.leaf_open_fraction() < 0.95, "leaf short of the open angle (%.2f)" % d.leaf_open_fraction())
	var leaf: Node3D = d.visual_node("Leaf") as Node3D
	assert_true(absf(leaf.rotation.y) < absf(_open_yaw()) - 0.05, "leaf rotation short of open")
	assert_true(c.global_position.distance_to(Vector3(0.05, c.global_position.y, 0.55)) < 0.1,
		"the leaf did not shove the crew member")
	# Clear the sweep: the leaf resumes.
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(10, 0.05, 10)))
	await wait_physics_frames(3)
	assert_true(await wait_until(func() -> bool: return not d.is_swinging(), open_s + 0.5), "resumes once clear")
	assert_near(leaf.rotation.y, _open_yaw(), 0.001, "then fully open")


func test_po6_collision_follows_the_leaf_mid_swing() -> void:
	var d: Door = await _door()
	var leaf: Node3D = d.visual_node("Leaf") as Node3D
	var body: AnimatableBody3D = d.get_node(^"LeafBody") as AnimatableBody3D
	var cs: CollisionShape3D = body.get_node(^"Collision") as CollisionShape3D
	var cs_local: Transform3D = leaf.global_transform.affine_inverse() * cs.global_transform
	d.set_open(true)
	var checked: int = 0
	for _i: int in range(_ticks(Tweak.interaction().door_swing_open_s) + MARGIN_TICKS):
		await wait_physics_frames(1)
		var f: float = d.leaf_open_fraction()
		if f > 0.02 and f < 0.98:
			checked += 1
			assert_true(body.global_transform.is_equal_approx(leaf.global_transform),
				"leaf body on the leaf at %.2f" % f)
			assert_true(cs.global_transform.is_equal_approx(leaf.global_transform * cs_local),
				"leaf collision shape on the leaf at %.2f" % f)
	assert_true(checked >= 3, "sampled mid-swing (%d ticks)" % checked)


func test_po6_load_time_states_snap() -> void:
	var s: Door = ATestMaps.add_prefab(_rt, "door", Vector3(4, 0, 0),
		func(p: GameplayPrefab) -> void: (p as Door).starts_open = true) as Door
	assert_false(s.is_swinging(), "starts_open snaps")
	assert_near(s.leaf_open_fraction(), 1.0, 0.0001, "starts_open: fully open")
	var m: Door = ATestMaps.add_prefab(_rt, "door", Vector3(-4, 0, 0)) as Door
	m.set_open(true)  # mission variants in _on_mission_start: same physics frame as the door's ready
	assert_near(m.leaf_open_fraction(), 1.0, 0.0001, "a change in the ready frame snaps")
	await wait_physics_frames(2)
	m.set_open(false, true)
	assert_false(m.is_swinging(), "instant snaps")
	assert_near((m.visual_node("Leaf") as Node3D).rotation.y, 0.0, 0.0001, "instant close")
