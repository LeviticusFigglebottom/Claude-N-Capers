## D-132 (D-130 perf audit, D1): per-node surface merge for crowd characters. Owner: ENV D.
## Used by build_char_layers.gd (texture arrays), assemble_characters.gd (merged meshes) and game/tests/d.
##
## Every "plain" character material (ORMMaterial3D: albedo + ORM + normal maps of one square size, nothing else set
## beyond metallic_specular, which ORMMaterial3D does not apply, and skin SSS; see ineligible_reason) becomes one layer
## of a shared texture array per size tier (TIERS): world/characters/_layers/char_layers_<tier>_<map>.png, imported as
## CompressedTexture2DArray. One ShaderMaterial per tier (char_layered_<tier>.tres, shader char_layered.gdshader) reads
## the layer from UV2.x and the SSS strength from UV2.y (encode_uv2), so all the plain surfaces of one mesh node that
## share a tier collapse into one surface (one draw, one shadow draw). Anything else (other sizes, double-sided,
## emissive, overrides) keeps its own surface and material. The nodes themselves (Body, Outfit, Gear, Headwear, Hair,
## Slung) stay, so node lookups, material_overlay (pager outline) and layers are unchanged.
##
## Which characters: the ones with a CrowdLod (CrowdLod.switch_m > 0: crowd NPCs and armed units), minus the ids in
## d1_exclude.json "ids" (the per-character fallback: list an id there, re-run build_char_layers + assemble, and that
## character gets its glb meshes and materials back), and only those under its "only" when that list is not empty
## (D-165: the Afterhours looks; D1 stays parked for the rest, D-132 addendum 2).
##
## The merged mesh keeps each source surface's automatic LODs: merged LOD k is the concatenation of every source
## surface's LOD at threshold t_k, the t_k being the sources' own thresholds merged to steps of at least LOD_STEP
## (a source switches at the next kept threshold at the latest: never coarser than before, never more draws). With
## LOD_STEP 1.0 every source threshold is kept, so each source switches exactly where it did: primitives per frame
## match the per-surface meshes (bench GN 642k vs 641.6k). A coarser step (1.6 was tried) saves ~20 % of the merged
## .res size but draws +18 % primitives (sources reach their coarse LODs later).
## Node meta `source_materials` (META_SOURCE) = the original material resource paths, in original surface order.
extends RefCounted

const DIR: String = "res://world/characters/_layers/"
const INDEX_PATH: String = "res://world/characters/_layers/layers.json"
const EXCLUDE_PATH: String = "res://world/characters/_layers/d1_exclude.json"
const SHADER_PATH: String = "res://world/characters/_layers/char_layered.gdshader"
const TIERS: Array[int] = [256, 512]
const MAPS: Array[String] = ["albedo", "orm", "normal"]
const COLUMNS: int = 16
## GL_MAX_ARRAY_TEXTURE_LAYERS minimum (GLES 3.0 / GL 3.3).
const MAX_LAYERS: int = 256
const META_SOURCE: StringName = &"source_materials"
## Merged LOD thresholds are at least this factor apart (1.0: all distinct source thresholds kept).
const LOD_STEP: float = 1.0

## Properties a plain material may set (everything else must equal REFERENCE's value).
const FREE_PROPERTIES: Array[String] = [
	"resource_name", "resource_path", "resource_local_to_scene", "resource_scene_unique_id", "script",
	"albedo_texture", "orm_texture", "normal_texture", "metallic_specular",
	"subsurf_scatter_enabled", "subsurf_scatter_strength", "subsurf_scatter_skin_mode",
]


## The reference plain material: every property a plain material must match.
static func plain_reference() -> ORMMaterial3D:
	var m: ORMMaterial3D = ORMMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.metallic = 1.0
	m.roughness = 1.0
	m.normal_enabled = true
	m.normal_scale = 1.0
	m.ao_enabled = true
	return m


## "" when `mat` can be a layer, else why not.
static func ineligible_reason(mat: Material, ref: ORMMaterial3D = null) -> String:
	var orm: ORMMaterial3D = mat as ORMMaterial3D
	if orm == null:
		return "not an ORMMaterial3D"
	if orm.resource_path.is_empty() or orm.resource_path.contains("::"):
		return "not a material file"
	if ref == null:
		ref = plain_reference()
	for p: Dictionary in orm.get_property_list():
		var name: String = p["name"]
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or FREE_PROPERTIES.has(name) or name.begins_with("metadata/"):
			continue
		if orm.get(name) != ref.get(name):
			return "%s = %s" % [name, orm.get(name)]
	if orm.subsurf_scatter_enabled and not orm.subsurf_scatter_skin_mode:
		return "subsurface scattering without skin mode"
	var size: int = -1
	for tex: Texture2D in [orm.albedo_texture, orm.orm_texture, orm.normal_texture]:
		if tex == null or tex.resource_path.is_empty() or not tex.resource_path.ends_with(".png"):
			return "a map is missing or not a png file"
		if tex.get_width() != tex.get_height() or (size >= 0 and tex.get_width() != size):
			return "maps not square or of different sizes"
		size = tex.get_width()
	if not TIERS.has(size):
		return "map size %d" % size
	return ""


## Texture size tier of a plain material, 0 when it is not one.
static func tier_of(mat: Material, ref: ORMMaterial3D = null) -> int:
	if not ineligible_reason(mat, ref).is_empty():
		return 0
	return (mat as ORMMaterial3D).albedo_texture.get_width()


## Grid columns for `layers` layers: COLUMNS / 2 to COLUMNS, the fewest unused slices (each costs VRAM), then the
## most columns.
static func grid_columns(layers: int) -> int:
	var best: int = 1
	var best_waste: int = layers
	for c: int in range(mini(COLUMNS / 2, layers), mini(COLUMNS, layers) + 1):
		var waste: int = ((layers + c - 1) / c) * c - layers
		if waste <= best_waste:
			best = c
			best_waste = waste
	return best


static func material_path(tier: int) -> String:
	return "%schar_layered_%d.tres" % [DIR, tier]


static func array_path(tier: int, map: String) -> String:
	return "%schar_layers_%d_%s.png" % [DIR, tier, map]


static func map_texture(mat: ORMMaterial3D, map: String) -> Texture2D:
	match map:
		"albedo":
			return mat.albedo_texture
		"orm":
			return mat.orm_texture
	return mat.normal_texture


## Character ids listed in d1_exclude.json ({"ids": [...]}): they keep their glb meshes and materials.
static func excluded_ids() -> Array[String]:
	return _scope_list("ids")


## D-165 scope: the ids under d1_exclude.json "only" ([] = every CrowdLod character). D1 stays parked for the other
## casts (D-132 addendum 2); the Afterhours looks get it for the dance-floor draw budget.
static func only_ids() -> Array[String]:
	return _scope_list("only")


static func _scope_list(key: String) -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(EXCLUDE_PATH):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXCLUDE_PATH))
	if data is Dictionary and (data as Dictionary).get(key) is Array:
		for id: Variant in (data as Dictionary)[key]:
			out.append(String(id))
	return out


## Whether a character gets the D1 merge: it has a CrowdLod (switch_m > 0), is not in d1_exclude.json "ids" and,
## when "only" lists ids, is one of them.
static func is_merged(char_id: String, switch_m: float, excluded: Array[String], only: Array[String] = []) -> bool:
	return switch_m > 0.0 and not excluded.has(char_id) and (only.is_empty() or only.has(char_id))


## {"materials": {path: {"tier": int, "layer": int}}, "tiers": {"256": {"layers": n, ...}}} or {} when missing.
static func read_index() -> Dictionary:
	if not FileAccess.file_exists(INDEX_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	return data if data is Dictionary else {}


## The material a node renders surface `si` with (override > surface override > mesh).
static func surface_material(mi: MeshInstance3D, si: int) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var m: Material = mi.get_surface_override_material(si)
	return m if m != null else mi.mesh.surface_get_material(si)


## The look materials of a character mesh node: the original (pre-merge) materials when the node was merged
## (meta source_materials), else the materials of its surfaces (`active`: as drawn, i.e. material_override first;
## else the mesh's own surface materials). Tests read materials through this.
static func look_materials(mi: MeshInstance3D, active: bool = true) -> Array[Material]:
	var out: Array[Material] = []
	if mi.has_meta(META_SOURCE):
		for p: Variant in mi.get_meta(META_SOURCE):
			out.append(load(String(p)) as Material)
		return out
	if mi.mesh == null:
		return out
	for si: int in range(mi.mesh.get_surface_count()):
		out.append(surface_material(mi, si) if active else mi.mesh.surface_get_material(si))
	return out


## Mesh-space vertices drawn with the material at `mat_path`: its own surfaces, plus on a merged node the vertices
## of the layered surface whose UV2 layer is that material's (layers.json).
static func material_vertices(mi: MeshInstance3D, mat_path: String) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if mi.mesh == null:
		return out
	var entry: Dictionary = {}
	if mi.has_meta(META_SOURCE):
		entry = (read_index().get("materials", {}) as Dictionary).get(mat_path, {})
	for si: int in range(mi.mesh.get_surface_count()):
		var m: Material = surface_material(mi, si)
		if m == null:
			continue
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if m.resource_path == mat_path:
			out.append_array(verts)
		elif not entry.is_empty() and m.resource_path == material_path(int(entry["tier"])):
			var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
			for k: int in range(verts.size()):
				if roundi(uv2[k].x) == int(entry["layer"]):
					out.append(verts[k])
	return out


## UV2 of a merged vertex: x = layer, y = 0.25 + 0.5 * sss strength (stays within [0.25, 0.75]; metallic_specular is
## not encoded: ORMMaterial3D renders every value as the default 0.5, and so does the shader).
static func encode_uv2(layer: int, mat: ORMMaterial3D) -> Vector2:
	var sss: float = clampf(mat.subsurf_scatter_strength, 0.0, 1.0) if mat.subsurf_scatter_enabled else 0.0
	return Vector2(float(layer), 0.25 + 0.5 * sss)


## Index buffer of one source surface LOD (lod < 0 = the full surface), as vertex ids.
static func lod_indices(surface: Dictionary, lod: int) -> PackedInt32Array:
	var count: int = int(surface.get("index_count", 0))
	var raw: PackedByteArray = surface.get("index_data", PackedByteArray())
	var width: int = raw.size() / maxi(count, 1)
	if lod >= 0:
		raw = (surface.get("lods", []) as Array)[lod * 2 + 1]
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(raw.size() / width)
	for k: int in range(out.size()):
		out[k] = raw.decode_u16(k * 2) if width == 2 else int(raw.decode_u32(k * 4))
	return out


## LOD thresholds (edge lengths) of one source surface, ascending.
static func lod_thresholds(surface: Dictionary) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var lods: Array = surface.get("lods", [])
	for k: int in range(0, lods.size(), 2):
		out.append(float(lods[k]))
	return out


## The merged mesh of one character mesh node (null when no two surfaces share a tier: nothing to gain).
## `index` = read_index(). Errors (a plain material missing from layers.json) go to `errors`.
static func merge_mesh(mi: MeshInstance3D, index: Dictionary, errors: Array[String]) -> ArrayMesh:
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	if mesh == null or mi.material_override != null:
		return null
	var layers: Dictionary = index.get("materials", {})
	var ref: ORMMaterial3D = plain_reference()
	var surfs: Array = mesh.get("_surfaces")
	# group key per surface: "t<tier>" for plain materials, "k<si>" (kept as is) for the rest
	var keys: Array[String] = []
	var order: Array[String] = []
	var members: Dictionary = {}
	for si: int in range(mesh.get_surface_count()):
		var mat: Material = surface_material(mi, si)
		var tier: int = tier_of(mat, ref)
		var key: String = "k%d" % si
		if tier > 0:
			if not layers.has(mat.resource_path):
				errors.append("%s: %s is not in %s (run build_char_layers.gd)" % [mi.name, mat.resource_path, INDEX_PATH])
				return null
			key = "t%d" % tier
		keys.append(key)
		if not members.has(key):
			members[key] = []
			order.append(key)
		(members[key] as Array).append(si)
	if order.size() == mesh.get_surface_count():
		return null
	var out: ArrayMesh = ArrayMesh.new()
	out.resource_name = mesh.resource_name
	out.blend_shape_mode = mesh.blend_shape_mode
	for b: int in range(mesh.get_blend_shape_count()):
		out.add_blend_shape(mesh.get_blend_shape_name(b))
	for key: String in order:
		var sis: Array = members[key]
		if key.begins_with("k"):
			_copy_surface(mesh, int(sis[0]), surfs[int(sis[0])], out)
		else:
			_add_merged(mi, mesh, surfs, sis, layers, int(key.substr(1)), out)
	return out


static func _copy_surface(mesh: ArrayMesh, si: int, surface: Dictionary, out: ArrayMesh) -> void:
	var lods: Dictionary = {}
	var th: PackedFloat32Array = lod_thresholds(surface)
	for k: int in range(th.size()):
		lods[th[k]] = lod_indices(surface, k)
	var flags: int = mesh.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(si),
		mesh.surface_get_blend_shape_arrays(si), lods, flags)
	var s: int = out.get_surface_count() - 1
	out.surface_set_material(s, mesh.surface_get_material(si))
	out.surface_set_name(s, mesh.surface_get_name(si))


static func _add_merged(mi: MeshInstance3D, mesh: ArrayMesh, surfs: Array, sis: Array, layers: Dictionary, tier: int,
		out: ArrayMesh) -> void:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var uv2s: PackedVector2Array = PackedVector2Array()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var shapes: Array = []
	for b: int in range(mesh.get_blend_shape_count()):
		shapes.append([PackedVector3Array(), PackedVector3Array(), PackedFloat32Array()])
	var offsets: PackedInt32Array = PackedInt32Array()
	var flags: int = 0
	for si_v: Variant in sis:
		flags |= mesh.surface_get_format(int(si_v)) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var per_vertex: int = 8 if flags != 0 else 4
	var all_th: Array[float] = []
	for si_v: Variant in sis:
		var si: int = si_v
		var mat: ORMMaterial3D = surface_material(mi, si) as ORMMaterial3D
		var uv2: Vector2 = encode_uv2(int((layers[mat.resource_path] as Dictionary)["layer"]), mat)
		var arr: Array = mesh.surface_get_arrays(si)
		var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		offsets.append(verts.size())
		verts.append_array(arr[Mesh.ARRAY_VERTEX])
		normals.append_array(arr[Mesh.ARRAY_NORMAL])
		tangents.append_array(arr[Mesh.ARRAY_TANGENT])
		uvs.append_array(arr[Mesh.ARRAY_TEX_UV])
		var u2: PackedVector2Array = PackedVector2Array()
		u2.resize(n)
		u2.fill(uv2)
		uv2s.append_array(u2)
		if arr[Mesh.ARRAY_BONES] != null:
			_append_skin(bones, weights, arr[Mesh.ARRAY_BONES], arr[Mesh.ARRAY_WEIGHTS], n, per_vertex)
		for k: int in lod_indices(surfs[si], -1):
			indices.append(k + offsets[offsets.size() - 1])
		var bs: Array = mesh.surface_get_blend_shape_arrays(si)
		for b: int in range(bs.size()):
			var sa: Array = bs[b]
			(shapes[b][0] as PackedVector3Array).append_array(sa[Mesh.ARRAY_VERTEX])
			if sa[Mesh.ARRAY_NORMAL] != null:
				(shapes[b][1] as PackedVector3Array).append_array(sa[Mesh.ARRAY_NORMAL])
			if sa[Mesh.ARRAY_TANGENT] != null:
				(shapes[b][2] as PackedFloat32Array).append_array(sa[Mesh.ARRAY_TANGENT])
		for t: float in lod_thresholds(surfs[si]):
			all_th.append(t)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	if not bones.is_empty():
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var blend: Array = []
	for b: int in range(shapes.size()):
		var sa: Array = []
		sa.resize(Mesh.ARRAY_MAX)
		sa[Mesh.ARRAY_VERTEX] = shapes[b][0]
		sa[Mesh.ARRAY_NORMAL] = shapes[b][1] if (shapes[b][1] as PackedVector3Array).size() == verts.size() else null
		sa[Mesh.ARRAY_TANGENT] = shapes[b][2] if (shapes[b][2] as PackedFloat32Array).size() == verts.size() * 4 else null
		blend.append(sa)
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend, _merged_lods(surfs, sis, offsets, all_th), flags)
	var s: int = out.get_surface_count() - 1
	out.surface_set_material(s, load(material_path(tier)) as Material)
	out.surface_set_name(s, "layers_%d" % tier)


## Appends one surface's bone indices / weights at `per_vertex` influences (a 4-influence surface merged with an
## 8-influence one is padded with zero weights).
static func _append_skin(bones: PackedInt32Array, weights: PackedFloat32Array, src_bones: PackedInt32Array,
		src_weights: PackedFloat32Array, n: int, per_vertex: int) -> void:
	var have: int = src_bones.size() / maxi(n, 1)
	if have == per_vertex:
		bones.append_array(src_bones)
		weights.append_array(src_weights)
		return
	for v: int in range(n):
		for k: int in range(per_vertex):
			bones.append(src_bones[v * have + k] if k < have else 0)
			weights.append(src_weights[v * have + k] if k < have else 0.0)


## {threshold: indices}: at each kept threshold every source surface contributes the LOD it would show there.
static func _merged_lods(surfs: Array, sis: Array, offsets: PackedInt32Array, all_th: Array[float]) -> Dictionary:
	all_th.sort()
	var kept: Array[float] = []
	for t: float in all_th:
		if kept.is_empty() or t >= kept[kept.size() - 1] * LOD_STEP:
			kept.append(t)
	# the coarsest source threshold always stays, so every source still reaches its last LOD
	if not all_th.is_empty() and kept[kept.size() - 1] < all_th[all_th.size() - 1]:
		if kept.size() > 1 and all_th[all_th.size() - 1] < kept[kept.size() - 1] * LOD_STEP:
			kept.remove_at(kept.size() - 1)
		kept.append(all_th[all_th.size() - 1])
	var lods: Dictionary = {}
	for t: float in kept:
		var idx: PackedInt32Array = PackedInt32Array()
		for j: int in range(sis.size()):
			var surface: Dictionary = surfs[int(sis[j])]
			var th: PackedFloat32Array = lod_thresholds(surface)
			var level: int = -1
			for k: int in range(th.size()):
				if th[k] <= t:
					level = k
			for v: int in lod_indices(surface, level):
				idx.append(v + offsets[j])
		lods[t] = idx
	return lods
