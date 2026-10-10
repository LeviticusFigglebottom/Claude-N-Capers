## ENV A dev sandbox map (systems/dev/dev_sandbox.tscn): structure, spawns, variants, navmesh.
extends TestCase

const SECTIONS: Array[String] = [
	"Geometry", "Props", "Lighting", "Navigation", "Zones", "Rooms", "Spawns", "Patrols",
	"Tactical", "Gameplay", "Variants", "Mission", "ReviewCameras",
]


func _launch(seed_value: int, difficulty: Enums.Difficulty = Enums.Difficulty.ROUTINE) -> HeistRuntime:
	return await HeistLauncher.launch(&"dev_sandbox", seed_value, difficulty, self)


func _nav_map(rt: HeistRuntime) -> RID:
	return rt.map.get_world_3d().navigation_map


## Wait until the navigation map has synced the region (async iterations), then force an update.
func _sync_nav(rt: HeistRuntime) -> RID:
	var nav_map: RID = _nav_map(rt)
	for i: int in range(30):
		await wait_physics_frames(1)
		NavigationServer3D.map_force_update(nav_map)
		if NavigationServer3D.map_get_closest_point(nav_map, Vector3(0.0, 0.0, 8.0)) != Vector3.ZERO:
			break
	return nav_map


func test_structure_and_spawns() -> void:
	var rt: HeistRuntime = await _launch(1001)
	assert_true(rt != null, "dev_sandbox launches")
	if rt == null:
		return
	for nm: String in SECTIONS:
		assert_true(rt.map.get_node_or_null(nm) != null, "map has %s" % nm)
	assert_true(rt.map.get_node("Navigation") is NavigationRegion3D, "Navigation is a NavigationRegion3D")
	assert_true(rt.mission != null, "Mission extends HeistMission")
	assert_true(rt.map.heist_def != null and rt.map.heist_def.id == &"dev_sandbox", "heist_def set")
	assert_true(rt.map.variant_table != null, "variant_table set")
	assert_eq(rt.map.review_cameras.size(), 2, "two review cameras")
	for p: NodePath in rt.map.review_cameras:
		assert_true(rt.map.get_node_or_null(p) is Marker3D, "review camera %s resolves" % p)
	assert_true(rt.npcs(&"guard").size() >= 3, "at least 3 guards (got %d)" % rt.npcs(&"guard").size())
	assert_eq(rt.npcs(&"civilian").size(), 2, "two civilians")
	assert_eq(rt.crew_members().size(), 4, "four crew")
	var kinds: Dictionary = {}
	for z: Node in rt.map.get_node("Zones").get_children():
		var mz: MapZone = z as MapZone
		if mz != null:
			kinds[mz.kind] = true
			assert_true(mz.get_child_count() > 0 and mz.get_child(0) is CollisionShape3D, "%s has a shape" % mz.name)
	for k: MapZone.Kind in [MapZone.Kind.PUBLIC, MapZone.Kind.RESTRICTED, MapZone.Kind.SECURE_LOOT,
			MapZone.Kind.ESCAPE, MapZone.Kind.BODY_HIDE]:
		assert_true(kinds.has(k), "zone kind %s present" % MapZone.Kind.keys()[k])
	assert_true(rt.map.get_slots(G.POLICE_SPAWN).size() >= 3, "3+ police spawns")
	assert_eq(rt.map.get_slots(G.SECURITY_ROOM).size(), 1, "camera operator spawn")
	var objectives: Array[Dictionary] = rt.mission.objectives()
	assert_eq(objectives.size(), 2, "get_loot + escape objectives")
	rt.teardown()
	await wait_frames(1)


func test_variants_deterministic() -> void:
	var rt: HeistRuntime = await _launch(1001)
	var v1: Dictionary = rt.variants.duplicate(true)
	rt.teardown()
	await wait_frames(1)
	rt = await _launch(1001)
	assert_eq(rt.variants, v1, "same seed, same variants")
	rt.teardown()
	await wait_frames(1)
	assert_eq((v1[&"keycard"] as Array).size(), 1, "one keycard slot")
	assert_true((v1[&"guard_extra"] as Array).size() <= 1, "0..1 extra guards on ROUTINE")
	assert_true(v1.has(&"escape_delay"), "escape_delay scalar rolled")
	assert_true(v1.has("rare"), "rare list present")
	var differs: bool = false
	for s: int in [1002, 1003, 1004, 1005, 1006, 1007]:
		rt = await _launch(s)
		if rt.variants != v1:
			differs = true
		rt.teardown()
		await wait_frames(1)
		if differs:
			break
	assert_true(differs, "some other seed rolls different variants")


func test_extra_guards_on_high_difficulty() -> void:
	var rt: HeistRuntime = await _launch(1001, Enums.Difficulty.BRUTAL)
	var extra: Array = rt.variants[&"guard_extra"]
	assert_true(extra.size() >= 1, "difficulty_add adds an extra guard on BRUTAL")
	assert_eq(rt.npcs(&"guard").size(), 3 + extra.size(), "guards = 3 + extra slots")
	rt.teardown()
	await wait_frames(1)


func test_navmesh_and_markers() -> void:
	var rt: HeistRuntime = await _launch(1001)
	var region: NavigationRegion3D = rt.map.get_node("Navigation") as NavigationRegion3D
	assert_true(region.navigation_mesh != null and region.navigation_mesh.get_polygon_count() > 0, "navmesh baked")
	var nav_map: RID = await _sync_nav(rt)
	var start: Vector3 = (rt.map.get_slots(G.PLAYER_SPAWN)[0] as Node3D).global_position
	# Through the 0.9 m front doorway to the back of the main room.
	var target: Vector3 = Vector3(-4.0, 0.0, -10.0)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, start, target, true)
	assert_true(path.size() > 0, "path from player spawn into the building")
	if path.size() > 0:
		var end: Vector3 = path[path.size() - 1]
		assert_true(Vector2(end.x, end.z).distance_to(Vector2(target.x, target.z)) < 0.5,
			"path ends inside the building (%s)" % end)
	for sp_node: Node in rt.map.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = sp_node as SpawnPoint
		if sp.kind == SpawnPoint.Kind.SNIPER_PERCH:
			continue
		var c: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, sp.global_position)
		assert_true(c.distance_to(sp.global_position) <= 0.25, "spawn %s on navmesh (%.2f m)" % [sp.name, c.distance_to(sp.global_position)])
	var points: int = 0
	for pp_node: Node in rt.map.find_children("*", "PatrolPoint", true, false):
		var pp: PatrolPoint = pp_node as PatrolPoint
		points += 1
		var c2: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, pp.global_position)
		assert_true(c2.distance_to(pp.global_position) <= 0.25, "patrol %s on navmesh (%.2f m)" % [pp.name, c2.distance_to(pp.global_position)])
		assert_true(pp.links.size() > 0, "patrol %s has links" % pp.name)
		for l: NodePath in pp.links:
			var o: PatrolPoint = pp.get_node_or_null(l) as PatrolPoint
			assert_true(o != null, "link %s of %s resolves to a PatrolPoint" % [l, pp.name])
			if o != null:
				var back: bool = false
				for l2: NodePath in o.links:
					if o.get_node_or_null(l2) == pp:
						back = true
				assert_true(back, "link %s <-> %s is bidirectional" % [pp.name, o.name])
	assert_true(points >= 8, "8+ patrol points")
	var gameplay: Node = rt.map.get_node("Gameplay")
	assert_true(gameplay.get_child_count() >= 17, "gameplay prefabs placed (%d)" % gameplay.get_child_count())
	var placed: Array[Node] = gameplay.get_children()
	for vs: VariantSlot in rt.map.get_variant_slots(&"keycard"):
		placed.append_array(vs.get_children())
	for g: Node in placed:
		var up: Node3D = g.get_node_or_null(^"UsePoint") as Node3D
		if up == null:
			continue
		# Projected to the floor: the phone's UsePoint sits at desk height (prefab offset).
		var floor_pos: Vector3 = Vector3(up.global_position.x, 0.0, up.global_position.z)
		var c3: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, floor_pos)
		var d3: float = Vector2(c3.x, c3.z).distance_to(Vector2(up.global_position.x, up.global_position.z))
		assert_true(d3 <= 0.25, "%s UsePoint on navmesh (%.2f m)" % [g.name, d3])
	rt.teardown()
	await wait_frames(1)
