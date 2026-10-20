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
