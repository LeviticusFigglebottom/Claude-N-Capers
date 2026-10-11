## validate_level `cameras` check: review cameras must not sit inside or against walls, and must be
## in a RoomVolume or outdoors.
extends LcTestBase


func _move_camera(pos: Vector3, look: Vector3 = Vector3(4.15, 1.0, 4.0)) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var c: Node3D = m.get_node("ReviewCameras/A_SW")
		c.transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos), false, ["cameras"])


func test_camera_in_room_centre_passes() -> void:
	var res: Dictionary = await _move_camera(Vector3(4.15, 1.65, 4.0), Vector3(1.0, 1.0, 4.0))
	_expect_only(res, [])


func test_camera_inside_wall_fails() -> void:
	# WallSouth spans z 0 .. 0.4 (exterior wall); the camera sits in its thickness.
	var res: Dictionary = await _move_camera(Vector3(3.0, 1.65, 0.2))
	_expect_fail(res, "cameras", "A_SW")
	_expect_fail(res, "cameras", "WallSouth")


func test_camera_against_wall_fails() -> void:
	# 0.2 m in front of the wall face (z 0.4): within the 0.3 m clearance.
	var res: Dictionary = await _move_camera(Vector3(3.0, 1.65, 0.6))
	_expect_fail(res, "cameras", "within 0.3 m")


func test_camera_in_unlisted_enclosed_space_fails() -> void:
	# Under the floor slab: no RoomVolume there and the slab blocks the sky.
	var res: Dictionary = await _move_camera(Vector3(4.0, -1.0, 4.0))
	_expect_fail(res, "cameras", "neither inside a RoomVolume nor outdoors")


func test_floor_names_count_mismatch_fails_contract() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		m.floor_names = PackedStringArray(["Ground", "Extra"]), false, ["contract_nodes"])
	_expect_fail(res, "contract_nodes", "floor_names has 2 entries")



func test_camera_in_door_opening_fails() -> void:
	# The fixture's 1.0 m opening in the 0.2 m wall between rooms A and B (x 7.9-8.1, z 3.5-4.5):
	# 0.5 m from both jambs, so the 0.3 m sphere misses them (the Glasshouse WorkshopSafe case).
	var res: Dictionary = await _move_camera(Vector3(7.85, 1.65, 4.0), Vector3(4.0, 1.0, 4.0))
	_expect_fail(res, "cameras", "only 0.05 m inside")


func test_camera_in_door_opening_inside_room_box_fails() -> void:
	# Room boxes often reach the wall centre line: a camera mid-wall in the opening (x 8.0 is in
	# neither fixture box, so widen room A's box) must still fail via the opening rule.
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var shape: BoxShape3D = (m.get_node("Rooms/RoomA").find_child("Shape") as CollisionShape3D).shape.duplicate()
		shape.size.x += 0.4
		(m.get_node("Rooms/RoomA").find_child("Shape") as CollisionShape3D).shape = shape
		(m.get_node("Rooms/RoomA") as Node3D).position.x += 0.2
		var c: Node3D = m.get_node("ReviewCameras/A_SW")
		c.transform = Transform3D(Basis.looking_at(Vector3(-4.0, -0.6, 0.0), Vector3.UP), Vector3(8.0, 1.65, 4.0)),
		false, ["cameras"])
	_expect_fail(res, "cameras", "wall opening")


func test_camera_facing_near_wall_fails() -> void:
	# 0.45 m from the west wall face, looking straight at it: the centre ray hits at 0.45 m.
	var res: Dictionary = await _move_camera(Vector3(0.85, 1.65, 5.5), Vector3(-1.0, 1.65, 5.5))
	_expect_fail(res, "cameras", "frustum centre/corner ray")
