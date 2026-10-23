## D1-05: assembled character scenes (docs/contracts/characters.md v1.1, D-029). Checks every scene
## in world/characters/characters.json: Root Node3D > Skeleton3D (52 contract bones) +
## AnimationPlayer (library "humanoid", P1 clips and loop modes once char_anim_humanoid exists),
## BoneAttachment3D markers with their Socket, blend shapes from SOURCE.txt, no null materials, and
## that the Head socket seats the crew mask on the face. Regenerate the scenes with
## world/characters/_tools/assemble_characters.gd (see world/characters/README.md).
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const Layers: GDScript = preload("res://world/characters/_tools/char_layers.gd")
const MASK: String = "res://assets/masks/mask_gilded_heron/mask_gilded_heron.glb"

var _index: Array[Dictionary] = []


func before_all() -> void:
	_index = Spec.read_index()


func _instance(entry: Dictionary) -> Node3D:
	var path: String = String(entry.get("scene", ""))
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		fail("could not load %s" % path)
		return null
	var node: Node = packed.instantiate()
	if not node is Node3D:
		fail("%s root is %s, not Node3D" % [path, node.get_class()])
		node.free()
		return null
	add_child(node)
	return node as Node3D


func _anim_delivered() -> bool:
	return ResourceLoader.exists(Spec.ANIM_GLB)


func test_index_lists_scenes() -> void:
	assert_true(_index.size() > 0, "characters.json lists scenes (run assemble_characters.gd)")
	for e: Dictionary in _index:
		var id: String = String(e.get("id", ""))
		var scene: String = String(e.get("scene", ""))
		assert_true(ResourceLoader.exists(scene), "scene exists: " + scene)
		if not bool(e.get("test", false)):
			assert_eq(scene, "%s%s/%s.tscn" % [Spec.OUT_DIR, id, id], "path convention for " + id)


func test_root_and_skeleton() -> void:
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		var tag: String = String(e["id"])
		assert_eq(String(root.name), Spec.root_name(tag), "root name")
		var skel: Skeleton3D = root.get_node_or_null("Skeleton3D") as Skeleton3D
		assert_true(skel != null, "%s: Root/Skeleton3D is a Skeleton3D" % tag)
		if skel != null:
			var names: Array[String] = []
			for i: int in range(skel.get_bone_count()):
				names.append(skel.get_bone_name(i))
			assert_eq(names, Spec.contract_bones(), "%s: 52 contract bones in order" % tag)
			assert_true(skel.get_child_count() > 0, "%s: skeleton has children" % tag)
			var meshes: int = 0
			for c: Node in skel.get_children():
				if c is MeshInstance3D:
					meshes += 1
			assert_true(meshes > 0, "%s: MeshInstance3D parts are direct children of Skeleton3D" % tag)
		root.queue_free()


func test_animation_player_and_clips() -> void:
	var loops: Array[String] = Spec.loop_names()
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		var tag: String = String(e["id"])
		var player: AnimationPlayer = root.get_node_or_null("AnimationPlayer") as AnimationPlayer
		assert_true(player != null, "%s: Root/AnimationPlayer" % tag)
		if player == null:
			root.queue_free()
			continue
		assert_true(player.get_node_or_null(player.root_node) == root, "%s: root_node is the Root" % tag)
		assert_true(player.has_animation_library(Spec.ANIM_LIBRARY_NAME), "%s: library humanoid" % tag)
		var lib: AnimationLibrary = player.get_animation_library(Spec.ANIM_LIBRARY_NAME)
		if lib != null:
			assert_eq(lib.resource_path, Spec.ANIM_LIBRARY_PATH, "%s: shared library file" % tag)
		if lib != null and _anim_delivered():
			for clip: String in Spec.P1_CLIPS:
				assert_true(player.has_animation("humanoid/" + clip), "%s: clip humanoid/%s" % [tag, clip])
			for clip: StringName in lib.get_animation_list():
				var want: Animation.LoopMode = Animation.LOOP_LINEAR if loops.has(String(clip)) else Animation.LOOP_NONE
				assert_eq(lib.get_animation(clip).loop_mode, want, "%s: loop mode of %s" % [tag, clip])
				_assert_tracks_resolve(root, lib.get_animation(clip), "%s/%s" % [tag, clip])
		root.queue_free()


func _assert_tracks_resolve(root: Node3D, anim: Animation, tag: String) -> void:
	var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
	for t: int in range(anim.get_track_count()):
		var path: NodePath = anim.track_get_path(t)
		assert_eq(String(path.get_concatenated_names()), "Skeleton3D", "%s track %d node" % [tag, t])
		assert_true(skel.find_bone(String(path.get_concatenated_subnames())) >= 0, "%s track %s bone" % [tag, path])


func test_markers_are_bone_attachments() -> void:
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		var tag: String = String(e["id"])
		var skel: Skeleton3D = root.get_node_or_null("Skeleton3D") as Skeleton3D
		if skel == null:
			root.queue_free()
			continue
		for marker: String in Spec.MARKERS:
			var att: BoneAttachment3D = skel.get_node_or_null(marker) as BoneAttachment3D
			assert_true(att != null, "%s: Skeleton3D/%s is a BoneAttachment3D" % [tag, marker])
			if att == null:
				continue
			assert_eq(att.bone_name, String(Spec.MARKERS[marker]), "%s: %s bone" % [tag, marker])
			assert_true(att.get_node_or_null(Spec.SOCKET_NAME) is Marker3D, "%s: %s/Socket" % [tag, marker])
		root.queue_free()


## Hand sockets carry the weapon grip frame the animation solver uses (_anim.grip_offset_godot).
func test_hand_sockets_match_grip_convention() -> void:
	var hands: Dictionary = Spec.hand_sockets()[0]
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
		var k: float = skel.get_bone_global_rest(skel.find_bone("head")).origin.y / Spec.DEFAULT_HEAD_Y
		for marker: String in ["HandR", "HandL"]:
			var socket: Node3D = skel.get_node_or_null(marker + "/" + Spec.SOCKET_NAME) as Node3D
			if socket == null:
				fail("%s: no %s/Socket" % [e["id"], marker])
				continue
			var want: Transform3D = hands[marker]
			assert_true(socket.transform.origin.distance_to(want.origin * k) < 0.0005, "%s: %s origin" % [e["id"], marker])
			var b: Basis = socket.transform.basis
			var err: float = (b.x - want.basis.x).length() + (b.y - want.basis.y).length() + (b.z - want.basis.z).length()
			assert_true(err < 0.0002, "%s: %s basis (error %f)" % [e["id"], marker, err])
		root.queue_free()


func test_walk_moves_bones() -> void:
	if not _anim_delivered():
		skip("char_anim_humanoid.glb not delivered yet")
		return
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		var tag: String = String(e["id"])
		var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
		var player: AnimationPlayer = root.get_node("AnimationPlayer") as AnimationPlayer
		var before: Array[Transform3D] = _pose(skel)
		player.play(&"humanoid/walk")
		await wait_frames(4)
		player.seek(0.25, true)
		var after: Array[Transform3D] = _pose(skel)
		var moved: int = 0
		for i: int in range(before.size()):
			if not before[i].is_equal_approx(after[i]):
				moved += 1
		assert_true(moved >= 4, "%s: humanoid/walk moves bones (%d moved)" % [tag, moved])
		root.queue_free()


static func _pose(skel: Skeleton3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i: int in range(skel.get_bone_count()):
		out.append(skel.get_bone_pose(i))
	return out


func test_no_null_materials() -> void:
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		for n: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			assert_true(mi.mesh != null, "%s/%s has a mesh" % [e["id"], mi.name])
			if mi.mesh == null:
				continue
			# D-067(b): the scene inherits the glb, so every mesh is the glb's own imported sub-resource
			# (D4-01: except the LOD2 proxy, which is <scene>_lod.res; D-132 D1: and the merged nodes, meta
			# source_materials, which are <scene>_<Node>.res).
			var glb: String = "res://assets/characters/%s/%s.glb" % [e["asset"], e["asset"]]
			if String(mi.name) == "CrowdLod":
				glb = String(e["scene"]).get_basename() + "_lod.res"
			elif mi.has_meta(Layers.META_SOURCE):
				glb = "%s_%s.res" % [String(e["scene"]).get_basename(), mi.name]
			assert_true(mi.mesh.resource_path.begins_with(glb + "::") or mi.mesh.resource_path == glb,
				"%s/%s mesh comes from %s (got '%s')" % [e["id"], mi.name, glb, mi.mesh.resource_path])
			var look: Array[Material] = Layers.look_materials(mi)
			for s: int in range(look.size()):
				var mat: Material = look[s]
				assert_true(mat != null, "%s/%s surface %d material" % [e["id"], mi.name, s])
		root.queue_free()


func test_blend_shapes_from_source() -> void:
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		var src: Dictionary = Spec.read_source("%s%s/SOURCE.txt" % [Spec.ASSETS_DIR, e["asset"]])
		var params: Variant = JSON.parse_string(String(src.get("params", "{}")))
		if not params is Dictionary:
			fail("%s SOURCE.txt params unreadable" % e["asset"])
			root.queue_free()
			continue
		for n: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			for i: int in range(mi.mesh.get_blend_shape_count()):
				var key: String = String(mi.mesh.get_blend_shape_name(i))
				var want: float = float((params as Dictionary).get(key, 0.0))
				assert_near(mi.get_blend_shape_value(i), want, 0.0001, "%s/%s %s" % [e["id"], mi.name, key])
		root.queue_free()


## The mask (pivot at the face centre) parented to Head/Socket sits on the face: its pivot between
## the eyes at cornea depth, its shell in front of the nose bridge and covering the eye line.
func test_mask_seats_on_face() -> void:
	var packed: PackedScene = load(MASK) as PackedScene
	if packed == null:
		skip("no mask glb")
		return
	for e: Dictionary in _index:
		var root: Node3D = _instance(e)
		if root == null:
			continue
		var tag: String = String(e["id"])
		var skel: Skeleton3D = root.get_node("Skeleton3D") as Skeleton3D
		var head: int = skel.find_bone("head")
		var socket: Node3D = skel.get_node("Head/" + Spec.SOCKET_NAME) as Node3D
		var k: float = skel.get_bone_global_rest(head).origin.y / Spec.DEFAULT_HEAD_Y
		var at: Transform3D = skel.get_bone_global_rest(head) * socket.transform
		var face: Vector3 = (Spec.SOCKET_POINTS["Head"] as Vector3) * k
		assert_true(at.origin.distance_to(face) < 0.002, "%s: Head socket at the face centre (%s)" % [tag, at.origin])
		assert_true(at.basis.is_equal_approx(Basis.IDENTITY), "%s: Head socket faces -Z, +Y up" % tag)
		var mask: Node3D = packed.instantiate() as Node3D
		socket.add_child(mask)
		await wait_frames(1)
		var box: AABB = AABB()
		var first: bool = true
		for n: Node in mask.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var b: AABB = root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var eye_y: float = 1.666 * k
		assert_true(box.position.y < eye_y - 0.05 and box.end.y > eye_y + 0.05, "%s: mask spans the eye line" % tag)
		assert_true(box.position.x < -0.06 and box.end.x > 0.06, "%s: mask covers both eyes" % tag)
		assert_true(box.position.z < -0.096 * k, "%s: mask shell in front of the nose bridge" % tag)
		root.queue_free()
