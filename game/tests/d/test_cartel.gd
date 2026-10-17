## QC-36: Ortega Fisheries Co-op gunmen (`enemy.cartel_gunman`, Dockside Burn), built by
## tools/blender/characters/char_cartel.py. Checks the assembled scenes against the character
## contract (docs/contracts/characters.md: Root > Skeleton3D with skinned meshes and the
## HandR/HandL/Head/Back/Hip BoneAttachment3D markers with a Socket), that every surface resolves to
## a library material, the triangle budget, plausible heights, that they wear no insignia / uniform
## materials (police, TAC, security, faction or livery ids), that every one wears the sling and that
## the slung long gun on the back marks the gunmen who carry it (D-116: 3 of the 6 looks; D-115 DB cast: 6 of the 12).
## D-115 DB cast (GN-D1 standard): up to 12 gunmen posted at Cataclysm draw from 12 looks a-l. Regenerate with
## tools/blender/characters/assemble.sh.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const Layers: GDScript = preload("res://world/characters/_tools/char_layers.gd")

const GUNMEN: Array[String] = [
	"char_cartel_gunman", "char_cartel_gunman_b", "char_cartel_gunman_c", "char_cartel_gunman_d", "char_cartel_gunman_e",
	"char_cartel_gunman_f", "char_cartel_gunman_g", "char_cartel_gunman_h", "char_cartel_gunman_i", "char_cartel_gunman_j",
	"char_cartel_gunman_k", "char_cartel_gunman_l",
]
## the looks with a slung long gun on the back (the others' long gun is the held one)
const SLUNG: Array[String] = [
	"char_cartel_gunman", "char_cartel_gunman_c", "char_cartel_gunman_e", "char_cartel_gunman_g", "char_cartel_gunman_i",
	"char_cartel_gunman_k",
]
const TRI_BUDGET: int = 35000
const MIN_HEIGHT: float = 1.6
const MAX_HEIGHT: float = 2.0
const ALLOWED_MESHES: Array[String] = ["Body", "Hair", "Outfit", "Gear", "Headwear", "Slung"]
const MAT_DIR: String = "res://world/materials/"
## Uniform / insignia material families the Co-op's armed civilians must never wear.
const FORBIDDEN_PREFIXES: Array[String] = [
	"char_police_", "char_hivis", "char_tac_", "char_sec_", "char_frd_", "char_sen_", "char_zero_",
	"char_bank_", "char_ng_", "char_visor_",
]
const SLING: String = "char_cartel_webbing"
const SLUNG_GUN: String = "char_cartel_gunmetal"

var _index: Dictionary = {}


func before_all() -> void:
	for e: Dictionary in Spec.read_index():
		_index[String(e.get("asset", ""))] = e


func _instance(asset_id: String) -> Node3D:
	var packed: PackedScene = load(Spec.scene_path(asset_id)) as PackedScene
	if packed == null:
		fail("could not load %s (run tools/blender/characters/assemble.sh)" % Spec.scene_path(asset_id))
		return null
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	return root


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if String(n.name) != "CrowdLod":  # D4-01 LOD2 proxy: checked by test_lod.gd
			out.append(n as MeshInstance3D)
	return out


func _tris(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _height(root: Node3D) -> float:
	var box: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in _meshes(root):
		var b: AABB = mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.end.y


## Material ids (file basenames) used on any surface of the character.
func _material_ids(root: Node3D) -> Array[String]:
	var ids: Array[String] = []
	for mi: MeshInstance3D in _meshes(root):
		var look: Array[Material] = Layers.look_materials(mi)
		for s: int in range(look.size()):
			var m: Material = look[s]
			if m == null:
				continue
			var id: String = m.resource_path.get_file().get_basename()
			if not ids.has(id):
				ids.append(id)
	return ids


func test_index_lists_every_gunman() -> void:
	for id: String in GUNMEN:
		assert_true(_index.has(id), "%s in characters.json" % id)
		if not _index.has(id):
			continue
		var e: Dictionary = _index[id]
		var cid: String = Spec.character_id(id)
		assert_eq(String(e["scene"]), "%s%s/%s.tscn" % [Spec.OUT_DIR, cid, cid], "%s: scene path convention" % id)
		assert_false(bool(e.get("test", false)), "%s: cast, not a test fixture" % id)
		assert_true(ResourceLoader.exists(String(e["scene"])), "%s: scene exists" % id)


func test_scene_contract_and_budget() -> void:
	for id: String in GUNMEN:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node_or_null("Skeleton3D") as Skeleton3D
		assert_true(skel != null, "%s: Root/Skeleton3D" % id)
		if skel == null:
			root.queue_free()
			continue
		assert_eq(skel.get_bone_count(), Spec.contract_bones().size(), "%s: contract bones" % id)
		assert_true(root.get_node_or_null("AnimationPlayer") is AnimationPlayer, "%s: AnimationPlayer" % id)
		for marker: String in Spec.MARKERS:
			var att: BoneAttachment3D = skel.get_node_or_null(marker) as BoneAttachment3D
			assert_true(att != null, "%s: %s marker" % [id, marker])
			if att != null:
				assert_true(att.get_node_or_null(Spec.SOCKET_NAME) is Marker3D, "%s: %s/Socket" % [id, marker])
		var tris: int = 0
		var names: Array[String] = []
		for mi: MeshInstance3D in _meshes(root):
			names.append(String(mi.name))
			assert_has(ALLOWED_MESHES, String(mi.name), "%s: unexpected mesh %s" % [id, mi.name])
			assert_true(mi.get_parent() == skel, "%s/%s: child of Skeleton3D" % [id, mi.name])
			assert_true(mi.skin != null, "%s/%s: skinned" % [id, mi.name])
			tris += _tris(mi.mesh)
		for need: String in ["Body", "Outfit"]:
			assert_has(names, need, "%s: has %s" % [id, need])
		# rigid kit: Gear, and/or the slung gun's own Slung mesh (v1.27; gunman_g's sling is part of its Outfit)
		assert_true(names.has("Gear") or names.has("Slung"), "%s: has Gear or Slung" % id)
		assert_true(tris > 5000 and tris <= TRI_BUDGET, "%s: %d triangles within %d" % [id, tris, TRI_BUDGET])
		var h: float = _height(root)
		assert_true(h >= MIN_HEIGHT and h <= MAX_HEIGHT, "%s: height %.3f m" % [id, h])
		root.queue_free()


func test_materials_resolve_to_the_library() -> void:
	for id: String in GUNMEN:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		for mi: MeshInstance3D in _meshes(root):
			var look: Array[Material] = Layers.look_materials(mi)
			for s: int in range(look.size()):
				var m: Material = look[s]
				assert_true(m != null, "%s/%s surface %d: material" % [id, mi.name, s])
				if m == null:
					continue
				var path: String = m.resource_path
				var ok: bool = path.begins_with(MAT_DIR) and path.ends_with(".tres")
				assert_true(ok and ResourceLoader.exists(path), "%s/%s surface %d: %s" % [id, mi.name, s, path])
		root.queue_free()


## Armed civilians, not police: no uniform, insignia or faction material anywhere.
func test_no_insignia_or_uniform_materials() -> void:
	for id: String in GUNMEN:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		for mat_id: String in _material_ids(root):
			for bad: String in FORBIDDEN_PREFIXES:
				assert_false(mat_id.begins_with(bad), "%s wears %s (uniform/insignia family %s)" % [id, mat_id, bad])
		root.queue_free()


## The 30 m read: every gunman wears the sling; exactly the SLUNG looks carry the slung long gun on the back,
## and it rises above the shoulders.
func test_sling_and_slung_gun() -> void:
	var with_gun: Array[String] = []
	for id: String in GUNMEN:
		var root: Node3D = _instance(id)
		if root == null:
			continue
		var ids: Array[String] = _material_ids(root)
		assert_has(ids, SLING, "%s: sling strap" % id)
		if ids.has(SLUNG_GUN):
			with_gun.append(id)
			# v1.27: the slung gun is its own mesh, Skeleton3D/Slung (ENV A hides it while a sit_* clip plays)
			var gear: MeshInstance3D = root.get_node_or_null("Skeleton3D/Slung") as MeshInstance3D
			assert_true(gear != null, "%s: Skeleton3D/Slung" % id)
			if gear == null:
				root.queue_free()
				continue
			var top: float = -INF
			var back_z: float = -INF
			for v: Vector3 in Layers.material_vertices(gear, MAT_DIR + SLUNG_GUN + ".tres"):
				var p: Vector3 = gear.transform * v
				top = maxf(top, p.y)
				back_z = maxf(back_z, p.z)
			var h: float = _height(root)
			assert_true(top > 0.84 * h, "%s: gun barrel above the shoulders (%.3f of %.3f m)" % [id, top, h])
			assert_true(back_z > 0.1, "%s: slung gun on the back (+Z, %.3f)" % [id, back_z])
		root.queue_free()
	with_gun.sort()
	var want: Array[String] = SLUNG.duplicate()
	want.sort()
	assert_eq(with_gun, want, "the slung gun on exactly %s" % [want])
