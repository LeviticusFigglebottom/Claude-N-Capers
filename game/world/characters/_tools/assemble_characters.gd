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
##    CharacterSpec.is_excluded) with a Skeleton3D, writes world/characters/<id>/<id>.tscn in the
##    contract shape (characters.md v1.1): Root Node3D > Skeleton3D (meshes as children, blend
##    shapes from SOURCE.txt params) + AnimationPlayer (library "humanoid"), and BoneAttachment3D
##    markers HandR/HandL/Head/Back/Hip under Skeleton3D, each with a `Socket` Marker3D child at
##    the attach point. Meshes are saved next to the scene as binary <scene>_<node>.res.
## 3. Writes world/characters/characters.json (the index ENV A and the tests read).
##
## Deterministic: sorted iteration, fixed sub-resource / ext-resource ids and path-derived uids, so
## re-runs produce identical bytes. Exit code 1 on any error.
extends SceneTree

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")

var _errors: int = 0
## Override with `-- --anim-glb=res://...` (testing the conversion against another glb).
var _anim_glb: String = Spec.ANIM_GLB
var _hand_sockets: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--anim-glb="):
			_anim_glb = arg.trim_prefix("--anim-glb=")
	var hands: Array = Spec.hand_sockets()
	_hand_sockets = hands[0]
	print("assemble_characters: hand sockets from %s" % hands[1])
	var lib: AnimationLibrary = _build_library()
	var entries: Array[Dictionary] = []
	for asset_id: String in _asset_ids():
		var scene: String = Spec.scene_path(asset_id)
		if _assemble(asset_id, scene, lib):
			entries.append({
				"id": Spec.character_id(asset_id), "asset": asset_id, "scene": scene,
				"test": Spec.TEST_SCENES.has(asset_id),
			})
	_write_index(entries)
	print("assemble_characters: %d scene(s), %d clip(s), %d error(s)" % [
		entries.size(), lib.get_animation_list().size(), _errors])
	quit(1 if _errors > 0 else 0)


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
		if ResourceLoader.exists(_glb(asset_id)):
			out.append(asset_id)
	return out


static func _glb(asset_id: String) -> String:
	return "%s%s/%s.glb" % [Spec.ASSETS_DIR, asset_id, asset_id]


func _assemble(asset_id: String, scene_path: String, lib: AnimationLibrary) -> bool:
	var packed: PackedScene = load(_glb(asset_id)) as PackedScene
	if packed == null:
		_error("could not load %s (run godot --import first)" % _glb(asset_id))
		return false
	var src: Node = packed.instantiate()
	var skel: Skeleton3D = _find_skeleton(src)
	if skel == null:
		print("assemble_characters: %s has no Skeleton3D; skipped" % asset_id)
		src.free()
		return false
	var source: Dictionary = Spec.read_source("%s%s/SOURCE.txt" % [Spec.ASSETS_DIR, asset_id])
	var root: Node3D = Node3D.new()
	root.name = Spec.root_name(Spec.character_id(asset_id))
	# Skeleton3D directly under Root; the wrappers' (rig_humanoid...) transforms are folded in.
	var xf: Transform3D = skel.transform
	var p: Node = skel.get_parent()
	while p != src and p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	_adopt_loose_meshes(src, skel)
	_disown(skel)
	skel.get_parent().remove_child(skel)
	skel.name = "Skeleton3D"
	skel.transform = xf
	root.add_child(skel)
	src.free()
	_apply_blend_shapes(skel, source, asset_id)
	if not _externalise_meshes(skel, scene_path):
		root.free()
		return false
	_add_markers(skel, source, asset_id)
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library(Spec.ANIM_LIBRARY_NAME, lib)
	lib.set_id_for_path(scene_path, "1_anim")
	_own(root, root)
	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	root.free()
	if err != OK:
		_error("could not pack %s (%s)" % [scene_path, error_string(err)])
		return false
	_fix_node_ids(scene, scene_path)
	return _save(scene, scene_path)


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


func _find_skeleton(src: Node) -> Skeleton3D:
	var found: Array[Node] = src.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return null
	if found.size() > 1:
		push_warning("assemble_characters: %s has %d skeletons; using the first" % [src.name, found.size()])
	return found[0] as Skeleton3D


## Meshes outside the skeleton (rigid gear exported as separate objects) move under it, keeping
## their place relative to the skeleton.
func _adopt_loose_meshes(src: Node, skel: Skeleton3D) -> void:
	var loose: Array[Node] = []
	for n: Node in src.find_children("*", "MeshInstance3D", true, false):
		if not skel.is_ancestor_of(n):
			loose.append(n)
	for n: Node in loose:
		var mi: MeshInstance3D = n as MeshInstance3D
		var rel: Transform3D = _rel_xform(src, skel).affine_inverse() * _rel_xform(src, mi)
		_disown(mi)
		mi.get_parent().remove_child(mi)
		mi.transform = rel
		skel.add_child(mi)


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


## Saves every mesh as `<scene>_<node>.res` next to the scene so the .tscn references it instead
## of embedding the vertex data (imported glb sub-resources cannot be referenced from a .tscn).
## Skins stay embedded (small) with fixed ids.
func _externalise_meshes(skel: Skeleton3D, scene_path: String) -> bool:
	var base: String = scene_path.get_basename()
	var done: Dictionary = {}
	var skins: Dictionary = {}
	for mi: MeshInstance3D in _meshes(skel):
		if mi.mesh == null:
			continue
		if mi.skin != null and not skins.has(mi.skin):
			mi.skin.set_scene_unique_id("skin_%d" % skins.size())
			mi.skin.resource_path = ""
			skins[mi.skin] = true
		if done.has(mi.mesh):
			mi.mesh = done[mi.mesh]
			continue
		var path: String = "%s_%s.res" % [base, String(mi.name).to_snake_case()]
		var mesh: Mesh = mi.mesh
		for s: int in range(mesh.get_surface_count()):
			var mat: Material = mesh.surface_get_material(s)
			if mat != null and (mat.resource_path.is_empty() or mat.resource_path.contains("::")):
				mat.set_scene_unique_id("mat_%d" % s)
		var am: ArrayMesh = mesh as ArrayMesh
		if am != null and am.shadow_mesh != null:
			am.shadow_mesh.set_scene_unique_id("shadow")
		if not _save(mesh, path):
			return false
		var saved: Mesh = load(path) as Mesh
		saved.set_id_for_path(scene_path, "mesh_" + String(mi.name).to_snake_case())
		done[mesh] = saved
		mi.mesh = saved
	return true


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
			local = Transform3D(Spec.socket_basis(rest.basis), rest.affine_inverse() * point)
		var key: String = Spec.SOURCE_KEYS[marker]
		if source.has(key):
			var v: Variant = JSON.parse_string(String(source[key]))
			if v is Array and (v as Array).size() == 3:
				local.origin = rest.affine_inverse() * Vector3(float(v[0]), float(v[1]), float(v[2]))
			else:
				_error("%s SOURCE.txt %s is not [x, y, z]" % [asset_id, key])
		var socket: Marker3D = Marker3D.new()
		socket.name = Spec.SOCKET_NAME
		socket.transform = _rounded(local)
		att.add_child(socket)


## Rounds to 0.1 mm / 1e-5 so float noise never changes the saved text.
static func _rounded(t: Transform3D) -> Transform3D:
	var b: Basis = t.basis
	return Transform3D(
		Basis(b.x.snappedf(0.00001), b.y.snappedf(0.00001), b.z.snappedf(0.00001)),
		t.origin.snappedf(0.0001))


static func _disown(n: Node) -> void:
	n.owner = null
	for c: Node in n.get_children():
		_disown(c)


static func _own(n: Node, owner_node: Node) -> void:
	for c: Node in n.get_children():
		c.owner = owner_node
		c.scene_file_path = ""
		_own(c, owner_node)


func _write_index(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["scene"]) < String(b["scene"]))
	var data: Dictionary = {
		"_doc": "Generated by world/characters/_tools/assemble_characters.gd; do not edit. " +
			"Scenes follow docs/contracts/characters.md v1.1. test=true entries are fixtures, not cast.",
		"version": 1,
		"anim_library": Spec.ANIM_LIBRARY_PATH,
		"characters": entries,
	}
	var f: FileAccess = FileAccess.open(Spec.INDEX_PATH, FileAccess.WRITE)
	if f == null:
		_error("could not write %s" % Spec.INDEX_PATH)
		return
	f.store_string(JSON.stringify(data, "\t", true) + "\n")
	f.close()
