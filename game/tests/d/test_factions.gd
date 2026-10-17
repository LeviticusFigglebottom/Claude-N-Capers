## D2-01: law-enforcement faction reskins (tools/blender/characters/_faction.py). For every base character
## and `visual_variant` frd | sentinel | zero (EnemyDef.params.visual_variant, groups.md QA-29) the scene
## world/characters/<id>_<variant>/<id>_<variant>.tscn exists, is indexed in characters.json with
## `variant_of` / `variant`, follows the character contract (Skeleton3D, AnimationPlayer "humanoid",
## markers + Socket; the full contract is checked for every indexed scene by test_scenes.gd), stays in the
## tri budget, resolves every surface to a library material, wears its faction's colours and keeps the
## special nodes (Wrecker Faceplate / Visor / HeadArmored, Phantom Goggles + override, Longshot
## LaserOrigin, a Bulwark shield scene per variant).
## D-067: the FRD field agent (`enemy.frd_agent`, FRD-only: base scene `frd_agent` = the FRD look, `frd_agent_b` a
## second body, `frd_agent_sentinel` the Sentinel reskin) follows the same contract, and the Zero Phantom /
## Longshot carry the Zero identity (bone skull mask, oxblood accents) on top of their special nodes.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const Layers: GDScript = preload("res://world/characters/_tools/char_layers.gd")
const BASES: Array[String] = [
	"patrol_officer", "tac_light", "tac_heavy", "phantom", "stinger", "bulwark", "wrecker", "longshot", "corpsman",
]
const VARIANTS: Array[String] = ["frd", "sentinel", "zero"]
const PREFIX: Dictionary = {"frd": "char_frd_", "sentinel": "char_sen_", "zero": "char_zero_"}
const TRI_BUDGET: int = 35000
const GOGGLE_MAT: String = "res://world/materials/char_goggle_glow.tres"
const HAZARD_MAT: String = "res://world/materials/char_hazard_yellow.tres"
const ENEMY_DIR: String = "res://systems/ai/data/enemies/"
const AGENTS: Array[String] = ["frd_agent", "frd_agent_b"]
const MAT_DIR: String = "res://world/materials/"

var _by_scene: Dictionary = {}


func before_all() -> void:
	for e: Dictionary in Spec.read_index():
		_by_scene[String(e["scene"])] = e


func _instance(path: String) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		fail("could not load %s (run tools/blender/characters/assemble.sh)" % path)
		return null
	var node: Node3D = packed.instantiate() as Node3D
	add_child(node)
	return node


static func _tris(mesh: Mesh) -> int:
	var n: int = 0
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


static func _materials(root: Node) -> Array[String]:
	var out: Array[String] = []
	var nodes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)
	for n: Node in nodes:
		var mi: MeshInstance3D = n as MeshInstance3D
		var look: Array[Material] = Layers.look_materials(mi, false)
		for s: int in range(look.size()):
			var m: Material = look[s]
			out.append(m.resource_path if m != null else "<null>")
	return out


func test_every_variant_is_indexed() -> void:
	for base: String in BASES:
		for v: String in VARIANTS:
			var path: String = Spec.variant_scene_path(base, v)
			assert_eq(path, "res://world/characters/%s_%s/%s_%s.tscn" % [base, v, base, v], "convention")
			assert_true(_by_scene.has(path), "characters.json lists %s" % path)
			if _by_scene.has(path):
				var e: Dictionary = _by_scene[path]
				assert_eq(String(e.get("variant_of", "")), base, "%s variant_of" % path)
				assert_eq(String(e.get("variant", "")), v, "%s variant" % path)
				assert_false(bool(e["test"]), "%s is cast" % path)
		assert_eq(Spec.variant_scene_path(base, "tac"), Spec.variant_scene_path(base, ""), "tac = base look")
		assert_true(_by_scene.has(Spec.variant_scene_path(base, "tac")), "base %s still indexed" % base)


func test_variants_follow_the_contract() -> void:
	for base: String in BASES:
		for v: String in VARIANTS:
			var path: String = Spec.variant_scene_path(base, v)
			var root: Node3D = _instance(path)
			if root == null:
				continue
			assert_eq(String(root.name), Spec.root_name("%s_%s" % [base, v]), "%s root name" % path)
			var skel: Skeleton3D = root.get_node_or_null("Skeleton3D") as Skeleton3D
			assert_true(skel != null, "%s: Skeleton3D" % path)
			var player: AnimationPlayer = root.get_node_or_null("AnimationPlayer") as AnimationPlayer
			assert_true(player != null and player.has_animation_library(Spec.ANIM_LIBRARY_NAME), "%s: humanoid library" % path)
			for marker: String in Spec.MARKERS:
				assert_true(root.get_node_or_null("Skeleton3D/%s/%s" % [marker, Spec.SOCKET_NAME]) is Marker3D,
					"%s: %s/Socket" % [path, marker])
			var tris: int = 0
			for n: Node in root.find_children("*", "MeshInstance3D", true, false):
				if String(n.name) == "CrowdLod":  # D4-01 LOD2 proxy (test_lod.gd)
					continue
				tris += _tris((n as MeshInstance3D).mesh)
				assert_true((n as MeshInstance3D).skin != null, "%s/%s skinned" % [path, n.name])
			assert_true(tris <= TRI_BUDGET, "%s: %d triangles within %d" % [path, tris, TRI_BUDGET])
			var mats: Array[String] = _materials(root)
			var faction_mats: int = 0
			for m: String in mats:
				assert_true(m.begins_with("res://world/materials/") and m.ends_with(".tres") and ResourceLoader.exists(m),
					"%s: material %s resolves" % [path, m])
				if m.get_file().begins_with(PREFIX[v]):
					faction_mats += 1
				# the base TAC / police colours are fully replaced
				assert_false(m.get_file() in ["char_tac_charcoal.tres", "char_tac_gear.tres", "char_police_navy.tres",
					"char_hivis.tres"], "%s: base colour %s remapped" % [path, m])
			assert_true(faction_mats >= 2, "%s wears %s colours (%d surfaces)" % [path, v, faction_mats])
			root.queue_free()


## Contract + budget + material checks shared by the agent scenes; returns the scene's material files.
func _check_scene(path: String, id: String) -> Array[String]:
	var files: Array[String] = []
	var root: Node3D = _instance(path)
	if root == null:
		return files
	assert_eq(String(root.name), Spec.root_name(id), "%s root name" % path)
	assert_true(root.get_node_or_null("Skeleton3D") is Skeleton3D, "%s: Skeleton3D" % path)
	var player: AnimationPlayer = root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	assert_true(player != null and player.has_animation_library(Spec.ANIM_LIBRARY_NAME), "%s: humanoid library" % path)
	for marker: String in Spec.MARKERS:
		assert_true(root.get_node_or_null("Skeleton3D/%s/%s" % [marker, Spec.SOCKET_NAME]) is Marker3D,
			"%s: %s/Socket" % [path, marker])
	var tris: int = 0
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if String(n.name) == "CrowdLod":  # D4-01 LOD2 proxy (test_lod.gd)
			continue
		tris += _tris((n as MeshInstance3D).mesh)
		assert_true((n as MeshInstance3D).skin != null, "%s/%s skinned" % [path, n.name])
	assert_true(tris <= TRI_BUDGET, "%s: %d triangles within %d" % [path, tris, TRI_BUDGET])
	for m: String in _materials(root):
		assert_true(m.begins_with(MAT_DIR) and ResourceLoader.exists(m), "%s: material %s resolves" % [path, m])
		files.append(m.get_file())
	root.queue_free()
	return files


func test_frd_agent() -> void:
	for id: String in AGENTS:
		var path: String = Spec.variant_scene_path(id, "")
		assert_true(_by_scene.has(path), "characters.json lists %s" % path)
		if _by_scene.has(path):
			assert_false(bool(_by_scene[path]["test"]), "%s is cast" % path)
			assert_eq(String(_by_scene[path].get("variant", "")), "", "%s is a base scene (the FRD look)" % path)
		var files: Array[String] = _check_scene(path, id)
		assert_has(files, "char_frd_navy.tres", "%s: navy FRD windbreaker" % path)
		assert_has(files, "char_frd_yellow.tres", "%s: gold FRD lettering" % path)
		for f: String in ["char_tac_charcoal.tres", "char_tac_helmet.tres", "char_police_navy.tres", "char_hivis.tres"]:
			assert_false(f in files, "%s: no patrol / TAC kit (%s)" % [path, f])
	# the Sentinel Corp reskin of the role (sentinel/frd_agent.tres visual_variant)
	var sen: String = Spec.variant_scene_path("frd_agent", "sentinel")
	assert_true(_by_scene.has(sen), "characters.json lists %s" % sen)
	if _by_scene.has(sen):
		assert_eq(String(_by_scene[sen].get("variant_of", "")), "frd_agent", "%s variant_of" % sen)
		assert_eq(String(_by_scene[sen].get("variant", "")), "sentinel", "%s variant" % sen)
	var sf: Array[String] = _check_scene(sen, "frd_agent_sentinel")
	assert_has(sf, "char_sen_grey.tres", "%s: Sentinel grey windbreaker" % sen)
	assert_has(sf, "char_sen_red.tres", "%s: Sentinel logo" % sen)
	assert_false("char_frd_yellow.tres" in sf, "%s: no FRD lettering" % sen)


## Zero Phantom / Longshot read as Zero: bone skull mask + oxblood accents, special nodes kept.
func test_zero_identity() -> void:
	for role: String in ["phantom", "longshot"]:
		var path: String = Spec.variant_scene_path(role, "zero")
		var root: Node3D = _instance(path)
		if root == null:
			continue
		var head: MeshInstance3D = root.get_node_or_null("Skeleton3D/Headwear") as MeshInstance3D
		assert_true(head != null, "%s: Headwear" % path)
		if head != null:
			assert_has(_materials(head), MAT_DIR + "char_zero_bone.tres", "%s: bone skull mask" % path)
		var files: Array[String] = []
		for m: String in _materials(root):
			files.append(m.get_file())
		assert_has(files, "char_zero_red.tres", "%s: oxblood accents" % path)
		assert_false("char_sniper_drab.tres" in files or "char_phantom_suit.tres" in files, "%s: dark Zero kit" % path)
		if role == "phantom":
			var gog: MeshInstance3D = root.get_node_or_null("Skeleton3D/Goggles") as MeshInstance3D
			assert_true(gog != null and gog.material_override != null and gog.material_override.resource_path == GOGGLE_MAT,
				"%s: glowing Goggles kept" % path)
		else:
			assert_true(root.get_node_or_null("Skeleton3D/HandR/Socket/LaserOrigin") is Marker3D, "%s: LaserOrigin" % path)
		root.queue_free()


func test_special_nodes_survive_every_variant() -> void:
	for v: String in VARIANTS:
		var w: Node3D = _instance(Spec.variant_scene_path("wrecker", v))
		if w != null:
			for nm: String in ["Faceplate", "Visor", "HeadArmored"]:
				var mi: MeshInstance3D = w.get_node_or_null("Skeleton3D/" + nm) as MeshInstance3D
				assert_true(mi != null and mi.skin != null and mi.mesh != null, "wrecker_%s: skinned %s" % [v, nm])
			var face: MeshInstance3D = w.get_node_or_null("Skeleton3D/Faceplate") as MeshInstance3D
			if face != null:
				assert_has(_materials(face), HAZARD_MAT, "wrecker_%s: Faceplate keeps the hazard rim" % v)
				assert_true(face.get_aabb().position.z < (w.get_node("Skeleton3D/Visor") as MeshInstance3D).get_aabb().position.z,
					"wrecker_%s: Faceplate in front of the Visor" % v)
			w.queue_free()
		var p: Node3D = _instance(Spec.variant_scene_path("phantom", v))
		if p != null:
			var gog: MeshInstance3D = p.get_node_or_null("Skeleton3D/Goggles") as MeshInstance3D
			assert_true(gog != null and gog.material_override != null, "phantom_%s: Goggles with override" % v)
			if gog != null and gog.material_override != null:
				assert_eq(gog.material_override.resource_path, GOGGLE_MAT, "phantom_%s: goggle glow material" % v)
			p.queue_free()
		var l: Node3D = _instance(Spec.variant_scene_path("longshot", v))
		if l != null:
			assert_true(l.get_node_or_null("Skeleton3D/HandR/Socket/LaserOrigin") is Marker3D, "longshot_%s: LaserOrigin" % v)
			l.queue_free()


func test_bulwark_shield_per_variant() -> void:
	var listed: Dictionary = {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(Spec.INDEX_PATH))
	if data is Dictionary:
		for e: Variant in (data as Dictionary).get("props", []):
			listed[String((e as Dictionary)["scene"])] = e
	for v: String in VARIANTS:
		var path: String = "res://world/characters/bulwark_%s/bulwark_%s_shield.tscn" % [v, v]
		assert_eq(Spec.PROP_SCENES.get("char_bulwark_%s_shield" % v, ""), path, "shield %s in PROP_SCENES" % v)
		assert_true(listed.has(path), "characters.json props list %s" % path)
		if listed.has(path):
			assert_eq(String(listed[path].get("variant_of", "")), "bulwark_shield", "%s variant_of" % path)
			assert_eq(String(listed[path].get("variant", "")), v, "%s variant" % path)
		var packed: PackedScene = load(path) as PackedScene
		assert_true(packed != null, "%s loads" % path)
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		assert_true(root is AnimatableBody3D and String(root.name) == "Shield", "%s: Shield AnimatableBody3D" % path)
		var col: CollisionShape3D = root.get_node_or_null("Collision") as CollisionShape3D
		assert_true(col != null and col.shape is ConvexPolygonShape3D, "%s: convex Collision" % path)
		var vis: MeshInstance3D = root.get_node_or_null("Visual") as MeshInstance3D
		assert_true(vis != null and vis.mesh != null, "%s: Visual" % path)
		if vis != null and vis.mesh != null:
			var b: AABB = vis.get_aabb()
			assert_true(b.size.y > 1.0 and b.size.y < 1.2 and b.position.z < -0.07, "%s: same shape as the base shield" % path)
			var faction_mats: int = 0
			for m: String in _materials(root):
				assert_true(ResourceLoader.exists(m), "%s: material %s" % [path, m])
				if m.get_file().begins_with(PREFIX[v]):
					faction_mats += 1
			assert_true(faction_mats >= 2, "%s recoloured" % path)
		root.free()


## Every EnemyDef with params.visual_variant whose role has a character resolves to an existing scene.
func test_enemy_defs_resolve() -> void:
	var checked: int = 0
	for f: String in _tres_files(ENEMY_DIR):
		var def: Resource = load(f)
		if def == null or not "params" in def:
			continue
		var params: Dictionary = def.get("params")
		var variant: String = String(params.get("visual_variant", ""))
		var role: String = String(def.get("id")).trim_prefix("enemy.")
		if variant.is_empty() or not ResourceLoader.exists(Spec.variant_scene_path(role, "")):
			continue
		var path: String = Spec.variant_scene_path(role, variant)
		assert_true(ResourceLoader.exists(path), "%s (%s) -> %s" % [f, variant, path])
		checked += 1
	assert_true(checked > 0, "at least one faction EnemyDef resolved")


static func _tres_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(".tres"):
			out.append(dir_path.path_join(f))
	for d: String in dir.get_directories():
		out.append_array(_tres_files(dir_path.path_join(d)))
	out.sort()
	return out
