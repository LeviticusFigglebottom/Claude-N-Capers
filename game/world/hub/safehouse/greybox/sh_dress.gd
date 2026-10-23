## Safehouse G2 dressing (C4-03). Owner: ENV C. Copy-adapted from Rolling Thunder's rt_dress.gd (D-147; the chains are
## not shared code): every room with a dressing kit (tools/blender/props/_kits_safehouse.py, plus the shared
## corridor_service / restroom_single / electrical_closet) is dressed by KitPlacer. The KitRoom is the room's clear
## rect inside its walls' faces, with the wall openings (door-height holes) and windows on its outline. Keep-outs:
## every station's body and its UsePoint approach, the spawns and return markers, the review cameras' standpoints, the
## explicit fixtures standing on the floor, the crew van, and the circulation lanes (L.DRESS_KEEP_OUT). Placed floor
## props get a box collider (cut at the catalog `top`) and a navmesh obstruction; mounts, "on" items and ceiling
## fixtures neither. Deterministic (per-room seeds, tree order). Called by build_safehouse.gd before sh_finish.gd.
extends RefCounted

const L: GDScript = preload("res://world/hub/safehouse/greybox/safehouse_layout.gd")
const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const KITS_DIR: String = "res://world/kits/"
const FOLDER: String = "Dress"
## Half size of the keep-out kept round every floor marker (spawns, return markers, review-camera standpoints).
const MARKER_HALF: float = 0.35
## The approach kept clear in front of a station: its UsePoint grown by this much.
const USE_HALF: float = 0.6
const EXIT_SIGN_Z: float = 2.36
## A room edge takes wall mounts only where its wall stands this high above the floor.
const MOUNT_WALL: float = 2.7
## Minimum horizontal width of a bake obstruction (two 0.1 m nav cells).
const NAV_MIN: float = 0.2

var report: PackedStringArray = []
var counts: Dictionary = {}

var _b: Object
var _root: Node3D
var _cat: Dictionary = {}
var _scenes: Dictionary = {}
var _boxes: Array[AABB] = []


func run(builder: Object) -> void:
	_b = builder
	_root = builder.get(&"map_root")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not (parsed is Dictionary):
		_err("cannot read %s" % CATALOG_PATH)
		return
	_cat = parsed
	_collect()
	var props: Node3D = _folder(_root.get_node("Props") as Node3D, FOLDER)
	for i: int in range(L.ROOMS.size()):
		var r: Array = L.ROOMS[i]
		var kit_id: String = String(r[2])
		if kit_id == "":
			continue
		var res: Array = _interior_room(r)
		_dress_room(res[0], res[1], String(r[0]), kit_id, props, 7100 + 13 * i)
	var total: int = 0
	for k: String in counts:
		total += int(counts[k])
	report.append("%d props in %d kit rooms" % [total, counts.size()])
	var errs: PackedStringArray = _b.get(&"errors")
	for line: String in report:
		printerr("dress: " + line)
		if line.begins_with("ERROR"):
			errs.append(line)
	_b.set(&"errors", errs)


func _err(msg: String) -> void:
	report.append("ERROR " + msg)


func aabb(asset: String) -> AABB:
	var a: Array = (_cat[asset] as Dictionary)["aabb"]
	return AABB(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3(float(a[3]), float(a[4]), float(a[5])))


func _folder(parent: Node3D, nm: String) -> Node3D:
	var f: Node3D = parent.get_node_or_null(nm) as Node3D
	if f == null:
		f = Node3D.new()
		f.name = nm
		parent.add_child(f)
		f.owner = _root
	return f


func _dress_room(room: KitRoom, world_box: AABB, id: String, kit_id: String, props_root: Node3D, seed: int) -> void:
	var kit: DressingKit = load(KITS_DIR + kit_id + ".tres") as DressingKit
	if kit == null:
		_err("%s: kit %s not found" % [id, kit_id])
		return
	var probe: AABB = world_box.grow(0.05)
	for b: AABB in _boxes:
		if b.intersects(probe):
			room.add_keep_out(b)
	for k: Variant in L.DRESS_KEEP_OUT.get(id, []):
		var b2: Array = k
		room.add_keep_out(AABB(Vector3(float(b2[0]), 0.0, float(b2[1])),
			Vector3(float(b2[2]) - float(b2[0]), world_box.size.y, float(b2[3]) - float(b2[1]))))
	var res: Dictionary = KitPlacer.place(room, kit, seed, false)
	var placements: Array = res["placements"]
	var parent: Node3D = _folder(props_root, id)
	var nodes: Array[Node3D] = KitPlacer.instantiate({"placements": placements}, parent, _root)
	for i: int in range(nodes.size()):
		var p: Dictionary = placements[i]
		_finish_node(nodes[i], String(p["asset"]), String(p["mode"]), String(p["mount"]), p["xform"])
	counts[id] = nodes.size()
	var missing: PackedStringArray = res["missing"]
	var warnings: PackedStringArray = res["warnings"]
	report.append("%s (%s, seed %d, hash %s): %d props%s%s" % [id, kit_id, seed, String(res.get("hash", "")).left(8),
		nodes.size(), "" if missing.is_empty() else ", MISSING " + ",".join(missing),
		"" if warnings.is_empty() else ", warnings: " + "; ".join(warnings)])


## [KitRoom, world AABB of the clear interior] for a ROOMS row: the rect inside its walls' faces, floor to ceiling;
## the wall openings (door-height holes) and windows on its outline (rt_dress.gd _interior_room).
func _interior_room(r: Array) -> Array:
	var bx: Array = r[3]
	var y: float = float(bx[1])
	var x0: float = float(bx[0])
	var z0: float = float(bx[2])
	var x1: float = float(bx[3])
	var z1: float = float(bx[5])
	var lo: Vector3 = Vector3(x0 + half_t(y, "z", x0, z0, z1), y, z0 + half_t(y, "x", z0, x0, x1))
	var hi: Vector3 = Vector3(x1 - half_t(y, "z", x1, z0, z1), float(bx[4]), z1 - half_t(y, "x", z1, x0, x1))
	var clear: AABB = AABB(lo, hi - lo)
	var room: KitRoom = KitRoom.from_aabb(clear, StringName(String(r[0])))
	# KitRoom walls: 0 north (z0), 1 east (x1), 2 south (z1), 3 west (x0)
	var edges: Array = [["x", z0, x0, x1], ["z", x1, z0, z1], ["x", z1, x0, x1], ["z", x0, z0, z1]]
	for w: int in range(4):
		var e: Array = edges[w]
		var any: bool = false
		for sg: Array in edge_walls(y, String(e[0]), float(e[1]), float(e[2]), float(e[3]), MOUNT_WALL):
			if float(sg[2]) > 0.0:
				any = true
		room.walls[w] = any
	var rect: Rect2 = Rect2(x0, z0, x1 - x0, z1 - z0)
	for w2: Array in L.WALLS:
		var along_x: bool = String(w2[1]) == "x"
		for hl: Array in w2[9]:
			if float(hl[3]) <= y + 0.05 or float(hl[2]) >= hi.y:
				continue
			var a0: float = maxf(float(hl[0]), x0 if along_x else z0)
			var a1: float = minf(float(hl[1]), x1 if along_x else z1)
			if a1 - a0 < 0.1:
				continue
			var mid: Vector3 = Vector3((a0 + a1) * 0.5, y, float(w2[2])) if along_x \
				else Vector3(float(w2[2]), y, (a0 + a1) * 0.5)
			if not _on_rect_edge(rect, mid, along_x):
				continue
			var sill: float = float(hl[2]) - y
			var head: float = minf(float(hl[3]) - y, clear.size.y)
			if sill <= 0.05:
				room.add_door(mid, a1 - a0, 1.0, head)
			else:
				room.add_window(mid + Vector3.UP * sill, a1 - a0 + 0.1, sill, head)
	return [room, clear]


## The wall stretches on a room edge (axis "x": runs along x at z = fixed) within [a0, a1]: [[from, to, thickness]]
## (thickness 0: no wall there).
func edge_walls(y: float, axis: String, fixed: float, a0: float, a1: float, h: float = 1.0) -> Array:
	var segs: Array = []
	for w: Array in L.WALLS:
		if float(w[6]) > y + 0.05 or float(w[7]) < y + h or String(w[1]) != axis or absf(float(w[2]) - fixed) > 0.001:
			continue
		var s0: float = maxf(float(w[3]), a0)
		var s1: float = minf(float(w[4]), a1)
		if s1 - s0 > 0.001:
			segs.append([s0, s1, float(w[5])])
	var pts: Array[float] = [a0, a1]
	for s: Array in segs:
		for v: float in [float(s[0]), float(s[1])]:
			if not pts.has(v):
				pts.append(v)
	pts.sort()
	var out: Array = []
	for i: int in range(pts.size() - 1):
		var p: float = pts[i]
		var q: float = pts[i + 1]
		var t: float = 0.0
		for s2: Array in segs:
			if float(s2[0]) <= p + 0.0001 and float(s2[1]) >= q - 0.0001:
				t = maxf(t, float(s2[2]))
		out.append([p, q, t])
	return out


## Half the thinnest wall on a room edge, 0.1 m by default.
func half_t(y: float, axis: String, fixed: float, a0: float, a1: float) -> float:
	var t: float = INF
	for sg: Array in edge_walls(y, axis, fixed, a0, a1):
		if float(sg[2]) > 0.0:
			t = minf(t, float(sg[2]))
	return 0.1 if t == INF else t * 0.5


static func _on_rect_edge(r: Rect2, pos: Vector3, along_x: bool) -> bool:
	if along_x:
		return (absf(pos.z - r.position.y) < 0.25 or absf(pos.z - r.end.y) < 0.25) and pos.x > r.position.x \
			and pos.x < r.end.x
	return (absf(pos.x - r.position.x) < 0.25 or absf(pos.x - r.end.x) < 0.25) and pos.z > r.position.y \
		and pos.z < r.end.y


## Everything the dressing leaves alone: the stations' bodies (and the wall-hung ones' faces) and their UsePoint
## approaches, the spawns / return markers, the review cameras' standpoints, the props (the van, the wall fixtures) and
## the explicit fixtures' floor footprints.
func _collect() -> void:
	for st: Node in _root.get_node("Stations").get_children():
		for body: Node in st.find_children("*", "StaticBody3D", true, false):
			_boxes.append(_body_box(body as StaticBody3D).grow(0.1))
		var up: Node3D = st.get_node_or_null("UsePoint") as Node3D
		if up != null:
			var u: Vector3 = _b.call(&"global_xform", up).origin
			_boxes.append(AABB(Vector3(u.x - USE_HALF, u.y - 0.05, u.z - USE_HALF), Vector3(USE_HALF * 2.0, 2.0,
				USE_HALF * 2.0)))
	for sp: Node in _root.get_node("Spawns").get_children():
		_boxes.append(_marker_box(_b.call(&"global_xform", sp).origin))
	for cam: Array in L.REVIEW_CAMERAS:
		if not String(cam[0]).begins_with("TopDown"):
			var c: Vector3 = _b.call(&"v3", cam[2])
			_boxes.append(_marker_box(Vector3(c.x, 0.0, c.z)))
	for body2: Node in _root.get_node("Props").find_children("*", "StaticBody3D", true, false):
		_boxes.append(_body_box(body2 as StaticBody3D).grow(0.1))
	for fx: Node in _root.get_node("Lighting/Fixtures").get_children():
		var f3: Node3D = fx as Node3D
		if f3 == null or not f3.scene_file_path.contains("floor_lamp") and not f3.scene_file_path.contains("bench_lamp") \
				and not f3.scene_file_path.contains("magnifier"):
			continue
		var o: Vector3 = f3.position
		_boxes.append(AABB(Vector3(o.x - 0.35, o.y, o.z - 0.35), Vector3(0.7, 1.8, 0.7)))


func _body_box(body: StaticBody3D) -> AABB:
	var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
	var xf: Transform3D = _b.call(&"global_xform", body)
	if cs == null or not (cs.shape is BoxShape3D):
		return AABB(xf.origin, Vector3.ZERO)
	var sz: Vector3 = (cs.shape as BoxShape3D).size
	return (xf * cs.transform) * AABB(-sz * 0.5, sz)


static func _marker_box(m: Vector3) -> AABB:
	return AABB(Vector3(m.x - MARKER_HALF, m.y - 0.05, m.z - MARKER_HALF), Vector3(MARKER_HALF * 2.0, 2.0,
		MARKER_HALF * 2.0))


## Collider + navmesh obstruction for floor props (not mounts, "on" items or ceiling fixtures); the obstruction is no
## thinner than two nav cells.
func _finish_node(n: Node3D, asset: String, mode: String, mount: String, xf: Transform3D) -> void:
	var cat: Dictionary = _cat[asset]
	var kind: String = String(cat.get("kind", ""))
	if kind == "exit_sign" and mode == "above_door":
		n.position.y += maxf(0.0, EXIT_SIGN_Z - float(cat.get("z", EXIT_SIGN_Z)))
	if mount != "" or mode == "on" or mode == "ceiling":
		return
	var bb: AABB = aabb(asset)
	var top: float = float(cat.get("top", 0.0))
	if top > 0.0 and top < bb.end.y:
		bb.size.y = top - bb.position.y
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	n.add_child(body)
	body.owner = _root
	SurfaceTags.tag(body, StringName(String(cat.get("surface", ""))))
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(maxf(bb.size.x, 0.01), maxf(bb.size.y, 0.01), maxf(bb.size.z, 0.01))
	cs.shape = shape
	cs.position = bb.get_center()
	body.add_child(cs)
	cs.owner = _root
	if kind == "rug":
		n.set_meta(&"walkable", true)
		return
	_b.call(&"obstruct", xf, _nav_thick(bb))


static func _nav_thick(bb: AABB) -> AABB:
	var out: AABB = bb
	for ax: int in [0, 2]:
		if out.size[ax] < NAV_MIN:
			out.position[ax] -= (NAV_MIN - out.size[ax]) * 0.5
			out.size[ax] = NAV_MIN
	return out
