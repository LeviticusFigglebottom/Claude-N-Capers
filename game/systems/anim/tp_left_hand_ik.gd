## Lead ruling (c) / characters.md v1.19: third-person left hand on the held weapon's `LeftHandIK` marker. After the
## clip (and the upper-body layers), an analytic two-bone IK (HardHatHandLift._reach: upper_arm.L -> forearm.L ->
## hand.L, the clip's elbow bend plane and hand rotation kept) moves the left hand so its grip point (HandL/Socket) lands
## on the marker. The marker rides the right hand, so its pose is rebuilt from this frame's hand.R pose
## (hand.R x HandR/Socket x the marker's fixed offset from that socket), never from last frame's attachment.
## AnimDriver sets the target and blends `influence`. Presentation only. Owner: ENV A.
class_name ThirdPersonLeftHandIK
extends SkeletonModifier3D

const NODE_NAME: String = "ThirdPersonLeftHandIK"
const CHAIN: Array[String] = ["upper_arm.L", "forearm.L", "hand.L"]
const HAND_R: String = "hand.R"

## The weapon's LeftHandIK marker (null = none).
var marker: Node3D = null
## Grip point error after the last solve (m, skeleton space; tests).
var last_error_m: float = INF

var _socket_r: Node3D = null
var _socket_l: Node3D = null
var _ids: Array[int] = []
var _hand_r: int = -1


## The modifier under `skeleton` (appended, so it runs after the clip layers); null without the arm bones.
static func ensure(skeleton: Skeleton3D) -> ThirdPersonLeftHandIK:
	if skeleton == null or skeleton.find_bone(HAND_R) < 0:
		return null
	for b: String in CHAIN:
		if skeleton.find_bone(b) < 0:
			return null
	var m: ThirdPersonLeftHandIK = skeleton.get_node_or_null(NODE_NAME) as ThirdPersonLeftHandIK
	if m == null:
		m = ThirdPersonLeftHandIK.new()
		m.name = NODE_NAME
		m.influence = 0.0
		m.active = false
		skeleton.add_child(m)
	return m


## Target `p_marker` with the rig's HandR / HandL sockets.
func set_target(p_marker: Node3D, socket_r: Node3D, socket_l: Node3D) -> void:
	marker = p_marker if p_marker != null and is_instance_valid(p_marker) else null
	_socket_r = socket_r
	_socket_l = socket_l


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or marker == null or not is_instance_valid(marker) or _socket_r == null or _socket_l == null \
			or not marker.is_inside_tree():
		return
	if _ids.is_empty():
		for b: String in CHAIN:
			_ids.append(sk.find_bone(b))
		_hand_r = sk.find_bone(HAND_R)
	# The marker relative to HandR/Socket is fixed (the gun is rigid in the right fist).
	var rel: Transform3D = _socket_r.global_transform.affine_inverse() * marker.global_transform
	var target: Vector3 = (sk.get_bone_global_pose(_hand_r) * _socket_r.transform * rel).origin
	var hand: Transform3D = sk.get_bone_global_pose(_ids[2])
	var grip: Vector3 = hand.basis * _socket_l.transform.origin  # HandL/Socket (grip point) from the wrist
	HardHatHandLift._reach(sk, _ids, hand, target - grip)
	var solved: Transform3D = sk.get_bone_global_pose(_ids[2])
	last_error_m = (solved * _socket_l.transform).origin.distance_to(target)
