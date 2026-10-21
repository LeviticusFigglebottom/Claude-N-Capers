## clipping: props vs world and vs each other; door swing arcs (level_standards §3.2).
class_name LcCheckClipping
extends LcCheck

const TOL_PEN: float = 0.005
const ARC_INFLATE: float = 0.05     ## props this close to a swing arc count as hit
const ARC_HEIGHTS: Array[float] = [0.1, 0.4, 0.8, 1.2, 1.6, 2.0]
const ARC_ANGLE_STEP_DEG: float = 5.0
const ARC_RADIAL_STEP: float = 0.1

var _reported: Dictionary = {}


func _init() -> void:
	id = &"clipping"
	title = "Nothing clips"


func run(ctx: LcContext) -> void:
	_reported.clear()
	var active: Array[LcProp] = []
	for p: LcProp in ctx.props:
		if ctx.is_active(p.node) and p.has_geometry:
			active.append(p)
	for p: LcProp in active:
		_physics_pass(ctx, p)
	# OBB vs OBB for pairs where neither prop has colliders (physics cannot see them).
	for i: int in range(active.size()):
		for j: int in range(i + 1, active.size()):
			var a: LcProp = active[i]
			var b: LcProp = active[j]
			if a.has_colliders() or b.has_colliders() or _exclusive(a, b) or _contained(a, b) or _contained(b, a):
				continue
			if not a.global_aabb.grow(0.01).intersects(b.global_aabb):
				continue
			var depth: float = LcGeom.obb_overlap(a.obb, b.obb)
			if depth > TOL_PEN:
				_report(ctx, a, b.node, depth, a.center())
	for d: Node3D in ctx.doors:
		if ctx.is_active(d):
			_check_door_arc(ctx, d, active)
	note("%d props, %d doors checked" % [active.size(), ctx.doors.size()])


## SL-2: designed contents of a hollow prop (meta `inside` = the sibling prop's node name, e.g. a lift car's floor
## drop inside the escape fit-out of the same car): skipped only while `a`'s box lies wholly inside `b`'s.
static func _contained(a: LcProp, b: LcProp) -> bool:
	if String(a.node.get_meta(&"inside", "")) != String(b.node.name) or a.node.get_parent() != b.node.get_parent():
		return false
	return b.global_aabb.grow(0.01).encloses(a.global_aabb)


## Props in different slots of the same group never coexist; nor do two props one of which names the other in its
## meta `never_with` (node names: OF-C2, a prefab that is only enabled once the other is disabled, e.g. Ostrander
## Federal's rope ladder, hidden and out of physics until the burn removes the lid it hangs through).
static func _exclusive(a: LcProp, b: LcProp) -> bool:
	if a.slot != null and b.slot != null and a.slot != b.slot and a.slot.slot_group == b.slot.slot_group:
		return true
	return _never_with(a, b) or _never_with(b, a)


static func _never_with(a: LcProp, b: LcProp) -> bool:
	var names: Variant = a.node.get_meta(&"never_with", [])
	return (names is Array or names is PackedStringArray) and String(b.node.name) in names


func _query_shapes(p: LcProp) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in p.shapes:
		out.append({"shape": s["shape"], "xf": s["xf"], "visual": false})
	# The visual box is also tested against the building shell (visual mesh poking through walls).
	var bs: BoxShape3D = BoxShape3D.new()
	var o: Dictionary = p.obb
	bs.size = (o["h"] as Vector3) * 2.0
	var ax: Array[Vector3] = o["ax"]
	out.append({"shape": bs, "xf": Transform3D(Basis(ax[0], ax[1], ax[2]), o["c"]), "visual": true})
	return out


func _physics_pass(ctx: LcContext, p: LcProp) -> void:
	for qs: Dictionary in _query_shapes(p):
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		q.shape = qs["shape"]
		q.transform = qs["xf"]
		q.collision_mask = LcContext.QUERY_MASK
		q.exclude = p.rids
		var hits: Array[Dictionary] = ctx.space().intersect_shape(q, 64)
		var cand: Array[RID] = []
		for h: Dictionary in hits:
			if not (h["rid"] in cand):
				cand.append(h["rid"])
		for h2: Dictionary in hits:
			var col: Object = h2.get("collider")
			if col == null or not ctx.is_active(col as Node):
				continue
			var other: LcProp = ctx.prop_of(col)
			var visual: bool = bool(qs["visual"])
			if other == null:
				# Shell: doors/windows sit in openings, skip them vs the shell.
				if p.is_door or p.is_window or p.kind == &"stairs":
					continue
			else:
				if other == p or _exclusive(p, other):
					continue
				# Visual box vs other props only when this prop has no colliders.
				if visual and p.has_colliders():
					continue
			var ex: Array[RID] = p.rids.duplicate()
			for r: RID in cand:
				if r != h2["rid"]:
					ex.append(r)
			q.exclude = ex
			var depth: float = _depth(ctx.space().collide_shape(q, 32))
			q.exclude = p.rids
			if depth > TOL_PEN:
				var target: Node = col as Node
				if other != null:
					target = other.node
				_report(ctx, p, target, depth, p.center())


static func _depth(pairs: Array[Vector3]) -> float:
	var best: float = 0.0
	for i: int in range(0, pairs.size() - 1, 2):
		best = maxf(best, pairs[i].distance_to(pairs[i + 1]))
	return best


func _report(ctx: LcContext, p: LcProp, other: Node, depth: float, pos: Vector3) -> void:
	var a: String = ctx.node_path(p.node)
	var b: String = ctx.node_path(other)
	var key: String = a + "|" + b if a < b else b + "|" + a
	if _reported.has(key):
		return
	_reported[key] = true
	fail(ctx, p.node, pos, "clips `%s` by %.3f m (tolerance %.3f m)" % [b, depth, TOL_PEN])


## Door swing: quarter circle swept by each leaf (pivot = hinge, rotates around Y) on the side
## the door opens to. Side: meta swing_side "front" (-Z of the leaf, default) | "back" | "both";
## a `swing` property == 2 (DOUBLE) means both.
func _check_door_arc(ctx: LcContext, door: Node3D, active: Array[LcProp]) -> void:
	var leaves: Array[Node3D] = []
	for leaf_name: String in ["Leaf", "Leaf2"]:
		var l: Node3D = door.find_child(leaf_name, true, false) as Node3D
		if l != null:
			leaves.append(l)
	if leaves.is_empty():
		warn(ctx, door, null, "door has no Leaf node; swing arc not checked")
		return
	var side: String = String(LcUtil.meta_s(door, &"swing_side"))
	# DOUBLE (swing 2) opens both leaves toward the back (door.gd); without a swing_side meta, check both sides
	if "swing" in door and int(door.get("swing")) == 2 and not door.has_meta(&"swing_side"):
		side = "both"
	if side == "":
		side = "front"
	var door_prop: LcProp = ctx.prop_of(door)
	for leaf: Node3D in leaves:
		var box: Variant = _leaf_box(leaf)
		if box == null:
			warn(ctx, leaf, null, "door leaf has no mesh; swing arc not checked")
			continue
		var lb: AABB = box
		# Leaf extends from the hinge along local +X or -X.
		var ext: float = lb.end.x if absf(lb.end.x) >= absf(lb.position.x) else lb.position.x
		var w: float = absf(ext)
		var xdir: Vector3 = leaf.global_basis.x.normalized() * signf(ext)
		var zfwd: Vector3 = -leaf.global_basis.z.normalized()
		var sides: Array[float] = []
		if side == "front" or side == "both":
			sides.append(1.0)
		if side == "back" or side == "both":
			sides.append(-1.0)
		var hinge: Vector3 = leaf.global_position
		var hit: Dictionary = {}
		var reach: AABB = AABB(hinge - Vector3(w, 0.0, w), Vector3(2.0 * w, 0.0, 2.0 * w))
		reach.position.y = hinge.y + lb.position.y
		reach.size.y = 2.2
		reach = reach.grow(ARC_INFLATE)
		var near: Array[LcProp] = []
		for o0: LcProp in active:
			if o0 != door_prop and not o0.is_door and o0.global_aabb.intersects(reach):
				near.append(o0)
		for sg: float in sides:
			var a: float = 0.0
			while a <= 90.0 + 0.001:
				var dir: Vector3 = (xdir * cos(deg_to_rad(a)) + zfwd * sg * sin(deg_to_rad(a))).normalized()
				var r: float = ARC_RADIAL_STEP
				while r <= w + 0.001:
					for hy: float in ARC_HEIGHTS:
						var pt: Vector3 = hinge + dir * r + Vector3.UP * (hy + lb.position.y)
						for o: LcProp in near:
							if hit.has(o):
								continue
							if LcGeom.point_in_obb(pt, o.obb, ARC_INFLATE):
								hit[o] = pt
					r += ARC_RADIAL_STEP
				a += ARC_ANGLE_STEP_DEG
		for o2: LcProp in hit.keys():
			fail(ctx, o2.node, hit[o2], "inside the swing arc of door `%s` (leaf `%s`, %.2f m)"
				% [ctx.node_path(door), leaf.name, w])


static func _leaf_box(leaf: Node3D) -> Variant:
	var inv: Transform3D = leaf.global_transform.affine_inverse()
	var out: Variant = null
	var nodes: Array[Node] = [leaf]
	nodes.append_array(leaf.find_children("*", "", true, false))
	for c: Node in nodes:
		var b: Variant = LcVisual.geometry_local_aabb(c)
		if b is AABB:
			var rel: AABB = (inv * (c as Node3D).global_transform) * (b as AABB)
			out = rel if out == null else (out as AABB).merge(rel)
	return out
