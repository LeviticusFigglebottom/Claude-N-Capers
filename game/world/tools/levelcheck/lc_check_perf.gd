## perf (final): per review camera, frustum-cull every visible geometry instance (AABB vs
## frustum, visibility ranges honoured, no occlusion = conservative) and count draw calls
## (surfaces), triangles and shadow-casting lights in view against architecture.md §10.
class_name LcCheckPerf
extends LcCheck

const MAX_DRAW_CALLS: int = 2500
const MAX_SHADOW_LIGHTS: int = 8
## Not in architecture §10 yet: provisional mid-range budget (lead to confirm).
const MAX_TRIANGLES: int = 3000000
const DEFAULT_FOV: float = 75.0
const ASPECT: float = 16.0 / 9.0
const FAR: float = 500.0


func _init() -> void:
	id = &"perf"
	title = "Per-shot performance budget"
	stages = PackedStringArray(["final"])


static func camera_params(n: Node3D) -> Dictionary:
	var fov: float = float(n.get_meta(&"fov", DEFAULT_FOV))
	var ortho: float = 0.0
	if n is Camera3D:
		var cam: Camera3D = n
		fov = cam.fov
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			ortho = cam.size
	elif String(n.name).begins_with("TopDown"):
		ortho = float(n.get_meta(&"size", 40.0))
	return {"fov": fov, "ortho": ortho}


func run(ctx: LcContext) -> void:
	var pieces: Array[Dictionary] = []
	var tri_cache: Dictionary = {}
	var mm_seen: Dictionary = {}
	for piece: Dictionary in LcVisual.render_pieces(ctx):
		var mesh: Mesh = piece["mesh"]
		# OF-C2: a MultiMeshInstance3D is one draw call per surface for all its instances (render_pieces lists
		# every instance); one piece with the instance's AABB and the summed triangles
		var mmi: MultiMeshInstance3D = piece["node"] as MultiMeshInstance3D
		if mmi != null:
			if mm_seen.has(mmi):
				continue
			mm_seen[mmi] = true
			var mt: int = 0
			for s2: int in range(mesh.get_surface_count()):
				mt += _surface_tris(mesh, s2)
			var mm: MultiMesh = mmi.multimesh
			var count: int = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			pieces.append({"aabb": mmi.global_transform * mmi.get_aabb(), "surfaces": mesh.get_surface_count(),
				"tris": mt * count, "range": mmi.visibility_range_end})
			continue
		var mid: int = mesh.get_instance_id()
		if not tri_cache.has(mid):
			var t: int = 0
			for s: int in range(mesh.get_surface_count()):
				t += _surface_tris(mesh, s)
			tri_cache[mid] = t
		var tris: int = tri_cache[mid]
		var gi: GeometryInstance3D = piece["node"]
		pieces.append({"aabb": (piece["xf"] as Transform3D) * mesh.get_aabb(), "surfaces": mesh.get_surface_count(),
			"tris": tris, "range": gi.visibility_range_end})
	var lights: Array[Light3D] = []
	for n: Node in ctx.map.find_children("*", "Light3D", true, false):
		var l: Light3D = n
		if l.is_visible_in_tree() and l.shadow_enabled and ctx.is_active(l):
			lights.append(l)
	note("| camera | draw calls | triangles | shadow lights |")
	note("|---|---|---|---|")
	for np: NodePath in ctx.map.review_cameras:
		var cam: Node3D = ctx.map.get_node_or_null(np) as Node3D
		if cam == null:
			continue
		var cp: Dictionary = camera_params(cam)
		var xf: Transform3D = cam.global_transform
		var planes: Array[Plane] = LcGeom.frustum_planes(xf, cp["fov"], ASPECT, 0.05, FAR, cp["ortho"])
		var draws: int = 0
		var tris: int = 0
		for pc: Dictionary in pieces:
			var box: AABB = pc["aabb"]
			var rng: float = float(pc["range"])
			if rng > 0.0 and box.get_center().distance_to(xf.origin) > rng:
				continue
			if LcGeom.aabb_in_frustum(box, planes):
				draws += int(pc["surfaces"])
				tris += int(pc["tris"])
		var shadows: int = 0
		for l2: Light3D in lights:
			if l2 is DirectionalLight3D:
				shadows += 1
				continue
			var r: float = float(l2.get(&"omni_range")) if l2 is OmniLight3D else float(l2.get(&"spot_range"))
			if LcGeom.sphere_in_frustum(l2.global_position, r, planes):
				shadows += 1
		note("| `%s` | %d | %d | %d |" % [cam.name, draws, tris, shadows])
		if draws > MAX_DRAW_CALLS:
			fail(ctx, cam, null, "%d draw calls in view > %d" % [draws, MAX_DRAW_CALLS])
		if tris > MAX_TRIANGLES:
			fail(ctx, cam, null, "%d triangles in view > %d" % [tris, MAX_TRIANGLES])
		if shadows > MAX_SHADOW_LIGHTS:
			fail(ctx, cam, null, "%d shadow-casting lights in view > %d" % [shadows, MAX_SHADOW_LIGHTS])


static func _surface_tris(mesh: Mesh, s: int) -> int:
	var arrays: Array = mesh.surface_get_arrays(s)
	if arrays.is_empty():
		return 0
	if arrays[Mesh.ARRAY_INDEX] != null and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
		return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
