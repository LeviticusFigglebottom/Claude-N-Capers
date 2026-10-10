## orientation (final): flush wall items, upright props, `faces` links, chairs/monitors,
## plumbing against walls, doors swinging into rooms (level_standards §3.3).
class_name LcCheckOrientation
extends LcCheck

const FLUSH_DOT: float = 0.999
const UPRIGHT_DOT: float = 0.999
const FACES_TOL_DEG: float = 20.0
const CHAIR_DESK_RADIUS: float = 1.0
const PLUMBING_KINDS: Array[StringName] = [&"toilet", &"sink", &"urinal"]
const PLUMBING_WALL_GAP: float = 0.15
const SEAT_TARGET_KINDS: Array[StringName] = [&"desk", &"table", &"counter_service", &"counter_transaction",
	&"workbench", &"console"]


func _init() -> void:
	id = &"orientation"
	title = "Flush and oriented"
	stages = PackedStringArray(["final"])


func run(ctx: LcContext) -> void:
	for p: LcProp in ctx.props:
		if not ctx.is_active(p.node) or not p.has_geometry:
			continue
		var b: Basis = p.xform.basis.orthonormalized()
		if p.mount == &"wall":
			_check_wall(ctx, p, b)
		elif p.mount == &"ceiling":
			if b.y.dot(Vector3.UP) < UPRIGHT_DOT:
				fail(ctx, p.node, null, "ceiling item not level (up . Y = %.4f)" % b.y.dot(Vector3.UP))
		elif not LcUtil.meta_b(p.node, &"tilted") and b.y.dot(Vector3.UP) < UPRIGHT_DOT:
			fail(ctx, p.node, null, "not upright (up . Y = %.4f); set meta tilted=true if deliberate"
				% b.y.dot(Vector3.UP))
		if p.node.has_meta(&"faces"):
			_check_faces(ctx, p)
		elif p.kind == &"chair":
			_check_lonely_chair(ctx, p)
		elif p.kind == &"monitor" or p.kind == &"tv":
			warn(ctx, p.node, null, "%s without a `faces` link (should face its chair/seating)" % p.kind)
		if p.kind in PLUMBING_KINDS:
			_check_plumbing(ctx, p, b)
	for d: Node3D in ctx.doors:
		if ctx.is_active(d):
			_check_door_side(ctx, d)


func _check_wall(ctx: LcContext, p: LcProp, b: Basis) -> void:
	var back: Vector3 = b.z
	var hit: Dictionary = ctx.ray(p.xform.origin - back * 0.05, p.xform.origin + back * 0.5,
		func(h: Dictionary) -> bool: return ctx.prop_of(h.get("collider")) != p and ctx.accept_any_active(h))
	if hit.is_empty():
		return  # floating check reports it
	var nrm: Vector3 = hit["normal"]
	var d: float = nrm.dot(-back)
	if d < FLUSH_DOT:
		fail(ctx, p.node, null, "wall item not flush/facing into the room (normal . -Z = %.4f, need >= %.3f)"
			% [d, FLUSH_DOT])


static func yaw_error_deg(from_xf: Transform3D, target: Vector3) -> float:
	var fwd: Vector3 = -from_xf.basis.z
	var to: Vector3 = target - from_xf.origin
	var f2: Vector2 = Vector2(fwd.x, fwd.z)
	var t2: Vector2 = Vector2(to.x, to.z)
	if f2.length() < 1e-6 or t2.length() < 1e-6:
		return 0.0
	return rad_to_deg(absf(f2.angle_to(t2)))


func _check_faces(ctx: LcContext, p: LcProp) -> void:
	var path: NodePath = NodePath(str(p.node.get_meta(&"faces")))
	var t: Node3D = p.node.get_node_or_null(path) as Node3D
	if t == null:
		fail(ctx, p.node, null, "meta faces `%s` does not resolve to a Node3D" % path)
		return
	var tp: LcProp = ctx.prop_of(t)
	var target: Vector3 = tp.center() if tp != null else t.global_position
	var tol: float = float(p.node.get_meta(&"faces_tolerance_deg", FACES_TOL_DEG))
	var err: float = yaw_error_deg(p.xform, target)
	if err > tol:
		fail(ctx, p.node, null, "faces `%s` %.1f deg off (tolerance %.0f)" % [ctx.node_path(t), err, tol])


func _check_lonely_chair(ctx: LcContext, p: LcProp) -> void:
	for o: LcProp in ctx.props_of_kind(SEAT_TARGET_KINDS):
		if LcGeom.aabb_gap(o.global_aabb, p.global_aabb) <= CHAIR_DESK_RADIUS:
			fail(ctx, p.node, null, "chair within %.1f m of `%s` has no `faces` link"
				% [CHAIR_DESK_RADIUS, ctx.node_path(o.node)])
			return


func _check_plumbing(ctx: LcContext, p: LcProp, b: Basis) -> void:
	var back_pt: Vector3 = p.xform * Vector3(0.0, 0.3, p.local_aabb.end.z)
	var hit: Dictionary = ctx.ray(back_pt - b.z * 0.02, back_pt + b.z * PLUMBING_WALL_GAP, ctx.accept_shell)
	if hit.is_empty():
		fail(ctx, p.node, null, "%s must stand with its back against a wall (none within %.2f m)"
			% [p.kind, PLUMBING_WALL_GAP])


## Door must open into a room, not a corridor (unless meta fire_exit = true).
func _check_door_side(ctx: LcContext, d: Node3D) -> void:
	if LcUtil.meta_b(d, &"fire_exit"):
		return
	var side: String = String(LcUtil.meta_s(d, &"swing_side"))
	if side == "both" or ("swing" in d and int(d.get("swing")) == 2):
		return
	var leaf: Node3D = d.find_child("Leaf", true, false) as Node3D
	if leaf == null:
		return
	var sg: float = -1.0 if side == "back" else 1.0
	var probe: Vector3 = leaf.global_position + (-leaf.global_basis.z.normalized()) * sg * 0.6 + Vector3.UP
	var room: RoomVolume = ctx.room_at(probe)
	if room != null and room.purpose == &"corridor":
		fail(ctx, d, null, "door swings into corridor `%s` (doors open into rooms unless meta fire_exit)"
			% ctx.node_path(room))
