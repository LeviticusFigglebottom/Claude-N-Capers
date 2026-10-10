## Tests for validate_level (C1-04): fixtures + mutation tests + geometry helpers.
## Fixtures: res://tests/c/fixtures/lc_fixture_{good,bad}.tscn (make_lc_fixtures.gd).
extends TestCase

const GOOD: String = "res://tests/c/fixtures/lc_fixture_good.tscn"
const BAD: String = "res://tests/c/fixtures/lc_fixture_bad.tscn"
const KITS: String = "res://tests/c/fixtures/kits"
## Bad fixture: check -> node names that must appear in that check's failures.
const BAD_EXPECT: Dictionary = {
	"floating": ["FloatBox"],
	"clipping": ["WallClipBox"],
	"lights": ["BareLight"],
	"materials": ["NullMatMesh"],
	"reachability": ["PlayerSpawn5"],
	"walkthrough": ["PlayerSpawn5"],
	"patrols": ["LonelyPoint"],
	# WallClipBox's base is coplanar with the wall it penetrates: a true z-fight.
	"zfight": ["WallClipBox"],
}


## Loads a fixture, lets `mutate` edit it before it enters the tree, runs the checks.
func _validate(path: String, stage: String, mutate: Callable = Callable(), variants_all: bool = false,
		only: PackedStringArray = PackedStringArray()) -> Dictionary:
	var map: HeistMap = (load(path) as PackedScene).instantiate() as HeistMap
	if mutate.is_valid():
		mutate.call(map)
	var ctx: LcContext = await LcRunner.prepare(map, self)
	ctx.stage = stage
	ctx.variants_all = variants_all
	ctx.kit_dirs.append(KITS)
	var checks: Array[LcCheck] = await LcRunner.run(ctx, only)
	var out: Dictionary = {}
	for c: LcCheck in checks:
		if c.skipped_reason == "":
			var lines: PackedStringArray = PackedStringArray()
			for i: Dictionary in c.sorted_issues():
				if i["severity"] == LcCheck.SEV_FAIL:
					lines.append(LcCheck.issue_line(i))
			out[String(c.id)] = lines
	remove_child(map)
	map.free()
	await wait_physics_frames(2)
	return out


static func _failed(res: Dictionary) -> PackedStringArray:
	var f: PackedStringArray = PackedStringArray()
	for k: String in res.keys():
		if not (res[k] as PackedStringArray).is_empty():
			f.append(k)
	f.sort()
	return f


func _expect_fail(res: Dictionary, check: String, needle: String) -> void:
	var lines: PackedStringArray = res.get(check, PackedStringArray())
	for l: String in lines:
		if l.contains(needle):
			return
	fail("expected %s to fail mentioning `%s`; got %s" % [check, needle, lines])


func _expect_only(res: Dictionary, checks: Array) -> void:
	var want: PackedStringArray = PackedStringArray(checks)
	want.sort()
	assert_eq(_failed(res), want, "failed checks; details: %s" % [res])


func test_good_fixture_passes_final_all_variants() -> void:
	var res: Dictionary = await _validate(GOOD, "final", Callable(), true)
	assert_eq(res.size(), 16, "all 16 checks ran at final")
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


func test_obb_overlap() -> void:
	var a: Dictionary = LcGeom.obb(Transform3D.IDENTITY, AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE))
	var b: Dictionary = LcGeom.obb(Transform3D(Basis(), Vector3(0.9, 0, 0)), AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE))
	assert_near(LcGeom.obb_overlap(a, b), 0.1, 1e-4)
	var c: Dictionary = LcGeom.obb(Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(1.3, 0, 0)),
		AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE))
	assert_true(LcGeom.obb_overlap(a, c) < 0.0, "rotated box 1.3 m away is separated")


func test_cycle_count() -> void:
	# K4: 7 simple cycles in total; through node 0 there are 3 triangles + 3 quads = 6.
	var adj: Dictionary = {0: [1, 2, 3], 1: [0, 2, 3], 2: [0, 1, 3], 3: [0, 1, 2]}
	assert_eq(LcGeom.count_cycles_through(adj, 0, 100), 6)
	assert_eq(LcGeom.count_cycles_through(adj, 0, 3), 3)
	var ring: Dictionary = {0: [1, 3], 1: [0, 2], 2: [1, 3], 3: [2, 0]}
	assert_eq(LcGeom.count_cycles_through(ring, 0, 3), 1)
	var line: Dictionary = {0: [1], 1: [0, 2], 2: [1]}
	assert_eq(LcGeom.count_cycles_through(line, 0, 3), 0)


func test_tri_overlap_area() -> void:
	var t1: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)])
	var t2: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 0)])
	assert_near(LcGeom.tri_overlap_area_2d(t1, t2), 0.5, 1e-5)
	var t3: PackedVector2Array = PackedVector2Array([Vector2(2, 2), Vector2(3, 2), Vector2(2, 3)])
	assert_near(LcGeom.tri_overlap_area_2d(t1, t3), 0.0, 1e-6)


func test_walkthrough_whitelist() -> void:
	var sp: Node3D = Node3D.new()
	sp.name = "PlayerSpawn1"
	var t: Node3D = Node3D.new()
	t.name = "Vault"
	var lines: PackedStringArray = PackedStringArray(["# comment", "PlayerSpawn1 Gameplay/Vault  # ok"])
	assert_true(LcCheckWalkthrough.whitelisted(lines, sp, "Spawns/PlayerSpawn1", t, "Gameplay/Vault"))
	assert_false(LcCheckWalkthrough.whitelisted(lines, sp, "Spawns/PlayerSpawn1", t, "Gameplay/Other"))
	assert_true(LcCheckWalkthrough.whitelisted(PackedStringArray(["* Vault"]), sp, "x", t, "y/Vault"))
	sp.free()
	t.free()


func test_frustum() -> void:
	var planes: Array[Plane] = LcGeom.frustum_planes(Transform3D.IDENTITY, 60.0, 16.0 / 9.0, 0.05, 100.0)
	assert_true(LcGeom.aabb_in_frustum(AABB(Vector3(-0.5, -0.5, -10.5), Vector3.ONE), planes), "in front")
	assert_false(LcGeom.aabb_in_frustum(AABB(Vector3(-0.5, -0.5, 9.5), Vector3.ONE), planes), "behind")
	assert_false(LcGeom.aabb_in_frustum(AABB(Vector3(50, -0.5, -10.5), Vector3.ONE), planes), "far right")
