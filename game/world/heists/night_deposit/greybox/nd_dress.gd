## Night Deposit G2 dressing (C2, ENV C): prop catalog access and the KitPlacer pass (same approach
## as the Glasshouse, gh_dress.gd). Every room with a RoomVolume.dressing_kit is dressed by its kit
## (world/kits): the dressing data's ANCHORS go in first; every gameplay prefab, marker, door swing,
## window, railing and review-camera standpoint is a keep-out. Placed floor props get a box collider
## (catalog AABB) and a navmesh obstruction, except the NPC seats (prop_chair_task, D-063), which the
## seated NPC owns. Fixtures keep the kit's lights; a few chosen ones cast shadows (<= 8 per view).
extends RefCounted

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
const L: GDScript = preload("res://world/heists/night_deposit/greybox/night_deposit_layout.gd")
const D: GDScript = preload("res://world/heists/night_deposit/greybox/night_deposit_dressing.gd")
const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const KITS_DIR: String = "res://world/kits/"
## Half size of the keep-out kept around every floor marker (spawn, patrol, use point...).
const MARKER_HALF: float = 0.35
## Building outline (exterior wall lines): RoomVolume sides on it are 0.2 m from the wall face.
const OUTLINE_X: Array[float] = [0.0, 26.0]
const OUTLINE_Z: Array[float] = [0.0, 20.0]
## Exit signs go above the frame head.
const EXIT_SIGN_Z: float = 2.36
## Seats an NPC sits in (no collider / obstruction: the spawn marker stays on the navmesh).
const NPC_SEATS: Array[String] = ["prop_chair_task"]

## Placement summary per kit room (printed by the builder): "id: n props, missing, warnings".
var report: PackedStringArray = []

var _b: Object
var _root: Node3D
var _cat: Dictionary = {}
var _scenes: Dictionary = {}
var _markers: Array[Vector3] = []
var _boxes: Array[AABB] = []
## Kit room id -> its instanced nodes (shadow pick, light tweaks).
var _room_nodes: Dictionary = {}


func setup(builder: Object, root: Node3D) -> void:
	_b = builder
	_root = root
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		_cat = parsed
	else:
		report.append("ERROR: cannot read %s" % CATALOG_PATH)


func has_asset(asset: String) -> bool:
	return _cat.has(asset)


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
	var kits: Dictionary = {}
	for r: Array in L.ROOMS:
		kits[String(r[0])] = String(r[2])
	for r2: Array in L.ROOMS:
		var id: String = String(r2[0])
		if String(r2[2]) == "" or String(r2[1]) == "exterior":
			continue
		var res: Array = _interior_room(r2)
		_dress_room(res[0], res[1], id, String(r2[2]), props_root)
	for e: Array in D.KIT_ROOMS_EXT:
		var res2: Array = _exterior_room(e)
		_dress_room(res2[0], res2[1], String(e[0]), String(kits[String(e[1])]), props_root)
	var direct: Node3D = _folder(props_root, "Direct")
	for d: Array in D.DIRECT_PROPS:
		var xf: Transform3D = _anchor_xform(String(d[1]), d[2], float(d[3]))
		var n: Node3D = scene(String(d[1])).instantiate() as Node3D
		n.name = String(d[0])
		n.transform = xf
		var metas: Dictionary = d[4]
		for k: Variant in metas:
			n.set_meta(StringName(String(k)), metas[k])
		direct.add_child(n)
		n.owner = _root
	_shadow_fixtures()
	_light_pendants()


## Site dressing (boats, containers, the vista van) under Geometry: visuals over collision blocks.
func site_dressing(parent: Node3D) -> void:
	for s: Array in D.SITE_DRESSING:
		var n: Node3D = scene(String(s[1])).instantiate() as Node3D
		n.name = String(s[0])
		n.position = s[2]
		n.basis = Basis(Vector3.UP, deg_to_rad(float(s[3])))
		parent.add_child(n)
		n.owner = _root


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
	var anchor_rows: Array = []
	for a: Array in D.ANCHORS:
		if String(a[0]) != id:
			continue
		var asset: String = String(a[2])
		if not _cat.has(asset):
			report.append("ERROR %s: anchor asset %s not in catalog" % [id, asset])
			continue
		room.add_anchor(_anchor_xform(asset, a[3], float(a[4])), StringName(asset))
		anchor_rows.append(a)
	var seed: int = int(D.KIT_SEEDS.get(id, 5000))
	var res: Dictionary = KitPlacer.place(room, kit, seed, true)
	var parent: Node3D = _folder(props_root, id)
	var nodes: Array[Node3D] = KitPlacer.instantiate(res, parent, _root)
	var placements: Array = res["placements"]
	for i: int in range(nodes.size()):
		var p: Dictionary = placements[i]
		if i < anchor_rows.size():
			nodes[i].name = String((anchor_rows[i] as Array)[1])
		_finish_node(nodes[i], String(p["asset"]), String(p["mode"]), String(p["mount"]), p["xform"])
	# Anchors were renamed above: re-point KitPlacer's `faces` metas at the final node names.
	for i3: int in range(nodes.size()):
		var f: int = int((placements[i3] as Dictionary).get("faces", -1))
		if f >= 0 and f < nodes.size():
			nodes[i3].set_meta(&"faces", NodePath("../" + String(nodes[f].name)))
	for i2: int in range(mini(anchor_rows.size(), nodes.size())):
		var metas: Dictionary = (anchor_rows[i2] as Array)[5]
		for k: Variant in metas:
			if String(k) == "faces_anchor":
				var j: int = _anchor_index(anchor_rows, String(metas[k]))
				if j >= 0:
					nodes[i2].set_meta(&"faces", NodePath("../" + String(nodes[j].name)))
			elif String(k) == "faces_node":
				nodes[i2].set_meta(&"faces", NodePath("../../../" + String(metas[k])))
			else:
				nodes[i2].set_meta(StringName(String(k)), metas[k])
	_room_nodes[id] = nodes
	_link_monitors(nodes, id)
	var tweaks: Dictionary = D.LIGHT_TWEAKS.get(id, {})
	for n: Node3D in nodes:
		var kind: String = String(n.get_meta(&"kind", ""))
		var lt: Light3D = n.get_node_or_null("Light") as Light3D
		if not tweaks.has(kind) or lt == null:
			continue
		_root.set_editable_instance(n, true)
		var props: Dictionary = tweaks[kind]
		for k2: Variant in props:
			if String(k2) in lt:
				lt.set(StringName(String(k2)), props[k2])
	var missing: PackedStringArray = res["missing"]
	var warnings: PackedStringArray = res["warnings"]
	report.append("%s (%s, seed %d): %d props%s%s" % [id, kit_id, seed, nodes.size(),
		"" if missing.is_empty() else ", MISSING " + ",".join(missing),
		"" if warnings.is_empty() else ", warnings: " + "; ".join(warnings)])


## Monitors face the chair in front of them (orientation check): the nearest chair within 30 deg
## of the screen's front.
func _link_monitors(nodes: Array[Node3D], id: String) -> void:
	for m: Node3D in nodes:
		if String(m.get_meta(&"kind", "")) != "monitor" or m.has_meta(&"faces"):
			continue
		var front: Vector3 = -m.transform.basis.z
		front.y = 0.0
		var best: Node3D = null
		var best_d: float = INF
		for c: Node3D in nodes:
			if String(c.get_meta(&"kind", "")) != "chair":
				continue
			var to: Vector3 = c.position - m.position
			to.y = 0.0
			if to.length() < 0.05 or front.normalized().dot(to.normalized()) < cos(deg_to_rad(30.0)):
				continue
			if to.length() < best_d:
				best_d = to.length()
				best = c
		if best != null:
			m.set_meta(&"faces", NodePath("../" + String(best.name)))
		else:
			report.append("WARN %s: monitor %s has no chair in front" % [id, m.name])


func _anchor_index(rows: Array, anchor_name: String) -> int:
	for i: int in range(rows.size()):
		if String((rows[i] as Array)[1]) == anchor_name:
			return i
	return -1


## Anchor pivot: floor props as given; wall mounts move to the wall face + 2 mm with the item centred
## on `pos`; ceiling mounts hang from `pos`.
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


## Collider + navmesh obstruction for floor props (not the NPC seats).
func _finish_node(n: Node3D, asset: String, mode: String, mount: String, xf: Transform3D) -> void:
	var kind: String = String((_cat[asset] as Dictionary).get("kind", ""))
	if kind == "exit_sign" and mode == "above_door":
		n.position.y += maxf(0.0, EXIT_SIGN_Z - float((_cat[asset] as Dictionary).get("z", EXIT_SIGN_Z)))
	if mount != "" or mode == "on" or mode == "ceiling" or asset in NPC_SEATS:
		return
	var bb: AABB = aabb(asset)
	var top: float = float((_cat[asset] as Dictionary).get("top", 0.0))
	if top > 0.0 and top < bb.end.y:
		# Work surfaces with an upstand: the collider stops at the work top so items rest on it.
		bb.size.y = top - bb.position.y
	if kind == "street_lamp":
		bb = AABB(Vector3(-0.12, 0.0, -0.12), Vector3(0.24, bb.size.y, 0.24))
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	n.add_child(body)
	body.owner = _root
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
			if not (String(n.get_meta(&"kind", "")) in ["light_fixture", "street_lamp"]) or n.get_node_or_null("Light") == null:
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


## The hall's night mode: the lit pendants keep their light, the rest are the unlit variant already.
func _light_pendants() -> void:
	for v: Variant in _room_nodes.get("G9", []):
		var n: Node3D = v as Node3D
		if String(n.name) in D.LIT_PENDANTS and n.get_node_or_null("Light") == null:
			report.append("WARN G9: lit pendant %s has no light" % n.name)


# --- Rooms --------------------------------------------------------------------------------------

## [KitRoom, world AABB of the clear interior] for an interior RoomVolume row.
func _interior_room(r: Array) -> Array:
	var id: String = String(r[0])
	var boxes: Array = r[4]
	var u: AABB = _box(boxes[0])
	for i: int in range(1, boxes.size()):
		u = u.merge(_box(boxes[i]))
	var lo: Vector3 = u.position
	var hi: Vector3 = u.end
	if D.CLEAR.has(id):
		var c: Array = D.CLEAR[id]
		lo = Vector3(float(c[0]), lo.y, float(c[1]))
		hi = Vector3(float(c[2]), hi.y, float(c[3]))
	else:
		lo.x += _inset(lo.x, OUTLINE_X)
		hi.x -= _inset(hi.x, OUTLINE_X)
		lo.z += _inset(lo.z, OUTLINE_Z)
		hi.z -= _inset(hi.z, OUTLINE_Z)
	var clear: AABB = AABB(lo, hi - lo)
	var room: KitRoom = KitRoom.from_aabb(clear, StringName(id))
	for d: Array in L.DOORS:
		_room_door(room, boxes, u, d)
	for w: Array in L.WINDOWS:
		_room_window(room, u, 3.0, 2.4, w[2], float(w[3]))
	for g: Array in L.GLAZING:
		_glazing_window(room, u, g)
	return [room, clear]


static func _inset(v: float, outline: Array[float]) -> float:
	for o: float in outline:
		if absf(v - o) < 0.01:
			return 0.2
	return 0.1


func _box(b: Array) -> AABB:
	var lo: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
	return AABB(lo, Vector3(float(b[3]), float(b[4]), float(b[5])) - lo)


## Door on the room outline -> add_door (swing reserved inside); door on an inner sub-box edge (the
## L-shaped B2) -> a keep-out in front of it.
func _room_door(room: KitRoom, boxes: Array, u: AABB, d: Array) -> void:
	var pos: Vector3 = d[2]
	var yaw: float = float(d[3])
	if absf(pos.y - u.position.y) > 0.5:
		return
	var width: float = _door_width(String(d[1]))
	var along_x: bool = absf(sin(deg_to_rad(yaw))) < 0.5
	if _on_edge(u, pos, along_x):
		var back: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.BACK
		var into: bool = back.dot(u.get_center() - pos) > 0.0
		var swing: String = String(d[5])
		var in_room: bool = swing == "DOUBLE" or (swing == "INWARD" and into) or (swing == "OUTWARD" and not into)
		room.add_door(pos, width, -1.0 if in_room else 0.0, 2.3 if width > 2.0 else 2.2)
		return
	for b: Variant in boxes:
		var sb: AABB = _box(b)
		if _on_edge(sb, pos, along_x):
			var half: Vector3 = Vector3(width * 0.5 + 0.2, 0.0, 0.6) if along_x else Vector3(0.6, 0.0, width * 0.5 + 0.2)
			room.add_keep_out(AABB(Vector3(pos.x - half.x, pos.y, pos.z - half.z), Vector3(half.x * 2.0, 2.3, half.z * 2.0)))
			return


func _on_edge(b: AABB, pos: Vector3, along_x: bool) -> bool:
	if along_x:
		return (absf(pos.z - b.position.z) < 0.06 or absf(pos.z - b.end.z) < 0.06) \
			and pos.x > b.position.x and pos.x < b.end.x
	return (absf(pos.x - b.position.x) < 0.06 or absf(pos.x - b.end.x) < 0.06) \
		and pos.z > b.position.z and pos.z < b.end.z


func _door_width(asset: String) -> float:
	if asset.contains("vault"):
		return 2.2
	if asset.contains("double"):
		return 1.8
	if asset.contains("service"):
		return 1.1
	return 0.9


func _room_window(room: KitRoom, u: AABB, width: float, height: float, pos: Vector3, yaw: float) -> void:
	var along_x: bool = absf(sin(deg_to_rad(yaw))) < 0.5
	var sill: float = pos.y - u.position.y
	if sill < -0.1 or sill > u.size.y or not _on_edge(u, pos, along_x):
		return
	room.add_window(pos, width, sill, minf(sill + height, u.size.y))


## Static glazing rows [name, axis, fixed, a0, a1, y0, y1] on the room outline become windows.
func _glazing_window(room: KitRoom, u: AABB, g: Array) -> void:
	var along_x: bool = String(g[1]) == "x"
	var a0: float = float(g[3])
	var a1: float = float(g[4])
	var mid: Vector3 = Vector3((a0 + a1) * 0.5, float(g[5]), float(g[2])) if along_x else Vector3(float(g[2]), float(g[5]), (a0 + a1) * 0.5)
	var sill: float = mid.y - u.position.y
	if sill < -0.1 or sill > u.size.y or not _on_edge(u, mid, along_x):
		return
	room.add_window(mid, a1 - a0, sill, minf(float(g[6]) - u.position.y, u.size.y))


## Exterior kit room: a yawed frame whose wall 0 is the facade; only wall 0 exists.
func _exterior_room(e: Array) -> Array:
	var b: Array = e[2]
	var floor_y: float = float(e[4])
	var yaw: float = deg_to_rad(float(e[3]))
	var sx: float = float(b[3]) - float(b[0])
	var sz: float = float(b[5]) - float(b[2])
	var h: float = float(b[4]) - float(b[1])
	var room: KitRoom = KitRoom.new()
	room.id = StringName(String(e[0]))
	room.xform = Transform3D(Basis(Vector3.UP, yaw), Vector3((float(b[0]) + float(b[3])) * 0.5, floor_y,
		(float(b[2]) + float(b[5])) * 0.5))
	room.size = Vector3(sz, h, sx) if absf(sin(yaw)) > 0.5 else Vector3(sx, h, sz)
	room.walls = [true, false, false, false]
	var world: AABB = AABB(Vector3(float(b[0]), floor_y - 0.5, float(b[2])), Vector3(sx, h + 0.5, sz))
	for d: Array in L.DOORS:
		var pos: Vector3 = d[2]
		if not world.grow(0.5).has_point(pos + Vector3.UP * 0.1):
			continue
		var width: float = _door_width(String(d[1]))
		var wl: Vector2 = room.nearest_wall(room.to_local(pos))
		if int(wl.x) == 0 and absf(room.to_local(pos).z + room.size.z * 0.5) < 0.5:
			room.add_door(pos, width, -1.0 if String(d[5]) == "DOUBLE" else 0.0)
		var hw: float = width * 0.5 + 0.4
		room.add_keep_out(AABB(Vector3(pos.x - maxf(hw, 1.5), pos.y, pos.z - maxf(hw, 1.5)),
			Vector3(maxf(hw, 1.5) * 2.0, 2.4, maxf(hw, 1.5) * 2.0)))
	for w: Array in L.WINDOWS:
		var wp: Vector3 = w[2]
		var lw: Vector3 = room.to_local(wp)
		if int(room.nearest_wall(lw).x) != 0 or absf(lw.z + room.size.z * 0.5) > 0.5 or wp.y - floor_y > h:
			continue
		if absf(lw.x) > room.size.x * 0.5:
			continue
		room.add_window(wp, 3.0, wp.y - floor_y, minf(wp.y - floor_y + 3.5, h))
	for g: Array in L.GLAZING:
		var along_x: bool = String(g[1]) == "x"
		var a0: float = float(g[3])
		var a1: float = float(g[4])
		var gp: Vector3 = Vector3((a0 + a1) * 0.5, float(g[5]), float(g[2])) if along_x else Vector3(float(g[2]), float(g[5]), (a0 + a1) * 0.5)
		var lg: Vector3 = room.to_local(gp)
		if int(room.nearest_wall(lg).x) != 0 or absf(lg.z + room.size.z * 0.5) > 0.5 or absf(lg.x) > room.size.x * 0.5:
			continue
		room.add_window(gp, a1 - a0, gp.y - floor_y, minf(float(g[6]) - floor_y, h))
	return [room, world]


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
		room.add_keep_out(_box(k))


## Everything the kits must leave alone: gameplay prefabs (collision + visual), their use points,
## spawns / patrol / tactical / preplan markers, nav-link ends, railings, the remaining map-built
## props, the review cameras' standpoints and the compass rose.
func _collect() -> void:
	for c: String in ["Gameplay", "Variants", "Navigation"]:
		var top: Node = _root.get_node_or_null(c)
		if top != null:
			for n: Node in top.find_children("*", "", true, false):
				_collect_node(n)
	for c2: String in ["Spawns", "Patrols", "Tactical", "Preplan", "Variants"]:
		var top2: Node = _root.get_node_or_null(c2)
		if top2 == null:
			continue
		for n2: Node in top2.find_children("*", "Marker3D", true, false):
			if String(n2.name) != "UsePoint":
				_markers.append(_gx(n2 as Node3D).origin)
	for r: Array in L.RAILINGS:
		_boxes.append(_box(r[1]).grow(0.05))
	for p: Array in L.PROPS:
		var s: Vector3 = p[2]
		var base: Vector3 = p[1]
		_boxes.append(AABB(base - Vector3(s.x * 0.5, 0.0, s.z * 0.5), s).grow(0.05))
	for cam: Array in L.REVIEW_CAMERAS:
		if String(cam[0]).begins_with("TopDown"):
			continue
		var cpos: Vector3 = cam[1]
		_boxes.append(AABB(cpos - Vector3(0.6, 1.75, 0.6), Vector3(1.2, 2.1, 1.2)))
	# the variant-only map props (srv_ground rack, the armoured car) are covered by KEEP_OUT


func _collect_node(n: Node) -> void:
	if n is NavigationLink3D:
		var link: NavigationLink3D = n
		var xf: Transform3D = _gx(link)
		_markers.append(xf * link.start_position)
		_markers.append(xf * link.end_position)
		return
	if not (n is Node3D) or not ("visual_scene" in n):
		return
	var pf: Node3D = n
	var path: String = (pf.get_script() as Script).resource_path if pf.get_script() != null else ""
	var up: Node3D = pf.get_node_or_null("UsePoint") as Node3D
	if up != null:
		_markers.append(_gx(up).origin)
	if path.contains("/door/") or path.contains("/window/"):
		return
	var xf2: Transform3D = _gx(pf)
	if path.contains("/escape_zone/"):
		var zs: Vector3 = pf.get(&"zone_size_m")
		_boxes.append(xf2 * AABB(Vector3(-zs.x * 0.5, 0.0, -zs.z * 0.5), Vector3(zs.x, 2.0, zs.z)))
		return
	if path.contains("/laser_grid/"):
		var ls: Vector3 = pf.get(&"size_m")
		_boxes.append((xf2 * AABB(Vector3(-ls.x * 0.5, 0.0, -ls.z * 0.5), ls)).grow(0.15))
		return
	var box: AABB = AABB()
	var first: bool = true
	for c: Node in pf.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c
		if not (cs.shape is BoxShape3D):
			continue
		var sz: Vector3 = (cs.shape as BoxShape3D).size
		var b: AABB = _gx(cs) * AABB(-sz * 0.5, sz)
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
	_boxes.append(box.grow(0.03))


func _gx(n: Node3D) -> Transform3D:
	return _b.call(&"global_xform", n)


## Soft fill per dressed interior room (level_standards §3.7: meta fill, energy <= 0.3, no
## shadows, <= 2 per room): the kit fixtures are downward spots, so this lifts the ceilings and
## upper walls. Long rooms get two, at a quarter and three quarters of their length.
func fill_lights(parent: Node3D) -> void:
	for r: Array in L.ROOMS:
		var id: String = String(r[0])
		if String(r[1]) == "exterior" or id == "G2":
			continue
		var boxes: Array = r[4]
		var b: Array = boxes[0]
		var lo: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
		var hi: Vector3 = Vector3(float(b[3]), float(b[4]), float(b[5]))
		var size: Vector3 = hi - lo
		var long_x: bool = size.x >= size.z
		var length: float = maxf(size.x, size.z)
		var spots: Array[float] = [0.5]
		if length >= 2.5 * minf(size.x, size.z):
			spots = [0.25, 0.75]
		var i: int = 0
		var warm: bool = id in ["G9", "G10", "G11", "G12", "G4", "B8"]
		for f: float in spots:
			var p: Vector3 = Vector3(lerpf(lo.x, hi.x, f if long_x else 0.5), hi.y - 0.6, lerpf(lo.z, hi.z, 0.5 if long_x else f))
			var light: OmniLight3D = OmniLight3D.new()
			light.name = "Fill%s_%d" % [id, i]
			light.position = p
			light.light_color = Color(1.0, 0.9, 0.78) if warm else Color(0.93, 0.95, 1.0)
			light.light_energy = 0.25
			light.omni_range = clampf(length / float(spots.size()) * 0.75 + 1.5, 3.0, 9.0)
			light.layers |= VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
			light.shadow_enabled = false
			light.set_meta(&"fill", true)
			parent.add_child(light)
			light.owner = _root
			i += 1


# --- Generated visuals --------------------------------------------------------------------------

## Visual scenes (library materials, metre-scaled UVs) for gameplay prefabs without catalog art,
## keyed by output path: the cash lift car (bag_lift: Car, DoorL, DoorR, Panel), the boat deck
## hatch (secure_zone E2: Body, DoorL, DoorR, DropAnchor), the laser grids (Beam<i>, emitter posts) and
## an empty scene (drill points, hidden small loot). Returns an error message or "".
static func make_visuals(art: RefCounted, res: GDScript, specs: Dictionary) -> String:
	var keys: Array = specs.keys()
	keys.sort()
	for k: Variant in keys:
		var path: String = String(k)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var spec: Dictionary = specs[k]
		var root: Node3D = Node3D.new()
		root.name = String(spec["name"])
		for node_spec: Array in spec.get("nodes", []):
			# [name, parent path ("" = root), position, mesh parts (or [] for an empty anchor), meta fixture]
			var nn: Node3D = MeshInstance3D.new() if not (node_spec[3] as Array).is_empty() else Node3D.new()
			nn.name = String(node_spec[0])
			nn.position = node_spec[2]
			if nn is MeshInstance3D:
				(nn as MeshInstance3D).mesh = art.local_box_mesh(node_spec[3])
			var parent: Node = root if String(node_spec[1]) == "" else root.get_node(String(node_spec[1]))
			parent.add_child(nn)
			nn.owner = root
		var ps: PackedScene = PackedScene.new()
		var err: int = ps.pack(root)
		root.free()
		var old_uid: String = res.read_uid(path)
		if err == OK:
			err = ResourceSaver.save(ps, path)
		if err != OK:
			return "cannot save %s (%d)" % [path, err]
		res.normalize_scene(path, old_uid)
	return ""
