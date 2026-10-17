## D-130 (ENV D check_seated_clip): on Glasshouse, Night Deposit, Gallery Night and Shadow Ledger every seated NPC
## spawn on an office / task chair (prop_chair_office / prop_chair_task art) stands on that chair's `Seat`, which is
## 0.12 m in front of the chair's pivot (the catalog wrapper's moved Seat, tools/blender/props `seat_fwd`), so the
## desk_work torso clears the backrest; it faces the chair's way and stays on the baked navmesh. Owner: ENV C.
## Generators: world/heists/shared/npc_seat_spawns.gd (after each map's dressing), sl_builder_base.chair.
extends TestCase

const MAPS: Dictionary = {
	"res://world/heists/glasshouse/glasshouse.tscn": ["CameraOperatorSeat", "AdminClerk"],
	"res://world/heists/night_deposit/night_deposit.tscn": ["CameraOperatorSeat", "NightManager"],
	"res://world/heists/gallery_night/gallery_night.tscn": ["Curator", "AdminPA"],
	"res://world/heists/shadow_ledger/shadow_ledger.tscn": ["CameraOperatorSeat", "AssistantLate", "AssociateLate"],
}
const CHAIR_ART: Array[String] = ["prop_chair_office", "prop_chair_task"]
const SEAT_FWD: float = 0.12
## A seated spawn this close (xz) to an office / task chair's pivot belongs to it.
const OWNER_M: float = 0.5
## The desk's nav carve (obstruction + 0.3 m agent radius) ends ~0.3 m off its edge and the seat is ~0.33 m off it, so
## a seated spawn may sit just outside the polygons: within this (the D-130 late-staff test's bound; levelcheck 0.25).
const NAV_TOL_M: float = 0.15
## The seated root clears the desk's near edge by this much (D-130: ~0.33 m with the seat 0.12 m forward).
const DESK_CLEAR_M: float = 0.2


func test_catalog_seats_forward() -> void:
	for a: String in CHAIR_ART:
		var e: Dictionary = PropCatalog.entry(StringName(a))
		var ps: PackedScene = load(String(e.get("scene", ""))) as PackedScene
		assert_true(ps != null, "%s scene" % a)
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate() as Node3D
		var seat: Node3D = inst.find_child("Seat", true, false) as Node3D
		assert_true(seat != null, "%s has a Seat" % a)
		if seat != null:
			var p: Vector3 = _local(inst, seat).origin
			assert_near(p.x, 0.0, 0.001, "%s Seat x" % a)
			assert_near(p.z, -SEAT_FWD, 0.001, "%s Seat 0.12 m forward (-Z)" % a)
			assert_near(p.y, 0.47 if a == "prop_chair_task" else 0.45, 0.005, "%s Seat height" % a)
			assert_eq(PropCatalog.seat(StringName(a), Vector3.ZERO), p, "%s catalog seat = the scene's" % a)
		inst.free()


func test_seated_spawns_on_chair_seats() -> void:
	for path: String in MAPS:
		var ps: PackedScene = load(path) as PackedScene
		assert_true(ps != null, "load %s" % path)
		if ps == null:
			continue
		var map: Node3D = ps.instantiate() as Node3D
		_check_map(map, path, MAPS[path])
		map.free()


func _check_map(map: Node3D, path: String, expected: Array) -> void:
	var chairs: Array[Node3D] = []
	var spawns: Array[SpawnPoint] = []
	var stack: Array[Node] = [map]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is SpawnPoint and (nd as SpawnPoint).idle_activity != &"":
			spawns.append(nd as SpawnPoint)
		elif nd is Node3D and String(nd.get_meta(&"kind", "")) == "chair" and _office_art(nd as Node3D):
			chairs.append(nd as Node3D)
			continue
		for c: Node in nd.get_children():
			stack.append(c)
	var nav: NavigationRegion3D = map.get_node_or_null("Navigation") as NavigationRegion3D
	var seen: PackedStringArray = []
	for sp: SpawnPoint in spawns:
		var sx: Transform3D = _local(map, sp)
		var chair: Node3D = null
		var best: float = OWNER_M
		for ch: Node3D in chairs:
			var o: Vector3 = _local(map, ch).origin
			var d: float = Vector2(o.x - sx.origin.x, o.z - sx.origin.z).length()
			if absf(o.y - sx.origin.y) < 0.3 and d < best:
				best = d
				chair = ch
		if chair == null:
			continue
		seen.append(String(sp.name))
		var what: String = "%s %s on %s" % [path.get_file(), sp.name, chair.name]
		var cx: Transform3D = _local(map, chair)
		var seat: Node3D = chair.find_child("Seat", true, false) as Node3D
		assert_true(seat != null, "%s: chair Seat" % what)
		if seat == null:
			continue
		var st: Vector3 = _local(map, seat).origin
		var off: float = Vector2(st.x - sx.origin.x, st.z - sx.origin.z).length()
		assert_true(off <= 0.02, "%s: spawn on the Seat (%.3f m off)" % [what, off])
		var rel: Vector3 = cx.basis.inverse() * (sx.origin - cx.origin)
		assert_near(-rel.z, SEAT_FWD, 0.02, "%s: %.3f m in front of the pivot" % [what, -rel.z])
		assert_true(absf(rel.x) <= 0.02, "%s: centred on the chair (%.3f m)" % [what, rel.x])
		var f1: Vector3 = -sx.basis.z
		var f2: Vector3 = -cx.basis.z
		var ang: float = rad_to_deg(absf(Vector2(f1.x, f1.z).angle_to(Vector2(f2.x, f2.z))))
		assert_true(ang < 5.0, "%s: faces the chair's way (%.1f deg)" % [what, ang])
		if nav != null and nav.navigation_mesh != null:
			var dn: float = _nav_dist(nav.navigation_mesh, sx.origin)
			assert_true(dn <= NAV_TOL_M, "%s: %.3f m from the baked navmesh (<= %.2f)" % [what, dn, NAV_TOL_M])
		var dd: float = _desk_clear(map, chair, sx.origin)
		assert_true(dd >= DESK_CLEAR_M, "%s: %.3f m to the nearest knee-height collider (>= %.2f)" % [what, dd, DESK_CLEAR_M])
		print("D-130 seat %s: seat %.3f m off, %.3f m fwd, desk %.3f m" % [what, off, -rel.z, dd])
	for nm: Variant in expected:
		assert_true(seen.has(String(nm)), "%s: %s seated on an office / task chair (%s)" % [path.get_file(), nm, seen])


## The chair is prop_chair_office / task art: its own scene, or (SL greybox chairs) its `Visual`.
func _office_art(n: Node3D) -> bool:
	var v: Node = n.get_node_or_null("Visual")
	for p: String in [n.scene_file_path, v.scene_file_path if v != null else "", String(n.get_meta(&"art_asset", ""))]:
		for a: String in CHAIR_ART:
			if p.get_file().get_basename() == a or p == a:
				return true
	return false


## Horizontal distance from the seated root `p` to the nearest enabled box collider at desk height (0.4-0.8 m over
## its floor; the chair's own excluded): the desk's near edge, not inside it.
func _desk_clear(map: Node3D, chair: Node3D, p: Vector3) -> float:
	var best: float = INF
	for n: Node in map.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		var body: StaticBody3D = cs.get_parent() as StaticBody3D
		if cs.disabled or not (cs.shape is BoxShape3D) or body == null or body.collision_layer == 0 or chair.is_ancestor_of(cs):
			continue
		var xf: Transform3D = _local(map, cs)
		if xf.origin.distance_to(p) > 3.0:
			continue
		var h: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		var lp: Vector3 = xf.affine_inverse() * p
		if h.y - lp.y < 0.4 or -h.y - lp.y > 0.8:  # the box spans [-h.y, h.y] - lp.y over the floor: misses 0.4-0.8 m
			continue
		var dx: float = maxf(absf(lp.x) - h.x, 0.0)
		var dz: float = maxf(absf(lp.z) - h.z, 0.0)
		best = minf(best, Vector2(dx, dz).length())
	return best


## Horizontal distance from `p` to the navmesh polygons on its floor (0 inside one).
func _nav_dist(nm: NavigationMesh, p: Vector3) -> float:
	var verts: PackedVector3Array = nm.get_vertices()
	var q: Vector2 = Vector2(p.x, p.z)
	var best: float = INF
	for i: int in range(nm.get_polygon_count()):
		var poly: PackedInt32Array = nm.get_polygon(i)
		var pts: PackedVector2Array = []
		var y: float = 0.0
		for k: int in poly:
			pts.append(Vector2(verts[k].x, verts[k].z))
			y += verts[k].y
		if absf(y / float(poly.size()) - p.y) > 0.5:
			continue
		if Geometry2D.is_point_in_polygon(q, pts):
			return 0.0
		for j: int in range(pts.size()):
			best = minf(best, Geometry2D.get_closest_point_to_segment(q, pts[j], pts[(j + 1) % pts.size()]).distance_to(q))
	return best


func _local(root: Node3D, n: Node3D) -> Transform3D:
	if n == root:
		return Transform3D.IDENTITY
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
