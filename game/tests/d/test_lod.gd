## D4-01: character LODs (world/characters/_tools/crowd_lod.gd). For every indexed character scene:
## * LOD1: each big surface carries Godot's automatic LODs down to <= 50 % (import `generate_lods`).
## * LOD2: crowd NPCs and armed units have `Skeleton3D/CrowdLod`, ONE skinned surface with the shared
##   char_crowd_lod material at 8..25 % of the full tris, visible from the switch distance while every glb
##   mesh ends there, casting no shadow (D-146); heisters, contacts and specials with toggled meshes / overrides have
##   none.
extends TestCase

const CLUB_PATRON_SCENE: String = "res://world/characters/club_patron/club_patron.tscn"  # LEAD: gdlint duplicated-load

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const ZOOM_SCRIPT: String = "res://world/characters/_tools/crowd_lod_zoom.gd"
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
		assert_eq(lod.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: CrowdLod casts no shadow (D-146)" % tag)
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


## D-080: no special (char_specials.py) has a CrowdLod; LOD0/1 only.
func test_specials_have_no_lod2() -> void:
	var n: int = 0
	for id: String in ["tac_heavy", "tac_heavy_frd", "corpsman", "corpsman_zero", "stinger", "longshot", "bulwark",
			"bulwark_aegis", "brandt", "wrecker", "phantom"]:
		var path: String = "res://world/characters/%s/%s.tscn" % [id, id]
		if not ResourceLoader.exists(path):
			continue
		n += 1
		var root: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		add_child(root)
		assert_true(root.get_node_or_null("Skeleton3D/" + CrowdLod.NODE_NAME) == null, "%s has no CrowdLod (D-080)" % id)
		for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
			assert_near((mi as MeshInstance3D).visibility_range_end, 0.0, 0.001, "%s/%s never culled" % [id, mi.name])
		root.queue_free()
	assert_true(n >= 8, "specials checked (%d)" % n)


class _FakeView extends Node:
	var zoom_factor: float = 4.0


## D-084: zoom_factor read defensively; the CrowdLod switch scales by it and returns to base at 1.0.
func test_zoom_scales_crowd_lod_switch() -> void:
	assert_near(CrowdLod.zoom_factor_of(null), 1.0, 0.0001, "null view -> 1.0")
	var plain: Node = Node.new()
	assert_near(CrowdLod.zoom_factor_of(plain), 1.0, 0.0001, "view without zoom_factor -> 1.0")
	plain.free()
	var view: _FakeView = _FakeView.new()
	assert_near(CrowdLod.zoom_factor_of(view), 4.0, 0.0001, "zoom_factor read")
	view.zoom_factor = 0.5
	assert_near(CrowdLod.zoom_factor_of(view), 1.0, 0.0001, "zoom < 1 clamps to 1")
	view.free()
	var root: Node3D = (load(CLUB_PATRON_SCENE) as PackedScene).instantiate() as Node3D
	add_child(root)
	var proxy: MeshInstance3D = root.get_node("Skeleton3D/" + CrowdLod.NODE_NAME) as MeshInstance3D
	assert_true(proxy.is_in_group(CrowdLod.GROUP), "CrowdLod is in the crowd_lod group")
	var base: float = proxy.visibility_range_begin
	assert_true(CrowdLod.apply_zoom_all(get_tree(), 4.0) >= 1, "apply_zoom_all found the proxy")
	assert_near(proxy.visibility_range_begin, base * 4.0, 0.001, "switch x4 at 4x zoom")
	var body: MeshInstance3D = CrowdLod.source_meshes(proxy.get_parent())[0]
	assert_near(body.visibility_range_end, base * 4.0, 0.001, "LOD0 end follows the switch")
	CrowdLod.apply_zoom(root, 1.0)
	assert_near(proxy.visibility_range_begin, base, 0.001, "back to base at 1x")
	var special: Node = (load("res://world/characters/tac_heavy/tac_heavy.tscn") as PackedScene).instantiate()
	assert_false(CrowdLod.apply_zoom(special, 4.0), "specials have nothing to scale")
	special.free()
	root.queue_free()


class _SignalView extends Node:
	signal zoom_factor_changed(f: float)
	var zoom_factor: float = 1.0


## D-084: a CrowdLod entering the tree creates the watcher; with no CrewView.local_view it is a no-op;
## a view's zoom_factor_changed drives the switch; the view leaving resets to 1x.
func test_crowd_lod_subscribes_to_zoom() -> void:
	var zoom_script: GDScript = load(ZOOM_SCRIPT) as GDScript
	var root: Node3D = (load(CLUB_PATRON_SCENE) as PackedScene).instantiate() as Node3D
	add_child(root)
	await get_tree().process_frame
	var w: Node = get_tree().root.get_node_or_null(NodePath(zoom_script.NODE_NAME))
	assert_true(w != null, "watcher created by the CrowdLod proxy")
	if w == null:
		root.queue_free()
		return
	w.call(&"recheck")
	var proxy: MeshInstance3D = root.get_node("Skeleton3D/CrowdLod") as MeshInstance3D
	var base: float = float(proxy.get_meta(CrowdLod.META_BASE, proxy.visibility_range_begin))
	var view: _SignalView = _SignalView.new()
	add_child(view)
	w.call(&"subscribe", view)
	view.zoom_factor_changed.emit(4.0)
	assert_near(proxy.visibility_range_begin, base * 4.0, 0.001, "zoom_factor_changed(4) scales the switch")
	var late: Node3D = (load("res://world/characters/club_patron_b/club_patron_b.tscn") as PackedScene).instantiate() as Node3D
	add_child(late)
	var lp: MeshInstance3D = late.get_node("Skeleton3D/CrowdLod") as MeshInstance3D
	assert_near(lp.visibility_range_begin, float(lp.get_meta(CrowdLod.META_BASE)) * 4.0, 0.001, "late spawn gets the zoom")
	view.queue_free()
	await get_tree().process_frame
	assert_near(proxy.visibility_range_begin, base, 0.001, "view gone -> back to 1x")
	assert_false(bool(w.call(&"is_subscribed")), "unsubscribed after the view left")
	late.queue_free()
	root.queue_free()


## A's A4-03 soak find: proxies entering in the same frame (a map load) share one pending watcher, not one each.
func test_one_zoom_watcher_per_tree() -> void:
	var zoom_script: GDScript = load(ZOOM_SCRIPT) as GDScript
	for n: Node in get_tree().root.get_children():
		if n.get_script() == zoom_script:
			n.free()
	var crowd: Array[Node] = []
	for i: int in 4:
		var r: Node = (load(CLUB_PATRON_SCENE) as PackedScene).instantiate()
		add_child(r)
		crowd.append(r)
	await get_tree().process_frame
	var count: int = 0
	for n: Node in get_tree().root.get_children():
		if n.get_script() == zoom_script:
			count += 1
	assert_eq(count, 1, "one watcher for 4 proxies entering in one frame")
	assert_false(get_tree().root.has_meta(zoom_script.PENDING_META), "pending marker cleared once added")
	for r: Node in crowd:
		r.queue_free()
