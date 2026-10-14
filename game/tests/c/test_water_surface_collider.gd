## PO-8: harbour water carries a bullet-only collider at the water surface (SurfaceTags.water_surface),
## so shots into the water splash at the surface instead of hitting the bed 6-8 m below. Owner: ENV C.
##
## Per probe (a clear spot over the water off the quay), in the live physics space:
## - a hitscan ray (CombatTweak.hitscan_mask, as shot_fx / crew_weapons cast it) from above hits the
##   surface body at water level, and ImpactFx's lookup (ShotFx.surface_of) reads `water`;
## - rays and a crew-capsule shape on the crew / NPC / loot movement masks, the LOS / vision masks and
##   the triggers mask never touch it (movement, sight and OOB unchanged), and a capsule just below the
##   surface is still inside the OUT_OF_BOUNDS zone;
## - the body is on the hitboxes layer only, outside the navmesh bake mask, and no baked navmesh
##   vertex sits at water level over the water.
extends TestCase

const ND_L: GDScript = preload("res://world/heists/night_deposit/greybox/night_deposit_layout.gd")
const DB_L: GDScript = preload("res://world/heists/dockside_burn/greybox/dockside_burn_layout.gd")
const EPS_Y: float = 0.02
## Masks that must never see the water surface: crew / NPC / loot bodies, LOS, NPC vision, triggers.
const NON_BULLET_MASKS: Dictionary = {
	"crew": CrewController.COLLISION_MASK_WORLD, "npc": NpcBase.MASK_WORLD, "loot": LootBag.MASK_WORLD,
	"vision": StealthDirector.VISION_MASK, "triggers": StealthDirector.TRIGGER_MASK,
}


func test_night_deposit_water_surface() -> void:
	await _check("night_deposit", "Geometry/Site/HarborWaterSurface", ND_L.WATER_Y, [Vector2(10.0, 60.0)])


func test_dockside_burn_water_surface() -> void:
	await _check("dockside_burn", "Geometry/Site/HarbourWaterSurface", DB_L.WATER_Y,
		[Vector2(0.0, 80.0), Vector2(100.0, 120.0)])
	await _check("dockside_burn", "Geometry/Site/SlipWaterSurface", DB_L.WATER_Y, [Vector2(67.0, 0.0)])


func _check(heist: String, body_path: String, water_y: float, probes: Array) -> void:
	var ps: PackedScene = load("res://world/heists/%s/%s.tscn" % [heist, heist]) as PackedScene
	if ps == null:
		fail("%s: cannot load map" % heist)
		return
	var map: Node3D = ps.instantiate() as Node3D
	var body: StaticBody3D = map.get_node_or_null(body_path) as StaticBody3D
	assert_true(body != null, "%s: %s exists" % [heist, body_path])
	if body == null:
		map.free()
		return
	var tw: CombatTweak = CombatTweak.data()
	assert_eq(body.collision_layer, SurfaceTags.WATER_SURFACE_LAYER, "%s: water surface on hitboxes layer only" % heist)
	assert_true((body.collision_layer & tw.hitscan_mask) != 0, "%s: water surface in hitscan_mask" % heist)
	assert_eq(StringName(body.get_meta(&"surface", &"")), &"water", "%s: metadata/surface = water" % heist)
	for k: String in NON_BULLET_MASKS:
		assert_eq(body.collision_layer & int(NON_BULLET_MASKS[k]), 0, "%s: water surface off the %s mask" % [heist, k])
	assert_eq(body.collision_layer & tw.los_mask, 0, "%s: water surface off los_mask" % heist)
	var shape: BoxShape3D = (body.get_node("Collision") as CollisionShape3D).shape as BoxShape3D
	var top: float = body.position.y + shape.size.y * 0.5
	assert_near(top, water_y, 0.001, "%s: collider top at water level" % heist)
	var xz_min: Vector2 = Vector2(body.position.x - shape.size.x * 0.5, body.position.z - shape.size.z * 0.5)
	var xz_max: Vector2 = Vector2(body.position.x + shape.size.x * 0.5, body.position.z + shape.size.z * 0.5)
	for n: Node in map.find_children("*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = (n as NavigationRegion3D).navigation_mesh
		if nm == null:
			continue
		assert_eq(body.collision_layer & nm.geometry_collision_mask, 0, "%s: water surface outside nav bake" % heist)
		var at_water: int = 0
		for v: Vector3 in nm.get_vertices():
			if absf(v.y - water_y) < 0.3 and v.x > xz_min.x + 1.0 and v.x < xz_max.x - 1.0 \
					and v.z > xz_min.y + 1.0 and v.z < xz_max.y - 1.0:
				at_water += 1
		assert_eq(at_water, 0, "%s: navmesh vertices at water level over %s" % [heist, body.name])
	add_child(map)
	await wait_physics_frames(3)
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	for p: Variant in probes:
		var xz: Vector2 = p
		var from: Vector3 = Vector3(xz.x, water_y + 6.0, xz.y)
		var to: Vector3 = Vector3(xz.x, water_y - 12.0, xz.y)
		var label: String = "%s @ %s" % [heist, xz]
		# Bullets: shot_fx misses (bodies) and crew hitscan (bodies + areas, + penetrable).
		for spec: Array in [[tw.hitscan_mask, false], [tw.hitscan_mask | tw.penetrable_mask, true]]:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, int(spec[0]))
			q.collide_with_areas = bool(spec[1])
			var hit: Dictionary = space.intersect_ray(q)
			assert_true(not hit.is_empty() and hit.get("collider") == body,
				"%s: hitscan ray hits %s (got %s)" % [label, body.name, _name(hit)])
			if not hit.is_empty():
				assert_near((hit["position"] as Vector3).y, water_y, EPS_Y, "%s: hit at water level" % label)
				assert_eq(ShotFx.surface_of(hit.get("collider") as Object), &"water", "%s: impact surface" % label)
		# Movement / sight / trigger masks never see it.
		for k: String in NON_BULLET_MASKS:
			var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, int(NON_BULLET_MASKS[k]))
			q2.collide_with_areas = k == "triggers"
			var h2: Dictionary = space.intersect_ray(q2)
			assert_true(h2.get("collider") != body, "%s: %s ray must not hit the water surface" % [label, k])
			if not h2.is_empty() and k != "triggers":
				assert_true((h2["position"] as Vector3).y < water_y - 1.0,
					"%s: %s ray stops below the water (bed), got %s" % [label, k, _name(h2)])
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		for k3: String in ["crew", "npc"]:
			var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			sq.shape = cap
			sq.transform = Transform3D(Basis.IDENTITY, Vector3(xz.x, water_y, xz.y))
			sq.collision_mask = int(NON_BULLET_MASKS[k3])
			for r: Dictionary in space.intersect_shape(sq, 16):
				assert_true(r.get("collider") != body, "%s: %s capsule overlaps the water surface" % [label, k3])
		# OOB: a body sinking below the surface is still inside the OUT_OF_BOUNDS zone.
		var pq: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
		pq.position = Vector3(xz.x, water_y - 0.5, xz.y)
		pq.collision_mask = StealthDirector.TRIGGER_MASK
		pq.collide_with_areas = true
		pq.collide_with_bodies = false
		var oob: bool = false
		for r2: Dictionary in space.intersect_point(pq, 16):
			var z: MapZone = r2.get("collider") as MapZone
			if z != null and z.kind == MapZone.Kind.OUT_OF_BOUNDS:
				oob = true
		assert_true(oob, "%s: OUT_OF_BOUNDS zone just below the surface" % label)
	map.queue_free()
	await wait_frames(1)


static func _name(hit: Dictionary) -> String:
	if hit.is_empty():
		return "<nothing>"
	var c: Node = hit.get("collider") as Node
	return "%s @ %s" % [c.name if c != null else "?", hit.get("position")]
