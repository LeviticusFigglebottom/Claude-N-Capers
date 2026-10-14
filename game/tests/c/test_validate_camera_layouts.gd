## validate_level `camera_spine` / `camera_screen` (D-075) with the real ENV A security_camera prefab
## on the good fixture: room A (x 0.4..7.9) and room B (x 8.1..15.6) stand in for the two
## back-of-house corridors; the door opening at x 8, z 3.5..4.5 joins them.
extends LcTestBase

const CAM_PREFAB: String = "res://systems/prefabs/security_camera/security_camera.tscn"
## On the mid wall's west face looking W over room A (room B is behind it).
const CAM_A: Array = ["CA", Vector3(7.9, 2.6, 1.5), Vector3(0.4, 1.0, 4.0)]
## On the mid wall's east face looking E over room B.
const CAM_B: Array = ["CB", Vector3(8.1, 2.6, 6.5), Vector3(15.6, 1.0, 4.0)]
## On room A's west wall looking E through the door opening into room B: sees both rooms.
const CAM_DOOR: Array = ["CD", Vector3(0.4, 2.4, 4.0), Vector3(15.0, 1.0, 4.0)]

var only_checks: PackedStringArray = PackedStringArray(["camera_spine", "camera_screen"])


func _prefab_ok() -> bool:
	if not ResourceLoader.exists(CAM_PREFAB):
		skip("ENV A security_camera prefab not present")
		return false
	return true


## layouts: { slot_id: [CAM_*, ...] } under Variants/Group_camera. screen: "" (none), "static"
## (under Props) or a layout slot_id to put it in. spine/screen: configure the HeistMap metas.
func _case(layouts: Dictionary, screen: String, spine: bool, screen_slots: bool) -> Dictionary:
	return await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		var grp: Node3D = Node3D.new()
		grp.name = "Group_camera"
		m.get_node("Variants").add_child(grp)
		var slots: Dictionary = {}
		for lid: String in layouts:
			var slot: VariantSlot = VariantSlot.new()
			slot.name = "Slot_" + lid
			slot.slot_group = &"camera"
			slot.slot_id = StringName(lid)
			grp.add_child(slot)
			slots[lid] = slot
			for cd: Array in layouts[lid]:
				var cam: Node3D = (load(CAM_PREFAB) as PackedScene).instantiate() as Node3D
				cam.name = "Camera" + String(cd[0])
				cam.set_meta(&"camera_id", cd[0])
				cam.set_meta(&"mount", "wall")
				cam.transform = Transform3D(Basis.looking_at((cd[2] as Vector3) - (cd[1] as Vector3), Vector3.UP), cd[1])
				slot.add_child(cam)
		# A canvas hung on room A's west wall.
		var canvas: VariantSlot = VariantSlot.new()
		canvas.name = "CanvasWest"
		canvas.slot_group = &"canvas"
		canvas.slot_id = &"canvas_west"
		canvas.position = Vector3(0.4, 0.0, 4.0)
		m.get_node("Variants").add_child(canvas)
		LcFixtureBuilder.prop(canvas, "Painting", Vector3(0.0, 1.5, 0.0), -90.0, "painting", Vector3(1.0, 0.8, 0.04),
			Vector3(0, 0, -0.02), null, false, {"mount": "wall"})
		if screen != "":
			var parent: Node = m.get_node("Props") if screen == "static" else slots[screen]
			# 2.4 m freestanding wall across the line from CA to the canvas (x 3, z 2..5).
			LcFixtureBuilder.prop(parent, "ScreenA", Vector3(3.0, 0.0, 3.5), 0.0, "partition_screen",
				Vector3(0.1, 2.4, 3.0), Vector3(0, 1.2, 0), null, true)
		if spine:
			m.set_meta(&"camera_spine_rooms", PackedStringArray(["room_a", "room_b"]))
		if screen_slots:
			m.set_meta(&"camera_screen_slots", PackedStringArray(["canvas_west"])), false, only_checks)


func test_unconfigured_map_skips_both() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", Callable(), false, only_checks)
	assert_false(res.has("camera_spine"), "camera_spine skipped without meta: %s" % [res])
	assert_false(res.has("camera_screen"), "camera_screen skipped without meta: %s" % [res])


func test_layouts_each_watching_one_corridor_pass() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case({"cam_a": [CAM_A], "cam_b": [CAM_B]}, "static", true, true)
	_expect_only(res, [])
	assert_true(res.has("camera_spine") and res.has("camera_screen"), "both checks ran: %s" % [res])


func test_layout_watching_both_corridors_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case({"cam_a": [CAM_A], "cam_b": [CAM_B], "cam_c": [CAM_A, CAM_B]}, "static", true, false)
	_expect_only(res, ["camera_spine"])
	_expect_fail(res, "camera_spine", "layout `cam_c` watches both")
	_expect_fail(res, "camera_spine", "`room_a` by camera CA and `room_b` by camera CB")
	assert_eq((res["camera_spine"] as PackedStringArray).size(), 1, "only cam_c fails: %s" % [res])


func test_camera_seeing_through_door_covers_both() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case({"cam_a": [CAM_DOOR], "cam_b": [CAM_B]}, "", true, false)
	_expect_fail(res, "camera_spine", "layout `cam_a` watches both")
	_expect_fail(res, "camera_spine", "camera CD and `room_b` by camera CD")


func test_missing_screen_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case({"cam_a": [CAM_A], "cam_b": [CAM_B]}, "", false, true)
	_expect_only(res, ["camera_screen"])
	_expect_fail(res, "camera_screen", "slot `canvas_west` has no partition screen between it and camera CA")
	_expect_fail(res, "camera_screen", "layout(s) cam_a")


func test_screen_only_in_other_layout_fails() -> void:
	if not _prefab_ok():
		return
	var res: Dictionary = await _case({"cam_a": [CAM_A], "cam_b": [CAM_B]}, "cam_b", false, true)
	_expect_fail(res, "camera_screen", "camera CA")


func test_unknown_ids_fail() -> void:
	var res: Dictionary = await _validate(GOOD, "greybox", func(m: HeistMap) -> void:
		m.set_meta(&"camera_spine_rooms", PackedStringArray(["room_a", "nope"]))
		m.set_meta(&"camera_screen_slots", PackedStringArray(["missing_slot"])), false, only_checks)
	_expect_fail(res, "camera_spine", "no RoomVolume with room_id `nope`")
	_expect_fail(res, "camera_screen", "no VariantSlot with slot_id `missing_slot`")
