## Shadow Ledger G2 dressing (SL-1, ENV C): the KitPlacer pass over every RoomVolume with a dressing kit (as Dockside
## Burn's db_dress.gd / Gallery Night's gn_dress.gd). The map-built props (layout PROPS / CHAIRS, already carrying their
## catalog visuals) enter each room as virtual anchors: the kit counts them (no second desk) and puts its "on" items
## (monitors, keyboards, coffee machines) on them, then they are dropped from the instancing. Every gameplay prefab,
## marker, door swing, door panel, window, the cage, the feature stair's foot, the void walkway, the laser plane and
## each review-camera standpoint is a keep-out, plus the room keep-outs of the dressing data. Placed floor props get a
## box collider and a navmesh obstruction. Kit fixtures carry the room's lights (LIGHT_TWEAKS); a few cast shadows
## (SHADOW_FIXTURES). Fill lights (meta fill) lift each room's ceiling. Data: shadow_ledger_dressing.gd.
extends RefCounted

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
const L: GDScript = preload("res://world/heists/shadow_ledger/greybox/shadow_ledger_layout.gd")
const D: GDScript = preload("res://world/heists/shadow_ledger/greybox/shadow_ledger_dressing.gd")
const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const KITS_DIR: String = "res://world/kits/"
## Half size of the keep-out kept around every floor marker (spawn, patrol, use point...).
const MARKER_HALF: float = 0.35
## Exit signs go above the frame head.
const EXIT_SIGN_Z: float = 2.36
## Interior kit props draw to this distance (as Gallery Night's near-range wrappers: both office floors stack inside
## every exterior view; no SL room is deeper than ~30 m).
const INTERIOR_VIS: float = 30.0
const NEAR_DIR: String = "res://world/heists/shadow_ledger/art/props_near/"
## Depth of the keep-out band along a stretch of a room edge without a wall (an L-shaped room's inner edge).
const OPEN_EDGE: float = 0.4
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
## Door prefabs and door-like openings: [world position, yaw (deg), leaf width].
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
	_tag_prefab_kinds()
	_aim_chairs()
	for rv: Node in _root.get_node("Rooms").get_children():
		var room: RoomVolume = rv as RoomVolume
		if room == null or String(room.dressing_kit) == "" or String(room.purpose) == "exterior":
			continue
		var res: Array = _interior_room(room)
		if res.is_empty():
			continue
		_dress_room(res[0], res[1], String(room.room_id), String(room.dressing_kit), props_root)
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
		_tweak_light(nd, "Direct")
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
		room.add_anchor(_anchor_on_collider(mb[0], String(mb[1]), wx), StringName(String(mb[1])))
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
	var missing: PackedStringArray = PackedStringArray()
	var present: Dictionary = _mapbuilt_kinds_in(id)  # a required kind the map built in another box of the room
	for mk: String in res["missing"]:
		if not present.has(mk):
			missing.append(mk)
	var warnings: PackedStringArray = res["warnings"]
	report.append("%s (%s, seed %d): %d props + %d map-built%s%s" % [id, kit_id, seed, nodes.size(), nv,
		"" if missing.is_empty() else ", MISSING " + ",".join(missing),
		"" if warnings.is_empty() else ", warnings: " + "; ".join(warnings)])
	if not missing.is_empty():
		report.append("ERROR %s: required kinds not placed: %s" % [id, ",".join(missing)])


## A map-built support's anchor for KitPlacer: its visual, raised to the layout collider's top where the catalog
## model's work top sits lower (desks 0.74 under a 0.75 m box), so the kit's "on" items rest on the collider.
func _anchor_on_collider(body: Node3D, asset: String, wx: Transform3D) -> Transform3D:
	var cat: Dictionary = _cat.get(asset, {})
	if not bool(cat.get("support", false)):
		return wx
	var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
	if cs == null or not (cs.shape is BoxShape3D):
		return wx
	var col_top: float = _gx(cs).origin.y + (cs.shape as BoxShape3D).size.y * 0.5
	var top: float = float(cat.get("top", 0.0))
	if top <= 0.0:
		top = aabb(asset).end.y
	var lift: float = col_top - (wx.origin.y + top)
	if lift <= 0.0005 or lift > 0.05:
		return wx
	var out: Transform3D = wx
	out.origin.y += lift
	return out


## Kinds of the map-built props inside any box of room `id` (an L-shaped room's other rectangle).
func _mapbuilt_kinds_in(id: String) -> Dictionary:
	var out: Dictionary = {}
	var rv: RoomVolume = _root.get_node_or_null("Rooms/Room" + id) as RoomVolume
	if rv == null:
		return out
	for c: Node in rv.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var sz: Vector3 = (cs.shape as BoxShape3D).size
		var box: AABB = AABB(cs.position - sz * 0.5, sz).grow(0.05)
		for mb: Array in _mapbuilt:
			if box.has_point((mb[2] as Transform3D).origin + Vector3.UP * 0.1):
				out[String((mb[0] as Node3D).get_meta(&"kind", ""))] = true
	return out


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
## meshes' visibility range (written as text, byte-stable; as db_dress.near_scene_path). Lights never get one.
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


## Monitors face the chair in front of them (orientation check): the nearest chair within 18 deg of the screen's front,
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

## [KitRoom, world AABB of the clear interior] for a RoomVolume: its largest box inside its walls' faces, floor to
## ceiling; doors, door panels, the lift car opening and the glazing on its outline.
func _interior_room(rv: RoomVolume) -> Array:
	var rid: String = String(rv.room_id)
	var best: AABB = AABB()
	for c: Node in rv.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var sz: Vector3 = (cs.shape as BoxShape3D).size
		var b: AABB = AABB(cs.position - sz * 0.5, sz)
		if b.size.x * b.size.z > best.size.x * best.size.z:
			best = b
	if best.size.x <= 0.0:
		report.append("ERROR %s: room has no box" % rid)
		return []
	var y: float = best.position.y
	var lv: String = _level_of(y)
	var x0: float = best.position.x
	var z0: float = best.position.z
	var x1: float = best.end.x
	var z1: float = best.end.z
	var lo: Vector3 = Vector3(x0 + half_t(lv, "z", x0, z0, z1), y, z0 + half_t(lv, "x", z0, x0, x1))
	var hi: Vector3 = Vector3(x1 - half_t(lv, "z", x1, z0, z1), best.end.y, z1 - half_t(lv, "x", z1, x0, x1))
	var clear: AABB = AABB(lo, hi - lo)
	var room: KitRoom = KitRoom.from_aabb(clear, StringName(rid))
	_thick_keepouts(room, lv, x0, z0, x1, z1, lo, hi)
	var rect: Rect2 = Rect2(x0, z0, x1 - x0, z1 - z0)
	for d: Array in _doors:
		var pos: Vector3 = d[0]
		if absf(pos.y - y) < 0.3 and _on_rect_edge(rect, pos, absf(sin(deg_to_rad(float(d[1])))) < 0.5):
			room.add_door(pos, float(d[2]), -1.0, minf(2.6, hi.y - y))
	for o: Array in _wall_openings(lv):
		var along_x: bool = String(o[0]) == "x"
		var mid: Vector3 = Vector3((float(o[2]) + float(o[3])) * 0.5, y, float(o[1])) if along_x \
			else Vector3(float(o[1]), y, (float(o[2]) + float(o[3])) * 0.5)
		if not _on_rect_edge(rect, mid, along_x):
			continue
		var a0: float = maxf(float(o[2]), x0 if along_x else z0)
		var a1: float = minf(float(o[3]), x1 if along_x else z1)
		if a1 - a0 < 0.1:
			continue
		mid = Vector3((a0 + a1) * 0.5, y, float(o[1])) if along_x else Vector3(float(o[1]), y, (a0 + a1) * 0.5)
		var sill: float = float(o[4])
		var head: float = minf(float(o[5]), clear.size.y)
		if sill <= 0.05:
			room.add_door(mid, a1 - a0, 1.0, head)
		else:
			room.add_window(mid + Vector3.UP * sill, a1 - a0 + 0.1, sill, head)
	return [room, clear]


func _level_of(y: float) -> String:
	if y < L.F41 - 0.5:
		return "L40"
	if y < L.F42 - 0.5:
		return "L41"
	if y < L.FRF - 0.5:
		return "L42"
	return "RF"


## Glazing and door-like openings of a level: [axis, fixed, a0, a1, sill (rel), head (rel)]. The curtain wall (per
## room span, from the room's sill to its ceiling, minus the solid bays), the interior glazing, the closed lift / sealed
## door panels and the L40 lift car opening (sill 0: kept clear like a door).
func _wall_openings(lv: String) -> Array:
	var out: Array = []
	for f: Array in L.FACADE_LINES.get(lv, []):
		for r: Array in _b.call(&"_level_rooms", lv):
			var meta: Array = L.ROOM_META.get(String(r[0]), [])
			if meta.is_empty():
				continue
			for e: Array in [["x", r[2], r[1], r[3]], ["x", r[4], r[1], r[3]], ["z", r[1], r[2], r[4]], ["z", r[3], r[2], r[4]]]:
				if not _b.call(&"_on_line", f, String(e[0]), float(e[1]), float(e[2]), float(e[3])):
					continue
				var cuts: Array = []
				for sb: Array in L.SOLID_BAYS:
					if String(sb[0]) == lv and String(sb[1]) == String(e[0]) and absf(float(sb[2]) - float(e[1])) < 0.001:
						cuts.append([float(sb[3]), float(sb[4])])
				for g: Array in _b.call(&"_subtract", [[float(e[2]), float(e[3])]], cuts):
					out.append([String(e[0]), float(e[1]), float(g[0]), float(g[1]), float(meta[3]), float(meta[2])])
	for g2: Array in L.WALL_GLASS:
		if String(g2[0]) == lv:
			out.append([String(g2[1]), float(g2[2]), float(g2[3]), float(g2[4]), maxf(float(g2[5]), 0.0), float(g2[6])])
	for p: Array in L.DOOR_PANELS:
		var b: Array = p[1]
		if _level_of(float(b[1])) != lv:
			continue
		var along_x: bool = float(b[3]) - float(b[0]) > float(b[5]) - float(b[2])
		var fixed: float = (float(b[2]) + float(b[5])) * 0.5 if along_x else (float(b[0]) + float(b[3])) * 0.5
		var line: float = snappedf(fixed, 0.5) if absf(fixed - snappedf(fixed, 0.5)) < 0.3 else fixed
		out.append(["x" if along_x else "z", line, float(b[0]) if along_x else float(b[2]),
			float(b[3]) if along_x else float(b[5]), 0.0, 2.2])
	if lv == "L40":
		var lc: Array = L.LIFT_CAR_OPENING
		out.append([String(lc[0]), float(lc[1]), float(lc[2]), float(lc[3]), 0.0, float(lc[4])])
	return out


## The wall stretches on a room edge (axis "x": runs along x at z = fixed) of level `lv` within [a0, a1]:
## [[from, to, thickness], ...] (thickness 0: no wall, an inner edge of an L-shaped room or a plan opening). As the
## builder's _wall_line: a stretch shared with a core room is 0.3 m, else 0.2 m; the curtain wall 0.4 m.
func edge_walls(lv: String, axis: String, fixed: float, a0: float, a1: float) -> Array:
	if _b.call(&"_on_facade", lv, axis, fixed, a0, a1):
		return [[a0, a1, L.EXT_T]]
	var segs: Array = []
	for r: Array in _b.call(&"_level_rooms", lv):
		for e: Array in [["x", r[2], r[1], r[3]], ["x", r[4], r[1], r[3]], ["z", r[1], r[2], r[4]], ["z", r[3], r[2], r[4]]]:
			if String(e[0]) != axis or absf(float(e[1]) - fixed) > 0.001:
				continue
			var s0: float = maxf(float(e[2]), a0)
			var s1: float = minf(float(e[3]), a1)
			if s1 - s0 > 0.001:
				segs.append([s0, s1, L.CORE_T if bool(r[5]) else L.INT_T])
	var pts: Array[float] = [a0, a1]
	for s: Array in segs:
		for v: float in [float(s[0]), float(s[1])]:
			if not pts.has(v):
				pts.append(v)
	var cuts: Array = []
	for o: Array in L.WALL_OPEN:
		if String(o[0]) == lv and String(o[1]) == axis and absf(float(o[2]) - fixed) < 0.001:
			cuts.append([float(o[3]), float(o[4])])
			for v2: float in [float(o[3]), float(o[4])]:
				if v2 > a0 and v2 < a1 and not pts.has(v2):
					pts.append(v2)
	pts.sort()
	var out: Array = []
	for i: int in range(pts.size() - 1):
		var p: float = pts[i]
		var q: float = pts[i + 1]
		var t: float = 0.0
		for s2: Array in segs:
			if float(s2[0]) <= p + 0.0001 and float(s2[1]) >= q - 0.0001:
				t = maxf(t, float(s2[2]))
		for c: Array in cuts:
			if float(c[0]) <= p + 0.0001 and float(c[1]) >= q - 0.0001:
				t = 0.0
		if not out.is_empty() and absf(float(out[-1][2]) - t) < 0.001 and absf(float(out[-1][1]) - p) < 0.0001:
			out[-1][1] = q
		else:
			out.append([p, q, t])
	return out


## Half the thinnest wall on a room edge (its clear rect), 0.1 m by default; thicker stretches become keep-outs.
func half_t(lv: String, axis: String, fixed: float, a0: float, a1: float) -> float:
	var t: float = INF
	for sg: Array in edge_walls(lv, axis, fixed, a0, a1):
		if float(sg[2]) > 0.0:
			t = minf(t, float(sg[2]))
	return 0.1 if t == INF else t * 0.5


## Keep-outs over the stretches of a room's edges where the wall is thicker than its clear rect assumes (wall mounts
## and floor props stay off them), and a band along the stretches with no wall at all (nothing backs onto air).
func _thick_keepouts(room: KitRoom, lv: String, x0: float, z0: float, x1: float, z1: float, lo: Vector3, hi: Vector3) -> void:
	# [axis, wall line, inward sign, clear face, from, to]
	for e: Array in [["x", z0, 1.0, lo.z, x0, x1], ["x", z1, -1.0, hi.z, x0, x1], ["z", x0, 1.0, lo.x, z0, z1],
			["z", x1, -1.0, hi.x, z0, z1]]:
		var sgn: float = float(e[2])
		for sg: Array in edge_walls(lv, String(e[0]), float(e[1]), float(e[4]), float(e[5])):
			var d0: float
			var d1: float
			if float(sg[2]) <= 0.0:
				d0 = minf(float(e[3]), float(e[3]) + sgn * OPEN_EDGE)
				d1 = maxf(float(e[3]), float(e[3]) + sgn * OPEN_EDGE)
			else:
				var face: float = float(e[1]) + sgn * float(sg[2]) * 0.5
				if (face - float(e[3])) * sgn <= 0.005:
					continue
				d0 = minf(float(e[3]), face + sgn * 0.05)
				d1 = maxf(float(e[3]), face + sgn * 0.05)
			var s0: float = maxf(float(sg[0]), float(e[4]))
			var s1: float = minf(float(sg[1]), float(e[5]))
			if String(e[0]) == "x":
				room.add_keep_out(AABB(Vector3(s0, lo.y, d0), Vector3(s1 - s0, hi.y - lo.y, d1 - d0)))
			else:
				room.add_keep_out(AABB(Vector3(d0, lo.y, s0), Vector3(d1 - d0, hi.y - lo.y, s1 - s0)))


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
## railings and balustrades, the cage, the feature stair and the review cameras' standpoints.
func _collect() -> void:
	for c: String in ["Gameplay", "Variants", "Navigation"]:
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
	for rl: Array in L.BALUSTRADES:
		var bb: Array = rl[1]
		var rlo: Vector3 = Vector3(float(bb[0]), float(bb[1]), float(bb[2]))
		var rhi: Vector3 = Vector3(float(bb[3]), float(bb[4]), float(bb[5]))
		_boxes.append(AABB(rlo, rhi - rlo).grow(0.15))
	var cg: Array = L.CAGE["box"]
	_boxes.append(AABB(Vector3(float(cg[0]) - 0.15, L.F41, float(cg[1]) - 0.15),
		Vector3(float(cg[2]) - float(cg[0]) + 0.3, float(L.CAGE["h"]) + 0.1, float(cg[3]) - float(cg[1]) + 0.3)))
	var fs: Dictionary = L.FEATURE_STAIR
	var fz: Array = fs["z"]
	_boxes.append(AABB(Vector3(float(fs["x0"]) - 1.2, L.F41, float(fz[0]) - 0.2),
		Vector3(20.6 - float(fs["x0"]) + 1.2, L.F42 - L.F41 + 1.2, float(fz[1]) - float(fz[0]) + 1.0)))
	for cam: Array in L.REVIEW_CAMERAS:
		if String(cam[0]).begins_with("TopDown"):
			continue
		var cp: Vector3 = cam[1]
		_boxes.append(AABB(cp - Vector3(0.5, 1.75, 0.5), Vector3(1.0, 2.1, 1.0)))
	for p2: Array in L.DOOR_PANELS:
		var b3: Array = p2[1]
		var plo: Vector3 = Vector3(float(b3[0]), float(b3[1]), float(b3[2]))
		var phi: Vector3 = Vector3(float(b3[3]), float(b3[4]), float(b3[5]))
		_boxes.append(AABB(plo, phi - plo).grow(0.6))


## A Props child placed by the map (layout props, chairs): its collider boxes; a catalog visual makes it a virtual
## anchor of its room.
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
	if path.contains("/escape_zone/") or path.contains("/secure_zone/"):
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


## G2 density: every prop root has a `kind` (validate_level density). Gameplay / variant prefab instances without one
## take their prefab id (the contract folder name, as Night Deposit's prefab helper does).
func _tag_prefab_kinds() -> void:
	for top: String in ["Gameplay", "Variants"]:
		var t: Node = _root.get_node_or_null(top)
		if t == null:
			continue
		for n: Node in t.find_children("*", "Node3D", true, false):
			if not ("visual_scene" in n) or n.has_meta(&"kind") or n.get_script() == null:
				continue
			var path: String = (n.get_script() as Script).resource_path
			n.set_meta(&"kind", path.get_base_dir().get_file())


## PO-9 orientation on long tables: a chair beside the end of a long table looks straight at the table edge, not at its
## centre. Each layout chair whose front ray crosses its table's footprint gets an `Aim` marker on that edge (a
## sibling under Props, not part of either prop) and faces it; the others keep facing the table itself.
func _aim_chairs() -> void:
	for c: Array in L.CHAIRS:
		var chair: Node3D = null
		var table: Node3D = null
		for lvn: Node in _root.get_node("Props").get_children():
			if chair == null:
				chair = lvn.get_node_or_null(String(c[0])) as Node3D
			if table == null:
				table = lvn.get_node_or_null(String(c[3])) as Node3D
		if chair == null or table == null:
			continue
		var cx: Transform3D = _gx(chair)
		var tx: Transform3D = _gx(table)
		var fwd: Vector3 = -cx.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var to: Vector3 = tx.origin - cx.origin
		to.y = 0.0
		if rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))) <= 12.0:
			continue
		var cs: CollisionShape3D = table.get_node_or_null("Collision") as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var half: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		var hit: float = -1.0
		for i: int in range(1, 60):  # march the chair's front ray until it is inside the table footprint
			var p: Vector3 = tx.affine_inverse() * (cx.origin + fwd * (0.05 * float(i)))
			if absf(p.x) < half.x - 0.05 and absf(p.z) < half.z - 0.05:
				hit = 0.05 * float(i) + 0.15
				break
		if hit < 0.0:
			report.append("WARN chair %s: its front misses %s" % [c[0], c[3]])
			continue
		var aim: Marker3D = Marker3D.new()
		aim.name = String(c[0]) + "Aim"
		aim.position = chair.position + (chair.get_parent() as Node3D).basis.inverse() * (fwd * hit) \
			+ Vector3.UP * 0.75
		chair.get_parent().add_child(aim)
		aim.owner = _root
		chair.set_meta(&"faces", chair.get_path_to(aim))


## Soft fill per interior room with a kit or a stair (level_standards §3.7: meta fill, energy <= 0.3, no shadows, <= 2
## per room): the kit fixtures are downward spots, so this lifts the ceilings and upper walls. Long rooms get two.
func fill_lights(parent: Node3D) -> void:
	for rv: Node in _root.get_node("Rooms").get_children():
		var room: RoomVolume = rv as RoomVolume
		if room == null:
			continue
		var rid: String = String(room.room_id)
		var purpose: String = String(room.purpose)
		if purpose in ["exterior", "shaft", "elevator"] or D.NO_FILL.has(rid):
			continue
		var best: AABB = AABB()
		for c: Node in room.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs != null and cs.shape is BoxShape3D:
				var sz: Vector3 = (cs.shape as BoxShape3D).size
				var b: AABB = AABB(cs.position - sz * 0.5, sz)
				if b.size.x * b.size.z > best.size.x * best.size.z:
					best = b
		var lo: Vector3 = best.position
		var hi: Vector3 = best.end
		var size: Vector3 = hi - lo
		var long_x: bool = size.x >= size.z
		var length: float = maxf(size.x, size.z)
		var spots: Array[float] = [0.5]
		if length >= 2.5 * minf(size.x, size.z) or length > 14.0:
			spots = [0.25, 0.75]
		var warm: bool = rid in D.WARM_ROOMS
		var dim: bool = rid in D.DIM_FILL_ROOMS
		var i: int = 0
		for fr: float in spots:
			var p: Vector3 = Vector3(lerpf(lo.x, hi.x, fr if long_x else 0.5), hi.y - minf(0.6, size.y * 0.2),
				lerpf(lo.z, hi.z, 0.5 if long_x else fr))
			var light: OmniLight3D = OmniLight3D.new()
			light.name = "Fill%s_%d" % [rid, i]
			light.position = p
			light.light_color = Color(1.0, 0.86, 0.72) if warm else Color(0.88, 0.94, 1.0)
			light.light_energy = 0.18 if dim else 0.28
			light.omni_range = clampf(length / float(spots.size()) * 0.8 + size.y * 0.5, 3.5, 10.0)
			light.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
			light.shadow_enabled = false
			light.set_meta(&"fill", true)
			parent.add_child(light)
			light.owner = _root
			i += 1
