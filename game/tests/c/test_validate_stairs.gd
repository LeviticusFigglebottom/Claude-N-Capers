## validate_level stair tests: U-stairs (flight chaining), ramp collision, riser errors.
extends LcTestBase


func _add_u_stair(m: HeistMap, ramp: bool, top: float) -> void:
	LcFixtureBuilder.u_stair(m.get_node("Geometry"), Vector3(30.0, 0.0, 0.0), ramp)
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
