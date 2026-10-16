## PO6-17: assault-event visuals (tools/blender/props/assault_events.py) keep the node contract ENV A codes
## against (docs/levels/_art/po6_17/README.md): turret van, sentry turret, police helicopter and the three
## breach points, plus the Glasshouse `AssaultEvents` markers. Owner: ENV C.
extends TestCase

const DIR: String = "res://world/props/assault_event/"
const GH: String = "res://world/heists/glasshouse/glasshouse.tscn"
const BREACHES: Dictionary = {
	"prop_breach_wall": Vector2(1.0, 2.2), "prop_breach_window": Vector2(1.0, 2.1), "prop_breach_ceiling": Vector2(1.2, 1.2),
}


func _load(id: String) -> Node3D:
	var ps: PackedScene = load(DIR + id + ".tscn") as PackedScene
	assert_true(ps != null, "%s loads" % id)
	return ps.instantiate() as Node3D if ps != null else null


func _node(root: Node3D, path: String) -> Node3D:
	var n: Node3D = root.get_node_or_null(NodePath("Model/" + path)) as Node3D
	assert_true(n != null, "%s: Model/%s" % [root.name, path])
	return n


func _pos(root: Node3D, path: String) -> Vector3:
	var n: Node3D = _node(root, path)
	if n == null:
		return Vector3.ZERO
	var t: Transform3D = Transform3D.IDENTITY
	var c: Node = n
	while c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t.origin


func test_turret_van() -> void:
	var van: Node3D = _load("prop_turret_van")
	if van == null:
		return
	for p: String in ["Body", "DoorL", "DoorR", "TurretMount", "ExitPoint"]:
		_node(van, p)
	assert_true(_pos(van, "TurretMount").y > 2.5, "turret mount on the roof")
	assert_true(_pos(van, "DoorL").x > 0.5 and _pos(van, "DoorR").x < -0.5, "DoorL at +X, DoorR at -X")
	assert_true(_pos(van, "DoorL").z < -2.8, "rear doors at -Z (nose +Z)")
	assert_true(_pos(van, "ExitPoint").z < -3.5 and is_zero_approx(_pos(van, "ExitPoint").y), "ExitPoint behind the rear, on the ground")
	assert_true(van.find_children("*", "CollisionObject3D", true, false).is_empty(), "van carries no collision")
	van.free()


func test_sentry_turret() -> void:
	var t: Node3D = _load("prop_sentry_turret")
	if t == null:
		return
	var yaw: Node3D = _node(t, "Yaw")
	var pitch: Node3D = _node(t, "Yaw/Pitch")
	var muzzle: Node3D = _node(t, "Yaw/Pitch/Muzzle")
	if yaw == null or pitch == null or muzzle == null:
		t.free()
		return
	assert_true(_pos(t, "Yaw/Pitch/Muzzle").z < -0.7, "muzzle forward at -Z")
	assert_true(yaw.basis.is_equal_approx(Basis.IDENTITY) and pitch.basis.is_equal_approx(Basis.IDENTITY), "rest pose = identity")
	t.free()


func test_police_helicopter() -> void:
	var h: Node3D = _load("prop_police_helicopter")
	if h == null:
		return
	for p: String in ["Body", "Rotor", "TailRotor", "RopeL", "RopeR", "SniperSeat", "Spotlight"]:
		_node(h, p)
	assert_true(_pos(h, "RopeL").x < -0.8 and _pos(h, "RopeR").x > 0.8, "RopeL at -X, RopeR at +X")
	assert_true(_pos(h, "Spotlight").z < -2.0, "spotlight under the nose (-Z)")
	assert_true(_pos(h, "TailRotor").z > 6.0, "tail rotor at +Z")
	assert_true(_pos(h, "Rotor").y > 2.5, "main rotor on the mast")
	h.free()


func test_breach_points() -> void:
	for id: String in BREACHES:
		var b: Node3D = _load(id)
		if b == null:
			continue
		var intact: Node3D = _node(b, "Intact")
		var blown: Node3D = _node(b, "Blown")
		for p: String in ["Charge", "EntryPoint", "ExitPoint"]:
			_node(b, p)
		if intact == null or blown == null:
			b.free()
			continue
		assert_true(intact.visible and not blown.visible, "%s: Intact shown, Blown hidden" % id)
		assert_false(intact.find_children("*", "StaticBody3D", true, false).is_empty(), "%s: Intact collides" % id)
		assert_true(blown.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s: Blown has no collision" % id)
		# cops' side is +Z, the room -Z (the ceiling scene: -Z = down)
		assert_true(_pos(b, "EntryPoint").z > 0.0 and _pos(b, "ExitPoint").z < -0.5, "%s: entry +Z, exit -Z" % id)
		var shape: CollisionShape3D = intact.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
		var bb: AABB = _xform_to(b, shape) * _shape_aabb(shape)
		var size: Vector2 = BREACHES[id]
		assert_true(bb.size.x >= size.x - 0.01 and bb.size.y >= size.y - 0.01, "%s: infill covers %s (%s)" % [id, size, bb.size])
		b.free()


func test_glasshouse_markers() -> void:
	var ps: PackedScene = load(GH) as PackedScene
	var map: Node3D = ps.instantiate() as Node3D
	var ae: Node3D = map.get_node_or_null(^"AssaultEvents") as Node3D
	assert_true(ae != null and ae.is_in_group(&"assault_events"), "AssaultEvents (group assault_events)")
	if ae == null:
		map.free()
		return
	var counts: Dictionary = {"TurretVan": 0, "HeliOrbit": 0, "HeliDrop": 0, "Breach": 0}
	var rappels: int = 0
	for c: Node in ae.get_children():
		if c is NavigationLink3D:
			# PO6-17 roof -> alley police rappel: one-way, RappelLinks meta, roof start above the alley end.
			var l: NavigationLink3D = c as NavigationLink3D
			assert_false(l.bidirectional, "%s one-way" % c.name)
			assert_true(l.has_meta(RappelLinks.META), "%s is a rappel link" % c.name)
			assert_true(l.start_position.y - l.end_position.y > 6.0, "%s goes roof -> ground" % c.name)
			rappels += 1
			continue
		assert_true(c is Marker3D, "%s is a Marker3D" % c.name)
		var kind: String = String(c.name).get_slice("_", 0)
		assert_true(counts.has(kind), "%s: known marker kind" % c.name)
		counts[kind] = int(counts.get(kind, 0)) + 1
		if kind == "HeliOrbit":
			assert_true(float(c.get_meta(&"radius", 0.0)) > 10.0, "%s radius" % c.name)
		if kind == "Breach":
			assert_true(String(c.get_meta(&"kind", "")) in ["wall", "ceiling", "window"], "%s kind" % c.name)
			assert_true(c.get_meta(&"size", Vector2.ZERO) is Vector2, "%s size" % c.name)
			assert_true(c.get_child_count() == 1, "%s holds its breach scene" % c.name)
	assert_eq(int(counts["TurretVan"]), 2, "2 turret-van spots")
	assert_eq(int(counts["HeliOrbit"]), 1, "1 helicopter orbit")
	assert_eq(int(counts["HeliDrop"]), 2, "2 rappel drops")
	assert_eq(rappels, 1, "the roof -> alley rappel link")
	assert_true(int(counts["Breach"]) >= 3 and int(counts["Breach"]) <= 4, "3-4 breach points")
	map.free()


func _xform_to(root: Node3D, n: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var c: Node = n
	while c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _shape_aabb(cs: CollisionShape3D) -> AABB:
	var s: Shape3D = cs.shape
	if s is BoxShape3D:
		return AABB(-(s as BoxShape3D).size * 0.5, (s as BoxShape3D).size)
	var pts: PackedVector3Array = (s as ConvexPolygonShape3D).points if s is ConvexPolygonShape3D else PackedVector3Array()
	var bb: AABB = AABB(pts[0], Vector3.ZERO) if not pts.is_empty() else AABB()
	for q: Vector3 in pts:
		bb = bb.expand(q)
	return bb
