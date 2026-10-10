## validate_level door-size regressions with the real ENV A door prefab (lock / width_m / visuals).
## The prefab is loaded by path at runtime (tests only); skipped if ENV A's prefab is absent.
extends LcTestBase

const DOOR_PREFAB: String = "res://systems/prefabs/door/door.tscn"
const LOCK_VAULT: int = 6


## Visual scene satisfying visual_slots.md `door`: Frame + Leaf (hinge pivot) with a w x h panel.
static func leaf_visual(w: float, h: float) -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "TestDoorVisual"
	var frame: Node3D = Node3D.new()
	frame.name = "Frame"
	root.add_child(frame)
	frame.owner = root
	var leaf: Node3D = Node3D.new()
	leaf.name = "Leaf"
	leaf.position = Vector3(-w * 0.5, 0.0, 0.0)
	root.add_child(leaf)
	leaf.owner = root
	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.name = "Panel"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(w, h, 0.05)
	panel.mesh = bm
	panel.position = Vector3(w * 0.5, h * 0.5, 0.0)
	leaf.add_child(panel)
	panel.owner = root
	var handle: Marker3D = Marker3D.new()
	handle.name = "Handle"
	handle.position = Vector3(w - 0.1, 1.0, -0.06)
	leaf.add_child(handle)
	handle.owner = root
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


## Adds a real door prefab far from the fixture building and returns scale failures.
func _door_case(lock: int, width_m: float, visual: PackedScene) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var door: Node3D = (load(DOOR_PREFAB) as PackedScene).instantiate() as Node3D
		door.name = "TestDoor"
		door.set(&"lock", lock)
		door.set(&"width_m", width_m)
		if visual != null:
			door.set(&"visual_scene", visual)
		door.position = Vector3(40.0, 0.0, 0.0)
		m.get_node("Gameplay").add_child(door)
		door.owner = m, false, ["scale"])


func _prefab_ok() -> bool:
	if not ResourceLoader.exists(DOOR_PREFAB):
		skip("ENV A door prefab not present")
		return false
	return true


func test_prefab_vault_door_with_narrow_leaf_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _door_case(LOCK_VAULT, 1.1, leaf_visual(1.1, 2.1))
	_expect_fail(res, "scale", "TestDoor")
	_expect_fail(res, "scale", "vault")


func test_prefab_vault_door_2m2_passes() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _door_case(LOCK_VAULT, 2.2, leaf_visual(2.2, 2.2))
	_expect_only(res, [])


func test_prefab_narrow_single_door_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _door_case(0, 0.7, leaf_visual(0.7, 2.1))
	_expect_fail(res, "scale", "door width 0.700")


func test_prefab_placeholder_with_mismatched_width_m_fails() -> void:
	if not _prefab_ok():
		return
	# No visual: the 0.9 m placeholder leaf is measured, but the gameplay opening is 0.7 m.
	var res: Dictionary = await _door_case(0, 0.7, null)
	_expect_fail(res, "scale", "width_m 0.700")


func test_prefab_default_single_door_passes() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _door_case(0, 0.0, null)
	_expect_only(res, [])
