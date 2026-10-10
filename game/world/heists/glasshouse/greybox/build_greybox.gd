## Glasshouse G1 greybox generator. Owner: ENV C (C1-03).
## Regenerate (deterministic; never hand-edit the outputs):
##   /opt/godot/godot --headless --path game --script res://world/heists/glasshouse/greybox/build_greybox.gd
## Reads glasshouse_layout.gd and writes, under res://world/heists/glasshouse/:
##   glasshouse.tscn (HeistMap, navmesh baked and embedded), glasshouse_def.tres,
##   glasshouse_variants.tres. Contracts: docs/contracts/heist_map.md v1.1, gameplay_prefabs.md.
## Design: docs/design/heists/glasshouse.md (APPROVED, D-023).
## Gameplay prefabs are instanced (never edited) and located through their contract class names,
## so this file holds no path into another environment's folder. They are added while the map is
## out of the tree, so their runtime _ready() never runs here.
extends SceneTree

const L: GDScript = preload("res://world/heists/glasshouse/greybox/glasshouse_layout.gd")
const R: GDScript = preload("res://world/heists/glasshouse/greybox/glasshouse_resources.gd")
const OUT_DIR: String = "res://world/heists/glasshouse/"
const SCENE_PATH: String = OUT_DIR + "glasshouse.tscn"
const DEF_PATH: String = OUT_DIR + "glasshouse_def.tres"
const VARIANTS_PATH: String = OUT_DIR + "glasshouse_variants.tres"
const MISSION_PATH: String = OUT_DIR + "glasshouse_mission.gd"
const MAT_DIR: String = "res://world/materials/"
const KIT_DIR: String = "res://assets/arch/"
const ENV_PATH: String = "res://world/lighting/env_glasshouse.tres"
const SUN_PATH: String = "res://world/lighting/sun_glasshouse.tscn"
## Stair step boxes overlap their higher neighbour by this much (no ray-through seams).
const SEAM: float = 0.02
## Prefab id -> contract class_name (gameplay_prefabs.md). Scene = the class script's .tscn sibling.
const PREFAB_CLASSES: Dictionary = {
	"door": "Door", "window": "WindowPrefab", "display_case": "DisplayCase", "safe": "Safe",
	"drill_point": "DrillPoint", "keycard_reader": "KeycardReader", "keycard_pickup": "KeycardPickup",
	"loot_spawn": "LootSpawn", "small_loot": "SmallLoot", "alarm_button": "AlarmButton", "phone": "Phone",
	"secure_zone": "SecureZone", "escape_zone": "EscapeZone", "body_container": "BodyContainer",
	"ladder": "Ladder", "camera_station": "CameraStation", "security_camera": "SecurityCamera",
	"code_note": "CodeNote",
}
## Building surface classes -> material library (greybox kit materials).
const LIB_MATS: Dictionary = {
	"wall": "grey_wall", "wall_ext": "grey_wall_ext", "floor": "grey_floor", "ceiling": "grey_ceiling",
	"stair": "grey_stair", "counter": "grey_counter", "prop": "grey_prop", "trim": "grey_trim",
	"glass": "grey_glass", "frame": "grey_frame", "door": "grey_door",
}
## Site surface classes (greybox flat colours, one per class; meta greybox = true).
const SITE_MATS: Dictionary = {
	"paving": Color(0.47, 0.46, 0.44), "sidewalk": Color(0.58, 0.57, 0.55), "asphalt": Color(0.22, 0.23, 0.25),
	"facade_a": Color(0.5, 0.5, 0.47), "facade_b": Color(0.46, 0.5, 0.55), "facade_c": Color(0.62, 0.58, 0.5),
	"brick": Color(0.48, 0.3, 0.25), "concrete": Color(0.5, 0.5, 0.5), "fence": Color(0.75, 0.55, 0.2),
	"vehicle": Color(0.3, 0.35, 0.45),
}
const EMISSIVE_MATS: Dictionary = {
	"neon": Color(1.0, 0.24, 0.65), "fixture": Color(1.0, 0.9, 0.75),
}

var _root: HeistMap = null
var _lib_cache: Dictionary = {}
var _site_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _box_shape_cache: Dictionary = {}
var _scene_cache: Dictionary = {}
## Projected nav obstructions for props and prefabs: [corners (PackedVector3Array), elevation, height].
var _obstructions: Array[Array] = []
var _errors: PackedStringArray = PackedStringArray()


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
	_root = HeistMap.new()
	_root.name = "Glasshouse"
	_root.heist_def = load(DEF_PATH) as HeistDef
	_root.variant_table = load(VARIANTS_PATH) as HeistVariantTable
	_root.floor_heights = PackedFloat32Array(L.FLOOR_HEIGHTS)
	for nm: String in ["Geometry", "Props", "Lighting"]:
		_add(_root, _node3d(nm))
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	nav.navigation_layers = 1
	_add(_root, nav)
	for nm2: String in ["Zones", "Rooms", "Spawns", "Patrols", "Tactical", "Gameplay", "Variants"]:
		_add(_root, _node3d(nm2))
	var mission: Node = Node.new()
	mission.name = "Mission"
	mission.set_script(load(MISSION_PATH))
	_add(_root, mission)
	_add(_root, _node3d("ReviewCameras"))

	_build_shell(_n("Geometry"))
	_build_site(_n("Geometry"))
	_build_props(_n("Props"))
	_build_lighting(_n("Lighting"))
	_build_rooms(_n("Rooms"))
	_build_zones(_n("Zones"))
	_build_patrols(_n("Patrols"))
	_build_spawns(_n("Spawns"))
	_build_tactical(_n("Tactical"))
	_build_review_cameras(_n("ReviewCameras"))
	_build_gameplay(_n("Gameplay"))
	_build_variants(_n("Variants"))
	_build_nav_links(nav)
	var polys: int = await _bake(nav)
	if polys <= 0:
		_fail("navmesh bake produced no polygons")
		return
	if not _errors.is_empty():
		_fail("\n".join(_errors))
		return
	var ps: PackedScene = PackedScene.new()
	err = ps.pack(_root)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE_PATH)
	_root.free()
	if err != OK:
		_fail("cannot save %s (%d)" % [SCENE_PATH, err])
		return
	R.normalize_scene(SCENE_PATH, old_scene_uid)
	print("glasshouse: saved %s (navmesh polygons: %d)" % [SCENE_PATH, polys])
	quit(0)


func _fail(msg: String) -> void:
	push_error("glasshouse: " + msg)
	if _root != null and is_instance_valid(_root):
		_root.free()
	quit(1)


func _n(path: String) -> Node3D:
	return _root.get_node(path) as Node3D


# --- Generic helpers --------------------------------------------------------------------------

func _add(parent: Node, n: Node) -> Node:
	parent.add_child(n)
	n.owner = _root
	return n


func _node3d(nm: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = nm
	n.position = pos
	return n


static func _yaw_basis(yaw_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg))


static func _v3(a: Array, i: int) -> Vector3:
	return Vector3(float(a[i]), float(a[i + 1]), float(a[i + 2]))


func _lib_mat(id: String) -> Material:
	var lib: String = String(LIB_MATS.get(id, ""))
	if lib == "":
		return _site_mat(id)
	if not _lib_cache.has(lib):
		_lib_cache[lib] = load(MAT_DIR + lib + ".tres") as Material
	return _lib_cache[lib]


func _site_mat(id: String) -> Material:
	if _site_cache.has(id):
		return _site_cache[id]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.resource_name = "gh_grey_" + id
	m.set_meta(&"greybox", true)
	if EMISSIVE_MATS.has(id):
		m.albedo_color = EMISSIVE_MATS[id]
		m.emission_enabled = true
		m.emission = EMISSIVE_MATS[id]
		m.emission_energy_multiplier = 3.0
		m.set_meta(&"untextured_ok", true)
	elif SITE_MATS.has(id):
		m.albedo_color = SITE_MATS[id]
		m.roughness = 0.9
	else:
		_errors.append("unknown material class `%s`" % id)
		m.albedo_color = Color(1.0, 0.0, 1.0)
	_site_cache[id] = m
	return m


func _box_mesh(size: Vector3, mat_id: String) -> BoxMesh:
	var key: String = "%s|%.3f|%.3f|%.3f" % [mat_id, size.x, size.y, size.z]
	if not _box_mesh_cache.has(key):
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		bm.material = _lib_mat(mat_id)
		_box_mesh_cache[key] = bm
	return _box_mesh_cache[key]


func _box_shape(size: Vector3) -> BoxShape3D:
	var key: String = "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if not _box_shape_cache.has(key):
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		_box_shape_cache[key] = bs
	return _box_shape_cache[key]


## Static box (world_static) from min/max corners: StaticBody3D + CollisionShape3D + MeshInstance3D.
func _box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat_id: String, collide: bool = true) -> Node3D:
	var size: Vector3 = mx - mn
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return null
	var root: Node3D
	if collide:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		root = body
	else:
		root = Node3D.new()
	root.name = nm
	root.position = (mn + mx) * 0.5
	_add(parent, root)
	if collide:
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Collision"
		col.shape = _box_shape(size)
		_add(root, col)
	if mat_id != "":
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = _box_mesh(size, mat_id)
		_add(root, mi)
	return root


func _box_a(parent: Node3D, nm: String, b: Array, mat_id: String, collide: bool = true) -> Node3D:
	return _box(parent, nm, _v3(b, 0), _v3(b, 3), mat_id, collide)


## Straight wall with rectangular openings. axis "x": runs along x at z = fixed; "z": along z at x = fixed.
## openings: [[along0, along1, sill_y, head_y], ...] (absolute heights).
func _wall(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, thick: float,
		yr: Vector2, openings: Array, mat_id: String) -> void:
	var y0: float = yr.x
	var y1: float = yr.y
	var cuts: Array[float] = [a0, a1]
	for o: Array in openings:
		for v: float in [float(o[0]), float(o[1])]:
			if v > a0 and v < a1 and not cuts.has(v):
				cuts.append(v)
	cuts.sort()
	var part: int = 0
	for i: int in range(cuts.size() - 1):
		var p: float = cuts[i]
		var q: float = cuts[i + 1]
		if q - p < 0.001:
			continue
		# Vertical solid ranges = [y0, y1] minus the openings covering [p, q].
		var holes: Array[Vector2] = []
		for o2: Array in openings:
			if float(o2[0]) <= p + 0.0001 and float(o2[1]) >= q - 0.0001:
				holes.append(Vector2(maxf(float(o2[2]), y0), minf(float(o2[3]), y1)))
		holes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cur: float = y0
		var spans: Array[Vector2] = []
		for h: Vector2 in holes:
			if h.x > cur + 0.0001:
				spans.append(Vector2(cur, h.x))
			cur = maxf(cur, h.y)
		if y1 > cur + 0.0001:
			spans.append(Vector2(cur, y1))
		# One box per storey (also lets the per-floor plan render cut every wall).
		var split: Array[Vector2] = []
		for sp: Vector2 in spans:
			if sp.x < L.UPPER - 0.0001 and sp.y > L.UPPER + 0.0001:
				split.append(Vector2(sp.x, L.UPPER))
				split.append(Vector2(L.UPPER, sp.y))
			else:
				split.append(sp)
		for s: Vector2 in split:
			var mn: Vector3
			var mx: Vector3
			if axis == "x":
				mn = Vector3(p, s.x, fixed - thick * 0.5)
				mx = Vector3(q, s.y, fixed + thick * 0.5)
			else:
				mn = Vector3(fixed - thick * 0.5, s.x, p)
				mx = Vector3(fixed + thick * 0.5, s.y, q)
			_box(parent, "%s_%02d" % [nm, part], mn, mx, mat_id)
			part += 1


func _kit_scene(piece: String) -> PackedScene:
	var path: String = "%s%s/%s.glb" % [KIT_DIR, piece, piece]
	if not _scene_cache.has(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			_errors.append("missing kit piece %s" % path)
		_scene_cache[path] = ps
	return _scene_cache[path]


func _prefab_scene(prefab: String) -> PackedScene:
	if _scene_cache.has(prefab):
		return _scene_cache[prefab]
	var cls: String = String(PREFAB_CLASSES.get(prefab, ""))
	var ps: PackedScene = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c["class"]) == cls:
			var path: String = String(c["path"]).get_basename() + ".tscn"
			if ResourceLoader.exists(path):
				ps = load(path) as PackedScene
	if ps == null:
		_errors.append("gameplay prefab `%s` (class %s) not found" % [prefab, cls])
	_scene_cache[prefab] = ps
	return ps


## Records a projected navmesh obstruction for a box (local AABB under xform).
func _obstruct(xform: Transform3D, box: AABB) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var lo: float = INF
	var hi: float = -INF
	for corner: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
		var lp: Vector3 = box.position + box.size * corner
		pts.append(xform * lp)
	for cy: float in [box.position.y, box.end.y]:
		var w: Vector3 = xform * Vector3(box.position.x, cy, box.position.z)
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
	_obstructions.append([pts, lo, hi - lo])


func _obstruct_circle(center: Vector3, radius: float, height: float) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	for i: int in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(center + Vector3(cos(a), 0.0, sin(a)) * radius)
	_obstructions.append([pts, center.y, height])


# --- Building shell ---------------------------------------------------------------------------

func _build_shell(geo: Node3D) -> void:
	var bld: Node3D = _add(geo, _node3d("Building")) as Node3D
	var walls: Node3D = _add(bld, _node3d("ExteriorWalls")) as Node3D
	for w: Array in L.EXT_WALLS:
		# Two half-thickness skins: exterior face `wall_ext`, room face `wall` (kit convention).
		var fixed: float = float(w[2])
		var centre: float = 6.0 if String(w[1]) == "x" else 9.0
		var out_sign: float = -1.0 if fixed < centre else 1.0
		var q: float = L.EXT_T * 0.25
		# Corners: x-walls own the outer corner squares, z-walls' outer skins close the gap
		# between them; inner skins stop at the inner corner.
		var h: float = L.EXT_T * 0.5
		var along_x: bool = String(w[1]) == "x"
		var o0: float = float(w[3]) - (0.0 if along_x else h)
		var o1: float = float(w[4]) + (0.0 if along_x else h)
		_wall(walls, String(w[0]) + "Out", String(w[1]), fixed + out_sign * q, o0, o1,
			h, Vector2(0.0, L.PARAPET_TOP), w[5], "wall_ext")
		var a0: float = float(w[3]) + (h if along_x else 0.0)
		var a1: float = float(w[4]) - (h if along_x else 0.0)
		_wall(walls, String(w[0]) + "In", String(w[1]), fixed - out_sign * q, a0, a1,
			h, Vector2(0.0, L.PARAPET_TOP), w[5], "wall")
	var iw: Node3D = _add(bld, _node3d("InteriorWalls")) as Node3D
	for w2: Array in L.INT_WALLS:
		_wall(iw, String(w2[0]), String(w2[1]), float(w2[2]), float(w2[3]), float(w2[4]), L.INT_T,
			Vector2(float(w2[5]), float(w2[6])), w2[7], "wall")
	var slabs: Node3D = _add(bld, _node3d("Slabs")) as Node3D
	for s: Array in L.SLABS:
		_box_a(slabs, String(s[0]), s[1], String(s[2]))
	var ceil: Node3D = _add(bld, _node3d("Ceilings")) as Node3D
	for c: Array in L.CEILINGS:
		_box_a(ceil, String(c[0]), c[1], "ceiling")
	_build_stair(bld)
	var rails: Node3D = _add(bld, _node3d("Railings")) as Node3D
	for r: Array in L.RAILINGS:
		_railing(rails, String(r[0]), _v3(r[1], 0), _v3(r[1], 3))
	var fe: Node3D = _add(bld, _node3d("FireEscape")) as Node3D
	_box_a(fe, "Landing", L.LANDING, "trim")
	_box(fe, "BracketW", Vector3(1.05, 3.6, -0.6), Vector3(1.15, 4.1, -0.2), "trim")
	_box(fe, "BracketE", Vector3(3.35, 3.6, -0.6), Vector3(3.45, 4.1, -0.2), "trim")
	_build_static_windows(bld)


## Railing: full-panel collision (blocks players and the navmesh) + top rail, mid rail and posts.
func _railing(parent: Node3D, nm: String, mn: Vector3, mx: Vector3) -> void:
	var body: Node3D = _box(parent, nm, mn, mx, "")
	body.set_meta(&"kind", "railing")
	var size: Vector3 = mx - mn
	var along_x: bool = size.x >= size.z
	var length: float = size.x if along_x else size.z
	var t: float = minf(size.x, size.z)
	for rail: Array in [["TopRail", size.y * 0.5 - 0.025], ["MidRail", 0.0]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = String(rail[0])
		mi.mesh = _box_mesh(Vector3(length, 0.05, t) if along_x else Vector3(t, 0.05, length), "trim")
		mi.position = Vector3(0.0, float(rail[1]), 0.0)
		_add(body, mi)
	var posts: int = maxi(2, int(ceil(length / 1.2)) + 1)
	for i: int in range(posts):
		var off: float = -length * 0.5 + 0.025 + (length - 0.05) * float(i) / float(posts - 1)
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "Post%d" % i
		post.mesh = _box_mesh(Vector3(0.05, size.y, t), "trim")
		post.position = Vector3(off, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, off)
		_add(body, post)


## U-stair: two straight flights (each its own `stairs` node, steps along local Z, solid stepped
## collision) and the half landing (plain geometry). Each step box reaches SEAM under its higher
## neighbour so no downward ray can slip through a seam between two boxes.
func _build_stair(bld: Node3D) -> void:
	var st: Dictionary = L.STAIR
	var rise: float = float(st["riser"])
	var tread: float = float(st["tread"])
	var n: int = int(st["risers_per_flight"])
	var lz: Array = st["landing_z"]
	var z_land: float = float(lz[1])
	var core: Node3D = _add(bld, _node3d("Stair")) as Node3D
	var rx0: Array = st["ret_x"]
	var lx: Array = st["landing_x"]
	_box(core, "HalfLanding", Vector3(float(lx[0]), 0.0, float(lz[0])),
		Vector3(float(lx[1]), rise * n, z_land), "stair")
	_box(core, "HalfLandingLip", Vector3(float(rx0[0]), 0.0, z_land), Vector3(float(rx0[1]), rise * n, z_land + SEAM), "stair")
	# Up-flight: risers 1..12, climbing toward -Z (north). Tread k (k < 12) spans
	# z [z_land + (11 - k) * tread, z_land + (12 - k) * tread] at height k * rise.
	var up: Node3D = _add(core, _node3d("FlightUp")) as Node3D
	up.set_meta(&"kind", "stairs")
	var ux: Array = st["up_x"]
	for k: int in range(1, n):
		var z0: float = z_land + float(n - 1 - k) * tread
		_box(up, "Step%02d" % k, Vector3(float(ux[0]), 0.0, z0 - SEAM), Vector3(float(ux[1]), rise * k, z0 + tread), "stair")
	# Return flight: risers 13..24 climbing toward +Z (south). Tread k spans
	# z [z_land + (k - 13) * tread, z_land + (k - 12) * tread] at height k * rise; over the janitor
	# closet (z >= g9_z) the steps stop at the closet ceiling.
	var ret: Node3D = _add(core, _node3d("FlightReturn")) as Node3D
	ret.set_meta(&"kind", "stairs")
	var rx: Array = st["ret_x"]
	var g9_z: float = float(st["g9_z"])
	var g9_top: float = float(st["g9_ceiling_top"])
	for k2: int in range(n + 1, 2 * n):
		var za: float = z_land + float(k2 - n - 1) * tread
		var zb: float = za + tread + SEAM
		var top: float = rise * k2
		if zb <= g9_z + 0.0001:
			_box(ret, "Step%02d" % k2, Vector3(float(rx[0]), 0.0, za), Vector3(float(rx[1]), top, zb), "stair")
		elif za >= g9_z - 0.0001:
			_box(ret, "Step%02d" % k2, Vector3(float(rx[0]), g9_top, za), Vector3(float(rx[1]), top, zb), "stair")
		else:
			_box(ret, "Step%02dA" % k2, Vector3(float(rx[0]), 0.0, za), Vector3(float(rx[1]), top, g9_z), "stair")
			_box(ret, "Step%02dB" % k2, Vector3(float(rx[0]), g9_top, g9_z), Vector3(float(rx[1]), top, zb), "stair")


## Static (non-interactive) glazing: kit window visual + a glass blocker filling the opening.
## Gameplay windows get the same blocker (see _build_windows) because the window prefab's
## GlassBody is a fixed 1.0 x 1.2 m panel.
func _build_static_windows(bld: Node3D) -> void:
	var gl: Node3D = _add(bld, _node3d("Glazing")) as Node3D
	for w: Array in L.WINDOWS:
		var piece: String = String(w[1])
		var pos: Vector3 = w[2]
		var yaw: float = float(w[3])
		_glass_blocker(gl, String(w[0]), piece, pos, yaw)
		if bool(w[4]):
			continue
		var ps: PackedScene = _kit_scene(piece)
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate() as Node3D
		inst.name = String(w[0])
		inst.position = pos
		inst.basis = _yaw_basis(yaw)
		_add(gl, inst)
	var bw: Dictionary = L.BREAKROOM_WINDOW
	_glass_blocker(gl, "BreakRoomWindow", String(bw["kit"]), bw["pos"], float(bw["yaw"]))


func _glass_blocker(parent: Node3D, nm: String, piece: String, pos: Vector3, yaw: float) -> void:
	var w: float = 3.0 if piece.contains("w300") else 1.0
	var h: float = 2.4 if piece.contains("h240") else 1.2
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm + "Blocker"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.basis = _yaw_basis(yaw)
	_add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(Vector3(w, h, 0.04))
	col.position = Vector3(0.0, h * 0.5, 0.0)
	_add(body, col)


# --- Site -------------------------------------------------------------------------------------

func _build_site(geo: Node3D) -> void:
	var site: Node3D = _add(geo, _node3d("Site")) as Node3D
	var ground: Node3D = _add(site, _node3d("Ground")) as Node3D
	for g: Array in L.GROUND:
		_box_a(ground, String(g[0]), g[1], String(g[2]))
	var blocks: Node3D = _add(site, _node3d("Blocks")) as Node3D
	for b: Array in L.BLOCKS:
		_box_a(blocks, String(b[0]), b[1], String(b[2]))
	var fences: Node3D = _add(site, _node3d("Closures")) as Node3D
	for f: Array in L.FENCES:
		_wall(fences, String(f[0]), String(f[1]), float(f[2]), float(f[3]), float(f[4]), 0.1,
			Vector2(float(f[5]), float(f[6])), f[7], String(f[8]))


# --- Props ------------------------------------------------------------------------------------

## Box prop: StaticBody3D root at the bottom-centre (meta kind / support), collision + mesh.
func _prop_box(parent: Node3D, nm: String, base: Vector3, size: Vector3, yaw: float, kind: String,
		support: bool, mat_id: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = _yaw_basis(yaw)
	body.set_meta(&"kind", kind)
	if support:
		body.set_meta(&"support", true)
	_add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(size)
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	_add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, mat_id)
	mi.position = col.position
	_add(body, mi)
	_obstruct(body.transform, AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size))
	return body


func _build_props(props: Node3D) -> void:
	var g: Node3D = _add(props, _node3d("Ground")) as Node3D
	var u: Node3D = _add(props, _node3d("Upper")) as Node3D
	var x: Node3D = _add(props, _node3d("Exterior")) as Node3D
	for p: Array in L.PROPS:
		var base: Vector3 = p[1]
		var parent: Node3D = g
		if base.y > 2.0:
			parent = u
		elif base.y < -0.01 or base.z < -0.1 or base.z > 12.1 or base.x > 18.1:
			parent = x
		_prop_box(parent, String(p[0]), base, p[2], float(p[3]), String(p[4]), bool(p[5]), String(p[6]))
	for c: Array in L.CHAIRS:
		var cp: Vector3 = c[1]
		_chair(g if cp.y < 2.0 else u, String(c[0]), cp, float(c[2]))
	_chandelier_plinth(g)
	for sl: Array in L.STREET_LAMPS:
		_street_lamp(x, String(sl[0]), sl[1], float(sl[2]))


func _chair(parent: Node3D, nm: String, base: Vector3, yaw: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = _yaw_basis(yaw)
	body.set_meta(&"kind", "chair")
	_add(parent, body)
	var size: Vector3 = Vector3(0.45, 0.85, 0.45)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(size)
	col.position = Vector3(0.0, size.y * 0.5, 0.0)
	_add(body, col)
	var seat: MeshInstance3D = MeshInstance3D.new()
	seat.name = "SeatMesh"
	seat.mesh = _box_mesh(Vector3(0.45, 0.45, 0.45), "prop")
	seat.position = Vector3(0.0, 0.225, 0.0)
	_add(body, seat)
	var back: MeshInstance3D = MeshInstance3D.new()
	back.name = "BackMesh"
	back.mesh = _box_mesh(Vector3(0.45, 0.4, 0.06), "prop")
	back.position = Vector3(0.0, 0.65, 0.195)
	_add(body, back)
	var m: Marker3D = Marker3D.new()
	m.name = "Seat"
	m.position = Vector3(0.0, 0.45, 0.0)
	_add(body, m)
	_obstruct(body.transform, AABB(Vector3(-0.225, 0.0, -0.225), size))


## Landmark 1: the circular chandelier display (2.4 m round glass case on a plinth).
func _chandelier_plinth(parent: Node3D) -> void:
	var ch: Dictionary = L.CHANDELIER
	var pos: Vector3 = ch["pos"]
	var r: float = float(ch["radius"])
	var ph: float = float(ch["plinth_h"])
	var gh: float = float(ch["glass_h"])
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ChandelierDisplay"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.set_meta(&"kind", "display_plinth")
	_add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = r
	cyl.height = ph + gh
	col.shape = cyl
	col.position = Vector3(0.0, (ph + gh) * 0.5, 0.0)
	_add(body, col)
	var plinth: MeshInstance3D = MeshInstance3D.new()
	plinth.name = "Plinth"
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = r
	pm.bottom_radius = r
	pm.height = ph
	pm.radial_segments = 32
	pm.material = _lib_mat("counter")
	plinth.mesh = pm
	plinth.position = Vector3(0.0, ph * 0.5, 0.0)
	_add(body, plinth)
	var glass: MeshInstance3D = MeshInstance3D.new()
	glass.name = "Glass"
	var gm: CylinderMesh = CylinderMesh.new()
	gm.top_radius = r - 0.05
	gm.bottom_radius = r - 0.05
	gm.height = gh
	gm.radial_segments = 32
	gm.material = _lib_mat("glass")
	glass.mesh = gm
	glass.position = Vector3(0.0, ph + gh * 0.5 + 0.002, 0.0)
	_add(body, glass)
	_obstruct_circle(pos, r, ph + gh)


func _street_lamp(parent: Node3D, nm: String, base: Vector3, yaw: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base
	body.basis = _yaw_basis(yaw)
	body.set_meta(&"kind", "street_lamp")
	_add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(Vector3(0.18, 6.0, 0.18))
	col.position = Vector3(0.0, 3.0, 0.0)
	_add(body, col)
	var pole: MeshInstance3D = MeshInstance3D.new()
	pole.name = "Pole"
	pole.mesh = _box_mesh(Vector3(0.18, 6.0, 0.18), "trim")
	pole.position = Vector3(0.0, 3.0, 0.0)
	_add(body, pole)
	var arm: MeshInstance3D = MeshInstance3D.new()
	arm.name = "Arm"
	arm.mesh = _box_mesh(Vector3(0.1, 0.1, 0.8), "trim")
	arm.position = Vector3(0.0, 5.95, -0.4)
	_add(body, arm)
	var head: MeshInstance3D = MeshInstance3D.new()
	head.name = "Head"
	head.mesh = _box_mesh(Vector3(0.3, 0.12, 0.6), "fixture")
	head.position = Vector3(0.0, 5.84, -0.6)
	head.set_meta(&"fixture", true)
	_add(body, head)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 5.6, -0.6)
	light.light_color = Color(0.95, 0.95, 1.0)
	light.light_energy = 1.6
	light.omni_range = 12.0
	_add(body, light)
	_obstruct(body.transform, AABB(Vector3(-0.09, 0.0, -0.09), Vector3(0.18, 6.0, 0.18)))


# --- Lighting ---------------------------------------------------------------------------------

func _build_lighting(lighting: Node3D) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = load(ENV_PATH) as Environment
	_add(lighting, we)
	var sun_ps: PackedScene = load(SUN_PATH) as PackedScene
	if sun_ps != null:
		var sun: Node3D = sun_ps.instantiate() as Node3D
		sun.name = "Sun"
		_add(lighting, sun)
	else:
		_errors.append("missing %s" % SUN_PATH)
	var fx: Node3D = _add(lighting, _node3d("Fixtures")) as Node3D
	for c: Array in L.CEILING_LIGHTS:
		_ceiling_light(fx, String(c[0]), c[1], c[2], float(c[3]), float(c[4]), Vector3(0.6, 0.05, 0.6))
	var ch: Dictionary = L.CHANDELIER
	var cpos: Vector3 = ch["pos"]
	_chandelier_ring(fx, Vector3(cpos.x, float(ch["ceiling"]), cpos.z))
	for w: Array in L.WALL_LIGHTS:
		_wall_light(fx, String(w[0]), w[1], float(w[2]), w[3], float(w[4]), float(w[5]), w[6])


## Ceiling-mounted fixture: pivot at the ceiling surface (top-centre), mesh just below, light under it.
func _ceiling_light(parent: Node3D, nm: String, pivot: Vector3, color: Color, energy: float, rng: float,
		size: Vector3) -> void:
	var root: Node3D = _node3d(nm, pivot)
	root.set_meta(&"mount", "ceiling")
	root.set_meta(&"fixture", true)
	root.set_meta(&"kind", "light_fixture")
	_add(parent, root)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Panel"
	mi.mesh = _box_mesh(size, "fixture")
	mi.position = Vector3(0.0, -size.y * 0.5 - 0.002, 0.0)
	_add(root, mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -0.25, 0.0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	_add(root, light)


## Landmark: brass-and-crystal ring chandelier over the display (ceiling-mounted).
func _chandelier_ring(parent: Node3D, pivot: Vector3) -> void:
	var root: Node3D = _node3d("ChandelierRing", pivot)
	root.set_meta(&"mount", "ceiling")
	root.set_meta(&"fixture", true)
	root.set_meta(&"kind", "light_fixture")
	_add(parent, root)
	var rod: MeshInstance3D = MeshInstance3D.new()
	rod.name = "Rod"
	rod.mesh = _box_mesh(Vector3(0.05, 0.5, 0.05), "trim")
	rod.position = Vector3(0.0, -0.252, 0.0)
	_add(root, rod)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 1.05
	tm.outer_radius = 1.25
	tm.rings = 32
	tm.ring_segments = 8
	tm.material = _lib_mat("fixture")
	ring.mesh = tm
	ring.position = Vector3(0.0, -0.6, 0.0)
	_add(root, ring)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -0.75, 0.0)
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 2.0
	light.omni_range = 6.0
	_add(root, light)


## Wall-mounted fixture/sign: pivot on the wall face (back-centre), -Z out of the wall.
func _wall_light(parent: Node3D, nm: String, pivot: Vector3, yaw: float, color: Color, energy: float,
		rng: float, size: Vector3) -> void:
	var root: Node3D = _node3d(nm, pivot)
	root.basis = _yaw_basis(yaw)
	root.set_meta(&"mount", "wall")
	root.set_meta(&"fixture", true)
	root.set_meta(&"kind", "fascia_sign" if nm.begins_with("Neon") else "light_fixture")
	_add(parent, root)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = _box_mesh(size, "neon" if nm.begins_with("Neon") else "fixture")
	mi.position = Vector3(0.0, 0.0, -size.z * 0.5 - 0.002)
	_add(root, mi)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, -0.1, -0.4)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	_add(root, light)


# --- Rooms and zones --------------------------------------------------------------------------

func _area_boxes(area: Area3D, boxes: Array) -> void:
	for i: int in range(boxes.size()):
		var b: Array = boxes[i]
		var mn: Vector3 = _v3(b, 0)
		var mx: Vector3 = _v3(b, 3)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Shape" if i == 0 else "Shape%d" % i
		col.shape = _box_shape(mx - mn)
		col.position = (mn + mx) * 0.5
		_add(area, col)


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
		_add(rooms, rv)
		_area_boxes(rv, r[4])


func _zone(parent: Node3D, nm: String, kind: String, zone_id: String, boxes: Array) -> MapZone:
	var z: MapZone = MapZone.new()
	z.name = nm
	z.kind = MapZone.Kind[kind]
	z.zone_id = StringName(zone_id)
	z.collision_layer = 1 << 9
	z.collision_mask = 0
	_add(parent, z)
	_area_boxes(z, boxes)
	return z


func _build_zones(zones: Node3D) -> void:
	for z: Array in L.ZONES:
		var mz: MapZone = _zone(zones, String(z[0]), String(z[1]), String(z[2]), z[3])
		if String(z[0]) == "BodyHideJanitor":
			mz.set_meta(&"capacity", 1)


# --- Patrols, spawns, tactical ----------------------------------------------------------------

func _build_patrols(patrols: Node3D) -> void:
	_patrol_graph(patrols, "Building", &"building", L.PATROL_POINTS_BUILDING, L.PATROL_EDGES_BUILDING)
	_patrol_graph(patrols, "Alley", &"alley", L.PATROL_POINTS_ALLEY, L.PATROL_EDGES_ALLEY)


func _patrol_graph(parent: Node3D, nm: String, graph_id: StringName, points: Dictionary, edges: Array) -> void:
	var g: PatrolGraph = PatrolGraph.new()
	g.name = nm
	g.graph_id = graph_id
	g.floor_index = 0
	_add(parent, g)
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
			p.basis = _yaw_basis(float(row[4]))
			p.face_marker_forward = true
		_add(g, p)
	var links: Dictionary = {}
	for e: Array in edges:
		for pair: Array in [[e[0], e[1]], [e[1], e[0]]]:
			var a: String = String(pair[0])
			var b: String = String(pair[1])
			if not points.has(a) or not points.has(b):
				_errors.append("patrol edge %s-%s: unknown point" % [a, b])
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


func _spawn(parent: Node3D, nm: String, kind: String, pos: Vector3, yaw: float, tags: Array, idle: String,
		graph: String) -> SpawnPoint:
	var sp: SpawnPoint = SpawnPoint.new()
	sp.name = nm
	sp.kind = SpawnPoint.Kind[kind]
	var tg: Array[StringName] = []
	for t: Variant in tags:
		tg.append(StringName(String(t)))
	sp.tags = tg
	sp.idle_activity = StringName(idle)
	sp.position = pos
	sp.basis = _yaw_basis(yaw)
	_add(parent, sp)
	if graph != "":
		sp.patrol_graph = sp.get_path_to(_root.get_node("Patrols/" + graph))
	return sp


func _build_spawns(spawns: Node3D) -> void:
	for p: Array in L.PLAYER_SPAWNS:
		_spawn(spawns, String(p[0]), "PLAYER", p[1], float(p[2]), p[3], "", "")
	for s: Array in L.NPC_SPAWNS:
		_spawn(spawns, String(s[0]), String(s[1]), s[2], float(s[3]), s[4], String(s[5]), String(s[6]))


func _build_tactical(tac: Node3D) -> void:
	for t: Array in L.TACTICAL:
		var tp: TacticalPoint = TacticalPoint.new()
		tp.name = String(t[0])
		tp.kind = TacticalPoint.Kind[String(t[1])]
		tp.position = t[2]
		tp.basis = _yaw_basis(float(t[3]))
		var tg: Array[StringName] = []
		for x: Variant in t[4]:
			tg.append(StringName(String(x)))
		tp.tags = tg
		tp.breachable = bool(t[5])
		_add(tac, tp)
	# Pre-planning drop points (P4 board; doc §Pre-planning).
	for pp: Array in [["PreplanBodyBagDrop", Vector3(10.5, 0.0, -2.2)], ["PreplanZipTiesDrop", Vector3(-2.0, 0.0, -1.0)]]:
		var m: Marker3D = Marker3D.new()
		m.name = String(pp[0])
		m.position = pp[1]
		m.add_to_group(G.PREPLAN_POINT, true)
		_add(tac, m)


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
		_add(cams, m)
		paths.append(NodePath("ReviewCameras/" + nm))
	_root.review_cameras = paths


# --- Gameplay prefabs -------------------------------------------------------------------------

## Instances a prefab under `parent` (all containers sit at the identity, so `pos` is world space).
## props: export -> value ("enum:KEY" looks the key up in the prefab script's enums).
## use_point: world floor point for the UsePoint (items on furniture, odd sill heights) or null.
func _prefab(parent: Node3D, prefab: String, nm: String, pos: Vector3, yaw: float, props: Dictionary = {},
		use_point: Variant = null, metas: Dictionary = {}) -> Node3D:
	var ps: PackedScene = _prefab_scene(prefab)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	inst.name = nm
	inst.position = pos
	inst.basis = _yaw_basis(yaw)
	for k: Variant in props:
		_set_prop(inst, String(k), props[k])
	for mk: Variant in metas:
		inst.set_meta(StringName(String(mk)), metas[mk])
	parent.add_child(inst)
	inst.owner = _root
	if use_point != null:
		_place_use_point(inst, use_point as Vector3)
	if prefab in ["safe", "display_case", "body_container", "secure_zone", "camera_station"]:
		_obstruct_prefab(inst)
	return inst


## Moves a prefab's UsePoint to a world floor point, -Z facing the object (Editable Children).
func _place_use_point(inst: Node3D, world: Vector3) -> void:
	var up: Node3D = inst.get_node_or_null("UsePoint") as Node3D
	if up == null:
		_errors.append("%s has no UsePoint" % inst.name)
		return
	var xf: Transform3D = _global_xform(inst)
	var to_obj: Vector3 = xf.origin - world
	to_obj.y = 0.0
	var g: Transform3D = Transform3D(Basis.looking_at(to_obj.normalized(), Vector3.UP), world)
	up.transform = xf.affine_inverse() * g
	_root.set_editable_instance(inst, true)


func _global_xform(n: Node3D) -> Transform3D:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != _root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _obstruct_prefab(inst: Node3D) -> void:
	var base: Transform3D = _global_xform(inst)
	for c: Node in inst.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c
		var body: Node = cs.get_parent()
		if not (body is StaticBody3D) or not (cs.shape is BoxShape3D):
			continue
		var rel: Transform3D = cs.transform
		var p: Node = body
		while p != null and p != inst:
			rel = (p as Node3D).transform * rel
			p = p.get_parent()
		var sz: Vector3 = (cs.shape as BoxShape3D).size
		_obstruct(base * rel, AABB(-sz * 0.5, sz))


func _set_prop(inst: Node, prop: String, value: Variant) -> void:
	var found: bool = false
	for p: Dictionary in inst.get_property_list():
		if String(p["name"]) == prop:
			found = true
			break
	if not found:
		_errors.append("%s has no property `%s`" % [inst.name, prop])
		return
	if value is String and String(value).begins_with("enum:"):
		value = _enum_value(inst, String(value).substr(5))
	inst.set(prop, value)


func _enum_value(inst: Node, key: String) -> int:
	var scr: Script = inst.get_script() as Script
	if scr != null:
		for c: Variant in scr.get_script_constant_map().values():
			if c is Dictionary and (c as Dictionary).has(key):
				return int((c as Dictionary)[key])
	_errors.append("enum key %s not found on %s" % [key, inst.name])
	return 0


func _build_gameplay(gp: Node3D) -> void:
	var doors: Node3D = _add(gp, _node3d("Doors")) as Node3D
	for d: Array in L.DOORS:
		var props: Dictionary = {"lock": "enum:" + String(d[4]), "swing": "enum:" + String(d[5]),
			"visual_scene": _kit_scene(String(d[1]))}
		if String(d[6]) != "":
			props["objective_tag"] = StringName(String(d[6]))
		var metas: Dictionary = {"kind": "door", "swing_side": "back"}
		var extra: Dictionary = d[7]
		if bool(extra.get("service", false)):
			metas["service"] = true
		if bool(extra.get("fire_exit", false)):
			metas["fire_exit"] = true
		if bool(extra.get("suspicious_when_open", false)):
			props["suspicious_when_open"] = true
		if String(d[1]).contains("service"):
			props["width_m"] = 1.1
		_prefab(doors, "door", String(d[0]), d[2], float(d[3]), props, null, metas)
	var wins: Node3D = _add(gp, _node3d("Windows")) as Node3D
	for w: Array in L.WINDOWS:
		if not bool(w[4]):
			continue
		var pos: Vector3 = w[2]
		var yaw: float = float(w[3])
		var front: Vector3 = _yaw_basis(yaw) * Vector3.FORWARD
		_prefab(wins, "window", String(w[0]), pos, yaw,
			{"breakable": true, "openable": false, "visual_scene": _kit_scene(String(w[1]))},
			Vector3(pos.x, 0.0, pos.z) + front * 0.7, {"kind": "window"})
	_build_workshop(gp)
	_build_cases(gp)
	_build_misc(gp)


func _build_workshop(gp: Node3D) -> void:
	var ws: Node3D = _add(gp, _node3d("Workshop")) as Node3D
	var safe: Node3D = _prefab(ws, "safe", "WorkshopSafe", Vector3(6.5, 0.0, 0.56), 180.0,
		{"size": "enum:LARGE", "methods": [&"drill"] as Array[StringName], "objective_tag": &"safe"})
	if safe != null:
		_prefab(safe, "drill_point", "SafeDrill", Vector3(0.2, 1.0, -0.36), 180.0,
			{"device": "enum:DRILL", "target": NodePath(".."), "objective_tag": &"safe_drill"})
		var reader: Node3D = _prefab(ws, "keycard_reader", "SafeKeycardReader", Vector3(7.3, 1.2, 0.2), 180.0,
			{"objective_tag": &"safe_reader"}, null, {"mount": "wall", "kind": "keycard_reader"})
		if reader != null:
			var targets: Array[NodePath] = [reader.get_path_to(safe)]
			reader.set(&"targets", targets)
	_prefab(ws, "loot_spawn", "SafeLoot", Vector3(6.5, 0.0, 1.2), 180.0,
		{"loot_id": &"loot.jewelry", "count": 4, "objective_tag": &"safe_loot"})


func _build_cases(gp: Node3D) -> void:
	var cases: Node3D = _add(gp, _node3d("DisplayCases")) as Node3D
	var jewelry: StringName = &"loot.jewelry"
	var rows: Array = [
		["WallCaseA", Vector3(0.51, 0.0, 8.0), -90.0], ["WallCaseB", Vector3(0.51, 0.0, 9.5), -90.0],
		["WallCaseC", Vector3(0.51, 0.0, 11.0), -90.0], ["IslandCaseA", Vector3(3.6, 0.0, 10.2), 0.0],
		["IslandCaseB", Vector3(9.8, 0.0, 8.6), 0.0], ["RearIslandCase", Vector3(9.0, 0.0, 6.81), 180.0],
		["SalonCaseA", Vector3(14.8, 0.0, 8.4), 180.0], ["SalonCaseB", Vector3(16.4, 0.0, 8.4), 180.0],
	]
	for r: Array in rows:
		_prefab(cases, "display_case", String(r[0]), r[1], float(r[2]),
			{"loot_id": jewelry, "glass_breaks_alarm": false}, null, {"kind": "display_case"})


func _build_misc(gp: Node3D) -> void:
	var misc: Node3D = _add(gp, _node3d("Misc")) as Node3D
	_prefab(misc, "small_loot", "RegisterCash", Vector3(2.6, 0.9, 7.4), 0.0,
		{"loot_id": &"loot.cash", "value": 800}, Vector3(2.6, 0.0, 6.75))
	_prefab(misc, "phone", "PhoneCounter", Vector3(4.4, 0.9, 7.4), 0.0, {}, Vector3(4.4, 0.0, 6.75))
	_prefab(misc, "phone", "PhoneAdmin", Vector3(4.6, L.UPPER + 0.75, 8.85), 0.0, {},
		Vector3(4.6, L.UPPER, 8.15))
	_prefab(misc, "alarm_button", "AlarmBackDoor", Vector3(2.5, 1.2, 0.2), 180.0, {}, null,
		{"mount": "wall", "kind": "alarm_button"})
	_prefab(misc, "alarm_button", "AlarmSecurity", Vector3(10.4, L.UPPER + 1.2, 1.5), 90.0, {}, null,
		{"mount": "wall", "kind": "alarm_button"})
	_prefab(misc, "body_container", "DumpsterA", Vector3(7.0, 0.0, -0.71), 0.0, {"capacity": 2}, null,
		{"kind": "dumpster"})
	_prefab(misc, "body_container", "DumpsterB", Vector3(9.1, 0.0, -0.71), 0.0, {"capacity": 2}, null,
		{"kind": "dumpster"})
	_prefab(misc, "ladder", "FireEscapeLadder", Vector3(1.45, 0.0, -1.45), 0.0, {"height_m": 4.2}, null,
		{"kind": "ladder"})
	var station: Node3D = _prefab(misc, "camera_station", "CameraStation", Vector3(6.01, L.UPPER, 2.0), -90.0,
		{}, null, {"kind": "camera_station"})
	if station != null:
		station.set(&"operator_spawn", station.get_path_to(_root.get_node("Spawns/CameraOperatorSeat")))


# --- Variants ---------------------------------------------------------------------------------

func _slot(parent: Node3D, group: String, slot_id: String, weight: float, params: Dictionary = {}) -> VariantSlot:
	var vs: VariantSlot = VariantSlot.new()
	vs.name = "Slot_" + slot_id
	vs.slot_group = StringName(group)
	vs.slot_id = StringName(slot_id)
	vs.weight = weight
	vs.params = params
	_add(parent, vs)
	return vs


func _group(parent: Node3D, group: String) -> Node3D:
	return _add(parent, _node3d("Group_" + group)) as Node3D


func _build_variants(variants: Node3D) -> void:
	_variants_guards(variants)
	_variants_doors_windows(variants)
	_variants_keycard(variants)
	_variants_staff(variants)
	_variants_loot_escape(variants)
	_variants_customers(variants)
	_variants_rare(variants)
	_variants_p2(variants)


func _variants_guards(variants: Node3D) -> void:
	var g: Node3D = _group(variants, "guard_post")
	var boh: VariantSlot = _slot(g, "guard_post", "rover_boh", 1.0)
	_spawn(boh, "GuardRoverBOH", "GUARD", Vector3(9.0, 0.0, 5.25), 90.0, ["guard_rover_boh"], "", "Building")
	var upr: VariantSlot = _slot(g, "guard_post", "rover_upper", 1.0)
	_spawn(upr, "GuardRoverUpper", "GUARD", Vector3(11.5, L.UPPER, 5.25), 90.0, ["guard_rover_upper"], "", "Building")
	var smk: VariantSlot = _slot(g, "guard_post", "alley_smoker", 1.0)
	_spawn(smk, "GuardAlleySmoker", "GUARD", Vector3(4.6, 0.0, -1.9), 0.0, ["guard_alley_smoker"], "", "Alley")


func _variants_doors_windows(variants: Node3D) -> void:
	var bd: Node3D = _group(variants, "back_door")
	_slot(bd, "back_door", "back_propped", 0.3, {"door": "Gameplay/Doors/BackDoor", "propped": true})
	_slot(bd, "back_door", "back_locked", 0.7, {"door": "Gameplay/Doors/BackDoor", "lock": "lockpick"})
	var ow: Node3D = _group(variants, "open_window")
	var bw: Dictionary = L.BREAKROOM_WINDOW
	var wpos: Vector3 = bw["pos"]
	var kit: PackedScene = _kit_scene(String(bw["kit"]))
	var open: VariantSlot = _slot(ow, "open_window", "ow_breakroom_open", 0.45)
	_prefab(open, "window", "BreakRoomWindow", wpos, float(bw["yaw"]),
		{"breakable": true, "openable": true, "visual_scene": kit, "objective_tag": &"breakroom_window"},
		null, {"kind": "window"})
	var link: NavigationLink3D = NavigationLink3D.new()
	link.name = "WindowLink"
	link.bidirectional = true
	link.navigation_layers = 1
	link.start_position = Vector3(wpos.x, L.UPPER, -0.8)
	link.end_position = Vector3(wpos.x, L.UPPER, 0.9)
	_add(open, link)
	var latched: VariantSlot = _slot(ow, "open_window", "ow_breakroom_latched", 0.55)
	_prefab(latched, "window", "BreakRoomWindow", wpos, float(bw["yaw"]),
		{"breakable": true, "openable": false, "visual_scene": kit, "objective_tag": &"breakroom_window"},
		null, {"kind": "window"})
	var sal: Node3D = _group(variants, "salon")
	var box: Array = [[13.1, -0.2, 6.1, 17.9, 3.2, 11.9]]
	var so: VariantSlot = _slot(sal, "salon", "salon_open", 0.5, {"door": "Gameplay/Doors/SalonDoor", "locked": false})
	_zone(so, "SalonPublic", "PUBLIC", "salon", box)
	var sl: VariantSlot = _slot(sal, "salon", "salon_locked", 0.5, {"door": "Gameplay/Doors/SalonDoor", "locked": true})
	_zone(sl, "SalonRestricted", "RESTRICTED", "salon", box)


func _variants_keycard(variants: Node3D) -> void:
	var kc: Node3D = _group(variants, "keycard")
	var rows: Array = [
		["kc_counter", 1.0, Vector3(3.2, 0.9, 7.4), 0.0, Vector3(3.2, 0.0, 6.75)],
		["kc_manager", 1.0, Vector3(9.2, L.UPPER + 0.75, 8.75), 0.0, Vector3(9.2, L.UPPER, 8.05)],
		["kc_security", 1.0, Vector3(10.15, L.UPPER + 1.0, 3.4), 90.0, Vector3(9.45, L.UPPER, 3.4)],
		["kc_breakroom", 1.0, Vector3(0.46, L.UPPER + 1.2, 2.6), -90.0, Vector3(1.2, L.UPPER, 2.6)],
		["kc_jeweler", 0.75, Vector3(9.75, 0.9, 0.75), 0.0, Vector3(9.75, 0.0, 1.45)],
	]
	for r: Array in rows:
		var s: VariantSlot = _slot(kc, "keycard", String(r[0]), float(r[1]))
		_prefab(s, "keycard_pickup", "Keycard", r[2], float(r[3]), {"objective_tag": &"keycard"}, r[4])
		if String(r[0]) == "kc_jeweler":
			# The card on the bench implies the jeweler is working (doc: kc_jeweler requires jw_working).
			_spawn(s, "Jeweler", "CIVILIAN", Vector3(8.5, 0.0, 1.45), 0.0, ["civ_staff_workshop"], "desk_work", "")


func _variants_staff(variants: Node3D) -> void:
	var jw: Node3D = _group(variants, "jeweler")
	var work: VariantSlot = _slot(jw, "jeweler", "jw_working", 0.6)
	_spawn(work, "Jeweler", "CIVILIAN", Vector3(8.5, 0.0, 1.45), 0.0, ["civ_staff_workshop"], "desk_work", "")
	_slot(jw, "jeweler", "jw_gone", 0.4)
	var ac: Node3D = _group(variants, "admin_clerk")
	var cin: VariantSlot = _slot(ac, "admin_clerk", "clerk_in", 0.5)
	_spawn(cin, "AdminClerk", "CIVILIAN", Vector3(1.6, L.UPPER, 9.8), 0.0, ["civ_staff_admin"], "desk_work", "")
	_slot(ac, "admin_clerk", "clerk_out", 0.5)


func _variants_loot_escape(variants: Node3D) -> void:
	var xl: Node3D = _group(variants, "extra_loot")
	var dl: VariantSlot = _slot(xl, "extra_loot", "xl_delivery", 0.25)
	_prefab(dl, "loot_spawn", "DeliveryBags", Vector3(4.4, 0.0, 1.0), 90.0,
		{"loot_id": &"loot.jewelry", "count": 2, "objective_tag": &"delivery_loot"})
	var mc: VariantSlot = _slot(xl, "extra_loot", "xl_manager_cash", 0.35)
	for i: int in range(3):
		var z: float = 9.0 + 0.5 * float(i)
		_prefab(mc, "small_loot", "ManagerCash%d" % (i + 1), Vector3(7.36, L.UPPER + 0.8, z), -90.0,
			{"loot_id": &"loot.cash", "value": 1000}, Vector3(8.05, L.UPPER, z))
	_slot(xl, "extra_loot", "xl_none", 0.4)
	var esc: Node3D = _group(variants, "escape")
	var e1: VariantSlot = _slot(esc, "escape", "esc_alley_west", 0.65, {"label": "E1"})
	_prefab(e1, "secure_zone", "VanSecureE1", Vector3(-8.5, 0.0, -3.2), -90.0, {},
		null, {"kind": "vehicle"})
	# Escape area: the alley behind the van, rear bumper to the fire-escape ladder (5.8 x 7 m).
	_prefab(e1, "escape_zone", "VanEscapeE1", Vector3(-2.4, 0.0, -3.2), -90.0,
		{"objective_tag": &"escape_van", "escape_type": &"van", "zone_size_m": Vector3(5.8, 3.0, 7.0)})
	var e2: VariantSlot = _slot(esc, "escape", "esc_pell", 0.35, {"label": "E2"})
	_prefab(e2, "secure_zone", "VanSecureE2", Vector3(22.4, L.ROAD_Y, 7.0), 0.0, {"zone_size_m": Vector3(6.0, 3.0, 8.0)},
		null, {"kind": "vehicle"})
	# Escape area: Pell St carriageway behind the van (7.8 x 4 m, kerb to kerb).
	_prefab(e2, "escape_zone", "VanEscapeE2", Vector3(25.2, L.ROAD_Y, 2.3), 0.0,
		{"objective_tag": &"escape_van", "escape_type": &"van", "zone_size_m": Vector3(7.8, 3.0, 4.0)})


func _variants_customers(variants: Node3D) -> void:
	var cg: Node3D = _group(variants, "customers")
	var rows: Array = [
		["cust_1", Vector3(1.7, 0.0, 9.5), 90.0, "browse"], ["cust_2", Vector3(3.5, 0.0, 8.45), 0.0, "queue"],
		["cust_3", Vector3(5.0, 0.0, 10.75), 180.0, "sit"], ["cust_4", Vector3(9.8, 0.0, 9.65), 0.0, "browse"],
		["cust_5", Vector3(7.0, 0.0, 10.75), 0.0, "browse"],
	]
	for r: Array in rows:
		var s: VariantSlot = _slot(cg, "customers", String(r[0]), 1.0)
		_spawn(s, "Customer", "CIVILIAN", r[1], float(r[2]), ["civ_customer"], String(r[3]), "")


func _variants_rare(variants: Node3D) -> void:
	var mg: Node3D = _group(variants, "manager_present")
	_slot(mg, "manager_present", "mgr_out", 1.0)
	var mi: VariantSlot = _slot(mg, "manager_present", "mgr_in", 0.0, {"alarm_button": "Gameplay/Misc/AlarmSecurity"})
	_spawn(mi, "Manager", "CIVILIAN", Vector3(9.5, L.UPPER, 9.85), 0.0, ["civ_staff_manager"], "phone", "")
	var ss: Node3D = _group(variants, "safe_state")
	_slot(ss, "safe_state", "safe_closed", 1.0)
	_slot(ss, "safe_state", "safe_open", 0.0, {"safe": "Gameplay/Workshop/WorkshopSafe"})
	var es: Node3D = _group(variants, "estate")
	_slot(es, "estate", "estate_none", 1.0)
	var eb: VariantSlot = _slot(es, "estate", "estate_bag", 0.0)
	_prefab(eb, "loot_spawn", "EstateBag", Vector3(14.1, 0.0, 7.4), -90.0,
		{"loot_id": &"loot.jewelry", "count": 1, "objective_tag": &"estate_loot"})


## P2 rows of the variable table (designed now, rule pick 0 until P2 enables them).
func _variants_p2(variants: Node3D) -> void:
	var cams: Dictionary = {
		"C1": [Vector3(12.5, 3.0, 6.1), 180.0], "C2": [Vector3(0.6, 3.0, 11.8), 0.0],
		"C3": [Vector3(17.8, 2.6, 5.25), 90.0], "C4": [Vector3(5.0, 3.0, -0.2), 0.0],
		"C5": [Vector3(9.5, 2.6, 4.4), 0.0], "C6": [Vector3(0.2, L.UPPER + 2.6, 5.25), -90.0],
	}
	var sets: Array = [["cam_a", ["C1", "C3", "C4"]], ["cam_b", ["C2", "C3", "C5"]], ["cam_c", ["C1", "C2", "C6"]]]
	var cg: Node3D = _group(variants, "camera")
	for s: Array in sets:
		var slot: VariantSlot = _slot(cg, "camera", String(s[0]), 1.0, {"phase": 2})
		for cid: Variant in s[1]:
			# Mount points only: the security_camera prefab's collision box reaches 0.025 m behind
			# its back-centre pivot, so a flush wall mount clips the wall (reported to ENV A).
			var row: Array = cams[cid]
			var m: Marker3D = Marker3D.new()
			m.name = "CameraMount" + String(cid)
			m.position = row[0]
			m.basis = _yaw_basis(float(row[1]))
			m.set_meta(&"camera_id", String(cid))
			m.set_meta(&"mount", "wall")
			m.set_meta(&"fov_deg", 60.0)
			m.set_meta(&"range_m", 20.0)
			m.add_to_group(G.CAMERA_SLOT, true)
			_add(slot, m)
	var sr: Node3D = _group(variants, "security_room_staffed")
	_slot(sr, "security_room_staffed", "sec_staffed", 0.6,
		{"phase": 2, "operator_spawn": "Spawns/CameraOperatorSeat", "station": "Gameplay/Misc/CameraStation"})
	_slot(sr, "security_room_staffed", "sec_empty", 0.4, {"phase": 2})
	var cn: Node3D = _group(variants, "code_note")
	var notes: Array = [
		["code_admin", Vector3(3.7, L.UPPER + 0.75, 8.85), Vector3(3.7, L.UPPER, 8.15)],
		["code_breakroom", Vector3(3.4, L.UPPER + 0.75, 2.5), Vector3(4.15, L.UPPER, 2.5)],
		["code_jeweler_notebook", Vector3(8.2, 0.9, 0.75), Vector3(8.2, 0.0, 1.45)],
	]
	for n: Array in notes:
		var slot2: VariantSlot = _slot(cn, "code_note", String(n[0]), 1.0, {"phase": 2})
		_prefab(slot2, "code_note", "CodeNote", n[1], 0.0, {"code_group": &"glasshouse_safe"}, n[2])


func _build_nav_links(nav: NavigationRegion3D) -> void:
	# Fire-escape ladder: alley floor <-> landing (climb; ENV A ladder movement is M2).
	var link: NavigationLink3D = NavigationLink3D.new()
	link.name = "FireEscapeLadderLink"
	link.bidirectional = true
	link.navigation_layers = 1
	link.start_position = Vector3(1.45, 0.0, -2.1)
	link.end_position = Vector3(1.45, L.UPPER, -0.9)
	_add(nav, link)


# --- Navigation bake --------------------------------------------------------------------------

## Bakes the walkable navmesh (heist_map.md §3 v1.1: agent radius 0.3, height 1.8, climb 0.3,
## slope 40, cell 0.1 / 0.1) from the Geometry colliders. Props and prefab bodies are projected
## obstructions, so no navmesh is generated on top of furniture or vans. Doors stay open.
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
	holder.add_child(_root.get_node("Geometry").duplicate())
	get_root().add_child(holder)
	await physics_frame
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, holder)
	for o: Array in _obstructions:
		src.add_projected_obstruction(o[0], float(o[1]), float(o[2]), false)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	holder.queue_free()
	await process_frame
	nav.navigation_mesh = nm
	return nm.get_polygon_count()
