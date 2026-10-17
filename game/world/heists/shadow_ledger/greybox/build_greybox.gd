## Shadow Ledger G1 greybox generator. Owner: ENV C (C2).
## Regenerate (deterministic; never hand-edit the outputs):
##   /opt/godot/godot --headless --path game --script res://world/heists/shadow_ledger/greybox/build_greybox.gd
## Reads shadow_ledger_layout.gd and writes, under res://world/heists/shadow_ledger/:
##   shadow_ledger.tscn (HeistMap, navmesh baked and embedded), shadow_ledger_def.tres,
##   shadow_ledger_variants.tres. Contracts: docs/contracts/heist_map.md v1.2, gameplay_prefabs.md,
##   preplanning.md. Design: docs/design/heists/shadow_ledger.md (APPROVED, D-042).
## Interior walls are derived from the plan rectangles (shared edges once, core edges 0.3 m), the
## curtain wall from the facade edges (sill / head per room), the slabs from the floor plate minus
## the stair, void and riser holes. Gameplay prefabs are instanced (never edited) and located through
## their contract class names, so this file holds no path into another environment's folder.
extends "res://world/heists/shadow_ledger/greybox/sl_gameplay.gd"

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
## G2 art pass (SL-1): environment / fixtures / city / probes / occluders, and the KitPlacer dressing pass.
const DA: GDScript = preload("res://world/heists/shadow_ledger/greybox/sl_art.gd")
const DR: GDScript = preload("res://world/heists/shadow_ledger/greybox/sl_dress.gd")
## Storey tops for the curtain wall (next FFL).
const STOREY_TOP: Dictionary = {"L41": 8.0, "L42": 11.6}
const ROOM_LIGHT: Dictionary = {
	"exec": [Color(1.0, 0.82, 0.62), 0.6, 8.0], "office": [Color(1.0, 0.93, 0.85), 0.35, 7.0],
	"boh": [Color(0.95, 0.97, 1.0), 0.6, 6.0], "security": [Color(0.6, 0.75, 1.0), 0.3, 5.0],
	"server": [Color(0.85, 0.92, 1.0), 0.8, 6.0], "art": [Color(1.0, 0.8, 0.6), 0.5, 6.0],
}
const EXEC_ROOMS: Array[String] = ["K3", "M1", "M2", "M4", "K1", "K5", "M5", "M8", "M14"]
const BOH_ROOMS: Array[String] = ["K10", "K14", "J41", "J42", "M10", "M11", "M12", "M13", "S1", "S2", "S3", "R1", "R3",
	"WCW41", "WCM41", "WCW42", "WCM42", "M6"]

## The level's interior wall lines while _build_interior_walls runs (key "<axis>|<fixed>" -> [from, to, core]).
var _lv_lines: Dictionary = {}


func _initialize() -> void:
	_build.call_deferred()


## Output scene: SCENE_PATH, or `-- --out=<path>` (game/tests/c/test_generator_determinism.gd builds each
## map twice into scratch files and compares them byte for byte; def / variants still go to their paths).
static func _scene_out() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			return a.trim_prefix("--out=")
	return SCENE_PATH


func _build() -> void:
	var old_scene_uid: String = R.read_uid(SCENE_PATH)
	var def: HeistDef = R.make_def()
	var table: HeistVariantTable = R.make_variants()
	var err: int = ResourceSaver.save(def, DEF_PATH)
	err = maxi(err, ResourceSaver.save(table, VARIANTS_PATH))
	if err != OK:
		_fail("cannot save def/variants (%d)" % err)
		return
	map_root = HeistMap.new()
	map_root.name = "ShadowLedger"
	map_root.heist_def = load(DEF_PATH) as HeistDef
	map_root.variant_table = load(VARIANTS_PATH) as HeistVariantTable
	map_root.floor_heights = PackedFloat32Array(L.FLOOR_HEIGHTS)
	map_root.floor_names = PackedStringArray(L.FLOOR_NAMES)
	for nm: String in ["Geometry", "Props", "Lighting"]:
		add(map_root, node3d(nm))
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	nav.navigation_layers = 1
	add(map_root, nav)
	for nm2: String in ["Zones", "Rooms", "Spawns", "Patrols", "Tactical", "Gameplay", "Variants"]:
		add(map_root, node3d(nm2))
	var mission: Node = Node.new()
	mission.name = "Mission"
	mission.set_script(load(MISSION_PATH))
	add(map_root, mission)
	add(map_root, node3d("Preplan"))
	add(map_root, node3d("ReviewCameras"))

	_build_shell(n("Geometry"))
	_build_site(n("Geometry"))
	_build_skins(n("Geometry/Building"))
	_build_props(n("Props"))
	_build_lighting(n("Lighting"))
	_build_rooms(n("Rooms"))
	_build_zones(n("Zones"))
	_build_patrols(n("Patrols"))
	_build_spawns(n("Spawns"))
	_build_tactical(n("Tactical"))
	_build_preplan(n("Preplan"))
	_build_review_cameras(n("ReviewCameras"))
	_build_audio(add(map_root, node3d("Audio")) as Node3D)
	build_gameplay(n("Gameplay"))
	build_variants(n("Variants"))
	_build_nav_links(nav)
	_close_barred_doorways()
	_build_dressing()
	var polys: int = await _bake(nav)
	if polys <= 0:
		_fail("navmesh bake produced no polygons")
		return
	for untagged: String in SurfaceTags.tag_tree(map_root):  # PO-8 bullet surface ids
		errors.append("no surface id for %s" % untagged)
	_build_art()
	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	var ps: PackedScene = PackedScene.new()
	err = ps.pack(map_root)
	if err == OK:
		err = ResourceSaver.save(ps, _scene_out())
	map_root.free()
	if err != OK:
		_fail("cannot save %s (%d)" % [_scene_out(), err])
		return
	R.normalize_scene(_scene_out(), old_scene_uid)
	print("shadow_ledger: saved %s (navmesh polygons: %d)" % [_scene_out(), polys])
	quit(0)


## D-117 Audio node (as Golden Hour / Nightfall Depository): CuePlayer, the shadow_ledger MusicDirector and the
## ambience beds of the heist doc (Audio/lighting): tower interior (L40-L42) and the rain-swept roof / terrace.
func _build_audio(parent: Node3D) -> void:
	var beds: Array = [
		["BedL40Service", Vector3(27.0, 1.8, 12.0), &"cue.amb_shadow_ledger_interior", -6.0],
		["BedL41Executive", Vector3(18.0, 5.5, 4.0), &"cue.amb_shadow_ledger_interior", 0.0],
		["BedL41Server", Vector3(28.0, 5.5, 10.0), &"cue.amb_shadow_ledger_interior", -2.0],
		["BedL41Offices", Vector3(6.0, 5.5, 20.0), &"cue.amb_shadow_ledger_interior", -3.0],
		["BedL42Executive", Vector3(18.0, 9.8, 4.0), &"cue.amb_shadow_ledger_interior", -2.0],
		["BedL42West", Vector3(5.0, 9.8, 15.0), &"cue.amb_shadow_ledger_interior", -4.0],
		["BedTerraceRain", Vector3(18.0, 9.5, 21.0), &"cue.amb_rooftop_rain", -4.0],
		["BedRoofRain", Vector3(18.0, 13.0, 12.0), &"cue.amb_rooftop_rain", 0.0],
		["BedRoofEast", Vector3(30.0, 13.0, 4.0), &"cue.amb_rooftop_rain", -2.0],
	]
	load("res://world/audio/map_audio_builder.gd").call(&"build", parent, map_root, &"shadow_ledger", beds)


func _fail(msg: String) -> void:
	push_error("shadow_ledger: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


# --- Plan helpers -----------------------------------------------------------------------------

## Rooms of a level: [unique id, x0, z0, x1, z1, core]. L41/L42 get the shared core.
func _level_rooms(lv: String) -> Array:
	var out: Array = []
	var src: Array = (L.PLAN_ROOMS[lv] as Array).duplicate()
	if lv == "L41" or lv == "L42":
		src.append_array(L.CORE)
	for r: Array in src:
		var pid: String = String(r[0])
		var uid: String = pid
		if pid in ["J", "WCW", "WCM"]:
			uid = pid + lv.substr(1)
		out.append([uid, float(r[1]), float(r[2]), float(r[3]), float(r[4]), lv == "RF" or L.CORE_IDS.has(pid)])
	return out


func _on_line(spec: Array, axis: String, fixed: float, a0: float, a1: float) -> bool:
	return String(spec[0]) == axis and absf(float(spec[1]) - fixed) < 0.001 \
		and a0 >= float(spec[2]) - 0.001 and a1 <= float(spec[3]) + 0.001


func _on_facade(lv: String, axis: String, fixed: float, a0: float, a1: float) -> bool:
	for f: Array in L.FACADE_LINES.get(lv, []):
		if _on_line(f, axis, fixed, a0, a1):
			return true
	return false


## Door holes on a wall line: [[a0, a1, y0, y1], ...] (single 1.0 m, double 2.0 m; head 2.2).
func _door_holes(ffl: float, axis: String, fixed: float) -> Array:
	var out: Array = []
	for d: Array in L.DOORS:
		var p: Vector3 = d[2]
		if absf(p.y - ffl) > 0.01 or bool((d[7] as Dictionary).get("no_wall", false)):
			continue
		var yaw: float = fposmod(float(d[3]), 180.0)
		var d_axis: String = "x" if absf(yaw) < 1.0 else "z"
		var d_fixed: float = p.z if d_axis == "x" else p.x
		if d_axis != axis or absf(d_fixed - fixed) > 0.001:
			continue
		var c: float = p.x if d_axis == "x" else p.z
		var w: float = 2.0 if String(d[1]).contains("double") else 1.0
		# G2: curtain-wall doors 3 mm wider each side (the t04 frame's jambs were coplanar with the reveals: zfight)
		var pad: float = 0.003 if _on_facade(_level_of_ffl(ffl), d_axis, d_fixed, c - w * 0.5, c + w * 0.5) else 0.0
		out.append([c - w * 0.5 - pad, c + w * 0.5 + pad, ffl, ffl + L.DOOR_H])
	return out


static func _level_of_ffl(ffl: float) -> String:
	for lv: String in L.LEVELS:
		if absf(float(L.LEVELS[lv][0]) - ffl) < 0.01:
			return lv
	return ""


## Glass blocker + pane (+ head frame bar) for a glazed hole in a wall line.
func _glass(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, y0: float, y1: float) -> void:
	var mn: Vector3 = Vector3(a0, y0, fixed - 0.02) if axis == "x" else Vector3(fixed - 0.02, y0, a0)
	var mx: Vector3 = Vector3(a1, y1, fixed + 0.02) if axis == "x" else Vector3(fixed + 0.02, y1, a1)
	var body: Node3D = box(parent, nm, mn, mx, "glass")
	if body == null:
		return
	var span: float = a1 - a0
	# G2: the head bar stops 6 mm short of the reveals and rides 4 mm into the opening's head (zfight with the pane)
	var fs: Vector3 = Vector3(span - 0.012, 0.05, 0.06) if axis == "x" else Vector3(0.06, 0.05, span - 0.012)
	var head: MeshInstance3D = MeshInstance3D.new()
	head.name = "FrameHead"
	head.mesh = box_mesh(fs, "frame")
	head.position = Vector3(0.0, (y1 - y0) * 0.5 - 0.021, 0.0)
	add(body, head)


## Interval list minus cuts: [[a, b], ...] - [[c, d], ...].
static func _subtract(spans: Array, cuts: Array) -> Array:
	var cur: Array = spans.duplicate(true)
	for c: Array in cuts:
		var nxt: Array = []
		for s: Array in cur:
			var a: float = float(s[0])
			var b: float = float(s[1])
			var c0: float = float(c[0])
			var c1: float = float(c[1])
			if c1 <= a + 0.0001 or c0 >= b - 0.0001:
				nxt.append([a, b])
				continue
			if c0 > a + 0.0001:
				nxt.append([a, c0])
			if c1 < b - 0.0001:
				nxt.append([c1, b])
		cur = nxt
	return cur


## Rectangle [x0, z0, x1, z1] minus holes -> merged rectangles (deterministic).
static func _rects_minus(outer: Array, holes: Array) -> Array:
	var xs: Array[float] = [float(outer[0]), float(outer[2])]
	var zs: Array[float] = [float(outer[1]), float(outer[3])]
	for h: Array in holes:
		for v: float in [float(h[0]), float(h[2])]:
			if v > xs[0] and v < xs[1] and not xs.has(v):
				xs.append(v)
		for w: float in [float(h[1]), float(h[3])]:
			if w > zs[0] and w < zs[1] and not zs.has(w):
				zs.append(w)
	xs.sort()
	zs.sort()
	var rows: Array = []
	for j: int in range(zs.size() - 1):
		var runs: Array = []
		var start: float = NAN
		for i: int in range(xs.size() - 1):
			var cx: float = (xs[i] + xs[i + 1]) * 0.5
			var cz: float = (zs[j] + zs[j + 1]) * 0.5
			var inside: bool = false
			for h2: Array in holes:
				if cx > float(h2[0]) and cx < float(h2[2]) and cz > float(h2[1]) and cz < float(h2[3]):
					inside = true
					break
			if not inside and is_nan(start):
				start = xs[i]
			if inside and not is_nan(start):
				runs.append([start, xs[i]])
				start = NAN
		if not is_nan(start):
			runs.append([start, xs[xs.size() - 1]])
		rows.append([zs[j], zs[j + 1], runs])
	var out: Array = []
	var open: Dictionary = {}
	for row: Array in rows:
		var nxt: Dictionary = {}
		for run: Array in row[2]:
			var key: String = "%.4f|%.4f" % [float(run[0]), float(run[1])]
			nxt[key] = [float(run[0]), open[key][1] if open.has(key) else float(row[0]), float(run[1]), float(row[1])]
		for k: String in open:
			if not nxt.has(k):
				out.append(open[k])
		open = nxt
	for k2: String in open:
		out.append(open[k2])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	return out


# --- Building shell ---------------------------------------------------------------------------

func _build_shell(geo: Node3D) -> void:
	var bld: Node3D = add(geo, node3d("Building")) as Node3D
	wall_tile = SLAB_TILE  # building walls draw as <= 6 m seamless mesh tiles (one collider each)
	_build_interior_walls(add(bld, node3d("InteriorWalls")) as Node3D)
	_build_facade(add(bld, node3d("Facade")) as Node3D)
	wall_tile = 0.0
	_build_slabs(add(bld, node3d("Slabs")) as Node3D)
	_build_ceilings(add(bld, node3d("Ceilings")) as Node3D)
	var stairs: Node3D = add(bld, node3d("Stairs")) as Node3D
	for cid: String in L.STAIR_CORES:
		_build_core(stairs, cid, L.STAIR_CORES[cid])
	_build_feature_stair(stairs)
	wall_tile = SLAB_TILE
	_build_riser(add(bld, node3d("Riser")) as Node3D)
	wall_tile = 0.0
	var fills: Node3D = add(bld, node3d("ShaftFills")) as Node3D
	# G2: 3 mm inside the slab faces they meet (zfight); the shafts are sealed (no navmesh)
	box(fills, "LiftShaft1", Vector3(15.15, L.TOP40 + 0.003, 7.65), Vector3(17.85, L.FRF - 0.003, 9.85), "trim")
	box(fills, "LiftShaft2", Vector3(18.15, L.TOP40 + 0.003, 7.65), Vector3(20.85, L.FRF - 0.003, 9.85), "trim")
	box(fills, "ServiceLiftShaft", Vector3(21.15, 2.6, 7.65), Vector3(23.85, L.FRF - 0.003, 10.35), "trim")
	var rails: Node3D = add(bld, node3d("Railings")) as Node3D
	for r: Array in L.BALUSTRADES:
		railing(rails, String(r[0]), v3(r[1], 0), v3(r[1], 3), true)
	_build_parapets(add(bld, node3d("Parapets")) as Node3D)
	_build_cage(bld)
	var panels: Node3D = add(bld, node3d("DoorPanels")) as Node3D
	for p: Array in L.DOOR_PANELS:
		var b: Array = p[1]
		mesh_box(panels, String(p[0]), v3(b, 0), v3(b, 3), "door")
	var br: Node3D = add(bld, node3d("CameraBrackets")) as Node3D
	for cid2: String in L.CAMERAS:
		var row: Array = L.CAMERAS[cid2]
		if row[2] != null:
			box_a(br, "Bracket" + cid2, row[2], "trim")
	var logo: MeshInstance3D = mesh_box(bld, "LogoWall", v3(L.LOGO_WALL, 0), v3(L.LOGO_WALL, 3), "logo_teal")
	logo.set_meta(&"landmark", "km_logo_wall")


## Interior walls per level from the room edges (shared edges once; core edges 0.3 m).
func _build_interior_walls(parent: Node3D) -> void:
	for lv: String in ["L40", "L41", "L42", "RF"]:
		var info: Array = L.LEVELS[lv]
		var ffl: float = float(info[0])
		var top: float = float(info[1])
		var lines: Dictionary = {}
		for r: Array in _level_rooms(lv):
			var x0: float = r[1]
			var z0: float = r[2]
			var x1: float = r[3]
			var z1: float = r[4]
			for e: Array in [["x", z0, x0, x1], ["x", z1, x0, x1], ["z", x0, z0, z1], ["z", x1, z0, z1]]:
				if _on_facade(lv, String(e[0]), float(e[1]), float(e[2]), float(e[3])):
					continue
				var key: String = "%s|%08.3f" % [e[0], float(e[1])]
				if not lines.has(key):
					lines[key] = []
				(lines[key] as Array).append([float(e[2]), float(e[3]), bool(r[5])])
		var keys: Array = lines.keys()
		keys.sort()
		_lv_lines = lines
		var lvl: Node3D = add(parent, node3d(lv)) as Node3D
		for key2: String in keys:
			var axis: String = key2.get_slice("|", 0)
			var fixed: float = float(key2.get_slice("|", 1))
			_wall_line(lvl, lv, ffl, top, axis, fixed, lines[key2])


## SL-P1: a WALL_OPEN cut ending on a perpendicular wall's centre line that stops there (an L / T corner of two
## corridors) left a half-thickness notch in the corner (K7 / K10 at (25.4, L41, 7.4): the navmesh path hugged it
## and the capsule caught on both pieces). The wall run beside the cut then reaches that wall's face: the cut
## shrinks by its half thickness. 0 when the perpendicular wall runs through the junction (no notch).
func _end_cap(axis: String, fixed: float, pos: float, _dir: float) -> float:
	var other: String = "z" if axis == "x" else "x"
	var key: String = "%s|%08.3f" % [other, pos]
	if not _lv_lines.has(key):
		return 0.0
	var below: bool = false
	var above: bool = false
	var t: float = 0.0
	for s: Array in _lv_lines[key]:
		var a: float = float(s[0])
		var b: float = float(s[1])
		if a < fixed - 0.001 and b > fixed - 0.05:
			below = true
		if b > fixed + 0.001 and a < fixed + 0.05:
			above = true
		if a <= fixed + 0.001 and b >= fixed - 0.001:
			t = maxf(t, L.CORE_T if bool(s[2]) else L.INT_T)
	# G2 (SL-1): 3 mm past the face, so the run's end cap is not coplanar with that wall's face (zfight)
	return t * 0.5 + 0.003 if below != above else 0.0


func _wall_line(parent: Node3D, lv: String, ffl: float, top: float, axis: String, fixed: float, segs: Array) -> void:
	var pts: Array[float] = []
	for s: Array in segs:
		for v: float in [float(s[0]), float(s[1])]:
			if not pts.has(v):
				pts.append(v)
	pts.sort()
	var cuts: Array = []
	for o: Array in L.WALL_OPEN:
		if String(o[0]) == lv and String(o[1]) == axis and absf(float(o[2]) - fixed) < 0.001:
			cuts.append([float(o[3]) + _end_cap(axis, fixed, float(o[3]), 1.0), float(o[4]) - _end_cap(axis, fixed, float(o[4]), -1.0)])
	# Elementary intervals -> thickness, merged into runs of equal thickness.
	var runs: Array = []
	for i: int in range(pts.size() - 1):
		var p: float = pts[i]
		var q: float = pts[i + 1]
		var t: float = 0.0
		for s2: Array in segs:
			if float(s2[0]) <= p + 0.0001 and float(s2[1]) >= q - 0.0001:
				t = maxf(t, L.CORE_T if bool(s2[2]) else L.INT_T)
		if t <= 0.0:
			continue
		for piece: Array in _subtract([[p, q]], cuts):
			if not runs.is_empty() and absf(float(runs[-1][1]) - float(piece[0])) < 0.0001 and absf(float(runs[-1][2]) - t) < 0.001:
				runs[-1][1] = float(piece[1])
			else:
				runs.append([float(piece[0]), float(piece[1]), t])
	var holes: Array = _door_holes(ffl, axis, fixed)
	var glass: Array = []
	for g: Array in L.WALL_GLASS:
		if String(g[0]) == lv and String(g[1]) == axis and absf(float(g[2]) - fixed) < 0.001:
			holes.append([float(g[3]), float(g[4]), ffl + float(g[5]), ffl + float(g[6])])
			glass.append(g)
	if lv == "L40" and axis == String(L.LIFT_CAR_OPENING[0]) and absf(fixed - float(L.LIFT_CAR_OPENING[1])) < 0.001:
		holes.append([float(L.LIFT_CAR_OPENING[2]), float(L.LIFT_CAR_OPENING[3]), ffl, ffl + float(L.LIFT_CAR_OPENING[4])])
	var mat: String = "wall_ext" if lv == "RF" else "wall"
	for k: int in range(runs.size()):
		var run: Array = runs[k]
		var nm: String = "%s%04d_%d" % [axis.to_upper(), int(round(fixed * 100.0)), k]
		wall(parent, nm, axis, fixed, float(run[0]), float(run[1]), float(run[2]), Vector2(ffl, top), holes, mat)
	for j: int in range(glass.size()):
		var g2: Array = glass[j]
		_glass(parent, "Glass%s%04d_%d" % [axis.to_upper(), int(round(fixed * 100.0)), j], axis, fixed,
			float(g2[3]), float(g2[4]), ffl + float(g2[5]), ffl + float(g2[6]))


## Curtain wall (L41, L42): per room span, a solid spandrel below the sill, laminated glass to the
## room's ceiling and a solid band up to the next floor; door holes (facade access doors, terrace
## sliders) and solid bays. The L40 facade below the play floors is solid.
func _build_facade(parent: Node3D) -> void:
	for lv: String in ["L41", "L42"]:
		var ffl: float = float(L.LEVELS[lv][0])
		var top: float = float(STOREY_TOP[lv])
		var rooms: Array = _level_rooms(lv)
		var lvl: Node3D = add(parent, node3d(lv)) as Node3D
		for f: Array in L.FACADE_LINES[lv]:
			var axis: String = String(f[0])
			var fixed: float = float(f[1])
			var spans: Array = []
			for r: Array in rooms:
				var edges: Array = [["x", r[2], r[1], r[3]], ["x", r[4], r[1], r[3]], ["z", r[1], r[2], r[4]], ["z", r[3], r[2], r[4]]]
				for e: Array in edges:
					if _on_line(f, String(e[0]), float(e[1]), float(e[2]), float(e[3])):
						var meta: Array = L.ROOM_META[String(r[0])]
						spans.append([float(e[2]), float(e[3]), float(meta[3]), float(meta[2])])
			spans.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			var doors: Array = _door_holes(ffl, axis, fixed)
			var solid: Array = []
			for sb: Array in L.SOLID_BAYS:
				if String(sb[0]) == lv and String(sb[1]) == axis and absf(float(sb[2]) - fixed) < 0.001:
					solid.append([float(sb[3]), float(sb[4])])
			var holes: Array = doors.duplicate(true)
			var panes: Array = []
			for s: Array in spans:
				var head: float = ffl + float(s[3]) - 0.008  # G2: 8 mm under the slab / ceiling line and its skin (zfight)
				var cut: Array = solid.duplicate(true)
				for d: Array in doors:
					cut.append([float(d[0]), float(d[1])])
					if float(d[0]) >= float(s[0]) - 0.001 and float(d[1]) <= float(s[1]) + 0.001 and head > ffl + L.DOOR_H:
						holes.append([float(d[0]), float(d[1]), ffl + L.DOOR_H, head])
						panes.append([float(d[0]), float(d[1]), ffl + L.DOOR_H, head])
				for g: Array in _subtract([[float(s[0]) + 0.05, float(s[1]) - 0.05]], cut):
					holes.append([float(g[0]), float(g[1]), ffl + float(s[2]), head])
					panes.append([float(g[0]), float(g[1]), ffl + float(s[2]), head])
			var a0: float = float(f[2]) - (L.EXT_T * 0.5 if axis == "x" else -L.EXT_T * 0.5)
			var a1: float = float(f[3]) + (L.EXT_T * 0.5 if axis == "x" else -L.EXT_T * 0.5)
			for pn0: Array in panes:
				pn0[0] = maxf(float(pn0[0]), a0)
				pn0[1] = minf(float(pn0[1]), a1)
			var nm: String = "Facade%s%04d" % [axis.to_upper(), int(round(fixed * 100.0))]
			wall(lvl, nm, axis, fixed, a0, a1, L.EXT_T, Vector2(ffl, top), holes, "wall_ext")
			for i: int in range(panes.size()):
				var pn: Array = panes[i]
				_glass(lvl, "%sPane%02d" % [nm, i], axis, fixed, float(pn[0]), float(pn[1]), float(pn[2]), float(pn[3]))
	# L40 (service level; the rest of the floor is sealed): solid facade from below the slab.
	var l40: Node3D = add(parent, node3d("L40")) as Node3D
	# G2: no top cap (it stands under the L41 slab and the L41 curtain wall: zfight)
	box(l40, "FacadeL40N", Vector3(-0.2, -0.6, -0.2), Vector3(36.2, L.F41, 0.2), "wall_ext", true, SLAB_TILE, true, 2)
	box(l40, "FacadeL40S", Vector3(-0.2, -0.6, 23.8), Vector3(36.2, L.F41, 24.2), "wall_ext", true, SLAB_TILE, true, 2)
	box(l40, "FacadeL40W", Vector3(-0.2, -0.6, 0.2), Vector3(0.2, L.F41, 23.8), "wall_ext", true, SLAB_TILE, true, 2)
	box(l40, "FacadeL40E", Vector3(35.8, -0.6, 0.2), Vector3(36.2, L.F41, 23.8), "wall_ext", true, SLAB_TILE, true, 2)


func _build_slabs(parent: Node3D) -> void:
	var core_holes: Array = []
	for cid: String in L.STAIR_CORES:
		var x0: float = float(L.STAIR_CORES[cid]["x0"])
		core_holes.append([x0 + L.STAIR_CLEAR.x, L.STAIR_Z_N, x0 + L.STAIR_CLEAR.y, L.STAIR_Z_START])
	var sa: Array = [core_holes[0]]
	# L40: only under the in-play rooms, the service lift car and the stair floor landings.
	var l40: Array = [[23.85, 7.35, 30.1, 16.6], [21.15, 7.65, 23.85, 10.35]]
	for cid2: String in L.STAIR_CORES:
		var x02: float = float(L.STAIR_CORES[cid2]["x0"])
		l40.append([x02 + L.STAIR_CLEAR.x, L.STAIR_Z_START, x02 + L.STAIR_CLEAR.y, L.STAIR_Z_S])
	for i: int in range(l40.size()):
		var r: Array = l40[i]
		# G2: sides inside the walls left out (zfight); the stair landings keep their edge over the flight below
		box(parent, "SlabL40_%d" % i, Vector3(float(r[0]), -0.3, float(r[1])), Vector3(float(r[2]), L.F40, float(r[3])), "floor", true,
			SLAB_TILE, false, 4 | 8 | 32 if i >= 2 else 4 | 8 | 16 | 32)
	# The sealed vacant rest of L40 (D-115): its slab inside the solid L40 facade, round the in-play rooms,
	# the service lift and the two stair cores (walls included). Bare concrete; never reached, so a navmesh
	# obstruction keeps it from baking an island. The pre-planning blueprint draws L40 as the floor plate.
	var vacant_holes: Array = [[23.85, 7.35, 30.1, 16.6], [20.85, 7.35, 23.85, 10.65]]
	for cid3: String in L.STAIR_CORES:
		var x03: float = float(L.STAIR_CORES[cid3]["x0"])
		vacant_holes.append([x03 - 0.15, 10.35, x03 + 3.15, 16.65])
	var vacant: Array = _rects_minus([0.2, 0.2, 35.8, 23.8], vacant_holes)
	for j: int in range(vacant.size()):
		var v: Array = vacant[j]
		box(parent, "SlabL40Vacant_%02d" % j, Vector3(float(v[0]), -0.3, float(v[1])), Vector3(float(v[2]), L.F40, float(v[3])),
			"floor", true, SLAB_TILE, false, 4 | 8 | 16 | 32)
		obstruct(Transform3D.IDENTITY, AABB(Vector3(float(v[0]), -0.5, float(v[1])),
			Vector3(float(v[2]) - float(v[0]), 2.5, float(v[3]) - float(v[1]))))
	# G2: 4 mm inside the curtain wall's outer face (the slab ends were coplanar with the facade skin: zfight); the
	# strip stands under the facade wall, so the walkable floor and the bake are unchanged.
	var plate: Array = [-0.196, -0.196, 36.196, 24.196]
	_slab(parent, "SlabL41", plate, core_holes, L.TOP40, L.F41, "floor")
	var void_hole: Array = [12.1, 0.2, 20.5, 4.0]
	var riser: Array = L.RISER["inner"]
	_slab(parent, "SlabL42", plate, core_holes + [void_hole, riser], L.TOP41, L.F42, "floor")
	_slab(parent, "SlabRoof", [-0.196, -0.196, 36.196, 18.196], sa + [L.RISER["hatch"]], L.TOP42, L.FRF, "roof")
	box(parent, "PlantBlockRoof", Vector3(11.85, L.TOPRF, 7.35), Vector3(24.15, L.PLANT_ROOF, 16.65), "roof", true, SLAB_TILE)
	# Riser grating at L42 (open over the lower ladder).
	_slab(parent, "RiserGrating", riser, [L.RISER["lower_hole"]], L.F42 - 0.05, L.F42, "fence")


## G2: a slab rect draws only the side faces on a hole's edge (the void, the stair wells, the riser): the others meet
## the next rect or stand inside the walls, where they were coplanar with the wall faces (zfight). A rect wholly inside
## the curtain wall's band (the strip north of the void) draws nothing. Visual only: the colliders are unchanged.
func _slab(parent: Node3D, nm: String, outer: Array, holes: Array, y0: float, y1: float, mat: String) -> void:
	var rects: Array = _rects_minus(outer, holes)
	var plate: bool = float(outer[2]) - float(outer[0]) > 10.0  # a floor plate (its edge band is the curtain wall)
	var hidden: Array[Node3D] = []
	var shown: Node3D = null
	for i: int in range(rects.size()):
		var r: Array = rects[i]
		var x0: float = float(r[0])
		var z0: float = float(r[1])
		var x1: float = float(r[2])
		var z1: float = float(r[3])
		var in_band: bool = plate and ((z1 - z0 <= L.EXT_T + 0.01 and (absf(z0 - float(outer[1])) < 0.001
			or absf(z1 - float(outer[3])) < 0.001)) or (x1 - x0 <= L.EXT_T + 0.01 and (absf(x0 - float(outer[0])) < 0.001
			or absf(x1 - float(outer[2])) < 0.001)))
		var caps: int = 0
		for side: Array in [[4, "x", x0, z0, z1], [8, "x", x1, z0, z1], [16, "z", z0, x0, x1], [32, "z", z1, x0, x1]]:
			if not _on_hole_edge(holes, String(side[1]), float(side[2]), float(side[3]), float(side[4])):
				caps |= int(side[0])
		var body: Node3D = box(parent, "%s_%02d" % [nm, i], Vector3(x0, y0, z0), Vector3(x1, y1, z1), "" if in_band else mat, true,
			SLAB_TILE, true, caps | 64)  # seamless tiles: no tile faces inside the slab (zfight with the walls' ends)
		if in_band:
			hidden.append(body)
		elif shown == null:
			shown = body
	for hb: Node3D in hidden:  # PO-8: the collider-only strips take the slab's bullet surface
		if shown != null:
			SurfaceTags.tag(hb as CollisionObject3D, SurfaceTags.from_meshes(shown as CollisionObject3D))


## True when the rect side (axis "x": the side at x = `at` spanning z a0..a1; "z": at z = `at` spanning x) runs along a
## hole's edge for some length.
static func _on_hole_edge(holes: Array, axis: String, at: float, a0: float, a1: float) -> bool:
	for h: Array in holes:
		var e0: float = float(h[0]) if axis == "x" else float(h[1])
		var e1: float = float(h[2]) if axis == "x" else float(h[3])
		var s0: float = float(h[1]) if axis == "x" else float(h[0])
		var s1: float = float(h[3]) if axis == "x" else float(h[2])
		if (absf(at - e0) < 0.001 or absf(at - e1) < 0.001) and minf(a1, s1) - maxf(a0, s0) > 0.01:
			return true
	return false


## Ceilings (0.05 m, underside at the room's ceiling) where the room is lower than the slab above.
func _build_ceilings(parent: Node3D) -> void:
	for lv: String in ["L40", "L41", "L42"]:
		var ffl: float = float(L.LEVELS[lv][0])
		var top: float = float(L.LEVELS[lv][1])
		for r: Array in _level_rooms(lv):
			var uid: String = String(r[0])
			var meta: Array = L.ROOM_META.get(uid, [])
			if meta.is_empty() or float(meta[2]) <= 0.0 or uid == "SL":
				continue
			var cy: float = ffl + float(meta[2])
			if cy >= top - 0.01:
				continue
			var rects: Array = L.ROOM_RECTS.get(uid, [[r[1], r[2], r[3], r[4]]])
			for i: int in range(rects.size()):
				var q: Array = rects[i]
				_edgeless(box(parent, "Ceil%s_%d" % [uid, i], Vector3(float(q[0]), cy, float(q[1])), Vector3(float(q[2]), cy + 0.05,
					float(q[3])), "ceiling"))


## G2 (SL-1, as DB-C2): a ceiling box draws only its underside and top (its 5 cm edges stand inside the walls, where
## they were coplanar with the wall pieces' ends: zfight). Visual only; the collider is unchanged.
func _edgeless(body: Node3D) -> void:
	if body == null:
		return
	for c: Node in body.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null:
			continue
		var bm: Mesh = mi.mesh
		var key: String = "flat|%s|%s" % [str(bm.get_aabb()), bm.surface_get_material(0).resource_name]
		if not _box_mesh_cache.has(key):
			var h: Vector3 = bm.get_aabb().size * 0.5
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for f: Array in [[Vector3.DOWN, Vector3.BACK, Vector3.RIGHT], [Vector3.UP, Vector3.RIGHT, Vector3.BACK]]:
				var n: Vector3 = f[0]
				var u: Vector3 = f[1] * absf((f[1] as Vector3).dot(h))
				var v: Vector3 = f[2] * absf((f[2] as Vector3).dot(h))
				var q: Array = [n * h - u - v, n * h + u - v, n * h + u + v, n * h - u + v]
				for k: int in [0, 1, 2, 0, 2, 3]:
					st.set_normal(n)
					st.set_uv(Vector2((q[k] as Vector3).x, (q[k] as Vector3).z))
					st.add_vertex(q[k])
			st.generate_tangents()
			st.set_material(bm.surface_get_material(0))
			_box_mesh_cache[key] = st.commit()
		mi.mesh = _box_mesh_cache[key]
		mi.position.y += 0.003  # G2: 3 mm over the glazing heads / wall pieces at the ceiling line (zfight)


## PO-13 slab skins (sl_builder_base.slab_skins): per-room floor (sl_finishes ROOM_FLOOR) and ceiling
## (ROOM_FINISH) finishes over the slab / ceiling boxes that carry another finish. Rooms without a ceiling
## (stairs, shafts) and the service lift car get none.
func _build_skins(bld: Node3D) -> void:
	var rooms: Array = []
	for lv: String in ["L40", "L41", "L42", "RF"]:
		var ffl: float = float(L.LEVELS[lv][0])
		for r: Array in _level_rooms(lv):
			var uid: String = String(r[0])
			var meta: Array = L.ROOM_META.get(uid, [])
			if meta.is_empty() or float(meta[2]) <= 0.0 or uid == "SL":
				continue
			var ceil_key: String = String((F.ROOM_FINISH[uid] as Array)[1]) if F.ROOM_FINISH.has(uid) else ""
			for q: Array in L.ROOM_RECTS.get(uid, [[r[1], r[2], r[3], r[4]]]):
				rooms.append([uid, float(q[0]), float(q[1]), float(q[2]), float(q[3]), ffl,
					ffl + float(meta[2]), String(F.ROOM_FLOOR.get(uid, "")), ceil_key])
	var skins: Node3D = add(bld, node3d("Skins")) as Node3D
	slab_skins(skins, [bld.get_node("Slabs"), bld.get_node("Ceilings")], rooms, "sl_")


## Railing: full-panel collision (blocks players and the navmesh) + top rail, posts; optional glass.
func railing(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, glass: bool = false) -> void:
	var body: Node3D = box(parent, nm, mn, mx, "")
	body.set_meta(&"kind", "railing")
	RT.apply(body)  # ridged collider top: nobody stands on a rail (D-104 slopes)
	var size: Vector3 = mx - mn
	var along_x: bool = size.x >= size.z
	var length: float = size.x if along_x else size.z
	var t: float = minf(size.x, size.z)
	var top: MeshInstance3D = MeshInstance3D.new()
	top.name = "TopRail"
	top.mesh = box_mesh(Vector3(length, 0.05, t + 0.02) if along_x else Vector3(t + 0.02, 0.05, length), "trim")
	top.position = Vector3(0.0, size.y * 0.5 - 0.025, 0.0)
	add(body, top)
	if glass:
		# G2: the pane stops 3 cm inside its end posts and 3 mm inside the rail's faces (zfight with the posts and with
		# the next railing's end)
		var ia: Vector3 = Vector3(0.03, 0.0, 0.003) if along_x else Vector3(0.003, 0.0, 0.03)
		mesh_box(body, "Pane", Vector3(-size.x * 0.5, -size.y * 0.5 + 0.05, -size.z * 0.5) + ia,
			Vector3(size.x * 0.5, size.y * 0.5 - 0.053, size.z * 0.5) - ia, "teal_glass")
	var posts: int = mini(maxi(2, int(ceil(length / 1.5)) + 1), 40)
	for i: int in range(posts):
		var off: float = -length * 0.5 + 0.025 + (length - 0.05) * float(i) / float(posts - 1)
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "Post%d" % i
		# G2: posts across the rail on both orientations (along z they were 2 mm off the pane: zfight)
		post.mesh = box_mesh(Vector3(0.05, size.y, t + 0.02) if along_x else Vector3(t + 0.02, size.y, 0.05), "trim")
		post.position = Vector3(off, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, off)
		add(body, post)


# --- Stairs -----------------------------------------------------------------------------------

## One straight flight along its local +Z from `origin` (first riser line, lower floor level):
## n risers of `r`, (n - 1) treads of `t`, width `w`. Steps are visual meshes (soffit 0.15 m below,
## or solid down to `solid_y`); the collision is a smooth ramp through the nosings, extended one
## tread back over the lower floor (validator convention (b)).
func _flight(parent: Node3D, nm: String, origin: Vector3, yaw: float, w: float, nr: int, r: float, t: float,
		solid_y: Variant, is_stairs: bool) -> Node3D:
	var f: Node3D = node3d(nm, origin)
	f.basis = yaw_basis(yaw)
	if is_stairs:
		f.set_meta(&"kind", "stairs")
	add(parent, f)
	for k: int in range(1, nr):
		var top: float = float(k) * r
		var lo: float = (float(solid_y) - origin.y) if solid_y != null else top - r - 0.15
		mesh_box(f, "Step%02d" % k, Vector3(-w * 0.5, lo, float(k - 1) * t), Vector3(w * 0.5, top, float(k) * t + SEAM), "stair")
	var ramp_t: float = 0.3
	var end_z: float = float(nr - 1) * t
	_ramp(f, -w * 0.5, w * 0.5, [[Vector2(-t, 0.0), Vector2(end_z, float(nr) * r), Vector2(end_z, float(nr) * r - ramp_t),
		Vector2(-t, -ramp_t)]])
	return f


## Ramp collision: one StaticBody3D with convex prisms, each a (z, y) polygon extruded over x0..x1.
func _ramp(flight: Node3D, x0: float, x1: float, polys: Array) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = 1
	body.collision_mask = 0
	add(flight, body)
	for i: int in range(polys.size()):
		var pts: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in polys[i]:
			pts.append(Vector3(x0, p.y, p.x))
			pts.append(Vector3(x1, p.y, p.x))
		var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shp.points = pts
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Prism%d" % i
		col.shape = shp
		add(body, col)


## U-stair core: per storey a west up-flight (north from z 15.03), the half landing, an east return
## flight (south to the floor landing) and the well divider; a railing over the void at the top
## floor; below L40 one flight + the half landing behind the steel-mesh gate (P1/P2 police spawns).
func _build_core(parent: Node3D, cid: String, core: Dictionary) -> void:
	var c: Node3D = add(parent, node3d("Stair" + cid.substr(1))) as Node3D
	var x0: float = float(core["x0"])
	var levels: Array = core["levels"]
	var xw: float = x0 + (L.STAIR_WEST.x + L.STAIR_WEST.y) * 0.5
	var xe: float = x0 + (L.STAIR_EAST.x + L.STAIR_EAST.y) * 0.5
	var w: float = L.STAIR_WEST.y - L.STAIR_WEST.x
	var t: float = L.STAIR_TREAD
	var prev_zh: float = -INF
	var prev_yh: float = 0.0
	for i: int in range(-1, levels.size() - 1):
		var y0: float = float(levels[i]) if i >= 0 else L.F40 - 3.6
		var y1: float = float(levels[i + 1]) if i >= 0 else L.F40
		var h: float = y1 - y0
		var m: int = int(round(h / 0.36))
		var r: float = h / float(2 * m)
		var zh: float = L.STAIR_Z_START - float(m - 1) * t
		var yh: float = y0 + h * 0.5
		var tag: String = "%d" % (i + 1) if i >= 0 else "Below"
		if i >= 0:
			_flight(c, "Flight%sW" % tag, Vector3(xw, y0, L.STAIR_Z_START), 180.0, w, m, r, t, null, true)
		_flight(c, "Flight%sE" % tag, Vector3(xe, yh, zh), 0.0, w, m, r, t, null, i >= 0)
		if i >= 0:
			var off: float = L.HANDRAIL_OFF
			_flight_rails(c, "Flight%sW" % tag, [x0 + L.STAIR_CLEAR.x + off, x0 + L.STAIR_WELL.x - off],
				L.STAIR_Z_START, y0, zh, y0 + float(m) * r)
			_flight_rails(c, "Flight%sE" % tag, [x0 + L.STAIR_WELL.y + off, x0 + L.STAIR_CLEAR.y - off],
				zh, yh, L.STAIR_Z_START, yh + float(m) * r)
		box(c, "HalfLanding%s" % tag, Vector3(x0 + L.STAIR_CLEAR.x, yh - 0.3, L.STAIR_Z_N), Vector3(x0 + L.STAIR_CLEAR.y, yh, zh), "stair")
		var top_storey: bool = i == levels.size() - 2
		var ytop_d: float = y1 + (1.1 if top_storey else 0.0)
		# SL-P1: a taller storey's divider starts further north than the one below, over the lower half landing
		# (L41 -> L42, 4.4 m, over the L40 -> L41 landing at +1.8). That overhang keeps STAIR_HEADROOM over the landing.
		var zd: float = zh
		if prev_zh > zh:
			zd = prev_zh
			box(c, "Divider%sHead" % tag, Vector3(x0 + L.STAIR_WELL.x, prev_yh + L.STAIR_HEADROOM, zh),
				Vector3(x0 + L.STAIR_WELL.y, ytop_d, zd), "wall")
		box(c, "Divider%s" % tag, Vector3(x0 + L.STAIR_WELL.x, y0, zd), Vector3(x0 + L.STAIR_WELL.y, ytop_d, L.STAIR_Z_START), "wall")
		prev_zh = zh
		prev_yh = yh
	var ytop: float = float(levels[levels.size() - 1])
	railing(c, "TopRail", Vector3(x0 + L.STAIR_CLEAR.x, ytop, L.STAIR_Z_START - 0.06), Vector3(x0 + L.STAIR_WELL.x, ytop + 1.1,
		L.STAIR_Z_START))
	# Below L40: dark shaft, landing floor, the closure over the missing flight, core walls.
	var yb: float = L.F40 - 3.6
	box(c, "BelowFloor", Vector3(x0 + L.STAIR_CLEAR.x, yb - 0.3, L.STAIR_Z_N), Vector3(x0 + L.STAIR_CLEAR.y, yb, L.STAIR_Z_S), "stair")
	# The closure is a guard at the half-landing edge (1.1 m): ridged collider top, not a perch (D-104 slopes).
	RT.apply(box(c, "BelowClosure", Vector3(x0 + L.STAIR_CLEAR.x, yb, 12.51), Vector3(x0 + L.STAIR_WELL.x, L.F40 - 0.7, 12.61), "wall"))
	# G2: no top cap (under the L40 slab / landing: zfight)
	box(c, "BelowWallW", Vector3(x0 - 0.15, yb, 10.5), Vector3(x0 + 0.15, L.F40, 16.5), "wall", true, 0.0, false, 2)
	box(c, "BelowWallE", Vector3(x0 + 2.85, yb, 10.5), Vector3(x0 + 3.15, L.F40, 16.5), "wall", true, 0.0, false, 2)
	box(c, "BelowWallN", Vector3(x0 + 0.15, yb, 10.35), Vector3(x0 + 2.85, L.F40, 10.65), "wall", true, 0.0, false, 2)
	box(c, "BelowWallS", Vector3(x0 + 0.15, yb, 16.35), Vector3(x0 + 2.85, L.F40, 16.65), "wall", true, 0.0, false, 2)
	# Steel-mesh security gate on the L40 landing (the gate leaf is Gameplay/Doors/Stair?Gate).
	var gx: float = x0 + 2.15
	box(c, "GateMeshW", Vector3(x0 + L.STAIR_WELL.x, L.F40, 15.07), Vector3(gx - 0.5, L.TOP40, 15.13), "cage_mesh")
	box(c, "GateMeshE", Vector3(gx + 0.5, L.F40, 15.07), Vector3(x0 + L.STAIR_CLEAR.y, L.TOP40, 15.13), "cage_mesh")
	box(c, "GateMeshTop", Vector3(gx - 0.5, L.F40 + L.DOOR_H, 15.07), Vector3(gx + 0.5, L.TOP40, 15.13), "cage_mesh")


## Feature stair (landmark 2) L41 -> L42 in the reception void: two straight flights east with a
## landing, solid base, glass balustrades; it arrives at the gallery landing (x 20.5).
func _build_feature_stair(parent: Node3D) -> void:
	var fs: Dictionary = L.FEATURE_STAIR
	var fst: Node3D = add(parent, node3d("FeatureStair")) as Node3D
	var nr: int = int(fs["risers"])
	var y0: float = float(fs["y0"])
	var y1: float = float(fs["y1"])
	var r: float = (y1 - y0) / float(2 * nr)
	var t: float = L.STAIR_TREAD
	var zs: Array = fs["z"]
	var zc: float = (float(zs[0]) + float(zs[1])) * 0.5
	var w: float = float(zs[1]) - float(zs[0])
	var xa: float = float(fs["x0"])
	var run: float = float(nr - 1) * t
	var xl: float = xa + run
	var xb: float = xl + float(fs["landing"])
	var ym: float = y0 + float(nr) * r
	_flight(fst, "Flight1", Vector3(xa, y0, zc), 90.0, w, nr, r, t, y0, true)
	box(fst, "Landing", Vector3(xl, y0, float(zs[0])), Vector3(xb, ym, float(zs[1])), "stair")
	_flight(fst, "Flight2", Vector3(xb, ym, zc), 90.0, w, nr, r, t, y0, true)
	var xe: float = xb + run
	# Glass balustrades: ridged collider tops, not a perch over the void (D-104 slopes).
	for side: Array in [["N", float(zs[0]) - 0.03, float(zs[0]) + 0.03], ["S", float(zs[1]) - 0.03, float(zs[1]) + 0.03]]:
		# G2: 3 mm off the floor (their bottoms were coplanar with the solid steps' and the landing's: zfight)
		# and 3 mm short of the landing's ends (their end faces were coplanar with the landing's / the first step's)
		RT.apply(box(fst, "Balustrade%s1" % side[0], Vector3(xa - t, y0 + 0.003, float(side[1])), Vector3(xl - 0.003, ym + 1.1,
			float(side[2])), "teal_glass"))
		RT.apply(box(fst, "Balustrade%sL" % side[0], Vector3(xl + 0.003, y0 + 0.003, float(side[1])), Vector3(xb - 0.003,
			ym + 1.1, float(side[2])), "teal_glass"))
		RT.apply(box(fst, "Balustrade%s2" % side[0], Vector3(xb + 0.003, y0 + 0.003, float(side[1])), Vector3(xe, y1 + 1.1,
			float(side[2])), "teal_glass"))
	# Handrails on both balustrades (flights and landing).
	for k: int in range(2):
		var zr: float = float(zs[0]) + L.HANDRAIL_OFF if k == 0 else float(zs[1]) - L.HANDRAIL_OFF
		var hr: float = L.HANDRAIL_H
		_handrail(fst, "Rail%d1" % k, Vector3(xa, y0 + hr, zr), Vector3(xl, ym + hr, zr))
		_handrail(fst, "Rail%dL" % k, Vector3(xl, ym + hr, zr), Vector3(xb, ym + hr, zr))
		_handrail(fst, "Rail%d2" % k, Vector3(xb, ym + hr, zr), Vector3(xe, y1 + hr, zr))
	box(fst, "BaseClosureE", Vector3(xe - 0.05, y0, float(zs[0]) + 0.03), Vector3(xe, L.TOP41, float(zs[1]) - 0.03), "wall")
	# The enclosed base is not walkable (no navmesh island under the flights).
	obstruct(Transform3D.IDENTITY, AABB(Vector3(xa + 1.7, y0, float(zs[0])), Vector3(xe - xa - 1.7, 0.3, w)))


## Services riser: walls (west, south with the two panel openings), the hatch is a roof-slab hole and
## the grating a slab; the ladders are gameplay prefabs.
func _build_riser(parent: Node3D) -> void:
	var rs: Dictionary = L.RISER
	var b: Array = rs["box"]
	var t: float = float(rs["t"])
	var p: Array = rs["panel"]
	wall(parent, "RiserWallW", "z", float(b[0]), float(b[1]) + 0.15, float(b[3]), t, Vector2(L.F41, L.FRF), [], "wall")
	wall(parent, "RiserWallS", "x", float(b[3]), float(b[0]), float(b[2]) - 0.15, t, Vector2(L.F41, L.TOP42),
		[[float(p[0]), float(p[1]), L.F41, L.F41 + 2.0], [float(p[0]), float(p[1]), L.F42, L.F42 + 2.0]], "wall")


func _build_parapets(parent: Node3D) -> void:
	var gaps: Array = [L.TERRACE_LADDER["gap"]]
	for gid: String in L.GONDOLAS:
		gaps.append(L.GONDOLAS[gid]["gate"])
	for pp: Array in L.PARAPETS:
		var axis: String = String(pp[1])
		var fixed: float = float(pp[2])
		var cuts: Array = []
		for g: Array in gaps:
			if String(g[0]) == axis and absf(float(g[1]) - fixed) < 0.001:
				cuts.append([float(g[2]), float(g[3])])
		var holes: Array = []
		for c: Array in cuts:
			holes.append([float(c[0]), float(c[1]), L.FRF, L.PARAPET_TOP + 0.5])
		wall(parent, String(pp[0]), axis, fixed, float(pp[3]), float(pp[4]), L.EXT_T, Vector2(L.FRF, L.PARAPET_TOP), holes, "wall_ext")
		var runs: Array = _subtract([[float(pp[3]), float(pp[4])]], cuts)
		for i: int in range(runs.size()):
			_coping(parent, "%sCoping%d" % [pp[0], i], axis, fixed, float(runs[i][0]), float(runs[i][1]))


## RT.ANGLE_DEG (55 deg) sloped coping: not standable (D-104 slopes: >= 50 deg).
func _coping(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	add(parent, body)
	var h: float = L.EXT_T * 0.5
	var rise: float = h * tan(deg_to_rad(RT.ANGLE_DEG))
	var y: float = L.PARAPET_TOP
	var pts: PackedVector3Array = PackedVector3Array()
	for a: float in [a0, a1]:
		for q: Vector2 in [Vector2(-h, 0.0), Vector2(h, 0.0), Vector2(0.0, rise)]:
			pts.append(Vector3(a, y + q.y, fixed + q.x) if axis == "x" else Vector3(fixed + q.x, y + q.y, a))
	var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shp.points = pts
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shp
	add(body, col)
	var pm: PrismMesh = PrismMesh.new()
	pm.size = Vector3(L.EXT_T, rise, a1 - a0)
	pm.material = lib_mat("coping")
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = pm
	var mid: float = (a0 + a1) * 0.5
	mi.position = Vector3(mid, y + rise * 0.5, fixed) if axis == "x" else Vector3(fixed, y + rise * 0.5, mid)
	mi.basis = Basis(Vector3.UP, PI * 0.5) if axis == "x" else Basis.IDENTITY
	add(body, mi)


## Server cage K11: mesh enclosure with the gate opening on its south side (gate = door prefab).
func _build_cage(bld: Node3D) -> void:
	var cg: Node3D = add(bld, node3d("ServerCage")) as Node3D
	var b: Array = L.CAGE["box"]
	var y0: float = L.F41
	var y1: float = L.F41 + float(L.CAGE["h"])
	var g: Array = L.CAGE["gate"]
	# See-through wire-mesh panels (collision kept) on a frame of posts and a top rail.
	# G2: the mesh panels stop 3 mm inside the top rail and the posts are 1 cm fatter and 3 mm proud of the rails, so no
	# face of the frame is coplanar with a panel's or a rail's (zfight); the colliders are unchanged.
	var cn: Node3D = box(cg, "CageN", Vector3(float(b[0]), y0, float(b[1]) - 0.03), Vector3(float(b[2]), y1, float(b[1]) + 0.03),
		"cage_mesh")
	wall(cg, "CageS", "x", float(b[3]), float(b[0]), float(b[2]), 0.06, Vector2(y0, y1),
		[[float(g[0]), float(g[1]), y0, y0 + L.DOOR_H]], "cage_mesh")
	var cw: Node3D = box(cg, "CageW", Vector3(float(b[0]) - 0.03, y0, float(b[1]) + 0.03), Vector3(float(b[0]) + 0.03, y1,
		float(b[3]) - 0.03), "cage_mesh")
	var ce: Node3D = box(cg, "CageE", Vector3(float(b[2]) - 0.03, y0, float(b[1]) + 0.03), Vector3(float(b[2]) + 0.03, y1,
		float(b[3]) - 0.03), "cage_mesh")
	for pn: Node3D in [cn, cw, ce]:
		_trim_panel(pn, 0.057)
	for sp: Node in cg.get_children():
		if String(sp.name).begins_with("CageS"):
			_trim_panel(sp as Node3D, 0.057)
	var posts: Array = [[b[0], b[1]], [b[2], b[1]], [b[0], b[3]], [b[2], b[3]], [g[0], b[3]], [g[1], b[3]]]
	for i: int in range(posts.size()):
		var px: float = float(posts[i][0])
		var pz: float = float(posts[i][1])
		mesh_box(cg, "Post%d" % i, Vector3(px - 0.04, y0 + 0.003, pz - 0.04), Vector3(px + 0.04, y1 + 0.003, pz + 0.04), "trim")
	for e: Array in [["RailN", b[0], b[1], b[2], b[1]], ["RailS", b[0], b[3], b[2], b[3]], ["RailW", b[0], b[1], b[0], b[3]],
			["RailE", b[2], b[1], b[2], b[3]]]:
		mesh_box(cg, String(e[0]), Vector3(minf(float(e[1]), float(e[3])) - 0.035, y1 - 0.06, minf(float(e[2]), float(e[4])) - 0.035),
			Vector3(maxf(float(e[1]), float(e[3])) + 0.035, y1, maxf(float(e[2]), float(e[4])) + 0.035), "trim")


## G2: a cage mesh panel's visual shrunk by `top` at its top edge (it then stops inside the top rail). Visual only.
func _trim_panel(body: Node3D, top: float) -> void:
	if body == null or top <= 0.0:
		return
	for c: Node in body.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null:
			continue
		var sz: Vector3 = mi.mesh.get_aabb().size
		var mat_key: String = String(mi.mesh.surface_get_material(0).resource_name).trim_prefix("sl_")
		mi.mesh = box_mesh(sz - Vector3(0.0, top, 0.0), mat_key)
		mi.position.y -= top * 0.5


## Handrail (MUST 1.0-1.1 m): a 5 cm bar from a to b (world), small collision, beside the walk line.
func _handrail(parent: Node3D, nm: String, a: Vector3, b: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = (a + b) * 0.5
	body.basis = Basis.looking_at(b - a, Vector3.UP)
	body.set_meta(&"kind", "handrail")
	add(parent, body)
	var size: Vector3 = Vector3(0.05, 0.05, a.distance_to(b))
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = RT.shape(size, 2)  # ridged along the bar: a handrail is not a foothold (D-104 slopes)
	add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = box_mesh(size, "trim")
	add(body, mi)


## Rails on both sides of a straight flight along world z: x positions, from the bottom riser line
## (z0, floor y0) to the top riser line (z1, top y1) (the validator's nosing line); the bar centre
## runs HANDRAIL_H above it (top 1.05 m).
func _flight_rails(parent: Node3D, nm: String, xs: Array, z0: float, y0: float, z1: float, y1: float) -> void:
	for i: int in range(xs.size()):
		_handrail(parent, "%sRail%d" % [nm, i], Vector3(float(xs[i]), y0 + L.HANDRAIL_H, z0), Vector3(float(xs[i]), y1 + L.HANDRAIL_H, z1))


# --- Site -------------------------------------------------------------------------------------

## Exterior dressing beyond the play space (visual only): Calder below, Arden Tower, Vantage House,
## the skyline, streets and the river far below; crown fins, helipad lights, beacons, BMU rail.
func _build_site(geo: Node3D) -> void:
	var site: Node3D = add(geo, node3d("Site")) as Node3D
	var blocks: Node3D = add(site, node3d("Blocks")) as Node3D
	for b: Array in L.SITE_BLOCKS:
		var mi: Node3D = box_a(blocks, String(b[0]), b[1], String(b[2]), false)
		mi.set_meta(&"distant", true)
	var lit: Node3D = add(site, node3d("CityLights")) as Node3D
	# Lit window rows: each band is split into 2 m windows with 1 m piers, flush on its facade.
	for c: Array in L.CITY_LIGHTS:
		var mn: Vector3 = v3(c[1], 0)
		var mx: Vector3 = v3(c[1], 3)
		var along_x: bool = (mx.x - mn.x) > (mx.z - mn.z)
		var a0: float = mn.x if along_x else mn.z
		var a1: float = mx.x if along_x else mx.z
		var k: int = 0
		var a: float = a0
		while a + 2.0 <= a1 + 0.001:
			var wmn: Vector3 = Vector3(a, mn.y, mn.z) if along_x else Vector3(mn.x, mn.y, a)
			var wmx: Vector3 = Vector3(a + 2.0, mx.y, mx.z) if along_x else Vector3(mx.x, mx.y, a + 2.0)
			mesh_box(lit, "%s_%02d" % [c[0], k], wmn, wmx, "city_lights")
			k += 1
			a += 3.0
	var cables: Node3D = add(site, node3d("Cables")) as Node3D
	for cb: Array in L.CABLES:
		var a: Vector3 = cb[1]
		var e: Vector3 = cb[2]
		var cm: MeshInstance3D = MeshInstance3D.new()
		cm.name = String(cb[0])
		cm.mesh = box_mesh(Vector3(0.03, 0.03, a.distance_to(e)), "steel")
		cm.position = (a + e) * 0.5
		cm.basis = Basis.looking_at(e - a, Vector3.UP)
		add(cables, cm)
	var roof: Node3D = add(site, node3d("RoofDressing")) as Node3D
	# Helipad deck (painted, 2 cm) + green perimeter strips (fixtures).
	mesh_box(roof, "HelipadDeck", Vector3(25.0, L.FRF, 3.0), Vector3(35.0, L.FRF + 0.02, 13.0), "helipad")
	for s: Array in [["PadEdgeN", 25.0, 3.0, 35.0, 3.1], ["PadEdgeS", 25.0, 12.9, 35.0, 13.0],
			["PadEdgeW", 25.0, 3.1, 25.1, 12.9], ["PadEdgeE", 34.9, 3.1, 35.0, 12.9]]:
		var strip: MeshInstance3D = mesh_box(roof, String(s[0]), Vector3(float(s[1]), L.FRF + 0.02, float(s[2])),
			Vector3(float(s[3]), L.FRF + 0.05, float(s[4])), "heli_green")
		strip.set_meta(&"fixture", true)
	# BMU rail along the N and W parapets (2 cm strip, visual).
	mesh_box(roof, "BMURailN", Vector3(0.4, L.FRF, 0.45), Vector3(34.8, L.FRF + 0.02, 0.55), "steel")
	mesh_box(roof, "BMURailW", Vector3(0.45, L.FRF, 0.55), Vector3(0.55, L.FRF + 0.02, 6.0), "steel")
	# Crown fins (cold-white LED) on the parapets' outer faces.
	for i: int in range(12):
		var x: float = 1.5 + 3.0 * float(i)
		var fin: MeshInstance3D = mesh_box(roof, "CrownFinN%02d" % i, Vector3(x - 0.04, L.FRF - 2.0, -0.26),
			Vector3(x + 0.04, L.PARAPET_TOP, -0.2), "led_white")
		fin.set_meta(&"fixture", true)
		var fin2: MeshInstance3D = mesh_box(roof, "CrownFinS%02d" % i, Vector3(x - 0.04, L.FRF - 2.0, 18.2),
			Vector3(x + 0.04, L.PARAPET_TOP, 18.26), "led_white")
		fin2.set_meta(&"fixture", true)
	# Aircraft beacons on the plant block and the BMU.
	for bc: Array in [["BeaconPlantNE", Vector3(23.9, L.PLANT_ROOF, 7.6)], ["BeaconPlantSW", Vector3(12.1, L.PLANT_ROOF, 16.4)]]:
		var bp: Vector3 = bc[1]
		var bm: MeshInstance3D = mesh_box(roof, String(bc[0]), bp + Vector3(-0.1, 0.0, -0.1), bp + Vector3(0.1, 0.2, 0.1), "beacon_red")
		bm.set_meta(&"fixture", true)


# --- Props ------------------------------------------------------------------------------------

func _build_props(props: Node3D) -> void:
	var by_level: Dictionary = {}
	for nm: String in ["L40", "L41", "L42", "Terrace", "Roof"]:
		by_level[nm] = add(props, node3d(nm))
	for p: Array in L.PROPS:
		var base: Vector3 = p[1]
		prop_box(by_level[_prop_level(base)], String(p[0]), base, p[2], float(p[3]), String(p[4]), bool(p[5]), String(p[6]))
	for c: Array in L.CHAIRS:
		var cp: Vector3 = c[1]
		var parent: Node3D = by_level[_prop_level(cp)]
		chair(parent, String(c[0]), cp, float(c[2]))
		var ch: Node3D = parent.get_node(String(c[0])) as Node3D
		ch.set_meta(&"faces", ch.get_path_to(parent.get_node(String(c[3]))))


static func _prop_level(p: Vector3) -> String:
	if p.y < L.F41 - 0.1:
		return "L40"
	if p.y < L.F42 - 0.1:
		return "L41"
	if p.y < L.FRF - 0.1:
		return "Terrace" if p.z > 18.0 else "L42"
	return "Roof"


# --- Lighting ---------------------------------------------------------------------------------

## 02:10, overcast, no sun or moon: city glow from below (one dim directional), the LUT (sl_art.environment); the
## rooms' fixtures come from the dressing kits (sl_dress.gd), the map keeps only KEEP_MAP_LIGHTS (rooms without a kit:
## the stairs, the head house; the reception void).
func _build_lighting(lighting: Node3D) -> void:
	DA.new(self).call(&"environment", lighting, map_root)
	var fx: Node3D = add(lighting, node3d("Fixtures")) as Node3D
	_room_lights(fx)
	_ceiling_light(fx, "LightReceptionVoid", Vector3(16.5, L.TOP42, 2.4), ROOM_LIGHT["exec"][0], 0.8, 9.0)
	for cid: String in L.STAIR_CORES:
		var x0: float = float(L.STAIR_CORES[cid]["x0"])
		var levels: Array = L.STAIR_CORES[cid]["levels"]
		for i: int in range(levels.size()):
			var ceil_y: float = [L.TOP40, L.TOP41, L.TOP42, L.TOPRF][i]
			_ceiling_light(fx, "Light%s%d" % [cid, i], Vector3(x0 + 2.0, ceil_y, 15.9), ROOM_LIGHT["boh"][0], 0.5, 5.0)


## One fixture per room at the centre of its first volume rectangle (night levels by zone).
func _room_lights(fx: Node3D) -> void:
	for lv: String in ["L40", "L41", "L42", "RF"]:
		var ffl: float = float(L.LEVELS[lv][0])
		for r: Array in _level_rooms(lv):
			var uid: String = String(r[0])
			var meta: Array = L.ROOM_META.get(uid, [])
			if meta.is_empty() or float(meta[2]) <= 0.0 or uid in ["SL", "K3"] or not ("Light" + uid in DD.KEEP_MAP_LIGHTS):
				continue
			var rects: Array = L.ROOM_RECTS.get(uid, [[r[1], r[2], r[3], r[4]]])
			var q: Array = rects[rects.size() - 1]
			var cy: float = minf(ffl + float(meta[2]), float(L.LEVELS[lv][1]))
			var zone: String = "office"
			if uid in EXEC_ROOMS:
				zone = "exec"
			elif uid in BOH_ROOMS:
				zone = "boh"
			elif uid == "K13":
				zone = "security"
			elif uid == "K11":
				zone = "server"
			elif uid == "M3":
				zone = "art"
			var row: Array = ROOM_LIGHT[zone]
			var pos: Vector3 = Vector3((float(q[0]) + float(q[2])) * 0.5, cy, (float(q[1]) + float(q[3])) * 0.5)
			if uid == "K11":
				pos = Vector3(28.75, cy, 11.6)
			_ceiling_light(fx, "Light" + uid, pos, row[0], float(row[1]), float(row[2]))


## Ceiling-mounted fixture: pivot at the ceiling surface (top-centre), panel below, light under it.
func _ceiling_light(parent: Node3D, nm: String, pivot: Vector3, color: Color, energy: float, rng: float) -> void:
	var r: Node3D = node3d(nm, pivot)
	r.set_meta(&"mount", "ceiling")
	r.set_meta(&"fixture", true)
	r.set_meta(&"kind", "light_fixture")
	add(parent, r)
	# G2 (SL-1): the catalog fixture model (6500 K linear LED over the void, 5000 K panels in the stairs / head house)
	var art: String = String(DD.MAP_FIXTURE_ART["void" if nm.contains("Void") else "ceiling"])
	DA.new(self).call(&"fixture_model", r, art, map_root)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -0.2, 0.0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	light.layers |= VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
	add(r, light)


# --- G2 dressing and art (SL-1) -----------------------------------------------------------------

## The KitPlacer pass (sl_dress.gd + shadow_ledger_dressing.gd): every kit room, the direct props; the fill lights.
## Floor props obstruct the navmesh bake that follows.
func _build_dressing() -> void:
	var dress: RefCounted = DR.new()
	dress.call(&"setup", self, map_root)
	dress.call(&"dress", n("Props"))
	dress.call(&"fill_lights", add(n("Lighting"), node3d("Fill")) as Node3D)
	for line: String in dress.get(&"report"):
		printerr("dress: " + line)
		if line.begins_with("ERROR"):
			errors.append(line)


## After the bake: the lit city windows, merged railing visuals, reflection probes per room, occluders, merged facade.
func _build_art() -> void:
	var art: RefCounted = DA.new(self)
	var win: int = art.call(&"city_windows", n("Geometry/Site"), map_root)
	var merged: int = art.call(&"merge_railings", map_root) + int(art.call(&"merge_city", map_root))
	var probes: int = art.call(&"reflection_probes", add(n("Lighting"), node3d("ReflectionProbes")) as Node3D, map_root)
	var occ: int = art.call(&"occluders", add(n("Geometry"), node3d("Occluders")) as Node3D, map_root)
	var fac: int = art.call(&"merge_facade", map_root)
	printerr("art: %d city windows, %d railing meshes merged away, %d probes, %d occluders, %d facade meshes merged away"
		% [win, merged, probes, occ, fac])


# --- Rooms and zones --------------------------------------------------------------------------

func _build_rooms(rooms: Node3D) -> void:
	var tall: Dictionary = {}
	for t: Array in L.TALL_ROOMS:
		tall[String(t[0])] = t
	var done: Dictionary = {}
	for lv: String in ["L40", "L41", "L42", "RF"]:
		var ffl: float = float(L.LEVELS[lv][0])
		var top: float = float(L.LEVELS[lv][1])
		for r: Array in _level_rooms(lv):
			var uid: String = String(r[0])
			if done.has(uid) or not L.ROOM_META.has(uid):
				continue
			done[uid] = true
			var meta: Array = L.ROOM_META[uid]
			var boxes: Array = []
			var fidx: int = int(L.LEVELS[lv][2])
			if tall.has(uid):
				var tr: Array = tall[uid]
				var q: Array = tr[4]
				fidx = int(tr[1])
				boxes.append([q[0], float(tr[2]), q[1], q[2], float(tr[3]), q[3]])
			else:
				var y1: float = minf(ffl + float(meta[2]), top) if float(meta[2]) > 0.0 else top
				for q2: Array in L.ROOM_RECTS.get(uid, [[r[1], r[2], r[3], r[4]]]):
					boxes.append([q2[0], ffl, q2[1], q2[2], y1, q2[3]])
			_room(rooms, uid, String(meta[0]), String(meta[1]), fidx, boxes, meta[4])
	for x: Array in L.EXTERIOR_ROOMS:
		_room(rooms, String(x[0]), String(x[1]), String(x[2]), int(x[3]), x[4], null)


func _room(rooms: Node3D, uid: String, purpose: String, kit: String, fidx: int, boxes: Array, crange: Variant) -> void:
	var rv: RoomVolume = RoomVolume.new()
	rv.name = "Room" + uid
	rv.room_id = StringName(uid)
	rv.purpose = StringName(purpose)
	rv.dressing_kit = StringName(kit)
	rv.floor_index = fidx
	rv.collision_layer = 1 << 9
	rv.collision_mask = 0
	rv.monitoring = false
	if crange != null:
		rv.set_meta(&"ceiling_range", crange)
	add(rooms, rv)
	area_boxes(rv, boxes)


func _build_zones(zones: Node3D) -> void:
	for z: Array in L.ZONES:
		var mz: MapZone = zone(zones, String(z[0]), String(z[1]), String(z[2]), z[3])
		if String(z[1]) == "BODY_HIDE":
			mz.set_meta(&"capacity", 2 if String(z[0]).contains("AHU") else 1)
		if String(z[1]) == "OUT_OF_BOUNDS":
			mz.set_meta(&"respawn_tag", &"oob_respawn")
			mz.set_meta(&"alarm", false)


# --- Patrols, spawns, tactical ----------------------------------------------------------------

func _build_patrols(patrols: Node3D) -> void:
	_patrol_graph(patrols, "Tower", &"tower", 1, L.PATROL_POINTS_TOWER, L.PATROL_EDGES_TOWER)
	_patrol_graph(patrols, "Roof", &"roof", 3, L.PATROL_POINTS_ROOF, L.PATROL_EDGES_ROOF)


func _patrol_graph(parent: Node3D, nm: String, graph_id: StringName, fidx: int, points: Dictionary, edges: Array) -> void:
	var g: PatrolGraph = PatrolGraph.new()
	g.name = nm
	g.graph_id = graph_id
	g.floor_index = fidx
	add(parent, g)
	var names: Array = points.keys()
	for pn: Variant in names:
		var row: Array = points[pn]
		var p: PatrolPoint = PatrolPoint.new()
		p.name = String(pn)
		p.position = row[0]
		p.pause_range = row[1]
		p.pause_anim = StringName(String(row[2]))
		var tags: Array[StringName] = []
		for t: Variant in row[3]:
			tags.append(StringName(String(t)))
		p.tags = tags
		if row[4] != null:
			p.basis = yaw_basis(float(row[4]))
			p.face_marker_forward = true
		add(g, p)
	var links: Dictionary = {}
	for e: Array in edges:
		for pair: Array in [[e[0], e[1]], [e[1], e[0]]]:
			var a: String = String(pair[0])
			var b: String = String(pair[1])
			if not points.has(a) or not points.has(b):
				errors.append("patrol edge %s-%s: unknown point" % [a, b])
				continue
			if not links.has(a):
				links[a] = []
			if not (links[a] as Array).has(b):
				(links[a] as Array).append(b)
	for pn2: Variant in names:
		var pp: PatrolPoint = g.get_node(String(pn2)) as PatrolPoint
		var paths: Array[NodePath] = []
		for other: Variant in links.get(pn2, []):
			paths.append(pp.get_path_to(g.get_node(String(other))))
		pp.links = paths


func _build_spawns(spawns: Node3D) -> void:
	for p: Array in L.PLAYER_SPAWNS:
		spawn(spawns, String(p[0]), "PLAYER", p[1], float(p[2]), p[3], "", "")
	for s: Array in L.NPC_SPAWNS:
		spawn(spawns, String(s[0]), String(s[1]), s[2], float(s[3]), s[4], String(s[5]), String(s[6]))


func _build_tactical(tac: Node3D) -> void:
	for t: Array in L.TACTICAL:
		var tp: TacticalPoint = TacticalPoint.new()
		tp.name = String(t[0])
		tp.kind = TacticalPoint.Kind[String(t[1])]
		tp.position = t[2]
		tp.basis = yaw_basis(float(t[3]))
		var tg: Array[StringName] = []
		for x: Variant in t[4]:
			tg.append(StringName(String(x)))
		tp.tags = tg
		tp.breachable = bool(t[5])
		add(tac, tp)


## PREPLAN_POINT markers (preplanning.md): node name = point id; metas category/label/floor/params.
func _build_preplan(pre: Node3D) -> void:
	for p: Array in L.PREPLAN_POINTS:
		var m: Marker3D = Marker3D.new()
		m.name = String(p[0])
		m.position = p[2]
		m.set_meta(&"category", StringName(String(p[1])))
		m.set_meta(&"label", StringName("ui.preplan.point." + String(p[0])))
		m.set_meta(&"floor", int(p[3]))
		m.set_meta(&"params", p[4])
		m.add_to_group(G.PREPLAN_POINT, true)
		add(pre, m)


func _build_review_cameras(cams: Node3D) -> void:
	var paths: Array[NodePath] = []
	for c: Array in L.REVIEW_CAMERAS:
		var m: Marker3D = Marker3D.new()
		var nm: String = String(c[0])
		m.name = nm
		var pos: Vector3 = c[1]
		var target: Vector3 = c[2]
		m.position = pos
		var dir: Vector3 = target - pos
		var up: Vector3 = Vector3.FORWARD if absf(dir.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
		m.basis = Basis.looking_at(dir, up)
		if nm.begins_with("TopDown"):
			m.set_meta(&"size", float(c[3]))
		else:
			m.set_meta(&"fov", float(c[3]))
		m.set_meta(&"caption", String(c[4]))
		add(cams, m)
		paths.append(NodePath("ReviewCameras/" + nm))
	map_root.review_cameras = paths


## Always-present ladder: the terrace caged ladder (terrace <-> roof). Riser and gondola links live in
## their variant slots.
func _build_nav_links(nav: NavigationRegion3D) -> void:
	var t: Dictionary = L.TERRACE_LADDER
	var link: Array = t["link"]
	nav_link(nav, "TerraceLadderLink", link[0], link[1])


# --- Navigation bake --------------------------------------------------------------------------

## D-073: BARRED / VAULT doorways (the L40 stair-core police gates) are baked CLOSED: a projected
## obstruction fills the opening (+0.15 m into each jamb, 0.3 m each side of the door line), so the
## agent-radius erosion leaves no navmesh through it. ENV A's door NavLink bridges the gap while the
## door is passable. validate_level `barred_doors` asserts it.
func _close_barred_doorways() -> void:
	for d: Array in L.DOORS:
		if not (String(d[4]) in ["BARRED", "VAULT"]):
			continue
		var w: float = (2.0 if String(d[1]).contains("double") else 1.0) + 0.3
		var o: Vector3 = d[2]
		obstruct(Transform3D(yaw_basis(float(d[3])), o), AABB(Vector3(-w * 0.5, -0.2, -0.3), Vector3(w, 2.6, 0.6)))


## Bakes the walkable navmesh (heist_map.md §3: agent radius 0.3, height 1.8, climb 0.3, slope 40,
## cell 0.1 / 0.1) from the Geometry colliders. Props and prefab bodies are projected obstructions.
## Doors stay open except the BARRED / VAULT doorways (_close_barred_doorways).
func _bake(nav: NavigationRegion3D) -> int:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.3
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var holder: Node3D = Node3D.new()
	holder.name = "BakeSource"
	holder.add_child(map_root.get_node("Geometry").duplicate())
	get_root().add_child(holder)
	await physics_frame
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, holder)
	for o: Array in obstructions:
		src.add_projected_obstruction(o[0], float(o[1]), float(o[2]), false)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	holder.queue_free()
	await process_frame
	nav.navigation_mesh = nm
	return nm.get_polygon_count()
