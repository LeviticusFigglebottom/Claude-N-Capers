## Gallery Night G1 greybox generator (GN-C1). Owner: ENV C. Freeze lifted (D-110): writes the map's final path
## res://world/heists/gallery_night/gallery_night.tscn by default.
## Regenerate (deterministic; never hand-edit the output):
##   /opt/godot/godot --headless --path game --script res://world/heists/gallery_night/greybox/build_greybox.gd \
##     -- --out=<path>            (default res://world/heists/gallery_night/gallery_night.tscn)
## Data: gallery_night_layout.gd, emitted by tools/levelcheck/plans/gallery_night_emit_layout.py from the floor
## plans (gallery_night_floors_ascii.py) and the slot list (gallery_night_slots.py --check). Design:
## docs/design/heists/gallery_night.md (APPROVED D-075; Build rulings B1-B6). Contracts: heist_map.md v1.2.
## Built: the four floors' shell (walls from the room edges with every plan opening, glass, slabs with the stair /
## Great Hall holes, ceilings, roofs, parapets), Stair SS (U-stair, ramp colliders) and the imperial stair, the
## balcony balustrades, the grade around the building, RoomVolumes (Room list purposes / kits), PUBLIC /
## RESTRICTED zones, player and police spawns, preplan points, review cameras, every VariantSlot (placeholder
## content), the navmesh. Every collision body carries a surface id (SurfaceTags); an untagged body fails the
## build. No RNG anywhere yet (dressing will use per-room seeded streams, KitPlacer.str_less ordering).
## G1 to-dos done here (GN-C1): Stair SS wall handrails, imperial-stair balustrades and landing guards, deck parapet
## copings >= 50 deg, the areaway light well + passage into PL (QC-64), the oculus, the street police islands and
## closures, P5's rappel / roof-drop links (QC-41), neighbour massing. Rehearsal fixes (g1_rehearsal.md F1-F7): sills
## under every walk-through facade opening (F1); slot facings + UsePoints (F2/F3); tagged placeholders and the
## casing_hall marker (F5); ENV A's `door` prefab on every B2 door with the greybox kit visual (arch_door_*_t20/t40:
## flush frame colliders, `frame_proud` / `door_frame_gap`, PO-7), holes cut to the kit opening, and breakable
## `window` prefabs on the EB / SL gameplay windows (F7); other windows stay greybox glass panes.
extends "res://world/heists/gallery_night/greybox/gn_npc.gd"

const FLOOR_INDEX: Dictionary = {"B": 0, "G": 1, "U": 2, "R": 3}
const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")  # PO6-17 AssaultEvents markers
const AE: GDScript = preload("res://world/heists/gallery_night/greybox/gn_assault.gd")  # their data + breach holes
## Slab underside above each floor's rooms (where the ceiling plane must stay below).
const SLAB_ABOVE: Dictionary = {"B": -0.3, "G": 5.1, "R": 11.7}
const SS_HOLE_Z: float = 6.35
## Guards and balustrades: 1.1 m (level_standards §2 railing 1.0-1.1). Handrail bar centre above the nosing line
## (5 cm bar: top 1.05 m) and its offset from the wall / guard face (lc_stair_rails: >= 0.03 m proud).
const RAIL_H: float = 1.1
const HANDRAIL_H: float = 1.025
const HANDRAIL_OFF: float = 0.07
## Stair SS: inner face of the facade wall on the core's west side (EXT_T / 2).
const CORE_FACE_W: float = 0.2
## Grand stair stone balustrade: thickness, top above the nosing line, depth below it (into the steps).
const BAL_T: float = 0.15
const BAL_TOP: float = 1.05
const BAL_BELOW: float = 0.25
## Sculpture Court reflecting pool (B4.4 / next_heist §7.4, ENV P review): [x0, z0, x1, z1] outer rim, rim width, rim
## height (= the basin's depth: the pool floor is the court grade), water level. 0.3 m stays under the 0.35 m step.
const POOL: Array = [-12.0, 15.0, -7.0, 21.0]
const POOL_RIM_W: float = 0.3
const POOL_RIM_H: float = 0.3
const POOL_WATER_Y: float = 0.2
const WATER_MAT: String = "res://world/materials/water_harbour_night.tres"
## Parapet coping (B4.5: >= 50 deg): a ridge 0.3 m above the wall top over the half thickness (0.2 m) = 56 deg.
const COPING_RISE: float = 0.3


func _initialize() -> void:
	_build.call_deferred()


## Output scene: DEFAULT_OUT, or `-- --out=<path>` (the regen-twice determinism check writes scratch files).
static func _scene_out() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			return a.trim_prefix("--out=")
	return DEFAULT_OUT


func _build() -> void:
	var out: String = _scene_out()
	var old_scene_uid: String = read_uid(out)
	map_root = HeistMap.new()
	map_root.name = "GalleryNight"
	# HeistDef / variant table: ENV B's data, copied verbatim from its drafts to the registry path (heist_map.md §1);
	# the generator only references them (DEF_PATH / VARIANTS_PATH), it never writes them.
	map_root.heist_def = load(DEF_PATH) as HeistDef
	map_root.variant_table = load(VARIANTS_PATH) as HeistVariantTable
	if map_root.heist_def == null or map_root.variant_table == null:
		_fail("missing %s or %s" % [DEF_PATH, VARIANTS_PATH])
		return
	map_root.floor_heights = PackedFloat32Array(L.FLOOR_HEIGHTS)
	map_root.floor_names = PackedStringArray(L.FLOOR_NAMES)
	map_root.set_meta(&"camera_spine_rooms", PackedStringArray(L.CAMERA_SPINE_ROOMS))
	map_root.set_meta(&"camera_screen_slots", PackedStringArray(L.CAMERA_SCREEN_SLOTS))
	map_root.set_meta(&"camera_layout_group", "camera")
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
	mission.set_script(load(MISSION_PATH))   # G1 stub (GN-C1); ENV A completes it (GN-A1)
	add(map_root, mission)
	add(map_root, node3d("Preplan"))
	add(map_root, node3d("ReviewCameras"))

	_build_shell(n("Geometry"))
	_build_site(n("Geometry"))
	_build_rooms(n("Rooms"))
	_build_zones(n("Zones"))
	_build_spawns(n("Spawns"))
	_build_preplan(n("Preplan"))
	_build_review_cameras(n("ReviewCameras"))
	build_npcs()
	build_tactical(n("Tactical"))
	build_lights(n("Lighting"))
	_build_environment(n("Lighting"))
	build_gameplay(n("Gameplay"))
	build_variants(n("Variants"))
	# PO6-17 markers (gn_assault.gd); the intact breach infills obstruct the bake
	errors.append_array(AM.build(map_root, AE.TURRET_VANS, AE.HELI_ORBITS, AE.HELI_DROPS, [], AE.BREACHES, obstructions,
		0.0))  # face_pad 0: the GN bake erodes a projected infill like the wall face (navmesh unchanged)
	_build_nav_links(nav)
	var polys: int = await _bake(nav)
	if polys <= 0:
		_fail("navmesh bake produced no polygons")
		return
	for untagged: String in SurfaceTags.tag_tree(map_root):  # PO-8 / D-105: refuse untagged bodies
		errors.append("no surface id for %s" % untagged)
	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var ps: PackedScene = PackedScene.new()
	var err: int = ps.pack(map_root)
	if err == OK:
		err = ResourceSaver.save(ps, out)
	map_root.free()
	if err != OK:
		_fail("cannot save %s (%d)" % [out, err])
		return
	normalize_scene(out, old_scene_uid)
	print("gallery_night: saved %s (navmesh polygons: %d)" % [out, polys])
	quit(0)


func _fail(msg: String) -> void:
	push_error("gallery_night: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


# --- Plan helpers -----------------------------------------------------------------------------

## Rectangle [x0, z0, x1, z1] minus holes -> merged rectangles (deterministic; as the SL generator).
static func rects_minus(outer: Array, holes: Array) -> Array:
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
	var out: Array = []
	var open: Dictionary = {}
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
		var nxt: Dictionary = {}
		for run: Array in runs:
			var key: String = "%.4f|%.4f" % [float(run[0]), float(run[1])]
			nxt[key] = [float(run[0]), open[key][1] if open.has(key) else zs[j], float(run[1]), zs[j + 1]]
		for k: String in open:
			if not nxt.has(k):
				out.append(open[k])
		open = nxt
	for k2: String in open:
		out.append(open[k2])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	return out


func _slab(parent: Node3D, nm: String, outer: Array, holes: Array, y0: float, y1: float, mat: String) -> void:
	var rects: Array = rects_minus(outer, holes)
	for i: int in range(rects.size()):
		var r: Array = rects[i]
		box(parent, "%s_%02d" % [nm, i], Vector3(float(r[0]), y0, float(r[1])), Vector3(float(r[2]), y1, float(r[3])), mat,
			SLAB_TILE)


static func _inset(r: Array, d: float) -> Array:
	return [float(r[0]) + d, float(r[1]) + d, float(r[2]) - d, float(r[3]) - d]


# --- Building shell ---------------------------------------------------------------------------

func _build_shell(geo: Node3D) -> void:
	var bld: Node3D = add(geo, node3d("Building")) as Node3D
	_build_walls(add(bld, node3d("Walls")) as Node3D)
	_build_slabs(add(bld, node3d("Slabs")) as Node3D)
	_build_ceilings(add(bld, node3d("Ceilings")) as Node3D)
	var stairs: Node3D = add(bld, node3d("Stairs")) as Node3D
	_build_stair_ss(stairs)
	_build_grand_stair(stairs)
	_build_rails(add(bld, node3d("Balustrades")) as Node3D)
	_build_copings(add(bld, node3d("Coping")) as Node3D)
	_build_areaway(add(bld, node3d("Areaway")) as Node3D)


## Walls from the emitted runs; every plan opening on the run's line is a hole (doors and arches full height,
## windows sill..head with a glass pane).
func _build_walls(parent: Node3D) -> void:
	var lv: Dictionary = {}
	for f: String in L.FLOORS:
		lv[f] = add(parent, node3d("Floor" + f))
	var counts: Dictionary = {}
	for w: Array in L.WALLS:
		var f2: String = String(w[0])
		var axis: String = String(w[1])
		var fixed: float = float(w[2])
		var holes: Array = []
		for o: Array in L.OPENINGS:
			if String(o[0]) == f2 and String(o[2]) == axis and absf(float(o[3]) - fixed) < 0.001 \
					and float(o[5]) > float(w[3]) and float(o[4]) < float(w[4]) and not AE.replaced(o):
				holes.append_array(opening_holes(o)[0])
		holes.append_array(AE.holes(f2, axis, fixed, float(w[3]), float(w[4])))  # PO6-17 breach openings (infilled)
		var fit: Array = wall_fit(f2, axis, fixed, float(w[5]), float(w[3]), float(w[4]))
		var thick: float = float(fit[1])
		var mat: String = "wall_ext" if thick >= L.EXT_T - 0.001 and _on_foot(f2, axis, fixed) else "wall"
		var key: String = "%s%s%04d" % [f2, axis.to_upper(), int(round(fixed * 10.0))]
		counts[key] = int(counts.get(key, -1)) + 1
		wall(lv[f2], "%s_%d" % [key, counts[key]], axis, float(fit[0]), float(w[3]), float(w[4]), thick,
			Vector2(float(w[6]), float(w[7])), holes, mat)
	_build_sills(add(parent, node3d("Sills")) as Node3D)
	var glass: Node3D = add(parent, node3d("Glass")) as Node3D
	for i: int in range(L.OPENINGS.size()):
		var o2: Array = L.OPENINGS[i]
		if String(o2[1]) != "W" or bool(opening_holes(o2)[1]) or AE.replaced(o2):   # a WindowPrefab / breach glazes it
			continue
		var fx: float = float(o2[3])
		var mn: Vector3 = Vector3(float(o2[4]), float(o2[6]), fx - 0.02) if String(o2[2]) == "x" \
			else Vector3(fx - 0.02, float(o2[6]), float(o2[4]))
		var mx: Vector3 = Vector3(float(o2[5]), float(o2[7]), fx + 0.02) if String(o2[2]) == "x" \
			else Vector3(fx + 0.02, float(o2[7]), float(o2[5]))
		box(glass, "Pane%02d_%s" % [i, String(o2[8]).get_slice(" ", 0)], mn, mx, "glass")


## Rehearsal F1: the floor slabs stop at the facade's inner face and the outside grade / areaway floor at its centre
## line or outer face, so under a facade opening a strip had no floor and the navmesh did not cross it (the bronze
## doors, the LD doors, the areaway passage). A sill box (the opening's fitted width x the wall thickness, the slab's
## depth, top at FFL) under every walk-through facade opening (doors, arches, the roller, the roof ladder top) joins
## inside and outside. Openings over a lower floor's facade wall that tops out at this FFL (the court French doors
## over the basement wall) already stand on it.
func _build_sills(parent: Node3D) -> void:
	for i: int in range(L.OPENINGS.size()):
		var o: Array = L.OPENINGS[i]
		var f: String = String(o[0])
		var axis: String = String(o[2])
		var fixed: float = float(o[3])
		var ffl: float = float(L.FFL[f])
		if not (String(o[1]) in ["D", "A", "S", "R", "V", "h"]) or absf(float(o[6]) - ffl) > 0.001 \
				or not _on_foot(f, axis, fixed):
			continue
		for h: Array in opening_holes(o)[0]:
			var a0: float = float(h[0])
			var a1: float = float(h[1])
			if _wall_below(f, axis, fixed, a0, a1, ffl):
				continue
			var w: Array = wall_at(f, axis, fixed, a0, a1)
			var t: float = float(w[5]) if not w.is_empty() else L.EXT_T
			var lo: float = fixed - t * 0.5
			var hi: float = fixed + t * 0.5
			if f == "G":   # the grade starts at the facade's centre line on every side: fill the inner half only
				var ft: Array = L.FOOT[f]
				var outer_lo: bool = absf(fixed - float(ft[0 if axis == "z" else 1])) < 0.001
				lo = fixed if outer_lo else lo
				hi = hi if outer_lo else fixed
			var mn: Vector3 = Vector3(a0, ffl - L.SLAB_T, lo) if axis == "x" else Vector3(lo, ffl - L.SLAB_T, a0)
			var mx: Vector3 = Vector3(a1, ffl, hi) if axis == "x" else Vector3(hi, ffl, a1)
			box(parent, "Sill%02d_%s" % [i, String(o[8]).get_slice(" ", 0).replace("-", "")], mn, mx, "floor")
	# PO6-17 ground-floor wall breaches: the floor under the (infilled) opening, inner half as above, for when it blows
	for b: Array in AE.BREACHES:
		var q: Array = AE.opening(b)
		if String(b[1]) != "wall" or absf(float(q[4])) > 0.001:
			continue
		var ax: String = String(q[0])
		var fx: float = float(q[1])
		var ft2: Array = L.FOOT["G"]
		var lo_out: bool = absf(fx - float(ft2[0 if ax == "z" else 1])) < 0.001
		var s0: float = fx if lo_out else fx - L.EXT_T * 0.5
		var s1: float = fx + L.EXT_T * 0.5 if lo_out else fx
		var bmn: Vector3 = Vector3(float(q[2]), -L.SLAB_T, s0) if ax == "x" else Vector3(s0, -L.SLAB_T, float(q[2]))
		var bmx: Vector3 = Vector3(float(q[3]), 0.0, s1) if ax == "x" else Vector3(s1, 0.0, float(q[3]))
		box(parent, "SillBreach_%s" % String(b[0]).get_slice("_", 1), bmn, bmx, "floor")


## A wall run of a lower floor on the same line covering [a0, a1] whose top is at `ffl` (it carries the opening).
static func _wall_below(f: String, axis: String, fixed: float, a0: float, a1: float, ffl: float) -> bool:
	for w: Array in L.WALLS:
		if String(w[0]) != f and String(w[1]) == axis and absf(float(w[2]) - fixed) < 0.001 \
				and float(w[3]) <= a0 + 0.001 and float(w[4]) >= a1 - 0.001 and absf(float(w[7]) - ffl) < 0.001:
			return true
	return false


func _on_foot(f: String, axis: String, fixed: float) -> bool:
	var ft: Array = L.FOOT[f]
	if axis == "x":
		return absf(fixed - float(ft[1])) < 0.001 or absf(fixed - float(ft[3])) < 0.001
	return absf(fixed - float(ft[0])) < 0.001 or absf(fixed - float(ft[2])) < 0.001


## Floor slabs (top at FFL; inside the facade's inner face), the Stair SS flight hole on every floor above the
## basement, the Great Hall void on the upper floor; the roof deck; the roofs over the upper rooms and the head
## house / lift motor room. The Great Hall roof has the glazed oculus (P5's rappel, QC-41). TODO(G1): the art-lift
## landings are solid floor (the bag_lift prefab's car serves each landing; markers in Gameplay/Lifts).
func _build_slabs(parent: Node3D) -> void:
	var half: float = L.EXT_T * 0.5
	var ss_hole: Array = [half, half, float(L.SS_CLEAR[2]), SS_HOLE_Z]
	for f: String in ["B", "G", "U", "R"]:
		var y: float = float(L.FFL[f])
		var holes: Array = [] if f == "B" else [ss_hole]
		for v: Array in L.VOIDS:
			if String(v[0]) == f:
				holes.append(v[2])
		_slab(parent, "Slab" + f, _inset(L.FOOT[f], half), holes, y - L.SLAB_T, y, "roof" if f == "R" else "floor")
	for r: Array in L.ROOMS:
		if String(r[0]) != "U" or L.ROOF_DECK_ROOMS.has(String(r[1])):
			continue
		var top: float = float(L.U_TOP[String(r[1])])
		var rr: Array = _clip_foot("U", [r[3], r[4], r[5], r[6]])
		box(parent, "Roof" + String(r[1]), Vector3(rr[0], top - L.SLAB_T, rr[1]), Vector3(rr[2], top, rr[3]), "roof")
	for v2: Array in L.VOIDS:
		var top2: float = float(L.U_TOP[String(v2[1])])
		_slab(parent, "Roof" + String(v2[1]), v2[2], [L.OCULUS] if String(v2[1]) == "GH_VOID" else [], top2 - L.SLAB_T, top2,
			"roof")
	_build_oculus(parent)
	for r2: Array in L.ROOMS:
		if String(r2[0]) == "R" and float(r2[7]) > 0.0:
			var yt: float = float(L.FFL["R"]) + float(r2[7]) + L.SLAB_T
			var c: Array = _clip_foot("R", [r2[3], r2[4], r2[5], r2[6]])
			box(parent, "Roof" + String(r2[1]), Vector3(c[0], yt - L.SLAB_T, c[1]), Vector3(c[2], yt, c[3]), "roof")


func _clip_foot(f: String, r: Array) -> Array:
	var half: float = L.EXT_T * 0.5
	var ft: Array = L.FOOT[f]
	return [maxf(float(r[0]), float(ft[0]) + half), maxf(float(r[1]), float(ft[1]) + half),
		minf(float(r[2]), float(ft[2]) - half), minf(float(r[3]), float(ft[3]) - half)]


## Ceiling planes (0.05 m) where a room's ceiling is below the slab / roof above it. The Great Hall's covers the
## balconies and the loggia (same plane, 9.8); the galleries, CS and TR reach their roof (no plane).
func _build_ceilings(parent: Node3D) -> void:
	for r: Array in L.ROOMS:
		var f: String = String(r[0])
		var rid: String = String(r[1])
		var ceil: float = float(r[7])
		if ceil <= 0.0 or rid in ["BW", "BE", "SL"]:
			continue
		var cy: float = float(L.FFL[f]) + ceil
		var above: float = float(SLAB_ABOVE.get(f, 0.0))
		if f == "U":
			above = float(L.U_TOP[rid]) - L.SLAB_T
		if rid == "GH":
			above = float(L.U_TOP["GH_VOID"]) - L.SLAB_T
		if cy >= above - 0.01:
			continue
		if rid == "GH":   # the coffered laylight, open at the oculus
			_slab(parent, "Ceil%s%s" % [f, rid], [r[3], r[4], r[5], r[6]], [L.OCULUS], cy, cy + 0.05, "ceiling")
			continue
		box(parent, "Ceil%s%s" % [f, rid], Vector3(float(r[3]), cy, float(r[4])), Vector3(float(r[5]), cy + 0.05, float(r[6])),
			"ceiling")


## The oculus (22, 17): a lined shaft from the laylight (+9.8) to the roof (+11.0) and a flush glass pane in the roof
## (breakable at G1 via the window prefab; the rappel link starts on it, QC-41).
func _build_oculus(parent: Node3D) -> void:
	var oc: Node3D = add(parent, node3d("Oculus")) as Node3D
	var o: Array = L.OCULUS
	var x0: float = float(o[0])
	var z0: float = float(o[1])
	var x1: float = float(o[2])
	var z1: float = float(o[3])
	var gh: Array = L.ROOMS.filter(func(r: Array) -> bool: return String(r[1]) == "GH")[0]
	var y0: float = float(gh[7]) + 0.05
	var y2: float = float(L.U_TOP["GH_VOID"])
	var y1: float = y2 - L.SLAB_T
	var t: float = 0.1
	box(oc, "LiningN", Vector3(x0 - t, y0, z0 - t), Vector3(x1 + t, y1, z0), "wall")
	box(oc, "LiningS", Vector3(x0 - t, y0, z1), Vector3(x1 + t, y1, z1 + t), "wall")
	box(oc, "LiningW", Vector3(x0 - t, y0, z0), Vector3(x0, y1, z1), "wall")
	box(oc, "LiningE", Vector3(x1, y0, z0), Vector3(x1 + t, y1, z1), "wall")
	box(oc, "Glass", Vector3(x0, y2 - 0.04, z0), Vector3(x1, y2, z1), "glass")


## Stair SS: per storey a west up-flight (north from z 6.35), the half landing, an east return flight (south to
## the next floor landing) and the well divider; a guard rail over the last flight at the roof landing.
func _build_stair_ss(parent: Node3D) -> void:
	var c: Node3D = add(parent, node3d("StairSS")) as Node3D
	var xw: float = (float(L.SS_WEST[0]) + float(L.SS_WEST[1])) * 0.5
	var xe: float = (float(L.SS_EAST[0]) + float(L.SS_EAST[1])) * 0.5
	var w: float = float(L.SS_WEST[1]) - float(L.SS_WEST[0])
	var t: float = L.SS_TREAD
	var cl: Array = L.SS_CLEAR
	for i: int in range(L.SS_STOREYS.size()):
		var st: Array = L.SS_STOREYS[i]
		var y0: float = float(st[0])
		var y1: float = float(st[1])
		var m: int = int(st[2])
		var r: float = float(st[3])
		var zh: float = L.SS_Z_START - float(m - 1) * t
		var yh: float = y0 + float(m) * r
		flight(c, "Flight%dW" % i, Vector3(xw, y0, L.SS_Z_START), 180.0, w, m, r, t, null)
		flight(c, "Flight%dE" % i, Vector3(xe, yh, zh), 0.0, w, m, r, t, null)
		box(c, "HalfLanding%d" % i, Vector3(float(cl[0]), yh - 0.3, float(cl[1])), Vector3(float(cl[2]), yh, zh), "stair")
		# The top storey's divider rises a guard height above the roof landing (the flight below is open there).
		var dtop: float = y1 + (RAIL_H if i == L.SS_STOREYS.size() - 1 else 0.0)
		box(c, "Divider%d" % i, Vector3(float(L.SS_WELL[0]), y0, zh), Vector3(float(L.SS_WELL[1]), dtop, L.SS_Z_START), "wall")
		# Wall handrails both sides of both flights, HANDRAIL_H above the nosing line (lc_stair_rails: wall side
		# 0.85-1.1 m, >= 0.03 m proud of the wall). Nosing line: riser k top (k r) at k-1 treads from the first riser.
		var sides_w: Array = [CORE_FACE_W + HANDRAIL_OFF, float(L.SS_WELL[0]) - HANDRAIL_OFF]
		var sides_e: Array = [float(L.SS_WELL[1]) + HANDRAIL_OFF, float(cl[2]) - HANDRAIL_OFF]
		var run: float = float(m - 1) * t
		for k: int in range(2):
			_handrail(c, "Flight%dWRail%d" % [i, k], Vector3(float(sides_w[k]), y0 + r + HANDRAIL_H, L.SS_Z_START),
				Vector3(float(sides_w[k]), yh + HANDRAIL_H, L.SS_Z_START - run))
			_handrail(c, "Flight%dERail%d" % [i, k], Vector3(float(sides_e[k]), yh + r + HANDRAIL_H, zh),
				Vector3(float(sides_e[k]), y1 + HANDRAIL_H, zh + run))
	var ytop: float = float(L.FFL["R"])
	railing(c, "TopRail", Vector3(float(cl[0]), ytop, L.SS_Z_START - 0.06), Vector3(float(L.SS_WELL[0]), ytop + 1.1, L.SS_Z_START))


## Imperial stair (Great Hall, landmark 3): the central flight (solid base) to the half landing, the two return
## flights to the balcony landings, guard rails on the landings' open edges, stone balustrades on every flight.
## Chain note: the returns' first risers sit 6.2 m (x) from the central flight's last riser across the 14 m half
## landing, past `scale`'s 4 m shared-landing reach; see the GN-C1 report (lead / validator question).
func _build_grand_stair(parent: Node3D) -> void:
	var g: Dictionary = L.GRAND
	var gs: Node3D = add(parent, node3d("GrandStair")) as Node3D
	var nr: int = int(g["risers"])
	var r: float = float(g["riser"])
	var t: float = float(g["tread"])
	var cx: Array = g["central"]
	var hl: Array = g["half_landing"]
	var y_half: float = float(nr) * r
	var y_top: float = 2.0 * y_half
	flight(gs, "Central", Vector3((float(cx[0]) + float(cx[1])) * 0.5, 0.0, float(g["z_foot"])), 180.0,
		float(cx[1]) - float(cx[0]), nr, r, t, 0.0)
	box(gs, "HalfLanding", Vector3(float(hl[0]), y_half - 0.3, float(hl[1]) - 0.1), Vector3(float(hl[2]), y_half, float(hl[3])),
		"stair")
	var lz: Array = g["upper_landing_z"]
	var sides: Array = ["W", "E"]
	for k: int in range(2):
		var xs: Array = (g["returns"] as Array)[k]
		var x0: float = float(xs[0])
		var x1: float = float(xs[1])
		flight(gs, "Return" + String(sides[k]), Vector3((x0 + x1) * 0.5, y_half, float(g["z_land"])), 0.0, x1 - x0, nr, r, t,
			null)
		box(gs, "UpperLanding" + String(sides[k]), Vector3(x0, y_top - 0.3, float(lz[0])), Vector3(x1, y_top, float(lz[1])), "stair")
		railing(gs, "UpperLandingRailS" + String(sides[k]), Vector3(x0, y_top, float(lz[1]) - 0.05),
			Vector3(x1, y_top + 1.1, float(lz[1]) + 0.05))
		var xo: float = x1 if k == 0 else x0
		railing(gs, "UpperLandingRailIn" + String(sides[k]), Vector3(xo - 0.05, y_top, float(lz[0])),
			Vector3(xo + 0.05, y_top + 1.1, float(lz[1]) - 0.05))
	# The half landing's open south edge between the flights.
	var r0: Array = (g["returns"] as Array)[0]
	var r1: Array = (g["returns"] as Array)[1]
	for seg: Array in [[float(r0[1]), float(cx[0])], [float(cx[1]), float(r1[0])]]:
		railing(gs, "HalfLandingRail%d" % int(seg[0]), Vector3(float(seg[0]), y_half, float(hl[3]) - 0.1),
			Vector3(float(seg[1]), y_half + 1.1, float(hl[3])))
	# Stone balustrades, 1.1 m (vertical data), on both sides of every flight: sloped panels inside the flight width,
	# their top BAL_TOP above the nosing line (open side 1.0-1.1, lc_stair_rails), from one tread before the first
	# riser to the last riser. The return flights' outer panels clear the balcony balustrade (x 15 / 29 +- 0.05).
	var run: float = float(nr - 1) * t
	var zf: float = float(g["z_foot"])
	var zl: float = float(g["z_land"])
	for xs2: Array in [[float(cx[0]), float(cx[0]) + BAL_T], [float(cx[1]) - BAL_T, float(cx[1])]]:
		_balustrade(gs, "CentralBalustrade%d" % int(round(xs2[0] * 10.0)), xs2[0], xs2[1], Vector2(zf + t, BAL_TOP),
			Vector2(zf - run, y_half + BAL_TOP))
	var ret_x: Array = [
		[float(r0[0]) + 0.05, float(r0[0]) + 0.05 + BAL_T], [float(r0[1]) - BAL_T, float(r0[1])],
		[float(r1[0]), float(r1[0]) + BAL_T], [float(r1[1]) - 0.05 - BAL_T, float(r1[1]) - 0.05],
	]
	for xs3: Array in ret_x:
		_balustrade(gs, "ReturnBalustrade%d" % int(round(xs3[0] * 10.0)), xs3[0], xs3[1], Vector2(zl - t, y_half + BAL_TOP),
			Vector2(zl + run, y_top + BAL_TOP))
	# The half landing's open west / east ends (over the colonnade under the balconies), up to the return flights.
	railing(gs, "HalfLandingRailW", Vector3(float(r0[0]) + 0.05, y_half, float(hl[1])),
		Vector3(float(r0[0]) + 0.05 + 0.1, y_half + RAIL_H, zl - t))
	railing(gs, "HalfLandingRailE", Vector3(float(r1[1]) - 0.15, y_half, float(hl[1])),
		Vector3(float(r1[1]) - 0.05, y_half + RAIL_H, zl - t))


func _build_rails(parent: Node3D) -> void:
	for i: int in range(L.RAILS.size()):
		var rl: Array = L.RAILS[i]
		var fx: float = float(rl[2])
		var mn: Vector3 = Vector3(float(rl[3]), float(rl[5]), fx - 0.05) if String(rl[1]) == "x" \
			else Vector3(fx - 0.05, float(rl[5]), float(rl[3]))
		var mx: Vector3 = Vector3(float(rl[4]), float(rl[6]), fx + 0.05) if String(rl[1]) == "x" \
			else Vector3(fx + 0.05, float(rl[6]), float(rl[4]))
		railing(parent, "Balustrade%02d" % i, mn, mx)


## Handrail (5 cm bar, world a -> b) with collision and meta kind handrail (lc_stair_rails reads its box).
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
	col.shape = box_shape(size)
	add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = box_mesh(size, "trim")
	add(body, mi)


## Sloped stone balustrade over a flight: x0..x1 wide, its top edge from a to b ((z, y) pairs), its bottom edge
## BAL_TOP + BAL_BELOW below (vertical ends). Convex collision (true to the visual, next_heist §7.2) and a mesh.
func _balustrade(parent: Node3D, nm: String, x0: float, x1: float, a: Vector2, b: Vector2) -> void:
	var d: float = BAL_TOP + BAL_BELOW
	var c: Array[Vector3] = []
	for x: float in [x0, x1]:
		c.append_array([Vector3(x, a.y - d, a.x), Vector3(x, a.y, a.x), Vector3(x, b.y, b.x), Vector3(x, b.y - d, b.x)])
	_hexahedron(parent, nm, c, "trim")


## Static convex hexahedron from 8 corners (0-3 one face, 4-7 the opposite face, same order): collision + mesh.
func _hexahedron(parent: Node3D, nm: String, c: Array[Vector3], mat_id: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	add(parent, body)
	var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shp.points = PackedVector3Array(c)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shp
	add(body, col)
	var centre: Vector3 = Vector3.ZERO
	for p: Vector3 in c:
		centre += p / 8.0
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q: Array in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [3, 2, 6, 7], [1, 2, 6, 5], [0, 3, 7, 4]]:
		var p0: Vector3 = c[int(q[0])]
		var p1: Vector3 = c[int(q[1])]
		var p2: Vector3 = c[int(q[2])]
		var p3: Vector3 = c[int(q[3])]
		var nrm: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
		var fc: Vector3 = (p0 + p1 + p2 + p3) * 0.25
		if nrm.dot(fc - centre) > 0.0:   # Godot front faces wind clockwise seen from outside
			var tmp: Vector3 = p1
			p1 = p3
			p3 = tmp
			nrm = -nrm
		st.set_normal(-nrm)
		for v: Vector3 in [p0, p1, p2, p0, p2, p3]:
			st.add_vertex(v)
	st.set_material(lib_mat(mat_id))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	add(body, mi)
	return body


## Roof-deck parapet copings (B4.5 / next_heist §7.5: >= 50 deg, `slopes`): a 56 deg ridge on every deck parapet a
## player can reach (the north parapet either side of the fire-escape ladder opening, the 1.2 m wall by the
## sawtooth). The Great Hall roof parapets are police-only (P5) and keep their flat tops for G2.
func _build_copings(parent: Node3D) -> void:
	for w: Array in L.WALLS:
		if String(w[0]) != "R" or float(w[7]) > float(L.FFL["R"]) + 1.3:
			continue
		var axis: String = String(w[1])
		var fixed: float = float(w[2])
		var cuts: Array = [[float(w[3]), float(w[4])]]
		for u: Array in L.WALLS:   # under a taller upper-floor wall on the same line (the deck's south edge): no top
			if String(u[0]) == "U" and String(u[1]) == axis and absf(float(u[2]) - fixed) < 0.001 and float(u[7]) > float(w[7]):
				var rest: Array = []
				for sp0: Array in cuts:
					if float(u[3]) > float(sp0[0]):
						rest.append([float(sp0[0]), minf(float(sp0[1]), float(u[3]))])
					if float(u[4]) < float(sp0[1]):
						rest.append([maxf(float(sp0[0]), float(u[4])), float(sp0[1])])
				cuts = rest
		for o: Array in L.OPENINGS:
			if String(o[0]) == "R" and String(o[2]) == axis and absf(float(o[3]) - fixed) < 0.001:
				var nxt: Array = []
				for sp: Array in cuts:
					if float(o[4]) > float(sp[0]) and float(o[5]) < float(sp[1]):
						nxt.append([float(sp[0]), float(o[4])])
						nxt.append([float(o[5]), float(sp[1])])
					else:
						nxt.append(sp)
				cuts = nxt
		for sp2: Array in cuts:
			if float(sp2[1]) - float(sp2[0]) < 0.01:
				continue
			_coping(parent, "Coping%s%04d_%04d" % [axis.to_upper(), int(round(fixed * 10.0)), int(round(float(sp2[0]) * 10.0))],
				axis, fixed, float(sp2[0]), float(sp2[1]), float(w[7]), float(w[5]))


func _coping(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, y: float, thick: float) -> void:
	var h: float = thick * 0.5
	var c: Array[Vector3] = []
	for a: float in [a0, a1]:
		for q: Vector2 in [Vector2(-h, 0.0), Vector2(-0.001, COPING_RISE), Vector2(0.001, COPING_RISE), Vector2(h, 0.0)]:
			c.append(Vector3(a, y + q.y, fixed + q.x) if axis == "x" else Vector3(fixed + q.x, y + q.y, a))
	_hexahedron(parent, nm, c, "trim")


## Grade around the building: the Parade (+ portico, + its east end to the barriers), the Mews and Wexley St, the
## Sculpture Court (open over the areaway light well); the police street islands behind the closures; the play-space
## closures and neighbour massing (Site table: barriers + the gala coach, the press van, the catering truck, the Mews
## gate, the Mews houses, the hotel, the Ostrander, the court walls and gate gap, the park railings). TODO(G1): kerbs,
## the portico ramp, the pool, the court gate leaf (padlock prefab), facades / vistas (G2).
func _build_site(geo: Node3D) -> void:
	var site: Node3D = add(geo, node3d("Site")) as Node3D
	var mats: Dictionary = {"X1": "asphalt", "X2": "paving", "X3": "court_stone"}
	var k: int = 0
	for e: Array in L.EXTERIOR:
		_slab(site, "Grade%s_%d" % [e[0], k], e[2], L.SITE_HOLES.get(String(e[0]), []), -0.3, 0.0, String(mats[String(e[0])]))
		k += 1
	for g: Array in L.GRADE_EXTRA:
		var q: Array = g[2]
		box(site, "Grade" + String(g[0]), Vector3(float(q[0]), -0.3, float(q[1])), Vector3(float(q[2]), 0.0, float(q[3])),
			String(g[1]), SLAB_TILE)
	for p: Array in L.POLICE_ISLANDS:
		var r: Array = p[1]
		box(site, "PoliceIsland" + String(p[0]), Vector3(float(r[0]), -0.3, float(r[1])), Vector3(float(r[2]), 0.0, float(r[3])),
			"asphalt", SLAB_TILE)
	_build_pool(add(site, node3d("Pool")) as Node3D)
	var cl: Node3D = add(site, node3d("Closures")) as Node3D
	for c: Array in L.CLOSURES:
		var b: Array = c[1]
		box(cl, String(c[0]), Vector3(float(b[0]), float(b[1]), float(b[2])), Vector3(float(b[3]), float(b[4]), float(b[5])),
			String(c[2]))


## Reflecting pool (B4.4): a stone rim 0.3 m high (a step in and out, heavy bag included) around a basin whose floor
## is the court grade; a still water sheet at POOL_WATER_Y (library night water, visual only) and the bullet-only water
## surface collider (SurfaceTags.water_surface: shots splash, nothing else collides).
func _build_pool(pool: Node3D) -> void:
	var x0: float = float(POOL[0])
	var z0: float = float(POOL[1])
	var x1: float = float(POOL[2])
	var z1: float = float(POOL[3])
	var w: float = POOL_RIM_W
	box(pool, "RimN", Vector3(x0, 0.0, z0), Vector3(x1, POOL_RIM_H, z0 + w), "court_stone")
	box(pool, "RimS", Vector3(x0, 0.0, z1 - w), Vector3(x1, POOL_RIM_H, z1), "court_stone")
	box(pool, "RimW", Vector3(x0, 0.0, z0 + w), Vector3(x0 + w, POOL_RIM_H, z1 - w), "court_stone")
	box(pool, "RimE", Vector3(x1 - w, 0.0, z0 + w), Vector3(x1, POOL_RIM_H, z1 - w), "court_stone")
	var mn: Vector3 = Vector3(x0 + w, 0.0, z0 + w)
	var mx: Vector3 = Vector3(x1 - w, POOL_WATER_Y, z1 - w)
	var sheet: MeshInstance3D = MeshInstance3D.new()
	sheet.name = "Water"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(mx.x - mn.x, mx.z - mn.z)
	sheet.mesh = pm
	sheet.material_override = load(WATER_MAT) as Material
	sheet.position = Vector3((mn.x + mx.x) * 0.5, POOL_WATER_Y, (mn.z + mx.z) * 0.5)
	add(pool, sheet)
	SurfaceTags.water_surface(pool, map_root, "PoolWaterSurface", mn, mx)


## Areaway (QC-64, B2 / B4.6): the 2 x 2 m light well under the court grate and the passage to the 1.0 m opening in
## the basement wall into PL: floor at the PL FFL, retaining walls up to grade, the court grade roofs the passage.
## The fixed ladder (ENV A `ladder` prefab, 4.2 m, masked only, no bags) stands against the well's west wall:
## Gameplay/Ladders/AreawayLadder. The grate is the `areaway` slot's content (lift 3 s / padlock).
func _build_areaway(parent: Node3D) -> void:
	var a: Dictionary = L.AREAWAY
	var p: Array = a["pit"]
	var t: float = float(a["wall_t"])
	var y0: float = float(a["floor_y"])
	var x0: float = float(p[0])
	var z0: float = float(p[1])
	var x1: float = float(p[2])
	var z1: float = float(p[3])
	box(parent, "Floor", Vector3(x0 - t, y0 - L.SLAB_T, z0 - t), Vector3(x1, y0, z1 + t), "floor")
	box(parent, "WallN", Vector3(x0 - t, y0, z0 - t), Vector3(x1, -0.3, z0), "wall")
	box(parent, "WallS", Vector3(x0 - t, y0, z1), Vector3(x1, -0.3, z1 + t), "wall")
	box(parent, "WallW", Vector3(x0 - t, y0, z0), Vector3(x0, -0.3, z1), "wall")


# --- Rooms, zones, spawns, preplan, review cameras --------------------------------------------

func _build_rooms(rooms: Node3D) -> void:
	var done: Dictionary = {}
	for r: Array in L.ROOMS:
		var f: String = String(r[0])
		var rid: String = String(r[1])
		if done.has(rid):
			continue
		done[rid] = true
		var boxes: Array = []
		var ffl: float = float(L.FFL[f])
		for r2: Array in L.ROOMS:   # every rect of this id on this floor (X4 is two)
			if String(r2[1]) == rid and String(r2[0]) == f:
				var y1: float = ffl + float(r2[7]) if float(r2[7]) > 0.0 else ffl + 3.0
				if rid in ["SS", "LF"]:
					y1 = float(L.FFL["R"])   # the shafts are one room from the basement to the roof deck
				boxes.append([r2[3], ffl, r2[4], r2[5], y1, r2[6]])
		if rid == "GH":
			var v: Array = (L.VOIDS[0] as Array)[2]
			boxes.append([v[0], float(L.FFL["U"]), v[1], v[2], ffl + float(r[7]), v[3]])
		_room(rooms, rid, String(r[2]), String(r[8]), int(FLOOR_INDEX[f]), boxes)
	for e: Array in L.EXTERIOR:
		if done.has(String(e[0])):
			continue
		done[String(e[0])] = true
		var xb: Array = []
		for e2: Array in L.EXTERIOR:
			if String(e2[0]) == String(e[0]):
				var q: Array = e2[2]
				xb.append([q[0], 0.0, q[1], q[2], 6.0, q[3]])
		_room(rooms, String(e[0]), String(e[1]), String(e[3]), 1, xb)


func _room(rooms: Node3D, uid: String, purpose: String, kit: String, fidx: int, boxes: Array) -> void:
	var rv: RoomVolume = RoomVolume.new()
	rv.name = "Room" + uid
	rv.room_id = StringName(uid)
	rv.purpose = StringName(purpose)
	rv.dressing_kit = StringName(kit)
	rv.floor_index = fidx
	rv.collision_layer = 1 << 9
	rv.collision_mask = 0
	rv.monitoring = false
	add(rooms, rv)
	area_boxes(rv, boxes)


## PUBLIC: the gala rooms, the Parade and the court (until last call; the mission flips them, QC-51) and the
## Mews; RESTRICTED: every other building room and the roof deck.
func _build_zones(zones: Node3D) -> void:
	var pub: Array = []
	var res: Array = []
	for r: Array in L.ROOMS:
		var f: String = String(r[0])
		var y0: float = float(L.FFL[f])
		var y1: float = y0 + (float(r[7]) if float(r[7]) > 0.0 else 3.0)
		var b: Array = [r[3], y0, r[4], r[5], y1, r[6]]
		if L.PUBLIC_ROOMS.has(String(r[1])):
			pub.append(b)
		else:
			res.append(b)
	for e: Array in L.EXTERIOR:
		var q: Array = e[2]
		pub.append([q[0], -0.3, q[1], q[2], 4.0, q[3]])
	zone(zones, "Public", "PUBLIC", "gala_public", pub)
	zone(zones, "Restricted", "RESTRICTED", "halberd_restricted", res)


func _build_spawns(spawns: Node3D) -> void:
	for p: Array in L.PLAYER_SPAWNS:
		var tags: Array = [] if String(p[1]) == "" else [String(p[1])]
		spawn(spawns, String(p[0]), "PLAYER", Vector3(float(p[4]), float(p[5]), float(p[6])), float(p[7]), tags, "")
	for c: Array in L.POLICE_SPAWNS:
		var pos: Vector3 = Vector3(float(c[2]), float(c[3]), float(c[4]))
		var yaw: float = rad_to_deg(atan2(pos.x - 22.0, pos.z - 15.0))   # -Z faces the building centre
		var sp: SpawnPoint = spawn(spawns, String(c[0]), "POLICE", pos, yaw, [String(c[1])], "")
		# Every police spawn sits on a police-only navmesh island (P1-P4 behind the street closures, P5 on the Great
		# Hall roof) joined to play by one-way links only (D-064 / QC-41): validated spawn -> crew.
		sp.set_meta(&"police_only", true)


## Always-present nav links (D-064 / QC-41): the street islands' one-way links through their closures, P5's rappel
## through the oculus and the roof drop onto the deck, and the areaway (nav layer `vent`, Phantom only).
func _build_nav_links(nav: NavigationRegion3D) -> void:
	var rows: Array = []
	for p: Array in L.POLICE_ISLANDS:
		rows.append(["IslandLink" + String(p[0]), p[2], p[3], false, 1])
	rows.append_array(L.NAV_LINKS)
	for l: Array in rows:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = String(l[0])
		var s: Array = l[1]
		var e: Array = l[2]
		link.start_position = Vector3(float(s[0]), float(s[1]), float(s[2]))
		link.end_position = Vector3(float(e[0]), float(e[1]), float(e[2]))
		link.bidirectional = bool(l[3])
		link.navigation_layers = int(l[4])
		add(nav, link)


## PREPLAN_POINT markers (preplanning.md): node name = point id; metas category / label / floor / params.
func _build_preplan(pre: Node3D) -> void:
	for p: Array in L.PREPLAN:
		var m: Marker3D = Marker3D.new()
		m.name = String(p[0])
		m.position = Vector3(float(p[5]), float(p[6]), float(p[7]))
		m.set_meta(&"category", StringName(String(p[1])))
		m.set_meta(&"label", StringName("ui.preplan.point.gallery_night." + String(p[0])))
		m.set_meta(&"floor", int(p[2]))
		var params: Dictionary = {}
		for k: String in (p[8] as Dictionary):
			params[k] = StringName(String(p[8][k]))
		m.set_meta(&"params", params)
		m.add_to_group(G.PREPLAN_POINT, true)
		add(pre, m)


func _build_review_cameras(cams: Node3D) -> void:
	var paths: Array[NodePath] = []
	for c: Array in L.REVIEW_CAMERAS:
		var m: Marker3D = Marker3D.new()
		var nm: String = String(c[0])
		m.name = nm
		var pos: Vector3 = Vector3(float(c[3]), float(c[4]), float(c[5]))
		var target: Vector3 = Vector3(float(c[6]), float(c[7]), float(c[8]))
		m.position = pos
		var dir: Vector3 = target - pos
		var up: Vector3 = Vector3.FORWARD if absf(dir.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
		m.basis = Basis.looking_at(dir, up)
		if nm == "rc_top_down":
			m.set_meta(&"size", 110.0)
		else:
			m.set_meta(&"fov", 70.0)
		m.set_meta(&"caption", "%s (%s)" % [nm, String(c[2])])
		add(cams, m)
		paths.append(NodePath("ReviewCameras/" + nm))
	map_root.review_cameras = paths


# --- Environment ------------------------------------------------------------------------------

## Night, no sun, no moon (a shadowless directional would light every interior through the roofs): a dark procedural
## sky behind the facades, a cool moonlit ambient so unlit floor / corners and the exterior read at night instead of
## black (the key lights carry the rest), AgX tonemap. No fog (the city is clear; the portico looks into the hall),
## no SSAO / SSIL (the Compatibility renderer ignores them). Same pattern as Night Deposit's _build_lighting.
func _build_environment(lighting: Node3D) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load("res://world/lighting/heist_world_environment.gd"))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_gallery_night"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.06)
	sky_mat.sky_horizon_color = Color(0.13, 0.13, 0.16)
	sky_mat.ground_bottom_color = Color(0.01, 0.015, 0.02)
	sky_mat.ground_horizon_color = Color(0.1, 0.1, 0.12)
	sky_mat.sky_energy_multiplier = 0.6
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.42, 0.55)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.fog_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.1
	we.environment = env
	add(lighting, we)


# --- Navigation bake --------------------------------------------------------------------------

## Bakes the walkable navmesh (heist_map.md §3: agent radius 0.3, height 1.8, climb 0.3, slope 40, cell 0.1 / 0.1)
## from the Geometry colliders, minus the projected obstructions (the BARRED doorways and the LD roller, D-073:
## gn_gameplay._close_barred). Doorways are open in the bake (door prefabs live under Gameplay). TODO(G1): prop
## obstructions, ladder links.
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
