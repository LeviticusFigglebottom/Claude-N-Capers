## Rolling Thunder armoured trucks' rear doors (B's RT HUD run: the saw timer anchored at the truck's pivot, inside the
## cargo box, and hid behind its collision). On the generated map, every ArmoredTruck: its saw runner is a SAW
## drill_point child (`SawPoint`, Safe._own_device_point) standing on the art's `DrillPoint` lock marker, outside the
## cargo box (Body) and facing into the lock; the visual has `Door`, `Body` and `LootAnchor`; swing_open() turns the
## door. Owner: ENV C.
extends TestCase

const MAP: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"
const NEAR_M: float = 0.05

var _map: Node = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null
	await wait_frames(2)


func test_trucks_saw_on_the_rear_door_and_doors_swing() -> void:
	_map = (load(MAP) as PackedScene).instantiate()
	add_child(_map)
	await wait_frames(2)
	var n: int = 0
	for node: Node in _map.find_children("*", "ArmoredTruck", true, false):
		var t: ArmoredTruck = node as ArmoredTruck
		var where: String = String(_map.get_path_to(t))
		var sp: DrillPoint = t.get_node_or_null(^"SawPoint") as DrillPoint
		assert_true(sp != null, "%s has a SawPoint" % where)
		var mark: Node3D = t.visual_node("DrillPoint") as Node3D
		assert_true(mark != null, "%s visual has DrillPoint" % where)
		for nm: String in ["Door", "Body", "LootAnchor"]:
			assert_true(t.visual_node(nm) != null, "%s visual has %s" % [where, nm])
		if sp == null or mark == null:
			continue
		assert_eq(sp.device_kind(), &"saw", "%s SawPoint is a saw" % where)
		assert_true(t.get(&"_device_point") == sp, "%s runs its saw at the SawPoint" % where)
		var d: float = sp.global_position.distance_to(mark.global_position)
		assert_true(d < NEAR_M, "%s SawPoint %.2f m from the lock marker" % [where, d])
		var body: AABB = t.global_transform * t.interior_aabb()
		assert_false(body.has_point(sp.global_position), "%s SawPoint outside the cargo box" % where)
		# -Z into the lock: the doors face the truck's -Z, so the point looks along the truck's +Z
		var into: Vector3 = -sp.global_basis.z
		assert_true(into.dot(t.global_basis.z) > 0.99, "%s SawPoint faces into the lock" % where)
		var door: Node3D = t.visual_node("Door") as Node3D
		var before: float = door.rotation.y
		t.swing_open()
		assert_true(absf(door.rotation.y - before) > 0.5, "%s door swings open" % where)
		n += 1
	assert_true(n >= 4, "checked the trucks (%d)" % n)
