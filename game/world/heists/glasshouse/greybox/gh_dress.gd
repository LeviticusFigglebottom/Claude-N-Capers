## Glasshouse G2 dressing (C1-08, ENV C): prop catalog access and the KitPlacer pass.
## Every room with a RoomVolume.dressing_kit is dressed by its kit (world/kits): the layout's
## ANCHORS go in first, every gameplay prefab, marker, door swing, window and walkway is a keep-out.
## Placed floor props get a box collider (catalog AABB) and a navmesh obstruction, except the NPC
## seats (prop_chair_task, D-063), which the seated NPC owns; fixtures keep the kit's lights, a few
## chosen ones cast shadows (<= 8 per view).
extends RefCounted

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
const L: GDScript = preload("res://world/heists/glasshouse/greybox/glasshouse_layout.gd")
const SEATS: GDScript = preload("res://world/heists/shared/npc_seat_spawns.gd")  # D-130 seated spawns
const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const KITS_DIR: String = "res://world/kits/"
## Half size of the keep-out kept around every floor marker (spawn, patrol, use point...).
const MARKER_HALF: float = 0.35
## Building outline (exterior wall lines): RoomVolume sides on it are 0.2 m from the wall face.
const OUTLINE_X: Array[float] = [0.0, 18.0]
const OUTLINE_Z: Array[float] = [0.0, 12.0]
## Neon: lit facade only (shadowed so nothing reaches the salon / stock room through the walls).
const NEON_RANGE: float = 4.5
const NEON_ENERGY: float = 1.6
## Exit signs go above the frame head (catalog z 2.32 puts the sign's bottom inside the 2.27 m frame).
const EXIT_SIGN_Z: float = 2.36
## Seats an NPC sits in (no collider / obstruction: the spawn marker stays on the navmesh; as nd_dress).
const NPC_SEATS: Array[String] = ["prop_chair_task"]

## Placement summary per kit room (printed by the builder): "id: n props, missing, warnings".
var report: PackedStringArray = []

var _b: Object
var _root: Node3D
var _cat: Dictionary = {}
var _scenes: Dictionary = {}
var _markers: Array[Vector3] = []
var _boxes: Array[AABB] = []
## Kit room id -> its instanced nodes (for the shadow pick).
var _room_nodes: Dictionary = {}


func setup(builder: Object, root: Node3D) -> void:
	_b = builder
	_root = root
	var f: FileAccess = FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		report.append("ERROR: cannot read %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_cat = parsed


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
		if String(r2[2]) == "" or id.begins_with("X"):
			continue
		var res: Array = _interior_room(r2)
		_dress_room(res[0], res[1], id, String(r2[2]), props_root)
	for e: Array in L.KIT_ROOMS_EXT:
		var res2: Array = _exterior_room(e)
		_dress_room(res2[0], res2[1], String(e[0]), String(kits[String(e[1])]), props_root)
	var ext: Node3D = _folder(props_root, "Direct")
	for d: Array in L.DIRECT_PROPS:
		var xf: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(d[3]))), d[2])
		var n: Node3D = scene(String(d[1])).instantiate() as Node3D
		n.name = String(d[0])
		n.transform = xf
		ext.add_child(n)
		n.owner = _root
		_finish_node(n, String(d[1]), "row", "", xf)
	_shadow_fixtures()
	for line: String in SEATS.snap(_root):  # D-130: seated spawns onto their chairs' Seats (no furniture moves)
		report.append("seat " + line)


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
	for a: Array in L.ANCHORS:
		if String(a[0]) != id:
			continue
		var asset: String = String(a[2])
		if not _cat.has(asset):
			report.append("ERROR %s: anchor asset %s not in catalog" % [id, asset])
			continue
		room.add_anchor(_anchor_xform(asset, a[3], float(a[4])), StringName(asset))
		anchor_rows.append(a)
	var seed: int = int(L.KIT_SEEDS.get(id, 4000))
	var res: Dictionary = KitPlacer.place(room, kit, seed, true)
	var parent: Node3D = _folder(props_root, id)
	var nodes: Array[Node3D] = KitPlacer.instantiate(res, parent, _root)
	var placements: Array = res["placements"]
	for i: int in range(nodes.size()):
		var p: Dictionary = placements[i]
		_finish_node(nodes[i], String(p["asset"]), String(p["mode"]), String(p["mount"]), p["xform"])
		if i < anchor_rows.size():
			var metas: Dictionary = (anchor_rows[i] as Array)[5]
			for k: Variant in metas:
				if String(k) == "faces_anchor":
					var j: int = _anchor_index(anchor_rows, String(metas[k]))
					if j >= 0:
						nodes[i].set_meta(&"faces", NodePath("../" + String(nodes[j].name)))
				elif String(k) == "faces_node":
					nodes[i].set_meta(&"faces", NodePath("../../../" + String(metas[k])))
				else:
					nodes[i].set_meta(StringName(String(k)), metas[k])
	_room_nodes[id] = nodes
	_link_monitors(nodes, id)
	var tweaks: Dictionary = L.LIGHT_TWEAKS.get(id, {})
	for n: Node3D in nodes:
		var kind: String = String(n.get_meta(&"kind", ""))
		var lt: Light3D = n.get_node_or_null("Light") as Light3D
		if not tweaks.has(kind) or lt == null:
			continue
		_root.set_editable_instance(n, true)
		var props: Dictionary = tweaks[kind]
		for k: Variant in props:
			lt.set(StringName(String(k)), props[k])
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


## Collider + navmesh obstruction for floor props, editable overrides for the neon.
func _finish_node(n: Node3D, asset: String, mode: String, mount: String, xf: Transform3D) -> void:
	var kind: String = String((_cat[asset] as Dictionary).get("kind", ""))
	if kind == "neon_sign":
		_root.set_editable_instance(n, true)
		var lt: OmniLight3D = n.get_node_or_null("Light") as OmniLight3D
		if lt != null:
			lt.shadow_enabled = true
			lt.omni_range = NEON_RANGE
			lt.light_energy = NEON_ENERGY
	if kind == "exit_sign" and mode == "above_door":
		n.position.y += maxf(0.0, EXIT_SIGN_Z - float((_cat[asset] as Dictionary).get("z", EXIT_SIGN_Z)))
	if mount != "" or mode == "on" or mode == "ceiling" or kind == "awning" or asset in NPC_SEATS:
		return
	var bb: AABB = aabb(asset)
	var top: float = float((_cat[asset] as Dictionary).get("top", 0.0))
	if top > 0.0 and top < bb.end.y:
		# Work surfaces with an upstand (packing bench, kitchen counter, workbench): the collider stops
		# at the work top so the items on it rest on it.
		bb.size.y = top - bb.position.y
	if kind == "street_lamp":
		bb = AABB(Vector3(-0.1, 0.0, -0.1), Vector3(0.2, bb.size.y, 0.2))
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	n.add_child(body)
	body.owner = _root
	SurfaceTags.tag(body, StringName(String((_cat[asset] as Dictionary).get("surface", ""))))  # PO-8
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
	_b.call(&"_obstruct", xf, bb)


func _shadow_fixtures() -> void:
	for s: Array in L.SHADOW_FIXTURES:
		var nodes: Array = _room_nodes.get(String(s[0]), [])
		var target: Vector3 = s[1]
		var best: Node3D = null
		var best_d: float = INF
		for v: Variant in nodes:
			var n: Node3D = v as Node3D
			if String(n.get_meta(&"kind", "")) != "light_fixture" or n.get_node_or_null("Light") == null:
				continue
			var d: float = n.position.distance_to(target)
			if d < best_d:
				best_d = d
				best = n
		if best == null:
			report.append("WARN %s: no fixture to cast shadows" % s[0])
			continue
		_root.set_editable_instance(best, true)
		(best.get_node("Light") as Light3D).shadow_enabled = true


# --- Rooms --------------------------------------------------------------------------------------

## [KitRoom, world AABB of the clear interior] for an interior RoomVolume row.
func _interior_room(r: Array) -> Array:
	var boxes: Array = r[4]
	var u: AABB = _box(boxes[0])
	for i: int in range(1, boxes.size()):
		u = u.merge(_box(boxes[i]))
	var lo: Vector3 = u.position
	var hi: Vector3 = u.end
	lo.x += _inset_x(lo.x)
	hi.x -= _inset_x(hi.x)
	lo.z += _inset_z(lo.z)
	hi.z -= _inset_z(hi.z)
	var clear: AABB = AABB(lo, hi - lo)
	var room: KitRoom = KitRoom.from_aabb(clear, StringName(String(r[0])))
	for d: Array in L.DOORS:
		_room_door(room, boxes, u, d)
	for w: Array in L.WINDOWS:
		_room_window(room, u, String(w[1]), w[2], float(w[3]))
	# The break-room door-window is walked through: dress it like a door (1.2 m clear in front).
	var bw: Dictionary = L.BREAKROOM_WINDOW
	var bpos: Vector3 = bw["pos"]
	if absf(bpos.y - u.position.y) < 0.5 and _on_edge(u, bpos, absf(sin(deg_to_rad(float(bw["yaw"])))) < 0.5):
		var bsz: Vector2 = _window_size(String(bw["kit"]))
		room.add_door(bpos, bsz.x, 1.2, bsz.y, 0.06)
	_room_gaps(room, u)
	return [room, clear]


## Interior sides with no wall over a stretch (the stair void off the upper corridor) are full-height
## openings, so nothing is hung on or backed against thin air (PO-9: U4 picture over the stair).
func _room_gaps(room: KitRoom, u: AABB) -> void:
	for axis: String in ["x", "z"]:
		var lo: float = u.position.x if axis == "x" else u.position.z
		var hi: float = u.end.x if axis == "x" else u.end.z
		for fixed: float in ([u.position.z, u.end.z] if axis == "x" else [u.position.x, u.end.x]):
			if (OUTLINE_Z if axis == "x" else OUTLINE_X).any(func(o: float) -> bool: return absf(o - fixed) < 0.01):
				continue
			var segs: Array[Vector2] = []
			for w: Array in L.INT_WALLS:
				if String(w[1]) == axis and absf(float(w[2]) - fixed) < 0.06 \
						and float(w[5]) <= u.position.y + 0.1 and float(w[6]) >= u.position.y + 2.0:
					segs.append(Vector2(float(w[3]), float(w[4])))
			segs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var cur: float = lo
			for s: Vector2 in segs + [Vector2(hi, hi)]:
				if s.x - cur >= 0.3:
					var c: float = (cur + minf(s.x, hi)) * 0.5
					var pos: Vector3 = Vector3(c, u.position.y, fixed) if axis == "x" else Vector3(fixed, u.position.y, c)
					room.add_window(pos, minf(s.x, hi) - cur, 0.0, u.size.y)
				cur = maxf(cur, s.y)


func _inset_x(x: float) -> float:
	for o: float in OUTLINE_X:
		if absf(x - o) < 0.01:
			return 0.2
	return 0.1


func _inset_z(z: float) -> float:
	for o: float in OUTLINE_Z:
		if absf(z - o) < 0.01:
			return 0.2
	return 0.1


func _box(b: Array) -> AABB:
	var lo: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
	return AABB(lo, Vector3(float(b[3]), float(b[4]), float(b[5])) - lo)


## Door on the room outline -> add_door (swing reserved inside); door on an inner sub-box edge (the
## L-shaped G1 around G7) -> a keep-out in front of it.
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
		room.add_door(pos, width, -1.0 if in_room else 0.0)
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
	if asset.contains("double"):
		return 1.8
	if asset.contains("service"):
		return 1.1
	return 0.9


func _window_size(piece: String) -> Vector2:
	var w: float = 3.0 if piece.contains("w300") else (1.2 if piece.contains("w120") else 1.0)
	var h: float = 2.4 if piece.contains("h240") else (0.6 if piece.contains("h60") else (2.1 if piece.contains("h210") else 1.2))
	return Vector2(w, h)


func _room_window(room: KitRoom, u: AABB, piece: String, pos: Vector3, yaw: float) -> void:
	var along_x: bool = absf(sin(deg_to_rad(yaw))) < 0.5
	var sill: float = pos.y - u.position.y
	if sill < -0.1 or sill > u.size.y or not _on_edge(u, pos, along_x):
		return
	var sz: Vector2 = _window_size(piece)
	room.add_window(pos, sz.x, sill, minf(sill + sz.y, u.size.y))


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
	var wins: Array = L.WINDOWS.duplicate()
	for w: Array in wins:
		var wp: Vector3 = w[2]
		var lw: Vector3 = room.to_local(wp)
		if int(room.nearest_wall(lw).x) != 0 or absf(lw.z + room.size.z * 0.5) > 0.5 or wp.y - floor_y > h:
			continue
		if absf(lw.x) > room.size.x * 0.5:
			continue
		var sz2: Vector2 = _window_size(String(w[1]))
		room.add_window(wp, sz2.x, wp.y - floor_y, minf(wp.y - floor_y + sz2.y, h))
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
	for k: Variant in L.KEEP_OUT.get(id, []):
		room.add_keep_out(_box(k))


## Everything the kits must leave alone: gameplay prefabs (collision + visual), their use points,
## spawns / patrol / tactical / preplan markers, nav-link ends, railings, the
## fire-escape landing, the chandelier display and the remaining greybox props.
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
	_boxes.append(_box(L.LANDING))
	for p: Array in L.PROPS:
		var s: Vector3 = p[2]
		var base: Vector3 = p[1]
		_boxes.append(AABB(base - Vector3(s.x * 0.5, 0.0, s.z * 0.5), s).grow(0.05))
	# Review cameras: keep their standpoint (and 0.6 m around it) clear of dressing.
	for cam: Array in L.REVIEW_CAMERAS:
		if String(cam[0]).begins_with("TopDown"):
			continue
		var cpos: Vector3 = cam[1]
		_boxes.append(AABB(cpos - Vector3(0.6, 1.75, 0.6), Vector3(1.2, 2.1, 1.2)))
	var ch: Dictionary = L.CHANDELIER
	var cp: Vector3 = ch["pos"]
	var cr: float = float(ch["radius"]) + 0.1
	_boxes.append(AABB(cp - Vector3(cr, 0.0, cr), Vector3(cr * 2.0, float(ch["height"]), cr * 2.0)))


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


## Landmark 1: the circular chandelier display (2.4 m round glass case): its catalog visual on collision drums; the
## ring chandelier above is a dressing anchor (layout ANCHORS). D-142: the walnut cabinet (0..glass_y) blocks stealth
## vision; the clear glass case above it is its own `see_through` body (prop_display_case_round: cabinet top 0.75).
func chandelier_display(parent: Node3D) -> void:
	var ch: Dictionary = L.CHANDELIER
	var pos: Vector3 = ch["pos"]
	var r: float = float(ch["radius"])
	var h: float = float(ch["height"])
	var gy: float = float(ch["glass_y"])
	var body: StaticBody3D = _drum(parent, "ChandelierDisplay", r, 0.0, gy)
	body.position = pos
	body.set_meta(&"kind", "display_plinth")
	var glass: StaticBody3D = _drum(body, "GlassCase", r, gy, h)
	glass.add_to_group(&"see_through", true)
	SurfaceTags.tag(glass, &"glass")
	var ps: PackedScene = scene("prop_display_case_round")
	if ps != null:
		var vis: Node3D = ps.instantiate() as Node3D
		vis.name = "Display"
		body.add_child(vis)
		vis.owner = _root
	_b.call(&"_obstruct_circle", pos, r, h)


## A static cylinder collider (radius r, from y0 to y1 in its parent's space), owned by the map root.
func _drum(parent: Node3D, nm: String, r: float, y0: float, y1: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.owner = _root
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = r
	cyl.height = y1 - y0
	col.shape = cyl
	col.position = Vector3(0.0, (y0 + y1) * 0.5, 0.0)
	body.add_child(col)
	col.owner = _root
	return body


func _gx(n: Node3D) -> Transform3D:
	return _b.call(&"_global_xform", n)


## Soft fill per dressed interior room (level_standards §3.7: meta fill, energy <= 0.3, no
## shadows, <= 2 per room): the kit fixtures are downward spots, so this lifts the ceilings and
## upper walls. Long rooms get two, at a quarter and three quarters of their length.
func fill_lights(parent: Node3D) -> void:
	for r: Array in L.ROOMS:
		var id: String = String(r[0])
		if String(r[2]) == "" or id.begins_with("X"):
			continue
		var boxes: Array = r[4]
		var b: Array = boxes[0]
		var lo: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
		var hi: Vector3 = Vector3(float(b[3]), float(b[4]), float(b[5]))
		for k: int in range(1, boxes.size()):
			var b2: Array = boxes[k]
			lo = lo.min(Vector3(float(b2[0]), float(b2[1]), float(b2[2])))
			hi = hi.max(Vector3(float(b2[3]), float(b2[4]), float(b2[5])))
		var size: Vector3 = hi - lo
		var long_x: bool = size.x >= size.z
		var length: float = maxf(size.x, size.z)
		var spots: Array[float] = [0.5]
		if length >= 2.5 * minf(size.x, size.z):
			spots = [0.25, 0.75]
		var i: int = 0
		for f: float in spots:
			var p: Vector3 = Vector3(lerpf(lo.x, hi.x, f if long_x else 0.5), hi.y - 0.6, lerpf(lo.z, hi.z, 0.5 if long_x else f))
			var light: OmniLight3D = OmniLight3D.new()
			light.name = "Fill%s_%d" % [id, i]
			light.position = p
			light.light_color = Color(1.0, 0.93, 0.84)
			light.light_energy = 0.25
			light.omni_range = clampf(length / float(spots.size()) * 0.75 + 1.5, 3.0, 8.0)
			light.layers |= VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
			light.shadow_enabled = false
			light.set_meta(&"fill", true)
			parent.add_child(light)
			light.owner = _root
			i += 1


# --- Generated visuals --------------------------------------------------------------------------

## Visual scenes (library materials, world-scaled UVs) for gameplay items without catalog art, at
## `paths` = [keycard, cash stack, jewelry stack, empty]. Pivot bottom-centre, front -Z. Returns
## an error message or "".
static func make_visuals(art: RefCounted, res: GDScript, paths: Array) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(paths[0]).get_base_dir()))
	art.add_tint("gh_card_white", "plastic_matte", Color(0.93, 0.93, 0.95))
	art.add_tint("gh_cash_green", "plastic_matte", Color(0.55, 0.68, 0.5))
	var specs: Array = [
		[paths[0], "GhKeycard", [[Vector3(0.086, 0.004, 0.054), Vector3(0.0, 0.002, 0.0), "gh_card_white"],
			[Vector3(0.078, 0.0025, 0.012), Vector3(0.0, 0.00525, -0.014), "rubber_black"]]],
		[paths[1], "GhCashStack", [[Vector3(0.16, 0.05, 0.075), Vector3(0.0, 0.025, 0.0), "gh_cash_green"],
			[Vector3(0.03, 0.056, 0.081), Vector3(0.0, 0.028, 0.0), "plaster_painted"]]],
		[paths[2], "GhJewelryStack", [[Vector3(0.36, 0.05, 0.24), Vector3(0.0, 0.025, 0.0), "leather_dark"],
			[Vector3(0.34, 0.05, 0.22), Vector3(0.0, 0.075, 0.0), "leather_dark"],
			[Vector3(0.32, 0.05, 0.2), Vector3(0.0, 0.125, 0.0), "leather_dark"],
			[Vector3(0.12, 0.08, 0.12), Vector3(0.06, 0.19, 0.0), "wood_veneer_walnut"]]],
		[paths[3], "GhEmpty", []],
	]
	for v: Array in specs:
		var path: String = String(v[0])
		var root: Node3D = Node3D.new()
		root.name = String(v[1])
		if not (v[2] as Array).is_empty():
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = art.local_box_mesh(v[2])
			root.add_child(mi)
			mi.owner = root
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
