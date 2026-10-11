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
## `props_block`: props/doors (world_dynamic) must not block the line either (a clear shot).
static func find_clear_point(target: Node3D, dist: float, behind: bool, eye: float = 1.65,
		props_block: bool = false) -> Variant:
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
			q.collision_mask = 1 if behind and not props_block else (1 | 2)
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


## Standing transform at `at` (feet) facing `look_point` horizontally (teleport_crew input).
static func facing(at: Vector3, look_point: Vector3) -> Transform3D:
	var xf: Transform3D = Transform3D(Basis(), at)
	var flat: Vector3 = Vector3(look_point.x, at.y, look_point.z)
	if flat.distance_to(at) < 0.01:
		return xf
	return xf.looking_at(flat, Vector3.UP)


## Closest navmesh point to `want` on `node`'s navigation map, or null when it is more than
## `max_off` m away horizontally (or 0.6 m vertically).
static func nav_point_near(node: Node3D, want: Vector3, max_off: float = 0.5) -> Variant:
	var nav: RID = node.get_world_3d().navigation_map
	var snap: Vector3 = NavigationServer3D.map_get_closest_point(nav, want)
	if Vector2(snap.x - want.x, snap.z - want.z).length() > max_off or absf(snap.y - want.y) > 0.6:
		return null
	return snap


## Floor-level centre of a box MapZone (its first CollisionShape3D child), else the area origin.
static func zone_center(zone: Area3D) -> Vector3:
	for c: Node in zone.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		var box: BoxShape3D = cs.shape as BoxShape3D if cs != null else null
		if box != null:
			return cs.global_position - cs.global_basis.y * (box.size.y * 0.5)
	return zone.global_position


## Where a bot drops a bag to secure it: the owning SecureZone's `DropAnchor` (the van's open rear),
## else the zone floor centre. The zone centre can sit inside a vehicle's solid body (D-066).
static func drop_point(zone: Area3D) -> Vector3:
	var n: Node = zone
	while n != null and not (n is SecureZone):
		n = n.get_parent()
	if n != null:
		var anchor: Node3D = n.find_child("DropAnchor", true, false) as Node3D
		if anchor != null:
			return anchor.global_position
	return zone_center(zone)


## A navmesh point whose standing body (0.5 m up) is inside `zone`, nearest the zone centre first.
static func nav_point_in_zone(zone: Area3D) -> Variant:
	var center: Vector3 = zone_center(zone)
	for r: float in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]:
		for deg: int in range(0, 360, 30 if r > 0.0 else 360):
			var want: Vector3 = center + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg))) * r
			var p: Variant = nav_point_near(zone, want, 0.4)
			if p != null and ZoneUtil.contains(zone, (p as Vector3) + Vector3.UP * 0.5):
				return p
	return null
