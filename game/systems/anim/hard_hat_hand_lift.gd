## D-115 (ENV D clip audit R1): hands sink into a hard hat in the hands-on-head clips (surrender, hands_up, cower...)
## because the shell stands ~2.4 cm off the skull. On a rig whose headwear is a hard hat, this modifier moves a
## hand that rests on the head AnimTweak.hard_hat_hand_lift_m up the head's axis with an analytic two-bone IK
## (upper_arm -> forearm -> hand, the clip's elbow bend plane kept, the hand's rotation kept). AnimDriver adds
## it and blends `influence` in during AnimTweak.hard_hat_lift_clips. Presentation only. Owner: ENV A.
class_name HardHatHandLift
extends SkeletonModifier3D

const NODE_NAME: String = "HardHatHandLift"
const HEADWEAR_META: StringName = &"headwear_class"
const HARD_HAT: StringName = &"hard_hat"
const SIDES: Array[Array] = [["upper_arm.L", "forearm.L", "hand.L"], ["upper_arm.R", "forearm.R", "hand.R"]]

## Metres to lift a hand that rests on the head.
var lift_m: float = 0.03
## A hand counts as on the head within this distance (m) of the head bone.
var near_head_m: float = 0.32
## Last lift applied per side (m, for tests): [left, right].
var applied: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])


## True when `rig` wears a hard hat: its `Headwear` node is tagged (meta headwear_class = &"hard_hat", ENV D) or
## its character id is listed in AnimTweak.hard_hat_characters (until the tag lands).
static func wears_hard_hat(rig: Node, character_id: String) -> bool:
	if rig == null:
		return false
	var hw: Node = rig.get_node_or_null(^"Skeleton3D/Headwear")
	if hw != null and hw.has_meta(HEADWEAR_META):
		return StringName(hw.get_meta(HEADWEAR_META)) == HARD_HAT
	return AnimTweak.data().hard_hat_characters.has(StringName(character_id))


## Add the modifier under `skeleton` (idempotent). Null when the rig lacks the arm / head bones.
static func ensure(skeleton: Skeleton3D) -> HardHatHandLift:
	if skeleton == null or skeleton.find_bone("head") < 0:
		return null
	for s: Array in SIDES:
		for b: Variant in s:
			if skeleton.find_bone(String(b)) < 0:
				return null
	var m: HardHatHandLift = skeleton.get_node_or_null(NODE_NAME) as HardHatHandLift
	if m == null:
		m = HardHatHandLift.new()
		m.name = NODE_NAME
		m.influence = 0.0
		m.active = false
		skeleton.add_child(m)
	var tw: AnimTweak = AnimTweak.data()
	m.lift_m = tw.hard_hat_hand_lift_m
	m.near_head_m = tw.hard_hat_near_head_m
	return m


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var head: Transform3D = sk.get_bone_global_pose(sk.find_bone("head"))
	var up: Vector3 = head.basis.y.normalized()
	for i: int in SIDES.size():
		applied[i] = 0.0
		var ids: Array[int] = []
		for b: Variant in SIDES[i]:
			ids.append(sk.find_bone(String(b)))
		var hand: Transform3D = sk.get_bone_global_pose(ids[2])
		if hand.origin.distance_to(head.origin) > near_head_m:
			continue
		if _reach(sk, ids, hand, hand.origin + up * lift_m):
			applied[i] = lift_m


## Two-bone IK in skeleton space: move the hand (ids[2]) to `target`, elbow kept in the clip's bend plane, the hand's
## rotation kept. False when the chain is degenerate.
static func _reach(sk: Skeleton3D, ids: Array[int], hand: Transform3D, target: Vector3) -> bool:
	var ua: Transform3D = sk.get_bone_global_pose(ids[0])
	var e: Vector3 = sk.get_bone_global_pose(ids[1]).origin
	var s: Vector3 = ua.origin
	var a: float = s.distance_to(e)
	var b: float = e.distance_to(hand.origin)
	var to_t: Vector3 = target - s
	if a < 0.01 or b < 0.01 or to_t.length() < 0.01:
		return false
	var d: float = clampf(to_t.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir: Vector3 = to_t.normalized()
	var bend: Vector3 = (e - s) - dir * (e - s).dot(dir)
	if bend.length() < 0.0001:
		bend = dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.UP).normalized()
	bend = bend.normalized()
	var cos_a: float = clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var e2: Vector3 = s + dir * a * cos_a + bend * a * sqrt(1.0 - cos_a * cos_a)
	sk.set_bone_global_pose(ids[0], Transform3D(Basis(Quaternion((e - s).normalized(), (e2 - s).normalized())) * ua.basis, s))
	var fa: Transform3D = sk.get_bone_global_pose(ids[1])
	var h1: Vector3 = sk.get_bone_global_pose(ids[2]).origin
	var t2: Vector3 = s + dir * d
	if (h1 - fa.origin).length() > 0.0001 and (t2 - fa.origin).length() > 0.0001:
		var q: Quaternion = Quaternion((h1 - fa.origin).normalized(), (t2 - fa.origin).normalized())
		sk.set_bone_global_pose(ids[1], Transform3D(Basis(q) * fa.basis, fa.origin))
	sk.set_bone_global_pose(ids[2], Transform3D(hand.basis, sk.get_bone_global_pose(ids[2]).origin))
	return true
