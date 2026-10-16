## PO6-17: assault-event visuals (tools/blender/props/assault_events.py) keep the node contract ENV A codes
## against (docs/levels/_art/po6_17/README.md): turret van, sentry turret, police helicopter and the three
## breach points (+ the map-sized variants), plus the `AssaultEvents` markers of Golden Hour, Dockside Burn, Night
## Deposit and Gallery Night. Owner: ENV C.
extends TestCase

const DIR: String = "res://world/props/assault_event/"
const GH: String = "res://world/heists/glasshouse/glasshouse.tscn"
const DB: String = "res://world/heists/dockside_burn/dockside_burn.tscn"
const ND: String = "res://world/heists/night_deposit/night_deposit.tscn"
const GN: String = "res://world/heists/gallery_night/gallery_night.tscn"
const BREACHES: Dictionary = {
	"prop_breach_wall": Vector2(1.0, 2.2), "prop_breach_window": Vector2(1.0, 2.1), "prop_breach_ceiling": Vector2(1.2, 1.2),
	"prop_breach_wall_t40": Vector2(1.0, 2.2), "prop_breach_ceiling_p100_d800": Vector2(1.2, 1.2),
	"prop_breach_ceiling_p100_d550": Vector2(1.2, 1.2),
}
## Infill depth behind the room face (walls) / ceiling [roof-top height, drop to the room floor] (marker frame).
const DEPTHS: Dictionary = {
	"prop_breach_wall": 0.2, "prop_breach_wall_t40": 0.4, "prop_breach_window": 0.4, "prop_breach_ceiling": [0.6, 3.0],
	"prop_breach_ceiling_p100_d800": [1.0, 8.0], "prop_breach_ceiling_p100_d550": [1.0, 5.5],
}
## Per-map markers: counts per kind, rappel links in AssaultEvents, and each breach [kind, room, scene, floor y of
## its ExitPoint (the room floor)].
const DB_EXPECT: Dictionary = {
	"counts": {"TurretVan": 2, "HeliOrbit": 1, "HeliDrop": 2, "Breach": 5}, "rappels": 0,
	"breaches": {
		"Breach_1": ["window", "M1", "prop_breach_window", 3.6], "Breach_2": ["wall", "PL", "prop_breach_wall_t40", 0.0],
		"Breach_3": ["wall", "AN", "prop_breach_wall_t40", 0.0],
		"Breach_4": ["ceiling", "C1", "prop_breach_ceiling_p100_d800", 0.0],
		"Breach_5": ["ceiling", "C2", "prop_breach_ceiling_p100_d800", 0.0]},
}
const ND_EXPECT: Dictionary = {
	"counts": {"TurretVan": 2, "HeliOrbit": 1, "HeliDrop": 2, "Breach": 3}, "rappels": 0,
	"breaches": {
		"Breach_1": ["ceiling", "G9", "prop_breach_ceiling_p100_d550", 0.0],
		"Breach_2": ["ceiling", "G8", "prop_breach_ceiling", 0.0], "Breach_3": ["wall", "G6", "prop_breach_wall_t40", 0.0]},
}
const GN_EXPECT: Dictionary = {
	"counts": {"TurretVan": 2, "HeliOrbit": 1, "HeliDrop": 2, "Breach": 4}, "rappels": 0,
	"breaches": {
		"Breach_1": ["window", "AO", "prop_breach_window", 5.4], "Breach_2": ["wall", "WG", "prop_breach_wall_t40", 0.0],
		"Breach_3": ["wall", "EB", "prop_breach_wall_t40", 0.0], "Breach_4": ["wall", "LD", "prop_breach_wall_t40", 0.0]},
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
		var dep: Variant = DEPTHS[id]
		if dep is Array:
			# ceiling: room floor `drop` below the underside (ExitPoint), the cops' roof `depth` above it (EntryPoint)
			assert_near(_pos(b, "ExitPoint").z, -float(dep[1]), 0.01, "%s: ExitPoint on the room floor" % id)
			assert_near(_pos(b, "EntryPoint").z, float(dep[0]), 0.01, "%s: EntryPoint on the roof" % id)
		else:
			assert_near(bb.size.z, float(dep), 0.01, "%s: infill fills the %.1f m wall" % [id, float(dep)])
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


func test_dockside_burn_markers() -> void:
	_check_map(DB, DB_EXPECT)


func test_night_deposit_markers() -> void:
	_check_map(ND, ND_EXPECT)


func test_gallery_night_markers() -> void:
	_check_map(GN, GN_EXPECT)


## Marker contract on a map (README §5-§7): AssaultEvents (group), Marker3D kinds and counts, orbit radius, the
## breach metas / `Visual` scene, -Z into the room (a ceiling: down, +Y horizontal), ExitPoint on the room floor and
## (walls / windows) the cops' EntryPoint on the other side of the wall; one-way roof -> ground rappel links.
func _check_map(path: String, expect: Dictionary) -> void:
	var map: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	var ae: Node3D = map.get_node_or_null(^"AssaultEvents") as Node3D
	assert_true(ae != null and ae.is_in_group(&"assault_events"), "%s: AssaultEvents (group assault_events)" % path)
	if ae == null:
		map.free()
		return
	var counts: Dictionary = {"TurretVan": 0, "HeliOrbit": 0, "HeliDrop": 0, "Breach": 0}
	var rappels: int = 0
	var breaches: Dictionary = expect["breaches"]
	for c: Node in ae.get_children():
		if c is NavigationLink3D:
			var l: NavigationLink3D = c as NavigationLink3D
			assert_true(not l.bidirectional and l.has_meta(RappelLinks.META), "%s: one-way rappel link" % c.name)
			assert_true(l.start_position.y - l.end_position.y > 3.0, "%s goes roof -> ground" % c.name)
			rappels += 1
			continue
		assert_true(c is Marker3D, "%s is a Marker3D" % c.name)
		var kind: String = String(c.name).get_slice("_", 0)
		assert_true(counts.has(kind), "%s: known marker kind" % c.name)
		counts[kind] = int(counts.get(kind, 0)) + 1
		var m: Marker3D = c as Marker3D
		if kind == "TurretVan":
			assert_true(is_zero_approx(m.basis.z.y) and m.basis.y.is_equal_approx(Vector3.UP), "%s upright" % c.name)
		elif kind == "HeliOrbit":
			assert_true(float(c.get_meta(&"radius", 0.0)) > 10.0 and m.position.y > 25.0, "%s radius / height" % c.name)
		elif kind == "Breach":
			_check_breach(m, breaches.get(String(c.name), []) as Array)
	for k: String in counts:
		assert_eq(int(counts[k]), int((expect["counts"] as Dictionary)[k]), "%s: %s markers" % [path, k])
	assert_eq(rappels, int(expect["rappels"]), "%s: rappel links" % path)
	map.free()


func _check_breach(m: Marker3D, want: Array) -> void:
	assert_eq(want.size(), 4, "%s is an expected breach" % m.name)
	if want.size() != 4:
		return
	var kind: String = String(m.get_meta(&"kind", ""))
	assert_eq(kind, String(want[0]), "%s kind" % m.name)
	assert_eq(String(m.get_meta(&"room", "")), String(want[1]), "%s room" % m.name)
	assert_eq(m.get_meta(&"size", Vector2.ZERO), BREACHES[String(want[2])], "%s size" % m.name)
	assert_true(m.get_child_count() == 1 and m.get_node_or_null(^"Visual") != null, "%s holds its breach scene" % m.name)
	var vis: Node3D = m.get_node_or_null(^"Visual") as Node3D
	if vis == null:
		return
	assert_eq(vis.scene_file_path, DIR + String(want[2]) + ".tscn", "%s scene" % m.name)
	var into: Vector3 = -m.basis.z
	if kind == "ceiling":
		assert_true(into.is_equal_approx(Vector3.DOWN) and is_zero_approx(m.basis.y.y), "%s faces down" % m.name)
	else:
		assert_true(is_zero_approx(into.y), "%s faces horizontally into the room" % m.name)
	var exit: Vector3 = m.transform * _pos(vis, "ExitPoint")
	assert_near(exit.y, float(want[3]), 0.02, "%s ExitPoint on the %s floor" % [m.name, String(want[1])])
	var entry: Vector3 = m.transform * _pos(vis, "EntryPoint")
	if kind != "ceiling":
		assert_true((entry - m.position).dot(into) < -0.5, "%s EntryPoint on the cops' side" % m.name)


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
