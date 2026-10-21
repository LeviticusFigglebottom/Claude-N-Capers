## D polish (LEAD 2026-10-21, D backlog #1): the most-watched reaction one-shots move the arms smoothly. surrender /
## surrender_b used to snap both forearms 52-55 deg in one frame at frame 1 (an ease-out from rest), surrender_c,
## mask_on and downed_arrested 50-52 deg in one frame where a folded arm's hand passed next to the shoulder. Every arm
## bone (upper arm, forearm, hand) now turns at most MAX_STEP_DEG between two frames. panic_start is the startle jolt
## (51 deg at the flinch, by design) and is not listed. Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const CLIPS: Array[String] = ["surrender", "surrender_b", "surrender_c", "mask_on", "downed_arrested"]
const BONES: Array[String] = ["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "hand.L", "hand.R"]
## per-frame local rotation budget for the arm bones (the clips measure 32-41 deg after the fix)
const MAX_STEP_DEG: float = 42.0

var _root: Node3D = null
var _player: AnimationPlayer = null
var _skel: Skeleton3D = null


func before_all() -> void:
	var packed: PackedScene = load(GLB) as PackedScene
	if packed == null:
		return
	_root = packed.instantiate() as Node3D
	add_child(_root)
	_skel = _root.get_node_or_null("rig_humanoid/Skeleton3D") as Skeleton3D
	var found: Array[Node] = _root.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_player = found[0] as AnimationPlayer


func after_all() -> void:
	if _root != null:
		_root.queue_free()


func _rotations(clip: String, f: int) -> Array[Quaternion]:
	_player.play(StringName(clip))
	_player.seek(float(f) / 30.0, true)
	var out: Array[Quaternion] = []
	for b: String in BONES:
		out.append(_skel.get_bone_pose_rotation(_skel.find_bone(b)))
	_player.stop()
	return out


func test_reaction_arms_never_snap() -> void:
	if _root == null or _player == null or _skel == null:
		fail("could not load %s (run godot --import first)" % GLB)
		return
	for clip: String in CLIPS:
		assert_true(_player.has_animation(StringName(clip)), "clip %s" % clip)
		if not _player.has_animation(StringName(clip)):
			continue
		var n: int = roundi(_player.get_animation(StringName(clip)).length * 30.0)
		var prev: Array[Quaternion] = _rotations(clip, 0)
		var worst: float = 0.0
		var at: String = ""
		for f: int in range(1, n + 1):
			var cur: Array[Quaternion] = _rotations(clip, f)
			for i: int in BONES.size():
				var d: float = rad_to_deg(prev[i].angle_to(cur[i]))
				if d > worst:
					worst = d
					at = "%s f%d" % [BONES[i], f]
			prev = cur
		assert_true(worst <= MAX_STEP_DEG, "%s: worst arm step %.1f deg (%s) <= %.0f" % [clip, worst, at, MAX_STEP_DEG])
