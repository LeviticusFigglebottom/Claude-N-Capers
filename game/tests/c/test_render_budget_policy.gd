## RenderBudgetPolicy (D-146): interior dressing outside the kept rooms casts no shadow, kept-room dressing moves to
## the sun-skip layer, interior doors stop casting, exterior doors and open rooms keep theirs, ranges are capped.
extends TestCase

var _map: Node3D = null


func _room(id: String, purpose: String, centre: Vector3, size: Vector3) -> void:
	var rv: RoomVolume = RoomVolume.new()
	rv.name = "Room" + id
	rv.room_id = StringName(id)
	rv.purpose = StringName(purpose)
	rv.position = centre
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	rv.add_child(cs)
	_map.get_node("Rooms").add_child(rv)


func _mesh(parent: String, nm: String, pos: Vector3, range_end: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3.ONE * 0.5
	mi.mesh = bm
	mi.position = pos
	mi.visibility_range_end = range_end
	mi.visibility_range_end_margin = range_end * 0.1
	_map.get_node(parent).add_child(mi)
	return mi


func _door(nm: String, pos: Vector3) -> MeshInstance3D:
	var d: Node3D = Node3D.new()
	d.name = nm
	d.position = pos
	_map.get_node("Gameplay/Doors").add_child(d)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	d.add_child(mi)
	return mi


func test_policy() -> void:
	_map = Node3D.new()
	for p: String in ["Rooms", "Props", "Gameplay", "Gameplay/Doors"]:
		var n: Node3D = Node3D.new()
		n.name = p.get_file()
		(_map.get_node(p.get_base_dir()) if p.contains("/") else _map).add_child(n)
	# rooms along x: A (kept) [0, 4], B [4, 8], C [8, 12]; the street beyond x 12 is exterior
	_room("A", "hall", Vector3(2, 1.5, 0), Vector3(4, 3, 4))
	_room("B", "office", Vector3(6, 1.5, 0), Vector3(4, 3, 4))
	_room("C", "office", Vector3(10, 1.5, 0), Vector3(4, 3, 4))
	_room("X", "exterior", Vector3(14, 1.5, 0), Vector3(4, 3, 4))
	var in_a: MeshInstance3D = _mesh("Props", "InA", Vector3(2, 0.5, 0), 40.0)
	var in_b: MeshInstance3D = _mesh("Props", "InB", Vector3(6, 0.5, 0), 40.0)
	var street: MeshInstance3D = _mesh("Props", "Street", Vector3(14, 0.5, 0), 40.0)
	var inner: MeshInstance3D = _door("InnerDoor", Vector3(8, 0, 0))  # between B and C (probes along its local z)
	(_map.get_node("Gameplay/Doors/InnerDoor") as Node3D).rotation_degrees.y = 90.0
	var outer: MeshInstance3D = _door("OuterDoor", Vector3(12, 0, 0))  # C to the exterior
	(_map.get_node("Gameplay/Doors/OuterDoor") as Node3D).rotation_degrees.y = 90.0
	var pol: RenderBudgetPolicy = RenderBudgetPolicy.new()
	pol.roots = PackedStringArray(["Props"])
	pol.door_roots = PackedStringArray(["Gameplay/Doors"])
	pol.cast_keep_rooms = PackedStringArray(["A"])
	pol.range_keep_rooms = PackedStringArray(["A"])
	pol.range_cap = 24.0
	pol.sun_skip_layer = 1 << 4
	_map.add_child(pol)
	add_child(_map)
	pol.apply()
	assert_eq(in_b.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "room B dressing: no shadow")
	assert_eq(in_b.visibility_range_end, 24.0, "room B dressing range capped")
	assert_ne(in_a.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "kept room A keeps casting")
	assert_eq(in_a.layers, 1 << 4, "kept room A moves to the sun-skip layer")
	assert_eq(in_a.visibility_range_end, 40.0)
	assert_ne(street.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "exterior: untouched")
	assert_eq(street.layers, 1)
	assert_eq(inner.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "door between B and C: no shadow")
	assert_ne(outer.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "exterior door keeps casting")
	_map.free()
