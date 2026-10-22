## RT convoy fit probe (ENV D): on C's generated Rolling Thunder map, every convoy mover's visual meshes get trimesh
## colliders, then each `Seat*` (sit_vehicle's root: the footwell / cab floor, facing the mover's +Z) is measured by
## rays against the real body: the roof liner over the root, the space ahead (knees, dash / front seat back) and
## behind (seat back), and the body side on the seat's door side, inside and out. Compared with D's clip numbers
## (SOURCE rt_vehicle_placement): head tops 1.21-1.28 m (Wrecker 1.28), the body 0.76 m ahead / 0.40 behind, and the
## vehicle_exit root travel EXIT_X sideways with a shoulder half width of 0.25 m (Wrecker 0.40).
##   /opt/godot/godot --headless --path game --script res://world/characters/_tools/probe_convoy_fit.gd
## Owner: ENV D.
extends SceneTree

const MAP: String = "res://world/heists/rolling_thunder/rolling_thunder.tscn"
const HEAD_TOP: float = 1.25
const HEAD_TOP_WRECKER: float = 1.28
const AHEAD: float = 0.76
const BEHIND: float = 0.40
const EXIT_X: float = 1.05
const SHOULDER: float = 0.25
const SHOULDER_WRECKER: float = 0.40

var _map: Node3D = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	root.add_child(_map)
	await physics_frame
	var vehicles: Array[Node3D] = []
	for movers: Node in _map.find_children("Movers", "", true, false):
		for v: Node in movers.get_children():
			if v is Node3D and not (v as Node3D).find_children("Seat*", "Node3D", true, false).is_empty():
				vehicles.append(v)
	# one mover per kind is enough (the layouts repeat the same prefabs)
	var seen: Dictionary = {}
	var probe: Array[Node3D] = []
	for v: Node3D in vehicles:
		if not seen.has(v.name):
			seen[v.name] = true
			probe.append(v)
	for v: Node3D in probe:
		for mi: Node in v.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).create_trimesh_collision()
	for _i: int in 3:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	print("PROBE vehicle seat | root(local) | faces | roof top | head gap (plain/Wrecker) | ahead@0.45/0.90 | behind@0.6 | side in/out | exit shoulder gap (plain/Wrecker)")
	for v: Node3D in probe:
		var inv: Transform3D = v.global_transform.affine_inverse()
		for s: Node in v.find_children("Seat*", "Node3D", true, false):
			var t: Transform3D = (s as Node3D).global_transform
			var r: Vector3 = t.origin
			var fwd: Vector3 = (-t.basis.z).normalized()
			var lt: Vector3 = inv * r
			var out_dir: Vector3 = v.global_basis.x.normalized() * (1.0 if lt.x >= 0.0 else -1.0)
			# the roof top straight above the root, from above (the hull is solid parts with no modelled interior)
			var liner: float = 4.0 - _ray(space, r + Vector3.UP * 4.0, Vector3.DOWN, 4.0)
			var ahead_lo: float = _ray(space, r + Vector3.UP * 0.45, fwd, 2.5)
			var ahead_hi: float = _ray(space, r + Vector3.UP * 0.90, fwd, 2.5)
			var behind: float = _ray(space, r + Vector3.UP * 0.60, -fwd, 2.5)
			var side_in: float = _ray(space, r + Vector3.UP * 0.90, out_dir, 3.0)
			var far: Vector3 = r + Vector3.UP * 0.90 + out_dir * 3.0
			var side_out: float = 3.0 - _ray(space, far, -out_dir, 3.0)
			var faces: String = "+Z" if (inv.basis * fwd).dot(Vector3.BACK) > 0.99 else str(inv.basis * fwd)
			print("PROBE %s %s | (%.2f, %.2f, %.2f) | %s | %.2f | %.2f / %.2f | %.2f / %.2f | %.2f | %.2f / %.2f | %.2f / %.2f" % [
				v.name, s.name, lt.x, lt.y, lt.z, faces, liner, liner - HEAD_TOP, liner - HEAD_TOP_WRECKER, ahead_lo,
				ahead_hi, behind, side_in, side_out, EXIT_X - SHOULDER - side_out, EXIT_X - SHOULDER_WRECKER - side_out])
	print("PROBE done (ahead >= %.2f, behind >= %.2f, head gap >= 0, exit shoulder gap >= 0)" % [AHEAD, BEHIND])
	quit(0)


## Distance along `dir` from `from` to the first hit within `len` (len when nothing).
func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, len: float) -> float:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * len)
	q.hit_back_faces = true
	var hit: Dictionary = space.intersect_ray(q)
	return from.distance_to(hit["position"]) if not hit.is_empty() else len
