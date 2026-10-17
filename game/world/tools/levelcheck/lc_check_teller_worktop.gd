## teller_worktop (all stages, OF-C3; Ostrander Federal §Ground notes, next_heist_ostrander §7.2): bank teller
## counters. Opt-in by prop meta `kind = "teller_worktop"` (the top height 0.95–1.05 m is the `scale` check's
## PROP_RULES row). Frame: the prop's local box; the teller (user) side is local -Z, the customer side +Z (front -Z,
## as catalog desks). Rules:
##   depth      the box's Z depth 0.45–0.9 m;
##   stand      the teller's stand zone, the worktop width (0.1 m in from each end) x 0.9 m out from the -Z edge x
##              0.05–1.8 m above the floor, is free of colliders other than seats (chairs, stools);
##   hide       with meta `hide_behind = true` (the crouch-hide claim): the solid front, measured by horizontal vision
##              rays from 1.5 m beyond the customer side at three stations across the width (1 cm height steps up from
##              0.05 m; glazing with meta `see_through` or kind window/glass is transparent), must reach
##              h + (1.62 - h) x d / max(hide_min_m, d + 0.35), where h is the top crouched detection point (1.05 m,
##              LcLines), d the distance from the front plane to a crouched crew centre 0.35 m behind the worktop's
##              teller edge, 1.62 the NPC eye and hide_min_m (meta, default 2.0) the closest observer the claim
##              covers (inside it PD2 uncovers a crouched player anyway). The geometry check behind hide_los.
class_name LcCheckTellerWorktop
extends LcCheck

const KIND: StringName = &"teller_worktop"
const DEPTH: Vector2 = Vector2(0.45, 0.9)
const STAND_DEPTH: float = 0.9
const STAND_Y: Vector2 = Vector2(0.05, 1.8)
const STAND_END_INSET: float = 0.1
const SEAT_KINDS: Array[StringName] = [&"chair", &"stool", &"desk_chair", &"seat"]
const FRONT_REACH: float = 1.5
const FRONT_STEP: float = 0.01
const FRONT_MAX: float = 2.4
const CAPSULE_R: float = 0.35
const DEFAULT_MIN: float = 2.0


func _init() -> void:
	id = &"teller_worktop"
	title = "Teller work tops: depth, stand zone, crouch-hide front (OF-C3)"


func run(ctx: LcContext) -> void:
	var tops: Array[LcProp] = ctx.props_of_kind([KIND])
	if tops.is_empty():
		skipped_reason = "not configured (no prop with kind `teller_worktop`)"
		return
	for p: LcProp in tops:
		_check(ctx, p)
	note("%d teller work top(s)" % tops.size())


func _check(ctx: LcContext, p: LcProp) -> void:
	var box: AABB = p.local_aabb
	var xf: Transform3D = Transform3D(p.xform.basis.orthonormalized(), p.xform.origin)
	var fl: Dictionary = ctx.shell_floor(p.node.global_position, 0.5, 1.5)
	var floor_y: float = (fl["position"] as Vector3).y if not fl.is_empty() else p.node.global_position.y
	var ly: float = floor_y - p.xform.origin.y  # floor height in the prop's local frame (upright props)
	if box.size.z < DEPTH.x - 0.005 or box.size.z > DEPTH.y + 0.005:
		fail(ctx, p.node, null, "depth %.2f m outside %.2f–%.2f m" % [box.size.z, DEPTH.x, DEPTH.y])
	var blocker: String = _stand_blocker(ctx, p, xf, box, ly)
	if blocker != "":
		fail(ctx, p.node, null, "teller stand zone (%.1f m behind the -Z edge, 0.05–1.8 m) is blocked by `%s`" % [STAND_DEPTH, blocker])
	if LcUtil.meta_b(p.node, &"hide_behind"):
		_check_front(ctx, p, xf, box, ly)


func _stand_blocker(ctx: LcContext, p: LcProp, xf: Transform3D, box: AABB, ly: float) -> String:
	var w: float = box.size.x - 2.0 * STAND_END_INSET
	if w <= 0.05:
		return ""
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(w, STAND_Y.y - STAND_Y.x, STAND_DEPTH - 0.02)
	var centre: Vector3 = Vector3(box.get_center().x, ly + (STAND_Y.x + STAND_Y.y) * 0.5, box.position.z - 0.01 - shape.size.z * 0.5)
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = LcContext.QUERY_MASK
	q.transform = Transform3D(xf.basis, xf * centre)
	for hit: Dictionary in ctx.space().intersect_shape(q, 16):
		var obj: Node = hit.get("collider") as Node
		if obj == null or obj is Area3D or not ctx.is_active(obj) or p.node == obj or p.node.is_ancestor_of(obj):
			continue
		var other: LcProp = ctx.prop_of(obj)
		if other != null and other.kind in SEAT_KINDS:
			continue
		return ctx.node_path(other.node if other != null else obj)
	return ""


func _check_front(ctx: LcContext, p: LcProp, xf: Transform3D, box: AABB, ly: float) -> void:
	var accept: Callable = LcLines.vision_accept(ctx)
	var h_top: float = LcLines.detection_heights(true).back()
	var min_d: float = LcLines.meta_float(p.node, &"hide_min_m", DEFAULT_MIN)
	var worst_h: float = INF
	var worst_need: float = 0.0
	var worst_x: float = 0.0
	for f: float in [-1.0 / 3.0, 0.0, 1.0 / 3.0]:
		var x: float = box.get_center().x + f * box.size.x
		var solid: float = 0.0
		var front_z: float = box.position.z
		var y: float = STAND_Y.x
		while y <= FRONT_MAX:
			var a: Vector3 = xf * Vector3(x, ly + y, box.end.z + FRONT_REACH)
			var b: Vector3 = xf * Vector3(x, ly + y, box.position.z)
			var hit: Dictionary = ctx.ray(a, b, accept, LcLines.VISION_MASK)
			if hit.is_empty():
				break
			solid = y
			front_z = (xf.affine_inverse() * (hit["position"] as Vector3)).z
			y += FRONT_STEP
		var d: float = maxf(front_z - (box.position.z - CAPSULE_R), 0.0)
		var need: float = h_top + (LcLines.NPC_EYE - h_top) * d / maxf(min_d, d + CAPSULE_R)
		if solid - need < worst_h - worst_need:
			worst_h = solid
			worst_need = need
			worst_x = x
	note("`%s`: solid front %.2f m, the crouch-hide claim needs %.2f m (observer >= %.1f m)"
		% [ctx.node_path(p.node), worst_h, worst_need, min_d])
	if worst_h < worst_need - 0.005:
		fail(ctx, p.node, xf * Vector3(worst_x, ly + worst_h, box.end.z),
			("solid front %.2f m is below the %.2f m a crouched player needs to be hidden" % [worst_h, worst_need])
			+ (" (top detection point %.2f m, observer eye %.2f m, >= %.1f m away)" % [h_top, LcLines.NPC_EYE, min_d]))
