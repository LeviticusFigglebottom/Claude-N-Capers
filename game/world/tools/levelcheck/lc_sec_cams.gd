## Security-camera layout helpers for the camera_spine / camera_screen checks (D-075). Owner: ENV C.
## Map configuration (HeistMap node metadata; a map without it skips both checks):
##   camera_layout_group  String/StringName, optional: VariantSlot slot_group whose slot_ids are the
##                        camera layouts (default "camera"). Without slots of that group the map has
##                        one static layout (every camera enabled).
##   camera_spine_rooms   PackedStringArray: the room_ids of the two back-of-house corridors.
##   camera_screen_slots  PackedStringArray: loot VariantSlot slot_ids that need a partition screen.
## Cameras: SecurityCamera instances (or nodes with meta kind = "security_camera"), outermost only.
## Cone = the runtime one (security_camera.gd + StealthDirector S2.6): a 3D cone of half angle
## fov_deg / 2 around the Lens -Z, out to range_m, swept over the pan arc (pan_deg) about world up.
class_name LcSecCams
extends RefCounted

const DEFAULT_GROUP: StringName = &"camera"
const META_GROUP: StringName = &"camera_layout_group"
const META_SPINE: StringName = &"camera_spine_rooms"
const META_SCREEN: StringName = &"camera_screen_slots"
const SCREEN_KIND: StringName = &"partition_screen"
const STATIC_LAYOUT: StringName = &"(static)"
## Pan arc sample spacing (degrees).
const PAN_STEP_DEG: float = 5.0


static func layout_group(map: HeistMap) -> StringName:
	if map.has_meta(META_GROUP) and str(map.get_meta(META_GROUP)) != "":
		return StringName(str(map.get_meta(META_GROUP)))
	return DEFAULT_GROUP


static func meta_list(map: HeistMap, key: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not map.has_meta(key):
		return out
	var v: Variant = map.get_meta(key)
	if v is String or v is StringName:
		out = str(v).split(",", false)
	elif v is Array or v is PackedStringArray:
		for e: Variant in v:
			out.append(str(e).strip_edges())
	return out


## Layout values: the sorted slot_ids of the layout group, or [STATIC_LAYOUT] when it has no slots.
static func layouts(ctx: LcContext) -> Array[StringName]:
	var g: StringName = layout_group(ctx.map)
	var out: Array[StringName] = []
	for s: VariantSlot in ctx.variant_slots():
		if s.slot_group == g and not out.has(s.slot_id):
			out.append(s.slot_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	if out.is_empty():
		out.append(STATIC_LAYOUT)
	return out


## True when no layout-group VariantSlot above `n` holds another layout (other groups count as on).
static func enabled_in(ctx: LcContext, n: Node, layout: StringName) -> bool:
	var g: StringName = layout_group(ctx.map)
	var cur: Node = n
	while cur != null and cur != ctx.map:
		var vs: VariantSlot = cur as VariantSlot
		if vs != null and vs.slot_group == g and vs.slot_id != layout:
			return false
		cur = cur.get_parent()
	return true


static func is_camera(n: Node) -> bool:
	return n is SecurityCamera or LcUtil.meta_s(n, &"kind") == &"security_camera"


## Every security camera in the map (outermost nodes), tree order.
static func cameras(ctx: LcContext) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in ctx.map.find_children("*", "Node3D", true, false):
		if not is_camera(n):
			continue
		var par: Node = n.get_parent()
		var nested: bool = false
		while par != null and par != ctx.map:
			if is_camera(par):
				nested = true
				break
			par = par.get_parent()
		if not nested:
			out.append(n as Node3D)
	return out


static func cameras_in_layout(ctx: LcContext, layout: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c: Node3D in cameras(ctx):
		if enabled_in(ctx, c, layout):
			out.append(c)
	return out


## Display name: meta camera_id, else the node name.
static func cam_name(c: Node) -> String:
	var cid: StringName = LcUtil.meta_s(c, &"camera_id")
	return String(cid) if cid != &"" else String(c.name)


static func eye(c: Node3D) -> Vector3:
	if c.has_method(&"eye_position"):
		return c.call(&"eye_position")
	return c.global_position


static func forward(c: Node3D) -> Vector3:
	if c.has_method(&"look_forward"):
		return c.call(&"look_forward")
	var f: Vector3 = -c.global_basis.z
	return f.normalized() if f.length_squared() > 0.000001 else Vector3.FORWARD


static func fov_deg(c: Node) -> float:
	return float(c.get(&"fov_deg")) if &"fov_deg" in c else 60.0


static func range_m(c: Node) -> float:
	return float(c.get(&"range_m")) if &"range_m" in c else 20.0


static func pan_deg(c: Node) -> float:
	return float(c.get(&"pan_deg")) if &"pan_deg" in c else 0.0


## View directions over the pan arc (rest pose first).
static func pan_dirs(c: Node3D) -> Array[Vector3]:
	var f: Vector3 = forward(c)
	var out: Array[Vector3] = [f]
	var half: float = pan_deg(c) * 0.5
	if half <= 0.0:
		return out
	var n: int = maxi(1, ceili(half / PAN_STEP_DEG))
	for i: int in range(1, n + 1):
		var a: float = deg_to_rad(half * float(i) / float(n))
		out.append(Basis(Vector3.UP, a) * f)
		out.append(Basis(Vector3.UP, -a) * f)
	return out


## True when point p is inside the camera's cone (range + half angle) for some pan direction.
static func in_cone(c: Node3D, dirs: Array[Vector3], p: Vector3) -> bool:
	var e: Vector3 = eye(c)
	var to: Vector3 = p - e
	if to.length() > range_m(c):
		return false
	if to.length_squared() < 0.000001:
		return true
	var half: float = deg_to_rad(fov_deg(c) * 0.5)
	for d: Vector3 in dirs:
		if d.angle_to(to) <= half:
			return true
	return false


## Room the camera watches from: the room just in front of its eye (wall mounts sit on the room
## box face), else the room at the eye.
static func camera_room(ctx: LcContext, c: Node3D) -> RoomVolume:
	var e: Vector3 = eye(c)
	var f: Vector3 = forward(c)
	var flat: Vector3 = Vector3(f.x, 0.0, f.z)
	if flat.length_squared() > 0.0001:
		var r: RoomVolume = ctx.room_at(e + flat.normalized() * 0.3)
		if r != null:
			return r
	return ctx.room_at(e)


## Smallest room containing p, grown by `grow` m (wall-hung slots sit on the box face).
static func room_near(ctx: LcContext, p: Vector3, grow: float) -> RoomVolume:
	var r: RoomVolume = ctx.room_at(p)
	if r != null:
		return r
	var best_area: float = INF
	for rv: RoomVolume in ctx.rooms:
		if LcAreas.contains(rv, p, grow):
			var ar: float = LcAreas.footprint(rv)
			if ar < best_area:
				best_area = ar
				r = rv
	return r


static func room_by_id(ctx: LcContext, room_id: StringName) -> RoomVolume:
	for r: RoomVolume in ctx.rooms:
		if r.room_id == room_id:
			return r
	return null


## Boxes of the renderable / collision geometry under `root` (itself included):
## [{ "xf": Transform3D (global), "aabb": AABB (local) }].
static func geometry_boxes(root: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for n: Node in nodes:
		if not (n is Node3D):
			continue
		var box: Variant = LcVisual.geometry_local_aabb(n)
		if box is AABB:
			out.append({"xf": (n as Node3D).global_transform, "aabb": box})
		var cs: CollisionShape3D = n as CollisionShape3D
		if cs != null and not cs.disabled and cs.shape != null and not (cs.get_parent() is Area3D):
			out.append({"xf": cs.global_transform, "aabb": cs.shape.get_debug_mesh().get_aabb()})
	return out


## True when the segment a -> b crosses one of the boxes.
static func segment_hits(boxes: Array[Dictionary], a: Vector3, b: Vector3) -> bool:
	for bx: Dictionary in boxes:
		var inv: Transform3D = (bx["xf"] as Transform3D).affine_inverse()
		if (bx["aabb"] as AABB).intersects_segment(inv * a, inv * b) != null:
			return true
	return false
