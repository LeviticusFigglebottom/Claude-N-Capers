## Builds the synthetic levelcheck fixture maps (good + deliberately bad) in memory.
## make_lc_fixtures.gd bakes their navmesh and saves them as .tscn. Owner: ENV C (tests).
## Good: two 7.5 x 7.2 m offices joined by a door, everything per level_standards.
## Bad adds: FloatBox (0.1 m above floor), WallClipBox (0.1 m into the south wall), BareLight
## (no fixture), NullMatMesh (null material), PlayerSpawn5 (sealed closet), LonelyPoint (no links).
class_name LcFixtureBuilder
extends RefCounted

const TEX_SIZE: int = 32
const CEIL_H: float = 2.8


static func checker(tint: Color) -> ImageTexture:
	var img: Image = Image.create_empty(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	for y: int in range(TEX_SIZE):
		for x: int in range(TEX_SIZE):
			var on: bool = ((x / 8) + (y / 8)) % 2 == 0
			img.set_pixel(x, y, tint if on else tint.darkened(0.25))
	return ImageTexture.create_from_image(img)


static func tri_mat(name: String, tint: Color, px_per_m: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_texture = checker(tint)
	m.uv1_triplanar = true
	var s: float = px_per_m / float(TEX_SIZE)
	m.uv1_scale = Vector3(s, s, s)
	m.roughness = 0.8
	return m


static func _own(n: Node, root: Node) -> void:
	for c: Node in n.get_children():
		c.owner = root
		_own(c, root)


static func _box_mesh(size: Vector3, mat: Material) -> BoxMesh:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	bm.material = mat
	return bm


## Static architecture piece: StaticBody3D (layer world_static) + box mesh, from min/max corners.
static func solid(parent: Node, name: String, lo: Vector3, hi: Vector3, mat: Material) -> StaticBody3D:
	var size: Vector3 = hi - lo
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = name
	sb.position = (lo + hi) * 0.5
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _box_mesh(size, mat)
	sb.add_child(mi)
	parent.add_child(sb)
	return sb


## Prop root (Node3D) with a box mesh at `offset` (local) and optional box collider.
static func prop(parent: Node, name: String, pos: Vector3, yaw_deg: float, kind: String, size: Vector3,
		offset: Vector3, mat: Material, collider: bool, metas: Dictionary = {}) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	root.set_meta(&"kind", kind)
	for k: String in metas.keys():
		root.set_meta(StringName(k), metas[k])
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.position = offset
	mi.mesh = _box_mesh(size, mat)
	root.add_child(mi)
	if collider:
		var sb: StaticBody3D = StaticBody3D.new()
		sb.name = "Body"
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Shape"
		cs.position = offset
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		sb.add_child(cs)
		root.add_child(sb)
	parent.add_child(root)
	return root


static func area_box(a: Area3D, center: Vector3, size: Vector3) -> void:
	a.position = center
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	a.add_child(cs)


static func spawn(parent: Node, name: String, kind: SpawnPoint.Kind, pos: Vector3) -> SpawnPoint:
	var s: SpawnPoint = SpawnPoint.new()
	s.name = name
	s.kind = kind
	s.position = pos
	parent.add_child(s)
	return s


## UV-mapped material whose uv1_scale gives `target` px/m on the given box size (BoxMesh UVs).
static func uv_mat_for_box(size: Vector3, target: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.resource_name = "fx_uv_box"
	m.albedo_texture = checker(Color(0.55, 0.4, 0.3))
	var bm: BoxMesh = _box_mesh(size, null)
	var tri: Dictionary = LcGeom.surface_triangles(bm, 0)
	var v: PackedVector3Array = tri["v"]
	var uv: PackedVector2Array = tri["uv"]
	var wa: float = 0.0
	var ua: float = 0.0
	for i: int in range(0, v.size(), 3):
		wa += LcGeom.tri_area(v[i], v[i + 1], v[i + 2])
		ua += LcGeom.tri_area_2d(uv[i], uv[i + 1], uv[i + 2])
	var d: float = sqrt(ua * TEX_SIZE * TEX_SIZE / wa)
	var s: float = target / d
	m.uv1_scale = Vector3(s, s, 1.0)
	return m


static func build(bad: bool) -> HeistMap:
	var m_floor: StandardMaterial3D = tri_mat("fx_floor", Color(0.45, 0.42, 0.38), 512.0)
	var m_wall: StandardMaterial3D = tri_mat("fx_wall", Color(0.75, 0.72, 0.66), 512.0)
	var m_ceil: StandardMaterial3D = tri_mat("fx_ceiling", Color(0.85, 0.85, 0.82), 256.0)
	var m_wood: StandardMaterial3D = tri_mat("fx_wood", Color(0.5, 0.33, 0.2), 512.0)
	var m_metal: StandardMaterial3D = tri_mat("fx_metal", Color(0.35, 0.36, 0.4), 512.0)
	var m_lamp: StandardMaterial3D = tri_mat("fx_lamp", Color(0.9, 0.9, 0.85), 512.0)
	m_lamp.emission_enabled = true
	m_lamp.emission = Color(1.0, 0.85, 0.65)
	var map: HeistMap = HeistMap.new()
	map.name = "LcFixtureBad" if bad else "LcFixtureGood"
	var names: Array[String] = ["Geometry", "Props", "Lighting", "Zones", "Rooms", "Spawns", "Patrols",
		"Tactical", "Gameplay", "Variants", "ReviewCameras"]
	var c: Dictionary = {}
	for n: String in names:
		var node: Node3D = Node3D.new()
		node.name = n
		c[n] = node
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	var mission: Node = Node.new()
	mission.name = "Mission"
	mission.set_script(load("res://tests/c/fixtures/lc_fixture_mission.gd"))
	for n2: String in ["Geometry", "Props", "Lighting"]:
		map.add_child(c[n2])
	map.add_child(nav)
	for n3: String in ["Zones", "Rooms", "Spawns", "Patrols", "Tactical", "Gameplay", "Variants"]:
		map.add_child(c[n3])
	map.add_child(mission)
	map.add_child(c["ReviewCameras"])
	var geo: Node3D = c["Geometry"]
	# --- shell: 16 x 8 m, exterior walls 0.4, interior wall 0.2 with a 1.0 x 2.2 m opening.
	solid(geo, "Floor", Vector3(0, -0.2, 0), Vector3(16, 0, 8), m_floor)
	solid(geo, "Ceiling", Vector3(0, CEIL_H, 0), Vector3(16, CEIL_H + 0.2, 8), m_ceil)
	solid(geo, "WallSouth", Vector3(0, 0, 0), Vector3(16, CEIL_H, 0.4), m_wall)
	solid(geo, "WallNorth", Vector3(0, 0, 7.6), Vector3(16, CEIL_H, 8), m_wall)
	solid(geo, "WallWest", Vector3(0, 0, 0.4), Vector3(0.4, CEIL_H, 7.6), m_wall)
	solid(geo, "WallEast", Vector3(15.6, 0, 0.4), Vector3(16, CEIL_H, 7.6), m_wall)
	solid(geo, "WallMidA", Vector3(7.9, 0, 0.4), Vector3(8.1, CEIL_H, 3.5), m_wall)
	solid(geo, "WallMidB", Vector3(7.9, 0, 4.5), Vector3(8.1, CEIL_H, 7.6), m_wall)
	solid(geo, "WallMidLintel", Vector3(7.9, 2.2, 3.5), Vector3(8.1, CEIL_H, 4.5), m_wall)
	if bad:
		# Sealed closet, separate from the building: navmesh inside, no way in.
		solid(geo, "ClosetFloor", Vector3(18, -0.2, 0), Vector3(21, 0, 3), m_floor)
		solid(geo, "ClosetCeiling", Vector3(18, CEIL_H, 0), Vector3(21, CEIL_H + 0.2, 3), m_ceil)
		solid(geo, "ClosetS", Vector3(18, 0, 0), Vector3(21, CEIL_H, 0.2), m_wall)
		solid(geo, "ClosetN", Vector3(18, 0, 2.8), Vector3(21, CEIL_H, 3), m_wall)
		solid(geo, "ClosetW", Vector3(18, 0, 0.2), Vector3(18.2, CEIL_H, 2.8), m_wall)
		solid(geo, "ClosetE", Vector3(20.8, 0, 0.2), Vector3(21, CEIL_H, 2.8), m_wall)
	# --- props
	var props: Node3D = c["Props"]
	var uv_size: Vector3 = Vector3(0.3, 0.3, 0.3)
	var m_uv: StandardMaterial3D = uv_mat_for_box(uv_size, 512.0)
	var desk_size: Vector3 = Vector3(1.4, 0.74, 0.7)
	# Room A: desk group near the south wall.
	var desk_a: Node3D = prop(props, "DeskA", Vector3(5.0, 0, 2.0), 0.0, "desk", desk_size,
		Vector3(0, 0.37, 0), m_wood, true, {"support": true})
	var chair_a: Node3D = prop(props, "ChairA", Vector3(5.0, 0, 2.9), 0.0, "chair", Vector3(0.5, 0.9, 0.5),
		Vector3(0, 0.45, 0), m_metal, true)
	_seat(chair_a)
	chair_a.set_meta(&"faces", NodePath("../DeskA"))
	var mon_a: Node3D = prop(props, "MonitorA", Vector3(5.0, 0.74, 1.95), 180.0, "monitor", Vector3(0.5, 0.35, 0.05),
		Vector3(0, 0.175, 0), m_metal, false)
	mon_a.set_meta(&"faces", NodePath("../ChairA"))
	prop(props, "BoxA", Vector3(4.55, 0.74, 2.1), 0.0, "box", uv_size, Vector3(0, 0.15, 0), m_uv, false)
	_lamp(props, "LampA", Vector3(4.0, CEIL_H, 4.0), m_lamp, false)
	prop(props, "CameraA", Vector3(6.5, 2.6, 7.6), 0.0, "camera", Vector3(0.2, 0.2, 0.3), Vector3(0, 0, -0.15),
		m_metal, false, {"mount": "wall"})
	prop(props, "PictureA", Vector3(0.4, 1.5, 4.0), -90.0, "picture", Vector3(0.8, 0.6, 0.03), Vector3(0, 0, -0.015),
		m_wood, false, {"mount": "wall"})
	# Room B: rotated desk group, different layout.
	prop(props, "DeskB", Vector3(13.0, 0, 5.5), 90.0, "desk", desk_size, Vector3(0, 0.37, 0), m_wood, true,
		{"support": true})
	var chair_b: Node3D = prop(props, "ChairB", Vector3(12.1, 0, 5.5), -90.0, "chair", Vector3(0.5, 0.9, 0.5),
		Vector3(0, 0.45, 0), m_metal, true)
	_seat(chair_b)
	chair_b.set_meta(&"faces", NodePath("../DeskB"))
	var mon_b: Node3D = prop(props, "MonitorB", Vector3(13.05, 0.74, 5.5), 90.0, "monitor", Vector3(0.5, 0.35, 0.05),
		Vector3(0, 0.175, 0), m_metal, false)
	mon_b.set_meta(&"faces", NodePath("../ChairB"))
	prop(props, "BoxB", Vector3(13.0, 0.74, 6.0), 0.0, "box", uv_size, Vector3(0, 0.15, 0), m_uv, false)
	_lamp(props, "LampB", Vector3(12.0, CEIL_H, 4.0), m_lamp, true)
	prop(props, "CameraB", Vector3(15.6, 2.6, 2.0), 90.0, "camera", Vector3(0.2, 0.2, 0.3), Vector3(0, 0, -0.15),
		m_metal, false, {"mount": "wall"})
	prop(props, "PictureB", Vector3(11.0, 1.5, 7.6), 0.0, "picture", Vector3(0.8, 0.6, 0.03), Vector3(0, 0, -0.015),
		m_wood, false, {"mount": "wall"})
	if bad:
		prop(props, "FloatBox", Vector3(6.5, 0.1, 2.0), 0.0, "box", Vector3(0.4, 0.4, 0.4), Vector3(0, 0.2, 0),
			m_wood, false)
		prop(props, "WallClipBox", Vector3(5.0, 0, 0.5), 0.0, "box", Vector3(0.4, 0.4, 0.4), Vector3(0, 0.2, 0),
			m_wood, true)
		prop(props, "NullMatMesh", Vector3(13.0, 0, 3.5), 0.0, "box", Vector3(0.4, 0.4, 0.4), Vector3(0, 0.2, 0),
			null, false)
	# --- lighting
	var light_root: Node3D = c["Lighting"]
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.35, 0.38)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = env
	light_root.add_child(we)
	if bad:
		var bare: OmniLight3D = OmniLight3D.new()
		bare.name = "BareLight"
		bare.position = Vector3(10.0, 2.5, 4.0)
		light_root.add_child(bare)
	# --- navigation agent settings (baked by make_lc_fixtures.gd)
	var nm: NavigationMesh = NavigationMesh.new()
	nm.cell_size = 0.1
	nm.cell_height = 0.05
	nm.agent_radius = 0.35
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.filter_baking_aabb = AABB(Vector3(-5, -1, -5), Vector3(40, 3.7, 20))
	nav.navigation_mesh = nm
	# --- rooms and zones
	for rd: Array in [["RoomA", &"room_a", Vector3(4.15, 1.4, 4.0)], ["RoomB", &"room_b", Vector3(11.85, 1.4, 4.0)]]:
		var rv: RoomVolume = RoomVolume.new()
		rv.name = rd[0]
		rv.room_id = rd[1]
		rv.purpose = &"office"
		rv.dressing_kit = &"lc_office"
		area_box(rv, rd[2], Vector3(7.5, CEIL_H, 7.2))
		(c["Rooms"] as Node3D).add_child(rv)
	var esc: MapZone = MapZone.new()
	esc.name = "EscapeZone"
	esc.kind = MapZone.Kind.ESCAPE
	area_box(esc, Vector3(2.0, 1.25, 3.5), Vector3(2.0, 2.5, 2.0))
	(c["Zones"] as Node3D).add_child(esc)
	var sec: MapZone = MapZone.new()
	sec.name = "SecureZone"
	sec.kind = MapZone.Kind.SECURE_LOOT
	area_box(sec, Vector3(14.0, 1.25, 6.9), Vector3(2.0, 2.5, 1.2))
	(c["Zones"] as Node3D).add_child(sec)
	# --- spawns
	var sp: Node3D = c["Spawns"]
	spawn(sp, "PlayerSpawn1", SpawnPoint.Kind.PLAYER, Vector3(1.5, 0, 6.5))
	spawn(sp, "PlayerSpawn2", SpawnPoint.Kind.PLAYER, Vector3(2.5, 0, 6.5))
	spawn(sp, "PlayerSpawn3", SpawnPoint.Kind.PLAYER, Vector3(3.5, 0, 6.5))
	spawn(sp, "PlayerSpawn4", SpawnPoint.Kind.PLAYER, Vector3(1.5, 0, 5.5))
	if bad:
		spawn(sp, "PlayerSpawn5", SpawnPoint.Kind.PLAYER, Vector3(19.5, 0, 1.5))
	spawn(sp, "PoliceWest", SpawnPoint.Kind.POLICE, Vector3(1.5, 0, 1.5))
	spawn(sp, "PoliceEast", SpawnPoint.Kind.POLICE, Vector3(14.5, 0, 1.5))
	spawn(sp, "PoliceNorth", SpawnPoint.Kind.POLICE, Vector3(8.9, 0, 7.0))
	var guard: SpawnPoint = spawn(sp, "Guard1", SpawnPoint.Kind.GUARD, Vector3(10.0, 0, 6.5))
	# --- patrols
	var graph: PatrolGraph = PatrolGraph.new()
	graph.name = "Main"
	(c["Patrols"] as Node3D).add_child(graph)
	var pts: Array[PatrolPoint] = []
	for pd: Array in [["P1", Vector3(10.0, 0, 1.5)], ["P2", Vector3(14.5, 0, 3.0)], ["P3", Vector3(10.5, 0, 6.0)],
			["P4", Vector3(6.0, 0, 4.0)]]:
		var pp: PatrolPoint = PatrolPoint.new()
		pp.name = pd[0]
		pp.position = pd[1]
		graph.add_child(pp)
		pts.append(pp)
	for i: int in range(4):
		pts[i].links = [NodePath("../" + String(pts[(i + 1) % 4].name)), NodePath("../" + String(pts[(i + 3) % 4].name))]
	if bad:
		var lonely: PatrolPoint = PatrolPoint.new()
		lonely.name = "LonelyPoint"
		lonely.position = Vector3(11.0, 0, 3.0)
		graph.add_child(lonely)
	guard.patrol_graph = NodePath("../../Patrols/Main")
	var cover: TacticalPoint = TacticalPoint.new()
	cover.name = "Cover1"
	cover.position = Vector3(6.5, 0, 6.5)
	(c["Tactical"] as Node3D).add_child(cover)
	# --- gameplay: door, loot spawn, objective
	var gp: Node3D = c["Gameplay"]
	var door: Node3D = Node3D.new()
	door.name = "DoorMid"
	door.position = Vector3(8.0, 0, 3.55)
	door.rotation_degrees = Vector3(0, -90, 0)
	door.set_meta(&"kind", "door")
	gp.add_child(door)
	var frame: Node3D = Node3D.new()
	frame.name = "Frame"
	door.add_child(frame)
	var leaf: Node3D = Node3D.new()
	leaf.name = "Leaf"
	door.add_child(leaf)
	var leaf_mesh: MeshInstance3D = MeshInstance3D.new()
	leaf_mesh.name = "Mesh"
	leaf_mesh.position = Vector3(0.45, 1.05, 0)
	leaf_mesh.mesh = _box_mesh(Vector3(0.9, 2.1, 0.04), m_wood)
	leaf.add_child(leaf_mesh)
	var loot: Marker3D = Marker3D.new()
	loot.name = "LootSpawn01"
	loot.position = Vector3(10.0, 0, 2.0)
	loot.set_meta(&"kind", "loot_spawn")
	gp.add_child(loot)
	var obj: Node3D = Node3D.new()
	obj.name = "VaultConsole"
	obj.set_script(load("res://tests/c/fixtures/lc_fixture_objective.gd"))
	obj.set(&"objective_tag", &"vault")
	obj.position = Vector3(14.5, 0, 4.0)
	gp.add_child(obj)
	var use: Marker3D = Marker3D.new()
	use.name = "UsePoint"
	use.position = Vector3(-0.8, 0, 0)
	obj.add_child(use)
	# --- variants
	var vt: HeistVariantTable = HeistVariantTable.new()
	vt.rules = [{"group": &"loot_spot", "pick": Vector2i(1, 1)}]
	for vd: Array in [["LootA", &"loot_a", Vector3(10.0, 0, 4.5)], ["LootB", &"loot_b", Vector3(6.0, 0, 5.5)]]:
		var slot: VariantSlot = VariantSlot.new()
		slot.name = vd[0]
		slot.slot_group = &"loot_spot"
		slot.slot_id = vd[1]
		slot.position = vd[2]
		(c["Variants"] as Node3D).add_child(slot)
		var spot: Marker3D = Marker3D.new()
		spot.name = "LootSpot"
		spot.set_meta(&"kind", "loot_spawn")
		slot.add_child(spot)
	# --- review cameras
	var cams: Node3D = c["ReviewCameras"]
	var shots: Array = [
		["A_SW", Vector3(1.0, 1.65, 1.0), Vector3(5.0, 0.8, 4.0)], ["A_NE", Vector3(7.4, 1.65, 7.1), Vector3(4.0, 0.8, 2.0)],
		["A_Desk", Vector3(6.5, 1.65, 4.0), Vector3(5.0, 0.7, 2.0)], ["A_Door", Vector3(2.0, 1.65, 4.0), Vector3(8.0, 1.0, 4.0)],
		["A_Camera", Vector3(4.0, 1.65, 5.0), Vector3(6.5, 2.6, 7.6)], ["A_Picture", Vector3(3.0, 1.65, 4.0), Vector3(0.4, 1.5, 4.0)],
		["B_SW", Vector3(8.6, 1.65, 1.0), Vector3(13.0, 0.8, 5.0)], ["B_NE", Vector3(15.1, 1.65, 7.1), Vector3(11.0, 0.8, 2.0)],
		["B_Desk", Vector3(11.0, 1.65, 3.5), Vector3(13.0, 0.7, 5.5)], ["B_Door", Vector3(14.0, 1.65, 4.0), Vector3(8.0, 1.0, 4.0)],
		["B_Camera", Vector3(12.0, 1.65, 4.0), Vector3(15.6, 2.6, 2.0)], ["B_Zone", Vector3(10.0, 1.65, 3.0), Vector3(14.0, 0.5, 6.9)],
	]
	var paths: Array[NodePath] = []
	for sd: Array in shots:
		var mk: Marker3D = Marker3D.new()
		mk.name = sd[0]
		cams.add_child(mk)
		mk.look_at_from_position(sd[1], sd[2], Vector3.UP)
		mk.set_meta(&"caption", "fixture shot %s" % sd[0])
		paths.append(NodePath("ReviewCameras/" + String(sd[0])))
	var top: Marker3D = Marker3D.new()
	top.name = "TopDownPlan"
	cams.add_child(top)
	top.position = Vector3(8.0, 30.0, 4.0)
	top.rotation_degrees = Vector3(-90, 0, 0)
	top.set_meta(&"size", 18.0)
	top.set_meta(&"caption", "top-down plan")
	paths.append(NodePath("ReviewCameras/TopDownPlan"))
	map.review_cameras = paths
	# --- resources
	var hd: HeistDef = HeistDef.new()
	hd.id = &"lc_fixture"
	hd.display_name = "Levelcheck fixture"
	map.heist_def = hd
	map.variant_table = vt
	map.floor_heights = PackedFloat32Array([0.0])
	_own(map, map)
	return map


static func _seat(chair: Node3D) -> void:
	var seat: Marker3D = Marker3D.new()
	seat.name = "Seat"
	seat.position = Vector3(0, 0.45, 0)
	chair.add_child(seat)


static func _lamp(parent: Node, name: String, pos: Vector3, mat: Material, shadow: bool) -> Node3D:
	var lamp: Node3D = prop(parent, name, pos, 0.0, "light_fixture", Vector3(0.6, 0.1, 0.6), Vector3(0, -0.05, 0), mat,
		false, {"mount": "ceiling"})
	lamp.add_to_group(&"fixture", true)
	var l: OmniLight3D = OmniLight3D.new()
	l.name = "Light"
	l.position = Vector3(0, -0.25, 0)
	l.omni_range = 9.0
	l.light_energy = 1.6
	l.light_color = Color(1.0, 0.88, 0.72)
	l.shadow_enabled = shadow
	lamp.add_child(l)
	return lamp


## Bakes the map's navmesh from its static colliders. Map must be inside the tree.
static func bake(map: HeistMap) -> void:
	var nav: NavigationRegion3D = map.get_node("Navigation")
	var nm: NavigationMesh = nav.navigation_mesh
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, map)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
