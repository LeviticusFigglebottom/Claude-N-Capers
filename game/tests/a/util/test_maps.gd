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
