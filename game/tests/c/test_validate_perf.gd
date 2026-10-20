## validate_level `perf` (architecture §10, D-146): shadow passes count toward the draws per view. A small fixture
## built here: one-surface boxes as casters, one shadowed light at a time, a camera looking at them.
extends TestCase

const CAM_FOV: Dictionary = {"fov": 75.0, "ortho": 0.0}
var _root: Node3D = null


func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)


func after_each() -> void:
	_root.free()
	_root = null


func _box(pos: Vector3, size: Vector3, cast: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	if not cast:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	return mi


func _pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Node in _root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		out.append(LcCheckPerf.piece_of(mi, mi.global_transform * mi.mesh.get_aabb(), mi.mesh.get_surface_count(), 12))
	return out


func _view(light: Light3D, eye: Vector3, at: Vector3, cp: Dictionary = CAM_FOV) -> Dictionary:
	var pieces: Array[Dictionary] = _pieces()
	var lights: Array[Dictionary] = [LcCheckPerf.prepare_light(light, pieces)]
	var xf: Transform3D = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)
	return LcCheckPerf.count_view(pieces, lights, xf, cp)


func test_omni_cube_counts_each_face() -> void:
	# N casters each enclosing the light: every one of the 6 cube faces draws all N
	var n: int = 5
	for i: int in range(n):
		_box(Vector3(0.0, 2.0, 0.0), Vector3.ONE * (1.0 + i * 0.2))
	var om: OmniLight3D = OmniLight3D.new()
	om.omni_range = 6.0
	om.shadow_enabled = true
	om.position = Vector3(0.0, 2.0, 0.0)
	_root.add_child(om)
	var r: Dictionary = _view(om, Vector3(0.0, 2.0, 10.0), Vector3(0.0, 2.0, 0.0))
	assert_eq(r["main"], n)
	assert_eq(r["shadow"], 6 * n, "omni cube: 6 faces x N casters")
	assert_eq(r["shadow_lights"], 1)
	# one more caster straight below the light lands in the -Y face only; one with cast_shadow off in none
	_box(Vector3(0.0, 0.25, 0.0), Vector3(0.4, 0.4, 0.4))
	_box(Vector3(0.0, 0.25, 0.8), Vector3(0.4, 0.4, 0.4), false)
	assert_eq(_view(om, Vector3(0.0, 2.0, 10.0), Vector3(0.0, 2.0, 0.0))["shadow"], 6 * n + 1)
	om.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	# dual paraboloid: 2 hemispheres split at the light's z = 0, which the box below straddles too
	assert_eq(_view(om, Vector3(0.0, 2.0, 10.0), Vector3(0.0, 2.0, 0.0))["shadow"], 2 * n + 2)


func test_spot_counts_casters_in_cone() -> void:
	var n: int = 4
	for i: int in range(n):
		_box(Vector3(-0.6 + i * 0.4, 0.2, 0.0), Vector3(0.3, 0.3, 0.3))
	_box(Vector3(0.0, 3.5, 0.0), Vector3(0.3, 0.3, 0.3))  # above the spot: behind it
	_box(Vector3(5.0, 0.2, 0.0), Vector3(0.3, 0.3, 0.3))  # outside the cone
	var sp: SpotLight3D = SpotLight3D.new()
	sp.spot_range = 4.0
	sp.spot_angle = 40.0
	sp.shadow_enabled = true
	sp.position = Vector3(0.0, 3.0, 0.0)
	sp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # pointing down
	_root.add_child(sp)
	var eye: Vector3 = Vector3(0.0, 1.7, 8.0)
	var r: Dictionary = _view(sp, eye, Vector3(0.0, 1.0, 0.0))
	assert_eq(r["shadow"], n, "spot: one pass over the casters in its cone")
	# distance fade: beyond fade_shadow + length the shadow no longer renders
	sp.distance_fade_enabled = true
	sp.distance_fade_begin = 40.0
	sp.distance_fade_shadow = 3.0
	sp.distance_fade_length = 2.0
	var r2: Dictionary = _view(sp, eye, Vector3(0.0, 1.0, 0.0))
	assert_eq(r2["shadow"], 0)
	assert_eq(r2["shadow_lights"], 0)


func test_sun_counts_casters_per_cascade() -> void:
	# narrow camera looking -z; the sun straight down; 2 splits at 50 % of 100 m: [0, 50] and [50, 100] m
	var near: int = 3
	var far: int = 2
	for i: int in range(near):
		_box(Vector3(i * 0.5, 0.5, -10.0), Vector3.ONE * 0.4)
	for i: int in range(far):
		_box(Vector3(i * 0.5, 0.5, -80.0), Vector3.ONE * 0.4)
	_box(Vector3(0.0, 40.0, -10.0), Vector3.ONE * 0.4)  # high toward the light, out of view: still casts in
	_box(Vector3(200.0, 0.5, -10.0), Vector3.ONE * 0.4)  # far off to the side: in no cascade
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.5
	sun.directional_shadow_max_distance = 100.0
	sun.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_root.add_child(sun)
	var narrow: Dictionary = {"fov": 10.0, "ortho": 0.0}
	var r: Dictionary = _view(sun, Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -1.0), narrow)
	assert_eq(r["shadow"], (near + 1) + far, "2 splits: the near casters (+ the one above) and the far ones")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	assert_eq(_view(sun, Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -1.0), narrow)["shadow"], near + 1 + far)
	sun.directional_shadow_max_distance = 40.0
	assert_eq(_view(sun, Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -1.0), narrow)["shadow"], near + 1,
		"a shorter max distance drops the far casters")


func test_visibility_range_hides_from_main_not_positional_shadow() -> void:
	# Godot culls positional shadow casters by node visibility only, never by visibility range (the sun's cascades
	# do apply it)
	var b: MeshInstance3D = _box(Vector3(0.0, 0.2, 0.0), Vector3(0.3, 0.3, 0.3))
	b.visibility_range_end = 5.0
	var sp: SpotLight3D = SpotLight3D.new()
	sp.spot_range = 4.0
	sp.shadow_enabled = true
	sp.position = Vector3(0.0, 3.0, 0.0)
	sp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_root.add_child(sp)
	var r: Dictionary = _view(sp, Vector3(0.0, 1.7, 8.0), Vector3(0.0, 1.0, 0.0))
	assert_eq(r["main"], 0)
	assert_eq(r["shadow"], 1)
	assert_eq(r["shadow_lights"], 1)


func test_out_of_view_casters_culled_tightly() -> void:
	# an omni beside the view: casters on the far side of the light from the camera frustum cannot shadow it
	_box(Vector3(0.0, 1.0, 0.0), Vector3(0.4, 0.4, 0.4))  # in view
	_box(Vector3(8.0, 1.0, 0.0), Vector3(0.4, 0.4, 0.4))  # beyond the light, away from the view
	var om: OmniLight3D = OmniLight3D.new()
	om.omni_range = 10.0
	om.shadow_enabled = true
	om.position = Vector3(5.0, 1.0, 0.0)
	_root.add_child(om)
	var narrow: Dictionary = {"fov": 20.0, "ortho": 0.0}
	var r: Dictionary = _view(om, Vector3(0.0, 1.0, 6.0), Vector3(0.0, 1.0, 0.0), narrow)
	assert_eq(r["main"], 1)
	assert_eq(r["shadow"], 1, "only the in-view caster's -X face draw")


func test_compatibility_light_passes() -> void:
	# two shadowed positional lights over N casters: each caster draws 2 colour passes (lit = N); a sun adds one more
	var n: int = 3
	for i: int in range(n):
		_box(Vector3(-0.5 + i * 0.5, 0.2, 0.0), Vector3(0.3, 0.3, 0.3))
	var pieces: Array[Dictionary] = _pieces()
	var lights: Array[Dictionary] = []
	for x: float in [-0.5, 0.5]:
		var om: OmniLight3D = OmniLight3D.new()
		om.omni_range = 3.0
		om.shadow_enabled = true
		om.position = Vector3(x, 2.0, 0.0)
		_root.add_child(om)
		lights.append(LcCheckPerf.prepare_light(om, pieces))
	var eye: Vector3 = Vector3(0.0, 1.7, 8.0)
	var xf: Transform3D = Transform3D(Basis.looking_at(Vector3(0.0, 0.5, 0.0) - eye, Vector3.UP), eye)
	assert_eq(LcCheckPerf.count_view(pieces, lights, xf, CAM_FOV)["lit"], n)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	_root.add_child(sun)
	lights.append(LcCheckPerf.prepare_light(sun, pieces))
	assert_eq(LcCheckPerf.count_view(pieces, lights, xf, CAM_FOV)["lit"], 2 * n)


## The GOOD fixture with 2,640 extra surfaces in the middle of room A (the top-down plan sees them all).
func _heavy(m: HeistMap) -> void:
	var am: ArrayMesh = ArrayMesh.new()
	for i: int in range(240):
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0.1, 0, 0), Vector3(0, 0.1, 0)])
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	for k: int in range(11):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Heavy%d" % k
		mi.mesh = am
		mi.position = Vector3(4.0, 1.0, 3.5)
		m.get_node("Geometry").add_child(mi)
		mi.owner = m


func _perf_for(heist_id: String) -> LcCheck:
	var map: HeistMap = (load(LcTestBase.GOOD) as PackedScene).instantiate() as HeistMap
	_heavy(map)
	var ctx: LcContext = await LcRunner.prepare(map, self)
	ctx.heist_id = heist_id
	ctx.stage = "final"
	var checks: Array[LcCheck] = await LcRunner.run(ctx, PackedStringArray(["perf"]))
	remove_child(map)
	map.free()
	await wait_physics_frames(2)
	return checks[0]


func test_budgets_enforced_only_for_opted_in_heists() -> void:
	var on: LcCheck = await _perf_for("ostrander_federal")
	assert_true(on.fail_count() > 0, "OF: main > 2500 fails")
	var off: LcCheck = await _perf_for("shadow_ledger")
	assert_eq(off.fail_count(), 0, "a shipped heist is report-only")
	assert_true(off.warn_count() > 0, "...but the overrun is reported")
