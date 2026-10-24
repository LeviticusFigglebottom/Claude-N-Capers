## lasers (all stages, D-048): a static laser grid's stealth bypass gap must fit the player.
## Grids: laser_grid prefab instances (scene/script file `laser_grid*`, or meta kind = "laser_grid")
## with pattern &"static" unless meta bypass = false, plus any grid with meta bypass = true.
## Beam volume: the grid's runtime `BeamArea<i>` / `Trigger` Area3D shapes in grid-local space
## (these follow `size_m`; the ENV A placeholder's posts are fixed at +-1 m and are ignored),
## falling back to `size_m`. For each side (grid-local -X / +X) beyond the beam volume:
##  * clear width = distance from the beam edge to the first obstruction along the grid plane,
##    min over rays at 5 heights x 3 depths (capsule depth band +-0.35 m);
##  * the player capsule (r 0.35) must fit standing (1.8 m) or crouched (1.2 m) centred 0.4 m past
##    the edge (physics intersect_shape against everything solid).
## The grid passes when one side has clear width >= 0.8 m and a fitting capsule. Every grid's `pattern` must be one
## laser_grid.gd runs (KNOWN_PATTERNS; an unknown one fails).
## QC-29: a grid with meta crouch_under = true may instead (or additionally) be passed underneath:
## the lowest beam's underside (grid-local BeamArea shapes) must be >= floor + 1.2 m + 0.02 m and a
## crouched capsule (r 0.35, h 1.2, 2 cm off the floor) must fit, colliding with nothing, along a
## contiguous stretch of the grid width at least 0.8 m wide (capsule centres sampled every 0.05 m;
## stretch = centre run + 2 r). Such grids are checked even when their pattern is not static.
## OF-C3 (D-104 §7.1, opt-in so older maps keep their numbers): HeistMap meta `laser_min_gap_m` (default 0.8) sets
## the clear width (side gap and crouch stretch), grid meta `min_gap_m` overrides it per grid; HeistMap meta
## `laser_crouch_face_m` (default 1.22 = 1.2 + 0.02) sets the minimum lowest-beam lower face for crouch-under.
## Between emitters: the side clear width also stops at any other laser grid's beam volume (BeamArea / Trigger
## shapes) on the probe rays, so two grids in one opening cannot share a gap that neither leaves.
class_name LcCheckLasers
extends LcCheck

const MIN_CLEAR: float = 0.8
## The patterns laser_grid.gd runs (LaserGrid.PATTERN_*; G3: AH wrote "sweep" / "timed", silently static grids).
const KNOWN_PATTERNS: Array[StringName] = [LaserGrid.PATTERN_STATIC, LaserGrid.PATTERN_SWEEPING, LaserGrid.PATTERN_TIMED_OFF]
const CAPSULE_R: float = 0.35
const STAND_H: float = 1.8
const CROUCH_H: float = 1.2
const PROBE_HEIGHTS: Array[float] = [0.15, 0.6, 1.0, 1.4, 1.75]
const PROBE_DEPTHS: Array[float] = [-0.35, 0.0, 0.35]
const SEARCH: float = 4.0
const CROUCH_LIFT: float = 0.02
const CROUCH_STEP: float = 0.05
const META_MIN_GAP: StringName = &"laser_min_gap_m"
const META_CROUCH_FACE: StringName = &"laser_crouch_face_m"

## Beam boxes of every active grid: [{ "grid": Node3D, "xf": Transform3D, "aabb": AABB }].
var _beams: Array[Dictionary] = []


func _init() -> void:
	id = &"lasers"
	title = "Laser grid bypass gaps"


static func is_laser_grid(n: Node) -> bool:
	if LcUtil.meta_s(n, &"kind") == &"laser_grid":
		return true
	if n.scene_file_path.get_file().begins_with("laser_grid"):
		return true
	var sc: Script = n.get_script() as Script
	return sc != null and sc.resource_path.get_file().begins_with("laser_grid")



## Grids whose bypass gap is asserted.
static func needs_gap(n: Node) -> bool:
	if LcUtil.meta_b(n, &"crouch_under"):
		return true
	if n.has_meta(&"bypass"):
		return bool(n.get_meta(&"bypass"))
	return "pattern" in n and StringName(str(n.get("pattern"))) == &"static"


func run(ctx: LcContext) -> void:
	var grids: Array[Node3D] = []
	for n: Node in ctx.map.find_children("*", "Node3D", true, false):
		if not is_laser_grid(n) or not ctx.is_active(n):
			continue
		# Only the outermost grid node (the prefab root), not its children.
		var par: Node = n.get_parent()
		var nested: bool = false
		while par != null and par != ctx.map:
			if is_laser_grid(par):
				nested = true
				break
			par = par.get_parent()
		if not nested:
			grids.append(n as Node3D)
	_beams.clear()
	for g0: Node3D in grids:
		_beams.append_array(beam_boxes(g0))
	var checked: int = 0
	for g: Node3D in grids:
		if "pattern" in g and not (StringName(str(g.get("pattern"))) in KNOWN_PATTERNS):
			fail(ctx, g, null, "unknown laser pattern `%s` (laser_grid.gd knows %s; an unknown one runs as a static grid)"
				% [g.get("pattern"), KNOWN_PATTERNS])
		if not needs_gap(g):
			note("`%s`: pattern `%s`, bypass gap not required" % [ctx.node_path(g), g.get("pattern") if "pattern" in g else "?"])
			continue
		checked += 1
		_check_grid(ctx, g)
	note("%d laser grid(s), %d with an asserted bypass gap" % [grids.size(), checked])


## Required clear width for grid g (grid meta min_gap_m, else HeistMap meta laser_min_gap_m, else MIN_CLEAR).
static func min_gap(ctx: LcContext, g: Node) -> float:
	return LcLines.meta_float(g, &"min_gap_m", LcLines.meta_float(ctx.map, META_MIN_GAP, MIN_CLEAR))


## Minimum lowest-beam lower face above the floor for crouch-under (HeistMap meta laser_crouch_face_m).
static func crouch_face(ctx: LcContext) -> float:
	return LcLines.meta_float(ctx.map, META_CROUCH_FACE, CROUCH_H + CROUCH_LIFT)


## The grid's BeamArea / Trigger collision boxes (global transform + local AABB).
static func beam_boxes(g: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Node in g.get_children():
		if not (a is Area3D) or not (String(a.name).begins_with("BeamArea") or a.name == &"Trigger"):
			continue
		for cs: Node in a.find_children("*", "CollisionShape3D", true, false):
			var shape: Shape3D = (cs as CollisionShape3D).shape
			if shape != null:
				out.append({"grid": g, "xf": (cs as Node3D).global_transform, "aabb": shape.get_debug_mesh().get_aabb()})
	return out


## Distance from a along a -> b to the first other grid's beam box, INF when none is crossed.
func _other_beam_dist(g: Node3D, a: Vector3, b: Vector3) -> float:
	var best: float = INF
	for bx: Dictionary in _beams:
		if bx["grid"] == g or _alternatives(g, bx["grid"]):
			continue
		var xf: Transform3D = bx["xf"]
		var inv: Transform3D = xf.affine_inverse()
		var la: Vector3 = inv * a
		var aabb: AABB = bx["aabb"]
		if aabb.has_point(la):
			return 0.0
		var hit: Variant = aabb.intersects_segment(la, inv * b)
		if hit != null:
			best = minf(best, a.distance_to(xf * (hit as Vector3)))
	return best


## Grids in different slots of one variant group (e.g. ND's laser_pattern static / sweep / timed at the same spot) are
## alternatives: never both in a run, so one's beams do not close the other's gap (all-slots-active passes included).
static func _alternatives(a: Node, b: Node) -> bool:
	var sa: Node = _slot_of(a)
	var sb: Node = _slot_of(b)
	return sa != null and sb != null and sa != sb and sa.get_parent() == sb.get_parent()


static func _slot_of(n: Node) -> Node:
	var cur: Node = n
	while cur != null and not (cur is VariantSlot):
		cur = cur.get_parent()
	return cur


## Beam volume x-extent [min, max] in grid-local space (unscaled grid basis assumed orthonormal).
static func beam_extent(g: Node3D) -> Vector2:
	var inv: Transform3D = g.global_transform.affine_inverse()
	var lo: float = INF
	var hi: float = -INF
	for a: Node in g.get_children():
		if not (a is Area3D) or not (String(a.name).begins_with("BeamArea") or a.name == &"Trigger"):
			continue
		for cs: Node in a.find_children("*", "CollisionShape3D", true, false):
			var shape: Shape3D = (cs as CollisionShape3D).shape
			if shape == null:
				continue
			var b: AABB = (inv * (cs as Node3D).global_transform) * shape.get_debug_mesh().get_aabb()
			lo = minf(lo, b.position.x)
			hi = maxf(hi, b.end.x)
	if lo == INF and "size_m" in g:
		var w: float = (g.get("size_m") as Vector3).x
		return Vector2(-w * 0.5, w * 0.5)
	return Vector2(lo, hi)


func _check_grid(ctx: LcContext, g: Node3D) -> void:
	var ext: Vector2 = beam_extent(g)
	if ext.x == INF:
		fail(ctx, g, null, "laser grid has no beam volume (no BeamArea/Trigger shapes, no size_m)")
		return
	var xf: Transform3D = Transform3D(g.global_basis.orthonormalized(), g.global_position)
	var fl: Dictionary = ctx.shell_floor(g.global_position, 0.5, 1.0)
	var floor_y: float = (fl["position"] as Vector3).y if not fl.is_empty() else g.global_position.y
	var results: PackedStringArray = PackedStringArray()
	var ok: bool = false
	var need_gap: float = min_gap(ctx, g)
	var crouch: bool = LcUtil.meta_b(g, &"crouch_under")
	if crouch:
		var cu: Dictionary = _crouch_under(ctx, g, xf, ext, floor_y)
		results.append(String(cu["text"]))
		if bool(cu["ok"]):
			ok = true
		else:
			fail(ctx, g, null, "crouch_under: %s" % cu["text"])
	var side_gap: bool = not g.has_meta(&"bypass") or LcUtil.meta_b(g, &"bypass") or not crouch
	for side: float in ([-1.0, 1.0] if side_gap else []):
		var edge: float = ext.x if side < 0.0 else ext.y
		var clear: float = _clear_width(ctx, g, xf, edge, side, floor_y)
		var fit: String = "none"
		if clear >= need_gap - 0.005:
			var centre: Vector3 = xf * Vector3(edge + side * (CAPSULE_R + 0.05), 0.0, 0.0)
			if _capsule_free(ctx, g, centre, floor_y, STAND_H):
				fit = "standing"
			elif _capsule_free(ctx, g, centre, floor_y, CROUCH_H):
				fit = "crouched"
		results.append("%s side: clear %.2f m, capsule %s" % ["-X" if side < 0.0 else "+X", clear, fit])
		if clear >= need_gap - 0.005 and fit != "none":
			ok = true
	note("`%s`: beams x %.2f..%.2f m; %s" % [ctx.node_path(g), ext.x, ext.y, "; ".join(results)])
	if not ok and (not crouch or side_gap):
		fail(ctx, g, null, "no passable bypass gap (need clear width >= %.2f m and a r %.2f capsule %.1f m standing or %.1f m crouched): %s"
			% [need_gap, CAPSULE_R, STAND_H, CROUCH_H, "; ".join(results)])


func _not_grid(ctx: LcContext, g: Node3D) -> Callable:
	return func(h: Dictionary) -> bool:
		var c: Node = h.get("collider") as Node
		return c == null or (not (c == g or g.is_ancestor_of(c)) and ctx.is_active(c))


func _clear_width(ctx: LcContext, g: Node3D, xf: Transform3D, edge: float, side: float, floor_y: float) -> float:
	var best: float = SEARCH
	var pq: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	pq.collision_mask = LcContext.QUERY_MASK
	var accept: Callable = _not_grid(ctx, g)
	for h: float in PROBE_HEIGHTS:
		for dz: float in PROBE_DEPTHS:
			var a: Vector3 = xf * Vector3(edge + side * 0.002, 0.0, dz)
			a.y = floor_y + h
			pq.position = a
			for hit: Dictionary in ctx.space().intersect_point(pq, 4):
				if accept.call(hit):
					return 0.0
			var b: Vector3 = xf * Vector3(edge + side * SEARCH, 0.0, dz)
			b.y = a.y
			var r: Dictionary = ctx.ray(a, b, accept)
			if not r.is_empty():
				best = minf(best, a.distance_to(r["position"]))
			best = minf(best, _other_beam_dist(g, a, b))
	return best


func _capsule_free(ctx: LcContext, g: Node3D, centre: Vector3, floor_y: float, height: float) -> bool:
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = CAPSULE_R
	cap.height = height
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = LcContext.QUERY_MASK
	# Lifted 5 cm off the floor (step tolerance), so resting on the floor is not a collision.
	q.transform = Transform3D(Basis(), Vector3(centre.x, floor_y + height * 0.5 + 0.05, centre.z))
	var accept: Callable = _not_grid(ctx, g)
	for hit: Dictionary in ctx.space().intersect_shape(q, 8):
		if accept.call(hit):
			return false
	return true


## Lowest beam underside, grid-local y (INF when the grid has no horizontal beam areas).
static func lowest_beam(g: Node3D) -> float:
	var inv: Transform3D = g.global_transform.affine_inverse()
	var lo: float = INF
	for a: Node in g.get_children():
		if not (a is Area3D) or not String(a.name).begins_with("BeamArea"):
			continue
		for cs: Node in a.find_children("*", "CollisionShape3D", true, false):
			var shape: Shape3D = (cs as CollisionShape3D).shape
			if shape != null:
				var b: AABB = (inv * (cs as Node3D).global_transform) * shape.get_debug_mesh().get_aabb()
				lo = minf(lo, b.position.y)
	return lo


func _crouch_under(ctx: LcContext, g: Node3D, xf: Transform3D, ext: Vector2, floor_y: float) -> Dictionary:
	var low: float = lowest_beam(g)
	if low == INF:
		return {"ok": false, "text": "no horizontal beams found (BeamArea shapes)"}
	var beam_h: float = g.global_position.y + low - floor_y
	var need: float = crouch_face(ctx)
	if beam_h < need - 0.001:
		return {"ok": false, "text": "lowest beam %.2f m above the floor, a crouched player needs %.2f m" % [beam_h, need]}
	var run: float = 0.0
	var best: float = 0.0
	var any_free: bool = false
	var x: float = ext.x + CAPSULE_R
	while x <= ext.y - CAPSULE_R + 0.0001:
		var c: Vector3 = xf * Vector3(x, 0.0, 0.0)
		if _capsule_free(ctx, g, c, floor_y + CROUCH_LIFT - 0.05, CROUCH_H):
			any_free = true
			run += CROUCH_STEP
			best = maxf(best, run - CROUCH_STEP)
		else:
			run = 0.0
		x += CROUCH_STEP
	var width: float = best + 2.0 * CAPSULE_R if any_free else 0.0
	var text: String = "lowest beam %.2f m, crouched clear stretch %.2f m" % [beam_h, width]
	return {"ok": width >= min_gap(ctx, g) - 0.005, "text": text}
