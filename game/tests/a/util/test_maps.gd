## Builds tiny HeistMap scenes in code for ENV A unit tests (no ENV C dependency).
class_name ATestMaps
extends RefCounted


static func _own(n: Node, root: Node) -> void:
	n.owner = root
	for c: Node in n.get_children():
		_own(c, root)


## Wait until the World3D navigation map holds exactly `rt`'s NavigationRegion3Ds (no region left over
## from an earlier test), then force a synchronous map update. Godot syncs navigation maps
## asynchronously (navigation/world/map_use_async_iterations), so under load a path queried right
## after launch can still run on a stale map iteration. Returns false on timeout.
static func await_nav_synced(rt: HeistRuntime, timeout_s: float = 5.0) -> bool:
	var tree: SceneTree = rt.get_tree()
	var map: RID = rt.get_viewport().world_3d.navigation_map
	var want: Array[RID] = []
	for n: Node in rt.find_children("*", "NavigationRegion3D", true, false):
		want.append((n as NavigationRegion3D).get_rid())
	var deadline: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var have: Array[RID] = NavigationServer3D.map_get_regions(map)
		var exact: bool = have.size() == want.size()
		for r: RID in want:
			exact = exact and have.has(r)
		if exact:
			NavigationServer3D.map_force_update(map)
			return true
		await tree.physics_frame
	return false


## A 30x30 m floor, PLAYER spawns, optional guard/civilian spawns and variant slots.
static func basic(guards: int = 1, civilians: int = 0, variant_groups: Dictionary = {}, table: HeistVariantTable = null) -> PackedScene:
	var root: HeistMap = HeistMap.new()
	root.name = "TestMap"
	root.variant_table = table
	var geo: Node3D = Node3D.new()
	geo.name = "Geometry"
	root.add_child(geo)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	floor_body.add_child(col)
	geo.add_child(floor_body)
	for nm: String in ["Props", "Lighting", "Zones", "Rooms", "Spawns", "Patrols", "Tactical", "Gameplay", "Variants", "ReviewCameras"]:
		var n: Node3D = Node3D.new()
		n.name = nm
		root.add_child(n)
	var spawns: Node3D = root.get_node("Spawns")
	for i: int in range(4):
		var sp: SpawnPoint = SpawnPoint.new()
		sp.name = "Player%d" % i
		sp.kind = SpawnPoint.Kind.PLAYER
		sp.position = Vector3(-10 + i, 0.05, 10)
		spawns.add_child(sp)
	for i: int in range(guards):
		var g: SpawnPoint = SpawnPoint.new()
		g.name = "Guard%d" % i
		g.kind = SpawnPoint.Kind.GUARD
		g.position = Vector3(5 + 3 * i, 0.05, -5)
		spawns.add_child(g)
	for i: int in range(civilians):
		var c: SpawnPoint = SpawnPoint.new()
		c.name = "Civ%d" % i
		c.kind = SpawnPoint.Kind.CIVILIAN
		c.position = Vector3(-5 - 2 * i, 0.05, -5)
		spawns.add_child(c)
	var variants: Node3D = root.get_node("Variants")
	for group: StringName in variant_groups:
		for sid: StringName in variant_groups[group]:
			var vs: VariantSlot = VariantSlot.new()
			vs.name = "%s_%s" % [group, sid]
			vs.slot_group = group
			vs.slot_id = sid
			var marker: Node3D = Node3D.new()
			marker.name = "Content"
			vs.add_child(marker)
			variants.add_child(vs)
	var mission: Node = Node.new()
	mission.name = "Mission"
	mission.set_script(load("res://systems/heist/heist_mission.gd"))
	root.add_child(mission)
	_own_children(root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


static func _own_children(root: Node) -> void:
	for c: Node in root.get_children():
		_own(c, root)


## basic() plus a PatrolGraph "Patrols/Graph" laid out as a cols x rows grid of linked PatrolPoints
## (4-neighbour links, so it branches and has loops) starting at guard 0's spawn and extending
## along +X / -Z. Every guard SpawnPoint gets `patrol_graph` set to it when `link_spawns`.
## `pause_range` is applied to every point.
static func with_patrol_grid(guards: int = 1, civilians: int = 0, cols: int = 3, rows: int = 3,
		spacing: float = 3.0, link_spawns: bool = true, pause_range: Vector2 = Vector2.ZERO) -> PackedScene:
	var root: HeistMap = basic(guards, civilians).instantiate() as HeistMap
	var graph: PatrolGraph = PatrolGraph.new()
	graph.name = "Graph"
	root.get_node("Patrols").add_child(graph)
	var origin: Vector3 = Vector3(5, 0.05, -5)
	for r: int in range(rows):
		for c: int in range(cols):
			var p: PatrolPoint = PatrolPoint.new()
			p.name = "P_%d_%d" % [c, r]
			p.position = origin + Vector3(c * spacing, 0.0, -r * spacing)
			p.pause_range = pause_range
			if c + 1 < cols:
				p.links.append(NodePath("../P_%d_%d" % [c + 1, r]))
			if r + 1 < rows:
				p.links.append(NodePath("../P_%d_%d" % [c, r + 1]))
			graph.add_child(p)
	if link_spawns:
		for sp: Node in root.get_node("Spawns").get_children():
			var g: SpawnPoint = sp as SpawnPoint
			if g != null and g.kind == SpawnPoint.Kind.GUARD:
				g.patrol_graph = NodePath("../../Patrols/Graph")
	_own_children(root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


## Runtime helper: add a MapZone box (centre, size) under `parent` (e.g. rt.map). Wait one physics
## frame before querying it.
static func add_zone(parent: Node, kind: MapZone.Kind, center: Vector3, size: Vector3) -> MapZone:
	var z: MapZone = MapZone.new()
	z.kind = kind
	z.name = "Zone_%d" % parent.get_child_count()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	z.add_child(cs)
	parent.add_child(z)
	z.global_position = center
	return z


## Runtime helper: a static wall box (world_static layer) that blocks vision rays.
static func add_wall(parent: Node, center: Vector3, size: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.name = "Wall_%d" % parent.get_child_count()
	b.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	parent.add_child(b)
	b.global_position = center
	return b


## Runtime helper: a brainless NpcBase observer at `pos` looking along `facing` (horizontal).
static func add_npc_observer(rt: HeistRuntime, role: StringName, pos: Vector3, facing: Vector3) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = role
	npc.detection_preset = &"civilian" if role == &"civilian" else &"guard"
	npc.name = "Obs_%s_%d" % [role, rt.dynamic_root.get_child_count()]
	rt.dynamic_root.add_child(npc)
	npc.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP), pos)
	NetIds.claim(npc)
	return npc


## Runtime helper (A1-07): instance gameplay prefab `prefab` under the map's Gameplay node at `pos`.
## `setup` (optional) is called with the prefab before it enters the tree.
static func add_prefab(rt: HeistRuntime, prefab: String, pos: Vector3, setup: Callable = Callable()) -> GameplayPrefab:
	var path: String = "res://systems/prefabs/%s/%s.tscn" % [prefab, prefab]
	var p: GameplayPrefab = (load(path) as PackedScene).instantiate() as GameplayPrefab
	p.position = pos
	if setup.is_valid():
		setup.call(p)
	rt.map.get_node(^"Gameplay").add_child(p)
	return p


## Runtime helper (A1-07): hold interact on `target_net_id` with crew `slot` (explicit target).
static func hold_interact(rt: HeistRuntime, slot: int, target_net_id: int) -> void:
	var c: CrewController = rt.crew_controller(slot) as CrewController
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = c.look_yaw
	i.interact = true
	i.interact_target_net_id = target_net_id
	rt.set_bot_intent(slot, i)


## A2-07: basic() with `def` as the map's HeistDef, plus two PLAYER SpawnPoints per tag in
## `preplan_spawn_tags` (at x = 10 + 3 * tag index, z = 10 / 11) and PREPLAN_POINT Node3Ds under
## Gameplay/Preplan: `preplan_points` maps a node name to its position. A name starting with "meta:"
## makes a node named "PointN" whose `asset_slot` metadata is the rest of the name.
static func with_heist_def(def: HeistDef, guards: int = 0, civilians: int = 0,
		preplan_spawn_tags: Array[StringName] = [], preplan_points: Dictionary = {},
		variant_groups: Dictionary = {}, table: HeistVariantTable = null) -> PackedScene:
	var root: HeistMap = basic(guards, civilians, variant_groups, table).instantiate() as HeistMap
	root.heist_def = def
	var spawns: Node = root.get_node("Spawns")
	for ti: int in range(preplan_spawn_tags.size()):
		for k: int in range(2):
			var sp: SpawnPoint = SpawnPoint.new()
			sp.name = "Preplan_%s_%d" % [preplan_spawn_tags[ti], k]
			sp.kind = SpawnPoint.Kind.PLAYER
			sp.tags = [preplan_spawn_tags[ti]] as Array[StringName]
			sp.position = Vector3(10 + 3 * ti, 0.05, 10 + k)
			spawns.add_child(sp)
	var holder: Node3D = Node3D.new()
	holder.name = "Preplan"
	root.get_node("Gameplay").add_child(holder)
	var idx: int = 0
	for key: Variant in preplan_points:
		var p: Node3D = Node3D.new()
		var nm: String = String(key)
		if nm.begins_with("meta:"):
			p.name = "Point%d" % idx
			p.set_meta(&"asset_slot", StringName(nm.substr(5)))
		else:
			p.name = nm
		p.position = preplan_points[key]
		p.add_to_group(G.PREPLAN_POINT, true)
		holder.add_child(p)
		idx += 1
	_own_children(root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


## A2-01: basic() plus a wall along z = 0 (x in [-14, 14], 3 m high) with a 0.9 m doorway centred on
## x = 0 and a baked navmesh (`Navigation`, project nav defaults D-025) through the doorway. Add a
## Door prefab at the origin at runtime (add_prefab(rt, "door", Vector3.ZERO, ...)).
## PO6-16: `room` (x half-width, depth) > 0 also closes a room behind the doorway on the -Z side: walls at
## x = +-room.x and z = -room.y (3 m high), so the doorway is the room's only entrance.
static func with_doorway_wall(guards: int = 0, civilians: int = 0, room: Vector2 = Vector2.ZERO) -> PackedScene:
	var root: HeistMap = basic(guards, civilians).instantiate() as HeistMap
	var geo: Node3D = root.get_node("Geometry")
	if room.x > 0.0 and room.y > 0.0:
		var specs: Array[Array] = [
			[Vector3(-room.x, 1.5, -room.y * 0.5), Vector3(0.2, 3.0, room.y)],
			[Vector3(room.x, 1.5, -room.y * 0.5), Vector3(0.2, 3.0, room.y)],
			[Vector3(0.0, 1.5, -room.y), Vector3(room.x * 2.0 + 0.2, 3.0, 0.2)]]
		for i: int in range(specs.size()):
			var rb: StaticBody3D = StaticBody3D.new()
			rb.name = "RoomWall%d" % i
			var rcs: CollisionShape3D = CollisionShape3D.new()
			var rbox: BoxShape3D = BoxShape3D.new()
			rbox.size = specs[i][1]
			rcs.shape = rbox
			rb.add_child(rcs)
			rb.position = specs[i][0]
			geo.add_child(rb)
	for side: float in [-1.0, 1.0]:
		var b: StaticBody3D = StaticBody3D.new()
		b.name = "Wall%s" % ("W" if side < 0.0 else "E")
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(14.0 - 0.45, 3.0, 0.2)
		cs.shape = box
		b.add_child(cs)
		b.position = Vector3(side * (0.45 + box.size.x * 0.5), 1.5, 0.0)
		geo.add_child(b)
	return _bake_nav(root, geo)


## PO6-15: basic() plus a straight corridor along Z (walls at x = +-width / 2, z in [-length / 2, length / 2],
## 3 m high, open at both ends) and a baked navmesh (`Navigation`, project nav defaults D-025).
static func with_corridor(width: float = 2.4, length: float = 16.0) -> PackedScene:
	var root: HeistMap = basic(0, 0).instantiate() as HeistMap
	var geo: Node3D = root.get_node("Geometry")
	for side: float in [-1.0, 1.0]:
		var b: StaticBody3D = StaticBody3D.new()
		b.name = "Corridor%s" % ("W" if side < 0.0 else "E")
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.2, 3.0, length)
		cs.shape = box
		b.add_child(cs)
		b.position = Vector3(side * (width * 0.5 + 0.1), 1.5, 0.0)
		geo.add_child(b)
	return _bake_nav(root, geo)


## OF-A4: basic() plus a second floor and a baked navmesh (`Navigation`, project nav defaults D-025): an upper
## platform (top y = 2.5, x in [6, 10], z in [-6, 0]) reached by a 22.6 deg ramp rising along +X from x = 0 to x = 6
## (z in [-4, -2]), and an unconnected island platform (top y = 2.5, x in [-10, -6], z in [-10, -6]) with no way up.
static func with_two_floors() -> PackedScene:
	var root: HeistMap = basic(0, 0).instantiate() as HeistMap
	var geo: Node3D = root.get_node("Geometry")
	var ang: float = atan2(2.5, 6.0)
	var normal: Vector3 = Vector3(-sin(ang), cos(ang), 0.0)
	var specs: Array[Array] = [
		["Upper", Vector3(8.0, 2.35, -3.0), Vector3(4.0, 0.3, 6.0), 0.0],
		["Island", Vector3(-8.0, 2.35, -8.0), Vector3(4.0, 0.3, 4.0), 0.0],
		["Ramp", Vector3(3.0, 1.25, -3.0) - normal * 0.1, Vector3(6.8, 0.2, 2.0), ang]]
	for spec: Array in specs:
		var b: StaticBody3D = StaticBody3D.new()
		b.name = String(spec[0])
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = spec[2]
		cs.shape = box
		b.add_child(cs)
		b.position = spec[1]
		b.rotation = Vector3(0.0, 0.0, float(spec[3]))
		geo.add_child(b)
	return _bake_nav(root, geo)


## Bakes a navmesh over `geo` (project nav defaults D-025) into a `Navigation` region of `root`, packs and frees root.
static func _bake_nav(root: HeistMap, geo: Node3D,
		bake_aabb: AABB = AABB(Vector3(-15.0, -1.0, -15.0), Vector3(30.0, 4.0, 30.0))) -> PackedScene:
	var nav: NavigationRegion3D = NavigationRegion3D.new()
	nav.name = "Navigation"
	root.add_child(nav)
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
	nm.filter_baking_aabb = bake_aabb
	var holder: Node3D = Node3D.new()  # parse needs the geometry in a tree for global transforms
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(holder)
	holder.add_child(root)
	var src: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, geo)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	holder.remove_child(root)
	holder.free()
	nav.navigation_mesh = nm
	_own_children(root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


## A3-08: with_heist_def() plus PREPLAN_POINT Marker3Ds directly under `<Map>/Preplan` (heist_map.md
## v1.2, preplanning.md: node name = point id), in group G.PREPLAN_POINT with `category` metadata.
## `markers`: point id -> Vector3, or point id -> {"pos": Vector3, "category": StringName, "params": Dictionary}.
static func with_preplan_markers(def: HeistDef, preplan_spawn_tags: Array[StringName] = [], markers: Dictionary = {},
		variant_groups: Dictionary = {}, table: HeistVariantTable = null) -> PackedScene:
	var root: HeistMap = with_heist_def(def, 0, 0, preplan_spawn_tags, {}, variant_groups, table).instantiate() as HeistMap
	var holder: Node3D = Node3D.new()
	holder.name = "Preplan"
	root.add_child(holder)
	for key: Variant in markers:
		var spec: Variant = markers[key]
		var m: Marker3D = Marker3D.new()
		m.name = String(key)
		if spec is Dictionary:
			m.position = (spec as Dictionary).get("pos", Vector3.ZERO)
			m.set_meta(&"category", StringName((spec as Dictionary).get("category", &"drop_zone")))
			m.set_meta(&"params", (spec as Dictionary).get("params", {}))
		else:
			m.position = spec
			m.set_meta(&"category", &"drop_zone")
		m.add_to_group(G.PREPLAN_POINT, true)
		holder.add_child(m)
	_own_children(root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


## A3-09: basic() plus extra SpawnPoints. `specs`: [{"kind": SpawnPoint.Kind, "tags": [StringName],
## "pos": Vector3, "name": String (optional)}].
static func with_tagged_spawns(specs: Array[Dictionary], guards: int = 0, civilians: int = 0) -> PackedScene:
	var root: HeistMap = basic(guards, civilians).instantiate() as HeistMap
	var spawns: Node = root.get_node("Spawns")
	for i: int in range(specs.size()):
		var spec: Dictionary = specs[i]
		var sp: SpawnPoint = SpawnPoint.new()
		sp.name = String(spec.get("name", "Tagged%d" % i))
		sp.kind = int(spec.get("kind", SpawnPoint.Kind.PLAYER)) as SpawnPoint.Kind
		var tags: Array[StringName] = []
		for t: Variant in spec.get("tags", []):
			tags.append(StringName(t))
		sp.tags = tags
		sp.position = spec.get("pos", Vector3.ZERO)
		spawns.add_child(sp)
	_own_children(root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


## OF-A2 / OF-A5: basic() plus static slabs (`slabs`: [[centre: Vector3, size: Vector3], ...], world_static),
## RAPPEL TacticalPoints under `Tactical` (`rappels`: [{"name": String, "pos": Vector3, "tags": [StringName]}]),
## extra SpawnPoints (`spawns`: with_tagged_spawns specs) and a navmesh baked over the floor and the slab tops
## inside `bake_aabb` (slabs farther apart than agent_max_climb are separate navmesh islands).
static func with_slabs(slabs: Array, rappels: Array = [], spawns: Array = [],
		bake_aabb: AABB = AABB(Vector3(-15.0, -1.0, -15.0), Vector3(30.0, 20.0, 30.0))) -> PackedScene:
	var root: HeistMap = basic(0, 0).instantiate() as HeistMap
	var geo: Node3D = root.get_node("Geometry")
	for i: int in range(slabs.size()):
		var spec: Array = slabs[i]
		var b: StaticBody3D = StaticBody3D.new()
		b.name = "Slab%d" % i
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = spec[1]
		cs.shape = box
		b.add_child(cs)
		b.position = spec[0]
		geo.add_child(b)
	var tactical: Node = root.get_node("Tactical")
	for i: int in range(rappels.size()):
		var r: Dictionary = rappels[i]
		var tp: TacticalPoint = TacticalPoint.new()
		tp.name = String(r.get("name", "Rappel%d" % i))
		tp.kind = TacticalPoint.Kind.RAPPEL
		var tags: Array[StringName] = []
		for t: Variant in r.get("tags", []):
			tags.append(StringName(t))
		tp.tags = tags
		tp.position = r.get("pos", Vector3.ZERO)
		tactical.add_child(tp)
	var sp_root: Node = root.get_node("Spawns")
	for i: int in range(spawns.size()):
		var spec: Dictionary = spawns[i]
		var sp: SpawnPoint = SpawnPoint.new()
		sp.name = String(spec.get("name", "Extra%d" % i))
		sp.kind = int(spec.get("kind", SpawnPoint.Kind.POLICE)) as SpawnPoint.Kind
		var tags: Array[StringName] = []
		for t: Variant in spec.get("tags", []):
			tags.append(StringName(t))
		sp.tags = tags
		sp.position = spec.get("pos", Vector3.ZERO)
		sp_root.add_child(sp)
	return _bake_nav(root, geo, bake_aabb)
