## perf (final): per review camera, the draws the renderer submits (architecture.md §10, D-146), modelled on
## Godot's own culling (servers/rendering/renderer_scene_cull.cpp + rendering_light_culler.cpp) and the
## Compatibility renderer's passes (drivers/gles3/rasterizer_scene_gles3.cpp). No occlusion: conservative.
## - main: every visible geometry instance in the camera frustum (AABB vs frustum, visibility ranges from the
##   camera), one draw per surface (a MultiMeshInstance3D: per surface for all its instances). The depth prepass is
##   not counted (neither renderer counts it).
## - lit (Compatibility only; Forward+ lights in one clustered pass): a shaded surface draws one colour pass per
##   shadowed positional light paired with it (light AABB overlaps the surface's AABB) plus one per shadowed sun,
##   min 1; lit = the passes beyond the first.
## - shadow: one draw per caster surface per shadow pass. Casters: cast_shadow on, on a layer in the light's
##   shadow_caster_mask. The sun: per cascade (splits of [near, min(max_distance, far)]; an orthogonal camera
##   ignores max_distance) casters inside the cascade's light-space box (the split corners' x/y range, unbounded
##   toward the light, cut at the far side) AND inside the split frustum extruded toward the light (Godot's tighter
##   caster culling), within their visibility range. A spot: one pass, casters in its perspective pyramid (fov
##   2 x angle, range). An omni: 6 cube faces (90 deg pyramids) or 2 paraboloid hemispheres. Positional casters must
##   also reach the view: inside the convex hull of the camera frustum and the light (tighter caster culling). A
##   positional light counts when its AABB is in view and its distance fade keeps the light and its shadow; its
##   shadow is counted as re-rendered every frame (the moving cast dirties it; a static frame would reuse it).
## - cast: the heist's peak (Cataclysm) NPC cast, CAST_ALLOWANCE, from D's heist_cast_perf.
## Fails: main > MAX_DRAW_CALLS, main + lit + shadow + cast > MAX_TOTAL_DRAWS, shadowed lights in view >
## MAX_SHADOW_LIGHTS, triangles > MAX_TRIANGLES, on a map whose root carries meta `perf_d146 = true` (D-146 addendum:
## no heist sets it since addendum 6); every other map gets the same lines as warnings (report-only). D-146 addendum 6:
## the budgets are judged on Forward+, measured on the GPU box with the Cataclysm cast (heist_cast_perf / the GPU
## frame is the cast gate); this Compatibility model, without occlusion and with every variant active, is the
## conservative early warning.
class_name LcCheckPerf
extends LcCheck

## Main pass draws per view (architecture §10).
const MAX_DRAW_CALLS: int = 2500
## Submitted draws per view: main + Compatibility light passes + shadow passes + peak cast (architecture §10, D-146).
const MAX_TOTAL_DRAWS: int = 4000
const MAX_SHADOW_LIGHTS: int = 8
## Not in architecture §10 yet: provisional mid-range budget (lead to confirm).
const MAX_TRIANGLES: int = 3000000
const DEFAULT_FOV: float = 75.0
const ASPECT: float = 16.0 / 9.0
const NEAR: float = 0.05
const FAR: float = 500.0
## Peak cast draws (all passes, Compatibility renderer) per heist from D's heist_cast_perf (Cataclysm, worst view:
## its `draws` minus `map`), added to every view's total. Re-measure when the cast or the map's shadowed lights
## change. Heists not listed get DEFAULT_CAST_ALLOWANCE.
const CAST_ALLOWANCE: Dictionary = {}
const DEFAULT_CAST_ALLOWANCE: int = 0
## Map-root meta that opts a heist into enforced budgets (D-146 addendum); without it the check is report-only.
const ENFORCE_META: StringName = &"perf_d146"
## Frustum quads by corner index (slice_corners order: layer * 4 + sx * 2 + sy; layer 0 near, 1 far).
const FACES: Array = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
## Godot's omni cube faces (renderer_scene_cull.cpp): view normal, up.
const CUBE: Array = [[Vector3(1, 0, 0), Vector3(0, -1, 0)], [Vector3(-1, 0, 0), Vector3(0, -1, 0)],
	[Vector3(0, -1, 0), Vector3(0, 0, -1)], [Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(0, -1, 0)], [Vector3(0, 0, -1), Vector3(0, -1, 0)]]

## Diagnostics (tools only): when `tally_on`, count_view adds each shadow draw to tally[[light name, piece index]].
static var tally_on: bool = false
static var tally: Dictionary = {}


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
	var pieces: Array[Dictionary] = collect_pieces(ctx)
	var lights: Array[Dictionary] = []
	for n: Node in ctx.map.find_children("*", "Light3D", true, false):
		var l: Light3D = n
		if l.is_visible_in_tree() and l.shadow_enabled and ctx.is_active(l):
			lights.append(prepare_light(l, pieces))
	var cast: int = int(CAST_ALLOWANCE.get(ctx.heist_id, DEFAULT_CAST_ALLOWANCE))
	var enforced: bool = bool(ctx.map.get_meta(ENFORCE_META, false))
	var flag: Callable = fail if enforced else warn
	note("Budgets %s (map meta `%s`)." % ["ENFORCED (fail)" if enforced
		else "REPORT-ONLY (D-146 addendum 6: judged on Forward+ on the GPU box; this is the Compatibility early warning)",
		ENFORCE_META])
	note("Draws per view = main + lit (Compatibility light passes) + shadow passes + peak cast allowance (%d); " % cast
			+ "budgets: main <= %d, total <= %d, shadowed lights <= %d (architecture §10, D-146)."
			% [MAX_DRAW_CALLS, MAX_TOTAL_DRAWS, MAX_SHADOW_LIGHTS])
	note("| camera | main | lit | shadow | cast | total | triangles | shadow lights | shadow by light |")
	note("|---|---|---|---|---|---|---|---|---|")
	for np: NodePath in ctx.map.review_cameras:
		var cam: Node3D = ctx.map.get_node_or_null(np) as Node3D
		if cam == null:
			continue
		var r: Dictionary = count_view(pieces, lights, cam.global_transform, camera_params(cam))
		var main: int = r["main"]
		var total: int = main + int(r["lit"]) + int(r["shadow"]) + cast
		var by: PackedStringArray = PackedStringArray()
		for e: Array in r["by_light"]:
			by.append("%s %d" % e)
		var plan: bool = is_plan_camera(cam)
		note("| `%s`%s | %d | %d | %d | %d | %d | %d | %d | %s |" % [cam.name, " (plan, exempt)" if plan else "", main,
			r["lit"], r["shadow"], cast, total, r["tris"], r["shadow_lights"], ", ".join(by)])
		if plan:
			continue
		if main > MAX_DRAW_CALLS:
			flag.call(ctx, cam, null, "%d main-pass draw calls in view > %d" % [main, MAX_DRAW_CALLS])
		if total > MAX_TOTAL_DRAWS:
			flag.call(ctx, cam, null, "%d draw calls in view (main %d + lit %d + shadow %d + cast %d) > %d"
					% [total, main, r["lit"], r["shadow"], cast, MAX_TOTAL_DRAWS])
		if int(r["tris"]) > MAX_TRIANGLES:
			flag.call(ctx, cam, null, "%d triangles in view > %d" % [r["tris"], MAX_TRIANGLES])
		if int(r["shadow_lights"]) > MAX_SHADOW_LIGHTS:
			flag.call(ctx, cam, null, "%d shadow-casting lights in view > %d" % [r["shadow_lights"], MAX_SHADOW_LIGHTS])


## The LEAD (r281, RT D-146 pass): orthographic plan cameras (`TopDown*`, the whole map from above, rendered by
## review_shots with its own flat plan environment) are not player views: reported, never flagged.
static func is_plan_camera(cam: Node3D) -> bool:
	return String(cam.name).begins_with("TopDown") and float(camera_params(cam)["ortho"]) > 0.0


## One entry per draw source: { node, aabb (world), surfaces, lit_surfaces (not unshaded), tris, vr_begin, vr_end,
## main (in the main pass), cast (casts shadows), layers }.
static func collect_pieces(ctx: LcContext) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	var tri_cache: Dictionary = {}
	var mm_seen: Dictionary = {}
	for piece: Dictionary in LcVisual.render_pieces(ctx):
		var mesh: Mesh = piece["mesh"]
		var gi: GeometryInstance3D = piece["node"]
		# OF-C2: a MultiMeshInstance3D is one draw call per surface for all its instances (render_pieces lists
		# every instance); one piece with the instance's AABB and the summed triangles
		var mmi: MultiMeshInstance3D = gi as MultiMeshInstance3D
		var box: AABB
		var tris: int = 0
		if mmi != null:
			if mm_seen.has(mmi):
				continue
			mm_seen[mmi] = true
			var mm: MultiMesh = mmi.multimesh
			var count: int = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			tris = _mesh_tris(mesh, tri_cache) * count
			box = mmi.global_transform * mmi.get_aabb()
		else:
			tris = _mesh_tris(mesh, tri_cache)
			box = (piece["xf"] as Transform3D) * mesh.get_aabb()
		var lit: int = 0
		for m: Variant in piece["materials"]:
			var bm: BaseMaterial3D = m as BaseMaterial3D
			if bm == null or bm.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				lit += 1
		pieces.append(piece_of(gi, box, mesh.get_surface_count(), tris, lit))
	return pieces


static func piece_of(gi: GeometryInstance3D, box: AABB, surfaces: int, tris: int, lit: int = -1) -> Dictionary:
	var cs: GeometryInstance3D.ShadowCastingSetting = gi.cast_shadow
	return {"node": gi, "aabb": box, "surfaces": surfaces, "lit_surfaces": surfaces if lit < 0 else lit,
		"tris": tris, "vr_begin": gi.visibility_range_begin - gi.visibility_range_begin_margin,
		"vr_end": gi.visibility_range_end + gi.visibility_range_end_margin if gi.visibility_range_end > 0.0 else 0.0,
		"main": cs != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
		"cast": cs != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "layers": gi.layers}


## Camera-independent light data: the light's world AABB, the casters (piece indices) of each positional shadow
## pass, or the sun's casters with their light-space bounds.
static func prepare_light(l: Light3D, pieces: Array[Dictionary]) -> Dictionary:
	var xf: Transform3D = l.global_transform.orthonormalized()
	var nm: String = String(l.name)
	if nm == "Light" and l.get_parent() != null:  # a fixture's light: name it by its fixture
		nm = String(l.get_parent().name)
	var out: Dictionary = {"light": l, "name": nm, "xf": xf}
	var casters: Array[int] = []
	for i: int in range(pieces.size()):
		var p: Dictionary = pieces[i]
		if bool(p["cast"]) and (int(p["layers"]) & int(l.shadow_caster_mask)) != 0:
			casters.append(i)
	if l is DirectionalLight3D:
		out["kind"] = &"dir"
		var inv: Transform3D = xf.affine_inverse()
		var lo: PackedVector3Array = PackedVector3Array()
		var hi: PackedVector3Array = PackedVector3Array()
		for i2: int in casters:
			var lb: AABB = inv * (pieces[i2]["aabb"] as AABB)
			lo.append(lb.position)
			hi.append(lb.end)
		out["casters"] = casters
		out["lo"] = lo
		out["hi"] = hi
		return out
	var passes: Array = []
	if l is SpotLight3D:
		var sp: SpotLight3D = l
		out["kind"] = &"spot"
		out["range"] = sp.spot_range
		var ang: float = deg_to_rad(sp.spot_angle)
		var sz: float = sin(ang) * sp.spot_range
		out["aabb"] = xf * (AABB(-Vector3.ONE * sp.spot_range, Vector3.ONE * 2.0 * sp.spot_range) if ang > PI * 0.5
			else AABB(Vector3(-sz, -sz, -sp.spot_range), Vector3(sz * 2.0, sz * 2.0, sp.spot_range)))
		var fov: float = minf(sp.spot_angle * 2.0, 179.0)
		passes.append(_in_volume(casters, pieces, LcGeom.frustum_planes(xf, fov, 1.0, 0.025, sp.spot_range)))
	else:
		var om: OmniLight3D = l as OmniLight3D
		out["kind"] = &"omni"
		out["range"] = om.omni_range
		out["aabb"] = xf * AABB(-Vector3.ONE * om.omni_range, Vector3.ONE * 2.0 * om.omni_range)
		if om.omni_shadow_mode == OmniLight3D.SHADOW_DUAL_PARABOLOID:
			for s: float in [1.0, -1.0]:
				var half: Array[Plane] = [Plane(xf.basis.z * s, xf.origin)]
				passes.append(_in_volume(casters, pieces, half, xf.origin, om.omni_range))
		else:
			for f: Array in CUBE:
				var face: Transform3D = xf * Transform3D(Basis.looking_at(f[0], f[1]), Vector3.ZERO)
				passes.append(_in_volume(casters, pieces, LcGeom.frustum_planes(face, 90.0, 1.0, 0.025, om.omni_range)))
	out["passes"] = passes
	return out


## Piece indices (of `from`) whose AABB is inside `planes` (and touches the sphere (c, r) when r > 0).
static func _in_volume(from: Array[int], pieces: Array[Dictionary], planes: Array[Plane], c: Vector3 = Vector3.ZERO,
		r: float = 0.0) -> Array[int]:
	var out: Array[int] = []
	for i: int in from:
		var box: AABB = pieces[i]["aabb"]
		if (r <= 0.0 or aabb_sphere(box, c, r)) and LcGeom.aabb_in_frustum(box, planes):
			out.append(i)
	return out


static func aabb_sphere(box: AABB, c: Vector3, r: float) -> bool:
	var q: Vector3 = c.clamp(box.position, box.end)
	return q.distance_squared_to(c) <= r * r


## Godot's visibility range test (camera to the AABB centre; the margins widen the range: a fading or not yet
## switched instance still draws).
static func in_range(p: Dictionary, eye: Vector3) -> bool:
	var b: float = float(p["vr_begin"])
	var e: float = float(p["vr_end"])
	if b <= 0.0 and e <= 0.0:
		return true
	var d: float = (p["aabb"] as AABB).get_center().distance_to(eye)
	return d >= b and (e <= 0.0 or d <= e)


## Draws for one view: { main, lit, shadow, tris, shadow_lights, by_light: [[name, draws]] (descending) }.
static func count_view(pieces: Array[Dictionary], lights: Array[Dictionary], xf: Transform3D,
		cp: Dictionary) -> Dictionary:
	var eye: Vector3 = xf.origin
	var planes: Array[Plane] = LcGeom.frustum_planes(xf, cp["fov"], ASPECT, NEAR, FAR, float(cp["ortho"]))
	var corners: PackedVector3Array = slice_corners(xf, cp, NEAR, FAR)
	var ok: PackedByteArray = PackedByteArray()
	ok.resize(pieces.size())
	var seen: Array[int] = []
	var main: int = 0
	var tris: int = 0
	for i: int in range(pieces.size()):
		var pc: Dictionary = pieces[i]
		if not in_range(pc, eye):
			continue
		ok[i] = 1
		if bool(pc["main"]) and LcGeom.aabb_in_frustum(pc["aabb"], planes):
			main += int(pc["surfaces"])
			tris += int(pc["tris"])
			seen.append(i)
	var shadow: int = 0
	var shadow_lights: int = 0
	var suns: int = 0
	var positional: Array[Dictionary] = []
	var by_light: Array = []
	for ld: Dictionary in lights:
		var n: int = -1
		if ld["kind"] == &"dir":
			n = _sun_draws(ld, pieces, ok, xf, cp)
			suns += 1
		else:
			n = _positional_draws(ld, pieces, eye, planes, corners)
			if n >= 0:
				positional.append(ld)
		if n < 0:
			continue
		shadow_lights += 1
		shadow += n
		by_light.append([ld["name"], n])
	by_light.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	# Compatibility: max(1, paired shadowed positional lights + shadowed suns) colour passes per shaded surface
	var lit: int = 0
	for i2: int in seen:
		var box: AABB = pieces[i2]["aabb"]
		var k: int = suns
		for ld2: Dictionary in positional:
			if (ld2["aabb"] as AABB).intersects(box):
				k += 1
		lit += int(pieces[i2]["lit_surfaces"]) * maxi(0, k - 1)
	return {"main": main, "lit": lit, "shadow": shadow, "tris": tris, "shadow_lights": shadow_lights,
		"by_light": by_light}


## -1 when the light's shadow does not render for this view.
static func _positional_draws(ld: Dictionary, pieces: Array[Dictionary], eye: Vector3, planes: Array[Plane],
		corners: PackedVector3Array) -> int:
	var l: Light3D = ld["light"]
	var pos: Vector3 = (ld["xf"] as Transform3D).origin
	if not LcGeom.aabb_in_frustum(ld["aabb"], planes):
		return -1
	if l.distance_fade_enabled:
		var d: float = pos.distance_to(eye)
		if d > l.distance_fade_begin + l.distance_fade_length or d > l.distance_fade_shadow + l.distance_fade_length:
			return -1
	var hull: Array[Plane] = shadow_hull(corners, pos, false)
	var n: int = 0
	for pass_list: Array[int] in ld["passes"]:
		for i: int in pass_list:
			if LcGeom.aabb_in_frustum(pieces[i]["aabb"], hull):
				n += int(pieces[i]["surfaces"])
				if tally_on:
					_tally(ld, i, int(pieces[i]["surfaces"]))
	return n


static func _tally(ld: Dictionary, i: int, n: int) -> void:
	var key: Array = [ld["name"], i]
	tally[key] = int(tally.get(key, 0)) + n


## The sun's cascades (renderer_scene_cull.cpp _light_instance_setup_directional_shadow + the light culler).
static func _sun_draws(ld: Dictionary, pieces: Array[Dictionary], ok: PackedByteArray, xf: Transform3D,
		cp: Dictionary) -> int:
	var sun: DirectionalLight3D = ld["light"]
	var lxf: Transform3D = ld["xf"]
	var ortho: float = float(cp["ortho"])
	var far: float = FAR if ortho > 0.0 or sun.directional_shadow_max_distance <= 0.0 \
			else minf(sun.directional_shadow_max_distance, FAR)
	var splits: Array[float] = [0.0]
	match sun.directional_shadow_mode:
		DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS:
			splits.append(sun.directional_shadow_split_1)
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
			splits.append_array([sun.directional_shadow_split_1, sun.directional_shadow_split_2,
				sun.directional_shadow_split_3])
	splits.append(1.0)
	var inv: Transform3D = lxf.affine_inverse()
	var toward: Vector3 = lxf.basis.z.normalized()
	var casters: Array[int] = ld["casters"]
	var lo: PackedVector3Array = ld["lo"]
	var hi: PackedVector3Array = ld["hi"]
	var n: int = 0
	for s: int in range(splits.size() - 1):
		var d0: float = NEAR + (far - NEAR) * splits[s]
		var d1: float = NEAR + (far - NEAR) * splits[s + 1]
		var corners: PackedVector3Array = slice_corners(xf, cp, d0, d1)
		var a0: Vector3 = Vector3.INF
		var a1: Vector3 = -Vector3.INF
		var c: Vector3 = Vector3.ZERO
		for p: Vector3 in corners:
			var q: Vector3 = inv * p
			a0 = a0.min(q)
			a1 = a1.max(q)
			c += q
		c /= 8.0
		var r: float = 0.0
		for p2: Vector3 in corners:
			r = maxf(r, (inv * p2).distance_to(c))
		var expand: float = tan(deg_to_rad(sun.light_angular_distance)) * (2.0 * r + sun.directional_shadow_pancake_size) \
				if sun.light_angular_distance > 0.0 else 0.0
		a0 -= Vector3(expand, expand, 0.0)
		a1 += Vector3(expand, expand, 0.0)
		var hull: Array[Plane] = shadow_hull(corners, toward, true)
		for k: int in range(casters.size()):
			var i: int = casters[k]
			if ok[i] == 0:
				continue
			var b0: Vector3 = lo[k]
			var b1: Vector3 = hi[k]
			# light space: +z is toward the light (unbounded); cut at the split's far side
			if b1.x < a0.x or b0.x > a1.x or b1.y < a0.y or b0.y > a1.y or b1.z < a0.z:
				continue
			if LcGeom.aabb_in_frustum(pieces[i]["aabb"], hull):
				n += int(pieces[i]["surfaces"])
				if tally_on:
					_tally(ld, i, int(pieces[i]["surfaces"]))
	return n


## Godot's tighter caster culling volume (rendering_light_culler.cpp): the convex hull of a frustum (8 corners,
## slice_corners order) and a light: a point (`light` = position) or, `directional`, at infinity (`light` = the
## direction toward it). Frustum faces the light is inside of, plus silhouette planes through the edges between a
## face it is inside of and one it is outside of. Inward planes (Plane.distance_to >= 0 inside).
static func shadow_hull(corners: PackedVector3Array, light: Vector3, directional: bool) -> Array[Plane]:
	var centre: Vector3 = Vector3.ZERO
	for p: Vector3 in corners:
		centre += p
	centre /= 8.0
	var face_planes: Array[Plane] = []
	var outside: Array[bool] = []
	var out: Array[Plane] = []
	for f: Array in FACES:
		var pl: Plane = Plane(corners[f[0]], corners[f[1]], corners[f[2]])
		if pl.distance_to(centre) < 0.0:
			pl = -pl
		face_planes.append(pl)
		var o: bool = pl.normal.dot(light) < 0.0 if directional else pl.distance_to(light) < 0.0
		outside.append(o)
		if not o:
			out.append(pl)
	if not outside.has(true):
		return out
	var edges: Dictionary = {}
	for fi: int in range(FACES.size()):
		var f2: Array = FACES[fi]
		for e: int in range(4):
			var a: int = f2[e]
			var b: int = f2[(e + 1) % 4]
			var key: int = mini(a, b) * 8 + maxi(a, b)
			if not edges.has(key):
				edges[key] = []
			(edges[key] as Array).append(fi)
	for key2: int in edges:
		var fs: Array = edges[key2]
		if fs.size() != 2 or outside[fs[0]] == outside[fs[1]]:
			continue
		var pa: Vector3 = corners[key2 / 8]
		var pb: Vector3 = corners[key2 % 8]
		var nrm: Vector3 = (pb - pa).cross(light if directional else light - pa)
		if nrm.length_squared() < 1e-12:
			continue
		var sp: Plane = Plane(nrm.normalized(), pa)
		if sp.distance_to(centre) < 0.0:
			sp = -sp
		out.append(sp)
	return out


## The 8 world-space corners of the view frustum between depths d0 and d1 (index layer * 4 + sx * 2 + sy).
static func slice_corners(xf: Transform3D, cp: Dictionary, d0: float, d1: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var ortho: float = float(cp["ortho"])
	var fwd: Vector3 = -xf.basis.z.normalized()
	var up: Vector3 = xf.basis.y.normalized()
	var right: Vector3 = xf.basis.x.normalized()
	for d: float in [d0, d1]:
		var hh: float = ortho * 0.5 if ortho > 0.0 else d * tan(deg_to_rad(float(cp["fov"])) * 0.5)
		var hw: float = hh * ASPECT
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				out.append(xf.origin + fwd * d + right * (hw * sx) + up * (hh * sy))
	return out


static func _mesh_tris(mesh: Mesh, cache: Dictionary) -> int:
	var mid: int = mesh.get_instance_id()
	if not cache.has(mid):
		var t: int = 0
		for s: int in range(mesh.get_surface_count()):
			t += _surface_tris(mesh, s)
		cache[mid] = t
	return cache[mid]


static func _surface_tris(mesh: Mesh, s: int) -> int:
	var arrays: Array = mesh.surface_get_arrays(s)
	if arrays.is_empty():
		return 0
	if arrays[Mesh.ARRAY_INDEX] != null and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 0:
		return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
