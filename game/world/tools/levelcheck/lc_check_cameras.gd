## cameras (all stages): review cameras must sit in open space. For every HeistMap.review_cameras
## entry except TopDown* orthographic shots:
##  * a 0.3 m sphere at the camera position touches no collision (not in or next to a wall);
##  * the camera is inside a RoomVolume (not `plenum`) by >= 0.3 m from the room box's side faces
##    (a camera on a wall line / in a door opening shows cut wall edges and the next room), or
##    outdoors (a ray straight up from it reaches open sky, 200 m);
##  * no frustum centre or corner ray (fov, 16:9) hits geometry within 0.5 m (near-clipped = FAIL);
##  * the camera does not stand in a wall opening: along world X or Z the building shell is less than
##    1.3 m apart across the camera, but 0.4 m in front of / behind that line it widens by >= 0.5 m
##    (a door/window reveal; corridors stay narrow and pass). Exterior rooms skip the inset rule.
class_name LcCheckCameras
extends LcCheck

const CLEAR_R: float = 0.3
const CORNER_RAY: float = 0.5
const SKY_RAY: float = 200.0
## Min horizontal distance from the camera to its RoomVolume's side faces (m).
const ROOM_INSET: float = 0.3
## Opening detection: shell within this total width across the camera (m) ...
const OPENING_MAX_W: float = 1.3
## ... that opens up (by OPENING_GROW) 0.4 m in front of or behind the wall line.
const OPENING_PROBE: float = 0.4
const OPENING_GROW: float = 0.5


func _init() -> void:
	id = &"cameras"
	title = "Review camera placement"


func run(ctx: LcContext) -> void:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = CLEAR_R
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.collision_mask = LcContext.QUERY_MASK
	var n_checked: int = 0
	for np: NodePath in ctx.map.review_cameras:
		var cam: Node3D = ctx.map.get_node_or_null(np) as Node3D
		if cam == null or float(LcCheckPerf.camera_params(cam)["ortho"]) > 0.0:
			continue
		n_checked += 1
		var p: Vector3 = cam.global_position
		q.transform = Transform3D(Basis(), p)
		var blockers: PackedStringArray = PackedStringArray()
		for h: Dictionary in ctx.space().intersect_shape(q, 8):
			if ctx.accept_any_active(h):
				var c: Node = h.get("collider") as Node
				var path: String = ctx.node_path(c) if c != null else "?"
				if not (path in blockers):
					blockers.append(path)
		if not blockers.is_empty():
			blockers.sort()
			fail(ctx, cam, p, "camera within %.1f m of collision (inside/against a wall?): %s" % [CLEAR_R, ", ".join(blockers.slice(0, 3))])
		var room: RoomVolume = ctx.room_at(p)
		if room != null and room.purpose == &"plenum":
			fail(ctx, cam, p, "camera is inside plenum `%s`" % ctx.node_path(room))
		elif room == null and not ctx.ray(p, p + Vector3.UP * SKY_RAY, ctx.accept_any_active).is_empty():
			fail(ctx, cam, p, "camera is neither inside a RoomVolume nor outdoors (wall, plenum or unlisted space?)")
		elif room != null and room.purpose != &"exterior":
			var inset: float = room_inset(room, p)
			if inset < ROOM_INSET:
				fail(ctx, cam, p, "camera only %.2f m inside `%s` (need >= %.1f m; on a wall line or in a door opening?)"
					% [inset, ctx.node_path(room), ROOM_INSET])
		var gap: float = opening_width(ctx, p)
		if gap > 0.0:
			fail(ctx, cam, p, "camera stands in a %.2f m wall opening (door/window reveal): the frame shows cut wall edges" % gap)
		_corner_rays(ctx, cam)
	note("%d perspective review camera(s) checked" % n_checked)


func _corner_rays(ctx: LcContext, cam: Node3D) -> void:
	var cp: Dictionary = LcCheckPerf.camera_params(cam)
	var v: float = deg_to_rad(float(cp["fov"])) * 0.5
	var hz: float = atan(tan(v) * LcCheckPerf.ASPECT)
	var b: Basis = cam.global_basis.orthonormalized()
	var best: float = INF
	var dirs: Array[Vector3] = [-b.z]
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			dirs.append((-b.z + b.x * tan(hz) * sx + b.y * tan(v) * sy).normalized())
	for d: Vector3 in dirs:
		var hit: Dictionary = ctx.ray(cam.global_position, cam.global_position + d * CORNER_RAY, ctx.accept_any_active)
		if not hit.is_empty():
			best = minf(best, cam.global_position.distance_to(hit["position"]))
	if best < INF:
		fail(ctx, cam, null, "a frustum centre/corner ray hits geometry %.2f m from the camera (< %.1f m: near-clipped frame)"
			% [best, CORNER_RAY])


## Horizontal distance from p to the nearest side face of the room box(es) containing it (best box).
static func room_inset(room: RoomVolume, p: Vector3) -> float:
	var best: float = -INF
	for b: Dictionary in LcAreas.boxes(room):
		var xf: Transform3D = b["xf"]
		var box: AABB = b["aabb"]
		var lp: Vector3 = xf.affine_inverse() * p
		if not box.grow(0.01).has_point(lp):
			continue
		var sx: float = xf.basis.x.length()
		var sz: float = xf.basis.z.length()
		var d: float = minf(minf(lp.x - box.position.x, box.end.x - lp.x) * sx, minf(lp.z - box.position.z, box.end.z - lp.z) * sz)
		best = maxf(best, d)
	return best


## Width of the wall opening the camera stands in, or 0 when it is not in one.
static func opening_width(ctx: LcContext, p: Vector3) -> float:
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var w0: float = _span(ctx, p, axis)
		if w0 >= OPENING_MAX_W:
			continue
		var perp: Vector3 = Vector3(axis.z, 0.0, axis.x)
		for s: float in [-1.0, 1.0]:
			if _span(ctx, p + perp * OPENING_PROBE * s, axis) >= w0 + OPENING_GROW:
				return w0
	return 0.0


## Shell distance across p along +-axis (INF when either side is open within 3 m).
static func _span(ctx: LcContext, p: Vector3, axis: Vector3) -> float:
	var total: float = 0.0
	for s: float in [-1.0, 1.0]:
		var hit: Dictionary = ctx.ray(p, p + axis * s * 3.0, ctx.accept_shell)
		if hit.is_empty():
			return INF
		total += p.distance_to(hit["position"])
	return total
