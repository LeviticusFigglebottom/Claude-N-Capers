## Renderable geometry access for levelcheck: render pieces (mesh + transform + materials),
## local bounds, and temporary single-sided trimesh proxies of the visual meshes. Owner: ENV C.
class_name LcVisual
extends RefCounted


## Local AABB of a renderable geometry node, or null.
static func geometry_local_aabb(c: Node) -> Variant:
	if c is MeshInstance3D:
		var mi: MeshInstance3D = c
		return mi.mesh.get_aabb() if mi.mesh != null else null
	if c is CSGShape3D:
		var csg: CSGShape3D = c
		return csg.get_aabb() if csg.is_root_shape() else null
	if c is MultiMeshInstance3D or c is SpriteBase3D or c is Label3D:
		return (c as GeometryInstance3D).get_aabb()
	return null


## Renderable pieces: [{ "node": GeometryInstance3D, "mesh": Mesh, "xf": Transform3D,
## "materials": Array (per surface, may hold null) }]. Only visible + active instances.
## Memoised LcGeom.surface_triangles (mesh-local), per validation run.
static func triangles(ctx: LcContext, mesh: Mesh, surface: int) -> Dictionary:
	var key: String = "tri:%d:%d" % [mesh.get_instance_id(), surface]
	if not ctx.cache.has(key):
		ctx.cache[key] = LcGeom.surface_triangles(mesh, surface)
	return ctx.cache[key]


static func render_pieces(ctx: LcContext) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Node in ctx.map.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n
		if not gi.is_visible_in_tree() or not ctx.is_active(gi):
			continue
		if gi is MeshInstance3D:
			var mi: MeshInstance3D = gi
			if mi.mesh == null:
				continue
			var mats: Array = []
			for s: int in range(mi.mesh.get_surface_count()):
				mats.append(mi.get_active_material(s))
			out.append({"node": mi, "mesh": mi.mesh, "xf": mi.global_transform, "materials": mats})
		elif gi is MultiMeshInstance3D:
			var mmi: MultiMeshInstance3D = gi
			var mm: MultiMesh = mmi.multimesh
			if mm == null or mm.mesh == null:
				continue
			var mats2: Array = []
			for s2: int in range(mm.mesh.get_surface_count()):
				mats2.append(mmi.material_override if mmi.material_override != null else mm.mesh.surface_get_material(s2))
			for i: int in range(mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count):
				out.append({"node": mmi, "mesh": mm.mesh, "xf": mmi.global_transform * mm.get_instance_transform(i),
					"materials": mats2})
		elif gi is CSGShape3D and (gi as CSGShape3D).is_root_shape():
			var csg: CSGShape3D = gi
			var meshes: Array = csg.get_meshes()
			if meshes.size() >= 2 and meshes[1] is Mesh:
				var m: Mesh = meshes[1]
				var mats3: Array = []
				for s3: int in range(m.get_surface_count()):
					mats3.append(csg.material_override if csg.material_override != null else m.surface_get_material(s3))
				out.append({"node": csg, "mesh": m, "xf": csg.global_transform * (meshes[0] as Transform3D),
					"materials": mats3})
	return out


## Builds trimesh colliders (layer LcContext.PROXY_LAYER) mirroring every render piece. Faces are
## single-sided unless the surface material disables culling, so rays see what the camera sees.
static func build_proxies(ctx: LcContext) -> void:
	free_proxies(ctx)
	ctx.proxy_root = Node3D.new()
	ctx.proxy_root.name = "_LcProxies"
	ctx.map.add_child(ctx.proxy_root)
	for piece: Dictionary in render_pieces(ctx):
		var mesh: Mesh = piece["mesh"]
		var mats: Array = piece["materials"]
		for s: int in range(mesh.get_surface_count()):
			var tri: Dictionary = triangles(ctx, mesh, s)
			var v: PackedVector3Array = tri["v"]
			if v.is_empty():
				continue
			var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
			shape.set_faces(v)
			var bm: BaseMaterial3D = mats[s] as BaseMaterial3D if s < mats.size() else null
			shape.backface_collision = bm != null and bm.cull_mode == BaseMaterial3D.CULL_DISABLED
			var body: StaticBody3D = StaticBody3D.new()
			body.collision_layer = LcContext.PROXY_LAYER
			body.collision_mask = 0
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			ctx.proxy_root.add_child(body)
			body.global_transform = piece["xf"]
	await ctx.await_sync(2)


static func free_proxies(ctx: LcContext) -> void:
	if ctx.proxy_root != null and is_instance_valid(ctx.proxy_root):
		ctx.proxy_root.get_parent().remove_child(ctx.proxy_root)
		ctx.proxy_root.free()
	ctx.proxy_root = null
