## D1-03: first-person arms rig `rig_arms` + the pistol viewmodel set (char_arms_fp).
## Checks the rig (root at the camera origin, contract arm/finger bones, weapon/magazine helper
## bones and the weapon grip offset), the mesh budget and the `pistol_<clip>` animations.
extends TestCase

const GLB: String = "res://assets/characters/char_arms_fp/char_arms_fp.glb"
const FINGERS: Array[String] = ["thumb", "index", "middle", "ring", "pinky"]
const CLIPS: Array[String] = [
	"pistol_idle", "pistol_ads_idle", "pistol_draw", "pistol_holster", "pistol_fire", "pistol_fire_ads",
	"pistol_reload", "pistol_reload_empty", "pistol_sprint",
]
const LOOPED: Array[String] = ["pistol_idle", "pistol_ads_idle", "pistol_sprint"]

var _root: Node3D = null
var _skel: Skeleton3D = null
var _player: AnimationPlayer = null


func before_all() -> void:
	var packed: PackedScene = load(GLB) as PackedScene
	if packed == null:
		return
	_root = packed.instantiate() as Node3D
	add_child(_root)
	_skel = _root.get_node_or_null("rig_arms/Skeleton3D") as Skeleton3D
	var found: Array[Node] = _root.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_player = found[0] as AnimationPlayer


func after_all() -> void:
	if _root != null:
		_root.queue_free()


func _ready_or_fail() -> bool:
	if _root == null or _skel == null:
		fail("could not load %s with rig_arms/Skeleton3D (run godot --import first)" % GLB)
		return false
	return true


static func expected_bones() -> Array[String]:
	var out: Array[String] = ["root"]
	for s: String in ["L", "R"]:
		for b: String in ["clavicle", "upper_arm", "forearm", "hand"]:
			out.append("%s.%s" % [b, s])
		for f: String in FINGERS:
			for i: int in [1, 2, 3]:
				out.append("%s_0%d.%s" % [f, i, s])
	out.append("weapon")
	out.append("magazine")
	return out


func _parent(bone: String) -> String:
	var p: int = _skel.get_bone_parent(_skel.find_bone(bone))
	return _skel.get_bone_name(p) if p >= 0 else ""


func test_bones_and_parents() -> void:
	if not _ready_or_fail():
		return
	var names: Array[String] = []
	for i: int in range(_skel.get_bone_count()):
		names.append(_skel.get_bone_name(i))
	assert_eq(names, expected_bones(), "rig_arms bone names and order")
	assert_eq(_parent("root"), "", "root has no parent")
	assert_eq(_parent("clavicle.L"), "root", "clavicle.L under root")
	assert_eq(_parent("clavicle.R"), "root", "clavicle.R under root")
	assert_eq(_parent("hand.R"), "forearm.R", "hand.R chain")
	assert_eq(_parent("index_01.L"), "hand.L", "fingers under the hand")
	assert_eq(_parent("weapon"), "hand.R", "weapon under hand.R")
	assert_eq(_parent("magazine"), "weapon", "magazine under weapon")


func test_root_is_the_camera_origin() -> void:
	if not _ready_or_fail():
		return
	var root_rest: Transform3D = _skel.get_bone_global_rest(_skel.find_bone("root"))
	assert_true(root_rest.origin.length() < 0.0001, "root bone at the origin")
	# shoulders are below and behind the eye; the right side is +X
	var sh_r: Vector3 = _skel.get_bone_global_rest(_skel.find_bone("upper_arm.R")).origin
	assert_true(sh_r.x > 0.1 and sh_r.y < -0.15 and sh_r.z > 0.03, "right shoulder at %s" % sh_r)


func test_weapon_bone_matches_grip_offset() -> void:
	if not _ready_or_fail():
		return
	var hand: Transform3D = _skel.get_bone_global_rest(_skel.find_bone("hand.R"))
	var weapon: Transform3D = _skel.get_bone_global_rest(_skel.find_bone("weapon"))
	var rel: Transform3D = hand.affine_inverse() * weapon
	# _anim.grip_offset_godot(): 18 deg grip rake, origin 76 % along the hand
	var c: float = cos(deg_to_rad(18.0))
	var s: float = sin(deg_to_rad(18.0))
	assert_true(rel.basis.x.is_equal_approx(Vector3(0, 0, 1)), "weapon X = %s" % rel.basis.x)
	assert_true(rel.basis.y.distance_to(Vector3(-c, -s, 0)) < 0.001, "weapon Y = %s" % rel.basis.y)
	assert_true(rel.basis.z.distance_to(Vector3(s, -c, 0)) < 0.001, "weapon Z = %s" % rel.basis.z)
	assert_near(rel.origin.x, -0.012, 0.001, "grip offset x")
	assert_near(rel.origin.z, -0.030, 0.001, "grip offset z")


func test_mesh_and_budget() -> void:
	if not _ready_or_fail():
		return
	var mesh_node: MeshInstance3D = _skel.get_node_or_null("Arms") as MeshInstance3D
	assert_true(mesh_node != null, "Arms mesh under the skeleton")
	if mesh_node == null:
		return
	var tris: int = 0
	var mats: Array[String] = []
	for si: int in range(mesh_node.mesh.get_surface_count()):
		var arrays: Array = mesh_node.mesh.surface_get_arrays(si)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		tris += idx.size() / 3
		var m: Material = mesh_node.mesh.surface_get_material(si)
		assert_true(m != null, "surface %d has a material" % si)
		if m != null:
			mats.append(m.resource_name)
	assert_true(tris <= 12000, "arms triangles %d <= 12000" % tris)
	assert_true(mesh_node.skin != null, "Arms is skinned")


func test_pistol_clips() -> void:
	if not _ready_or_fail():
		return
	assert_true(_player != null, "AnimationPlayer present")
	if _player == null:
		return
	for clip: String in CLIPS:
		assert_true(_player.has_animation(StringName(clip)), "clip %s" % clip)
		if not _player.has_animation(StringName(clip)):
			continue
		var a: Animation = _player.get_animation(StringName(clip))
		assert_true(a.length > 0.0, "%s length" % clip)
		var want: Animation.LoopMode = Animation.LOOP_LINEAR if LOOPED.has(clip) else Animation.LOOP_NONE
		assert_eq(a.loop_mode, want, "%s loop mode" % clip)
		for t: int in range(a.get_track_count()):
			var bone: String = String(a.track_get_path(t).get_concatenated_subnames())
			assert_true(_skel.find_bone(bone) >= 0, "%s: track bone %s" % [clip, bone])
	assert_near(_player.get_animation(&"pistol_reload").length, 1.5, 0.002, "reload = reload_time_s 1.5")
	assert_near(_player.get_animation(&"pistol_reload_empty").length, 2.1, 0.002, "reload_empty = 2.1 s")
	assert_near(_player.get_animation(&"pistol_draw").length, 11.0 / 30.0, 0.002, "draw ~ equip_time 0.35 s")


func test_magazine_moves_in_reload() -> void:
	if not _ready_or_fail() or _player == null or not _player.has_animation(&"pistol_reload"):
		return
	var a: Animation = _player.get_animation(&"pistol_reload")
	var found: bool = false
	for t: int in range(a.get_track_count()):
		if String(a.track_get_path(t).get_concatenated_subnames()) == "magazine" \
				and a.track_get_type(t) == Animation.TYPE_POSITION_3D:
			found = true
	assert_true(found, "pistol_reload animates the magazine bone position")
