## validate_level door_frame_gap + seam_gaps (PO-7) with the real ENV A door prefab in a small test
## wall far from the fixture building (x 40): a good door, a leaf gap, a frame-wall gap, a frame
## clipping into the wall, a door in no opening; plus a corner seam slit in the fixture shell.
## Skipped if ENV A's prefab is absent (tests only load it by path).
extends LcTestBase

const DOOR_PREFAB: String = "res://systems/prefabs/door/door.tscn"
const X0: float = 40.0
const WALL_T: float = 0.2
const ONLY: Array = ["door_frame_gap", "seam_gaps"]


## Door visual (visual_slots.md): Frame = jamb linings (0.05 m wide, wall depth + 0.02) and a head
## around a 1.0 x 2.2 m opening; Leaf = `leaf_w` x 2.1 m panel hinged at -leaf_w / 2.
static func door_visual(leaf_w: float) -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "GapDoorVisual"
	var mat: StandardMaterial3D = LcFixtureBuilder.tri_mat("fx_frame", Color(0.4, 0.4, 0.42), 512.0)
	var frame: Node3D = Node3D.new()
	frame.name = "Frame"
	root.add_child(frame)
	frame.owner = root
	var d: float = WALL_T + 0.02
	for part: Array in [["JambL", Vector3(-0.475, 1.1, 0.0), Vector3(0.05, 2.2, d)],
			["JambR", Vector3(0.475, 1.1, 0.0), Vector3(0.05, 2.2, d)],
			["Head", Vector3(0.0, 2.15, 0.0), Vector3(1.0, 0.1, d)]]:
		_mesh(frame, root, String(part[0]), part[1], part[2], mat)
	var leaf: Node3D = Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(-leaf_w * 0.5, 0.0, 0.0)
	root.add_child(leaf)
	leaf.owner = root
	_mesh(leaf, root, "Panel", Vector3(leaf_w * 0.5, 1.054, 0.0), Vector3(leaf_w - 0.004, 2.092, 0.04), mat)
	var handle: Marker3D = Marker3D.new()
	handle.name = "Handle"
	handle.position = Vector3(leaf_w - 0.1, 1.0, -0.06)
	leaf.add_child(handle)
	handle.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


static func _mesh(parent: Node3D, owner_root: Node, nm: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
	mi.owner = owner_root


## Test wall along X at z 0 (x 38.5-41.5, 3 m high) with an opening [x0, x1] x [0, head]
## (no opening when x1 <= x0), and a door prefab with a `leaf_w` leaf at (X0, 0, 0).
func _case(leaf_w: float, x0: float, x1: float, head: float = 2.2) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var geo: Node3D = m.get_node("Geometry")
		var mat: StandardMaterial3D = LcFixtureBuilder.tri_mat("fx_wall", Color(0.75, 0.72, 0.66), 512.0)
		var h: float = WALL_T * 0.5
		if x1 <= x0:
			LcFixtureBuilder.solid(geo, "GapWall", Vector3(X0 - 1.5, 0.0, -h), Vector3(X0 + 1.5, 3.0, h), mat)
		else:
			LcFixtureBuilder.solid(geo, "GapWallL", Vector3(X0 - 1.5, 0.0, -h), Vector3(x0, 3.0, h), mat)
			LcFixtureBuilder.solid(geo, "GapWallR", Vector3(x1, 0.0, -h), Vector3(X0 + 1.5, 3.0, h), mat)
			LcFixtureBuilder.solid(geo, "GapWallHead", Vector3(x0, head, -h), Vector3(x1, 3.0, h), mat)
		var door: Node3D = (load(DOOR_PREFAB) as PackedScene).instantiate() as Node3D
		door.name = "GapDoor"
		door.set(&"width_m", 0.9)
		door.set(&"visual_scene", door_visual(leaf_w))
		door.set_meta(&"kind", "door")
		door.position = Vector3(X0, 0.0, 0.0)
		m.get_node("Gameplay").add_child(door)
		door.owner = m, false, ONLY)


func _prefab_ok() -> bool:
	if not ResourceLoader.exists(DOOR_PREFAB):
		skip("ENV A door prefab not present")
		return false
	return true


func test_good_door_passes() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case(0.9, X0 - 0.5, X0 + 0.5)
	_expect_only(res, [])


func test_leaf_gap_fails() -> void:
	if not _prefab_ok():
		return
	# 0.8 m leaf in the 0.9 m clear opening: 5 cm slits beside it.
	var res: Dictionary = await _case(0.8, X0 - 0.5, X0 + 0.5)
	_expect_fail(res, "door_frame_gap", "GapDoor")
	_expect_fail(res, "door_frame_gap", "leaf gap 0.05")
	_expect_fail(res, "door_frame_gap", "see-through gap")


func test_frame_wall_gap_fails() -> void:
	if not _prefab_ok():
		return
	# 1.0 m frame in a 1.1 m opening, 2.3 m head: 5 cm / 10 cm open strips round the frame.
	var res: Dictionary = await _case(0.9, X0 - 0.55, X0 + 0.55, 2.3)
	_expect_fail(res, "door_frame_gap", "frame-wall gap 0.050 m at the +X jamb")
	_expect_fail(res, "door_frame_gap", "frame-wall gap 0.100 m at the head")
	_expect_fail(res, "door_frame_gap", "between the frame and the wall")


func test_frame_clipping_into_wall_fails() -> void:
	if not _prefab_ok():
		return
	# 1.0 m frame in a 0.9 m opening: each jamb runs 5 cm into the wall.
	var res: Dictionary = await _case(0.9, X0 - 0.45, X0 + 0.45)
	_expect_fail(res, "door_frame_gap", "frame clips 0.050 m into the wall")


func test_door_in_no_opening_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case(0.9, 0.0, 0.0)
	_expect_fail(res, "door_frame_gap", "sits in no wall opening")


func test_corner_seam_slit_fails() -> void:
	# The east wall stops 5 cm short of the south wall: a see-through slit in room B's corner.
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var east: StaticBody3D = m.get_node("Geometry/WallEast") as StaticBody3D
		var lo: Vector3 = Vector3(15.6, 0.0, 0.45)
		var hi: Vector3 = Vector3(16.0, LcFixtureBuilder.CEIL_H, 7.6)
		east.position = (lo + hi) * 0.5
		((east.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size = hi - lo
		((east.get_node("Mesh") as MeshInstance3D).mesh as BoxMesh).size = hi - lo, false, ONLY)
	_expect_fail(res, "seam_gaps", "corner seam 0.050 m")
