## furniture_logic (all stages, PO-9 / D-105): plausible furniture arrangement, inferred from
## geometry and prop ids, never from authored `faces` metas (the orientation check trusts those).
## Rules (tolerances in the consts; algorithm in tools/levelcheck/README.md):
##   seat_facing   a seat within SEAT_REACH of a desk / table / counter faces its nearest one
##   seat_side     desk chairs sit on the desk's user side, visitor chairs on the far side
##   seat_pair     two seats never face each other with no table between them
##   door_clear    no prop in a door's clear zone (leaf width x DOOR_DEPTH each side)
##   use_point     no prop in the standing volume of a gameplay UsePoint
##   duplicate     no identical props stacked on the same spot
##   overlap       (WARN) props whose boxes interpenetrate outside designed stacks (or meta `inside` contents, clipping)
##   wall_back     wall furniture stands with its back to the wall, never facing it
## Classification lives in ONE place: FURNITURE_BY_ASSET (catalog asset id = scene file basename)
## then FURNITURE_BY_KIND (meta kind); a node meta `furniture` overrides both. Owner: ENV C.
class_name LcCheckFurnitureLogic
extends LcCheck

const SEAT_REACH: float = 1.2         ## seat centre to table footprint (m)
const FACE_TOL_DEG: float = 45.0
const PAIR_DIST: float = 2.4          ## seats closer than this (centres) are tested as a pair
const DOOR_DEPTH: float = 1.0
const DOOR_BAND: Vector2 = Vector2(0.05, 2.0)
## Step-in rooms (closets, footprint below this) keep only STEP_IN_DEPTH clear on their side.
const STEP_IN_AREA: float = 2.5
const STEP_IN_DEPTH: float = 0.6
const BLOCK_DEPTH: float = 0.05       ## door / UsePoint intrusions deeper than this fail
const USE_HALF: Vector3 = Vector3(0.2, 0.7, 0.2)   ## standing box half extents at a UsePoint
const DUP_DIST: float = 0.05
const DUP_YAW_DEG: float = 5.0
const OVERLAP_DEPTH: float = 0.05
const THIN: float = 0.03              ## rugs / mats / floor decals never block anything
const WALL_BACK_MAX: float = 0.15
const WALL_SEARCH: float = 0.6
const FRONT_CLEAR: Dictionary = {&"chair": 0.1, &"desk_chair": 0.1, &"visitor_chair": 0.1, &"stool": 0.1,
	&"lounge_seat": 0.1, &"monitor": 0.3, &"wall_unit": WALL_BACK_MAX}

## Catalog asset id -> furniture class (only where the kind alone is not enough).
const FURNITURE_BY_ASSET: Dictionary = {
	&"prop_chair_office": &"desk_chair", &"prop_chair_task": &"desk_chair",
	&"prop_chair_visitor": &"visitor_chair",
	&"prop_chair_break": &"chair", &"prop_chair_consult": &"chair",
	&"prop_side_table": &"", &"prop_coffee_table": &"low_table",
}
## Meta kind -> furniture class.
const FURNITURE_BY_KIND: Dictionary = {
	&"chair": &"chair", &"stool": &"stool", &"armchair": &"lounge_seat",
	&"desk": &"desk", &"workbench": &"desk", &"jeweler_bench": &"desk", &"console": &"desk",
	&"camera_station": &"desk",
	&"table": &"table", &"check_table": &"table", &"mirror_table": &"table", &"coffee_table": &"low_table",
	&"counter_service": &"counter", &"counter_transaction": &"counter", &"counter_bar": &"counter",
	&"kitchen_counter": &"counter", &"teller_worktop": &"counter",
	&"sofa": &"wall_unit", &"credenza": &"wall_unit", &"bookshelf": &"wall_unit", &"lockers": &"wall_unit",
	&"file_cabinet": &"wall_unit", &"wardrobe": &"wall_unit", &"fridge": &"wall_unit", &"key_cabinet": &"wall_unit",
	&"monitor": &"monitor", &"tv": &"monitor",
}
const SEATS: Array[StringName] = [&"chair", &"desk_chair", &"visitor_chair", &"stool", &"lounge_seat"]
const SURFACES: Array[StringName] = [&"desk", &"table", &"low_table", &"counter"]
## Kinds that never block a door or a UsePoint (they are the door / walk-on / pick-up items).
const PASSIVE_KINDS: Array[StringName] = [&"door", &"vault_door", &"industrial_door", &"shutter", &"hatch", &"window",
	&"stairs",
	&"loot_spawn", &"loot_bag", &"small_loot", &"rug", &"light_fixture", &"railing", &"handrail",
	&"laser_grid", &"laser_emitter"]

var _cls: Dictionary = {}       # LcProp -> class
var _oriented: Dictionary = {}  # LcProp -> bool (front = -Z is meaningful)


func _init() -> void:
	id = &"furniture_logic"
	title = "Furniture arranged plausibly"


## Furniture class of a node: meta `furniture`, else the asset table, else the kind table.
static func classify(n: Node) -> StringName:
	if n.has_meta(&"furniture"):
		return StringName(str(n.get_meta(&"furniture")))
	var asset: StringName = asset_id(n)
	if asset != &"" and FURNITURE_BY_ASSET.has(asset):
		return FURNITURE_BY_ASSET[asset]
	return FURNITURE_BY_KIND.get(LcUtil.meta_s(n, &"kind"), &"")


## Catalog asset id of a prop instance (scene file basename), or &"".
static func asset_id(n: Node) -> StringName:
	if n.scene_file_path == "":
		return &""
	return StringName(n.scene_file_path.get_file().get_basename())


func run(ctx: LcContext) -> void:
	_cls.clear()
	_oriented.clear()
	var active: Array[LcProp] = []
	var counts: Dictionary = {}
	for p: LcProp in ctx.props:
		if not ctx.is_active(p.node) or not p.has_geometry:
			continue
		active.append(p)
		var c: StringName = classify(p.node)
		_cls[p] = c
		# Seats are always authored front = -Z; other furniture only when it is a catalog asset
		# (greybox boxes have no front) or carries an explicit `furniture` meta.
		_oriented[p] = c in SEATS or p.node.has_meta(&"furniture") \
			or (asset_id(p.node) != &"" and PropCatalog.entry(asset_id(p.node)).size() > 0)
		if c != &"":
			counts[c] = int(counts.get(c, 0)) + 1
	var seats: Array[LcProp] = []
	var surfaces: Array[LcProp] = []
	for p: LcProp in active:
		if _cls[p] in SEATS:
			seats.append(p)
		elif _cls[p] in SURFACES:
			surfaces.append(p)
	for s: LcProp in seats:
		_check_seat(ctx, s, surfaces)
	for i: int in range(seats.size()):
		for j: int in range(i + 1, seats.size()):
			_check_pair(ctx, seats[i], seats[j], surfaces)
	for d: Node3D in ctx.doors:
		if ctx.is_active(d):
			_check_door(ctx, d, active)
	_check_use_points(ctx, active)
	_check_duplicates_and_overlaps(ctx, active)
	for p: LcProp in active:
		if _oriented[p] and FRONT_CLEAR.has(_cls[p]):
			_check_wall(ctx, p)
	var keys: Array = counts.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys:
		parts.append("%s %d" % [k, counts[k]])
	note("classified: " + (", ".join(parts) if not parts.is_empty() else "nothing"))
	note("%d seats, %d tables/desks/counters, %d doors checked" % [seats.size(), surfaces.size(), ctx.doors.size()])


# --- 2D footprint helpers (props are upright; the OBB's X/Z axes span the footprint) ---------

static func _rect_local(o: Dictionary, p: Vector3) -> Vector2:
	var ax: Array[Vector3] = o["ax"]
	var d: Vector3 = p - (o["c"] as Vector3)
	return Vector2(d.dot(ax[0]), d.dot(ax[2]))


## Closest point (world, at p.y) on an OBB's footprint rectangle to p; p itself when inside.
static func closest_on_rect(o: Dictionary, p: Vector3) -> Vector3:
	var ax: Array[Vector3] = o["ax"]
	var h: Vector3 = o["h"]
	var l: Vector2 = _rect_local(o, p)
	var cl: Vector2 = Vector2(clampf(l.x, -h.x, h.x), clampf(l.y, -h.z, h.z))
	var c: Vector3 = o["c"]
	var w: Vector3 = c + ax[0] * cl.x + ax[2] * cl.y
	return Vector3(w.x, p.y, w.z)


static func in_rect(o: Dictionary, p: Vector3, inflate: float = 0.0) -> bool:
	var h: Vector3 = o["h"]
	var l: Vector2 = _rect_local(o, p)
	return absf(l.x) <= h.x + inflate and absf(l.y) <= h.z + inflate


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Yaw error (deg) between a prop's front (-Z) and the direction `to`.
static func facing_error(xf: Transform3D, to: Vector3) -> float:
	var f: Vector2 = _flat(-xf.basis.z)
	var t: Vector2 = _flat(to)
	if f.length() < 1e-6 or t.length() < 1e-6:
		return 0.0
	return rad_to_deg(absf(f.angle_to(t)))


static func _exclusive(a: LcProp, b: LcProp) -> bool:
	if a.slot != null and b.slot != null and a.slot != b.slot and a.slot.slot_group == b.slot.slot_group:
		return true
	# QC-87c: two convoy layouts (meta `convoy_layout`, RT clean / crash) are never shown together
	var la: Node = _layout_of(a.node)
	var lb: Node = _layout_of(b.node)
	return la != null and lb != null and la != lb


static func _layout_of(n: Node) -> Node:
	var cur: Node = n
	while cur != null:
		if cur.has_meta(&"convoy_layout"):
			return cur
		cur = cur.get_parent()
	return null


func _seat_point(s: LcProp) -> Vector3:
	var c: Vector3 = s.center()
	return Vector3(c.x, s.bottom_y(), c.z)


## Nearest desk / table / counter to a seat: [prop, distance] or [null, INF]. Only surfaces at the
## seat's floor (within 0.3 m) count; armchairs only pair with tables.
func _nearest_surface(s: LcProp, surfaces: Array[LcProp]) -> Array:
	var best: LcProp = null
	var best_d: float = INF
	var sp: Vector3 = _seat_point(s)
	for t: LcProp in surfaces:
		if _exclusive(s, t) or absf(t.bottom_y() - s.bottom_y()) > 0.3:
			continue
		if _cls[s] == &"lounge_seat" and not (_cls[t] in [&"table", &"low_table"]):
			continue
		var d: float = _flat(closest_on_rect(t.obb, sp) - sp).length()
		if d < best_d or (is_equal_approx(d, best_d) and best != null and String(t.node.name) < String(best.node.name)):
			best = t
			best_d = d
	return [best, best_d]


func _check_seat(ctx: LcContext, s: LcProp, surfaces: Array[LcProp]) -> void:
	var nt: Array = _nearest_surface(s, surfaces)
	var t: LcProp = nt[0]
	if t == null or float(nt[1]) > SEAT_REACH:
		return
	var sp: Vector3 = _seat_point(s)
	var to: Vector3 = closest_on_rect(t.obb, sp) - sp
	if _flat(to).length() < 0.05:
		to = t.center() - sp
	var err: float = facing_error(s.xform, to)
	if err > FACE_TOL_DEG:
		fail(ctx, s.node, null, "seat_facing: %s %.2f m from `%s` faces %.0f deg away from it (tolerance %.0f)"
			% [_cls[s], float(nt[1]), ctx.node_path(t.node), err, FACE_TOL_DEG])
	if _cls[t] != &"desk":
		return
	var user: int = _user_side(ctx, t)
	if user < 0:
		return
	var side: int = _side_of(t, sp)
	if side == user:
		if _cls[s] == &"visitor_chair":
			fail(ctx, s.node, null, "seat_side: visitor chair on the user side of desk `%s` (visitors sit across the desk)"
				% ctx.node_path(t.node))
		return
	match _cls[s]:
		&"desk_chair":
			fail(ctx, s.node, null, "seat_side: desk chair on the %s of desk `%s`, not at its knee hole"
				% [_side_name(side, user), ctx.node_path(t.node)])
		&"visitor_chair":
			if side != (user + 2) % 4:
				fail(ctx, s.node, null, "seat_side: visitor chair at the %s of desk `%s` (visitors sit across the desk)"
					% [_side_name(side, user), ctx.node_path(t.node)])
		&"chair", &"stool":
			if not _has_user_seat(t, user):
				fail(ctx, s.node, null, "seat_side: the only seat at desk `%s` is on its %s, not at the user side"
					% [ctx.node_path(t.node), _side_name(side, user)])


static func _side_name(side: int, user: int) -> String:
	return "far side" if side == (user + 2) % 4 else "end"


## Side of a footprint rectangle a point lies on: 0 = -Z, 1 = +X, 2 = +Z, 3 = -X (OBB local).
static func _side_of(t: LcProp, p: Vector3) -> int:
	var h: Vector3 = t.obb["h"]
	var l: Vector2 = _rect_local(t.obb, p)
	var ex: float = absf(l.x) - h.x
	var ez: float = absf(l.y) - h.z
	if ez >= ex:
		return 2 if l.y > 0.0 else 0
	return 1 if l.x > 0.0 else 3


## User (knee-hole) side of a desk: -Z for catalog assets (prop front, the drawers face the user),
## else the side opposite a wall within 0.25 m of a long side; -1 = unknown.
func _user_side(ctx: LcContext, t: LcProp) -> int:
	if _oriented[t]:
		return 0
	var h: Vector3 = t.obb["h"]
	var ax: Array[Vector3] = t.obb["ax"]
	# probe across the short axis (out of the long sides)
	var across_z: bool = h.x >= h.z
	var axis: Vector3 = ax[2] if across_z else ax[0]
	var half: float = h.z if across_z else h.x
	var c: Vector3 = t.center() + Vector3.UP * (minf(0.5, h.y) - h.y)
	for sg: float in [1.0, -1.0]:
		var from: Vector3 = c + axis * sg * (half - 0.02)
		if not ctx.ray(from, from + axis * sg * 0.27, ctx.accept_shell).is_empty():
			if across_z:
				return 0 if sg > 0.0 else 2
			return 3 if sg > 0.0 else 1
	return -1


func _has_user_seat(t: LcProp, user: int) -> bool:
	for p: Variant in _cls.keys():
		var s: LcProp = p
		if _cls[s] in SEATS and _side_of(t, _seat_point(s)) == user \
				and _flat(closest_on_rect(t.obb, _seat_point(s)) - _seat_point(s)).length() <= SEAT_REACH:
			return true
	return false


func _check_pair(ctx: LcContext, a: LcProp, b: LcProp, surfaces: Array[LcProp]) -> void:
	if _exclusive(a, b) or absf(a.bottom_y() - b.bottom_y()) > 0.3:
		return
	var pa: Vector3 = _seat_point(a)
	var pb: Vector3 = _seat_point(b)
	var d: float = _flat(pb - pa).length()
	if d > PAIR_DIST or d < 0.01:
		return
	if facing_error(a.xform, pb - pa) > FACE_TOL_DEG or facing_error(b.xform, pa - pb) > FACE_TOL_DEG:
		return
	# a shared table between them makes it a normal place setting
	var steps: int = maxi(2, int(ceil(d / 0.05)))
	for t: LcProp in surfaces:
		if _exclusive(a, t) or _exclusive(b, t):
			continue
		for i: int in range(1, steps):
			if in_rect(t.obb, pa.lerp(pb, float(i) / float(steps))):
				return
	var first: LcProp = a if String(ctx.node_path(a.node)) < String(ctx.node_path(b.node)) else b
	var other: LcProp = b if first == a else a
	fail(ctx, first.node, null, "seat_pair: faces `%s` %.2f m away with no table between them"
		% [ctx.node_path(other.node), d])


# --- doors and use points --------------------------------------------------------------------

func _blocker(p: LcProp) -> bool:
	if p.is_door or p.is_window or p.kind in PASSIVE_KINDS or p.mount == &"ceiling":
		return false
	return p.local_aabb.size.y > THIN or p.mount != &""


## Leaf (and Leaf2) bounds in the door root's space with the leaves closed.
static func leaf_box(d: Node3D) -> Variant:
	var inv: Transform3D = d.global_transform.affine_inverse()
	var out: Variant = null
	for nm: String in ["Leaf", "Leaf2"]:
		var leaf: Node3D = d.find_child(nm, true, false) as Node3D
		if leaf == null:
			continue
		var closed: Transform3D = inv * leaf.get_parent_node_3d().global_transform * Transform3D(Basis.IDENTITY, leaf.position)
		var leaf_inv: Transform3D = leaf.global_transform.affine_inverse()
		var nodes: Array[Node] = [leaf]
		nodes.append_array(leaf.find_children("*", "", true, false))
		for c: Node in nodes:
			var box: Variant = LcVisual.geometry_local_aabb(c)
			if box is AABB:
				var rel: AABB = (closed * leaf_inv * (c as Node3D).global_transform) * (box as AABB)
				out = rel if out == null else (out as AABB).merge(rel)
	return out


func _check_door(ctx: LcContext, d: Node3D, active: Array[LcProp]) -> void:
	var dp: LcProp = ctx.prop_of(d)
	var lb: Variant = leaf_box(d)
	if lb == null:
		if dp == null:
			return
		lb = dp.local_aabb
	var leaf: AABB = lb
	var zc: float = leaf.get_center().z
	var zone_xf: Transform3D = Transform3D(d.global_transform.basis.orthonormalized(), d.global_transform.origin)
	var depth_m: Array[float] = []
	for sg: float in [-1.0, 1.0]:
		var probe: Vector3 = zone_xf * Vector3(leaf.get_center().x, 1.0, zc + sg * 0.5)
		var room: RoomVolume = ctx.room_at(probe)
		var step_in: bool = room != null and LcAreas.footprint(room) < STEP_IN_AREA
		depth_m.append(STEP_IN_DEPTH if step_in else DOOR_DEPTH)
	var zone := AABB(Vector3(leaf.position.x, DOOR_BAND.x, zc - depth_m[0]),
		Vector3(leaf.size.x, DOOR_BAND.y - DOOR_BAND.x, depth_m[0] + depth_m[1]))
	var zo: Dictionary = LcGeom.obb(zone_xf, zone)
	var wb: AABB = zone_xf * zone
	for p: LcProp in active:
		if p == dp or not _blocker(p) or d.is_ancestor_of(p.node) or p.node.is_ancestor_of(d):
			continue
		if not wb.intersects(p.global_aabb):
			continue
		var depth: float = LcGeom.obb_overlap(zo, p.obb)
		if depth > BLOCK_DEPTH:
			_block(ctx, p, "door_clear: in the clear zone of door `%s` (%.1f / %.1f m each side, leaf width %.2f m) by %.2f m"
				% [ctx.node_path(d), depth_m[0], depth_m[1], leaf.size.x, depth])


## Dressing (catalog assets, anything under Props) fails; gameplay prefabs and variant content are
## placed for mission design and are only reported (WARN) for review.
func _block(ctx: LcContext, p: LcProp, msg: String) -> void:
	var under_props: bool = ctx.node_path(p.node).begins_with("Props/")
	var dressing: bool = asset_id(p.node) != &"" and String(PropCatalog.entry(asset_id(p.node)).get("prefab", "")) == "" \
		and PropCatalog.entry(asset_id(p.node)).size() > 0
	if under_props or dressing:
		fail(ctx, p.node, null, msg)
	else:
		warn(ctx, p.node, null, msg + " (gameplay prefab / variant content: review)")


func _check_use_points(ctx: LcContext, active: Array[LcProp]) -> void:
	for root_name: String in ["Gameplay", "Variants"]:
		var r: Node = ctx.map.get_node_or_null(root_name)
		if r == null:
			continue
		for n: Node in r.find_children("UsePoint", "Node3D", true, false):
			var up: Node3D = n as Node3D
			if not ctx.is_active(up):
				continue
			var owner_prop: LcProp = ctx.prop_of(up)
			var c: Vector3 = up.global_position + Vector3.UP * (0.1 + USE_HALF.y)
			var bo: Dictionary = LcGeom.obb(Transform3D(Basis.IDENTITY, c), AABB(-USE_HALF, USE_HALF * 2.0))
			var wb := AABB(c - USE_HALF, USE_HALF * 2.0)
			for p: LcProp in active:
				if p == owner_prop or not _blocker(p) or p.node.is_ancestor_of(up):
					continue
				if (owner_prop != null and _exclusive(owner_prop, p)) or not wb.intersects(p.global_aabb):
					continue
				var depth: float = LcGeom.obb_overlap(bo, p.obb)
				if depth > BLOCK_DEPTH:
					_block(ctx, p, "use_point: stands in the user's spot of `%s` (UsePoint @ %s) by %.2f m"
						% [ctx.node_path(up.get_parent()), fmt_v(up.global_position), depth])


# --- duplicates / overlaps -------------------------------------------------------------------

static func _ident(p: LcProp) -> String:
	if p.node.scene_file_path != "":
		return p.node.scene_file_path
	var s: Vector3 = p.local_aabb.size
	return "%s|%d|%d|%d" % [p.kind, roundi(s.x * 100.0), roundi(s.y * 100.0), roundi(s.z * 100.0)]


func _designed_stack(a: LcProp, b: LcProp) -> bool:
	# an item resting on a shelf / top inside the other's bounds, or a seat tucked under its table
	if a.bottom_y() > b.bottom_y() + 0.05 or b.bottom_y() > a.bottom_y() + 0.05:
		return true
	var ca: StringName = _cls.get(a, &"")
	var cb: StringName = _cls.get(b, &"")
	if (ca in SEATS and cb in SURFACES) or (cb in SEATS and ca in SURFACES):
		return true
	return a.mount != &"" or b.mount != &""


func _check_duplicates_and_overlaps(ctx: LcContext, active: Array[LcProp]) -> void:
	var cand: Array[LcProp] = []
	for p: LcProp in active:
		if not (p.is_door or p.is_window or p.kind in [&"stairs", &"rug"]):
			cand.append(p)
	for i: int in range(cand.size()):
		var a: LcProp = cand[i]
		for j: int in range(i + 1, cand.size()):
			var b: LcProp = cand[j]
			if _exclusive(a, b) or a.node.is_ancestor_of(b.node) or b.node.is_ancestor_of(a.node):
				continue
			if not a.global_aabb.grow(0.01).intersects(b.global_aabb):
				continue
			var first: LcProp = a if ctx.node_path(a.node) < ctx.node_path(b.node) else b
			var other: LcProp = b if first == a else a
			if _ident(a) == _ident(b) and a.xform.origin.distance_to(b.xform.origin) <= DUP_DIST:
				var ya: float = a.xform.basis.get_euler().y
				var yb: float = b.xform.basis.get_euler().y
				if rad_to_deg(absf(angle_difference(ya, yb))) <= DUP_YAW_DEG:
					fail(ctx, first.node, null, "duplicate: identical prop `%s` on the same spot (%.3f m apart)"
						% [ctx.node_path(other.node), a.xform.origin.distance_to(b.xform.origin)])
					continue
			if a.global_aabb.size.y <= THIN or b.global_aabb.size.y <= THIN or _designed_stack(a, b) \
					or LcCheckClipping._contained(a, b) or LcCheckClipping._contained(b, a):
				continue
			var depth: float = LcGeom.obb_overlap(a.obb, b.obb)
			if depth > OVERLAP_DEPTH:
				warn(ctx, first.node, null, "overlap: bounds interpenetrate `%s` by %.2f m (not a stack or a tucked seat)"
					% [ctx.node_path(other.node), depth])


# --- walls -----------------------------------------------------------------------------------

## Shell distance along `dir` from points on a face of the prop (min over samples); INF if none.
func _face_gap(ctx: LcContext, p: LcProp, back: bool, reach: float) -> float:
	var la: AABB = p.local_aabb
	var b: Basis = p.xform.basis.orthonormalized()
	var dir: Vector3 = b.z if back else -b.z
	var zf: float = la.end.z if back else la.position.z
	var best: float = INF
	for fx: float in [0.25, 0.5, 0.75]:
		for fy: float in [0.3, 0.7]:
			var lp: Vector3 = Vector3(lerpf(la.position.x, la.end.x, fx), lerpf(la.position.y, la.end.y, fy), zf)
			var wp: Vector3 = p.xform * lp
			var from: Vector3 = wp - dir * 0.02
			var hit: Dictionary = ctx.ray(from, wp + dir * reach, ctx.accept_shell)
			if not hit.is_empty():
				best = minf(best, maxf(0.0, (hit["position"] as Vector3).distance_to(from) - 0.02))
	return best


func _check_wall(ctx: LcContext, p: LcProp) -> void:
	var c: StringName = _cls[p]
	var front_tol: float = float(FRONT_CLEAR[c])
	var front: float = _face_gap(ctx, p, false, front_tol)
	if front <= front_tol:
		fail(ctx, p.node, null, "wall_back: %s faces a wall %.2f m in front of it (needs > %.2f m)" % [c, front, front_tol])
		return
	if c != &"wall_unit":
		return
	var back: float = _face_gap(ctx, p, true, WALL_SEARCH)
	if back > WALL_BACK_MAX and back <= WALL_SEARCH:
		fail(ctx, p.node, null, "wall_back: %s stands %.2f m off the wall behind it (back within %.2f m)"
			% [asset_id(p.node) if asset_id(p.node) != &"" else p.kind, back, WALL_BACK_MAX])
