## camera_spine (all stages, D-075): no camera layout watches both back-of-house corridors.
## Configured by HeistMap meta `camera_spine_rooms` (two RoomVolume room_ids; see LcSecCams), else
## skipped. For every layout (slot_id of the `camera_layout_group` VariantSlots, default `camera`;
## every layout regardless of --variants) the enabled security cameras (not inside a slot of that
## group holding another layout) are tested against each corridor: a camera covers a corridor when
## any sample point of the room (0.5 m floor grid, 0.9 m and 1.5 m up) is inside its cone (range_m,
## fov_deg as a 3D cone, swept over pan_deg) with a clear line from the Lens (building shell only:
## walls, closed doors, windows). FAIL when one layout covers both, naming the layout and a camera
## per corridor.
class_name LcCheckCameraSpine
extends LcCheck

const GRID_STEP: float = 0.5
const SAMPLE_HEIGHTS: Array[float] = [0.9, 1.5]


func _init() -> void:
	id = &"camera_spine"
	title = "Camera layouts never watch both back-of-house corridors (D-075)"


func run(ctx: LcContext) -> void:
	var ids: PackedStringArray = LcSecCams.meta_list(ctx.map, LcSecCams.META_SPINE)
	if ids.is_empty():
		skipped_reason = "not configured (no HeistMap meta `camera_spine_rooms`)"
		return
	if ids.size() != 2:
		fail(ctx, ctx.map, null, "`camera_spine_rooms` must list exactly 2 room_ids, got %d: %s" % [ids.size(), ", ".join(ids)])
		return
	var rooms: Array[RoomVolume] = []
	for rid: String in ids:
		var r: RoomVolume = LcSecCams.room_by_id(ctx, StringName(rid))
		if r == null:
			fail(ctx, ctx.map, null, "`camera_spine_rooms`: no RoomVolume with room_id `%s`" % rid)
		rooms.append(r)
	if rooms.has(null):
		return
	var samples: Array[PackedVector3Array] = [_samples(rooms[0]), _samples(rooms[1])]
	var coverage: Dictionary = {}  # camera instance id -> [bool, bool]
	var group: StringName = LcSecCams.layout_group(ctx.map)
	for layout: StringName in LcSecCams.layouts(ctx):
		var cams: Array[Node3D] = LcSecCams.cameras_in_layout(ctx, layout)
		var names_a: PackedStringArray = PackedStringArray()
		var names_b: PackedStringArray = PackedStringArray()
		for c: Node3D in cams:
			var key: int = c.get_instance_id()
			if not coverage.has(key):
				coverage[key] = [_covers(ctx, c, samples[0]), _covers(ctx, c, samples[1])]
			var cov: Array = coverage[key]
			if bool(cov[0]):
				names_a.append(LcSecCams.cam_name(c))
			if bool(cov[1]):
				names_b.append(LcSecCams.cam_name(c))
		var by_room: Array[PackedStringArray] = [names_a, names_b]
		var line: PackedStringArray = PackedStringArray()
		for i: int in range(2):
			line.append("`%s` %s" % [ids[i], ", ".join(by_room[i]) if not by_room[i].is_empty() else "free"])
		note("layout `%s` (%d camera(s)): %s" % [layout, cams.size(), "; ".join(line)])
		if not by_room[0].is_empty() and not by_room[1].is_empty():
			var where: Node = _layout_node(ctx, group, layout)
			fail(ctx, where, null, "layout `%s` watches both back-of-house corridors: `%s` by camera %s and `%s` by camera %s"
				% [layout, ids[0], by_room[0][0], ids[1], by_room[1][0]])


static func _samples(room: RoomVolume) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in LcAreas.floor_grid(room, GRID_STEP):
		for h: float in SAMPLE_HEIGHTS:
			out.append(p + Vector3.UP * h)
	return out


## True when the camera's cone reaches any of the room's sample points with a clear shell line.
static func _covers(ctx: LcContext, c: Node3D, pts: PackedVector3Array) -> bool:
	var dirs: Array[Vector3] = LcSecCams.pan_dirs(c)
	var e: Vector3 = LcSecCams.eye(c)
	for p: Vector3 in pts:
		if LcSecCams.in_cone(c, dirs, p) and ctx.ray(e, p, ctx.accept_shell).is_empty():
			return true
	return false


static func _layout_node(ctx: LcContext, group: StringName, layout: StringName) -> Node:
	for s: VariantSlot in ctx.variant_slots():
		if s.slot_group == group and s.slot_id == layout:
			return s
	return ctx.map
