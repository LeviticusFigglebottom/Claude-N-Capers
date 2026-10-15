## PO6-19 (D-114 §7): the physical-bones ragdoll `Skeleton3D/Ragdoll` of every assembled character
## (world/characters/_tools/ragdoll_builder.gd, API in _tools/RAGDOLL.md). Static checks on every
## non-test character in characters.json: the simulator exists and is inactive, every RAGDOLL_BONES body
## with its bone and a shape, an ~80 kg mass split, joint limits within the caps, world + ragdoll collision.
## Physics checks on the Security Officer: an inactive ragdoll neither collides nor changes the animated
## pose; a chest impulse on a floor ends lying down nearby with the limbs attached and no NaN; the hinges
## bend the right way (elbow forward, knee back); the settled pose can be baked and the ragdoll stopped.
## Regenerate with tools/blender/characters/assemble.sh.
extends TestCase

const Spec: GDScript = preload("res://world/characters/_tools/character_spec.gd")
const SMOKE: String = "char_security_officer"
const MASS_MIN: float = 70.0
const MASS_MAX: float = 90.0
## Cone caps (degrees) by bone family: swing half-angle, twist.
const SWING_CAP: Dictionary = {"spine": 30.0, "chest": 30.0, "head": 40.0, "upper_arm": 80.0, "thigh": 70.0}
const TWIST_CAP: float = 45.0
const HINGE_CAP: float = 145.0
const MAX_SHAPE_M: float = 0.6
const SETTLE_S: float = 3.0
const CHEST_IMPULSE: Vector3 = Vector3(0.0, 0.0, 150.0)
const LINK_SLACK: float = 1.3

## asset id -> instanced root (not in the tree), built once for the static checks.
var _roots: Dictionary = {}


func before_all() -> void:
	for e: Dictionary in Spec.read_index():
		if bool(e.get("test", false)):
			continue
		var packed: PackedScene = load(String(e["scene"])) as PackedScene
		if packed != null:
			_roots[String(e["asset"])] = packed.instantiate()


func after_all() -> void:
	for r: Variant in _roots.values():
		(r as Node).free()
	_roots.clear()


static func _sim(root: Node) -> PhysicalBoneSimulator3D:
	return root.get_node_or_null("Skeleton3D/" + Spec.RAGDOLL_NODE) as PhysicalBoneSimulator3D


static func _bodies(sim: PhysicalBoneSimulator3D) -> Array[PhysicalBone3D]:
	var out: Array[PhysicalBone3D] = []
	for n: Node in sim.get_children():
		if n is PhysicalBone3D:
			out.append(n as PhysicalBone3D)
	return out


static func _shape(pb: PhysicalBone3D) -> Shape3D:
	for n: Node in pb.get_children():
		if n is CollisionShape3D:
			return (n as CollisionShape3D).shape
	return null


func test_every_character_has_an_inactive_ragdoll() -> void:
	assert_true(_roots.size() > 50, "characters.json lists the cast (%d)" % _roots.size())
	for asset: String in _roots:
		var sim: PhysicalBoneSimulator3D = _sim(_roots[asset])
		if sim == null:
			fail("%s has no Skeleton3D/%s" % [asset, Spec.RAGDOLL_NODE])
			continue
		assert_false(sim.active, "%s Ragdoll must ship inactive" % asset)
		assert_false(sim.is_simulating_physics(), "%s Ragdoll must not simulate" % asset)


func test_every_ragdoll_has_the_bones_and_shapes() -> void:
	for asset: String in _roots:
		var sim: PhysicalBoneSimulator3D = _sim(_roots[asset])
		if sim == null:
			continue
		var skel: Skeleton3D = sim.get_parent() as Skeleton3D
		for e: Dictionary in Spec.RAGDOLL_BONES:
			var pb: PhysicalBone3D = sim.get_node_or_null(String(e["node"])) as PhysicalBone3D
			if pb == null:
				fail("%s Ragdoll/%s missing" % [asset, e["node"]])
				continue
			assert_eq(pb.bone_name, String(e["bone"]), "%s %s bone" % [asset, pb.name])
			assert_true(skel.find_bone(pb.bone_name) >= 0, "%s has bone %s" % [asset, pb.bone_name])
			var shape: Shape3D = _shape(pb)
			var ok: bool = false
			if shape is BoxShape3D:
				var s: Vector3 = (shape as BoxShape3D).size
				ok = String(e["shape"]) == "box" and s.x > 0.05 and s.y > 0.05 and s.z > 0.05 \
					and maxf(s.x, maxf(s.y, s.z)) < MAX_SHAPE_M
			elif shape is CapsuleShape3D:
				var c: CapsuleShape3D = shape as CapsuleShape3D
				ok = String(e["shape"]) == "capsule" and c.radius > 0.02 and c.height < MAX_SHAPE_M
			assert_true(ok, "%s %s shape %s" % [asset, pb.name, shape])


func test_mass_split_is_a_human_body() -> void:
	for asset: String in _roots:
		var sim: PhysicalBoneSimulator3D = _sim(_roots[asset])
		if sim == null:
			continue
		var total: float = 0.0
		for pb: PhysicalBone3D in _bodies(sim):
			total += pb.mass
			assert_true(pb.mass >= 1.0, "%s %s mass %.1f" % [asset, pb.name, pb.mass])
		assert_true(total >= MASS_MIN and total <= MASS_MAX, "%s ragdoll mass %.1f kg" % [asset, total])


func test_joint_limits_within_the_caps() -> void:
	for asset: String in _roots:
		var sim: PhysicalBoneSimulator3D = _sim(_roots[asset])
		if sim == null:
			continue
		for pb: PhysicalBone3D in _bodies(sim):
			var family: String = String(pb.bone_name).get_slice(".", 0)
			if family == "hips":
				assert_eq(pb.joint_type, PhysicalBone3D.JOINT_TYPE_NONE, "%s hips is the root body" % asset)
			elif family == "forearm" or family == "shin":
				assert_eq(pb.joint_type, PhysicalBone3D.JOINT_TYPE_HINGE, "%s %s hinge" % [asset, pb.name])
				assert_true(bool(pb.get("joint_constraints/angular_limit_enabled")), "%s %s limit" % [asset, pb.name])
				var lo: float = float(pb.get("joint_constraints/angular_limit_lower"))
				var hi: float = float(pb.get("joint_constraints/angular_limit_upper"))
				assert_true(lo >= -0.01 and hi <= HINGE_CAP and hi > 90.0,
					"%s %s hinge %.0f..%.0f (flexion only)" % [asset, pb.name, lo, hi])
			else:
				assert_eq(pb.joint_type, PhysicalBone3D.JOINT_TYPE_CONE, "%s %s cone" % [asset, pb.name])
				var swing: float = float(pb.get("joint_constraints/swing_span"))
				var twist: float = float(pb.get("joint_constraints/twist_span"))
				assert_true(swing > 5.0 and swing <= float(SWING_CAP.get(family, 0.0)) + 0.01,
					"%s %s swing %.0f" % [asset, pb.name, swing])
				assert_true(twist > 5.0 and twist <= TWIST_CAP + 0.01, "%s %s twist %.0f" % [asset, pb.name, twist])


func test_ragdoll_collision_layers() -> void:
	for asset: String in _roots:
		var sim: PhysicalBoneSimulator3D = _sim(_roots[asset])
		if sim == null:
			continue
		for pb: PhysicalBone3D in _bodies(sim):
			assert_eq(pb.collision_layer, Spec.RAGDOLL_LAYER, "%s %s layer" % [asset, pb.name])
			assert_eq(pb.collision_mask, Spec.RAGDOLL_MASK, "%s %s mask (world + ragdoll)" % [asset, pb.name])
			assert_true(pb.linear_damp > 0.0 and pb.angular_damp > 0.0, "%s %s damping" % [asset, pb.name])


# --------------------------------------------------------------------------------------------
# physics (Security Officer)
# --------------------------------------------------------------------------------------------

func _spawn(at: Vector3, with_ragdoll: bool = true) -> Node3D:
	var root: Node3D = (load(Spec.scene_path(SMOKE)) as PackedScene).instantiate() as Node3D
	if not with_ragdoll:
		var sim: Node = _sim(root)
		sim.get_parent().remove_child(sim)
		sim.free()
	root.position = at
	add_child(root)
	return root


func _floor() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1  # world_static
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = WorldBoundaryShape3D.new()
	body.add_child(col)
	add_child(body)
	return body


## Bone transform driven by a physical bone (global): body transform x body_offset^-1.
static func _bone_xf(pb: PhysicalBone3D) -> Transform3D:
	return pb.global_transform * pb.body_offset.affine_inverse()


## Hinge flexion (degrees) of `child` relative to its parent body: positive = elbow forward / knee back.
static func _flex(parent: PhysicalBone3D, child: PhysicalBone3D) -> float:
	var axis: Vector3 = child.global_basis * child.joint_offset.basis.z
	return -rad_to_deg(parent.global_basis.y.signed_angle_to(child.global_basis.y, axis))


static func _start(root: Node3D) -> PhysicalBoneSimulator3D:
	var sim: PhysicalBoneSimulator3D = _sim(root)
	sim.active = true
	sim.physical_bones_start_simulation()
	return sim


func test_inactive_ragdoll_neither_collides_nor_moves_the_pose() -> void:
	var a: Node3D = _spawn(Vector3(0, 0, -40))
	var b: Node3D = _spawn(Vector3(0, 0, -40), false)
	for r: Node3D in [a, b]:
		(r.get_node("AnimationPlayer") as AnimationPlayer).play("humanoid/walk")
	await wait_physics_frames(20)
	for pb: PhysicalBone3D in _bodies(_sim(a)):
		assert_eq(PhysicsServer3D.body_get_collision_layer(pb.get_rid()), 0, "%s collides while inactive" % pb.name)
	# Compare the drawn poses (read in skeleton_updated, after the modifiers ran) with a ragdoll-less twin.
	var drawn: Dictionary = {}
	for r: Node3D in [a, b]:
		var skel: Skeleton3D = r.get_node("Skeleton3D")
		skel.skeleton_updated.connect(func() -> void: drawn[r] = _key_poses(skel))
	await wait_frames(3)
	assert_true(drawn.has(a) and drawn.has(b), "both skeletons updated")
	if drawn.has(a) and drawn.has(b):
		for bone: String in (drawn[a] as Dictionary):
			assert_true((drawn[a][bone] as Vector3).is_equal_approx(drawn[b][bone] as Vector3),
				"inactive ragdoll changed the %s pose" % bone)
	a.queue_free()
	b.queue_free()


static func _key_poses(skel: Skeleton3D) -> Dictionary:
	var out: Dictionary = {}
	for bone: String in ["hips", "chest", "head", "forearm.L", "shin.R"]:
		out[bone] = skel.get_bone_global_pose(skel.find_bone(bone)).origin
	return out


func test_chest_impulse_falls_flat_and_stays_in_one_piece() -> void:
	var flo: StaticBody3D = _floor()
	var root: Node3D = _spawn(Vector3(20, 0, 0))
	(root.get_node("AnimationPlayer") as AnimationPlayer).play("humanoid/idle")
	await wait_physics_frames(2)
	var sim: PhysicalBoneSimulator3D = _start(root)
	await wait_physics_frames(1)
	(sim.get_node("Chest") as PhysicalBone3D).apply_central_impulse(CHEST_IMPULSE)
	await wait_physics_frames(roundi(SETTLE_S * Engine.physics_ticks_per_second))
	var skel: Skeleton3D = root.get_node("Skeleton3D")
	var bodies: Dictionary = {}
	for pb: PhysicalBone3D in _bodies(sim):
		bodies[pb.bone_name] = pb
		var xf: Transform3D = pb.global_transform
		assert_true(xf.origin.is_finite() and xf.basis.x.is_finite() and xf.basis.y.is_finite(), "%s NaN" % pb.name)
	var hips: Vector3 = _bone_xf(bodies["hips"]).origin
	assert_true(hips.y < 0.4, "hips at %.2f m: on the floor" % hips.y)
	assert_true(hips.y > -0.05, "hips at %.2f m: above the floor" % hips.y)
	assert_true(Vector2(hips.x - 20.0, hips.z).length() < 10.0, "body flew to %s" % hips)
	for pb: PhysicalBone3D in _bodies(sim):
		var parent: int = skel.get_bone_parent(skel.find_bone(pb.bone_name))
		while parent >= 0 and not bodies.has(StringName(skel.get_bone_name(parent))):
			parent = skel.get_bone_parent(parent)
		if parent < 0:
			continue
		var pname: StringName = skel.get_bone_name(parent)
		var rest: float = skel.get_bone_global_rest(parent).origin.distance_to(
			skel.get_bone_global_rest(skel.find_bone(pb.bone_name)).origin)
		var now: float = _bone_xf(bodies[pname]).origin.distance_to(_bone_xf(pb).origin)
		assert_true(now <= rest * LINK_SLACK + 0.01, "%s detached from %s: %.3f m (rest %.3f)" % [
			pb.bone_name, pname, now, rest])
	# Modifier results are only in the pose between skeleton_updated and the next frame's reset.
	await skel.skeleton_updated
	var drawn: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hips")).origin
	assert_true(drawn.distance_to(_bone_xf(bodies["hips"]).origin) < 0.05, "the skeleton follows the ragdoll")
	root.queue_free()
	flo.queue_free()


func test_hinges_bend_the_right_way() -> void:
	var root: Node3D = _spawn(Vector3(-20, 5, 0))
	await wait_physics_frames(2)
	var sim: PhysicalBoneSimulator3D = _start(root)
	for pb: PhysicalBone3D in _bodies(sim):
		pb.gravity_scale = 0.0
	await wait_physics_frames(1)
	var b: Dictionary = {}
	for pb: PhysicalBone3D in _bodies(sim):
		b[pb.name] = pb
	var rest: Dictionary = {
		"ForearmL": _flex(b["UpperArmL"], b["ForearmL"]), "ForearmR": _flex(b["UpperArmR"], b["ForearmR"]),
		"ShinL": _flex(b["ThighL"], b["ShinL"]), "ShinR": _flex(b["ThighR"], b["ShinR"]),
	}
	# L elbow pushed forward and L knee back (allowed), R elbow back and R knee forward (must not hyperextend).
	var low: Vector3 = Vector3(0, -0.15, 0)
	(b["ForearmL"] as PhysicalBone3D).apply_impulse(Vector3(0, 0, -3), low)
	(b["ForearmR"] as PhysicalBone3D).apply_impulse(Vector3(0, 0, 3), low)
	(b["ShinL"] as PhysicalBone3D).apply_impulse(Vector3(0, 0, 6), low)
	(b["ShinR"] as PhysicalBone3D).apply_impulse(Vector3(0, 0, -6), low)
	# Track each hinge's flexion range (relative to rest) over half a second.
	var pairs: Dictionary = {"ForearmL": "UpperArmL", "ForearmR": "UpperArmR", "ShinL": "ThighL", "ShinR": "ThighR"}
	var lo: Dictionary = {}
	var hi: Dictionary = {}
	for f: int in range(30):
		await wait_physics_frames(1)
		for n: String in pairs:
			var d: float = _flex(b[pairs[n]], b[n]) - float(rest[n])
			lo[n] = minf(float(lo.get(n, d)), d)
			hi[n] = maxf(float(hi.get(n, d)), d)
	for n: String in ["ForearmL", "ShinL"]:
		assert_true(float(hi[n]) > 20.0, "%s flexes the right way (max %.0f deg)" % [n, hi[n]])
	for n: String in pairs:
		assert_true(float(lo[n]) > -10.0, "%s must not hyperextend (min %.0f deg)" % [n, lo[n]])
		assert_true(float(hi[n]) < HINGE_CAP + 10.0, "%s flexion %.0f deg beyond the cap" % [n, hi[n]])
	root.queue_free()


## The freeze recipe of RAGDOLL.md: bake the settled bodies into the skeleton pose, stop the ragdoll.
func test_settled_pose_can_be_baked_and_the_ragdoll_stopped() -> void:
	var flo: StaticBody3D = _floor()
	var root: Node3D = _spawn(Vector3(0, 0, 40))
	var player: AnimationPlayer = root.get_node("AnimationPlayer")
	player.play("humanoid/idle")
	await wait_physics_frames(2)
	player.pause()  # RAGDOLL.md: pause at death (stop() would snap to frame 0)
	var sim: PhysicalBoneSimulator3D = _start(root)
	await wait_physics_frames(1)
	(sim.get_node("Chest") as PhysicalBone3D).apply_central_impulse(-CHEST_IMPULSE)
	await wait_physics_frames(roundi(SETTLE_S * Engine.physics_ticks_per_second))
	var skel: Skeleton3D = root.get_node("Skeleton3D")
	var hips_before: Vector3 = _bone_xf(sim.get_node("Hips")).origin
	_bake(skel, sim)
	sim.physical_bones_stop_simulation()
	sim.active = false
	await wait_physics_frames(10)
	var hips: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hips")).origin
	assert_true(hips.distance_to(hips_before) < 0.02, "baked hips %s vs settled %s" % [hips, hips_before])
	for pb: PhysicalBone3D in _bodies(sim):
		assert_eq(PhysicsServer3D.body_get_collision_layer(pb.get_rid()), 0, "%s still collides" % pb.name)
	root.queue_free()
	flo.queue_free()


## Writes the physical bones' current transforms into the skeleton's local bone poses (parents first).
static func _bake(skel: Skeleton3D, sim: PhysicalBoneSimulator3D) -> void:
	var driven: Dictionary = {}
	for pb: PhysicalBone3D in _bodies(sim):
		driven[skel.find_bone(pb.bone_name)] = skel.global_transform.affine_inverse() * _bone_xf(pb)
	var global: Array[Transform3D] = []
	global.resize(skel.get_bone_count())
	for i: int in range(skel.get_bone_count()):
		var parent: int = skel.get_bone_parent(i)
		var parent_xf: Transform3D = global[parent] if parent >= 0 else Transform3D.IDENTITY
		var local: Transform3D = skel.get_bone_pose(i)
		if driven.has(i):
			local = parent_xf.affine_inverse() * (driven[i] as Transform3D)
			skel.set_bone_pose(i, local.orthonormalized())
		global[i] = parent_xf * local
