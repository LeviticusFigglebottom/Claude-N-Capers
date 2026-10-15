## PO6-19 (D-114 §7): builds the physical-bones ragdoll `Skeleton3D/Ragdoll` of an assembled character.
## Owner: ENV D. Called by assemble_characters.gd; the API for ENV A is in _tools/RAGDOLL.md.
##
## A PhysicalBoneSimulator3D (inactive: it never touches the animated pose until ENV A starts it) with one
## PhysicalBone3D per CharacterSpec.RAGDOLL_BONES entry. Each body frame is its bone's frame (bone +Y runs
## along the bone to its child) moved to the segment centre, so `body_offset` is a pure translation for
## the limbs; the CollisionShape3D is a box (hips, spine, chest) or a Y-axis capsule sized from the rest
## pose and scaled with the character height. Joints sit at the bone origin: cone-twist (twist axis = the
## joint frame's X = along the bone) or hinge (axis = the joint frame's Z = the flexion axis).
## Everything is computed from the rest pose and rounded, so re-runs write identical bytes.
extends RefCounted

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
## Cone-twist joint frame in the body frame: X (twist axis) along the bone (+Y).
const CONE_BASIS: Basis = Basis(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))


## The `Ragdoll` simulator for `skel` (not added to it). Problems are appended to `errors`.
static func build(skel: Skeleton3D, errors: Array[String]) -> PhysicalBoneSimulator3D:
	var head: int = skel.find_bone("head")
	var k: float = 1.0
	if head >= 0:
		k = skel.get_bone_global_rest(head).origin.y / Spec.DEFAULT_HEAD_Y
	var sim: PhysicalBoneSimulator3D = PhysicalBoneSimulator3D.new()
	sim.name = Spec.RAGDOLL_NODE
	sim.active = false
	for e: Dictionary in Spec.RAGDOLL_BONES:
		var pb: PhysicalBone3D = _bone(skel, e, k, errors)
		if pb != null:
			sim.add_child(pb)
	return sim


static func _bone(skel: Skeleton3D, e: Dictionary, k: float, errors: Array[String]) -> PhysicalBone3D:
	var bone_name: String = e["bone"]
	var i: int = skel.find_bone(bone_name)
	if i < 0:
		errors.append("no bone %s for the ragdoll" % bone_name)
		return null
	var rest: Transform3D = skel.get_bone_global_rest(i)
	var dir: Vector3 = Vector3.UP
	var length: float = float(e.get("len", 0.0)) * k
	var to: String = e.get("len_to", "")
	if not to.is_empty():
		var c: int = skel.find_bone(to)
		if c < 0:
			errors.append("no bone %s (end of the %s ragdoll segment)" % [to, bone_name])
			return null
		var local: Vector3 = rest.affine_inverse() * skel.get_bone_global_rest(c).origin
		length = local.length()
		dir = local / length
	var seg: float = length + float(e.get("ext", 0.0)) * k
	var rb: Basis = Basis.IDENTITY if dir.is_equal_approx(Vector3.UP) else Basis(Quaternion(Vector3.UP, dir))
	var shape: Shape3D
	var centre: float = seg * 0.5
	if String(e["shape"]) == "box":
		var dims: Array = _box(skel, bone_name, rest, length, k)
		shape = BoxShape3D.new()
		(shape as BoxShape3D).size = (dims[0] as Vector3).snappedf(0.0001)
		centre = dims[1]
	else:
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = snappedf(float(e["radius"]) * k, 0.0001)
		cap.height = snappedf(maxf(seg, cap.radius * 2.0 + 0.01), 0.0001)
		centre = float(e.get("start", 0.0)) * k + seg * 0.5
		shape = cap
	var pb: PhysicalBone3D = PhysicalBone3D.new()
	pb.name = e["node"]
	pb.bone_name = bone_name
	pb.body_offset = rounded(Transform3D(rb, dir * centre))
	pb.transform = rounded(rest * pb.body_offset)
	pb.mass = e["mass"]
	pb.friction = Spec.RAGDOLL_FRICTION
	pb.bounce = 0.0
	pb.linear_damp = Spec.RAGDOLL_LINEAR_DAMP
	pb.angular_damp = Spec.RAGDOLL_ANGULAR_DAMP
	pb.can_sleep = true
	pb.collision_layer = Spec.RAGDOLL_LAYER
	pb.collision_mask = Spec.RAGDOLL_MASK
	_joint(skel, pb, e, i, rest.basis * rb, centre)
	shape.set_scene_unique_id("ragdoll_" + String(e["node"]).to_snake_case())
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Shape"
	col.shape = shape
	pb.add_child(col)
	return pb


## [size, centre along the bone] of a torso box in the bone frame (X width, Y along the bone, Z depth).
static func _box(skel: Skeleton3D, bone_name: String, rest: Transform3D, length: float, k: float) -> Array:
	var cfg: Dictionary = Spec.RAGDOLL_BOX[bone_name]
	var depth: float = float(cfg["depth"]) * k
	if bone_name == "hips":
		var hip: Vector3 = rest.affine_inverse() * skel.get_bone_global_rest(skel.find_bone("thigh.L")).origin
		var below: float = float(cfg["below"]) * k
		return [Vector3(2.0 * absf(hip.x) + float(cfg["pad"]) * k, length + below, depth), (length - below) * 0.5]
	if bone_name == "chest":
		var span: float = skel.get_bone_global_rest(skel.find_bone("upper_arm.L")).origin.distance_to(
			skel.get_bone_global_rest(skel.find_bone("upper_arm.R")).origin)
		return [Vector3(span * float(cfg["shoulder_frac"]), length, depth), length * 0.5]
	return [Vector3(float(cfg["width"]) * k, length, depth), length * 0.5]


## Joint at the bone origin (body frame: (0, -centre, 0)). Hinge axis (frame Z) = flexion direction x the
## parent segment, so the [lower, upper] = [0, 140] range bends the elbow forward / the knee back (Jolt's
## hinge angle runs opposite to the right-hand rule about frame Z; verified by test_ragdoll.gd).
static func _joint(skel: Skeleton3D, pb: PhysicalBone3D, e: Dictionary, i: int, body_basis: Basis,
		centre: float) -> void:
	var kind: String = e["joint"]
	var at: Vector3 = Vector3(0.0, -centre, 0.0)
	if kind == "cone":
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		pb.set("joint_constraints/swing_span", float(e["swing"]))
		pb.set("joint_constraints/twist_span", float(e["twist"]))
		pb.joint_offset = rounded(Transform3D(CONE_BASIS, at))
	elif kind == "hinge":
		var parent: int = skel.get_bone_parent(i)
		var up: Vector3 = (skel.get_bone_global_rest(i).origin - skel.get_bone_global_rest(parent).origin).normalized()
		var flex: Vector3 = Spec.RAGDOLL_FLEX_DIR[String(e["bone"]).get_slice(".", 0)]
		var axis: Vector3 = body_basis.inverse() * flex.cross(up)
		var x: Vector3 = Vector3.UP
		var z: Vector3 = (axis - x * axis.dot(x)).normalized()
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		pb.set("joint_constraints/angular_limit_enabled", true)
		pb.set("joint_constraints/angular_limit_lower", float(e["lower"]))
		pb.set("joint_constraints/angular_limit_upper", float(e["upper"]))
		pb.joint_offset = rounded(Transform3D(Basis(x, z.cross(x), z), at))
	else:
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE


## Rounds to 0.1 mm / 1e-5 so float noise never changes the saved text.
static func rounded(t: Transform3D) -> Transform3D:
	var b: Basis = t.basis
	return Transform3D(
		Basis(b.x.snappedf(0.00001), b.y.snappedf(0.00001), b.z.snappedf(0.00001)),
		t.origin.snappedf(0.0001))
