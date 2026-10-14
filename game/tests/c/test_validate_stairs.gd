## validate_level stair and door-scale tests: U-stairs and imperial stairs (flight chaining across a
## landing), ramp collision, riser errors, vault doors.
extends LcTestBase


func _add_u_stair(m: HeistMap, ramp: bool, top: float, rail_h: float = 1.05, rail_gap: float = 0.0) -> void:
	LcFixtureBuilder.u_stair(m.get_node("Geometry"), Vector3(30.0, 0.0, 0.0), ramp, rail_h, rail_gap)
	m.floor_heights = PackedFloat32Array([0.0, top])


func test_u_stair_chain_passes() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void: _add_u_stair(m, false, 3.2),
		false, ["scale"])
	_expect_only(res, [])


func test_u_stair_ramp_collision_passes() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void: _add_u_stair(m, true, 3.2),
		false, ["scale"])
	_expect_only(res, [])


func test_u_stair_chain_missing_floor_height_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void: _add_u_stair(m, false, 3.4),
		false, ["scale"])
	_expect_fail(res, "scale", "Flight1")
	_expect_fail(res, "scale", "Flight2")
	_expect_fail(res, "scale", "no chain")


func test_stair_bad_riser_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_add_u_stair(m, false, 3.2)
		var st: Node3D = m.get_node("Geometry/UStair/Flight2/Step15")
		st.position.y += 0.04, false, ["scale"])
	_expect_fail(res, "scale", "riser")


func test_vault_door_scale() -> void:
	var ok: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var d: Node3D = m.get_node("Gameplay/DoorMid")
		d.set_meta(&"kind", "vault_door")
		(d.get_node("Leaf") as Node3D).scale = Vector3(2.2 / 0.9, 2.2 / 2.1, 1.0), false, ["scale"])
	_expect_only(ok, [])
	var bad: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		m.get_node("Gameplay/DoorMid").set_meta(&"kind", "vault_door"), false, ["scale"])
	_expect_fail(bad, "scale", "vault")


func test_u_stair_without_rails_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void: _add_u_stair(m, false, 3.2, 0.0),
		false, ["scale"])
	_expect_fail(res, "scale", "Flight1")
	_expect_fail(res, "scale", "Flight2")
	_expect_fail(res, "scale", "no handrail")
	_expect_fail(res, "scale", "open edge")


func test_u_stair_low_rail_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void: _add_u_stair(m, false, 3.2, 0.7),
		false, ["scale"])
	_expect_fail(res, "scale", "no handrail")
	_expect_fail(res, "scale", "tops [0.7")


func test_u_stair_single_unguarded_gap_fails() -> void:
	# 0.5 m gap in flight 2's outer guard, over a drop of several metres (void outside the fixture).
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_add_u_stair(m, false, 3.2, 1.05, 0.5), false, ["scale"])
	_expect_fail(res, "scale", "Flight2")
	_expect_fail(res, "scale", "+X side: open edge unguarded")
	var lines: PackedStringArray = res.get("scale", PackedStringArray())
	for l: String in lines:
		assert_false(l.contains("Flight1"), "flight 1 is fully guarded: %s" % l)


func test_u_stair_rail_measured_on_real_nosing_line() -> void:
	# 1.02 m above the real nosing line: passes only if heights are measured from the first-riser
	# nosing (a floor-based line would read it ~0.16 m too high at the bottom).
	var ok: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_add_u_stair(m, false, 3.2, 1.02), false, ["scale"])
	_expect_only(ok, [])
	var low: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_add_u_stair(m, false, 3.2, 0.95), false, ["scale"])
	_expect_fail(low, "scale", "open edge unguarded")


func _add_imperial(m: HeistMap, landing: String) -> void:
	LcFixtureBuilder.imperial_stair(m.get_node("Geometry"), Vector3(40.0, 0.0, 0.0), landing)
	m.floor_heights = PackedFloat32Array([0.0, 5.4])


## Lines of `check` mentioning `needle`.
static func _lines_with(res: Dictionary, check: String, needle: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for l: String in res.get(check, PackedStringArray()):
		if l.contains(needle):
			out.append(l)
	return out


func test_imperial_stair_chains_across_wide_landing() -> void:
	# Return flights start 6.2 m (in x) from the central flight's top riser, across a 14 m half landing.
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void: _add_imperial(m, "full"),
		false, ["scale"])
	_expect_only(res, [])


func test_imperial_stair_without_landing_fails() -> void:
	# Matching heights, but each flight only has its own pad: voids between them.
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void: _add_imperial(m, "pads"),
		false, ["scale"])
	for f: String in ["FlightC", "FlightW", "FlightE"]:
		_expect_fail(res, "scale", "%s`" % f)
	_expect_fail(res, "scale", "no chain")


func test_u_stair_split_landing_fails() -> void:
	# The old 4 m proximity rule chained these flights (1.4 m apart) across a 0.2 m void.
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_add_u_stair(m, false, 3.2)
		var geo: Node3D = m.get_node("Geometry/UStair")
		var land: Node = geo.get_node("Landing")
		geo.remove_child(land)
		land.free()
		var mat: Material = LcFixtureBuilder.tri_mat("fx_stair", Color(0.6, 0.6, 0.6), 512.0)
		var y: float = 10 * 0.16
		LcFixtureBuilder.solid(geo, "PadA", Vector3(0.0, y - 0.2, 9 * 0.28), Vector3(1.2, y, 9 * 0.28 + 1.2), mat)
		LcFixtureBuilder.solid(geo, "PadB", Vector3(1.4, y - 0.2, 9 * 0.28), Vector3(2.6, y, 9 * 0.28 + 1.2), mat),
		false, ["scale"])
	_expect_fail(res, "scale", "Flight1")
	_expect_fail(res, "scale", "Flight2")
	_expect_fail(res, "scale", "no chain")


func test_imperial_stair_landing_cut_by_wall_or_rail_fails() -> void:
	for cut: String in ["wall", "rail"]:
		var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void: _add_imperial(m, cut),
			false, ["scale"])
		var west: String = "\n".join(_lines_with(res, "scale", "FlightW`"))
		assert_true(west.contains("no chain"), "%s: west flight cut off: %s" % [cut, res])
		assert_true(_lines_with(res, "scale", "FlightE`").is_empty(), "%s: east flight still chains: %s" % [cut, res])
		assert_true(_lines_with(res, "scale", "FlightC`").is_empty(), "%s: central flight still chains: %s" % [cut, res])
