## materials (final): no null/default/greybox material on any surface, no missing textures,
## texel density within +-50% of the style guide target (§4: 512 px/m -> 256..768; ceilings
## (down-facing) and meta distant=true may also use 256 px/m -> 128..768; meta texel_target overrides).
class_name LcCheckMaterials
extends LcCheck

const TARGET_NEAR: float = 512.0
const TARGET_FAR: float = 256.0
const TOL_FRAC: float = 0.5
## A surface fails when more than this fraction of its area is out of tolerance.
const MAX_BAD_AREA: float = 0.2


func _init() -> void:
	id = &"materials"
	title = "Materials and texel density"
	stages = PackedStringArray(["final"])


func run(ctx: LcContext) -> void:
	var surfaces: int = 0
	var reported: Dictionary = {}
	for piece: Dictionary in LcVisual.render_pieces(ctx):
		var node: GeometryInstance3D = piece["node"]
		var mesh: Mesh = piece["mesh"]
		var mats: Array = piece["materials"]
		for s: int in range(mesh.get_surface_count()):
			surfaces += 1
			var key: String = "%d:%d" % [node.get_instance_id(), s]
			if reported.has(key):
				continue
			var mat: Material = mats[s] if s < mats.size() else null
			var problem: String = material_problem(mat)
			if problem != "":
				reported[key] = true
				fail(ctx, node, null, "surface %d: %s" % [s, problem])
				continue
			var bm: BaseMaterial3D = mat as BaseMaterial3D
			if bm != null and bm.albedo_texture != null:
				var xf: Transform3D = piece["xf"]
				var dkey: String = "dens:%d:%d:%d:%s:%s:%s" % [mesh.get_instance_id(), s, bm.get_instance_id(), xf.basis,
					node.get_meta(&"texel_target", 0.0), LcUtil.meta_b(node, &"distant")]
				if not ctx.cache.has(dkey):
					ctx.cache[dkey] = _density_problem(ctx, node, mesh, s, bm, xf)
				var dens: String = ctx.cache[dkey]
				if dens != "":
					reported[key] = true
					fail(ctx, node, null, "surface %d (%s): %s" % [s, _mat_name(bm), dens])
	note("%d surfaces checked" % surfaces)


static func _mat_name(m: Material) -> String:
	if m.resource_path != "":
		return m.resource_path.get_file()
	return m.resource_name if m.resource_name != "" else m.get_class()


## "" when fine, else a description.
static func material_problem(mat: Material) -> String:
	if mat == null:
		return "no material (renders with the default material)"
	if mat.has_meta(&"greybox") and bool(mat.get_meta(&"greybox")) or mat.resource_path.contains("/greybox"):
		return "greybox material `%s` at final stage" % _mat_name(mat)
	var untextured_ok: bool = mat.has_meta(&"untextured_ok") and bool(mat.get_meta(&"untextured_ok"))
	if mat is BaseMaterial3D:
		var bm: BaseMaterial3D = mat
		if bm.albedo_texture == null and not untextured_ok:
			return "material `%s` has no albedo texture (untextured face; meta untextured_ok for glass/emissive)" % _mat_name(bm)
		if bm.normal_enabled and bm.normal_texture == null:
			return "material `%s` enables normal map without a texture" % _mat_name(bm)
		if bm.emission_enabled and bm.emission_texture == null and bm.emission == Color.BLACK:
			return "material `%s` enables emission with black colour and no texture" % _mat_name(bm)
		if mat is ORMMaterial3D and (mat as ORMMaterial3D).orm_texture == null and not untextured_ok:
			return "ORM material `%s` has no ORM texture" % _mat_name(bm)
		return ""
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat
		if sm.shader == null:
			return "ShaderMaterial `%s` has no shader" % _mat_name(sm)
		return ""
	return ""


func _density_problem(ctx: LcContext, node: GeometryInstance3D, mesh: Mesh, s: int, bm: BaseMaterial3D, xf: Transform3D) -> String:
	var tex: Texture2D = bm.albedo_texture
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw <= 0.0 or th <= 0.0:
		return "albedo texture has zero size"
	var tri: Dictionary = LcVisual.triangles(ctx, mesh, s)
	var v: PackedVector3Array = tri["v"]
	var uv: PackedVector2Array = tri["uv"]
	var override: float = float(node.get_meta(&"texel_target", 0.0))
	var distant: bool = LcUtil.meta_b(node, &"distant")
	var total: float = 0.0
	var bad: float = 0.0
	var dens_sum: float = 0.0
	var tri_dens: float = 0.0
	if bm.uv1_triplanar:
		tri_dens = tw * bm.uv1_scale.x
		if not bm.uv1_world_triplanar:
			tri_dens /= maxf(xf.basis.get_scale().x, 1e-6)
	elif uv.size() != v.size():
		return "textured surface has no UVs"
	for i: int in range(0, v.size() - 2, 3):
		var a: Vector3 = xf * v[i]
		var b: Vector3 = xf * v[i + 1]
		var c: Vector3 = xf * v[i + 2]
		var area: float = LcGeom.tri_area(a, b, c)
		if area < 1e-6:
			continue
		var d: float = tri_dens
		if not bm.uv1_triplanar:
			var uva: float = LcGeom.tri_area_2d(uv[i], uv[i + 1], uv[i + 2]) * absf(bm.uv1_scale.x * bm.uv1_scale.y)
			d = sqrt(uva * tw * th / area)
		var nrm: Vector3 = (b - a).cross(c - a).normalized()
		var lo: float = TARGET_NEAR * (1.0 - TOL_FRAC)
		var hi: float = TARGET_NEAR * (1.0 + TOL_FRAC)
		if override > 0.0:
			lo = override * (1.0 - TOL_FRAC)
			hi = override * (1.0 + TOL_FRAC)
		elif distant or nrm.y < -0.7:
			# Ceilings / distant: 256 px/m target, but the near target is also acceptable.
			lo = TARGET_FAR * (1.0 - TOL_FRAC)
		total += area
		dens_sum += d * area
		if d < lo - 0.5 or d > hi + 0.5:
			bad += area
	if total <= 0.0:
		return ""
	if bad / total > MAX_BAD_AREA:
		return "texel density %.0f px/m (area-weighted) out of +-%d%% of target on %.0f%% of its area" \
			% [dens_sum / total, int(TOL_FRAC * 100.0), bad / total * 100.0]
	return ""
