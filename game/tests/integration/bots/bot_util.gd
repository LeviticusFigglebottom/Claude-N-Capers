## Helpers for integration-test bots. Owner: LEAD.
class_name BotUtil
extends RefCounted


## Intent that looks from `from` toward `to` (absolute yaw/pitch, Godot -Z forward).
static func look_at_intent(from: Vector3, to: Vector3, base: CrewIntent = null) -> CrewIntent:
	var i: CrewIntent = base if base != null else CrewIntent.new()
	var d: Vector3 = to - from
	i.look_yaw = atan2(-d.x, -d.z)
	i.look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	return i


static func idle() -> CrewIntent:
	return CrewIntent.new()


## True if the gameplay API needed by integration gates exists yet (ENV A delivers in P1).
static func runtime_available() -> bool:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == &"HeistLauncher":
			return true
	return false


## Find a standing spot on the navmesh about `dist` m from `target`, either behind it (its +Z side)
## or in front (its -Z side), with clear line of sight from eye height to the target's head.
## Returns a Transform3D facing the target, or null if none found (QC-6, D-036).
static func find_clear_point(target: Node3D, dist: float, behind: bool, eye: float = 1.65) -> Variant:
	var world: World3D = target.get_world_3d()
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var nav_map: RID = world.navigation_map
	var fwd: Vector3 = -target.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var base_dir: Vector3 = -fwd if behind else fwd
	var head: Vector3 = target.global_position + Vector3(0, eye, 0)
	# Behind: sweep up to +-110 deg off straight-behind (still > 60 deg from the 120-deg FOV centre).
	# In front: stay within +-45 deg so the target can see the bot. Distances are tried nearest-first
	# to the requested one, in 0.5 m steps, so cluttered rooms still yield a spot.
	var max_deg: int = 110 if behind else 45
	var sweep: Array = [0.0]
	for a: int in range(10, max_deg + 1, 10):
		sweep.append(float(a))
		sweep.append(float(-a))
	var dists: Array = []
	var step: float = 0.5
	var k: int = 0
	while k <= 8:
		for sgn: float in [1.0, -1.0]:
			var dd: float = dist + sgn * step * k
			if dd >= 0.6 and not dists.has(dd):
				dists.append(dd)
		k += 1
	for d: float in dists:
		for deg: float in sweep:
			var dir: Vector3 = base_dir.rotated(Vector3.UP, deg_to_rad(deg))
			var want: Vector3 = target.global_position + dir * d
			var snap: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, want)
			if Vector2(snap.x - want.x, snap.z - want.z).length() > 0.5 or absf(snap.y - target.global_position.y) > 0.6:
				continue
			var from: Vector3 = snap + Vector3(0, eye, 0)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, head)
			# Behind: only architecture matters (world_static). In front the target must really see
			# the bot, so props (world_dynamic) block too. NPCs never block placement.
			q.collision_mask = 1 if behind else (1 | 2)
			if not space.intersect_ray(q).is_empty():
				continue
			var xf: Transform3D = Transform3D(Basis(), snap)
			return xf.looking_at(Vector3(head.x, snap.y, head.z), Vector3.UP)
	return null


## True once the navigation map containing `node` answers closest-point queries near it.
static func nav_ready(node: Node3D) -> bool:
	var nav: RID = node.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav) == 0 or NavigationServer3D.map_get_regions(nav).is_empty():
		return false
	var p: Vector3 = NavigationServer3D.map_get_closest_point(nav, node.global_position)
	return p != Vector3.ZERO and p.distance_to(node.global_position) < 2.0
