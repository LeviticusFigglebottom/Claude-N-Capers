## Night Deposit G1 greybox generator. Owner: ENV C (C2).
## Regenerate (deterministic; never hand-edit the outputs):
##   /opt/godot/godot --headless --path game --script res://world/heists/night_deposit/greybox/build_greybox.gd
## Reads night_deposit_layout.gd and writes, under res://world/heists/night_deposit/:
##   night_deposit.tscn (HeistMap, navmesh baked and embedded), night_deposit_def.tres,
##   night_deposit_variants.tres. Contracts: docs/contracts/heist_map.md v1.2, gameplay_prefabs.md v1.1,
##   preplanning.md. Design: docs/design/heists/night_deposit.md (APPROVED, D-040).
## Gameplay prefabs are instanced (never edited) and located through their contract class names,
## so this file holds no path into another environment's folder. They are added while the map is
## out of the tree, so their runtime _ready() never runs here. Prefabs not on trunk yet
## (bag_lift, hack_terminal; QC-11/QC-12) get placeholders with the intended node names.
extends "res://world/heists/night_deposit/greybox/nd_gameplay.gd"


func _initialize() -> void:
	_build.call_deferred()


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
	map_root.name = "NightDeposit"
	map_root.heist_def = load(DEF_PATH) as HeistDef
	map_root.variant_table = load(VARIANTS_PATH) as HeistVariantTable
	map_root.floor_heights = PackedFloat32Array(L.FLOOR_HEIGHTS)
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
	_build_nav_links(nav)
	var polys: int = await _bake(nav)
	if polys <= 0:
		_fail("navmesh bake produced no polygons")
		return
	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	var ps: PackedScene = PackedScene.new()
	err = ps.pack(map_root)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE_PATH)
	map_root.free()
	if err != OK:
		_fail("cannot save %s (%d)" % [SCENE_PATH, err])
		return
	R.normalize_scene(SCENE_PATH, old_scene_uid)
	print("night_deposit: saved %s (navmesh polygons: %d)" % [SCENE_PATH, polys])
	quit(0)


func _fail(msg: String) -> void:
	push_error("night_deposit: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


# --- Building shell ---------------------------------------------------------------------------

func _build_shell(geo: Node3D) -> void:
	var bld: Node3D = add(geo, node3d("Building")) as Node3D
	var walls: Node3D = add(bld, node3d("ExteriorWalls")) as Node3D
	var q: float = L.EXT_T * 0.25
	var h: float = L.EXT_T * 0.5
	for w: Array in L.EXT_WALLS:
		var fixed: float = float(w[2])
		var out_sign: float = float(w[9])
		var yr: Vector2 = Vector2(float(w[7]), float(w[8]))
		wall(walls, String(w[0]) + "Out", String(w[1]), fixed + out_sign * q, float(w[3]), float(w[4]), h, yr,
			w[10], "wall_ext")
		wall(walls, String(w[0]) + "In", String(w[1]), fixed - out_sign * q, float(w[5]), float(w[6]), h, yr,
			w[10], "wall")
	# The closed sally roller shutter (3.0 m) inside its opening.
	box(walls, "SallyRollerShutter", Vector3(2.0, 0.0, -0.06), Vector3(5.0, 2.8, 0.06), "door")
	var iw: Node3D = add(bld, node3d("InteriorWalls")) as Node3D
	for w2: Array in L.INT_WALLS:
		var t: float = float(w2[8]) if w2.size() > 8 else L.INT_T
		wall(iw, String(w2[0]), String(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), t,
			Vector2(float(w2[5]), float(w2[6])), w2[7], "wall")
	var slabs: Node3D = add(bld, node3d("Slabs")) as Node3D
	for s: Array in L.SLABS:
		box_a(slabs, String(s[0]), s[1], String(s[2]))
	var ceil_n: Node3D = add(bld, node3d("Ceilings")) as Node3D
	for c: Array in L.CEILINGS:
		box_a(ceil_n, String(c[0]), c[1], "ceiling")
	_build_stair(bld)
	var rails: Node3D = add(bld, node3d("Railings")) as Node3D
	for r: Array in L.RAILINGS:
		railing(rails, String(r[0]), v3(r[1], 0), v3(r[1], 3))
	_build_glazing(bld)
	_build_lift_shaft(bld)
	_build_areaway(bld)
	_build_vault_cage(bld)
	_build_compass(bld)


## Railing: full-panel collision (blocks players and the navmesh) + top rail, mid rail and posts.
func railing(parent: Node3D, nm: String, mn: Vector3, mx: Vector3) -> void:
	var body: Node3D = box(parent, nm, mn, mx, "")
	body.set_meta(&"kind", "railing")
	var size: Vector3 = mx - mn
	var along_x: bool = size.x >= size.z
	var length: float = size.x if along_x else size.z
	var t: float = minf(size.x, size.z)
	for rail: Array in [["TopRail", size.y * 0.5 - 0.025], ["MidRail", 0.0]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = String(rail[0])
		mi.mesh = box_mesh(Vector3(length, 0.05, t) if along_x else Vector3(t, 0.05, length), "trim")
		mi.position = Vector3(0.0, float(rail[1]), 0.0)
		add(body, mi)
	var posts: int = mini(maxi(2, int(ceil(length / 1.2)) + 1), 40)
	for i: int in range(posts):
		var off: float = -length * 0.5 + 0.025 + (length - 0.05) * float(i) / float(posts - 1)
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "Post%d" % i
		post.mesh = box_mesh(Vector3(0.05, size.y, t), "trim")
		post.position = Vector3(off, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, off)
		add(body, post)


## U-stair G2 (layout STAIR): two straight flights (`stairs` nodes, steps along local Z) and the half
## landing. Each flight's steps are visual meshes; its collision is a smooth ramp through the nosings
## (convex prisms), which the validator accepts as an enveloping ramp (tools/levelcheck/README.md).
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
	for k: int in range(1, nr):
		var top: float = -float(k) * r
		var zl: float = z_top - float(k) * tr
		var zh: float = z_top - float(k - 1) * tr + SEAM
		if zh <= b14_z:
			mesh_box(f1, "Step%02d" % k, Vector3(xa, L.BASE, zl), Vector3(xb, top, zh), "stair")
		elif zl >= b14_z:
			mesh_box(f1, "Step%02d" % k, Vector3(xa, L.BASE_CEIL, zl), Vector3(xb, top, zh), "stair")
		else:
			mesh_box(f1, "Step%02dA" % k, Vector3(xa, L.BASE, zl), Vector3(xb, top, b14_z), "stair")
			mesh_box(f1, "Step%02dB" % k, Vector3(xa, L.BASE_CEIL, b14_z), Vector3(xb, top, zh), "stair")
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
	for j: int in range(1, nr):
		var top2: float = y_land - float(j) * r
		var za: float = z_land + float(j - 1) * tr - SEAM
		var zb: float = z_land + float(j) * tr
		mesh_box(f2, "Step%02d" % (nr + j), Vector3(float(x2[0]), L.BASE, za), Vector3(float(x2[1]), top2, zb), "stair")
	_ramp(f2, float(x2[0]), float(x2[1]), [
		[Vector2(z_land, y_land), Vector2(z_top + tr, L.BASE), Vector2(z_land, L.BASE)],
	])


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


## Static glazing: glass blocker (collision) + pane + head/sill frame bars.
func _build_glazing(bld: Node3D) -> void:
	var gl: Node3D = add(bld, node3d("Glazing")) as Node3D
	for g: Array in L.GLAZING:
		var along_x: bool = String(g[1]) == "x"
		var f: float = float(g[2])
		var a0: float = float(g[3])
		var a1: float = float(g[4])
		var y0: float = float(g[5])
		var y1: float = float(g[6])
		var mn: Vector3 = Vector3(a0, y0, f - 0.02) if along_x else Vector3(f - 0.02, y0, a0)
		var mx: Vector3 = Vector3(a1, y1, f + 0.02) if along_x else Vector3(f + 0.02, y1, a1)
		var body: Node3D = box(gl, String(g[0]), mn, mx, "glass")
		var span: float = a1 - a0
		var fs: Vector3 = Vector3(span, 0.05, 0.08) if along_x else Vector3(0.08, 0.05, span)
		var head: MeshInstance3D = MeshInstance3D.new()
		head.name = "FrameHead"
		head.mesh = box_mesh(fs, "frame")
		head.position = Vector3(0.0, (y1 - y0) * 0.5 - 0.025, 0.0)
		add(body, head)


## Cash lift shaft (bags only) G1 <-> B1: closed shaft walls, the west wall with the bag hatch on each
## floor. The bag_lift prefab (Gameplay/Misc/CashLift, QC-11) runs the car; its visual carries the G1
## call panel, the B1 panel (runtime LandingPanel1) is dressed here at the same offset.
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
		box(lf, "ShaftN" + String(st[0]), Vector3(x0, y0, z0 - 0.05), Vector3(x1, y1, z0 + 0.05), "trim")
		box(lf, "ShaftS" + String(st[0]), Vector3(x0, y0, z1 - 0.05), Vector3(x1, y1, z1 + 0.05), "trim")
		wall(lf, "ShaftW" + String(st[0]), "z", x0, z0 + 0.05, z1 - 0.05, 0.1, Vector2(y0, y1),
			[[float(hz[0]), float(hz[1]), y0 + float(hy[0]), y0 + float(hy[1])]], "trim")
	# Call/send panels on the shaft wall above each hatch (the bag_lift `Panel` is an empty anchor: a
	# panel mesh in the prefab visual would reach through the shaft wall).
	var car: Vector3 = L.LIFT["car"]
	var py: float = float(L.LIFT["panel_y"])
	for pl: Array in [["CallPanelGround", car.y + py], ["CallPanelBasement", car.y + L.BASE + py]]:
		var y: float = float(pl[1])
		mesh_box(lf, String(pl[0]), Vector3(x0 - 0.08, y - 0.07, car.z - 0.11), Vector3(x0 - 0.05, y + 0.07, car.z + 0.11),
			"frame")
		# The closed shaft is no floor for NPCs (the car floor at G1, the pit at B1).
		obstruct(Transform3D.IDENTITY, AABB(Vector3(x0 + 0.05, y - py - 0.05, z0 + 0.05),
			Vector3(x1 - x0 - 0.05, 1.3, z1 - z0 - 0.1)))


## Areaway (vent route): pit walls, ledge, caged top with a grate roof. The gate (door prefab) and the
## ladder are gameplay prefabs (variant `vent_open`; Gameplay/Misc/AreawayLadder).
func _build_areaway(bld: Node3D) -> void:
	var aw: Node3D = add(bld, node3d("Areaway")) as Node3D
	var a: Dictionary = L.AREAWAY
	box_a(aw, "Ledge", a["ledge"], "concrete")
	var pit: Array = a["pit"]
	box(aw, "PitNorth", Vector3(16.9, -4.3, -2.6), Vector3(19.0, 0.0, float(pit[2])), "concrete")
	box(aw, "PitEast", Vector3(float(pit[3]), -4.3, float(pit[2])), Vector3(19.0, 0.0, -0.2), "concrete")
	var ch: float = float(a["cage_h"])
	var gz: float = (a["gate_pos"] as Vector3).z
	wall(aw, "CageWest", "z", 16.95, -2.6, -0.2, 0.1, Vector2(0.0, ch), [[gz - 0.5, gz + 0.5, 0.0, 2.2]], "fence")
	box(aw, "CageNorth", Vector3(17.0, 0.0, -2.6), Vector3(19.0, ch, -2.5), "fence")
	box(aw, "CageEast", Vector3(18.9, 0.0, -2.5), Vector3(19.0, ch, -0.2), "fence")
	box(aw, "CageGrate", Vector3(16.9, ch, -2.6), Vector3(19.0, ch + 0.05, -0.2), "ironwork")


## Vault B9 cash cage: chain-link enclosure x 12-16, z 13.5-16.5 (2.4 m), open gate on the north side.
func _build_vault_cage(bld: Node3D) -> void:
	var vc: Node3D = add(bld, node3d("VaultCage")) as Node3D
	var y0: float = L.BASE
	var y1: float = L.BASE + 2.4
	wall(vc, "CageN", "x", 13.5, 12.0, 16.0, 0.06, Vector2(y0, y1), [[13.5, 14.5, y0, y1]], "fence")
	box(vc, "CageS", Vector3(12.0, y0, 16.47), Vector3(16.0, y1, 16.53), "fence")
	box(vc, "CageW", Vector3(11.97, y0, 13.53), Vector3(12.03, y1, 16.47), "fence")
	box(vc, "CageE", Vector3(15.97, y0, 13.53), Vector3(16.03, y1, 16.47), "fence")


## Landmark 2: mosaic compass rose inlaid in the hall floor (visual only: an up-facing disc and four
## arms 3-4 mm above the floor, single-sided so nothing reads as a cut solid in the plan render).
func _build_compass(bld: Node3D) -> void:
	var c: Dictionary = L.COMPASS
	var pos: Vector3 = c["pos"]
	var r: float = float(c["radius"])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var segs: int = 32
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		for v: Vector3 in [Vector3.ZERO, Vector3(cos(a0), 0.0, sin(a0)) * r, Vector3(cos(a1), 0.0, sin(a1)) * r]:
			st.set_uv(Vector2(v.x, v.z) / (2.0 * r) + Vector2(0.5, 0.5))
			st.add_vertex(v)
	st.set_material(lib_mat("compass"))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CompassRose"
	mi.mesh = st.commit()
	mi.position = pos + Vector3(0.0, 0.003, 0.0)
	add(bld, mi)
	for i2: int in range(4):
		var arm: MeshInstance3D = MeshInstance3D.new()
		arm.name = "CompassArm%d" % i2
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(0.18, r * 1.9)
		pm.material = lib_mat("ironwork")
		arm.mesh = pm
		arm.position = pos + Vector3(0.0, 0.004, 0.0)
		arm.basis = yaw_basis(45.0 * float(i2))
		add(bld, arm)


# --- Site -------------------------------------------------------------------------------------

func _build_site(geo: Node3D) -> void:
	var site: Node3D = add(geo, node3d("Site")) as Node3D
	var ground: Node3D = add(site, node3d("Ground")) as Node3D
	for g: Array in L.GROUND:
		box_a(ground, String(g[0]), g[1], String(g[2]))
	_quay_steps(ground)
	var water: Array = L.WATER
	box_a(site, "HarborWater", water, "water", false)
	var blocks: Node3D = add(site, node3d("Blocks")) as Node3D
	for b: Array in L.BLOCKS:
		var mat: String = String(b[2])
		box_a(blocks, String(b[0]), b[1], mat)
	_far_shore_lights(blocks)
	var fences: Node3D = add(site, node3d("Closures")) as Node3D
	for f: Array in L.FENCES:
		wall(fences, String(f[0]), String(f[1]), float(f[2]), float(f[3]), float(f[4]), 0.1,
			Vector2(float(f[5]), float(f[6])), f[7], String(f[8]))
	# Seabed (collision only) must not grow a navmesh island under the water.
	var sb: Array = []
	for g2: Array in L.GROUND:
		if String(g2[0]) == "Seabed":
			sb = g2[1]
	if not sb.is_empty():
		obstruct(Transform3D.IDENTITY, AABB(v3(sb, 0) + Vector3(0.0, -0.5, 0.0), v3(sb, 3) - v3(sb, 0) + Vector3(0.0, 2.0, 0.0)))


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
		mesh_box(steps, "Tread%d" % k, Vector3(float(xs[0]), -2.4, z0), Vector3(float(xs[1]), top, z0 + run + SEAM), "quay")
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
func _far_shore_lights(parent: Node3D) -> void:
	var fl: Node3D = add(parent, node3d("FarShoreLights")) as Node3D
	for i: int in range(12):
		var x: float = -150.0 + 32.0 * float(i)
		var y: float = 2.0 + float((i * 7) % 5)
		mesh_box(fl, "Light%02d" % i, Vector3(x, y, 299.0), Vector3(x + 1.5, y + 0.6, 299.5), "far_lights")


# --- Props ------------------------------------------------------------------------------------

func _build_props(props: Node3D) -> void:
	var g: Node3D = add(props, node3d("Ground")) as Node3D
	var b: Node3D = add(props, node3d("Basement")) as Node3D
	var x: Node3D = add(props, node3d("Exterior")) as Node3D
	for p: Array in L.PROPS:
		var base: Vector3 = p[1]
		var parent: Node3D = g
		if base.y < -2.0:
			parent = b
		elif base.y < -0.01 or base.z < -0.1 or base.z > 20.1 or base.x > 26.1:
			parent = x
		prop_box(parent, String(p[0]), base, p[2], float(p[3]), String(p[4]), bool(p[5]), String(p[6]))
	for c: Array in L.CHAIRS:
		var cp: Vector3 = c[1]
		chair(b if cp.y < -2.0 else g, String(c[0]), cp, float(c[2]))
	for sl: Array in L.STREET_LAMPS:
		_street_lamp(x, String(sl[0]), sl[1], float(sl[2]))


## Sodium street lamp (fixture head + OmniLight).
func _street_lamp(parent: Node3D, nm: String, base: Vector3, yaw: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = yaw_basis(yaw)
	body.set_meta(&"kind", "street_lamp")
	add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = box_shape(Vector3(0.18, 6.0, 0.18))
	col.position = Vector3(0.0, 3.0, 0.0)
	add(body, col)
	mesh_box(body, "Pole", Vector3(-0.09, 0.0, -0.09), Vector3(0.09, 6.0, 0.09), "trim")
	mesh_box(body, "Arm", Vector3(-0.05, 5.9, -0.8), Vector3(0.05, 6.0, 0.0), "trim")
	var head: MeshInstance3D = mesh_box(body, "Head", Vector3(-0.15, 5.78, -0.9), Vector3(0.15, 5.9, -0.3), "sodium")
	head.set_meta(&"fixture", true)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 5.6, -0.6)
	light.light_color = EMISSIVE_MATS["sodium"]
	light.light_energy = 1.8
	light.omni_range = 13.0
	add(body, light)
	obstruct(body.transform, AABB(Vector3(-0.09, 0.0, -0.09), Vector3(0.18, 6.0, 0.18)))


# --- Lighting ---------------------------------------------------------------------------------

## Night, no sun: weak fog-diffused moon, sodium street light, fog bank (~120 m visibility).
func _build_lighting(lighting: Node3D) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_night_deposit_greybox"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.05)
	sky_mat.sky_horizon_color = Color(0.12, 0.13, 0.14)
	sky_mat.ground_bottom_color = Color(0.01, 0.015, 0.02)
	sky_mat.ground_horizon_color = Color(0.1, 0.11, 0.12)
	sky_mat.sky_energy_multiplier = 0.6
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.34, 0.35)
	# Fog bank over the harbor (doc: view limited at ~120 m): thin overall, denser near the water.
	env.fog_density = 0.005
	env.fog_height = 2.0
	env.fog_height_density = 0.08
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.4
	we.environment = env
	add(lighting, we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.basis = Basis.looking_at(Vector3(0.4, -0.35, 0.85).normalized(), Vector3.UP)
	moon.position = Vector3(13.0, 30.0, 10.0)
	moon.light_color = Color(0.62, 0.7, 0.85)
	moon.light_energy = 0.12
	moon.shadow_enabled = false
	add(lighting, moon)
	var fx: Node3D = add(lighting, node3d("Fixtures")) as Node3D
	for c: Array in L.CEILING_LIGHTS:
		_ceiling_light(fx, String(c[0]), c[1], c[2], float(c[3]), float(c[4]))
	for w: Array in L.WALL_LIGHTS:
		_wall_light(fx, String(w[0]), w[1], float(w[2]), w[3], float(w[4]), float(w[5]), w[6])
	for cl: Array in L.CLOCKS:
		_clock(fx, String(cl[0]), cl[1], float(cl[2]), float(cl[3]))


## Ceiling-mounted fixture: pivot at the ceiling surface (top-centre), panel just below, light under it.
func _ceiling_light(parent: Node3D, nm: String, pivot: Vector3, color: Color, energy: float, rng: float) -> void:
	var r: Node3D = node3d(nm, pivot)
	r.set_meta(&"mount", "ceiling")
	r.set_meta(&"fixture", true)
	r.set_meta(&"kind", "light_fixture")
	add(parent, r)
	var size: Vector3 = Vector3(0.6, 0.05, 0.6) if not nm.begins_with("LightHall") else Vector3(0.5, 0.4, 0.5)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Panel"
	mi.mesh = box_mesh(size, "fixture")
	mi.position = Vector3(0.0, -size.y * 0.5 - 0.002, 0.0)
	add(r, mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -size.y - 0.2, 0.0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
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
	mi.mesh = box_mesh(size, "atm_led" if nm.contains("Fascia") else "sodium")
	mi.position = Vector3(0.0, 0.0, -size.z * 0.5 - 0.002)
	add(r, mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -0.1, -0.4)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	add(r, light)


## Landmark 1: brass harbor clock (lit face, wall-mounted).
func _clock(parent: Node3D, nm: String, pivot: Vector3, yaw: float, radius: float) -> void:
	var r: Node3D = node3d(nm, pivot)
	r.basis = yaw_basis(yaw)
	r.set_meta(&"mount", "wall")
	r.set_meta(&"fixture", true)
	r.set_meta(&"kind", "clock")
	add(parent, r)
	var face: MeshInstance3D = MeshInstance3D.new()
	face.name = "Face"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.12
	cm.radial_segments = 32
	cm.material = lib_mat("clock")
	face.mesh = cm
	face.basis = Basis(Vector3.RIGHT, PI * 0.5)
	face.position = Vector3(0.0, 0.0, -0.062)
	add(r, face)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 0.0, -0.5)
	light.light_color = EMISSIVE_MATS["clock"]
	light.light_energy = 0.6
	light.omni_range = 5.0
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
	link.navigation_layers = 1
	link.start_position = Vector3(16.3, 0.0, -1.4)
	link.end_position = Vector3(18.2, L.BASE, -1.1)
	add(nav, link)


# --- Navigation bake --------------------------------------------------------------------------

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
