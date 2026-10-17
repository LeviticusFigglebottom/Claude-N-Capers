## bag_line (all stages, OF-C3): a marked bag-carry line is camera-free in every camera layout it must be free in.
## Opt-in: nodes with meta `bag_line` (a String name, or true for the node name), else the check is skipped. A line
## is an LcLines marked line at the carrier's feet (Path3D, Marker3D chain or one Marker3D), sampled every 0.5 m.
## Metas on the line:
##   bag_line_layouts  optional layout slot_ids it must be free in (default: every layout of the map's camera layout
##                     group, as camera_spine: HeistMap meta `camera_layout_group`, default `camera`).
##   bag_line_posture  "stand" (default) or "crouch": the carrier's runtime detection points (LcLines).
## Cameras and cones are camera_spine's (LcSecCams: SecurityCamera instances, enabled per layout, a 3D cone of
## fov_deg / range_m swept over pan_deg); a camera sees a point when it is in the cone with a clear building-shell
## line from the Lens (walls, closed doors, windows; props do not block: conservative). FAIL per line and layout,
## naming the first camera and the seen sample count.
class_name LcCheckBagLine
extends LcCheck

const META: StringName = &"bag_line"
const STEP: float = 0.5


func _init() -> void:
	id = &"bag_line"
	title = "Bag-carry lines are camera-free per camera layout (OF-C3)"


func run(ctx: LcContext) -> void:
	var lines: Array[Node3D] = []
	for n: Node in ctx.map.find_children("*", "Node3D", true, false):
		if n.has_meta(META) and str(n.get_meta(META)) not in ["", "false"] and ctx.is_active(n):
			lines.append(n as Node3D)
	if lines.is_empty():
		skipped_reason = "not configured (no node with meta `bag_line`)"
		return
	var all_layouts: Array[StringName] = LcSecCams.layouts(ctx)
	var cache: Dictionary = {}  # "camera id|line id" -> [seen count, first point]
	for ln: Node3D in lines:
		_check_line(ctx, ln, all_layouts, cache)


static func line_name(n: Node) -> String:
	var v: String = str(n.get_meta(META))
	return String(n.name) if v == "true" else v


func _check_line(ctx: LcContext, ln: Node3D, all_layouts: Array[StringName], cache: Dictionary) -> void:
	var nm: String = line_name(ln)
	var want: Array[StringName] = []
	var known: PackedStringArray = PackedStringArray()
	for l: StringName in all_layouts:
		known.append(String(l))
	for lid: String in LcLines.meta_strings(ln, &"bag_line_layouts"):
		if not all_layouts.has(StringName(lid)):
			fail(ctx, ln, null, "bag line `%s`: unknown camera layout `%s` (layouts: %s)" % [nm, lid, ", ".join(known)])
			continue
		want.append(StringName(lid))
	if want.is_empty():
		want = all_layouts
	var crouched: bool = String(LcUtil.meta_s(ln, &"bag_line_posture")).to_lower() in ["crouch", "crouched"]
	var heights: Array[float] = LcLines.detection_heights(crouched)
	var pts: PackedVector3Array = LcLines.samples(LcLines.vertices(ln), STEP)
	var free: PackedStringArray = PackedStringArray()
	for layout: StringName in want:
		var first_cam: String = ""
		var first_pt: Vector3 = Vector3.ZERO
		var seen_n: int = 0
		for c: Node3D in LcSecCams.cameras_in_layout(ctx, layout):
			if not ctx.is_active(c):
				continue
			var key: String = "%d|%d" % [c.get_instance_id(), ln.get_instance_id()]
			if not cache.has(key):
				cache[key] = _seen(ctx, c, pts, heights)
			var r: Array = cache[key]
			if int(r[0]) > seen_n:
				seen_n = int(r[0])
				first_cam = LcSecCams.cam_name(c)
				first_pt = r[1]
		if first_cam == "":
			free.append(String(layout))
		else:
			fail(ctx, ln, first_pt, "bag line `%s` is seen in layout `%s` by camera %s (%d of %d sample(s); first at %s)"
				% [nm, layout, first_cam, seen_n, pts.size(), fmt_v(first_pt)])
	note("bag line `%s` (`%s`, %d sample(s)): camera-free in %s" % [nm, ctx.node_path(ln), pts.size(),
		", ".join(free) if not free.is_empty() else "no layout"])


## [samples seen, first seen detection point].
static func _seen(ctx: LcContext, c: Node3D, pts: PackedVector3Array, heights: Array[float]) -> Array:
	var dirs: Array[Vector3] = LcSecCams.pan_dirs(c)
	var e: Vector3 = LcSecCams.eye(c)
	var n: int = 0
	var first: Vector3 = Vector3.ZERO
	for q: Vector3 in pts:
		for h: float in heights:
			var t: Vector3 = q + Vector3.UP * h
			if LcSecCams.in_cone(c, dirs, t) and ctx.ray(e, t, ctx.accept_shell).is_empty():
				if n == 0:
					first = t
				n += 1
				break
	return [n, first]
