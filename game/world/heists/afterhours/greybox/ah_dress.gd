## Afterhours G2 dressing (AH-C2, ENV C): copy-adapted from rolling_thunder/greybox/rt_dress.gd (D-147 reuse-first;
## the RT chain is not shared code), itself Ostrander Federal's of_dress.gd. Registered by ONE line in build_greybox.gd,
## before the navmesh bake (placed floor props obstruct it):
## * Map-built furniture art: the G1 boxes of Props/MapBuilt get exact-fit catalog art (ah_dress_data.gd PROP_ART: ENV
##   D's club set pieces, prop_ah_*, and the library; the greybox Mesh goes, the collider, metas, seats and the navmesh
##   stay).
## * Kit rooms: every RoomVolume whose dressing kit exists (the shared kits and the AH kits of
##   tools/blender/props/_kits_afterhours.py) and whose purpose is not exterior is dressed by KitPlacer. Every gameplay
##   prefab, use point, door swing, marker, nav-link end, shell box, map-built prop, seat chair and review-camera
##   standpoint is a keep-out.
## * Exteriors: street furniture rows and directly placed props (fixed tables); a slot that meets a keep-out is skipped
##   and reported, so no route, spawn, cover or use point moves. Landmarks: the marquee over the G1 box.
## Placed floor props get a box collider (cut at the catalog `top`) and a navmesh obstruction (thin ones widened to two
## nav cells); mounts, "on" items and ceiling fixtures neither. Never moves a G1 contract node. Data: ah_dress_data.gd.
extends RefCounted

const L: GDScript = preload("res://world/heists/afterhours/greybox/afterhours_layout.gd")
const LC: GDScript = preload("res://world/heists/afterhours/greybox/afterhours_layout_content.gd")
const D: GDScript = preload("res://world/heists/afterhours/greybox/ah_dress_data.gd")
const OD: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_dress.gd")
const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const KITS_DIR: String = "res://world/kits/"
## Half size of the keep-out kept around every floor marker (spawn, patrol, use point...).
const MARKER_HALF: float = 0.35
const EXIT_SIGN_Z: float = 2.36
## Depth of the keep-out band along a room edge without a wall.
const OPEN_EDGE: float = 0.4
## A room edge takes wall mounts (lamps at 2.4 m, signs) only where its wall stands this high above the floor.
const MOUNT_WALL: float = 2.7
const FOLDER: String = "Dress"
const NO_RETAG: Array[String] = ["sink", "toilet", "urinal"]
const SEAT_TARGETS: Array[String] = ["desk", "table", "counter_service", "counter_transaction", "coffee_table",
	"check_table", "counter_bar", "cocktail_table"]
const POLE_KINDS: Array[String] = ["street_lamp", "lamp_post"]
## Kinds whose collider and nav obstruction is a pole off the pivot: kind -> [pole centre x (local), radius, height]
## (prop_traffic_signal: its pivot is the footprint centre).
## (prop_pole_sign_halfway: the pole at the pivot, under the 4.6 m sign cabinet.)
const POLE_OFF: Dictionary = {"traffic_signal": [-1.4, 0.14, 4.0], "pole_sign": [0.0, 0.11, 4.6]}
## Landmark kinds that cast no shadow (flat or low on the rail bank / the roof deck; D-146 shadow draws).
const NO_SHADOW_KINDS: Array[String] = ["rail_track", "marking", "signage"]
const ART_SCALE_MIN: float = 0.55
const ART_SCALE_MAX: float = 1.6
## Minimum horizontal width of a bake obstruction (two 0.1 m nav cells).
const NAV_MIN: float = 0.2
## Near-range wrappers of the interior kit props (generated, byte-stable; as of_dress.gd, OF's size bands).
const NEAR_DIR: String = "res://world/heists/afterhours/art/props_near/"
static var _near: Dictionary = {}

var report: PackedStringArray = []
var counts: Dictionary = {}

var _b: Object
var _root: Node3D
var _cat: Dictionary = {}
var _scene_asset: Dictionary = {}
var _scenes: Dictionary = {}
var _markers: Array[Vector3] = []
var _boxes: Array[AABB] = []
## Door prefabs: [world position, yaw (deg), leaf width, handle position].
var _doors: Array[Array] = []
## Map-built supports with catalog art: [node, asset, world transform of the cell (unscaled), box height].
var _mapbuilt: Array[Array] = []
## Seated spawns' chairs (catalog chairs outside Props): [world transform, asset].
var _seat_chairs: Array[Array] = []
var _art_bodies: int = 0
## World footprints of the exterior props placed so far (rows and direct props keep off each other).
var _placed_ext: Array[AABB] = []
## Door approaches (1.2 m each side): street furniture keeps off them (the kit rooms use KitRoom.add_door).
var _door_boxes: Array[AABB] = []


## The one call build_greybox.gd makes. `builder` is the generator (map_root, errors, obstruct(), global_xform()).
func run(builder: Object) -> void:
	_b = builder
	_root = builder.get(&"map_root")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not (parsed is Dictionary):
		_err("cannot read %s" % CATALOG_PATH)
		return
	_cat = parsed
	for a: String in _cat:
		_scene_asset[String((_cat[a] as Dictionary).get("scene", ""))] = a
	art_mapbuilt()
	_collect()
	_tag_prefab_kinds()
	var props: Node3D = _folder(_root.get_node("Props") as Node3D, FOLDER)
	var waiting: PackedStringArray = []
	for rv: Node in _root.get_node("Rooms").get_children():
		var room: RoomVolume = rv as RoomVolume
		if room == null or String(room.dressing_kit) == "":
			continue
		if not ResourceLoader.exists(KITS_DIR + String(room.dressing_kit) + ".tres"):
			waiting.append("%s (%s)" % [room.room_id, room.dressing_kit])
			continue
		if not _placer_room(room):
			continue
		var res: Array = _interior_room(room)
		if res.is_empty():
			continue
		_dress_room(res[0], res[1], String(room.room_id), String(room.dressing_kit), props)
	_rows(_folder(props, "Streets"))
	_direct_props(_folder(props, "Direct"))
	_landmarks()
	_link_faces()
	var total: int = 0
	for k: String in counts:
		total += int(counts[k])
	report.append("%d props (%d kit rooms + streets + direct), %d map-built art bodies; new kits waiting: %s"
		% [total, counts.size() - 2, _art_bodies, ", ".join(waiting)])
	for line: String in report:
		printerr("dress: " + line)
		if line.begins_with("ERROR"):
			var errs: PackedStringArray = _b.get(&"errors")
			errs.append(line)
			_b.set(&"errors", errs)


func _err(msg: String) -> void:
	report.append("ERROR " + msg)


static func _placer_room(room: RoomVolume) -> bool:
	return String(room.purpose) != "exterior" or D.PLACER_EXTERIOR.has(String(room.room_id))


func scene(asset: String, near: bool = false) -> PackedScene:
	var key: String = asset + ("|near" if near else "")
	if _scenes.has(key):
		return _scenes[key]
	var ps: PackedScene = null
	if _cat.has(asset):
		var path: String = String((_cat[asset] as Dictionary)["scene"])
		ps = load(near_scene_path(asset, path) if near else path) as PackedScene
	if ps == null:
		_err("no scene for asset %s" % asset)
	_scenes[key] = ps
	return ps


## The near-range variant of a catalog wrapper scene (INTERIOR_VIS, of_dress.gd near_scene_path): an inherited scene
## under NEAR_DIR overriding its meshes' visibility range (byte-stable text). The original path when nothing changes.
static func near_scene_path(asset: String, scene_path: String) -> String:
	if _near.has(asset):
		return String(_near[asset])
	var base: PackedScene = load(scene_path) as PackedScene
	var out: String = scene_path
	if base != null:
		var inst: Node = base.instantiate()
		var body: PackedStringArray = []
		var editable: PackedStringArray = []
		var rng: float = OD._near_range(inst)
		for m: Node in inst.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = m as GeometryInstance3D
			var parent_path: String = String(inst.get_path_to(m.get_parent()))
			var lines: String = '\n[node name="%s" parent="%s"]\n' % [m.name, parent_path]
			if gi.visibility_range_end <= 0.0 or gi.visibility_range_end > rng:
				lines += "visibility_range_end = %.1f\nvisibility_range_end_margin = %.1f\nvisibility_range_fade_mode = 1\n" \
					% [rng, rng * 0.1]
			if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				lines += "cast_shadow = 0\n"  # indoors: lit by shadowless fixtures; the sun's cascades skip it (D-146)
			if not lines.ends_with("]\n"):
				body.append(lines)
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


func _under(n: Node, top: String) -> bool:
	var cur: Node = n.get_parent()
	while cur != null and cur != _root:
		if cur.get_parent() == _root and String(cur.name) == top:
			return true
		cur = cur.get_parent()
	return false


static func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _gx(n: Node3D) -> Transform3D:
	return _b.call(&"global_xform", n)


## A bake obstruction box no thinner than two nav cells on x / z (centred; the collider keeps its real size).
static func nav_thick(b: AABB) -> AABB:
	var out: AABB = b
	for ax: int in [0, 2]:
		if out.size[ax] < NAV_MIN:
			var c: float = out.position[ax] + out.size[ax] * 0.5
			out.position[ax] = c - NAV_MIN * 0.5
			out.size[ax] = NAV_MIN
	return out


# --- Map-built furniture art ---------------------------------------------------------------------


## The catalog art over each map-built box of PROP_ART (of_dress.gd art_mapbuilt): the greybox Mesh goes, the collider
## stays, nx x nz scaled copies of the asset fill the box (Visual, Visual2, ...). A cell within 3 % of the asset's
## footprint becomes a KitPlacer anchor of its room. The catalog props already in Props/MapBuilt (BoothDesk) anchor too.
func art_mapbuilt() -> void:
	var bodies: Array[Node] = []
	for grp: String in D.ART_GROUPS:
		var g: Node = _root.get_node_or_null(grp)
		if g == null:
			_err("no %s" % grp)
			continue
		bodies.append_array(g.get_children())
	for c: Node in bodies:
		var cat_asset: String = String(_scene_asset.get(c.scene_file_path, "")) if c.scene_file_path != "" else ""
		if cat_asset != "" and c is Node3D:
			_mapbuilt.append([c, cat_asset, _gx(c as Node3D), aabb(cat_asset).end.y])
			continue
		var body: StaticBody3D = c as StaticBody3D
		if body == null or not D.PROP_ART.has(String(body.name)):
			continue
		var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			_err("map-built %s has no box collider" % body.name)
			continue
		var art: Array = D.PROP_ART[String(body.name)]
		var asset: String = String(art[0])
		if not _cat.has(asset):
			_err("map-built %s: asset %s not in catalog" % [body.name, asset])
			continue
		var size: Vector3 = (cs.shape as BoxShape3D).size
		var mesh: Node = body.get_node_or_null("Mesh")
		if mesh != null:
			body.remove_child(mesh)
			mesh.free()
		body.set_meta(&"art_asset", asset)
		var ck: String = String((_cat[asset] as Dictionary).get("kind", ""))
		if ck != "" and ck != String(body.get_meta(&"kind", "")) and not ck in NO_RETAG:
			body.set_meta(&"layout_kind", body.get_meta(&"kind", ""))
			body.set_meta(&"kind", ck)
		SurfaceTags.tag(body, StringName(String((_cat[asset] as Dictionary).get("surface", ""))))
		_art_bodies += 1
		var nx: int = int(art[2])
		var nz: int = int(art[3])
		var cell: Vector2 = Vector2(size.x / float(nx), size.z / float(nz))
		var ab: AABB = aabb(asset)
		var i: int = 0
		for iz: int in range(nz):
			for ix: int in range(nx):
				var yaw: float = float(art[1]) + (180.0 if bool(art[4]) and iz % 2 == 1 else 0.0)
				var rot: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
				var turned: bool = absf(sin(deg_to_rad(yaw))) > 0.5
				var fx: float = ab.size.z if turned else ab.size.x
				var fz: float = ab.size.x if turned else ab.size.z
				var sx: float = cell.x / fx
				var sz: float = cell.y / fz
				var sy: float = 1.0 if bool(art[5]) else size.y / ab.size.y
				for s: float in [sx, sz, sy]:
					if s < ART_SCALE_MIN or s > ART_SCALE_MAX:
						report.append("WARN art %s: %s scaled %.2f / %.2f / %.2f" % [body.name, asset, sx, sy, sz])
						break
				var local_scale: Vector3 = Vector3(sz if turned else sx, sy, sx if turned else sz)
				var basis: Basis = rot * Basis.from_scale(local_scale)
				var centre: Vector3 = Vector3(-size.x * 0.5 + cell.x * (ix + 0.5), 0.0, -size.z * 0.5 + cell.y * (iz + 0.5))
				var ac: Vector3 = basis * Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
				var vis: Node3D = _art_visual(body, "Visual" if i == 0 else "Visual%d" % (i + 1), asset,
					Transform3D(basis, centre - ac))
				if vis != null and sx >= 0.97 and sz >= 0.97 and sx <= 1.3 and sz <= 1.3 and absf(sy - 1.0) <= 0.12:
					var wx: Transform3D = _gx(body) * Transform3D(rot, centre - rot * Vector3(ab.get_center().x, 0.0,
						ab.get_center().z))
					_mapbuilt.append([body, asset, wx, size.y])
				i += 1


## A catalog prop as a visual child of a map-built body; any collision it ships with is off (the layout collider stays
## the gameplay shape).
func _art_visual(body: Node3D, nm: String, asset: String, xf: Transform3D) -> Node3D:
	var ps: PackedScene = scene(asset)
	if ps == null:
		return null
	var vis: Node3D = ps.instantiate() as Node3D
	vis.name = nm
	vis.transform = xf
	body.add_child(vis)
	vis.owner = _root
	var shapes: Array[Node] = vis.find_children("*", "CollisionShape3D", true, false)
	if not shapes.is_empty():
		_root.set_editable_instance(vis, true)
		for m: Node in vis.find_children("*", "", true, false):
			if m.scene_file_path != "":
				_root.set_editable_instance(m, true)
		for co: Node in vis.find_children("*", "CollisionObject3D", true, false):
			(co as CollisionObject3D).collision_layer = 0
		for s: Node in shapes:
			(s as CollisionShape3D).disabled = true
	return vis


# --- Kit rooms ----------------------------------------------------------------------------------

func _dress_room(room: KitRoom, world_box: AABB, id: String, kit_id: String, props_root: Node3D) -> void:
	var kit: DressingKit = load(KITS_DIR + kit_id + ".tres") as DressingKit
	if kit == null:
		_err("%s: kit %s not found" % [id, kit_id])
		return
	_add_keepouts(room, world_box, id)
	var nv: int = 0
	var virtual_kinds: Dictionary = {}
	for mb: Array in _mapbuilt:
		var wx: Transform3D = mb[2]
		var c: Vector3 = wx.origin
		if c.x < world_box.position.x or c.x > world_box.end.x or c.z < world_box.position.z or c.z > world_box.end.z:
			continue
		if c.y < world_box.position.y - 0.3 or c.y > world_box.position.y + 1.0:
			continue
		var ax: Transform3D = wx
		var top: float = float((_cat[String(mb[1])] as Dictionary).get("top", 0.0))
		if top <= 0.0:
			top = aabb(String(mb[1])).end.y
		var lift: float = float(mb[3]) - top
		if lift > 0.0005 and lift <= 0.12:
			ax.origin.y += lift
		room.add_anchor(ax, StringName(String(mb[1])))
		virtual_kinds[String((_cat[String(mb[1])] as Dictionary).get("kind", ""))] = true
		nv += 1
	for sc: Array in _seat_chairs:
		var sp: Vector3 = (sc[0] as Transform3D).origin
		if world_box.grow(0.05).has_point(sp + Vector3.UP * 0.1):
			room.add_anchor(sc[0], StringName(String(sc[1])))
			virtual_kinds["chair"] = true
			nv += 1
	var seed: int = int(D.KIT_SEEDS.get(id, 7100))
	var res: Dictionary = KitPlacer.place(room, kit, seed, not D.NO_CEILING_GRID.has(id))
	var all: Array = res["placements"]
	var kept: Array = []
	for i: int in range(nv, all.size()):
		var pd: Dictionary = (all[i] as Dictionary).duplicate()
		pd["scene"] = near_scene_path(String(pd["asset"]), String(pd["scene"]))
		var f: int = int(pd.get("faces", -1))
		pd["faces"] = f - nv if f >= nv else -1
		var h: int = int(pd.get("host", -1))
		pd["host"] = h - nv if h >= nv else -1
		kept.append(pd)
	var parent: Node3D = _folder(props_root, id.replace("-", ""))
	var nodes: Array[Node3D] = KitPlacer.instantiate({"placements": kept}, parent, _root)
	for i: int in range(nodes.size()):
		var p: Dictionary = kept[i]
		_finish_node(nodes[i], String(p["asset"]), String(p["mode"]), String(p["mount"]), p["xform"])
		if String(p["mount"]) == "" and String(p["mode"]) != "ceiling":   # the fixed-table props keep off it
			_placed_ext.append((p["xform"] as Transform3D) * aabb(String(p["asset"])))
	counts[id] = nodes.size()
	var missing: PackedStringArray = PackedStringArray()
	var present: Dictionary = _mapbuilt_kinds_in(world_box)
	for mk: String in res["missing"]:
		if not present.has(mk) and not virtual_kinds.has(mk):
			missing.append(mk)
	var warnings: PackedStringArray = res["warnings"]
	report.append("%s (%s, seed %d, hash %s): %d props + %d anchors%s%s" % [id, kit_id, seed,
		String(res.get("hash", "")).left(8), nodes.size(), nv,
		"" if missing.is_empty() else ", MISSING " + ",".join(missing),
		"" if warnings.is_empty() else ", warnings: " + "; ".join(warnings)])
	if not missing.is_empty():
		report.append("WARN %s: required kinds not placed: %s" % [id, ",".join(missing)])


## Kinds of the map-built props and the gameplay prefabs inside a box (a kind the map already provides).
func _mapbuilt_kinds_in(world_box: AABB) -> Dictionary:
	var out: Dictionary = {}
	var probe: AABB = world_box.grow(0.05)
	for top: String in ["Props/MapBuilt", "Gameplay"]:
		var mb: Node = _root.get_node_or_null(top)
		if mb == null:
			continue
		for c: Node in mb.find_children("*", "Node3D", true, false):
			var n3: Node3D = c as Node3D
			if n3 == null or not n3.has_meta(&"kind") or not probe.has_point(_gx(n3).origin + Vector3.UP * 0.1):
				continue
			out[String(n3.get_meta(&"kind", ""))] = true
			if n3.has_meta(&"art_asset"):
				out[String((_cat.get(String(n3.get_meta(&"art_asset")), {}) as Dictionary).get("kind", ""))] = true
	return out


## [KitRoom, world AABB of the clear interior] for a RoomVolume: its largest box inside its walls' faces, floor to
## ceiling; the doors and the wall openings (door-height holes, windows) on its outline; edges with no wall at all are
## open (no wall mounts there, a keep-out band).
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
		_err("%s: room has no box" % rid)
		return []
	var y: float = best.position.y
	var x0: float = best.position.x
	var z0: float = best.position.z
	var x1: float = best.end.x
	var z1: float = best.end.z
	var lo: Vector3 = Vector3(x0 + half_t(y, "z", x0, z0, z1), y, z0 + half_t(y, "x", z0, x0, x1))
	var hi: Vector3 = Vector3(x1 - half_t(y, "z", x1, z0, z1), best.end.y, z1 - half_t(y, "x", z1, x0, x1))
	var clear: AABB = AABB(lo, hi - lo)
	var room: KitRoom = KitRoom.from_aabb(clear, StringName(rid))
	# KitRoom walls: 0 north (z0), 1 east (x1), 2 south (z1), 3 west (x0)
	var edges: Array = [["x", z0, x0, x1], ["z", x1, z0, z1], ["x", z1, x0, x1], ["z", x0, z0, z1]]
	for w: int in range(4):
		var e: Array = edges[w]
		var any: bool = false
		for sg: Array in edge_walls(y, String(e[0]), float(e[1]), float(e[2]), float(e[3]), MOUNT_WALL):
			if float(sg[2]) > 0.0:
				any = true
		room.walls[w] = any  # a wall lower than MOUNT_WALL (the yard's 2.4 m walls) takes no mounts
	_thick_keepouts(room, y, x0, z0, x1, z1, lo, hi)
	var rect: Rect2 = Rect2(x0, z0, x1 - x0, z1 - z0)
	for d: Array in _doors:
		var pos: Vector3 = d[0]
		if absf(pos.y - y) < 0.3 and _on_rect_edge(rect, pos, absf(sin(deg_to_rad(float(d[1])))) < 0.5):
			room.add_door(pos, float(d[2]), -1.0, minf(2.6, hi.y - y))
	for w2: Array in L.WALLS:
		if not _wall_spans(w2, y):
			continue
		var along_x: bool = String(w2[1]) == "x"
		for hl: Array in w2[9]:
			if float(hl[3]) <= y + 0.05 or float(hl[2]) >= best.end.y:
				continue
			var mid: Vector3 = Vector3((float(hl[0]) + float(hl[1])) * 0.5, y, float(w2[2])) if along_x \
				else Vector3(float(w2[2]), y, (float(hl[0]) + float(hl[1])) * 0.5)
			if not _on_rect_edge(rect, mid, along_x):
				continue
			var a0: float = maxf(float(hl[0]), x0 if along_x else z0)
			var a1: float = minf(float(hl[1]), x1 if along_x else z1)
			if a1 - a0 < 0.1:
				continue
			mid = Vector3((a0 + a1) * 0.5, y, float(w2[2])) if along_x else Vector3(float(w2[2]), y, (a0 + a1) * 0.5)
			var sill: float = float(hl[2]) - y
			var head: float = minf(float(hl[3]) - y, clear.size.y)
			if sill <= 0.05:
				room.add_door(mid, a1 - a0, 1.0, head)
			else:
				room.add_window(mid + Vector3.UP * sill, a1 - a0 + 0.1, sill, head)
	return [room, clear]


## True when wall row `w` stands on the floor at `y` (its runs span y .. y + `h`).
static func _wall_spans(w: Array, y: float, h: float = 1.0) -> bool:
	return float(w[6]) <= y + 0.05 and float(w[7]) >= y + h


## The wall stretches on a room edge (axis "x": runs along x at z = fixed) of the floor at `y` within [a0, a1]:
## [[from, to, thickness], ...] (thickness 0: no wall there, an open edge).
func edge_walls(y: float, axis: String, fixed: float, a0: float, a1: float, h: float = 1.0) -> Array:
	var segs: Array = []
	for w: Array in L.WALLS:
		if not _wall_spans(w, y, h) or String(w[1]) != axis or absf(float(w[2]) - fixed) > 0.001:
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
		if not out.is_empty() and absf(float(out[-1][2]) - t) < 0.001 and absf(float(out[-1][1]) - p) < 0.0001:
			out[-1][1] = q
		else:
			out.append([p, q, t])
	return out


## Half the thinnest wall on a room edge (its clear rect), 0.1 m by default.
func half_t(y: float, axis: String, fixed: float, a0: float, a1: float) -> float:
	var t: float = INF
	for sg: Array in edge_walls(y, axis, fixed, a0, a1):
		if float(sg[2]) > 0.0:
			t = minf(t, float(sg[2]))
	return 0.1 if t == INF else t * 0.5


## Keep-outs where a room edge's wall is thicker than its clear rect assumes, and a band along the open stretches.
func _thick_keepouts(room: KitRoom, y: float, x0: float, z0: float, x1: float, z1: float, lo: Vector3, hi: Vector3) -> void:
	for e: Array in [["x", z0, 1.0, lo.z, x0, x1], ["x", z1, -1.0, hi.z, x0, x1], ["z", x0, 1.0, lo.x, z0, z1],
			["z", x1, -1.0, hi.x, z0, z1]]:
		var sgn: float = float(e[2])
		for sg: Array in edge_walls(y, String(e[0]), float(e[1]), float(e[4]), float(e[5])):
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
		room.add_keep_out(_marker_box(m))
	for k: Variant in D.KEEP_OUT.get(id, []):
		var b2: Array = k
		room.add_keep_out(AABB(Vector3(float(b2[0]), float(b2[1]), float(b2[2])),
			Vector3(float(b2[3]) - float(b2[0]), float(b2[4]) - float(b2[1]), float(b2[5]) - float(b2[2]))))


static func _marker_box(m: Vector3) -> AABB:
	return AABB(Vector3(m.x - MARKER_HALF, m.y - 0.05, m.z - MARKER_HALF), Vector3(MARKER_HALF * 2.0, 2.0, MARKER_HALF * 2.0))


## Everything the dressing must leave alone (of_dress.gd _collect): gameplay prefabs (collision + visual) and their use
## points, door prefabs, spawns / patrol / tactical / preplan / line markers, nav-link ends, every catalog scene already
## in the map (seat chairs, the booth desk), the map-built boxes, the shell and site boxes and the review cameras'
## standpoints.
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
	for n4: Node in _root.find_children("*", "Node3D", true, false):
		if n4.scene_file_path == "" or not _scene_asset.has(n4.scene_file_path):
			continue
		if n4.get_parent() != null and n4.get_parent().has_meta(&"art_asset"):
			continue  # a map-built body's art cell: its body's collider is the keep-out
		var asset: String = String(_scene_asset[n4.scene_file_path])
		var wx4: Transform3D = _gx(n4 as Node3D)
		if String((_cat[asset] as Dictionary).get("kind", "")) == "chair" and not _under(n4, "Props"):
			_seat_chairs.append([wx4, asset])
			_boxes.append((wx4 * aabb(asset)).grow(0.45))
		else:
			var kb0: AABB = (wx4 * aabb(asset)).grow(0.03)
			if bool((_cat[asset] as Dictionary).get("support", false)):  # "on" items still sit on its top
				kb0.size.y = maxf(0.05, kb0.size.y - 0.06)
			_boxes.append(kb0)
	var mbn: Node = _root.get_node_or_null("Props/MapBuilt")
	if mbn != null:
		for p: Node in mbn.get_children():
			for cs: Node in p.find_children("*", "CollisionShape3D", true, false):
				var bs: BoxShape3D = (cs as CollisionShape3D).shape as BoxShape3D
				if bs == null or (cs as CollisionShape3D).disabled:
					continue
				var kb: AABB = (_gx(cs as Node3D) * AABB(-bs.size * 0.5, bs.size)).grow(0.01)
				if (p as Node3D).has_meta(&"art_asset"):
					kb.size.y = maxf(0.05, kb.size.y - 0.03)
				_boxes.append(kb)
	for s: Array in L.SHELL_BOXES:
		var lo: Vector3 = _v3(s[2])
		var hi: Vector3 = _v3(s[3])
		_boxes.append(AABB(lo, hi - lo).grow(0.15))
	for s2: Array in L.SITE_BOXES:
		if String(s2[0]) == "Grade":
			continue
		var lo2: Vector3 = _v3(s2[2])
		var hi2: Vector3 = _v3(s2[3])
		_boxes.append(AABB(lo2, hi2 - lo2).grow(0.1))
	for cam: Array in LC.REVIEW_CAMERAS:
		var cp: Vector3 = _v3(cam[2])
		if cp.y > 40.0:
			continue
		_boxes.append(AABB(cp - Vector3(0.5, 1.75, 0.5), Vector3(1.0, 2.1, 1.0)))


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
		var handle: Node3D = pf.get_node_or_null("Interactable") as Node3D
		_doors.append([xf2.origin, yaw, wd if wd > 0.0 else 0.9, _gx(handle).origin if handle != null else xf2.origin])
		# the door's two approaches (1.2 m each side, the leaf's width + 0.6) stay clear of street furniture too
		var dw: float = (wd if wd > 0.0 else 0.9) + 0.6
		_door_boxes.append(xf2 * AABB(Vector3(-dw * 0.5, 0.0, -1.2), Vector3(dw, 2.2, 2.4)))
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
		var asset: String = String(_scene_asset.get(vs.resource_path, vs.resource_path.get_file().get_basename()))
		if _cat.has(asset):
			var vb: AABB = xf2 * aabb(asset)
			box = vb if first else box.merge(vb)
			first = false
	if first:
		box = AABB(xf2.origin - Vector3(0.15, 0.0, 0.15), Vector3(0.3, 0.3, 0.3))
	_boxes.append(box.grow(0.05))


## G2 density: every gameplay / variant prefab root without a `kind` takes its prefab id (as of_dress.gd).
func _tag_prefab_kinds() -> void:
	for top: String in ["Gameplay", "Variants"]:
		var t: Node = _root.get_node_or_null(top)
		if t == null:
			continue
		for n: Node in t.find_children("*", "Node3D", true, false):
			if not ("visual_scene" in n) or n.has_meta(&"kind") or n.get_script() == null:
				continue
			n.set_meta(&"kind", (n.get_script() as Script).resource_path.get_base_dir().get_file())


# --- Exteriors ----------------------------------------------------------------------------------

## The sidewalk rows (D.ROWS): each item's slots along the run; a slot meeting a keep-out is skipped (reported).
func _rows(parent: Node3D) -> void:
	var placed: int = 0
	var skipped: PackedStringArray = []
	for r: Array in D.ROWS:
		var a: Vector3 = _v3(r[2])
		var b: Vector3 = _v3(r[3])
		var run: Vector3 = b - a
		var length: float = run.length()
		var dir: Vector3 = run / maxf(length, 0.001)
		var left: Vector3 = Vector3(dir.z, 0.0, -dir.x)
		var folder: Node3D = _folder(parent, String(r[1]))
		for it: Array in r[5]:
			var asset: String = String(it[0])
			for i: int in range(int(it[3])):
				var s: float = float(it[1]) + float(it[2]) * float(i)
				if s > length:
					break
				var pos: Vector3 = a + dir * s + left * float(it[4])
				var nm: String = "%s%d" % [String(_cat.get(asset, {}).get("kind", "prop")).to_pascal_case(), i]
				if _place_ext(folder, nm, asset, pos, float(r[4]), {}):
					placed += 1
				else:
					skipped.append("%s/%s" % [r[1], nm])
	counts["Streets"] = placed
	report.append("streets: %d props%s" % [placed, "" if skipped.is_empty() else ", skipped (keep-outs): "
		+ ", ".join(skipped)])


func _direct_props(parent: Node3D) -> void:
	var placed: int = 0
	var skipped: PackedStringArray = []
	for d: Array in D.DIRECT_PROPS:
		if _place_ext(parent, String(d[0]), String(d[1]), d[2], float(d[3]), d[4]):
			placed += 1
		else:
			skipped.append(String(d[0]))
	counts["Direct"] = placed
	report.append("direct: %d props%s" % [placed, "" if skipped.is_empty() else ", skipped (keep-outs): "
		+ ", ".join(skipped)])


## One exterior prop if its footprint is clear of every keep-out and earlier exterior prop (mounts and ceiling items:
## of earlier props only).
func _place_ext(parent: Node3D, nm: String, asset: String, pos: Vector3, yaw: float, metas: Dictionary) -> bool:
	if not _cat.has(asset):
		_err("exterior: asset %s not in catalog" % asset)
		return false
	var cat: Dictionary = _cat[asset]
	var xf: Transform3D = _anchor_xform(asset, pos, yaw)
	var fp: AABB = xf * aabb(asset)
	var mounted: bool = String(cat.get("mount", "")) != ""
	if String(cat.get("kind", "")) in POLE_KINDS:
		var bb0: AABB = aabb(asset)
		fp = xf * AABB(Vector3(bb0.position.x, bb0.position.y, -bb0.size.x * 0.5), Vector3(bb0.size.x, 2.2, bb0.size.x))
	elif POLE_OFF.has(String(cat.get("kind", ""))):
		fp = xf * _pole_box(POLE_OFF[String(cat.get("kind", ""))])
	var probe: AABB = fp.grow(0.05)
	for e: AABB in _placed_ext:
		if e.intersects(probe):
			return false
	if not mounted:
		for b: AABB in _boxes + _door_boxes:
			if b.intersects(probe):
				return false
		for m: Vector3 in _markers:
			if _marker_box(m).intersects(probe):
				return false
	var ps: PackedScene = scene(asset)
	if ps == null:
		return false
	var nd: Node3D = ps.instantiate() as Node3D
	nd.name = nm
	nd.transform = xf
	for k: Variant in metas:
		nd.set_meta(StringName(String(k)), metas[k])
	if not nd.has_meta(&"kind"):
		nd.set_meta(&"kind", String(cat.get("kind", "")))
	parent.add_child(nd)
	nd.owner = _root
	_finish_node(nd, asset, String(cat.get("place", "floor")), String(cat.get("mount", "")), xf)
	_placed_ext.append(fp)
	return true


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


## Collider + navmesh obstruction for floor props (not mounts, "on" items or ceiling fixtures); the obstruction is no
## thinner than two nav cells (a bollard, a lamp pole).
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
	if kind in POLE_KINDS:  # the pole only: the arm overhangs the road at 5 m
		bb = AABB(Vector3(bb.position.x, bb.position.y, -bb.size.x * 0.5), Vector3(bb.size.x, bb.size.y, bb.size.x))
	elif POLE_OFF.has(kind):  # the signal's pole only: its mast arm overhangs the carriageway at 5.2 m
		bb = _pole_box(POLE_OFF[kind])
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
	_b.call(&"obstruct", xf, nav_thick(bb))


## A pole's box [centre x, radius, height] (prop-local).
static func _pole_box(pole: Array) -> AABB:
	var r: float = float(pole[1])
	return AABB(Vector3(float(pole[0]) - r, 0.0, -r), Vector3(r * 2.0, float(pole[2]), r * 2.0))


## The landmark visuals (D.LANDMARKS): no collider, no obstruction, no keep-out test; the listed G1 boxes lose their
## greybox Mesh (their colliders stay; ah_finish.gd then leaves them alone).
func _landmarks() -> void:
	for lm: Array in D.LANDMARKS:
		var ps: PackedScene = scene(String(lm[1]))
		var parent: Node3D = _root.get_node_or_null(String(lm[2])) as Node3D
		if ps == null or parent == null:
			_err("landmark %s: no scene or parent %s" % [lm[0], lm[2]])
			continue
		var nd: Node3D = ps.instantiate() as Node3D
		nd.name = String(lm[0])
		nd.transform = _gx(parent).affine_inverse() * Transform3D(Basis(Vector3.UP, deg_to_rad(float(lm[4]))), lm[3])
		parent.add_child(nd)
		nd.owner = _root
		if String((_cat[String(lm[1])] as Dictionary).get("kind", "")) in NO_SHADOW_KINDS:
			_root.set_editable_instance(nd, true)
			for gi: Node in nd.find_children("*", "GeometryInstance3D", true, false):
				(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for path: Variant in lm[5]:
			var mesh: Node = _root.get_node_or_null(String(path) + "/Mesh")
			if mesh == null:
				_err("landmark %s: no %s/Mesh" % [lm[0], path])
				continue
			mesh.get_parent().set_meta(&"art_asset", String(lm[1]))
			mesh.get_parent().remove_child(mesh)
			mesh.free()
	counts["Landmarks"] = D.LANDMARKS.size()


# --- Orientation links --------------------------------------------------------------------------

## `faces` links (levelcheck orientation, of_dress.gd _link_faces): every chair in a dressed room without one looks at
## the nearest desk / table within 1 m when it faces it within 15 deg, else at an `Aim` marker where its front ray meets
## that desk's footprint; every monitor looks at the nearest chair in front of it (18 deg).
func _link_faces() -> void:
	var chairs: Array[Node3D] = []
	var targets: Array[Node3D] = []
	var monitors: Array[Node3D] = []
	for top: String in ["Props", "Spawns"]:
		for n: Node in _root.get_node(top).find_children("*", "Node3D", true, false):
			var n3: Node3D = n as Node3D
			if n3 == null:
				continue
			if n3.get_parent() != null and n3.get_parent().has_meta(&"art_asset"):
				continue
			var k: String = String(n3.get_meta(&"kind", ""))
			if k == "" and n3.scene_file_path != "" and _scene_asset.has(n3.scene_file_path):
				k = String((_cat[String(_scene_asset[n3.scene_file_path])] as Dictionary).get("kind", ""))
			if k == "chair" or k == "stool":
				chairs.append(n3)
			elif k in SEAT_TARGETS:
				targets.append(n3)
			elif k == "monitor":
				monitors.append(n3)
	for c: Node3D in chairs:
		if c.has_meta(&"faces"):
			continue
		var cx: Transform3D = _gx(c)
		var best: Node3D = null
		var best_d: float = INF
		for t: Node3D in targets:
			var ft: AABB = _footprint(t)
			if absf(ft.position.y - cx.origin.y) > 0.5:
				continue
			# 1.3 m from the chair's origin: levelcheck's 1.0 m is from its footprint (U9's visitor chair, G3)
			if not ft.grow(1.3).has_point(Vector3(cx.origin.x, ft.position.y + 0.01, cx.origin.z)):
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
			continue
		var hit: float = -1.0
		for i: int in range(1, 50):
			var q: Vector3 = cx.origin + fwd * (0.05 * float(i))
			if q.x > fb.position.x + 0.05 and q.x < fb.end.x - 0.05 and q.z > fb.position.z + 0.05 and q.z < fb.end.z - 0.05:
				hit = 0.05 * float(i) + 0.15
				break
		if hit < 0.0:
			report.append("WARN chair %s: its front misses %s" % [_root.get_path_to(c), best.name])
			continue
		var aim: Marker3D = Marker3D.new()
		aim.name = String(c.name) + "Aim"
		var par: Node3D = c.get_parent() as Node3D
		aim.transform = Transform3D(Basis.IDENTITY, _gx(par).affine_inverse() * (cx.origin + fwd * hit + Vector3.UP * 0.75))
		par.add_child(aim)
		aim.owner = _root
		c.set_meta(&"faces", c.get_path_to(aim))
	for m: Node3D in monitors:
		if m.has_meta(&"faces"):
			continue
		var mx: Transform3D = _gx(m)
		var front: Vector3 = -mx.basis.z
		front.y = 0.0
		var pick: Node3D = null
		var pick_d: float = INF
		for c2: Node3D in chairs:
			var to2: Vector3 = _gx(c2).origin - mx.origin
			to2.y = 0.0
			if to2.length() < 0.05 or to2.length() > 2.5 or front.normalized().dot(to2.normalized()) < cos(deg_to_rad(18.0)):
				continue
			if to2.length() < pick_d:
				pick_d = to2.length()
				pick = c2
		if pick == null:  # a monitor on a map-built desk: turn it (about its pivot) to the desk's chair within 45 deg
			for c3: Node3D in chairs:
				var to3: Vector3 = _gx(c3).origin - mx.origin
				to3.y = 0.0
				if to3.length() > 0.05 and to3.length() <= 1.5 and front.normalized().dot(to3.normalized()) >= cos(deg_to_rad(45.0)):
					var turn: float = Vector2(front.x, front.z).angle_to(Vector2(to3.x, to3.z))
					m.rotate_y(-turn)
					pick = c3
					break
		if pick != null:
			m.set_meta(&"faces", m.get_path_to(pick))


## The floor footprint (world AABB) of a prop node: its box collider, else its catalog visual.
func _footprint(n: Node3D) -> AABB:
	var cs: CollisionShape3D = n.get_node_or_null("Collision") as CollisionShape3D
	if cs == null:
		cs = n.get_node_or_null("Collision/Shape") as CollisionShape3D
	if cs != null and cs.shape is BoxShape3D:
		var bs: Vector3 = (cs.shape as BoxShape3D).size
		return _gx(cs) * AABB(-bs * 0.5, bs)
	var asset: String = String(_scene_asset.get(n.scene_file_path, n.get_meta(&"art_asset", "")))
	if _cat.has(asset):
		return _gx(n) * aabb(asset)
	return AABB(_gx(n).origin - Vector3(0.3, 0.0, 0.3), Vector3(0.6, 0.75, 0.6))
