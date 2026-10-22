## Guard for ENV A's phase carry between locomotion loops (AnimDriver: switching walk / walk_* / walk_back or
## run / run_* seeks the new clip to the old one's normalised time, D-153 motion strips): within each gait family every
## 8-way clip has the same length; the forward clips' feet are in one phase and the backward clips' in another (the
## middle of each foot's stance at the same normalised time, within PHASE_TOL), BACK_OFFSET apart, so a carried phase
## keeps the feet in step. strafe_l / strafe_r (18 f) are not in a family. Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
## phase group -> [reference clip, members]. The backward clips' feet run BACK_OFFSET of a cycle later than the
## forward ones' (measured, both families): a carry from a forward clip to a backward one adds BACK_OFFSET to the
## normalised time (and subtracts it the other way); within a group the time carries as is.
const GROUPS: Dictionary = {
	"walk": ["walk", ["walk_fl", "walk_fr"]],
	"walk_back": ["walk_back", ["walk_bl", "walk_br"]],
	"run": ["run", ["run_fl", "run_fr", "run_l", "run_r"]],
	"run_back": ["run_b", ["run_bl", "run_br"]],
}
## forward group -> its backward group (the same gait, the same length)
const BACK_OF: Dictionary = {"walk": "walk_back", "run": "run_back"}
const BACK_OFFSET: float = 0.10
const BACK_OFFSET_TOL: float = 0.04
## samples per cycle, and the largest phase difference (fraction of the cycle) a carried phase may land off by
const SAMPLES: int = 60
const PHASE_TOL: float = 0.08
## a foot within this height (m) of its lowest point is planted
const PLANT_M: float = 0.02

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


func _ready_or_fail() -> bool:
	if _root == null or _player == null or _skel == null:
		fail("could not load %s with rig_humanoid/Skeleton3D and an AnimationPlayer (run godot --import first)" % GLB)
		return false
	return true


## Normalised time (0..1) of the middle of `bone`'s stance in `clip` (the circular mean of the samples where the foot
## is within PLANT_M of its lowest point): when that foot carries the body. Unlike the swing apex, it does not skew
## between walking forward and backward.
func _stance(clip: String, bone: String) -> float:
	var b: int = _skel.find_bone(bone)
	var a: Animation = _player.get_animation(StringName(clip))
	_player.play(StringName(clip))
	var ys: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(SAMPLES):
		_player.seek(float(i) / float(SAMPLES) * a.length, true)
		ys.append(_skel.get_bone_global_pose(b).origin.y)
	_player.stop()
	var lo: float = INF
	for y: float in ys:
		lo = minf(lo, y)
	var acc: Vector2 = Vector2.ZERO
	for i: int in range(SAMPLES):
		if ys[i] <= lo + PLANT_M:
			acc += Vector2.from_angle(TAU * float(i) / float(SAMPLES))
	return fposmod(acc.angle() / TAU, 1.0)


static func _cyc(a: float, b: float) -> float:
	var d: float = absf(a - b)
	return minf(d, 1.0 - d)


func test_families_share_length() -> void:
	if not _ready_or_fail():
		return
	for fwd: String in BACK_OF:
		var ref: String = GROUPS[fwd][0]
		var ra: Animation = _player.get_animation(StringName(ref))
		assert_true(ra != null, "%s exists" % ref)
		if ra == null:
			continue
		var back: String = BACK_OF[fwd]
		for clip: String in GROUPS[fwd][1] + [GROUPS[back][0]] + GROUPS[back][1]:
			var a: Animation = _player.get_animation(StringName(clip))
			assert_true(a != null, "%s exists" % clip)
			if a != null:
				assert_near(a.length, ra.length, 0.001, "%s length == %s length" % [clip, ref])
				assert_eq(a.loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)


func test_families_share_foot_phase() -> void:
	if not _ready_or_fail():
		return
	for g: String in GROUPS:
		var ref: String = GROUPS[g][0]
		var ref_l: float = _stance(ref, "foot.L")
		var ref_r: float = _stance(ref, "foot.R")
		assert_true(_cyc(ref_l, ref_r) > 0.35, "%s: the feet are planted half a cycle apart (L %.2f, R %.2f)" % [ref, ref_l,
			ref_r])
		for clip: String in GROUPS[g][1]:
			if not _player.has_animation(StringName(clip)):
				continue
			var l: float = _stance(clip, "foot.L")
			var r: float = _stance(clip, "foot.R")
			assert_true(_cyc(l, ref_l) <= PHASE_TOL and _cyc(r, ref_r) <= PHASE_TOL,
				"%s in phase with %s (left stance %.2f vs %.2f, right %.2f vs %.2f)" % [clip, ref, l, ref_l, r, ref_r])


func test_backward_offset() -> void:
	if not _ready_or_fail():
		return
	for fwd: String in BACK_OF:
		var f: String = GROUPS[fwd][0]
		var b: String = GROUPS[BACK_OF[fwd]][0]
		for foot: String in ["foot.L", "foot.R"]:
			var d: float = fposmod(_stance(b, foot) - _stance(f, foot) + 0.5, 1.0) - 0.5
			assert_near(d, BACK_OFFSET, BACK_OFFSET_TOL, "%s %s runs %.2f of a cycle after %s" % [b, foot, d, f])
