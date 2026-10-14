## validate_level frame_proud (PO-7): door frame colliders flush with the wall faces and clear of
## the leaf's span. The real ENV A door prefab in a small t20 test wall far from the fixture building
## (x 40, like test_validate_door_frame_gap): flush jamb colliders pass, colliders standing 2 cm
## proud fail, colliders 3 cm inside the leaf's span fail, and the catalog's
## prop_door_single_ivory_t20 (the Glasshouse LobbyDoor visual) passes. Skipped without the prefab.
extends LcTestBase

const DOOR_PREFAB: String = "res://systems/prefabs/door/door.tscn"
const CATALOG_DOOR: String = "res://world/props/door/prop_door_single_ivory_t20.tscn"
const X0: float = 40.0
const WALL_T: float = 0.2
const ONLY: Array = ["frame_proud", "door_frame_gap"]


## Door visual: Frame = jamb linings (0.05 m, wall depth) + head meshes, a Frame/Collision body with
## box jambs `col_depth` deep whose inner faces sit `col_inner` from the centre; Leaf 0.9 x 2.1 m.
static func door_visual(col_depth: float, col_inner: float) -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "ProudDoorVisual"
	var mat: StandardMaterial3D = LcFixtureBuilder.tri_mat("fx_frame", Color(0.4, 0.4, 0.42), 512.0)
	var frame: Node3D = Node3D.new()
	frame.name = "Frame"
	root.add_child(frame)
	frame.owner = root
	for part: Array in [["JambL", Vector3(-0.475, 1.1, 0.0), Vector3(0.05, 2.2, WALL_T)],
			["JambR", Vector3(0.475, 1.1, 0.0), Vector3(0.05, 2.2, WALL_T)],
			["Head", Vector3(0.0, 2.15, 0.0), Vector3(1.0, 0.1, WALL_T)]]:
		_mesh(frame, root, String(part[0]), part[1], part[2], mat)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	frame.add_child(body)
	body.owner = root
	var w: float = 0.5 - col_inner
	for sx: float in [-1.0, 1.0]:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Jamb%s" % ("L" if sx < 0.0 else "R")
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(w, 2.2, col_depth)
		cs.shape = bs
		cs.position = Vector3(sx * (col_inner + w * 0.5), 1.1, 0.0)
		body.add_child(cs)
		cs.owner = root
	var leaf: Node3D = Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(-0.45, 0.0, 0.0)
	root.add_child(leaf)
	leaf.owner = root
	_mesh(leaf, root, "Panel", Vector3(0.45, 1.054, 0.0), Vector3(0.896, 2.092, 0.04), mat)
	var handle: Marker3D = Marker3D.new()
	handle.name = "Handle"
	handle.position = Vector3(0.8, 1.0, -0.06)
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


## Test wall along X at z 0 (x 38.5-41.5, 3 m high, WALL_T thick) with a 1.0 x 2.2 m opening and a
## door prefab showing `visual` at (X0, 0, 0).
func _case(visual: PackedScene) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var geo: Node3D = m.get_node("Geometry")
		var mat: StandardMaterial3D = LcFixtureBuilder.tri_mat("fx_wall", Color(0.75, 0.72, 0.66), 512.0)
		var h: float = WALL_T * 0.5
		LcFixtureBuilder.solid(geo, "ProudWallL", Vector3(X0 - 1.5, 0.0, -h), Vector3(X0 - 0.5, 3.0, h), mat)
		LcFixtureBuilder.solid(geo, "ProudWallR", Vector3(X0 + 0.5, 0.0, -h), Vector3(X0 + 1.5, 3.0, h), mat)
		LcFixtureBuilder.solid(geo, "ProudWallHead", Vector3(X0 - 0.5, 2.2, -h), Vector3(X0 + 0.5, 3.0, h), mat)
		var door: Node3D = (load(DOOR_PREFAB) as PackedScene).instantiate() as Node3D
		door.name = "ProudDoor"
		door.set(&"width_m", 0.9)
		door.set(&"visual_scene", visual)
		door.set_meta(&"kind", "door")
		door.position = Vector3(X0, 0.0, 0.0)
		m.get_node("Gameplay").add_child(door)
		door.owner = m, false, ONLY)


func _prefab_ok() -> bool:
	if not ResourceLoader.exists(DOOR_PREFAB):
		skip("ENV A door prefab not present")
		return false
	return true


func test_flush_frame_collider_passes() -> void:
	if not _prefab_ok():
		return
	_expect_only(await _case(door_visual(WALL_T, 0.45)), [])


func test_proud_frame_collider_fails() -> void:
	if not _prefab_ok():
		return
	# jamb colliders 0.24 m deep in the 0.2 m wall: 2 cm proud of both faces
	var res: Dictionary = await _case(door_visual(WALL_T + 0.04, 0.45))
	_expect_fail(res, "frame_proud", "ProudDoor")
	_expect_fail(res, "frame_proud", "stands 0.020 m proud of the -Z wall face beside the -X jamb")
	_expect_fail(res, "frame_proud", "stands 0.020 m proud of the +Z wall face beside the +X jamb")


func test_frame_collider_narrowing_the_opening_fails() -> void:
	if not _prefab_ok():
		return
	# jamb colliders' inner faces 0.42 m from the centre: 2.8 cm inside the 0.896 m leaf on each side
	var res: Dictionary = await _case(door_visual(WALL_T, 0.42))
	_expect_fail(res, "frame_proud", "narrows the clear opening by 0.028 m")
	assert_false(str(res.get("frame_proud", [])).contains("proud of"), "flush depth: no proud issue")


func test_catalog_door_frame_is_flush() -> void:
	if not _prefab_ok():
		return
	# the Glasshouse LobbyDoor visual in a matching t20 opening: flush rounded jambs, no gap / clip
	_expect_only(await _case(load(CATALOG_DOOR) as PackedScene), [])
