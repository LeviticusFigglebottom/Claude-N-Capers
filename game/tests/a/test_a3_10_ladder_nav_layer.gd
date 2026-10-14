## A3-10 (S10.1b, S1.1): a Ladder builds its own NavigationLink3D on Ladder.NAV_LAYER (not layer 1),
## so default agents / path queries (layer 1: NPCs, police, AI crew bots, bag carriers) never route
## up a ladder they cannot climb; a climber's query (1 | NAV_LAYER) does.
extends TestCase

## Ladder pivot (bottom-centre, climb side -Z, ledge at +Z).
const LADDER_POS: Vector3 = Vector3(0.0, 0.0, -6.0)
const PLATFORM_H: float = 3.0
## Platform box: x in [-3, 3], z in [-5.9, 0.1], top at PLATFORM_H (only reachable by the ladder).
const PLATFORM_CENTER: Vector3 = Vector3(0.0, PLATFORM_H * 0.5, -2.9)
const PLATFORM_SIZE: Vector3 = Vector3(6.0, PLATFORM_H, 6.0)
const FLOOR_START: Vector3 = Vector3(0.0, 0.0, -11.0)
const PLATFORM_GOAL: Vector3 = Vector3(0.0, PLATFORM_H, -2.0)

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## ATestMaps.basic() plus a raised platform and a navmesh baked over floor and platform top (two
## islands: the box walls are far above agent_max_climb).
static func _platform_map() -> PackedScene:
	var root: HeistMap = ATestMaps.basic(0, 0).instantiate() as HeistMap
	var geo: Node3D = root.get_node("Geometry")
	var b: StaticBody3D = StaticBody3D.new()
	b.name = "Platform"
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = PLATFORM_SIZE
	cs.shape = box
	b.add_child(cs)
	b.position = PLATFORM_CENTER
	geo.add_child(b)
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	root.add_child(nav)
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.3
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.filter_baking_aabb = AABB(Vector3(-15.0, -1.0, -15.0), Vector3(30.0, 6.0, 30.0))
	var holder: Node3D = Node3D.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(holder)
	holder.add_child(root)
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, geo)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	holder.remove_child(root)
	holder.free()
	nav.navigation_mesh = nm
	for c: Node in root.get_children():
		_own(c, root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


static func _own(n: Node, root: Node) -> void:
	n.owner = root
	for c: Node in n.get_children():
		_own(c, root)


func _launch() -> Ladder:
	_rt = await HeistLauncher.launch(&"unit_ladder_nav", 1414, Enums.Difficulty.ROUTINE, self,
		{"map_packed": _platform_map(), "skip_casing": true, "crew_ai": false})
	var l: Ladder = ATestMaps.add_prefab(_rt, "ladder", LADDER_POS) as Ladder
	await wait_physics_frames(2)
	assert_true(await ATestMaps.await_nav_synced(_rt), "navigation map synced to this map's navmesh")
	await _sync_links()
	return l


## Links register asynchronously too: wait a frame, then force a map update.
func _sync_links() -> void:
	await wait_physics_frames(2)
	NavigationServer3D.map_force_update(_rt.get_viewport().world_3d.navigation_map)


func _path(layers: int) -> PackedVector3Array:
	var nav_map: RID = _rt.get_viewport().world_3d.navigation_map
	return NavigationServer3D.map_get_path(nav_map, FLOOR_START, PLATFORM_GOAL, true, layers)


func _passes_near(path: PackedVector3Array, p: Vector3, r: float) -> bool:
	for q: Vector3 in path:
		if q.distance_to(p) <= r:
			return true
	return false


func test_ladder_nav_link_on_ladder_layer_at_grab_points() -> void:
	var l: Ladder = await _launch()
	var link: NavigationLink3D = l.get_node_or_null(Ladder.NAV_LINK_NAME) as NavigationLink3D
	assert_true(link != null, "Ladder builds a NavLink child")
	assert_eq(l.nav_link(), link)
	assert_eq(Ladder.NAV_LAYER, 8, "layer 4 (bit value 8)")
	assert_eq(link.navigation_layers, Ladder.NAV_LAYER, "ladder layer only")
	assert_eq(link.navigation_layers & 1, 0, "not on the default (walkable) layer 1")
	assert_true(link.bidirectional, "up and down")
	assert_true(link.enabled, "enabled while usable")
	assert_true(link.get_global_start_position().distance_to(l.bottom_position()) < 0.05,
		"start at the Bottom grab point (%s)" % link.get_global_start_position())
	assert_true(link.get_global_end_position().distance_to(l.top_position()) < 0.05,
		"end at the Top grab point (%s)" % link.get_global_end_position())
	assert_true(l.bottom_position().z < LADDER_POS.z, "Bottom is off the climb face on -Z")
	assert_near(l.bottom_position().y, 0.0, 0.05, "Bottom on the floor")
	assert_near(l.top_position().y, PLATFORM_H, 0.05, "Top on the landing")
	# Both ends lie within the default link connection radius of the navmesh they connect to.
	var nav_map: RID = _rt.get_viewport().world_3d.navigation_map
	var radius: float = NavigationServer3D.map_get_link_connection_radius(nav_map)
	var at_bottom: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, l.bottom_position())
	var at_top: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, l.top_position())
	assert_true(at_bottom.distance_to(l.bottom_position()) < radius, "floor navmesh within %.2f m" % radius)
	assert_true(at_top.distance_to(l.top_position()) < radius, "landing navmesh within %.2f m" % radius)
	assert_near(at_top.y, PLATFORM_H, 0.3, "Top snaps onto the landing, not the floor")
	l.usable = false
	assert_false(link.enabled, "unusable ladder: link disabled")


func test_layer_1_path_stops_at_the_foot_ladder_layer_reaches_platform() -> void:
	var l: Ladder = await _launch()
	var walk: PackedVector3Array = _path(1)
	assert_true(walk.size() >= 2, "layer-1 path exists on the floor")
	var end1: Vector3 = walk[walk.size() - 1]
	assert_true(end1.y < 0.5, "layer 1 never reaches the platform (ends at %s)" % end1)
	assert_true(absf(end1.x) < 3.6 and end1.z > -6.6 and end1.z < 0.8,
		"layer 1 ends on the floor beside the platform (%s)" % end1)
	var climb: PackedVector3Array = _path(1 | Ladder.NAV_LAYER)
	assert_true(climb.size() >= 2, "climber path exists")
	var end2: Vector3 = climb[climb.size() - 1]
	assert_true(end2.distance_to(PLATFORM_GOAL) < 0.3, "1 | NAV_LAYER reaches the platform (ends at %s)" % end2)
	assert_true(_passes_near(climb, l.bottom_position(), 0.5), "via the Bottom grab point")
	assert_true(_passes_near(climb, l.top_position(), 0.5), "via the Top grab point")
	l.usable = false
	await _sync_links()
	var off: PackedVector3Array = _path(1 | Ladder.NAV_LAYER)
	assert_true(off[off.size() - 1].y < 0.5, "a disabled ladder link is not routed")


func test_npc_agents_stay_on_layer_1() -> void:
	await _launch()
	var npc: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(4, 0.05, -10)), {})
	await wait_physics_frames(2)
	var agent: NavigationAgent3D = npc.get_node_or_null("NavAgent") as NavigationAgent3D
	assert_true(agent != null, "guard has a NavAgent")
	assert_eq(agent.navigation_layers & Ladder.NAV_LAYER, 0, "NPC agents never use ladder links")
	assert_true((agent.navigation_layers & 1) != 0, "NPC agents walk layer 1")
