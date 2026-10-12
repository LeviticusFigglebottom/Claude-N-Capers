## D4-01: character LODs (world/characters/_tools/crowd_lod.gd). For every indexed character scene:
## * LOD1: each big surface carries Godot's automatic LODs down to <= 50 % (import `generate_lods`).
## * LOD2: crowd NPCs and armed units have `Skeleton3D/CrowdLod`, ONE skinned surface with the shared
##   char_crowd_lod material at 8..25 % of the full tris, visible from the switch distance while every glb
##   mesh ends there; heisters, contacts and specials with toggled meshes / overrides have none.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const BIG_SURFACE: int = 1000

var _index: Array[Dictionary] = []


func before_all() -> void:
	_index = Spec.read_index()


func _instance(entry: Dictionary) -> Node3D:
	var packed: PackedScene = load(String(entry["scene"])) as PackedScene
	if packed == null:
		fail("could not load %s" % entry["scene"])
		return null
	var node: Node3D = packed.instantiate() as Node3D
	add_child(node)
	return node


func test_auto_lods_on_big_surfaces() -> void:
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		# Per character: the big surfaces' automatic LODs reach <= 45 % in total (a few hard-edged garment
		# surfaces stop at ~70 %, the body / hair / cloth panels go to 12 % and below).
		var total: int = 0
		var reduced: int = 0
		for mi: MeshInstance3D in CrowdLod.source_meshes(root.get_node("Skeleton3D")):
			var surfs: Array = (mi.mesh as ArrayMesh).get("_surfaces")
			for si: int in range(surfs.size()):
				var s: Dictionary = surfs[si]
				var count: int = int(s.get("index_count", 0))
				if count / 3 < BIG_SURFACE:
					continue
				var lods: Array = s.get("lods", [])
				var width: int = (s["index_data"] as PackedByteArray).size() / count
				var smallest: int = count
				for i: int in range(1, lods.size(), 2):
					smallest = mini(smallest, (lods[i] as PackedByteArray).size() / width)
				total += count
				reduced += smallest
		if total > 0:
			assert_true(reduced * 100 <= total * 45, "%s: automatic LODs reach %d %% of the big surfaces (<= 45 %%)" % [
				e["id"], reduced * 100 / total])
		root.queue_free()


func test_crowd_lod_shape_and_ranges() -> void:
	var with_lod: int = 0
	for e: Dictionary in _index:
		if bool(e.get("test", false)):
			continue
		var root: Node3D = _instance(e)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
		var meshes: Array[MeshInstance3D] = CrowdLod.source_meshes(skel)
		var names: Array[String] = []
		for mi: MeshInstance3D in meshes:
			names.append(String(mi.name))
		var source: Dictionary = Spec.read_source("%s%s/SOURCE.txt" % [Spec.ASSETS_DIR, e["asset"]])
		var want: float = CrowdLod.switch_m(source, names)
		var lod: MeshInstance3D = skel.get_node_or_null(NodePath(CrowdLod.NODE_NAME)) as MeshInstance3D
		var tag: String = String(e["id"])
		if want <= 0.0:
			assert_true(lod == null, "%s: no LOD2 (heister / contact / gameplay-toggled meshes)" % tag)
			for mi: MeshInstance3D in meshes:
				assert_near(mi.visibility_range_end, 0.0, 0.001, "%s/%s has no visibility range" % [tag, mi.name])
			root.queue_free()
			continue
		with_lod += 1
		assert_true(lod != null, "%s: Skeleton3D/CrowdLod" % tag)
		if lod == null:
			root.queue_free()
			continue
		var mesh: ArrayMesh = lod.mesh as ArrayMesh
		assert_true(mesh != null and mesh.get_surface_count() == 1, "%s: CrowdLod is one surface" % tag)
		assert_eq(mesh.resource_path, String(e["scene"]).get_basename() + "_lod.res", "%s: CrowdLod mesh file" % tag)
		assert_eq(mesh.surface_get_material(0).resource_path, CrowdLod.MATERIAL_PATH, "%s: shared LOD2 material" % tag)
		assert_true(lod.skin != null and lod.skin.get_bind_count() == meshes[0].skin.get_bind_count(),
			"%s: CrowdLod skinned with the glb skin's binds" % tag)
		assert_eq(lod.skeleton, NodePath(".."), "%s: CrowdLod skeleton path" % tag)
		var arr: Array = mesh.surface_get_arrays(0)
		var tris: int = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var full: int = CrowdLod.full_tris(meshes)
		var ratio: float = float(tris) / float(full)
		assert_true(ratio >= 0.08 and ratio <= 0.25, "%s: LOD2 %d / %d tris = %.2f within 0.08..0.25" % [tag, tris, full, ratio])
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var bad_bone: bool = false
		for b: int in bones:
			bad_bone = bad_bone or b < 0 or b >= lod.skin.get_bind_count()
		assert_false(bad_bone, "%s: LOD2 bone ids within the skin binds" % tag)
		assert_near(lod.visibility_range_begin, want, 0.001, "%s: CrowdLod begins at %.0f m" % [tag, want])
		for mi: MeshInstance3D in meshes:
			assert_near(mi.visibility_range_end, want, 0.001, "%s/%s ends at %.0f m" % [tag, mi.name, want])
			assert_eq(mi.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED,
				"%s/%s: no alpha fade" % [tag, mi.name])
		root.queue_free()
	assert_true(with_lod >= 40, "LOD2 on the crowd and unit casts (%d scenes)" % with_lod)


func test_telegraph_characters_keep_full_meshes() -> void:
	for id: String in ["wrecker", "phantom", "crew_rook", "crew_sable", "crew_dutch", "crew_wren", "crew_body", "contact_odile"]:
		var path: String = "res://world/characters/%s/%s.tscn" % [id, id]
		if not ResourceLoader.exists(path):
			continue
		var root: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		add_child(root)
		assert_true(root.get_node_or_null("Skeleton3D/" + CrowdLod.NODE_NAME) == null, "%s has no CrowdLod" % id)
		root.queue_free()
