## ENV D 2026-10-14 long-gun support grip: the LeftHandGrip (left-hand IK target) offset is per FP set. The 7
## long-gun sets on B's centred under-fore-end markers use D's measured PD2 grip wrist; side-grip sets keep the
## global offset; the live IK target of an equipped gun sits at its set's offset. Owner: ENV P.
extends TestCase

const LONG_GUN: Vector3 = Vector3(-0.0315, -0.0178, 0.0266)
const LONG_SETS: Array[StringName] = [&"rifle", &"shotgun", &"lmg", &"sniper", &"break_action", &"lever",
	&"shotgun_box"]

var _root: Node3D = null


func after_each() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	await wait_frames(1)


func test_per_set_offsets() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	for s: StringName in LONG_SETS:
		assert_true(tw.grip_offset(s).is_equal_approx(LONG_GUN), "%s: long-gun grip (%s)" % [s, tw.grip_offset(s)])
	for s: StringName in [&"smg", &"launcher", &"flamethrower", &"minigun"]:
		assert_eq(tw.grip_offset(s), tw.left_hand_grip_offset, "%s keeps the side-grip offset" % s)


func _grip_of(primary: StringName) -> Array:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	add_child(_root)
	await wait_frames(1)
	var l: Loadout = Loadout.new()
	l.primary = primary
	l.secondary = &"weapon.kestrel_p9"
	var c: CrewController = CrewController.spawn_for_range(_root, Transform3D.IDENTITY, l) as CrewController
	await wait_frames(3)
	var fp: FpViewmodel = CrewView.of(c).fp_viewmodel()
	var marker: Node3D = (c.weapon_visual as WeaponVisual).get_marker(&"LeftHandIK") if c.weapon_visual != null else null
	var grip: Node3D = marker.get_node_or_null(FpLeftHandIk.GRIP_NAME) as Node3D if marker != null else null
	return [fp.anim_set if fp != null else &"", grip]


func test_live_ik_target_follows_set() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	for w: StringName in [&"weapon.corsair_ar", &"weapon.wasp_pdw"]:
		var got: Array = await _grip_of(w)
		var grip: Node3D = got[1] as Node3D
		assert_true(grip != null, "%s: LeftHandGrip built" % w)
		if grip != null:
			var want: Vector3 = FpViewmodelTweak.data().grip_offset(got[0])
			assert_true(grip.position.is_equal_approx(want), "%s (%s): grip at %s, want %s" % [w, got[0], grip.position,
				want])
		await after_each()
