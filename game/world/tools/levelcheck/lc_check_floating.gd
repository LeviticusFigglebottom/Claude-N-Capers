## floating: every prop rests on a support or is mounted flush (level_standards §3.1).
class_name LcCheckFloating
extends LcCheck

const TOL_ABOVE: float = 0.01      ## max gap between prop base and support
const TOL_PEN: float = 0.005       ## allowed penetration (deeper is reported by clipping)
const MOUNT_TOL: float = 0.01      ## max gap between mount pivot and wall/ceiling surface
const PROBE_START: float = 0.05    ## rays start this far behind the contact plane
const PROBE_RANGE: float = 0.5


func _init() -> void:
	id = &"floating"
	title = "Nothing floats"


func run(ctx: LcContext) -> void:
	var n: int = 0
	for p: LcProp in ctx.props:
		if not ctx.is_active(p.node):
			continue
		if not p.has_geometry:
			warn(ctx, p.node, null, "prop has no geometry or collision; skipped")
			continue
		if p.kind == &"hatch":
			continue  # GN-C2: a floor hatch sits in its hole like a shell piece (door_frame_gap measures the fit)
		n += 1
		match p.mount:
			&"":
				_check_resting(ctx, p)
			&"wall":
				_check_mount(ctx, p, p.xform.basis.z.normalized(), "wall")
			&"ceiling":
				_check_mount(ctx, p, Vector3.UP, "ceiling")
			_:
				fail(ctx, p.node, null, "meta mount `%s` invalid (use \"wall\" or \"ceiling\")" % p.mount)
	note("%d props checked" % n)


## A support hit: not the prop itself; a prop hit must be a declared support (meta support).
func _support_ok(ctx: LcContext, p: LcProp, hit: Dictionary) -> bool:
	var other: LcProp = ctx.prop_of(hit.get("collider"))
	if other == p:
		return false
	if not ctx.accept_any_active(hit):
		return false
	return other == null or other.is_support or other.is_door or other.kind in LcContext.SHELL_KINDS


func _check_resting(ctx: LcContext, p: LcProp) -> void:
	var bottom: float = p.bottom_y()
	var samples: PackedVector3Array = p.footprint_samples()
	var supported: Array[bool] = []
	var best_gap: float = INF
	for s: Vector3 in samples:
		var from: Vector3 = Vector3(s.x, bottom + PROBE_START, s.z)
		var to: Vector3 = Vector3(s.x, bottom - PROBE_RANGE, s.z)
		var hit: Dictionary = ctx.ray(from, to, func(h: Dictionary) -> bool: return _support_ok(ctx, p, h))
		var ok: bool = false
		if not hit.is_empty():
			var gap: float = bottom - (hit["position"] as Vector3).y
			best_gap = minf(best_gap, maxf(gap, 0.0))
			ok = gap <= TOL_ABOVE and gap >= -PROBE_START
		if not ok:
			ok = _aabb_support(ctx, p, s, bottom)
			if ok:
				best_gap = 0.0
		supported.append(ok)
	# Centre supported, or two diagonally opposite corners (centre of mass over the support).
	var stable: bool = supported[0] or (supported[1] and supported[4]) or (supported[2] and supported[3])
	if not stable:
		var gap_s: String = "no support within %.2f m" % PROBE_RANGE if best_gap == INF \
			else "nearest support %.3f m below the base" % best_gap
		fail(ctx, p.node, Vector3(p.center().x, bottom, p.center().z),
			"floats: %s (tolerance %.3f m; mount props need meta mount)" % [gap_s, TOL_ABOVE])


## Fallback for support props without colliders: top of their box within tolerance.
func _aabb_support(ctx: LcContext, p: LcProp, s: Vector3, bottom: float) -> bool:
	for o: LcProp in ctx.props:
		if o == p or not o.is_support or o.has_colliders() or not ctx.is_active(o.node):
			continue
		var top: float = o.global_aabb.end.y
		if bottom - top > TOL_ABOVE or top - bottom > TOL_PEN:
			continue
		if LcGeom.point_in_obb(Vector3(s.x, top - 0.01, s.z), o.obb, 0.001):
			return true
	return false


func _check_mount(ctx: LcContext, p: LcProp, back: Vector3, what: String) -> void:
	var o: Vector3 = p.xform.origin
	var from: Vector3 = o - back * PROBE_START
	var to: Vector3 = o + back * PROBE_RANGE
	var hit: Dictionary = ctx.ray(from, to, func(h: Dictionary) -> bool:
		return ctx.prop_of(h.get("collider")) != p and ctx.accept_any_active(h))
	if hit.is_empty():
		fail(ctx, p.node, o, "%s-mounted but no %s within %.2f m behind its pivot (pivot must be %s)"
			% [what, what, PROBE_RANGE, "back-centre" if what == "wall" else "top-centre"])
		return
	var d: float = ((hit["position"] as Vector3) - o).dot(back)
	if d > MOUNT_TOL:
		fail(ctx, p.node, o, "%s-mounted %.3f m away from the %s (tolerance %.3f m)" % [what, d, what, MOUNT_TOL])
	elif d < -TOL_PEN:
		fail(ctx, p.node, o, "%s-mounted pivot is %.3f m inside the %s" % [what, -d, what])
