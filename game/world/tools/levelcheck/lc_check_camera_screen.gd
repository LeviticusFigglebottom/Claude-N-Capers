## camera_screen (all stages, D-075): every listed loot slot is screened from its room's camera.
## Configured by HeistMap meta `camera_screen_slots` (VariantSlot slot_ids; see LcSecCams), else
## skipped. Slot centre: centre of the slot's authored geometry (children meshes/colliders), else the
## slot origin. Slot room: the smallest RoomVolume containing the centre (0.3 m tolerance for
## wall-hung slots). For every layout and every camera enabled in it whose room (just in front of
## the Lens) is the slot's room, the segment Lens -> slot centre must cross the geometry (meshes or
## colliders) of a node with meta kind = "partition_screen" that is enabled in that layout.
## FAIL names the slot and the camera (and the layouts). A slot whose room has no camera passes.
class_name LcCheckCameraScreen
extends LcCheck

const SLOT_ROOM_GROW: float = 0.3


func _init() -> void:
	id = &"camera_screen"
	title = "Listed loot slots have a partition screen between them and their room's camera (D-075)"


func run(ctx: LcContext) -> void:
	var ids: PackedStringArray = LcSecCams.meta_list(ctx.map, LcSecCams.META_SCREEN)
	if ids.is_empty():
		skipped_reason = "not configured (no HeistMap meta `camera_screen_slots`)"
		return
	var screens: Array[Node] = []
	for n: Node in ctx.map.find_children("*", "", true, false):
		if LcUtil.meta_s(n, &"kind") == LcSecCams.SCREEN_KIND:
			screens.append(n)
	var screen_boxes: Dictionary = {}  # instance id -> boxes
	for s: Node in screens:
		screen_boxes[s.get_instance_id()] = LcSecCams.geometry_boxes(s)
	var layouts: Array[StringName] = LcSecCams.layouts(ctx)
	note("%d partition screen(s), %d layout(s)" % [screens.size(), layouts.size()])
	for sid: String in ids:
		var slot: VariantSlot = _slot(ctx, StringName(sid))
		if slot == null:
			fail(ctx, ctx.map, null, "`camera_screen_slots`: no VariantSlot with slot_id `%s`" % sid)
			continue
		var centre: Vector3 = _centre(slot)
		var room: RoomVolume = LcSecCams.room_near(ctx, centre, SLOT_ROOM_GROW)
		if room == null:
			fail(ctx, slot, centre, "slot `%s` is in no RoomVolume (cannot find its room's camera)" % sid)
			continue
		# camera instance id -> { "cam": Node3D, "bad": Array (layouts), "ok": Array (layouts) }
		var per_cam: Dictionary = {}
		for layout: StringName in layouts:
			for c: Node3D in LcSecCams.cameras_in_layout(ctx, layout):
				if LcSecCams.camera_room(ctx, c) != room:
					continue
				var key: int = c.get_instance_id()
				if not per_cam.has(key):
					per_cam[key] = {"cam": c, "bad": [], "ok": []}
				var screened: bool = false
				for s2: Node in screens:
					if LcSecCams.enabled_in(ctx, s2, layout) and LcSecCams.segment_hits(
							screen_boxes[s2.get_instance_id()], LcSecCams.eye(c), centre):
						screened = true
						break
				(per_cam[key]["ok" if screened else "bad"] as Array).append(String(layout))
		if per_cam.is_empty():
			note("slot `%s` (room `%s`): no camera in its room in any layout" % [sid, room.room_id])
			continue
		for k: Variant in per_cam:
			var e: Dictionary = per_cam[k]
			var cam: Node3D = e["cam"]
			var bad: PackedStringArray = PackedStringArray(e["bad"])
			var ok: PackedStringArray = PackedStringArray(e["ok"])
			if bad.is_empty():
				note("slot `%s` (room `%s`): screened from camera %s in %s" % [sid, room.room_id,
					LcSecCams.cam_name(cam), ", ".join(ok)])
			else:
				fail(ctx, slot, centre, "slot `%s` has no partition screen between it and camera %s (`%s`, room `%s`) in layout(s) %s"
					% [sid, LcSecCams.cam_name(cam), ctx.node_path(cam), room.room_id, ", ".join(bad)])


static func _slot(ctx: LcContext, slot_id: StringName) -> VariantSlot:
	for s: VariantSlot in ctx.variant_slots():
		if s.slot_id == slot_id:
			return s
	return null


## Centre of the slot's authored geometry, else its origin.
static func _centre(slot: VariantSlot) -> Vector3:
	var box: AABB = AABB()
	var first: bool = true
	for c: Node in slot.get_children():
		for b: Dictionary in LcSecCams.geometry_boxes(c):
			var w: AABB = (b["xf"] as Transform3D) * (b["aabb"] as AABB)
			box = w if first else box.merge(w)
			first = false
	return slot.global_position if first else box.get_center()
