## Safehouse ("The Press") G1 greybox generator (C4-02). Owner: ENV C. Writes SCENE_PATH (see there).
## Regenerate (deterministic; never hand-edit the output):
##   /opt/godot/godot --headless --path game --script res://world/hub/safehouse/greybox/build_safehouse.gd \
##     -- [--out=<path>]
## Data: safehouse_layout.gd (from the G0, docs/design/heists/safehouse.md). Contract: docs/contracts/hub_map.md v1.2
## (root SafehouseMap, a data-only HeistMap: no HeistDef, never on the Board). Copy-adapted from the Rolling Thunder
## generator helpers (rt_builder_base.gd / rt_shell.gd / build_greybox.gd; D-147 reuse-first, the chains are not
## shared code). Built: the shell (slab, walls with every opening, closed exterior leaves, frosted panes, roofs,
## ceilings, the hall's rooflight wells), RoomVolumes, the 9 stations (ENV A's hub_station prefab, greybox bodies
## under each Visual, UsePoint, StationCam), PLAYER spawns + return markers, review cameras, the crew van stand-in,
## the night environment, Audio/Jukebox (MusicDirector, listen_to_event_bus off) and the navmesh. Validate with
## validate_level --scene=<SCENE_PATH> --profile=hub (tools/levelcheck/validate_all.sh --hub).
extends SceneTree

const L: GDScript = preload("res://world/hub/safehouse/greybox/safehouse_layout.gd")
## Loaded at run time (both reach autoloads, which a --script entry point cannot compile against).
const MAP_SCRIPT: String = "res://world/hub/safehouse_map.gd"
const MUSIC_DIRECTOR: String = "res://world/audio/music_director.gd"
## Staged off hub_map's `res://world/hub/safehouse/safehouse.tscn` until ENV B's 2D-hub tests pin the menu hub
## (SafehouseHost enters any scene at that path, so B's 2D-hub flows would turn 3D); then this becomes that path.
const SCENE_PATH: String = "res://world/hub/safehouse/safehouse_g1.tscn"
const DNC: GDScript = preload("res://world/heists/shared/door_nav_clearance.gd")
## The station art is the greybox body under Visual (as RT's truck saw points: no placeholder).
const EMPTY_VISUAL: String = "res://world/heists/glasshouse/art/gh_empty.tscn"
const STATION_CLASS: String = "HubStationPrefab"
const MAT_DIR: String = "res://world/materials/"
## Greybox surface classes -> library material (the bullet surface follows the material, surface_map.json).
const CLASS_MAT: Dictionary = {
	"wall": "grey_wall", "wall_ext": "grey_wall_ext", "floor": "grey_floor", "roof": "grey_floor",
	"ceiling": "grey_ceiling", "glass": "grey_glass", "glass_frosted": "grey_glass", "counter": "grey_counter",
	"prop": "grey_prop", "trim": "grey_trim", "door": "grey_door",
}

var map_root: HeistMap = null
var errors: PackedStringArray = PackedStringArray()
## Projected nav obstructions [corners, elevation, height] for the bodies outside Geometry (stations, props).
var obstructions: Array[Array] = []
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}
var _mat_cache: Dictionary = {}


func _initialize() -> void:
	_build.call_deferred()


static func _scene_out() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			return a.trim_prefix("--out=")
	return SCENE_PATH


func _build() -> void:
	var out: String = _scene_out()
	var old_uid: String = _read_uid(out)
	map_root = (load(MAP_SCRIPT) as GDScript).new() as HeistMap
	map_root.name = "Safehouse"
	map_root.floor_heights = PackedFloat32Array(L.FLOOR_HEIGHTS)
	map_root.floor_names = PackedStringArray(L.FLOOR_NAMES)
	for nm: String in ["Geometry", "Props", "Lighting"]:
		add(map_root, node3d(nm))
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	nav.navigation_layers = 1
	add(map_root, nav)
	for nm2: String in ["Rooms", "Spawns", "Stations", "ReviewCameras", "Audio"]:
		add(map_root, node3d(nm2))
	build_shell(n("Geometry"))
	build_rooms(n("Rooms"))
	build_spawns(n("Spawns"))
	build_stations(n("Stations"))
	build_props(n("Props"))
	build_review_cameras(n("ReviewCameras"))
	build_environment(n("Lighting"))
	build_audio(n("Audio"))
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
	normalize_scene(out, old_uid)
	print("safehouse: saved %s (navmesh polygons: %d)" % [out, polys])
	quit(0)


func _fail(msg: String) -> void:
	push_error("safehouse: " + msg)
	if map_root != null and is_instance_valid(map_root):
		map_root.free()
	quit(1)


# --- Shell ------------------------------------------------------------------------------------------

func build_shell(geo: Node3D) -> void:
	var bld: Node3D = add(geo, node3d("Building")) as Node3D
	var ground: Array = L.GROUND
	box(add(bld, node3d("Ground")) as Node3D, "Slab", v3(ground[0]), v3(ground[1]), "floor")
	var walls_n: Node3D = add(bld, node3d("Walls")) as Node3D
	for w: Array in L.WALLS:
		wall(walls_n, String(w[0]), String(w[1]), float(w[2]), float(w[3]), float(w[4]), float(w[5]),
			Vector2(float(w[6]), float(w[7])), w[9], String(w[8]))
	var fills: Node3D = add(bld, node3d("Fills")) as Node3D
	for f: Array in L.FILLS:
		box(fills, String(f[0]), v3(f[1]), v3(f[2]), String(f[3]))
	var roofs: Node3D = add(bld, node3d("Roofs")) as Node3D
	for s: Array in L.ROOFS:
		_slab(roofs, String(s[0]), s[1], s[2], float(s[3]), float(s[4]), String(s[5]))
	var ceils: Node3D = add(bld, node3d("Ceilings")) as Node3D
	for c: Array in L.CEILINGS:
		_slab(ceils, String(c[0]), c[1], c[2], float(c[3]), float(c[3]) + L.CEIL_T, "ceiling")
	var wells: Node3D = add(bld, node3d("Rooflights")) as Node3D
	var lo: float = float(L.CEILINGS[1][3]) + L.CEIL_T
	var hi: float = float(L.ROOFS[0][3])
	var t: float = L.WELL_T
	for i: int in range(L.ROOFLIGHTS.size()):
		var r: Array = L.ROOFLIGHTS[i]
		var x0: float = float(r[0])
		var z0: float = float(r[1])
		var x1: float = float(r[2])
		var z1: float = float(r[3])
		var nm: String = "Rooflight%d" % (i + 1)
		box(wells, nm + "WellN", Vector3(x0 - t, lo, z0 - t), Vector3(x1 + t, hi, z0), "ceiling")
		box(wells, nm + "WellS", Vector3(x0 - t, lo, z1), Vector3(x1 + t, hi, z1 + t), "ceiling")
		box(wells, nm + "WellW", Vector3(x0 - t, lo, z0), Vector3(x0, hi, z1), "ceiling")
		box(wells, nm + "WellE", Vector3(x1, lo, z0), Vector3(x1 + t, hi, z1), "ceiling")
		box(wells, nm + "Glass", Vector3(x0, L.ROOFLIGHT_GLASS_Y.x, z0), Vector3(x1, L.ROOFLIGHT_GLASS_Y.y, z1), "glass")


## A slab [x0, z0, x1, z1] minus holes, y0..y1.
func _slab(parent: Node3D, nm: String, outer: Array, holes: Array, y0: float, y1: float, cls: String) -> void:
	var rects: Array = rects_minus(outer, holes)
	for i: int in range(rects.size()):
		var r: Array = rects[i]
		var leaf: String = nm if rects.size() == 1 else "%s_%02d" % [nm, i]
		box(parent, leaf, Vector3(float(r[0]), y0, float(r[1])), Vector3(float(r[2]), y1, float(r[3])), cls)


# --- Rooms, spawns, stations, props, cameras --------------------------------------------------------

func build_rooms(rooms: Node3D) -> void:
	for r: Array in L.ROOMS:
		var rv: RoomVolume = RoomVolume.new()
		rv.name = "Room" + String(r[0])
		rv.room_id = StringName(String(r[0]))
		rv.purpose = StringName(String(r[1]))
		rv.dressing_kit = StringName(String(r[2]))
		rv.floor_index = 0
		rv.collision_layer = 1 << 9
		rv.collision_mask = 0
		rv.monitoring = false
		add(rooms, rv)
		var b: Array = r[3]
		var mn: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
		var mx: Vector3 = Vector3(float(b[3]), float(b[4]), float(b[5]))
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "Shape"
		col.shape = _box_shape(mx - mn)
		col.position = (mn + mx) * 0.5
		add(rv, col)


func build_spawns(spawns: Node3D) -> void:
	for s: Array in L.SPAWNS:
		var sp: SpawnPoint = SpawnPoint.new()
		sp.name = String(s[0])
		sp.kind = SpawnPoint.Kind.PLAYER
		var tg: Array[StringName] = []
		for tag: Variant in s[3]:
			tg.append(StringName(String(tag)))
		sp.tags = tg
		sp.transform = Transform3D(yaw_basis(float(s[2])), v3(s[1]))
		add(spawns, sp)


## The 9 stations: ENV A's hub_station prefab named by id, station_id set, the greybox body under Visual (so the
## interaction's line of sight counts it as the station's own), UsePoint at the G0 distance, a StationCam marker.
func build_stations(holder: Node3D) -> void:
	var ps: PackedScene = _class_scene(STATION_CLASS)
	if ps == null:
		return
	var empty: PackedScene = load(EMPTY_VISUAL) as PackedScene
	for s: Array in L.STATIONS:
		var id: String = String(s[0])
		var st: Node3D = ps.instantiate() as Node3D
		st.name = id
		add(holder, st)
		map_root.set_editable_instance(st, true)
		st.set(&"station_id", StringName(id))
		st.set(&"visual_scene", empty)
		var xf: Transform3D = Transform3D(yaw_basis(float(s[2])), v3(s[1]))
		st.transform = xf
		if id in L.WALL_MOUNTED:
			st.set_meta(&"mount", "wall")
		var up: Marker3D = st.get_node_or_null("UsePoint") as Marker3D
		var it: Node3D = st.get_node_or_null("Interactable") as Node3D
		var vis: Node3D = st.get_node_or_null("Visual") as Node3D
		if up == null or it == null or vis == null:
			errors.append("hub_station %s lacks UsePoint / Interactable / Visual" % id)
			continue
		up.position = Vector3(0.0, -xf.origin.y, -float(s[3]))
		it.position = v3(s[4])
		var body: Node3D = add(vis, node3d("Greybox")) as Node3D
		for b: Array in s[5]:
			var mn: Vector3 = v3(b[1])
			var mx: Vector3 = v3(b[2])
			box(body, String(b[0]), mn, mx, String(b[3]))
			if xf.origin.y + mn.y < 0.3:   # floor-standing parts block the walker (wall-hung ones are above the agent's climb)
				obstruct(xf, AABB(mn, mx - mn))
		if id == "jukebox":
			add(st, node3d("Speaker", L.JUKEBOX_SPEAKER))
		var cam: Marker3D = Marker3D.new()
		cam.name = "StationCam"
		var eye: Vector3 = up.position + Vector3(0.0, L.STATION_CAM_H, -L.STATION_CAM_BACK)
		cam.transform = Transform3D(Basis.looking_at(it.position - eye, Vector3.UP), eye)
		cam.set_meta(&"fov", L.STATION_CAM_FOV)
		add(st, cam)


func build_props(props: Node3D) -> void:
	for p: Array in L.PROPS:
		var mn: Vector3 = v3(p[1])
		var mx: Vector3 = v3(p[2])
		var b: StaticBody3D = box(props, String(p[0]), mn, mx, String(p[3]))
		b.set_meta(&"prop", true)
		obstruct(Transform3D.IDENTITY, AABB(mn, mx - mn))


func build_review_cameras(cams: Node3D) -> void:
	var paths: Array[NodePath] = []
	for c: Array in L.REVIEW_CAMERAS:
		var m: Marker3D = Marker3D.new()
		var nm: String = String(c[0])
		m.name = nm
		var pos: Vector3 = v3(c[2])
		var dir: Vector3 = v3(c[3]) - pos
		var up: Vector3 = Vector3.FORWARD if absf(dir.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
		m.position = pos
		m.basis = Basis.looking_at(dir, up)
		if nm.begins_with("TopDown"):
			m.set_meta(&"size", L.TOPDOWN_SIZE)
		else:
			m.set_meta(&"fov", 70.0)
		m.set_meta(&"caption", "%s (%s)" % [nm, String(c[1])])
		add(cams, m)
		paths.append(NodePath("ReviewCameras/" + nm))
	map_root.review_cameras = paths


## G1: environment only (C4-03 adds the fixtures, GI and the LUT): a moonless overcast night sky and a warm
## ambient so the greybox reads.
func build_environment(lighting: Node3D) -> void:
	var we: WorldEnvironment = HeistWorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.66, 0.58)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = env
	add(lighting, we)


## hub_map.md: Audio/Jukebox, the cabinet's MusicDirector (no heist facts; SafehouseMap.set_jukebox_track plays it).
## The stems play positionally at the cabinet's Speaker (C4-03).
func build_audio(audio: Node3D) -> void:
	var j: Node = (load(MUSIC_DIRECTOR) as GDScript).new() as Node
	j.name = "Jukebox"
	j.set(&"listen_to_event_bus", false)
	j.set(&"track_id", &"")
	j.set(&"positional_parent", NodePath("../../Stations/jukebox/Speaker"))
	j.set(&"unit_size", L.JUKEBOX_UNIT_SIZE)
	j.set(&"max_distance", L.JUKEBOX_MAX_DISTANCE)
	add(audio, j)


## Walkable navmesh (heist_map.md §3: agent radius 0.3, height 1.8, climb 0.3, slope 40, cell 0.1 / 0.1) from the
## Geometry colliders minus the station / prop obstructions, with the door throats (door_nav_clearance.gd).
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
	print("door throats: %d doors" % DNC.add(src, map_root, nm))
	holder.queue_free()
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	await process_frame
	nav.navigation_mesh = nm
	return nm.get_polygon_count()


# --- Generic helpers (rt_builder_base.gd) -----------------------------------------------------------

func add(parent: Node, c: Node) -> Node:
	parent.add_child(c)
	c.owner = map_root
	return c


func node3d(nm: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var c: Node3D = Node3D.new()
	c.name = nm
	c.position = pos
	return c


func n(path: String) -> Node3D:
	return map_root.get_node(path) as Node3D


static func yaw_basis(yaw_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg))


static func v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _material(cls: String) -> Material:
	var id: String = String(CLASS_MAT.get(cls, "grey_prop"))
	if not _mat_cache.has(id):
		_mat_cache[id] = load(MAT_DIR + id + ".tres") as Material
		if _mat_cache[id] == null:
			errors.append("missing material %s" % id)
	return _mat_cache[id]


func _surface(cls: String) -> StringName:
	return SurfaceTags.for_id(String(CLASS_MAT.get(cls, "grey_prop")))


func _box_mesh(size: Vector3, cls: String) -> Mesh:
	var key: String = "%s|%.3f|%.3f|%.3f" % [cls, size.x, size.y, size.z]
	if not _mesh_cache.has(key):
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		bm.material = _material(cls)
		_mesh_cache[key] = bm
	return _mesh_cache[key]


func _box_shape(size: Vector3) -> BoxShape3D:
	var key: String = "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if not _shape_cache.has(key):
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = size
		_shape_cache[key] = bs
	return _shape_cache[key]


## Static box (world_static) from min/max corners in `parent`'s space: StaticBody3D + CollisionShape3D +
## MeshInstance3D in the class's greybox material, tagged with its bullet surface. Clear glass is see-through
## (D-142); frosted glass is not.
func box(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, cls: String) -> StaticBody3D:
	var size: Vector3 = mx - mn
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return null
	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.name = nm
	sb.position = (mn + mx) * 0.5
	add(parent, sb)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(size)
	add(sb, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, cls)
	add(sb, mi)
	SurfaceTags.tag(sb, _surface(cls))
	if cls == "glass":
		sb.set_meta(&"see_through", true)
		sb.add_to_group(&"see_through", true)
	return sb


## Straight wall with rectangular holes. axis "x": runs along x at z = fixed; "z": along z at x = fixed.
## holes: [[a0, a1, y0, y1], ...] (absolute heights).
func wall(parent: Node3D, nm: String, axis: String, fixed: float, a0: float, a1: float, thick: float, yr: Vector2,
		holes_in: Array, cls: String) -> void:
	var cuts: Array[float] = [a0, a1]
	for o: Array in holes_in:
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
		var hs: Array[Vector2] = []
		for o2: Array in holes_in:
			if float(o2[0]) <= p + 0.0001 and float(o2[1]) >= q - 0.0001:
				hs.append(Vector2(maxf(float(o2[2]), yr.x), minf(float(o2[3]), yr.y)))
		hs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cur: float = yr.x
		var spans: Array[Vector2] = []
		for h: Vector2 in hs:
			if h.x > cur + 0.0001:
				spans.append(Vector2(cur, h.x))
			cur = maxf(cur, h.y)
		if yr.y > cur + 0.0001:
			spans.append(Vector2(cur, yr.y))
		for sp: Vector2 in spans:
			var mn: Vector3 = Vector3(p, sp.x, fixed - thick * 0.5) if axis == "x" else Vector3(fixed - thick * 0.5, sp.x, p)
			var mx: Vector3 = Vector3(q, sp.y, fixed + thick * 0.5) if axis == "x" else Vector3(fixed + thick * 0.5, sp.y, q)
			box(parent, "%s_%02d" % [nm, part], mn, mx, cls)
			part += 1


## Records a projected navmesh obstruction for a box (local AABB under xform).
func obstruct(xform: Transform3D, aabb: AABB) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	for corner: Vector3 in [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]:
		pts.append(xform * (aabb.position + aabb.size * corner))
	var lo: float = (xform * aabb.position).y
	obstructions.append([pts, lo, aabb.size.y])


## A prefab scene by contract class name (never a path into game/systems): the class script's .tscn sibling.
func _class_scene(cls: String) -> PackedScene:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c["class"]) == cls:
			var path: String = String(c["path"]).get_basename() + ".tscn"
			if ResourceLoader.exists(path):
				return load(path) as PackedScene
	errors.append("prefab class %s has no scene" % cls)
	return null


## Rectangle [x0, z0, x1, z1] minus holes -> merged rectangles (deterministic; rt_shell.rects_minus).
static func rects_minus(outer: Array, holes_in: Array) -> Array:
	var xs: Array[float] = [float(outer[0]), float(outer[2])]
	var zs: Array[float] = [float(outer[1]), float(outer[3])]
	for h: Array in holes_in:
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
			for h2: Array in holes_in:
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


# --- Scene normalisation (byte-stable regens; rt_builder_base.gd) ------------------------------------

static func _read_uid(path: String) -> String:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return ""
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	var first: String = f.get_line()
	f.close()
	var rx: RegEx = RegEx.create_from_string("uid=\"(uid://[a-z0-9]+)\"")
	var m: RegExMatch = rx.search(first)
	return m.get_string(1) if m != null else ""


## Rewrites the random parts of a saved .tscn (ext/sub resource ids, node unique_ids) as sequential values so reruns
## are byte-identical, and keeps the file's previous uid.
static func normalize_scene(path: String, old_uid: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var ids: Dictionary = {}
	var ext_n: int = 0
	var sub_n: int = 0
	var decl: RegEx = RegEx.create_from_string("^\\[(ext_resource|sub_resource) [^\\n]*id=\"([^\"]+)\"")
	for line: String in text.split("\n"):
		var m: RegExMatch = decl.search(line)
		if m == null:
			continue
		if m.get_string(1) == "ext_resource":
			ext_n += 1
			ids["E|" + m.get_string(2)] = "%d_sh" % ext_n
		else:
			sub_n += 1
			ids["S|" + m.get_string(2)] = "sh_%d" % sub_n
	var out: PackedStringArray = PackedStringArray()
	var ref_ext: RegEx = RegEx.create_from_string("ExtResource\\(\"([^\"]+)\"\\)")
	var ref_sub: RegEx = RegEx.create_from_string("SubResource\\(\"([^\"]+)\"\\)")
	var uid_rx: RegEx = RegEx.create_from_string(" unique_id=[0-9]+")
	var hdr: RegEx = RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"")
	var node_n: int = 0
	for line2: String in text.split("\n"):
		var l: String = line2
		var m2: RegExMatch = decl.search(l)
		if m2 != null:
			var key: String = ("E|" if m2.get_string(1) == "ext_resource" else "S|") + m2.get_string(2)
			l = l.replace("id=\"%s\"" % m2.get_string(2), "id=\"%s\"" % ids[key])
		l = _replace_refs(l, ref_ext, ids, "E|", "ExtResource")
		l = _replace_refs(l, ref_sub, ids, "S|", "SubResource")
		if l.begins_with("[node ") and uid_rx.search(l) != null:
			node_n += 1
			l = uid_rx.sub(l, " unique_id=%d" % (100000 + node_n))
		if l.begins_with("[gd_scene") and old_uid != "":
			l = hdr.sub(l, "uid=\"%s\"" % old_uid)
		out.append(l)
	var w: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	w.store_string("\n".join(out))
	w.close()


static func _replace_refs(line: String, rx: RegEx, ids: Dictionary, prefix: String, fn: String) -> String:
	var out: String = ""
	var last: int = 0
	for m: RegExMatch in rx.search_all(line):
		var key: String = prefix + m.get_string(1)
		var rep: String = "%s(\"%s\")" % [fn, ids[key]] if ids.has(key) else m.get_string(0)
		out += line.substr(last, m.get_start() - last) + rep
		last = m.get_end()
	return out + line.substr(last)
