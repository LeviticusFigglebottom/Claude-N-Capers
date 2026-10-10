## A2-08 (D-037): window GlassBody fitted to the visual's `Glass`, safe KEYCARD method (reader-bound),
## one-way push-bar door, security_camera collision kept in front of its wall-mount pivot.
extends TestCase

var _rt: HeistRuntime = null


func before_each() -> void:
	Engine.time_scale = 1.0
	_rt = await HeistLauncher.launch(&"unit_a2_08", 2808, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	await wait_physics_frames(2)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _crew() -> CrewController:
	var c: CrewController = _rt.crew_controller(0) as CrewController
	c.set_masked()
	return c


func _use_at(p: GameplayPrefab, xf: Transform3D, seconds: float) -> void:
	_crew()
	_rt.teleport_crew(0, xf)
	await wait_physics_frames(1)
	ATestMaps.hold_interact(_rt, 0, p.net_id)
	await wait_seconds(seconds + 0.15)
	_rt.clear_bot_intent(0)
	await wait_physics_frames(2)


## Glass shape (box) in the prefab's space: [centre, size].
func _glass_box(w: WindowPrefab) -> Array:
	var cs: CollisionShape3D = w.get_node(^"GlassBody/Shape") as CollisionShape3D
	var body: Node3D = w.get_node(^"GlassBody") as Node3D
	return [body.transform * cs.position, (cs.shape as BoxShape3D).size]


## A visual with `Frame` and a `Glass` made of `panes` [[size, position], ...] MeshInstance3Ds
## (one pane = `Glass` itself is the MeshInstance3D).
func _window_visual(panes: Array) -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "KitWindow"
	var frame: Node3D = Node3D.new()
	frame.name = "Frame"
	root.add_child(frame)
	frame.owner = root
	var glass: Node3D
	if panes.size() == 1:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = panes[0][0]
		mi.mesh = bm
		mi.position = panes[0][1]
		glass = mi
	else:
		glass = Node3D.new()
		glass.position = Vector3(0, 0.1, 0)
	glass.name = "Glass"
	root.add_child(glass)
	glass.owner = root
	if panes.size() > 1:
		for i: int in range(panes.size()):
			var pm: MeshInstance3D = MeshInstance3D.new()
			pm.name = "Pane%d" % i
			var b: BoxMesh = BoxMesh.new()
			b.size = panes[i][0]
			pm.mesh = b
			pm.position = panes[i][1]
			glass.add_child(pm)
			pm.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func test_window_glass_body_fits_visual_glass() -> void:
	var ph: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(-4, 0.9, -6)) as WindowPrefab
	var vis: PackedScene = _window_visual([[Vector3(2.0, 0.8, 0.01), Vector3(0, 0.5, 0)]])
	var kit: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(0, 0.9, -6), func(p: GameplayPrefab) -> void:
		p.visual_scene = vis) as WindowPrefab
	var multi_vis: PackedScene = _window_visual([
		[Vector3(0.6, 1.0, 0.02), Vector3(-0.4, 0.5, 0)], [Vector3(0.6, 1.0, 0.08), Vector3(0.4, 0.5, 0.01)]])
	var multi: WindowPrefab = ATestMaps.add_prefab(_rt, "window", Vector3(4, 0.9, -6), func(p: GameplayPrefab) -> void:
		p.visual_scene = multi_vis) as WindowPrefab
	await wait_physics_frames(2)
	var b0: Array = _glass_box(ph)
	assert_true((b0[1] as Vector3).is_equal_approx(Vector3(1.0, 1.2, 0.05)), "placeholder keeps 1.0 x 1.2 m: %s" % b0[1])
	assert_true((b0[0] as Vector3).is_equal_approx(Vector3(0, 0.6, 0)), "placeholder centre: %s" % b0[0])
	var b1: Array = _glass_box(kit)
	assert_true((b1[1] as Vector3).is_equal_approx(Vector3(2.0, 0.8, 0.05)), "kit glass 2.0 x 0.8 m: %s" % b1[1])
	assert_true((b1[0] as Vector3).is_equal_approx(Vector3(0, 0.5, 0)), "kit glass centre: %s" % b1[0])
	var b2: Array = _glass_box(multi)
	# Panes span x [-0.7, 0.7], y [0.1, 1.1] (Glass at y 0.1), z [-0.03, 0.05].
	assert_true((b2[1] as Vector3).is_equal_approx(Vector3(1.4, 1.0, 0.08)), "merged AABB size: %s" % b2[1])
	assert_true((b2[0] as Vector3).is_equal_approx(Vector3(0, 0.6, 0.01)), "merged AABB centre: %s" % b2[0])
	# A ray through the wide kit glass near its edge hits the GlassBody (it really collides there).
	var space: PhysicsDirectSpaceState3D = kit.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		kit.global_position + Vector3(0.9, 0.5, -1.0), kit.global_position + Vector3(0.9, 0.5, 1.0), GameplayPrefab.LAYER_WORLD_STATIC)
	var hit: Dictionary = space.intersect_ray(q)
	assert_eq(hit.get("collider"), kit.get_node(^"GlassBody"), "edge of the 2 m glass blocks")
	kit.break_glass()
	assert_eq((kit.get_node(^"GlassBody") as StaticBody3D).collision_layer, 0, "broken: collision off")


func _reader(pos: Vector3, nm: String, targets: Array[NodePath] = []) -> KeycardReader:
	return ATestMaps.add_prefab(_rt, "keycard_reader", pos, func(p: GameplayPrefab) -> void:
		p.name = nm
		(p as KeycardReader).targets = targets) as KeycardReader


func _safe(pos: Vector3, nm: String, methods: Array[StringName], reader_path: NodePath = NodePath(""), lock_s: float = 0.0) -> Safe:
	return ATestMaps.add_prefab(_rt, "safe", pos, func(p: GameplayPrefab) -> void:
		var s: Safe = p as Safe
		s.name = nm
		s.methods = methods
		s.reader = reader_path
		s.time_lock_s = lock_s) as Safe


func _swipe(kr: KeycardReader) -> void:
	var c: CrewController = _crew()
	c.add_item(&"item.keycard")
	await _use_at(kr, kr.use_point.global_transform, Tweak.interaction().keycard_s)


func test_safe_keycard_via_reader_targets() -> void:
	var safe: Safe = _safe(Vector3(-4, 0, -6), "KcSafe", [&"keycard"])
	var kr: KeycardReader = _reader(Vector3(-2.5, 1.2, -6.2), "KcReader", [NodePath("../KcSafe")])
	await wait_physics_frames(2)
	assert_false(safe.interactable.enabled, "the safe itself offers no keycard interaction")
	await _swipe(kr)
	assert_true(kr.used, "reader used")
	assert_true(safe.opened, "reader opened the safe")
	assert_eq(safe.beaten_by, &"keycard")


func test_safe_keycard_via_reader_export_with_time_lock() -> void:
	var kr: KeycardReader = _reader(Vector3(2.5, 1.2, -6.2), "VaultReader")
	# Both wirings at once: it still opens once.
	kr.targets = [NodePath("../Vault")]
	var safe: Safe = _safe(Vector3(4, 0, -6), "Vault", [&"keycard", &"drill"], NodePath("../VaultReader"), 2.0)
	await wait_physics_frames(2)
	assert_eq(safe.interactable.kind, &"place_drill", "other methods still on the safe")
	await _swipe(kr)
	assert_false(safe.opened, "time lock first")
	assert_eq(safe.stage, Safe.Stage.TIME_LOCK)
	assert_eq(safe.beaten_by, &"keycard")
	assert_eq(safe.interactable.kind, &"start_time_lock")
	safe.swing_open()
	assert_true(safe.opened)


func test_safe_without_keycard_method_ignores_reader() -> void:
	var safe: Safe = _safe(Vector3(0, 0, -8), "DrillSafe", [&"drill"])
	var kr: KeycardReader = _reader(Vector3(1.5, 1.2, -8.2), "R3", [NodePath("../DrillSafe")])
	await wait_physics_frames(2)
	await _swipe(kr)
	assert_true(kr.used)
	assert_false(safe.opened, "no &\"keycard\" in methods: not opened")
	assert_eq(safe.stage, Safe.Stage.LOCKED)


func _push_door() -> Door:
	var d: Door = ATestMaps.add_prefab(_rt, "door", Vector3(0, 0, 4), func(p: GameplayPrefab) -> void:
		(p as Door).push_bar = true) as Door
	await wait_physics_frames(2)
	return d


func test_push_bar_door_crew_from_both_sides() -> void:
	var door: Door = await _push_door()
	var c: CrewController = _crew()
	var inside: Transform3D = door.use_point.global_transform  # -Z side
	var outside: Transform3D = Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, 0, 0.7))
	_rt.teleport_crew(0, outside)
	await wait_physics_frames(1)
	assert_false(door.is_inside(c))
	assert_eq(door.interactable.availability(c), Door.BLOCK_PUSH_BAR_OUTSIDE, "blocked from outside")
	await _use_at(door, outside, Tweak.interaction().door_open_s)
	assert_false(door.is_open, "stays closed from outside")
	_rt.teleport_crew(0, inside)
	await wait_physics_frames(1)
	assert_true(door.is_inside(c))
	assert_eq(door.interactable.availability(c), InteractableComponent.BLOCK_NONE, "usable from inside")
	await _use_at(door, inside, Tweak.interaction().door_open_s)
	assert_true(door.is_open, "opened from inside")
	_rt.teleport_crew(0, outside)
	await wait_physics_frames(1)
	assert_eq(door.interactable.availability(c), InteractableComponent.BLOCK_NONE, "open: normal door from outside")
	await _use_at(door, outside, Tweak.interaction().door_open_s)
	assert_false(door.is_open, "closed from outside")
	assert_eq(door.interactable.availability(c), Door.BLOCK_PUSH_BAR_OUTSIDE, "closed again: one-way again")


func test_push_bar_door_npcs_and_nav_link() -> void:
	var door: Door = await _push_door()
	var out_g: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, 0, 1.0)), {})
	var in_g: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, 0, -1.0)), {})
	out_g.get_node("Brain").set_physics_process(false)
	in_g.get_node("Brain").set_physics_process(false)
	await wait_physics_frames(1)
	var link: NavigationLink3D = door.get_node(^"NavLink") as NavigationLink3D
	assert_true(link.enabled and not link.bidirectional, "closed: one-way link inside -> outside")
	assert_true(link.start_position.z < 0.0 and link.end_position.z > 0.0, "link starts inside")
	assert_false(door.can_npc_open(out_g), "outside NPC treats it as locked")
	assert_false(door.passable_for(out_g))
	assert_false(door.npc_open(out_g), "outside NPC cannot open it")
	assert_true(door.can_npc_open(in_g), "inside NPC may open it")
	assert_true(door.npc_open(in_g))
	await wait_seconds(Tweak.interaction().npc_door_open_stealth_s + 0.2)
	assert_true(door.is_open, "opened by the inside NPC")
	assert_true(link.bidirectional, "open: both ways")
	assert_true(door.passable_for(out_g), "open: passable from outside")


func test_security_camera_collision_in_front_of_pivot() -> void:
	var cam: Node3D = (load("res://systems/prefabs/security_camera/security_camera.tscn") as PackedScene).instantiate() as Node3D
	var body: Node3D = cam.get_node(^"Collision") as Node3D
	var cs: CollisionShape3D = body.get_node(^"Shape") as CollisionShape3D
	var box: BoxShape3D = cs.shape as BoxShape3D
	var aabb: AABB = (body.transform * cs.transform) * AABB(-box.size * 0.5, box.size)
	assert_true(aabb.end.z <= 0.0001, "no collision behind the wall-mount pivot (max z %.3f)" % aabb.end.z)
	assert_true(aabb.position.z < -0.3, "still covers the head (min z %.3f)" % aabb.position.z)
	cam.free()
