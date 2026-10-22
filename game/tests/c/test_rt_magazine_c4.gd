## Rolling Thunder site: the explosives magazine's C4 boxes are used from inside the room (P's RT real-input pass, r280:
## a C4Box UsePoint 0.2 m off MagWallN was off the eroded navmesh, so with MagazineDoor shut a bot pathed to the nearest
## point beyond that wall: 12 STUCK at (-23.5, 0, -52.5)). On the generated map, every C4Box's UsePoint stands inside
## the magazine (MagWall* footprints) at least the bake's agent radius (0.3 m) off every wall, nearer the door than
## the north wall. Owner: ENV C.
extends TestCase

const MAP: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"
const AGENT_R: float = 0.3

var _map: Node3D = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null
	await wait_frames(2)


func test_c4_use_points_stand_inside_the_magazine_on_its_navmesh() -> void:
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	add_child(_map)
	await wait_frames(1)
	var walls: Array[AABB] = []
	var room: AABB = AABB()
	for n: Node in _map.find_children("MagWall*", "", true, false):
		var bb: AABB = _footprint(n)
		walls.append(bb)
		room = bb if room.size == Vector3.ZERO else room.merge(bb)
	assert_eq(walls.size(), 5, "found the magazine walls")
	var boxes: Array[Node] = _map.find_children("C4Box*", "ItemPickup", true, false)
	assert_true(boxes.size() >= 2, "found the C4 boxes (%d)" % boxes.size())
	for b: Node in boxes:
		var up: Vector3 = (b.get_node("UsePoint") as Node3D).global_position
		var where: String = String(_map.get_path_to(b))
		assert_true(room.grow(-AGENT_R).has_point(Vector3(up.x, room.get_center().y, up.z)),
			"%s UsePoint %s inside the magazine, >= %.1f m off its outer walls" % [where, up, AGENT_R])
		for w: AABB in walls:
			var dx: float = maxf(maxf(w.position.x - up.x, up.x - w.end.x), 0.0)
			var dz: float = maxf(maxf(w.position.z - up.z, up.z - w.end.z), 0.0)
			assert_true(sqrt(dx * dx + dz * dz) >= AGENT_R, "%s UsePoint %s within %.1f m of a wall" % [where, up,
				AGENT_R])


## A wall's collider footprint (world AABB of its box shapes).
func _footprint(n: Node) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c as CollisionShape3D
		var box: BoxShape3D = cs.shape as BoxShape3D
		if box == null:
			continue
		var w: AABB = cs.global_transform * AABB(-box.size * 0.5, box.size)
		out = w if first else out.merge(w)
		first = false
	return out
