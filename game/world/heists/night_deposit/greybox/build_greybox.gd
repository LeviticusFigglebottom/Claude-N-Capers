## Night Deposit generator (G1 greybox C2, G2 art + dressing). Owner: ENV C.
## Regenerate (deterministic; never hand-edit the outputs):
##   /opt/godot/godot --headless --path game --script res://world/heists/night_deposit/greybox/build_greybox.gd
## then re-bake the interior GI under xvfb (bake_gi.gd header). Reads night_deposit_layout.gd and
## night_deposit_dressing.gd and writes, under res://world/heists/night_deposit/:
##   night_deposit.tscn (HeistMap, navmesh baked and embedded), night_deposit_def.tres,
##   night_deposit_variants.tres, art/*.tscn (generated prefab visuals). Contracts: docs/contracts/
##   heist_map.md v1.2, gameplay_prefabs.md v1.3, preplanning.md. Design: docs/design/heists/
##   night_deposit.md (APPROVED, D-040).
## Gameplay prefabs are instanced (never edited) and located through their contract class names,
## so this file holds no path into another environment's folder. They are added while the map is
## out of the tree, so their runtime _ready() never runs here.
extends "res://world/heists/night_deposit/greybox/nd_gameplay.gd"

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
const GI_PATH: String = OUT_DIR + "night_deposit_voxelgi.res"
const AM: GDScript = preload("res://world/heists/shared/assault_markers.gd")  # PO6-17 AssaultEvents markers
## PO-8: collision-only boxes whose visuals are drawn elsewhere (panes, cage mesh, ceiling finish,
## palisades, the quay steps, the harbour bed under the water) -> bullet surface id.
const SURFACE_GROUPS: Array = [
	["Geometry/Building/Glazing", &"glass"], ["Geometry/Building/VaultCage", &"metal"],
	["Geometry/Building/Areaway", &"metal"], ["Geometry/Building/Ceilings", &"plaster"],
	["Geometry/Building/ExteriorWalls/SallyRollerShutter", &"metal"], ["Geometry/Site/Closures", &"metal"],
	["Geometry/Site/Ground/QuaySteps", &"concrete"], ["Geometry/Site/Ground/Seabed", &"water"],
]

## Far-shore light positions (_far_shore_lights), reflected as glints on the harbour water (PO-13).
var far_glints: PackedVector3Array = PackedVector3Array()


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
	art = A.new()
	art.setup()
	var vis_err: String = DR.make_visuals(art, R, _visual_specs())
	if vis_err != "":
		_fail(vis_err)
		return
	var old_scene_uid: String = R.read_uid(SCENE_PATH)
	var def: HeistDef = R.make_def()
	var table: HeistVariantTable = R.make_variants()
	var err: int = ResourceSaver.save(def, DEF_PATH)
	err = maxi(err, ResourceSaver.save(table, VARIANTS_PATH))
	if err != OK:
		_fail("cannot save def/variants (%d)" % err)
		return
	map_root = HeistMap.new()
	map_root.name = "NightDeposit"
	map_root.heist_def = load(DEF_PATH) as HeistDef
	map_root.variant_table = load(VARIANTS_PATH) as HeistVariantTable
	map_root.floor_heights = PackedFloat32Array(L.FLOOR_HEIGHTS)
	dress = DR.new()
	dress.setup(self, map_root)
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
	_build_props(n("Props"))
	_build_lighting(n("Lighting"))
	_build_rooms(n("Rooms"))
	_build_zones(n("Zones"))
	_build_patrols(n("Patrols"))
	_build_spawns(n("Spawns"))
	_build_tactical(n("Tactical"))
	_build_preplan(n("Preplan"))
	_build_review_cameras(n("ReviewCameras"))
	build_gameplay(n("Gameplay"))
	build_variants(n("Variants"))
	# PO6-17 markers (layout ASSAULT_*); the intact breach infills / roof curbs obstruct the bake
	errors.append_array(AM.build(map_root, L.ASSAULT_TURRET_VANS, L.ASSAULT_HELI_ORBITS, L.ASSAULT_HELI_DROPS, [],
		L.ASSAULT_BREACHES, obstructions))
	_build_nav_links(nav)
	dress.dress(n("Props"))
	dress.site_dressing(add(n("Geometry"), node3d("SiteDressing")) as Node3D)
	dress.fill_lights(add(n("Lighting"), node3d("Fill")) as Node3D)
	for line: String in dress.report:
		printerr("dress: " + line)
		if line.begins_with("ERROR"):
			errors.append(line)
	_build_art()
	_tune_street_light(n("Props"))
	art.water_glints(n("Props"), far_glints)
	_close_barred_doorways()
	var polys: int = await _bake(nav)
	if polys <= 0:
		_fail("navmesh bake produced no polygons")
		return
	for g: Array in SURFACE_GROUPS:
		SurfaceTags.tag_untagged(map_root, NodePath(String(g[0])), g[1])
	for untagged: String in SurfaceTags.tag_tree(map_root):  # PO-8 bullet surface ids
		errors.append("no surface id for %s" % untagged)
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
	R.strip_nested_overrides(_scene_out())
	R.normalize_scene(_scene_out(), old_scene_uid)
	print("night_deposit: saved %s (navmesh polygons: %d)" % [_scene_out(), polys])
	quit(0)


func _fail(msg: String) -> void:
	push_error("night_deposit: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


## Generated prefab visuals (nd_dress.make_visuals): the cash lift car, the boat's deck hatch, the
## antechamber laser grids per pattern (posts + `Beam<i>`), an empty scene.
func _visual_specs() -> Dictionary:
	var lift_parts: Array = [[Vector3(1.2, 0.05, 1.14), Vector3(0.0, -0.025, 0.0), "brushed_steel"],
		[Vector3(1.2, 1.2, 0.04), Vector3(0.0, 0.6, 0.55), "brushed_steel"],
		[Vector3(0.04, 1.2, 1.1), Vector3(-0.58, 0.6, 0.0), "brushed_steel"],
		[Vector3(0.04, 1.2, 1.1), Vector3(0.58, 0.6, 0.0), "brushed_steel"],
		[Vector3(1.2, 0.04, 0.04), Vector3(0.0, 1.18, -0.55), "brushed_steel"],
		[Vector3(1.0, 0.012, 0.9), Vector3(0.0, 0.006, 0.0), "rubber_black"]]
	var specs: Dictionary = {
		VIS_EMPTY: {"name": "NdEmpty", "nodes": []},
		VIS_CASH_LIFT: {"name": "NdCashLift", "nodes": [
			["Car", "", Vector3.ZERO, []], ["CarMesh", "Car", Vector3.ZERO, lift_parts],
			["DoorL", "Car", Vector3(-0.3, 0.6, -0.55), []], ["DoorR", "Car", Vector3(0.3, 0.6, -0.55), []],
			["Panel", "", Vector3(0.0, 1.45, -0.715), []]]},
		VIS_BOAT_HATCH: {"name": "NdBoatHatch", "nodes": [
			["Body", "", Vector3.ZERO, [[Vector3(1.4, 0.1, 1.0), Vector3(0.0, 0.05, 0.0), "wood_veneer_walnut"],
				[Vector3(1.5, 0.02, 1.1), Vector3(0.0, 0.11, 0.0), "brushed_steel"]]],
			["DoorL", "", Vector3(-0.35, 0.12, 0.0), []], ["DoorR", "", Vector3(0.35, 0.12, 0.0), []],
			["DropAnchor", "", Vector3(0.0, 0.12, 0.0), []]]},
	}
	# [pattern, width, height, beams, sweeping, z offset, base plate h, base plate w, post w]: the three
	# variant grids share a spot, so each sits 90 mm apart in z.
	# Offsets go south (+z, into B8) so nothing enters the vault gate's swing; post and plate sizes
	# differ by 1 cm so faces of overlapping variants never coincide.
	for r: Array in [["laser_static", 8.85, 2.0, 4, false, 0.0, 0.03, 0.14, 0.08],
			["laser_timed", 9.8, 2.0, 4, false, 0.09, 0.036, 0.13, 0.07],
			["laser_sweep", 9.8, 2.2, 2, true, 0.18, 0.042, 0.12, 0.06]]:
		var w: float = float(r[1])
		var h: float = float(r[2])
		var dz: float = float(r[5])
		var ph: float = float(r[6])
		var pw: float = float(r[7])
		var sw: float = float(r[8])
		var nodes: Array = [["Emitters", "", Vector3(0.0, 0.0, dz), [
			[Vector3(sw, h, sw), Vector3(-w * 0.5 + 0.04, h * 0.5, 0.0), "metal_dark"],
			[Vector3(sw, h, sw), Vector3(w * 0.5 - 0.04, h * 0.5, 0.0), "metal_dark"],
			[Vector3(pw, ph, pw), Vector3(-w * 0.5 + 0.07, ph * 0.5, 0.0), "metal_dark"],
			[Vector3(pw, ph, pw), Vector3(w * 0.5 - 0.07, ph * 0.5, 0.0), "metal_dark"]]]]
		if bool(r[4]):
			nodes[0][3].append([Vector3(w - 0.16, 0.04, 0.06), Vector3(0.0, h - 0.02, 0.0), "metal_dark"])
		for i: int in range(int(r[3])):
			var parts: Array = [[Vector3(0.012, h - 0.1, 0.012), Vector3.ZERO, "laser_red"]] if bool(r[4]) \
				else [[Vector3(w - 0.16, 0.012, 0.012), Vector3.ZERO, "laser_red"]]
			var pos: Vector3 = Vector3(-w * 0.25 + w * 0.5 * float(i), h * 0.5, 0.0) if bool(r[4]) \
				else Vector3(0.0, h * (float(i) + 0.5) / float(r[3]), 0.0)
			# the grid moves `Beam<i>` on the beam line (z 0) at runtime: the bar is a child offset by dz
			nodes.append(["Beam%d" % i, "", pos, []])
			nodes.append(["Bar", "Beam%d" % i, Vector3(0.0, 0.0, dz), parts])
		specs[VIS_LASER[String(r[0])]] = {"name": "NdLaser" + String(r[0]).capitalize().replace(" ", ""), "nodes": nodes}
	return specs


# --- Building shell ---------------------------------------------------------------------------

func _build_shell(geo: Node3D) -> void:
	var bld: Node3D = add(geo, node3d("Building")) as Node3D
	var walls: Node3D = add(bld, node3d("ExteriorWalls")) as Node3D
	var q: float = L.EXT_T * 0.25
	var h: float = L.EXT_T * 0.5
	vis_group = "Shell"
	for w: Array in L.EXT_WALLS:
		var fixed: float = float(w[2])
		var out_sign: float = float(w[9])
		var yr: Vector2 = Vector2(float(w[7]), float(w[8]))
		wall(walls, String(w[0]) + "Out", String(w[1]), fixed + out_sign * q, float(w[3]), float(w[4]), h, yr,
			w[10], "wall_ext")
		wall(walls, String(w[0]) + "In", String(w[1]), fixed - out_sign * q, float(w[5]), float(w[6]), h, yr,
			(w[10] as Array) + _junction_cuts(String(w[1]), fixed, yr), "wall")
	# The closed sally roller shutter (3.0 m) inside its opening: slats + guide rails + the hood box.
	box(walls, "SallyRollerShutter", Vector3(2.0, 0.0, -0.06), Vector3(5.0, 2.8, 0.06), "")
	_roller_shutter()
	vis_group = "Interior"
	var iw: Node3D = add(bld, node3d("InteriorWalls")) as Node3D
	for w2: Array in L.INT_WALLS:
		var t: float = float(w2[8]) if w2.size() > 8 else L.INT_T
		var yr2: Vector2 = Vector2(float(w2[5]), float(w2[6]))
		wall(iw, String(w2[0]), String(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), t, yr2,
			(w2[7] as Array) + _junction_cuts(String(w2[1]), float(w2[2]), yr2), "wall")
	var slabs: Node3D = add(bld, node3d("Slabs")) as Node3D
	for s: Array in L.SLABS:
		for p: Array in AM.cut(String(s[0]), s[1], L.ASSAULT_BREACHES):  # PO6-17 ceiling breach holes
			box_a(slabs, String(p[0]), p[1], String(s[2]))
	var ceil_n: Node3D = add(bld, node3d("Ceilings")) as Node3D
	for c: Array in L.CEILINGS:
		for p2: Array in AM.cut(String(c[0]), c[1], L.ASSAULT_BREACHES):
			box_a(ceil_n, String(p2[0]), p2[1], "none")
	_build_stair(bld)
	var rails: Node3D = add(bld, node3d("Railings")) as Node3D
	for r: Array in L.RAILINGS:
		railing(rails, String(r[0]), v3(r[1], 0), v3(r[1], 3))
	vis_group = "Shell"
	_build_glazing(bld)
	_build_hide_line()
	vis_group = "Interior"
	_build_lift_shaft(bld)
	vis_group = "Shell"
	_build_areaway(bld)
	vis_group = "Interior"
	_build_vault_cage(bld)


## Sally roller shutter (visual): horizontal steel slats on the opening, guide rails, the coil hood.
## Zero-width "openings" (no hole) that split a wall line where a perpendicular wall meets it, so each
## wall box faces a single room and takes that room's finish (a face's material follows its centre).
func _junction_cuts(axis: String, fixed: float, yr: Vector2) -> Array:
	var out: Array = []
	var rows: Array = []
	for w: Array in L.EXT_WALLS:
		rows.append([String(w[1]), float(w[2]), minf(float(w[3]), float(w[5])), maxf(float(w[4]), float(w[6])), float(w[7]),
			float(w[8])])
	for w2: Array in L.INT_WALLS:
		rows.append([String(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), float(w2[5]), float(w2[6])])
	for r: Array in rows:
		if String(r[0]) == axis or minf(float(r[5]), yr.y) - maxf(float(r[4]), yr.x) < 0.1:
			continue
		var touches: bool = absf(float(r[2]) - fixed) < 0.35 or absf(float(r[3]) - fixed) < 0.35 \
			or (float(r[2]) < fixed and float(r[3]) > fixed)
		if touches:
			out.append([float(r[1]), float(r[1]), -100.0, -100.0])
	return out


func _roller_shutter() -> void:
	var y: float = 0.0
	while y < 2.79:
		art.acc.box("Shell", Vector3(2.0, y, -0.05), Vector3(5.0, minf(y + 0.095, 2.8), 0.05), func(f: int, _n: Vector3, _c: Vector3) -> String:
			return "" if f == 2 or f == 3 else "metal_painted")
		art.acc.box("Shell", Vector3(2.02, y + 0.093, -0.055), Vector3(4.98, minf(y + 0.1, 2.8), 0.055), "metal_dark")
		y += 0.1
	for x: Vector2 in [Vector2(1.9, 2.0), Vector2(5.0, 5.1)]:
		art.acc.box("Shell", Vector3(x.x, 0.0, -0.32), Vector3(x.y, 2.8, -0.2), "metal_dark")
	art.acc.box("Shell", Vector3(1.85, 2.8, -0.55), Vector3(5.15, 3.2, -0.2), "metal_dark")


## Railing: full-panel collision (blocks players and the navmesh) with a ridged top (RT: nobody stands
## on a rail, D-104 slopes) + top rail, mid rail and posts (brushed steel indoors; the quay chain
## railing: dark posts and two chains).
func railing(parent: Node3D, nm: String, mn: Vector3, mx: Vector3) -> void:
	var body: Node3D = box(parent, nm, mn, mx, "")
	body.set_meta(&"kind", "railing")
	RT.apply(body)
	var size: Vector3 = mx - mn
	var along_x: bool = size.x >= size.z
	var length: float = size.x if along_x else size.z
	var t: float = minf(size.x, size.z)
	var quay: bool = nm.begins_with("RailQuay")
	var key: String = "metal_dark" if quay else "brushed_steel"
	var parts: Array = []
	for ry: float in ([size.y * 0.5 - 0.03, size.y * 0.5 - 0.45] if quay else [size.y * 0.5 - 0.025, 0.0]):
		var thick: float = 0.03 if quay else 0.05
		parts.append([Vector3(length, thick, t) if along_x else Vector3(t, thick, length), Vector3(0.0, ry, 0.0), key])
	var spacing: float = 2.0 if quay else 1.2
	var posts: int = mini(maxi(2, int(ceil(length / spacing)) + 1), 40)
	for i: int in range(posts):
		var off: float = -length * 0.5 + 0.03 + (length - 0.06) * float(i) / float(posts - 1)
		var ps: Vector3 = Vector3(0.06, size.y - 0.002, t) if quay else Vector3(0.05, size.y - 0.052, t - 0.004)
		parts.append([ps, (Vector3(off, -0.001, 0.0) if along_x else Vector3(0.0, -0.001, off)), key])
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Rails"
	mi.mesh = art.local_box_mesh(parts)
	add(body, mi)


## U-stair G2 (layout STAIR): two straight flights (`stairs` nodes, steps along local Z) and the half
## landing. Each flight's steps are a visual mesh under the flight node; its collision is a smooth ramp
## through the nosings (convex prisms), which the validator accepts as an enveloping ramp.
func _build_stair(bld: Node3D) -> void:
	var st: Dictionary = L.STAIR
	var r: float = float(st["riser"])
	var tr: float = float(st["tread"])
	var nr: int = int(st["risers_per_flight"])
	var lz: Array = st["landing_z"]
	var z_land: float = float(lz[1])
	var z_top: float = z_land + float(nr - 1) * tr
	var y_land: float = float(st["landing_y"])
	var b14_z: float = float(st["b14_z"])
	var ramp_t: float = float(st["ramp_t"])
	var core: Node3D = add(bld, node3d("Stair")) as Node3D
	var lx: Array = st["landing_x"]
	vis_group = "Interior"
	box(core, "HalfLanding", Vector3(float(lx[0]), L.BASE, float(lz[0])), Vector3(float(lx[1]), y_land, z_land), "stair")
	var dx: Array = st["divider_x"]
	box(core, "DividerB", Vector3(float(dx[0]), L.BASE, z_land), Vector3(float(dx[1]), 0.0, z_top), "wall")
	box(core, "DividerG", Vector3(float(dx[0]), 0.0, z_land), Vector3(float(dx[1]), 1.05, z_top), "wall")
	# Flight 1: down from the ground floor (z_top, 0.0) north to the landing (z_land, -2.0).
	var f1: Node3D = add(core, node3d("Flight1")) as Node3D
	f1.set_meta(&"kind", "stairs")
	var x1: Array = st["f1_x"]
	var xa: float = float(x1[0])
	var xb: float = float(x1[1])
	vis_group = "Flight1"
	for k: int in range(1, nr):
		var top: float = -float(k) * r
		var zl: float = z_top - float(k) * tr
		var zh: float = z_top - float(k - 1) * tr + SEAM
		if zh <= b14_z:
			_step_box(Vector3(xa, L.BASE, zl), Vector3(xb, top, zh))
		elif zl >= b14_z:
			_step_box(Vector3(xa, L.BASE_CEIL, zl), Vector3(xb, top, zh))
		else:
			_step_box(Vector3(xa, L.BASE, zl), Vector3(xb, top, b14_z))
			_step_box(Vector3(xa, L.BASE_CEIL, b14_z), Vector3(xb, top, zh))
	art.acc.flush(f1, map_root, {}, ["Flight1"])
	var ramp1: Callable = func(z: float) -> float: return -(z_top - z) / tr * r
	_ramp(f1, xa, xb, [
		[Vector2(z_land - tr, L.BASE), Vector2(b14_z, L.BASE), Vector2(b14_z, ramp1.call(b14_z)), Vector2(z_land - tr, y_land)],
		[Vector2(b14_z, ramp1.call(b14_z)), Vector2(z_top, 0.0), Vector2(z_top, -ramp_t),
			Vector2(b14_z, ramp1.call(b14_z) - ramp_t)],
	])
	# Flight 2: down from the landing (z_land, -2.0) south to the basement (z_top, -4.0).
	var f2: Node3D = add(core, node3d("Flight2")) as Node3D
	f2.set_meta(&"kind", "stairs")
	var x2: Array = st["f2_x"]
	vis_group = "Flight2"
	for j: int in range(1, nr):
		var top2: float = y_land - float(j) * r
		var za: float = z_land + float(j - 1) * tr - SEAM
		var zb: float = z_land + float(j) * tr
		_step_box(Vector3(float(x2[0]), L.BASE, za), Vector3(float(x2[1]), top2, zb))
	art.acc.flush(f2, map_root, {}, ["Flight2"])
	vis_group = "Interior"
	_ramp(f2, float(x2[0]), float(x2[1]), [
		[Vector2(z_land, y_land), Vector2(z_top + tr, L.BASE), Vector2(z_land, L.BASE)],
	])
	# Handrails on both walls of each flight, following the nosing line from the top nosing to the
	# bottom one (Flight1: (z_top, 0) -> (z_land, -10 r); Flight2: (z_land, -2) -> (z_top, -2 - 10 r)).
	# Under `Stair/Handrails`, not the flights, so the flight boxes stay the steps.
	var hr: Node3D = add(core, node3d("Handrails")) as Node3D
	var n1: Vector2 = Vector2(z_top, 0.0)
	var n1b: Vector2 = Vector2(z_land, -float(nr - 1) * r)
	var n2: Vector2 = Vector2(z_land, y_land)
	var n2b: Vector2 = Vector2(z_top, y_land - float(nr - 1) * r)
	_handrail(hr, "Flight1West", xa, 1.0, n1, n1b)
	_handrail(hr, "Flight1East", xb, -1.0, n1, n1b)
	_handrail(hr, "Flight2West", float(x2[0]), 1.0, n2, n2b)
	_handrail(hr, "Flight2East", float(x2[1]), -1.0, n2, n2b)


## One stair step block (visual): its sides lie on the core walls / divider and its base on the
## basement floor or on B14's ceiling (which draws the soffit), so only treads and risers are drawn.
func _step_box(mn: Vector3, mx: Vector3) -> void:
	art.acc.box(vis_group, mn, mx, func(f: int, n: Vector3, c: Vector3) -> String:
		if f == 0 or f == 1 or f == 2:
			return ""
		return art.face_key("stair", f, n, c))


## Wall handrail: a round bar `rail_h` above the nosing line between nosings a and b ((z, y) pairs),
## `rail_off` out from the wall face at x `x_wall` (`inward` = +1 / -1 towards the flight), three
## brackets and a return to the wall at each end. Only the bar carries meta kind = handrail (its own
## tilted transform, so the validator's box is the bar). No collision: it never blocks the stair.
func _handrail(parent: Node3D, nm: String, x_wall: float, inward: float, a: Vector2, b: Vector2) -> void:
	var st: Dictionary = L.STAIR
	var h: float = float(st["rail_h"])
	var off: float = float(st["rail_off"])
	var rad: float = float(st["rail_r"])
	var x: float = x_wall + inward * off
	var pa: Vector3 = Vector3(x, a.y + h, a.x)
	var pb: Vector3 = Vector3(x, b.y + h, b.x)
	var rail: Node3D = add(parent, node3d(nm)) as Node3D
	var bar: MeshInstance3D = MeshInstance3D.new()
	bar.name = "Bar"
	var ln: float = pa.distance_to(pb)
	bar.mesh = art.local_rod_mesh(rad, ln, "brushed_steel")
	var up: Vector3 = (pb - pa).normalized()
	bar.transform = Transform3D(Basis(Vector3.RIGHT, up, Vector3.RIGHT.cross(up)), (pa + pb) * 0.5 - up * ln * 0.5)
	bar.set_meta(&"kind", "handrail")
	add(rail, bar)
	for e: Array in [["ReturnA", pa], ["ReturnB", pb]]:
		var ret: MeshInstance3D = MeshInstance3D.new()
		ret.name = String(e[0])
		ret.mesh = art.local_rod_mesh(rad, off, "brushed_steel")
		var p: Vector3 = e[1]
		# rod along local +Y turned to run along -inward X from the bar back to the wall
		ret.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0 * inward)), Vector3(x, p.y, p.z))
		add(rail, ret)
	for i: int in range(3):
		var f: float = 0.2 + 0.3 * float(i)
		var q: Vector3 = pa.lerp(pb, f)
		mesh_box(Vector3(minf(x_wall, x), q.y - rad - 0.05, q.z - 0.015), Vector3(maxf(x_wall, x), q.y - rad + 0.005, q.z + 0.015),
			"handrail")


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


## Static glazing: glass blocker (collision) + pane + a frame round the opening (head, sill, jambs).
## The ATM vestibule's street glass is green (landmark 3); the bandit glass gets brass mullions over
## the counter joints.
## D-142 / D-128: the counter's hidden line for levelcheck hide_los (Gameplay/Lines/HideCounter, Marker3D chain).
func _build_hide_line() -> void:
	var lines: Node3D = add(n("Gameplay"), node3d("Lines")) as Node3D
	var root: Node3D = add(lines, node3d("HideCounter")) as Node3D
	root.set_meta(&"hide_spot", true)
	root.set_meta(&"hide_from", PackedStringArray(["G9"]))
	root.set_meta(&"hide_posture", "crouch")
	for i: int in range(L.HIDE_COUNTER.size()):
		var m: Marker3D = Marker3D.new()
		m.name = "P%02d" % i
		m.position = L.HIDE_COUNTER[i]
		add(root, m)


func _build_glazing(bld: Node3D) -> void:
	var gl: Node3D = add(bld, node3d("Glazing")) as Node3D
	for g: Array in L.GLAZING:
		var along_x: bool = String(g[1]) == "x"
		var f: float = float(g[2])
		var a0: float = float(g[3])
		var a1: float = float(g[4])
		var y0: float = float(g[5])
		var y1: float = float(g[6])
		var mn: Vector3 = Vector3(a0, y0, f - 0.01) if along_x else Vector3(f - 0.01, y0, a0)
		var mx: Vector3 = Vector3(a1, y1, f + 0.01) if along_x else Vector3(f + 0.01, y1, a1)
		var nm: String = String(g[0])
		var glass_key: String = "glass_green" if nm.begins_with("Atm") else "glass"
		# collision is the full opening; the pane is inset 4 mm so its edges sit inside the frame bars
		box(gl, nm, mn, mx, "").add_to_group(&"see_through", true)  # D-142: clear glazing; stealth vision sees through it
		var ins: Vector3 = Vector3(0.004, 0.004, 0.0) if along_x else Vector3(0.0, 0.004, 0.004)
		art.vis_box(vis_group, mn + ins, mx - ins, glass_key)
		var frame_key: String = "brass" if nm == "BanditGlass" else ("ironwork" if nm.begins_with("Atm") else "frame")
		var fw: float = 0.05
		var fd: float = 0.08
		# head and sill run full width; jambs and mullions fit between them (no overlapping faces)
		var bars: Array = [[a0, a1, y1 - fw, y1], [a0, a1, y0, y0 + fw], [a0, a0 + fw, y0 + fw, y1 - fw],
			[a1 - fw, a1, y0 + fw, y1 - fw]]
		if nm == "BanditGlass":
			# D-142: the solid brass deal-tray rail under the glass (its own opaque body, on the counter's marble top)
			var rmn: Vector3 = Vector3(a0, L.BANDIT_RAIL_Y, f - fd * 0.5)
			var rmx: Vector3 = Vector3(a1, y0, f + fd * 0.5)
			box(gl, "BanditRail", rmn, rmx, "")
			art.vis_box(vis_group, rmn, rmx, "brass")
			bars = [[a0, a1, y1 - fw, y1], [a0, a0 + fw, y0, y1 - fw], [a1 - fw, a1, y0, y1 - fw]]
			for k: int in range(1, 6):
				var xm: float = a0 + (a1 - a0) * float(k) / 6.0
				bars.append([xm - 0.025, xm + 0.025, y0, y1 - fw])
		for bb: Array in bars:
			var lo: Vector3 = Vector3(float(bb[0]), float(bb[2]), f - fd * 0.5) if along_x else Vector3(f - fd * 0.5, float(bb[2]), float(bb[0]))
			var hi: Vector3 = Vector3(float(bb[1]), float(bb[3]), f + fd * 0.5) if along_x else Vector3(f + fd * 0.5, float(bb[3]), float(bb[1]))
			art.vis_box(vis_group, lo, hi, frame_key)


## Cash lift shaft (bags only) G1 <-> B1: closed shaft walls, the west wall with the bag hatch on each
## floor. The bag_lift prefab (Gameplay/Misc/CashLift, QC-11) runs the car; its visual carries the G1
## call panel anchor, the call panels themselves are dressed here on the shaft wall above each hatch.
func _build_lift_shaft(bld: Node3D) -> void:
	var lf: Node3D = add(bld, node3d("CashLiftShaft")) as Node3D
	var b: Array = L.LIFT["box"]
	var x0: float = float(b[0])
	var z0: float = float(b[1])
	var x1: float = float(b[2])
	var z1: float = float(b[3])
	var hz: Array = L.LIFT["hatch_z"]
	var hy: Array = L.LIFT["hatch_y"]
	# One box per storey (the per-floor plan render cuts every wall).
	for st: Array in [["B", L.BASE, L.BASE_CEIL], ["G", 0.0, L.WING_CEIL]]:
		var y0: float = float(st[1])
		var y1: float = float(st[2])
		box(lf, "ShaftN" + String(st[0]), Vector3(x0, y0, z0 - 0.05), Vector3(x1, y1, z0 + 0.05), "shaft")
		box(lf, "ShaftS" + String(st[0]), Vector3(x0, y0, z1 - 0.05), Vector3(x1, y1, z1 + 0.05), "shaft")
		wall(lf, "ShaftW" + String(st[0]), "z", x0, z0 + 0.05, z1 - 0.05, 0.1, Vector2(y0, y1),
			[[float(hz[0]), float(hz[1]), y0 + float(hy[0]), y0 + float(hy[1])]], "shaft")
		# steel hatch frame round each bag hatch (room side)
		var hy0: float = y0 + float(hy[0])
		var hy1: float = y0 + float(hy[1])
		for fr: Array in [[float(hz[0]) - 0.05, float(hz[0]), hy0 - 0.05, hy1 + 0.05],
				[float(hz[1]), float(hz[1]) + 0.05, hy0 - 0.05, hy1 + 0.05],
				[float(hz[0]), float(hz[1]), hy1, hy1 + 0.05], [float(hz[0]), float(hz[1]), hy0 - 0.05, hy0]]:
			mesh_box(Vector3(x0 - 0.08, float(fr[2]), float(fr[0])), Vector3(x0 - 0.05, float(fr[3]), float(fr[1])), "steel")
	var car: Vector3 = L.LIFT["car"]
	var py: float = float(L.LIFT["panel_y"])
	for pl: Array in [["CallPanelGround", car.y + py], ["CallPanelBasement", car.y + L.BASE + py]]:
		var y: float = float(pl[1])
		mesh_box(Vector3(x0 - 0.08, y - 0.07, car.z - 0.11), Vector3(x0 - 0.05, y + 0.07, car.z + 0.11), "steel")
		# The closed shaft is no floor for NPCs (the car floor at G1, the pit at B1).
		obstruct(Transform3D.IDENTITY, AABB(Vector3(x0 + 0.05, y - py - 0.05, z0 + 0.05),
			Vector3(x1 - x0 - 0.05, 1.3, z1 - z0 - 0.1)))


## Areaway (vent route): pit walls, ledge, a steel bar cage with the grate on top. The gate (door
## prefab) and the ladder are gameplay prefabs (variant `vent_open`; Gameplay/Misc/AreawayLadder).
## The cage collision stays solid panels; its visual is bars.
func _build_areaway(bld: Node3D) -> void:
	var aw: Node3D = add(bld, node3d("Areaway")) as Node3D
	var a: Dictionary = L.AREAWAY
	box_a(aw, "Ledge", a["ledge"], "concrete")
	var pit: Array = a["pit"]
	box(aw, "PitNorth", Vector3(16.9, -4.3, -2.6), Vector3(19.0, 0.0, float(pit[2])), "concrete")
	box(aw, "PitEast", Vector3(float(pit[3]), -4.3, float(pit[2])), Vector3(19.0, 0.0, -0.2), "concrete")
	var ch: float = float(a["cage_h"])
	var gz: float = (a["gate_pos"] as Vector3).z
	wall(aw, "CageWest", "z", 16.95, -2.6, -0.2, 0.1, Vector2(0.0, ch), [[gz - 0.5, gz + 0.5, 0.0, 2.2]], "")
	box(aw, "CageNorth", Vector3(17.0, 0.0, -2.6), Vector3(19.0, ch, -2.5), "")
	box(aw, "CageEast", Vector3(18.9, 0.0, -2.5), Vector3(19.0, ch, -0.2), "")
	box(aw, "CageGrate", Vector3(16.9, ch, -2.6), Vector3(19.0, ch + 0.05, -0.2), "")
	_bars("z", 16.95, -2.6, gz - 0.55, 0.0, ch, "ironwork")
	# bar panels stop 1 cm short of the plinth band (front at z -0.25) on the north wall
	_bars("z", 16.95, gz + 0.55, -0.26, 0.0, ch, "ironwork")
	_bars("x", -2.55, 17.0, 19.0, 0.0, ch, "ironwork")
	_bars("z", 18.95, -2.5, -0.26, 0.0, ch, "ironwork")
	# grate on top: flat bars both ways
	var x: float = 16.95
	while x < 19.0:
		art.vis_box(vis_group, Vector3(x, ch, -2.6), Vector3(x + 0.03, ch + 0.05, -0.2), "ironwork")
		x += 0.15
	for zz: float in [-2.6, -1.4, -0.23]:
		art.vis_box(vis_group, Vector3(16.9, ch + 0.004, zz), Vector3(19.0, ch + 0.046, zz + 0.03), "ironwork")


## A bar panel (visual) on a line: posts at the ends, top + bottom rails and round-ish bars every 0.12 m.
func _bars(axis: String, fixed: float, a0: float, a1: float, y0: float, y1: float, key: String) -> void:
	var t: float = 0.03
	var lo_a: float = minf(a0, a1)
	var hi_a: float = maxf(a0, a1)
	for e: Array in [[lo_a, lo_a + 0.05], [hi_a - 0.05, hi_a]]:
		art.vis_box(vis_group, _bar_lo(axis, fixed, float(e[0]), y0, 0.05), _bar_hi(axis, fixed, float(e[1]), y1, 0.05), key)
	for ry: Vector2 in [Vector2(y0 + 0.08, y0 + 0.12), Vector2(y1 - 0.06, y1 - 0.02)]:
		art.vis_box(vis_group, _bar_lo(axis, fixed, lo_a + 0.05, ry.x, 0.04), _bar_hi(axis, fixed, hi_a - 0.05, ry.y, 0.04), key)
	var a: float = lo_a + 0.12
	while a < hi_a - 0.08:
		art.vis_box(vis_group, _bar_lo(axis, fixed, a - t * 0.5, y0, t), _bar_hi(axis, fixed, a + t * 0.5, y1 - 0.02, t), key)
		a += 0.12


func _bar_lo(axis: String, fixed: float, a: float, y: float, d: float) -> Vector3:
	return Vector3(a, y, fixed - d * 0.5) if axis == "x" else Vector3(fixed - d * 0.5, y, a)


func _bar_hi(axis: String, fixed: float, a: float, y: float, d: float) -> Vector3:
	return Vector3(a, y, fixed + d * 0.5) if axis == "x" else Vector3(fixed + d * 0.5, y, a)


## Vault B9 cash cage: steel bar enclosure x 12-16, z 13.5-16.5 (2.4 m), open gate on the north side.
## Collision panels as before; the visual is bars.
func _build_vault_cage(bld: Node3D) -> void:
	var vc: Node3D = add(bld, node3d("VaultCage")) as Node3D
	var y0: float = L.BASE
	var y1: float = L.BASE + 2.4
	wall(vc, "CageN", "x", 13.5, 12.0, 16.0, 0.06, Vector2(y0, y1), [[13.5, 14.5, y0, y1]], "")
	box(vc, "CageS", Vector3(12.0, y0, 16.47), Vector3(16.0, y1, 16.53), "")
	box(vc, "CageW", Vector3(11.97, y0, 13.53), Vector3(12.03, y1, 16.47), "")
	box(vc, "CageE", Vector3(15.97, y0, 13.53), Vector3(16.03, y1, 16.47), "")
	_bars("x", 13.5, 12.0, 13.5, y0, y1, "steel")
	_bars("x", 13.5, 14.5, 16.0, y0, y1, "steel")
	_bars("x", 16.5, 12.0, 16.0, y0, y1, "steel")
	_bars("z", 12.0, 13.53, 16.47, y0, y1, "steel")
	_bars("z", 16.0, 13.53, 16.47, y0, y1, "steel")


# --- Site -------------------------------------------------------------------------------------

func _build_site(geo: Node3D) -> void:
	var site: Node3D = add(geo, node3d("Site")) as Node3D
	var ground: Node3D = add(site, node3d("Ground")) as Node3D
	vis_group = "Street"
	for g: Array in L.GROUND:
		box_a(ground, String(g[0]), g[1], String(g[2]))
	_quay_steps(ground)
	var water: Array = L.WATER
	box_a(site, "HarborWater", water, "", false)
	SurfaceTags.water_surface(site, map_root, "HarborWaterSurface", v3(water, 0), v3(water, 3))  # PO-8 bullets
	art.acc.quad("Water", "water", Vector3(float(water[0]), float(water[4]), float(water[2])),
		Vector3(float(water[3]), float(water[4]), float(water[2])), Vector3(float(water[3]), float(water[4]), float(water[5])),
		Vector3(float(water[0]), float(water[4]), float(water[5])), Vector3.UP)
	var blocks: Node3D = add(site, node3d("Blocks")) as Node3D
	vis_group = "Neighbours"
	for b: Array in L.BLOCKS:
		var mat: String = String(b[2])
		var blk: Node3D = box_a(blocks, String(b[0]), b[1], mat)
		if mat == "glass":
			blk.add_to_group(&"see_through", true)  # D-142: the clear hall skylight
		if mat == "barrier":
			RT.apply(blk)  # road / police barriers: a ridged top, not a perch over the closure (D-104)
	_far_shore_lights()
	vis_group = "Street"
	var fences: Node3D = add(site, node3d("Closures")) as Node3D
	for f: Array in L.FENCES:
		wall(fences, String(f[0]), String(f[1]), float(f[2]), float(f[3]), float(f[4]), 0.1,
			Vector2(float(f[5]), float(f[6])), f[7], "")
		_palisade(String(f[1]), float(f[2]), float(f[3]), float(f[4]), float(f[5]), float(f[6]), f[7])
	# Seabed (collision only) must not grow a navmesh island under the water.
	var sb: Array = []
	for g2: Array in L.GROUND:
		if String(g2[0]) == "Seabed":
			sb = g2[1]
	if not sb.is_empty():
		obstruct(Transform3D.IDENTITY, AABB(v3(sb, 0) + Vector3(0.0, -0.5, 0.0), v3(sb, 3) - v3(sb, 0) + Vector3(0.0, 2.0, 0.0)))


## Steel palisade (visual) along a closure fence: posts every 2.4 m, two rails, pales every 0.15 m
## with the gate openings left to the gate prefabs.
func _palisade(axis: String, fixed: float, a0: float, a1: float, y0: float, y1: float, openings: Array) -> void:
	var cuts: Array[Vector2] = [Vector2(a0, a1)]
	for o: Array in openings:
		cuts = A._subtract(cuts, Vector2(float(o[0]) - 0.05, float(o[1]) + 0.05))
	for run: Vector2 in cuts:
		if run.y - run.x < 0.2:
			continue
		var a: float = run.x
		while a <= run.y + 0.001:
			var pa: float = clampf(a, run.x, run.y - 0.08)
			art.vis_box("Street", _bar_lo(axis, fixed, pa, y0, 0.08), _bar_hi(axis, fixed, pa + 0.08, y1, 0.08), "fence_post")
			a += 2.4
		for ry: Vector2 in [Vector2(y0 + 0.25, y0 + 0.31), Vector2(y1 - 0.35, y1 - 0.29)]:
			art.vis_box("Street", _bar_lo(axis, fixed - 0.03, run.x + 0.01, ry.x, 0.03), _bar_hi(axis, fixed - 0.03, run.y - 0.01, ry.y, 0.03),
				"fence")
		var p: float = run.x + 0.1
		while p < run.y - 0.06:
			art.vis_box("Street", _bar_lo(axis, fixed + 0.01, p - 0.02, y0, 0.02), _bar_hi(axis, fixed + 0.01, p + 0.02, y1 - 0.04, 0.02),
				"fence")
			p += 0.15


## Quay steps: visual treads + one smooth walkable ramp (slope 33.7 deg) for the collision.
func _quay_steps(parent: Node3D) -> void:
	var qs: Dictionary = L.QUAY_STEPS
	var xs: Array = qs["x"]
	var zt: float = float(qs["z_top"])
	var zb: float = float(qs["z_bot"])
	var yt: float = float(qs["y_top"])
	var yb: float = float(qs["y_bot"])
	var n_r: int = int(qs["risers"])
	var steps: Node3D = add(parent, node3d("QuaySteps")) as Node3D
	var run: float = (zb - zt) / float(n_r - 1)
	var rise: float = (yt - yb) / float(n_r)
	for k: int in range(1, n_r):
		var top: float = yt - float(k) * rise
		var z0: float = zt + float(k - 1) * run - SEAM
		mesh_box(Vector3(float(xs[0]), -2.4, z0), Vector3(float(xs[1]), top, z0 + run + SEAM), "quay")
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = 1
	body.collision_mask = 0
	add(steps, body)
	var pts: PackedVector3Array = PackedVector3Array()
	for p: Vector2 in [Vector2(zt, yt), Vector2(zb, yb), Vector2(zb, -2.4), Vector2(zt, -2.4)]:
		pts.append(Vector3(float(xs[0]), p.y, p.x))
		pts.append(Vector3(float(xs[1]), p.y, p.x))
	var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shp.points = pts
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shp
	add(body, col)


## Far-shore lights in the fog (emissive dressing, 300 m out).
## The far-shore light boxes double as reflected glints on the harbour water (nd_art.water_glints).
func _far_shore_lights() -> void:
	for i: int in range(12):
		var x: float = -150.0 + 32.0 * float(i)
		var y: float = 2.0 + float((i * 7) % 5)
		art.vis_box("Neighbours", Vector3(x, y, 299.0), Vector3(x + 1.5, y + 0.6, 299.5), "far_lights")
		far_glints.append(Vector3(x + 0.75, y + 0.3, 299.0))


# --- Props ------------------------------------------------------------------------------------

## Map-built props (the WC partition); everything else is catalog dressing (nd_dress.gd).
func _build_props(props: Node3D) -> void:
	var b: Node3D = add(props, node3d("MapBuilt")) as Node3D
	for p: Array in L.PROPS:
		prop_box(b, String(p[0]), p[1], p[2], float(p[3]), String(p[4]), bool(p[5]), String(p[6]))


# --- Art pass (G2): finishes, trim, facade, neighbours, markings, landmarks, probes ---------------

func _build_art() -> void:
	art.room_surfaces()
	art.hall_coffers()
	art.facade()
	art.site_markings()
	var cp: Dictionary = L.COMPASS
	art.compass(cp["pos"], float(cp["radius"]))
	art.neighbours(L.BLOCKS.filter(func(b: Array) -> bool:
		return not (String(b[2]) in ["boat_hidden", "container_hidden", "van_hidden", "trim", "glass", "crane", "container"])))
	var vis: Node3D = add(n("Geometry"), node3d("Visual")) as Node3D
	art.acc.flush(vis, map_root, {"Neighbours": {"distant": true}})
	var probes: Node3D = add(n("Lighting"), node3d("ReflectionProbes")) as Node3D
	art.reflection_probes(probes, map_root)
	var occ: Node3D = add(n("Geometry"), node3d("Occluders")) as Node3D
	art.occluders(occ, map_root, L.BLOCKS)
	var audio: Node3D = add(map_root, node3d("Audio")) as Node3D
	art.audio(audio, map_root)


# --- Lighting ---------------------------------------------------------------------------------

## Night, no sun: weak fog-diffused moon, sodium street light, fog bank (~120 m visibility). The
## interior VoxelGI is baked by bake_gi.gd.
func _build_lighting(lighting: Node3D) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load("res://world/lighting/heist_world_environment.gd"))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_night_deposit"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.05)
	sky_mat.sky_horizon_color = Color(0.14, 0.13, 0.13)
	sky_mat.ground_bottom_color = Color(0.01, 0.015, 0.02)
	sky_mat.ground_horizon_color = Color(0.1, 0.1, 0.11)
	sky_mat.sky_energy_multiplier = 0.6
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Cool moonlit ambient (D-086: blue/grey kits read at 20 m instead of brown-black under sodium).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.42, 0.55)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.31, 0.32)
	# Fog bank over the harbor (doc: view limited at ~120 m): thin overall, denser near the water.
	env.fog_density = 0.005
	env.fog_height = 1.0
	env.fog_height_density = 0.06
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.1
	we.environment = env
	add(lighting, we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.basis = Basis.looking_at(Vector3(0.4, -0.35, 0.85).normalized(), Vector3.UP)
	moon.position = Vector3(13.0, 30.0, 10.0)
	moon.light_color = Color(0.6, 0.7, 0.9)
	moon.light_energy = 0.22
	moon.shadow_enabled = false
	add(lighting, moon)
	_voxel_gi(lighting)
	var fx: Node3D = add(lighting, node3d("Fixtures")) as Node3D
	for c: Array in L.CEILING_LIGHTS:
		_ceiling_light(fx, String(c[0]), c[1], c[2], float(c[3]), float(c[4]))
	for w: Array in L.WALL_LIGHTS:
		_wall_light(fx, String(w[0]), w[1], float(w[2]), w[3], float(w[4]), float(w[5]), w[6])


## Interior VoxelGI over the building (data baked by bake_gi.gd under xvfb; see its header).
func _voxel_gi(lighting: Node3D) -> void:
	if not ResourceLoader.exists(GI_PATH):
		var empty: VoxelGIData = VoxelGIData.new()
		empty.interior = true
		ResourceSaver.save(empty, GI_PATH)
	var vg: VoxelGI = VoxelGI.new()
	vg.name = "VoxelGI"
	vg.position = Vector3(13.0, 1.5, 10.0)
	vg.size = Vector3(27.0, 11.8, 21.0)
	vg.subdiv = VoxelGI.SUBDIV_64
	vg.data = load(GI_PATH) as VoxelGIData
	add(lighting, vg)


## Ceiling-mounted fixture: pivot at the ceiling surface (top-centre), panel just below, light under it.
func _ceiling_light(parent: Node3D, nm: String, pivot: Vector3, color: Color, energy: float, rng: float) -> void:
	var r: Node3D = node3d(nm, pivot)
	r.set_meta(&"mount", "ceiling")
	r.set_meta(&"fixture", true)
	r.set_meta(&"kind", "light_fixture")
	add(parent, r)
	var size: Vector3 = Vector3(0.6, 0.05, 0.6)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Panel"
	mi.mesh = art.local_box_mesh([[size, Vector3.ZERO, "emit_cool" if color.b > color.r + 0.01 else "emit_warm"]])
	mi.position = Vector3(0.0, -size.y * 0.5 - 0.002, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(r, mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -size.y - 0.2, 0.0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	light.layers |= VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
	add(r, light)


## Wall-mounted fixture/sign: pivot on the wall face (back-centre), -Z out of the wall.
func _wall_light(parent: Node3D, nm: String, pivot: Vector3, yaw: float, color: Color, energy: float,
		rng: float, size: Vector3) -> void:
	var r: Node3D = node3d(nm, pivot)
	r.basis = yaw_basis(yaw)
	r.set_meta(&"mount", "wall")
	r.set_meta(&"fixture", true)
	r.set_meta(&"kind", "fascia_sign" if nm.contains("Fascia") else "light_fixture")
	add(parent, r)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Body"
	if nm.contains("Fascia"):
		mi.mesh = art.local_box_mesh([[size, Vector3.ZERO, "metal_slate"],
			[Vector3(size.x - 0.12, size.y - 0.12, 0.01), Vector3(0.0, 0.0, -size.z * 0.5 - 0.005), "emit_mint"]])
	else:
		mi.mesh = art.local_box_mesh([[size, Vector3.ZERO, "metal_dark"],
			[Vector3(size.x - 0.06, size.y - 0.08, 0.01), Vector3(0.0, -0.01, -size.z * 0.5 - 0.005), "emit_cool"]])
	mi.position = Vector3(0.0, 0.0, -size.z * 0.5 - 0.002)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(r, mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -0.1, -0.4)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	light.layers |= VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
	add(r, light)


# --- Rooms and zones --------------------------------------------------------------------------

func _build_rooms(rooms: Node3D) -> void:
	for r: Array in L.ROOMS:
		var rv: RoomVolume = RoomVolume.new()
		rv.name = "Room" + String(r[0])
		rv.room_id = StringName(String(r[0]))
		rv.purpose = StringName(String(r[1]))
		rv.dressing_kit = StringName(String(r[2]))
		rv.floor_index = int(r[3])
		rv.collision_layer = 1 << 9
		rv.collision_mask = 0
		rv.monitoring = false
		if r[5] != null:
			rv.set_meta(&"ceiling_range", r[5])
		add(rooms, rv)
		area_boxes(rv, r[4])


func _build_zones(zones: Node3D) -> void:
	for z: Array in L.ZONES:
		var mz: MapZone = zone(zones, String(z[0]), String(z[1]), String(z[2]), z[3])
		if String(z[0]) == "BodyHideJanitor":
			mz.set_meta(&"capacity", 1)
		if String(z[1]) == "OUT_OF_BOUNDS":
			mz.set_meta(&"respawn_tag", &"oob_respawn")
			mz.set_meta(&"alarm", false)


# --- Patrols, spawns, tactical ----------------------------------------------------------------

func _build_patrols(patrols: Node3D) -> void:
	_patrol_graph(patrols, "Bank", &"bank", L.PATROL_POINTS_BANK, L.PATROL_EDGES_BANK)
	_patrol_graph(patrols, "Exterior", &"exterior", L.PATROL_POINTS_EXTERIOR, L.PATROL_EDGES_EXTERIOR)
	_patrol_graph(patrols, "ArmoredCar", &"armored_car", L.PATROL_POINTS_ARMORED, L.PATROL_EDGES_ARMORED)
	_patrol_graph(patrols, "Rounds", &"rounds", L.PATROL_POINTS_ROUNDS, L.PATROL_EDGES_ROUNDS)


func _patrol_graph(parent: Node3D, nm: String, graph_id: StringName, points: Dictionary, edges: Array) -> void:
	var g: PatrolGraph = PatrolGraph.new()
	g.name = nm
	g.graph_id = graph_id
	g.floor_index = 1
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
		if row.size() > 5:
			p.weight = float(row[5])
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


func _build_nav_links(nav: NavigationRegion3D) -> void:
	# Areaway ladder: lot (outside the cage gate) <-> pit floor (ENV A ladder movement, A2-04).
	var link: NavigationLink3D = NavigationLink3D.new()
	link.name = "AreawayLadderLink"
	link.bidirectional = true
	# Ladder.NAV_LAYER ("ladder", climbers only): on layer 1 bag carriers, AI crew and police routed into
	# the ladder and stalled at its foot (freeze gate 2). The prefab adds its own identical link; this one
	# stays so the bake anchors the island beyond the ladder (and the generated scene keeps its layout).
	link.navigation_layers = 8  # = Ladder.NAV_LAYER (literal: --script builds have no autoloads)
	link.start_position = Vector3(16.3, 0.0, -1.4)
	link.end_position = Vector3(18.2, L.BASE, -0.9)
	add(nav, link)


# --- Navigation bake --------------------------------------------------------------------------

## Keeps only navmesh components that hold a gameplay marker (spawns, patrol points, UsePoints,
## nav-link ends): no islands on neighbour roofs, garage decks or the shop roof, which would let
## NPC queries snap there and make the bounds check cast from unreachable places.
func _prune_islands(nm: NavigationMesh) -> void:
	var anchors: PackedVector3Array = PackedVector3Array()
	for n: Node in map_root.find_children("*", "", true, false):
		if n is PatrolPoint or n is SpawnPoint or (n.name == &"UsePoint" and n is Node3D):
			anchors.append(global_xform(n as Node3D).origin)
		elif n is NavigationLink3D:
			anchors.append((n as NavigationLink3D).start_position)
			anchors.append((n as NavigationLink3D).end_position)
	var verts: PackedVector3Array = nm.get_vertices()
	var polys: Array[PackedInt32Array] = []
	for i: int in range(nm.get_polygon_count()):
		polys.append(nm.get_polygon(i))
	# Union-find over polygons sharing a vertex (by quantised position: tiles duplicate vertices).
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(polys.size())
	for i2: int in range(polys.size()):
		parent[i2] = i2
	var owner_of: Dictionary = {}
	for pi: int in range(polys.size()):
		for vi: int in polys[pi]:
			var v: Vector3 = verts[vi]
			var key: Vector3i = Vector3i(roundi(v.x * 20.0), roundi(v.y * 20.0), roundi(v.z * 20.0))
			if owner_of.has(key):
				_union(parent, pi, int(owner_of[key]))
			else:
				owner_of[key] = pi
	var keep_roots: Dictionary = {}
	for a: Vector3 in anchors:
		var best: int = -1
		var best_d: float = 1.5
		for pi2: int in range(polys.size()):
			var c: Vector3 = Vector3.ZERO
			var p2: PackedVector2Array = PackedVector2Array()
			for vi2: int in polys[pi2]:
				c += verts[vi2]
				p2.append(Vector2(verts[vi2].x, verts[vi2].z))
			c /= float(polys[pi2].size())
			var d: float = Vector2(c.x - a.x, c.z - a.z).length() + absf(c.y - a.y) * 2.0
			# An anchor inside a big polygon (police spawn island behind a closed gate) keeps it.
			d = 0.0 if Geometry2D.is_point_in_polygon(Vector2(a.x, a.z), p2) and absf(c.y - a.y) < 1.0 else d
			if d < best_d:
				best_d = d
				best = pi2
		if best >= 0:
			keep_roots[_find(parent, best)] = true
	var new_verts: PackedVector3Array = PackedVector3Array()
	var remap: Dictionary = {}
	var kept: Array[PackedInt32Array] = []
	for pi3: int in range(polys.size()):
		if not keep_roots.has(_find(parent, pi3)):
			continue
		var np: PackedInt32Array = PackedInt32Array()
		for vi3: int in polys[pi3]:
			if not remap.has(vi3):
				remap[vi3] = new_verts.size()
				new_verts.append(verts[vi3])
			np.append(int(remap[vi3]))
		kept.append(np)
	nm.clear_polygons()
	nm.set_vertices(new_verts)
	for np2: PackedInt32Array in kept:
		nm.add_polygon(np2)
	print("night_deposit: navmesh %d -> %d polygons after island pruning" % [polys.size(), kept.size()])


static func _find(parent: PackedInt32Array, i: int) -> int:
	var r: int = i
	while parent[r] != r:
		r = parent[r]
	return r


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _find(parent, a)
	var rb: int = _find(parent, b)
	if ra != rb:
		parent[maxi(ra, rb)] = mini(ra, rb)


## Bakes the walkable navmesh (heist_map.md §3: agent radius 0.3, height 1.8, climb 0.3, slope 40,
## cell 0.1 / 0.1) from the Geometry colliders. Props and prefab bodies are projected obstructions,
## so no navmesh is generated on top of furniture or vans. Doors stay open.
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
	# only the play space (site + quay + moored boats); the far shore and vista blocks stay out
	nm.filter_baking_aabb = AABB(Vector3(-60.0, -8.0, -45.0), Vector3(130.0, 40.0, 90.0))
	var holder: Node3D = Node3D.new()
	holder.name = "BakeSource"
	holder.add_child(map_root.get_node("Geometry").duplicate())
	get_root().add_child(holder)
	await physics_frame
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, holder)
	for o: Array in obstructions:
		src.add_projected_obstruction(o[0], float(o[1]), float(o[2]), false)
	preload("res://world/heists/shared/door_nav_clearance.gd").add(src, map_root, nm)  # door throats (ENV P ghost 250)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	_prune_islands(nm)
	holder.queue_free()
	await process_frame
	nav.navigation_mesh = nm
	return nm.get_polygon_count()


## D-086 (D's 20 m read): sodium street/wall lamps desaturated toward warm white and a bit brighter, so enemy
## kits keep their colours where they stand; the map stays dark (no new lights, small energy step).
func _tune_street_light(props: Node) -> void:
	for l: Node in props.find_children("*", "Light3D", true, false):
		var light: Light3D = l as Light3D
		var c: Color = light.light_color
		if c.r > 0.9 and c.b < 0.4:  # sodium orange
			light.light_color = Color(1.0, 0.8, 0.6)
			light.light_energy *= 1.2


## D-073 / D-085: BARRED police gates baked CLOSED; only the door's NavLink bridges them (as Glasshouse).
func _close_barred_doorways() -> void:
	for d: Array in L.DOORS.filter(func(r: Array) -> bool: return String(r[4]) == "BARRED"):
		var w: float = (1.8 if String(d[5]) == "DOUBLE" else 0.9) + 0.6  # leaf + jamb tolerance
		obstruct(Transform3D(yaw_basis(float(d[3])), d[2]), AABB(Vector3(-w * 0.5, -0.2, -0.3), Vector3(w, 2.8, 0.6)))
