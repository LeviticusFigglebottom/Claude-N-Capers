## Tests for validate_level (C1-04): fixtures + mutation tests.
## Fixtures: res://tests/c/fixtures/lc_fixture_{good,bad}.tscn (make_lc_fixtures.gd).
extends LcTestBase


func test_good_fixture_passes_final_all_variants() -> void:
	var res: Dictionary = await _validate(GOOD, "final", Callable(), true)
	assert_eq(res.size(), 18, "all 18 checks ran at final")
	_expect_only(res, [])


func test_good_fixture_passes_greybox_and_skips_final_checks() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox")
	_expect_only(res, [])
	for c: String in ["orientation", "materials", "zfight", "lights", "density", "variety", "bounds", "perf"]:
		assert_false(res.has(c), "%s must not run at greybox" % c)
	assert_true(res.has("floating") and res.has("reachability") and res.has("contract_nodes"))


func test_bad_fixture_fails_exactly_expected() -> void:
	var res: Dictionary = await _validate(BAD, "final", Callable(), true)
	_expect_only(res, BAD_EXPECT.keys())
	for check: String in BAD_EXPECT.keys():
		for needle: String in BAD_EXPECT[check]:
			_expect_fail(res, check, needle)


func test_mutation_rotated_chair_fails_orientation() -> void:
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		(m.get_node("Props/ChairA") as Node3D).rotation_degrees.y = 90.0, false, ["orientation"])
	_expect_fail(res, "orientation", "ChairA")


func test_mutation_tall_desk_fails_scale() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var d: Node3D = m.get_node("Props/DeskB")
		d.scale = Vector3(1.0, 1.3, 1.0), false, ["scale"])
	_expect_fail(res, "scale", "DeskB")


func test_mutation_missing_ceiling_fails_bounds_and_scale() -> void:
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		var c: Node = m.get_node("Geometry/Ceiling")
		c.get_parent().remove_child(c)
		c.free(), false, ["scale", "bounds"])
	_expect_fail(res, "bounds", "void")
	_expect_fail(res, "scale", "open to the sky")


func test_mutation_missing_required_item_fails_density() -> void:
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		var c: Node = m.get_node("Props/ChairB")
		c.get_parent().remove_child(c)
		c.free(), false, ["density"])
	_expect_fail(res, "density", "requires a `chair`")


func test_mutation_off_wall_picture_fails_floating() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		(m.get_node("Props/PictureA") as Node3D).position.x += 0.05, false, ["floating"])
	_expect_fail(res, "floating", "PictureA")


func test_mutation_prop_in_door_swing_fails_clipping() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var b: Node3D = LcFixtureBuilder.prop(m.get_node("Props"), "ArcBox", Vector3(8.5, 0, 4.0), 0.0, "box",
			Vector3(0.3, 0.3, 0.3), Vector3(0, 0.15, 0), null, false)
		b.owner = m, false, ["clipping"])
	_expect_fail(res, "clipping", "ArcBox")
	_expect_fail(res, "clipping", "swing arc")


func test_mutation_patrol_point_in_desk_fails_navmesh() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		(m.get_node("Patrols/Main/P4") as Node3D).position = Vector3(5.0, 0, 2.0), false, ["navmesh"])
	_expect_fail(res, "navmesh", "P4")


func test_mutation_identical_layouts_fail_variety() -> void:
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		# Move room B's dressing to mirror room A exactly (same room-local positions/yaws).
		for pair: Array in [["DeskB", "DeskA"], ["ChairB", "ChairA"], ["MonitorB", "MonitorA"], ["BoxB", "BoxA"],
				["LampB", "LampA"], ["CameraB", "CameraA"], ["PictureB", "PictureA"]]:
			var a: Node3D = m.get_node("Props/" + String(pair[1]))
			var b: Node3D = m.get_node("Props/" + String(pair[0]))
			b.transform = Transform3D(a.transform.basis, a.transform.origin + Vector3(7.7, 0, 0)), false, ["variety"])
	_expect_fail(res, "variety", "same layout")


func test_mutation_fill_light_rules() -> void:
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "LoudFill"
		l.position = Vector3(3.0, 2.0, 5.0)
		l.light_energy = 1.0
		l.shadow_enabled = true
		l.set_meta(&"fill", true)
		m.get_node("Lighting").add_child(l)
		l.owner = m, false, ["lights"])
	_expect_fail(res, "lights", "fill light energy")
	_expect_fail(res, "lights", "fill light casts shadows")


func test_mutation_contract_nodes() -> void:
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		m.review_cameras = m.review_cameras.slice(0, 3)
		m.heist_def = null, false, ["contract_nodes"])
	_expect_fail(res, "contract_nodes", "review cameras")
	_expect_fail(res, "contract_nodes", "heist_def")


func test_mutation_second_guard_needs_three_loops() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var g: SpawnPoint = LcFixtureBuilder.spawn(m.get_node("Spawns"), "Guard2", SpawnPoint.Kind.GUARD, Vector3(13.5, 0, 2.0))
		g.patrol_graph = NodePath("../../Patrols/Main")
		g.owner = m, false, ["patrols"])
	_expect_fail(res, "patrols", "loop option")


func test_mutation_coplanar_rug_fails_zfight() -> void:
	var res: Dictionary = await _validate(GOOD, "final", func(m: HeistMap) -> void:
		var rug: MeshInstance3D = MeshInstance3D.new()
		rug.name = "FlatRug"
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(1.0, 1.0)
		pm.material = LcFixtureBuilder.tri_mat("rug", Color.DARK_RED, 512.0)
		rug.mesh = pm
		rug.position = Vector3(3.0, 0.0, 5.0)
		m.get_node("Props").add_child(rug)
		rug.owner = m, false, ["zfight"])
	_expect_fail(res, "zfight", "FlatRug")
