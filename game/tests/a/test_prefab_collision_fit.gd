## Lead item 6: prefab collision boxes fitted to the visual (merged mesh AABB in prefab space,
## pivot rules from visual_slots.md), a visual-supplied `Collision` body, `collision_size_override`;
## and the safe's C4 blast through Explosion.apply (NPCs hurt, the placing crew spared).
extends TestCase

var _rt: HeistRuntime = null
var _hits: Array[Dictionary] = []
var _cb: Callable = Callable()


func before_each() -> void:
	Engine.time_scale = 1.0
	_hits = []
	_rt = await HeistLauncher.launch(&"unit_collision_fit", 606, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "skip_casing": true, "crew_ai": false})
	_cb = func(v: int, a: int, info: Dictionary) -> void: _hits.append({"victim": v, "attacker": a, "info": info})
	EventBus.damage_applied.connect(_cb)
	await wait_physics_frames(2)


func after_each() -> void:
	Engine.time_scale = 1.0
	if EventBus.damage_applied.is_connected(_cb):
		EventBus.damage_applied.disconnect(_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## Box mesh instance `node_name` of `size` centred at `centre` under `parent` (owned by `root`).
func _box(root: Node, parent: Node, node_name: String, size: Vector3, centre: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = centre
	parent.add_child(mi)
	mi.owner = root
	return mi


func _marker(root: Node, node_name: String, pos: Vector3) -> void:
	var mk: Marker3D = Marker3D.new()
	mk.name = node_name
	mk.position = pos
	root.add_child(mk)
	mk.owner = root


func _pack(root: Node3D) -> PackedScene:
	var ps: PackedScene = PackedScene.new()
	assert_eq(ps.pack(root), OK, "visual packs")
	root.free()
	return ps


## A 2.0 x 0.9 x 0.5 display case: Body 0.6 high, Glass 0.3 on top, plus a foot dipping 5 cm below
## the floor (clipped by the floor pivot rule).
func _wide_case_visual(with_collision: bool = false) -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "WideCase"
	var body: MeshInstance3D = _box(root, root, "Body", Vector3(2.0, 0.6, 0.5), Vector3(0, 0.3, 0))
	_box(root, body, "Foot", Vector3(0.1, 0.1, 0.1), Vector3(0.9, -0.3, 0))
	_box(root, root, "Glass", Vector3(2.0, 0.3, 0.5), Vector3(0, 0.75, 0))
	_marker(root, "LootAnchor", Vector3(0, 0.62, 0))
	if with_collision:
		var sb: StaticBody3D = StaticBody3D.new()
		sb.name = "Collision"
		sb.collision_layer = 0
		root.add_child(sb)
		sb.owner = root
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Shape"
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(2.0, 0.9, 0.5)
		cs.shape = bs
		cs.position = Vector3(0, 0.45, 0)
		sb.add_child(cs)
		cs.owner = root
	return _pack(root)


## [centre, size] of the prefab's `Collision/Shape` box in prefab space.
func _own_box(p: GameplayPrefab) -> Array[Vector3]:
	var cs: CollisionShape3D = p.get_node(^"Collision/Shape") as CollisionShape3D
	var box: BoxShape3D = cs.shape as BoxShape3D
	var c: Vector3 = p.xform_to_self(cs).origin
	return [c, box.size if box != null else Vector3.ZERO]


func _assert_vec(actual: Vector3, expected: Vector3, msg: String) -> void:
	assert_true(actual.is_equal_approx(expected) or (actual - expected).length() < 0.001,
		"%s: %s, expected %s" % [msg, actual, expected])


func _case(pos: Vector3, visual: PackedScene, override: Vector3 = Vector3.ZERO) -> DisplayCase:
	return ATestMaps.add_prefab(_rt, "display_case", pos, func(n: Node) -> void:
		var dc: DisplayCase = n as DisplayCase
		dc.visual_scene = visual
		dc.collision_size_override = override) as DisplayCase


func test_placeholders_keep_their_boxes() -> void:
	var dc: DisplayCase = _case(Vector3(-4, 0, -6), null)
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(0, 0, -6)) as Safe
	var ht: HackTerminal = ATestMaps.add_prefab(_rt, "hack_terminal", Vector3(4, 0, -6)) as HackTerminal
	var cam: SecurityCamera = ATestMaps.add_prefab(_rt, "security_camera", Vector3(0, 2.5, -9)) as SecurityCamera
	await wait_physics_frames(1)
	var b: Array[Vector3] = _own_box(dc)
	_assert_vec(b[1], Vector3(1.0, 1.3, 0.6), "display case placeholder size")
	_assert_vec(b[0], Vector3(0, 0.65, 0), "display case placeholder centre")
	b = _own_box(safe)
	_assert_vec(b[1], Vector3(0.8, 1.2, 0.7), "safe: Body only (the swinging Door is not boxed)")
	_assert_vec(b[0], Vector3(0, 0.6, 0), "safe centre")
	b = _own_box(ht)
	assert_near(b[1].x, 0.6, 0.001, "rack width")
	assert_near(b[1].y, 2.0, 0.001, "rack height")
	assert_true(b[1].z >= 1.0 and b[1].z < 1.1, "rack depth incl. the front screen/panel (%.3f)" % b[1].z)
	var ca: AABB = cam.collision_aabb()
	assert_true(ca.end.z <= 0.0001 and ca.position.z < -0.4, "camera hitbox in front of the wall (%s)" % ca)


func test_custom_visual_sizes_collision() -> void:
	var dc: DisplayCase = _case(Vector3(0, 0, -6), _wide_case_visual())
	await wait_physics_frames(1)
	assert_false(dc.using_placeholder)
	var b: Array[Vector3] = _own_box(dc)
	_assert_vec(b[1], Vector3(2.0, 0.9, 0.5), "2.0 x 0.9 x 0.5 case: collision matches the visual")
	_assert_vec(b[0], Vector3(0, 0.45, 0), "bottom on the floor pivot (the foot below y = 0 is clipped)")
	assert_eq(dc.collision_body(), dc.get_node(^"Collision"), "the prefab's own body is used")
	assert_eq((dc.get_node(^"Collision") as CollisionObject3D).collision_layer, GameplayPrefab.LAYER_WORLD_STATIC)
	# Physically there: a ray at 0.95 m from the case's +X end hits it (the old 1 m box ended at 0.5).
	var space: PhysicsDirectSpaceState3D = dc.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		dc.global_position + Vector3(0.95, 0.5, -2.0), dc.global_position + Vector3(0.95, 0.5, 0.0), 1)
	var hit: Dictionary = space.intersect_ray(q)
	assert_eq(hit.get("collider"), dc.get_node(^"Collision"), "ray at x 0.95 hits the fitted box")


func test_visual_collision_child_replaces_prefab_box() -> void:
	var dc: DisplayCase = _case(Vector3(0, 0, -6), _wide_case_visual(true))
	await wait_physics_frames(1)
	var vis: StaticBody3D = dc.visual_node("Collision") as StaticBody3D
	assert_true(vis != null, "visual supplies Collision")
	assert_eq(dc.collision_body(), vis, "the visual's body is the active one")
	assert_eq(vis.collision_layer, GameplayPrefab.LAYER_WORLD_STATIC, "takes the prefab's layer")
	var own: CollisionObject3D = dc.get_node(^"Collision") as CollisionObject3D
	assert_eq(own.collision_layer, 0, "prefab's own box is off")
	assert_true((own.get_node(^"Shape") as CollisionShape3D).disabled, "own shape disabled")
	assert_eq(Damage.find_target(vis), dc, "hits on the visual's body reach the case")
	dc.take_hit({"amount": 10.0}, 0)
	assert_true(dc.glass_broken, "shooting it still breaks the glass")


func test_override_size() -> void:
	var dc: DisplayCase = _case(Vector3(0, 0, -6), _wide_case_visual(true), Vector3(1.5, 1.0, 0.8))
	await wait_physics_frames(1)
	var b: Array[Vector3] = _own_box(dc)
	_assert_vec(b[1], Vector3(1.5, 1.0, 0.8), "override size")
	_assert_vec(b[0], Vector3(0, 0.5, 0), "override placed on the floor pivot (bottom-centre)")
	assert_eq(dc.collision_body(), dc.get_node(^"Collision"), "override uses the prefab's box")
	var vis: CollisionObject3D = dc.visual_node("Collision") as CollisionObject3D
	assert_eq(vis.collision_layer, 0, "the visual's Collision is turned off by an override")


func test_wall_pivot_clips_behind_the_wall() -> void:
	var root: Node3D = Node3D.new()
	root.name = "CamArt"
	var mount: MeshInstance3D = _box(root, root, "Mount", Vector3(0.2, 0.2, 0.3), Vector3(0, 0, -0.05))
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, -0.1, -0.2)
	root.add_child(head)
	head.owner = root
	_box(root, head, "Housing", Vector3(0.14, 0.14, 0.3), Vector3(0, 0, -0.1))
	var lens: Marker3D = Marker3D.new()
	lens.name = "Lens"
	head.add_child(lens)
	lens.owner = root
	_box(root, head, "Led", Vector3(0.02, 0.02, 0.02), Vector3(0.04, 0.07, -0.2))
	assert_true(mount != null)
	var art: PackedScene = _pack(root)
	var cam: SecurityCamera = ATestMaps.add_prefab(_rt, "security_camera", Vector3(0, 2.5, -9), func(n: Node) -> void:
		(n as SecurityCamera).visual_scene = art) as SecurityCamera
	await wait_physics_frames(1)
	var ca: AABB = cam.collision_aabb()
	assert_near(ca.end.z, 0.0, 0.001, "mount art reaching z +0.1 is clipped at the wall plane")
	assert_near(ca.position.z, -0.45, 0.001, "covers the housing front")
	assert_near(ca.size.x, 0.2, 0.001, "width of the mount")


func test_c4_blast_hurts_npc_not_the_placer() -> void:
	var safe: Safe = ATestMaps.add_prefab(_rt, "safe", Vector3(0, 0, -6), func(n: Node) -> void:
		(n as Safe).methods = [&"c4"]) as Safe
	var npc: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", Vector3(1.5, 0.05, -7.5))
	var far: NpcBase = ACombatSpecials.spawn(_rt, "patrol_officer", Vector3(12, 0.05, -12))
	for n: NpcBase in [npc, far]:
		for nm: String in ["Brain", "Motor", "Gunner"]:
			var c: Node = n.get_node_or_null(nm)
			if c != null:
				c.set_physics_process(false)
		n.max_health = 100000.0
		n.health = 100000.0
	await wait_physics_frames(2)
	var crew: CrewController = _rt.crew_controller(0) as CrewController
	crew.set_masked()
	crew.add_item(Safe.C4_ITEM, 1)
	_rt.teleport_crew(0, safe.use_point.global_transform)
	await wait_physics_frames(1)
	var total: float = crew.health.health + crew.health.armor
	ATestMaps.hold_interact(_rt, 0, safe.net_id)
	await wait_seconds(Tweak.interaction().c4_place_s + 0.15)
	_rt.clear_bot_intent(0)
	assert_eq(safe.stage, Safe.Stage.C4_ARMED, "armed")
	Engine.time_scale = 4.0
	var ok: bool = await wait_until(func() -> bool: return safe.opened, Tweak.interaction().c4_fuse_s + 2.0)
	Engine.time_scale = 1.0
	assert_true(ok, "C4 blew the door")
	var on_npc: Array[Dictionary] = []
	for h: Dictionary in _hits:
		if int(h["victim"]) == npc.net_id:
			on_npc.append(h)
		assert_true(int(h["victim"]) != far.net_id, "outside c4_blast_radius_m: untouched")
		assert_true(int(h["victim"]) != crew.net_id, "no damage event on the placing crew")
	assert_eq(on_npc.size(), 1, "one explosion hit on the nearby NPC")
	if on_npc.size() == 1:
		var info: Dictionary = on_npc[0]["info"]
		assert_eq(int(info["type"]), Enums.DamageType.EXPLOSION, "explosion damage")
		assert_eq(int(on_npc[0]["attacker"]), crew.net_id, "attributed to the crew member who placed it")
		assert_true(float(info["amount"]) > 0.0, "damaged")
	assert_near(crew.health.health + crew.health.armor, total, 0.001, "crew C4 never hurts the crew")
