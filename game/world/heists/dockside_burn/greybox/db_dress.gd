## Dockside Burn G2 dressing (DB-C2, ENV C): the KitPlacer pass over every RoomVolume with a dressing kit (as Gallery
## Night's gn_dress.gd). The map-built props (layout PROPS, already carrying their catalog visuals) enter each room as
## virtual anchors: the kit counts them (no second counter / desk) and puts its "on" items (monitors, money counters,
## microwaves) on them, then they are dropped from the instancing. Every gameplay prefab, marker, door swing, window,
## stair, railing, strip curtain and review-camera standpoint is a keep-out, plus the room keep-outs of the dressing
## data (the hall's open floor, the racking aisles). Placed floor props get a box collider and a navmesh obstruction.
## Kit fixtures carry the room's lights (LIGHT_TWEAKS); a few cast shadows (SHADOW_FIXTURES). Fill lights (meta fill)
## lift each room's ceiling. Data: dockside_burn_dressing.gd.
extends RefCounted

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
const L: GDScript = preload("res://world/heists/dockside_burn/greybox/dockside_burn_layout.gd")
const D: GDScript = preload("res://world/heists/dockside_burn/greybox/dockside_burn_dressing.gd")
const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")
const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const KITS_DIR: String = "res://world/kits/"
## PO6-17 breach openings: the dressing keeps this clear on both faces.
const BREACH_REACH: float = 1.2
## Half size of the keep-out kept around every floor marker (spawn, patrol, use point...).
const MARKER_HALF: float = 0.35
## Exit signs go above the frame head.
const EXIT_SIGN_Z: float = 2.36
## Interior kit props draw to this distance (as Gallery Night's near-range wrappers: the building's rooms stack inside
## every exterior view; no DB room is deeper than ~30 m).
const INTERIOR_VIS: float = 30.0
const NEAR_DIR: String = "res://world/heists/dockside_burn/art/props_near/"
## Strip curtains: the passage through them stays clear this far on both sides.
const CURTAIN_CLEAR: float = 1.5
static var _near: Dictionary = {}

## Placement summary per kit room (printed by the builder): "id: n props, missing, warnings".
var report: PackedStringArray = []
var counts: Dictionary = {}

var _b: Object
var _root: Node3D
var _cat: Dictionary = {}
var _scenes: Dictionary = {}
var _markers: Array[Vector3] = []
var _boxes: Array[AABB] = []
## Door prefabs: [world position, yaw (deg), leaf width].
var _doors: Array[Array] = []
## Map-built props with a catalog visual: [node, asset, world transform of the visual].
var _mapbuilt: Array[Array] = []
var _room_nodes: Dictionary = {}


func setup(builder: Object, root: Node3D) -> void:
	_b = builder
	_root = root
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		_cat = parsed
	else:
		report.append("ERROR: cannot read %s" % CATALOG_PATH)


func scene(asset: String) -> PackedScene:
	if _scenes.has(asset):
		return _scenes[asset]
	var ps: PackedScene = null
	if _cat.has(asset):
		ps = load(String((_cat[asset] as Dictionary)["scene"])) as PackedScene
	if ps == null:
		report.append("ERROR: no scene for asset %s" % asset)
	_scenes[asset] = ps
	return ps


func aabb(asset: String) -> AABB:
	var a: Array = (_cat[asset] as Dictionary)["aabb"]
	return AABB(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3(float(a[3]), float(a[4]), float(a[5])))


# --- Main pass ----------------------------------------------------------------------------------

func dress(props_root: Node3D) -> void:
	_collect()
	for r: Array in L.ROOMS:
		var kit: String = String(r[2])
		if kit == "" or String(r[1]) == "exterior":
			continue
		var res: Array = _interior_room(r)
		_dress_room(res[0], res[1], String(r[0]), kit, props_root)
	var direct: Node3D = _folder(props_root, "Direct")
	for d: Array in D.DIRECT_PROPS:
		var asset: String = String(d[1])
		if not _cat.has(asset):
			report.append("ERROR direct: asset %s not in catalog" % asset)
			continue
		var xf: Transform3D = _anchor_xform(asset, d[2], float(d[3]))
		var nd: Node3D = scene(asset).instantiate() as Node3D
		nd.name = String(d[0])
		nd.transform = xf
		var metas: Dictionary = d[4]
		for k: Variant in metas:
			nd.set_meta(StringName(String(k)), metas[k])
		direct.add_child(nd)
		nd.owner = _root
		var cat: Dictionary = _cat[asset]
		_finish_node(nd, asset, String(cat.get("place", "floor")), String(cat.get("mount", "")), xf)
	_shadow_fixtures()


func _folder(parent: Node3D, nm: String) -> Node3D:
	var f: Node3D = parent.get_node_or_null(nm) as Node3D
	if f == null:
		f = Node3D.new()
		f.name = nm
		parent.add_child(f)
		f.owner = _root
	return f


func _dress_room(room: KitRoom, world_box: AABB, id: String, kit_id: String, props_root: Node3D) -> void:
	var kit: DressingKit = load(KITS_DIR + kit_id + ".tres") as DressingKit
	if kit == null:
		report.append("ERROR %s: kit %s not found" % [id, kit_id])
		return
	_add_keepouts(room, world_box, id)
	# virtual anchors: the map-built props inside this room's clear box (hosts, required kinds already present)
	var virtual: Array[Node3D] = []
	for mb: Array in _mapbuilt:
		var wx: Transform3D = mb[2]
		var c: Vector3 = wx.origin
		if c.x < world_box.position.x or c.x > world_box.end.x or c.z < world_box.position.z or c.z > world_box.end.z:
			continue
		if c.y < world_box.position.y - 0.3 or c.y > world_box.position.y + 1.0:
			continue
		room.add_anchor(wx, StringName(String(mb[1])))
		virtual.append(mb[0])
	var seed: int = int(D.KIT_SEEDS.get(id, 9000))
	var res: Dictionary = KitPlacer.place(room, kit, seed, not D.NO_CEILING_GRID.has(id))
	var all: Array = res["placements"]
	var nv: int = virtual.size()
	var kept: Array = []
	var faces_map: Array[NodePath] = []  # per kept placement: a map-built target (else empty)
	for i: int in range(nv, all.size()):
		var pd: Dictionary = (all[i] as Dictionary).duplicate()
		pd["scene"] = near_scene_path(String(pd["asset"]), String(pd["scene"]))
		var f: int = int(pd.get("faces", -1))
		faces_map.append(NodePath() if f < 0 or f >= nv else NodePath(String(virtual[f].name)))
		pd["faces"] = f - nv if f >= nv else -1
		kept.append(pd)
	var parent: Node3D = _folder(props_root, id)
	var nodes: Array[Node3D] = KitPlacer.instantiate({"placements": kept}, parent, _root)
	for i: int in range(nodes.size()):
		var p: Dictionary = kept[i]
		_finish_node(nodes[i], String(p["asset"]), String(p["mode"]), String(p["mount"]), p["xform"])
		if not faces_map[i].is_empty():
			var target: Node3D = _find_mapbuilt(String(faces_map[i]))
			if target != null:
				nodes[i].set_meta(&"faces", nodes[i].get_path_to(target))
	_room_nodes[id] = nodes
	counts[id] = nodes.size()
	_link_monitors(nodes, id)
	for n: Node3D in nodes:
		_tweak_light(n, id)
	var missing: PackedStringArray = res["missing"]
	var warnings: PackedStringArray = res["warnings"]
	report.append("%s (%s, seed %d): %d props + %d map-built%s%s" % [id, kit_id, seed, nodes.size(), nv,
		"" if missing.is_empty() else ", MISSING " + ",".join(missing),
		"" if warnings.is_empty() else ", warnings: " + "; ".join(warnings)])
	if not missing.is_empty():
		report.append("ERROR %s: required kinds not placed: %s" % [id, ",".join(missing)])


func _find_mapbuilt(nm: String) -> Node3D:
	for mb: Array in _mapbuilt:
		if String((mb[0] as Node3D).name) == nm:
			return mb[0]
	return null


## LIGHT_TWEAKS: per room id and fixture asset -> Light3D properties.
func _tweak_light(n: Node3D, key: String) -> void:
	var tweaks: Dictionary = D.LIGHT_TWEAKS.get(key, {})
	var lt: Light3D = n.get_node_or_null("Light") as Light3D
	if lt == null or tweaks.is_empty():
		return
	var asset: String = String(n.scene_file_path.get_file().get_basename())
	if not tweaks.has(asset):
		return
	_root.set_editable_instance(n, true)
	var props: Dictionary = tweaks[asset]
	for k2: Variant in props:
		if String(k2) in lt:
			lt.set(StringName(String(k2)), props[k2])


## The near-range variant of a catalog wrapper scene (INTERIOR_VIS): an inherited scene under NEAR_DIR overriding its
## meshes' visibility range (written as text, byte-stable; as gn_dress.near_scene_path). Lights never get one.
static func near_scene_path(asset: String, scene_path: String) -> String:
	if _near.has(asset):
		return String(_near[asset])
	var base: PackedScene = load(scene_path) as PackedScene
	var out: String = scene_path
	if base != null:
		var inst: Node = base.instantiate()
		var body: PackedStringArray = []
		var editable: PackedStringArray = []
		for m: Node in inst.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = m as GeometryInstance3D
			if gi.visibility_range_end > 0.0 and gi.visibility_range_end <= INTERIOR_VIS:
				continue
			var parent_path: String = String(inst.get_path_to(m.get_parent()))
			body.append('\n[node name="%s" parent="%s"]\nvisibility_range_end = %.1f\nvisibility_range_end_margin = %.1f\n'
				% [m.name, parent_path, INTERIOR_VIS, INTERIOR_VIS * 0.1] + "visibility_range_fade_mode = 1\n")
			var a: Node = m.get_parent()
			while a != inst:
				if a.scene_file_path != "" and not editable.has(String(inst.get_path_to(a))):
					editable.append(String(inst.get_path_to(a)))
				a = a.get_parent()
		if not body.is_empty():
			var text: String = '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="%s" id="1_base"]\n' \
				% scene_path + '\n[node name="%s" instance=ExtResource("1_base")]\n' % inst.name + "".join(body)
			editable.sort()
			for e: String in editable:
				text += '\n[editable path="%s"]\n' % e
			out = NEAR_DIR + asset + ".tscn"
			if not FileAccess.file_exists(out) or FileAccess.get_file_as_string(out) != text:
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NEAR_DIR))
				var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
				f.store_string(text)
				f.close()
		inst.free()
	_near[asset] = out
	return out


## Monitors face the chair in front of them (orientation check): the nearest chair within 30 deg of the screen's front,
## a kit chair or a map-built one.
func _link_monitors(nodes: Array[Node3D], id: String) -> void:
	var chairs: Array[Node3D] = []
	for c: Node3D in nodes:
		if String(c.get_meta(&"kind", "")) == "chair":
			chairs.append(c)
	for mb: Array in _mapbuilt:
		if String((mb[0] as Node3D).get_meta(&"kind", "")) == "chair":
			chairs.append(mb[0])
	for m: Node3D in nodes:
		if String(m.get_meta(&"kind", "")) != "monitor" or m.has_meta(&"faces"):
			continue
		var mx: Transform3D = _gx(m)
		var front: Vector3 = -mx.basis.z
		front.y = 0.0
		var best: Node3D = null
		var best_d: float = INF
		for c: Node3D in chairs:
			var to: Vector3 = _gx(c).origin - mx.origin
			to.y = 0.0
			if to.length() < 0.05 or to.length() > 2.5 or front.normalized().dot(to.normalized()) < cos(deg_to_rad(18.0)):
				continue
			if to.length() < best_d:
				best_d = to.length()
				best = c
		if best != null:
			m.set_meta(&"faces", m.get_path_to(best))
		else:
			report.append("WARN %s: monitor %s has no chair in front" % [id, m.name])


## Anchor pivot: floor props as given; wall mounts move to the wall face + 2 mm with the item centred on `pos`; ceiling
## mounts hang from `pos`.
func _anchor_xform(asset: String, pos: Vector3, yaw_deg: float) -> Transform3D:
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var mount: String = String((_cat[asset] as Dictionary).get("mount", ""))
	var p: Vector3 = pos
	if mount == "wall":
		var bb: AABB = aabb(asset)
		p -= Vector3.UP * bb.get_center().y
		p += basis * Vector3(0.0, 0.0, -0.002)
	elif mount == "ceiling":
		p.y -= 0.002
	return Transform3D(basis, p)


## Collider + navmesh obstruction for floor props (not mounts, "on" items or ceiling fixtures).
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
	SurfaceTags.tag(body, StringName(String(cat.get("surface", ""))))  # PO-8
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
	_b.call(&"obstruct", xf, bb)


func _shadow_fixtures() -> void:
	for s: Array in D.SHADOW_FIXTURES:
		var nodes: Array = _room_nodes.get(String(s[0]), [])
		var target: Vector3 = s[1]
		var best: Node3D = null
		var best_d: float = INF
		for v: Variant in nodes:
			var n: Node3D = v as Node3D
			if n.get_node_or_null("Light") == null:
				continue
			var d: float = _gx(n).origin.distance_to(target)
			if d < best_d:
				best_d = d
				best = n
		if best == null:
			report.append("WARN %s: no fixture to cast shadows" % s[0])
			continue
		_root.set_editable_instance(best, true)
		(best.get_node("Light") as Light3D).shadow_enabled = true


# --- Rooms --------------------------------------------------------------------------------------

## [KitRoom, world AABB of the clear interior] for a ROOMS row: its (largest, or DRESS_BOX) box inside its walls'
## faces, floor to ceiling; doors, wall openings and windows on its outline.
func _interior_room(r: Array) -> Array:
	var rid: String = String(r[0])
	var boxes: Array = r[4]
	var b: Array = boxes[0]
	for bb: Variant in boxes:
		var a: Array = bb
		if (float(a[3]) - float(a[0])) * (float(a[5]) - float(a[2])) > (float(b[3]) - float(b[0])) * (float(b[5]) - float(b[2])):
			b = a
	var y: float = float(b[1])
	var top: float = float(b[4])
	var x0: float = float(b[0])
	var z0: float = float(b[2])
	var x1: float = float(b[3])
	var z1: float = float(b[5])
	if D.DRESS_BOX.has(rid):
		var db: Array = D.DRESS_BOX[rid]
		x0 = float(db[0])
		z0 = float(db[1])
		x1 = float(db[2])
		z1 = float(db[3])
	var yt: float = y + 1.0
	var lo: Vector3 = Vector3(x0 + half_t("z", x0, yt, z0, z1), y, z0 + half_t("x", z0, yt, x0, x1))
	var hi: Vector3 = Vector3(x1 - half_t("z", x1, yt, z0, z1), top, z1 - half_t("x", z1, yt, x0, x1))
	var clear: AABB = AABB(lo, hi - lo)
	var room: KitRoom = KitRoom.from_aabb(clear, StringName(rid))
	_thick_keepouts(room, x0, z0, x1, z1, lo, hi)
	var rect: Rect2 = Rect2(x0, z0, x1 - x0, z1 - z0)
	for d: Array in _doors:
		var pos: Vector3 = d[0]
		if absf(pos.y - y) < 0.3 and _on_rect_edge(rect, pos, absf(sin(deg_to_rad(float(d[1])))) < 0.5):
			room.add_door(pos, float(d[2]), -1.0, minf(4.2, hi.y - y))
	for o: Array in _wall_openings():
		var along_x: bool = String(o[0]) == "x"
		var mid: Vector3 = Vector3((float(o[2]) + float(o[3])) * 0.5, y, float(o[1])) if along_x \
			else Vector3(float(o[1]), y, (float(o[2]) + float(o[3])) * 0.5)
		if not _on_rect_edge(rect, mid, along_x) or float(o[5]) <= y + 0.05 or float(o[4]) >= y + 3.0:
			continue
		var width: float = float(o[3]) - float(o[2])
		if float(o[4]) <= y + 0.05:
			room.add_door(mid, width, 1.2, minf(float(o[5]) - y, clear.size.y))
		else:
			room.add_window(mid + Vector3.UP * (float(o[4]) - y), width + 0.2, float(o[4]) - y, minf(float(o[5]) - y, clear.size.y))
	return [room, clear]


## Every wall opening of the layout: [axis, fixed, a0, a1, y0, y1] (exterior / interior wall extras, portals,
## glazing; door openings come from the door prefabs).
func _wall_openings() -> Array:
	var out: Array = []
	for w: Array in L.EXT_WALLS:
		for op: Array in w[8]:
			out.append([String(w[1]), float(w[2]), float(op[0]), float(op[1]), float(op[2]), float(op[3])])
	for w2: Array in L.INT_WALLS:
		for op2: Array in w2[9]:
			out.append([String(w2[1]), float(w2[2]), float(op2[0]), float(op2[1]), float(op2[2]), float(op2[3])])
	for p: Array in L.PORTALS:
		for w3: Array in L.INT_WALLS:
			if String(w3[0]) == String(p[0]):
				var op3: Array = p[1]
				out.append([String(w3[1]), float(w3[2]), float(op3[0]), float(op3[1]), float(op3[2]), float(op3[3])])
	for g: Array in L.GLAZING:
		out.append([String(g[1]), float(g[2]), float(g[3]), float(g[4]), float(g[5]), float(g[6])])
	return out


## The wall stretches on a room edge (axis "x": runs along x at z = fixed) at height y: [[from, to, thickness], ...].
static func edge_walls(axis: String, fixed: float, y: float, a0: float, a1: float) -> Array:
	var out: Array = []
	for w: Array in L.EXT_WALLS:
		if String(w[1]) == axis and absf(float(w[2]) - fixed) < 0.01 and _spans(w, 3, a0, a1, y):
			out.append([float(w[3]), float(w[4]), L.EXT_T])
	for w2: Array in L.INT_WALLS:
		if String(w2[1]) == axis and absf(float(w2[2]) - fixed) < 0.01 and _spans(w2, 3, a0, a1, y):
			out.append([float(w2[3]), float(w2[4]), float(w2[7])])
	for sh: Array in L.SHEDS:
		var near: float = float(sh[2] if axis == "x" else sh[1])
		var far: float = float(sh[4] if axis == "x" else sh[3])
		if absf(fixed - near) < 0.01 or absf(fixed - far) < 0.01:
			out.append([float(sh[1] if axis == "x" else sh[2]), float(sh[3] if axis == "x" else sh[4]), float(sh[8])])
	return out


## Half the thinnest wall on a room edge (its clear rect), 0.1 m by default; thicker stretches become keep-outs.
static func half_t(axis: String, fixed: float, y: float, a0: float, a1: float) -> float:
	var t: float = INF
	for sg: Array in edge_walls(axis, fixed, y, a0, a1):
		t = minf(t, float(sg[2]))
	return 0.1 if t == INF else t * 0.5


## Keep-outs over the stretches of a room's edges where the wall is thicker than its clear rect assumes (wall mounts
## and floor props stay off them).
func _thick_keepouts(room: KitRoom, x0: float, z0: float, x1: float, z1: float, lo: Vector3, hi: Vector3) -> void:
	var yt: float = lo.y + 1.0
	# [axis, wall line, inward sign, clear face, from, to]
	for e: Array in [["x", z0, 1.0, lo.z, x0, x1], ["x", z1, -1.0, hi.z, x0, x1], ["z", x0, 1.0, lo.x, z0, z1],
			["z", x1, -1.0, hi.x, z0, z1]]:
		for sg: Array in edge_walls(String(e[0]), float(e[1]), yt, float(e[4]), float(e[5])):
			var face: float = float(e[1]) + float(e[2]) * float(sg[2]) * 0.5
			if (face - float(e[3])) * float(e[2]) <= 0.005:
				continue
			var d0: float = minf(float(e[3]), face + float(e[2]) * 0.05)
			var d1: float = maxf(float(e[3]), face + float(e[2]) * 0.05)
			var s0: float = maxf(float(sg[0]), float(e[4]))
			var s1: float = minf(float(sg[1]), float(e[5]))
			if String(e[0]) == "x":
				room.add_keep_out(AABB(Vector3(s0, lo.y, d0), Vector3(s1 - s0, hi.y - lo.y, d1 - d0)))
			else:
				room.add_keep_out(AABB(Vector3(d0, lo.y, s0), Vector3(d1 - d0, hi.y - lo.y, s1 - s0)))


static func _spans(w: Array, i: int, a0: float, a1: float, y: float) -> bool:
	return float(w[i]) < a1 - 0.3 and float(w[i + 1]) > a0 + 0.3 and float(w[i + 2]) <= y and float(w[i + 3]) >= y


static func _on_rect_edge(r: Rect2, pos: Vector3, along_x: bool) -> bool:
	if along_x:
		return (absf(pos.z - r.position.y) < 0.25 or absf(pos.z - r.end.y) < 0.25) and pos.x > r.position.x and pos.x < r.end.x
	return (absf(pos.x - r.position.x) < 0.25 or absf(pos.x - r.end.x) < 0.25) and pos.z > r.position.y and pos.z < r.end.y


# --- Keep-outs ----------------------------------------------------------------------------------

func _add_keepouts(room: KitRoom, world_box: AABB, id: String) -> void:
	var probe: AABB = world_box.grow(0.05)
	for b: AABB in _boxes:
		if b.intersects(probe):
			room.add_keep_out(b)
	for m: Vector3 in _markers:
		if m.x < probe.position.x or m.x > probe.end.x or m.z < probe.position.z or m.z > probe.end.z:
			continue
		if m.y < world_box.position.y - 0.3 or m.y > world_box.position.y + 3.5:
			continue
		room.add_keep_out(AABB(Vector3(m.x - MARKER_HALF, m.y - 0.05, m.z - MARKER_HALF),
			Vector3(MARKER_HALF * 2.0, 2.0, MARKER_HALF * 2.0)))
	for k: Variant in D.KEEP_OUT.get(id, []):
		var b2: Array = k
		room.add_keep_out(AABB(Vector3(float(b2[0]), float(b2[1]), float(b2[2])),
			Vector3(float(b2[3]) - float(b2[0]), float(b2[4]) - float(b2[1]), float(b2[5]) - float(b2[2]))))


## Everything the kits must leave alone: gameplay prefabs (collision + visual), their use points, door prefabs (their
## swing is reserved per room), spawns / patrol / tactical / preplan markers, nav-link ends, the map-built props, the
## stairs and railings, the strip curtains' passage, the review cameras' standpoints and the PO6-17 breach openings.
func _collect() -> void:
	for c: String in ["Gameplay", "Variants", "Navigation", "AssaultEvents"]:
		var top: Node = _root.get_node_or_null(c)
		if top != null:
			for n: Node in top.find_children("*", "", true, false):
				_collect_node(n)
	for c2: String in ["Spawns", "Patrols", "Tactical", "Preplan", "Variants", "Gameplay"]:
		var top2: Node = _root.get_node_or_null(c2)
		if top2 == null:
			continue
		for n2: Node in top2.find_children("*", "Marker3D", true, false):
			_markers.append(_gx(n2 as Node3D).origin)
		for n3: Node in top2.find_children("*", "Node3D", true, false):
			if n3 is SpawnPoint or n3 is PatrolPoint or n3 is TacticalPoint:
				_markers.append(_gx(n3 as Node3D).origin)
	var props: Node = _root.get_node_or_null("Props")
	if props != null:
		for p: Node in props.find_children("*", "Node3D", false, false):
			_collect_mapbuilt(p as Node3D)
	for rl: Array in L.RAILINGS:
		var bb: Array = rl[1]
		var rlo: Vector3 = Vector3(float(bb[0]), float(bb[1]), float(bb[2]))
		var rhi: Vector3 = Vector3(float(bb[3]), float(bb[4]), float(bb[5]))
		_boxes.append(AABB(rlo, rhi - rlo).grow(0.15))
	for sc: Array in L.STRIP_CURTAINS:
		var cb: Array = sc[1]
		var lo: Vector3 = Vector3(float(cb[0]), float(cb[1]), float(cb[2]) - CURTAIN_CLEAR)
		var hi: Vector3 = Vector3(float(cb[3]), float(cb[4]), float(cb[5]) + CURTAIN_CLEAR)
		_boxes.append(AABB(lo, hi - lo))
	for cam: Array in L.REVIEW_CAMERAS:
		if String(cam[0]).begins_with("TopDown"):
			continue
		var cp: Vector3 = cam[1]
		_boxes.append(AABB(cp - Vector3(0.6, 1.75, 0.6), Vector3(1.2, 2.1, 1.2)))
	_boxes.append_array(AM.keep_outs(L.ASSAULT_BREACHES, BREACH_REACH))


## A Props child placed by the map (layout props, chairs; the masts): its collider boxes; a catalog visual makes it a
## virtual anchor of its room.
func _collect_mapbuilt(p: Node3D) -> void:
	if p is CollisionObject3D or p.has_meta(&"kind"):
		var vis: Node3D = p.get_node_or_null("Visual") as Node3D
		if vis != null and p.has_meta(&"art_asset"):  # a virtual anchor of its room (KitPlacer keeps clear of it)
			_mapbuilt.append([p, String(p.get_meta(&"art_asset")), _gx(vis)])
			# its collider too (it may be larger than the visual), 2 cm below its top so "on" items still sit on it
			for cs2: Node in p.find_children("*", "CollisionShape3D", false, false):
				var bs2: BoxShape3D = (cs2 as CollisionShape3D).shape as BoxShape3D
				if bs2 != null:
					var kb: AABB = (_gx(cs2 as Node3D) * AABB(-bs2.size * 0.5, bs2.size)).grow(0.01)
					kb.size.y = maxf(0.05, kb.size.y - 0.03)
					_boxes.append(kb)
			return
		var any: bool = false
		for cs: Node in p.find_children("*", "CollisionShape3D", true, false):
			var shp: Shape3D = (cs as CollisionShape3D).shape
			var bs: BoxShape3D = shp as BoxShape3D
			if (cs as CollisionShape3D).disabled:
				continue
			if bs != null:
				_boxes.append((_gx(cs as Node3D) * AABB(-bs.size * 0.5, bs.size)).grow(0.03))
				any = true
			elif shp != null:
				var r: float = 0.3
				_boxes.append(AABB(_gx(cs as Node3D).origin - Vector3(r, 0.0, r), Vector3(r * 2.0, 1.0, r * 2.0)))
				any = true
		if not any:  # no collider: keep its footprint
			_boxes.append(_gx(p) * AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.0, 0.6)))
		return
	for c: Node in p.get_children():
		if c is Node3D:
			_collect_mapbuilt(c as Node3D)


func _collect_node(n: Node) -> void:
	if n is NavigationLink3D:
		var link: NavigationLink3D = n
		var xf: Transform3D = _gx(link)
		_markers.append(xf * link.start_position)
		_markers.append(xf * link.end_position)
		return
	if not (n is Node3D) or not ("visual_scene" in n):
		if n is CollisionObject3D and n.get_parent() != null and not ("visual_scene" in n.get_parent()):
			for cs: Node in n.find_children("*", "CollisionShape3D", false, false):
				var bs: BoxShape3D = (cs as CollisionShape3D).shape as BoxShape3D
				if bs != null:
					_boxes.append((_gx(cs as Node3D) * AABB(-bs.size * 0.5, bs.size)).grow(0.05))
		return
	var pf: Node3D = n
	var path: String = (pf.get_script() as Script).resource_path if pf.get_script() != null else ""
	var up: Node3D = pf.get_node_or_null("UsePoint") as Node3D
	if up != null:
		_markers.append(_gx(up).origin)
	var xf2: Transform3D = _gx(pf)
	if path.contains("/door/"):
		var yaw: float = rad_to_deg(xf2.basis.get_euler().y)
		var wd: float = float(pf.get(&"width_m")) if "width_m" in pf else 0.0
		_doors.append([xf2.origin, yaw, wd if wd > 0.0 else 0.9])  # width_m 0: the kit single leaf
		return
	if path.contains("/window/"):
		return
	if path.contains("/escape_zone/"):
		var zs: Vector3 = pf.get(&"zone_size_m")
		_boxes.append(xf2 * AABB(Vector3(-zs.x * 0.5, 0.0, -zs.z * 0.5), Vector3(zs.x, 2.0, zs.z)))
		return
	var box: AABB = AABB()
	var first: bool = true
	for c: Node in pf.find_children("*", "CollisionShape3D", true, false):
		var cs2: CollisionShape3D = c
		if not (cs2.shape is BoxShape3D):
			continue
		var sz: Vector3 = (cs2.shape as BoxShape3D).size
		var b: AABB = _gx(cs2) * AABB(-sz * 0.5, sz)
		box = b if first else box.merge(b)
		first = false
	var vs: PackedScene = pf.get(&"visual_scene") as PackedScene
	if vs != null:
		var asset: String = vs.resource_path.get_file().get_basename()
		if _cat.has(asset):
			var vb: AABB = xf2 * aabb(asset)
			box = vb if first else box.merge(vb)
			first = false
	if first:
		box = AABB(xf2.origin - Vector3(0.15, 0.0, 0.15), Vector3(0.3, 0.3, 0.3))
	_boxes.append(box.grow(0.05))


func _gx(n: Node3D) -> Transform3D:
	return _b.call(&"global_xform", n)


## Soft fill per interior room with a kit or a stair (level_standards §3.7: meta fill, energy <= 0.3, no shadows, <= 2
## per room): the kit fixtures are downward spots, so this lifts the ceilings and upper walls. Long rooms get two.
func fill_lights(parent: Node3D) -> void:
	for r: Array in L.ROOMS:
		var rid: String = String(r[0])
		if String(r[1]) == "exterior" or D.NO_FILL.has(rid):
			continue
		var b: Array = (r[4] as Array)[0]
		for bb: Variant in r[4]:
			var a: Array = bb
			if (float(a[3]) - float(a[0])) * (float(a[5]) - float(a[2])) > (float(b[3]) - float(b[0])) * (float(b[5]) - float(b[2])):
				b = a
		var lo: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
		var hi: Vector3 = Vector3(float(b[3]), float(b[4]), float(b[5]))
		var size: Vector3 = hi - lo
		var long_x: bool = size.x >= size.z
		var length: float = maxf(size.x, size.z)
		var spots: Array[float] = [0.5]
		if length >= 2.5 * minf(size.x, size.z) or length > 14.0:
			spots = [0.25, 0.75]
		var stair: bool = String(r[1]) == "stair"
		if stair and size.y > 5.0:
			spots = [0.5, 0.5]  # one per storey (ground, mezzanine)
		var warm: bool = rid in D.WARM_ROOMS
		var i: int = 0
		for fr: float in spots:
			var p: Vector3 = Vector3(lerpf(lo.x, hi.x, fr if long_x else 0.5), hi.y - minf(0.6, size.y * 0.2),
				lerpf(lo.z, hi.z, 0.5 if long_x else fr))
			if stair:
				p.y = lo.y + 2.4 + L.MEZZ * float(i)
			var light: OmniLight3D = OmniLight3D.new()
			light.name = "Fill%s_%d" % [rid, i]
			light.position = p
			light.light_color = Color(1.0, 0.88, 0.74) if warm else Color(0.9, 0.95, 1.0)
			light.light_energy = 0.28
			light.omni_range = clampf(length / float(spots.size()) * 0.8 + size.y * 0.5, 3.5, 12.0)
			light.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
			light.shadow_enabled = false
			light.set_meta(&"fill", true)
			parent.add_child(light)
			light.owner = _root
			i += 1
