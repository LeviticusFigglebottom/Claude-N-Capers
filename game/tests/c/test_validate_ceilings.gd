## validate_level `scale` ceiling bands for the D-075 room purposes (gallery, hall, car_park).
## The fixture rooms are 2.8 m high (LcFixtureBuilder.CEIL_H), so a purpose passes or fails on its band.
extends LcTestBase


func _with_purpose(purpose: StringName) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		(m.get_node("Rooms/RoomA") as RoomVolume).purpose = purpose, false, ["scale"])


func test_d075_purpose_bands_in_table() -> void:
	assert_eq(LcCheckScale.CEILING.get(&"gallery"), Vector2(4.5, 6.5), "gallery: top-lit 4.5-6.5 m (D-075)")
	assert_eq(LcCheckScale.CEILING.get(&"hall"), Vector2(6.0, 9.0), "hall: 6-9 m (D-075)")
	assert_eq(LcCheckScale.CEILING.get(&"car_park"), Vector2(2.2, 3.0), "car_park: 2.2-3.0 m (D-075, QC-87)")
	for p: StringName in [&"gallery", &"hall", &"car_park"]:
		assert_false(p in LcCheckScale.NO_CEILING, "%s has a ceiling rule" % p)


func test_car_park_at_2_8_passes() -> void:
	var res: Dictionary = await _with_purpose(&"car_park")
	_expect_only(res, [])


func test_gallery_at_2_8_fails() -> void:
	var res: Dictionary = await _with_purpose(&"gallery")
	_expect_fail(res, "scale", "outside 4.5-6.5 m for purpose `gallery`")


func test_hall_at_2_8_fails() -> void:
	var res: Dictionary = await _with_purpose(&"hall")
	_expect_fail(res, "scale", "outside 6.0-9.0 m for purpose `hall`")


func test_override_still_wins_over_purpose() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var r: RoomVolume = m.get_node("Rooms/RoomA") as RoomVolume
		r.purpose = &"gallery"
		r.set_meta(&"ceiling_range", Vector2(2.6, 3.0)), false, ["scale"])
	_expect_only(res, [])
