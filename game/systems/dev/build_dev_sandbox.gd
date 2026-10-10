## Generator for the ENV A dev sandbox map (testing only; never ships; not a heist). Owner: ENV A.
## Regenerate: /opt/godot/godot --headless --path game --script res://systems/dev/build_dev_sandbox.gd
## Builds the node tree in code (docs/contracts/heist_map.md §2), bakes the navmesh from the
## Geometry colliders and saves dev_sandbox.tscn + dev_sandbox_def.tres + dev_sandbox_variants.tres.
## Gameplay prefabs (res://systems/prefabs/<name>/<name>.tscn) that do not exist yet are skipped
## (listed at the end of the run); re-run once they exist.
##
## Layout (meters, +Y up, -Z forward/north, floor y = 0). Walkable compound x [-20, 20], z [-15, 15].
## Building x [-8, 8], z [-12, 0]; front door at (0, 0, 0) on the south wall, window opening at
## x = 8, z [-4.1, -2.9] (sill 0.9, head 2.1); back room x [3, 8], z [-12, -7] with a keycard door at
## (5.5, 0, -7). Van / secure loot in the SE corner, dumpster in the SW corner.
extends SceneTree

const DIR: String = "res://systems/dev/"
const SCENE_PATH: String = DIR + "dev_sandbox.tscn"
const DEF_PATH: String = DIR + "dev_sandbox_def.tres"
const VARIANTS_PATH: String = DIR + "dev_sandbox_variants.tres"
const MISSION_PATH: String = DIR + "dev_sandbox_mission.gd"
const PREFAB_DIR: String = "res://systems/prefabs/"

const WALL_H: float = 3.0
const WALL_T: float = 0.2
const OUTER_T: float = 0.3
const DOOR_W: float = 0.9
const DOOR_H: float = 2.1
const SILL_H: float = 0.9
const SPAWN_Y: float = 0.05
const DESK_H: float = 0.75

## name -> [position (x, z), links, pause_range, pause_anim, tags]
const PATROL_POINTS: Dictionary = {
	"InWest": [Vector2(-6.0, -2.0), ["InNorthWest", "DoorIn", "InHub"], Vector2.ZERO, &"idle", [&"guard"]],
	"InNorthWest": [Vector2(-6.0, -10.0), ["InWest", "InNorth", "InHub"], Vector2(2.0, 5.0), &"check_door", [&"guard"]],
	"InNorth": [Vector2(1.5, -10.0), ["InNorthWest", "InEast", "InHub"], Vector2.ZERO, &"idle", [&"guard"]],
	"InEast": [Vector2(6.0, -3.5), ["InNorth", "DoorIn"], Vector2(2.0, 5.0), &"lean", [&"guard"]],
	"InHub": [Vector2(-1.0, -6.0), ["InWest", "InNorthWest", "InNorth", "DoorIn"], Vector2.ZERO, &"idle", [&"guard"]],
	"DoorIn": [Vector2(0.0, -1.2), ["InWest", "InEast", "InHub", "DoorOut"], Vector2.ZERO, &"idle", [&"guard"]],
	"DoorOut": [Vector2(0.0, 1.2), ["DoorIn", "YardSouth"], Vector2.ZERO, &"idle", [&"guard"]],
	"YardSouth": [Vector2(0.0, 8.0), ["DoorOut", "YardWest", "YardEast", "CivBench", "CivVan"], Vector2.ZERO, &"idle", [&"guard"]],
	"YardWest": [Vector2(-14.0, 4.0), ["YardSouth", "YardNorthWest", "CivBench"], Vector2(2.0, 5.0), &"smoke", [&"guard"]],
	"YardNorthWest": [Vector2(-14.0, -13.5), ["YardWest", "YardNorthEast"], Vector2.ZERO, &"idle", [&"guard"]],
	"YardNorthEast": [Vector2(14.0, -13.5), ["YardNorthWest", "YardEast"], Vector2(2.0, 5.0), &"idle", [&"guard"]],
	"YardEast": [Vector2(14.0, 3.0), ["YardNorthEast", "YardSouth", "CivVan"], Vector2.ZERO, &"idle", [&"guard"]],
	"CivBench": [Vector2(-8.0, 11.0), ["YardSouth", "YardWest", "CivVan"], Vector2(2.0, 5.0), &"phone", [&"civilian"]],
	"CivVan": [Vector2(8.0, 8.0), ["YardSouth", "YardEast", "CivBench"], Vector2(2.0, 5.0), &"idle", [&"civilian"]],
}

var _root: HeistMap = null
var _missing: Array[String] = []
var _mats: Dictionary[String, StandardMaterial3D] = {}


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var def: HeistDef = _make_def()
	var table: HeistVariantTable = _make_variants()
	var err: int = ResourceSaver.save(def, DEF_PATH)
	err = maxi(err, ResourceSaver.save(table, VARIANTS_PATH))
	if err != OK:
		push_error("dev_sandbox: failed to save def/variants (%d)" % err)
		quit(1)
		return
	_root = HeistMap.new()
	_root.name = "DevSandbox"
	_root.heist_def = load(DEF_PATH) as HeistDef
	_root.variant_table = load(VARIANTS_PATH) as HeistVariantTable
	_root.floor_heights = PackedFloat32Array([0.0])
	var sections: Array[String] = ["Geometry", "Props", "Lighting"]
	for nm: String in sections:
		_add(_root, _node3d(nm))
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	nav.navigation_layers = 1
	_add(_root, nav)
	for nm: String in ["Zones", "Rooms", "Spawns", "Patrols", "Tactical", "Gameplay", "Variants"]:
		_add(_root, _node3d(nm))
	var mission: Node = Node.new()
	mission.name = "Mission"
	mission.set_script(load(MISSION_PATH))
	_add(_root, mission)
	_add(_root, _node3d("ReviewCameras"))

	_build_geometry(_root.get_node("Geometry") as Node3D)
	_build_lighting(_root.get_node("Lighting") as Node3D)
	_build_zones(_root.get_node("Zones") as Node3D)
	_build_rooms(_root.get_node("Rooms") as Node3D)
	var graph: PatrolGraph = _build_patrols(_root.get_node("Patrols") as Node3D)
	_build_tactical(_root.get_node("Tactical") as Node3D)
	_build_review_cameras(_root.get_node("ReviewCameras") as Node3D)

	# In the tree for global transforms (nav parsing) and NodePaths.
	get_root().add_child(_root)
	_build_spawns(_root.get_node("Spawns") as Node3D, graph)
	_build_variants(_root.get_node("Variants") as Node3D, graph)
	_link_patrols(graph)
	await physics_frame
	var polys: int = _bake(nav, _root.get_node("Geometry") as Node3D)
	if polys <= 0:
		push_error("dev_sandbox: navmesh bake produced no polygons")
		quit(1)
		return
	get_root().remove_child(_root)
	# Prefabs are added out of the tree so their runtime _ready() never runs in the generator.
	_build_gameplay(_root.get_node("Gameplay") as Node3D)

	var ps: PackedScene = PackedScene.new()
	err = ps.pack(_root)
	if err == OK:
		err = ResourceSaver.save(ps, SCENE_PATH)
	_root.free()
	if err != OK:
		push_error("dev_sandbox: failed to save scene (%d)" % err)
		quit(1)
		return
	print("dev_sandbox: saved %s (navmesh polygons: %d)" % [SCENE_PATH, polys])
	if not _missing.is_empty():
		print("dev_sandbox: MISSING prefabs (skipped): %s" % ", ".join(_missing))
	quit(0)


# --- Resources ------------------------------------------------------------------------

func _make_def() -> HeistDef:
	var d: HeistDef = HeistDef.new()
	d.id = &"dev_sandbox"
	d.display_name = "Dev Sandbox"
	d.briefing = "ENV A test compound. Not a heist; never ships."
	d.mode = Enums.HeistMode.STEALTH_OR_LOUD
	d.map_scene = SCENE_PATH
	d.base_payout = 10000
	d.loot = [&"loot.jewelry"]
	d.objectives = [&"get_loot", &"escape"]
	d.escape_options = [&"van"]
	return d


func _make_variants() -> HeistVariantTable:
	var t: HeistVariantTable = HeistVariantTable.new()
	t.rules = [
		{"group": &"keycard", "pick": Vector2i(1, 1)},
		{"group": &"guard_extra", "pick": Vector2i(0, 1), "difficulty_add": [0, 0, 0, 1, 1, 1]},
	]
	t.scalars = [{"id": &"escape_delay", "values": [0, 30]}]
	t.rare_events = [{"id": &"rare.extra_cash", "chance": 0.1, "effects": {}, "good": true}]
	return t


# --- Helpers --------------------------------------------------------------------------

func _add(parent: Node, n: Node) -> Node:
	parent.add_child(n)
	n.owner = _root
	return n


func _node3d(nm: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = nm
	n.position = pos
	return n


func _mat(key: String, color: Color) -> StandardMaterial3D:
	if not _mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.resource_name = key
		m.albedo_color = color
		m.roughness = 0.9
		_mats[key] = m
	return _mats[key]


## Static box: StaticBody3D (layer world_static) + matching CollisionShape3D and MeshInstance3D.
func _box(parent: Node3D, nm: String, size: Vector3, center: Vector3, mat: StandardMaterial3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = nm
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	_add(parent, body)
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	_add(body, col)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	_add(body, mi)


## Box from min/max corners (easier to keep openings exact).
func _box_mm(parent: Node3D, nm: String, mn: Vector3, mx: Vector3, mat: StandardMaterial3D) -> void:
	_box(parent, nm, mx - mn, (mn + mx) * 0.5, mat)


func _area_box(area: Area3D, size: Vector3, center: Vector3, idx: int = 0) -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Shape" if idx == 0 else "Shape%d" % idx
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = center - area.position
	_add(area, col)


func _facing(n: Node3D, pos: Vector3, look_at_point: Vector3) -> void:
	n.position = pos
	var dir: Vector3 = look_at_point - pos
	if dir.length() > 0.001:
		var up: Vector3 = Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		n.basis = Basis.looking_at(dir, up)


# --- Geometry ------------------------------------------------------------------------

func _build_geometry(geo: Node3D) -> void:
	var floor_mat: StandardMaterial3D = _mat("floor_concrete", Color(0.42, 0.43, 0.45))
	var outer_mat: StandardMaterial3D = _mat("wall_outer", Color(0.62, 0.55, 0.44))
	var bld_mat: StandardMaterial3D = _mat("wall_building", Color(0.36, 0.47, 0.6))
	var inner_mat: StandardMaterial3D = _mat("wall_interior", Color(0.75, 0.73, 0.68))
	_box(geo, "Floor", Vector3(41.0, 0.5, 31.0), Vector3(0.0, -0.25, 0.0), floor_mat)
	var hx: float = 20.0 + OUTER_T * 0.5
	var hz: float = 15.0 + OUTER_T * 0.5
	_box(geo, "WallNorth", Vector3(40.0 + 2.0 * OUTER_T, WALL_H, OUTER_T), Vector3(0.0, WALL_H * 0.5, -hz), outer_mat)
	_box(geo, "WallSouth", Vector3(40.0 + 2.0 * OUTER_T, WALL_H, OUTER_T), Vector3(0.0, WALL_H * 0.5, hz), outer_mat)
	_box(geo, "WallWest", Vector3(OUTER_T, WALL_H, 30.0), Vector3(-hx, WALL_H * 0.5, 0.0), outer_mat)
	_box(geo, "WallEast", Vector3(OUTER_T, WALL_H, 30.0), Vector3(hx, WALL_H * 0.5, 0.0), outer_mat)

	var bld: Node3D = _node3d("Building")
	_add(geo, bld)
	var t: float = WALL_T * 0.5
	var hd: float = DOOR_W * 0.5
	# South wall (z = 0) with the 0.9 m front doorway centred on x = 0.
	_box_mm(bld, "SouthWallW", Vector3(-8.0 - t, 0.0, -t), Vector3(-hd, WALL_H, t), bld_mat)
	_box_mm(bld, "SouthWallE", Vector3(hd, 0.0, -t), Vector3(8.0 + t, WALL_H, t), bld_mat)
	_box_mm(bld, "SouthLintel", Vector3(-hd, DOOR_H, -t), Vector3(hd, WALL_H, t), bld_mat)
	# North wall (z = -12).
	_box_mm(bld, "NorthWall", Vector3(-8.0 - t, 0.0, -12.0 - t), Vector3(8.0 + t, WALL_H, -12.0 + t), bld_mat)
	# West wall (x = -8).
	_box_mm(bld, "WestWall", Vector3(-8.0 - t, 0.0, -12.0 + t), Vector3(-8.0 + t, WALL_H, -t), bld_mat)
	# East wall (x = 8) with a 1.2 m window opening z [-4.1, -2.9], sill 0.9, head 2.1.
	_box_mm(bld, "EastWallN", Vector3(8.0 - t, 0.0, -12.0 + t), Vector3(8.0 + t, WALL_H, -4.1), bld_mat)
	_box_mm(bld, "EastWallS", Vector3(8.0 - t, 0.0, -2.9), Vector3(8.0 + t, WALL_H, -t), bld_mat)
	_box_mm(bld, "WindowSill", Vector3(8.0 - t, 0.0, -4.1), Vector3(8.0 + t, SILL_H, -2.9), bld_mat)
	_box_mm(bld, "WindowHead", Vector3(8.0 - t, DOOR_H, -4.1), Vector3(8.0 + t, WALL_H, -2.9), bld_mat)
	# Back room partitions: x = 3 (z [-12, -7]) and z = -7 (x [3, 8]) with the keycard doorway at x = 5.5.
	_box_mm(bld, "BackRoomWallW", Vector3(3.0 - t, 0.0, -12.0 + t), Vector3(3.0 + t, WALL_H, -7.0 + t), inner_mat)
	_box_mm(bld, "BackRoomWallS1", Vector3(3.0 + t, 0.0, -7.0 - t), Vector3(5.5 - hd, WALL_H, -7.0 + t), inner_mat)
	_box_mm(bld, "BackRoomWallS2", Vector3(5.5 + hd, 0.0, -7.0 - t), Vector3(8.0 - t, WALL_H, -7.0 + t), inner_mat)
	# Phone desk against the west wall (the phone prefab sits on it).
	_box_mm(bld, "PhoneDesk", Vector3(-7.9, 0.0, -1.6), Vector3(-7.1, DESK_H, -0.4), _mat("desk_wood", Color(0.5, 0.36, 0.24)))
	_box_mm(bld, "BackRoomLintel", Vector3(5.5 - hd, DOOR_H, -7.0 - t), Vector3(5.5 + hd, WALL_H, -7.0 + t), inner_mat)


func _build_lighting(lighting: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	_add(lighting, sun)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.6
	we.environment = env
	_add(lighting, we)


# --- Navigation ----------------------------------------------------------------------

## Bakes from the Geometry static colliders only (prefabs toggle their own obstacles at runtime).
## Cell size 0.05: with agent radius 0.35 a 0.25 cell erodes 0.5 m per side and closes 0.9 m doors.
func _bake(nav: NavigationRegion3D, geo: Node3D) -> int:
	var nm: NavigationMesh = NavigationMesh.new()
	nm.agent_radius = 0.35
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.05
	nm.cell_height = 0.05
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, geo)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav.navigation_mesh = nm
	return nm.get_polygon_count()


# --- Zones and rooms -----------------------------------------------------------------

## The yard is the compound minus the building: four boxes (south, west, east, north strips).
func _yard_boxes() -> Array[AABB]:
	return [
		AABB(Vector3(-20.0, 0.0, 0.0), Vector3(40.0, 3.0, 15.0)),
		AABB(Vector3(-20.0, 0.0, -15.0), Vector3(12.0, 3.0, 15.0)),
		AABB(Vector3(8.0, 0.0, -15.0), Vector3(12.0, 3.0, 15.0)),
		AABB(Vector3(-8.0, 0.0, -15.0), Vector3(16.0, 3.0, 3.0)),
	]


func _zone(parent: Node3D, nm: String, kind: MapZone.Kind, zone_id: StringName, boxes: Array[AABB]) -> void:
	var z: MapZone = MapZone.new()
	z.name = nm
	z.kind = kind
	z.zone_id = zone_id
	z.collision_layer = 1 << 9
	z.collision_mask = 0
	_add(parent, z)
	for i: int in range(boxes.size()):
		_area_box(z, boxes[i].size, boxes[i].get_center(), i)


func _build_zones(zones: Node3D) -> void:
	_zone(zones, "PublicYard", MapZone.Kind.PUBLIC, &"yard", _yard_boxes())
	_zone(zones, "RestrictedBuilding", MapZone.Kind.RESTRICTED, &"building",
		[AABB(Vector3(-8.0, 0.0, -12.0), Vector3(16.0, 3.0, 12.0))])
	_zone(zones, "SecureLootVan", MapZone.Kind.SECURE_LOOT, &"van",
		[AABB(Vector3(14.0, 0.0, 8.0), Vector3(5.0, 3.0, 6.0))])
	_zone(zones, "EscapeVan", MapZone.Kind.ESCAPE, &"escape_van",
		[AABB(Vector3(11.0, 0.0, 5.0), Vector3(9.0, 3.0, 10.0))])
	_zone(zones, "BodyHideDumpster", MapZone.Kind.BODY_HIDE, &"dumpster",
		[AABB(Vector3(-19.5, 0.0, 11.0), Vector3(3.5, 3.0, 3.5))])


func _room(parent: Node3D, nm: String, room_id: StringName, purpose: StringName, boxes: Array[AABB]) -> void:
	var r: RoomVolume = RoomVolume.new()
	r.name = nm
	r.room_id = room_id
	r.purpose = purpose
	r.floor_index = 0
	r.collision_layer = 1 << 9
	r.collision_mask = 0
	r.monitoring = false
	_add(parent, r)
	for i: int in range(boxes.size()):
		_area_box(r, boxes[i].size, boxes[i].get_center(), i)


func _build_rooms(rooms: Node3D) -> void:
	_room(rooms, "Yard", &"yard", &"exterior", _yard_boxes())
	_room(rooms, "Building", &"building", &"sales_floor", [AABB(Vector3(-8.0, 0.0, -12.0), Vector3(16.0, 3.0, 12.0))])


# --- Spawns ---------------------------------------------------------------------------

func _spawn(parent: Node3D, nm: String, kind: SpawnPoint.Kind, pos: Vector3, look: Vector3,
		tags: Array[StringName] = [], graph: PatrolGraph = null, idle: StringName = &"") -> SpawnPoint:
	var sp: SpawnPoint = SpawnPoint.new()
	sp.name = nm
	sp.kind = kind
	sp.tags = tags
	sp.idle_activity = idle
	_facing(sp, pos, look)
	_add(parent, sp)
	if graph != null:
		sp.patrol_graph = sp.get_path_to(graph)
	return sp


func _build_spawns(spawns: Node3D, graph: PatrolGraph) -> void:
	var y: float = SPAWN_Y
	var door: Vector3 = Vector3(0.0, y, 0.0)
	for i: int in range(4):
		_spawn(spawns, "Player%d" % i, SpawnPoint.Kind.PLAYER, Vector3(6.0 + 1.0 * i, y, 11.0), door,
			[StringName("crew_van_%d" % i)])
	_spawn(spawns, "GuardInsideWest", SpawnPoint.Kind.GUARD, Vector3(-5.0, y, -9.0), door,
		[&"guard_inside"], graph)
	_spawn(spawns, "GuardInsideEast", SpawnPoint.Kind.GUARD, Vector3(2.0, y, -3.0), door,
		[&"guard_inside"], graph)
	_spawn(spawns, "GuardYard", SpawnPoint.Kind.GUARD, Vector3(-14.0, y, 8.0), Vector3(0.0, y, 8.0),
		[&"guard_yard"], graph)
	_spawn(spawns, "CivilianBrowse", SpawnPoint.Kind.CIVILIAN, Vector3(-4.0, y, 6.0), door,
		[&"civ_customer"], null, &"browse")
	_spawn(spawns, "CivilianPhone", SpawnPoint.Kind.CIVILIAN, Vector3(4.0, y, 9.0), Vector3(4.0, y, 15.0),
		[&"civ_customer"], null, &"phone")
	var centre: Vector3 = Vector3(0.0, y, 3.0)
	_spawn(spawns, "PoliceWest", SpawnPoint.Kind.POLICE, Vector3(-19.2, y, 0.0), centre, [&"police_west"])
	_spawn(spawns, "PoliceNorth", SpawnPoint.Kind.POLICE, Vector3(0.0, y, -14.2), Vector3(10.0, y, -14.2), [&"police_north"])
	_spawn(spawns, "PoliceEast", SpawnPoint.Kind.POLICE, Vector3(19.2, y, -5.0), centre, [&"police_east"])
	_spawn(spawns, "PoliceSouth", SpawnPoint.Kind.POLICE, Vector3(-6.0, y, 14.2), centre, [&"police_south"])
	_spawn(spawns, "CameraOperator", SpawnPoint.Kind.CAMERA_OPERATOR, Vector3(-6.8, y, -10.8), door,
		[&"security_staff"])


# --- Patrols --------------------------------------------------------------------------

func _build_patrols(patrols: Node3D) -> PatrolGraph:
	var g: PatrolGraph = PatrolGraph.new()
	g.name = "Main"
	g.graph_id = &"main"
	g.floor_index = 0
	_add(patrols, g)
	for nm: String in PATROL_POINTS:
		var row: Array = PATROL_POINTS[nm]
		var p: PatrolPoint = PatrolPoint.new()
		p.name = nm
		var xz: Vector2 = row[0]
		p.position = Vector3(xz.x, 0.0, xz.y)
		p.pause_range = row[2]
		p.pause_anim = row[3]
		var tags: Array[StringName] = []
		for tg: StringName in row[4]:
			tags.append(tg)
		p.tags = tags
		p.face_marker_forward = p.pause_range != Vector2.ZERO
		_add(g, p)
	return g


## Links are relative NodePaths to neighbours; validated bidirectional here.
func _link_patrols(g: PatrolGraph) -> void:
	for nm: String in PATROL_POINTS:
		var p: PatrolPoint = g.get_node(nm) as PatrolPoint
		var links: Array[NodePath] = []
		for other: String in PATROL_POINTS[nm][1]:
			var o: PatrolPoint = g.get_node_or_null(other) as PatrolPoint
			if o == null or not (PATROL_POINTS[other][1] as Array).has(nm):
				push_error("dev_sandbox: patrol link %s -> %s is not bidirectional" % [nm, other])
				continue
			links.append(p.get_path_to(o))
		p.links = links


# --- Tactical ---------------------------------------------------------------------------

func _tactical(parent: Node3D, nm: String, kind: TacticalPoint.Kind, pos: Vector3, look: Vector3,
		breachable: bool = false) -> void:
	var t: TacticalPoint = TacticalPoint.new()
	t.name = nm
	t.kind = kind
	t.breachable = breachable
	_facing(t, pos, look)
	_add(parent, t)


func _build_tactical(tac: Node3D) -> void:
	var door: Vector3 = Vector3(0.0, 0.0, 0.0)
	_tactical(tac, "CoverBuildingSW", TacticalPoint.Kind.COVER, Vector3(-8.8, 0.0, 0.8), door)
	_tactical(tac, "CoverBuildingSE", TacticalPoint.Kind.COVER, Vector3(8.8, 0.0, 0.8), door)
	_tactical(tac, "CoverBuildingNW", TacticalPoint.Kind.COVER, Vector3(-8.8, 0.0, -12.8), Vector3(-8.8, 0.0, 0.0))
	_tactical(tac, "CoverBuildingNE", TacticalPoint.Kind.COVER, Vector3(8.8, 0.0, -12.8), Vector3(8.8, 0.0, 0.0))
	_tactical(tac, "CoverInsideWest", TacticalPoint.Kind.COVER, Vector3(-7.2, 0.0, -6.0), door)
	_tactical(tac, "CoverBackRoomCorner", TacticalPoint.Kind.COVER, Vector3(2.3, 0.0, -7.7), door)
	_tactical(tac, "CoverVan", TacticalPoint.Kind.COVER, Vector3(13.0, 0.0, 11.0), door)
	_tactical(tac, "EntryFrontDoor", TacticalPoint.Kind.ENTRY, Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -5.0), true)
	_tactical(tac, "EntryWindow", TacticalPoint.Kind.ENTRY, Vector3(9.0, 0.0, -3.5), Vector3(0.0, 0.0, -3.5), true)
	_tactical(tac, "FlankEast", TacticalPoint.Kind.FLANK, Vector3(14.0, 0.0, -8.0), Vector3(8.0, 0.0, -3.5))


func _build_review_cameras(cams: Node3D) -> void:
	var overview: Marker3D = Marker3D.new()
	overview.name = "Overview"
	_facing(overview, Vector3(0.0, 32.0, 24.0), Vector3(0.0, 0.0, -2.0))
	_add(cams, overview)
	var yard: Marker3D = Marker3D.new()
	yard.name = "YardToDoor"
	_facing(yard, Vector3(16.0, 3.5, 13.0), Vector3(0.0, 1.2, 0.0))
	_add(cams, yard)
	_root.review_cameras = [NodePath("ReviewCameras/Overview"), NodePath("ReviewCameras/YardToDoor")]


# --- Variants ---------------------------------------------------------------------------

func _build_variants(variants: Node3D, graph: PatrolGraph) -> void:
	var keycard: PackedScene = _prefab_scene("keycard_pickup")
	var key_spots: Array[Vector3] = [Vector3(-6.5, 0.0, -8.5), Vector3(-16.0, 0.0, -13.0), Vector3(17.0, 0.0, -12.0)]
	for i: int in range(key_spots.size()):
		var vs: VariantSlot = VariantSlot.new()
		vs.name = "Keycard%d" % (i + 1)
		vs.slot_group = &"keycard"
		vs.slot_id = StringName("keycard_%d" % (i + 1))
		vs.prefab = keycard
		vs.position = key_spots[i]
		_add(variants, vs)
	var guard_spots: Array[Vector3] = [Vector3(-14.0, SPAWN_Y, -2.0), Vector3(-3.0, SPAWN_Y, -10.0)]
	for i: int in range(guard_spots.size()):
		var vs2: VariantSlot = VariantSlot.new()
		vs2.name = "GuardExtra%d" % (i + 1)
		vs2.slot_group = &"guard_extra"
		vs2.slot_id = StringName("guard_extra_%d" % (i + 1))
		vs2.position = guard_spots[i]
		_add(variants, vs2)
		var sp: SpawnPoint = SpawnPoint.new()
		sp.name = "Guard"
		sp.kind = SpawnPoint.Kind.GUARD
		sp.tags = [&"guard_extra"]
		_add(vs2, sp)
		sp.patrol_graph = sp.get_path_to(graph)


# --- Gameplay prefabs --------------------------------------------------------------------

func _prefab_scene(prefab: String) -> PackedScene:
	var path: String = "%s%s/%s.tscn" % [PREFAB_DIR, prefab, prefab]
	if not ResourceLoader.exists(path):
		if not _missing.has(prefab):
			_missing.append(prefab)
		return null
	return load(path) as PackedScene


## Instance a prefab (owner = map root only, so it is saved as an instance) or null if missing.
func _prefab(parent: Node3D, prefab: String, nm: String, pos: Vector3, yaw_deg: float = 0.0,
		props: Dictionary = {}) -> Node3D:
	var ps: PackedScene = _prefab_scene(prefab)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		push_error("dev_sandbox: prefab %s root is not a Node3D" % prefab)
		return null
	inst.name = nm
	inst.position = pos
	inst.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	for k: String in props:
		_set_prop(inst, k, props[k])
	parent.add_child(inst)
	inst.owner = _root
	return inst


func _set_prop(inst: Node, prop: String, value: Variant) -> void:
	var found: bool = false
	for p: Dictionary in inst.get_property_list():
		if String(p["name"]) == prop:
			found = true
			break
	if not found:
		push_warning("dev_sandbox: %s has no property '%s'" % [inst.name, prop])
		return
	if value is String and String(value).begins_with("enum:"):
		value = _enum_value(inst, String(value).substr(5))
	inst.set(prop, value)


## Look up an enum key (e.g. "LOCKPICK") in the prefab script's constants (enum dictionaries).
func _enum_value(inst: Node, key: String) -> int:
	var scr: Script = inst.get_script() as Script
	if scr != null:
		var consts: Dictionary = scr.get_script_constant_map()
		for c: Variant in consts.values():
			if c is Dictionary and (c as Dictionary).has(key):
				return int((c as Dictionary)[key])
	push_warning("dev_sandbox: enum key %s not found on %s" % [key, inst.name])
	return 0


func _build_gameplay(gp: Node3D) -> void:
	var jewelry: StringName = &"loot.jewelry"
	_prefab(gp, "door", "FrontDoor", Vector3(0.0, 0.0, 0.0), 180.0, {"lock": "enum:LOCKPICK", "width_m": DOOR_W})
	var back_door: Node3D = _prefab(gp, "door", "BackRoomDoor", Vector3(5.5, 0.0, -7.0), 180.0,
		{"lock": "enum:KEYCARD", "width_m": DOOR_W})
	var reader: Node3D = _prefab(gp, "keycard_reader", "BackRoomReader", Vector3(4.6, 1.2, -6.85), 180.0)
	if reader != null and back_door != null:
		var targets: Array[NodePath] = [NodePath("../BackRoomDoor")]
		_set_prop(reader, "targets", targets)
	_prefab(gp, "display_case", "DisplayCaseA", Vector3(-5.0, 0.0, -5.0), 0.0, {"loot_id": jewelry})
	_prefab(gp, "display_case", "DisplayCaseB", Vector3(-2.0, 0.0, -9.0), 0.0, {"loot_id": jewelry})
	_prefab(gp, "small_loot", "SmallLootA", Vector3(2.3, 0.0, -11.3), 180.0)
	_prefab(gp, "small_loot", "SmallLootB", Vector3(-7.4, 0.0, -4.0), 0.0)
	_prefab(gp, "loot_spawn", "LootSpawnJewelry", Vector3(6.0, 0.0, -1.5), 0.0, {"loot_id": jewelry, "count": 2})
	_prefab(gp, "safe", "BackRoomSafe", Vector3(7.2, 0.0, -11.3), 180.0)
	# Drill point on the safe front (z = -10.95), -Z into the lock; its UsePoint is 1 m lower.
	_prefab(gp, "drill_point", "SafeDrillPoint", Vector3(7.2, 1.0, -10.93), 0.0,
		{"device": "enum:DRILL", "target": NodePath("../BackRoomSafe")})
	# Volume prefabs host their own MapZone `Zone`; sized to match the Zones/ boxes.
	_prefab(gp, "secure_zone", "VanSecure", Vector3(16.5, 0.0, 11.0), 0.0, {"zone_size_m": Vector3(5.0, 3.0, 6.0)})
	_prefab(gp, "escape_zone", "VanEscape", Vector3(15.5, 0.0, 10.0), 0.0,
		{"objective_tag": &"escape_van", "escape_type": &"van", "zone_size_m": Vector3(9.0, 3.0, 10.0)})
	_prefab(gp, "body_container", "Dumpster", Vector3(-17.75, 0.0, 12.75), 180.0)
	_prefab(gp, "phone", "OfficePhone", Vector3(-7.5, DESK_H, -1.0), -90.0)
	_prefab(gp, "alarm_button", "AlarmButton", Vector3(2.85, 1.2, -9.0), 90.0)
	var cam: Node3D = _prefab(gp, "security_camera", "CameraLobby", Vector3(-7.6, 2.7, -11.6), 0.0)
	if cam != null:
		_facing(cam, cam.position, Vector3(0.0, 1.0, 0.0))
	_prefab(gp, "window", "EastWindow", Vector3(8.0, SILL_H, -3.5), -90.0)
