## D-116 (PO, supersedes the PO6-11 two-hand hold in FIRST PERSON): pistol / revolver are one-handed: no left-hand IK,
## the left arm stays out of the viewmodel camera's view at the hip and through ADS and comes back for the reload;
## the hip pose / ADS arc tweaks are in place, and the ADS settle returns the sights to the crosshair. Real input
## (PInputDriver). Owner: ENV P.
extends TestCase

var _rt: HeistRuntime = null
var _inp: PInputDriver = null
## Post-modifier wrist (hand.L origin) in LeftHandIK marker space, sampled in Skeleton3D.skeleton_updated.
var _wrists: Array[Vector3] = []
var _fp: FpViewmodel = null
var _marker: Node3D = null


func after_each() -> void:
	if _inp != null:
		_inp.release_all()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	_fp = null
	_marker = null
	await wait_frames(1)


func test_pistol_sets_one_handed() -> void:
	var tw: FpViewmodelTweak = FpViewmodelTweak.data()
	for set_id: StringName in [&"pistol", &"revolver"]:
		assert_true(tw.one_handed_fp_sets.has(set_id), "%s is one-handed in first person" % set_id)
		assert_true(tw.left_hand_ik_skip_sets.has(set_id), "%s skips the left-hand IK" % set_id)
		assert_true(tw.set_hip_rot_deg.has(set_id), "%s has a hip pose" % set_id)
		assert_true(float(tw.set_ads_arc_roll_deg.get(set_id, 0.0)) > 0.0, "%s has an ADS arc" % set_id)
	assert_false(tw.one_handed_fp_sets.has(&"rifle"), "long guns stay two-handed")


func _launch(wid: StringName) -> CrewController:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.secondary = wid
	l.secondary_mods = [] as Array[StringName]
	l.resolved_secondary = LoadoutResolver.resolve_weapon(wid, l.secondary_mods)
	_rt = await HeistLauncher.launch(&"unit_map", 42, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "crew_ai": false, "loadouts": {0: l}})
	_inp = PInputDriver.new(self)
	_inp.capture_mouse()
	var c: CrewController = _rt.crew_controller(0) as CrewController
	await _inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.2)
	await _inp.tap(&"slot_secondary")
	await wait_physics_frames(90)
	return c


## Post-modifier hand.L in the viewmodel camera's view: true when it is inside the screen (with a margin).
func _on_skel() -> void:
	if _fp == null or not is_instance_valid(_fp):
		return
	var vc: Camera3D = CrewView.of(_fp.crew()).viewmodel_camera()
	var hb: int = _fp.skeleton.find_bone(FpLeftHandIk.END_BONE)
	var p: Vector3 = _fp.skeleton.global_transform * _fp.skeleton.get_bone_global_pose(hb).origin
	var cam: Camera3D = vc if vc != null else get_viewport().get_camera_3d()
	var sz: Vector2 = get_viewport().get_visible_rect().size
	var on_screen: bool = not cam.is_position_behind(p) and Rect2(Vector2.ZERO, sz).grow(sz.y * 0.05) \
		.has_point(cam.unproject_position(p))
	_wrists.append(Vector3(1.0 if on_screen else 0.0, 0.0, 0.0))


func test_left_arm_out_of_view_except_reload() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	for wid: StringName in [&"weapon.kestrel_p9", &"weapon.marshal_357"]:
		var c: CrewController = await _launch(wid)
		_fp = FpViewmodel.of(get_viewport().get_camera_3d())
		assert_true(_fp != null and c != null, "%s: FP viewmodel" % wid)
		if _fp == null:
			await after_each()
			continue
		_wrists.clear()
		_fp.skeleton.skeleton_updated.connect(_on_skel)
		_inp.press(&"aim")
		await wait_physics_frames(40)
		_inp.release(&"aim")
		await wait_physics_frames(40)
		_fp.skeleton.skeleton_updated.disconnect(_on_skel)
		var seen: int = 0
		for w: Vector3 in _wrists:
			seen += int(w.x)
		assert_true(_wrists.size() > 30, "%s: sampled %d poses" % [wid, _wrists.size()])
		assert_eq(seen, 0, "%s: the left hand is never on screen at the hip / through ADS (%d of %d)" % [wid, seen,
			_wrists.size()])
		assert_near(_fp.left_arm_drop(), 1.0, 1e-3, "%s: left arm fully dropped" % wid)
		for _k: int in 2:  # a full magazine does not reload
			await _inp.tap(&"fire")
			await wait_physics_frames(20)
		await _inp.tap(&"reload")
		assert_true(await wait_until(func() -> bool: return _fp.left_arm_drop() < 0.5, 2.0),
			"%s: the left arm comes back for the reload (%.2f)" % [wid, _fp.left_arm_drop()])
		await after_each()


func test_ads_settles_on_axis() -> void:
	if FpViewmodelTweak.data().arms_scene == null:
		skip("char_arms_fp not delivered")
		return
	var c: CrewController = await _launch(&"weapon.kestrel_p9")
	assert_true(c != null, "crew")
	_fp = FpViewmodel.of(get_viewport().get_camera_3d())
	_inp.press(&"aim")
	await wait_physics_frames(60)
	var cam: Camera3D = get_viewport().get_camera_3d()
	var aim: Node3D = _fp.weapon_visual.get_marker(WeaponVisual.AIM_POINT)
	var p: Vector3 = cam.global_transform.affine_inverse() * aim.global_position
	assert_near(_fp.ads_weight, 1.0, 1e-3, "aimed")
	assert_true(Vector2(p.x, p.y).length() < 0.002, "settled sights on the camera axis (%s)" % p)
	_inp.release(&"aim")
