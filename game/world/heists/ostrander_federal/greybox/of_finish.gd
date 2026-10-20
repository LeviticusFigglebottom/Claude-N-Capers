## Ostrander Federal G2 surface pass (OF-C2 surfaces lane, ENV C): library finishes on every wall, floor and ceiling of
## every room except BH, VE and X1 (the hall lane), the trim sheet's skirtings, dado rails and cornices, stone
## pilasters, ceiling coffers and beams, the vault's riveted steel lining, cable trays and the cage panels' bars. One
## call from build_greybox.gd (after of_art_rooms, before the navmesh bake; everything here is visual only):
##   preload(".../of_finish.gd").new(self).call(&"build")
## Data: of_finish_data.gd. Mesh accumulator: glasshouse gh_mesh.gd (world UVs, 1 UV unit = 2 m, trim strips by V).
## * A Geometry box (BoxMesh in a greybox material, axis aligned) is cut into faces; each face is split by the rooms
##   0.3 m off it (walls: along the wall; floors / ceilings: by the room rects of the level it looks into), buried
##   parts (inside another box) and plenum parts (above a room's ceiling) are dropped, and every piece is drawn with its
##   room's finish into one merged mesh per room (big rooms in light-sized tiles). The box keeps its collider; its
##   greybox mesh is freed and its bullet surface follows the new finish.
## * A box with an exposed face looking into BH, VE or X1 belongs to the hall lane and is left untouched: only its
##   faces into our rooms get skins, D.SKIN proud (no z-fight).
## * Other greybox pieces in our rooms (hulls, stair steps, rails, map-built furniture boxes) get a world-triplanar
##   material_override; glass the clear library glass.
## Deterministic: tree order, sorted keys, no RNG.
extends RefCounted

const L: GDScript = preload("res://world/heists/ostrander_federal/greybox/ostrander_federal_layout.gd")
const D: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_finish_data.gd")
const M: GDScript = preload("res://world/heists/glasshouse/greybox/gh_mesh.gd")
const MAT_DIR: String = "res://world/materials/"
const TRIM_TABLE: String = "res://assets/textures/trim_interior/trim_table.json"
const PROBE: float = 0.3
const SAMPLE_STEP: float = 0.1
const NEXT_FFL: Dictionary = {"B": 0.0, "G": 5.0, "M": 8.6, "E": 12.2, "R": 20.0}
const HASH: float = 2.0
const NORMALS: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK]
const FOLDER: String = "FinishD"

var b: Object
var root: Node3D
var report: PackedStringArray = PackedStringArray()
var acc: RefCounted = M.new()
## [rid, x0, z0, x1, z1, y0 (band), y1 (band), ffl, ceiling height (0 = none)]
var _rooms: Array[Array] = []
var _room_rec: Dictionary = {}
var _mats: Dictionary = {}
var _tri: Dictionary = {}
var _glass: Material = null
## Solids (box AABBs) in a HASH grid: [aabb, owner id].
var _solids: Array[Array] = []
var _grid: Dictionary = {}
## Obstacles (props, fixtures, lights, prefabs) for the trims that stand proud: AABBs in a HASH grid.
var _obst: Array[AABB] = []
var _ogrid: Dictionary = {}
## Wall runs per room: [n, plane, a0, a1, y0, y1] (plane: the face coordinate along n, skin included).
var _runs: Dictionary = {}
var _counts: Dictionary = {"boxes": 0, "mixed": 0, "skins": 0, "overrides": 0, "glass": 0, "trims": 0, "pilasters": 0,
	"beams": 0, "cage_bars": 0, "trays": 0}


func _init(builder: Object) -> void:
	b = builder


func build() -> void:
	root = b.get(&"map_root")
	_setup_rooms()
	_setup_materials()
	_collect_obstacles()
	var geo: Node3D = root.get_node("Geometry") as Node3D
	var boxes: Array[Array] = []    # [mi, aabb, cls, site]
	var others: Array[MeshInstance3D] = []
	_collect(geo, boxes, others)
	for bx: Array in boxes:
		_add_solid(bx[1], (bx[0] as Node).get_instance_id())
	for bx2: Array in boxes:
		_box(bx2[0], bx2[1], String(bx2[2]), bool(bx2[3]), bool(bx2[4]))
	var flights: Dictionary = {}
	for mi: MeshInstance3D in others:
		var par: Node = mi.get_parent()
		if String(par.get_meta(&"kind", "")) == "stairs" and mi.mesh is BoxMesh and not _under(mi, "Site"):
			if not flights.has(par):
				flights[par] = []
			(flights[par] as Array).append(mi)
			continue
		_override(mi)
	for fl: Variant in flights:
		_merge_steps(fl as Node3D, flights[fl])
	_mapbuilt()
	for lp: Array in [["Gameplay/Devices/Lid/Visual/LidPanel", "marble"], ["Gameplay/Devices/Lid/Plug/Mesh", "concrete"]]:
		var lid: MeshInstance3D = root.get_node_or_null(String(lp[0])) as MeshInstance3D
		if lid != null and _grey_class(lid) != "":
			lid.material_override = _triplanar(String(lp[1]))   # the lid: hidden with its prefab at the burn
			_counts["overrides"] += 1
	_trims()
	_ceilings()
	_vault_trays()
	_roof()
	_neighbours()
	_flush(b.call(&"add", geo, b.call(&"node3d", FOLDER)) as Node3D)
	report.append("finishes D: %d boxes re-faced (%d hall-lane boxes skinned with %d skins), %d overrides, %d glass, "
		% [_counts["boxes"], _counts["mixed"], _counts["skins"], _counts["overrides"], _counts["glass"]]
		+ "%d trim runs, %d pilasters, %d ceiling beams, %d cage bars, %d tray runs"
		% [_counts["trims"], _counts["pilasters"], _counts["beams"], _counts["cage_bars"], _counts["trays"]])
	var errs: PackedStringArray = b.get(&"errors")
	for line: String in report:
		printerr("finish D: " + line)
		if line.begins_with("ERROR"):
			errs.append(line)
	b.set(&"errors", errs)


# --- Rooms ---------------------------------------------------------------------------------------

func _setup_rooms() -> void:
	for r: Array in L.ROOMS:
		var f: String = String(r[0])
		var q: Array = r[3]
		var ffl: float = float(L.FFL[f])
		var h: float = float(r[4])
		var y1: float = maxf(float(NEXT_FFL[f]), ffl + h)
		if String(r[2]) == "exterior":
			y1 = 20.0
			h = 0.0
		var rec: Array = [String(r[1]), float(q[0]), float(q[1]), float(q[2]), float(q[3]), ffl, y1, ffl, h]
		_rooms.append(rec)
		if not _room_rec.has(String(r[1])):
			_room_rec[String(r[1])] = rec
	for v: Array in L.VOIDS:
		var vq: Array = v[2]
		_rooms.append(["BH", float(vq[0]), float(vq[1]), float(vq[2]), float(vq[3]), 0.0, 8.0, 0.0, 8.0])
	for e: Array in L.EXTERIOR:
		var eq: Array = e[2]
		var erec: Array = [String(e[0]), float(eq[0]), float(eq[1]), float(eq[2]), float(eq[3]), -1.5, 20.0, 0.0, 0.0]
		_rooms.append(erec)
		_room_rec[String(e[0])] = erec


## Room id at p ("" = none): the containing rect whose band starts highest (the gallery over the hall wins).
func room_at(p: Vector3) -> String:
	var best: String = ""
	var by: float = -INF
	for r: Array in _rooms:
		if p.x >= float(r[1]) and p.x < float(r[3]) and p.z >= float(r[2]) and p.z < float(r[4]) \
				and p.y >= float(r[5]) - 0.05 and p.y < float(r[6]) and float(r[5]) > by:
			best = String(r[0])
			by = float(r[5])
	return best


func _rec_at(p: Vector3) -> Array:
	var best: Array = []
	var by: float = -INF
	for r: Array in _rooms:
		if p.x >= float(r[1]) and p.x < float(r[3]) and p.z >= float(r[2]) and p.z < float(r[4]) \
				and p.y >= float(r[5]) - 0.05 and p.y < float(r[6]) and float(r[5]) > by:
			best = r
			by = float(r[5])
	return best


static func _theirs(rid: String) -> bool:
	return rid in D.THEIRS


## X1-X5 (the exteriors; XL, XC, XW are executive rooms).
static func _exterior(rid: String) -> bool:
	return rid.length() == 2 and rid[0] == "X" and rid[1].is_valid_int()


static func _mine(rid: String) -> bool:
	return rid != "" and not (rid in D.THEIRS) and D.ROOMS.has(rid)


# --- Materials -----------------------------------------------------------------------------------

func _setup_materials() -> void:
	var keys: Array = D.KEYS.keys()
	keys.sort()
	for k: Variant in keys:
		var row: Array = D.KEYS[k]
		var lib: BaseMaterial3D = load(MAT_DIR + String(row[0]) + ".tres") as BaseMaterial3D
		if lib == null:
			report.append("ERROR finish: no library material %s" % row[0])
			continue
		var m: Material = lib
		if row[1] != null:
			var t: BaseMaterial3D = lib.duplicate() as BaseMaterial3D
			t.resource_name = "of_" + String(k)
			t.albedo_color = row[1]
			m = t
		_mats[String(k)] = m
		var sv: Array = row[2] if row[2] != null else []
		acc.register_material(String(k), m, Vector2(float(sv[0]), float(sv[1])) if sv.size() == 2 else Vector2(-1.0, -1.0))
	var trim: Material = load(MAT_DIR + "trim_interior.tres") as Material
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRIM_TABLE))
	if trim == null or not (table is Dictionary):
		report.append("ERROR finish: no trim sheet")
		return
	for s: Variant in (table as Dictionary)["strips"]:
		var sd: Dictionary = s
		if String(sd["name"]) in D.TRIM_STRIPS:
			var tk: String = "trim_" + String(sd["name"])
			_mats[tk] = trim
			acc.register_material(tk, trim, Vector2(float(sd["v_top_gltf"]), float(sd["v_bottom_gltf"])))
	var src: BaseMaterial3D = load(MAT_DIR + "glass_clear.tres") as BaseMaterial3D
	var g: BaseMaterial3D = src.duplicate() as BaseMaterial3D
	g.resource_name = "of_glass_d"
	g.uv1_triplanar = true
	g.uv1_world_triplanar = true
	g.uv1_scale = Vector3.ONE   # 512 px over 1 m: 512 px/m (as the landmark glass)
	g.cull_mode = BaseMaterial3D.CULL_DISABLED
	g.albedo_color = Color(0.86, 0.9, 0.9, 0.5)
	_glass = g


## World-triplanar copy of a finish (512 px/m for the 1024 px library, 256 px/m for the 512 px ceiling tile).
func _triplanar(key: String) -> Material:
	if _tri.has(key):
		return _tri[key]
	var m: BaseMaterial3D = (_mats[key] as BaseMaterial3D).duplicate() as BaseMaterial3D
	m.resource_name = "of_tri_" + key
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * (1.0 / M.TILE_M)
	_tri[key] = m
	return m


static func _lib_of(key: String) -> String:
	if key.begins_with("trim_"):
		return "trim_interior"
	return String((D.KEYS[key] as Array)[0]) if D.KEYS.has(key) else key


# --- Collection ----------------------------------------------------------------------------------

static func _grey_class(mi: MeshInstance3D) -> String:
	if mi.material_override != null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return ""
	var m: Material = mi.mesh.surface_get_material(0)
	if m == null or not m.resource_path.contains("/grey_"):
		return ""
	return String(D.GREY_CLASS.get(m.resource_path.get_file().get_basename(), "prop"))


func _collect(n: Node, boxes: Array[Array], others: Array[MeshInstance3D]) -> void:
	for c: Node in n.get_children():
		if c.name in [&"Landmarks", &"BoxBanks", &"FinishD"]:
			continue
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null:
			var cls: String = _grey_class(mi)
			if cls != "":
				var xf: Transform3D = b.call(&"global_xform", mi)
				var site: bool = _under(mi, "Site")
				var boxy: bool = mi.mesh is BoxMesh and xf.basis.is_equal_approx(Basis.IDENTITY) \
					and mi.get_parent() is StaticBody3D and not _under(mi, "FireEscape")
				if boxy:
					var sz: Vector3 = (mi.mesh as BoxMesh).size
					# a hidden box was redrawn by the hall lane (of_dress_a.gd, Geometry/FinishA) or a landmark: skins only
					boxes.append([mi, AABB(xf.origin - sz * 0.5, sz), cls, site, not mi.visible])
				elif mi.visible:
					others.append(mi)
		_collect(c, boxes, others)


func _under(n: Node, top: String) -> bool:
	var cur: Node = n.get_parent()
	while cur != null and cur != root:
		if String(cur.name) == top:
			return true
		cur = cur.get_parent()
	return false


func _add_solid(a: AABB, owner_id: int) -> void:
	var idx: int = _solids.size()
	_solids.append([a, owner_id])
	for k: Vector3i in _cells(a):
		if not _grid.has(k):
			_grid[k] = []
		(_grid[k] as Array).append(idx)


static func _cells(a: AABB) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var lo: Vector3i = Vector3i((a.position / HASH).floor())
	var hi: Vector3i = Vector3i((a.end / HASH).floor())
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			for z: int in range(lo.z, hi.z + 1):
				out.append(Vector3i(x, y, z))
	return out


func _in_solid(q: Vector3, self_id: int) -> bool:
	var k: Vector3i = Vector3i((q / HASH).floor())
	for idx: int in _grid.get(k, []):
		var s: Array = _solids[idx]
		if int(s[1]) == self_id:
			continue
		var a: AABB = s[0]
		if q.x > a.position.x and q.x < a.end.x and q.y > a.position.y and q.y < a.end.y and q.z > a.position.z \
				and q.z < a.end.z:
			return true
	return false


## Props, fixtures, prefabs and lights (anything a proud trim must not swallow): visual AABBs in world space.
func _collect_obstacles() -> void:
	for top: String in ["Props", "Lighting", "Gameplay", "Variants"]:
		var t: Node = root.get_node_or_null(top)
		if t == null:
			continue
		for c: Node in t.find_children("*", "Node3D", true, false):
			var a: AABB = AABB()
			var ok: bool = false
			if c is GeometryInstance3D and not (c is MultiMeshInstance3D):
				var gi: GeometryInstance3D = c
				if not gi.visible:
					continue
				a = (b.call(&"global_xform", gi) as Transform3D) * gi.get_aabb()
				ok = true
			elif c is Light3D:
				a = AABB((b.call(&"global_xform", c) as Transform3D).origin - Vector3.ONE * 0.25, Vector3.ONE * 0.5)
				ok = true
			if ok and a.size.length() < 30.0:
				_add_obstacle(a)
	# door prefabs build their frame visuals at runtime: their casing box (the opening + 0.12 m each side, 2.35 m)
	var doors: Node = root.get_node_or_null("Gameplay/Doors")
	if doors != null:
		for d: Node in doors.get_children():
			if d is Node3D and "width_m" in d:
				var w: float = float(d.get(&"width_m")) * 0.5 + D.DOOR_CASING
				var dx: Transform3D = b.call(&"global_xform", d)
				_add_obstacle(dx * AABB(Vector3(-w, 0.0, -0.16), Vector3(w * 2.0, 2.35, 0.32)))
	# other prefabs (cameras, keypads, readers, phones) build their visuals at runtime too: a 0.5 m box at the origin
	for top2: String in ["Gameplay", "Variants"]:
		var t2: Node = root.get_node_or_null(top2)
		if t2 == null:
			continue
		for pf: Node in t2.find_children("*", "Node3D", true, false):
			if "visual_scene" in pf and not ("width_m" in pf):
				var po: Vector3 = (b.call(&"global_xform", pf) as Transform3D).origin
				_add_obstacle(AABB(po - Vector3.ONE * 0.25, Vector3.ONE * 0.5))
	var lm: Node = root.get_node_or_null("Geometry/Landmarks")
	if lm != null:
		for c3: Node in lm.find_children("*", "GeometryInstance3D", true, false):
			var a3: AABB = (b.call(&"global_xform", c3) as Transform3D) * (c3 as GeometryInstance3D).get_aabb()
			if a3.size.length() < 12.0:
				_add_obstacle(a3)
	var bb: Node = root.get_node_or_null("Geometry/BoxBanks")
	if bb != null:
		for c2: Node in bb.find_children("*", "GeometryInstance3D", true, false):
			var gi2: GeometryInstance3D = c2
			if gi2 is MultiMeshInstance3D:
				_add_obstacle((b.call(&"global_xform", gi2) as Transform3D) * (gi2 as MultiMeshInstance3D).custom_aabb)
			else:
				_add_obstacle((b.call(&"global_xform", gi2) as Transform3D) * gi2.get_aabb())


func _add_obstacle(a: AABB) -> void:
	var idx: int = _obst.size()
	_obst.append(a)
	for k: Vector3i in _cells(a):
		if not _ogrid.has(k):
			_ogrid[k] = []
		(_ogrid[k] as Array).append(idx)


func _blocked(a: AABB) -> bool:
	for k: Vector3i in _cells(a):
		for idx: int in _ogrid.get(k, []):
			if _obst[idx].intersects(a):
				return true
	return false


# --- Boxes -> faces ------------------------------------------------------------------------------

## One box: its face pieces ([corners, n, key, room, group]); hall-lane boxes keep their mesh and get skins only.
func _box(mi: MeshInstance3D, a: AABB, cls: String, site: bool, claimed: bool) -> void:
	var body: Node = mi.get_parent()
	var self_id: int = mi.get_instance_id()
	if claimed and (cls == "glass" or String(body.get_parent().name) in D.NO_SKIN_GROUPS):
		return
	if cls == "glass":
		if not _faces_theirs(a, self_id):
			mi.material_override = _glass
			_counts["glass"] += 1
		return
	var cage: bool = String(body.get_parent().name) == "Cages"
	var pieces: Array[Array] = []
	var their_area: float = 0.0
	var all_area: float = 0.0
	var skey: String = _site_key(String(body.name), cls) if site else ""
	for f: int in range(6):
		for pc: Array in _face_pieces(a, f, cls):
			if not _exposed(pc[0], pc[1], self_id):
				continue
			var ar: float = _quad_area(pc[0])
			all_area += ar
			if _theirs(String(pc[3])):
				their_area += ar
			elif site:
				pc[2] = skey
				pc[4] = "Site_" + String(body.get_parent().name)
				pc[5] = null
			pieces.append(pc)
	# the hall lane's box when a real part of it shows in BH / VE / X1 (a sliver, a wall top flush with their floor, a
	# ceiling plane's edge behind the glass front: ours, that part left to the coplanar face it meets)
	if claimed or (their_area >= D.THEIRS_SHARE * all_area and their_area > 0.0):
		_counts["mixed"] += 1
		for pc2: Array in pieces:
			var rid: String = String(pc2[3])
			if not _mine(rid) or not (cls in ["wall", "wall_ext", "floor", "roof", "ceiling", "stair"]):
				continue
			var nn: Vector3 = pc2[1]
			var q: Array = pc2[0]
			var off: Array[Vector3] = []
			for p: Vector3 in q:
				off.append(p + nn * D.SKIN)
			_emit_piece(off, nn, String(pc2[2]), rid, String(pc2[4]))
			if pc2[5] != null:
				_record_run(pc2[5], D.SKIN)
			_counts["skins"] += 1
		return
	if cage:
		_cage(a)
		_retag(body, "metal_ultra")
	else:
		var votes: Dictionary = {}
		for pc3: Array in pieces:
			if String(pc3[2]) == "@theirs":   # a sliver of our box showing in their room: their neutral finish
				pc3[2] = String(D.THEIRS_KEY.get(cls, "ashlar"))
				pc3[4] = "Shell"
			_emit_piece(pc3[0], pc3[1], String(pc3[2]), String(pc3[3]), String(pc3[4]))
			if pc3[5] != null:
				_record_run(pc3[5], 0.0)
			var area: float = _quad_area(pc3[0])
			votes[String(pc3[2])] = float(votes.get(String(pc3[2]), 0.0)) + area
		_retag(body, _best_vote(votes))
	_counts["boxes"] += 1
	mi.get_parent().remove_child(mi)
	mi.free()


## Glass is the hall lane's when a face looks into BH or VE, or when none looks into one of our rooms (the hall's
## facade windows); a window between one of our rooms and the plaza is ours.
func _faces_theirs(a: AABB, self_id: int) -> bool:
	var ours: bool = false
	for f: int in range(6):
		for pc: Array in _face_pieces(a, f, "glass"):
			if not _exposed(pc[0], pc[1], self_id):
				continue
			var rid: String = String(pc[3])
			if rid == "BH" or rid == "VE":
				return true
			if _mine(rid) and not _exterior(rid):
				ours = true
	return not ours


static func _best_vote(votes: Dictionary) -> String:
	var best: String = ""
	var bv: float = -1.0
	var ks: Array = votes.keys()
	ks.sort()
	for k: Variant in ks:
		if float(votes[k]) > bv:
			bv = float(votes[k])
			best = String(k)
	return best


func _retag(body: Node, key: String) -> void:
	if body is CollisionObject3D and key != "":
		var s: StringName = SurfaceTags.for_id(_lib_of(key))
		if s != &"":
			SurfaceTags.tag(body, s)


static func _quad_area(q: Array) -> float:
	return ((q[1] as Vector3) - (q[0] as Vector3)).cross((q[3] as Vector3) - (q[0] as Vector3)).length()


## A face's pieces: [[4 corners], n, key, room, group, run info or null]. Walls split along the wall by room (then by the style's
## height bands); floors / ceilings by the room rects of the level they look into. Plenum parts are dropped.
func _face_pieces(a: AABB, f: int, cls: String) -> Array[Array]:
	var n: Vector3 = NORMALS[f]
	var out: Array[Array] = []
	var mn: Vector3 = a.position
	var mx: Vector3 = a.end
	if absf(n.y) > 0.5:
		var y: float = mx.y if n.y > 0.0 else mn.y
		var probe_y: float = y + PROBE * n.y
		var taken: Array = []
		var recs: Array[Array] = []
		for r: Array in _rooms:
			if probe_y >= float(r[5]) - 0.05 and probe_y < float(r[6]):
				recs.append(r)
		recs.sort_custom(func(p: Array, q: Array) -> bool: return float(p[5]) > float(q[5]))
		var face: Array = [mn.x, mn.z, mx.x, mx.z]
		for r2: Array in recs:
			var ix0: float = maxf(mn.x, float(r2[1]))
			var iz0: float = maxf(mn.z, float(r2[2]))
			var ix1: float = minf(mx.x, float(r2[3]))
			var iz1: float = minf(mx.z, float(r2[4]))
			if ix1 - ix0 < 0.005 or iz1 - iz0 < 0.005:
				continue
			var rid: String = String(r2[0])
			var holes: Array = taken.duplicate()
			if n.y > 0.0:
				for fc: Array in D.FLOOR_CUTS:
					if absf(y - float(fc[4])) < 0.05:
						holes.append([float(fc[0]), float(fc[1]), float(fc[2]), float(fc[3])])
			var cut: Array = _rects_minus([ix0, iz0, ix1, iz1], holes)
			taken.append([ix0, iz0, ix1, iz1])
			var ffl: float = float(r2[7])
			var h: float = float(r2[8])
			if h > 0.0 and y > ffl + h + 0.01:
				continue   # plenum above the room's ceiling (or the ceiling plane's top)
			if h > 0.0 and n.y > 0.0 and y >= ffl + h - 0.01:
				continue   # the top of a ceiling plane / a box in the plenum
			var surf: int = 2 if n.y < 0.0 else 0
			if (n.y < 0.0 and h > 0.0 and y < ffl + h - 0.05) or (n.y > 0.0 and y > ffl + 0.05):
				surf = 1   # a door head's soffit, a window sill: the wall finish
			var k2: String = _room_key(rid, surf, cls)
			if k2 == "":
				continue
			for c: Array in cut:
				out.append([_hquad(c, y), n, k2, rid, _group(rid), null])
		for rest: Array in _rects_minus(face, taken):
			out.append([_hquad(rest, y), n, String(D.CLASS_KEY.get(cls, "concrete")), "", "Shell", null])
		return out
	# vertical face: along axis u (x for +-z faces, z for +-x faces)
	var along_x: bool = absf(n.z) > 0.5
	var u0: float = mn.x if along_x else mn.z
	var u1: float = mx.x if along_x else mx.z
	var plane: float = (mx.z if n.z > 0.0 else mn.z) if along_x else (mx.x if n.x > 0.0 else mn.x)
	var jamb: bool = u1 - u0 < 0.35 and (mx.y - mn.y) > (u1 - u0)
	var py: float = clampf(mn.y + 1.0, mn.y + 0.05, mx.y - 0.05)
	var steps: int = maxi(1, ceili((u1 - u0) / SAMPLE_STEP - 0.001))
	var runs: Array[Array] = []   # [rid, ua, ub, rec]
	for i: int in range(steps):
		var ua: float = u0 + (u1 - u0) * float(i) / float(steps)
		var ub: float = u0 + (u1 - u0) * float(i + 1) / float(steps)
		var uc: float = (ua + ub) * 0.5
		var p: Vector3 = Vector3(uc, py, plane) if along_x else Vector3(plane, py, uc)
		var rec: Array = _rec_at(p + n * PROBE)
		var rid: String = String(rec[0]) if not rec.is_empty() else ""
		if not runs.is_empty() and String(runs[-1][0]) == rid:
			runs[-1][2] = ub
		else:
			runs.append([rid, ua, ub, rec])
	for run: Array in runs:
		var rid2: String = String(run[0])
		var rec2: Array = run[3]
		var y0: float = mn.y
		var y1: float = mx.y
		var ffl: float = 0.0
		if not rec2.is_empty():
			ffl = float(rec2[7])
			var h2: float = float(rec2[8])
			if h2 > 0.0:
				if y0 >= ffl + h2 - 0.01:
					continue
				y1 = minf(y1, ffl + h2)
		var wkey: String = _room_key(rid2, 1, cls)
		if wkey == "":
			continue
		var bands: Array[Array] = [[y0, y1, wkey]]
		var info: Variant = null
		if not jamb and _mine(rid2):
			bands = _wall_bands(rid2, ffl, y0, y1, wkey)
			info = [rid2, n, plane, along_x, float(run[1]), float(run[2]), y0, y1]
		for bd: Array in bands:
			for r: Array in _wall_cut(along_x, plane, n, [float(run[1]), float(bd[0]), float(run[2]), float(bd[1])]):
				var q: Array[Vector3] = _vquad(along_x, plane, float(r[0]), float(r[2]), float(r[1]), float(r[3]))
				out.append([q, n, String(bd[2]), rid2, _group(rid2), info])
				info = null
	return out


## A wall face rect [u0, y0, u1, y1] minus the WALL_CUTS on its plane (the box banks hide the wall behind them).
static func _wall_cut(along_x: bool, plane: float, n: Vector3, r: Array) -> Array:
	var holes: Array = []
	for c: Array in D.WALL_CUTS:
		if (String(c[0]) == "z") == along_x and absf(float(c[1]) - plane) < 0.01 \
				and signf(n.z if along_x else n.x) == signf(float(c[2])):
			holes.append([float(c[3]), float(c[5]), float(c[4]), float(c[6])])
	if holes.is_empty():
		return [r]
	return _rects_minus(r, holes)


## A wall run of one of our rooms (trims follow it): info = [rid, n, plane, along_x, u0, u1, y0, y1].
func _record_run(info: Array, skin: float) -> void:
	var rid: String = String(info[0])
	if not _runs.has(rid):
		_runs[rid] = []
	(_runs[rid] as Array).append([info[1], float(info[2]) + skin * ((info[1] as Vector3).z if bool(info[3]) else (info[1] as Vector3).x),
		info[3], info[4], info[5], info[6], info[7]])


## Vertical bands of a wall face in a styled room: wainscot under the dado rail, panelling to the picture rail.
func _wall_bands(rid: String, ffl: float, y0: float, y1: float, wkey: String) -> Array[Array]:
	var st: Dictionary = D.STYLES.get(String((D.ROOMS[rid] as Array)[3]), {})
	var cuts: Array[Array] = []   # [ya, yb, key]
	if st.has("dado") and String((st["dado"] as Array)[4]) != "":
		var dd: Array = st["dado"]
		cuts.append([ffl, ffl + float(dd[1]), String(dd[4])])
		if st.has("picture"):
			var pc: Array = st["picture"]
			cuts.append([ffl + float(dd[1]) + float(dd[2]), ffl + float(pc[1]), String(pc[4])])
	var out: Array[Array] = []
	var cur: float = y0
	for c: Array in cuts:
		var ca: float = maxf(float(c[0]), y0)
		var cb: float = minf(float(c[1]), y1)
		if cb - ca < 0.01:
			continue
		if ca > cur + 0.001:
			out.append([cur, ca, wkey])
		out.append([ca, cb, String(c[2])])
		cur = cb
	if y1 > cur + 0.001:
		out.append([cur, y1, wkey])
	return out


## Finish key of a room surface (0 floor, 1 walls, 2 ceiling); outside our rooms: the class default (exterior
## facade for the shell, "" for the hall lane's rooms).
func _room_key(rid: String, i: int, cls: String) -> String:
	if _theirs(rid):
		return "@theirs"
	if D.ROOMS.has(rid):
		var k: String = String((D.ROOMS[rid] as Array)[i])
		if k != "":
			return k
		return "" if i == 2 else String(D.CLASS_KEY.get(cls, "concrete"))
	if cls == "wall_ext" and i == 1:
		return "facade"
	return String(D.CLASS_KEY.get(cls, "concrete"))


static func _site_key(nm: String, cls: String) -> String:
	for row: Array in D.SITE_KEYS:
		if nm.begins_with(String(row[0])):
			return String(row[1])
	return String(D.CLASS_KEY.get(cls, "concrete"))


func _group(rid: String) -> String:
	if rid == "":
		return "Shell"
	return "R_" + rid


static func _hquad(r: Array, y: float) -> Array[Vector3]:
	return [Vector3(float(r[0]), y, float(r[1])), Vector3(float(r[2]), y, float(r[1])), Vector3(float(r[2]), y, float(r[3])),
		Vector3(float(r[0]), y, float(r[3]))]


static func _vquad(along_x: bool, plane: float, u0: float, u1: float, y0: float, y1: float) -> Array[Vector3]:
	if along_x:
		return [Vector3(u0, y0, plane), Vector3(u1, y0, plane), Vector3(u1, y1, plane), Vector3(u0, y1, plane)]
	return [Vector3(plane, y0, u0), Vector3(plane, y0, u1), Vector3(plane, y1, u1), Vector3(plane, y1, u0)]


## A piece is drawn unless every sample just off it lies inside another box (buried), or every sample just inside it
## does (flush with another box's face in the same plane, e.g. a wall top under the slab top: that box draws it).
func _exposed(q: Array, n: Vector3, self_id: int) -> bool:
	var a: Vector3 = q[0]
	var e1: Vector3 = (q[1] as Vector3) - a
	var e2: Vector3 = (q[3] as Vector3) - a
	var out_free: bool = false
	var in_free: bool = false
	for s: float in [0.08, 0.5, 0.92]:
		for t: float in [0.08, 0.5, 0.92]:
			var c: Vector3 = a + e1 * s + e2 * t
			if not out_free and not _in_solid(c + n * 0.002, self_id):
				out_free = true
			if not in_free and not _in_solid(c - n * 0.002, self_id):
				in_free = true
			if out_free and in_free:
				return true
	return false


func _emit_piece(q: Array, n: Vector3, key: String, rid: String, group: String) -> void:
	if key == "" or key == "@theirs" or not _mats.has(key):
		return
	if group == "Shell" and maxf(maxf((q[0] as Vector3).y, (q[1] as Vector3).y), (q[2] as Vector3).y) <= 0.001:
		key = "concrete"   # below grade, facing no room: one finish (no two fallbacks meet coplanar)
	_tile(group, rid)
	acc.call(&"quad", group, key, q[0], q[1], q[2], q[3], n)


func _tile(group: String, rid: String) -> void:
	if not group.begins_with("R_") or (acc.get(&"tile_groups") as Dictionary).has(group) or not _room_rec.has(rid):
		return
	var r: Array = _room_rec[rid]
	var area: float = (float(r[3]) - float(r[1])) * (float(r[4]) - float(r[2]))
	if area >= D.TILE_AREA and not _exterior(rid):
		(acc.get(&"tile_groups") as Dictionary)[group] = D.TILE


## Rect [x0, z0, x1, z1] minus rects (rectangle decomposition on the cut lines).
static func _rects_minus(outer: Array, holes: Array) -> Array:
	var xs: Array[float] = [float(outer[0]), float(outer[2])]
	var zs: Array[float] = [float(outer[1]), float(outer[3])]
	for h: Array in holes:
		for v: float in [float(h[0]), float(h[2])]:
			if v > float(outer[0]) and v < float(outer[2]) and not xs.has(v):
				xs.append(v)
		for w: float in [float(h[1]), float(h[3])]:
			if w > float(outer[1]) and w < float(outer[3]) and not zs.has(w):
				zs.append(w)
	xs.sort()
	zs.sort()
	var out: Array = []
	for j: int in range(zs.size() - 1):
		var start: float = NAN
		for i: int in range(xs.size()):
			var inside: bool = true
			if i < xs.size() - 1:
				var cx: float = (xs[i] + xs[i + 1]) * 0.5
				var cz: float = (zs[j] + zs[j + 1]) * 0.5
				inside = false
				for h2: Array in holes:
					if cx > float(h2[0]) and cx < float(h2[2]) and cz > float(h2[1]) and cz < float(h2[3]):
						inside = true
						break
			if not inside and is_nan(start):
				start = xs[i]
			elif inside and not is_nan(start):
				if xs[i] - start > 0.005 and zs[j + 1] - zs[j] > 0.005:
					out.append([start, zs[j], xs[i], zs[j + 1]])
				start = NAN
	return out


# --- Other greybox pieces ------------------------------------------------------------------------

## Hulls, stair steps, rails, turned boxes: a world-triplanar finish of the room they stand in (or their class).
func _override(mi: MeshInstance3D) -> void:
	var cls: String = _grey_class(mi)
	var xf: Transform3D = b.call(&"global_xform", mi)
	var a: AABB = xf * mi.get_aabb()
	var c: Vector3 = a.get_center()
	var rid: String = room_at(c)
	var site_hull: bool = _under(mi, "Site") and mi.get_parent() is StaticBody3D   # the Tannery ramp: left grey otherwise
	if not site_hull and (_theirs(rid) or _theirs(room_at(Vector3(c.x, a.position.y + 0.05, c.z)))):
		return
	if cls == "glass":
		mi.material_override = _glass
		_counts["glass"] += 1
		return
	var key: String = String(D.CLASS_KEY.get(cls, "metal"))
	if cls == "stair":
		key = String((D.ROOMS[rid] as Array)[0]) if D.ROOMS.has(rid) else "terrazzo"
	elif String(mi.get_parent().name).begins_with("Coping"):
		key = "coping"
	elif cls == "wall_ext":
		key = "facade"
	elif cls == "floor" and (_under(mi, "Grade") or site_hull):
		key = "asphalt"
	mi.material_override = _triplanar(key)
	_retag(mi.get_parent(), key)
	_counts["overrides"] += 1


## A flight's step boxes as one mesh (one draw instead of one per step), in its room's floor finish, world triplanar.
func _merge_steps(flight: Node3D, steps: Array) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Variant in steps:
		var mi: MeshInstance3D = v
		var sz: Vector3 = (mi.mesh as BoxMesh).size
		var lo: Vector3 = mi.position - sz * 0.5
		var hi: Vector3 = mi.position + sz * 0.5
		for f: int in range(6):
			var n: Vector3 = NORMALS[f]
			var q: Array[Vector3] = M._face(lo, hi, f)
			var pts: Array[Vector3] = q
			if (q[1] - q[0]).cross(q[3] - q[0]).dot(n) < 0.0:
				pts = [q[0], q[3], q[2], q[1]]
			for idx: int in [0, 2, 1, 0, 3, 2]:
				st.set_normal(n)
				st.set_uv(M.world_uv(pts[idx], n))
				st.add_vertex(pts[idx])
	st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	mesh.resource_name = "of_steps_" + String(flight.name)
	var c: Vector3 = (b.call(&"global_xform", flight) as Transform3D).origin
	var rid: String = room_at(c + Vector3.UP * 0.5)
	var key: String = String((D.ROOMS[rid] as Array)[0]) if D.ROOMS.has(rid) else "terrazzo"
	mesh.surface_set_material(0, _triplanar(key))
	for v2: Variant in steps:
		var m2: MeshInstance3D = v2
		flight.remove_child(m2)
		m2.free()
	var out: MeshInstance3D = MeshInstance3D.new()
	out.name = "Steps"
	out.mesh = mesh
	b.call(&"add", flight, out)
	_counts["overrides"] += 1


## Map-built furniture boxes still in greybox in our rooms (no catalog art): their class finish, triplanar.
func _mapbuilt() -> void:
	var mb: Node = root.get_node_or_null("Props/MapBuilt")
	if mb == null:
		return
	for c: Node in mb.get_children():
		var mi: MeshInstance3D = c.get_node_or_null("Mesh") as MeshInstance3D
		if mi == null or not mi.visible or _grey_class(mi) == "":
			continue
		var rid: String = room_at((b.call(&"global_xform", mi) as Transform3D).origin)
		if _theirs(rid):
			continue
		var cls: String = _grey_class(mi)
		var key: String = "metal" if cls in ["prop", "trim"] else String(D.CLASS_KEY.get(cls, "wood"))
		mi.material_override = _triplanar(key)
		_counts["overrides"] += 1


# --- Trims ---------------------------------------------------------------------------------------

## Skirting, dado / picture rails, cornices and stone pilasters along every recorded wall run of a styled room.
func _trims() -> void:
	var rids: Array = _runs.keys()
	rids.sort()
	for rid: Variant in rids:
		var rec: Array = _room_rec[String(rid)]
		var ffl: float = float(rec[7])
		var h: float = float(rec[8])
		var st: Dictionary = D.STYLES.get(String((D.ROOMS[String(rid)] as Array)[3]), {})
		var group: String = "D_" + String(rid)
		for run: Array in _runs[rid]:
			var n: Vector3 = run[0]
			var y0: float = float(run[5])
			var y1: float = float(run[6])
			var did: bool = false
			if st.has("skirt") and y0 <= ffl + 0.01 and y1 >= ffl + 0.3:
				var sk: Array = st["skirt"]
				_strip(group, run, ffl, ffl + float(sk[1]), float(sk[2]), String(sk[0]), true)
				did = true
			for key: String in ["dado", "picture"]:
				if not st.has(key):
					continue
				var dd: Array = st[key]
				var ya: float = ffl + float(dd[1])
				var yb: float = ya + float(dd[2])
				if y0 <= ya + 0.001 and y1 >= yb - 0.001:
					_strip(group, run, ya, yb, float(dd[3]), String(dd[0]), false)
					did = true
			if st.has("cornice") and h > 0.0:
				var cn: Array = st["cornice"]
				var ct: float = ffl + h
				if y1 >= ct - 0.01 and y0 <= ct - float(cn[1]):
					_strip(group, run, ct - float(cn[1]), ct, float(cn[2]), String(cn[0]), false, true)
					did = true
			if st.has("pilasters") and h > 0.0:
				_pilasters(group, run, ffl, h, st)
			if st.has("courses"):
				did = _courses(String(rid), run, st) or did
			if did:
				_counts["trims"] += 1


## Exterior runs: limestone string courses at the floor lines, a plinth at grade, louvre screens on the roof plant.
func _courses(rid: String, run: Array, st: Dictionary) -> bool:
	var y0: float = float(run[5])
	var y1: float = float(run[6])
	var g: String = "R_" + rid
	var did: bool = false
	var cs: Array = st["courses"]
	var ch: float = float(cs[1])
	for yv: Variant in cs[3]:
		var y: float = float(yv)
		if y0 <= y - ch * 0.5 and y1 >= y + ch * 0.5:
			_strip(g, run, y - ch * 0.5, y + ch * 0.5, float(cs[2]), String(cs[0]), false)
			did = true
		elif absf(y0 - y) < 0.01 and y1 >= y + ch:
			_strip(g, run, y, y + ch, float(cs[2]), String(cs[0]), false)
			did = true
	if st.has("plinth") and y0 <= 0.05 and y1 >= 1.0:
		var pl: Array = st["plinth"]
		_strip(g, run, maxf(y0, -0.75), float(pl[1]), float(pl[2]), String(pl[0]), true)
		did = true
	if rid == "X5" and _on_rect_edge(run, D.LOUVRE_RECT):
		var top: float = minf(y1, 12.2 + 2.7)
		var y: float = 12.2 + 0.35
		while y + 0.05 <= top:
			_strip(g, run, y, y + 0.05, 0.06, "louvre", false)
			y += D.LOUVRE_PITCH
		did = true
	return did


## A wall run lying on an edge of the rect [x0, z0, x1, z1] (its plane within 0.4 m of the edge, inside its extent).
static func _on_rect_edge(run: Array, r: Array) -> bool:
	var plane: float = float(run[1])
	var along_x: bool = bool(run[2])
	var u0: float = float(run[3])
	var u1: float = float(run[4])
	if along_x:
		return (absf(plane - float(r[1])) < 0.4 or absf(plane - float(r[3])) < 0.4) and u0 >= float(r[0]) - 0.4 \
			and u1 <= float(r[2]) + 0.4
	return (absf(plane - float(r[0])) < 0.4 or absf(plane - float(r[2])) < 0.4) and u0 >= float(r[1]) - 0.4 \
		and u1 <= float(r[3]) + 0.4


## Roof decks (X5 rects): lap seams across the membrane every SEAM_PITCH and a drain grate per rect, clear of the
## plant, the head house and every prop.
func _roof() -> void:
	var y: float = float(L.FFL["R"])
	for r: Array in L.ROOMS:
		if String(r[1]) != "X5":
			continue
		var q: Array = r[3]
		var x0: float = float(q[0]) + 0.5
		var z0: float = float(q[1]) + 0.5
		var x1: float = float(q[2]) - 0.5
		var z1: float = float(q[3]) - 0.5
		if x1 - x0 < 1.0 or z1 - z0 < 1.0:
			continue
		var x: float = ceilf(x0 / D.SEAM_PITCH) * D.SEAM_PITCH
		while x <= x1:
			var z: float = z0
			while z < z1 - 0.01:
				var ze: float = minf(z + 1.0, z1)
				var lo: Vector3 = Vector3(x - 0.02, y, z)
				var hi: Vector3 = Vector3(x + 0.02, y + 0.006, ze)
				if not _blocked(AABB(lo, hi - lo).grow(0.03)):
					_slab_box("R_X5", lo, hi, "roof_seam")
				z = ze
			x += D.SEAM_PITCH
		var c: Vector3 = Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5)
		var dl: Vector3 = c - Vector3(0.18, 0.0, 0.18)
		var dh: Vector3 = c + Vector3(0.18, 0.008, 0.18)
		if not _blocked(AABB(dl, dh - dl).grow(0.1)):
			_slab_box("R_X5", dl, dh, "drain")


## A flat box on a floor (no bottom face).
func _slab_box(g: String, lo: Vector3, hi: Vector3, key: String) -> void:
	for f: int in range(6):
		if f == 2:
			continue
		var q: Array[Vector3] = M._face(lo, hi, f)
		acc.call(&"quad", g, key, q[0], q[1], q[2], q[3], NORMALS[f])


## The neighbours seen from the play space: the parking structure's decks (spandrels, dark open slots, columns,
## painted bays on the roof deck) and the Corvino Building's storeys (limestone string courses, windows with sills
## and lintels) on the faces toward the lane, the bank roof and the terrace.
func _neighbours() -> void:
	var cl: Node = root.get_node_or_null("Geometry/Site/Closures")
	if cl == null:
		return
	for row: Array in D.NEIGHBOURS:
		var body: Node3D = cl.get_node_or_null(String(row[0])) as Node3D
		if body == null:
			continue
		var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
		if cs == null or not (cs.shape is BoxShape3D):
			continue
		var sz: Vector3 = (cs.shape as BoxShape3D).size
		var a: AABB = (b.call(&"global_xform", cs) as Transform3D) * AABB(-sz * 0.5, sz)
		if String(row[1]) == "parking":
			_parking(a)
		else:
			_corvino(a)


func _parking(a: AABB) -> void:
	var g: String = "N_Parking"
	var zf: float = a.end.z   # the south face, on Ledger Lane
	var y: float = a.position.y
	while y + D.PARK_FLOOR <= a.end.y + 0.01:
		var s0: float = y + float(D.PARK_SLOT[0])
		var s1: float = y + float(D.PARK_SLOT[1])
		_front_box(g, Vector3(a.position.x + 0.3, s0, zf), Vector3(a.end.x - 0.3, s1, zf + 0.004), "deck_dark")
		for k: int in range(3):   # the edge barrier cables
			var cy: float = s0 + 0.35 + 0.25 * float(k)
			acc.call(&"box", g, Vector3(a.position.x + 0.3, cy, zf + 0.03), Vector3(a.end.x - 0.3, cy + 0.02, zf + 0.05), "steel")
		y += D.PARK_FLOOR
	var x: float = ceilf((a.position.x + 0.5) / D.PARK_COLUMN) * D.PARK_COLUMN
	while x <= a.end.x - 0.5:
		_front_box(g, Vector3(x - 0.3, a.position.y, zf), Vector3(x + 0.3, a.end.y, zf + 0.09), "deck_concrete")
		x += D.PARK_COLUMN
	_front_box(g, Vector3(a.position.x, a.end.y - 0.25, zf), Vector3(a.end.x, a.end.y, zf + 0.06), "deck_concrete")
	# the roof deck: two rows of painted bays (2.5 m) and a yellow edge line
	var ty: float = a.end.y + 0.003
	for zr: Array in [[a.end.z - 6.0, a.end.z - 1.0], [a.end.z - 13.0, a.end.z - 8.0]]:
		var bx: float = a.position.x + 1.0
		while bx <= a.end.x - 1.0:
			_floor_line(g, Vector3(bx - 0.05, ty, float(zr[0])), Vector3(bx + 0.05, ty, float(zr[1])), "line_white")
			bx += 2.5
	_floor_line(g, Vector3(a.position.x + 0.5, ty, a.end.z - 0.6), Vector3(a.end.x - 0.5, ty, a.end.z - 0.45), "line_white")


func _corvino(a: AABB) -> void:
	var g: String = "N_Corvino"
	# faces toward the play space: north (the lane) and east (the bank roof / terrace), above the bank's roof line
	for face: Array in [["z", a.position.z, -1.0], ["x", a.end.x, 1.0]]:
		var along_x: bool = String(face[0]) == "z"
		var plane: float = float(face[1])
		var sgn: float = float(face[2])
		var u0: float = a.position.x if along_x else a.position.z
		var u1: float = a.end.x if along_x else a.end.z
		var ystart: float = a.position.y if along_x else maxf(a.position.y, 12.2)
		var y: float = a.position.y + D.CORVINO_STOREY
		while y < a.end.y - 0.3:   # string courses
			if y > ystart:
				_proud_box(g, along_x, plane, sgn, u0, u1, y - 0.12, y + 0.12, 0.05, "ashlar_warm")
			y += D.CORVINO_STOREY
		var fy: float = a.position.y
		while fy + D.CORVINO_STOREY <= a.end.y + 0.01:
			var w0: float = fy + D.CORVINO_SILL
			var w1: float = w0 + float(D.CORVINO_WINDOW[1])
			if w0 >= ystart:
				var u: float = u0 + D.CORVINO_BAY * 0.5
				while u + float(D.CORVINO_WINDOW[0]) * 0.5 <= u1 - 0.3:
					var hw: float = float(D.CORVINO_WINDOW[0]) * 0.5
					_proud_box(g, along_x, plane, sgn, u - hw, u + hw, w0, w1, 0.004, "window_dark")
					_proud_box(g, along_x, plane, sgn, u - hw - 0.08, u + hw + 0.08, w0 - 0.08, w0, 0.06, "ashlar_warm")
					_proud_box(g, along_x, plane, sgn, u - hw - 0.05, u + hw + 0.05, w1, w1 + 0.14, 0.03, "ashlar_warm")
					u += D.CORVINO_BAY
			fy += D.CORVINO_STOREY


## A box `depth` proud of a face plane (normal sgn along x or z) over [u0, u1] x [y0, y1].
func _proud_box(g: String, along_x: bool, plane: float, sgn: float, u0: float, u1: float, y0: float, y1: float,
		depth: float, key: String) -> void:
	var p2: float = plane + sgn * depth
	var lo: Vector3 = Vector3(u0, y0, minf(plane, p2)) if along_x else Vector3(minf(plane, p2), y0, u0)
	var hi: Vector3 = Vector3(u1, y1, maxf(plane, p2)) if along_x else Vector3(maxf(plane, p2), y1, u1)
	var back: int = (4 if sgn > 0.0 else 5) if along_x else (0 if sgn > 0.0 else 1)
	for f: int in range(6):
		if f == back:
			continue
		var q: Array[Vector3] = M._face(lo, hi, f)
		acc.call(&"quad", g, key, q[0], q[1], q[2], q[3], NORMALS[f])


## A box standing on a +Z face plane at lo.z: every face but the back (-Z) one.
func _front_box(g: String, lo: Vector3, hi: Vector3, key: String) -> void:
	for f: int in range(6):
		if f == 4:
			continue
		var q: Array[Vector3] = M._face(lo, hi, f)
		acc.call(&"quad", g, key, q[0], q[1], q[2], q[3], NORMALS[f])


func _floor_line(g: String, lo: Vector3, hi: Vector3, key: String) -> void:
	acc.call(&"quad", g, key, lo, Vector3(hi.x, lo.y, lo.z), hi, Vector3(lo.x, lo.y, hi.z), Vector3.UP)


## One trim strip (a box `depth` proud of the run's face from ya to yb): the front in the strip key, the top, the
## bottom (unless on the floor) and the ends in the strip's plain body finish. The run is cut into STRIP_STEP pieces
## and the pieces behind a prop, a fixture, a door frame or a box bank are left out (merged back into spans).
func _strip(group: String, run: Array, ya: float, yb: float, depth: float, key: String, on_floor: bool,
		at_ceiling: bool = false) -> void:
	var n: Vector3 = run[0]
	var plane: float = float(run[1])
	var along_x: bool = bool(run[2])
	var a0: float = float(run[3]) + D.TRIM_END_INSET
	var a1: float = float(run[4]) - D.TRIM_END_INSET
	if a1 - a0 < 0.05:
		return
	var pz: float = plane + (n.z if along_x else n.x) * depth
	var steps: int = maxi(1, ceili((a1 - a0) / D.STRIP_STEP))
	var spans: Array[Vector2] = []
	for i: int in range(steps):
		var sa: float = a0 + (a1 - a0) * float(i) / float(steps)
		var sb: float = a0 + (a1 - a0) * float(i + 1) / float(steps)
		var lo0: Vector3 = Vector3(sa, ya, minf(plane, pz)) if along_x else Vector3(minf(plane, pz), ya, sa)
		var hi0: Vector3 = Vector3(sb, yb, maxf(plane, pz)) if along_x else Vector3(maxf(plane, pz), yb, sb)
		if _blocked(AABB(lo0, hi0 - lo0).grow(0.01)):
			continue
		if not spans.is_empty() and absf(spans[-1].y - sa) < 1e-5:
			spans[-1].y = sb
		else:
			spans.append(Vector2(sa, sb))
	for sp: Vector2 in spans:
		var u0: float = sp.x + (0.0 if absf(sp.x - a0) < 1e-5 else D.TRIM_END_INSET)
		var u1: float = sp.y - (0.0 if absf(sp.y - a1) < 1e-5 else D.TRIM_END_INSET)
		if u1 - u0 >= 0.05:
			_strip_box(group, n, plane, along_x, Vector2(u0, u1), Vector2(ya, yb), depth, key, on_floor, at_ceiling)


## One strip piece: `ur` the span along the wall, `yr` its height.
func _strip_box(group: String, n: Vector3, plane: float, along_x: bool, ur: Vector2, yr: Vector2, depth: float,
		key: String, on_floor: bool, at_ceiling: bool) -> void:
	var u0: float = ur.x
	var u1: float = ur.y
	var ya: float = yr.x
	var yb: float = yr.y
	var p2: float = plane + (n.z if along_x else n.x) * depth
	var lo: Vector3
	var hi: Vector3
	if along_x:
		lo = Vector3(u0, ya, minf(plane, p2))
		hi = Vector3(u1, yb, maxf(plane, p2))
	else:
		lo = Vector3(minf(plane, p2), ya, u0)
		hi = Vector3(maxf(plane, p2), yb, u1)
	var body: String = _trim_body(key)
	for f: int in range(6):
		var fn: Vector3 = NORMALS[f]
		var k: String = body
		if fn.is_equal_approx(n):
			k = key
		elif fn.is_equal_approx(-n) or (f == 2 and on_floor) or (f == 3 and at_ceiling):
			continue
		var q: Array[Vector3] = M._face(lo, hi, f)
		acc.call(&"quad", group, k, q[0], q[1], q[2], q[3], fn)


static func _trim_body(key: String) -> String:
	if key.contains("wood"):
		return "wood"
	if key.contains("metal"):
		return "steel"
	if key.contains("rubber"):
		return "metal_dark"
	if key.begins_with("ashlar"):
		return key
	return "plaster"


## Stone pilasters on the world grid along a long run, clear of the run ends, doors and every prop / fixture.
func _pilasters(group: String, run: Array, ffl: float, h: float, st: Dictionary) -> void:
	var pl: Array = st["pilasters"]
	var w: float = float(pl[1])
	var proud: float = float(pl[2])
	var spacing: float = float(pl[3])
	var y0: float = float(run[5])
	var y1: float = float(run[6])
	var top: float = ffl + h - (float((st["cornice"] as Array)[1]) if st.has("cornice") else 0.0)
	if y0 > ffl + 0.01 or y1 < top - 0.01:
		return
	var u0: float = float(run[3]) + 0.35 + w * 0.5
	var u1: float = float(run[4]) - 0.35 - w * 0.5
	if u1 < u0:
		return
	var k0: int = ceili(u0 / spacing - 0.0001)
	var k1: int = floori(u1 / spacing + 0.0001)
	var n: Vector3 = run[0]
	var plane: float = float(run[1])
	var along_x: bool = bool(run[2])
	for k: int in range(k0, k1 + 1):
		var uc: float = float(k) * spacing
		var p2: float = plane + (n.z if along_x else n.x) * proud
		var lo: Vector3
		var hi: Vector3
		if along_x:
			lo = Vector3(uc - w * 0.5, ffl, minf(plane, p2))
			hi = Vector3(uc + w * 0.5, top, maxf(plane, p2))
		else:
			lo = Vector3(minf(plane, p2), ffl, uc - w * 0.5)
			hi = Vector3(maxf(plane, p2), top, uc + w * 0.5)
		if _blocked(AABB(lo, hi - lo).grow(0.03)):
			continue
		var key: String = String(pl[0])
		for f: int in range(6):
			var fn: Vector3 = NORMALS[f]
			if fn.is_equal_approx(-n) or f == 2:
				continue
			var q: Array[Vector3] = M._face(lo, hi, f)
			acc.call(&"quad", group, key, q[0], q[1], q[2], q[3], fn)
		_counts["pilasters"] += 1


# --- Ceilings ------------------------------------------------------------------------------------

## Coffer grids and beams under the ceilings of CEILING_FEATURES (segments that would hit a fixture are left out).
func _ceilings() -> void:
	var rids: Array = D.CEILING_FEATURES.keys()
	rids.sort()
	for rid: Variant in rids:
		var cf: Array = D.CEILING_FEATURES[rid]
		var rec: Array = _room_rec[String(rid)]
		var x0: float = float(rec[1]) + 0.1
		var z0: float = float(rec[2]) + 0.1
		var x1: float = float(rec[3]) - 0.1
		var z1: float = float(rec[4]) - 0.1
		var cy: float = float(rec[7]) + float(rec[8])
		var kind: String = String(cf[0])
		var key: String = String(cf[1])
		var sp: float = float(cf[2])
		var w: float = float(cf[3])
		var dep: float = float(cf[4])
		var xs: Array[float] = []
		var zs: Array[float] = []
		if kind == "coffer" or kind == "beams_z":
			var nx: int = maxi(1, roundi((x1 - x0) / sp))
			for i: int in range(1, nx):
				xs.append(x0 + (x1 - x0) * float(i) / float(nx))
		if kind == "coffer" or kind == "beams_x":
			if cf.size() > 5:
				for zz: Variant in cf[5]:
					zs.append(float(zz))
			else:
				var nz: int = maxi(1, roundi((z1 - z0) / sp))
				for j: int in range(1, nz):
					zs.append(z0 + (z1 - z0) * float(j) / float(nz))
		var group: String = "D_" + String(rid)
		# beams along z at each x (split at the crossing lines), then along x at each z
		for x: float in xs:
			var cuts: Array[float] = [z0]
			cuts.append_array(zs)
			cuts.append(z1)
			for s: int in range(cuts.size() - 1):
				_beam(group, key, Vector3(x - w * 0.5, cy - dep, cuts[s]), Vector3(x + w * 0.5, cy, cuts[s + 1]))
		for z: float in zs:
			var cuts2: Array[float] = [x0]
			cuts2.append_array(xs)
			cuts2.append(x1)
			for s2: int in range(cuts2.size() - 1):
				_beam(group, key, Vector3(cuts2[s2], cy - dep, z - w * 0.5), Vector3(cuts2[s2 + 1], cy, z + w * 0.5))


func _beam(group: String, key: String, lo: Vector3, hi: Vector3) -> void:
	if hi.x - lo.x < 0.1 or hi.z - lo.z < 0.1:
		return
	if _blocked(AABB(lo, hi - lo).grow(0.04)):
		return
	for f: int in range(6):
		if f == 3:
			continue
		var q: Array[Vector3] = M._face(lo, hi, f)
		acc.call(&"quad", group, key, q[0], q[1], q[2], q[3], NORMALS[f])
	_counts["beams"] += 1


# --- Vault ---------------------------------------------------------------------------------------

## A cage panel over its collider box: posts every CAGE_POST_STEP, top / mid / kick rails, vertical bars.
func _cage(a: AABB) -> void:
	var along_x: bool = a.size.x >= a.size.z
	var u0: float = a.position.x if along_x else a.position.z
	var u1: float = a.end.x if along_x else a.end.z
	var c: float = a.get_center().z if along_x else a.get_center().x
	var y0: float = a.position.y
	var y1: float = a.end.y
	var g: String = "D_VT"
	var k: String = D.CAGE_KEY
	var hp: float = D.CAGE_POST * 0.5
	var posts: Array[float] = [u0 + hp, u1 - hp]
	var n: int = floori((u1 - u0) / D.CAGE_POST_STEP)
	for i: int in range(1, n):
		posts.append(u0 + (u1 - u0) * float(i) / float(n))
	for pu: float in posts:
		_bar(g, k, along_x, pu - hp, pu + hp, c, hp, y0, y1)
	var rails: Array[Vector2] = [Vector2(y1 - 0.06, y1)]
	if y1 - y0 > 0.6:
		rails.append(Vector2(y0, y0 + 0.1))
		if y1 - y0 > 2.0:
			rails.append(Vector2(y0 + 1.1, y0 + 1.15))
	else:
		rails.append(Vector2(y0, y0 + 0.05))
	for r: Vector2 in rails:
		_bar(g, k, along_x, u0, u1, c, 0.025, r.x, r.y)
	var nb: int = floori((u1 - u0) / D.CAGE_BAR_PITCH)
	var hb: float = D.CAGE_BAR * 0.5
	for j: int in range(1, nb):
		var bu: float = u0 + (u1 - u0) * float(j) / float(nb)
		_bar(g, k, along_x, bu - hb, bu + hb, c, hb, y0 + 0.1, y1 - 0.06)
		_counts["cage_bars"] += 1


func _bar(g: String, k: String, along_x: bool, u0: float, u1: float, c: float, half: float, y0: float, y1: float) -> void:
	var lo: Vector3 = Vector3(u0, y0, c - half) if along_x else Vector3(c - half, y0, u0)
	var hi: Vector3 = Vector3(u1, y1, c + half) if along_x else Vector3(c + half, y1, u1)
	acc.call(&"box", g, lo, hi, k)


## Cable trays on hangers along the vault's east and west walls, 0.35 m under the ceiling, in 1 m runs clear of every
## fixture, with a cable bundle in each.
func _vault_trays() -> void:
	var rec: Array = _room_rec["VT"]
	var cy: float = float(rec[7]) + float(rec[8])
	var g: String = "D_VT"
	for side: Array in [[float(rec[1]) + 0.1, 1.0], [float(rec[3]) - 0.1, -1.0]]:
		var face: float = float(side[0])
		var s: float = float(side[1])
		var z: float = float(rec[2]) + 0.6
		while z + 1.0 <= float(rec[4]) - 0.6 + 0.001:
			var x0: float = face + s * 0.08
			var x1: float = face + s * 0.38
			var lo: Vector3 = Vector3(minf(x0, x1), cy - 0.42, z)
			var hi: Vector3 = Vector3(maxf(x0, x1), cy - 0.34, z + 1.0)
			if not _blocked(AABB(lo, hi - lo).grow(0.05)):
				acc.call(&"box", g, Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y + 0.012, hi.z), "steel")
				acc.call(&"box", g, Vector3(lo.x, lo.y, lo.z), Vector3(lo.x + 0.012, hi.y, hi.z), "steel")
				acc.call(&"box", g, Vector3(hi.x - 0.012, lo.y, lo.z), Vector3(hi.x, hi.y, hi.z), "steel")
				acc.call(&"box", g, Vector3(lo.x + 0.03, lo.y + 0.012, lo.z), Vector3(hi.x - 0.03, lo.y + 0.06, hi.z),
					"cable_fabric")
				for hz: float in [z + 0.1, z + 0.9]:
					var hx: float = (lo.x + hi.x) * 0.5
					acc.call(&"box", g, Vector3(hx - 0.006, hi.y, hz - 0.006), Vector3(hx + 0.006, cy, hz + 0.006), "steel")
				_counts["trays"] += 1
			z += 1.0


# --- Output --------------------------------------------------------------------------------------

## One MeshInstance3D per group, one surface per material (the trim strips share the trim sheet, the tinted keys their
## own copies): the accumulator's buckets merged by material, in sorted key order (deterministic).
func _flush(parent: Node3D) -> void:
	var groups: Dictionary = acc.get(&"_groups")
	var mats: Dictionary = acc.get(&"_materials")
	var names: Array = groups.keys()
	names.sort()
	for g: Variant in names:
		var buckets: Dictionary = groups[g]
		var keys: Array = buckets.keys()
		keys.sort()
		var order: Array[Material] = []
		var by_mat: Dictionary = {}
		for k: Variant in keys:
			var m: Material = mats[k]
			if not by_mat.has(m):
				by_mat[m] = []
				order.append(m)
			(by_mat[m] as Array).append(k)
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.resource_name = "of_finish_" + String(g)
		for m2: Material in order:
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for k2: Variant in by_mat[m2]:
				var bk: Dictionary = buckets[k2]
				var vs: PackedVector3Array = bk["v"]
				var ns: PackedVector3Array = bk["n"]
				var us: PackedVector2Array = bk["uv"]
				for i: int in range(vs.size()):
					st.set_normal(ns[i])
					st.set_uv(us[i])
					st.add_vertex(vs[i])
			st.index()
			st.generate_tangents()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, m2)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Visual_" + String(g)
		mi.mesh = mesh
		mi.set_meta(&"finish_d", true)
		var vr: float = D.DETAIL_VIS if String(g).begins_with("D_") else (D.NEIGHBOUR_VIS if String(g).begins_with("N_") else 0.0)
		if vr > 0.0:   # D_: trims, pilasters, beams, cage bars, trays; N_: the neighbours' facade detail
			mi.visibility_range_end = vr
			mi.visibility_range_end_margin = vr * 0.1
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if String(g).begins_with("D_"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.call(&"add", parent, mi)
	groups.clear()
