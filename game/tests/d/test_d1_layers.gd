## D-132 D1 (world/characters/_tools/char_layers.gd): per-node surface merge on the crowd and unit characters.
## * Every character with a CrowdLod, not in _layers/d1_exclude.json "ids" and (when listed) in its "only": each mesh
##   node whose plain materials share a texture tier draws them as ONE surface per tier (char_layered_<tier>.tres),
##   the other materials keep their own surface; the node's meta source_materials lists the glb's materials in order;
##   vertices and LOD0 triangles are the glb's, and every vertex's UV2 layer is its source material's layer in
##   layers.json.
## * Characters without a CrowdLod (heisters, specials, contacts), the d1_exclude.json ids and (D-165) every id outside
##   a non-empty "only" keep the glb meshes.
## * layers.json covers every plain material of the merged characters; the texture arrays load with the layer counts
##   it records; the shader keeps decals (no decals_disabled).
## * The fallback: char_layers.is_merged honours the exclude and only lists, and merging a glb node in-test gives the same
##   result as the assembled scene (the assemble path the fallback skips).
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const Layers: GDScript = preload("res://world/characters/_tools/char_layers.gd")

var _index: Array[Dictionary] = []
var _layers: Dictionary = {}
var _excluded: Array[String] = []
var _only: Array[String] = []


func before_all() -> void:
	_index = Spec.read_index()
	_layers = Layers.read_index()
	_excluded = Layers.excluded_ids()
	_only = Layers.only_ids()


func _instance(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		fail("could not load %s" % path)
		return null
	var node: Node3D = packed.instantiate() as Node3D
	add_child(node)
	return node


func _glb_path(e: Dictionary) -> String:
	return "%s%s/%s.glb" % [Spec.ASSETS_DIR, e["asset"], e["asset"]]


func _tris(mesh: Mesh, si: int) -> int:
	return mesh.surface_get_array_index_len(si) / 3


func test_index_and_arrays() -> void:
	assert_true(_layers.has("materials") and _layers.has("tiers"), "layers.json readable (run build_char_layers.gd)")
	var tiers: Dictionary = _layers.get("tiers", {})
	assert_true(tiers.has("256"), "a 256 tier")
	var ref: ORMMaterial3D = Layers.plain_reference()
	for key: String in tiers:
		var tier: int = int(key)
		var t: Dictionary = tiers[key]
		var n: int = int(t["layers"])
		assert_true(n > 0 and n <= Layers.MAX_LAYERS, "tier %d: %d layers within 1..%d" % [tier, n, Layers.MAX_LAYERS])
		assert_eq(int(t["slices"]), int(t["columns"]) * int(t["rows"]), "tier %d: slices = columns x rows" % tier)
		assert_true(int(t["slices"]) >= n, "tier %d: a slice per layer" % tier)
		for map: String in Layers.MAPS:
			var arr: TextureLayered = load(Layers.array_path(tier, map)) as TextureLayered
			assert_true(arr != null, "tier %d %s: a texture array (godot --import)" % [tier, map])
			if arr == null:
				continue
			assert_eq(arr.get_layers(), int(t["slices"]), "tier %d %s: layer count" % [tier, map])
			assert_eq(arr.get_width(), tier, "tier %d %s: width" % [tier, map])
			assert_eq(arr.get_height(), tier, "tier %d %s: height" % [tier, map])
			assert_true(arr.has_mipmaps(), "tier %d %s: mipmaps" % [tier, map])
		var mat: ShaderMaterial = load(Layers.material_path(tier)) as ShaderMaterial
		assert_true(mat != null and mat.shader != null and mat.shader.resource_path == Layers.SHADER_PATH,
			"tier %d: ShaderMaterial on char_layered.gdshader" % tier)
		if mat != null:
			for map: String in Layers.MAPS:
				var tex: Variant = mat.get_shader_parameter("texture_" + map)
				assert_true(tex is TextureLayered and (tex as TextureLayered).resource_path == Layers.array_path(tier, map),
					"tier %d: texture_%s is its array" % [tier, map])
		var paths: Array = t["materials"]
		assert_eq(paths.size(), n, "tier %d: material list size" % tier)
		for i: int in range(paths.size()):
			var entry: Dictionary = (_layers["materials"] as Dictionary).get(paths[i], {})
			assert_eq(int(entry.get("layer", -1)), i, "%s: layer %d" % [paths[i], i])
			assert_eq(int(entry.get("tier", -1)), tier, "%s: tier %d" % [paths[i], tier])
			assert_eq(Layers.tier_of(load(String(paths[i])) as Material, ref), tier, "%s is plain at %d" % [paths[i], tier])


func test_shader_keeps_decals_fog_and_shadows() -> void:
	var code: String = (load(Layers.SHADER_PATH) as Shader).code
	for banned: String in ["decals_disabled", "unshaded", "fog_disabled", "shadows_disabled", "ambient_light_disabled",
			"cull_disabled", "shadow_to_opacity"]:
		assert_false(code.contains(banned), "char_layered.gdshader has no %s" % banned)
	assert_true(code.contains("repeat_enable"), "array samplers repeat (tiled UVs)")


func test_merged_nodes() -> void:
	var ref: ORMMaterial3D = Layers.plain_reference()
	var merged_chars: int = 0
	for e: Dictionary in _index:
		if bool(e.get("test", false)):
			continue
		var root: Node3D = _instance(String(e["scene"]))
		var glb: Node3D = _instance(_glb_path(e))
		if root == null or glb == null:
			continue
		var tag: String = String(e["id"])
		var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
		var has_lod: bool = skel.get_node_or_null(NodePath(CrowdLod.NODE_NAME)) != null
		var want_merge: bool = Layers.is_merged(tag, 15.0 if has_lod else 0.0, _excluded, _only)
		var any_merged: bool = false
		for mi: MeshInstance3D in CrowdLod.source_meshes(skel):
			var src: MeshInstance3D = glb.get_node_or_null(NodePath("Skeleton3D/" + String(mi.name))) as MeshInstance3D
			if src == null:
				continue
			var label: String = "%s/%s" % [tag, mi.name]
			var tiers: Dictionary = {}
			var kept: int = 0
			var want_paths: Array[String] = []
			for si: int in range(src.mesh.get_surface_count()):
				var m: Material = Layers.surface_material(src, si)
				want_paths.append(m.resource_path if m != null else "")
				var tier: int = Layers.tier_of(m, ref) if src.material_override == null else 0
				if tier > 0 and want_merge:
					assert_true((_layers["materials"] as Dictionary).has(m.resource_path),
						"%s: plain %s is in layers.json" % [label, m.resource_path])
				if tier > 0:
					tiers[tier] = int(tiers.get(tier, 0)) + 1
				else:
					kept += 1
			var shared: bool = false
			for tier: int in tiers:
				shared = shared or int(tiers[tier]) > 1
			if not want_merge or (kept + tiers.size() == src.mesh.get_surface_count()):
				assert_false(mi.has_meta(Layers.META_SOURCE), "%s: not merged" % label)
				assert_eq(mi.mesh, src.mesh, "%s: keeps the glb mesh" % label)
				continue
			any_merged = true
			assert_true(shared, "%s: merged because surfaces share a tier" % label)
			assert_true(mi.has_meta(Layers.META_SOURCE), "%s: meta source_materials" % label)
			var meta: Array[String] = []
			meta.assign(mi.get_meta(Layers.META_SOURCE, []))
			assert_eq(meta, want_paths, "%s: source_materials = the glb's materials in order" % label)
			assert_eq(mi.mesh.get_surface_count(), kept + tiers.size(), "%s: one surface per tier + the kept ones" % label)
			_check_merged_mesh(label, src, mi)
		if want_merge:
			assert_true(any_merged, "%s: at least one merged node" % tag)
		if want_merge:
			merged_chars += 1
		root.queue_free()
		glb.queue_free()
	var want: int = _only.size() - _excluded.size() if not _only.is_empty() else 40
	assert_true(merged_chars >= want, "D1 merge on the scoped casts (%d of at least %d)" % [merged_chars, want])


func _check_merged_mesh(label: String, src: MeshInstance3D, mi: MeshInstance3D) -> void:
	var src_verts: int = 0
	var src_tris: int = 0
	for si: int in range(src.mesh.get_surface_count()):
		src_verts += src.mesh.surface_get_array_len(si)
		src_tris += _tris(src.mesh, si)
	var verts: int = 0
	var tris: int = 0
	var seen_tiers: Array[int] = []
	for si: int in range(mi.mesh.get_surface_count()):
		verts += mi.mesh.surface_get_array_len(si)
		tris += _tris(mi.mesh, si)
		var m: Material = mi.mesh.surface_get_material(si)
		if m is ShaderMaterial:
			var tier: int = int(String(mi.mesh.surface_get_name(si)).trim_prefix("layers_"))
			assert_false(seen_tiers.has(tier), "%s: one layered surface for tier %d" % [label, tier])
			seen_tiers.append(tier)
			assert_eq(m.resource_path, Layers.material_path(tier), "%s surface %d: char_layered_%d" % [label, si, tier])
			var uv2: PackedVector2Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_TEX_UV2]
			var bad: int = 0
			for v: Vector2 in uv2:
				if absf(v.x - roundf(v.x)) > 0.001 or v.y < 0.249 or v.y > 0.751:
					bad += 1
			assert_eq(bad, 0, "%s surface %d: UV2 = integer layer + SSS code" % [label, si])
		else:
			assert_true(m is BaseMaterial3D, "%s surface %d: a kept surface keeps its glb material" % [label, si])
	assert_eq(verts, src_verts, "%s: same vertex count as the glb" % label)
	assert_eq(tris, src_tris, "%s: same LOD0 triangle count as the glb" % label)
	assert_eq(mi.skin, src.skin, "%s: same skin" % label)
	# every source material's vertices sit in its layer: a material's layer vertex count equals its glb surface's
	for si: int in range(src.mesh.get_surface_count()):
		var m: Material = Layers.surface_material(src, si)
		if m == null or not (_layers["materials"] as Dictionary).has(m.resource_path):
			continue
		var own: int = 0
		for sj: int in range(src.mesh.get_surface_count()):
			var mj: Material = Layers.surface_material(src, sj)
			if mj != null and mj.resource_path == m.resource_path:
				own += src.mesh.surface_get_array_len(sj)
		assert_eq(Layers.material_vertices(mi, m.resource_path).size(), own, "%s: %s vertices in its layer" % [
			label, m.resource_path.get_file()])


func test_uv2_code_round_trip() -> void:
	var m: ORMMaterial3D = ORMMaterial3D.new()
	for sss: float in [0.0, 0.25, 0.3, 1.0]:
		m.subsurf_scatter_enabled = sss > 0.0
		m.subsurf_scatter_strength = sss
		var uv2: Vector2 = Layers.encode_uv2(17, m)
		# the shader's decode (char_layered.gdshader)
		assert_eq(roundi(uv2.x), 17, "layer")
		assert_near(clampf((uv2.y - 0.25) * 2.0, 0.0, 1.0), sss, 0.0001, "sss %.2f" % sss)
	m.subsurf_scatter_enabled = false
	m.subsurf_scatter_strength = 0.5
	assert_near(Layers.encode_uv2(0, m).y, 0.25, 0.0001, "SSS off: strength 0")


## The per-character fallback: an id in d1_exclude.json is never merged, and the assembled scenes follow the list.
func test_fallback_switch() -> void:
	assert_true(Layers.is_merged("gallery_waiter", 15.0, [] as Array[String]), "a crowd character is merged")
	assert_false(Layers.is_merged("gallery_waiter", 15.0, ["gallery_waiter"] as Array[String]),
		"an excluded id is not merged")
	assert_false(Layers.is_merged("crew_rook", 0.0, [] as Array[String]), "no CrowdLod: not merged")
	assert_true(Layers.is_merged("club_dancer", 15.0, [] as Array[String], ["club_dancer"] as Array[String]),
		"an id under only is merged")
	assert_false(Layers.is_merged("gallery_waiter", 15.0, [] as Array[String], ["club_dancer"] as Array[String]),
		"an id outside a non-empty only is not merged")
	var text: String = FileAccess.get_file_as_string(Layers.EXCLUDE_PATH)
	var data: Variant = JSON.parse_string(text)
	assert_true(data is Dictionary and (data as Dictionary).get("ids") is Array, "d1_exclude.json = {\"ids\": [...]}")
	for id: String in _only:
		assert_true(ResourceLoader.exists("res://world/characters/%s/%s.tscn" % [id, id]), "only lists %s: a scene" % id)
	for id: String in _excluded:
		var path: String = "res://world/characters/%s/%s.tscn" % [id, id]
		if not ResourceLoader.exists(path):
			fail("d1_exclude.json lists %s, which has no scene" % id)
			continue
		var root: Node3D = _instance(path)
		for mi: MeshInstance3D in CrowdLod.source_meshes(root.get_node("Skeleton3D")):
			assert_false(mi.has_meta(Layers.META_SOURCE), "%s/%s: excluded, glb mesh" % [id, mi.name])
			assert_true(mi.mesh.resource_path.contains(".glb::"), "%s/%s: excluded, glb mesh" % [id, mi.name])
		root.queue_free()
	# what the fallback skips: merging a glb node reproduces the assembled node's surface layout
	var sample: String = _only[0] if not _only.is_empty() else "gallery_waiter"
	var glb: Node3D = _instance("%schar_%s/char_%s.glb" % [Spec.ASSETS_DIR, sample, sample])
	var scene: Node3D = _instance("res://world/characters/%s/%s.tscn" % [sample, sample])
	if glb == null or scene == null:
		return
	var errors: Array[String] = []
	var outfit: MeshInstance3D = glb.get_node("Skeleton3D/Outfit") as MeshInstance3D
	var merged: ArrayMesh = Layers.merge_mesh(outfit, _layers, errors)
	assert_eq(errors, [] as Array[String], "merge_mesh: no errors")
	var assembled: Mesh = (scene.get_node("Skeleton3D/Outfit") as MeshInstance3D).mesh
	if not _excluded.has(sample):
		assert_true(merged != null and merged.get_surface_count() == assembled.get_surface_count(),
			"%s/Outfit: in-test merge = assembled surfaces" % sample)
	else:
		assert_eq(assembled, outfit.mesh, "%s excluded: the assembled Outfit is the glb mesh" % sample)
	assert_true(merged != null and merged.get_surface_count() < outfit.mesh.get_surface_count(),
		"%s/Outfit: fewer surfaces than the glb (%d)" % [sample, outfit.mesh.get_surface_count()])
	glb.queue_free()
	scene.queue_free()
