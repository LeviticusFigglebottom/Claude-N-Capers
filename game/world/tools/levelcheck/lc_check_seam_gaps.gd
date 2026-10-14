## seam_gaps (all stages, PO-7): no see-through slits where walls meet each other, the floor or
## the ceiling. Per box side of every RoomVolume (except exterior / roof / plenum / shaft /
## elevator rooms), against single-sided proxies of the visual meshes (LcGaps), counting only the
## building shell and door / window visuals:
## (1) corners / junctions: scan lines along the side at floor + 0.15 m and + 1.2 m, every 0.015 m
##     (edges refined by bisection). Each sample casts from 0.3 m inside the room to 0.6 m past the
##     side, both ways; a sample is open when nothing is hit. The scan starts and ends where a ray
##     along the side from inside the room meets the crossing wall (the real corner), so a run that
##     reaches such an end is a corner slit; a run reaching an end without a crossing wall is open
##     plan and ignored; a crossing wall counts only when it also stands at 1.9 m. Open runs
##     0.02-0.3 m wide fail when the wall stands on both sides of the run at 1.9 m too (a
##     full-height seam, not the gap between balusters or a counter).
## (2) wall to floor / ceiling: at stations every 1 m along the side, a vertical scan line from the
##     floor to the ceiling (found by shell rays inside the room); an open run 0.02-0.3 m tall that
##     touches the floor or the ceiling fails when the wall above (1.9 m) / below (1.2 m) is solid
##     (not a railing). A run that spans most of the height is a doorway.
## Runs inside a door / window prefab's visual bounds are left to door_frame_gap.
class_name LcCheckSeamGaps
extends LcCheck

const GAP_TOL_M: float = 0.02
const SLIT_MAX_M: float = 0.3
const STEP_M: float = 0.015
const INSET_M: float = 0.3
const BEYOND_M: float = 0.6
const SCAN_YS: Array[float] = [0.15, 1.2]
const FULL_HEIGHT_Y: float = 1.9
const STATION_M: float = 1.0
const EXEMPT: Array[StringName] = [&"exterior", &"roof", &"plenum", &"shaft", &"elevator"]
const MAX_REPORTS: int = 40

var _accept: Callable
var _ctx: LcContext
var _found: Array[Dictionary] = []
## [Transform3D, AABB] of every door / window prefab visual (their gaps are door_frame_gap's).
var _openings: Array[Array] = []


func _init() -> void:
	id = &"seam_gaps"
	title = "No see-through slits at wall corners, junctions, floors and ceilings"


func run(ctx: LcContext) -> void:
	_ctx = ctx
	_accept = func(src: Node) -> bool: return LcGaps.is_shell(ctx, src)
	var regions: Array[AABB] = []
	var rooms: Array[RoomVolume] = []
	for r: RoomVolume in ctx.rooms:
		if r.purpose in EXEMPT or not ctx.is_active(r):
			continue
		rooms.append(r)
		regions.append(LcAreas.world_aabb(r).grow(BEYOND_M + 0.5))
	if rooms.is_empty():
		note("no interior rooms")
		return
	for n: Node in ctx.map.find_children("*", "", true, false):
		var pf: GameplayPrefab = n as GameplayPrefab
		if pf != null and (pf is Door or pf is WindowPrefab):
			var box: Variant = LcCheckDoorFrameGap._box(pf, pf.visual_root, [])
			if box is AABB:
				_openings.append([pf.global_transform.affine_inverse(), (box as AABB).grow(0.05)])
	await LcGaps.build_proxies(ctx, regions)
	var sides: int = 0
	for r2: RoomVolume in rooms:
		for b: Dictionary in LcAreas.boxes(r2):
			var xf: Transform3D = (b["xf"] as Transform3D).orthonormalized()
			var box: AABB = b["aabb"]
			for k: int in range(4):
				sides += 1
				_scan_side(r2, xf, box, k)
	LcVisual.free_proxies(ctx)
	_found.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return a["w"] > c["w"])
	for i: int in range(mini(_found.size(), MAX_REPORTS)):
		var f: Dictionary = _found[i]
		fail(ctx, f["room"], f["at"], f["msg"])
	if _found.size() > MAX_REPORTS:
		fail(ctx, ctx.map, null, "%d more seam slit(s) not listed" % (_found.size() - MAX_REPORTS))
	note("%d room(s), %d box side(s) scanned; slits > %.2f m fail" % [rooms.size(), sides, GAP_TOL_M])


## Side k of a room box (box-local): 0 = -Z, 1 = +X, 2 = +Z, 3 = -X.
func _scan_side(room: RoomVolume, xf: Transform3D, box: AABB, k: int) -> void:
	var lo: Vector3 = box.position
	var hi: Vector3 = box.end
	var c0: Vector3
	var c1: Vector3
	var n: Vector3
	match k:
		0:
			c0 = Vector3(lo.x, lo.y, lo.z)
			c1 = Vector3(hi.x, lo.y, lo.z)
			n = Vector3(0, 0, -1)
		1:
			c0 = Vector3(hi.x, lo.y, lo.z)
			c1 = Vector3(hi.x, lo.y, hi.z)
			n = Vector3(1, 0, 0)
		2:
			c0 = Vector3(hi.x, lo.y, hi.z)
			c1 = Vector3(lo.x, lo.y, hi.z)
			n = Vector3(0, 0, 1)
		_:
			c0 = Vector3(lo.x, lo.y, hi.z)
			c1 = Vector3(lo.x, lo.y, lo.z)
			n = Vector3(-1, 0, 0)
	var w0: Vector3 = xf * c0
	var w1: Vector3 = xf * c1
	var nw: Vector3 = (xf.basis * n).normalized()
	var length: float = w0.distance_to(w1)
	if length < 0.5:
		return
	var u: Vector3 = (w1 - w0) / length
	var depth: float = (hi - lo).x if (k == 0 or k == 2) else (hi - lo).z
	var inset: float = minf(INSET_M, depth * 0.4)
	var height: float = hi.y - lo.y
	var side: Dictionary = {"room": room, "w0": w0, "u": u, "n": nw, "inset": inset, "len": length}
	for y: float in SCAN_YS:
		if y + 0.1 > height:
			continue
		_corner_scan(side, y)
	var t: float = STATION_M * 0.5
	while t < length:
		_junction_scan(side, t, w0.y, w0.y + height)
		t += STATION_M


func _p(side: Dictionary, t: float, y: float, out: float) -> Vector3:
	var w0: Vector3 = side["w0"]
	return Vector3(w0.x, y, w0.z) + (side["u"] as Vector3) * t + (side["n"] as Vector3) * out


func _open(side: Dictionary, t: float, y: float) -> bool:
	var a: Vector3 = _p(side, t, y, -float(side["inset"]))
	var b: Vector3 = _p(side, t, y, BEYOND_M)
	return LcGaps.ray(_ctx, a, b, _accept).is_empty() and LcGaps.ray(_ctx, b, a, _accept).is_empty()


## Corner (scan end) along the side from 0.6 m in, at height y: t of the crossing wall, or NAN.
func _corner(side: Dictionary, y: float, from_t: float, dir: float) -> float:
	var a: Vector3 = _p(side, from_t, y, -float(side["inset"]) * 0.5)
	var b: Vector3 = _p(side, from_t + dir * (0.6 + 0.4), y, -float(side["inset"]) * 0.5)
	var dd: float = LcGaps.dist(_ctx, a, b, _accept)
	return NAN if dd == INF else from_t + dir * dd


## _corner at y, kept only when a crossing wall stands there at `yy` too (within 0.05 m): stairs,
## counters and railings are not corners.
func _wall_corner(side: Dictionary, y: float, yy: float, from_t: float, dir: float) -> float:
	var t: float = _corner(side, y, from_t, dir)
	var t2: float = _corner(side, yy, from_t, dir)
	if is_nan(t) or is_nan(t2) or absf(t - t2) > 0.05:
		return NAN
	return t


func _corner_scan(side: Dictionary, dy: float) -> void:
	var y: float = (side["w0"] as Vector3).y + dy
	var length: float = side["len"]
	var near: float = minf(0.6, length * 0.5)
	var yy: float = (side["w0"] as Vector3).y + FULL_HEIGHT_Y
	var t_lo: float = _wall_corner(side, y, yy, near, -1.0)
	var t_hi: float = _wall_corner(side, y, yy, length - near, 1.0)
	var a: float = (t_lo + 0.002) if not is_nan(t_lo) else 0.0
	var b: float = (t_hi - 0.002) if not is_nan(t_hi) else length
	if b - a < 0.1:
		return
	var runs: Array[Dictionary] = LcGaps.open_runs(func(t: float) -> bool: return _open(side, t, y), a, b, STEP_M)
	for r: Dictionary in runs:
		if (r["lo_end"] and is_nan(t_lo)) or (r["hi_end"] and is_nan(t_hi)):
			continue
		var ra: float = (t_lo if r["lo_end"] else float(r["a"]))
		var rb: float = (t_hi if r["hi_end"] else float(r["b"]))
		var w: float = rb - ra
		if w <= GAP_TOL_M or w > SLIT_MAX_M:
			continue
		# Full-height seam: the wall stands on both sides of the run above rail / counter height too.
		var left_ok: bool = r["lo_end"] or not _open(side, ra - 0.02, yy)
		var right_ok: bool = r["hi_end"] or not _open(side, rb + 0.02, yy)
		if not (left_ok and right_ok) or not _open(side, (ra + rb) * 0.5, y):
			continue
		if _in_opening(_p(side, (ra + rb) * 0.5, y, 0.0)):
			continue
		var kind: String = "corner" if (r["lo_end"] or r["hi_end"]) else "wall"
		_found.append({"w": w, "room": side["room"], "at": _p(side, (ra + rb) * 0.5, y, 0.0),
			"msg": "see-through %s seam %.3f m wide in the room's %s wall at %.2f m above the floor (> %.2f m)"
				% [kind, w, _dir_name(side["n"]), dy, GAP_TOL_M]})


func _junction_scan(side: Dictionary, t: float, y_lo: float, y_hi: float) -> void:
	var inside: Vector3 = _p(side, t, y_lo + 1.0, -float(side["inset"]))
	var df: float = LcGaps.dist(_ctx, inside, inside + Vector3.DOWN * 1.5, _accept)
	var dc: float = LcGaps.dist(_ctx, inside, inside + Vector3.UP * (y_hi - y_lo + 1.0), _accept)
	if df == INF or dc == INF:
		return
	var fy: float = inside.y - df
	var cy: float = inside.y + dc
	var a: float = fy + 0.003
	var b: float = cy - 0.003
	if b - a < 1.0:
		return
	for r: Dictionary in LcGaps.open_runs(func(y: float) -> bool: return _open(side, t, y), a, b, STEP_M):
		var touches_floor: bool = r["lo_end"]
		var touches_ceiling: bool = r["hi_end"]
		if touches_floor == touches_ceiling:
			continue  # floating hole (window, hatch) or open full height
		var w: float = (float(r["b"]) - fy) if touches_floor else (cy - float(r["a"]))
		if w <= GAP_TOL_M or w > SLIT_MAX_M:
			continue
		# A wall, not a railing or counter: solid at 1.9 m (floor runs) / 1.2 m (ceiling runs).
		if _open(side, t, fy + (FULL_HEIGHT_Y if touches_floor else 1.2)):
			continue
		var y: float = (fy + w * 0.5) if touches_floor else (cy - w * 0.5)
		if _in_opening(_p(side, t, y, 0.0)):
			continue
		_found.append({"w": w, "room": side["room"], "at": _p(side, t, y, 0.0),
			"msg": "see-through gap %.3f m between the room's %s wall and the %s (> %.2f m)"
				% [w, _dir_name(side["n"]), "floor" if touches_floor else "ceiling", GAP_TOL_M]})


## True when world point `p` lies inside a door / window prefab's visual bounds.
func _in_opening(p: Vector3) -> bool:
	for o: Array in _openings:
		if (o[1] as AABB).has_point((o[0] as Transform3D) * p):
			return true
	return false


static func _dir_name(n: Vector3) -> String:
	if absf(n.x) >= absf(n.z):
		return "+X (east)" if n.x > 0.0 else "-X (west)"
	return "+Z (south)" if n.z > 0.0 else "-Z (north)"
