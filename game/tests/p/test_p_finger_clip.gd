## PO-13 / D-111 support hand: finger skin vs the gun in the real game pose (PFingerClip), hip and ADS, one gun per
## long-gun set. Sanity: the CPU-skinned finger vertices sit on their bones (the skinning maths match the render).
## Report: per gun and pose, finger vertices inside the gun and the deepest one ("[FINGERS] ..." lines). The
## depth limit is REPORT ONLY while ENV D iterates the grip (PO 2026-10-14); it becomes an assert once green.
## Owner: ENV P.
extends TestCase

const LONG_GUNS: Array[StringName] = [&"weapon.corsair_ar", &"weapon.bastion_br", &"weapon.mule_12",
	&"weapon.anvil_lmg", &"weapon.condor_50", &"weapon.reaper_db", &"weapon.shrike_44", &"weapon.brute_12"]

var _root: Node3D = null
var _inp: PInputDriver = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	await wait_frames(1)


func _spawn(primary: StringName) -> CrewController:
	Net.start_solo("Player", 0)
	_root = Node3D.new()
	add_child(_root)
	await wait_frames(1)
	var l: Loadout = Loadout.new()
	l.primary = primary
	l.secondary = &"weapon.kestrel_p9"
	var c: CrewController = CrewController.spawn_for_range(_root, Transform3D.IDENTITY, l) as CrewController
	await wait_frames(40)  # draw finished, IK influence at 1
	return c


func test_skinning_matches_bones() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _spawn(&"weapon.corsair_ar")
	var fp: FpViewmodel = CrewView.of(c).fp_viewmodel()
	var r: Dictionary = await PFingerClip.measure(fp, c.weapon_visual as Node3D)
	assert_true(bool(r.get("_ok", false)), "measured (%s)" % r)
	assert_true(int(r.get("_total", {}).get("verts", 0)) > 50, "finger vertices found")
	# Skinning sanity: finger skin vertices lie within a phalanx of their strongest bone's head.
	var md: float = float(r.get("_mean_bone_m", INF))
	assert_true(md < 0.03, "finger vertices %.1f mm from their bones on average" % (md * 1000.0))


## The probe is not blind: the same Corsair with the IK target moved 4.5 cm left (the fingers curl round the right
## side, so they land inside the fore-end) reports many more finger vertices inside.
func test_probe_detects_pushed_hand() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	if tw.arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _spawn(&"weapon.corsair_ar")
	var base_r: Dictionary = await PFingerClip.measure(CrewView.of(c).fp_viewmodel(), c.weapon_visual as Node3D)
	var base: Dictionary = base_r["_total"]
	await after_each()
	var saved: Dictionary[StringName, Vector3] = tw.set_left_hand_grip_offset.duplicate()
	tw.set_left_hand_grip_offset[&"rifle"] = tw.grip_offset(&"rifle") + Vector3(-0.045, 0, 0)
	c = await _spawn(&"weapon.corsair_ar")
	var pushed_r: Dictionary = await PFingerClip.measure(CrewView.of(c).fp_viewmodel(), c.weapon_visual as Node3D)
	var pushed: Dictionary = pushed_r["_total"]
	tw.set_left_hand_grip_offset = saved
	print("[FINGERS] probe check: base %s, pushed 4.5 cm left %s" % [base, pushed])
	assert_true(int(pushed["inside"]) > int(base["inside"]) * 2 + 30, "pushed hand: many more vertices inside")


func test_report_long_guns() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	for w: StringName in LONG_GUNS:
		var c: CrewController = await _spawn(w)
		var fp: FpViewmodel = CrewView.of(c).fp_viewmodel()
		_inp = PInputDriver.new(self)
		for pose: String in ["hip", "ads"]:
			if pose == "ads":
				_inp.press(&"aim")
				await wait_frames(40)
			var r: Dictionary = await PFingerClip.measure(fp, c.weapon_visual as Node3D)
			assert_true(bool(r.get("_ok", false)), "%s %s measured" % [w, pose])
			var line: String = "[FINGERS] %s %s set=%s gun_tris=%d" % [w, pose, fp.anim_set, int(r.get("_gun_tris", 0))]
			for f: String in PFingerClip.FINGERS + PackedStringArray(["_total"]):
				var e: Dictionary = r.get(f, {})
				line += " %s %d/%d %.1fmm" % [f.trim_prefix("_"), int(e.get("inside", 0)), int(e.get("verts", 0)),
					float(e.get("max_mm", 0.0))]
			print(line)
		await after_each()
