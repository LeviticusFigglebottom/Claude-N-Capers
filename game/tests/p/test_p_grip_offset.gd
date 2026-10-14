## ENV D 2026-10-14 long-gun support grip: the LeftHandGrip (left-hand IK target) offset is per FP set. The 7
## long-gun sets on B's centred under-fore-end markers use D's measured PD2 grip wrist; side-grip sets keep the
## global offset. The live IK target check follows once FpLeftHandIk.set_target reads grip_offset(set_id).
## Owner: ENV P.
extends TestCase

const LONG_GUN: Vector3 = Vector3(-0.0315, -0.0178, 0.0266)
const LONG_SETS: Array[StringName] = [&"rifle", &"shotgun", &"lmg", &"sniper", &"break_action", &"lever",
	&"shotgun_box"]


func test_per_set_offsets() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	for s: StringName in LONG_SETS:
		assert_true(tw.grip_offset(s).is_equal_approx(LONG_GUN), "%s: long-gun grip (%s)" % [s, tw.grip_offset(s)])
	for s: StringName in [&"smg", &"launcher", &"flamethrower", &"minigun"]:
		assert_eq(tw.grip_offset(s), tw.left_hand_grip_offset, "%s keeps the side-grip offset" % s)
