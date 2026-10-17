## validate_level `bag_line` (OF-C3) with the real ENV A security_camera prefab on the good fixture: a bag-carry
## line across room A (z 6.0, x 1..7) must be camera-free in each camera layout it is required in. Camera CA
## (room A's mid wall, looking W) sees it; CB (room B) does not.
extends LcTestBase

const CAM_PREFAB: String = "res://systems/prefabs/security_camera/security_camera.tscn"
const CAM_A: Array = ["CA", Vector3(7.9, 2.6, 1.5), Vector3(0.4, 1.0, 4.0)]
const CAM_B: Array = ["CB", Vector3(8.1, 2.6, 6.5), Vector3(15.6, 1.0, 4.0)]
const ONLY: PackedStringArray = ["bag_line"]


func _prefab_ok() -> bool:
	if not ResourceLoader.exists(CAM_PREFAB):
		skip("ENV A security_camera prefab not present")
		return false
	return true


## layouts: { slot_id: [CAM_*, ...] } under Variants/Group_camera; metas: on the line (null = no line).
func _case(layouts: Dictionary, metas: Variant) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var grp: Node3D = Node3D.new()
		grp.name = "Group_camera"
		m.get_node("Variants").add_child(grp)
		for lid: String in layouts:
			var slot: VariantSlot = VariantSlot.new()
			slot.name = "Slot_" + lid
			slot.slot_group = &"camera"
			slot.slot_id = StringName(lid)
			grp.add_child(slot)
			for cd: Array in layouts[lid]:
				var cam: Node3D = (load(CAM_PREFAB) as PackedScene).instantiate() as Node3D
				cam.name = "Camera" + String(cd[0])
				cam.set_meta(&"camera_id", cd[0])
				cam.set_meta(&"mount", "wall")
				cam.transform = Transform3D(Basis.looking_at((cd[2] as Vector3) - (cd[1] as Vector3), Vector3.UP), cd[1])
				slot.add_child(cam)
		if metas is Dictionary:
			var path: Path3D = Path3D.new()
			path.name = "BagLineA"
			path.curve = Curve3D.new()
			path.curve.add_point(Vector3(1.0, 0.0, 6.0))
			path.curve.add_point(Vector3(7.0, 0.0, 6.0))
			for k: String in metas:
				path.set_meta(StringName(k), metas[k])
			m.get_node("Gameplay").add_child(path), false, ONLY)


func test_unconfigured_map_skips() -> void:
	var res: Dictionary = await _case({}, null)
	assert_false(res.has("bag_line"), "bag_line skipped without a line: %s" % [res])


func test_line_seen_in_one_layout_fails_that_layout_only() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case({"cam_a": [CAM_A], "cam_b": [CAM_B]}, {"bag_line": "vault_e1"})
	_expect_only(res, ["bag_line"])
	_expect_fail(res, "bag_line", "bag line `vault_e1` is seen in layout `cam_a` by camera CA")
	assert_eq((res["bag_line"] as PackedStringArray).size(), 1, "only cam_a fails: %s" % [res])


func test_line_required_only_in_the_free_layout_passes() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case({"cam_a": [CAM_A], "cam_b": [CAM_B]},
		{"bag_line": "vault_e1", "bag_line_layouts": PackedStringArray(["cam_b"])})
	_expect_only(res, [])
	assert_true(res.has("bag_line"), "bag_line ran: %s" % [res])


func test_unknown_layout_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case({"cam_a": [CAM_B]}, {"bag_line": true, "bag_line_layouts": "cam_z"})
	_expect_fail(res, "bag_line", "unknown camera layout `cam_z`")
