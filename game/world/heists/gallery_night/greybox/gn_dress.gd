## Gallery Night G2 dressing (GN-C2, ENV C): the KitPlacer pass over every RoomVolume with a dressing kit (as Night
## Deposit / Golden Hour: nd_dress.gd, gh_dress.gd). The dressing data's ANCHORS go in first (the gala, the galleries'
## designed pieces); every gameplay prefab, marker, door swing, plan opening, window, stair, railing and review-camera
## standpoint is a keep-out. Placed floor props get a box collider (catalog AABB up to the work top) and a navmesh
## obstruction, except NPC seats (D-063) and the walk-through velvet rope (next_heist §7.9: "or none"). Ceiling
## fixtures carry the kit's lights (LIGHT_TWEAKS per room); a few chosen ones cast shadows (<= 8 per view). Fill
## lights (meta fill) lift each room's ceiling and upper walls. Data: gallery_night_dressing.gd.
extends RefCounted

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
const L: GDScript = preload("res://world/heists/gallery_night/greybox/gallery_night_layout.gd")
const SEATS: GDScript = preload("res://world/heists/shared/npc_seat_spawns.gd")  # D-130 seated spawns
const D: GDScript = preload("res://world/heists/gallery_night/greybox/gallery_night_dressing.gd")
const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")
const AE: GDScript = preload("res://world/heists/gallery_night/greybox/gn_assault.gd")
const GP: GDScript = preload("res://world/heists/gallery_night/greybox/gn_gameplay.gd")
const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const KITS_DIR: String = "res://world/kits/"
## PO6-17 breach openings: the dressing keeps this clear on both faces.
const BREACH_REACH: float = 1.2
## Half size of the keep-out kept around every floor marker (spawn, patrol, use point...).
const MARKER_HALF: float = 0.35
## Exit signs go above the frame head.
const EXIT_SIGN_Z: float = 2.36
## Seats an NPC sits in (no collider / obstruction: the spawn marker stays on the navmesh).
const NPC_SEATS: Array[String] = ["prop_chair_task"]
## Plan arches / shuttered arches / vault doorways keep this much clear floor in front (both sides).
const ARCH_CLEAR: float = 1.2
## Interior props draw to this distance at most (style guide §5 gives 25 / 60 m; the building's floors stack inside
## every exterior view and no room is deeper than ~25 m, so 30 m keeps the perf budget without visible pop).
const INTERIOR_VIS: float = 30.0
const NEAR_DIR: String = "res://world/heists/gallery_night/art/props_near/"
## asset -> near-range scene path (near_scene_path).
static var _near: Dictionary = {}

## Placement summary per kit room (printed by the builder): "id: n props, missing, warnings".
var report: PackedStringArray = []
## Room id -> placed node count (the builder's report).
var counts: Dictionary = {}

var _b: Object
var _root: Node3D
var _art: RefCounted
var _cat: Dictionary = {}
var _scenes: Dictionary = {}
var _markers: Array[Vector3] = []
var _boxes: Array[AABB] = []
## Door prefabs: [world position, yaw (deg), leaf width].
var _doors: Array[Array] = []
## Kit room id -> its instanced nodes (shadow pick, light tweaks).
var _room_nodes: Dictionary = {}


func setup(builder: Object, root: Node3D, art: RefCounted) -> void:
	_b = builder
	_root = root
	_art = art
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
		var kit: String = String(r[8])
		if kit == "" or String(r[2]) == "exterior" or float(r[7]) <= 0.0:
			continue
		var res: Array = _interior_room(r)
		_dress_room(res[0], res[1], String(r[1]), kit, props_root)
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
		_tweak_light(nd, String(d[0]).get_slice("_", 0))
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
	for a: Array in D.ANCHORS:
		if String(a[0]) != id:
			continue
		var asset: String = String(a[2])
		if not _cat.has(asset):
			report.append("ERROR %s: anchor asset %s not in catalog" % [id, asset])
			continue
		room.add_anchor(_anchor_xform(asset, a[3], float(a[4])), StringName(asset))
		anchor_rows.append(a)
	var seed: int = int(D.KIT_SEEDS.get(id, 7000))
	var res: Dictionary = KitPlacer.place(room, kit, seed, not D.NO_CEILING_GRID.has(id))
	for pl: Variant in res["placements"]:
		var pd: Dictionary = pl
		pd["scene"] = near_scene_path(String(pd["asset"]), String(pd["scene"]))
	var parent: Node3D = _folder(props_root, id)
	var nodes: Array[Node3D] = KitPlacer.instantiate(res, parent, _root)
	var placements: Array = res["placements"]
	for i: int in range(nodes.size()):
		var p: Dictionary = placements[i]
		if i < anchor_rows.size():
			nodes[i].name = String((anchor_rows[i] as Array)[1])
		_finish_node(nodes[i], String(p["asset"]), String(p["mode"]), String(p["mount"]), p["xform"])
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
	counts[id] = nodes.size()
	_link_monitors(nodes, id)
	for n: Node3D in nodes:
		_tweak_light(n, id)
	var missing: PackedStringArray = res["missing"]
	var warnings: PackedStringArray = res["warnings"]
	report.append("%s (%s, seed %d): %d props%s%s" % [id, kit_id, seed, nodes.size(),
		"" if missing.is_empty() else ", MISSING " + ",".join(missing),
		"" if warnings.is_empty() else ", warnings: " + "; ".join(warnings)])


## LIGHT_TWEAKS: per room id (or a DIRECT prop's name prefix) and fixture asset -> Light3D properties.
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
## meshes' visibility range (written as text, so the glb meshes stay in the glb; byte-stable). The wrapper path itself
## when no mesh needs it.
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


## Monitors face the chair in front of them (orientation check): the nearest chair within 30 deg of the screen's front.
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


## Collider + navmesh obstruction for floor props (not the NPC seats, not the walk-through rope).
func _finish_node(n: Node3D, asset: String, mode: String, mount: String, xf: Transform3D) -> void:
	var cat: Dictionary = _cat[asset]
	var kind: String = String(cat.get("kind", ""))
	if kind == "exit_sign" and mode == "above_door":
		n.position.y += maxf(0.0, EXIT_SIGN_Z - float(cat.get("z", EXIT_SIGN_Z)))
	if mount != "" or mode == "on" or mode == "ceiling" or asset in NPC_SEATS or asset in D.NO_COLLIDE:
		return
	var bb: AABB = aabb(asset)
	var top: float = float(cat.get("top", 0.0))
	if top > 0.0 and top < bb.end.y:
		bb.size.y = top - bb.position.y
	if kind == "street_lamp":
		bb = AABB(Vector3(-0.12, 0.0, -0.12), Vector3(0.24, bb.size.y, 0.24))
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

## [KitRoom, world AABB of the clear interior] for a ROOMS row: the rect inside its walls' faces, floor to ceiling;
## doors, plan openings and windows on its outline.
func _interior_room(r: Array) -> Array:
	var f: String = String(r[0])
	var rid: String = String(r[1])
	var y: float = float(L.FFL[f])
	var x0: float = float(r[3])
	var z0: float = float(r[4])
	var x1: float = float(r[5])
	var z1: float = float(r[6])
	var yt: float = y + 1.0
	var lo: Vector3 = Vector3(x0 + _half_t(f, "z", x0, yt, z0, z1), y, z0 + _half_t(f, "x", z0, yt, x0, x1))
	var hi: Vector3 = Vector3(x1 - _half_t(f, "z", x1, yt, z0, z1), y + float(r[7]), z1 - _half_t(f, "x", z1, yt, x0, x1))
	# the stair core's east wall is refitted thicker (gn_gameplay.CORE_FIT) on floors where it carries a door
	var core: Array = GP.CORE_DOOR_WALL
	if absf(x0 - float(core[1])) < 0.001:
		var fit: Array = GP.wall_fit(f, "z", x0, float(core[2]), -1.0e9, 1.0e9)
		lo.x = maxf(lo.x, float(fit[0]) + float(fit[1]) * 0.5)
	if D.CLEAR.has(rid):
		var c: Array = D.CLEAR[rid]
		lo = Vector3(float(c[0]), lo.y, float(c[1]))
		hi = Vector3(float(c[2]), hi.y, float(c[3]))
	var clear: AABB = AABB(lo, hi - lo)
	var room: KitRoom = KitRoom.from_aabb(clear, StringName(rid))
	_thick_keepouts(room, f, r, lo, hi)
	var rect: Rect2 = Rect2(x0, z0, x1 - x0, z1 - z0)
	for d: Array in _doors:
		var pos: Vector3 = d[0]
		if absf(pos.y - y) < 0.3 and _on_rect_edge(rect, pos, absf(sin(deg_to_rad(float(d[1])))) < 0.5):
			room.add_door(pos, float(d[2]), -1.0)
	for o: Array in L.OPENINGS:
		if String(o[0]) != f or absf(float(o[6]) - y) > 0.01 and String(o[1]) != "W":
			continue
		var along_x: bool = String(o[2]) == "x"
		var mid: Vector3 = Vector3((float(o[4]) + float(o[5])) * 0.5, y, float(o[3])) if along_x \
			else Vector3(float(o[3]), y, (float(o[4]) + float(o[5])) * 0.5)
		if not _on_rect_edge(rect, mid, along_x):
			continue
		var width: float = float(o[5]) - float(o[4])
		match String(o[1]):
			"W":
				room.add_window(mid + Vector3.UP * (float(o[6]) - y), width + 0.2, float(o[6]) - y, minf(float(o[7]) - y, clear.size.y))
			"A", "S", "V", "R", "h", "D":
				room.add_door(mid, width, ARCH_CLEAR, minf(float(o[7]) - y, clear.size.y), 0.1)
	return [room, clear]


## Half the thinnest wall on a room edge (its clear rect); thicker stretches become keep-outs (_thick_keepouts).
func _half_t(f: String, axis: String, fixed: float, y: float, a0: float, a1: float) -> float:
	var t: float = INF
	for sg: Array in _art.call(&"wall_segments", f, axis, fixed, y, a0 + 0.3, a1 - 0.3):
		t = minf(t, float(sg[2]))
	return 0.0 if t == INF else t * 0.5


## Keep-outs over the stretches of a room edge where its wall is thicker than the clear rect assumes (wall mounts
## and floor props stay off them): [lo, hi] = the clear AABB corners.
func _thick_keepouts(room: KitRoom, f: String, r: Array, lo: Vector3, hi: Vector3) -> void:
	var yt: float = lo.y + 1.0
	var x0: float = float(r[3])
	var z0: float = float(r[4])
	var x1: float = float(r[5])
	var z1: float = float(r[6])
	# [axis, wall line, inward sign, clear face, from, to]
	for e: Array in [["x", z0, 1.0, lo.z, x0, x1], ["x", z1, -1.0, hi.z, x0, x1], ["z", x0, 1.0, lo.x, z0, z1],
			["z", x1, -1.0, hi.x, z0, z1]]:
		for sg: Array in _art.call(&"wall_segments", f, String(e[0]), float(e[1]), yt, float(e[4]), float(e[5])):
			var face: float = float(e[1]) + float(e[2]) * float(sg[2]) * 0.5
			if (face - float(e[3])) * float(e[2]) <= 0.005:
				continue
			var d0: float = minf(float(e[3]), face + float(e[2]) * 0.05)
			var d1: float = maxf(float(e[3]), face + float(e[2]) * 0.05)
			if String(e[0]) == "x":
				room.add_keep_out(AABB(Vector3(float(sg[0]), lo.y, d0), Vector3(float(sg[1]) - float(sg[0]), hi.y - lo.y, d1 - d0)))
			else:
				room.add_keep_out(AABB(Vector3(d0, lo.y, float(sg[0])), Vector3(d1 - d0, hi.y - lo.y, float(sg[1]) - float(sg[0]))))


static func _on_rect_edge(r: Rect2, pos: Vector3, along_x: bool) -> bool:
	if along_x:
		return (absf(pos.z - r.position.y) < 0.1 or absf(pos.z - r.end.y) < 0.1) and pos.x > r.position.x and pos.x < r.end.x
	return (absf(pos.x - r.position.x) < 0.1 or absf(pos.x - r.end.x) < 0.1) and pos.z > r.position.y and pos.z < r.end.y


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
## stairs and balustrades, the review cameras' standpoints and the PO6-17 breach openings.
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
	var mb: Node = _root.get_node_or_null("Props")
	if mb != null:
		for p: Node in mb.find_children("*", "Node3D", false, false):
			_collect_mapbuilt(p as Node3D)
	for rl: Array in L.RAILS:
		var fx: float = float(rl[2])
		var along_x: bool = String(rl[1]) == "x"
		var lo: Vector3 = Vector3(float(rl[3]), float(rl[5]), fx - 0.05) if along_x else Vector3(fx - 0.05, float(rl[5]), float(rl[3]))
		var hi: Vector3 = Vector3(float(rl[4]), float(rl[6]), fx + 0.05) if along_x else Vector3(fx + 0.05, float(rl[6]), float(rl[4]))
		_boxes.append(AABB(lo, hi - lo).grow(0.15))
	for st: Array in D.STAIR_KEEP_OUT:
		_boxes.append(AABB(Vector3(float(st[0]), float(st[1]), float(st[2])),
			Vector3(float(st[3]) - float(st[0]), float(st[4]) - float(st[1]), float(st[5]) - float(st[2]))))
	for cam: Array in L.REVIEW_CAMERAS:
		if String(cam[0]).begins_with("TopDown"):
			continue
		var cp: Vector3 = Vector3(float(cam[3]), float(cam[4]), float(cam[5]))
		_boxes.append(AABB(cp - Vector3(0.6, 1.75, 0.6), Vector3(1.2, 2.1, 1.2)))
	_boxes.append_array(AM.keep_outs(AE.BREACHES, BREACH_REACH))


## A Props child placed by the map before the dressing (supports, racks, the AHU, screens): its box.
func _collect_mapbuilt(p: Node3D) -> void:
	if p.scene_file_path != "":
		var asset: String = p.scene_file_path.get_file().get_basename()
		if _cat.has(asset):
			_boxes.append((_gx(p) * aabb(asset)).grow(0.03))
		return
	if p is CollisionObject3D:
		for cs: Node in p.find_children("*", "CollisionShape3D", true, false):
			var bs: BoxShape3D = (cs as CollisionShape3D).shape as BoxShape3D
			if bs != null:
				_boxes.append((_gx(cs as Node3D) * AABB(-bs.size * 0.5, bs.size)).grow(0.03))
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
		return
	var pf: Node3D = n
	var path: String = (pf.get_script() as Script).resource_path if pf.get_script() != null else ""
	var up: Node3D = pf.get_node_or_null("UsePoint") as Node3D
	if up != null:
		_markers.append(_gx(up).origin)
	var xf2: Transform3D = _gx(pf)
	if path.contains("/door/"):
		var yaw: float = rad_to_deg(xf2.basis.get_euler().y)
		_doors.append([xf2.origin, yaw, float(pf.get(&"width_m")) if "width_m" in pf else 0.9])
		return
	if path.contains("/window/"):
		return
	if path.contains("/escape_zone/"):
		var zs: Vector3 = pf.get(&"zone_size_m")
		_boxes.append(xf2 * AABB(Vector3(-zs.x * 0.5, 0.0, -zs.z * 0.5), Vector3(zs.x, 2.0, zs.z)))
		return
	if path.contains("/laser_grid/"):
		var ls: Vector3 = pf.get(&"size_m")
		_boxes.append((xf2 * AABB(Vector3(-ls.x * 0.5, 0.0, -ls.z * 0.5), ls)).grow(0.3))
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
	_boxes.append(box.grow(0.05))


func _gx(n: Node3D) -> Transform3D:
	return _b.call(&"global_xform", n)


## Soft fill per dressed interior room (level_standards §3.7: meta fill, energy <= 0.3, no shadows, <= 2 per room): the
## kit fixtures are downward spots, so this lifts the ceilings and upper walls. Long rooms get two.
func fill_lights(parent: Node3D) -> void:
	for r: Array in L.ROOMS:
		var rid: String = String(r[1])
		if String(r[2]) == "exterior" or float(r[7]) <= 0.0 or D.NO_FILL.has(rid):
			continue
		var y0: float = float(L.FFL[String(r[0])])
		var lo: Vector3 = Vector3(float(r[3]), y0, float(r[4]))
		var hi: Vector3 = Vector3(float(r[5]), y0 + float(r[7]), float(r[6]))
		var size: Vector3 = hi - lo
		var long_x: bool = size.x >= size.z
		var length: float = maxf(size.x, size.z)
		var spots: Array[float] = [0.5]
		if length >= 2.5 * minf(size.x, size.z) or length > 14.0:
			spots = [0.25, 0.75]
		var warm: bool = rid in D.WARM_ROOMS
		var i: int = 0
		for fr: float in spots:
			var p: Vector3 = Vector3(lerpf(lo.x, hi.x, fr if long_x else 0.5), hi.y - minf(0.6, size.y * 0.2),
				lerpf(lo.z, hi.z, 0.5 if long_x else fr))
			var light: OmniLight3D = OmniLight3D.new()
			light.name = "Fill%s_%d" % [rid, i]
			light.position = p
			light.light_color = Color(1.0, 0.88, 0.74) if warm else Color(0.92, 0.95, 1.0)
			light.light_energy = 0.28
			light.omni_range = clampf(length / float(spots.size()) * 0.8 + size.y * 0.5, 3.5, 12.0)
			light.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
			light.shadow_enabled = false
			light.set_meta(&"fill", true)
			parent.add_child(light)
			light.owner = _root
			i += 1
