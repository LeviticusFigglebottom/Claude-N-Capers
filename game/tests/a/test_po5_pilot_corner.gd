## P's OF ghost run 5: Po5Pilot.next_corner steers at the point past the path segment nearest the crew, never at a
## path point already behind it (the 0.5 s re-plan leaves the old start ~1.7 m behind at walking speed).
extends TestCase

const PATH: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)]


func test_old_start_behind_the_crew_is_skipped() -> void:
	var path: PackedVector3Array = PackedVector3Array(PATH)
	assert_eq(Po5Pilot.next_corner(path, Vector3(1.7, 0, 0.1), Vector3(10, 0, 10)), Vector3(10, 0, 0),
		"1.7 m along the first leg: steer at the first corner, not back at the start")
	assert_eq(Po5Pilot.next_corner(path, Vector3(10.2, 0, 4.0), Vector3(10, 0, 10)), Vector3(10, 0, 10),
		"on the second leg: the end, not the corner behind")
	assert_eq(Po5Pilot.next_corner(path, Vector3(9.8, 0, 0.1), Vector3(10, 0, 10)), Vector3(10, 0, 10),
		"within 0.45 m of the corner: the next point")
	assert_eq(Po5Pilot.next_corner(path, Vector3(0.1, 0, 0), Vector3(10, 0, 10)), Vector3(10, 0, 0), "at the start")
	assert_eq(Po5Pilot.next_corner(PackedVector3Array(), Vector3.ZERO, Vector3(5, 0, 5)), Vector3(5, 0, 5), "no path")


## B's DB count_cage stall (StairMezz): a nav path with a corner exactly in an open door's plane still crosses to the
## far side; the pilot inside the doorway band walked back to its own side and the path sent it north again (loop).
func test_path_crossing_with_a_corner_in_the_door_plane() -> void:
	var door: Door = Door.new()
	door.width_m = 0.9
	add_child(door)
	door.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(1.5, 3.6, 6.0))  # DB StairMezz: local z = -world z
	await wait_frames(1)
	var path: PackedVector3Array = PackedVector3Array([Vector3(1.7, 3.8, 5.3), Vector3(1.73, 3.8, 5.5),
		Vector3(1.8, 3.8, 6.0), Vector3(2.0, 3.8, 6.5), Vector3(11.6, 3.8, 6.5)])
	assert_eq(Po5Pilot.path_crosses(door, path), -1.0, "the path leaves through the door to its local -z side (world z > 6)")
	var back: PackedVector3Array = PackedVector3Array([Vector3(2.0, 3.8, 6.5), Vector3(1.8, 3.8, 6.0), Vector3(1.7, 3.8, 5.3)])
	assert_eq(Po5Pilot.path_crosses(door, back), 1.0, "the other way: local +z")
	var along: PackedVector3Array = PackedVector3Array([Vector3(1.7, 3.8, 5.3), Vector3(1.7, 3.8, 4.6)])
	assert_eq(Po5Pilot.path_crosses(door, along), 0.0, "no crossing")
	door.queue_free()


## B's DB GatehouseNorth stall: the path's own way out of a doorway (the first point past THROUGH_PAST_M), not the straight
## line to the target.
func test_path_side_of_a_doorway() -> void:
	var door: Door = Door.new()
	add_child(door)
	door.global_transform = Transform3D(Basis.IDENTITY, Vector3(27.0, 0.0, -32.0))  # DB GatehouseNorth
	await wait_frames(1)
	var south: PackedVector3Array = PackedVector3Array([Vector3(27.0, 0.2, -32.6), Vector3(27.0, 0.2, -34.0),
		Vector3(40.0, 0.2, -34.0)])
	assert_eq(Po5Pilot.path_side(door, south), -1.0, "the path leaves south (local -z) though the target is north")
	var north: PackedVector3Array = PackedVector3Array([Vector3(27.0, 0.2, -31.5), Vector3(27.0, 0.2, -30.0)])
	assert_eq(Po5Pilot.path_side(door, north), 1.0, "north")
	var other_floor: PackedVector3Array = PackedVector3Array([Vector3(27.0, 3.8, -30.0)])
	assert_eq(Po5Pilot.path_side(door, other_floor), 0.0, "a point on another floor does not count")
	door.queue_free()


## LEAD's r264 sweep (GH Routine 1001): the path climbs stairs east of the crew, then comes back west on the floor
## above, right over the crew. The next corner is the stair foot, never the leg 4.4 m overhead.
func test_next_corner_ignores_the_leg_overhead() -> void:
	var path: PackedVector3Array = PackedVector3Array([Vector3(12.5, 0.2, 5.0), Vector3(13.5, 0.3, 4.7),
		Vector3(15.1, 4.4, 4.6), Vector3(11.6, 4.4, 5.0), Vector3(4.2, 4.4, 2.5)])
	var c: Vector3 = Po5Pilot.next_corner(path, Vector3(11.7, 0.0, 5.0), Vector3(4.2, 4.4, 2.5))
	assert_true(c.y < 1.0, "steers along the ground floor to the stairs, not at %s overhead" % c)
