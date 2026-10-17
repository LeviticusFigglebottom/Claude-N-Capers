## hide_los (all stages, OF-C3 / D-136 §3b.11, D-128): a spot the design calls "hidden" is hidden by LOS sample,
## not by eye. Opt-in: nodes with meta `hide_spot = true` (else the check is skipped). A spot is a marked line
## (LcLines: a Path3D, a Marker3D chain or a single Marker3D) at the crew's feet, sampled every 0.5 m.
## Spot metas:
##   hide_from      room_ids (String "a,b" or PackedStringArray), required: the observer rooms. Observers stand on a
##                  floor grid of each room (`hide_grid_m`, default 1.0 m; the shell floor under each grid point),
##                  eye at the NPC head height 1.62 m; grid points inside a solid are skipped.
##   hide_posture   "crouch" (default) or "stand": the crew's detection points are the runtime ones, feet +
##                  min(h, eye) for StealthTweak `los_heights` (crouched: 1.0 and 1.05 m).
##   hide_min_m     observers closer than this (flat) are ignored, default 2.0 m: inside it PD2 uncovers a crouched
##                  player regardless of cover (S2.2), so "hidden" claims never cover it.
##   hide_range_m   observers farther than this (3D) are ignored, default 20 m (the standing max_range, S2.2).
##   hide_cameras   true: security cameras whose Lens is in a `hide_from` room observe too (cone + range_m, any
##                  layout; no minimum distance: cameras have no uncover).
## Vision rays follow StealthDirector (VISION_MASK: world static/dynamic, vision blockers) against active colliders;
## glazing (group or meta `see_through`, kind window/glass/glazing) is transparent. FAIL when any detection point of any
## sample is seen by any observer; the message gives the counts and the first observer.
class_name LcCheckHideLos
extends LcCheck

const META: StringName = &"hide_spot"
const STEP: float = 0.5
const DEFAULT_GRID: float = 1.0
const DEFAULT_MIN: float = 2.0
const DEFAULT_RANGE: float = 20.0


func _init() -> void:
	id = &"hide_los"
	title = "Hidden spots are hidden by LOS sample (D-128)"


func run(ctx: LcContext) -> void:
	var spots: Array[Node3D] = []
	for n: Node in ctx.map.find_children("*", "Node3D", true, false):
		if LcUtil.meta_b(n, META) and ctx.is_active(n):
			spots.append(n as Node3D)
	if spots.is_empty():
		skipped_reason = "not configured (no node with meta `hide_spot`)"
		return
	for s: Node3D in spots:
		_check_spot(ctx, s)


func _check_spot(ctx: LcContext, s: Node3D) -> void:
	var ids: PackedStringArray = LcLines.meta_strings(s, &"hide_from")
	if ids.is_empty():
		fail(ctx, s, null, "hide spot has no `hide_from` room_ids")
		return
	var obs: Array[Dictionary] = _observers(ctx, s, ids)
	if obs.is_empty():
		fail(ctx, s, null, "no observer points in `hide_from` rooms %s" % ", ".join(ids))
		return
	var crouched: bool = LcLines.is_crouched(s, &"hide_posture")
	var heights: Array[float] = LcLines.detection_heights(crouched)
	var min_d: float = LcLines.meta_float(s, &"hide_min_m", DEFAULT_MIN)
	var max_d: float = LcLines.meta_float(s, &"hide_range_m", DEFAULT_RANGE)
	var accept: Callable = LcLines.vision_accept(ctx)
	var pts: PackedVector3Array = LcLines.samples(LcLines.vertices(s), STEP)
	var seen: int = 0
	var first: String = ""
	var first_pos: Variant = null
	for q: Vector3 in pts:
		var hit: String = _seen_from(ctx, q, heights, obs, min_d, max_d, accept)
		if hit != "":
			seen += 1
			if first == "":
				first = hit
				first_pos = q
	var posture: String = "crouched" if crouched else "standing"
	var hs: PackedStringArray = PackedStringArray()
	for h: float in heights:
		hs.append("%.2f" % h)
	note("`%s`: %s, %d sample(s), %d observer point(s) in %s, points %s m: %s" % [ctx.node_path(s), posture, pts.size(),
		obs.size(), ", ".join(ids), ", ".join(hs), "hidden" if seen == 0 else "%d seen" % seen])
	if seen > 0:
		fail(ctx, s, first_pos, "hide spot is visible: %d of %d sample(s) seen (%s); first: %s"
			% [seen, pts.size(), posture, first])


## Observers: [{ "eye": Vector3, "room": String, "cam": Node3D or null, "dirs": Array[Vector3] }].
func _observers(ctx: LcContext, s: Node3D, ids: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var grid: float = LcLines.meta_float(s, &"hide_grid_m", DEFAULT_GRID)
	var pq: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	pq.collision_mask = LcLines.VISION_MASK
	var accept: Callable = LcLines.vision_accept(ctx)
	for rid: String in ids:
		var r: RoomVolume = LcSecCams.room_by_id(ctx, StringName(rid))
		if r == null:
			fail(ctx, s, null, "`hide_from`: no RoomVolume with room_id `%s`" % rid)
			continue
		for p: Vector3 in LcAreas.floor_grid(r, grid):
			var fl: Dictionary = ctx.shell_floor(p, 0.5, 0.5)
			if fl.is_empty():
				continue
			var feet: Vector3 = fl["position"]
			var eye: Vector3 = feet + Vector3.UP * LcLines.NPC_EYE
			if _inside_solid(ctx, pq, eye, accept) or _inside_solid(ctx, pq, feet + Vector3.UP * 0.9, accept):
				continue
			out.append({"eye": eye, "room": rid, "cam": null, "dirs": []})
	if LcUtil.meta_b(s, &"hide_cameras"):
		for c: Node3D in LcSecCams.cameras(ctx):
			if not ctx.is_active(c):
				continue
			var cr: RoomVolume = LcSecCams.camera_room(ctx, c)
			if cr != null and String(cr.room_id) in ids:
				out.append({"eye": LcSecCams.eye(c), "room": String(cr.room_id), "cam": c, "dirs": LcSecCams.pan_dirs(c)})
	return out


static func _inside_solid(ctx: LcContext, pq: PhysicsPointQueryParameters3D, p: Vector3, accept: Callable) -> bool:
	pq.position = p
	for hit: Dictionary in ctx.space().intersect_point(pq, 4):
		if accept.call(hit):
			return true
	return false


## "" when no observer sees any detection point of sample q, else a description of the first that does.
func _seen_from(ctx: LcContext, q: Vector3, heights: Array[float], obs: Array[Dictionary], min_d: float,
		max_d: float, accept: Callable) -> String:
	for o: Dictionary in obs:
		var e: Vector3 = o["eye"]
		var cam: Node3D = o["cam"] as Node3D
		var flat: float = Vector2(q.x - e.x, q.z - e.z).length()
		if cam == null and flat < min_d:
			continue
		for h: float in heights:
			var t: Vector3 = q + Vector3.UP * h
			var dist: float = e.distance_to(t)
			if cam == null and dist > max_d:
				continue
			if cam != null and not LcSecCams.in_cone(cam, o["dirs"], t):
				continue
			if ctx.ray(e, t, accept, LcLines.VISION_MASK).is_empty():
				var who: String = ("camera %s" % LcSecCams.cam_name(cam)) if cam != null else "observer"
				return "%s in `%s` at %s, %.1f m, sees the %.2f m point at %s" % [who, o["room"], fmt_v(e), dist, h, fmt_v(t)]
	return ""
