## Ostrander Federal G2 dressing D (OF-C2 vault / ops lane, ENV C): a working bank vault in VT and lived-in ops rooms
## (VO, CP, OF), plus `faces` links for the chairs of the vault and ops rooms and the cage gates' floor stencils. One
## call from build_greybox.gd (after of_art_rooms, before the navmesh bake: placed floor props obstruct it):
##   preload(".../of_dress_d.gd").new(self).call(&"build")
## Data: of_dress_d_data.gd. Placement as of_art_rooms.gd: floor props get a catalog-AABB box collider (cut at the
## catalog `top`) and a nav obstruction; wall-mount and "on" items neither. A row whose box would overlap an existing
## prop, prefab, light or the hoist rig is left out (reported), so nothing here clips and no loot spawn moves.
extends RefCounted

const D: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_dress_d_data.gd")
const FOLDER: String = "DressD"
const SEAT_TARGETS: Array[String] = ["desk", "table", "counter_service", "counter_transaction", "coffee_table"]
## Wall rows stand this far off their face.
const WALL_GAP: float = 0.004
const HASH: float = 2.0
## Near-range wrappers of the catalog props placed here (generated, byte-stable; as of_art_rooms.gd _near_scene):
## "on" items draw to VIS_ON, wall-mount items to VIS_WALL, the rest to VIS_FLOOR (the hall / gallery views look
## through the glass fronts into these rooms).
const NEAR_DIR: String = "res://world/heists/ostrander_federal/art/props_near_d/"
const VIS_ON: float = 12.0
const VIS_WALL: float = 16.0
const VIS_FLOOR: float = 22.0

var b: Object
var root: Node3D
var report: PackedStringArray = PackedStringArray()
var _obst: Array[Array] = []    # [aabb, node]
var _placed: int = 0
var _skipped: PackedStringArray = PackedStringArray()
var _near: Dictionary = {}


func _init(builder: Object) -> void:
	b = builder


func build() -> void:
	root = b.get(&"map_root")
	_collect()
	var props: Node3D = root.get_node("Props") as Node3D
	var folder: Node3D = b.call(&"add", props, b.call(&"node3d", FOLDER)) as Node3D
	var rooms: Dictionary = {}
	for w: Array in D.WALL:
		_place_wall(_room(folder, rooms, String(w[0])), w)
	for f: Array in D.FREE:
		_place_free(_room(folder, rooms, String(f[0])), f)
	var pcs: int = _code_pcs()
	if pcs > 0:
		report.append("dress D: %d code PCs get the desktop visual" % pcs)
	var linked: int = _link_faces()
	_hatch(b.call(&"add", root.get_node("Geometry"), b.call(&"node3d", "StencilsD")) as Node3D)
	report.append("dress D: %d props placed in %d rooms, %d left out (%s), %d chair faces links"
		% [_placed, rooms.size(), _skipped.size(), ", ".join(_skipped), linked])
	for line: String in report:
		printerr("dress D: " + line)


func _room(folder: Node3D, rooms: Dictionary, rid: String) -> Node3D:
	if not rooms.has(rid):
		rooms[rid] = b.call(&"add", folder, b.call(&"node3d", rid))
	return rooms[rid]


# --- Obstacles -----------------------------------------------------------------------------------

func _collect() -> void:
	for top: String in ["Props", "Gameplay", "Variants", "Lighting", "Patrols", "Spawns", "Tactical", "Preplan",
			"ReviewCameras"]:
		var t: Node = root.get_node_or_null(top)
		if t == null:
			continue
		for c: Node in t.find_children("*", "Node3D", true, false):
			if c is GeometryInstance3D and not (c is MultiMeshInstance3D) and (c as GeometryInstance3D).visible:
				var a: AABB = (b.call(&"global_xform", c) as Transform3D) * (c as GeometryInstance3D).get_aabb()
				if a.size.length() < 20.0:
					_obst.append([a, _prop_root(c)])
			elif c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D and not _under_area(c):
				var sz: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
				var xf: Transform3D = b.call(&"global_xform", c)
				_obst.append([xf * AABB(-sz * 0.5, sz), _prop_root(c)])
			elif c is Light3D or c is Marker3D:
				var p: Vector3 = (b.call(&"global_xform", c) as Transform3D).origin
				var r: float = 0.2 if c is Light3D else (0.45 if top in ["Patrols", "Spawns", "Tactical"] else 0.3)
				if top == "ReviewCameras":
					r = 0.6
				_obst.append([AABB(p - Vector3.ONE * r, Vector3.ONE * r * 2.0), null])


func _under_area(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p is Area3D:
			return true
		p = p.get_parent()
	return false


func _under(n: Node, top: String) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != root:
		if String(p.name) == top:
			return true
		p = p.get_parent()
	return false


## The nearest ancestor with a `kind` meta (the prop / prefab a mesh belongs to), else the node itself.
func _prop_root(n: Node) -> Node:
	var p: Node = n
	while p != null and p != root:
		if p.has_meta(&"kind"):
			return p
		p = p.get_parent()
	return n


## An existing piece this box would overlap (the host of an "on" item excepted), or null.
func _hit(a: AABB, host_top: float) -> Variant:
	for o: Array in _obst:
		var oa: AABB = o[0]
		if not oa.intersects(a):
			continue
		if host_top > -INF and absf(oa.end.y - host_top) < 0.03 and oa.size.y > 0.3:
			continue   # the desk / table the item stands on
		return o
	return null


# --- Placement -----------------------------------------------------------------------------------

func _cat(asset: String) -> Dictionary:
	return PropCatalog.entry(StringName(asset))


static func _aabb(cat: Dictionary) -> AABB:
	var a: Array = cat.get("aabb", [])
	if a.size() != 6:
		return AABB()
	return AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]))


func _place_wall(parent: Node3D, row: Array) -> void:
	var face: Array = D.FACES[String(row[3])]
	var cat: Dictionary = _cat(String(row[2]))
	var bb: AABB = _aabb(cat)
	var nrm: Vector3 = Vector3(float(face[2]), 0.0, 0.0) if String(face[0]) == "x" else Vector3(0.0, 0.0, float(face[2]))
	var yaw: float = rad_to_deg(atan2(-nrm.x, -nrm.z))
	var along: float = float(row[4])
	var c: float = float(face[1])
	var on_face: Vector3 = Vector3(c, float(row[5]), along) if String(face[0]) == "x" else Vector3(along, float(row[5]), c)
	var pos: Vector3 = on_face + nrm * (bb.end.z + WALL_GAP)
	_place(parent, String(row[1]), String(row[2]), pos, yaw, cat)


func _place_free(parent: Node3D, row: Array) -> void:
	var p: Array = row[3]
	_place(parent, String(row[1]), String(row[2]), Vector3(float(p[0]), float(p[1]), float(p[2])), float(row[4]),
		_cat(String(row[2])))


func _place(parent: Node3D, nm: String, asset: String, pos: Vector3, yaw: float, cat: Dictionary) -> void:
	var place0: String = String(cat.get("place", "floor"))
	var vis: float = VIS_ON if place0 == "on" else (VIS_WALL if place0 == "wall_mount" else VIS_FLOOR)
	var ps: PackedScene = _near_scene(asset, vis)
	if ps == null:
		report.append("ERROR dress D %s: no scene for %s" % [nm, asset])
		return
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos)
	var bb: AABB = _aabb(cat)
	var world: AABB = xf * bb
	var place: String = String(cat.get("place", "floor"))
	var mount: String = String(cat.get("mount", ""))
	var host: float = pos.y if place == "on" else -INF
	var test: AABB = world.grow(-0.005)
	if place == "on":
		test.position.y += 0.01
		test.size.y = maxf(test.size.y - 0.01, 0.005)
	var hit: Variant = _hit(test, host)
	if hit != null:
		var o: Node = (hit as Array)[1]
		_skipped.append("%s (hits %s)" % [nm, String(root.get_path_to(o)) if o != null and root.is_ancestor_of(o) else "marker"])
		return
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = nm
	inst.transform = b.call(&"global_xform", parent).affine_inverse() * xf
	b.call(&"add", parent, inst)
	_obst.append([world, inst])
	_placed += 1
	if mount != "" or place in ["on", "ceiling", "wall_mount", "above_door", "rug"]:
		return
	_collide(inst, cat, xf, bb)


## The catalog scene with every mesh drawing to `vis` at most: a generated wrapper scene in NEAR_DIR (the catalog
## scene instanced, its mesh nodes' visibility ranges overridden), written only when its text changes.
func _near_scene(asset: String, vis: float) -> PackedScene:
	if _near.has(asset):
		return _near[asset]
	var base: PackedScene = b.call(&"catalog_scene", asset) as PackedScene
	if base == null:
		return null
	var out: PackedScene = base
	var inst: Node = base.instantiate()
	var body: PackedStringArray = []
	var editable: PackedStringArray = []
	for m: Node in inst.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = m as GeometryInstance3D
		if gi.visibility_range_end > 0.0 and gi.visibility_range_end <= vis:
			continue
		body.append('\n[node name="%s" parent="%s"]\nvisibility_range_end = %.1f\nvisibility_range_end_margin = %.1f\n'
			% [m.name, String(inst.get_path_to(m.get_parent())), vis, vis * 0.1] + "visibility_range_fade_mode = 1\n")
		var a: Node = m.get_parent()
		while a != inst:
			if a.scene_file_path != "" and not editable.has(String(inst.get_path_to(a))):
				editable.append(String(inst.get_path_to(a)))
			a = a.get_parent()
	if not body.is_empty():
		var text: String = '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="%s" id="1_base"]\n' \
			% base.resource_path + '\n[node name="%s" instance=ExtResource("1_base")]\n' % inst.name + "".join(body)
		editable.sort()
		for e: String in editable:
			text += '\n[editable path="%s"]\n' % e
		var path: String = NEAR_DIR + asset + ".tscn"
		if not FileAccess.file_exists(path) or FileAccess.get_file_as_string(path) != text:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NEAR_DIR))
			var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			f.store_string(text)
			f.close()
		out = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	inst.free()
	_near[asset] = out
	return out


## Box collider from the catalog AABB (cut at its `top`) and a nav obstruction, unless the prop brings its own collision.
func _collide(inst: Node3D, cat: Dictionary, xf: Transform3D, bb0: AABB) -> void:
	var bb: AABB = bb0
	var top: float = float(cat.get("top", 0.0))
	if top > 0.0 and top < bb.end.y:
		bb.size.y = top - bb.position.y
	if inst.find_children("*", "CollisionObject3D", true, false).is_empty():
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		b.call(&"add", inst, body)
		SurfaceTags.tag(body, StringName(String(cat.get("surface", ""))))
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Shape"
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(maxf(bb.size.x, 0.01), maxf(bb.size.y, 0.01), maxf(bb.size.z, 0.01))
		cs.shape = shape
		cs.position = bb.get_center()
		b.call(&"add", body, cs)
	b.call(&"obstruct", xf, bb)


## The code-PC HackTerminals still on the placeholder (OF, AO1-3, EA): the desktop visual lane B gave pc_vault_ops.
func _code_pcs() -> int:
	var ps: PackedScene = load("res://world/props/hack_terminal/prop_of_desk_pc.tscn") as PackedScene
	var g: Node = root.get_node_or_null("Variants/Group_code_pc")
	if g == null or ps == null:
		return 0
	var n: int = 0
	for pc: Node in g.find_children("CodePC", "", true, false):
		if "visual_scene" in pc and pc.get(&"visual_scene") == null:
			pc.set(&"visual_scene", ps)
			n += 1
	return n


# --- Chairs face their desk ----------------------------------------------------------------------

## Every chair of FACES_ROOMS within 1 m of a desk / table and without a `faces` link: linked to it when it already
## faces it (15 deg), else to an aim marker straight ahead over the top (as of_dress.gd _link_faces).
func _link_faces() -> int:
	var chairs: Array[Node3D] = []
	var targets: Array[Node3D] = []
	for top: String in ["Props", "Variants"]:
		for n: Node in root.get_node(top).find_children("*", "Node3D", true, false):
			var n3: Node3D = n as Node3D
			if n3 == null or not n3.has_meta(&"kind") or not _in_rooms(_gx(n3).origin):
				continue
			if n3.get_parent() != null and n3.get_parent().has_meta(&"art_asset"):
				continue
			var k: String = String(n3.get_meta(&"kind"))
			if k == "chair":
				chairs.append(n3)
			elif k in SEAT_TARGETS:
				targets.append(n3)
	var n_linked: int = 0
	for c: Node3D in chairs:
		if c.has_meta(&"faces"):
			continue
		var cx: Transform3D = _gx(c)
		var best: Node3D = null
		var best_d: float = INF
		for t: Node3D in targets:
			var ft: AABB = _footprint(t)
			if ft.size == Vector3.ZERO or not ft.grow(1.0).has_point(Vector3(cx.origin.x, ft.position.y + 0.01, cx.origin.z)):
				continue
			var dist: float = ft.get_center().distance_to(cx.origin)
			if dist < best_d:
				best_d = dist
				best = t
		if best == null:
			continue
		var fb: AABB = _footprint(best)
		var fwd: Vector3 = -cx.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var to: Vector3 = fb.get_center() - cx.origin
		to.y = 0.0
		if rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))) <= 15.0:
			c.set_meta(&"faces", c.get_path_to(best))
			n_linked += 1
			continue
		var hit: float = -1.0
		for i: int in range(1, 50):
			var q: Vector3 = cx.origin + fwd * (0.05 * float(i))
			if q.x > fb.position.x + 0.05 and q.x < fb.end.x - 0.05 and q.z > fb.position.z + 0.05 and q.z < fb.end.z - 0.05:
				hit = 0.05 * float(i) + 0.15
				break
		if hit < 0.0:
			report.append("WARN chair %s: its front misses %s" % [root.get_path_to(c), best.name])
			continue
		var aim: Marker3D = Marker3D.new()
		aim.name = String(c.name) + "Aim"
		var par: Node3D = c.get_parent() as Node3D
		aim.transform = Transform3D(Basis.IDENTITY, _gx(par).affine_inverse() * (cx.origin + fwd * hit + Vector3.UP * 0.75))
		b.call(&"add", par, aim)
		c.set_meta(&"faces", c.get_path_to(aim))
		n_linked += 1
	return n_linked


func _in_rooms(p: Vector3) -> bool:
	for r: Node in root.get_node("Rooms").get_children():
		var rv: RoomVolume = r as RoomVolume
		if rv == null or not (String(rv.room_id) in D.FACES_ROOMS):
			continue
		for cs: Node in rv.get_children():
			var shape: CollisionShape3D = cs as CollisionShape3D
			if shape == null or not (shape.shape is BoxShape3D):
				continue
			var sz: Vector3 = (shape.shape as BoxShape3D).size
			if AABB(shape.position - sz * 0.5, sz).grow(0.05).has_point(p):
				return true
	return false


func _gx(n: Node3D) -> Transform3D:
	return b.call(&"global_xform", n)


## A prop's floor footprint: its box collider, else its visual AABB.
func _footprint(n: Node3D) -> AABB:
	for cs: Node in n.find_children("*", "CollisionShape3D", true, false):
		var s: CollisionShape3D = cs as CollisionShape3D
		if s.shape is BoxShape3D:
			var sz: Vector3 = (s.shape as BoxShape3D).size
			return _gx(s) * AABB(-sz * 0.5, sz)
	var out: AABB = AABB()
	var first: bool = true
	for g: Node in n.find_children("*", "GeometryInstance3D", true, false):
		var w: AABB = _gx(g as Node3D) * (g as GeometryInstance3D).get_aabb()
		out = w if first else out.merge(w)
		first = false
	return out


# --- Stencils ------------------------------------------------------------------------------------

## Yellow hatched keep-clear bands in front of the cage gates: diagonal stripes 3 mm over the vault floor (one mesh).
func _hatch(parent: Node3D) -> void:
	var lib: BaseMaterial3D = load("res://world/materials/plaster_painted.tres") as BaseMaterial3D
	var paint: BaseMaterial3D = lib.duplicate() as BaseMaterial3D
	paint.resource_name = "of_stencil_yellow"
	paint.albedo_color = Color(1.0, 0.78, 0.22)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y: float = D.HATCH_Y
	var w: float = D.HATCH_STRIPE
	for r: Array in D.HATCH:
		var x0: float = float(r[0])
		var z0: float = float(r[1])
		var x1: float = float(r[2])
		var z1: float = float(r[3])
		# a border frame, then 45 deg stripes clipped to the band
		_quad(st, Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z0 + 0.05), Vector2(x0, z0 + 0.05), y)
		_quad(st, Vector2(x0, z1 - 0.05), Vector2(x1, z1 - 0.05), Vector2(x1, z1), Vector2(x0, z1), y)
		_quad(st, Vector2(x0, z0 + 0.05), Vector2(x0 + 0.05, z0 + 0.05), Vector2(x0 + 0.05, z1 - 0.05), Vector2(x0, z1 - 0.05), y)
		_quad(st, Vector2(x1 - 0.05, z0 + 0.05), Vector2(x1, z0 + 0.05), Vector2(x1, z1 - 0.05), Vector2(x1 - 0.05, z1 - 0.05), y)
		var span: float = (x1 - x0) + (z1 - z0)
		var s: float = 0.25
		while s < span:
			var a0: float = s
			var a1: float = s + w
			var pts: Array[Vector2] = _band(x0 + 0.05, z0 + 0.05, x1 - 0.05, z1 - 0.05, a0, a1)
			if pts.size() >= 3:
				for i: int in range(1, pts.size() - 1):
					_tri(st, pts[0], pts[i], pts[i + 1], y)
			s += w * 2.5
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	mesh.resource_name = "of_stencils_d"
	mesh.surface_set_material(0, paint)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "GateHatches"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.call(&"add", parent, mi)


## The rectangle [x0, x1] x [z0, z1] clipped to the diagonal band a0 <= (x - x0) + (z - z0) <= a1 (convex polygon).
static func _band(x0: float, z0: float, x1: float, z1: float, a0: float, a1: float) -> Array[Vector2]:
	var poly: Array[Vector2] = [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
	poly = _clip(poly, x0, z0, a0, 1.0)
	poly = _clip(poly, x0, z0, a1, -1.0)
	return poly


## Keeps the part of poly with s * ((x - x0) + (z - z0) - a) >= 0.
static func _clip(poly: Array[Vector2], x0: float, z0: float, a: float, s: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in range(poly.size()):
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		var dp: float = s * ((p.x - x0) + (p.y - z0) - a)
		var dq: float = s * ((q.x - x0) + (q.y - z0) - a)
		if dp >= 0.0:
			out.append(p)
		if (dp >= 0.0) != (dq >= 0.0):
			out.append(p.lerp(q, dp / (dp - dq)))
	return out


static func _quad(st: SurfaceTool, a: Vector2, b2: Vector2, c: Vector2, d: Vector2, y: float) -> void:
	_tri(st, a, b2, c, y)
	_tri(st, a, c, d, y)


## One up-facing triangle (clockwise from above = front), UV = world metres / 2.
static func _tri(st: SurfaceTool, a: Vector2, b2: Vector2, c: Vector2, y: float) -> void:
	var pts: Array[Vector2] = [a, b2, c]
	var cr: float = (b2 - a).cross(c - a)
	if cr < 0.0:   # front faces wind clockwise seen from above: cross2d(x, z) > 0
		pts = [a, c, b2]
	for p: Vector2 in pts:
		st.set_normal(Vector3.UP)
		st.set_uv(p / 2.0)
		st.add_vertex(Vector3(p.x, y, p.y))
