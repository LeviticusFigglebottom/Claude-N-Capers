## PO6-17 RNG assault-event markers (D-114 §5 / D-115 #5) for the generated maps after Golden Hour (Dockside Burn,
## Night Deposit). Owner: ENV C. Preloaded by the map generators (no class_name: they run as --script). Marker nodes
## only for ENV A (contract: docs/levels/_art/po6_17/README.md): `AssaultEvents` (group `assault_events`) with
## Marker3Ds `TurretVan_<n>`, `HeliOrbit_<n>` (meta radius), `HeliDrop_<n>`, `Breach_<n>` (meta kind / size / room;
## the breach scene as child `Visual`, Intact) and optional one-way rappel NavigationLink3Ds (meta `rappel`).
## Layout rows (the map's `<id>_layout.gd` ASSAULT_* tables):
##   vans [name, pos, yaw_deg (+Z = van forward)]; orbits [name, centre, radius]; drops [name, pos];
##   rappels [name, roof start, ground end];
##   breaches [name, kind, scene id, pos (room-side face; ceiling: centre of the underside), yaw_deg (-Z into the
##   room; ceiling: turn of +Y about the vertical, 0 = +Y north), size (w, h), room, depth (ceiling underside to
##   roof top; 0 for walls / windows)].
extends RefCounted

const SCENE_DIR: String = "res://world/props/assault_event/"
## Wall / window breach scenes -> the infill depth (m) behind the room face (README §4 table).
const INFILL_T: Dictionary = {"prop_breach_wall": 0.2, "prop_breach_wall_t40": 0.4, "prop_breach_window": 0.4}
## Ceiling breach roof curb (prop_breach_ceiling*: 0.15 m wide, 0.2 m high round the 1.2 m hole).
const CURB_W: float = 0.15
const CURB_H: float = 0.25
## Infill obstructions reach this far (one nav cell) past the room face: the voxelised wall face they stand in for
## erodes one cell further than a projected obstruction on the same plane.
const NAV_FACE_PAD: float = 0.1


## Ceiling breach holes [x0, z0, x1, z1, y0, y1] (world): the ceiling underside up to the roof top. `size` is the
## hole's extent along the marker's x / +Y, so a quarter-turned ceiling swaps it in world x / z.
static func ceiling_holes(breaches: Array) -> Array[Array]:
	var out: Array[Array] = []
	for b: Array in breaches:
		if String(b[1]) != "ceiling":
			continue
		var p: Vector3 = b[3]
		var sz: Vector2 = b[5]
		if absf(sin(deg_to_rad(float(b[4])))) > 0.5:
			sz = Vector2(sz.y, sz.x)
		out.append([p.x - sz.x * 0.5, p.z - sz.y * 0.5, p.x + sz.x * 0.5, p.z + sz.y * 0.5, p.y - 0.01,
			p.y + float(b[7]) + 0.01])
	return out


## A slab / ceiling box [x0, y0, z0, x1, y1, z1] minus the ceiling breach hole it spans in Y: [[name, box]]
## unchanged, or four strips `<name>_W/_E/_N/_S` round the hole.
static func cut(nm: String, b: Array, breaches: Array) -> Array[Array]:
	for h: Array in ceiling_holes(breaches):
		var x0: float = float(h[0])
		var z0: float = float(h[1])
		var x1: float = float(h[2])
		var z1: float = float(h[3])
		if float(b[1]) < float(h[4]) or float(b[4]) > float(h[5]) or x0 <= float(b[0]) or x1 >= float(b[3]) \
				or z0 <= float(b[2]) or z1 >= float(b[5]):
			continue
		return [[nm + "_W", [b[0], b[1], b[2], x0, b[4], b[5]]], [nm + "_E", [x1, b[1], b[2], b[3], b[4], b[5]]],
			[nm + "_N", [x0, b[1], b[2], x1, b[4], z0]], [nm + "_S", [x0, b[1], z1, x1, b[4], b[5]]]]
	return [[nm, b]]


## A ceiling rectangle (x, z) at height y minus the ceiling breach hole in it (four strips round the hole).
static func ceiling_rects(x0: float, z0: float, x1: float, z1: float, y: float, breaches: Array) -> Array[Rect2]:
	var r: Rect2 = Rect2(x0, z0, x1 - x0, z1 - z0)
	for h: Array in ceiling_holes(breaches):
		var hole: Rect2 = Rect2(float(h[0]), float(h[1]), float(h[2]) - float(h[0]), float(h[3]) - float(h[1]))
		if absf(float(h[4]) + 0.01 - y) > 0.005 or not r.encloses(hole):
			continue
		return [Rect2(x0, z0, hole.position.x - x0, z1 - z0), Rect2(hole.end.x, z0, x1 - hole.end.x, z1 - z0),
			Rect2(hole.position.x, z0, hole.size.x, hole.position.y - z0),
			Rect2(hole.position.x, hole.end.y, hole.size.x, z1 - hole.end.y)]
	return [r]


## World AABBs the room dressing keeps clear of: a wall / window opening widened by `reach` / 2 each side and
## `reach` deep on both faces; under a ceiling hole a landing column widened by `reach` / 4 each side (from the room
## floor, the scene's ExitPoint, to 0.5 m under the ceiling) and the hole (with its curb width) at the ceiling.
static func keep_outs(breaches: Array, reach: float) -> Array[AABB]:
	var out: Array[AABB] = []
	for b: Array in breaches:
		var sz: Vector2 = b[5]
		var xf: Transform3D = marker_xform(b)
		if String(b[1]) == "ceiling":
			# the landing column (up to 0.5 m under the ceiling, so the room's ceiling fixtures stay) + the hole itself
			var h: float = sz.x * 0.5 + reach * 0.25
			var drop: float = _drop(String(b[2]))
			out.append(AABB(Vector3(xf.origin.x - h, xf.origin.y - drop, xf.origin.z - h), Vector3(h * 2.0, drop - 0.5, h * 2.0)))
			var h2: float = sz.x * 0.5 + CURB_W
			out.append(AABB(Vector3(xf.origin.x - h2, xf.origin.y - 0.5, xf.origin.z - h2), Vector3(h2 * 2.0, 0.6, h2 * 2.0)))
			continue
		var t: float = float(INFILL_T.get(String(b[2]), 0.4))
		var lb: AABB = AABB(Vector3(-sz.x * 0.5 - reach * 0.5, 0.0, -reach), Vector3(sz.x + reach, sz.y, t + reach * 2.0))
		out.append(xf * lb)
	return out


## A ceiling breach scene's drop to the room floor (its Model/ExitPoint, marker frame -Z = down); 3.0 if unreadable.
static func _drop(scene_id: String) -> float:
	var ps: PackedScene = load(SCENE_DIR + scene_id + ".tscn") as PackedScene
	if ps == null:
		return 3.0
	var vis: Node3D = ps.instantiate() as Node3D
	var ep: Node3D = vis.find_child("ExitPoint", true, false) as Node3D
	var drop: float = 3.0
	if ep != null:
		var t: Transform3D = Transform3D.IDENTITY
		var c: Node = ep
		while c != vis:
			t = (c as Node3D).transform * t
			c = c.get_parent()
		drop = -t.origin.z
	vis.free()
	return drop


## The `Breach_<n>` marker's transform: -Z into the room; a ceiling faces down (+Y = north turned by yaw).
static func marker_xform(b: Array) -> Transform3D:
	var yaw: Basis = Basis(Vector3.UP, deg_to_rad(float(b[4])))
	var basis: Basis = yaw * Basis(Vector3.RIGHT, -PI * 0.5) if String(b[1]) == "ceiling" else yaw
	return Transform3D(basis, b[3])


## Builds `AssaultEvents` under `root` (owned by it). Each wall / window infill and each ceiling curb is appended to
## `obstructions` ([corners, elevation, height], the generators' projected-obstruction rows) because the bake only
## parses `Geometry`: an intact breach stays wall for the navmesh. Returns errors.
static func build(root: Node3D, vans: Array, orbits: Array, drops: Array, rappels: Array, breaches: Array,
		obstructions: Array[Array]) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var ae: Node3D = Node3D.new()
	ae.name = "AssaultEvents"
	ae.add_to_group(&"assault_events", true)
	_own(root, root, ae)
	for v: Array in vans:
		_marker(root, ae, String(v[0]), Transform3D(Basis(Vector3.UP, deg_to_rad(float(v[2]))), v[1]))
	for o: Array in orbits:
		_marker(root, ae, String(o[0]), Transform3D(Basis.IDENTITY, o[1])).set_meta(&"radius", float(o[2]))
	for d: Array in drops:
		_marker(root, ae, String(d[0]), Transform3D(Basis.IDENTITY, d[1]))
	for r: Array in rappels:
		var rl: NavigationLink3D = NavigationLink3D.new()
		rl.name = String(r[0])
		rl.bidirectional = false
		rl.set_meta(&"rappel", true)  # RappelLinks.META (literal: the builder runs without autoloads)
		rl.start_position = r[1]
		rl.end_position = r[2]
		_own(root, ae, rl)
	for b: Array in breaches:
		var kind: String = String(b[1])
		var size: Vector2 = b[5]
		var xf: Transform3D = marker_xform(b)
		var m: Marker3D = _marker(root, ae, String(b[0]), xf)
		m.set_meta(&"kind", kind)
		m.set_meta(&"size", size)
		m.set_meta(&"room", String(b[6]))
		var ps: PackedScene = load(SCENE_DIR + String(b[2]) + ".tscn") as PackedScene
		if ps == null:
			errors.append("assault event scene %s missing" % String(b[2]))
			continue
		var vis: Node3D = ps.instantiate() as Node3D
		vis.name = "Visual"
		_own(root, m, vis)
		var box: AABB
		if kind == "ceiling":
			# the roof curb (marker frame: x / y across the hole, +Z up from the ceiling underside)
			var co: float = size.x * 0.5 + CURB_W
			box = AABB(Vector3(-co, -co, float(b[7])), Vector3(co * 2.0, co * 2.0, CURB_H))
		else:
			if not INFILL_T.has(String(b[2])):
				errors.append("%s: no infill depth for %s" % [String(b[0]), String(b[2])])
				continue
			# NAV_FACE_PAD into the room: a projected obstruction erodes like the voxelised wall face it replaces
			var t: float = float(INFILL_T[String(b[2])])
			box = AABB(Vector3(-size.x * 0.5, -0.2, -NAV_FACE_PAD), Vector3(size.x, size.y + 0.2, t + NAV_FACE_PAD))
		obstructions.append(_projected(xf, box))
	return errors


## [corners (bottom face), elevation, height] of a local box under xform (axis-aligned in world after the transform).
static func _projected(xf: Transform3D, box: AABB) -> Array:
	var wb: AABB = xf * box
	var pts: PackedVector3Array = PackedVector3Array()
	for c: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
		pts.append(Vector3(wb.position.x + wb.size.x * c.x, wb.position.y, wb.position.z + wb.size.z * c.z))
	return [pts, wb.position.y, wb.size.y]


static func _marker(root: Node, parent: Node3D, nm: String, xf: Transform3D) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = nm
	m.transform = xf
	_own(root, parent, m)
	return m


static func _own(root: Node, parent: Node, n: Node) -> void:
	parent.add_child(n)
	n.owner = root
