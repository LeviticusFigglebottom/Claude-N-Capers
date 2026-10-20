## Ostrander Federal G2 dressing, lane C (OF-C2, ENV C): every kit room outside lanes A / B (the offices, BOH, the
## basement, the vault VT and concourse VC, the corridors, the gallery GA, the executive level), the map-built
## furniture's catalog art in those rooms, the exteriors X2-X5 and the stairs (direct props), fill lights, the Audio
## node (CuePlayer, MusicDirector, the four OF beds) and the burn-through set piece (of_burn.gd). Registered by ONE line
## in build_greybox.gd (before the navmesh bake: placed floor props obstruct it, as Shadow Ledger's sl_dress.gd).
## A cell up to 30 % larger than the asset still anchors (its "on" items stay inside the real top).
## The KitPlacer pass follows sl_dress.gd: every gameplay prefab, use point, door swing, marker, nav-link end, shell box
## (the counter, cages, pillars, the gallery guard, glazing), map-built prop, other-lane prop and review-camera standpoint
## is a keep-out, plus the room keep-outs of of_dress_data.gd. Placed floor props get a box collider and a navmesh
## obstruction. Never moves a G1 contract node. Data: of_dress_data.gd.
extends RefCounted

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095)
const L: GDScript = preload("res://world/heists/ostrander_federal/greybox/ostrander_federal_layout.gd")
const LC: GDScript = preload("res://world/heists/ostrander_federal/greybox/ostrander_federal_layout_content.gd")
const D: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_dress_data.gd")
const BURN: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_burn.gd")
const CATALOG_PATH: String = "res://world/props/prop_catalog.json"
const KITS_DIR: String = "res://world/kits/"
const AUDIO_BUILDER: String = "res://world/audio/map_audio_builder.gd"
## Half size of the keep-out kept around every floor marker (spawn, patrol, use point...).
const MARKER_HALF: float = 0.35
const EXIT_SIGN_Z: float = 2.36
## Interior kit props draw to this distance (as SL / GN near-range wrappers; no OF room is deeper than ~32 m).
const INTERIOR_VIS: float = 34.0
## [largest extent below (m), visibility range (m)]: the size bands of _near_range.
const NEAR_RANGES: Array[Array] = [[0.35, 10.0], [0.8, 16.0], [1.6, 24.0]]
const NEAR_DIR: String = "res://world/heists/ostrander_federal/art/props_near/"
## Depth of the keep-out band along a room edge without a wall (an open loggia / gallery edge).
const OPEN_EDGE: float = 0.4
## The props folder this lane owns under Props, the fill folder under Lighting.
const FOLDER: String = "DressC"
const FILL_FOLDER: String = "FillC"
## Scale window for the map-built art cells (outside it the cell is still built, with a warning).
## Catalog kinds the art never retags its body to (plumbing is checked against the body's own frame).
const NO_RETAG: Array[String] = ["sink", "toilet", "urinal"]
## Kinds a chair sits at (levelcheck orientation SEAT_TARGET_KINDS).
const SEAT_TARGETS: Array[String] = ["desk", "table", "counter_service", "counter_transaction", "coffee_table",
	"check_table", "counter_bar", "cocktail_table"]
## Kinds whose collider and nav obstruction is the pole at the pivot (a lamp's arm overhangs at head height).
const POLE_KINDS: Array[String] = ["street_lamp", "lamp_post"]
const ART_SCALE_MIN: float = 0.55
const ART_SCALE_MAX: float = 1.6
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
## Map-built supports in lane C rooms with catalog art: [body, asset, world transform of the cell (unscaled)].
var _mapbuilt: Array[Array] = []
var _room_nodes: Dictionary = {}
## Seated spawns' chairs (catalog chairs outside Props): [world transform, asset].
var _seat_chairs: Array[Array] = []
## Map-built bodies given catalog art (art_mapbuilt).
var _art_bodies: int = 0


## The one call build_greybox.gd makes (OF-C2 lane C). `builder` is the generator (map_root, errors, obstruct()).
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
	for d: Array in D.DIRECT_PROPS:  # the direct props are placed after the kits: keep the kits off them
		if _cat.has(String(d[1])):
			_boxes.append((_anchor_xform(String(d[1]), d[2], float(d[3])) * aabb(String(d[1]))).grow(0.02))
	for rv: Node in _root.get_node("Rooms").get_children():
		var room: RoomVolume = rv as RoomVolume
		if room == null or not _mine(room):
			continue
		var res: Array = _interior_room(room)
		if res.is_empty():
			continue
		_dress_room(res[0], res[1], String(room.room_id), String(room.dressing_kit), props)
	_direct_props(_folder(props, "Direct"))
	_shadow_fixtures()
	_link_faces()
	fill_lights(_folder(_root.get_node("Lighting") as Node3D, FILL_FOLDER))
	_audio()
	var burn: RefCounted = BURN.new()
	burn.call(&"build", _b, _root)
	report.append_array(burn.get(&"report"))
	var total: int = 0
	for k: String in counts:
		total += int(counts[k])
	report.append("lane C: %d kit props in %d rooms, %d map-built art bodies" % [total, counts.size(), _art_bodies])
	for line: String in report:
		printerr("dress C: " + line)
		if line.begins_with("ERROR"):
			var errs: PackedStringArray = _b.get(&"errors")
			errs.append(line)
			_b.set(&"errors", errs)


func _err(msg: String) -> void:
	report.append("ERROR " + msg)


static func _mine(room: RoomVolume) -> bool:
	var id: String = String(room.room_id)
	return String(room.dressing_kit) != "" and String(room.purpose) != "exterior" and not D.OTHER_LANES.has(id)


func scene(asset: String) -> PackedScene:
	if _scenes.has(asset):
		return _scenes[asset]
	var ps: PackedScene = null
	if _cat.has(asset):
		ps = load(near_scene_path(asset, String((_cat[asset] as Dictionary)["scene"]))) as PackedScene
	if ps == null:
		_err("no scene for asset %s" % asset)
	_scenes[asset] = ps
	return ps


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


# --- Map-built furniture art ---------------------------------------------------------------------


## The catalog art over each lane-C map-built box (PROP_ART): the greybox Mesh goes, the collider stays, nx x nz
## scaled copies of the asset fill the box (Visual, Visual2, ...). A cell within 3 % of the asset's footprint becomes
## a KitPlacer anchor of its room (its "on" items rest on the box top).
func art_mapbuilt() -> void:
	var mb: Node = _root.get_node_or_null("Props/MapBuilt")
	if mb == null:
		_err("no Props/MapBuilt")
		return
	for c: Node in mb.get_children():
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
		if ck != "" and ck != String(body.get_meta(&"kind", "")) and not ck in NO_RETAG:  # levelcheck reads the catalog kind
			body.set_meta(&"layout_kind", body.get_meta(&"kind", ""))
			body.set_meta(&"kind", ck)
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
				var fx: float = ab.size.z if turned else ab.size.x  # footprint along box x / z after the yaw
				var fz: float = ab.size.x if turned else ab.size.z
				var sx: float = cell.x / fx
				var sz: float = cell.y / fz
				var sy: float = 1.0 if art.size() > 5 and bool(art[5]) else size.y / ab.size.y
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


## A catalog prop's near-range wrapper as a visual child of a map-built body; any collision it ships with is off (the
## layout collider stays the gameplay shape).
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


# --- Rooms ------------------------------------------------------------------------------------

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
		if lift > 0.0005 and lift <= 0.12:  # the "on" items rest on the box top (the art is scaled to it)
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
	var seed: int = int(D.KIT_SEEDS.get(id, 7000))
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
	var parent: Node3D = _folder(props_root, id)
	var nodes: Array[Node3D] = KitPlacer.instantiate({"placements": kept}, parent, _root)
	for i: int in range(nodes.size()):
		var p: Dictionary = kept[i]
		_finish_node(nodes[i], String(p["asset"]), String(p["mode"]), String(p["mount"]), p["xform"])
	_room_nodes[id] = nodes
	counts[id] = nodes.size()
	for n: Node3D in nodes:
		_tweak_light(n, D.LIGHT_TWEAKS.get(id, {}))
	var missing: PackedStringArray = PackedStringArray()
	var present: Dictionary = _mapbuilt_kinds_in(room, world_box)
	for mk: String in res["missing"]:
		if not present.has(mk) and not virtual_kinds.has(mk):
			missing.append(mk)
	var warnings: PackedStringArray = res["warnings"]
	report.append("%s (%s, seed %d, hash %s): %d props + %d map-built%s%s" % [id, kit_id, seed,
		String(res.get("hash", "")).left(8), nodes.size(), nv,
		"" if missing.is_empty() else ", MISSING " + ",".join(missing),
		"" if warnings.is_empty() else ", warnings: " + "; ".join(warnings)])
	if not missing.is_empty():
		report.append("WARN %s: required kinds not placed: %s" % [id, ",".join(missing)])


## Kinds of the map-built props (any lane) inside the room's box (a kind the map already provides).
func _mapbuilt_kinds_in(_room: KitRoom, world_box: AABB) -> Dictionary:
	var out: Dictionary = {}
	var mb: Node = _root.get_node_or_null("Props/MapBuilt")
	if mb == null:
		return out
	var probe: AABB = world_box.grow(0.05)
	for c: Node in mb.get_children():
		var n3: Node3D = c as Node3D
		if n3 != null and probe.has_point(_gx(n3).origin + Vector3.UP * 0.1):
			out[String(n3.get_meta(&"kind", ""))] = true
			if n3.has_meta(&"art_asset"):
				out[String((_cat.get(String(n3.get_meta(&"art_asset")), {}) as Dictionary).get("kind", ""))] = true
	return out


## [KitRoom, world AABB of the clear interior] for a RoomVolume: its largest box inside its walls' faces, floor to
## ceiling; the doors and the wall openings (door-height holes, windows) on its outline.
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
	for w: Array in L.WALLS:
		if String(w[0]) != lv:
			continue
		var along_x: bool = String(w[1]) == "x"
		for hl: Array in w[9]:
			var mid: Vector3 = Vector3((float(hl[0]) + float(hl[1])) * 0.5, y, float(w[2])) if along_x \
				else Vector3(float(w[2]), y, (float(hl[0]) + float(hl[1])) * 0.5)
			if not _on_rect_edge(rect, mid, along_x):
				continue
			var a0: float = maxf(float(hl[0]), x0 if along_x else z0)
			var a1: float = minf(float(hl[1]), x1 if along_x else z1)
			if a1 - a0 < 0.1:
				continue
			mid = Vector3((a0 + a1) * 0.5, y, float(w[2])) if along_x else Vector3(float(w[2]), y, (a0 + a1) * 0.5)
			var sill: float = float(hl[2]) - y
			var head: float = minf(float(hl[3]) - y, clear.size.y)
			if sill <= 0.05:
				room.add_door(mid, a1 - a0, 1.0, head)
			else:
				room.add_window(mid + Vector3.UP * sill, a1 - a0 + 0.1, sill, head)
	return [room, clear]


func _level_of(y: float) -> String:
	var best: String = "B"
	for f: String in L.FLOORS:
		if y >= float(L.FFL[f]) - 0.5:
			best = f
	return best


## The wall stretches on a room edge (axis "x": runs along x at z = fixed) of level `lv` within [a0, a1]:
## [[from, to, thickness], ...] (thickness 0: no wall there, an open edge).
func edge_walls(lv: String, axis: String, fixed: float, a0: float, a1: float) -> Array:
	var segs: Array = []
	for w: Array in L.WALLS:
		if String(w[0]) != lv or String(w[1]) != axis or absf(float(w[2]) - fixed) > 0.001:
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


## Half the thinnest wall on a room edge (its clear rect), 0.1 m by default; thicker stretches become keep-outs.
func half_t(lv: String, axis: String, fixed: float, a0: float, a1: float) -> float:
	var t: float = INF
	for sg: Array in edge_walls(lv, axis, fixed, a0, a1):
		if float(sg[2]) > 0.0:
			t = minf(t, float(sg[2]))
	return 0.1 if t == INF else t * 0.5


## Keep-outs where a room edge's wall is thicker than its clear rect assumes, and a band along the open stretches.
func _thick_keepouts(room: KitRoom, lv: String, x0: float, z0: float, x1: float, z1: float, lo: Vector3, hi: Vector3) -> void:
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


## Everything the kits must leave alone: gameplay prefabs (collision + visual) and their use points, door prefabs,
## spawns / patrol / tactical / preplan / line markers, nav-link ends, every catalog scene already in the map (seat
## chairs, other lanes' props), the map-built boxes, the shell boxes inside rooms and the review cameras' standpoints.
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
	# catalog scenes anywhere outside the prefabs (seated spawns' chairs, other lanes' dressing)
	for n4: Node in _root.find_children("*", "Node3D", true, false):
		if n4.scene_file_path == "" or not _scene_asset.has(n4.scene_file_path):
			continue
		var asset: String = String(_scene_asset[n4.scene_file_path])
		var wx4: Transform3D = _gx(n4 as Node3D)
		if String((_cat[asset] as Dictionary).get("kind", "")) == "chair" and not _under(n4, "Props"):
			# a seated spawn's chair: the room's chair (a kit anchor) and its pull-out space stays clear
			_seat_chairs.append([wx4, asset])
			_boxes.append((wx4 * aabb(asset)).grow(0.45))
		else:
			_boxes.append((wx4 * aabb(asset)).grow(0.03))
	var mbn: Node = _root.get_node_or_null("Props/MapBuilt")
	if mbn != null:
		for p: Node in mbn.get_children():
			for cs: Node in p.find_children("*", "CollisionShape3D", true, false):
				var bs: BoxShape3D = (cs as CollisionShape3D).shape as BoxShape3D
				if bs == null:
					continue
				var kb: AABB = (_gx(cs as Node3D) * AABB(-bs.size * 0.5, bs.size)).grow(0.01)
				if (p as Node3D).has_meta(&"art_asset"):  # 3 cm below its top so "on" items still sit on it
					kb.size.y = maxf(0.05, kb.size.y - 0.03)
				_boxes.append(kb)
	for s: Array in L.SHELL_BOXES:
		var lo: Vector3 = _v3(s[2])
		var hi: Vector3 = _v3(s[3])
		_boxes.append(AABB(lo, hi - lo).grow(0.15))
	for cam: Array in LC.REVIEW_CAMERAS:
		if String(cam[0]).begins_with("TopDown"):
			continue
		var cp: Vector3 = _v3(cam[2])
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


## G2 density: every gameplay / variant prefab root without a `kind` takes its prefab id (as sl_dress.gd).
func _tag_prefab_kinds() -> void:
	for top: String in ["Gameplay", "Variants"]:
		var t: Node = _root.get_node_or_null(top)
		if t == null:
			continue
		for n: Node in t.find_children("*", "Node3D", true, false):
			if not ("visual_scene" in n) or n.has_meta(&"kind") or n.get_script() == null:
				continue
			n.set_meta(&"kind", (n.get_script() as Script).resource_path.get_base_dir().get_file())


# --- Finishing ----------------------------------------------------------------------------------

## Light3D properties of a placed fixture (`tweaks`: asset -> properties).
func _tweak_light(n: Node3D, tweaks: Dictionary) -> void:
	var lt: Light3D = n.get_node_or_null("Light") as Light3D
	if lt == null or tweaks.is_empty():
		return
	var asset: String = String(_scene_asset.get(n.scene_file_path, n.scene_file_path.get_file().get_basename()))
	var props: Dictionary = tweaks.get(asset, {})
	if props.is_empty():
		return
	_root.set_editable_instance(n, true)
	for k2: Variant in props:
		if String(k2) in lt:
			lt.set(StringName(String(k2)), props[k2])


## The near-range variant of a catalog wrapper scene (INTERIOR_VIS): an inherited scene under NEAR_DIR overriding its
## meshes' visibility range (byte-stable text, as sl_dress.near_scene_path). The original path when nothing changes.
static func near_scene_path(asset: String, scene_path: String) -> String:
	if _near.has(asset):
		return String(_near[asset])
	var base: PackedScene = load(scene_path) as PackedScene
	var out: String = scene_path
	if base != null:
		var inst: Node = base.instantiate()
		var body: PackedStringArray = []
		var editable: PackedStringArray = []
		var rng: float = _near_range(inst)
		for m: Node in inst.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = m as GeometryInstance3D
			if gi.visibility_range_end > 0.0 and gi.visibility_range_end <= rng:
				continue
			var parent_path: String = String(inst.get_path_to(m.get_parent()))
			body.append('\n[node name="%s" parent="%s"]\nvisibility_range_end = %.1f\nvisibility_range_end_margin = %.1f\n'
				% [m.name, parent_path, rng, rng * 0.1] + "visibility_range_fade_mode = 1\n")
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


## The near range of a prop by its size (perf, OF-C2): its largest mesh extent picks a NEAR_RANGES band (small desk
## clutter goes first; furniture keeps INTERIOR_VIS). Ceiling fixtures keep their own (shorter) catalog range.
static func _near_range(inst: Node) -> float:
	var box: AABB = AABB()
	var first: bool = true
	for m: Node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = Transform3D.IDENTITY
		var cur: Node = mi
		while cur != inst and cur is Node3D:
			xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var wb: AABB = xf * mi.mesh.get_aabb()
		box = wb if first else box.merge(wb)
		first = false
	var ext: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	for band: Array in NEAR_RANGES:
		if ext < float(band[0]):
			return float(band[1])
	return INTERIOR_VIS


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
	if kind in POLE_KINDS:  # the pole only: the arm overhangs the street at 5 m
		bb = AABB(Vector3(bb.position.x, bb.position.y, -bb.size.x * 0.5), Vector3(bb.size.x, bb.size.y, bb.size.x))
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


func _direct_props(parent: Node3D) -> void:
	for d: Array in D.DIRECT_PROPS:
		var asset: String = String(d[1])
		if not _cat.has(asset):
			_err("direct: asset %s not in catalog" % asset)
			continue
		var xf: Transform3D = _anchor_xform(asset, d[2], float(d[3]))
		var ps: PackedScene = scene(asset)
		if ps == null:
			continue
		var nd: Node3D = ps.instantiate() as Node3D
		nd.name = String(d[0])
		nd.transform = xf
		var metas: Dictionary = d[4]
		for k: Variant in metas:
			nd.set_meta(StringName(String(k)), metas[k])
		parent.add_child(nd)
		nd.owner = _root
		var cat: Dictionary = _cat[asset]
		_finish_node(nd, asset, String(cat.get("place", "floor")), String(cat.get("mount", "")), xf)
		for pre: String in D.DIRECT_LIGHT:
			if String(d[0]).begins_with(pre):
				_tweak_light(nd, {asset: D.DIRECT_LIGHT[pre]})
	counts["Direct"] = D.DIRECT_PROPS.size()


## `faces` links (levelcheck orientation): every chair in a lane-C room (kit, direct and seated-spawn chairs) without one
## looks at the nearest desk / table within 1 m when it faces it within 20 deg, else at an `Aim` marker where its front
## ray meets that desk's footprint; every monitor looks at the nearest chair in front of it (18 deg).
func _link_faces() -> void:
	var chairs: Array[Node3D] = []
	var targets: Array[Node3D] = []
	var monitors: Array[Node3D] = []
	for top: String in ["Props", "Variants"]:
		for n: Node in _root.get_node(top).find_children("*", "Node3D", true, false):
			var n3: Node3D = n as Node3D
			if n3 == null or not n3.has_meta(&"kind") or not _in_lane_room(_gx(n3).origin):
				continue
			if n3.get_parent() != null and n3.get_parent().has_meta(&"art_asset"):
				continue  # a map-built body's art cell: the body is the prop
			var k: String = String(n3.get_meta(&"kind"))
			if k == "chair":
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
			if not ft.grow(1.0).has_point(Vector3(cx.origin.x, ft.position.y + 0.01, cx.origin.z)):
				continue
			var dist: float = _footprint(t).get_center().distance_to(cx.origin)
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


func _in_lane_room(p: Vector3) -> bool:
	for rv: Node in _root.get_node("Rooms").get_children():
		var room: RoomVolume = rv as RoomVolume
		if room == null or not _mine(room):
			continue
		for c: Node in room.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs != null and cs.shape is BoxShape3D:
				var sz: Vector3 = (cs.shape as BoxShape3D).size
				if AABB(cs.position - sz * 0.5, sz).grow(0.05).has_point(p + Vector3.UP * 0.1):
					return true
	return false


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


## Soft fill per lane-C room with a kit (level_standards §3.7: meta fill, energy <= 0.3, no shadows, <= 2 per room): the
## kit fixtures are downward spots, so this lifts the ceilings and upper walls. Long rooms get two.
func fill_lights(parent: Node3D) -> void:
	for rv: Node in _root.get_node("Rooms").get_children():
		var room: RoomVolume = rv as RoomVolume
		if room == null or not _mine(room):
			continue
		var rid: String = String(room.room_id)
		if D.NO_FILL.has(rid):
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
			light.light_color = Color(1.0, 0.88, 0.74) if warm else Color(0.9, 0.95, 1.0)
			light.light_energy = 0.18 if dim else 0.28
			light.omni_range = clampf(length / float(spots.size()) * 0.8 + size.y * 0.5, 3.5, 12.0)
			light.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
			light.shadow_enabled = false
			light.set_meta(&"fill", true)
			parent.add_child(light)
			light.owner = _root
			i += 1


## D-117 Audio node (as the other heists): CuePlayer, the ostrander_federal MusicDirector and the OF ambience beds.
func _audio() -> void:
	var audio: Node3D = _root.get_node_or_null("Audio") as Node3D
	if audio == null:
		audio = Node3D.new()
		audio.name = "Audio"
		_root.add_child(audio)
		audio.owner = _root
	load(AUDIO_BUILDER).call(&"build", audio, _root, &"ostrander_federal", D.AUDIO_BEDS)
