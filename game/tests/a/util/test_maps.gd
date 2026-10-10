## Builds tiny HeistMap scenes in code for ENV A unit tests (no ENV C dependency).
class_name ATestMaps
extends RefCounted


static func _own(n: Node, root: Node) -> void:
	n.owner = root
	for c: Node in n.get_children():
		_own(c, root)


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
