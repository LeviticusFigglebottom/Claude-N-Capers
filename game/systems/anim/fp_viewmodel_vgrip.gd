## D-118 (PD2 vertical grip) for FpViewmodel. Owner: ENV P.
## When the equipped gun's effective `LeftHandIK` is a mod's (WeaponVisual.get_marker differs from get_base_marker)
## and the set has a `<set>_vgrip_hand` clip and a vgrip wrist offset, the IK target moves to the grip
## (FpViewmodelTweak.set_vgrip_grip_offset) and the left hand / fingers take that clip's frame 0: the VgripPose
## modifier calls apply(), HandCapture uses `rel` for hand.L's orientation relative to the weapon bone.
class_name FpViewmodelVgrip
extends RefCounted

## Read only: hand.L orientation relative to the weapon bone in the vgrip clip (valid while active()).
var rel: Basis = Basis.IDENTITY

## The target local rotations of hand.L's finger bones (bone -> Quaternion, frame 0 of `<set>_vgrip_hand`);
## empty = no vertical grip on this gun.
var _pose: Dictionary = {}


## Whether the equipped gun's vertical grip holds the left hand.
func active() -> bool:
	return not _pose.is_empty()


## Called for every equipped visual; true when a vertical grip took over the left hand.
func setup(vm: FpViewmodel, wv: WeaponVisual, set_id: StringName, weapon_bone: int) -> bool:
	_pose.clear()
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	var skeleton: Skeleton3D = vm.skeleton
	if wv == null or skeleton == null or vm.left_hand_ik == null or not tw.set_vgrip_grip_offset.has(set_id):
		return false
	var mk: Node3D = wv.get_marker(&"LeftHandIK")
	if mk == null or not wv.has_method(&"get_base_marker") or mk == wv.call(&"get_base_marker", &"LeftHandIK"):
		return false
	if vm._resolve(set_id, &"vgrip_hand") != &"vgrip_hand":
		return false
	var anim: Animation = vm.player.get_animation("%s/vgrip_hand" % set_id)
	var hand: int = skeleton.find_bone(FpLeftHandIk.END_BONE)
	if anim == null or hand < 0:
		return false
	for t: int in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var b: int = skeleton.find_bone(String(anim.track_get_path(t)).get_slice(":", 1))
		if b >= 0 and _is_descendant(skeleton, b, hand):  # the fingers; hand.L's orientation goes through HandRestore
			_pose[b] = anim.rotation_track_interpolate(t, 0.0)
	if _pose.is_empty() or weapon_bone < 0:
		_pose.clear()
		return false
	rel = clip_global(skeleton, anim, weapon_bone).basis.orthonormalized().inverse() \
		* clip_global(skeleton, anim, hand).basis.orthonormalized()
	var grip: Node3D = mk.get_node_or_null(FpLeftHandIk.GRIP_NAME) as Node3D
	if grip != null:  # ENV D's offset is in weapon (WeaponVisual) axes; the grip node lives in the marker's
		var to_marker: Basis = mk.global_basis.orthonormalized().inverse() * wv.global_basis.orthonormalized()
		grip.position = to_marker * (tw.set_vgrip_grip_offset[set_id] as Vector3)
	return true


## VgripPose modifier: blend the fingers to the grip pose by the left-hand IK's influence (the clip owns the hand
## while reloading / swapping, like the IK).
func apply(vm: FpViewmodel) -> void:
	var skeleton: Skeleton3D = vm.skeleton
	if _pose.is_empty() or skeleton == null or vm.left_hand_ik == null or vm.left_hand_ik.ik == null:
		return
	var w: float = vm.left_hand_ik.ik.influence
	if w <= 0.0:
		return
	for b: int in _pose:
		var cur: Quaternion = skeleton.get_bone_pose_rotation(b)
		skeleton.set_bone_pose_rotation(b, cur.slerp(_pose[b] as Quaternion, w))


## Skeleton-space pose of `bone` in `anim` at frame 0 (rest where the clip has no track).
static func clip_global(skeleton: Skeleton3D, anim: Animation, bone: int) -> Transform3D:
	var chain: Array[int] = []
	var b: int = bone
	while b >= 0:
		chain.push_front(b)
		b = skeleton.get_bone_parent(b)
	var g: Transform3D = Transform3D.IDENTITY
	for i: int in chain:
		var rest: Transform3D = skeleton.get_bone_rest(i)
		var path: NodePath = NodePath("%s:%s" % [_skeleton_path(anim), skeleton.get_bone_name(i)])
		var rt: int = anim.find_track(path, Animation.TYPE_ROTATION_3D)
		var pt: int = anim.find_track(path, Animation.TYPE_POSITION_3D)
		var q: Quaternion = anim.rotation_track_interpolate(rt, 0.0) if rt >= 0 else rest.basis.get_rotation_quaternion()
		var o: Vector3 = anim.position_track_interpolate(pt, 0.0) if pt >= 0 else rest.origin
		g = g * Transform3D(Basis(q).scaled(rest.basis.get_scale()), o)
	return g


## The node path prefix (before ":bone") the clip's bone tracks use.
static func _skeleton_path(anim: Animation) -> String:
	for t: int in anim.get_track_count():
		var p: String = String(anim.track_get_path(t))
		if p.contains(":"):
			return p.get_slice(":", 0)
	return "."


static func _is_descendant(skeleton: Skeleton3D, b: int, ancestor: int) -> bool:
	var p: int = skeleton.get_bone_parent(b)
	while p >= 0:
		if p == ancestor:
			return true
		p = skeleton.get_bone_parent(p)
	return false
