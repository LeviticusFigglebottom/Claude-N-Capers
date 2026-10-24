## D1-05 / D1-02: headless character assembly. Owner: ENV D. See game/world/characters/README.md.
##
##   godot --headless --path game --import
##   godot --headless --path game --script res://world/characters/_tools/assemble_characters.gd
##
## 1. Converts the clips of assets/characters/char_anim_humanoid/char_anim_humanoid.glb into the
##    shared AnimationLibrary world/characters/anim_humanoid.res (tracks retargeted to
##    `Skeleton3D:<bone>` relative to the character Root, non-skeleton tracks dropped, loop modes
##    set). Missing glb -> an empty library and a warning.
## 2. For every character glb assets/characters/char_<id>/char_<id>.glb (rule:
##    CharacterSpec.is_excluded), writes world/characters/<id>/<id>.tscn in the contract shape
##    (characters.md v1.1): Root Node3D > Skeleton3D (meshes as children, blend shapes from
##    SOURCE.txt params) + AnimationPlayer (library "humanoid"), and BoneAttachment3D markers
##    HandR/HandL/Head/Back/Hip under Skeleton3D, each with a `Socket` Marker3D child at the attach
##    point. D-067(b): the scene inherits the glb (exported with `remove_armature`, so it imports as
##    Root > Skeleton3D > meshes); meshes and skins stay in the glb, the .tscn only holds overrides
##    and added nodes. A glb without a top-level Skeleton3D is an error. PO6-19: every character also
##    gets the inactive physical-bones ragdoll `Skeleton3D/Ragdoll` (ragdoll_builder.gd, RAGDOLL.md).
## 3. Special characters (P3): SOURCE.txt `extra_markers` add Marker3D nodes (Longshot `LaserOrigin`)
##    and `material_override` sets MeshInstance3D.material_override (Phantom `Goggles`); extra named
##    meshes (Wrecker `Faceplate` / `Visor` / `HeadArmored`) come through as they are.
##    Prop assets (CharacterSpec.PROP_SCENES: the Bulwark shields) become `Shield` AnimatableBody3D
##    scenes with `Collision` + `Visual` (see _assemble_prop).
## 4. D-132 D1 (char_layers.gd): characters with a CrowdLod (minus world/characters/_layers/d1_exclude.json "ids", the
##    per-character fallback; only its "only" ids when listed, D-165: the Afterhours looks) get each mesh node's plain
##    surfaces merged into one surface per texture tier, saved as world/characters/<id>/<id>_<Node>.res and set as
##    that node's mesh (node meta `source_materials` = the original material paths). Run build_char_layers.gd and
##    `godot --import` first (its header has the order); the LOD2 mesh is built from the glb surfaces before the
##    merge. Fallback (per character): add its id to world/characters/_layers/d1_exclude.json {"ids": [...]}, run
##    build_char_layers.gd, `godot --import` and this script: the character gets its glb meshes and materials back
##    (its <id>_<Node>.res files are removed). test_d1_layers.gd checks both states.
## 5. Writes world/characters/characters.json (the index ENV A and the tests read); D2-01 faction
##    variants get `variant_of` + `variant` fields (from SOURCE.txt).
##
## Deterministic: sorted iteration, fixed sub-resource / ext-resource ids and path-derived uids, so
## re-runs produce identical bytes. Exit code 1 on any error.
extends SceneTree

## D-165: the telegraph mesh kept at full detail (see _pin_marks)
const MARKS_NODE: String = "Marks"
const MARKS_LOD_BIAS: float = 64.0
const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const RagdollBuilder: GDScript = preload("res://world/characters/_tools/ragdoll_builder.gd")
const Layers: GDScript = preload("res://world/characters/_tools/char_layers.gd")

var _errors: int = 0
## Override with `-- --anim-glb=res://...` (testing the conversion against another glb).
var _anim_glb: String = Spec.ANIM_GLB
var _hand_sockets: Dictionary = {}
var _layer_index: Dictionary = {}
var _d1_excluded: Array[String] = []
var _d1_only: Array[String] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--anim-glb="):
			_anim_glb = arg.trim_prefix("--anim-glb=")
	var hands: Array = Spec.hand_sockets()
	_hand_sockets = hands[0]
	print("assemble_characters: hand sockets from %s" % hands[1])
	_layer_index = Layers.read_index()
	_d1_excluded = Layers.excluded_ids()
	_d1_only = Layers.only_ids()
	var lib: AnimationLibrary = _build_library()
	var entries: Array[Dictionary] = []
	var props: Array[Dictionary] = []
	var prop_ids: Array[String] = []
	prop_ids.assign(Spec.PROP_SCENES.keys())
	prop_ids.sort()
	for asset_id: String in prop_ids:
		var prop_scene: String = Spec.PROP_SCENES[asset_id]
		if ResourceLoader.exists(_glb(asset_id)) and _assemble_prop(asset_id, prop_scene):
			props.append(_with_variant({"id": Spec.character_id(asset_id), "asset": asset_id, "scene": prop_scene},
				asset_id))
	for asset_id: String in _asset_ids():
		var scene: String = Spec.scene_path(asset_id)
		if _assemble(asset_id, scene, lib):
			entries.append(_with_variant({
				"id": Spec.character_id(asset_id), "asset": asset_id, "scene": scene,
				"test": Spec.TEST_SCENES.has(asset_id),
			}, asset_id))
	_write_index(entries, props)
	print("assemble_characters: %d scene(s), %d prop(s), %d clip(s), %d error(s)" % [
		entries.size(), props.size(), lib.get_animation_list().size(), _errors])
	quit(1 if _errors > 0 else 0)


## D2-01: faction variants carry `variant_of` / `variant` (SOURCE.txt `variant_of` / `visual_variant`).
static func _with_variant(entry: Dictionary, asset_id: String) -> Dictionary:
	var source: Dictionary = Spec.read_source("%s%s/SOURCE.txt" % [Spec.ASSETS_DIR, asset_id])
	if source.has(Spec.VARIANT_OF_KEY) and source.has(Spec.VARIANT_KEY):
		entry["variant_of"] = String(source[Spec.VARIANT_OF_KEY])
		entry["variant"] = String(source[Spec.VARIANT_KEY])
	return entry


func _error(msg: String) -> void:
	_errors += 1
	push_error("assemble_characters: " + msg)


# --------------------------------------------------------------------------------------------
# deterministic ids
# --------------------------------------------------------------------------------------------

## 63-bit uid derived from the resource path (stable across machines and re-runs).
static func _uid_for(path: String) -> int:
	var hi: int = hash("uid:" + path) & 0x7fffffff
	var lo: int = hash(path + ":uid") & 0xffffffff
	return (hi << 32) | lo


func _save(res: Resource, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(res, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		_error("could not save %s (%s)" % [path, error_string(err)])
		return false
	err = ResourceSaver.set_uid(path, _uid_for(path))
	if err != OK:
		_error("could not set uid of %s (%s)" % [path, error_string(err)])
	var uid: int = _uid_for(path)
	if ResourceUID.has_id(uid):
		ResourceUID.set_id(uid, path)
	else:
		ResourceUID.add_id(uid, path)
	return true


# --------------------------------------------------------------------------------------------
# animation library
# --------------------------------------------------------------------------------------------

func _build_library() -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	if not ResourceLoader.exists(_anim_glb):
		push_warning("assemble_characters: %s missing; writing an empty library" % _anim_glb)
		return _save_library(lib)
	var packed: PackedScene = load(_anim_glb) as PackedScene
	if packed == null:
		_error("could not load %s (run godot --import first)" % _anim_glb)
		return _save_library(lib)
	var src: Node = packed.instantiate()
	var loops: Array[String] = Spec.loop_names()
	print("assemble_characters: %d looped clip names from %s" % [loops.size(), Spec.loop_names_source()])
	var players: Array[Node] = src.find_children("*", "AnimationPlayer", true, false)
	players.sort_custom(func(a: Node, b: Node) -> bool: return String(src.get_path_to(a)) < String(src.get_path_to(b)))
	var bones: Array[String] = Spec.contract_bones()
	for node: Node in players:
		var player: AnimationPlayer = node as AnimationPlayer
		var names: Array[String] = []
		for n: StringName in player.get_animation_list():
			names.append(String(n))
		names.sort()
		for full: String in names:
			var clip: String = full.get_slice("/", full.get_slice_count("/") - 1)
			if clip == "RESET" or clip.is_empty() or lib.has_animation(clip):
				continue
			var anim: Animation = _retarget(player.get_animation(full), bones)
			anim.loop_mode = Animation.LOOP_LINEAR if loops.has(clip) else Animation.LOOP_NONE
			anim.resource_name = clip
			anim.resource_local_to_scene = false
			anim.set_scene_unique_id("anim_" + clip)
			lib.add_animation(clip, anim)
	src.free()
	if lib.get_animation_list().is_empty():
		push_warning("assemble_characters: %s has no animations" % _anim_glb)
	return _save_library(lib)


## Saves the library and returns the saved copy, so scenes reference the file instead of embedding it.
func _save_library(lib: AnimationLibrary) -> AnimationLibrary:
	if not _save(lib, Spec.ANIM_LIBRARY_PATH):
		return lib
	var saved: AnimationLibrary = ResourceLoader.load(Spec.ANIM_LIBRARY_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as AnimationLibrary
	return saved if saved != null else lib


## Copy of `src` whose transform tracks target `Skeleton3D:<bone>` (path relative to the Root);
## tracks on anything other than a contract bone are dropped. Bone names are matched with "." and
## "_" treated alike (glTF loaders may sanitise `hand.R` to `hand_R` in track paths).
static func _retarget(src: Animation, bones: Array[String]) -> Animation:
	var by_key: Dictionary = {}
	for b: String in bones:
		by_key[b.replace(".", "_")] = b
	var out: Animation = Animation.new()
	out.length = src.length
	out.step = src.step
	var kept: Array[String] = []
	for t: int in range(src.get_track_count()):
		var tt: Animation.TrackType = src.track_get_type(t)
		if tt != Animation.TYPE_POSITION_3D and tt != Animation.TYPE_ROTATION_3D and tt != Animation.TYPE_SCALE_3D:
			continue
		var path: NodePath = src.track_get_path(t)
		if path.get_subname_count() != 1 or path.get_name_count() == 0:
			continue
		if String(path.get_name(path.get_name_count() - 1)) != "Skeleton3D":
			continue
		var bone: String = by_key.get(String(path.get_subname(0)).replace(".", "_"), "")
		if bone.is_empty():
			continue
		var key: String = "%d:%s" % [tt, bone]
		if kept.has(key):
			continue
		kept.append(key)
		var nt: int = out.add_track(tt)
		out.track_set_path(nt, NodePath("Skeleton3D:" + bone))
		out.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
		out.track_set_interpolation_loop_wrap(nt, src.track_get_interpolation_loop_wrap(t))
		for k: int in range(src.track_get_key_count(t)):
			out.track_insert_key(nt, src.track_get_key_time(t, k), src.track_get_key_value(t, k),
				src.track_get_key_transition(t, k))
	return out


# --------------------------------------------------------------------------------------------
# character scenes
# --------------------------------------------------------------------------------------------

## Asset ids to assemble, sorted: test fixtures plus every non-excluded `char_<id>/char_<id>.glb`.
func _asset_ids() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(Spec.ASSETS_DIR)
	if dir == null:
		_error("no %s" % Spec.ASSETS_DIR)
		return out
	var names: Array[String] = []
	names.assign(dir.get_directories())
	names.sort()
	for asset_id: String in names:
		if Spec.is_excluded(asset_id) and not Spec.TEST_SCENES.has(asset_id):
			continue
		if Spec.is_prop(asset_id):
			continue
		if ResourceLoader.exists(_glb(asset_id)):
			out.append(asset_id)
	return out


static func _glb(asset_id: String) -> String:
	return "%s%s/%s.glb" % [Spec.ASSETS_DIR, asset_id, asset_id]


## D-067(b): the scene INHERITS the glb (`[node name="<Root>" instance=ExtResource("1_glb")]`), so the
## meshes and skins stay in the imported glb and the .tscn only holds the differences: the root name,
## blend shape values, material overrides and the added nodes (markers, extra markers,
## AnimationPlayer). The glb must be exported with `remove_armature` (EXPORT in the Blender script)
## so it imports as `<root> > Skeleton3D > meshes`, which is already the contract shape.
func _assemble(asset_id: String, scene_path: String, lib: AnimationLibrary) -> bool:
	var packed: PackedScene = load(_glb(asset_id)) as PackedScene
	if packed == null:
		_error("could not load %s (run godot --import first)" % _glb(asset_id))
		return false
	var root: Node3D = _inherited_root(asset_id, scene_path)
	if root == null:
		return false
	var skel: Skeleton3D = root.get_node_or_null(^"Skeleton3D") as Skeleton3D
	if skel == null:
		_error("%s has no top-level Skeleton3D: rebuild it with EXPORT remove_armature (D-067b)" % asset_id)
		root.free()
		return false
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if not skel.is_ancestor_of(n):
			_error("%s: mesh %s is not under Skeleton3D (parent every mesh to the armature)" % [
				asset_id, root.get_path_to(n)])
	var source: Dictionary = Spec.read_source("%s%s/SOURCE.txt" % [Spec.ASSETS_DIR, asset_id])
	root.name = Spec.root_name(Spec.character_id(asset_id))
	_apply_blend_shapes(skel, source, asset_id)
	_add_markers(skel, source, asset_id)
	_add_extra_markers(skel, source, asset_id)
	_apply_overrides(skel, source, asset_id, scene_path)
	_pin_marks(skel)
	_apply_headwear_class(skel, source, asset_id)
	var switch_m: float = _add_crowd_lod(skel, source, asset_id, scene_path)
	_merge_layers(skel, asset_id, scene_path, switch_m)
	_add_ragdoll(skel, asset_id)
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(Spec.ANIM_LIBRARY_NAME, lib)
	lib.set_id_for_path(scene_path, "1_anim")
	packed.set_id_for_path(scene_path, "1_glb")
	_own_new(root, root)
	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	root.free()
	if err != OK:
		_error("could not pack %s (%s)" % [scene_path, error_string(err)])
		return false
	_fix_node_ids(scene, scene_path)
	# The glb's imported node ids are random per import: never save references to them.
	var bundle: Dictionary = scene._get_bundled_scene()
	bundle.erase("id_paths")
	scene._set_bundled_scene(bundle)
	return _save(scene, scene_path)


## There is no scripted setter for a node's inherited state: write a one-line inherited stub to
## `scene_path`, load it uncached and instantiate it with GEN_EDIT_STATE_MAIN (the editor's own
## path), so pack() writes an inherited scene. The stub is overwritten by the real scene.
func _inherited_root(asset_id: String, scene_path: String) -> Node3D:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scene_path.get_base_dir()))
	var f: FileAccess = FileAccess.open(scene_path, FileAccess.WRITE)
	if f == null:
		_error("could not write %s" % scene_path)
		return null
	f.store_string("[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_glb\"]\n\n" % _glb(asset_id))
	f.store_string("[node name=\"Root\" instance=ExtResource(\"1_glb\")]\n")
	f.close()
	var stub: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if stub == null:
		_error("could not load the inherited stub %s" % scene_path)
		return null
	var node: Node = stub.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not node is Node3D:
		_error("%s: the glb root is not a Node3D" % asset_id)
		if node != null:
			node.free()
		return null
	return node as Node3D


## Owner = root for the nodes added on top of the inherited glb (the inherited ones are owned already).
static func _own_new(n: Node, owner_node: Node) -> void:
	for c: Node in n.get_children():
		if c.owner == null:
			c.owner = owner_node
		_own_new(c, owner_node)


## Node unique ids (`unique_id=` in the .tscn) are random per pack; derive them from the node path.
static func _fix_node_ids(scene: PackedScene, scene_path: String) -> void:
	var bundle: Dictionary = scene._get_bundled_scene()
	if not bundle.has("node_ids"):
		return
	var state: SceneState = scene.get_state()
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in range(state.get_node_count()):
		ids.append((hash(scene_path + "|" + String(state.get_node_path(i))) & 0x3fffffff) + 1)
	bundle["node_ids"] = ids
	scene._set_bundled_scene(bundle)


## Transform of `n` relative to `src` (the instanced glb root), without needing the tree.
static func _rel_xform(src: Node, n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != src and cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Godot ignores glTF default morph weights, so the variant's params (SOURCE.txt `params:`) are
## written onto every MeshInstance3D that has blend shapes of those names.
func _apply_blend_shapes(skel: Skeleton3D, source: Dictionary, asset_id: String) -> void:
	var params: Dictionary = {}
	if source.has("params"):
		var parsed: Variant = JSON.parse_string(String(source["params"]))
		if parsed is Dictionary:
			params = parsed
	for mi: MeshInstance3D in _meshes(skel):
		if mi.mesh == null:
			continue
		for i: int in range(mi.mesh.get_blend_shape_count()):
			var key: String = String(mi.mesh.get_blend_shape_name(i))
			if params.has(key) and (params[key] is float or params[key] is int):
				mi.set_blend_shape_value(i, float(params[key]))
			else:
				push_warning("assemble_characters: %s %s blend shape '%s' has no param; left at 0" % [
					asset_id, mi.name, key])


static func _meshes(skel: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in skel.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _add_markers(skel: Skeleton3D, source: Dictionary, asset_id: String) -> void:
	var head: int = skel.find_bone("head")
	var k: float = 1.0
	if head >= 0:
		k = skel.get_bone_global_rest(head).origin.y / Spec.DEFAULT_HEAD_Y
	var names: Array[String] = []
	names.assign(Spec.MARKERS.keys())
	names.sort()
	for marker: String in names:
		var bone_name: String = Spec.MARKERS[marker]
		var bone: int = skel.find_bone(bone_name)
		if bone < 0:
			_error("%s has no bone %s for %s" % [asset_id, bone_name, marker])
			continue
		var att: BoneAttachment3D = BoneAttachment3D.new()
		att.name = marker
		skel.add_child(att)
		att.bone_name = bone_name
		var rest: Transform3D = skel.get_bone_global_rest(bone)
		att.transform = rest
		var local: Transform3D
		if _hand_sockets.has(marker):
			var h: Transform3D = _hand_sockets[marker]
			local = Transform3D(h.basis, h.origin * k)
		else:
			var point: Vector3 = (Spec.SOCKET_POINTS[marker] as Vector3) * k
			local = Transform3D(Spec.socket_basis(rest.basis, marker), rest.affine_inverse() * point)
		var key: String = Spec.SOURCE_KEYS[marker]
		if source.has(key):
			var v: Variant = JSON.parse_string(String(source[key]))
			if v is Array and (v as Array).size() == 3:
				local.origin = rest.affine_inverse() * Vector3(float(v[0]), float(v[1]), float(v[2]))
			else:
				_error("%s SOURCE.txt %s is not [x, y, z]" % [asset_id, key])
		elif source.has(Spec.SEAT_PREFIX + marker):
			var seat: Variant = Spec.parse_seat(String(source[Spec.SEAT_PREFIX + marker]))
			if seat is Vector3:
				local.origin = rest.affine_inverse() * (seat as Vector3)
			else:
				_error("%s SOURCE.txt %s%s has no (model [x, y, z] ...)" % [asset_id, Spec.SEAT_PREFIX, marker])
		if Spec.SOCKET_OFFSETS.has(marker):   # D-116: Back/Socket = the carried bag's pivot, off the measured seat
			local.origin += rest.basis.inverse() * ((Spec.SOCKET_OFFSETS[marker] as Vector3) * k)
		var socket: Marker3D = Marker3D.new()
		socket.name = Spec.SOCKET_NAME
		socket.transform = _rounded(local)
		att.add_child(socket)


## D-165: a `Marks` mesh (the Corpsman's medic marks, char_specials.py) is a gameplay telegraph: a high lod_bias keeps
## it at full detail where the renderer's automatic LODs ate the white plus from 20 m on (a few hundred tris).
func _pin_marks(skel: Skeleton3D) -> void:
	var mi: MeshInstance3D = skel.get_node_or_null(NodePath(MARKS_NODE)) as MeshInstance3D
	if mi != null:
		mi.lod_bias = MARKS_LOD_BIAS


## SOURCE.txt `extra_markers`: Marker3D nodes under existing nodes of the skeleton (e.g. the Longshot's
## `LaserOrigin` under `HandR/Socket`), origin in the parent's space, identity basis.
func _add_extra_markers(skel: Skeleton3D, source: Dictionary, asset_id: String) -> void:
	if not source.has(Spec.EXTRA_MARKERS_KEY):
		return
	var data: Variant = JSON.parse_string(String(source[Spec.EXTRA_MARKERS_KEY]))
	if not data is Array:
		_error("%s SOURCE.txt %s is not a JSON array" % [asset_id, Spec.EXTRA_MARKERS_KEY])
		return
	for e: Variant in data:
		if not e is Dictionary:
			_error("%s: bad %s entry" % [asset_id, Spec.EXTRA_MARKERS_KEY])
			continue
		var d: Dictionary = e
		var parent: Node = skel.get_node_or_null(NodePath(String(d.get("parent", ""))))
		var org: Variant = d.get("origin", [])
		if parent == null or not org is Array or (org as Array).size() != 3:
			_error("%s: %s needs an existing parent and origin [x, y, z]" % [asset_id, d.get("name", "?")])
			continue
		var marker: Marker3D = Marker3D.new()
		marker.name = String(d.get("name", "Marker"))
		marker.transform = _rounded(Transform3D(Basis.IDENTITY, Vector3(float(org[0]), float(org[1]), float(org[2]))))
		parent.add_child(marker)


## SOURCE.txt `headwear_class` -> meta `headwear_class` (StringName) on Skeleton3D/Headwear (lead 2026-10-16: ENV A's
## HardHatHandLift lifts the hands of hard-hat rigs in surrender / cower).
func _apply_headwear_class(skel: Skeleton3D, source: Dictionary, asset_id: String) -> void:
	if not source.has(Spec.HEADWEAR_CLASS_KEY):
		return
	var hw: Node = skel.get_node_or_null(^"Headwear")
	if hw == null:
		_error("%s SOURCE.txt %s but no Skeleton3D/Headwear" % [asset_id, Spec.HEADWEAR_CLASS_KEY])
		return
	hw.set_meta(&"headwear_class", StringName(String(source[Spec.HEADWEAR_CLASS_KEY])))


## SOURCE.txt `material_override`: {mesh node name: material path} -> material_override (the Phantom's
## `Goggles` get the emissive library material, which ENV A duplicates per instance and ramps).
## The ext-resource id is fixed (`2_<material file>`): the saver would otherwise pick a random one.
func _apply_overrides(skel: Skeleton3D, source: Dictionary, asset_id: String, scene_path: String) -> void:
	if not source.has(Spec.OVERRIDE_KEY):
		return
	var data: Variant = JSON.parse_string(String(source[Spec.OVERRIDE_KEY]))
	if not data is Dictionary:
		_error("%s SOURCE.txt %s is not a JSON object" % [asset_id, Spec.OVERRIDE_KEY])
		return
	var names: Array = (data as Dictionary).keys()
	names.sort()
	for nm: Variant in names:
		var mi: MeshInstance3D = skel.get_node_or_null(NodePath(String(nm))) as MeshInstance3D
		var mat: Material = load(String(data[nm])) as Material
		if mi == null or mat == null:
			_error("%s: material_override %s -> %s unresolved" % [asset_id, nm, data[nm]])
			continue
		mat.set_id_for_path(scene_path, "2_" + mat.resource_path.get_file().get_basename())
		mi.material_override = mat


## D4-01: LOD2 (CrowdLod.gd): `Skeleton3D/CrowdLod`, one merged skinned surface saved as <scene>_lod.res,
## visible from the switch distance on; the glb meshes get the matching visibility_range_end. LOD1 is
## Godot's automatic mesh LOD (import option), so the existing nodes keep their paths and meshes.
## Returns the switch distance (0.0 = no LOD2).
func _add_crowd_lod(skel: Skeleton3D, source: Dictionary, asset_id: String, scene_path: String) -> float:
	var meshes: Array[MeshInstance3D] = CrowdLod.source_meshes(skel)
	var names: Array[String] = []
	for mi: MeshInstance3D in meshes:
		names.append(String(mi.name))
	var switch_m: float = CrowdLod.switch_m(source, names)
	var mesh_path: String = "%s_lod.res" % scene_path.get_basename()
	if switch_m <= 0.0 or meshes.is_empty():
		if FileAccess.file_exists(mesh_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(mesh_path))
		return 0.0
	var mesh: ArrayMesh = CrowdLod.build_mesh(meshes)
	if mesh == null:
		_error("%s: no surface qualifies for the LOD2 mesh" % asset_id)
		return 0.0
	if not _save(mesh, mesh_path):
		return 0.0
	var saved: Mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Mesh
	saved.set_id_for_path(scene_path, "3_lod")
	var skin: Skin = meshes[0].skin.duplicate() if meshes[0].skin != null else null
	for mi: MeshInstance3D in meshes:
		mi.visibility_range_end = switch_m
		mi.visibility_range_end_margin = CrowdLod.MARGIN_M
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var lod: MeshInstance3D = MeshInstance3D.new()
	lod.name = CrowdLod.NODE_NAME
	var proxy_script: Script = load("res://world/characters/_tools/crowd_lod_proxy.gd") as Script
	proxy_script.set_id_for_path(scene_path, "3_proxy")   # a fixed ext-resource id (else random per run)
	lod.set_script(proxy_script)
	lod.mesh = saved
	if skin != null:
		skin.resource_path = ""
		skin.set_scene_unique_id("skin_lod")
		lod.skin = skin
	lod.visibility_range_begin = switch_m
	lod.visibility_range_begin_margin = CrowdLod.MARGIN_M
	lod.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	lod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # D-146 (crowd_lod_proxy.gd also sets it)
	lod.add_to_group(CrowdLod.GROUP, true)
	skel.add_child(lod)
	lod.skeleton = NodePath("..")
	return switch_m


## D-132 D1 (char_layers.gd): each mesh node's plain surfaces merged per texture tier into
## <scene dir>/<id>_<Node>.res, set as the node's mesh, with meta `source_materials`. Not merged (no CrowdLod, or
## listed in d1_exclude.json): stale merged meshes are removed and the glb meshes stay.
func _merge_layers(skel: Skeleton3D, asset_id: String, scene_path: String, switch_m: float) -> void:
	var merge: bool = Layers.is_merged(Spec.character_id(asset_id), switch_m, _d1_excluded, _d1_only)
	if merge and _layer_index.is_empty():
		_error("%s: %s missing (run build_char_layers.gd and godot --import first)" % [asset_id, Layers.INDEX_PATH])
		merge = false
	for mi: MeshInstance3D in CrowdLod.source_meshes(skel):
		var mesh_path: String = "%s_%s.res" % [scene_path.get_basename(), mi.name]
		var merged: ArrayMesh = null
		if merge:
			var errors: Array[String] = []
			merged = Layers.merge_mesh(mi, _layer_index, errors)
			for msg: String in errors:
				_error("%s: %s" % [asset_id, msg])
		if merged == null:
			if FileAccess.file_exists(mesh_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(mesh_path))
			continue
		var paths: Array[String] = []
		for si: int in range(mi.mesh.get_surface_count()):
			paths.append(Layers.surface_material(mi, si).resource_path)
		if not _save(merged, mesh_path):
			continue
		var saved: Mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Mesh
		saved.set_id_for_path(scene_path, "4_%s" % mi.name)
		mi.mesh = saved
		mi.set_meta(Layers.META_SOURCE, paths)


## PO6-19: the inactive physical-bones ragdoll `Skeleton3D/Ragdoll` (ragdoll_builder.gd, RAGDOLL.md).
func _add_ragdoll(skel: Skeleton3D, asset_id: String) -> void:
	var errors: Array[String] = []
	var sim: PhysicalBoneSimulator3D = RagdollBuilder.build(skel, errors)
	for msg: String in errors:
		_error("%s: %s" % [asset_id, msg])
	skel.add_child(sim)


# --------------------------------------------------------------------------------------------
# props (Bulwark shields)
# --------------------------------------------------------------------------------------------

## `Shield` AnimatableBody3D (world_dynamic layer, no script: ENV A owns the behaviour) with the
## glb's convex hull as `Collision` and its mesh as `Visual` (saved as <scene>_visual.res). The glb's
## origin (the grip, -Z = shield face) is the scene origin.
func _assemble_prop(asset_id: String, scene_path: String) -> bool:
	var packed: PackedScene = load(_glb(asset_id)) as PackedScene
	if packed == null:
		_error("could not load %s (run godot --import first)" % _glb(asset_id))
		return false
	var src: Node = packed.instantiate()
	var mesh_node: MeshInstance3D = null
	for n: Node in src.find_children("*", "MeshInstance3D", true, false):
		if mesh_node == null or String(n.name) == "Visual":
			mesh_node = n as MeshInstance3D
	var shape_node: CollisionShape3D = null
	for n: Node in src.find_children("*", "CollisionShape3D", true, false):
		shape_node = n as CollisionShape3D
		break
	if mesh_node == null or shape_node == null or shape_node.shape == null:
		_error("%s needs a mesh and a convex Collision" % asset_id)
		src.free()
		return false
	var root: AnimatableBody3D = AnimatableBody3D.new()
	root.name = "Shield"
	root.collision_layer = Spec.SHIELD_LAYER
	root.collision_mask = 0
	root.sync_to_physics = false
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	var shape: Shape3D = shape_node.shape.duplicate()
	shape.resource_path = ""
	shape.set_scene_unique_id("collision_shape")
	col.shape = shape
	col.transform = _rounded(_rel_xform(src, shape_node))
	root.add_child(col)
	var vis: MeshInstance3D = MeshInstance3D.new()
	vis.name = "Visual"
	vis.transform = _rounded(_rel_xform(src, mesh_node))
	vis.mesh = mesh_node.mesh
	root.add_child(vis)
	src.free()
	var mesh: Mesh = vis.mesh
	for s2: int in range(mesh.get_surface_count()):
		var mat: Material = mesh.surface_get_material(s2)
		if mat != null and (mat.resource_path.is_empty() or mat.resource_path.contains("::")):
			mat.set_scene_unique_id("mat_%d" % s2)
	var am: ArrayMesh = mesh as ArrayMesh
	if am != null and am.shadow_mesh != null:
		am.shadow_mesh.set_scene_unique_id("shadow")
	var mesh_path: String = "%s_visual.res" % scene_path.get_basename()
	if not _save(mesh, mesh_path):
		root.free()
		return false
	var saved: Mesh = load(mesh_path) as Mesh
	saved.set_id_for_path(scene_path, "mesh_visual")
	vis.mesh = saved
	_own(root, root)
	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	root.free()
	if err != OK:
		_error("could not pack %s (%s)" % [scene_path, error_string(err)])
		return false
	_fix_node_ids(scene, scene_path)
	return _save(scene, scene_path)


## Rounds to 0.1 mm / 1e-5 so float noise never changes the saved text.
static func _rounded(t: Transform3D) -> Transform3D:
	var b: Basis = t.basis
	return Transform3D(
		Basis(b.x.snappedf(0.00001), b.y.snappedf(0.00001), b.z.snappedf(0.00001)),
		t.origin.snappedf(0.0001))


static func _own(n: Node, owner_node: Node) -> void:
	for c: Node in n.get_children():
		c.owner = owner_node
		c.scene_file_path = ""
		_own(c, owner_node)


func _write_index(entries: Array[Dictionary], props: Array[Dictionary] = []) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["scene"]) < String(b["scene"]))
	var data: Dictionary = {
		"_doc": "Generated by world/characters/_tools/assemble_characters.gd; do not edit. " +
			"Scenes follow docs/contracts/characters.md v1.1. test=true entries are fixtures, not cast.",
		"version": 1,
		"anim_library": Spec.ANIM_LIBRARY_PATH,
		"characters": entries,
	}
	if not props.is_empty():
		props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["scene"]) < String(b["scene"]))
		data["props"] = props
	var f: FileAccess = FileAccess.open(Spec.INDEX_PATH, FileAccess.WRITE)
	if f == null:
		_error("could not write %s" % Spec.INDEX_PATH)
		return
	f.store_string(JSON.stringify(data, "\t", true) + "\n")
	f.close()
