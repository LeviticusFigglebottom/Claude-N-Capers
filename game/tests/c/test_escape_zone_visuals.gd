## PO-13: every escape_zone on the four heists shows a real visual, not EscapeZone.PLACEHOLDER (the green slab).
## * heli / zipline / lift: the escape art (tools/blender/props/escape.py) stands on the ground under the zone
##   (bottom within 0.1 m) and overlaps the zone's footprint.
## * van / boat: the vehicle is already there (the slot's secure_zone van, the moored launch), so the visual is
##   a node-only marker (escape_van_marker / escape_boat_marker) and the test checks that vehicle instead: it
##   stands beside the zone (footprint gap <= 0.6 m van, <= 1.0 m boat) on the ground.
## The required visual nodes (EscapeZone.required_visual_nodes) are present in every case. Owner: ENV C.
extends TestCase

const VAN_MARKER: String = "res://world/heists/shared/escape_van_marker.tscn"
const BOAT_MARKER: String = "res://world/heists/shared/escape_boat_marker.tscn"
const HELI: String = "res://world/props/escape_zone/veh_heli_escape.tscn"
const LINE: String = "res://world/props/escape_zone/prop_escape_zipline_rig.tscn"
const LIFT: String = "res://world/props/escape_zone/prop_escape_lift_fitout.tscn"
const VAN_ART: String = "res://world/props/secure_zone/veh_van_secure.tscn"
## heist -> {escape_zone name: expected visual scene}
const EXPECTED: Dictionary = {
	"glasshouse": {"VanEscapeE1": VAN_MARKER, "VanEscapeE2": VAN_MARKER},
	"night_deposit": {"VanEscapeE1": VAN_MARKER, "BoatEscapeE2": BOAT_MARKER},
	"dockside_burn": {"VanEscapeE1": VAN_MARKER, "VanEscapeE2": VAN_MARKER, "BoatEscapeE3": BOAT_MARKER},
	"shadow_ledger": {"HeliEscapeE1": HELI, "LineEscapeE2": LINE, "LiftEscapeE3": LIFT},
}
const GROUND_TOL_M: float = 0.1
const VAN_GAP_M: float = 0.6
const BOAT_GAP_M: float = 1.0
## The art's footprint centre stays this close to the zone's (m).
const CENTRE_TOL_M: float = 3.0


func test_glasshouse() -> void:
	await _check("glasshouse")


func test_night_deposit() -> void:
	await _check("night_deposit")


func test_dockside_burn() -> void:
	await _check("dockside_burn")


func test_shadow_ledger() -> void:
	await _check("shadow_ledger")


func _check(heist: String) -> void:
	var ps: PackedScene = load("res://world/heists/%s/%s.tscn" % [heist, heist]) as PackedScene
	if ps == null:
		fail("%s scene missing" % heist)
		return
	var map: Node3D = ps.instantiate() as Node3D
	add_child(map)
	await wait_physics_frames(3)
	var want: Dictionary = EXPECTED[heist]
	var seen: PackedStringArray = PackedStringArray()
	for n: Node in map.find_children("*", "Node3D", true, false):
		var ez: EscapeZone = n as EscapeZone
		if ez == null:
			continue
		var tag: String = "%s/%s" % [heist, ez.name]
		seen.append(String(ez.name))
		_check_zone(map, ez, tag, String(want.get(String(ez.name), "")))
	seen.sort()
	var names: PackedStringArray = PackedStringArray(want.keys())
	names.sort()
	assert_eq(seen, names, "%s: escape zones" % heist)
	map.queue_free()
	await wait_frames(1)


func _check_zone(map: Node3D, ez: EscapeZone, tag: String, expected: String) -> void:
	assert_true(ez.visual_scene != null, "%s: visual_scene set" % tag)
	if ez.visual_scene == null:
		return
	assert_eq(ez.visual_scene.resource_path, expected, "%s: visual" % tag)
	assert_ne(ez.visual_scene.resource_path, EscapeZone.PLACEHOLDER.resource_path, "%s: not the placeholder" % tag)
	assert_false(ez.using_placeholder, "%s: art instanced" % tag)
	assert_true(ez.visual_instance != null, "%s: visual instantiates" % tag)
	if ez.visual_instance == null:
		return
	for req: String in ez.required_visual_nodes():
		assert_true(ez.visual_node(req) is Node3D, "%s: required visual node `%s`" % [tag, req])
	var zone: AABB = ez.global_transform * AABB(Vector3(-ez.zone_size_m.x * 0.5, 0.0, -ez.zone_size_m.z * 0.5), ez.zone_size_m)
	var ground: float = _ground_y(map, ez.global_position)
	var art: AABB = _mesh_aabb(ez.visual_instance)
	if art.size != Vector3.ZERO:
		assert_near(art.position.y, ground, GROUND_TOL_M, "%s: art bottom %.2f on the ground %.2f" % [tag, art.position.y, ground])
		assert_true(_xz_gap(art, zone) == 0.0, "%s: art overlaps the zone footprint" % tag)
		var dc: Vector2 = Vector2(art.get_center().x - zone.get_center().x, art.get_center().z - zone.get_center().z)
		assert_true(dc.length() <= CENTRE_TOL_M, "%s: art centred on the zone (%.2f m off)" % [tag, dc.length()])
		assert_true(art.end.y - ground <= 4.0, "%s: art at most 4 m tall" % tag)
		return
	match String(ez.visual_instance.get_meta(&"escape_vehicle", &"")):
		"secure_zone":
			_check_van(map, ez, tag, zone, ground)
		"moored_boat":
			_check_boat(map, tag, zone)
		var other:
			fail("%s: mesh-less visual without a known escape_vehicle meta (%s)" % [tag, other])


## The slot's secure_zone van (catalog art) stands beside the zone on the same ground.
func _check_van(map: Node3D, ez: EscapeZone, tag: String, zone: AABB, ground: float) -> void:
	var van: SecureZone = null
	for c: Node in ez.get_parent().get_children():
		if c is SecureZone:
			van = c as SecureZone
	assert_true(van != null, "%s: a secure_zone van in the slot" % tag)
	if van == null:
		return
	assert_true(van.visual_scene != null and van.visual_scene.resource_path == VAN_ART, "%s: the van is the catalog van" % tag)
	var box: AABB = _mesh_aabb(van.visual_instance)
	assert_true(box.size.x > 1.5, "%s: van has meshes" % tag)
	var gap: float = _xz_gap(box, zone)
	assert_true(gap <= VAN_GAP_M, "%s: van %.2f m from the zone (<= %.1f)" % [tag, gap, VAN_GAP_M])
	assert_near(box.position.y, _ground_y(map, van.global_position), GROUND_TOL_M, "%s: van on the ground" % tag)
	assert_near(ez.global_position.y, ground, GROUND_TOL_M, "%s: zone floor on the ground" % tag)


## A moored launch (`Launch*`: ND dressing veh_boat_launch, DB greybox hull) lies alongside the zone.
func _check_boat(map: Node3D, tag: String, zone: AABB) -> void:
	var best: float = INF
	for n: Node in map.find_children("Launch*", "Node3D", true, false):
		var box: AABB = _mesh_aabb(n as Node3D)
		if box.size != Vector3.ZERO:
			best = minf(best, _xz_gap(box, zone))
	assert_true(best <= BOAT_GAP_M, "%s: moored launch %.2f m from the zone (<= %.1f)" % [tag, best, BOAT_GAP_M])


## World AABB of every MeshInstance3D at or under `root` (empty when none).
static func _mesh_aabb(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	if root == null:
		return out
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for n: Node in nodes:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Horizontal gap between two boxes (0 when their footprints overlap).
static func _xz_gap(a: AABB, b: AABB) -> float:
	var dx: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dz: float = maxf(0.0, maxf(a.position.z - b.end.z, b.position.z - a.end.z))
	return Vector2(dx, dz).length()


## First collision surface under `p` (from 0.5 m above), or -INF.
static func _ground_y(map: Node3D, p: Vector3) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * 5.0, 1)
	var hit: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(q)
	return -INF if hit.is_empty() else (hit["position"] as Vector3).y
