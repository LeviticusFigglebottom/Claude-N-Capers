## D-138 / P round 243: the CountCagePadlock's UsePoint stands on M1's navmesh and the walk from the mezzanine
## corridor reaches it through the M1 door, not over the M1/M2 wall into the break room (the pilot stalled in M2
## when the point sat in the gate's swing, 0.42 m off the wall). Owner: ENV C.
extends TestCase

const SCENE: String = "res://world/heists/dockside_burn/dockside_burn.tscn"
const PADLOCK: String = "Gameplay/Doors/CountCageGate/CountCagePadlock"
## Mezzanine corridor MC, west of the M2 door (where the pilot came up the fire stair).
const CORRIDOR: Vector3 = Vector3(2.0, 3.6, 7.0)
## M2 break room floor box (x, z) on the mezzanine.
const M2_MIN: Vector2 = Vector2(3.0, 0.0)
const M2_MAX: Vector2 = Vector2(9.0, 6.0)
const SNAP_M: float = 0.3

var _map: Node3D = null
var _rid: RID = RID()


func before_all() -> void:
	var ps: PackedScene = load(SCENE) as PackedScene
	if ps == null:
		return
	_map = ps.instantiate() as Node3D
	add_child(_map)
	_rid = (_map.get_node("Navigation") as NavigationRegion3D).get_navigation_map()
	for i: int in range(120):
		await wait_physics_frames(1)
		if NavigationServer3D.map_get_iteration_id(_rid) > 0 \
				and NavigationServer3D.map_get_closest_point(_rid, CORRIDOR).distance_to(CORRIDOR) <= SNAP_M:
			break


func after_all() -> void:
	if _map != null:
		_map.queue_free()


func _use_point() -> Vector3:
	var pad: Node3D = _map.get_node_or_null(PADLOCK) as Node3D
	if pad == null:
		return Vector3.INF
	var up: Node3D = pad.get_node_or_null("UsePoint") as Node3D
	return up.global_position if up != null else Vector3.INF


func test_use_point_on_navmesh() -> void:
	assert_true(_map != null, "dockside_burn scene loads")
	var p: Vector3 = _use_point()
	assert_true(p != Vector3.INF, "CountCagePadlock has a UsePoint")
	var c: Vector3 = NavigationServer3D.map_get_closest_point(_rid, p)
	assert_true(c.distance_to(p) <= SNAP_M, "UsePoint %s on the navmesh (closest %s)" % [p, c])
	assert_false(c.x > M2_MIN.x and c.x < M2_MAX.x and c.z > M2_MIN.y and c.z < M2_MAX.y,
		"nearest mesh point is in M1, not over the wall in M2 (%s)" % c)


func test_corridor_walk_avoids_break_room() -> void:
	var p: Vector3 = _use_point()
	if p == Vector3.INF:
		return
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_rid, CORRIDOR, p, true)
	assert_true(path.size() >= 2, "a path from the corridor to the padlock")
	if path.is_empty():
		return
	assert_true(path[path.size() - 1].distance_to(p) <= SNAP_M, "the path ends at the UsePoint")
	for q: Vector3 in path:
		assert_false(q.x > M2_MIN.x + 0.05 and q.x < M2_MAX.x - 0.05 and q.z > M2_MIN.y and q.z < M2_MAX.y - 0.05,
			"path corner %s stays out of the M2 break room" % q)
