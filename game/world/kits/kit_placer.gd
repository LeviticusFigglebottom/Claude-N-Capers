## Deterministic, seeded dressing-kit placer (C1-07, ENV C). Given a KitRoom (clear interior,
## openings, keep-outs, anchors), a DressingKit and a seed, picks props from the prop catalog
## (world/props/prop_catalog.json) and places them against walls, in corners, at desks, on top of
## supports, on walls and on the ceiling, with no overlaps and the levelcheck metas.
##
## Usage (map generator / tool code):
##   var room := KitRoom.from_volume(room_volume, 0.1)        # or KitRoom.from_aabb(clear_box)
##   room.add_door(door_world_pos, 0.9)                        # every door into the room
##   room.add_window(sill_centre_world, 1.0, 0.9, 2.1)         # windows (sill/head above floor)
##   room.add_keep_out(prefab_world_aabb)                      # gameplay prefabs, stairs ...
##   var res: Dictionary = KitPlacer.place(room, load("res://world/kits/break_room.tres"), 1234)
##   KitPlacer.instantiate(res, props_parent, scene_root)      # nodes + metas (+ owner for saving)
##
## Result: { "placements": Array[Dictionary], "hash": String, "warnings": PackedStringArray,
## "missing": PackedStringArray (required kinds that did not fit) }. A placement: { "asset",
## "scene", "kind", "mode", "mount", "xform" (world Transform3D), "local" (room-local Transform3D),
## "box" (room-local AABB), "faces" (index or -1), "host" (index or -1) }.
## Everything is a pure function of (room, kit, seed, catalog): same inputs, same layout.
class_name KitPlacer
extends RefCounted

const GAP: float = 0.012            # floor props: gap to the wall and between props
const MOUNT_GAP: float = 0.002      # wall/ceiling props: offset from the surface
const EDGE: float = 0.03            # keep props this far from wall ends / host edges
const TRIES: int = 60
const LONE_RADIUS: float = 1.9      # levelcheck lone-prop rule is 2.0 m in rooms > 12 m²
const LONE_AREA: float = 12.0
const TALL_ON: float = 0.15         # "on" items taller than this go to the back of the host
const SEAT_KINDS_AROUND: Array[StringName] = [&"table", &"coffee_table"]
const FLOOR_MODES: Array[String] = ["wall", "corner", "floor", "center", "seat"]
const ORDER: Dictionary = {"rug": -1, "row": 0, "wall": 0, "corner": 1, "center": 2, "floor": 3, "seat": 4, "on": 5,
	"wall_mount": 6, "above_door": 7, "ceiling": 8}


## Place `kit` in `room` with `seed`. `ceiling_fixtures` = false skips the kit's ceiling grid.
static func place(room: KitRoom, kit: DressingKit, seed: int, ceiling_fixtures: bool = true) -> Dictionary:
	var st := _State.new()
	st.room = room
	st.kit = kit
	st.rng.seed = ("%s|%s|%d|%d" % [kit.id, room.id, kit.seed_salt, seed]).hash()
	st.catalog = PropCatalog.load_catalog()
	st.max_count = maxi(kit.min_props, int(floor(room.area() * kit.max_density)))
	var t: float = st.rng.randf_range(0.3, 0.55)
	st.target = clampi(int(round(room.area() * lerpf(kit.min_density, kit.max_density, t))), kit.min_props, st.max_count)
	_reserve_openings(st)
	for a: Dictionary in room.anchors:
		_place_anchor(st, a)
	if ceiling_fixtures:
		_place_ceiling(st)
	var req: Array[StringName] = []
	for k: StringName in kit.required_items:
		req.append(k)
	req.sort_custom(func(a: StringName, b: StringName) -> bool: return _mode_rank(st, a) < _mode_rank(st, b))
	for k: StringName in req:
		if _count_kind(st, k) > 0:
			continue
		var n: int = _pick_count(st, k)
		var ok: int = 0
		for i: int in range(n):
			ok += 1 if _place_kind(st, k, -1, 0.0, i) else 0
		if ok == 0:
			st.missing.append(String(k))
	_place_optional(st)
	_place_clutter(st)
	_fix_lone(st)
	_finish_links(st)
	var out: Array[Dictionary] = []
	for p: Dictionary in st.placed:
		var q: Dictionary = p.duplicate()
		q["xform"] = room.xform * (p["local"] as Transform3D)
		out.append(q)
	return {"placements": out, "hash": layout_hash(out), "warnings": st.warnings, "missing": st.missing}


## Instance the placements under `parent`. `owner` (optional) is set on every new node so the map
## can be saved. Names are `<Kind>_<n>` (PascalCase, unique under parent). `faces` metas are
## sibling NodePaths. Returns the new nodes in placement order.
static func instantiate(result: Dictionary, parent: Node3D, owner: Node = null, name_prefix: String = "") -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	var used: Dictionary = {}
	for c: Node in parent.get_children():
		used[String(c.name)] = true
	var placements: Array = result["placements"]
	var parent_xf: Transform3D = parent.global_transform if parent.is_inside_tree() else KitRoom._chain(parent)
	for p: Variant in placements:
		var d: Dictionary = p
		var packed: PackedScene = load(String(d["scene"])) as PackedScene
		var n: Node3D = packed.instantiate() as Node3D
		var base: String = name_prefix + String(d["kind"]).to_pascal_case()
		var idx: int = 1
		while used.has("%s_%d" % [base, idx]):
			idx += 1
		n.name = "%s_%d" % [base, idx]
		used[String(n.name)] = true
		n.transform = parent_xf.affine_inverse() * (d["xform"] as Transform3D)
		parent.add_child(n)
		if owner != null:
			n.owner = owner
		nodes.append(n)
	for i: int in range(placements.size()):
		var f: int = int((placements[i] as Dictionary).get("faces", -1))
		if f >= 0 and f < nodes.size():
			nodes[i].set_meta(&"faces", NodePath("../" + String(nodes[f].name)))
	return nodes


## Layout hash like levelcheck `variety`: kind + room-local centre (0.25 m) + yaw (15 deg).
static func layout_hash(placements: Array) -> String:
	var rows: PackedStringArray = PackedStringArray()
	for p: Variant in placements:
		var d: Dictionary = p
		var lx: Transform3D = d["local"]
		var b: AABB = d["box"]
		var c: Vector3 = b.get_center()
		var yaw: float = rad_to_deg(lx.basis.get_euler().y)
		rows.append("%s|%d|%d|%d|%d" % [d["kind"], roundi(c.x / 0.25), roundi(c.y / 0.25), roundi(c.z / 0.25), roundi(yaw / 15.0)])
	rows.sort()
	return "|".join(rows).md5_text()


## Room-local boxes of every pair of placements that overlap by more than `eps` (tests/debug).
static func overlaps(result: Dictionary, eps: float = 0.002) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var ps: Array = result["placements"]
	for i: int in range(ps.size()):
		for j: int in range(i + 1, ps.size()):
			var a: AABB = (ps[i] as Dictionary)["box"]
			var b: AABB = (ps[j] as Dictionary)["box"]
			# an item on/at its host touches the host's (non-convex) bounds by design
			if int((ps[j] as Dictionary)["host"]) == i or int((ps[i] as Dictionary)["host"]) == j:
				continue
			if _hit(a, b, eps):
				out.append("%s #%d vs %s #%d" % [(ps[i] as Dictionary)["asset"], i, (ps[j] as Dictionary)["asset"], j])
	return out


# --- internals ---------------------------------------------------------------------------

class _State:
	extends RefCounted
	var room: KitRoom
	var kit: DressingKit
	var rng := RandomNumberGenerator.new()
	var catalog: Dictionary = {}
	## Placements (room-local): see the class doc.
	var placed: Array[Dictionary] = []
	## Blockers for floor props only: { "box": AABB, "owner": int }.
	var clear: Array[Dictionary] = []
	## Hard blockers for everything (doors' swing zones, keep-outs).
	var hard: Array[AABB] = []
	## Wall intervals mounted items may not use: { wall, u0, u1, z0, z1 }.
	var wall_holes: Array[Dictionary] = []
	var warnings: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	var target: int = 0
	var max_count: int = 0


static func _mode_rank(st: _State, kind: StringName) -> int:
	var ids: PackedStringArray = _assets_for(st, kind)
	if ids.is_empty():
		return 99
	return int(ORDER.get(String((st.catalog[ids[0]] as Dictionary).get("place", "floor")), 9))


static func _assets_for(st: _State, kind: StringName) -> PackedStringArray:
	if st.kit.assets.has(kind):
		var allowed: PackedStringArray = PackedStringArray()
		for a: Variant in st.kit.assets[kind]:
			if st.catalog.has(String(a)):
				allowed.append(String(a))
		if not allowed.is_empty():
			return allowed
	return PropCatalog.ids_of_kind(kind)


static func _pick_count(st: _State, kind: StringName) -> int:
	if st.kit.counts.has(kind):
		var v: Vector2i = st.kit.counts[kind]
		return st.rng.randi_range(v.x, maxi(v.x, v.y))
	return 1


static func _count_kind(st: _State, kind: StringName) -> int:
	var n: int = 0
	for p: Dictionary in st.placed:
		if StringName(String(p["kind"])) == kind:
			n += 1
	return n


static func _reserve_openings(st: _State) -> void:
	var r: KitRoom = st.room
	for o: Dictionary in r.openings:
		var w: int = int(o["wall"])
		var u: float = float(o["u"])
		var hw: float = float(o["width"]) * 0.5
		st.wall_holes.append({"wall": w, "u0": u - hw - 0.08, "u1": u + hw + 0.08, "z0": float(o["bottom"]) - 0.05,
			"z1": float(o["top"]) + 0.05})
		if bool(o["door"]):
			var depth: float = float(o["swing"])
			var a: Vector3 = r.wall_point(w, u - hw - 0.1)
			var b: Vector3 = r.wall_point(w, u + hw + 0.1) + KitRoom.wall_normal(w) * depth
			var box := AABB(a, Vector3.ZERO).expand(b)
			box.position.y = 0.0
			box.size.y = float(o["top"]) + 0.05
			st.hard.append(box)
	for k: AABB in r.keep_out:
		st.hard.append(k)


# --- geometry helpers --------------------------------------------------------------------

static func _box_of(_st: _State, asset: String, local: Transform3D) -> AABB:
	return local * PropCatalog.aabb(StringName(asset))


static func _hit(a: AABB, b: AABB, eps: float = 0.002) -> bool:
	return a.grow(-eps).intersects(b.grow(-eps))


static func _inside_room(st: _State, box: AABB) -> bool:
	var hx: float = st.room.size.x * 0.5 + 0.004
	var hz: float = st.room.size.z * 0.5 + 0.004
	return box.position.x >= -hx and box.end.x <= hx and box.position.z >= -hz and box.end.z <= hz \
		and box.position.y >= -0.004 and box.end.y <= st.room.size.y + 0.004


## True when `box` (a floor-standing prop unless `mounted`) is free. `ignore` = placement index
## whose boxes are skipped (a host for seats / on-top items).
static func _free(st: _State, box: AABB, floor_prop: bool, ignore: int = -1) -> bool:
	if not _inside_room(st, box):
		return false
	for h: AABB in st.hard:
		if _hit(box, h):
			return false
	for i: int in range(st.placed.size()):
		if i == ignore:
			continue
		if _hit(box, (st.placed[i] as Dictionary)["box"]):
			return false
	if floor_prop:
		for c: Dictionary in st.clear:
			if int(c["owner"]) != ignore and _hit(box, c["box"]):
				return false
	return true


static func _wall_free(st: _State, w: int, u0: float, u1: float, z0: float, z1: float) -> bool:
	if not st.room.walls[w]:
		return false
	if u0 < EDGE or u1 > st.room.wall_length(w) - EDGE:
		return false
	for h: Dictionary in st.wall_holes:
		if int(h["wall"]) == w and u1 > float(h["u0"]) and u0 < float(h["u1"]) and z1 > float(h["z0"]) and z0 < float(h["z1"]):
			return false
	return true


static func _xf(yaw: float, pos: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


## Local transform putting `asset`'s back against wall `w` at `u` (centre of the footprint).
static func _wall_xf(st: _State, asset: String, w: int, u: float, y: float = 0.0, gap: float = GAP) -> Transform3D:
	var bb: AABB = PropCatalog.aabb(StringName(asset))
	var yaw: float = KitRoom.wall_yaw(w)
	var n: Vector3 = KitRoom.wall_normal(w)
	var cx: float = bb.get_center().x
	var basis := Basis(Vector3.UP, yaw)
	var p: Vector3 = st.room.wall_point(w, u) + n * (bb.end.z + gap) - basis * Vector3(cx, 0.0, 0.0)
	p.y = y
	return Transform3D(basis, p)


static func _add(st: _State, asset: String, local: Transform3D, mode: String, host: int = -1) -> int:
	var e: Dictionary = st.catalog[asset]
	var box: AABB = _box_of(st, asset, local)
	st.placed.append({"asset": asset, "scene": e["scene"], "kind": e["kind"], "mode": mode, "mount": e.get("mount", ""),
		"local": local, "box": box, "faces": -1, "host": host})
	var idx: int = st.placed.size() - 1
	var clr: float = float(e.get("clear", 0.0))
	if clr > 0.0 and mode in FLOOR_MODES:
		var fr: Vector3 = -(local.basis.z.normalized())
		var a: Vector3 = Vector3(box.position.x, 0.0, box.position.z)
		var b: Vector3 = Vector3(box.end.x, 1.0, box.end.z)
		var zone := AABB(a, b - a)
		zone = zone.merge(AABB(a + fr * clr, b - a))
		st.clear.append({"box": zone, "owner": idx})
	return idx


# --- placement by mode -------------------------------------------------------------------

## `nth` >= 0 (required instances): the kit's asset list for the kind is used in order (cycling),
## so a designer can ask for e.g. one office chair then two visitor chairs.
static func _place_kind(st: _State, kind: StringName, near: int = -1, radius: float = 0.0, nth: int = -1) -> bool:
	if st.placed.size() >= st.max_count:
		return false
	var ids: PackedStringArray = _assets_for(st, kind)
	if ids.is_empty():
		st.warnings.append("no catalog asset of kind %s" % kind)
		return false
	var asset: String = ids[nth % ids.size()] if nth >= 0 and st.kit.assets.has(kind) else ids[st.rng.randi_range(0, ids.size() - 1)]
	return _place_asset(st, asset, near, radius)


static func _place_asset(st: _State, asset: String, near: int = -1, radius: float = 0.0) -> bool:
	var mode: String = String((st.catalog[asset] as Dictionary).get("place", "floor"))
	match mode:
		"wall", "corner":
			return _try_wall(st, asset, mode == "corner", near, radius)
		"floor", "center", "rug":
			return _try_floor(st, asset, mode != "floor", near, radius)
		"seat":
			return _try_seat(st, asset, near)
		"row":
			return _try_row(st, asset)
		"on":
			return _try_on(st, asset, near)
		"wall_mount":
			return _try_mount(st, asset)
		"above_door":
			return _try_above_door(st, asset)
		"ceiling":
			return _try_ceiling_one(st, asset)
	return false


static func _anchor_point(st: _State, near: int) -> Vector3:
	return (st.placed[near] as Dictionary)["box"].get_center() if near >= 0 else Vector3.ZERO


static func _try_wall(st: _State, asset: String, corner: bool, near: int, radius: float) -> bool:
	var bb: AABB = PropCatalog.aabb(StringName(asset))
	var half: float = bb.size.x * 0.5
	var top: float = bb.end.y
	for t: int in range(TRIES):
		var w: int = st.rng.randi_range(0, 3)
		var ln: float = st.room.wall_length(w)
		if ln < bb.size.x + 2.0 * EDGE:
			continue
		var u: float
		if corner:
			u = half + GAP + EDGE if st.rng.randf() < 0.5 else ln - half - GAP - EDGE
		else:
			u = st.rng.randf_range(half + EDGE, ln - half - EDGE)
		var lx: Transform3D = _wall_xf(st, asset, w, u)
		var box: AABB = _box_of(st, asset, lx)
		if near >= 0 and _gap2d(box, (st.placed[near] as Dictionary)["box"]) > radius:
			continue
		# under a window only when lower than its sill; never across a door
		if not _wall_free(st, w, u - half, u + half, 0.0, top):
			continue
		if _free(st, box, true):
			_add(st, asset, lx, "corner" if corner else "wall")
			return true
	return false


## Street furniture: a line parallel to a wall (facade) at the catalog `standoff` (curb line).
static func _try_row(st: _State, asset: String) -> bool:
	var bb: AABB = PropCatalog.aabb(StringName(asset))
	var standoff: float = float((st.catalog[asset] as Dictionary).get("standoff", 1.0))
	var walls: Array[int] = []
	for w: int in range(4):
		if st.room.walls[w]:
			walls.append(w)
	if walls.is_empty():
		walls = [0, 1, 2, 3]
	for t: int in range(TRIES):
		var w: int = walls[st.rng.randi_range(0, walls.size() - 1)]
		var u: float = st.rng.randf_range(bb.size.x * 0.5 + EDGE, st.room.wall_length(w) - bb.size.x * 0.5 - EDGE)
		var yaw: float = KitRoom.wall_yaw(w)
		var basis := Basis(Vector3.UP, yaw)
		var p: Vector3 = st.room.wall_point(w, u) + KitRoom.wall_normal(w) * standoff - basis * Vector3(bb.get_center().x, 0.0, bb.get_center().z)
		var lx := Transform3D(basis, Vector3(p.x, 0.0, p.z))
		var box: AABB = _box_of(st, asset, lx)
		if _free(st, box, true):
			_add(st, asset, lx, "row")
			return true
	return false


static func _try_floor(st: _State, asset: String, center: bool, near: int, radius: float) -> bool:
	var bb: AABB = PropCatalog.aabb(StringName(asset))
	var e: Dictionary = st.catalog[asset]
	var clr: float = float(e.get("clear", 0.0))
	var sx: float = st.room.size.x * 0.5
	var sz: float = st.room.size.z * 0.5
	for t: int in range(TRIES):
		var yaw: float = PI * 0.5 * st.rng.randi_range(0, 3)
		if center:
			yaw = 0.0 if st.room.size.x >= st.room.size.z else PI * 0.5
			yaw += PI * st.rng.randi_range(0, 1)
		var pos: Vector3
		if near >= 0:
			var c: Vector3 = _anchor_point(st, near)
			pos = Vector3(c.x + st.rng.randf_range(-radius, radius), 0.0, c.z + st.rng.randf_range(-radius, radius))
		elif center and t < TRIES / 2:
			pos = Vector3(st.rng.randfn(0.0, sx * 0.15), 0.0, st.rng.randfn(0.0, sz * 0.15))
		else:
			pos = Vector3(st.rng.randf_range(-sx, sx), 0.0, st.rng.randf_range(-sz, sz))
		var lx: Transform3D = _xf(yaw, pos)
		lx.origin -= lx.basis * Vector3(bb.get_center().x, 0.0, bb.get_center().z)
		var box: AABB = _box_of(st, asset, lx)
		# free-standing furniture keeps its clearance from the walls on every side
		var margin: float = minf(clr, 0.9) if not center else minf(clr, 0.6)
		var inner := AABB(Vector3(-sx + margin, -1.0, -sz + margin), Vector3(2.0 * (sx - margin), 10.0, 2.0 * (sz - margin)))
		if margin > 0.0 and not inner.encloses(box):
			continue
		var raise: float = _rug_lift(st, box)
		if raise < 0.0:
			continue
		if raise > 0.0:
			lx.origin.y += raise
			box = _box_of(st, asset, lx)
		if not _free(st, box, true, _rug_under(st, box)):
			continue
		if not _lone_ok(st, box):
			continue
		if clr > 0.0 and not _halo_free(st, box, clr * 0.6):
			continue
		_add(st, asset, lx, "center" if center else "floor")
		return true
	return false


## Free-standing furniture keeps a ring of `clr` free of other floor furniture and keep-outs, so its
## chairs / users fit around it (tables, executive desks, podiums).
static func _halo_free(st: _State, box: AABB, clr: float) -> bool:
	var halo := AABB(Vector3(box.position.x - clr, 0.0, box.position.z - clr), Vector3(box.size.x + 2.0 * clr, 1.2, box.size.z + 2.0 * clr))
	for h: AABB in st.hard:
		if _hit(halo, h):
			return false
	for p: Dictionary in st.placed:
		var b: AABB = p["box"]
		if b.position.y < 0.5 and b.size.y > 0.05 and _hit(halo, b):
			return false
	return true


## Rugs (thin support props) under a floor prop: the prop must sit fully on one (lifted by its
## thickness) or not touch it. Returns the lift, 0 for none, -1 for a partial overlap.
static func _rug_lift(st: _State, box: AABB) -> float:
	for p: Dictionary in st.placed:
		var b: AABB = p["box"]
		if b.size.y > 0.05 or not bool((st.catalog[p["asset"]] as Dictionary).get("support", false)):
			continue
		var flat := AABB(Vector3(box.position.x, b.position.y, box.position.z), Vector3(box.size.x, b.size.y, box.size.z))
		if not flat.grow(-0.002).intersects(b):
			continue
		if b.grow(0.002).encloses(flat):
			return b.end.y
		return -1.0
	return 0.0


static func _rug_under(st: _State, box: AABB) -> int:
	for i: int in range(st.placed.size()):
		var b: AABB = (st.placed[i] as Dictionary)["box"]
		if b.size.y <= 0.05 and b.end.y <= box.position.y + 0.002 and absf(b.end.y - box.position.y) < 0.003:
			var f := AABB(Vector3(box.position.x, b.position.y, box.position.z), Vector3(box.size.x, b.size.y, box.size.z))
			if b.grow(0.002).encloses(f):
				return i
	return -1


static func _try_seat(st: _State, asset: String, near: int) -> bool:
	var e: Dictionary = st.catalog[asset]
	var hosts: Array = e.get("hosts", [])
	var cands: Array[int] = []
	for i: int in range(st.placed.size()):
		if near >= 0 and i != near:
			continue
		if String((st.placed[i] as Dictionary)["kind"]) in hosts:
			cands.append(i)
	if cands.is_empty():
		return false
	var bb: AABB = PropCatalog.aabb(StringName(asset))
	var side_pref: String = String(e.get("seat_side", "front"))
	for t: int in range(TRIES):
		var hi: int = cands[st.rng.randi_range(0, cands.size() - 1)]
		var h: Dictionary = st.placed[hi]
		var hl: Transform3D = h["local"]
		var hb: AABB = PropCatalog.aabb(StringName(String(h["asset"])))
		var around: bool = StringName(String(h["kind"])) in SEAT_KINDS_AROUND
		var sides: Array[int] = [0]                   # 0 front (-Z), 1 back (+Z), 2 left (-X), 3 right (+X)
		if side_pref == "back":
			sides = [1, 2, 3]
		elif around:
			sides = [0, 1, 2, 3]
		var side: int = sides[st.rng.randi_range(0, sides.size() - 1)]
		var along: float = (hb.size.x if side < 2 else hb.size.z) * 0.5 - 0.3
		if not around:
			along = minf(along, 0.15)
		var off: float = st.rng.randf_range(-maxf(along, 0.0), maxf(along, 0.0))
		var push: float = st.rng.randf_range(0.06, 0.18 + 0.012 * float(t))
		var depth: float = -bb.position.z            # chair front half-depth from its pivot
		var hc: Vector3 = hb.get_center()
		var p: Vector3
		match side:
			0:
				p = Vector3(hc.x + off, 0.0, hb.position.z - push - depth)
			1:
				p = Vector3(hc.x + off, 0.0, hb.end.z + push + depth)
			2:
				p = Vector3(hb.position.x - push - depth, 0.0, hc.z + off)
			_:
				p = Vector3(hb.end.x + push + depth, 0.0, hc.z + off)
		# the chair's front (-Z) looks straight at the host centre (levelcheck `faces`, +-20 deg)
		var to: Vector3 = Vector3(hc.x, 0.0, hc.z) - p
		var yaw: float = atan2(-to.x, -to.z)
		var lx := Transform3D(hl.basis * Basis(Vector3.UP, yaw), hl * p)
		lx.origin.y = 0.0
		var lift: float = _rug_lift(st, _box_of(st, asset, lx))
		if lift < 0.0:
			continue
		lx.origin.y = lift
		var box: AABB = _box_of(st, asset, lx)
		if _free(st, box, true, hi) and (lift == 0.0 or _free(st, box, true, _rug_under(st, box))):
			var idx: int = _add(st, asset, lx, "seat", hi)
			(st.placed[idx] as Dictionary)["faces"] = hi
			return true
	return false


static func _try_on(st: _State, asset: String, near: int) -> bool:
	var e: Dictionary = st.catalog[asset]
	var hosts: Array = e.get("hosts", [])
	var cands: Array[int] = []
	for i: int in range(st.placed.size()):
		if near >= 0 and i != near:
			continue
		var p: Dictionary = st.placed[i]
		if String(p["kind"]) in hosts and bool((st.catalog[p["asset"]] as Dictionary).get("support", false)):
			cands.append(i)
	if cands.is_empty():
		return false
	var bb: AABB = PropCatalog.aabb(StringName(asset))
	var tall: bool = bb.size.y > TALL_ON
	for t: int in range(TRIES):
		var hi: int = cands[st.rng.randi_range(0, cands.size() - 1)]
		var h: Dictionary = st.placed[hi]
		var hl: Transform3D = h["local"]
		var hb: AABB = PropCatalog.aabb(StringName(String(h["asset"])))
		var top: float = PropCatalog.top(StringName(String(h["asset"])))
		var x0: float = hb.position.x + EDGE - bb.position.x
		var x1: float = hb.end.x - EDGE - bb.end.x
		var z0: float = hb.position.z + EDGE - bb.position.z
		var z1: float = hb.end.z - EDGE - bb.end.z
		if x1 < x0 or z1 < z0:
			continue
		var zz: float = st.rng.randf_range(lerpf(z0, z1, 0.55), z1) if tall else st.rng.randf_range(z0, z1)
		var p := Vector3(st.rng.randf_range(x0, x1), top, zz)
		var yaw: float = 0.0 if tall else st.rng.randf_range(-0.35, 0.35)
		var lx := Transform3D(hl.basis * Basis(Vector3.UP, yaw), hl * p)
		var box: AABB = _box_of(st, asset, lx)
		if _in_keepout(StringName(String(h["asset"])), hl.affine_inverse() * box):
			continue
		if _free(st, box, false, hi) and _on_clear_of_host_stack(st, box, hi):
			_add(st, asset, lx, "on", hi)
			return true
	return false


## True when a host-local box touches one of the host's no-place zones (sink, tools, roll...).
static func _in_keepout(host_asset: StringName, host_box: AABB) -> bool:
	for z: Variant in PropCatalog.entry(host_asset).get("keepout", []):
		var r: Array = z
		var hit_x: bool = host_box.end.x > float(r[0]) and host_box.position.x < float(r[2])
		if hit_x and host_box.end.z > float(r[1]) and host_box.position.z < float(r[3]):
			return true
	return false


## On-top items must not overlap other items on the same host (their boxes touch the host only).
static func _on_clear_of_host_stack(st: _State, box: AABB, host: int) -> bool:
	for p: Dictionary in st.placed:
		if int(p["host"]) == host and _hit(box, p["box"]):
			return false
	return true


static func _try_mount(st: _State, asset: String) -> bool:
	var e: Dictionary = st.catalog[asset]
	var bb: AABB = PropCatalog.aabb(StringName(asset))
	var zc: float = float(e.get("z", 1.5))
	var hosts: Array = e.get("hosts", [])
	var host_walls: Array[Vector2] = []
	for p: Dictionary in st.placed:
		if String(p["kind"]) in hosts and String(p["mode"]) in ["wall", "corner"]:
			var c: Vector3 = (p["box"] as AABB).get_center()
			host_walls.append(st.room.nearest_wall(c))
	# kit furniture that only makes sense over its host (wall cabinets over counters) never falls back
	var strict: bool = not hosts.is_empty() and String(e.get("kind", "")) == "wall_cabinet"
	if strict and host_walls.is_empty():
		return false
	for t: int in range(TRIES):
		var w: int
		var u: float
		if not host_walls.is_empty() and (t < TRIES / 2 or strict):
			var hw: Vector2 = host_walls[st.rng.randi_range(0, host_walls.size() - 1)]
			w = int(hw.x)
			u = hw.y + st.rng.randf_range(-0.15, 0.15) * float(t > 4)
			if asset.contains("grab_bar") or asset.contains("paper_dispenser") or asset.contains("soap"):
				u += (0.55 if st.rng.randf() < 0.5 else -0.55)
		else:
			w = st.rng.randi_range(0, 3)
			u = st.rng.randf_range(bb.size.x * 0.5 + EDGE, st.room.wall_length(w) - bb.size.x * 0.5 - EDGE)
		var z0: float = zc + bb.position.y
		var z1: float = zc + bb.end.y
		if not _wall_free(st, w, u - bb.size.x * 0.5, u + bb.size.x * 0.5, z0, z1):
			continue
		var lx: Transform3D = _wall_xf(st, asset, w, u, zc, MOUNT_GAP - bb.end.z)
		var box: AABB = _box_of(st, asset, lx)
		if _free(st, box, false):
			_add(st, asset, lx, "wall_mount")
			return true
	return false


static func _try_above_door(st: _State, asset: String) -> bool:
	var e: Dictionary = st.catalog[asset]
	var zc: float = float(e.get("z", 2.32))
	for o: Dictionary in st.room.openings:
		if not bool(o["door"]):
			continue
		var w: int = int(o["wall"])
		var lx: Transform3D = _wall_xf(st, asset, w, float(o["u"]), zc, MOUNT_GAP - PropCatalog.aabb(StringName(asset)).end.z)
		var box: AABB = _box_of(st, asset, lx)
		if box.position.y < float(o["top"]) + 0.01:
			continue
		var clash: bool = false
		for p: Dictionary in st.placed:
			if _hit(box, p["box"]):
				clash = true
		if not clash and _inside_room(st, box):
			_add(st, asset, lx, "above_door")
			return true
	return _try_mount(st, asset)


static func _ceiling_xf(st: _State, asset: String, pos: Vector3) -> Transform3D:
	var bb: AABB = PropCatalog.aabb(StringName(asset))
	var lx := _xf(0.0 if st.room.size.x >= st.room.size.z else PI * 0.5, pos)
	lx.origin.y = st.room.size.y - bb.end.y - MOUNT_GAP
	return lx


static func _try_ceiling_one(st: _State, asset: String) -> bool:
	for t: int in range(TRIES):
		var p := Vector3(st.rng.randf_range(-st.room.size.x * 0.35, st.room.size.x * 0.35), 0.0,
			st.rng.randf_range(-st.room.size.z * 0.35, st.room.size.z * 0.35))
		var lx: Transform3D = _ceiling_xf(st, asset, p)
		if _free(st, _box_of(st, asset, lx), false):
			_add(st, asset, lx, "ceiling")
			return true
	return false


static func _place_ceiling(st: _State) -> void:
	var keys: Array = st.kit.ceiling.keys()
	keys.sort()
	for k: Variant in keys:
		var asset: String = String(k)
		if not st.catalog.has(asset):
			st.warnings.append("ceiling asset %s not in catalog" % asset)
			continue
		var spacing: float = maxf(0.8, float(st.kit.ceiling[k]))
		var nx: int = maxi(1, int(round(st.room.size.x / spacing)))
		var nz: int = maxi(1, int(round(st.room.size.z / spacing)))
		for i: int in range(nx):
			for j: int in range(nz):
				var p := Vector3((float(i) + 0.5) / float(nx) * st.room.size.x - st.room.size.x * 0.5, 0.0,
					(float(j) + 0.5) / float(nz) * st.room.size.z - st.room.size.z * 0.5)
				var lx: Transform3D = _ceiling_xf(st, asset, p)
				if _free(st, _box_of(st, asset, lx), false):
					_add(st, asset, lx, "ceiling")


static func _place_anchor(st: _State, a: Dictionary) -> void:
	var asset: String = String(a.get("asset", &""))
	if asset == "" and a.has("kind"):
		var ids: PackedStringArray = _assets_for(st, StringName(String(a["kind"])))
		if not ids.is_empty():
			asset = ids[st.rng.randi_range(0, ids.size() - 1)]
	if asset == "" or not st.catalog.has(asset):
		st.warnings.append("anchor without a catalog asset: %s" % a)
		return
	var lx: Transform3D = a["transform"]
	var mode: String = String((st.catalog[asset] as Dictionary).get("place", "floor"))
	_add(st, asset, lx, mode)


static func _place_optional(st: _State) -> void:
	var kinds: Array = st.kit.optional_items.keys()
	kinds.sort()
	var total: float = 0.0
	for k: Variant in kinds:
		total += maxf(0.0, float(st.kit.optional_items[k]))
	if total <= 0.0:
		return
	var clutter_share: int = 0
	for g: Variant in st.kit.clutter_groups.keys():
		clutter_share += 2
	var goal: int = maxi(st.target - clutter_share, st.placed.size())
	var fails: int = 0
	while st.placed.size() < goal and fails < 24:
		var r: float = st.rng.randf() * total
		var pick: StringName = &""
		for k: Variant in kinds:
			r -= maxf(0.0, float(st.kit.optional_items[k]))
			if r <= 0.0:
				pick = StringName(String(k))
				break
		if pick == &"":
			pick = StringName(String(kinds[kinds.size() - 1]))
		# an optional kind never floods a room: at most counts.y (default 2) of it
		var cap: int = (st.kit.counts[pick] as Vector2i).y if st.kit.counts.has(pick) else 2
		if _count_kind(st, pick) >= cap:
			fails += 1
			continue
		var n: int = _pick_count(st, pick)
		var ok: bool = false
		for i: int in range(n):
			ok = _place_kind(st, pick) or ok
		fails = 0 if ok else fails + 1


static func _place_clutter(st: _State) -> void:
	var groups: Array = st.kit.clutter_groups.keys()
	groups.sort()
	for g: Variant in groups:
		var spec: Dictionary = st.kit.clutter_groups[g]
		var anchors: Array = spec.get("anchors", [])
		var items: Dictionary = spec.get("items", {})
		var count: Vector2i = spec.get("count", Vector2i(1, 2))
		var radius: float = float(spec.get("radius", 1.0))
		var item_kinds: Array = items.keys()
		item_kinds.sort()
		var total: float = 0.0
		for k: Variant in item_kinds:
			total += float(items[k])
		if total <= 0.0:
			continue
		var hosts: Array[int] = []
		for i: int in range(st.placed.size()):
			if String((st.placed[i] as Dictionary)["kind"]) in anchors:
				hosts.append(i)
		var generic: Array[String] = []
		for a: Variant in anchors:
			if String(a) in ["wall", "door", "corner"]:
				generic.append(String(a))
		for slot: int in range(hosts.size() + generic.size()):
			var n: int = st.rng.randi_range(count.x, maxi(count.x, count.y))
			for c: int in range(n):
				if st.placed.size() >= st.max_count:
					return
				var r: float = st.rng.randf() * total
				var kind: StringName = StringName(String(item_kinds[item_kinds.size() - 1]))
				for k: Variant in item_kinds:
					r -= float(items[k])
					if r <= 0.0:
						kind = StringName(String(k))
						break
				if slot < hosts.size():
					_clutter_at(st, kind, hosts[slot], radius)
				else:
					_clutter_generic(st, kind, generic[slot - hosts.size()], radius)


static func _clutter_at(st: _State, kind: StringName, host: int, radius: float) -> void:
	var ids: PackedStringArray = _assets_for(st, kind)
	if ids.is_empty():
		return
	var asset: String = ids[st.rng.randi_range(0, ids.size() - 1)]
	var mode: String = String((st.catalog[asset] as Dictionary).get("place", "floor"))
	if mode == "on":
		_try_on(st, asset, host)
	elif mode == "seat":
		_try_seat(st, asset, host)
	else:
		_place_asset(st, asset, host, radius)


static func _clutter_generic(st: _State, kind: StringName, anchor: String, radius: float) -> void:
	var ids: PackedStringArray = _assets_for(st, kind)
	if ids.is_empty():
		return
	var asset: String = ids[st.rng.randi_range(0, ids.size() - 1)]
	var mode: String = String((st.catalog[asset] as Dictionary).get("place", "floor"))
	if mode == "on":
		_try_on(st, asset, -1)
		return
	if anchor == "corner":
		_try_wall(st, asset, true, -1, 0.0)
	elif anchor == "door" and not st.room.openings.is_empty():
		for t: int in range(8):
			var o: Dictionary = st.room.openings[st.rng.randi_range(0, st.room.openings.size() - 1)]
			if not bool(o["door"]):
				continue
			var w: int = int(o["wall"])
			var side: float = 1.0 if st.rng.randf() < 0.5 else -1.0
			var bb: AABB = PropCatalog.aabb(StringName(asset))
			var u: float = float(o["u"]) + side * (float(o["width"]) * 0.5 + 0.2 + bb.size.x * 0.5 + st.rng.randf_range(0.0, radius))
			if u - bb.size.x * 0.5 < EDGE or u + bb.size.x * 0.5 > st.room.wall_length(w) - EDGE:
				continue
			var lx: Transform3D = _wall_xf(st, asset, w, u)
			var box: AABB = _box_of(st, asset, lx)
			if _wall_free(st, w, u - bb.size.x * 0.5, u + bb.size.x * 0.5, 0.0, bb.end.y) and _free(st, box, true):
				_add(st, asset, lx, "wall")
				return
	else:
		_try_wall(st, asset, false, -1, 0.0)


# --- final passes ------------------------------------------------------------------------

static func _gap2d(a: AABB, b: AABB) -> float:
	var dx: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dz: float = maxf(0.0, maxf(a.position.z - b.end.z, b.position.z - a.end.z))
	return sqrt(dx * dx + dz * dz)


static func _lone_ok(st: _State, box: AABB) -> bool:
	if st.room.area() <= LONE_AREA:
		return true
	var any_floor: bool = false
	for p: Dictionary in st.placed:
		any_floor = any_floor or String(p["mount"]) == ""
	if not any_floor:
		return true
	for p: Dictionary in st.placed:
		if String(p["mount"]) == "" and _gap2d(box, p["box"]) <= LONE_RADIUS:
			return true
	return false


## Floor props with no floor neighbour within 2 m in rooms > 12 m²: drop optional ones (and
## whatever stands on them).
static func _fix_lone(st: _State) -> void:
	if st.room.area() <= LONE_AREA:
		return
	var drop: Dictionary = {}
	for i: int in range(st.placed.size()):
		var p: Dictionary = st.placed[i]
		if String(p["mount"]) != "" or String(p["mode"]) == "on":
			continue
		var lone: bool = true
		for j: int in range(st.placed.size()):
			var q: Dictionary = st.placed[j]
			if j != i and String(q["mount"]) == "" and _gap2d(p["box"], q["box"]) <= LONE_RADIUS:
				lone = false
				break
		if lone and not (StringName(String(p["kind"])) in st.kit.required_items) and not (StringName(String(p["kind"])) in st.kit.lone_ok_kinds):
			drop[i] = true
	if drop.is_empty():
		return
	for i: int in range(st.placed.size()):
		if drop.has(int((st.placed[i] as Dictionary)["host"])):
			drop[i] = true
	var keep: Array[Dictionary] = []
	var remap: Dictionary = {}
	for i: int in range(st.placed.size()):
		if not drop.has(i):
			remap[i] = keep.size()
			keep.append(st.placed[i])
	for p: Dictionary in keep:
		p["host"] = int(remap.get(int(p["host"]), -1))
		p["faces"] = int(remap.get(int(p["faces"]), -1))
	st.placed = keep
	st.warnings.append("dropped %d lone prop(s)" % drop.size())


## Monitors face the chair at their desk (or the desk front); TVs too.
static func _finish_links(st: _State) -> void:
	for i: int in range(st.placed.size()):
		var p: Dictionary = st.placed[i]
		if not (String(p["kind"]) in ["monitor", "tv"]):
			continue
		var host: int = int(p["host"])
		for j: int in range(st.placed.size()):
			var q: Dictionary = st.placed[j]
			if int(q["host"]) == host and String(q["kind"]) == "chair" and int(q["faces"]) == host:
				var to: Vector3 = (q["box"] as AABB).get_center() - (p["local"] as Transform3D).origin
				var fwd: Vector3 = -(p["local"] as Transform3D).basis.z
				var err: float = rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z))))
				if err <= 18.0:
					p["faces"] = j
				break
