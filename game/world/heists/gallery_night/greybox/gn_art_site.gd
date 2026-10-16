## Gallery Night G2 art pass, outside (GN-C2, ENV C): the Beaux-Arts limestone facade (granite plinth from the @ext face
## rule, a string course at the upper floor, a modillion cornice at every street wall top, pilasters for the blind
## arcades, stone architraves and bronze glazing bars at the windows), the gilded halberd over the portico (landmark),
## the red carpet and street markings, the neighbours' windows, the skyline ring and far grade (no void, levelcheck
## `bounds`) and the occluders. Visual only: everything goes to the art accumulator (gn_art.gd) or is an occluder.
extends RefCounted

const L: GDScript = preload("res://world/heists/gallery_night/greybox/gallery_night_layout.gd")
const AE: GDScript = preload("res://world/heists/gallery_night/greybox/gn_assault.gd")
## Neighbour massing classes (CLOSURES name -> art class) and the faces that show windows.
const CLOSURE_CLASS: Dictionary = {
	"MewsHouses": "brick", "GrandWexleyHotel": "render", "OstranderConservatory": "stucco", "CourtWallW": "limestone",
	"CourtWallN": "limestone", "CourtWallSW": "limestone", "CourtWallSE": "limestone", "MewsGate": "door",
	"ParadeWBarriers": "trim", "ParadeEBarriers": "trim", "WexleyNBarriers": "trim", "ParkRailings": "trim",
	"GalaCoach": "hidden", "PressVan": "hidden", "CateringTruck": "hidden",
}
## The vehicle closures' visuals (catalog scenes, part of the closure geometry, beyond the barriers):
## closure -> [[scene, position, yaw]].
const CLOSURE_VEHICLES: Dictionary = {
	"GalaCoach": [["res://world/props/secure_zone/veh_limo_gala.tscn", Vector3(-42.1, 0.0, 38.9), 0.0],
		["res://world/props/secure_zone/veh_limo_gala.tscn", Vector3(-42.1, 0.0, 45.65), 0.0]],
	"PressVan": [["res://world/props/secure_zone/veh_van_secure.tscn", Vector3(72.0, 0.0, 43.0), 0.0]],
	"CateringTruck": [["res://world/props/secure_zone/veh_van_secure.tscn", Vector3(53.0, 0.0, -24.6), 90.0]],
}
## [closure, face normal, floor height (m), first floor y] for the window grids.
const NEIGHBOUR_WINDOWS: Array = [
	["MewsHouses", Vector3.BACK, 3.0, 0.9],
	["GrandWexleyHotel", Vector3.LEFT, 3.2, 4.0],
	["OstranderConservatory", Vector3.RIGHT, 4.0, 1.2],
]
## String course (top of the ground floor) and the cornice depth.
const STRING_Y: Vector2 = Vector2(5.05, 5.4)
const STRING_D: float = 0.08
const CORNICE_H: float = 0.45
const CORNICE_D: float = 0.22
## Blind-arcade pilasters on the gallery street walls: width, relief, spacing.
const PILASTER_W: float = 0.7
const PILASTER_D: float = 0.06
const PILASTER_STEP: float = 4.0
## Skyline ring (city blocks round the site, past the play space): four contiguous rows of blocks (no gaps a level eye
## ray could pass through); [x0, z0, x1, z1, height] built by _skyline_blocks().
const SKYLINE_N: Array = [-60.0, -110.0]
const SKYLINE_S: Array = [95.0, 150.0]
const SKYLINE_W: Array = [-160.0, -105.0]
const SKYLINE_E: Array = [110.0, 165.0]
const SKYLINE_HEIGHTS: Array = [34.0, 22.0, 40.0, 28.0, 46.0, 26.0, 31.0, 38.0, 24.0]
## Far grade: one plane 2 cm under the play grades (inside their boxes) out to 600 m, minus the building footprint and the
## areaway light well (it must never show inside the stair wells or the well).
const FAR_GRADE: Array = [-600.0, -600.0, 600.0, 600.0, -0.02]
const FAR_HOLES: Array = [[-0.2, -0.2, 44.2, 30.2], [-4.2, 12.8, -0.2, 15.2]]
## The gilded halberd (landmark 2) on the portico wall over the bronze doors: shaft x, base y, top y, wall face z.
const HALBERD: Array = [21.0, 4.6, 9.6, 30.2]
## Red carpet: from the bronze doors to the kerb [x0, z0, x1, z1].
const CARPET: Array = [19.0, 30.2, 23.0, 36.0]

var art: RefCounted


func _init(a: RefCounted) -> void:
	art = a


# --- Facade -------------------------------------------------------------------------------------

## Exterior wall runs (on the footprint, 0.4 m): [axis, fixed, a0, a1, y0, y1, outward sign].
static func ext_runs() -> Array:
	var out: Array = []
	for w: Array in L.WALLS:
		var f: String = String(w[0])
		if f == "B" or float(w[5]) < L.EXT_T - 0.001:
			continue
		var ft: Array = L.FOOT[f]
		var axis: String = String(w[1])
		var fixed: float = float(w[2])
		var lo: float = float(ft[1]) if axis == "x" else float(ft[0])
		var hi: float = float(ft[3]) if axis == "x" else float(ft[2])
		if absf(fixed - lo) > 0.001 and absf(fixed - hi) > 0.001:
			continue
		out.append([axis, fixed, float(w[3]), float(w[4]), float(w[6]), float(w[7]), -1.0 if absf(fixed - lo) < 0.001 else 1.0, f])
	return out


func facade() -> void:
	for r: Array in ext_runs():
		var axis: String = String(r[0])
		var fixed: float = float(r[1])
		var out_s: float = float(r[6])
		var face: float = fixed + out_s * L.EXT_T * 0.5
		var f: String = String(r[7])
		var span: Vector2 = Vector2(float(r[2]), float(r[3]))
		if f == "G" or (f == "U" and float(r[4]) <= STRING_Y.x):
			for run: Vector2 in art.wall_runs(f, axis, fixed, span.x, span.y, STRING_Y.x, STRING_Y.y):
				_band(axis, face, out_s, run, STRING_Y.x, STRING_Y.y, STRING_D, "limestone_plaster_painted")
		if f == "U":
			var top: float = float(r[5])
			for run2: Vector2 in art.wall_runs(f, axis, fixed, span.x, span.y, top - CORNICE_H, top):
				_band(axis, face, out_s, run2, top - CORNICE_H, top - CORNICE_H + 0.15, CORNICE_D * 0.5, "ashlar_marble_cream")
				_band(axis, face, out_s, run2, top - CORNICE_H + 0.15, top - 0.08, CORNICE_D, "ashlar_marble_cream")
				_band(axis, face, out_s, run2, top - 0.08, top, CORNICE_D + 0.04, "ashlar_marble_cream")
		if f == "G" or f == "U":
			_pilasters(axis, fixed, face, out_s, span, f, float(r[4]), STRING_Y.x if f == "G" else float(r[5]) - CORNICE_H)
	_window_surrounds()
	_halberd()


func _band(axis: String, face: float, outward: float, run: Vector2, ya: float, yb: float, d: float, key: String) -> void:
	var lo: Vector3
	var hi: Vector3
	if axis == "x":
		lo = Vector3(run.x, ya, minf(face, face + outward * d))
		hi = Vector3(run.y, yb, maxf(face, face + outward * d))
	else:
		lo = Vector3(minf(face, face + outward * d), ya, run.x)
		hi = Vector3(maxf(face, face + outward * d), yb, run.y)
	var back: int = (5 if outward < 0.0 else 4) if axis == "x" else (1 if outward < 0.0 else 0)
	var nrm: Vector3 = Vector3(0.0, 0.0, outward) if axis == "x" else Vector3(outward, 0.0, 0.0)
	art.acc.box(art.call(&"shell_group", (lo + hi) * 0.5, nrm), lo, hi,
		func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == back else key)


## Pilasters every PILASTER_STEP m along solid stretches of a street wall, from the plinth top to `y1`.
func _pilasters(axis: String, fixed: float, face: float, out_s: float, span: Vector2, f: String, y0: float, y1: float) -> void:
	var ya: float = maxf(y0, 0.6) if f == "G" else STRING_Y.y
	if y1 - ya < 1.0:
		return
	var a: float = ceilf((span.x + 1.0) / PILASTER_STEP) * PILASTER_STEP
	while a < span.y - 1.0:
		var r: Vector2 = Vector2(a - PILASTER_W * 0.5, a + PILASTER_W * 0.5)
		var runs: Array[Vector2] = art.wall_runs(f, axis, fixed, r.x, r.y, ya, y1)
		if runs.size() == 1 and runs[0].y - runs[0].x > PILASTER_W - 0.01:
			_band(axis, face, out_s, r, ya, y1, PILASTER_D, "ashlar_marble_cream")
		a += PILASTER_STEP


## Stone architraves (jambs, head, sill) round every facade window and bronze glazing bars over the greybox panes.
func _window_surrounds() -> void:
	for o: Array in L.OPENINGS:
		# gameplay windows (EB, SL: WindowPrefab with its own frame) and the breach window keep their own surrounds
		if String(o[1]) != "W" or String(o[8]).contains("tall window") or AE.replaced(o):
			continue
		var f: String = String(o[0])
		var axis: String = String(o[2])
		var fixed: float = float(o[3])
		var ft: Array = L.FOOT[f]
		var lo_line: float = float(ft[1]) if axis == "x" else float(ft[0])
		var hi_line: float = float(ft[3]) if axis == "x" else float(ft[2])
		if absf(fixed - lo_line) > 0.001 and absf(fixed - hi_line) > 0.001:
			continue
		var out_s: float = -1.0 if absf(fixed - lo_line) < 0.001 else 1.0
		var face: float = fixed + out_s * L.EXT_T * 0.5
		var a0: float = float(o[4])
		var a1: float = float(o[5])
		var y0: float = float(o[6])
		var y1: float = float(o[7])
		var w: float = 0.16
		var d: float = 0.05
		_band(axis, face, out_s, Vector2(a0 - w, a0), y0, y1 + w, d, "ashlar_marble_cream")
		_band(axis, face, out_s, Vector2(a1, a1 + w), y0, y1 + w, d, "ashlar_marble_cream")
		_band(axis, face, out_s, Vector2(a0, a1), y1, y1 + w, d, "ashlar_marble_cream")
		if y0 > 0.25:
			_band(axis, face, out_s, Vector2(a0 - w - 0.05, a1 + w + 0.05), y0 - 0.1, y0, d + 0.04, "ashlar_marble_cream")


## Landmark 2: the gilded halberd over the bronze doors: a 5 m staff, the axe blade and spike, two pennant ribbons.
func _halberd() -> void:
	var x: float = float(HALBERD[0])
	var y0: float = float(HALBERD[1])
	var y1: float = float(HALBERD[2])
	var z: float = float(HALBERD[3])
	var g: String = "gilt_brass"
	var grp: String = art.call(&"shell_group", Vector3(x, y1, z), Vector3.BACK)
	var skip_back: Callable = func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 4 else g
	art.acc.box(grp, Vector3(x - 0.06, y0, z), Vector3(x + 0.06, y1, z + 0.1), skip_back)
	art.acc.box(grp, Vector3(x - 0.04, y1, z), Vector3(x + 0.04, y1 + 0.6, z + 0.08), skip_back)
	# the axe blade (stepped crescent) to the east, the back spike to the west
	for i: int in range(5):
		var h: float = 1.2 - float(i) * 0.18
		var yc: float = y1 - 0.75
		art.acc.box(grp, Vector3(x + 0.06 + float(i) * 0.12, yc - h * 0.5, z), Vector3(x + 0.18 + float(i) * 0.12, yc + h * 0.5,
			z + 0.06), skip_back)
	art.acc.box(grp, Vector3(x - 0.5, y1 - 0.85, z), Vector3(x - 0.06, y1 - 0.65, z + 0.06), skip_back)
	art.acc.box(grp, Vector3(x - 0.3, y0 - 0.12, z), Vector3(x + 0.3, y0, z + 0.12), skip_back)


# --- Site ---------------------------------------------------------------------------------------

## The red carpet (fabric, +6 mm), the kerb line and lane markings on the Parade, and the Mews cobbles band.
func site_markings() -> void:
	var c: Array = CARPET
	art.acc.box("Site", Vector3(float(c[0]), 0.0, float(c[1])), Vector3(float(c[2]), 0.006, float(c[3])),
		func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 2 else "carpetwine_carpet_commercial")
	# the Parade's kerb: a granite strip at z 36 (the pavement south of the facade is the grade)
	art.acc.box("Site", Vector3(-40.0, 0.0, 35.9), Vector3(58.0, 0.012, 36.15), func(f: int, _n: Vector3, _c: Vector3) -> String:
		return "" if f == 2 else "granite_marble_cream")
	# dashed centre line of the Parade (z 43)
	var x: float = -38.0
	while x < 56.0:
		art.acc.box("Site", Vector3(x, 0.0, 42.94), Vector3(x + 3.0, 0.004, 43.06), func(f: int, _n: Vector3, _c: Vector3) -> String:
			return "" if f == 2 else "paint_white")
		x += 6.0


## Far grade and the skyline ring: lit / dark window bands on every block face (deterministic pattern).
func skyline() -> void:
	var g: Array = FAR_GRADE
	var y: float = float(g[4])
	var holes: Array[Rect2] = []
	for h: Array in FAR_HOLES:
		holes.append(Rect2(float(h[0]), float(h[1]), float(h[2]) - float(h[0]), float(h[3]) - float(h[1])))
	for r: Rect2 in art.call(&"rects_minus", Rect2(float(g[0]), float(g[1]), float(g[2]) - float(g[0]), float(g[3]) - float(g[1])), holes):
		art.acc.quad("Far", "asphalt", Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y),
			Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y), Vector3.UP)
	var blocks: Array = _skyline_blocks()
	for i: int in range(blocks.size()):
		var b: Array = blocks[i]
		var lo: Vector3 = Vector3(float(b[0]), 0.0, float(b[1]))
		var hi: Vector3 = Vector3(float(b[2]), float(b[4]), float(b[3]))
		var key: String = ["render_plaster_painted", "brick_red", "stucco_plaster_painted", "concrete"][i % 4]
		art.acc.box("Far", lo, hi, func(f: int, _n: Vector3, _c: Vector3) -> String: return "" if f == 2 else key)
		for n: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			_window_grid("Far", lo, hi, n, 3.4, 1.0, i)


## The skyline rows: north / south rows span the full width, west / east columns fill between them; 50 m blocks with a 1 m
## alley between (closed behind by the next row's corner blocks), heights cycling through SKYLINE_HEIGHTS.
static func _skyline_blocks() -> Array:
	var out: Array = []
	var k: int = 0
	for row: Array in [SKYLINE_N, SKYLINE_S]:
		var x: float = SKYLINE_W[1]
		while x < SKYLINE_E[0] - 0.1:
			var x1: float = minf(x + 50.0, SKYLINE_E[0])
			out.append([x, minf(float(row[0]), float(row[1])), x1, maxf(float(row[0]), float(row[1])),
				float(SKYLINE_HEIGHTS[k % SKYLINE_HEIGHTS.size()])])
			x = x1
			k += 1
	for col: Array in [SKYLINE_W, SKYLINE_E]:
		var z: float = SKYLINE_N[1]
		while z < SKYLINE_S[1] - 0.1:
			var z1: float = minf(z + 50.0, SKYLINE_S[1])
			out.append([float(col[0]), z, float(col[1]), z1, float(SKYLINE_HEIGHTS[k % SKYLINE_HEIGHTS.size()])])
			z = z1
			k += 1
	return out


## Window grids on the neighbours' play-facing faces.
func neighbour_windows() -> void:
	for nw: Array in NEIGHBOUR_WINDOWS:
		for c: Array in L.CLOSURES:
			if String(c[0]) != String(nw[0]):
				continue
			var b: Array = c[1]
			_window_grid("Neighbours", Vector3(float(b[0]), float(b[1]), float(b[2])), Vector3(float(b[3]), float(b[4]), float(b[5])),
				nw[1], float(nw[2]), float(nw[3]), String(c[0]).length())


## Windows 1.2 x 1.6 m every 3 m along a block face (normal n), one row per storey from `y_first`; ~1 in 3 lit.
func _window_grid(group: String, lo: Vector3, hi: Vector3, n: Vector3, storey: float, y_first: float, salt: int) -> void:
	var along_x: bool = absf(n.z) > 0.5
	var a0: float = lo.x if along_x else lo.z
	var a1: float = hi.x if along_x else hi.z
	var fixed: float = (hi.z if n.z > 0.0 else lo.z) if along_x else (hi.x if n.x > 0.0 else lo.x)
	var off: float = 0.03
	var y: float = lo.y + y_first
	var row: int = 0
	while y + 1.6 < hi.y - 0.8:
		var a: float = a0 + 1.5
		var col: int = 0
		while a + 1.2 < a1 - 1.0:
			var lit: bool = ((col * 7 + row * 13 + salt * 5) % 9) < 3
			var key: String = "window_lit" if lit else "window_dark"
			var p0: Vector3
			var p1: Vector3
			if along_x:
				p0 = Vector3(a, y, fixed + n.z * off)
				p1 = Vector3(a + 1.2, y + 1.6, fixed + n.z * off)
				art.acc.quad(group, key, Vector3(p0.x, p0.y, p0.z), Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p1.y, p0.z),
					Vector3(p0.x, p1.y, p0.z), n)
			else:
				p0 = Vector3(fixed + n.x * off, y, a)
				p1 = Vector3(fixed + n.x * off, y + 1.6, a + 1.2)
				art.acc.quad(group, key, Vector3(p0.x, p0.y, p0.z), Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p1.y, p1.z),
					Vector3(p0.x, p1.y, p0.z), n)
			a += 3.0
			col += 1
		y += storey
		row += 1


# --- Occluders ----------------------------------------------------------------------------------

## Box occluders: the building's floor slabs and the solid parts of the shell (per storey, inset from the facade), the
## Stair SS core, the neighbours and the skyline blocks. Glazing and arches are never covered (inset boxes stay
## inside solid wall runs only).
func occluders(parent: Node3D, owner_root: Node) -> int:
	var rows: Array = []
	for c: Array in L.CLOSURES:
		var b: Array = c[1]
		if float(b[4]) - float(b[1]) >= 5.0 and minf(float(b[3]) - float(b[0]), float(b[5]) - float(b[2])) >= 1.0:
			rows.append([String(c[0]), Vector3(float(b[0]), float(b[1]), float(b[2])), Vector3(float(b[3]), float(b[4]), float(b[5]))])
	var blocks: Array = _skyline_blocks()
	for i: int in range(blocks.size()):
		var s: Array = blocks[i]
		rows.append(["Skyline%02d" % i, Vector3(float(s[0]), 0.0, float(s[1])), Vector3(float(s[2]), float(s[4]), float(s[3]))])
	# solid wall runs >= 3 m long and >= 2.5 m high: a thin occluder inside the wall
	var k: int = 0
	for w: Array in art.call(&"wall_list"):
		var axis: String = String(w[1])
		var fixed: float = float(w[2])
		var t: float = float(w[8])
		for run: Vector2 in art.wall_runs(String(w[0]), axis, fixed, float(w[3]), float(w[4]), float(w[5]), float(w[6])):
			if run.y - run.x < 3.0 or float(w[6]) - float(w[5]) < 2.5:
				continue
			var lo: Vector3 = Vector3(run.x + 0.05, float(w[5]) + 0.05, fixed - t * 0.25) if axis == "x" \
				else Vector3(fixed - t * 0.25, float(w[5]) + 0.05, run.x + 0.05)
			var hi: Vector3 = Vector3(run.y - 0.05, float(w[6]) - 0.05, fixed + t * 0.25) if axis == "x" \
				else Vector3(fixed + t * 0.25, float(w[6]) - 0.05, run.y - 0.05)
			rows.append(["Wall%03d" % k, lo, hi])
			k += 1
	for r: Array in rows:
		var occ: OccluderInstance3D = OccluderInstance3D.new()
		occ.name = "Occluder" + String(r[0])
		var lo2: Vector3 = r[1]
		var hi2: Vector3 = r[2]
		occ.position = (lo2 + hi2) * 0.5
		var bo: BoxOccluder3D = BoxOccluder3D.new()
		bo.size = (hi2 - lo2).max(Vector3(0.02, 0.02, 0.02))
		occ.occluder = bo
		parent.add_child(occ)
		occ.owner = owner_root
	return rows.size()
