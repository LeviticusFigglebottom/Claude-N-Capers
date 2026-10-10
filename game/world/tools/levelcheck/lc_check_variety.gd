## variety (final): rooms dressed with the same kit must not share a layout. Layout hash =
## sorted (kind, room-local position quantised to 0.25 m, yaw quantised to 15 deg) of the props
## inside the room, relative to the room's first box transform.
class_name LcCheckVariety
extends LcCheck

const POS_Q: float = 0.25
const YAW_Q_DEG: float = 15.0


func _init() -> void:
	id = &"variety"
	title = "Layout variety"
	stages = PackedStringArray(["final"])


static func layout_hash(ctx: LcContext, r: RoomVolume) -> String:
	var boxes: Array[Dictionary] = LcAreas.boxes(r)
	if boxes.is_empty():
		return ""
	var xf: Transform3D = boxes[0]["xf"]
	var origin_xf: Transform3D = Transform3D(xf.basis.orthonormalized(), xf * (boxes[0]["aabb"] as AABB).position)
	var inv: Transform3D = origin_xf.affine_inverse()
	var items: PackedStringArray = PackedStringArray()
	for p: LcProp in LcCheckDensity.props_in_room(ctx, r):
		var lp: Vector3 = inv * p.center()
		var fwd: Vector3 = inv.basis * (-p.xform.basis.z)
		var yaw: int = posmod(roundi(rad_to_deg(atan2(fwd.x, fwd.z)) / YAW_Q_DEG), int(360.0 / YAW_Q_DEG))
		items.append("%s@%d,%d,%d/%d" % [p.kind, roundi(lp.x / POS_Q), roundi(lp.y / POS_Q), roundi(lp.z / POS_Q), yaw])
	items.sort()
	return ";".join(items).md5_text()


func run(ctx: LcContext) -> void:
	var by_kit: Dictionary = {}
	for r: RoomVolume in ctx.rooms:
		if r.dressing_kit == &"":
			continue
		if not by_kit.has(r.dressing_kit):
			by_kit[r.dressing_kit] = []
		(by_kit[r.dressing_kit] as Array).append(r)
	var kits: Array = by_kit.keys()
	kits.sort()
	for k: StringName in kits:
		var seen: Dictionary = {}
		for r2: RoomVolume in by_kit[k]:
			var h: String = layout_hash(ctx, r2)
			if seen.has(h):
				fail(ctx, r2, null, "same layout as `%s` (kit `%s`); vary the kit seed" % [ctx.node_path(seen[h]), k])
			else:
				seen[h] = r2
		note("kit `%s`: %d room(s), %d distinct layout(s)" % [k, (by_kit[k] as Array).size(), seen.size()])
