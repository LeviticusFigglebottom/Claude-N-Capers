## Dockside Burn G1 greybox generator. Owner: ENV C (C3).
## Regenerate (deterministic; never hand-edit the outputs):
##   /opt/godot/godot --headless --path game --script res://world/heists/dockside_burn/greybox/build_greybox.gd
## Reads dockside_burn_layout.gd and writes, under res://world/heists/dockside_burn/:
##   dockside_burn.tscn (HeistMap, navmesh baked and embedded), dockside_burn_def.tres,
##   dockside_burn_variants.tres. Contracts: docs/contracts/heist_map.md v1.2, gameplay_prefabs.md v1.3,
##   preplanning.md. Design: docs/design/heists/dockside_burn.md (APPROVED, D-064).
## Walls are explicit lines (layout EXT_WALLS / INT_WALLS / FENCES / SHEDS); their door and window
## openings are derived from the layout's DOORS and GLAZING, so a door never misses its hole.
## Gameplay prefabs are instanced (never edited) and located through their contract class names, so
## this file holds no path into another environment's folder.
extends "res://world/heists/dockside_burn/greybox/db_gameplay.gd"

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER


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
	map_root.name = "DocksideBurn"
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
	_close_barred_doorways()
	var polys: int = await _bake(nav)
	if polys <= 0:
		_fail("navmesh bake produced no polygons")
		return
	for untagged: String in SurfaceTags.tag_tree(map_root):  # PO-8 bullet surface ids
		errors.append("no surface id for %s" % untagged)
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
	print("dockside_burn: saved %s (navmesh polygons: %d)" % [SCENE_PATH, polys])
	quit(0)


func _fail(msg: String) -> void:
	push_error("dockside_burn: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


# --- Openings ---------------------------------------------------------------------------------

## Door and window openings on a wall line (axis, fixed, along a0..a1, y0..y1, thickness).
func _openings(axis: String, fixed: float, a0: float, a1: float, y0: float, y1: float, thick: float) -> Array:
	var out: Array = []
	var tol: float = thick * 0.5 + 0.01
	for d: Array in L.DOORS:
		var o: Vector3 = d[2]
		var yaw: float = float(d[3])
		var dax: String = "x" if absf(sin(deg_to_rad(yaw))) < 0.5 else "z"
		var dfix: float = o.z if dax == "x" else o.x
		var along: float = o.x if dax == "x" else o.z
		if dax != axis or absf(dfix - fixed) > tol or along < a0 or along > a1 or o.y < y0 - 0.01 or o.y >= y1:
			continue
		var op: Array = L.DOOR_OPENINGS[_door_type(d)]
		var hw: float = float(op[0]) * 0.5
		out.append([along - hw, along + hw, o.y, o.y + float(op[1])])
	for g: Array in L.GLAZING:
		if String(g[1]) != axis or absf(float(g[2]) - fixed) > tol:
			continue
		if float(g[3]) < a0 - 0.01 or float(g[4]) > a1 + 0.01 or float(g[5]) >= y1 or float(g[6]) <= y0:
			continue
		out.append([float(g[3]), float(g[4]), float(g[5]), float(g[6])])
	return out


func _portals(wall_name: String) -> Array:
	var out: Array = []
	for p: Array in L.PORTALS:
		if String(p[0]) == wall_name:
			out.append(p[1])
	return out


# --- Building shell ---------------------------------------------------------------------------

func _build_shell(geo: Node3D) -> void:
	var bld: Node3D = add(geo, node3d("Building")) as Node3D
	var walls: Node3D = add(bld, node3d("ExteriorWalls")) as Node3D
	var q: float = L.EXT_T * 0.25
	var h: float = L.EXT_T * 0.5
	for w: Array in L.EXT_WALLS:
		var fixed: float = float(w[2])
		var a0: float = float(w[3])
		var a1: float = float(w[4])
		var yr: Vector2 = Vector2(float(w[5]), float(w[6]))
		var out_sign: float = float(w[7])
		var ops: Array = (w[8] as Array).duplicate()
		ops.append_array(_openings(String(w[1]), fixed, a0, a1, yr.x, yr.y, L.EXT_T))
		wall(walls, String(w[0]) + "Out", String(w[1]), fixed + out_sign * q, a0, a1, h, yr, ops, "wall_ext")
		wall(walls, String(w[0]) + "In", String(w[1]), fixed - out_sign * q, a0, a1, h, yr, ops, "wall")
	var iw: Node3D = add(bld, node3d("InteriorWalls")) as Node3D
	for w2: Array in L.INT_WALLS:
		var t: float = float(w2[7])
		var yr2: Vector2 = Vector2(float(w2[5]), float(w2[6]))
		var ops2: Array = (w2[9] as Array).duplicate()
		ops2.append_array(_portals(String(w2[0])))
		ops2.append_array(_openings(String(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), yr2.x, yr2.y, t))
		wall(iw, String(w2[0]), String(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), t, yr2, ops2, String(w2[8]))
	var slabs: Node3D = add(bld, node3d("Slabs")) as Node3D
	for s: Array in L.SLABS:
		box_a(slabs, String(s[0]), s[1], String(s[2]))
	var ceil_n: Node3D = add(bld, node3d("Ceilings")) as Node3D
	for c: Array in L.CEILINGS:
		box_a(ceil_n, String(c[0]), c[1], "ceiling")
	_build_core(bld)
	_build_platform(bld)
	var st: Node3D = add(bld, node3d("Stairs")) as Node3D
	for row: Array in L.STRAIGHT_STAIRS:
		_straight_stair(st, row)
	_build_fire_landing(st)
	var rails: Node3D = add(bld, node3d("Railings")) as Node3D
	for r: Array in L.RAILINGS:
		railing(rails, String(r[0]), v3(r[1], 0), v3(r[1], 3))
	_build_glazing(bld)
	_build_parapet_coping(bld)
	for sc: Array in L.STRIP_CURTAINS:
		mesh_box(bld, String(sc[0]), v3(sc[1], 0), v3(sc[1], 3), "strip_curtain")
	# Landmark 1: the painted leaping-fish mural on the high-bay north wall (visual only).
	mesh_box(bld, "Mural", v3(L.MURAL, 0), v3(L.MURAL, 3), "mural")
	# PL culvert floor grate (Phantom vent exit; visual only, flush with the floor).
	mesh_box(bld, "CulvertGrate", Vector3(1.4, 0.0, 14.4), Vector3(2.6, 0.015, 15.6), "grate")
	_build_sheds(bld)


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
	var posts: int = mini(maxi(2, int(ceil(length / 1.5)) + 1), 40)
	for i: int in range(posts):
		var off: float = -length * 0.5 + 0.025 + (length - 0.05) * float(i) / float(posts - 1)
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "Post%d" % i
		post.mesh = box_mesh(Vector3(0.05, size.y, t), "trim")
		post.position = Vector3(off, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, off)
		add(body, post)


## Static glazing: glass blocker (collision) + pane + head frame bar.
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


## Office-roof parapet: 45 deg sloped coping (0.2 rise over 0.2 run each side), not standable (doc
## play-space closure: nobody stands on it; the hall and high-bay roofs beyond stay out of reach).
func _build_parapet_coping(bld: Node3D) -> void:
	var cp: Node3D = add(bld, node3d("Coping")) as Node3D
	var y: float = L.OFFICE_PARAPET
	_coping(cp, "CopingN", "x", 0.0, 3.15, 18.15, y)
	_coping(cp, "CopingS", "x", 8.0, -0.2, 18.15, y)
	_coping(cp, "CopingW", "z", 0.0, 6.15, 7.85, y)
	_coping(cp, "CopingE", "z", 18.0, 0.2, 7.85, y)
	_coping(cp, "CopingHHN", "x", 0.0, -0.2, 3.15, L.HH_TOP)
	_coping(cp, "CopingHHW", "z", 0.0, 0.2, 6.15, L.HH_TOP)


func _coping(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, y: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	add(parent, body)
	var h: float = L.EXT_T * 0.5
	var pts: PackedVector3Array = PackedVector3Array()
	for a: float in [a0, a1]:
		for q: Vector2 in [Vector2(-h, 0.0), Vector2(h, 0.0), Vector2(0.0, h)]:
			pts.append(Vector3(a, y + q.y, fixed + q.x) if axis == "x" else Vector3(fixed + q.x, y + q.y, a))
	var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shp.points = pts
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shp
	add(body, col)
	var pm: PrismMesh = PrismMesh.new()
	pm.size = Vector3(L.EXT_T, h, a1 - a0)
	pm.material = lib_mat("trim")
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = pm
	var mid: float = (a0 + a1) * 0.5
	mi.position = Vector3(mid, y + h * 0.5, fixed) if axis == "x" else Vector3(fixed, y + h * 0.5, mid)
	mi.basis = Basis(Vector3.UP, PI * 0.5) if axis == "x" else Basis.IDENTITY
	add(body, mi)


## Small buildings: four walls (door / window openings from the layout), the roof slab.
func _build_sheds(bld: Node3D) -> void:
	var sh: Node3D = add(bld, node3d("Sheds")) as Node3D
	for s: Array in L.SHEDS:
		var g: Node3D = add(sh, node3d(String(s[0]))) as Node3D
		var x0: float = float(s[1])
		var z0: float = float(s[2])
		var x1: float = float(s[3])
		var z1: float = float(s[4])
		var y0: float = float(s[5])
		var ceil_y: float = float(s[6])
		var rt: float = float(s[7])
		var t: float = float(s[8])
		var open: Array = s[9]
		var top: float = ceil_y + rt
		var h: float = t * 0.5
		var sides: Array = [["N", "x", z0, x0 - h, x1 + h], ["S", "x", z1, x0 - h, x1 + h], ["W", "z", x0, z0 + h, z1 - h],
			["E", "z", x1, z0 + h, z1 - h]]
		for sd: Array in sides:
			if String(sd[0]) in open:
				continue
			var ops: Array = _openings(String(sd[1]), float(sd[2]), float(sd[3]), float(sd[4]), y0, top, t)
			wall(g, "Wall" + String(sd[0]), String(sd[1]), float(sd[2]), float(sd[3]), float(sd[4]), t, Vector2(y0, top), ops,
				"wall_ext")
		box(g, "Roof", Vector3(x0 - h, ceil_y, z0 - h), Vector3(x1 + h, top, z1 + h), "roof")


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
	if solid_y == null:
		_ramp(f, -w * 0.5, w * 0.5, [[Vector2(-t, 0.0), Vector2(end_z, float(nr) * r), Vector2(end_z, float(nr) * r - ramp_t),
			Vector2(-t, -ramp_t)]])
	else:
		# Solid base: the enveloping ramp's prism runs down to the base (no hollow under the flight).
		var lo: float = minf(float(solid_y) - origin.y, -ramp_t)
		_ramp(f, -w * 0.5, w * 0.5, [[Vector2(-t, 0.0), Vector2(end_z, float(nr) * r), Vector2(end_z, lo), Vector2(-t, lo)]])
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
	col.shape = box_shape(size)
	add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = box_mesh(size, "trim")
	add(body, mi)


## Stair core ST (Shadow Ledger core layout): per storey a west up-flight (north from z 4.53), the
## half landing, an east return flight (south to the floor landing) and the well divider; floor
## landings at +3.6 / +7.2 (the slabs leave the core out) and a railing over the void at the roof.
func _build_core(parent: Node3D) -> void:
	var c: Node3D = add(parent, node3d("StairST")) as Node3D
	var x0: float = float(L.STAIR_CORE["x0"])
	var levels: Array = L.STAIR_CORE["levels"]
	var xw: float = x0 + (L.STAIR_WEST.x + L.STAIR_WEST.y) * 0.5
	var xe: float = x0 + (L.STAIR_EAST.x + L.STAIR_EAST.y) * 0.5
	var w: float = L.STAIR_WEST.y - L.STAIR_WEST.x
	var t: float = L.STAIR_TREAD
	for i: int in range(levels.size() - 1):
		var y0: float = float(levels[i])
		var y1: float = float(levels[i + 1])
		var hgt: float = y1 - y0
		var m: int = int(round(hgt / (2.0 * L.STAIR_RISER)))
		var r: float = hgt / float(2 * m)
		var zh: float = L.STAIR_Z_START - float(m - 1) * t
		var yh: float = y0 + hgt * 0.5
		var tag: String = "%d" % (i + 1)
		_flight(c, "Flight%sW" % tag, Vector3(xw, y0, L.STAIR_Z_START), 180.0, w, m, r, t, null, true)
		_flight(c, "Flight%sE" % tag, Vector3(xe, yh, zh), 0.0, w, m, r, t, null, true)
		var off: float = L.HANDRAIL_OFF
		for k: int in range(2):
			var xr: float = (x0 + L.STAIR_CLEAR.x + off) if k == 0 else (x0 + L.STAIR_WELL.x - off)
			_handrail(c, "Flight%sWRail%d" % [tag, k], Vector3(xr, y0 + L.HANDRAIL_H, L.STAIR_Z_START),
				Vector3(xr, y0 + float(m) * r + L.HANDRAIL_H, zh))
			var xr2: float = (x0 + L.STAIR_WELL.y + off) if k == 0 else (x0 + L.STAIR_CLEAR.y - off)
			_handrail(c, "Flight%sERail%d" % [tag, k], Vector3(xr2, yh + L.HANDRAIL_H, zh),
				Vector3(xr2, yh + float(m) * r + L.HANDRAIL_H, L.STAIR_Z_START))
		box(c, "HalfLanding%s" % tag, Vector3(x0 + L.STAIR_CLEAR.x, yh - 0.3, L.STAIR_Z_N), Vector3(x0 + L.STAIR_CLEAR.y, yh, zh),
			"stair")
		var top_storey: bool = i == levels.size() - 2
		box(c, "Divider%s" % tag, Vector3(x0 + L.STAIR_WELL.x, y0, zh), Vector3(x0 + L.STAIR_WELL.y, y1 + (1.1 if top_storey else 0.0),
			L.STAIR_Z_START), "wall")
		box(c, "FloorLanding%s" % tag, Vector3(x0 + L.STAIR_CLEAR.x, y1 - 0.3, L.STAIR_Z_START), Vector3(x0 + L.STAIR_CLEAR.y, y1,
			L.STAIR_Z_S), "stair")
	var ytop: float = float(levels[levels.size() - 1])
	railing(c, "TopRail", Vector3(x0 + L.STAIR_CLEAR.x, ytop, L.STAIR_Z_START - 0.06), Vector3(x0 + L.STAIR_WELL.x, ytop + 1.1,
		L.STAIR_Z_START))


## Hall platform PF: steel deck on three columns (the x 18 wall carries its west edge).
func _build_platform(parent: Node3D) -> void:
	var pf: Node3D = add(parent, node3d("Platform")) as Node3D
	box_a(pf, "Deck", L.PLATFORM["deck"], "floor")
	var i: int = 0
	for c: Vector2 in L.PLATFORM["columns"]:
		box(pf, "Column%d" % i, Vector3(c.x - 0.1, 0.0, c.y - 0.1), Vector3(c.x + 0.1, L.MEZZ_SLAB, c.y + 0.1), "trim")
		i += 1


## Straight two-flight stair with a mid landing (layout STRAIGHT_STAIRS): solid base, 1.05+ m guard
## panels on the open sides (mesh-guard fence material), handrails both sides (the bar is the nearest
## barrier: the validator reads its top, 1.05 m).
func _straight_stair(parent: Node3D, row: Array) -> void:
	var nm: String = String(row[0])
	var o: Vector3 = row[1]
	var yaw: float = float(row[2])
	var w: float = float(row[3])
	var nr: int = int(row[4])
	var t: float = float(row[5])
	var land: float = float(row[6])
	var guards: Array = row[7]
	var solid_y: float = float(row[8])
	var r: float = L.STAIR_RISER
	var b: Basis = yaw_basis(yaw)
	var g: Node3D = add(parent, node3d(nm)) as Node3D
	var run: float = float(nr - 1) * t
	var ym: float = o.y + float(nr) * r
	var y1: float = ym + float(nr) * r
	var o2: Vector3 = o + b * Vector3(0.0, 0.0, run + land) + Vector3(0.0, float(nr) * r, 0.0)
	_flight(g, "Flight1", o, yaw, w, nr, r, t, solid_y, true)
	_flight(g, "Flight2", o2, yaw, w, nr, r, t, solid_y, true)
	_world_box(g, "Landing", o, b, Vector3(-w * 0.5, solid_y - o.y, run), Vector3(w * 0.5, ym - o.y, run + land), "stair")
	var segs: Array = [[-t, run, ym + 1.1], [run, run + land, ym + 1.1], [run + land, 2.0 * run + land, y1 + 1.1]]
	for side: Variant in guards:
		var sx: float = -1.0 if String(side) == "L" else 1.0
		for k: int in range(segs.size()):
			var sg: Array = segs[k]
			_world_box(g, "Guard%s%d" % [side, k], o, b, Vector3(sx * w * 0.5 - 0.03, solid_y - o.y, float(sg[0])),
				Vector3(sx * w * 0.5 + 0.03, float(sg[2]) - o.y, float(sg[1])), "fence")
	for k2: int in range(2):
		var sx2: float = -1.0 if k2 == 0 else 1.0
		var xl: float = sx2 * (w * 0.5 - 0.03 - L.HANDRAIL_OFF)
		var p: Array = [[0.0, 0.0, run, ym - o.y], [run, ym - o.y, run + land, ym - o.y], [run + land, ym - o.y, 2.0 * run + land, y1 - o.y]]
		for j: int in range(p.size()):
			var a: Vector3 = o + b * Vector3(xl, float(p[j][1]) + L.HANDRAIL_H, float(p[j][0]))
			var c: Vector3 = o + b * Vector3(xl, float(p[j][3]) + L.HANDRAIL_H, float(p[j][2]))
			_handrail(g, "Rail%d%d" % [k2, j], a, c)
	# The enclosed base is not walkable (no navmesh island on the solid base's top edge).
	var lo: Vector3 = o + b * Vector3(-w * 0.5, 0.0, 0.5)
	var hi: Vector3 = o + b * Vector3(w * 0.5, 0.0, 2.0 * run + land - 0.5)
	obstruct(Transform3D.IDENTITY, AABB(Vector3(minf(lo.x, hi.x), solid_y, minf(lo.z, hi.z)),
		Vector3(absf(hi.x - lo.x), 0.3, absf(hi.z - lo.z))))


## Box given in a frame (origin o, basis b) by local min / max corners (b is a multiple of 90 deg).
func _world_box(parent: Node3D, nm: String, o: Vector3, b: Basis, lmn: Vector3, lmx: Vector3, mat: String) -> void:
	var p: Vector3 = o + b * lmn
	var q: Vector3 = o + b * lmx
	box(parent, nm, Vector3(minf(p.x, q.x), minf(p.y, q.y), minf(p.z, q.z)), Vector3(maxf(p.x, q.x), maxf(p.y, q.y), maxf(p.z, q.z)),
		mat)


## Fire-stair top landing at the MC west door (+3.6): slab on two posts (the OC west door is under it).
func _build_fire_landing(parent: Node3D) -> void:
	var fl: Node3D = add(parent, node3d("FireLanding")) as Node3D
	box_a(fl, "Slab", L.FIRE_LANDING, "stair")
	for z: float in [6.05, 7.95]:
		box(fl, "Post%d" % int(z), Vector3(-1.4, 0.0, z - 0.05), Vector3(-1.3, L.MEZZ_SLAB, z + 0.05), "trim")


# --- Site -------------------------------------------------------------------------------------

func _build_site(geo: Node3D) -> void:
	var site: Node3D = add(geo, node3d("Site")) as Node3D
	var ground: Node3D = add(site, node3d("Ground")) as Node3D
	for g: Array in L.GROUND:
		var gb: Node3D = box_a(ground, String(g[0]), g[1], String(g[2]))
		if String(g[2]) == "none":
			SurfaceTags.tag(gb, &"water")  # shots into the harbour stop on the bed below the water
			# Seabed / slip bed (collision only) must not grow a navmesh island under the water.
			var bb: Array = g[1]
			obstruct(Transform3D.IDENTITY, AABB(v3(bb, 0) + Vector3(0.0, -0.5, 0.0), v3(bb, 3) - v3(bb, 0) + Vector3(0.0, 2.0, 0.0)))
	_quay_steps(ground)
	_pontoon_ramp(ground)
	for w: Array in L.WATER:
		box_a(site, String(w[0]), w[1], "water", false)
	var blocks: Node3D = add(site, node3d("Blocks")) as Node3D
	for b: Array in L.BLOCKS:
		box_a(blocks, String(b[0]), b[1], String(b[2]))
	_far_shore_lights(blocks)
	var fences: Node3D = add(site, node3d("Closures")) as Node3D
	for f: Array in L.FENCES:
		var ops: Array = (f[7] as Array).duplicate()
		ops.append_array(_openings(String(f[1]), float(f[2]), float(f[3]), float(f[4]), float(f[5]), float(f[6]), 0.1))
		wall(fences, String(f[0]), String(f[1]), float(f[2]), float(f[3]), float(f[4]), 0.1,
			Vector2(float(f[5]), float(f[6])), ops, String(f[8]))
	box_a(fences, "YardGateLeaf", L.GATE_LEAF, "fence")
	mesh_box(site, "WeighbridgePlate", v3(L.WEIGHBRIDGE, 0), v3(L.WEIGHBRIDGE, 3), "trim")


## Quay steps (-1.8 -> 0.0): one flight in the recess, walls both sides (the quay deck), handrails.
func _quay_steps(parent: Node3D) -> void:
	var qs: Dictionary = L.QUAY_STEPS
	var o: Vector3 = qs["origin"]
	var w: float = float(qs["w"])
	var nr: int = int(qs["risers"])
	var t: float = float(qs["tread"])
	var yaw: float = float(qs["yaw"])
	var f: Node3D = _flight(parent, "QuaySteps", o, yaw, w, nr, L.STAIR_RISER, t, -2.6, true)
	var b: Basis = yaw_basis(yaw)
	var run: float = float(nr - 1) * t
	for k: int in range(2):
		var sx: float = -1.0 if k == 0 else 1.0
		var xl: float = sx * (w * 0.5 - L.HANDRAIL_OFF)
		_handrail(f.get_parent() as Node3D, "QuayStepsRail%d" % k, o + b * Vector3(xl, L.HANDRAIL_H, 0.0),
			o + b * Vector3(xl, float(nr) * L.STAIR_RISER + L.HANDRAIL_H, run))


## Pontoon ramp (16.7 deg, walkable): a convex prism from the quay (0.0) to the pontoon (-1.8), with
## full-height guard panels on both sides (Geometry; the tops run 1.05+ above the ramp surface).
func _pontoon_ramp(parent: Node3D) -> void:
	var rp: Dictionary = L.RAMP
	var xs: Array = rp["x"]
	var zs: Array = rp["z"]
	var ys: Array = rp["y"]
	var th: float = float(rp["t"])
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PontoonRamp"
	body.collision_layer = 1
	body.collision_mask = 0
	add(parent, body)
	var pts: PackedVector3Array = PackedVector3Array()
	for p: Vector2 in [Vector2(float(zs[0]), float(ys[0])), Vector2(float(zs[1]), float(ys[1])),
			Vector2(float(zs[1]), float(ys[1]) - th), Vector2(float(zs[0]), float(ys[0]) - th)]:
		for x: Variant in xs:
			pts.append(Vector3(float(x), p.y, p.x))
	var shp: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shp.points = pts
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shp
	add(body, col)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a: Vector3 = Vector3(float(xs[0]), float(ys[0]), float(zs[0]))
	var bq: Vector3 = Vector3(float(xs[1]), float(ys[0]), float(zs[0]))
	var c: Vector3 = Vector3(float(xs[1]), float(ys[1]), float(zs[1]))
	var d: Vector3 = Vector3(float(xs[0]), float(ys[1]), float(zs[1]))
	st.set_normal((c - bq).cross(a - bq).normalized())
	for v: Vector3 in [a, bq, c, a, c, d]:
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)
	st.set_material(lib_mat("deck"))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	add(body, mi)
	for k: int in range(2):
		var x: float = float(xs[0]) - 0.05 if k == 0 else float(xs[1])
		box(parent, "RampGuard%d" % k, Vector3(x, float(ys[1]), float(zs[0])), Vector3(x + 0.05, float(ys[0]) + 1.05, float(zs[1])),
			"fence")


## Far-shore lights in the fog (emissive dressing, 400 m out).
func _far_shore_lights(parent: Node3D) -> void:
	var fl: Node3D = add(parent, node3d("FarShoreLights")) as Node3D
	for i: int in range(14):
		var x: float = -160.0 + 30.0 * float(i)
		var y: float = 2.0 + float((i * 7) % 5)
		mesh_box(fl, "Light%02d" % i, Vector3(x, y, 399.0), Vector3(x + 1.5, y + 0.6, 399.5), "far_lights")


# --- Props ------------------------------------------------------------------------------------

func _build_props(props: Node3D) -> void:
	var g: Node3D = add(props, node3d("Ground")) as Node3D
	var m: Node3D = add(props, node3d("Mezzanine")) as Node3D
	var x: Node3D = add(props, node3d("Exterior")) as Node3D
	for p: Array in L.PROPS:
		prop_box(_prop_parent(p[1], g, m, x), String(p[0]), p[1], p[2], float(p[3]), String(p[4]), bool(p[5]), String(p[6]))
	for c: Array in L.CHAIRS:
		chair(_prop_parent(c[1], g, m, x), String(c[0]), c[1], float(c[2]))
	for ms: Array in L.MASTS:
		_mast(x, String(ms[0]), ms[1], float(ms[2]))


func _prop_parent(base: Vector3, g: Node3D, m: Node3D, x: Node3D) -> Node3D:
	if base.x < 0.0 or base.x > 48.0 or base.z < 0.0 or base.z > 32.0 or base.y < -0.01:
		return x
	return m if base.y > 3.0 else g


## Sodium yard mast (fixture head + OmniLight).
func _mast(parent: Node3D, nm: String, base: Vector3, yaw: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = yaw_basis(yaw)
	body.set_meta(&"kind", "lamp_post")
	add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = box_shape(Vector3(0.2, 8.0, 0.2))
	col.position = Vector3(0.0, 4.0, 0.0)
	add(body, col)
	mesh_box(body, "Pole", Vector3(-0.1, 0.0, -0.1), Vector3(0.1, 8.0, 0.1), "trim")
	mesh_box(body, "Arm", Vector3(-0.05, 7.9, -1.0), Vector3(0.05, 8.0, 0.0), "trim")
	var head: MeshInstance3D = mesh_box(body, "Head", Vector3(-0.18, 7.76, -1.1), Vector3(0.18, 7.9, -0.4), "sodium")
	head.set_meta(&"fixture", true)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 7.5, -0.75)
	light.light_color = EMISSIVE_MATS["sodium"]
	light.light_energy = 2.2
	light.omni_range = 18.0
	light.layers |= VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
	add(body, light)
	obstruct(body.transform, AABB(Vector3(-0.1, 0.0, -0.1), Vector3(0.2, 8.0, 0.2)))


# --- Lighting ---------------------------------------------------------------------------------

## 05:10 pre-dawn: no sun (8 deg below the horizon, east), a weak sky fill, dense harbour fog
## (~150 m visibility), sodium yard masts and the cold-store LEDs (doc Audio/lighting).
func _build_lighting(lighting: Node3D) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load("res://world/lighting/heist_world_environment.gd"))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_dockside_burn_greybox"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.04, 0.06, 0.1)
	sky_mat.sky_horizon_color = Color(0.2, 0.22, 0.26)
	sky_mat.ground_bottom_color = Color(0.02, 0.03, 0.04)
	sky_mat.ground_horizon_color = Color(0.16, 0.17, 0.19)
	sky_mat.sky_energy_multiplier = 0.7
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.36, 0.38)
	# LEAD 2026-10-12 (D 20/40 m read): thinner; was density 0.006, height 4.0, height_density 0.05.
	env.fog_density = 0.0035
	env.fog_height = 2.0
	env.fog_height_density = 0.015
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.4
	we.environment = env
	add(lighting, we)
	var dawn: DirectionalLight3D = DirectionalLight3D.new()
	dawn.name = "PreDawnSky"
	dawn.basis = Basis.looking_at(Vector3(-0.6, -0.4, 0.3).normalized(), Vector3.UP)
	dawn.position = Vector3(24.0, 40.0, 16.0)
	dawn.light_color = Color(0.6, 0.68, 0.85)
	dawn.light_energy = 0.12
	dawn.shadow_enabled = false
	add(lighting, dawn)
	var fx: Node3D = add(lighting, node3d("Fixtures")) as Node3D
	for c: Array in L.CEILING_LIGHTS:
		_ceiling_light(fx, String(c[0]), c[1], c[2], float(c[3]), float(c[4]))
	for w: Array in L.WALL_LIGHTS:
		_wall_light(fx, String(w[0]), w[1], float(w[2]), w[3], float(w[4]), float(w[5]), w[6])
	# Landmark 2: the Pier 10 crane's orange hazard beacons on the portal beams.
	for i: int in range(2):
		var p: Vector3 = Vector3(77.0, 22.0, -8.0 if i == 0 else 8.0)
		var bcn: MeshInstance3D = mesh_box(fx, "CraneBeacon%d" % i, p - Vector3(0.2, 0.0, 0.2), p + Vector3(0.2, 0.4, 0.2), "beacon")
		bcn.set_meta(&"fixture", true)
		var bl: OmniLight3D = OmniLight3D.new()
		bl.name = "CraneBeaconLight%d" % i
		bl.position = p + Vector3(0.0, 0.7, 0.0)
		bl.light_color = EMISSIVE_MATS["beacon"]
		bl.light_energy = 1.5
		bl.omni_range = 10.0
		add(fx, bl)


## Ceiling-mounted fixture: pivot at the ceiling surface (top-centre), panel just below, light under it.
func _ceiling_light(parent: Node3D, nm: String, pivot: Vector3, color: Color, energy: float, rng: float) -> void:
	var r: Node3D = node3d(nm, pivot)
	r.set_meta(&"mount", "ceiling")
	r.set_meta(&"fixture", true)
	r.set_meta(&"kind", "light_fixture")
	add(parent, r)
	var size: Vector3 = Vector3(0.6, 0.05, 0.6) if pivot.y < 5.0 else Vector3(0.5, 0.3, 0.5)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Panel"
	mi.mesh = box_mesh(size, "cold_led" if color.b > color.r else "fixture")
	mi.position = Vector3(0.0, -size.y * 0.5 - 0.002, 0.0)
	add(r, mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -size.y - 0.2, 0.0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	light.layers |= VIEWMODEL_LIT_LAYER  # D-095: also lights the FP viewmodel
	add(r, light)


## Wall-mounted flood / lamp: pivot on the wall face (back-centre), -Z out of the wall.
func _wall_light(parent: Node3D, nm: String, pivot: Vector3, yaw: float, color: Color, energy: float,
		rng: float, size: Vector3) -> void:
	var r: Node3D = node3d(nm, pivot)
	r.basis = yaw_basis(yaw)
	r.set_meta(&"mount", "wall")
	r.set_meta(&"fixture", true)
	r.set_meta(&"kind", "light_fixture")
	add(parent, r)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = box_mesh(size, "sodium")
	mi.position = Vector3(0.0, 0.0, -size.z * 0.5 - 0.002)
	add(r, mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -0.1, -0.5)
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
		if String(z[1]) == "OUT_OF_BOUNDS":
			mz.set_meta(&"respawn_tag", &"oob_respawn")
			mz.set_meta(&"alarm", false)


# --- Patrols, spawns, tactical ----------------------------------------------------------------

func _build_patrols(patrols: Node3D) -> void:
	var g: PatrolGraph = PatrolGraph.new()
	g.name = "Cartel"
	g.graph_id = &"cartel"
	g.floor_index = 1
	add(patrols, g)
	var points: Dictionary = L.PATROL_POINTS
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
	var edges: Array = L.PATROL_EDGES.duplicate()
	for post: Array in L.PATROL_POSTS:
		for a0: int in range(post.size()):
			for b0: int in range(a0 + 1, post.size()):
				edges.append([post[a0], post[b0]])
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
	for s: Array in L.POLICE_SPAWNS:
		var sp: SpawnPoint = spawn(spawns, String(s[0]), "POLICE", s[1], float(s[2]), s[3], "", "")
		if (s[3] as Array).has("police_roof"):
			# P5: a police-only navmesh island; validated from the spawn down its one-way rappel links.
			sp.set_meta(&"police_only", true)
	# Cartel reinforcements (rare `cartel_reinforcements`): scripted, spawned by the mission (QC-25).
	for r: Array in L.REINFORCEMENT_SPAWNS:
		var rs: SpawnPoint = spawn(spawns, String(r[0]), "GUARD", r[1], float(r[2]), ["scripted", "cartel", "cartel_reinf"], "",
			"Cartel")
		rs.set_meta(&"enemy_id", &"enemy.cartel_gunman")


func _build_tactical(tac: Node3D) -> void:
	for t: Array in L.TACTICAL:
		_tactical(tac, t)


## PREPLAN_POINT markers (preplanning.md): node name = point id; metas category/label/floor/params.
func _build_preplan(pre: Node3D) -> void:
	for p: Array in L.PREPLAN_POINTS:
		var m: Marker3D = Marker3D.new()
		m.name = String(p[0])
		m.position = p[2]
		m.set_meta(&"category", StringName(String(p[1])))
		m.set_meta(&"label", StringName("ui.preplan.point.dockside_burn." + String(p[0])))
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


## Always-present links: the one-way rappel links (QC-41) and the culvert (nav layer `vent`).
func _build_nav_links(nav: NavigationRegion3D) -> void:
	for l: Array in L.NAV_LINKS:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = String(l[0])
		link.start_position = l[1]
		link.end_position = l[2]
		link.bidirectional = bool(l[3])
		link.navigation_layers = int(l[4])
		add(nav, link)


# --- Navigation bake --------------------------------------------------------------------------

## D-073: BARRED / VAULT doorways (roller doors, the strongroom, the play-space closure gates) are
## baked CLOSED: a projected obstruction fills the opening (+0.15 m into each jamb, 0.3 m each side of
## the wall line), so the agent-radius erosion leaves no navmesh through it. ENV A's door NavLink
## (InteractionTweak.door_nav_link_half_m) bridges the gap while the door is passable. validate_level
## `barred_doors` asserts it.
func _close_barred_doorways() -> void:
	for d: Array in L.DOORS:
		if not (String(d[4]) in ["BARRED", "VAULT"]):
			continue
		var w: float = float(L.DOOR_OPENINGS[_door_type(d)][0]) + 0.3
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
