## validate_level `hide_los` (OF-C3, D-136 §3b.11, D-128) and `teller_worktop` on the good fixture. Room B
## (x 8.1..15.6, z 0.4..7.6, floor 0) gets a solid ledge across its width at z 3.0..3.1; the observers stand in a
## "hall" RoomVolume north of it (z 3.3..7.6); the hide spot is a crouched player at z 2.4 (0.6 m behind the ledge).
extends LcTestBase

const HIDE: PackedStringArray = ["hide_los"]
const TELLER: PackedStringArray = ["teller_worktop"]


static func _hall(m: HeistMap) -> void:
	var rv: RoomVolume = RoomVolume.new()
	rv.name = "HallB"
	rv.room_id = &"hall_b"
	rv.purpose = &"office"
	LcFixtureBuilder.area_box(rv, Vector3(11.85, 1.4, 5.45), Vector3(7.5, 2.8, 4.3))
	m.get_node("Rooms").add_child(rv)


## Ledge of height `h` (solid) and, above it to 2.4 m, glazing with meta see_through when `glass`.
static func _ledge(m: HeistMap, h: float, glass: bool) -> void:
	LcFixtureBuilder.prop(m.get_node("Props"), "Ledge", Vector3(11.85, 0.0, 3.05), 0.0, "counter_front",
		Vector3(7.5, h, 0.1), Vector3(0, h * 0.5, 0), null, true)
	if glass:
		LcFixtureBuilder.prop(m.get_node("Props"), "Glass", Vector3(11.85, h, 3.05), 0.0, "glass",
			Vector3(7.5, 2.4 - h, 0.02), Vector3(0, (2.4 - h) * 0.5, 0), null, true, {"see_through": true})


## A Marker3D chain (x 9..14 at z 2.4) with the hide metas.
static func _spot(m: HeistMap, metas: Dictionary) -> void:
	var line: Node3D = Node3D.new()
	line.name = "HideLine"
	for k: String in metas:
		line.set_meta(StringName(k), metas[k])
	m.get_node("Gameplay").add_child(line)
	for i: int in range(2):
		var mk: Marker3D = Marker3D.new()
		mk.name = "P%d" % i
		mk.position = Vector3(9.0 + 5.0 * i, 0.0, 2.4)
		line.add_child(mk)


func _hide_case(ledge_h: float, glass: bool, metas: Dictionary) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_hall(m)
		_ledge(m, ledge_h, glass)
		_spot(m, metas), false, HIDE)


func test_unconfigured_map_skips() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", Callable(), false, PackedStringArray(["hide_los", "teller_worktop"]))
	assert_false(res.has("hide_los"), "hide_los skipped without hide_spot: %s" % [res])
	assert_false(res.has("teller_worktop"), "teller_worktop skipped without the kind: %s" % [res])


func test_crouched_behind_a_1_05m_ledge_is_visible() -> void:
	# The doc's original claim: a 1.05 m front never hides the 1.05 m crouched detection point.
	var res: Dictionary = await _hide_case(1.05, true, {"hide_spot": true, "hide_from": "hall_b"})
	_expect_only(res, ["hide_los"])
	_expect_fail(res, "hide_los", "hide spot is visible")
	_expect_fail(res, "hide_los", "11 of 11 sample(s) seen (crouched)")


func test_crouched_behind_a_1_35m_base_with_glass_is_hidden() -> void:
	var res: Dictionary = await _hide_case(1.35, true, {"hide_spot": true, "hide_from": PackedStringArray(["hall_b"])})
	_expect_only(res, [])
	assert_true(res.has("hide_los"), "hide_los ran: %s" % [res])


func test_a_1_15m_base_is_not_enough() -> void:
	# Observers 2 m away need 1.05 + 0.57 x 0.6 / 2.0 = 1.22 m at the ledge's crew-side face (0.6 m from the crew).
	var res: Dictionary = await _hide_case(1.15, true, {"hide_spot": true, "hide_from": "hall_b"})
	_expect_fail(res, "hide_los", "hide spot is visible")


func test_standing_posture_is_visible_over_1_35m() -> void:
	var res: Dictionary = await _hide_case(1.35, true, {"hide_spot": true, "hide_from": "hall_b", "hide_posture": "stand"})
	_expect_fail(res, "hide_los", "standing")
	_expect_fail(res, "hide_los", "sees the 1.60 m point")


func test_unknown_room_and_missing_hide_from_fail() -> void:
	var res: Dictionary = await _hide_case(1.35, false, {"hide_spot": true, "hide_from": "nope"})
	_expect_fail(res, "hide_los", "no RoomVolume with room_id `nope`")
	var res2: Dictionary = await _hide_case(1.35, false, {"hide_spot": true})
	_expect_fail(res2, "hide_los", "has no `hide_from`")


# --- teller_worktop ------------------------------------------------------------------------------------------

## A 3.0 x 1.0 x `depth` m work top at (12, 0, 2.0) (teller side -Z = south), optional solid front of `front_h` on its
## customer face (+Z) with glass above, optional box in the stand zone.
func _teller_case(depth: float, front_h: float, hide: bool, stand_box: bool) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var props: Node = m.get_node("Props")
		var metas: Dictionary = {"hide_behind": true} if hide else {}
		LcFixtureBuilder.prop(props, "Worktop", Vector3(12.0, 0.0, 2.0), 0.0, "teller_worktop",
			Vector3(3.0, 1.0, depth), Vector3(0, 0.5, 0), null, true, metas)
		if front_h > 0.0:
			var z: float = 2.0 + depth * 0.5 + 0.025
			LcFixtureBuilder.prop(props, "ScreenBase", Vector3(12.0, 0.0, z), 0.0, "counter_front",
				Vector3(3.0, front_h, 0.05), Vector3(0, front_h * 0.5, 0), null, true)
			LcFixtureBuilder.prop(props, "BanditGlass", Vector3(12.0, front_h, z), 0.0, "glass",
				Vector3(3.0, 2.4 - front_h, 0.02), Vector3(0, (2.4 - front_h) * 0.5, 0), null, true)
		if stand_box:
			LcFixtureBuilder.prop(props, "StandBox", Vector3(12.0, 0.0, 1.2), 0.0, "box", Vector3(0.4, 0.4, 0.4),
				Vector3(0, 0.2, 0), null, true), false, TELLER)


func test_teller_worktop_with_1_4m_screen_base_passes() -> void:
	var res: Dictionary = await _teller_case(0.6, 1.4, true, false)
	_expect_only(res, [])
	assert_true(res.has("teller_worktop"), "teller_worktop ran: %s" % [res])


func test_teller_worktop_without_a_solid_front_fails_the_hide_claim() -> void:
	# Front = the 1.0 m work top itself; needs 1.05 + 0.57 x 0.95 / 2.0 = 1.32 m.
	var res: Dictionary = await _teller_case(0.6, 0.0, true, false)
	_expect_only(res, ["teller_worktop"])
	_expect_fail(res, "teller_worktop", "is below the 1.32 m a crouched player needs")


func test_teller_worktop_1_2m_base_fails_and_no_claim_passes() -> void:
	var res: Dictionary = await _teller_case(0.6, 1.2, true, false)
	_expect_fail(res, "teller_worktop", "solid front 1.20 m")
	var res2: Dictionary = await _teller_case(0.6, 1.2, false, false)
	_expect_only(res2, [])


func test_teller_worktop_depth_and_stand_zone() -> void:
	var res: Dictionary = await _teller_case(1.2, 0.0, false, false)
	_expect_fail(res, "teller_worktop", "depth 1.20 m outside 0.45–0.90 m")
	var res2: Dictionary = await _teller_case(0.6, 0.0, false, true)
	_expect_only(res2, ["teller_worktop"])
	_expect_fail(res2, "teller_worktop", "blocked by `Props/StandBox`")
