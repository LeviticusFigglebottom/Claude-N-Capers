## First-person left-hand IK (D-069, characters.md v1.7). Owner: ENV A. Presentation only.
## Guns sharing an FP set differ in fore-end position (up to 0.24 m), so the clip's left hand is only a
## default: a TwoBoneIK3D on the arms skeleton (upper_arm.L -> forearm.L -> hand.L, elbow pole at
## FpViewmodelTweak.left_hand_pole_offset) pulls hand.L onto the equipped weapon model's `LeftHandIK`
## marker: the IK target is a `LeftHandGrip` child of the marker at FpViewmodelTweak.left_hand_grip_offset (the
## marker is the palm contact; the hand bone origin is the wrist). Influence blends to 0 while the clip uses
## the left hand (FpViewmodel reload / swap) or for sets in
## left_hand_ik_skip_sets (bow, akimbo), and when the weapon has no `LeftHandIK`.
class_name FpLeftHandIk
extends RefCounted

const ROOT_BONE: String = "upper_arm.L"
const MIDDLE_BONE: String = "forearm.L"
const END_BONE: String = "hand.L"
const GRIP_NAME: String = "LeftHandGrip"

var ik: TwoBoneIK3D = null
var pole: Node3D = null
var target: Node3D = null
var set_allowed: bool = true


## Build the IK on `skeleton` (null when the rig lacks the left-arm bones).
static func create(skeleton: Skeleton3D) -> FpLeftHandIk:
	if skeleton == null or skeleton.find_bone(ROOT_BONE) < 0 or skeleton.find_bone(END_BONE) < 0 \
			or skeleton.find_bone(MIDDLE_BONE) < 0:
		return null
	var h: FpLeftHandIk = FpLeftHandIk.new()
	h.pole = Node3D.new()
	h.pole.name = "LeftHandPole"
	skeleton.add_child(h.pole)
	var root_pos: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone(ROOT_BONE)).origin
	h.pole.position = root_pos + FpViewmodelTweak.data().left_hand_pole_offset
	h.ik = TwoBoneIK3D.new()
	h.ik.name = "LeftHandIK"
	skeleton.add_child(h.ik)
	h.ik.setting_count = 1
	h.ik.set_root_bone_name(0, ROOT_BONE)
	h.ik.set_middle_bone_name(0, MIDDLE_BONE)
	h.ik.set_end_bone_name(0, END_BONE)
	h.ik.set_pole_node(0, h.ik.get_path_to(h.pole))
	h.ik.influence = 0.0
	return h


## Point the hand at `marker` (the weapon's LeftHandIK; null = none) for FP set `set_id`.
func set_target(marker: Node3D, set_id: StringName) -> void:
	target = null
	if marker != null and is_instance_valid(marker):
		var grip: Node3D = marker.get_node_or_null(GRIP_NAME) as Node3D
		if grip == null:
			grip = Node3D.new()
			grip.name = GRIP_NAME
			marker.add_child(grip)
		grip.position = FpViewmodelTweak.data().grip_offset(set_id)  # per-set PD2 support grip (D-111)
		target = grip
	set_allowed = not FpViewmodelTweak.data().left_hand_ik_skip_sets.has(set_id)
	if ik != null and is_instance_valid(ik):
		ik.set_target_node(0, ik.get_path_to(target) if target != null and target.is_inside_tree() else NodePath(""))


## Blend the influence toward 1 while `hand_free_for_grip` and a target exists, else toward 0.
func update(delta: float, hand_free_for_grip: bool) -> void:
	if ik == null or not is_instance_valid(ik):
		return
	var want: float = 1.0 if hand_free_for_grip and set_allowed and target != null and is_instance_valid(target) else 0.0
	ik.influence = move_toward(ik.influence, want, delta * FpViewmodelTweak.data().left_hand_ik_rate)
	ik.active = ik.influence > 0.0
