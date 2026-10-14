## validate_level `slopes` (next_heist §7.5: no walkable slope < 50° outside the play mesh) and
## `viewmodel_lit` (D-095: interior key lights carry render layer 21; FAIL since PO-8).
extends LcTestBase


## A StaticBody3D wedge (collision only): footprint x0..x1, z0..z1; the top rises from `h0` at z0 to
## `h1` at z1 (h0 == h1 makes a flat block).
func _wedge(m: HeistMap, nm: String, x0: float, x1: float, z0: float, z1: float, h0: float, h1: float) -> void:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = nm
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1),
		Vector3(x0, h0, z0), Vector3(x1, h0, z0), Vector3(x0, h1, z1), Vector3(x1, h1, z1)])
	cs.shape = shape
	sb.add_child(cs)
	m.get_node("Geometry").add_child(sb)
	sb.owner = m
	cs.owner = m


## Room A shrinks to x >= 3.6, so its west strip (x 0.4..3.6) is navmesh but not play space.
func _shrink_room_a(m: HeistMap) -> void:
	var r: RoomVolume = m.get_node("Rooms/RoomA")
	r.position.x = (3.6 + 7.9) * 0.5
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(7.9 - 3.6, 2.8, 7.2)
	(r.get_node("Shape") as CollisionShape3D).shape = box


## Runs one check on GOOD after `mutate`; returns the check (issues of every severity).
func _one(check: String, mutate: Callable, heist_id: String = "") -> LcCheck:
	var map: HeistMap = (load(GOOD) as PackedScene).instantiate() as HeistMap
	mutate.call(map)
	var ctx: LcContext = await LcRunner.prepare(map, self)
	ctx.heist_id = heist_id
	var checks: Array[LcCheck] = await LcRunner.run(ctx, PackedStringArray([check]))
	remove_child(map)
	map.free()
	await wait_physics_frames(2)
	return checks[0]


func test_good_fixture_passes() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", Callable(), false, ["slopes"])
	_expect_only(res, [])


func test_flat_ledge_outside_play_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_shrink_room_a(m)
		_wedge(m, "Ledge", 1.0, 2.0, 2.0, 3.0, 0.8, 0.8), false, ["slopes"])
	_expect_fail(res, "slopes", "Geometry/Ledge")
	_expect_fail(res, "slopes", "outside the play mesh")


func test_shallow_slope_fails_steep_slope_passes() -> void:
	# 40° rises 0.84 m over 1 m: walkable and in reach. 55° is too steep to stand on.
	var low: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_shrink_room_a(m)
		_wedge(m, "Ramp40", 1.0, 2.0, 2.0, 3.0, 0.0, tan(deg_to_rad(40.0))), false, ["slopes"])
	_expect_fail(low, "slopes", "Ramp40")
	var steep: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_shrink_room_a(m)
		_wedge(m, "Ramp55", 1.0, 2.0, 2.0, 3.0, 0.0, tan(deg_to_rad(55.0))), false, ["slopes"])
	_expect_only(steep, [])


func test_ledge_out_of_jump_reach_passes() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_shrink_room_a(m)
		_wedge(m, "HighLedge", 1.0, 2.0, 2.0, 3.0, 1.3, 1.3), false, ["slopes"])
	_expect_only(res, [])


func test_ledge_inside_room_is_play_space() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_wedge(m, "Ledge", 1.0, 2.0, 2.0, 3.0, 0.8, 0.8), false, ["slopes"])
	_expect_only(res, [])


func test_legacy_heist_warns_only() -> void:
	var c: LcCheck = await _one("slopes", func(m: HeistMap) -> void:
		_shrink_room_a(m)
		_wedge(m, "Ledge", 1.0, 2.0, 2.0, 3.0, 0.8, 0.8), "glasshouse")
	assert_true(c.passed(), "legacy heists only warn")
	assert_true(c.warn_count() >= 1, "ledge reported as WARN")


# --- viewmodel_lit -------------------------------------------------------------------------

func test_viewmodel_lit_fails_on_untagged_key_lights() -> void:
	var c: LcCheck = await _one("viewmodel_lit", func(m: HeistMap) -> void:
		for p: String in ["Props/LampA/Light", "Props/LampB/Light"]:
			(m.get_node(p) as Light3D).layers &= ~CrewView.VIEWMODEL_LIT_LAYER)
	assert_false(c.passed(), "PO-8: a key light without layer 21 fails")
	assert_eq(c.fail_count(), 2, "LampA + LampB lack layer 21: %s" % [c.issues])
	assert_true(LcCheck.issue_line(c.sorted_issues()[0]).contains("viewmodel_lit"))


func test_viewmodel_lit_tagged_lights_pass() -> void:
	var c: LcCheck = await _one("viewmodel_lit", func(_m: HeistMap) -> void: pass)
	assert_true(c.passed(), "%s" % [c.issues])
	assert_eq(c.issues.size(), 0, "the fixture lamps carry layer 21: %s" % [c.issues])


func test_viewmodel_lit_ignores_fill_and_dim_lights() -> void:
	var c: LcCheck = await _one("viewmodel_lit", func(m: HeistMap) -> void:
		var fill: OmniLight3D = OmniLight3D.new()
		fill.name = "FillA"
		fill.light_energy = 2.0
		fill.set_meta(&"fill", true)
		fill.position = Vector3(3.0, 2.2, 3.0)
		m.get_node("Lighting").add_child(fill)
		var dim: OmniLight3D = OmniLight3D.new()
		dim.name = "DimA"
		dim.light_energy = 0.2
		dim.position = Vector3(2.0, 2.2, 3.0)
		m.get_node("Lighting").add_child(dim))
	assert_eq(c.issues.size(), 0, "untagged fill and dim non-key lights are not key lights: %s" % [c.issues])


## PO-8: the source of the dressing lights. Every prop scene in the library that carries a light
## (tools/blender/props/_scenes.py) has layer 21 on it, so every map dressed from it inherits it.
func test_every_library_prop_light_carries_viewmodel_lit() -> void:
	var cat: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://world/props/prop_catalog.json"))
	assert_true(cat is Dictionary, "prop_catalog.json parses")
	var n: int = 0
	for aid: String in (cat as Dictionary).keys():
		var e: Variant = cat[aid]
		if not (e is Dictionary and bool((e as Dictionary).get("has_light", false))):
			continue
		var inst: Node = (load(String(e["scene"])) as PackedScene).instantiate()
		for l: Node in inst.find_children("*", "Light3D", true, false):
			n += 1
			assert_true(((l as Light3D).layers & CrewView.VIEWMODEL_LIT_LAYER) != 0,
				"%s/%s lacks layer 21 `viewmodel_lit`" % [aid, inst.get_path_to(l)])
		inst.free()
	assert_true(n >= 20, "library prop lights found: %d" % n)
