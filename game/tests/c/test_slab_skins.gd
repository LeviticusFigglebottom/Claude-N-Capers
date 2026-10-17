## PO-13 slab skins and slab tiles (Shadow Ledger, Dockside Burn): the per-room floor / ceiling finish quads
## laid over slab boxes that span several rooms, and the 6 m mesh tiles of those slab boxes (Compatibility
## renderer: <= 8 lights per mesh instance), are visual only. Owner: ENV C.
## - Slab / ceiling / grade / building-wall bodies keep one box collider; their mesh tiles are <= SLAB_TILE wide
##   and tile it (walls: seamless tiles, no faces on the internal seams).
## - Every skin is a MeshInstance3D under Geometry/Building/Skins (one per room) with no CollisionObject3D above or
##   below it, casts no shadow, and each quad sits 3-5 mm off a slab collider face (zfight: < 2 mm is
##   coplanar; feet: a 4 mm visual lift is far below the capsule's step tolerance).
## - The baked navmesh equals the fingerprint of the pre-skin bake (nav bakes parse colliders only).
## - Vision rays (StealthDirector.VISION_MASK) through every skin quad hit the same collider at the same
##   point with and without the skins in the world.
extends TestCase

const MAPS: Dictionary = {
	"shadow_ledger": "res://world/heists/shadow_ledger/shadow_ledger.tscn",
	"dockside_burn": "res://world/heists/dockside_burn/dockside_burn.tscn",
}
## Navmesh fingerprints of the bakes committed before the skins (PO-13 surface passes):
## [vertex count, polygon count, sha256 of the vertices + polygons].
const NAV_FINGERPRINT: Dictionary = {
	# re-pinned: SL-P1 corridor corner caps + the stair dividers' head clearance
	"shadow_ledger": [1599, 1643, "3de1ddf171b64145b28fb4391f33cbd0727ebaafd29e196a8c9dd15c923fc3b3"],
	"dockside_burn": [2211, 2258, "eba34e479cfc9b5759685a5da6c9694c34c61ac330122af6a9b596c1688f3f4c"],  # re-pinned: shutters baked shut
}
const SKINS: String = "Geometry/Building/Skins"
const OFFSET_MIN: float = 0.003
const OFFSET_MAX: float = 0.005
const SLAB_TILE: float = 6.0
## Tiled groups per map (the big horizontal boxes).
const TILED: Dictionary = {
	"shadow_ledger": ["Geometry/Building/Slabs", "Geometry/Building/InteriorWalls", "Geometry/Building/Facade",
		"Geometry/Building/Riser"],  # room ceilings stay whole (seams on wall lines z-fight)
	"dockside_burn": ["Geometry/Building/Slabs", "Geometry/Building/Ceilings", "Geometry/Site/Ground",
		"Geometry/Building/ExteriorWalls", "Geometry/Building/InteriorWalls", "Geometry/Building/Sheds"],
}


## [vertex count, polygon count, sha256 hex] of a NavigationMesh.
static func fingerprint(nm: NavigationMesh) -> Array:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var verts: PackedVector3Array = nm.get_vertices()
	ctx.update(var_to_bytes(verts))
	for i: int in range(nm.get_polygon_count()):
		ctx.update(var_to_bytes(nm.get_polygon(i)))
	return [verts.size(), nm.get_polygon_count(), ctx.finish().hex_encode()]


## Skin quads of a mesh: [[centre, normal (UP floor / DOWN ceiling)], ...] in map space.
static func quads(mi: MeshInstance3D) -> Array:
	var out: Array = []
	for s: int in range(mi.mesh.get_surface_count()):
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i: int in range(0, v.size(), 6):
			var lo: Vector3 = v[i]
			var hi: Vector3 = v[i]
			for j: int in range(i, i + 6):
				lo = lo.min(v[j])
				hi = hi.max(v[j])
			out.append([mi.transform * ((lo + hi) * 0.5), nrm[i]])
	return out


func _load(heist: String) -> Node3D:
	var ps: PackedScene = load(MAPS[heist]) as PackedScene
	if ps == null:
		fail("%s missing" % MAPS[heist])
		return null
	return ps.instantiate() as Node3D


func test_skins_are_visual_only() -> void:
	for heist: String in MAPS:
		var map: Node3D = _load(heist)
		if map == null:
			continue
		var skins: Node = map.get_node_or_null(SKINS)
		assert_true(skins != null and skins.get_child_count() > 0, "%s: %s has skin meshes" % [heist, SKINS])
		if skins == null:
			map.free()
			continue
		var p: Node = skins
		while p != null:
			assert_false(p is CollisionObject3D, "%s: skins sit under a CollisionObject3D (%s)" % [heist, p.name])
			p = p.get_parent()
		assert_true(skins.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s: a skin has a body" % heist)
		assert_true(skins.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s: a skin has a shape" % heist)
		for c: Node in skins.get_children():
			assert_true(c is MeshInstance3D and c.get_child_count() == 0, "%s: %s is a bare MeshInstance3D" % [heist, c.name])
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi == null:
				continue
			assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: %s casts no shadow" % [heist, c.name])
			for s: int in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(s)
				assert_true(m != null and String(m.resource_name).begins_with(heist.substr(0, 1)),
					"%s: %s surface %d uses a map finish" % [heist, c.name, s])
		map.free()


func test_slab_tiles_cover_one_collider() -> void:
	for heist: String in MAPS:
		var map: Node3D = _load(heist)
		if map == null:
			continue
		var tiled: int = 0
		for g: String in TILED[heist]:
			for body: Node in map.get_node(g).find_children("*", "StaticBody3D", true, false):
				var shapes: Array[Node] = body.find_children("*", "CollisionShape3D", false, false)
				var meshes: Array[Node] = body.find_children("Mesh*", "MeshInstance3D", false, false)
				if meshes.size() > 1:
					assert_eq(shapes.size(), 1, "%s: tiled %s keeps one collider" % [heist, body.name])
				# Box bodies only (box(): one BoxShape3D + box / seamless wall tiles); quay steps / ramps are built otherwise.
				if shapes.size() != 1 or meshes.is_empty() or not ((shapes[0] as CollisionShape3D).shape is BoxShape3D):
					continue
				var bm: BaseMaterial3D = (meshes[0] as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
				if bm != null and bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					continue  # curtain-wall glass panes stay whole (see-through, not lit walls)
				var sz: Vector3 = ((shapes[0] as CollisionShape3D).shape as BoxShape3D).size
				var area: float = 0.0
				for m: Node in meshes:
					var ms: Vector3 = (m as MeshInstance3D).mesh.get_aabb().size
					assert_true(ms.x <= SLAB_TILE + 0.005 and ms.z <= SLAB_TILE + 0.005,
						"%s: %s/%s is a <= %.0f m tile" % [heist, body.name, m.name, SLAB_TILE])
					area += ms.x * ms.z
				assert_near(area, sz.x * sz.z, 0.01, "%s: %s tiles cover its collider" % [heist, body.name])
				tiled += 1 if meshes.size() > 1 else 0
		assert_true(tiled > 0, "%s: big slabs are tiled" % heist)
		map.free()


func test_navmesh_unchanged() -> void:
	for heist: String in MAPS:
		var map: Node3D = _load(heist)
		if map == null:
			continue
		var nm: NavigationMesh = (map.get_node("Navigation") as NavigationRegion3D).navigation_mesh
		assert_eq(fingerprint(nm), NAV_FINGERPRINT[heist], "%s: navmesh equals the pre-skin bake" % heist)
		map.free()


func test_vision_rays_ignore_skins() -> void:
	for heist: String in MAPS:
		var map: Node3D = _load(heist)
		if map == null:
			continue
		var holder: Node3D = Node3D.new()
		holder.name = "SlabSkinTest"
		var geo: Node = map.get_node("Geometry")
		for d: Node in geo.find_children("*", "", true, false):
			d.owner = null
		geo.owner = null
		map.remove_child(geo)
		holder.add_child(geo)
		map.free()
		add_child(holder)
		await wait_physics_frames(2)
		var space: PhysicsDirectSpaceState3D = holder.get_world_3d().direct_space_state
		var skins: Node = holder.get_node(SKINS)
		var qs: Array = []
		for mi: Node in skins.get_children():
			qs.append_array(quads(mi as MeshInstance3D))
		assert_true(qs.size() > 0, "%s: skin quads found" % heist)
		var before: Array = []
		var bad_offset: int = 0
		for q: Array in qs:
			var c: Vector3 = q[0]
			var n: Vector3 = q[1]
			before.append(_ray(space, c + n * 1.0, c - n * 0.5))
			# Offset: from the skin plane towards its slab, the slab face is 3-5 mm away.
			var h: Dictionary = _ray(space, c, c - n * 0.02)
			var d: float = c.distance_to(h["position"]) if not h.is_empty() else INF
			if d < OFFSET_MIN or d > OFFSET_MAX:
				bad_offset += 1
				if bad_offset <= 5:
					fail("%s: skin quad at %s is %.4f m off its slab (want %.3f-%.3f)" % [heist, c, d, OFFSET_MIN, OFFSET_MAX])
		skins.get_parent().remove_child(skins)
		skins.free()
		await wait_physics_frames(2)
		var changed: int = 0
		for i: int in range(qs.size()):
			var c2: Vector3 = qs[i][0]
			var n2: Vector3 = qs[i][1]
			var after: Dictionary = _ray(space, c2 + n2 * 1.0, c2 - n2 * 0.5)
			var b: Dictionary = before[i]
			if b.is_empty() != after.is_empty() or (not b.is_empty() and (b["collider_id"] != after["collider_id"]
					or b["position"] != after["position"])):
				changed += 1
		assert_eq(changed, 0, "%s: vision rays through %d skin quads hit the same collider without the skins" % [heist, qs.size()])
		holder.queue_free()
		await wait_frames(1)


static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, StealthDirector.VISION_MASK))
