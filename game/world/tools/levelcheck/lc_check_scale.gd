## scale: human scale table of level_standards §2.6 + stairs vs HeistMap.floor_heights (§2.7)
## + ceilings exist indoors (§2.8).
class_name LcCheckScale
extends LcCheck

const TOL: float = 0.03
const DOOR_H: Vector2 = Vector2(2.1, 2.1)
const DOOR_SINGLE: Vector2 = Vector2(0.9, 0.9)
const DOOR_SERVICE: Vector2 = Vector2(1.0, 1.2)
const DOOR_DOUBLE: Vector2 = Vector2(1.8, 1.8)
## Vault doors (meta kind = "vault_door", or a door prefab with lock = VAULT): round or square.
const VAULT_DOOR_W: Vector2 = Vector2(1.8, 2.4)
const VAULT_DOOR_H: Vector2 = Vector2(2.0, 2.4)
const LOCK_VAULT: int = 6
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
	# plant / mechanical rooms are not in §2.6 either: like warehouse/industrial (lead to confirm).
	&"plant": Vector2(2.6, 6.0),
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
## Collision equal to the visual steps within this = stepped collision.
const STAIR_STEP_MATCH: float = 0.02
## Ramp collision must stay within [visual - this, visual + max riser + this] everywhere.
const STAIR_RAMP_TOL: float = 0.02
## Max horizontal gap between one flight's top and the next flight's bottom (shared landing).
const STAIR_CHAIN_GAP: float = 4.0
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
	var stairs: Array[Node] = []
	for n: Node in ctx.map.find_children("*", "Node3D", true, false):
		if LcUtil.meta_s(n, &"kind") == &"stairs" and ctx.is_active(n):
			stairs.append(n)
	if stairs.is_empty():
		return
	await LcVisual.build_proxies(ctx, stairs)
	var flights: Array[Dictionary] = []
	for st: Node in stairs:
		var f: Dictionary = _check_flight(ctx, st as Node3D)
		if not f.is_empty():
			flights.append(f)
	LcVisual.free_proxies(ctx)
	_check_chains(ctx, flights)


static func _in(v: float, r: Vector2, tol: float = TOL) -> bool:
	return v >= r.x - tol and v <= r.y + tol


static func is_vault_door(d: Node) -> bool:
	return LcUtil.meta_s(d, &"kind") == &"vault_door" or ("lock" in d and int(d.get("lock")) == LOCK_VAULT)


func _check_door(ctx: LcContext, d: Node3D) -> void:
	var total_w: float = 0.0
	var leaves: int = 0
	var vault: bool = is_vault_door(d)
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
		var hgt: float = lb.size.y * sy
		if vault and not _in(hgt, VAULT_DOOR_H):
			fail(ctx, leaf, null, "vault door height %.3f m, need %.1f-%.1f m" % [hgt, VAULT_DOOR_H.x, VAULT_DOOR_H.y])
		elif not vault and not _in(hgt, DOOR_H):
			fail(ctx, leaf, null, "door leaf height %.3f m, need %.2f m" % [hgt, DOOR_H.x])
	if leaves == 0:
		return
	var service: bool = LcUtil.meta_b(d, &"service")
	var ok: bool
	if vault:
		ok = _in(total_w, VAULT_DOOR_W)
	elif leaves == 2:
		ok = _in(total_w, DOOR_DOUBLE)
	else:
		ok = _in(total_w, DOOR_SINGLE) or (service and _in(total_w, DOOR_SERVICE))
	if not ok:
		fail(ctx, d, null, "door width %.3f m (%d leaf%s): single 0.9, double 1.8, service (meta service) 1.0-1.2, vault 1.8-2.4"
			% [total_w, leaves, ", vault" if vault else ""])


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


## One flight (`kind = "stairs"` node). Height profile along its local Z axis (rays down every
## 1 cm through the centre line, 0.3 m beyond both ends). The *visual* profile (proxies of the
## flight's meshes; beyond them, other collision) gives risers/treads; the *collision*
## profile must either follow the steps (stepped collision) or envelope them as a ramp:
## visual - 0.02 <= collision <= visual + max riser + 0.02 everywhere (so feet never sink into a
## tread and the ramp passes through the nosings). Returns { node, bottom, top, bottom_pt, top_pt }
## for chaining, or {} when the profile is unusable.
func _check_flight(ctx: LcContext, st: Node3D) -> Dictionary:
	var p: LcProp = ctx.prop_of(st)
	var local: AABB
	if p != null and p.node == st:
		local = p.local_aabb
	else:
		var tmp_box: Variant = LcCheckClipping._leaf_box(st)
		if tmp_box == null:
			fail(ctx, st, null, "stairs have no geometry")
			return {}
		local = tmp_box
	var xf: Transform3D = st.global_transform
	var width: float = local.size.x * xf.basis.x.length()
	if width < STAIR_MIN_WIDTH - 0.01:
		fail(ctx, st, null, "stair width %.2f m < %.1f m" % [width, STAIR_MIN_WIDTH])
	var top_y: float = (xf * local.end).y + 0.5
	var bot_y: float = (xf * local.position).y - 1.0
	var cx: float = local.get_center().x
	var zs: Array[float] = []
	var col: Array[float] = []
	var vis: Array[float] = []
	var up_ok: Callable = func(h: Dictionary) -> bool: return (h["normal"] as Vector3).y > 0.7
	# Beyond the flight's meshes the "visual" profile is whatever it lands on, minus its own colliders.
	var up_other: Callable = func(h: Dictionary) -> bool:
		var cn: Node = h.get("collider") as Node
		return (h["normal"] as Vector3).y > 0.7 and not (cn != null and (cn == st or st.is_ancestor_of(cn)))
	# Half-sample offset keeps rays off exact step edges; a miss is retried 2 mm either side.
	var z: float = local.position.z - 0.3 + STAIR_SAMPLE * 0.5
	while z <= local.end.z + 0.3:
		var cy: float = INF
		var vy: float = INF
		for dz: float in [0.0, 0.002, -0.002]:
			var w: Vector3 = xf * Vector3(cx, 0.0, z + dz)
			var a: Vector3 = Vector3(w.x, top_y, w.z)
			var b: Vector3 = Vector3(w.x, bot_y, w.z)
			if cy == INF:
				var hc: Dictionary = ctx.ray(a, b, up_ok)
				cy = INF if hc.is_empty() else (hc["position"] as Vector3).y
			if vy == INF:
				var hv: Dictionary = ctx.ray(a, b, up_ok, LcContext.PROXY_LAYER)
				vy = INF if hv.is_empty() else (hv["position"] as Vector3).y
		if vy == INF:
			var w2: Vector3 = xf * Vector3(cx, 0.0, z)
			var ho: Dictionary = ctx.ray(Vector3(w2.x, top_y, w2.z), Vector3(w2.x, bot_y, w2.z), up_other)
			vy = cy if ho.is_empty() else (ho["position"] as Vector3).y
		col.append(cy)
		vis.append(vy)
		zs.append(z)
		z += STAIR_SAMPLE
	for i: int in range(col.size()):
		if col[i] == INF:
			fail(ctx, st, xf * Vector3(cx, 0.0, zs[i]), "stairs have a hole in their collision profile")
			return {}
	var flats: Array[Dictionary] = _flats(vis)
	if flats.size() < 3:
		fail(ctx, st, null, "stairs profile has no visible steps")
		return {}
	_check_collision_profile(ctx, st, col, vis)
	_check_steps(ctx, st, flats)
	var first: Dictionary = flats[0]
	var last: Dictionary = flats[flats.size() - 1]
	var lo_end: Dictionary = first if float(first["y"]) < float(last["y"]) else last
	var hi_end: Dictionary = last if lo_end == first else first
	# Riser positions: where the low/high end flats meet the stair.
	var lo_i: int = int(lo_end["start"]) + int(lo_end["n"]) - 1 if lo_end == first else int(lo_end["start"])
	var hi_i: int = int(hi_end["start"]) if hi_end == last else int(hi_end["start"]) + int(hi_end["n"]) - 1
	var bottom: float = float(lo_end["y"])
	var top: float = float(hi_end["y"])
	note("`%s`: %d risers, %.3f -> %.3f m" % [ctx.node_path(st), flats.size() - 1, bottom, top])
	# Headroom above the profile.
	for i4: int in range(0, vis.size(), 10):
		var w2: Vector3 = xf * Vector3(cx, 0.0, zs[i4])
		var base: Vector3 = Vector3(w2.x, vis[i4], w2.z)
		var upr: Dictionary = ctx.ray(base + Vector3.UP * 0.05, base + Vector3.UP * HEADROOM, ctx.accept_shell)
		if not upr.is_empty():
			fail(ctx, st, base, "stair headroom %.2f m < %.1f m" % [(upr["position"] as Vector3).y - base.y, HEADROOM])
			break
	var bw: Vector3 = xf * Vector3(cx, 0.0, zs[lo_i])
	var tw: Vector3 = xf * Vector3(cx, 0.0, zs[hi_i])
	return {"node": st, "bottom": bottom, "top": top, "bottom_pt": Vector3(bw.x, bottom, bw.z),
		"top_pt": Vector3(tw.x, top, tw.z)}


## Flats of a height profile separated by jumps > 2 cm: [{ y, len, start, n }].
static func _flats(h: Array[float]) -> Array[Dictionary]:
	var flats: Array[Dictionary] = []
	var cur: Dictionary = {}
	for i: int in range(h.size()):
		if cur.is_empty() or absf(h[i] - float(cur["y"])) > 0.02:
			if not cur.is_empty():
				flats.append(cur)
			cur = {"y": h[i], "len": 0.0, "start": i, "n": 0}
		cur["len"] = float(cur["len"]) + STAIR_SAMPLE
		cur["n"] = int(cur["n"]) + 1
	if not cur.is_empty():
		flats.append(cur)
	return flats


func _check_collision_profile(ctx: LcContext, st: Node3D, col: Array[float], vis: Array[float]) -> void:
	var max_dev: float = 0.0
	var below: float = 0.0
	var above: float = 0.0
	for i: int in range(col.size()):
		max_dev = maxf(max_dev, absf(col[i] - vis[i]))
		below = maxf(below, vis[i] - col[i])
		above = maxf(above, col[i] - vis[i])
	if max_dev <= STAIR_STEP_MATCH:
		return
	if below <= STAIR_RAMP_TOL and above <= STAIR_RISER.y + STAIR_RAMP_TOL:
		note("`%s`: ramp collision enveloping the steps (max %.3f m above the treads)" % [ctx.node_path(st), above])
		return
	fail(ctx, st, null, "stair collision neither follows the steps nor envelopes them as a ramp "
		+ "(%.3f m below / %.3f m above the visual steps)" % [below, above])


func _check_steps(ctx: LcContext, st: Node3D, flats: Array[Dictionary]) -> void:
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


## Flights chain when one's top equals the next one's bottom (+-0.01 m) within STAIR_CHAIN_GAP
## horizontally (a shared landing). Every flight must lie on a chain that starts at one
## floor height and ends at a higher one (level_standards §2.7).
func _check_chains(ctx: LcContext, flights: Array[Dictionary]) -> void:
	var fh: PackedFloat32Array = ctx.map.floor_heights
	var ok: Dictionary = {}
	for i: int in range(flights.size()):
		if _floor_index(fh, float(flights[i]["bottom"])) >= 0:
			_chain_dfs(flights, [i], fh, ok)
	for j: int in range(flights.size()):
		var f: Dictionary = flights[j]
		if not ok.has(j):
			fail(ctx, f["node"], null, "stairs span %.3f -> %.3f m and no chain of flights through it joins two floor_heights %s"
				% [f["bottom"], f["top"], fh])


static func _floor_index(fh: PackedFloat32Array, y: float) -> int:
	for i: int in range(fh.size()):
		if absf(fh[i] - y) <= 0.01:
			return i
	return -1


static func _chain_dfs(flights: Array[Dictionary], path: Array, fh: PackedFloat32Array, ok: Dictionary) -> void:
	var last: Dictionary = flights[int(path[path.size() - 1])]
	var start_floor: int = _floor_index(fh, float(flights[int(path[0])]["bottom"]))
	var end_floor: int = _floor_index(fh, float(last["top"]))
	if end_floor > start_floor:
		for k: int in path:
			ok[k] = true
	if path.size() >= 8:
		return
	for j: int in range(flights.size()):
		if j in path:
			continue
		var nx: Dictionary = flights[j]
		var gap: Vector3 = (nx["bottom_pt"] as Vector3) - (last["top_pt"] as Vector3)
		if absf(float(nx["bottom"]) - float(last["top"])) <= 0.01 and Vector2(gap.x, gap.z).length() <= STAIR_CHAIN_GAP:
			var p2: Array = path.duplicate()
			p2.append(j)
			_chain_dfs(flights, p2, fh, ok)
