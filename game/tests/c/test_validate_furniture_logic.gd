## validate_level `furniture_logic` (PO-9, D-105): seats face their desk / table and sit on a usable
## side, no two seats face each other without a table between them, nothing blocks a door's clear
## zone, no duplicated stacked props, wall furniture never faces a wall. Small fixtures are added to
## the good fixture map far from its building (x = 40). Owner: ENV C.
extends LcTestBase

const ONLY: Array = ["furniture_logic"]
const X0: float = 40.0


## A prop root under Props: Node3D (meta kind, optional furniture class) + one box mesh child whose
## bottom sits on the root's origin.
static func _box(m: HeistMap, nm: String, kind: String, size: Vector3, pos: Vector3, yaw_deg: float,
		furniture: String = "") -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = nm
	root.set_meta(&"kind", kind)
	if furniture != "":
		root.set_meta(&"furniture", furniture)
	root.position = pos
	root.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = Vector3(0.0, size.y * 0.5, 0.0)
	root.add_child(mi)
	m.get_node("Props").add_child(root)
	return root


static func _desk(m: HeistMap) -> void:
	# user (knee-hole) side = -Z
	_box(m, "TestDesk", "desk", Vector3(1.4, 0.74, 0.7), Vector3(X0, 0.0, 0.0), 0.0, "desk")


static func _chair(m: HeistMap, nm: String, cls: String, pos: Vector3, yaw_deg: float) -> void:
	_box(m, nm, "chair", Vector3(0.45, 0.85, 0.45), pos, yaw_deg, cls)


func test_desk_with_its_chair_passes() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_desk(m)
		# yaw 180: front (-Z) turned to +Z, towards the desk
		_chair(m, "DeskChair", "desk_chair", Vector3(X0, 0.0, -0.75), 180.0)
		_chair(m, "VisitorA", "visitor_chair", Vector3(X0 - 0.35, 0.0, 0.75), -10.0)
		_chair(m, "VisitorB", "visitor_chair", Vector3(X0 + 0.35, 0.0, 0.75), 10.0), false, ONLY)
	_expect_only(res, [])


func test_good_fixture_passes() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", Callable(), false, ONLY)
	_expect_only(res, [])


func test_chairs_facing_each_other_in_front_of_desk_fail() -> void:
	# The product-owner case: two chairs on the desk's front, turned to each other.
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_desk(m)
		_chair(m, "ChairWest", "visitor_chair", Vector3(X0 - 0.5, 0.0, -0.9), -90.0)
		_chair(m, "ChairEast", "visitor_chair", Vector3(X0 + 0.5, 0.0, -0.9), 90.0), false, ONLY)
	_expect_fail(res, "furniture_logic", "seat_pair")
	_expect_fail(res, "furniture_logic", "seat_facing")
	_expect_fail(res, "furniture_logic", "visitor chair on the user side")


func test_chairs_across_a_table_pass() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_box(m, "TestTable", "table", Vector3(1.2, 0.74, 0.8), Vector3(X0, 0.0, 0.0), 0.0)
		_chair(m, "ChairN", "chair", Vector3(X0, 0.0, -0.6), 180.0)
		_chair(m, "ChairS", "chair", Vector3(X0, 0.0, 0.6), 0.0), false, ONLY)
	_expect_only(res, [])


func test_desk_chair_on_far_side_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_desk(m)
		_chair(m, "DeskChair", "desk_chair", Vector3(X0, 0.0, 0.75), 0.0), false, ONLY)
	_expect_fail(res, "furniture_logic", "desk chair on the far side")


func test_prop_blocking_door_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var door: Node3D = Node3D.new()
		door.name = "TestDoor"
		door.set_meta(&"kind", "door")
		door.position = Vector3(X0, 0.0, 6.0)
		var leaf: Node3D = Node3D.new()
		leaf.name = "Leaf"
		leaf.position = Vector3(-0.45, 0.0, 0.0)
		door.add_child(leaf)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.9, 2.1, 0.05)
		mi.mesh = bm
		mi.position = Vector3(0.45, 1.05, 0.0)
		leaf.add_child(mi)
		m.get_node("Gameplay").add_child(door)
		_box(m, "DoorwayBin", "bin", Vector3(0.4, 0.6, 0.4), Vector3(X0 + 0.1, 0.0, 6.5), 0.0), false, ONLY)
	_expect_fail(res, "furniture_logic", "door_clear")
	_expect_fail(res, "furniture_logic", "DoorwayBin")


func test_duplicated_stack_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		_box(m, "CrateA", "box", Vector3(0.6, 0.6, 0.6), Vector3(X0, 0.0, 12.0), 0.0)
		_box(m, "CrateB", "box", Vector3(0.6, 0.6, 0.6), Vector3(X0 + 0.02, 0.0, 12.0), 2.0), false, ONLY)
	_expect_fail(res, "furniture_logic", "duplicate")


func test_cabinet_facing_wall_fails() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var wall: StaticBody3D = StaticBody3D.new()
		wall.name = "TestWall"
		wall.position = Vector3(X0, 1.5, 18.1)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(4.0, 3.0, 0.2)
		cs.shape = bs
		wall.add_child(cs)
		m.get_node("Geometry").add_child(wall)
		# yaw 180: the front (-Z) looks at +Z, into the wall 2 cm away
		_box(m, "FacingCabinet", "file_cabinet", Vector3(0.5, 1.3, 0.6), Vector3(X0, 0.0, 17.68), 180.0, "wall_unit")
		# back to the wall, 1 cm off it: fine
		_box(m, "GoodCabinet", "file_cabinet", Vector3(0.5, 1.3, 0.6), Vector3(X0 + 1.0, 0.0, 17.69), 0.0, "wall_unit"),
		false, ONLY)
	_expect_fail(res, "furniture_logic", "FacingCabinet")
	var lines: PackedStringArray = res.get("furniture_logic", PackedStringArray())
	for l: String in lines:
		assert_false(l.contains("GoodCabinet"), "cabinet with its back to the wall failed: %s" % l)
