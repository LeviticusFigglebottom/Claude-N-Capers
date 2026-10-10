## scale: human scale table of level_standards §2.6 + stairs vs HeistMap.floor_heights (§2.7)
## + ceilings exist indoors (§2.8).
class_name LcCheckScale
extends LcCheck

const TOL: float = 0.03
const DOOR_H: Vector2 = Vector2(2.1, 2.1)
const DOOR_SINGLE: Vector2 = Vector2(0.9, 0.9)
const DOOR_SERVICE: Vector2 = Vector2(1.0, 1.2)
const DOOR_DOUBLE: Vector2 = Vector2(1.8, 1.8)
## purpose -> allowed ceiling height range (m). level_standards §2.6.
const CEILING: Dictionary = {
	# residential / office 2.6-3.0
	&"office": Vector2(2.6, 3.0), &"manager_office": Vector2(2.6, 3.0), &"meeting_room": Vector2(2.6, 3.0),
	&"conference_room": Vector2(2.6, 3.0), &"break_room": Vector2(2.6, 3.0), &"kitchen": Vector2(2.6, 3.0),
	&"restroom": Vector2(2.6, 3.0), &"locker_room": Vector2(2.6, 3.0), &"storage": Vector2(2.6, 3.0),
	&"janitor": Vector2(2.6, 3.0), &"security_room": Vector2(2.6, 3.0), &"server_room": Vector2(2.6, 3.0),
	&"electrical": Vector2(2.6, 3.0), &"it_closet": Vector2(2.6, 3.0), &"corridor": Vector2(2.6, 3.0),
	&"staff_room": Vector2(2.6, 3.0), &"residential": Vector2(2.6, 3.0), &"bedroom": Vector2(2.6, 3.0),
	&"living_room": Vector2(2.6, 3.0), &"bathroom": Vector2(2.6, 3.0), &"cash_office": Vector2(2.6, 3.0),
	# retail / lobby 3.0-4.5
	&"sales_floor": Vector2(3.0, 4.5), &"retail": Vector2(3.0, 4.5), &"lobby": Vector2(3.0, 4.5),
	&"showroom": Vector2(3.0, 4.5), &"reception": Vector2(3.0, 4.5), &"gallery": Vector2(3.0, 4.5),
	&"restaurant": Vector2(3.0, 4.5), &"bar": Vector2(3.0, 4.5),
	# warehouse / banking hall 3.5-6
	&"warehouse": Vector2(3.5, 6.0), &"banking_hall": Vector2(3.5, 6.0), &"loading": Vector2(3.5, 6.0),
	&"loading_dock": Vector2(3.5, 6.0), &"garage": Vector2(3.5, 6.0), &"workshop": Vector2(3.5, 6.0),
	# vaults are not in the §2.6 table: office minimum up to banking-hall maximum (lead to confirm).
	&"vault": Vector2(2.6, 6.0),
	# atrium <= 10
	&"atrium": Vector2(3.0, 10.0),
}
## Purposes without a ceiling rule (open or vertical spaces).
const NO_CEILING: Array[StringName] = [&"exterior", &"stair", &"shaft", &"elevator", &"roof", &"plenum"]
const HEADROOM: float = 2.1
const STAIR_RISER: Vector2 = Vector2(0.15, 0.19)
const STAIR_TREAD: Vector2 = Vector2(0.25, 0.32)
const STAIR_MIN_WIDTH: float = 1.1
const STAIR_MAX_RUN_RISERS: int = 16
const LANDING_MIN: float = 0.8
const STAIR_SAMPLE: float = 0.01
## kind -> [measure, range]. measure: "height" (top above floor), "centre" (centre above floor),
## "bottom" (base above floor).
const PROP_RULES: Dictionary = {
	&"counter_service": ["height", Vector2(0.9, 0.9)],
	&"counter_transaction": ["height", Vector2(1.05, 1.1)],
	&"counter_bar": ["height", Vector2(1.05, 1.1)],
	&"desk": ["height", Vector2(0.72, 0.76)],
	&"railing": ["height", Vector2(1.0, 1.1)],
	&"switch": ["centre", Vector2(1.15, 1.25)],
	&"outlet": ["centre", Vector2(0.25, 0.35)],
	&"thermostat": ["centre", Vector2(1.45, 1.55)],
	&"picture": ["centre", Vector2(1.45, 1.6)],
	&"sign": ["centre", Vector2(2.2, 2.4)],
	&"exit_sign": ["centre", Vector2(2.2, 2.4)],
}
const CAMERA_RANGE: Vector2 = Vector2(2.4, 3.2)
const CHAIR_SEAT: Vector2 = Vector2(0.42, 0.48)


func _init() -> void:
	id = &"scale"
	title = "Human scale"


func run(ctx: LcContext) -> void:
	for d: Node3D in ctx.doors:
		if ctx.is_active(d):
			_check_door(ctx, d)
	for r: RoomVolume in ctx.rooms:
		_check_ceiling(ctx, r)
	for p: LcProp in ctx.props:
		if ctx.is_active(p.node) and p.has_geometry:
			_check_prop(ctx, p)
	for n: Node in ctx.map.find_children("*", "Node3D", true, false):
		if LcUtil.meta_s(n, &"kind") == &"stairs" and ctx.is_active(n):
			_check_stairs(ctx, n as Node3D)


static func _in(v: float, r: Vector2, tol: float = TOL) -> bool:
	return v >= r.x - tol and v <= r.y + tol


func _check_door(ctx: LcContext, d: Node3D) -> void:
	var total_w: float = 0.0
	var leaves: int = 0
	for leaf_name: String in ["Leaf", "Leaf2"]:
		var leaf: Node3D = d.find_child(leaf_name, true, false) as Node3D
		if leaf == null:
			continue
		var box: Variant = LcCheckClipping._leaf_box(leaf)
		if box == null:
			warn(ctx, leaf, null, "door leaf without mesh; size not checked")
			return
		var lb: AABB = box
		var sx: float = leaf.global_basis.x.length()
		var sy: float = leaf.global_basis.y.length()
		total_w += lb.size.x * sx
		leaves += 1
		if not _in(lb.size.y * sy, DOOR_H):
			fail(ctx, leaf, null, "door leaf height %.3f m, need %.2f m" % [lb.size.y * sy, DOOR_H.x])
	if leaves == 0:
		return
	var service: bool = LcUtil.meta_b(d, &"service")
	var ok: bool
	if leaves == 2:
		ok = _in(total_w, DOOR_DOUBLE)
	else:
		ok = _in(total_w, DOOR_SINGLE) or (service and _in(total_w, DOOR_SERVICE))
	if not ok:
		fail(ctx, d, null, "door width %.3f m (%d leaf): single 0.9, double 1.8, service (meta service) 1.0-1.2"
			% [total_w, leaves])


func _check_ceiling(ctx: LcContext, r: RoomVolume) -> void:
	if r.purpose in NO_CEILING:
		return
	var rng: Vector2
	if r.has_meta(&"ceiling_range"):
		rng = r.get_meta(&"ceiling_range")
		note("`%s`: ceiling_range override %s (lead review)" % [ctx.node_path(r), rng])
	elif CEILING.has(r.purpose):
		rng = CEILING[r.purpose]
	else:
		fail(ctx, r, null, "purpose `%s` has no ceiling-height rule (add it to the table via the lead)" % r.purpose)
		return
	var heights: Array[float] = []
	var open: int = 0
	var low: Array[Vector3] = []
	for s: Vector3 in LcAreas.floor_grid(r, 1.0, 0.5):
		var fl: Dictionary = ctx.shell_floor(s, 1.0, 0.6)
		if fl.is_empty():
			continue
		var fp: Vector3 = fl["position"]
		var up: Dictionary = ctx.ray(fp + Vector3.UP * 0.05, fp + Vector3.UP * 12.0, ctx.accept_shell)
		if up.is_empty():
			open += 1
			continue
		var h: float = (up["position"] as Vector3).y - fp.y
		heights.append(h)
		if h < HEADROOM:
			low.append(fp)
	if open > 0:
		fail(ctx, r, null, "%d sample(s) with no ceiling (indoor room open to the sky)" % open)
	if heights.is_empty():
		if open == 0:
			fail(ctx, r, null, "no floor found under the room volume")
		return
	heights.sort()
	var med: float = heights[heights.size() / 2]
	note("`%s` (%s): ceiling median %.2f m (rule %.1f-%.1f)" % [ctx.node_path(r), r.purpose, med, rng.x, rng.y])
	if not _in(med, rng, 0.02):
		fail(ctx, r, null, "ceiling height %.2f m outside %.1f-%.1f m for purpose `%s`" % [med, rng.x, rng.y, r.purpose])
	for lp: Vector3 in low.slice(0, 3):
		fail(ctx, r, lp, "headroom below %.1f m" % HEADROOM)


func _floor_under(ctx: LcContext, at: Vector3) -> Variant:
	var hit: Dictionary = ctx.ray(at, at + Vector3.DOWN * 4.0, func(h: Dictionary) -> bool:
		return ctx.prop_of(h.get("collider")) == null and ctx.accept_shell(h) and (h["normal"] as Vector3).y > 0.7)
	return null if hit.is_empty() else (hit["position"] as Vector3).y


func _check_prop(ctx: LcContext, p: LcProp) -> void:
	if p.kind == &"camera" or p.kind == &"security_camera":
		if p.mount != &"ceiling":
			var fy: Variant = _floor_under(ctx, p.center())
			if fy != null and not _in(p.center().y - float(fy), CAMERA_RANGE, 0.0):
				fail(ctx, p.node, null, "camera at %.2f m above floor, need %.1f-%.1f m or ceiling mount"
					% [p.center().y - float(fy), CAMERA_RANGE.x, CAMERA_RANGE.y])
		return
	if p.kind == &"chair":
		var seat: Node3D = p.node.find_child("Seat", true, false) as Node3D
		if seat == null:
			warn(ctx, p.node, null, "chair has no `Seat` marker; seat height not checked")
			return
		var fy2: Variant = _floor_under(ctx, p.center() + Vector3.UP * 0.01)
		if fy2 != null and not _in(seat.global_position.y - float(fy2), CHAIR_SEAT, 0.0):
			fail(ctx, p.node, null, "chair seat %.2f m, need 0.45 m" % (seat.global_position.y - float(fy2)))
		return
	if not PROP_RULES.has(p.kind):
		return
	var rule: Array = PROP_RULES[p.kind]
	var rng: Vector2 = rule[1]
	var probe: Vector3 = p.center()
	if p.mount == &"wall":
		probe -= p.xform.basis.z.normalized() * 0.2
	var fy3: Variant = _floor_under(ctx, Vector3(probe.x, p.global_aabb.position.y + 0.05, probe.z))
	if fy3 == null:
		warn(ctx, p.node, null, "no floor found below; %s height not checked" % p.kind)
		return
	var v: float
	match String(rule[0]):
		"height":
			v = p.global_aabb.end.y - float(fy3)
		"centre":
			v = p.center().y - float(fy3)
		_:
			v = p.global_aabb.position.y - float(fy3)
	if not _in(v, rng, 0.02):
		fail(ctx, p.node, null, "%s %s %.3f m, need %.2f-%.2f m" % [p.kind, rule[0], v, rng.x, rng.y])


## Stairs: height profile along the stair's local Z axis (rays down, 1 cm steps) -> risers/treads.
func _check_stairs(ctx: LcContext, st: Node3D) -> void:
	var p: LcProp = ctx.prop_of(st)
	var local: AABB
	if p != null and p.node == st:
		local = p.local_aabb
	else:
		var tmp_box: Variant = LcCheckClipping._leaf_box(st)
		if tmp_box == null:
			fail(ctx, st, null, "stairs have no geometry")
			return
		local = tmp_box
	var xf: Transform3D = st.global_transform
	var width: float = local.size.x * xf.basis.x.length()
	if width < STAIR_MIN_WIDTH - 0.01:
		fail(ctx, st, null, "stair width %.2f m < %.1f m" % [width, STAIR_MIN_WIDTH])
	var top_y: float = (xf * local.end).y + 0.5
	var heights: Array[float] = []
	var cx: float = local.get_center().x
	var z: float = local.position.z - 0.3
	var zs: Array[float] = []
	while z <= local.end.z + 0.3:
		var w: Vector3 = xf * Vector3(cx, 0.0, z)
		var hit: Dictionary = ctx.ray(Vector3(w.x, top_y, w.z), Vector3(w.x, (xf * local.position).y - 1.0, w.z),
			func(h: Dictionary) -> bool: return (h["normal"] as Vector3).y > 0.7)
		heights.append(INF if hit.is_empty() else (hit["position"] as Vector3).y)
		zs.append(z)
		z += STAIR_SAMPLE
	# Segment into flats separated by jumps > 2 cm.
	var flats: Array[Dictionary] = []
	var cur: Dictionary = {}
	for i: int in range(heights.size()):
		var hgt: float = heights[i]
		if hgt == INF:
			fail(ctx, st, xf * Vector3(cx, 0.0, zs[i]), "stairs have a hole in their collision profile")
			return
		if cur.is_empty() or absf(hgt - float(cur["y"])) > 0.02:
			if not cur.is_empty():
				flats.append(cur)
			cur = {"y": hgt, "len": 0.0}
		cur["len"] = float(cur["len"]) + STAIR_SAMPLE
	if not cur.is_empty():
		flats.append(cur)
	if flats.size() < 3:
		fail(ctx, st, null, "stairs profile has no steps (collision must follow the steps)")
		return
	var dir_up: bool = float(flats[flats.size() - 1]["y"]) > float(flats[0]["y"])
	var bottom: float = minf(float(flats[0]["y"]), float(flats[flats.size() - 1]["y"]))
	var top: float = maxf(float(flats[0]["y"]), float(flats[flats.size() - 1]["y"]))
	var run_risers: int = 0
	var risers: int = 0
	for i2: int in range(1, flats.size()):
		var rise: float = absf(float(flats[i2]["y"]) - float(flats[i2 - 1]["y"]))
		risers += 1
		run_risers += 1
		if not _in(rise, STAIR_RISER, 0.003):
			fail(ctx, st, null, "riser %d is %.3f m, need %.2f-%.2f" % [risers, rise, STAIR_RISER.x, STAIR_RISER.y])
		if i2 < flats.size() - 1:
			var tread: float = float(flats[i2]["len"])
			if tread >= LANDING_MIN:
				run_risers = 0
			elif not _in(tread, STAIR_TREAD, 0.015):
				fail(ctx, st, null, "tread %d is %.3f m, need %.2f-%.2f" % [i2, tread, STAIR_TREAD.x, STAIR_TREAD.y])
		if run_risers > STAIR_MAX_RUN_RISERS:
			fail(ctx, st, null, "more than %d risers without a landing" % STAIR_MAX_RUN_RISERS)
			run_risers = 0
	note("`%s`: %d risers, %.3f -> %.3f m (%s)" % [ctx.node_path(st), risers, bottom, top, "up +Z" if dir_up else "up -Z"])
	var fh: PackedFloat32Array = ctx.map.floor_heights
	var matched: bool = false
	for i3: int in range(fh.size() - 1):
		for j3: int in range(i3 + 1, fh.size()):
			if absf(bottom - fh[i3]) <= 0.01 and absf(top - fh[j3]) <= 0.01:
				matched = true
	if not matched:
		fail(ctx, st, null, "stairs span %.3f -> %.3f m which does not match floor_heights %s" % [bottom, top, fh])
	# Headroom above each tread.
	for i4: int in range(0, heights.size(), 10):
		var w2: Vector3 = xf * Vector3(cx, 0.0, zs[i4])
		var base: Vector3 = Vector3(w2.x, heights[i4], w2.z)
		var up: Dictionary = ctx.ray(base + Vector3.UP * 0.05, base + Vector3.UP * HEADROOM, ctx.accept_shell)
		if not up.is_empty():
			fail(ctx, st, base, "stair headroom %.2f m < %.1f m" % [(up["position"] as Vector3).y - base.y, HEADROOM])
			break
