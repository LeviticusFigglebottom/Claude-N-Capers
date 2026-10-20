## Ostrander Federal G2 skyline lane (OF-C2, ENV C): the downtown round the site, so no reachable eye sees the void
## (levelcheck `bounds`, final). Design: docs/design/heists/ostrander_federal.md §Site (Play-space closure: the avenue
## vistas to the west bend facade and the domed Exchange tower east, Tannery north to a T-junction facade, the lane's
## west end; Far: financial-district towers on every side at 80-300 m).
## Built, visual only (no collider; the navmesh, baked from the Geometry colliders, is unchanged):
##   - the far grade (one plane under the whole city, minus the bank's footprint and basement) and the street
##     continuations at their levels: Halloran Avenue west / east with its sidewalks, Ledger Lane west, Tannery Street
##     north and the cross street at its T-junction;
##   - the inner city: brick / limestone / concrete / stucco blocks closing every street axis, with limestone string
##     courses, cornices and roof plant; punched two-pane window bays, lit ~1 in 5;
##   - the far ring of financial-district towers (curtain-wall floor bands, some floors lit) and the Exchange tower with
##     its drum and verdigris dome at the avenue's east end;
##   - box occluders for every block (Lighting/Occluders, of_gi.gd's pattern).
## Draw calls: one MeshInstance3D per quadrant (one indexed surface per finish; every window bay, floor band and
## shopfront of the quadrant is in its `glass` / `lit` surface) and one ground mesh: <= 34 surfaces in all. The bays are
## merged rather than MultiMesh instances: the same draw calls, and levelcheck builds one proxy body per MultiMesh
## instance (bounds / zfight), where the Jolt body cap (10240) is already reached by the map. Nothing here casts shadows
## (the SW sun shafts into the hall stay as lit) or joins the VoxelGI bake.
## Used by build_greybox.gd after of_gi.gd's build():  preload(".../of_skyline.gd").new(self).call(&"build")
extends RefCounted

const L: GDScript = preload("res://world/heists/ostrander_federal/greybox/ostrander_federal_layout.gd")
const MAT_DIR: String = "res://world/materials/"
## Library textures tile every 2 m (metadata uv_tile_m): 512 px/m.
const UV_M: float = 2.0
const CENTRE: Vector2 = Vector2(24.0, 18.0)
## Far grade: under every street and block (2-8 cm below the site's grades, never coplanar with them).
const GRADE_Y: float = -0.83
const FAR_GRADE: Array = [-300.0, -260.0, 340.0, 320.0]
## No far grade over the bank's basement (its ceilings are at -0.8); the hall and plaza front stand on fill.
const BANK_HOLE: Array = [-0.4, -0.4, 48.6, 25.4]
## Street continuations [x0, z0, x1, z1, top y, finish]: the avenue (-0.75, as the site's avenue) and the north streets
## (0.0, as the lane and Tannery Street). Each abuts the site's grade or police islands, never overlaps them.
const STREETS: Array = [
	[-150.0, 48.0, -44.0, 62.0, -0.75, "asphalt"],     # Halloran Ave west, past P1 to the bend facade
	[-150.0, 44.0, -44.0, 48.0, -0.75, "paving"],      # its north sidewalk
	[-44.0, 36.0, -16.4, 48.0, -0.75, "paving"],       # the avenue's north side west of the closure, to Corvino
	[-150.0, 62.0, -16.4, 66.0, -0.75, "paving"],      # south sidewalk west of the Assay Office
	[94.0, 42.0, 175.0, 62.0, -0.75, "asphalt"],       # Halloran Ave east, past P2 to the Exchange
	[66.0, 38.0, 175.0, 42.0, -0.75, "paving"],        # its north sidewalk
	[66.4, 62.0, 175.0, 66.0, -0.75, "paving"],        # its south sidewalk
	[-80.0, -10.0, -44.0, 0.3, 0.0, "paving"],         # Ledger Lane west, past P3 to its end facade
	[48.2, -82.0, 62.0, -50.0, 0.0, "asphalt"],        # Tannery Street north, past P4
	[-180.0, -96.0, 175.0, -82.0, 0.0, "asphalt"],     # the cross street at the T-junction
]
## Inner city blocks [x0, z0, x1, z1, height, finish]: contiguous round the site (shared faces between blocks; 0.3 m
## off the site's neighbours: Corvino, the parking structure, the Belmont Arms, the Assay Office).
const BLOCKS: Array = [
	# west: Corvino's neighbours on the avenue and the lane, the lane's end facade, the avenue's bend facade
	[-44.0, 0.3, -20.3, 18.0, 24.0, "brick"],
	[-44.0, 18.0, -20.3, 36.0, 31.0, "limestone"],
	[-80.0, 0.3, -44.0, 22.0, 22.0, "brick_dark"],
	[-80.0, 22.0, -44.0, 44.0, 28.0, "plaster"],
	[-80.0, -40.0, -44.0, -10.0, 20.0, "concrete"],
	[-110.0, -40.0, -80.0, 44.0, 30.0, "limestone"],
	[-150.0, -40.0, -110.0, 10.0, 24.0, "brick"],
	[-150.0, 10.0, -110.0, 44.0, 33.0, "limestone"],
	[-180.0, -82.0, -150.0, 100.0, 36.0, "concrete"],
	[-180.0, -124.0, -110.0, -96.0, 30.0, "limestone"],
	[-150.0, -82.0, -110.0, -40.0, 28.0, "plaster"],
	# north-west and north: behind the lane and the parking structure, the T-junction facade
	[-44.0, -46.3, -16.3, -10.3, 22.0, "brick"],
	[-110.0, -82.0, -44.0, -40.0, 26.0, "brick_dark"],
	[-44.0, -82.0, -16.0, -46.3, 29.0, "plaster"],
	[-16.0, -82.0, 20.0, -46.3, 26.0, "limestone"],
	[20.0, -82.0, 48.2, -46.3, 34.0, "concrete"],
	[-110.0, -124.0, 20.0, -96.0, 28.0, "brick_dark"],
	[20.0, -124.0, 100.0, -96.0, 32.0, "limestone"],
	[100.0, -124.0, 175.0, -96.0, 26.0, "concrete"],
	# north-east and east: across Tannery north of the Belmont, behind the Belmont, the avenue's north side east
	[62.3, -82.0, 100.0, -48.0, 30.0, "brick"],
	[62.3, -48.0, 100.0, -14.3, 24.0, "plaster"],
	[100.0, -82.0, 140.0, -14.3, 36.0, "concrete"],
	[80.3, -14.3, 140.0, 12.0, 30.0, "limestone"],
	[80.3, 12.0, 140.0, 38.0, 26.0, "brick"],
	[140.0, -82.0, 175.0, 38.0, 34.0, "brick_dark"],
	[175.0, -124.0, 205.0, 30.0, 28.0, "limestone"],
	[175.0, 80.0, 205.0, 130.0, 26.0, "concrete"],
	# south: the avenue's south side either side of the Assay Office, and behind it
	[-150.0, 66.0, -110.0, 100.0, 26.0, "limestone"],
	[-110.0, 66.0, -60.0, 100.0, 30.0, "brick"],
	[-60.0, 66.0, -16.3, 100.0, 22.0, "plaster"],
	[66.3, 66.0, 100.0, 100.0, 28.0, "brick"],
	[100.0, 66.0, 140.0, 100.0, 32.0, "limestone"],
	[140.0, 66.0, 175.0, 100.0, 24.0, "plaster"],
	[-16.0, 90.3, 25.0, 130.0, 30.0, "brick_dark"],
	[25.0, 90.3, 66.0, 130.0, 36.0, "limestone"],
	[-180.0, 100.0, -110.0, 130.0, 28.0, "concrete"],
	[-110.0, 100.0, -16.0, 130.0, 34.0, "brick"],
	[66.0, 100.0, 175.0, 130.0, 30.0, "concrete"],
]
## The Exchange tower closing the avenue east (doc: "the domed Exchange tower facade"): base, shaft, drum + dome.
const EXCHANGE_BASE: Array = [175.0, 30.0, 205.0, 80.0, 30.0, "limestone"]
const EXCHANGE_SHAFT: Array = [181.0, 46.0, 199.0, 64.0, 62.0, "limestone"]
const DOME_C: Vector3 = Vector3(190.0, 62.0, 55.0)
const DOME_R: float = 8.6
const DRUM_H: float = 6.0
## Far ring of towers (financial district, 200-300 m out): [x0, z0, x1, z1] rows (whole 40 m towers), heights cycling.
const RING_N: Array = [-260.0, -230.0, 300.0, -200.0]
const RING_S: Array = [-260.0, 240.0, 300.0, 270.0]
const RING_W: Array = [-260.0, -200.0, -230.0, 240.0]
const RING_E: Array = [270.0, -200.0, 300.0, 240.0]
const RING_HEIGHTS: Array = [62.0, 48.0, 88.0, 55.0, 104.0, 70.0, 50.0, 95.0, 66.0, 78.0, 58.0, 84.0]
const RING_FINISH: Array[String] = ["concrete", "limestone", "concrete", "plaster"]
const TOWER_W: float = 40.0
## Inner facades: storey height, first upper-floor sill above the ground, window bays (two panes) per 4 m.
const STOREY: float = 3.6
const FIRST_SILL: float = 5.4
const BAY: float = 4.0
const PANE: Vector2 = Vector2(1.3, 1.9)
const PANE_GAP: float = 0.7
const WIN_OFF: float = 0.06
## Limestone string course over the ground floor, cornice at the top (overhang, depth).
const STRING_Y: Vector2 = Vector2(4.4, 4.8)
const STRING_D: float = 0.15
const CORNICE_H: float = 0.8
const CORNICE_D: float = 0.45
## finish key -> [library material, albedo tint]
const FINISH: Dictionary = {
	"brick": ["brick_red", Color(1.0, 1.0, 1.0)],
	"brick_dark": ["brick_red", Color(0.68, 0.6, 0.56)],
	"limestone": ["limestone_ashlar", Color(1.0, 1.0, 1.0)],
	"concrete": ["concrete", Color(0.9, 0.9, 0.9)],
	"plaster": ["plaster_painted", Color(0.95, 0.86, 0.72)],
	"verdigris": ["metal_painted", Color(0.42, 0.66, 0.58)],
	"asphalt": ["asphalt", Color(1.0, 1.0, 1.0)],
	"paving": ["concrete", Color(1.0, 0.98, 0.94)],
}
## Untextured glass (meta untextured_ok): key -> [albedo, emission, energy, metallic, roughness].
const GLASS: Dictionary = {
	"glass": [Color(0.15, 0.19, 0.25), Color(0.0, 0.0, 0.0), 0.0, 0.6, 0.12],
	"lit": [Color(0.96, 0.88, 0.7), Color(1.0, 0.86, 0.62), 0.9, 0.0, 0.4],
}
const QUADS: Array[String] = ["N", "E", "S", "W"]
const OCC_MIN: float = 8.0
const OCC_INSET: float = 0.5

var b: Object
var counts: Dictionary = {}
var _mats: Dictionary = {}
## quadrant -> finish -> SurfaceTool
var _st: Dictionary = {}
var _ground: Dictionary = {}
var _occ: Array = []
## Footprints that hide a facade up to their top (the site's closures, the bank, the blocks): [Rect2, top y].
var _solid: Array = []


func _init(builder: Object) -> void:
	b = builder


func build() -> void:
	var root: Node = b.get(&"map_root")
	for row: Array in L.SITE_BOXES:
		if String(row[0]) == "Closures" and float((row[3] as Array)[1]) >= 8.0:
			_solid.append([_rect(float(row[2][0]), float(row[2][2]), float(row[3][0]), float(row[3][2])), float(row[3][1])])
	_solid.append([_rect(0.0, 0.0, 48.4, 36.4), 13.3])
	for q: String in QUADS:
		_st[q] = {}
	var blocks: Array = []
	for bk: Array in BLOCKS:
		if float(bk[4]) > 0.0:
			blocks.append(bk)
			_solid.append([_rect(float(bk[0]), float(bk[1]), float(bk[2]), float(bk[3])), float(bk[4])])
	_ground_build()
	for i: int in range(blocks.size()):
		_block(blocks[i], i)
	_exchange()
	var towers: Array = _ring()
	for j: int in range(towers.size()):
		_tower(towers[j], j)
	var geo: Node3D = root.get_node("Geometry") as Node3D
	var sky: Node3D = Node3D.new()
	sky.name = "Skyline"
	b.call(&"add", geo, sky)
	counts["surfaces"] = _flush(sky)
	counts["blocks"] = blocks.size() + 2
	counts["towers"] = towers.size()
	var occ_parent: Node3D = root.get_node_or_null("Lighting/Occluders") as Node3D
	if occ_parent == null:
		occ_parent = Node3D.new()
		occ_parent.name = "SkylineOccluders"
		b.call(&"add", root.get_node("Lighting"), occ_parent)
	counts["occluders"] = _occluders(occ_parent)
	print("of_skyline: %d blocks, %d towers, %d surfaces, %d window bays, %d occluders" % [counts["blocks"],
		counts["towers"], counts["surfaces"], counts["bays"], counts["occluders"]])


static func _rect(x0: float, z0: float, x1: float, z1: float) -> Rect2:
	return Rect2(minf(x0, x1), minf(z0, z1), absf(x1 - x0), absf(z1 - z0))


## Quadrant of a footprint centre seen from the site centre.
static func _quad(cx: float, cz: float) -> String:
	var d: Vector2 = Vector2(cx, cz) - CENTRE
	if absf(d.x) > absf(d.y):
		return "E" if d.x > 0.0 else "W"
	return "S" if d.y > 0.0 else "N"


## Street level in front of a facade point: the north streets (lane, Tannery) at 0.0, the avenue side at -0.75.
static func _street_y(x: float, z: float) -> float:
	if z < 1.0 or (x > 48.0 and z < 38.0):
		return 0.0
	return -0.75


static func _hash(a: int, c: int, d: int) -> int:
	var h: int = (a * 73856093) ^ (c * 19349663) ^ (d * 83492791)
	return absi(h) % 1000


# --- Materials -----------------------------------------------------------------------------------

func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: BaseMaterial3D = null
	if GLASS.has(key):
		var g: Array = GLASS[key]
		m = StandardMaterial3D.new()
		m.albedo_color = g[0]
		m.metallic = float(g[3])
		m.roughness = float(g[4])
		if float(g[2]) > 0.0:
			m.emission_enabled = true
			m.emission = g[1]
			m.emission_energy_multiplier = float(g[2])
		m.set_meta(&"untextured_ok", true)
	else:
		var f: Array = FINISH[key]
		var base: BaseMaterial3D = load(MAT_DIR + String(f[0]) + ".tres") as BaseMaterial3D
		if base == null:
			var errs: PackedStringArray = b.get(&"errors")
			errs.append("of_skyline: missing material %s" % f[0])
			b.set(&"errors", errs)
			base = StandardMaterial3D.new()
		m = base.duplicate() as BaseMaterial3D
		m.albedo_color = f[1]
	m.resource_name = "of_sky_" + key
	_mats[key] = m
	return m


func _tool(q: String, key: String) -> SurfaceTool:
	var d: Dictionary = _st[q] if q != "" else _ground
	if not d.has(key):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		d[key] = st
	return d[key]


# --- Geometry primitives -------------------------------------------------------------------------

## A planar quad: corners counter-clockwise seen from outside (right-hand around `n`); Godot's front faces wind
## clockwise, so the triangles are emitted reversed. UVs are planar in metres / UV_M (upright on walls).
static func _quad_to(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	var horiz: bool = absf(n.y) > 0.5
	var t: Vector3 = Vector3.RIGHT if horiz else Vector3.UP.cross(n).normalized()
	for p: Vector3 in [p0, p2, p1, p0, p3, p2]:
		st.set_normal(n)
		if horiz:
			st.set_uv(Vector2(p.x, p.z) / UV_M)
		else:
			st.set_uv(Vector2(p.dot(t), -p.y) / UV_M)
		st.add_vertex(p)


## Axis box from world corners: the 4 sides and the top (the bottom is never seen).
static func _box_to(st: SurfaceTool, lo: Vector3, hi: Vector3, top: bool = true) -> void:
	var a: Vector3 = lo
	var e: Vector3 = hi
	_quad_to(st, Vector3(a.x, a.y, e.z), Vector3(e.x, a.y, e.z), Vector3(e.x, e.y, e.z), Vector3(a.x, e.y, e.z), Vector3.BACK)
	_quad_to(st, Vector3(e.x, a.y, a.z), Vector3(a.x, a.y, a.z), Vector3(a.x, e.y, a.z), Vector3(e.x, e.y, a.z), Vector3.FORWARD)
	_quad_to(st, Vector3(e.x, a.y, e.z), Vector3(e.x, a.y, a.z), Vector3(e.x, e.y, a.z), Vector3(e.x, e.y, e.z), Vector3.RIGHT)
	_quad_to(st, Vector3(a.x, a.y, a.z), Vector3(a.x, a.y, e.z), Vector3(a.x, e.y, e.z), Vector3(a.x, e.y, a.z), Vector3.LEFT)
	if top:
		_quad_to(st, Vector3(a.x, e.y, e.z), Vector3(e.x, e.y, e.z), Vector3(e.x, e.y, a.z), Vector3(a.x, e.y, a.z), Vector3.UP)


## A flat horizontal rect at height y (facing up).
static func _flat_to(st: SurfaceTool, r: Rect2, y: float) -> void:
	_quad_to(st, Vector3(r.position.x, y, r.end.y), Vector3(r.end.x, y, r.end.y), Vector3(r.end.x, y, r.position.y),
		Vector3(r.position.x, y, r.position.y), Vector3.UP)


## `r` minus `holes` as disjoint rects (row bands).
static func _rects_minus(r: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = [r]
	for h: Rect2 in holes:
		var nxt: Array[Rect2] = []
		for c: Rect2 in out:
			if not c.intersects(h):
				nxt.append(c)
				continue
			var i: Rect2 = c.intersection(h)
			if i.position.y > c.position.y:
				nxt.append(Rect2(c.position.x, c.position.y, c.size.x, i.position.y - c.position.y))
			if i.end.y < c.end.y:
				nxt.append(Rect2(c.position.x, i.end.y, c.size.x, c.end.y - i.end.y))
			if i.position.x > c.position.x:
				nxt.append(Rect2(c.position.x, i.position.y, i.position.x - c.position.x, i.size.y))
			if i.end.x < c.end.x:
				nxt.append(Rect2(i.end.x, i.position.y, c.end.x - i.end.x, i.size.y))
		out = nxt
	return out


# --- Ground --------------------------------------------------------------------------------------

func _ground_build() -> void:
	var g: Array = FAR_GRADE
	var hole: Array[Rect2] = [_rect(float(BANK_HOLE[0]), float(BANK_HOLE[1]), float(BANK_HOLE[2]), float(BANK_HOLE[3]))]
	for r: Rect2 in _rects_minus(_rect(float(g[0]), float(g[1]), float(g[2]), float(g[3])), hole):
		_flat_to(_tool("", "asphalt"), r, GRADE_Y)
	for s: Array in STREETS:
		_box_to(_tool("", String(s[5])), Vector3(float(s[0]), GRADE_Y, float(s[1])), Vector3(float(s[2]), float(s[4]), float(s[3])))


# --- Inner blocks --------------------------------------------------------------------------------

func _block(bk: Array, idx: int) -> void:
	var x0: float = float(bk[0])
	var z0: float = float(bk[1])
	var x1: float = float(bk[2])
	var z1: float = float(bk[3])
	var h: float = float(bk[4])
	var fin: String = String(bk[5])
	var q: String = _quad((x0 + x1) * 0.5, (z0 + z1) * 0.5)
	var st: SurfaceTool = _tool(q, fin)
	_box_to(st, Vector3(x0, GRADE_Y, z0), Vector3(x1, h - CORNICE_H, z1), false)
	var lime: SurfaceTool = _tool(q, "limestone")
	_box_to(lime, Vector3(x0 - CORNICE_D, h - CORNICE_H, z0 - CORNICE_D), Vector3(x1 + CORNICE_D, h, z1 + CORNICE_D))
	_occ.append(["Block%02d" % idx, Vector3(x0, GRADE_Y, z0), Vector3(x1, h - CORNICE_H, z1)])
	# roof plant (doc §Site, Up: every visible roof has a parapet and plant)
	var cx: float = (x0 + x1) * 0.5
	var cz: float = (z0 + z1) * 0.5
	var pw: float = minf(8.0, (x1 - x0) * 0.3)
	var pd: float = minf(6.0, (z1 - z0) * 0.3)
	_box_to(_tool(q, "concrete"), Vector3(cx - pw * 0.5, h, cz - pd * 0.5), Vector3(cx + pw * 0.5, h + 2.6, cz + pd * 0.5))
	for n: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		_facade(q, fin, x0, z0, x1, z1, h, n, idx)


## One facade: the string course (non-limestone finishes), the ground-floor shopfront glass and the upper window bays,
## only where the face is seen: it looks toward the site, and only above whatever stands in front of it (the median of
## three probes along the face: a neighbour's top, e.g. the parking structure's +12).
func _facade(q: String, fin: String, x0: float, z0: float, x1: float, z1: float, h: float, n: Vector3, idx: int) -> void:
	var along_x: bool = absf(n.z) > 0.5
	var a0: float = x0 if along_x else z0
	var a1: float = x1 if along_x else z1
	var fixed: float = ((z1 if n.z > 0.0 else z0) if along_x else (x1 if n.x > 0.0 else x0))
	var mid: Vector2 = Vector2((a0 + a1) * 0.5, fixed) if along_x else Vector2(fixed, (a0 + a1) * 0.5)
	if (CENTRE - mid).dot(Vector2(n.x, n.z)) <= 0.0 and not _faces_street(mid, n):
		return
	var tops: Array[float] = []
	for f: float in [0.2, 0.5, 0.8]:
		var a: float = lerpf(a0, a1, f)
		var p: Vector2 = (Vector2(a, fixed) if along_x else Vector2(fixed, a)) + Vector2(n.x, n.z) * 0.8
		var top: float = -INF
		for sr: Array in _solid:
			if (sr[0] as Rect2).has_point(p):
				top = maxf(top, float(sr[1]))
		tops.append(top)
	tops.sort()
	var occ_y: float = tops[1]
	if occ_y >= h - CORNICE_H - 3.0:
		return
	var gy: float = _street_y(mid.x, mid.y + n.z * 2.0) if along_x else _street_y(mid.x + n.x * 2.0, mid.y)
	var open_ground: bool = occ_y == -INF
	if fin != "limestone" and open_ground:
		var lo: Vector3
		var hi: Vector3
		# one band per face, only its outer slab (the x-faces' bands run past the corners)
		if along_x:
			var zf: float = fixed + n.z * STRING_D
			lo = Vector3(x0 - STRING_D, gy + STRING_Y.x, minf(fixed, zf))
			hi = Vector3(x1 + STRING_D, gy + STRING_Y.y, maxf(fixed, zf))
		else:
			var xf: float = fixed + n.x * STRING_D
			lo = Vector3(minf(fixed, xf), gy + STRING_Y.x, z0)
			hi = Vector3(maxf(fixed, xf), gy + STRING_Y.y, z1)
		_box_to(_tool(q, "limestone"), lo, hi)
	var t: Vector3 = Vector3.UP.cross(n)
	var off: float = WIN_OFF
	# shopfront glass: 4.4 m panes on a 6 m pitch, 0.5 m above the street
	var nb: int = int(floor((a1 - a0 - 2.0) / 6.0)) if open_ground else 0
	var start: float = (a0 + a1) * 0.5 - float(nb) * 3.0
	for k: int in range(nb):
		var c: float = start + 3.0 + float(k) * 6.0
		var base: Vector3 = (Vector3(c, 0.0, fixed) if along_x else Vector3(fixed, 0.0, c)) + n * off
		_pane(_tool(q, "glass"), base, t, n, 4.4, gy + 0.5, gy + 3.6)
	# upper floors: two-pane bays on a 4 m pitch
	var cols: int = int(floor((a1 - a0 - 3.0) / BAY))
	var c0: float = (a0 + a1) * 0.5 - float(cols - 1) * BAY * 0.5
	var row: int = 0
	var y: float = gy + FIRST_SILL + PANE.y * 0.5
	while y + PANE.y * 0.5 < h - CORNICE_H - 0.9:
		if y - PANE.y * 0.5 < occ_y + 0.5:
			y += STOREY
			row += 1
			continue
		for k2: int in range(cols):
			var c2: float = c0 + float(k2) * BAY
			var p3: Vector3 = (Vector3(c2, y, fixed) if along_x else Vector3(fixed, y, c2)) + n * off
			var lit: bool = _hash(idx * 7 + int(n.x * 3.0 + n.z * 5.0 + 8.0), row, k2) < 190
			_bay_to(_tool(q, "lit" if lit else "glass"), p3, t, n)
		y += STOREY
		row += 1


## Outer faces of the inner city that front a street continuation still get windows (the cross street's north side).
static func _faces_street(mid: Vector2, n: Vector3) -> bool:
	var p: Vector2 = mid + Vector2(n.x, n.z) * 3.0
	for s: Array in STREETS:
		if _rect(float(s[0]), float(s[1]), float(s[2]), float(s[3])).has_point(p):
			return true
	return false


## One window bay: two panes centred on `c` (its centre), along `t`, facing `n`.
func _bay_to(st: SurfaceTool, c: Vector3, t: Vector3, n: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		var pc: Vector3 = c + t * side * (PANE.x + PANE_GAP) * 0.5
		_pane(st, pc, t, n, PANE.x, c.y - PANE.y * 0.5, c.y + PANE.y * 0.5)
	counts["bays"] = int(counts.get("bays", 0)) + 1


## A vertical pane centred on `base` (x/z) along `t`, from y0 to y1.
static func _pane(st: SurfaceTool, base: Vector3, t: Vector3, n: Vector3, w: float, y0: float, y1: float) -> void:
	var a: Vector3 = Vector3(base.x, 0.0, base.z) - t * w * 0.5
	var e: Vector3 = Vector3(base.x, 0.0, base.z) + t * w * 0.5
	_quad_to(st, Vector3(a.x, y0, a.z), Vector3(e.x, y0, e.z), Vector3(e.x, y1, e.z), Vector3(a.x, y1, a.z), n)


# --- The Exchange tower --------------------------------------------------------------------------

func _exchange() -> void:
	var bs: Array = EXCHANGE_BASE
	_block(bs, 90)
	var sh: Array = EXCHANGE_SHAFT
	var q: String = "E"
	var lime: SurfaceTool = _tool(q, "limestone")
	_box_to(lime, Vector3(float(sh[0]), float(bs[4]), float(sh[1])), Vector3(float(sh[2]), float(sh[4]), float(sh[3])))
	_occ.append(["ExchangeShaft", Vector3(float(sh[0]), float(bs[4]), float(sh[1])), Vector3(float(sh[2]), float(sh[4]), float(sh[3]))])
	# shaft windows on the west face (toward the avenue)
	var y: float = float(bs[4]) + 2.0 + PANE.y * 0.5
	var row: int = 0
	while y + PANE.y * 0.5 < float(sh[4]) - 1.5:
		for k: int in range(4):
			var z: float = float(sh[1]) + 3.0 + float(k) * 4.0
			var lit: bool = _hash(91, row, k) < 150
			_bay_to(_tool(q, "lit" if lit else "glass"), Vector3(float(sh[0]) - WIN_OFF, y, z), Vector3.BACK, Vector3.LEFT)
		y += STOREY
		row += 1
	# drum (limestone) and dome (verdigris)
	var seg: int = 24
	var r: float = DOME_R
	var c: Vector3 = DOME_C
	for i: int in range(seg):
		var t0: float = TAU * float(i) / float(seg)
		var t1: float = TAU * float(i + 1) / float(seg)
		var p0: Vector3 = c + Vector3(cos(t0), 0.0, sin(t0)) * r
		var p1: Vector3 = c + Vector3(cos(t1), 0.0, sin(t1)) * r
		var nm: Vector3 = Vector3(cos((t0 + t1) * 0.5), 0.0, sin((t0 + t1) * 0.5))
		# counter-clockwise around the outward normal: p1 -> p0 at the bottom (y up, angle grows toward +z)
		_quad_to(lime, p1, p0, p0 + Vector3.UP * DRUM_H, p1 + Vector3.UP * DRUM_H, nm)
	var dome: SurfaceTool = _tool(q, "verdigris")
	var rings: int = 8
	var top: Vector3 = c + Vector3.UP * DRUM_H
	for j: int in range(rings):
		var l0: float = PI * 0.5 * float(j) / float(rings)
		var l1: float = PI * 0.5 * float(j + 1) / float(rings)
		for i2: int in range(seg):
			var t2: float = TAU * float(i2) / float(seg)
			var t3: float = TAU * float(i2 + 1) / float(seg)
			var q00: Vector3 = top + Vector3(cos(t2) * cos(l0), sin(l0), sin(t2) * cos(l0)) * r
			var q10: Vector3 = top + Vector3(cos(t3) * cos(l0), sin(l0), sin(t3) * cos(l0)) * r
			var q11: Vector3 = top + Vector3(cos(t3) * cos(l1), sin(l1), sin(t3) * cos(l1)) * r
			var q01: Vector3 = top + Vector3(cos(t2) * cos(l1), sin(l1), sin(t2) * cos(l1)) * r
			_sphere_quad(dome, [q10, q00, q01, q11], [Vector2(t3, l0), Vector2(t2, l0), Vector2(t2, l1), Vector2(t3, l1)], top, r)
	_occ.append(["ExchangeDrum", c + Vector3(-r * 0.6, 0.0, -r * 0.6), c + Vector3(r * 0.6, DRUM_H, r * 0.6)])


## A dome facet: normals radial, UVs from the (longitude, latitude) parameters as arc lengths (metres / UV_M).
static func _sphere_quad(st: SurfaceTool, p: Array, ll: Array, centre: Vector3, r: float) -> void:
	for k: int in [0, 2, 1, 0, 3, 2]:
		var v: Vector3 = p[k]
		var a: Vector2 = ll[k]
		st.set_normal(((v - centre) / r).normalized())
		st.set_uv(Vector2(-a.x * r, -a.y * r) / UV_M)
		st.add_vertex(v)


# --- Far ring ------------------------------------------------------------------------------------

## The ring's towers: north / south rows across the full width, west / east columns between them.
static func _ring() -> Array:
	var out: Array = []
	var k: int = 0
	for row: Array in [RING_N, RING_S]:
		var x: float = float(row[0])
		while x < float(row[2]) - 0.1:
			var x1: float = minf(x + TOWER_W, float(row[2]))
			out.append([x, float(row[1]), x1, float(row[3]), float(RING_HEIGHTS[k % RING_HEIGHTS.size()]), k])
			x = x1
			k += 1
	for col: Array in [RING_W, RING_E]:
		var z: float = float(col[1])
		while z < float(col[3]) - 0.1:
			var z1: float = minf(z + TOWER_W, float(col[3]))
			out.append([float(col[0]), z, float(col[2]), z1, float(RING_HEIGHTS[(k * 5) % RING_HEIGHTS.size()]), k])
			z = z1
			k += 1
	return out


## A curtain-wall tower: body, a set-back crown, glazed floor bands (some floors lit) on its site-facing faces.
func _tower(tw: Array, idx: int) -> void:
	var x0: float = float(tw[0])
	var z0: float = float(tw[1])
	var x1: float = float(tw[2])
	var z1: float = float(tw[3])
	var h: float = float(tw[4])
	var fin: String = RING_FINISH[idx % RING_FINISH.size()]
	var q: String = _quad((x0 + x1) * 0.5, (z0 + z1) * 0.5)
	var st: SurfaceTool = _tool(q, fin)
	_box_to(st, Vector3(x0, GRADE_Y, z0), Vector3(x1, h, z1))
	var inset: float = 6.0 + float(idx % 3) * 2.0
	var crown: float = 6.0 + float(idx % 4) * 3.0
	_box_to(st, Vector3(x0 + inset, h, z0 + inset), Vector3(x1 - inset, h + crown, z1 - inset))
	_occ.append(["Tower%02d" % idx, Vector3(x0, GRADE_Y, z0), Vector3(x1, h, z1)])
	for n: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		var along_x: bool = absf(n.z) > 0.5
		var fixed: float = ((z1 if n.z > 0.0 else z0) if along_x else (x1 if n.x > 0.0 else x0))
		var a0: float = x0 if along_x else z0
		var a1: float = x1 if along_x else z1
		var mid: Vector2 = Vector2((a0 + a1) * 0.5, fixed) if along_x else Vector2(fixed, (a0 + a1) * 0.5)
		if (CENTRE - mid).dot(Vector2(n.x, n.z)) <= 0.0:
			continue
		var t: Vector3 = Vector3.UP.cross(n)
		var base: Vector3 = (Vector3(mid.x, 0.0, fixed) if along_x else Vector3(fixed, 0.0, mid.y)) + n * WIN_OFF
		var y: float = 4.0
		var row: int = 0
		while y + 2.4 < h - 1.5:
			var lit: bool = _hash(idx, row, 3) < 160
			_pane(_tool(q, "lit" if lit else "glass"), base, t, n, (a1 - a0) - 2.0, y, y + 2.4)
			y += 3.8
			row += 1


# --- Output --------------------------------------------------------------------------------------

## One MeshInstance3D per quadrant (a surface per finish, sorted keys) and the ground.
func _flush(sky: Node3D) -> int:
	var surfaces: int = _commit(sky, "Ground", _ground)
	for q: String in QUADS:
		surfaces += _commit(sky, "City" + q, _st[q])
	counts["bays"] = int(counts.get("bays", 0))
	return surfaces


func _commit(sky: Node3D, nm: String, tools: Dictionary) -> int:
	if tools.is_empty():
		return 0
	var mesh: ArrayMesh = ArrayMesh.new()
	var keys: Array = tools.keys()
	keys.sort()
	for key: String in keys:
		var st: SurfaceTool = tools[key]
		st.index()
		if not GLASS.has(key):
			st.generate_tangents()
		st.set_material(_mat(key))
		st.commit(mesh)
	mesh.resource_name = "of_sky_" + nm.to_lower()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	_visual(mi)
	b.call(&"add", sky, mi)
	return keys.size()


## Far visuals: no shadows (the low SW sun keeps its shafts into the hall), out of the VoxelGI bake, levelcheck distant.
static func _visual(gi: GeometryInstance3D) -> void:
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	gi.set_meta(&"distant", true)


## Box occluders (of_gi.gd's pattern), inset, for every block and tower >= OCC_MIN on both plan sides.
func _occluders(parent: Node3D) -> int:
	var root: Node = b.get(&"map_root")
	var k: int = 0
	for r: Array in _occ:
		var a: Vector3 = r[1]
		var e: Vector3 = r[2]
		var sz: Vector3 = e - a
		if minf(sz.x, sz.z) < OCC_MIN or sz.y < OCC_MIN:
			continue
		var inset: Vector3 = Vector3(OCC_INSET, OCC_INSET, OCC_INSET)
		var occ: OccluderInstance3D = OccluderInstance3D.new()
		occ.name = "OccSky%03d%s" % [k, String(r[0])]
		occ.position = (a + e) * 0.5
		var bo: BoxOccluder3D = BoxOccluder3D.new()
		bo.size = sz - inset * 2.0
		occ.occluder = bo
		parent.add_child(occ)
		occ.owner = root
		k += 1
	return k
