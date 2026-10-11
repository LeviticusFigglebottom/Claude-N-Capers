## validate_level stair and door-scale tests: U-stairs (flight chaining), ramp collision, riser
## errors, vault doors.
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
