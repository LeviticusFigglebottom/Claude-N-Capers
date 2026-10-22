## Rolling Thunder car park: the deck-2 strip guards (P's RT G1 real-input pass, r278: a HEAVY bag carrier going Deck 2
## south -> R1 top pinned twice on Strip2GuardW2's south end, the nav corner 0.3 m off it). On the generated map, no
## edge of the walkable navmesh at the guards' level (sampled every 0.1 m) comes within the crew capsule's radius of a
## `Strip2Guard*` collider footprint. Owner: ENV C.
extends TestCase

const MAP: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"
const CREW_R: float = 0.35
const STEP_M: float = 0.1

var _map: Node3D = null


func after_each() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null
	await wait_frames(2)


func test_navmesh_keeps_the_crew_radius_off_the_strip_guards() -> void:
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	add_child(_map)
	await wait_frames(1)
	var guards: Array[AABB] = []
	for n: Node in _map.find_children("Strip2Guard*", "", true, false):
		var bb: AABB = _footprint(n)
		if bb.has_volume():
			guards.append(bb)
	assert_true(guards.size() >= 4, "found the strip guards (%d)" % guards.size())
	var nav: NavigationRegion3D = _map.get_node("Navigation") as NavigationRegion3D
	var nm: NavigationMesh = nav.navigation_mesh
	var verts: PackedVector3Array = nm.get_vertices()
	var worst: float = INF
	var at: Vector3 = Vector3.ZERO
	for i: int in nm.get_polygon_count():
		var poly: PackedInt32Array = nm.get_polygon(i)
		for k: int in poly.size():
			var a: Vector3 = nav.global_transform * verts[poly[k]]
			var b: Vector3 = nav.global_transform * verts[poly[(k + 1) % poly.size()]]
			var steps: int = maxi(1, ceili(a.distance_to(b) / STEP_M))
			for s: int in steps + 1:
				var p: Vector3 = a.lerp(b, float(s) / steps)
				for g: AABB in guards:
					if p.y < g.position.y - 0.3 or p.y > g.end.y:
						continue
					var dx: float = maxf(maxf(g.position.x - p.x, p.x - g.end.x), 0.0)
					var dz: float = maxf(maxf(g.position.z - p.z, p.z - g.end.z), 0.0)
					var d: float = sqrt(dx * dx + dz * dz)
					if d < worst:
						worst = d
						at = p
	assert_true(worst >= CREW_R, "navmesh edge %.2f m from a strip guard at %s (< %.2f m)" % [worst, at, CREW_R])


## A guard's collider footprint (world AABB of its convex hull points).
func _footprint(n: Node) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = c as CollisionShape3D
		var hull: ConvexPolygonShape3D = cs.shape as ConvexPolygonShape3D
		if hull == null:
			continue
		for q: Vector3 in hull.points:
			var w: Vector3 = cs.global_transform * q
			out = AABB(w, Vector3.ZERO) if first else out.expand(w)
			first = false
	return out
