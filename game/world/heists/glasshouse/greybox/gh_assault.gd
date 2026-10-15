## Glasshouse PO6-17 RNG assault events (D-114 §5), used by build_greybox.gd. Owner: ENV C.
## Marker nodes only for ENV A (contract: docs/levels/_art/po6_17/README.md): `AssaultEvents` (group
## `assault_events`) with Marker3Ds `TurretVan_<n>`, `HeliOrbit_<n>` (meta radius), `HeliDrop_<n>` and
## `Breach_<n>` (meta kind / size / room; the breach scene as child `Visual`, Intact). No gameplay wiring.
## Data: glasshouse_layout.gd `ASSAULT_*`.
class_name GlasshouseAssaultEvents
extends RefCounted

const L: GDScript = preload("res://world/heists/glasshouse/greybox/glasshouse_layout.gd")
const SCENE_DIR: String = "res://world/props/assault_event/"


## Ceiling breach holes [x0, z0, x1, z1, y0, y1] (world): the ceiling underside up to the roof top.
static func ceiling_holes() -> Array[Array]:
	var out: Array[Array] = []
	for b: Array in L.ASSAULT_BREACHES:
		if String(b[1]) != "ceiling":
			continue
		var p: Vector3 = b[3]
		var sz: Vector2 = b[5]
		out.append([p.x - sz.x * 0.5, p.z - sz.y * 0.5, p.x + sz.x * 0.5, p.z + sz.y * 0.5, p.y - 0.01,
			p.y + L.ASSAULT_CEILING_DEPTH + 0.01])
	return out


## A slab / ceiling box [x0, y0, z0, x1, y1, z1] minus the ceiling breach hole it spans in Y: [[name, box]]
## unchanged, or four strips `<name>_W/_E/_N/_S` round the hole.
static func cut(nm: String, b: Array) -> Array[Array]:
	for h: Array in ceiling_holes():
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


## Builds `AssaultEvents` under `root` (owned by it). Each wall/window breach infill is appended to
## `obstructions` (build_greybox._obstruct format: [corners, elevation, height]) because the bake only
## parses `Geometry`: the intact breach stays wall for the navmesh. Returns errors.
static func build(root: Node3D, obstructions: Array[Array]) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var ae: Node3D = Node3D.new()
	ae.name = "AssaultEvents"
	ae.add_to_group(&"assault_events", true)
	_own(root, root, ae)
	for v: Array in L.ASSAULT_TURRET_VANS:
		_marker(root, ae, String(v[0]), Transform3D(Basis(Vector3.UP, deg_to_rad(float(v[2]))), v[1]))
	for o: Array in L.ASSAULT_HELI_ORBITS:
		_marker(root, ae, String(o[0]), Transform3D(Basis.IDENTITY, o[1])).set_meta(&"radius", float(o[2]))
	for d: Array in L.ASSAULT_HELI_DROPS:
		_marker(root, ae, String(d[0]), Transform3D(Basis.IDENTITY, d[1]))
	for b: Array in L.ASSAULT_BREACHES:
		var kind: String = String(b[1])
		var size: Vector2 = b[5]
		# -Z into the room: walls/windows by yaw, ceilings face down (+Y = north)
		var basis: Basis = Basis(Vector3.RIGHT, -PI * 0.5) if kind == "ceiling" else Basis(Vector3.UP, deg_to_rad(float(b[4])))
		var xf: Transform3D = Transform3D(basis, b[3])
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
		if kind != "ceiling":
			var t: float = L.EXT_T if kind == "window" else L.INT_T
			var box: AABB = AABB(Vector3(-size.x * 0.5, -0.2, 0.0), Vector3(size.x, size.y + 0.2, t))
			var pts: PackedVector3Array = PackedVector3Array()
			for c: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
				pts.append(xf * (box.position + box.size * c))
			obstructions.append([pts, xf.origin.y + box.position.y, box.size.y])
	return errors


static func _marker(root: Node, parent: Node3D, nm: String, xf: Transform3D) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = nm
	m.transform = xf
	_own(root, parent, m)
	return m


static func _own(root: Node, parent: Node, n: Node) -> void:
	parent.add_child(n)
	n.owner = root
