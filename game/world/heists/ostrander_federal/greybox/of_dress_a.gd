## Ostrander Federal G2 dressing, lane A (OF-C2, ENV C): the grand banking hall BH, the bronze vestibule VE and the
## plaza X1. One call from build_greybox.gd, before the navmesh bake (placed floor props obstruct it):
##   preload(".../of_dress_a.gd").new(self).call(&"build")
## Design: docs/design/heists/ostrander_federal.md (Site: landmarks 1-3; Ground notes; Room list BH / VE / X1;
## Audio/lighting: palette, the hall's 3000 K bronze pendants, every light on a fixture; Budgets: draw calls, hall
## density 0.03-0.06 props/m², the coffered ceiling as one trim mesh). Data: of_dress_a_data.gd. Kits:
## game/world/kits/banking_hall_grand.tres, vestibule_bronze.tres, exterior_plaza.tres (fixed tables, no RNG).
## * Shell finish: every greybox box of Geometry/Building inside the lane's zones (the hall, the vestibule, the plaza
##   face) is hidden and redrawn face by face (world UVs, gh_mesh.gd) in library finishes: a marble floor in ultramarine
##   bands round the meridian inlay, a marble dado and limestone walls, marble pillars in bronze bases and capitals,
##   the bronze vestibule enclosure with a glazed transom, the limestone-and-granite facade. Faces outside the zones
##   get a plain textured stand-in (OTHER_FINISH; the surfaces lane skins its rooms' faces 4 mm proud). Colliders,
##   metas and the navmesh are untouched.
##   Site boxes seen from the plaza get world-triplanar library finishes (paving, granite, asphalt, limestone, brick).
## * The coffered ceiling: limestone beams on the hall's ultramarine ceiling, gilt rosettes, a gilt fillet round the
##   lantern oculus (one merged mesh). The arched windows get bronze bays (prop_of_window_bay) on both faces.
## * The G1 furniture boxes (check desks, benches, queue rails, the kiosk, planters, benches, cars) carry exact-fit art;
##   placed props (pendants, palms, the guard's podium, slip trays, VE's lectern and rope, street lamps, bollards, bins,
##   a bus shelter, two cars) get a box collider and a nav obstruction unless mounted, "on" or ceiling items.
extends RefCounted

const D: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_dress_a_data.gd")
const GH: GDScript = preload("res://world/heists/glasshouse/greybox/gh_mesh.gd")
const LM: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_landmarks.gd")
const OD: GDScript = preload("res://world/heists/ostrander_federal/greybox/of_dress.gd")
const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095)
## A face belongs to the zone holding the point this far in front of it.
const PROBE: float = 0.05
## Claim margin round the zones (the surfaces lane, of_finish.gd, leaves boxes this close to BH / VE / X1 to lane A).
const CLAIM: float = 0.35
## A face is buried (not drawn) when the points this far in front of its centre and inset corners lie in another box.
const BURY: float = 0.02
const BURY_INSET: float = 0.03
## Kinds whose collider and nav obstruction is the pole at the pivot (the lamp's arm overhangs at 5-6 m).
const POLE_KINDS: Array[String] = ["street_lamp"]
const FOLDER: String = "DressA"

var b: Object
var report: PackedStringArray = PackedStringArray()
var _root: HeistMap
var _gh: RefCounted
var _mats: Dictionary = {}
var _tri: Dictionary = {}
var _solids: Array[AABB] = []
var _hidden: int = 0
var _counts: Dictionary = {}


func _init(builder: Object) -> void:
	b = builder


func build() -> void:
	_root = b.get(&"map_root")
	_gh = GH.new()
	_gh.set(&"tile_groups", {"BH_floor": 8.0, "BH_ceil": 16.0})
	for k: String in D.MATERIALS:
		_mat(k)
	_mats["glass"] = LM._glass()
	_gh.call(&"register_material", "glass", _mats["glass"])
	var geo: Node3D = b.call(&"n", "Geometry")
	var fin: Node3D = b.call(&"add", geo, b.call(&"node3d", "FinishA")) as Node3D
	_collect_solids(geo)
	_shell(b.call(&"n", "Geometry/Building") as Node3D)
	_site(b.call(&"n", "Geometry/Site") as Node3D)
	_coffers()
	_hall_trims()
	_facade_trims()
	_street()
	_gh.call(&"flush", fin, _root)
	_window_bays(fin)
	_mapbuilt_art()
	var props: Node3D = b.call(&"add", b.call(&"n", "Props"), b.call(&"node3d", FOLDER)) as Node3D
	_counts["BH"] = _place_all(_folder(props, "BH"), D.BH_PROPS, true) + _pendants(_folder(props, "BH"))
	_counts["VE"] = _place_all(_folder(props, "VE"), D.VE_PROPS, true)
	_counts["X1"] = _place_all(_folder(props, "X1"), D.X1_PROPS, false)
	_fills(b.call(&"add", b.call(&"n", "Lighting"), b.call(&"node3d", "FillA")) as Node3D)
	report.append("lane A: %d shell boxes refinished, BH %d / VE %d / X1 %d placed props, %d map-built art bodies"
		% [_hidden, _counts["BH"], _counts["VE"], _counts["X1"], D.MAPBUILT_ART.size()])
	var errs: PackedStringArray = b.get(&"errors")
	for line: String in report:
		printerr("dress A: " + line)
		if line.begins_with("ERROR"):
			errs.append(line)
	b.set(&"errors", errs)


func _folder(parent: Node3D, nm: String) -> Node3D:
	var f: Node3D = parent.get_node_or_null(nm) as Node3D
	if f == null:
		f = b.call(&"add", parent, b.call(&"node3d", nm)) as Node3D
	return f


func _gx(n: Node3D) -> Transform3D:
	return b.call(&"global_xform", n)


## The material of a finish key (data table, else a greybox library id), registered with the mesh accumulator.
func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var path: String = String(D.MATERIALS.get(key, "res://world/materials/%s.tres" % key))
	var m: Material = load(path) as Material
	if m == null:
		report.append("ERROR finish %s: no material %s" % [key, path])
		m = load("res://world/materials/plaster_painted.tres") as Material
	_mats[key] = m
	_gh.call(&"register_material", key, m)
	return m


## A world-triplanar copy of a finish (512 px/m: 1 repeat per 2 m of a 1024 px tile) for the site's boxes and hulls.
func _triplanar(key: String) -> Material:
	if _tri.has(key):
		return _tri[key]
	var src: BaseMaterial3D = _mat(key) as BaseMaterial3D
	var m: BaseMaterial3D = src.duplicate() as BaseMaterial3D
	m.resource_name = "of_site_" + key
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var tw: float = float(src.albedo_texture.get_width()) if src.albedo_texture != null else 1024.0
	m.uv1_scale = Vector3.ONE * (512.0 / tw)
	_tri[key] = m
	return m


# --- Shell ----------------------------------------------------------------------------------------

## Every box mesh of the building and the site (the buried-face test).
func _collect_solids(geo: Node3D) -> void:
	for n: Node in geo.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh is BoxMesh:
			_solids.append(_gx(mi) * mi.mesh.get_aabb())


## A box whose AABB (+0.35 m, the surfaces-lane convention) touches a lane-A zone is this lane's to refinish.
func _zone_hit(box: AABB) -> bool:
	var g: AABB = box.grow(CLAIM)
	for z: Array in D.ZONES:
		if g.intersects(AABB(z[1], (z[2] as Vector3) - (z[1] as Vector3))):
			return true
	return false


func _shell(bld: Node3D) -> void:
	for n: Node in bld.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var rel: PackedStringArray = String(bld.get_path_to(mi)).split("/")
		if rel.size() < 2 or rel[0] in D.SKIP_GROUPS or not mi.visible:
			continue
		var box: AABB = _gx(mi) * mi.mesh.get_aabb()
		if not _zone_hit(box):
			continue
		var src: Material = mi.get_active_material(0)
		var src_key: String = src.resource_path.get_file().get_basename() if src != null else "grey_wall"
		if src_key == "grey_glass" and String(mi.get_parent().name) != "GuardCap":
			mi.material_override = _mats["glass"]
			continue
		if not (mi.mesh is BoxMesh):
			mi.material_override = _triplanar("of_limestone")  # copings and curbs on the plaza face
			continue
		var body: Node3D = mi.get_parent() as Node3D
		var whole: String = String(D.NAME_FINISH.get(rel[0], D.NAME_FINISH.get(String(body.name), "")))
		mi.visible = false
		_hidden += 1
		if _in(box, D.TRANSOM_LO, D.TRANSOM_HI):
			_transom(box, body)
			continue
		var ve: bool = _in(box, D.VE_BOX_LO, D.VE_BOX_HI)
		for f: int in range(6):
			_face(box, f, src_key, whole, ve, rel[0])
		if rel[0] == "Pillars":
			_pillar_trims(box)


static func _in(box: AABB, lo: Vector3, hi: Vector3) -> bool:
	return box.position.x >= lo.x - 0.001 and box.position.y >= lo.y - 0.001 and box.position.z >= lo.z - 0.001 \
		and box.end.x <= hi.x + 0.001 and box.end.y <= hi.y + 0.001 and box.end.z <= hi.z + 0.001


## Face f of a box (0 -X, 1 +X, 2 -Y, 3 +Y, 4 -Z, 5 +Z): axis, sign, plane, rect [u0, v0, u1, v1] (u, v = the other two
## axes: x-faces (z, y), y-faces (x, z), z-faces (x, y)).
static func _axes(a: int) -> Vector2i:
	return [Vector2i(2, 1), Vector2i(0, 2), Vector2i(0, 1)][a]


func _face(box: AABB, f: int, src_key: String, whole: String, ve: bool, group: String) -> void:
	var a: int = f / 2
	var s: float = -1.0 if f % 2 == 0 else 1.0
	var w: float = box.position[a] if s < 0.0 else box.end[a]
	var uv: Vector2i = _axes(a)
	var rect: Array = [box.position[uv.x], box.position[uv.y], box.end[uv.x], box.end[uv.y]]
	if _buried(box, a, s, w, uv, rect):
		return
	var rest: Array = _uncovered(box, a, s, w, uv, rect)
	for z: Array in D.ZONES:
		var lo: Vector3 = z[1]
		var hi: Vector3 = z[2]
		var p: float = w + s * PROBE
		if p < lo[a] or p > hi[a]:
			continue
		var hole: Array = [lo[uv.x], lo[uv.y], hi[uv.x], hi[uv.y]]
		var nxt: Array = []
		for r: Array in rest:
			var ir: Array = _isect(r, hole)
			if not ir.is_empty():
				_finish(String(z[0]), ir, a, s, w, src_key, whole, ve, group)
			nxt.append_array(_minus(r, hole))
		rest = nxt
	for r2: Array in rest:  # faces outside the zones: a plain textured stand-in (other lanes skin them 4 mm proud)
		_emit(_other_group(w, a), String(D.OTHER_FINISH.get(src_key, "plaster")), r2, a, s, w)


func _other_group(w: float, a: int) -> String:
	return "Other_%d" % (int(floor(w / 4.0)) if a == 1 else 0)


## Whether the face is covered by another box (its centre and inset corners, just in front of it, lie in one).
func _buried(box: AABB, a: int, s: float, w: float, uv: Vector2i, rect: Array) -> bool:
	var pts: Array[Vector2] = [Vector2((rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5)]
	var iu: float = minf(BURY_INSET, (rect[2] - rect[0]) * 0.25)
	var iv: float = minf(BURY_INSET, (rect[3] - rect[1]) * 0.25)
	for cu: float in [rect[0] + iu, rect[2] - iu]:
		for cv: float in [rect[1] + iv, rect[3] - iv]:
			pts.append(Vector2(cu, cv))
	for o: AABB in _solids:
		if o.is_equal_approx(box):
			continue
		var all_in: bool = true
		for q: Vector2 in pts:
			var v: Vector3 = Vector3.ZERO
			v[a] = w + s * BURY
			v[uv.x] = q.x
			v[uv.y] = q.y
			if not o.grow(0.001).has_point(v):
				all_in = false
				break
		if all_in:
			return true
	return false


## The parts of a face not shared with a same-facing coplanar face of another box (a slab top over the walls' tops
## below it; the smaller face keeps the shared part: never two faces in one plane, levelcheck zfight).
func _uncovered(box: AABB, a: int, s: float, w: float, uv: Vector2i, rect: Array) -> Array:
	var rest: Array = [rect]
	for o: AABB in _solids:
		if o.is_equal_approx(box):
			continue
		var ow: float = o.end[a] if s > 0.0 else o.position[a]
		if absf(ow - w) > 0.002:
			continue
		var h: Array = [o.position[uv.x], o.position[uv.y], o.end[uv.x], o.end[uv.y]]
		if _isect(rect, h).is_empty() or (h[2] - h[0]) * (h[3] - h[1]) >= (rect[2] - rect[0]) * (rect[3] - rect[1]):
			continue  # the smaller face keeps the shared part
		var nxt: Array = []
		for r: Array in rest:
			nxt.append_array(_minus(r, h))
		rest = nxt
	return rest


static func _isect(r: Array, h: Array) -> Array:
	var o: Array = [maxf(r[0], h[0]), maxf(r[1], h[1]), minf(r[2], h[2]), minf(r[3], h[3])]
	if o[2] - o[0] < 0.001 or o[3] - o[1] < 0.001:
		return []
	return o


## r minus h as up to four rects (bands below / above h, then left / right of it within h's v-range).
static func _minus(r: Array, h: Array) -> Array:
	var o: Array = _isect(r, h)
	if o.is_empty():
		return [r]
	var out: Array = []
	if o[1] > r[1] + 0.001:
		out.append([r[0], r[1], r[2], o[1]])
	if r[3] > o[3] + 0.001:
		out.append([r[0], o[3], r[2], r[3]])
	if o[0] > r[0] + 0.001:
		out.append([r[0], o[1], o[0], o[3]])
	if r[2] > o[2] + 0.001:
		out.append([o[2], o[1], r[2], o[3]])
	return out


## The finish of a face piece inside a zone (banded walls, painted floors, the zone's ceiling / soffit / tops).
func _finish(zone: String, r: Array, a: int, s: float, w: float, _src_key: String, whole: String, ve: bool,
		group: String) -> void:
	var zf: Dictionary = D.ZONE_FINISH[zone]
	var g: String = _group(zone, r, a, w, group)
	if whole != "":
		_emit(g, whole, r, a, s, w)
		return
	if ve and zone == "BH":  # the vestibule enclosure seen from the hall: dark bronze over a marble skirting
		_bands(g, r, a, s, w, [[D.SKIRT_H, "of_marble_blue"], [INF, "of_bronze_dark"]])
		return
	if a == 1:
		if s > 0.0 and absf(w) < 0.1 and D.FLOOR_PAINT.has(zone):
			_floor(g, zone, r, w, String(zf["floor"]))
		elif s > 0.0:
			_emit(g, String(zf["top"]), r, a, s, w)
		else:
			_emit(g, String(zf["ceiling"]) if w > 7.9 else String(zf["soffit"]), r, a, s, w)
		return
	if zone == "X1":
		_bands(g, r, a, s, w, [[D.PLINTH_H, "of_granite"], [INF, String(zf["wall"])]])
	elif zone == "VE":
		_bands(g, r, a, s, w, [[D.SKIRT_H, "of_marble_blue"], [INF, "marble"]])
	else:
		_bands(g, r, a, s, w, [[D.SKIRT_H, "of_marble_blue"], [D.DADO_H, "marble"], [INF, String(zf["wall"])]])
		_dado_rail(g, r, a, s, w)


func _group(zone: String, r: Array, a: int, w: float, group: String) -> String:
	if zone == "BH" or zone == "BHC":
		if a == 1:
			return "BH_floor" if w < 0.1 else ("BH_ceil" if w > 7.9 else "BH_soffit")
		if group == "Pillars":
			return "BH_pillars"
		var cz: float = (r[0] + r[2]) * 0.5 if a == 0 else w
		return "BH_wall_N" if cz < 26.0 else "BH_wall_S"
	if zone == "X1":
		return "X1_facade"
	return zone


## A vertical piece cut into horizontal bands: [[top y, key], ...] bottom up.
func _bands(g: String, r: Array, a: int, s: float, w: float, bands: Array) -> void:
	var y0: float = r[1]
	for bd: Array in bands:
		var top: float = float(bd[0])
		if r[3] <= y0 + 0.001:
			return
		var y1: float = minf(r[3], top)
		if y1 > y0 + 0.001:
			_emit(g, String(bd[1]), [r[0], y0, r[2], y1], a, s, w)
			if String(bd[1]) == "of_limestone":
				_ashlar(g, [r[0], y0, r[2], y1], a, s, w)
			y0 = y1


## Ashlar coursing over a limestone (or rusticated granite) wall piece: mortar joints 12 mm wide, 3 mm proud (never
## coplanar with the face), courses `course` m high, blocks `block` m long, every other course offset half a block.
func _ashlar(g: String, r: Array, a: int, s: float, w: float, course: float = D.ASHLAR_COURSE,
		block: float = D.ASHLAR_BLOCK) -> void:
	if r[2] - r[0] < 0.3 or r[3] - r[1] < 0.2:
		return
	var jw: float = D.ASHLAR_JOINT * 0.5
	var wj: float = w + s * 0.003
	var k: int = int(ceil(r[1] / course))
	while float(k) * course < r[3] - 0.05:
		var y: float = float(k) * course
		if y > r[1] + 0.05:
			_emit(g, "of_granite", [r[0], y - jw, r[2], y + jw], a, s, wj)
		var ytop: float = minf(r[3], y + course)
		var off: float = 0.0 if k % 2 == 0 else block * 0.5
		var u: float = floor((r[0] - off) / block) * block + off + block
		while u < r[2] - 0.05:
			if u > r[0] + 0.05 and ytop - maxf(y, r[1]) > 0.05:
				_emit(g, "of_granite", [u - jw, maxf(y, r[1]) + jw, u + jw, ytop - jw], a, s, wj)
			u += block
		k += 1


## The bronze dado cap rail (1.08-1.13 m, 25 mm proud) along a hall wall piece wider than 0.5 m (ends held 0.12 m back
## from the openings' architraves).
func _dado_rail(g: String, r: Array, a: int, s: float, w: float) -> void:
	if r[1] > D.DADO_H - 0.02 or r[3] < D.DADO_H + 0.03 or r[2] - r[0] < 0.5:
		return
	var u0: float = r[0] + 0.12
	var u1: float = r[2] - 0.12
	var lo: Vector3 = Vector3.ZERO
	var hi: Vector3 = Vector3.ZERO
	var uv: Vector2i = _axes(a)
	lo[uv.x] = u0
	hi[uv.x] = u1
	lo[1] = D.DADO_H - 0.02
	hi[1] = D.DADO_H + 0.03
	lo[a] = w if s > 0.0 else w - 0.025
	hi[a] = w + 0.025 if s > 0.0 else w
	_box(g, lo, hi, "of_bronze", a * 2 + (0 if s > 0.0 else 1))


## A floor piece through the zone's paint rects (the first holding a part wins; "" leaves no face), the field after.
func _floor(g: String, zone: String, r: Array, w: float, field: String) -> void:
	var rest: Array = [r]
	for row: Array in D.FLOOR_PAINT[zone]:
		var h: Array = [row[0], row[1], row[2], row[3]]
		var nxt: Array = []
		for q: Array in rest:
			var ir: Array = _isect(q, h)
			if not ir.is_empty() and String(row[4]) != "":
				_emit(g, String(row[4]), ir, 1, 1.0, w)
			nxt.append_array(_minus(q, h))
		rest = nxt
	for q2: Array in rest:
		_emit(g, field, q2, 1, 1.0, w)


## One rect on a face plane as a quad (normal = sign along axis a).
func _emit(g: String, key: String, r: Array, a: int, s: float, w: float) -> void:
	if key == "":
		return
	_mat(key)
	var uv: Vector2i = _axes(a)
	var c: Array[Vector3] = []
	for k: Vector2 in [Vector2(r[0], r[1]), Vector2(r[2], r[1]), Vector2(r[2], r[3]), Vector2(r[0], r[3])]:
		var v: Vector3 = Vector3.ZERO
		v[a] = w
		v[uv.x] = k.x
		v[uv.y] = k.y
		c.append(v)
	var n: Vector3 = Vector3.ZERO
	n[a] = s
	_gh.call(&"quad", g, key, c[0], c[1], c[2], c[3], n)


## A trim box's faces in one finish, `skip` = the face index not drawn (-1: none; its back on a wall / ceiling), or an
## Array of them (a beam's top and the ends against the walls).
func _box(g: String, lo: Vector3, hi: Vector3, key: String, skip: Variant) -> void:
	var box: AABB = AABB(lo, hi - lo)
	for f: int in range(6):
		if (skip is int and f == int(skip)) or (skip is Array and f in (skip as Array)):
			continue
		var a: int = f / 2
		var s: float = -1.0 if f % 2 == 0 else 1.0
		var uv: Vector2i = _axes(a)
		_emit(g, key, [box.position[uv.x], box.position[uv.y], box.end[uv.x], box.end[uv.y]], a, s,
			box.position[a] if s < 0.0 else box.end[a])


## Marble pillars: a bronze base (0-0.22 m) and a bronze capital under the gallery slab (3.92-4.2 m).
func _pillar_trims(box: AABB) -> void:
	var g: String = "BH_pillars"
	_box(g, Vector3(box.position.x - 0.04, 0.0, box.position.z - 0.04), Vector3(box.end.x + 0.04, 0.22,
		box.end.z + 0.04), "of_bronze", 2)
	_box(g, Vector3(box.position.x - 0.06, box.end.y - 0.28, box.position.z - 0.06), Vector3(box.end.x + 0.06,
		box.end.y, box.end.z + 0.06), "of_bronze", 3)
	_box(g, Vector3(box.position.x - 0.025, 0.22, box.position.z - 0.025), Vector3(box.end.x + 0.025, 0.3,
		box.end.z + 0.025), "of_marble_blue", -1)


## The glazed transom over the vestibule's inner doors (x 21.9-23.9 / 24.1-26.1, 2.2-4.4 m): one two-sided glass pane
## on the wall's centre plane in a bronze frame (rails, stiles, two muntins), bronze head soffit and top. The wall's
## collider stays (it blocks movement and bullets) and joins the glazing's `see_through` group (D-142: vision passes).
func _transom(box: AABB, body: Node3D) -> void:
	var g: String = "VE_transom"
	var zc: float = box.get_center().z
	_emit(g, "glass", [box.position.x, box.position.y, box.end.x, box.end.y], 2, 1.0, zc)
	var x0: float = box.position.x
	var x1: float = box.end.x
	var y0: float = box.position.y
	var y1: float = box.end.y
	var z0: float = zc - 0.05
	var z1: float = zc + 0.05
	_box(g, Vector3(x0, y0, box.position.z), Vector3(x1, y0 + 0.1, box.end.z), "of_bronze", -1)
	_box(g, Vector3(x0, y1 - 0.12, box.position.z), Vector3(x1, y1, box.end.z), "of_bronze_dark", -1)
	for xs: Array in [[x0, x0 + 0.08], [x1 - 0.08, x1]]:
		_box(g, Vector3(xs[0], y0 + 0.1, z0), Vector3(xs[1], y1 - 0.12, z1), "of_bronze", -1)
	for t: float in [1.0 / 3.0, 2.0 / 3.0]:
		var xm: float = lerpf(x0, x1, t)
		_box(g, Vector3(xm - 0.025, y0 + 0.1, z0 + 0.01), Vector3(xm + 0.025, y1 - 0.12, z1 - 0.01), "of_bronze", -1)
	_box(g, Vector3(x0 + 0.08, lerpf(y0, y1, 0.5) - 0.02, z0 + 0.01), Vector3(x1 - 0.08, lerpf(y0, y1, 0.5) + 0.02,
		z1 - 0.01), "of_bronze", -1)
	(body as Node).add_to_group(&"see_through", true)
	body.set_meta(&"see_through", true)


func _site(site: Node3D) -> void:
	for n: Node in site.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var nm: String = String(mi.name) if mi.name != &"Mesh" else String(mi.get_parent().name)
		if not D.SITE_FINISH.has(nm):
			continue
		mi.material_override = _triplanar(String(D.SITE_FINISH[nm]))


# --- The coffered ceiling, the facade, the street ---------------------------------------------------------

## Limestone beams on the ultramarine ceiling (8.0), gilt rosettes at the whole coffers' centres, the gilt oculus
## fillet (one merged group: beam soffits are narrower than the tile grid's minimum span).
func _coffers() -> void:
	var g: String = "BH_beams"
	var ox0: float = D.OCULUS[0]
	var oz0: float = D.OCULUS[1]
	var ox1: float = D.OCULUS[2]
	var oz1: float = D.OCULUS[3]
	for bx: Array in D.COFFER_X:
		var x: float = bx[0]
		var spans: Array = [[D.COFFER_Z0, oz0], [oz1, D.COFFER_Z1]] if x > ox0 + 0.01 and x < ox1 - 0.01 \
			else [[D.COFFER_Z0, D.COFFER_Z1]]
		for sp: Array in spans:
			_box(g, Vector3(x - float(bx[1]), D.CEIL - float(bx[2]), sp[0]), Vector3(x + float(bx[1]), D.CEIL, sp[1]),
				"of_limestone", _wall_ends(3, 2, float(sp[0]), float(sp[1]), D.COFFER_Z0, D.COFFER_Z1)
				+ _wall_ends(-1, 0, x - float(bx[1]), x + float(bx[1]), D.COFFER_X0, D.COFFER_X1))
	for bz: Array in D.COFFER_Z:
		var z: float = bz[0]
		var spans2: Array = [[D.COFFER_X0, ox0], [ox1, D.COFFER_X1]] if z > oz0 + 0.01 and z < oz1 - 0.01 \
			else [[D.COFFER_X0, D.COFFER_X1]]
		for sp2: Array in spans2:
			_box(g, Vector3(sp2[0], D.CEIL - float(bz[2]) - 0.004, z - float(bz[1])),
				Vector3(sp2[1], D.CEIL, z + float(bz[1])), "of_limestone",
				_wall_ends(3, 0, float(sp2[0]), float(sp2[1]), D.COFFER_X0, D.COFFER_X1)
				+ _wall_ends(-1, 2, z - float(bz[1]), z + float(bz[1]), D.COFFER_Z0, D.COFFER_Z1))
	var rs: Vector2 = D.ROSETTE
	for i: int in range(D.COFFER_X.size() - 1):
		var cx: float = (float(D.COFFER_X[i][0]) + float(D.COFFER_X[i + 1][0])) * 0.5
		for j: int in range(D.COFFER_Z.size() - 1):
			var cz: float = (float(D.COFFER_Z[j][0]) + float(D.COFFER_Z[j + 1][0])) * 0.5
			if cx > ox0 and cx < ox1 and cz > oz0 and cz < oz1:
				continue
			_box(g, Vector3(cx - rs.x, D.CEIL - rs.y, cz - rs.x), Vector3(cx + rs.x, D.CEIL, cz + rs.x), "of_gilt", 3)
	var t: float = 0.03
	var y0: float = D.CEIL - 0.45
	var y1: float = D.CEIL + 0.6
	_box(g, Vector3(ox0, y0, oz0 + t), Vector3(ox0 + t, y1, oz1 - t), "of_gilt", -1)
	_box(g, Vector3(ox1 - t, y0, oz0 + t), Vector3(ox1, y1, oz1 - t), "of_gilt", -1)
	_box(g, Vector3(ox0, y0, oz0), Vector3(ox1, y1, oz0 + t), "of_gilt", -1)
	_box(g, Vector3(ox0, y0, oz1 - t), Vector3(ox1, y1, oz1), "of_gilt", -1)


## The hall's pilasters on the window piers (limestone shafts on marble pedestals, bronze-banded capitals), the
## limestone cornice under the ceiling's perimeter beam, bronze panel strips on the vestibule's marble walls, the gilt
## bead under the major beams.
func _hall_trims() -> void:
	for pl: Array in D.PILASTERS:
		var x: float = pl[0]
		var hw: float = D.PILASTER_W * 0.5
		var z1: float = D.HALL_S_FACE
		var z0: float = z1 - D.PILASTER_D
		var gg: String = "BH_wall_S"
		_box(gg, Vector3(x - hw - 0.04, 0.0, z0 - 0.04), Vector3(x + hw + 0.04, D.DADO_H, z1), "marble", 5)
		_box(gg, Vector3(x - hw - 0.05, D.DADO_H, z0 - 0.05), Vector3(x + hw + 0.05, D.DADO_H + 0.08, z1), "of_bronze", 5)
		_box(gg, Vector3(x - hw, D.DADO_H + 0.08, z0), Vector3(x + hw, D.CORNICE_Y0 - 0.3, z1), "of_limestone", 5)
		_box(gg, Vector3(x - hw - 0.06, D.CORNICE_Y0 - 0.3, z0 - 0.06), Vector3(x + hw + 0.06, D.CORNICE_Y0 - 0.22, z1),
			"of_gilt", 5)
		_box(gg, Vector3(x - hw - 0.08, D.CORNICE_Y0 - 0.22, z0 - 0.08), Vector3(x + hw + 0.08, D.CORNICE_Y0, z1),
			"of_limestone", 5)
	for cs: Array in D.CORNICES:
		var gc: String = "BH_wall_S"
		_box(gc, Vector3(cs[0], D.CORNICE_Y0, D.HALL_S_FACE - 0.3), Vector3(cs[1], D.CORNICE_Y0 + 0.16, D.HALL_S_FACE),
			"of_limestone", [0, 1, 5])
		_box(gc, Vector3(cs[0], D.CORNICE_Y0 + 0.16, D.HALL_S_FACE - 0.22), Vector3(cs[1], D.CEIL - 0.45,
			D.HALL_S_FACE), "of_gilt", [0, 1, 5])
	for st: Array in D.VE_STRIPS:  # [axis, plane w, sign, u] vertical bronze strips 0.15-4.0 m
		var a: int = int(st[0])
		var w: float = st[1]
		var sg: float = st[2]
		var u: float = st[3]
		var lo: Vector3 = Vector3.ZERO
		var hi: Vector3 = Vector3.ZERO
		var uv: Vector2i = _axes(a)
		lo[uv.x] = u - 0.02
		hi[uv.x] = u + 0.02
		lo[1] = D.SKIRT_H
		hi[1] = 4.0
		lo[a] = w if sg > 0.0 else w - 0.012
		hi[a] = w + 0.012 if sg > 0.0 else w
		_box("VE", lo, hi, "of_bronze", a * 2 + (0 if sg > 0.0 else 1))
	for bx: Array in D.COFFER_X:  # gilt bead under the major beams
		if float(bx[1]) < 0.2:
			continue
		_box("BH_beams", Vector3(float(bx[0]) - 0.03, D.CEIL - float(bx[2]) - 0.02, D.COFFER_Z0),
			Vector3(float(bx[0]) + 0.03, D.CEIL - float(bx[2]), D.COFFER_Z1), "of_gilt", 3)


## The faces a beam does not draw: its top (on the ceiling) and an end on a wall (axis a: 0 x / 2 z).
static func _wall_ends(top: int, a: int, s0: float, s1: float, w0: float, w1: float) -> Array:
	var out: Array = [top]
	if absf(s0 - w0) < 0.001:
		out.append(a * 2)
	if absf(s1 - w1) < 0.001:
		out.append(a * 2 + 1)
	return out


## Plaza-face trims (z 36.2): the granite plinth cap, the string course at the gallery floor, the cornice.
func _facade_trims() -> void:
	for t: Array in D.FACADE_TRIMS:
		_box("X1_facade", Vector3(t[0], t[2], 36.2), Vector3(t[1], t[3], 36.2 + float(t[4])), String(t[5]), 4)
	for wn: Array in D.SMALL_WINDOWS:  # bronze frames round the gallery-level windows, both faces of the glass
		for zz: Array in [[36.02, 36.07], [35.93, 35.98]]:
			var z0: float = zz[0]
			var z1: float = zz[1]
			_box("X1_facade", Vector3(wn[0], wn[2], z0), Vector3(wn[1], wn[2] + 0.06, z1), "of_bronze", -1)
			_box("X1_facade", Vector3(wn[0], wn[3] - 0.06, z0), Vector3(wn[1], wn[3], z1), "of_bronze", -1)
			_box("X1_facade", Vector3(wn[0], wn[2] + 0.06, z0), Vector3(wn[0] + 0.06, wn[3] - 0.06, z1), "of_bronze", -1)
			_box("X1_facade", Vector3(wn[1] - 0.06, wn[2] + 0.06, z0), Vector3(wn[1], wn[3] - 0.06, z1), "of_bronze", -1)
			var xm: float = (float(wn[0]) + float(wn[1])) * 0.5
			_box("X1_facade", Vector3(xm - 0.02, wn[2] + 0.06, z0 + 0.005), Vector3(xm + 0.02, wn[3] - 0.06, z1 - 0.005),
				"of_bronze", -1)


## Halloran Avenue's lane markings and the far sidewalk / plaza kerb strips (5 mm over the grade: visual only).
func _street() -> void:
	var y: float = D.FP + 0.005
	for ll: Array in D.LANE_LINES:
		var z: float = ll[0]
		var hw: float = ll[1]
		var dash: float = ll[2]
		var gap: float = ll[3]
		if gap <= 0.0:
			_emit("X1_street", "paint_white", [D.STREET_X0, z - hw, D.STREET_X1, z + hw], 1, 1.0, y)
			continue
		var x: float = D.STREET_X0 + 1.0
		while x + dash < D.STREET_X1:
			_emit("X1_street", "paint_white", [x, z - hw, x + dash, z + hw], 1, 1.0, y)
			x += dash + gap
	for sw: Array in D.SIDEWALK_STRIPS:
		_emit("X1_street", String(sw[2]), [D.STREET_X0, sw[0], D.STREET_X1, sw[1]], 1, 1.0, y)


## The arched windows' bronze bays, on the plaza face (yaw 180, back on the glass at z 36.02) and the hall face (eight
## instances: a baked MultiMesh read at the origin in levelcheck's zfight pass, so plain instances).
func _window_bays(fin: Node3D) -> void:
	var ps: PackedScene = b.call(&"catalog_scene", "prop_of_window_bay") as PackedScene
	if ps == null:
		return
	var holder: Node3D = b.call(&"add", fin, b.call(&"node3d", "WindowBays")) as Node3D
	for wb: Array in D.WINDOW_BAYS:
		for side: Array in [["Out", PI, 36.02], ["In", 0.0, 35.98]]:
			var inst: Node3D = ps.instantiate() as Node3D
			inst.name = "Bay%s%s" % [wb[0], side[0]]
			inst.transform = Transform3D(Basis(Vector3.UP, float(side[1])),
				Vector3(float(wb[1]), D.WINDOW_SILL, float(side[2])))
			b.call(&"add", holder, inst)


# --- Furniture and props ------------------------------------------------------------------------------

## G1 furniture boxes -> exact-fit art: the greybox mesh is hidden, the art stands at the box's floor centre.
func _mapbuilt_art() -> void:
	for row: Array in D.MAPBUILT_ART:
		var body: StaticBody3D = _root.get_node_or_null("Props/MapBuilt/" + String(row[0])) as StaticBody3D
		if body == null:
			report.append("ERROR map-built %s not found" % row[0])
			continue
		var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
		var mi: MeshInstance3D = body.get_node_or_null("Mesh") as MeshInstance3D
		if cs == null or not (cs.shape is BoxShape3D) or mi == null:
			report.append("ERROR map-built %s: no box collider / mesh" % row[0])
			continue
		var size: Vector3 = (cs.shape as BoxShape3D).size
		mi.visible = false
		var vis: Node3D = _instance(String(row[1]), body.position.z < 36.0)
		if vis == null:
			continue
		vis.name = "Visual"
		vis.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(row[2]))), cs.position - Vector3(0.0, size.y * 0.5, 0.0))
		b.call(&"add", body, vis)
		body.set_meta(&"art_asset", String(row[1]))
		for co: Node in vis.find_children("*", "CollisionObject3D", true, false):
			(co as CollisionObject3D).collision_layer = 0
			for s: Node in co.find_children("*", "CollisionShape3D", true, false):
				(s as CollisionShape3D).disabled = true
			_root.set_editable_instance(vis, true)


## A catalog scene instance (interior: lane C's size-banded near-range wrapper).
func _instance(asset: String, interior: bool) -> Node3D:
	var e: Dictionary = PropCatalog.entry(StringName(asset))
	var path: String = String(e.get("scene", ""))
	if path == "":
		report.append("ERROR no catalog asset %s" % asset)
		return null
	if interior and String(e.get("place", "")) != "ceiling":
		path = OD.near_scene_path(asset, path)
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		report.append("ERROR cannot load %s" % path)
		return null
	return ps.instantiate() as Node3D


func _place_all(parent: Node3D, rows: Array, interior: bool) -> int:
	var n: int = 0
	for r: Array in rows:
		if _place(parent, String(r[0]), String(r[1]), b.call(&"v3", r[2]), float(r[3]), interior) != null:
			n += 1
	return n


func _place(parent: Node3D, nm: String, asset: String, pos: Vector3, yaw: float, interior: bool) -> Node3D:
	var inst: Node3D = _instance(asset, interior)
	if inst == null:
		return null
	var cat: Dictionary = PropCatalog.entry(StringName(asset))
	inst.name = nm
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), pos)
	var mount: String = String(cat.get("mount", ""))
	var place: String = String(cat.get("place", "floor"))
	if mount == "wall":  # the given point is the item's centre on the wall face
		var a: Array = cat.get("aabb", [0, 0, 0, 0, 0, 0])
		xf.origin -= Vector3.UP * (float(a[1]) + float(a[4]) * 0.5)
		xf.origin += xf.basis * Vector3(0.0, 0.0, -0.002)
	inst.transform = xf
	b.call(&"add", parent, inst)
	if not interior and inst.get_node_or_null("Light") is Light3D:
		_light(inst, {"light_energy": D.EXT_LIGHT_ENERGY})
	if mount != "" or place in ["on", "ceiling", "wall_mount", "above_door", "rug"]:
		return inst
	_collide(inst, cat, xf)
	return inst


## Box collider from the catalog AABB (cut at its `top`; a lamp's pole only) + a nav obstruction (as lanes B / C).
func _collide(inst: Node3D, cat: Dictionary, xf: Transform3D) -> void:
	var a: Array = cat.get("aabb", [])
	if a.size() != 6:
		return
	var bb: AABB = AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]))
	var top: float = float(cat.get("top", 0.0))
	if top > 0.0 and top < bb.end.y:
		bb.size.y = top - bb.position.y
	if String(cat.get("kind", "")) in POLE_KINDS:
		bb = AABB(Vector3(bb.position.x, bb.position.y, -bb.size.x * 0.5), Vector3(bb.size.x, bb.size.y, bb.size.x))
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


## The hall's ten bronze drum pendants (3000 K) at coffer centres; SHADOW_PENDANTS cast shadows.
func _pendants(parent: Node3D) -> int:
	var n: int = 0
	for p: Array in D.PENDANTS:
		var inst: Node3D = _place(parent, String(p[0]), "prop_of_hall_pendant", p[1], 0.0, true)
		if inst == null:
			continue
		n += 1
		if String(p[0]) in D.SHADOW_PENDANTS:
			# D-146: dual paraboloid (2 shadow passes, not the cube's 6)
			_light(inst, {"shadow_enabled": true, "omni_shadow_mode": OmniLight3D.SHADOW_DUAL_PARABOLOID})
	return n


func _light(inst: Node3D, props: Dictionary) -> void:
	var lt: Light3D = inst.get_node_or_null("Light") as Light3D
	if lt == null:
		return
	_root.set_editable_instance(inst, true)
	for k: Variant in props:
		lt.set(StringName(String(k)), props[k])


## Soft warm fill under the coffers (level_standards §3.7: meta fill, energy <= 0.3, no shadows, <= 2 per room).
func _fills(parent: Node3D) -> void:
	for f: Array in D.FILLS:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = String(f[0])
		light.position = f[1]
		light.light_color = Color(1.0, 0.86, 0.7)
		light.light_energy = 0.28
		light.omni_range = float(f[2])
		light.layers = 1 | VIEWMODEL_LIT_LAYER
		light.shadow_enabled = false
		light.set_meta(&"fill", true)
		b.call(&"add", parent, light)
