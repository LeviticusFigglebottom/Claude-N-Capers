## D1-01: rig_humanoid + base body import (docs/contracts/characters.md). Run after `godot --import`.
## Checks exact bone names and order, the main parent chains, height and facing (-Z) of
## char_body_base, and the body's blend shapes.
extends TestCase

const GLB: String = "res://assets/characters/char_body_base/char_body_base.glb"
const HEIGHT: float = 1.78
const FINGERS: Array[String] = ["thumb", "index", "middle", "ring", "pinky"]

var _root: Node3D = null
var _skel: Skeleton3D = null


func before_all() -> void:
	var packed: PackedScene = load(GLB) as PackedScene
	if packed == null:
		return
	_root = packed.instantiate() as Node3D
	add_child(_root)
	_skel = _root.get_node_or_null("Skeleton3D") as Skeleton3D


func after_all() -> void:
	if _root != null:
		_root.queue_free()


## The contract bone list in the order the generator creates it (parents first).
static func contract_bones() -> Array[String]:
	var out: Array[String] = ["root", "hips", "spine", "chest", "neck", "head"]
	for s: String in ["L", "R"]:
		for b: String in ["clavicle", "upper_arm", "forearm", "hand"]:
			out.append("%s.%s" % [b, s])
		for f: String in FINGERS:
			for i: int in [1, 2, 3]:
				out.append("%s_0%d.%s" % [f, i, s])
	for s: String in ["L", "R"]:
		for b: String in ["thigh", "shin", "foot", "toe"]:
			out.append("%s.%s" % [b, s])
	return out


func _ready_or_fail() -> bool:
	if _root == null:
		fail("could not load %s (run godot --import first)" % GLB)
		return false
	if _skel == null:
		fail("no top-level Skeleton3D (export with remove_armature, D-067b)")
		return false
	return true


func _parent(bone: String) -> String:
	var i: int = _skel.find_bone(bone)
	if i < 0:
		return "<missing>"
	var p: int = _skel.get_bone_parent(i)
	return _skel.get_bone_name(p) if p >= 0 else ""


func _rest(bone: String) -> Vector3:
	return _skel.get_bone_global_rest(_skel.find_bone(bone)).origin


func test_bone_names_match_contract() -> void:
	if not _ready_or_fail():
		return
	var names: Array[String] = []
	for i: int in range(_skel.get_bone_count()):
		names.append(_skel.get_bone_name(i))
	var want: Array[String] = contract_bones()
	assert_eq(want.size(), 52, "contract has 52 bones")
	assert_eq(names.size(), 52, "bone count")
	assert_eq(names, want, "exact bone names and order")


func test_parent_chains() -> void:
	if not _ready_or_fail():
		return
	var chain: Dictionary = {
		"root": "", "hips": "root", "spine": "hips", "chest": "spine", "neck": "chest", "head": "neck",
	}
	for s: String in ["L", "R"]:
		chain["clavicle." + s] = "chest"
		chain["upper_arm." + s] = "clavicle." + s
		chain["forearm." + s] = "upper_arm." + s
		chain["hand." + s] = "forearm." + s
		chain["thigh." + s] = "hips"
		chain["shin." + s] = "thigh." + s
		chain["foot." + s] = "shin." + s
		chain["toe." + s] = "foot." + s
		for f: String in FINGERS:
			chain["%s_01.%s" % [f, s]] = "hand." + s
			chain["%s_02.%s" % [f, s]] = "%s_01.%s" % [f, s]
			chain["%s_03.%s" % [f, s]] = "%s_02.%s" % [f, s]
	for bone: String in chain:
		assert_eq(_parent(bone), chain[bone], "parent of " + bone)


func test_height_and_feet_on_floor() -> void:
	if not _ready_or_fail():
		return
	var body: MeshInstance3D = _skel.get_node_or_null("Body") as MeshInstance3D
	assert_true(body != null, "Body mesh under Skeleton3D")
	if body == null:
		return
	var box: AABB = body.get_aabb()
	assert_near(box.end.y, HEIGHT, 0.01, "head top at 1.78 m")
	assert_near(box.position.y, 0.0, 0.005, "soles on the floor")
	assert_near(_rest("root").length(), 0.0, 0.0001, "root at the origin")
	assert_true(_rest("head").y > 1.5, "head bone high up")


func test_faces_minus_z() -> void:
	if not _ready_or_fail():
		return
	for s: String in ["L", "R"]:
		assert_true(_rest("toe." + s).z < _rest("foot." + s).z - 0.05, "toe in front (-Z) of the ankle " + s)
	assert_true(_rest("hand.L").x < 0.0 and _rest("hand.R").x > 0.0, "left = -X, right = +X")
	assert_true(_rest("thumb_01.R").z < _rest("pinky_01.R").z, "thumbs forward (A-pose palms in)")


func test_blend_shapes() -> void:
	if not _ready_or_fail():
		return
	var body: MeshInstance3D = _skel.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		fail("no Body")
		return
	var mesh: ArrayMesh = body.mesh as ArrayMesh
	var names: Array[String] = []
	for i: int in range(mesh.get_blend_shape_count()):
		names.append(String(mesh.get_blend_shape_name(i)))
	assert_eq(names, ["build", "gender", "age"] as Array[String], "shape keys")
	assert_true(body.skin != null, "Body is skinned")
